use rdkafka::config::ClientConfig;
use rdkafka::consumer::{Consumer, StreamConsumer};
use rdkafka::message::Message;
use rdkafka::producer::{FutureProducer, FutureRecord};
use rand::Rng;
use tokio::time::{sleep, Duration};
use tracing::{error, info, warn};

const TOPIC_INPUT: &str = "item-events";
const TOPIC_DLT: &str = "item-events.DLT";

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("kafka_consumer=info".parse().unwrap()),
        )
        .init();

    let brokers = std::env::var("KAFKA_BROKERS")
        .unwrap_or_else(|_| "kafka:9092".into());

    let fail_rate: f64 = std::env::var("CONSUMER_FAIL_RATE")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(0.0)
        .clamp(0.0, 1.0);

    let max_retries: u32 = std::env::var("MAX_RETRIES")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(3);

    info!(
        brokers  = %brokers,
        fail_rate = %fail_rate,
        max_retries = %max_retries,
        "kafka_consumer_start"
    );

    let consumer: StreamConsumer = ClientConfig::new()
        .set("group.id",           "item-events-consumer")
        .set("bootstrap.servers",  &brokers)
        .set("enable.auto.commit", "true")
        .set("auto.offset.reset",  "earliest")
        .create()
        .expect("consumer creation failed");

    let producer: FutureProducer = ClientConfig::new()
        .set("bootstrap.servers", &brokers)
        .create()
        .expect("producer creation failed");

    consumer
        .subscribe(&[TOPIC_INPUT])
        .expect("subscribe failed");

    info!(topic = TOPIC_INPUT, "kafka_consumer_subscribed");

    loop {
        match consumer.recv().await {
            Err(e) => error!(error = %e, "kafka_recv_error"),
            Ok(msg) => {
                let payload = msg
                    .payload_str()
                    .unwrap_or("")
                    .to_string();

                info!(
                    partition = %msg.partition(),
                    offset    = %msg.offset(),
                    "kafka_message_received"
                );

                process_message(&payload, &producer, fail_rate, max_retries).await;
            }
        }
    }
}

async fn process_message(
    payload: &str,
    producer: &FutureProducer,
    fail_rate: f64,
    max_retries: u32,
) {
    let mut rng = rand::thread_rng();

    for attempt in 1..=max_retries {
        if rng.gen::<f64>() >= fail_rate {
            info!(attempt = %attempt, "kafka_message_processed");
            return;
        }

        warn!(
            attempt     = %attempt,
            max_retries = %max_retries,
            payload     = %payload,
            "kafka_message_processing_failed"
        );

        if attempt < max_retries {
            // exponential back-off: 200ms, 400ms
            sleep(Duration::from_millis(200 * attempt as u64)).await;
        }
    }

    // All retries exhausted — dead-letter the message
    error!(payload = %payload, "kafka_message_sent_to_dlt");
    send_to_dlt(producer, payload).await;
}

async fn send_to_dlt(producer: &FutureProducer, payload: &str) {
    let record = FutureRecord::to(TOPIC_DLT)
        .payload(payload)
        .key("failed");

    match producer.send(record, Duration::from_secs(5)).await {
        Ok((partition, offset)) => {
            info!(
                topic     = TOPIC_DLT,
                partition = %partition,
                offset    = %offset,
                "kafka_dlt_write_ok"
            );
        }
        Err((e, _)) => error!(error = %e, "kafka_dlt_write_failed"),
    }
}
