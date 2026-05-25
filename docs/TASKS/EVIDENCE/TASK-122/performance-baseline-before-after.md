# TASK-122 Performance Baseline Before/After

- Current broad sync test duration: `158738` ms.
- Latest sync test report: `docs/TASKS/EVIDENCE/TASK-122/agent-runs/20260525T005619Z-ios-test-sync-task-TASK-122-p4660.json`.
- ProductPrice keyset paging static evidence: `True`.
- ProductPrice page limit clamp <=1000: `True`.
- ProductPrice chunk/range paging evidence: `True`.
- Automatic MainActor heavy-work hits: `1`.
- Automatic Task.sleep hits: `2`.
- Automatic unbounded Task.sleep loop: `False`.
- Manual/dry-run contaminates Automatic: `False`.

Before baseline: `NOT_RUN`; no comparable pre-TASK-122 harness measurement is available.
Verdict: `PASS_WITH_NOTES`; architecture/runtime invariants are evidence-backed, but no performance improvement claim is authorized.
