# TASK-117 - 10 Execution Start

## Status
- Task: `TASK-117`
- Phase: `ACTIVE / EXECUTION`
- Responsible: `CODEX / Cursor Executor`
- Started: `2026-05-23 17:03:53 -0400`
- Reason: `User override explicit end-to-end execution authorization`

## User Override
The user explicitly authorized TASK-117 to move from `ACTIVE / PLANNING` to `ACTIVE / EXECUTION` and requested end-to-end execution.

TASK-116 remains `ACTIVE / REVIEW`, not `DONE`.

TASK-115 remains `BLOCKED / SUPERSEDED_BY_TASK-116`.

## P0 HEAD / GitHub / Local Consistency

Result: `PASS`.

| Source | Value |
|---|---|
| `git status --short` | `M docs/MASTER-PLAN.md`; untracked `docs/TASKS/TASK-117-ios-sync-final-architecture-cleanup.md`; untracked `docs/TASKS/EVIDENCE/TASK-117/` |
| Dirty classification | `DOCUMENTAL_TASK117_APPROVED_BASELINE`; no runtime Swift/Kotlin/SQL dirty files |
| `git branch --show-current` | `main` |
| `git rev-parse HEAD` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| `git rev-parse origin/main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| `git ls-remote origin main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| `git ls-remote https://github.com/XNIW/iOSMerchandiseControl.git main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| GitHub API `commits/main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| GitHub rendered `commits/main` | latest rendered embedded data `e14b433613ab59beb5a9796a00f285b4d8a15e5b`, short `e14b433`, message `Task 116 D` |

## Required File Comparison

Each required file was checked with:
- `git show HEAD:<path>` SHA-256
- `https://raw.githubusercontent.com/XNIW/iOSMerchandiseControl/main/<path>` SHA-256
- `https://github.com/XNIW/iOSMerchandiseControl/blob/main/<path>` rendered status

All files matched `HEAD == raw` and each rendered page returned HTTP `200`.

| File | HEAD/raw | Rendered |
|---|---:|---:|
| `iOSMerchandiseControl/ContentView.swift` | PASS | 200 |
| `iOSMerchandiseControl/OptionsView.swift` | PASS | 200 |
| `iOSMerchandiseControl/Sync/SyncOrchestrator.swift` | PASS | 200 |
| `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift` | PASS | 200 |
| `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift` | PASS | 200 |
| `iOSMerchandiseControl/Sync/SupabaseManualSyncCompatibilityAdapter.swift` | PASS | 200 |
| `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift` | PASS | 200 |
| `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift` | PASS | 200 |
| `iOSMerchandiseControl/SupabaseSyncEventIncrementalApplyService.swift` | PASS | 200 |

## Objective Understood
Remove real automatic-runtime coupling from `SupabaseManualSync*` and make normal automatic sync owned by `SyncOrchestrator` plus domain services under `iOSMerchandiseControl/Sync`.

## Initial Minimal Plan
1. Promote tracking to `ACTIVE / EXECUTION`.
2. Run baseline harness commands.
3. Audit the real call graph before runtime edits.
4. Implement only the minimum slices required to remove automatic-path legacy coupling.
5. Verify with strict source/call-graph gates, Debug/Release builds, iOS sync tests, smoke/live gates where available, and final CA matrix.

## Initial Runtime Files To Audit Before Editing
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift`
- `iOSMerchandiseControl/Sync/*`
- manual sync boundary files
- incremental apply/outbox files
- `tools/agent/*`
- `iOSMerchandiseControlTests/*`

No runtime code was modified before this evidence.
