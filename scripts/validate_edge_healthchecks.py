#!/usr/bin/env python3
"""Validate edge healthcheck completeness for regression control.

This check enforces an explicit healthcheck policy used by infra-management tooling:
- each edge must declare a healthcheck block
- healthcheck must have type and interval
- edges carrying HTTP protocol should define conditions
"""

import argparse
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml


def _as_text_list(value: Any) -> Optional[List[str]]:
    if value is None:
        return None
    if not isinstance(value, list):
        return None
    strings: List[str] = []
    for item in value:
        if isinstance(item, str):
            strings.append(item)
    return strings


def validate_edge_healthchecks(edges: List[Dict[str, Any]]) -> List[str]:
    """Return validation error messages."""
    errors: List[str] = []
    allowed_healthcheck_types = {"http", "https", "tcp", "query"}

    for edge in edges:
        edge_id = edge.get("id", "<unknown>")
        healthcheck = edge.get("healthcheck")

        if not isinstance(healthcheck, dict):
            errors.append(f"{edge_id}: missing healthcheck block")
            continue

        healthcheck_type_value = healthcheck.get("type")
        if not healthcheck_type_value:
            errors.append(f"{edge_id}: healthcheck missing type")
            continue

        if not healthcheck.get("interval"):
            errors.append(f"{edge_id}: healthcheck missing interval")
        healthcheck_type = str(healthcheck_type_value).lower()
        if healthcheck_type not in allowed_healthcheck_types:
            errors.append(f"{edge_id}: healthcheck.type must be one of {sorted(allowed_healthcheck_types)}")

        if healthcheck_type in {"http", "https"}:
            conditions = _as_text_list(healthcheck.get("conditions"))
            if not conditions:
                errors.append(f"{edge_id}: healthcheck.conditions required for http/https healthcheck type")

    return errors


def load_edges(path: Path) -> List[Dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(f"edges file not found: {path}")
    data = yaml.safe_load(path.read_text()) or {}
    edges = data.get("edges", [])
    if not isinstance(edges, list):
        raise ValueError(f"edges file invalid: expected list at {path}")
    return edges


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate explicit edge healthchecks")
    parser.add_argument("edges_file", type=Path, help="Path to network/main-dev/edges/edges.yml")
    args = parser.parse_args()

    edges = load_edges(args.edges_file)
    errors = validate_edge_healthchecks(edges)
    if errors:
        print("Edge healthcheck validation failed:")
        for error in errors:
            print(f"  - {error}")
        raise SystemExit(1)

    print(f"Validated {len(edges)} edges in {args.edges_file}")


if __name__ == "__main__":
    main()
