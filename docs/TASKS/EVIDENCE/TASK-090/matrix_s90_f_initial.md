# TASK-090 S90-F initial matrix

Timestamp locale: 2026-05-09 17:03 -0400

| Scenario | Direzione | Dataset | Oggetti | Evidenza iniziale | Esito iniziale | Stop gate | Runtime costo/beneficio |
|----------|-----------|---------|---------|-------------------|----------------|-----------|-------------------------|
| Catalog pull Supabase -> iOS | Supabase -> iOS | STATIC + prior `TASK087_*`; `TASK090_*` proposto | Supplier / Category / Product | Release factory/viewmodel/pull apply letti; schema catalogo letto | PARTIAL | Owner/session/collision live non verificati | Nuovo runtime Could/Optional: rischio catalogo globale > valore rispetto a test statici/prior smoke |
| ProductPrice current/previous Supabase <-> iOS | Supabase <-> iOS | STATIC + prior `TASK088_*` | ProductPrice purchase/retail current/previous | Schema unique e servizi apply/push/reconciler letti | PARTIAL | Nuovo read-back live non eseguito | Runtime opzionale: prior TASK-088 copre identity/idempotenza con read-back |
| Android -> Supabase -> iOS | Android -> Supabase -> iOS | Prior `TASK087_*` | Catalogo scoped | TASK-087 MIN-A verified runtime scoped | PARTIAL | Android/iOS runtime non riaperti in TASK-090 | Nuovo Android runtime non bloccante: Android e' reference only |
| iOS -> Supabase -> Android | iOS -> Supabase -> Android | Prior `TASK087_*`/`TASK088_*` | Catalogo + ProductPrice | TASK-087 MIN-I verified; TASK-088 Android reference ProductPrice PASS | PARTIAL | Nessun nuovo write live | Nuovo write live non proporzionato senza gate |
| Import/export app -> file -> app | iOS local | Synthetic/local fakeable | Products / ProductPrice / lookup tables | `DatabaseView` export/import letto; TASK-089 export synthetic evidence | PARTIAL | UI round-trip non ancora ripetuto | Test/harness locali preferiti; UI manual runtime Could |
| UI truthfulness/copy Release | iOS Release UI | STATIC | Copy / CTA / summary / accessibility labels | Localizable 4 lingue lette; 222 manualSync keys per lingua | PASS_CANDIDATE | Copy falso o test copy fail -> CHANGES_REQUIRED | Static audit alto valore, basso rischio |
| Retry/idempotenza | iOS/Supabase logic | STATIC + XCTest | Catalog/ProductPrice | stale guards/fingerprint/deterministic IDs/read-back verification letti | PARTIAL | Test finale non ancora eseguiti | Test locali mirati alto valore; live retry optional |
| Privacy/anti-distruttivo | Processo | STATIC | Evidence/log/tracking | Nessun segreto, nessun dato reale, nessuna mutazione | PASS_CANDIDATE | Qualsiasi segreto/dump/write cieco -> BLOCKED | Static/process evidence sufficiente |
