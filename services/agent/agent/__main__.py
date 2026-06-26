"""CLI entrypoint: `python -m agent [question]`."""

import argparse
import sys

from . import config
from .diagnose import DEFAULT_QUESTION, diagnose


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="agent",
        description="Diagnose the active Cloud Incident Lab fault via Prometheus.",
    )
    parser.add_argument(
        "question",
        nargs="?",
        default=DEFAULT_QUESTION,
        help="What to ask the agent (defaults to a general 'what fault is active?').",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress the live step-by-step trace; print only the final answer.",
    )
    args = parser.parse_args()

    print(f"model={config.MODEL}  prometheus={config.PROMETHEUS_URL}\n")
    try:
        answer = diagnose(args.question, stream=not args.quiet)
    except Exception as exc:  # noqa: BLE001 — surface any failure to the operator
        print(f"\nagent failed: {exc}", file=sys.stderr)
        return 1

    if args.quiet:
        print(answer)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
