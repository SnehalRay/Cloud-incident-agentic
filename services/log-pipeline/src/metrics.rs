use lazy_static::lazy_static;
use prometheus::{
    register_counter_vec, register_histogram_vec, register_int_counter,
    CounterVec, Encoder, HistogramVec, IntCounter, TextEncoder,
};

lazy_static! {
    // Every HTTP request logged by RequestLoggingFilter
    pub static ref HTTP_REQUESTS_TOTAL: CounterVec = register_counter_vec!(
        "backend_http_requests_total",
        "Total HTTP requests processed by the backend",
        &["method", "endpoint", "status"]
    ).unwrap();

    // duration_ms field from RequestLoggingFilter
    pub static ref HTTP_DURATION_MS: HistogramVec = register_histogram_vec!(
        "backend_http_request_duration_ms",
        "HTTP request duration in milliseconds",
        &["endpoint"],
        vec![5.0, 10.0, 50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0, 10000.0, 30000.0]
    ).unwrap();

    // rate_limit_exceeded log entries
    pub static ref RATE_LIMIT_VIOLATIONS: CounterVec = register_counter_vec!(
        "backend_rate_limit_violations_total",
        "Rate limit violations per instance",
        &["instance_id"]
    ).unwrap();

    // db_write_failed log entries
    pub static ref DB_WRITE_FAILURES: CounterVec = register_counter_vec!(
        "backend_db_write_failures_total",
        "Database write failures per shard",
        &["shard"]
    ).unwrap();

    // cache_get/put/evict_error log entries
    pub static ref CACHE_ERRORS: CounterVec = register_counter_vec!(
        "backend_cache_errors_total",
        "Cache operation errors by type",
        &["operation"]
    ).unwrap();

    // rate_limiter_redis_unavailable log entries
    pub static ref REDIS_UNAVAILABLE: IntCounter = register_int_counter!(
        "backend_redis_unavailable_total",
        "Number of times Redis was unavailable"
    ).unwrap();

    // slow_request_start log entries
    pub static ref SLOW_REQUESTS: IntCounter = register_int_counter!(
        "backend_slow_requests_total",
        "Number of intentional slow requests started"
    ).unwrap();

    // overload_shard_start log entries
    pub static ref SHARD_OVERLOADS: CounterVec = register_counter_vec!(
        "backend_shard_overload_events_total",
        "Shard overload events triggered",
        &["shard"]
    ).unwrap();

    // Docker OOM kill events — fires when any container is OOM-killed
    pub static ref OOM_KILLS: CounterVec = register_counter_vec!(
        "container_oom_kills_total",
        "Number of OOM kills per container observed via Docker events API",
        &["container"]
    ).unwrap();

    // db_query_slow log entries — distinguishes network degradation from hard partition
    pub static ref DB_QUERY_SLOW: CounterVec = register_counter_vec!(
        "backend_db_query_slow_total",
        "Database queries that exceeded 500ms, labelled by shard",
        &["shard"]
    ).unwrap();

    // Incremented each time the pipeline reconnects to the backend log stream.
    // Each reconnect = container restarted. Agent uses this to detect crash loops.
    pub static ref CONTAINER_RESTARTS: IntCounter = register_int_counter!(
        "backend_container_restarts_total",
        "Number of times the backend container log stream reconnected (proxy for restarts)"
    ).unwrap();
}

pub fn init() {
    // Touch each metric to force lazy_static initialisation at startup
    lazy_static::initialize(&HTTP_REQUESTS_TOTAL);
    lazy_static::initialize(&HTTP_DURATION_MS);
    lazy_static::initialize(&RATE_LIMIT_VIOLATIONS);
    lazy_static::initialize(&DB_WRITE_FAILURES);
    lazy_static::initialize(&CACHE_ERRORS);
    lazy_static::initialize(&REDIS_UNAVAILABLE);
    lazy_static::initialize(&SLOW_REQUESTS);
    lazy_static::initialize(&SHARD_OVERLOADS);
    lazy_static::initialize(&DB_QUERY_SLOW);
    lazy_static::initialize(&OOM_KILLS);
    lazy_static::initialize(&CONTAINER_RESTARTS);
}

pub fn render() -> String {
    let encoder = TextEncoder::new();
    let families = prometheus::gather();
    let mut buf = Vec::new();
    encoder.encode(&families, &mut buf).unwrap();
    String::from_utf8(buf).unwrap()
}
