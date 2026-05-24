# TASK-121 agent-runs index

Generated during the post-TASK-121 architecture review/fix pass on 2026-05-24.

Updated during the continuation root-residue eradication and canonical GitHub alignment pass on 2026-05-24.

Updated during the independent final review pass on 2026-05-24 17:21 -0400.

Current verdict: `TASK-121 ACTIVE / FIX — CHANGES_REQUIRED`, not DONE.

Current reviewed SHA:
- local `HEAD`: `a7564857128d08d4e15eaf0977617fbd8a91806a`
- `origin/main`: `a7564857128d08d4e15eaf0977617fbd8a91806a`
- GitHub canonical `main`: `a7564857128d08d4e15eaf0977617fbd8a91806a`
- historical architecture commit referenced by earlier evidence: `2ac8cb02587657307a0ec136e8153f6ee29808a2`

Blocking review finding: `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift` remains a multi-domain mega-service; the strengthened `sync-architecture` scanner now fails correctly.

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
- FAIL: `scan sync-architecture --task TASK-121 --strict` after scanner strengthening (`20260524T211916Z-scan-sync-architecture-task-TASK-121-strict-p40244`); earlier PASS refs are superseded false negatives for the Remote mega-service case.
- PASS: `scan retry-ownership --task TASK-121 --strict`
- PASS: `scan manual-boundary --task TASK-121 --strict`
- PASS: `scan shared-purity --task TASK-121 --strict`
- PASS: `scan dead-code --task TASK-121 --strict`
- PASS: `scan xcode-membership --task TASK-121 --strict`
- PASS: `scan duplicate-symbols --task TASK-121 --strict`
- PASS: `scan root-residue --task TASK-121 --strict`

Root residue reconciliation is full PASS for the local index/worktree and canonical GitHub `main`: classified residue count is 0, no blocker-class `PASS_WITH_NOTES` remains, and the post-push remote tree has no forbidden root sync files.

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

## Independent final review rerun — 2026-05-24 17:21 -0400

- PASS: `git head-consistency --task TASK-121` (`20260524T210617Z-git-head-consistency-task-TASK-121-p2043`)
- PASS: `preflight --require-head-consistency --task TASK-121` (`20260524T210617Z-preflight-require-head-consistency-task-TASK-121-p2042`)
- PASS: `config validate --task TASK-121` (`20260524T210617Z-config-validate-task-TASK-121-p2085`)
- PASS: `scan task-docs --task TASK-121 --strict` (`20260524T210952Z-scan-task-docs-task-TASK-121-strict-p4708`)
- PASS: `scan master-plan-consistency --task TASK-121 --strict` (`20260524T210952Z-scan-master-plan-consistency-task-TASK-121-strict-p4709`)
- PASS: `scan harness-routing --task TASK-121 --strict` (`20260524T210952Z-scan-harness-routing-task-TASK-121-strict-p4859`)
- PASS: `scan harness-health --task TASK-121 --strict` (`20260524T210952Z-scan-harness-health-task-TASK-121-strict-p4846`)
- PASS: `scan mcp-wrapper --task TASK-121 --strict` (`20260524T210952Z-scan-mcp-wrapper-task-TASK-121-strict-p4831`)
- PASS: `scan status-taxonomy --task TASK-121 --strict` (`20260524T210952Z-scan-status-taxonomy-task-TASK-121-strict-p4851`)
- PASS: `scan evidence-metadata --task TASK-121 --strict` (`20260524T210952Z-scan-evidence-metadata-task-TASK-121-strict-p4855`)
- PASS: `scan sync-inventory --task TASK-121 --strict` (`20260524T211013Z-scan-sync-inventory-task-TASK-121-strict-p7588`)
- FAIL: `scan sync-architecture --task TASK-121 --strict` after scanner fix (`20260524T211916Z-scan-sync-architecture-task-TASK-121-strict-p40244`)
- PASS: `scan retry-ownership --task TASK-121 --strict` (`20260524T211013Z-scan-retry-ownership-task-TASK-121-strict-p7617`)
- PASS: `scan manual-boundary --task TASK-121 --strict` (`20260524T211013Z-scan-manual-boundary-task-TASK-121-strict-p7653`)
- PASS: `scan root-residue --task TASK-121 --strict` (`20260524T211013Z-scan-root-residue-task-TASK-121-strict-p7684`)
- PASS: `scan shared-purity --task TASK-121 --strict` (`20260524T211013Z-scan-shared-purity-task-TASK-121-strict-p7628`)
- PASS: `scan dead-code --task TASK-121 --strict` (`20260524T211013Z-scan-dead-code-task-TASK-121-strict-p7704`)
- PASS: `scan xcode-membership --task TASK-121 --strict` (`20260524T211013Z-scan-xcode-membership-task-TASK-121-strict-p7625`)
- PASS: `scan duplicate-symbols --task TASK-121 --strict` (`20260524T211013Z-scan-duplicate-symbols-task-TASK-121-strict-p7639`)
- PASS: `scan source-format --task TASK-121 --strict` after scanner fix (`20260524T211916Z-scan-source-format-task-TASK-121-strict-p40218`)
- PASS: `scan scanner-self-tests --task TASK-121 --strict` after scanner fix (`20260524T211916Z-scan-scanner-self-tests-task-TASK-121-strict-p40243`)
- PASS: `ios build debug --task TASK-121` (`20260524T211032Z-ios-build-debug-task-TASK-121-p13238`)
- PASS: `ios build release --task TASK-121` (`20260524T211046Z-ios-build-release-task-TASK-121-p13956`)
- PASS: `ios test automatic-architecture --task TASK-121` (`20260524T211201Z-ios-test-automatic-architecture-task-TASK-121-p14753`)
- PASS: `ios test automatic-domain --task TASK-121` (`20260524T211224Z-ios-test-automatic-domain-task-TASK-121-p15486`)
- PASS: `ios test sync --task TASK-121` (`20260524T211235Z-ios-test-sync-task-TASK-121-p16090`)
- PASS: `ios test manual-sync-regression --task TASK-121` (`20260524T211507Z-ios-test-manual-sync-regression-task-TASK-121-p16952`)
- PASS_WITH_NOTES: `ios smoke options --task TASK-121` (`20260524T211520Z-ios-smoke-options-task-TASK-121-p17571`)
- PASS: `supabase status-redacted --task TASK-121` (`20260524T211023Z-supabase-status-redacted-task-TASK-121-p12132`)
- PASS: `supabase contract sync-schema --task TASK-121 --read-only` (`20260524T211023Z-supabase-contract-sync-schema-task-TASK-121-read-only-p12133`)
- PASS: `scan sensitive --task TASK-121` (`20260524T211559Z-scan-sensitive-task-TASK-121-p18305`)
- PASS: `scan evidence --task TASK-121` (`20260524T211559Z-scan-evidence-task-TASK-121-p18304`)
- PASS: `report validate-json --task TASK-121 --path docs/TASKS/EVIDENCE/TASK-121/agent-runs` (`20260524T211559Z-report-validate-json-task-TASK-121-path-docs-TASKS-EVIDENCE-TASK-121-agent-runs-p18356`)
- PASS: `git diff --check` after tracking edits; no output.

