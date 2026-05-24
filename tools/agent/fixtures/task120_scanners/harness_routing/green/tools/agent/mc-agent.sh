#!/usr/bin/env bash
cat <<'JSON'
{
  "schema_version": "1.1",
  "commands": [
    {"argv": ["git", "head-consistency", "--task"]},
    {"argv": ["preflight", "--require-head-consistency", "--task"]},
    {"argv": ["config", "validate"]},
    {"argv": ["help-json"]},
    {"argv": ["list", "commands-json"]},
    {"argv": ["scan", "task-docs", "--task"]},
    {"argv": ["scan", "harness-routing", "--task"]},
    {"argv": ["scan", "harness-health", "--task"]},
    {"argv": ["scan", "source-format", "--task"]},
    {"argv": ["scan", "duplicate-symbols", "--task"]},
    {"argv": ["scan", "automatic-legacy-monolith", "--task"]},
    {"argv": ["scan", "mainactor-boundary", "--task"]},
    {"argv": ["scan", "swiftdata-context-boundary", "--task"]},
    {"argv": ["scan", "manual-root-residue", "--task"]},
    {"argv": ["scan", "master-plan-consistency", "--task"]},
    {"argv": ["scan", "mcp-wrapper", "--task"]},
    {"argv": ["scan", "scanner-self-tests", "--task"]},
    {"argv": ["scan", "status-taxonomy", "--task"]},
    {"argv": ["scan", "evidence-metadata", "--task"]},
    {"argv": ["scan", "sync-architecture", "--task"]},
    {"argv": ["scan", "manual-boundary", "--task"]},
    {"argv": ["scan", "dead-code", "--task"]},
    {"argv": ["scan", "xcode-membership", "--task"]},
    {"argv": ["ios", "build", "debug"]},
    {"argv": ["ios", "build", "release"]},
    {"argv": ["ios", "test", "automatic-architecture", "--task"]},
    {"argv": ["ios", "test", "automatic-domain", "--task"]},
    {"argv": ["ios", "test", "sync"]},
    {"argv": ["ios", "smoke", "options"]},
    {"argv": ["supabase", "status-redacted"]},
    {"argv": ["supabase", "contract", "sync-schema", "--task", "--read-only"]},
    {"argv": ["scan", "sensitive"]},
    {"argv": ["scan", "evidence", "--task"]},
    {"argv": ["report", "validate-json", "--task", "--path"]}
  ],
  "exit_codes": {
    "0": "PASS",
    "1": "FAIL",
    "2": "BLOCKED_EXTERNAL",
    "3": "MISCONFIGURED",
    "4": "UNSAFE_OPERATION_REFUSED"
  }
}
JSON
# task-docs harness-routing harness-health source-format duplicate-symbols automatic-legacy-monolith
# mainactor-boundary swiftdata-context-boundary manual-root-residue master-plan-consistency
# mcp-wrapper scanner-self-tests status-taxonomy evidence-metadata
