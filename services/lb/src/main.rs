//! A small reverse-proxy load balancer in front of the backend nodes.
//!
//! Behaviour:
//!   * round-robin across BACKEND_NODES, skipping nodes that fail health checks
//!   * active health checks every HEALTH_INTERVAL_SECS against HEALTH_PATH
//!   * proxy traffic on LB_PORT (default 8080)
//!   * expose Prometheus metrics on METRICS_PORT (default 9095)
//!
//! Killing this process is the `lb-failure-fault`: the backend nodes stay
//! healthy, but nothing routes traffic to them — exposing the LB as a single
//! point of failure.

mod metrics;

use std::net::SocketAddr;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::Duration;

use axum::{
    body::Body,
    extract::State,
    http::{header, Request, Response, StatusCode},
    response::IntoResponse,
    routing::get,
    Router,
};
use tokio::time::sleep;
use tracing::{info, warn};

struct Upstream {
    addr: String,
    healthy: AtomicBool,
}

struct Pool {
    ups: Vec<Upstream>,
    idx: AtomicUsize,
}

impl Pool {
    fn from_env() -> Arc<Self> {
        let nodes = std::env::var("BACKEND_NODES")
            .unwrap_or_else(|_| "backend-1:8080,backend-2:8080".into());
        let ups = nodes
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .map(|addr| Upstream {
                addr,
                healthy: AtomicBool::new(false),
            })
            .collect();
        Arc::new(Pool {
            ups,
            idx: AtomicUsize::new(0),
        })
    }

    /// Round-robin over only the currently-healthy upstreams.
    fn next_healthy_addr(&self) -> Option<String> {
        let n = self.ups.len();
        for _ in 0..n {
            let i = self.idx.fetch_add(1, Ordering::Relaxed) % n;
            if self.ups[i].healthy.load(Ordering::Relaxed) {
                return Some(self.ups[i].addr.clone());
            }
        }
        None
    }
}

#[derive(Clone)]
struct AppState {
    pool: Arc<Pool>,
    client: reqwest::Client,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("lb=info".parse().unwrap()),
        )
        .init();

    metrics::init();

    let pool = Pool::from_env();
    for up in &pool.ups {
        metrics::LB_UPSTREAM_UP
            .with_label_values(&[&up.addr])
            .set(0);
    }
    info!(upstreams = pool.ups.len(), "lb_start");

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(10))
        .build()
        .expect("reqwest client build failed");

    // Health-check loop in the background.
    {
        let pool = pool.clone();
        let client = client.clone();
        tokio::spawn(async move { health_loop(pool, client).await });
    }

    // Metrics server on its own port.
    let metrics_port: u16 = env_u16("METRICS_PORT", 9095);
    tokio::spawn(async move {
        let app = Router::new().route("/metrics", get(|| async { metrics::render() }));
        let addr = SocketAddr::from(([0, 0, 0, 0], metrics_port));
        let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
        info!(%addr, "lb_metrics_server_start");
        axum::serve(listener, app).await.unwrap();
    });

    // Proxy server (the data plane).
    let lb_port: u16 = env_u16("LB_PORT", 8080);
    let state = AppState {
        pool: pool.clone(),
        client,
    };
    let app = Router::new().fallback(proxy).with_state(state);
    let addr = SocketAddr::from(([0, 0, 0, 0], lb_port));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    info!(%addr, "lb_proxy_server_start");
    axum::serve(listener, app).await.unwrap();
}

fn env_u16(key: &str, default: u16) -> u16 {
    std::env::var(key)
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(default)
}

async fn health_loop(pool: Arc<Pool>, client: reqwest::Client) {
    let path = std::env::var("HEALTH_PATH").unwrap_or_else(|_| "/actuator/health".into());
    let interval = std::env::var("HEALTH_INTERVAL_SECS")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(2u64);

    loop {
        for up in &pool.ups {
            let url = format!("http://{}{}", up.addr, path);
            let ok = matches!(
                client.get(url).timeout(Duration::from_secs(2)).send().await,
                Ok(r) if r.status().is_success()
            );
            let was = up.healthy.swap(ok, Ordering::Relaxed);
            metrics::LB_UPSTREAM_UP
                .with_label_values(&[&up.addr])
                .set(if ok { 1 } else { 0 });
            if was != ok {
                if ok {
                    info!(upstream = %up.addr, "upstream_healthy");
                } else {
                    warn!(upstream = %up.addr, "upstream_unhealthy");
                }
            }
        }
        sleep(Duration::from_secs(interval)).await;
    }
}

async fn proxy(State(state): State<AppState>, req: Request<Body>) -> Response<Body> {
    let Some(addr) = state.pool.next_healthy_addr() else {
        metrics::LB_NO_HEALTHY.inc();
        return (StatusCode::SERVICE_UNAVAILABLE, "no healthy upstreams\n").into_response();
    };

    let path_q = req
        .uri()
        .path_and_query()
        .map(|p| p.as_str())
        .unwrap_or("/")
        .to_string();
    let url = format!("http://{}{}", addr, path_q);

    let (parts, body) = req.into_parts();
    let body_bytes = match axum::body::to_bytes(body, usize::MAX).await {
        Ok(b) => b,
        Err(_) => return (StatusCode::BAD_REQUEST, "bad request body\n").into_response(),
    };

    // Let reqwest set Host for the upstream rather than forwarding the client's.
    let mut headers = parts.headers.clone();
    headers.remove(header::HOST);

    let upstream_resp = state
        .client
        .request(parts.method, url)
        .headers(headers)
        .body(body_bytes)
        .send()
        .await;

    match upstream_resp {
        Ok(r) => {
            let status = r.status();
            metrics::LB_REQUESTS_TOTAL
                .with_label_values(&[&addr, status.as_str()])
                .inc();
            let mut builder = Response::builder().status(status);
            for (k, v) in r.headers().iter() {
                // Drop hop-by-hop headers; let the framework re-encode the body.
                if k == header::TRANSFER_ENCODING || k == header::CONNECTION {
                    continue;
                }
                builder = builder.header(k, v);
            }
            let bytes = r.bytes().await.unwrap_or_default();
            builder.body(Body::from(bytes)).unwrap()
        }
        Err(_) => {
            metrics::LB_UPSTREAM_FAILURES
                .with_label_values(&[&addr])
                .inc();
            (StatusCode::BAD_GATEWAY, "upstream error\n").into_response()
        }
    }
}
