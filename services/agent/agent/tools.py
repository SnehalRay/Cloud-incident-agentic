"""LangChain tools the agent uses to investigate Prometheus.

Each tool returns a compact, human-readable string rather than raw JSON — the
model reasons over text far more reliably than over nested result envelopes.
"""

from __future__ import annotations

from langchain_core.tools import tool

from . import prometheus


def _format_instant(data: dict) -> str:
    result = data.get("result", [])
    if not result:
        return "(no series — the metric exists but currently has no matching samples)"
    lines = []
    for series in result:
        metric = dict(series.get("metric", {}))
        metric.pop("__name__", None)
        labels = ", ".join(f"{k}={v}" for k, v in sorted(metric.items()))
        value = series.get("value", [None, "?"])[1]
        lines.append(f"  {{{labels}}} => {value}" if labels else f"  (no labels) => {value}")
    return "\n".join(lines)


def _format_range(data: dict) -> str:
    result = data.get("result", [])
    if not result:
        return "(no series over this window)"
    lines = []
    for series in result:
        metric = dict(series.get("metric", {}))
        metric.pop("__name__", None)
        labels = ", ".join(f"{k}={v}" for k, v in sorted(metric.items())) or "(no labels)"
        values = series.get("values", [])
        if not values:
            continue
        first = values[0][1]
        last = values[-1][1]
        peak = max(float(v[1]) for v in values)
        lines.append(f"  {{{labels}}}: first={first} last={last} peak={peak:g} ({len(values)} points)")
    return "\n".join(lines)


@tool
def query_prometheus(promql: str) -> str:
    """Run an instant PromQL query and return the current value of each series.

    Use this for point-in-time questions: current rate, current count, current
    value of a gauge. Wrap counters in rate()/increase() for meaningful numbers,
    e.g. `rate(backend_rate_limit_violations_total[1m])`.
    """
    try:
        data = prometheus.instant_query(promql)
    except prometheus.PrometheusError as exc:
        return f"ERROR: {exc}"
    return f"query: {promql}\n{_format_instant(data)}"


@tool
def query_prometheus_range(promql: str, minutes: int = 15, step: str = "30s") -> str:
    """Run a range PromQL query over the last `minutes` minutes to see a trend.

    Returns first/last/peak per series. Use this to tell a sustained problem
    from a one-off blip, or to see whether a counter is still climbing.
    """
    try:
        data = prometheus.range_query(promql, minutes=minutes, step=step)
    except prometheus.PrometheusError as exc:
        return f"ERROR: {exc}"
    return f"query: {promql} (last {minutes}m, step {step})\n{_format_range(data)}"


@tool
def list_metric_names() -> str:
    """List every metric name Prometheus currently knows about.

    Use this once at the start if you are unsure which metrics exist.
    """
    try:
        names = prometheus.metric_names()
    except prometheus.PrometheusError as exc:
        return f"ERROR: {exc}"
    relevant = [n for n in names if n.startswith(("backend_", "container_", "kafka_"))]
    return "Lab metrics:\n" + "\n".join(f"  {n}" for n in sorted(relevant))


TOOLS = [query_prometheus, query_prometheus_range, list_metric_names]