Post-tracking validation refs:
- PASS: `scan task-docs --task TASK-121 --strict` (`20260524T212741Z-scan-task-docs-task-TASK-121-strict-p69155`)
- PASS: `scan master-plan-consistency --task TASK-121 --strict` (`20260524T212741Z-scan-master-plan-consistency-task-TASK-121-strict-p69154`)
- PASS: `scan evidence-metadata --task TASK-121 --strict` (`20260524T212741Z-scan-evidence-metadata-task-TASK-121-strict-p69156`)
- PASS: `scan source-format --task TASK-121 --strict` (`20260524T212559Z-scan-source-format-task-TASK-121-strict-p44756`)
- FAIL: `scan sync-architecture --task TASK-121 --strict` (`20260524T212756Z-scan-sync-architecture-task-TASK-121-strict-p70446`); `remote_transport_is_thin` evidence: line count 1866, direct domain conformances 7, domain method hits 14, debug task hooks 40.
- PASS: `scan scanner-self-tests --task TASK-121 --strict` (`20260524T212607Z-scan-scanner-self-tests-task-TASK-121-strict-p46364`)
- PASS: `scan evidence --task TASK-121` (`20260524T212756Z-scan-evidence-task-TASK-121-p70413`)
- PASS: `report validate-json --task TASK-121 --path docs/TASKS/EVIDENCE/TASK-121/agent-runs` (`20260524T212834Z-report-validate-json-task-TASK-121-path-docs-TASKS-EVIDENCE-TASK-121-agent-runs-p91739`)
- PASS: `git diff --check`, no output.

## Final anti-false-positive architecture certification

- Canonical architecture commit checked and pushed: `2ac8cb02587657307a0ec136e8153f6ee29808a2` for local `HEAD`, `origin/main`, and GitHub canonical `main` immediately after the architecture push.
- local git ls-files root sync-related count: 0 non-allowlisted root sync/Supabase files.
- GitHub canonical main root sync-related count: 0 forbidden root sync files; old root `iOSMerchandiseControl/SupabaseInventoryService.swift` returns GitHub raw `404`.
- root residues before/after: original blocking set 10 -> 0; anti-false-positive root allowlist pass found and moved additional root sync files including `SupabaseInventoryService.swift`.
- duplicate root+moved path count: 0.
- SupabaseInventoryService status: root path eliminated and production symbol removed; transport renamed to `SupabaseTransportClient` in `Sync/Remote/SupabaseTransportClient.swift`; Remote adapters added for catalog, product price, history, and sync-event incremental access.
- source-format status: PASS, `20260524T193322Z-scan-source-format-task-TASK-121-strict-p38688`.
- scanner false-positive fixes: root-residue now checks `git ls-files` root-only, duplicate root+moved paths, and legacy production `SupabaseInventoryService` symbol use; Supabase contract TASK-121 routes to `task121_scans.py` and requires reconciliation PASS.
- CA-121-01...56 final ledger: scanner/build/test/smoke refs below; live/cleanup gates remain NOT_RUN and are not counted as PASS.
- PASS_WITH_NOTES: only `ios smoke options`, accepted fallback evidence from wrapper.
- NOT_RUN: live reconcile, live sync matrix, cleanup.
- reviewer next action: review `TASK-121 ACTIVE / REVIEW — ARCHITECTURE_TARGET_MET`; TASK-121 remains not DONE until review/user acceptance.

