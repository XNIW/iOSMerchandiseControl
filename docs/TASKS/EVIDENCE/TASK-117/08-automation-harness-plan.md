# 08 - Automation / Harness Plan

## Canonical harness
`./tools/agent/mc-agent.sh` is the canonical CLI for future TASK-117 execution gates.

MCP is only a thin adapter over the CLI contract. Future agents must not rebuild long manual shell commands when a harness command exists.

## Command contract
Every new or improved command must:
- print `RESULT`;
- print `EXIT_CODE`;
- print `REPORT_MD`;
- print `REPORT_JSON`;
- print `NEXT_ACTION`;
- produce Markdown and JSON schema-compatible reports;
- use quiet output by default;
- redact token, password, JWT, email, project ref, device id, personal paths and sensitive query fragments;
- avoid committing noisy raw logs;
- enforce live/cleanup safety gates;
- use task-scoped `TASK117_*` prefixes.

Exit codes:
- `0`: PASS
- `1`: FAIL
- `2`: BLOCKED
- `3`: MISCONFIGURED
- `4`: UNSAFE_OPERATION_REFUSED

## Existing commands to reuse in execution
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

## Live/device/Supabase commands to plan, not run in planning
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

## Commands to create or improve before gate use
See `09-command-gap-backlog.md` for command-specific design:
- `scan automatic-contracts-clean`
- `scan root-host-clean`
- `scan options-observer-only`
- `scan duplicate-sync-owner`
- `scan incremental-apply-contract`
- `scan swiftdata-mainactor-heavy`
- `scan l10n-sync-keys`
- `harness doctor --task TASK-117`
- `evidence bundle --task TASK-117`
- `sync doctor --task TASK-117`
