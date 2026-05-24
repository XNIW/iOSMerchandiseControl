# TASK-121 agent-runs index

Generated during the post-TASK-121 architecture review/fix pass on 2026-05-24.

Updated during the continuation root-residue eradication pass on 2026-05-24.

## Discovery and preflight

- PASS: `git head-consistency --task TASK-121`
- PASS: `preflight --require-head-consistency --task TASK-121`
- PASS: `config validate --task TASK-121`
- PASS: `help-json`
- PASS: `list commands-json`
- PASS: `report validate-json --task TASK-121 --path docs/TASKS/EVIDENCE/TASK-121/agent-runs`

Discovery evidence:
- `00-help-json.json`
- `00-commands-json.json`
- `00-discovery-summary.md`

## Harness and scanner gates

- PASS: `scan task-docs --task TASK-121 --strict`
- PASS: `scan master-plan-consistency --task TASK-121 --strict`
- PASS: `scan harness-routing --task TASK-121 --strict`
- PASS: `scan harness-health --task TASK-121 --strict`
- PASS: `scan mcp-wrapper --task TASK-121 --strict`
- PASS: `scan status-taxonomy --task TASK-121 --strict`
- PASS: `scan evidence-metadata --task TASK-121 --strict`
- PASS: `scan scanner-self-tests --task TASK-121 --strict`

## Architecture gates

- PASS: `scan source-format --task TASK-121 --strict`
- PASS: `scan sync-inventory --task TASK-121 --strict`
- PASS: `scan sync-architecture --task TASK-121 --strict`
- PASS: `scan retry-ownership --task TASK-121 --strict`
- PASS: `scan manual-boundary --task TASK-121 --strict`
- PASS: `scan shared-purity --task TASK-121 --strict`
- PASS: `scan dead-code --task TASK-121 --strict`
- PASS: `scan xcode-membership --task TASK-121 --strict`
- PASS: `scan duplicate-symbols --task TASK-121 --strict`
- PASS: `scan root-residue --task TASK-121 --strict`

Root residue reconciliation is full PASS for the local index/worktree: classified residue count is 0 and no blocker-class `PASS_WITH_NOTES` remains. Canonical GitHub `main` is tracked separately below because push was explicitly forbidden.

## Root residue resolution pass

- before: 10 root residues
- after: 0 root residues
- ledger: `docs/TASKS/EVIDENCE/TASK-121/root-residue-resolution-ledger.md`
- scanner ref: `20260524T182117Z-scan-root-residue-task-TASK-121-strict-p96790`
- sync inventory ref: `20260524T180519Z-scan-sync-inventory-task-TASK-121-strict-p64584`
- xcode membership ref: `20260524T180544Z-scan-xcode-membership-task-TASK-121-strict-p67343`
- duplicate symbols ref: `20260524T180548Z-scan-duplicate-symbols-task-TASK-121-strict-p67804`
- moved list:
  - `iOSMerchandiseControl/InventorySyncService.swift` -> `iOSMerchandiseControl/Sync/Recovery/InventorySyncService.swift`
  - `iOSMerchandiseControl/SupabaseProductPricePreviewService.swift` -> `iOSMerchandiseControl/Sync/Manual/SupabaseProductPricePreviewService.swift`
  - `iOSMerchandiseControl/SupabaseProductPricePushDryRunService.swift` -> `iOSMerchandiseControl/Sync/Manual/SupabaseProductPricePushDryRunService.swift`
  - `iOSMerchandiseControl/SupabasePullApplyService.swift` -> `iOSMerchandiseControl/Sync/Recovery/SupabasePullApplyService.swift`
  - `iOSMerchandiseControl/SupabasePullPreviewModels.swift` -> `iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewModels.swift`
  - `iOSMerchandiseControl/SupabasePullPreviewService.swift` -> `iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewService.swift`
  - `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift` -> `iOSMerchandiseControl/Sync/Manual/SupabasePushPreflightViewModel.swift`
  - `iOSMerchandiseControl/SupabaseSyncEventPreviewService.swift` -> `iOSMerchandiseControl/Sync/Manual/SupabaseSyncEventPreviewService.swift`
  - `iOSMerchandiseControl/SyncEventOutboxDrainService.swift` -> `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxDrainService.swift`
  - `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift` -> `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxEnqueueService.swift`

## Build, tests, smoke

- PASS: `ios build debug --task TASK-121`
- PASS: `ios build release --task TASK-121`
- PASS: `ios test automatic-architecture --task TASK-121`
- PASS: `ios test automatic-domain --task TASK-121`
- PASS: `ios test sync --task TASK-121`
- PASS: `ios test manual-sync-regression --task TASK-121`
- PASS_WITH_NOTES: `ios smoke options --task TASK-121` via accepted XcodeBuildMCP fallback evidence because legacy JXA/Accessibility was tooling-blocked.

Options fallback evidence:
- `docs/TASKS/EVIDENCE/TASK-121/ios-options-xcodebuildmcp-fallback.txt`
- `docs/TASKS/EVIDENCE/TASK-121/ios-options-xcodebuildmcp-fallback.jpg`
- report ref: `20260524T181548Z-ios-smoke-options-task-TASK-121-p75878`

