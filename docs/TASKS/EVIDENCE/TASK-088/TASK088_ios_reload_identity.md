# TASK088 iOS Reload Identity

Data: 2026-05-09 13:10 -0400

## Tipo verifica

- `TEST`: XCTest mirato su SwiftData in-memory con nuovo `ModelContext`.
- `STATIC`: wiring Release controllato nel codice iOS.
- Nessun dato reale, nessun UUID completo, nessun segreto.

## Evidenza test

Comando eseguito:

```bash
xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceManualPushServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests/testTask080LocalProductPricesEnableCloudSendWithoutCatalogCandidates -parallel-testing-enabled NO
```

Esito: **TEST SUCCEEDED**, 38 test, 0 failure.

Test nuovo rilevante:

- `SupabaseProductPriceManualPushServiceTests.testTask088VerifiedPushLinksRemoteIDAcrossReloadAndSecondDryRun`

Copertura del test:

- crea product `TASK088_BAR_PRICE` con 4 ProductPrice locali;
- primo dry-run: 4 candidati;
- push verificato con remote mock che restituisce/read-back le righe inserite;
- riconciliazione locale: 4 `remoteID` valorizzati;
- reload tramite nuovo `ModelContext`: 4 `remoteID` ancora presenti;
- secondo dry-run: 0 candidati.

## Evidenza codice

- `SupabaseManualSyncReleaseProductPriceAdapter.push` ora chiama `ProductPriceManualPushIdentityReconciler` solo dopo `ProductPriceManualPushResult.isVerifiedSuccess`.
- Il reconciler associa payload verificati a righe locali non linkate usando chiave sicura:
  `product remoteID + type + price canonico + effectiveAt + source + note`.
- In caso di salvataggio SwiftData fallito, il contesto viene rollbackato e non viene dichiarato successo locale.

## Esito

**PASS TEST/STATIC**: la persistenza `remoteID` dopo push verificato e reload del context e' coperta da test mirato e wiring Release.
