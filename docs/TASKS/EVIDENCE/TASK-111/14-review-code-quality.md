# TASK-111 — Review code quality

**Verdict code review:** PASS AFTER REVIEW FIXES

## Problemi reali trovati

| ID | Severita' | Area | Problema | Fix applicato |
|---|---|---|---|---|
| R111-CQ-01 | High | `DatabaseView` import analysis | Gli errori row-level di `ProductImportCore` venivano rimappati tutti a `barcodeMissing`, perdendo motivi reali come prezzo negativo o retail mancante. | `DatabaseImportRowErrorPayload` ora conserva `reasonKeys`; la UI/export ricevono le cause reali. |
| R111-CQ-02 | High | Localizzazione errori | `ProductImportCore` produceva testi italiani hardcoded per errori visibili all'utente/export. | Errori convertiti a localization keys; `ProductImportRowError.reason` risolve via `L(_)`; aggiunte stringhe EN/IT/ES/ZH. |
| R111-CQ-03 | Medium | Summary import | `DatabaseView` non propagava `totalInputRows`, quindi il riepilogo poteva mostrare righe lette errate nei flussi database. | Aggiunto `totalInputRows` al payload e alla conversione UI. |
| R111-CQ-04 | Medium | Supplier/category resolver | Il riepilogo pending poteva contare come nuovi nomi equivalenti per case/diacritici, mentre il resolver li tratta case-insensitive. | Summary e resolver ora confrontano tramite `ProductImportCore.normalizedRelationKey`. |
| R111-CQ-05 | Low | Copy localizzato | Alcune stringhe IT usavano "warning" e alcune ES mancavano accenti in testi nuovi visibili. | Polish localizzazioni: "Avvisi", "Filas leídas", "Filas válidas", "última", "válidas". |

## Verifiche architetturali

| Controllo | Esito | Note |
|---|---|---|
| SwiftUI / SwiftData boundaries | PASS | Business logic principale resta in `ProductImportCore`; View gestisce stato UI/filtri. |
| No business logic pesante in View | PASS | La review non ha introdotto parsing/apply dentro SwiftUI. |
| Naming coerente | PASS | `reasonKeys`, `normalizedRelationKey`, `totalInputRows` sono coerenti col dominio. |
| Duplicazione inutile | PASS | Riutilizzato resolver core invece di duplicare normalizzazioni stringa. |
| Workaround temporanei | PASS | Nessun flag/debug workaround aggiunto. |
| Supabase coupling | PASS | Nessun coupling nuovo; nessuna mutation; nessun uso service role. |
| Sync impact | PASS | Import locale non modifica il lifecycle sync TASK-109/TASK-110. |
| ModelContext safety | PASS | Apply e resolver restano nei punti esistenti; no uso non sicuro aggiunto. |
| MainActor / freeze risk | PASS | Inizializzatori row error resi `nonisolated`; parser/core resta fuori dalla View. |
| ProductPrice history | PASS | Test idempotenza current/previous PASS. |
| Preview side-effect-free | PASS | Test preview sparse-update PASS; nessun apply implicito in preview. |
| Stringhe hardcoded UI | PASS AFTER FIX | Errori row-level localizzati; localizzazioni lint OK. |

## File modificati dalla review

- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/ProductImportCore.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift`
- `docs/TASKS/EVIDENCE/TASK-111/13-review-preflight.md`
- `docs/TASKS/EVIDENCE/TASK-111/14-review-code-quality.md`
- `docs/TASKS/EVIDENCE/TASK-111/15-review-test-results.md`
- `docs/TASKS/EVIDENCE/TASK-111/16-review-ux-performance.md`
- `docs/TASKS/EVIDENCE/TASK-111/17-review-final-verdict.md`
- `docs/TASKS/TASK-111-excel-analysis-parity-ios.md`
- `docs/MASTER-PLAN.md`

## Non modificati intenzionalmente

- Android: reference-only.
- Supabase: no mutation / no schema / no policy.
- DAO/sync/cloud lifecycle: nessun intervento TASK-111.
