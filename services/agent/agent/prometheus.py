"""Thin wrapper over the Prometheus HTTP query API."""

from __future__ import annotations

import time
from typing import Any

import httpx

from . import config


class PrometheusError(RuntimeError):
    """Raised when Prometheus returns an error or is unreachable."""


def _get(path: str, params: dict[str, Any]) -> dict[str, Any]:
    url = f"{config.PROMETHEUS_URL}{path}"
    try:
        resp = httpx.get(url, params=params, timeout=15.0)
    except httpx.HTTPError as exc:  # network-level failure
        raise PrometheusError(f"could not reach Prometheus at {url}: {exc}") from exc

    if resp.status_code != 200:
        raise PrometheusError(
            f"Prometheus returned HTTP {resp.status_code}: {resp.text[:200]}"
        )

    body = resp.json()
    if body.get("status") != "success":
        raise PrometheusError(f"Prometheus query error: {body.get('error', body)}")
    return body["data"]


def instant_query(promql: str) -> dict[str, Any]:
    """Run an instant query, returning the raw `data` object."""
    return _get("/api/v1/query", {"query": promql})


def range_query(promql: str, minutes: int, step: str) -> dict[str, Any]:
    """Run a range query over the last `minutes` minutes at the given step."""
    end = time.time()
    start = end - minutes * 60
    return _get(
        "/api/v1/query_range",
        {"query": promql, "start": start, "end": end, "step": step},
    )


def metric_names() -> list[str]:
    """Return every metric name Prometheus currently knows about."""
    return _get("/api/v1/label/__name__/values", {})
