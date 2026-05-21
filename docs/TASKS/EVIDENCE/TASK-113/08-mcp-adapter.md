# MCP Adapter

Status: PASS.

Files:
- `tools/agent/mcp/server.mjs`
- `tools/agent/mcp/test-wrapper.mjs`
- `tools/agent/mcp/package.json`
- `tools/agent/mcp/package-lock.json`
- `tools/agent/mcp/README.md`

Properties verified:
- Thin wrapper over `mc-agent.sh`.
- Allowlist only; no arbitrary shell command.
- Uses `spawn` with argv arrays.
- Fixed cwd.
- Timeout via `MC_MCP_TIMEOUT_MS`.
- Does not modify `MC_ALLOW_LIVE` or `MC_ALLOW_CLEANUP`.
- Prefix injection attempt refused.
- `node_modules/` removed and ignored.

Evidence:
- `node tools/agent/mcp/server.mjs --self-test`: PASS.
- `node tools/agent/mcp/test-wrapper.mjs`: PASS.

Professional review update — 2026-05-21:
- PASS: `npm test` in `tools/agent/mcp` passed with package version aligned to `0.2.0-task113`.
- PASS: self-test covers required allowlist entries, injection prefix refusal and timeout smoke.
- PASS: code review confirms unknown tools are rejected by the `CallToolRequestSchema` handler and no arbitrary shell command is exposed.
- PASS: MCP live tools do not set `MC_ALLOW_LIVE`; CLI live gate remains authoritative.
