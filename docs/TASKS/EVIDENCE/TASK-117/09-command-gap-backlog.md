# 09 - Command Gap Backlog

Every command below must emit Markdown + JSON, `RESULT`, `EXIT_CODE`, `REPORT_MD`, `REPORT_JSON`, `NEXT_ACTION`, reliable exit codes, redaction, quiet output and TASK117-scoped safety gates.

## `scan automatic-contracts-clean --task TASK-117`
- **Why**: prove automatic runtime/provider contracts expose no manual DTO/protocol/result.
- **Files**: `Sync/SyncAutomaticRuntime.swift`, `Sync/SyncAutomaticRuntimeProviders.swift`, provider/adapters under `Sync`.
- **Inputs**: `--task TASK-117`.
- **Output**: `docs/TASKS/EVIDENCE/TASK-117/agent-runs/*automatic-contracts-clean*.md/.json`.
- **Exit codes**: 0 PASS, 1 FAIL, 3 MISCONFIGURED.
- **Redaction**: paths normalized, no personal paths.
- **Safety**: read-only source scan.
- **One-line**: `./tools/agent/mc-agent.sh scan automatic-contracts-clean --task TASK-117`.
- **Fail if**: automatic contracts expose `SupabaseManualSync*`, `ManualPushPlan`, `SupabaseManualPushResult`, `ProductPriceManualPushResult`, `SupabaseSyncEventIncrementalApplySummary`.
- **Not PASS**: renamed files that still expose legacy shapes.

## `scan root-host-clean --task TASK-117`
- **Why**: prove `ContentView` no longer constructs manual root host/factory/adapter/VM.
- **Files**: `ContentView.swift`.
- **Inputs**: `--task TASK-117`.
- **Output**: MD/JSON report under TASK-117 agent-runs.
- **Exit codes**: 0 PASS, 1 FAIL, 3 MISCONFIGURED.
- **Redaction**: paths normalized.
- **Safety**: read-only source scan.
- **One-line**: `./tools/agent/mc-agent.sh scan root-host-clean --task TASK-117`.
- **Fail if**: `SupabaseManualSyncForegroundRootHost`, `SupabaseManualSyncCompatibilityAdapter`, `SupabaseManualSyncReleaseFactory`, `SupabaseManualSyncViewModel` appear in `ContentView.swift`.
- **Not PASS**: comments suppressing tokens without real call graph removal.

## `scan options-observer-only --task TASK-117`
- **Why**: prove Options observes cached presenter/provider state only.
- **Files**: `OptionsView.swift`, `Sync/Presentation/*`.
- **Inputs**: `--task TASK-117`.
- **Output**: MD/JSON report.
- **Exit codes**: 0 PASS, 1 FAIL, 3 MISCONFIGURED.
- **Redaction**: no raw account details.
- **Safety**: read-only source scan.
- **One-line**: `./tools/agent/mc-agent.sh scan options-observer-only --task TASK-117`.
- **Fail if**: Options starts foreground/realtime/reconnect, performs decision-heavy remote fetch, creates manual VM for automatic status, or shows duplicate public sync CTA.
- **Not PASS**: provider exists but view still decides sync.

## `scan duplicate-sync-owner --task TASK-117`
- **Why**: prove there is only one safety loop/reconnect/realtime/local mutation owner.
- **Files**: `Sync/SyncOrchestrator.swift`, `ContentView.swift`, realtime watcher, reconnect scheduler.
- **Inputs**: `--task TASK-117`.
- **Output**: MD/JSON report.
- **Exit codes**: 0 PASS, 1 FAIL, 3 MISCONFIGURED.
- **Redaction**: paths normalized.
- **Safety**: read-only source/call-graph scan.
- **One-line**: `./tools/agent/mc-agent.sh scan duplicate-sync-owner --task TASK-117`.
- **Fail if**: two timers/watchers/safety loops can call sync concurrently or manual VM remains an automatic owner.
- **Not PASS**: scan that counts only type names and ignores trigger call graph.

