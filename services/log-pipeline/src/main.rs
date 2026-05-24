mod docker_logs;
mod log_parser;
mod metrics;

use axum::{routing::get, Router};
use tracing::info;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env()
            .add_directive("log_pipeline=info".parse().unwrap()))
        .init();

    metrics::init();

    // Stream logs from the backend container in a background task.
    // Retries automatically if the container isn't up yet or restarts.
    tokio::spawn(async {
        docker_logs::stream_with_retry("incident-lab-backend").await;
    });

    let app = Router::new().route("/metrics", get(metrics_handler));
    let listener = tokio::net::TcpListener::bind("0.0.0.0:9091").await.unwrap();
    info!("metrics_server_start addr=0.0.0.0:9091");
    axum::serve(listener, app).await.unwrap();
}

async fn metrics_handler() -> String {
    metrics::render()
}
