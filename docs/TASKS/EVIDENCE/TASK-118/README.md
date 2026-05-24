# TASK-118 Evidence

Directory evidence per TASK-118.

## Required harness evidence
- `agent-runs/*.md`
- `agent-runs/*.json`
- `agent-runs/*.log`

## Required gates
- HEAD consistency: `git head-consistency --task TASK-118` oppure `preflight --require-head-consistency --task TASK-118`
- Source scans: `scan sync-boundaries --task TASK-118 --strict`, `scan no-full-pull-normal-path --task TASK-118 --strict`
- Builds: Debug / Release
- Tests: `ios test sync`, `ios test automatic-domain`
- Smoke: Options/root banner
- Evidence hygiene: `scan evidence --task TASK-118`
- JSON validation: `report validate-json --task TASK-118 --path docs/TASKS/EVIDENCE/TASK-118/agent-runs`

## Redaction
Evidence deve redigere token, JWT, password, service key, email, project ref, path personali, device id e `config.env`. Se redaction non e' verificabile, il gate e' `FAIL` o `MISCONFIGURED`.

## Execution evidence summary - 2026-05-23
- HEAD consistency: PASS — `agent-runs/20260524T000229Z-git-head-consistency-task-TASK-118-p15990.{md,json,log}`
- Preflight require HEAD: PASS — `agent-runs/20260523T233202Z-preflight-require-head-consistency-task-TASK-118-p82634.{md,json,log}`
- Execution audit: PASS — `01-execution-audit.md`
- Baseline scans: FAIL atteso prima dello split — `agent-runs/20260523T233226Z-scan-sync-boundaries-task-TASK-118-strict-p83762.*`, `agent-runs/20260523T233226Z-scan-no-full-pull-normal-path-task-TASK-118-strict-p83787.*`
- Final scan `sync-boundaries --strict`: PASS — `agent-runs/20260524T001448Z-scan-sync-boundaries-task-TASK-118-strict-p38828.{md,json,log}`
- Final scan `no-full-pull-normal-path --strict`: PASS — `agent-runs/20260524T001448Z-scan-no-full-pull-normal-path-task-TASK-118-strict-p38874.{md,json,log}`
- Build Debug: PASS — `agent-runs/20260524T001448Z-ios-build-debug-task-TASK-118-p38829.{md,json,log}`
- Build Release: PASS — `agent-runs/20260524T001506Z-ios-build-release-task-TASK-118-p40203.{md,json,log}`
- iOS test automatic-domain: PASS — `agent-runs/20260524T001428Z-ios-test-automatic-domain-task-TASK-118-p38177.{md,json,log}`
- iOS test sync: PASS — `agent-runs/20260524T001618Z-ios-test-sync-task-TASK-118-p40975.{md,json,log}`
- Options/root smoke: PASS via XcodeBuildMCP fallback — `options-smoke-mcp.{md,json,log}` and `options-smoke-mcp-screenshot.jpg`; canonical harness `ios smoke options` BLOCKED by Accessibility/JXA — `agent-runs/20260523T235852Z-ios-smoke-options-task-TASK-118-p6951.{md,json,log}`
- Supabase status redacted: PASS — `agent-runs/20260524T000127Z-supabase-status-redacted-task-TASK-118-p11781.{md,json,log}`
- Live sync matrix: REFUSED by safety gate without `MC_ALLOW_LIVE=1` — `agent-runs/20260524T000151Z-live-sync-matrix-task-TASK-118-prefix-TASK118_FINAL_-p12577.{md,json,log}`
- Sensitive/redaction scan: PASS — `agent-runs/20260524T002051Z-scan-sensitive-task-TASK-118-p46437.{md,json,log}`
- Evidence scan: PASS — `agent-runs/20260524T002117Z-scan-evidence-task-TASK-118-p46871.{md,json,log}`
- JSON validation: PASS — `agent-runs/20260524T002125Z-report-validate-json-task-TASK-118-path-docs-TASKS-EVIDENCE-TASK-118-agent-runs-p50923.{md,json,log}`
- Diff whitespace: PASS — `git diff --check`

## Review/fix evidence summary - 2026-05-24
- HEAD consistency: PASS — `agent-runs/20260524T005749Z-git-head-consistency-task-TASK-118-p88863.{md,json,log}`
- Preflight require HEAD: PASS — `agent-runs/20260524T005749Z-preflight-require-head-consistency-task-TASK-118-p88864.{md,json,log}`
- Config validate: PASS — `agent-runs/20260524T005749Z-config-validate-task-TASK-118-p88881.{md,json,log}`
- Review finding/fix: automatic catalog/product-price services were not real remote writers before review; fixed and covered by `Task118AutomaticDomainTests`.
- Strict scan `sync-boundaries`: PASS — `agent-runs/20260524T010037Z-scan-sync-boundaries-task-TASK-118-strict-p92435.{md,json,log}`
- Strict scan `no-full-pull-normal-path`: PASS — `agent-runs/20260524T010038Z-scan-no-full-pull-normal-path-task-TASK-118-strict-p92467.{md,json,log}`
- Build Debug: PASS — `agent-runs/20260524T010042Z-ios-build-debug-task-TASK-118-p93293.{md,json,log}`
- Build Release: PASS — `agent-runs/20260524T010049Z-ios-build-release-task-TASK-118-p93881.{md,json,log}`
- iOS test automatic-domain: PASS — `agent-runs/20260524T010013Z-ios-test-automatic-domain-task-TASK-118-p91771.{md,json,log}`
- iOS test sync: PASS — `agent-runs/20260524T010200Z-ios-test-sync-task-TASK-118-p94650.{md,json,log}`
- Options/root smoke primary harness: BLOCKED — `agent-runs/20260524T010451Z-ios-smoke-options-task-TASK-118-p95638.{md,json,log}`; reason: Accessibility/JXA prerequisite.
- Options/root smoke fallback: PASS — `30-review-options-smoke-mcp-fallback.md` and `options-smoke-mcp-fallback-20260524T0106.jpg`.
- Supabase status redacted: PASS — `agent-runs/20260524T010718Z-supabase-status-redacted-task-TASK-118-p5263.{md,json,log}`
- Live sync matrix: REFUSED by safety gate without `MC_ALLOW_LIVE=1` — `agent-runs/20260524T010803Z-live-sync-matrix-task-TASK-118-prefix-TASK118_FINAL_-p6201.{md,json,log}`
- Sensitive/redaction scan: PASS — `agent-runs/20260524T010656Z-scan-sensitive-task-TASK-118-p97345.{md,json,log}`
- Evidence scan: PASS — `agent-runs/20260524T010809Z-scan-evidence-task-TASK-118-p6619.{md,json,log}`
- JSON validation: PASS — `agent-runs/20260524T010827Z-report-validate-json-task-TASK-118-path-docs-TASKS-EVIDENCE-TASK-118-agent-runs-p14094.{md,json,log}`
- MCP wrapper review: PASS by source audit and self-test (`node tools/agent/mcp/server.mjs --self-test`); wrapper remains allowlisted, argv-based, cwd-fixed, and does not set `MC_ALLOW_LIVE`/`MC_ALLOW_CLEANUP`.
- Diff whitespace: PASS — `git diff --check`
