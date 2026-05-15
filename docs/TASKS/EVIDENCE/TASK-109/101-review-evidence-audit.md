# TASK-109 — 101 Review Evidence Audit

Review pass: 2026-05-15 02:25 -0400

## Claims verificati

- Wave 1 diagnostica presente: `00`...`07` documentano cold launch, Options-trigger baseline, stale/no-op Review, Cancel Review e History count `0`.
- Execution finale presente: `40`, `41`, `42` documentano smoke finale, UX/performance e localizzazioni; `99-traceability-matrix.md` esiste.
- Build/test execution storici sono documentati, ma non sono stati riusati come verdict finale senza rerun.
- Review rerun finale:
  - Debug build XcodeBuildMCP: PASS, warnings `0`.
  - Release build XcodeBuildMCP: PASS, warnings `0`.
  - Targeted XCTest rerun su iPhone 17 Pro iOS 26.5: PASS, `** TEST SUCCEEDED **`, xcresult `Test-iOSMerchandiseControl-2026.05.15_02-16-00--0400.xcresult`.

## Claims deboli o incompleti

- History live non-empty: l'execution aveva solo `shared_sheet_sessions = 0`. La review ha creato una riga dev owner-scoped `TASK109_REVIEW_HISTORY_20260515_0622Z`, ma non ha potuto validare pull iOS runtime perche' l'app in Simulator e' signed-out.
- Android parity: evidence esistente e review corrente sono statiche/source-grounded; nessuna patch Kotlin e nessun Gradle runtime rerun perche' Android non e' stato modificato.
- Supabase RLS/index audit: verificati con query mirate finche' il pooler ha permesso connessioni. Esecuzioni parallele successive hanno riattivato `ECIRCUITBREAKER`; non sono usate come PASS.

## Claims falsi o da non promuovere a PASS finale

- `S11` e `S12` non possono essere `PASS` finche' non esiste evidenza runtime iOS signed-in con remote History non vuota, Options count `> 0` e History tab popolata.
- `DONE` non e' consentito: stop condition `11`, `12`, `13` (second sync live non-duplicate per History) non sono chiuse runtime-grounded.

## Azioni correttive applicate

- Aggiunto test regressione `testDirectSyncDefersHistoryUntilPreparedApplyCompletes`.
- Corretto il gate History in `SupabaseManualSyncViewModel`: History sync viene eseguito durante direct/root sync solo quando non ci sono apply catalog/prezzi ancora staged; se c'e' apply locale preparato, History viene sincronizzata dopo l'apply.
- Migliorata copy pubblica `Fetching cloud counts...` -> `Checking cloud updates...` e localizzata EN/IT/ES/ZH.

## Evidence mancanti bloccanti

- App-auth signed-in runtime su iOS.
- Pull della riga `TASK109_REVIEW_HISTORY_20260515_0622Z` in SwiftData.
- `History sessions > 0` in Options dopo pull.
- HistoryView con riga visibile.
- Second sync live no-op senza duplicati.
