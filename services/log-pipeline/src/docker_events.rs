use bollard::system::EventsOptions;
use bollard::Docker;
use futures_util::StreamExt;
use std::collections::HashMap;
use tokio::time::{sleep, Duration};
use tracing::{error, info, warn};

use crate::metrics;

/// Watches the Docker event stream for OOM kills on any container and
/// increments `container_oom_kills_total{container=<name>}`.
pub async fn watch_oom_events() {
    let mut first = true;
    loop {
        if !first {
            sleep(Duration::from_secs(5)).await;
        }
        first = false;

        info!("oom_watcher_connecting");
        match stream_events().await {
            Ok(()) => warn!("oom_watcher_stream_closed — reconnecting in 5s"),
            Err(e) => error!("oom_watcher_error error={} — retrying in 5s", e),
        }
    }
}

async fn stream_events() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let docker = Docker::connect_with_socket_defaults()?;

    // Filter to container-scoped OOM events only
    let mut filters = HashMap::new();
    filters.insert("type", vec!["container"]);
    filters.insert("event", vec!["oom"]);

    let options = EventsOptions {
        filters,
        ..Default::default()
    };

    let mut stream = docker.events(Some(options));
    info!("oom_watcher_started");

    while let Some(result) = stream.next().await {
        let event = result?;

        // Actor.Attributes["name"] holds the container name
        let container_name = event
            .actor
            .and_then(|a| a.attributes)
            .and_then(|attrs| attrs.get("name").cloned())
            .unwrap_or_else(|| "unknown".into());

        info!(container = %container_name, "oom_kill_detected");
        metrics::OOM_KILLS
            .with_label_values(&[&container_name])
            .inc();
    }

    Ok(())
}
