# Log Pipeline — Metrics Reference

All metrics are exposed at `http://log-pipeline:9091/metrics` and scraped by Prometheus.

## Fault Diagnosis Map

The agent should use these PromQL queries to identify active faults.

### Rate Limit Storm
```promql
rate(backend_rate_limit_violations_total[2m]) > 0
```
If this is non-zero, the rate limiter is actively rejecting requests.
Check label `instance_id` to see which frontend instance is the source.

---

### Redis Outage
```promql
rate(backend_redis_unavailable_total[2m]) > 0
rate(backend_cache_errors_total{operation="get"}[2m]) > 0
```
Both firing together = Redis is down.
Side effect: rate limiter fails open (429s disappear even under load).

---

### Hot Database Shard
```promql
rate(backend_shard_overload_events_total[5m]) > 0
rate(backend_db_write_failures_total[2m]) > 0
```
`shard_overload_events_total` firing = overload was deliberately triggered.
Check the `shard` label to identify which shard is affected.

---

### Network Partition (shard unreachable)
```promql
rate(backend_db_write_failures_total[2m]) > 0
rate(backend_shard_overload_events_total[5m]) == 0
```
DB write failures WITHOUT a prior shard overload event = network partition.
Check `shard` label to identify the partitioned shard.

---

### Slow Request / Thread Pool Exhaustion
```promql
histogram_quantile(0.95, rate(backend_http_request_duration_ms_bucket[2m])) > 5000
rate(backend_slow_requests_total[2m]) > 0
```
p95 latency above 5 seconds with slow requests active = thread pool exhaustion.

---

### Backend Crash Loop
```promql
increase(backend_container_restarts_total[5m]) > 1
rate(backend_http_requests_total[2m]) == 0
```
Container restart counter increasing = crash loop.
Request rate going to zero confirms backend is unavailable between restarts.

---

## Full Metric List

| Metric | Type | Labels | Populated by |
|--------|------|--------|--------------|
| `backend_http_requests_total` | counter | method, endpoint, status | every request |
| `backend_http_request_duration_ms` | histogram | endpoint | duration_ms field |
| `backend_rate_limit_violations_total` | counter | instance_id | rate_limit_exceeded log |
| `backend_db_write_failures_total` | counter | shard | db_write_failed log |
| `backend_cache_errors_total` | counter | operation | cache_*_error logs |
| `backend_redis_unavailable_total` | counter | — | rate_limiter_redis_unavailable log |
| `backend_slow_requests_total` | counter | — | slow_request_start log |
| `backend_shard_overload_events_total` | counter | shard | overload_shard_start log |
| `backend_container_restarts_total` | counter | — | pipeline log stream reconnect |