## `scan incremental-apply-contract --task TASK-117`
- **Why**: prove incremental pull owns fetch/dispatch/watermark and wrappers are not automatic path owners.
- **Files**: `Sync/Incremental/*`, `SupabaseSyncEventIncrementalApplyService.swift`.
- **Inputs**: `--task TASK-117`.
- **Output**: MD/JSON report.
- **Exit codes**: 0 PASS, 1 FAIL, 3 MISCONFIGURED.
- **Redaction**: no payload/entity raw details.
- **Safety**: read-only source scan.
- **One-line**: `./tools/agent/mc-agent.sh scan incremental-apply-contract --task TASK-117`.
- **Fail if**: automatic path uses legacy wrapper, watermark advances before domain success, or apply services are DTO-only.
- **Not PASS**: physical files exist but are not dispatched/tested.

## `scan swiftdata-mainactor-heavy --task TASK-117`
- **Why**: catch MainActor-heavy apply/recovery loops.
- **Files**: `Sync/*`, apply services, pull/full recovery helpers.
- **Inputs**: `--task TASK-117`.
- **Output**: MD/JSON report.
- **Exit codes**: 0 PASS, 1 FAIL, 3 MISCONFIGURED.
- **Redaction**: paths normalized.
- **Safety**: read-only source scan.
- **One-line**: `./tools/agent/mc-agent.sh scan swiftdata-mainactor-heavy --task TASK-117`.
- **Fail if**: large fetch/apply/save loops run on `@MainActor` or UI `ModelContext`.
- **Not PASS**: unverified comments claiming background context.

## `scan l10n-sync-keys --task TASK-117`
- **Why**: ensure new sync/banner/status copy exists in IT/EN/ES/ZH.
- **Files**: localization files, Options/root banner strings.
- **Inputs**: `--task TASK-117`.
- **Output**: MD/JSON report.
- **Exit codes**: 0 PASS, 1 FAIL, 3 MISCONFIGURED.
- **Redaction**: no secrets expected.
- **Safety**: read-only source scan.
- **One-line**: `./tools/agent/mc-agent.sh scan l10n-sync-keys --task TASK-117`.
- **Fail if**: missing keys, duplicate keys, or untranslated critical sync states.
- **Not PASS**: only one language updated.

## `harness doctor --task TASK-117`
- **Why**: validate harness TASK-117 awareness and output contract.
- **Files**: `tools/agent/*`, report schema helpers.
- **Inputs**: `--task TASK-117`.
- **Output**: MD/JSON report.
- **Exit codes**: 0 PASS, 1 FAIL, 2 BLOCKED, 3 MISCONFIGURED.
- **Redaction**: full redaction check.
- **Safety**: read-only.
- **One-line**: `./tools/agent/mc-agent.sh harness doctor --task TASK-117`.
- **Fail if**: commands omit required fields, use wrong exit codes, or are not TASK-117 aware.
- **Not PASS**: generic doctor that ignores TASK-117 command gaps.

## `evidence bundle --task TASK-117`
- **Why**: produce a deterministic evidence index for planning/review.
- **Files**: `docs/TASKS/EVIDENCE/TASK-117/*`, agent-runs.
- **Inputs**: `--task TASK-117`.
- **Output**: bundle MD/JSON.
- **Exit codes**: 0 PASS, 1 FAIL, 3 MISCONFIGURED.
- **Redaction**: run sensitive/evidence scans before PASS.
- **Safety**: read-only.
- **One-line**: `./tools/agent/mc-agent.sh evidence bundle --task TASK-117`.
- **Fail if**: required evidence files missing or raw noisy logs included.
- **Not PASS**: missing NEXT_ACTION or missing JSON companion.

## `sync doctor --task TASK-117`
- **Why**: summarize architecture gate readiness without running live mutation.
- **Files**: source scans, previous reports, task evidence.
- **Inputs**: `--task TASK-117`.
- **Output**: MD/JSON readiness report.
- **Exit codes**: 0 PASS, 1 FAIL, 2 BLOCKED, 3 MISCONFIGURED.
- **Redaction**: no raw account/device/project refs.
- **Safety**: read-only unless explicit live command is invoked separately.
- **One-line**: `./tools/agent/mc-agent.sh sync doctor --task TASK-117`.
- **Fail if**: strict scans missing/failing or reports stale.
- **Not PASS**: critical live/device gates marked `NOT_RUN`.
