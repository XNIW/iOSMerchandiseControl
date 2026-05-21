# mc-agent MCP adapter

Thin MCP wrapper over `../mc-agent.sh`.

## Setup

```bash
cd tools/agent/mcp
npm install
npm test
npm start
```

`node_modules/` is local-only and ignored by git.

## Safety

- No arbitrary shell command tool.
- Tool allowlist only.
- Uses `spawn` with argv arrays.
- Fixed cwd: iOS repo.
- Timeout via `MC_MCP_TIMEOUT_MS` (default 120000 ms).
- Does not set or override `MC_ALLOW_LIVE` / `MC_ALLOW_CLEANUP`.
- Prefix args must match safe `TASKNNN_*` syntax.

## Tools

- `mc_preflight`
- `mc_report`
- `mc_report_task114`
- `mc_ios_build_debug`
- `mc_ios_build_release`
- `mc_ios_test_sync`
- `mc_android_build_debug`
- `mc_android_build_release`
- `mc_android_test_sync`
- `mc_android_test_offline`
- `mc_sync_counts_supabase_task114`
- `mc_sync_counts_android_task114`
- `mc_sync_counts_ios_task114`
- `mc_supabase_status_redacted`
- `mc_supabase_residue_check`
- `mc_live_reconcile_counts_task114`
- `mc_live_sync_matrix`
- `mc_live_sync_matrix_task114`
- `mc_live_offline_matrix`

Run `../mc-agent.sh help-json` for the canonical CLI contract.