## Canonical GitHub alignment certification

- local HEAD at architecture push: `2ac8cb02587657307a0ec136e8153f6ee29808a2`
- origin/main at architecture push: `2ac8cb02587657307a0ec136e8153f6ee29808a2`
- GitHub main at architecture push: `2ac8cb02587657307a0ec136e8153f6ee29808a2`
- pushed: yes, `git push origin main` fast-forward `3709b26..2ac8cb0`
- root forbidden files local: 0
- root forbidden files GitHub: 0 by `git ls-tree origin/main` and GitHub raw checks
- SupabaseInventoryService root status: absent; GitHub raw status `404`
- Sync/Remote transport/adapters status: present; GitHub raw status `200` for transport and all four adapters
- scanner anti-false-positive status: PASS after RED observation (`20260524T192703Z-scan-root-residue-task-TASK-121-strict-p25792`) and post-push PASS (`20260524T194147Z-scan-root-residue-task-TASK-121-strict-p65460`)
- local build/test/scanner status: PASS
- GitHub canonical verification status: PASS by `git rev-parse`, `git ls-remote`, `git ls-tree`, and GitHub raw status checks
- Options smoke status: PASS_WITH_NOTES, non-blocking accepted XcodeBuildMCP fallback
- live/cleanup status: NOT_RUN, not counted as PASS
- final verdict: `TASK-121 ACTIVE / REVIEW — ARCHITECTURE_TARGET_MET`

Latest final refs:
- root-residue: `20260524T194147Z-scan-root-residue-task-TASK-121-strict-p65460`
- sync-inventory: `20260524T193309Z-scan-sync-inventory-task-TASK-121-strict-p36429`
- sync-architecture: `20260524T193309Z-scan-sync-architecture-task-TASK-121-strict-p36430`
- manual-boundary: `20260524T193322Z-scan-manual-boundary-task-TASK-121-strict-p38691`
- duplicate-symbols: `20260524T193322Z-scan-duplicate-symbols-task-TASK-121-strict-p38748`
- scanner-self-tests: `20260524T193322Z-scan-scanner-self-tests-task-TASK-121-strict-p38751`
- debug build: `20260524T193224Z-ios-build-debug-task-TASK-121-p31097`
- release build: `20260524T193330Z-ios-build-release-task-TASK-121-p41091`
- automatic architecture: `20260524T193439Z-ios-test-automatic-architecture-task-TASK-121-p41890`
- automatic domain: `20260524T193512Z-ios-test-automatic-domain-task-TASK-121-p42632`
- sync tests: `20260524T193522Z-ios-test-sync-task-TASK-121-p43231`
- manual sync regression: `20260524T193753Z-ios-test-manual-sync-regression-task-TASK-121-p44142`
- options smoke: `20260524T193809Z-ios-smoke-options-task-TASK-121-p44742`
- Supabase contract read-only: `20260524T193832Z-supabase-contract-sync-schema-task-TASK-121-read-only-p45438`
- post-push head-consistency: `20260524T194147Z-git-head-consistency-task-TASK-121-p65438`
- post-push preflight: `20260524T194147Z-preflight-require-head-consistency-task-TASK-121-p65461`

Final post-documentation rerun refs:
- task-docs: `20260524T194921Z-scan-task-docs-task-TASK-121-strict-p69545`
- master-plan-consistency: `20260524T194921Z-scan-master-plan-consistency-task-TASK-121-strict-p69546`
- harness-health: `20260524T190151Z-scan-harness-health-task-TASK-121-strict-p57748`
- evidence-metadata: `20260524T194921Z-scan-evidence-metadata-task-TASK-121-strict-p69589`
- sync-inventory: `20260524T190151Z-scan-sync-inventory-task-TASK-121-strict-p57747`
- root-residue: `20260524T194921Z-scan-root-residue-task-TASK-121-strict-p69594`
- source-format: `20260524T190032Z-scan-source-format-task-TASK-121-strict-p41571`
- scanner-self-tests: `20260524T190032Z-scan-scanner-self-tests-task-TASK-121-strict-p41575`
- Supabase status-redacted: `20260524T190040Z-supabase-status-redacted-task-TASK-121-p43916`
- Supabase contract read-only: `20260524T190040Z-supabase-contract-sync-schema-task-TASK-121-read-only-p43917`
- sensitive: `20260524T190040Z-scan-sensitive-task-TASK-121-p43965`
- evidence: `20260524T194930Z-scan-evidence-task-TASK-121-p71177`
- report validate-json: `20260524T195004Z-report-validate-json-task-TASK-121-path-docs-TASKS-EVIDENCE-TASK-121-agent-runs-p88706`
- `git diff --check`: PASS, no output on final rerun.
