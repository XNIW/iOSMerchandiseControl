# 07 - No Delete Before Test Policy

## Rule
No source file is deleted, moved out of target membership, or renamed in TASK-117 execution until replacement behavior is covered by source scans, build/test gates and regression evidence.

## Required order
1. Prove current call graph and classify file role.
2. Add or harden source/call-graph scan.
3. Add regression test or harness gate for behavior being preserved.
4. Replace automatic path references with clean domain/manual boundary.
5. Run strict scans.
6. Run Debug/Release build and iOS sync tests.
7. Remove or relocate classified legacy file.
8. Rerun strict scans/build/tests.
9. Record evidence and rollback path.

## Files explicitly protected from premature delete
- `SupabaseManualSyncViewModel.swift`
- `SupabaseManualSyncReleaseFactory.swift`
- `SupabaseSyncEventIncrementalApplyService.swift`
- `SupabasePullApplyService.swift`
- `SupabaseProductPriceApplyService.swift`
- `HistorySessionSyncService.swift`
- root-level `SyncEventOutbox*`
- root-level `SyncEventRecording*`

## Deletion is forbidden when
- the file is `UNKNOWN_REQUIRES_AUDIT`;
- manual sync explicit UI still depends on it;
- release target still references it;
- a strict scan is missing;
- build/test gate is `NOT_RUN`, `FAIL` or `PASS_WITH_NOTES`;
- rollback path is not documented.
