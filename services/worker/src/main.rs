use redis::AsyncCommands;
use serde::Deserialize;
use sqlx::PgPool;
use tokio::time::{sleep, Duration};
use tracing::{error, info, warn};

#[derive(Debug, Deserialize)]
struct Job {
    #[serde(rename = "type")]
    job_type: String,
    instance_id: Option<String>,
    endpoint:    Option<String>,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("worker=info".parse().unwrap()),
        )
        .init();

    let redis_url = std::env::var("REDIS_URL")
        .unwrap_or_else(|_| "redis://redis:6379".into());
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");

    let pool = connect_db(&database_url).await;
    let client = redis::Client::open(redis_url.as_str())
        .expect("invalid REDIS_URL");

    info!(queue = "jobs:queue", "worker_started");

    loop {
        match process_next(&client, &pool).await {
            Ok(_)  => {}
            Err(e) => {
                error!(error = %e, "worker_error — retrying in 3s");
                sleep(Duration::from_secs(3)).await;
            }
        }
    }
}

async fn connect_db(url: &str) -> PgPool {
    loop {
        match PgPool::connect(url).await {
            Ok(pool) => {
                info!("worker_db_connected");
                return pool;
            }
            Err(e) => {
                error!(error = %e, "worker_db_connect_failed — retrying in 3s");
                sleep(Duration::from_secs(3)).await;
            }
        }
    }
}

async fn process_next(
    client: &redis::Client,
    pool: &PgPool,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut conn = client.get_async_connection().await?;

    // Block up to 30s for a job — returns None on timeout, Some((key, value)) on job
    let result: Option<(String, String)> = conn.blpop("jobs:queue", 30.0).await?;

    let payload = match result {
        Some((_, v)) => v,
        None => return Ok(()), // timeout — nothing in the queue
    };

    let job: Job = match serde_json::from_str(&payload) {
        Ok(j) => j,
        Err(e) => {
            warn!(payload = %payload, error = %e, "job_parse_failed — skipping");
            return Ok(());
        }
    };

    let instance_id = job.instance_id.as_deref().unwrap_or("unknown");
    let endpoint    = job.endpoint.as_deref().unwrap_or("unknown");

    info!(
        job_type   = %job.job_type,
        instance_id = %instance_id,
        endpoint    = %endpoint,
        "job_received"
    );

    sqlx::query(
        "INSERT INTO audit_log (event_type, instance_id, endpoint) VALUES ($1, $2, $3)",
    )
    .bind(&job.job_type)
    .bind(instance_id)
    .bind(endpoint)
    .execute(pool)
    .await?;

    info!(
        job_type    = %job.job_type,
        instance_id = %instance_id,
        "job_processed"
    );

    Ok(())
}
