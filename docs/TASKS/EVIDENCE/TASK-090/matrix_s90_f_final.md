# TASK-090 — Matrice S90-F finale

Timestamp locale: 2026-05-09 17:10 -0400

## Sintesi

La matrice finale distingue evidenze iOS forti (static review, Debug/Release build, XCTest mirati e full XCTest) da scenari runtime live non eseguiti per gate ambiente. Non sono stati usati dati reali, non sono stati stampati segreti e non sono stati eseguiti write Supabase `TASK090_*`.

| Scenario | Direzione | Dataset | Oggetti | Evidenza finale | Esito | Stop gate / motivo |
|----------|-----------|---------|---------|-----------------|-------|--------------------|
| Catalog pull Supabase -> iOS | Supabase -> iOS | STATIC + prior runtime `TASK087_*`; nessun nuovo write `TASK090_*` | Supplier / Category / Product | Wiring Release letto (`SupabaseManualSyncReleaseFactory`, `SupabaseManualSyncViewModel`, `SupabasePullPreviewService`, `SupabasePullApplyService`); build Debug/Release PASS; XCTest mirati PASS; full XCTest 567/0 PASS; schema catalogo/RLS read-only verificato | PARTIAL | Nuovo smoke live `TASK090_*` non eseguito: owner/session live e collision scan DB non verificati immediatamente prima di una mutazione sicura |
| ProductPrice current/previous Supabase <-> iOS | Supabase <-> iOS | STATIC + XCTest + prior runtime `TASK088_*` | ProductPrice purchase/retail current/previous | Servizi apply/push/reconciler letti; unique key reale `(owner_user_id, product_id, type, effective_at)` verificata da migration; targeted XCTest ProductPrice/manual sync PASS; TASK-088 documenta read-back runtime 4 rows / 0 duplicati / current-previous coerenti | PASS | Fresh runtime `TASK090_*` non ripetuto, ma il perimetro ProductPrice richiesto ha evidenza diretta da TASK-088 e regressioni correnti PASS |
| Cross-platform Android -> Supabase -> iOS | Android -> Supabase -> iOS | Prior runtime `TASK087_*`; Android solo riferimento | Catalogo + riferimenti prezzi dove applicabile | TASK-087 documenta MIN-A verified runtime; iOS Release path verificato staticamente/build/test; nessuna patch Android | PARTIAL | Android runtime non rieseguito in TASK-090; nessun nuovo seed/write `TASK090_*` senza gate owner/session |
| Cross-platform iOS -> Supabase -> Android | iOS -> Supabase -> Android | Prior runtime `TASK087_*`/`TASK088_*`; Android solo riferimento | Catalogo + ProductPrice | TASK-087 MIN-I verified runtime; TASK-088 ProductPrice Android reference coerente; iOS ProductPrice push identity test correnti PASS | PARTIAL | Android runtime non rieseguito; nuovo write live `TASK090_*` non autorizzabile senza collision/owner/session |
| Import/export runtime iOS app -> file -> app | iOS local | STATIC + XCTest/fakeable; nessun dataset reale | Products / Suppliers / Categories / ProductPrice | `DatabaseView` export prodotti/full DB/import letto; TASK-089 synthetic export evidence; full XCTest PASS; nessun file cliente usato | PARTIAL | Round-trip UI manuale app -> file -> app non rieseguito in questa execution; scenario ripetibile solo con ulteriore runtime controllato |
| UI truthfulness/copy Release | iOS Release UI | STATIC + localizzazioni | Copy / CTA / summary / a11y labels | `OptionsView`, `SupabaseManualSyncViewModel`, `Localizable.strings` 4 lingue letti; 222 chiavi manualSync per lingua; `plutil` PASS; copy non promette sync completa senza apply/push/pull verificato | PASS | Nessuna patch copy necessaria |
| Retry/idempotenza | iOS/Supabase logic | STATIC + XCTest + prior runtime | Catalog/ProductPrice identity | Fingerprint/stale guards, owner/session guards, deterministic ProductPrice IDs, exact read-back verification, all-or-nothing reconciler; targeted XCTest PASS; TASK-088 secondo push idempotente | PARTIAL | PASS per ProductPrice; PARTIAL per cicli cross-platform completi per assenza di nuovo runtime `TASK090_*` |
| Privacy/anti-distruttivo | Processo/evidenze | STATIC | Evidenze/tracking/comandi | Nessun dato reale fixture; nessun segreto nei file evidence; nessun drop/truncate/delete/reset/wipe/backfill; nessuna patch Kotlin/SQL; nessuna sync automatica introdotta | PASS | Nessuno |

## Costo/beneficio runtime

- Nuovo runtime live `TASK090_*`: beneficio utile ma non superiore al rischio senza owner/session/collision verificati; marcato `Should / BLOCKED_ENV`, non bloccante per passare a review.
- Android runtime: utile come riferimento, ma costoso e fuori target primario iOS; marcato `Optional runtime / PARTIAL`.
- Import/export manuale UI: utile ma non necessario per duplicare TASK-089; marcato `PARTIAL` con follow-up runtime possibile.

