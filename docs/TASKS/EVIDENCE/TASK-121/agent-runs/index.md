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

Root residue reconciliation is now full PASS: classified residue count is 0 and no blocker-class `PASS_WITH_NOTES` remains.

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
