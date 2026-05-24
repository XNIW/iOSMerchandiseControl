# TASK-121 final architecture certification

Verdict: `TASK-121 ACTIVE / REVIEW — ARCHITECTURE_TARGET_MET`.

This canonical alignment pass physically eradicated the remaining local root residues, removed the legacy `SupabaseInventoryService` production symbol, committed the TASK-121 fix set, pushed it to GitHub `main`, and verified canonical GitHub after the push. It does not mark TASK-121 DONE.

## Canonical GitHub alignment certification

- local HEAD at architecture push: `2ac8cb02587657307a0ec136e8153f6ee29808a2`
- origin/main at architecture push: `2ac8cb02587657307a0ec136e8153f6ee29808a2`
- GitHub main at architecture push: `2ac8cb02587657307a0ec136e8153f6ee29808a2`
- pushed: yes, fast-forward `3709b26..2ac8cb0`
- root forbidden files local: 0
- root forbidden files GitHub: 0
- SupabaseInventoryService root status: absent; GitHub raw status `404`
- Sync/Remote transport/adapters status: present; GitHub raw status `200` for transport and all four adapters
- scanner anti-false-positive status: PASS after an observed RED (`20260524T192703Z-scan-root-residue-task-TASK-121-strict-p25792`) and post-push PASS (`20260524T194147Z-scan-root-residue-task-TASK-121-strict-p65460`)
- local build/test/scanner status: PASS
- GitHub canonical verification status: PASS by `git rev-parse`, `git ls-remote`, `git ls-tree`, and GitHub raw checks
- Options smoke status: PASS_WITH_NOTES, non-blocking accepted XcodeBuildMCP fallback
- live/cleanup status: NOT_RUN, not counted as PASS
- final verdict: `TASK-121 ACTIVE / REVIEW — ARCHITECTURE_TARGET_MET`

## Supported local PASS evidence

- HEAD/preflight/config: PASS.
- Harness discovery/routing/health/MCP/status/evidence metadata/scanner fixtures: PASS.
- Source format, sync inventory, sync architecture, retry ownership, manual boundary, shared purity, dead code, Xcode membership and duplicate symbols: PASS.
- Debug build, Release build, automatic architecture tests, automatic domain tests, broad sync tests and manual sync regression tests: PASS.
- Options smoke: PASS_WITH_NOTES non-blocking via accepted XcodeBuildMCP fallback evidence.
- Supabase contract was read-only only: PASS.
- Sensitive/evidence/report validation: PASS.
- Root residue reconciliation: PASS locally with `classified_residue_count=0`.

## Canonical GitHub blocker resolution

- Before this pass, GitHub canonical `main` still listed the pre-fix root service.
- After the authorized push, canonical `main` no longer lists `iOSMerchandiseControl/SupabaseInventoryService.swift`.
- `Sync/Remote/SupabaseTransportClient.swift` and the four Remote adapter files are present on canonical GitHub `main`.
- `ARCHITECTURE_TARGET_MET` is declared only for TASK-121 review handoff; DONE still requires review/user acceptance.

## Root residue resolution pass

Before: 10 root residues.

After: 0 root residues.

Moved:
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

Ledger:
- `docs/TASKS/EVIDENCE/TASK-121/root-residue-resolution-ledger.md`

Scanner refs:
- root residue: `20260524T182117Z-scan-root-residue-task-TASK-121-strict-p96790`
- sync inventory: `20260524T180519Z-scan-sync-inventory-task-TASK-121-strict-p64584`
- source format: `20260524T180449Z-scan-source-format-task-TASK-121-strict-p62217`
- xcode membership: `20260524T180544Z-scan-xcode-membership-task-TASK-121-strict-p67343`
- duplicate symbols: `20260524T180548Z-scan-duplicate-symbols-task-TASK-121-strict-p67804`
- dead code: `20260524T180541Z-scan-dead-code-task-TASK-121-strict-p66869`

## PASS_WITH_NOTES classification

The only remaining PASS_WITH_NOTES is non-blocking: `ios smoke options --task TASK-121` is `PASS_WITH_NOTES` because legacy JXA/Accessibility is tooling-blocked, while the wrapper accepted XcodeBuildMCP fallback evidence:

- report: `20260524T181548Z-ios-smoke-options-task-TASK-121-p75878`
- fallback text: `docs/TASKS/EVIDENCE/TASK-121/ios-options-xcodebuildmcp-fallback.txt`
- fallback screenshot: `docs/TASKS/EVIDENCE/TASK-121/ios-options-xcodebuildmcp-fallback.jpg`

This is accepted by CA-121-22 and is not a root-residue or architecture blocker.

## NOT_RUN gates

Live and cleanup gates remained NOT_RUN by design:

- `MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live reconcile-counts --task TASK-121 --prefix TASK121_RECON_`
- `MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-matrix --task TASK-121 --prefix TASK121_FINAL_`
- `MC_ALLOW_CLEANUP=1 ...`

They are not counted as PASS.

## Required next action

Claude review should verify the root-residue move ledger, the scanner reports, and the non-blocking Options fallback note. TASK-121 remains not DONE.

## Final anti-false-positive architecture certification

- Canonical architecture commit checked and pushed: `2ac8cb02587657307a0ec136e8153f6ee29808a2` matched local `HEAD`, `origin/main`, and GitHub canonical `main` immediately after the authorized architecture push.
- local git ls-files root sync-related count: 0 non-allowlisted files after the anti-false-positive pass.
- GitHub canonical main root sync-related count: 0 forbidden root sync files; old root `iOSMerchandiseControl/SupabaseInventoryService.swift` returns raw `404`.
- root residues before/after: original blocking set 10 -> 0; additional anti-false-positive root rehomes completed; final scanner residue count 0.
- duplicate root+moved path count: 0.
- SupabaseInventoryService status: root path removed and production symbol eliminated; transport renamed to `SupabaseTransportClient` in `Sync/Remote/SupabaseTransportClient.swift`; automatic/history/incremental callers use Remote adapters or protocols.
- source-format status: PASS.
- scanner false-positive fixes: root-residue checks tracked root files via `git ls-files`, duplicate root+moved paths, and legacy production symbol use; Supabase contract TASK-121 routes to TASK-121 scanner and requires reconciliation PASS.
- CA-121-01...56 final ledger: build/test/scanner refs in `agent-runs/index.md`; live/cleanup gates remain NOT_RUN and are not counted as PASS.
- PASS_WITH_NOTES: `ios smoke options` only, via accepted fallback.
- NOT_RUN: live reconcile, live sync matrix, cleanup.
- reviewer next action: review `TASK-121 ACTIVE / REVIEW — ARCHITECTURE_TARGET_MET`; TASK-121 remains not DONE until review/user acceptance.
