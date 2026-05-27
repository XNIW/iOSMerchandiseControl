# TASK-127 Evidence 03 - Harness Implementation Plan

Date: 2026-05-27

Implemented before Swift runtime changes:

- Added TASK-127 top-level scan routing in `tools/agent/mc-agent.sh`.
- Added TASK-127 scanner wrapper in `tools/agent/lib/common.sh`.
- Added `tools/agent/lib/task127_scans.py` for scanner self-tests and static gates.
- Added iOS command routing for:
  - `ios test options-summary-performance --task TASK-127`
  - `ios test options-summary-provider --task TASK-127`
  - `ios smoke options-performance --task TASK-127`
- Added Android read-only audit routing for:
  - `android audit options-performance --task TASK-127`
- Added TASK-127 MCP allowlist entries as thin wrappers over `mc-agent.sh`.
- Added TASK-127 README command catalog examples.

No Swift/Kotlin/SQL app behavior was patched during this harness step.

