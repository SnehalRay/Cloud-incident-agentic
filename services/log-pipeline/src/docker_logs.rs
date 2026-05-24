use bollard::container::{LogOutput, LogsOptions};
use bollard::Docker;
use futures_util::StreamExt;
use tokio::time::{sleep, Duration};
use tracing::{error, info, warn};

use crate::log_parser::{self, LogEvent};
use crate::metrics;

// Keeps streaming logs from the target container, retrying on any error.
pub async fn stream_with_retry(container: &str) {
    let mut first = true;
    loop {
        info!("log_stream_connecting container={}", container);
        match stream(container).await {
            Ok(()) => warn!("log_stream_closed container={} — reconnecting in 5s", container),
            Err(e) => error!("log_stream_error container={} error={} — retrying in 5s", container, e),
        }
        // Every reconnect after the first means the container restarted
        if !first {
            metrics::CONTAINER_RESTARTS.inc();
        }
        first = false;
        sleep(Duration::from_secs(5)).await;
    }
}

async fn stream(container: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let docker = Docker::connect_with_socket_defaults()?;

    // tail=0 means no backlog — only new lines from the moment we connect
    let options = LogsOptions::<String> {
        follow:     true,
        stdout:     true,
        stderr:     true,
        tail:       "0".into(),
        timestamps: false,
        ..Default::default()
    };

    let mut stream = docker.logs(container, Some(options));
    info!("log_stream_started container={}", container);

    while let Some(result) = stream.next().await {
        let bytes = match result? {
            LogOutput::StdOut { message } => message,
            LogOutput::StdErr { message } => message,
            _ => continue,
        };

        let text = String::from_utf8_lossy(&bytes);
        for line in text.lines() {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            if let Some(event) = log_parser::parse(line) {
                record(event);
            }
        }
    }

    Ok(())
}

fn record(event: LogEvent) {
    match event {
        LogEvent::HttpRequest { method, endpoint, status, duration_ms } => {
            metrics::HTTP_REQUESTS_TOTAL
                .with_label_values(&[&method, &endpoint, &status])
                .inc();
            metrics::HTTP_DURATION_MS
                .with_label_values(&[&endpoint])
                .observe(duration_ms);
        }
        LogEvent::RateLimitExceeded { instance_id } => {
            metrics::RATE_LIMIT_VIOLATIONS
                .with_label_values(&[&instance_id])
                .inc();
        }
        LogEvent::DbWriteFailed { shard } => {
            metrics::DB_WRITE_FAILURES
                .with_label_values(&[&shard])
                .inc();
        }
        LogEvent::CacheError { operation } => {
            metrics::CACHE_ERRORS
                .with_label_values(&[&operation])
                .inc();
        }
        LogEvent::RedisUnavailable => {
            metrics::REDIS_UNAVAILABLE.inc();
        }
        LogEvent::SlowRequest => {
            metrics::SLOW_REQUESTS.inc();
        }
        LogEvent::ShardOverload { shard } => {
            metrics::SHARD_OVERLOADS
                .with_label_values(&[&shard])
                .inc();
        }
        LogEvent::DbQuerySlow { shard } => {
            metrics::DB_QUERY_SLOW
                .with_label_values(&[&shard])
                .inc();
        }
        LogEvent::Ignored => {}
    }
}
