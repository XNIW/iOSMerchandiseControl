# TASK-117 Planning Summary

## Status
- **Task**: TASK-117
- **Phase**: ACTIVE / PLANNING
- **Readiness**: NOT_READY_FOR_EXECUTION
- **Current handoff**: TASK-117 ACTIVE / PLANNING, not READY_FOR_EXECUTION until planning review.

## Objective
Plan the final iOS sync architecture cleanup so normal automatic sync is owned by `SyncOrchestrator` and real domain services under `iOSMerchandiseControl/Sync`, without relying on `SupabaseManualSyncViewModel`, `SupabaseManualSyncCompatibilityAdapter`, `SupabaseManualSyncReleaseFactory`, or `SupabaseManualSync*` types in the automatic path.

## Evidence produced
- P0 HEAD/raw/rendered consistency audit: `HEAD_CONSISTENCY_PASS`.
- Call graph inventory for `ContentView`, `OptionsView`, `SyncOrchestrator`, automatic runtime, incremental pull/apply and outbox path.
- Legacy file classification with unresolved domain/wrapper candidates marked `UNKNOWN_REQUIRES_AUDIT`.
- Target architecture contract and strict source/call-graph scan rules.
- Risk/regression matrix covering app UX, sync behavior, localization, device/live gates and operator UX.
- Future execution slices S117-A...S117-O.
- No-delete-before-test policy.
- Automation harness plan and command-gap backlog.

## Explicit non-actions
- No Swift/Kotlin/SQL runtime files changed.
- No build, test, simulator, runtime, live Supabase, cleanup or migration executed.
- No TASK-116 DONE claim.
- No TASK-117 READY_FOR_EXECUTION or DONE claim.

## Tracking constraints
- MASTER-PLAN must show TASK-117 as `ACTIVE / PLANNING`.
- TASK-116 remains `ACTIVE / REVIEW`, not DONE.
- TASK-115 remains `BLOCKED / SUPERSEDED_BY_TASK-116`.
