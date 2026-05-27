# TASK-127 Evidence 05 - MCP TASK-127 Plan

Date: 2026-05-27

MCP remains a thin allowlisted wrapper over `mc-agent.sh`. No free shell command and no `MC_ALLOW_LIVE` / `MC_ALLOW_CLEANUP` mutation was introduced.

Added TASK-127 allowlisted wrappers for preflight, scanners, iOS tests/smoke, Android audit, and report validation.

Validation:

- `node --check tools/agent/mcp/server.mjs`: PASS
- `node tools/agent/mcp/server.mjs --self-test`: PASS

