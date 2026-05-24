#!/usr/bin/env python3
"""TASK-119-specific scanner entrypoint.

This wrapper keeps TASK-119 task semantics out of historical TASK-117/TASK-118
scan modules while reusing the shared sync architecture scan implementation.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


LIB_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(LIB_DIR))

import sync_architecture_scans  # noqa: E402


def main(argv: list[str]) -> int:
    if os.environ.get("TASK_ID") not in {None, "", "TASK-119"}:
        os.environ["TASK_ID"] = os.environ["TASK_ID"]
    return sync_architecture_scans.main(argv)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
