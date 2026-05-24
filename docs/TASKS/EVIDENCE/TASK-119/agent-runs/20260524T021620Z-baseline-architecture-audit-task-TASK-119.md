# TASK-119 Baseline Architecture Audit

- **Task**: TASK-119
- **Command**: manual baseline architecture audit from read-only scanner outputs
- **Result**: PASS_WITH_NOTES
- **Safety**: read-only static audit; no Swift production refactor, no build broad suite, no live, no cleanup
- **Git SHA**: 3bcb58f
- **Dirty**: dirty

## Before Architecture Map

Current automatic path observed in iOS:

1. `ContentView` creates `AppSyncRootHost`, manual sheet state, `HistorySessionSyncService`, and root presentation.
2. `AppSyncRootHost` builds `SyncAutomaticRuntime` through `SyncAutomaticRuntimeFactory.make(...)` and owns `SyncOrchestrator`.
3. `SyncOrchestrator` is `@MainActor`, observes scene/auth/realtime/outbox signals, decides action, and calls the automatic runtime.
4. `SyncAutomaticRuntime` is also `@MainActor`, owns `activeTask`, decision input, push, pull, activity registration, recovery, and state-store updates.
5. `AutomaticPushServices.swift` currently groups catalog push, product-price push, outbox writing, history-session push, and activity registration.
6. `SupabaseInventoryService` is a mixed remote actor with automatic contracts plus manual/task legacy payloads and methods.
7. Options/root presentation reads sync state and summary providers, but remains coupled to UI-level orchestration.

## Initial Scan Matrix

| Gate | Result | Evidence |
| --- | --- | --- |
| `scan sync-architecture --task TASK-119 --strict` | FAIL | `20260524T021325Z-scan-sync-architecture-task-TASK-119-strict-p45340.{md,json,log}` |
| `scan manual-boundary --task TASK-119 --strict` | FAIL | `20260524T021325Z-scan-manual-boundary-task-TASK-119-strict-p45343.{md,json,log}` |
| `scan dead-code --task TASK-119 --strict` | PASS | `20260524T021325Z-scan-dead-code-task-TASK-119-strict-p45341.{md,json,log}` |
| `scan xcode-membership --task TASK-119 --strict` | PASS | `20260524T021412Z-scan-xcode-membership-task-TASK-119-strict-p47330.{md,json,log}` |
| `ios test automatic-architecture --task TASK-119` | PASS | `20260524T021419Z-ios-test-automatic-architecture-task-TASK-119-p47812.{md,json,log}` |
| `report validate-json --task TASK-119 --path docs/TASKS/EVIDENCE/TASK-119/agent-runs` | PASS | `20260524T021532Z-report-validate-json-task-TASK-119-path-docs-TASKS-EVIDENCE-TASK-119-agent-runs-p49310.{md,json,log}` |

## Observed God Files

| File | Lines | Baseline note |
| --- | ---: | --- |
| `iOSMerchandiseControl/Sync/AutomaticPushServices.swift` | 986 | Multiple domains in one file; split required or reviewer-approved justification. |
| `iOSMerchandiseControl/SupabaseInventoryService.swift` | 1861 | Mixed remote contracts and manual/task legacy helpers; split/isolation risk. |
| `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift` | 6550 | Manual boundary file is very large; not automatic runtime work unless manual regression risk requires it. |
| `iOSMerchandiseControl/HistorySessionSyncService.swift` | 680 | Used by root/manual-adjacent and automatic history push; keep as shared/unknown until reference scan proves safe split. |

## Boundary Findings

- Automatic core files did not show direct manual-only symbol references in the new TASK-119 architecture test.
- `SupabaseInventoryService.swift` does expose manual-only payload/method names, including `SupabaseManualPush*` and product-price manual push contracts, so remote contract isolation remains a TASK-119 risk.
- `SyncDecisionEngine` still models `.manual`, `.bootstrap`, and `.fullRecovery`; normal automatic-path guards must remain explicit.
- `SyncAutomaticRuntime.swift` and `SyncOrchestrator.swift` are `@MainActor`, so non-UI work still needs engine/facade separation.
- `AutomaticPushServices.swift` uses fresh `ModelContext(modelContainer)` in several services, but the runtime/provider layer still needs sharper ownership checks.

## Dead-Code Candidate Baseline

The read-only dead-code scan produced 27 candidate rows. No deletion was performed. Future deletion requires reference count, Xcode membership, build/test evidence, and review acceptance.

## Regression Risks

- Manual sync remains supported and has large existing files/tests; isolating it can regress explicit manual flows.
- Supabase contract validation is read-only; no schema/migration/RLS/grant/RPC change is allowed in TASK-119.
- The local TASK-119 tracking files are absent from origin/GitHub rendered main, so production Swift refactor remains blocked until the mismatch is explicitly accepted or reconciled.

## NEXT_ACTION

Do not start large Swift refactor while TASK-119 tracking remains local-only versus origin/GitHub. Next safe action is either explicit local-only approval/riallineamento, or continued read-only audit/harness work.
