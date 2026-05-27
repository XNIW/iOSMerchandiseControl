# TASK-127 Phase -1 — MCP Allowlist Gap Analysis

- RESULT: PASS_WITH_NOTES
- EXIT_CODE: 0
- REPORT_MD: `docs/TASKS/EVIDENCE/TASK-127/-1-02-mcp-allowlist-gap-analysis.md`
- REPORT_JSON: `docs/TASKS/EVIDENCE/TASK-127/-1-02-mcp-allowlist-gap-analysis.json`
- NEXT_ACTION: Add MCP allowlist entries only after CLI commands exist and remain thin wrappers over `mc-agent`.

## Finding

The MCP adapter is documented as a thin wrapper over `mc-agent`; TASK-127 commands are not yet in the CLI catalog, so allowlist entries would be premature before Phase 0 harness creation.

Required future MCP behavior:

- no shell-freeform execution;
- argv-array spawn only;
- fixed iOS repo cwd;
- no mutation of `MC_ALLOW_LIVE` / `MC_ALLOW_CLEANUP`;
- allowlist only useful TASK-127 commands;
- self-test evidence after allowlist update.
