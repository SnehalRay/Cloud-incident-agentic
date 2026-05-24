use serde::Deserialize;

// Shape of a JSON log line from logstash-logback-encoder
#[derive(Deserialize)]
struct LogLine {
    message: String,
}

#[derive(Debug)]
pub enum LogEvent {
    HttpRequest {
        method: String,
        endpoint: String,
        status: String,
        duration_ms: f64,
    },
    RateLimitExceeded {
        instance_id: String,
    },
    DbWriteFailed {
        shard: String,
    },
    CacheError {
        operation: String, // get | put | evict | clear
    },
    RedisUnavailable,
    SlowRequest,
    ShardOverload {
        shard: String,
    },
    Ignored,
}

pub fn parse(line: &str) -> Option<LogEvent> {
    let log_line: LogLine = serde_json::from_str(line).ok()?;
    let msg = log_line.message.as_str();

    let event = if msg.starts_with("service=backend") {
        LogEvent::HttpRequest {
            method:      kv(msg, "method").unwrap_or("unknown").into(),
            endpoint:    kv(msg, "endpoint").unwrap_or("unknown").into(),
            status:      kv(msg, "status").unwrap_or("0").into(),
            duration_ms: kv(msg, "duration_ms").and_then(|v| v.parse().ok()).unwrap_or(0.0),
        }
    } else if msg.starts_with("rate_limit_exceeded") {
        LogEvent::RateLimitExceeded {
            instance_id: kv(msg, "instance_id").unwrap_or("unknown").into(),
        }
    } else if msg.starts_with("db_write_failed") {
        LogEvent::DbWriteFailed {
            shard: kv(msg, "shard").unwrap_or("unknown").into(),
        }
    } else if msg.starts_with("cache_get_error") {
        LogEvent::CacheError { operation: "get".into() }
    } else if msg.starts_with("cache_put_error") {
        LogEvent::CacheError { operation: "put".into() }
    } else if msg.starts_with("cache_evict_error") {
        LogEvent::CacheError { operation: "evict".into() }
    } else if msg.starts_with("cache_clear_error") {
        LogEvent::CacheError { operation: "clear".into() }
    } else if msg.starts_with("rate_limiter_redis_unavailable") {
        LogEvent::RedisUnavailable
    } else if msg.starts_with("slow_request_start") {
        LogEvent::SlowRequest
    } else if msg.starts_with("overload_shard_start") {
        LogEvent::ShardOverload {
            shard: kv(msg, "shard").unwrap_or("unknown").into(),
        }
    } else {
        LogEvent::Ignored
    };

    Some(event)
}

// Extracts the value for `key=` from a key=value message string.
// Stops at the next space — works for values without spaces.
fn kv<'a>(msg: &'a str, key: &str) -> Option<&'a str> {
    let needle = format!("{}=", key);
    let start = msg.find(needle.as_str())? + needle.len();
    let rest = &msg[start..];
    let end = rest.find(' ').unwrap_or(rest.len());
    Some(&rest[..end])
}
