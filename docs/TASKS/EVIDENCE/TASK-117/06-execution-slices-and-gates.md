# 06 - Execution Slices and Gates

Execution is not authorized by this planning task. These slices define future work only.

| Slice | Purpose | Required gates |
|---|---|---|
| S117-A | Planning + HEAD/raw consistency. | `HEAD_CONSISTENCY_PASS` or explicit `PLANNING-BLOCKED_HEAD_MISMATCH`. |
| S117-B | Strict call graph inventory. | Source/call graph evidence for root, Options, orchestrator, runtime, incremental and outbox paths. |
| S117-C | Define final domain contracts with zero `SupabaseManualSync*`. | `scan automatic-contracts-clean` planned/implemented. |
| S117-D | Extract clean automatic runtime providers. | No manual DTO/result types in automatic provider contracts. |
| S117-E | Replace `SyncOrchestrator` legacy adapter dependency. | `scan duplicate-sync-owner`; no `SyncOrchestratorLegacySyncAdapter`. |
| S117-F | Replace `ContentView` root host. | `scan root-host-clean`; no manual VM/factory/adapter/root host in ContentView. |
| S117-G | Options observer-only cleanup. | `scan options-observer-only`; no decision-heavy remote fetch in view path. |
| S117-H | Manual sync facade isolation/removal. | Manual path under `Sync/Manual` or `ManualSync`; explicit action only. |
| S117-I | Incremental pull/apply cleanup and wrapper deprecation. | `scan incremental-apply-contract`; idempotency/dirty/tombstone/watermark tests. |
| S117-J | Outbox push/drain final ownership. | Owner-bound outbox tests and no VM legacy push path. |
| S117-K | Remove/relocate dead legacy files. | No-delete-before-test policy satisfied. |
| S117-L | Harden harness scans and source-based regression tests. | New scans emit MD/JSON, reliable exit codes and NEXT_ACTION. |
| S117-M | Build/test/smoke/l10n/performance gates. | Debug/Release build PASS, iOS sync tests PASS, smoke/l10n/perf PASS. |
| S117-N | Live/device/account gates or external blockers. | Physical iPhone, Android live, near-realtime, offline, account matrix. |
| S117-O | Final review and DONE eligibility matrix. | No critical `NOT_RUN`/`FAIL`/`PASS_WITH_NOTES` unless user accepts external blocker. |

## Existing commands to reuse in future execution
```bash
./tools/agent/mc-agent.sh preflight --task TASK-117
./tools/agent/mc-agent.sh config validate --task TASK-117
./tools/agent/mc-agent.sh list commands-json
./tools/agent/mc-agent.sh help-json
./tools/agent/mc-agent.sh scan no-legacy-runtime-path --task TASK-117
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live no-legacy-runtime-path --task TASK-117
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live no-full-pull-normal-path --task TASK-117
./tools/agent/mc-agent.sh ios build debug --task TASK-117
./tools/agent/mc-agent.sh ios build release --task TASK-117
./tools/agent/mc-agent.sh ios test sync --task TASK-117
./tools/agent/mc-agent.sh ios smoke simulator --task TASK-117
./tools/agent/mc-agent.sh ios smoke options --task TASK-117
./tools/agent/mc-agent.sh scan sensitive --task TASK-117
./tools/agent/mc-agent.sh scan evidence --task TASK-117
./tools/agent/mc-agent.sh report --latest --task TASK-117
```

## Live/device/Supabase commands to plan, not run now
```bash
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios auth-preflight --live --task TASK-117
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios physical-auth-store-diagnostics --live --task TASK-117
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios physical-sync-acceptance --live --task TASK-117
MC_ALLOW_LIVE=1 MC_ANDROID_DEVICE_SERIAL=<serial> ./tools/agent/mc-agent.sh android auth-preflight --live --task TASK-117
MC_ALLOW_LIVE=1 MC_ANDROID_DEVICE_SERIAL=<serial> ./tools/agent/mc-agent.sh live runtime-parity --task TASK-117 --prefix TASK117_RUNTIME_
MC_ALLOW_LIVE=1 MC_ANDROID_DEVICE_SERIAL=<serial> ./tools/agent/mc-agent.sh live mutation-near-realtime --task TASK-117 --prefix TASK117_REALTIME_
MC_ALLOW_LIVE=1 MC_ANDROID_DEVICE_SERIAL=<serial> ./tools/agent/mc-agent.sh live offline-reconnect-sync --task TASK-117 --prefix TASK117_OFFLINE_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live account-merge-policy-matrix --task TASK-117 --prefix TASK117_ACCOUNT_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-performance-budget --task TASK-117 --prefix TASK117_PERF_
./tools/agent/mc-agent.sh supabase status-redacted --task TASK-117
./tools/agent/mc-agent.sh supabase verify-rls --profile linked --task TASK-117
./tools/agent/mc-agent.sh supabase verify-grants --profile linked --task TASK-117
./tools/agent/mc-agent.sh supabase cleanup --task TASK-117 --prefix TASK117_REALTIME_ --dry-run
MC_ALLOW_CLEANUP=1 ./tools/agent/mc-agent.sh supabase cleanup --task TASK-117 --prefix TASK117_REALTIME_ --execute --cleanup-plan-id <id>
./tools/agent/mc-agent.sh supabase residue-check --prefix TASK117_REALTIME_ --profile linked --task TASK-117
```
