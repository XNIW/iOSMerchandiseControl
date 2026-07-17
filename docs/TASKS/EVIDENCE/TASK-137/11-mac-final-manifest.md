# Manifest consolidamento finale Mac — iOS

Data: 2026-07-17
Repository: `/Users/minxiang/Desktop/iOSMerchandiseControl`
Stato iniziale: `main` @ `2801241a646cd5d35aba5e7d285f23a44825c0ef`; `origin/main` uguale; ahead/behind `0/0`; worktree sporco misto.
Branch di separazione: `integrate/mac-final-ios-20260717T150455Z`.

Commit TASK-137 creati sul branch di separazione:

- `629eb8e8` — runtime/UI, incluso il fail-closed della remove response;
- `4b89c7d2` — test cache/API/remove/sync contract.

Metadati comuni per ogni path incluso: repository iOS canonico;
`include=yes`; dipendenza contratto backend TASK-137; evidence XCTest finale
Product Images `22/22`, build/sync/localizzazioni baseline. I path aggiunti
(`A` nei receipt Git dei commit) erano untracked al recovery; tutti gli altri
erano tracked. Le sezioni assegnano categoria, motivo, evidence e dipendenze a
ciascun path.

La whitelist seguente è esaustiva. Tutti i path non elencati restano esclusi.

## TASK-137 — runtime (`D. TASK137_IOS_SOURCE`)

- `iOSMerchandiseControl.xcodeproj/project.pbxproj`
- `iOSMerchandiseControl/SupabaseConfig.swift`
- `iOSMerchandiseControl/SupabaseConfig.example.plist`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/EditProductView.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageAPIClient.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageCache.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageContract.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageProcessor.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageService.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageStore.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageViews.swift`
- `iOSMerchandiseControl/Sync/Automatic/Pull/CatalogIncrementalApplyService.swift`
- `iOSMerchandiseControl/Sync/Automatic/Pull/SyncEventIncrementalApplyHelpers.swift`
- `iOSMerchandiseControl/Sync/Manual/SupabaseManualPushService.swift`
- `iOSMerchandiseControl/Sync/Recovery/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewModels.swift`
- `iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/Sync/Recovery/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/Sync/Remote/CatalogRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/SupabaseInventoryDTOs.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

## TASK-137 — test (`E. TASK137_TEST`)

- `iOSMerchandiseControlTests/ProductImages/ProductImageAPIClientTests.swift`
- `iOSMerchandiseControlTests/ProductImages/ProductImageCacheTests.swift`
- `iOSMerchandiseControlTests/ProductImages/ProductImageProcessorTests.swift`
- `iOSMerchandiseControlTests/ProductImages/ProductImageSyncContractTests.swift`

## TASK-088B — harness escluso e preservato (`H. TASK088_PRESERVE`, `include=no`)

- `iOSMerchandiseControlTests/Task088ObservePrewarmCoordinatorTests.swift`
- `iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests.swift`
- `tests/test_final_sync_contract.py`
- `tools/agent/lib/android.sh`
- `tools/agent/lib/final_sync.sh`
- `tools/agent/lib/final_sync_contract.py`
- `tools/agent/lib/ios.sh`
- `tools/agent/lib/task088_supabase_rest.mjs`

## Governance ed evidence (`G. TASK137_DOCUMENTATION`)

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-137-product-catalog-images-cross-platform-ios.md`
- `docs/TASKS/EVIDENCE/TASK-137/README.md`
- `docs/TASKS/EVIDENCE/TASK-137/ios-fixture-manifest.json`
- `docs/TASKS/EVIDENCE/TASK-137/ios-heic-metrics.json`
- `docs/TASKS/EVIDENCE/TASK-137/ios-high-resolution-metrics.json`
- `docs/TASKS/EVIDENCE/TASK-137/ios-performance-metrics.json`
- `docs/TASKS/EVIDENCE/TASK-137/ios-rotated-jpeg-metrics.json`
- `docs/TASKS/EVIDENCE/TASK-137/ios-test-summary.json`
- `docs/TASKS/EVIDENCE/TASK-137/ios-transparent-png-metrics.json`
- `docs/TASKS/EVIDENCE/TASK-137/11-mac-final-manifest.md`

## Esclusioni esplicite

- `Data/data.0~A8YuSCH6JEVuFMRhbuqsRtxYMJabCBuXDBMUh4xY7ie6UpJByvjfqXSlyI5CCTtx5OThPbPdozjB5539MkpEFw==`
- `Data/data.0~YmgyKWPcvf6m90Z-rf2OC150mrrlN9-FSMXkDgrs-nR2qxUBNx4RIwmr9c9IuFlEOKZwafrb4MzyySjPWMHdAw==`
- `Data/refs.0~A8YuSCH6JEVuFMRhbuqsRtxYMJabCBuXDBMUh4xY7ie6UpJByvjfqXSlyI5CCTtx5OThPbPdozjB5539MkpEFw==`
- `Data/refs.0~YmgyKWPcvf6m90Z-rf2OC150mrrlN9-FSMXkDgrs-nR2qxUBNx4RIwmr9c9IuFlEOKZwafrb4MzyySjPWMHdAw==`
- `Info.plist`
- `iOSMerchandiseControlTests/MobileAtomicSyncEventTests.swift`
- Tutte le altre modifiche iOS preesistenti, evidence TASK-136, dati locali, output generati e log grezzi.
- Nessun deploy TestFlight/App Store, migrazione remota o rilancio della matrice K125.
- `Data/`, `Info.plist`, evidence TASK-136 e output generati sono
  `J. GENERATED_EXCLUDE` o `K. SENSITIVE_EXCLUDE`; gli hunk preesistenti nei
  file parzialmente staged e tutti gli altri tracked dirty sono
  `L. UNRELATED_PRESERVE`. Nessun path `M. UNKNOWN_BLOCK` è incluso e non ci
  sono modifiche `.gitattributes`.
