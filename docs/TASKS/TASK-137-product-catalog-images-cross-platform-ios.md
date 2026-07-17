# TASK-137: Product Catalog Images cross-platform (iOS)

## Informazioni generali

- **Task ID**: TASK-137
- **Titolo**: Product Catalog Images cross-platform (iOS)
- **File task**: `docs/TASKS/TASK-137-product-catalog-images-cross-platform-ios.md`
- **Stato**: REVIEW_WITH_BLOCKERS
- **Fase attuale**: REVIEW
- **Responsabile attuale**: CLAUDE/CHATGPT_REVIEWER
- **Data creazione**: 2026-07-16
- **Ultimo aggiornamento**: 2026-07-17
- **Ultimo agente che ha operato**: CODEX
- **Contratto canonico**:
  `/Users/minxiang/Projects/merchandise-control-admin-web/docs/TASKS/TASK-137-product-catalog-images-cross-platform.md`
- **Evidence**: `docs/TASKS/EVIDENCE/TASK-137/README.md`

## Dipendenze

- TASK-136 resta `DONE` storico e non viene riaperto.
- TASK-088 resta `REVIEW_WITH_ENVIRONMENTAL_PERFORMANCE_BLOCKER` nel repository
  canonico Admin e non viene riaperto.
- Schema/API TASK-137 devono essere implementati e verificati prima della lane
  Swift.
- Win7POS e esplicitamente escluso.

## Scopo

Integrare su iOS una sola immagine primaria versionata per prodotto usando il
contratto backend congelato: picker JPEG/PNG/HEIC, normalizzazione e JPEG
main/thumb nativi, intent/upload diretto/finalize, URL di lettura effimero,
cache offline account/shop scoped e sync incrementale del solo UUID versione.

## Non incluso

- gallery, video, crop editor, originale, OCR/AI o immagini Excel;
- blob/Base64/path Storage/signed URL/token in SwiftData, outbox o sync event;
- service role o secret nell'app;
- nuove dipendenze senza blocker dimostrato;
- refactor generale sync/UI;
- force push, release/deploy production o modifiche Win7POS; commit e push
  restano vincolati ai gate del consolidamento finale.

## Superficie iOS congelata

- `docs/MASTER-PLAN.md`, questo task ed evidence TASK-137;
- `Models.swift` e mapping DTO/apply soltanto per UUID versione e timestamp
  opzionali;
- nuovo gruppo `iOSMerchandiseControl/ProductImages/` per preprocess, API,
  upload e cache;
- `DatabaseView.swift`, `EditProductView.swift` e wiring minimo prodotto;
- `Localizable.strings` en/it/es/zh-Hans;
- test XCTest mirati TASK-137.

Ogni file aggiuntivo deve essere motivato nell'Execution ledger canonico prima
della modifica. I diff iOS preesistenti, inclusi DatabaseView e sync TASK-088,
devono essere preservati.

## Vincoli iOS

- input JPEG/PNG e HEIC/HEIF quando prodotto dal picker; output sempre JPEG;
- orientamento normalizzato nei pixel, metadata EXIF/GPS rimossi;
- main lato lungo max 1600 px, thumb max 384 px, mai upscale, budget/quality
  definiti dal contratto canonico;
- cache key `(account, shop, product UUID, version UUID, variant)` e nessuna
  lettura cross-account/cross-shop;
- upload richiede rete e non entra nella normale outbox;
- edit prodotto puo riuscire anche se upload immagine fallisce;
- finalize/remove riusano `catalog_changed`, senza full pull;
- owner/manager write; viewer/cashier/revoked/cross-shop negati dal server;
- nessun claim parity fisica basato solo sul Simulator.

## Criteri di accettazione

- [x] Il DTO/apply persiste solo `primary_image_version_id` e timestamp.
- [x] Duplicate/no-op/stale/checkpoint/tombstone/offline-reconnect/account switch
  restano corretti e idempotenti.
- [x] JPEG/PNG/HEIC vengono normalizzati nei due budget senza metadata/upscale.
- [x] Intent, due PUT diretti, finalize, read URL e remove rispettano il
  contratto API senza persistenza di URL/token.
- [x] Thumbnail/lista e main/dettaglio hanno placeholder, loading/error e cache
  offline isolata.
- [x] Upload fallito non annulla una modifica prodotto gia valida.
- [x] XCTest mirati, test apply/sync, build Debug Simulator, localizzazioni e
  `git diff --check` passano realmente.
- [x] Runtime non-production e cleanup vengono registrati senza claim fisico
  improprio.

## Decisioni

| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|---|---|---|---|
| 1 | Apple PhotosUI/ImageIO/CoreGraphics/URLSession. | Libreria immagini nuova. | Primitive native sufficienti e superficie minima. | attiva |
| 2 | UUID versione opzionale sul Product locale. | URL/path o blob persistito. | Sync/cache versionati senza secret o byte nel dominio. | attiva |
| 3 | Backend prima della lane Swift. | Mockare un contratto mobile divergente. | Il contratto cross-platform e gia congelato. | attiva |

## Execution

### Obiettivo compreso

Implementare soltanto la lane iOS del contratto TASK-137 dopo il gate backend,
preservando i diff esistenti e gli invarianti sync.

### Stato corrente

- mapping DTO/apply, PhotosPicker/camera, processor, API, cache e UI
  implementati con framework Apple gia disponibili;
- suite finale Product Images `22/22`, sync esistenti `46/46`, localizzazioni
  `8/8` e build Debug baseline `PASS`;
- metriche e riepiloghi xcresult copiati in evidence durevole;
- consolidamento Mac: signed URL vincolate all'origin Supabase configurato;
  read/download e remove coperti dinamicamente; remove fail-closed su stato e
  versione prima di azzerare riferimento o cache; commit locali `629eb8e8`
  runtime/UI e `4b89c7d2` test;
- blocker review: nessun workflow iOS contro Supabase locale/staging reale e
  nessun device fisico; non viene dichiarata parity live.

### Handoff -> Review

- **Prossima fase**: REVIEW_WITH_BLOCKERS; harness mobile auth live separato.
- **Prossimo agente**: CLAUDE/Reviewer.
- **Azione consigliata**: verificare contratto, sicurezza, parity funzionale,
  evidence e assenza di claim production/physical impropri.
