#!/usr/bin/env python3
"""TASK-119-specific scanner entrypoint.

This wrapper keeps TASK-119 task semantics out of historical TASK-117/TASK-118
scan modules while reusing the shared sync architecture scan implementation.
"""

from __future__ import annotations

import os
import sys
import json
from pathlib import Path


LIB_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(LIB_DIR))

import sync_architecture_scans  # noqa: E402


def main(argv: list[str]) -> int:
    task_id = os.environ.get("TASK_ID", "TASK-119")
    if task_id not in {"", "TASK-119"}:
        print(json.dumps({
            "schema_version": "1.1",
            "schemaVersion": "1.1",
            "task_id": task_id,
            "taskId": task_id,
            "source": "scan.task119",
            "scan": argv[1] if len(argv) > 1 else "unknown",
            "result_status": "MISCONFIGURED",
            "status": "MISCONFIGURED",
            "summary": "TASK-119 scanner invoked for a non-TASK-119 task id.",
            "safety_level": "read_only_static_scan",
            "checks": [{
                "id": "task119_task_id_guard",
                "status": "MISCONFIGURED",
                "reason": "TASK-119 scanner entrypoint only accepts TASK-119.",
            }],
            "NEXT_ACTION": "Use a task-specific scanner for this task id.",
        }, indent=2, sort_keys=True))
        return 3
    return sync_architecture_scans.main(argv)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