## Supabase and safety

- PASS: `supabase contract sync-schema --task TASK-121 --read-only`
- PASS: `supabase status-redacted --task TASK-121`
- PASS: `scan sensitive --task TASK-121`
- PASS: `scan evidence --task TASK-121`
- PASS: `report validate-json --task TASK-121 --path docs/TASKS/EVIDENCE/TASK-121/agent-runs`
- PASS: `git diff --check`

Live and cleanup gates were NOT_RUN by design and are not counted as PASS.

## Final anti-false-positive architecture certification

- GitHub/local SHA checked: `74cbe9fc41067e64bd11fd6e62307b4451233866` for local `HEAD`, `origin/main`, and GitHub canonical `main`.
- local git ls-files root sync-related count: 0 non-allowlisted root sync/Supabase files.
- GitHub canonical main root sync-related count: 1 blocking file, `iOSMerchandiseControl/SupabaseInventoryService.swift`.
- root residues before/after: original blocking set 10 -> 0; anti-false-positive root allowlist pass found and moved additional root sync files including `SupabaseInventoryService.swift`.
- duplicate root+moved path count: 0.
- SupabaseInventoryService status: root path eliminated; moved/renamed to `Sync/Remote/SupabaseTransportClient.swift`; Remote adapters added for catalog, product price, history, and sync-event incremental access.
- source-format status: PASS, `20260524T184456Z-scan-source-format-task-TASK-121-strict-p21711`.
- scanner false-positive fixes: root-residue now checks `git ls-files` root-only and duplicate root+moved paths; Supabase contract TASK-121 now routes to `task121_scans.py` and requires reconciliation PASS.
- CA-121-01...56 final ledger: scanner/build/test/smoke refs below; live/cleanup gates remain NOT_RUN and are not counted as PASS.
- PASS_WITH_NOTES: only `ios smoke options`, accepted fallback evidence from wrapper.
- NOT_RUN: live reconcile, live sync matrix, cleanup.
- reviewer next action: do not approve `ARCHITECTURE_TARGET_MET` until canonical GitHub alignment is authorized and verified.

Latest final refs:
- root-residue: `20260524T184456Z-scan-root-residue-task-TASK-121-strict-p21697`
- sync-inventory: `20260524T184455Z-scan-sync-inventory-task-TASK-121-strict-p21649`
- sync-architecture: `20260524T184427Z-scan-sync-architecture-task-TASK-121-strict-p19019`
- manual-boundary: `20260524T184455Z-scan-manual-boundary-task-TASK-121-strict-p21648`
- duplicate-symbols: `20260524T184456Z-scan-duplicate-symbols-task-TASK-121-strict-p21700`
- debug build: `20260524T184725Z-ios-build-debug-task-TASK-121-p26069`
- release build: `20260524T184825Z-ios-build-release-task-TASK-121-p26986`
- automatic architecture: `20260524T185030Z-ios-test-automatic-architecture-task-TASK-121-p28971`
- automatic domain: `20260524T185045Z-ios-test-automatic-domain-task-TASK-121-p29633`
- sync tests: `20260524T185057Z-ios-test-sync-task-TASK-121-p30253`
- manual sync regression: `20260524T185328Z-ios-test-manual-sync-regression-task-TASK-121-p31082`
- options smoke: `20260524T185344Z-ios-smoke-options-task-TASK-121-p31687`
- Supabase contract read-only: `20260524T185625Z-supabase-contract-sync-schema-task-TASK-121-read-only-p33721`

Final post-documentation rerun refs:
- task-docs: `20260524T190006Z-scan-task-docs-task-TASK-121-strict-p36651`
- master-plan-consistency: `20260524T190006Z-scan-master-plan-consistency-task-TASK-121-strict-p36650`
- harness-health: `20260524T190151Z-scan-harness-health-task-TASK-121-strict-p57748`
- evidence-metadata: `20260524T190017Z-scan-evidence-metadata-task-TASK-121-strict-p39095`
- sync-inventory: `20260524T190151Z-scan-sync-inventory-task-TASK-121-strict-p57747`
- root-residue: `20260524T190017Z-scan-root-residue-task-TASK-121-strict-p39138`
- source-format: `20260524T190032Z-scan-source-format-task-TASK-121-strict-p41571`
- scanner-self-tests: `20260524T190032Z-scan-scanner-self-tests-task-TASK-121-strict-p41575`
- Supabase status-redacted: `20260524T190040Z-supabase-status-redacted-task-TASK-121-p43916`
- Supabase contract read-only: `20260524T190040Z-supabase-contract-sync-schema-task-TASK-121-read-only-p43917`
- sensitive: `20260524T190040Z-scan-sensitive-task-TASK-121-p43965`
- evidence: `20260524T190326Z-scan-evidence-task-TASK-121-p73652`
- report validate-json: `20260524T190326Z-report-validate-json-task-TASK-121-path-docs-TASKS-EVIDENCE-TASK-121-agent-runs-p73653`
- `git diff --check`: PASS, no output on final rerun.
