//! Prometheus instruments exposed by the load balancer on :9095.
//!
//! Mirrors the style of services/log-pipeline/src/metrics.rs. The `lb_` prefix
//! keeps these distinct from the backend's `backend_*` series. None of these
//! names a fault — the diagnosis agent decides what a given reading implies.

use lazy_static::lazy_static;
use prometheus::{
    register_counter_vec, register_int_counter, register_int_gauge_vec, CounterVec, Encoder,
    IntCounter, IntGaugeVec, TextEncoder,
};

lazy_static! {
    // Requests the LB successfully routed, by upstream node and resulting status.
    // This is the per-node load signal (also surfaces a "hot replica").
    pub static ref LB_REQUESTS_TOTAL: CounterVec = register_counter_vec!(
        "lb_requests_total",
        "Requests routed by the load balancer, by upstream and resulting status",
        &["upstream", "status"]
    )
    .unwrap();

    // The LB's own health-check view of each backend node.
    pub static ref LB_UPSTREAM_UP: IntGaugeVec = register_int_gauge_vec!(
        "lb_upstream_up",
        "Health-check state per backend upstream (1 = healthy, 0 = unhealthy)",
        &["upstream"]
    )
    .unwrap();

    // Forward attempts that could not reach the chosen upstream.
    pub static ref LB_UPSTREAM_FAILURES: CounterVec = register_counter_vec!(
        "lb_upstream_failures_total",
        "Forward attempts that failed to reach an upstream",
        &["upstream"]
    )
    .unwrap();

    // Requests rejected because no upstream was healthy at all.
    pub static ref LB_NO_HEALTHY: IntCounter = register_int_counter!(
        "lb_no_healthy_upstreams_total",
        "Requests rejected because no backend upstream was healthy"
    )
    .unwrap();
}

pub fn init() {
    lazy_static::initialize(&LB_REQUESTS_TOTAL);
    lazy_static::initialize(&LB_UPSTREAM_UP);
    lazy_static::initialize(&LB_UPSTREAM_FAILURES);
    lazy_static::initialize(&LB_NO_HEALTHY);
}

pub fn render() -> String {
    let encoder = TextEncoder::new();
    let families = prometheus::gather();
    let mut buf = Vec::new();
    encoder.encode(&families, &mut buf).unwrap();
    String::from_utf8(buf).unwrap()
}
