# TASK-121 final architecture certification

Verdict: `TASK-121 ACTIVE / REVIEW — ARCHITECTURE_TARGET_MET`.

This continuation pass physically eradicated the remaining root residues and reran the TASK-121 scanner/build/test/safety matrix. It does not mark TASK-121 DONE; it hands the task back to Claude review.

## Supported PASS evidence

- HEAD/preflight/config: PASS.
- Harness discovery/routing/health/MCP/status/evidence metadata/scanner fixtures: PASS.
- Source format, sync inventory, sync architecture, retry ownership, manual boundary, shared purity, dead code, Xcode membership and duplicate symbols: PASS.
- Debug build, Release build, automatic architecture tests, automatic domain tests, broad sync tests and manual sync regression tests: PASS.
- Options smoke: PASS_WITH_NOTES non-blocking via accepted XcodeBuildMCP fallback evidence.
- Supabase contract was read-only only: PASS.
- Sensitive/evidence/report validation: PASS.
- Root residue reconciliation: PASS with `classified_residue_count=0`.

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
