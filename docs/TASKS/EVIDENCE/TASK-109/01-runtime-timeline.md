# TASK-109 — 01 Runtime Timeline

Data run: 2026-05-15 00:36-00:40 -0400  
Build/run: Debug via XcodeBuildMCP, scheme `iOSMerchandiseControl`  
Simulator: iPhone 15 Pro Max iOS 26.1 (`459C668B-7CE8-443B-BAB3-7D3D5FFC9143`)  
Build HEAD: `48a6956a80ae6fdb8d205359ac78147ad1ac4b78` + worktree dirty preesistente registrato in `00-preflight-tracking.md`

## Artefatti

- Build log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/build_run_sim_2026-05-15T04-36-58-723Z_pid23201_dbebce53.log`
- Runtime log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/com.niwcyber.iOSMerchandiseControl_2026-05-15T04-37-14-851Z_helperpid25969_ownerpid23201_748505d1.log`
- OS log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/com.niwcyber.iOSMerchandiseControl_oslog_2026-05-15T04-37-15-916Z_helperpid26009_ownerpid23201_e7ae91bd.log`
- Video: `docs/TASKS/EVIDENCE/TASK-109/wave1-runtime-smoke.mp4`
- Screenshots: `docs/TASKS/EVIDENCE/TASK-109/screenshots/`

## Timeline osservata

| Tempo relativo | Evento | Evidence | Note |
|---:|---|---|---|
| T+0s | App lanciata da cold stop/build-run su Inventory | XcodeBuildMCP `build_run_sim` | Sessione app gia' signed-in nel simulatore. |
| T+~0-4s | Root foreground check avviato senza entrare in Options | runtime log | `InventorySnapshot start/done`, poi `PullPreview summary`. |
| T+~3.0s | Snapshot locale completato | runtime log | `products=19695 suppliers=57 categories=27 prices=41109`, `elapsedMs=3038`. |
| T+~4s | Pull preview completata | runtime log | `signals=true`, `failure=none`, `new=0 updates=0 conflicts=0 tombstones=0 warnings=1`, `remotePrices=1000` preview sample. |
| T+15s+ | Inventory ancora aperta, root banner visibile | `screenshots/02-cold-launch-inventory-no-options.jpg` | Banner: `Cloud updates are ready to review`; quindi baseline corrente NON richiede Options per primo check. |
| T+~85s | Options aperta dopo root check | `screenshots/03-options-sync-card-history-count.jpg` | Card mostra lo stesso esito utente (`There are changes to review`) e `Sync now`; non ho osservato nuovo log di preview post-Options. |
| T+~100s | Tap `Sync now` | `screenshots/04-sync-now-after-tap.jpg` | Si apre Review con `Device already updated` e CTA primaria `Recheck`: bug UX/stale/no-op riprodotto. |
| T+~110s | Tap `Cancel` su review | `screenshots/05-after-cancel-review.jpg` | App mostra dialog annidato `Cancel this review?` con pulsante `Cancel`: bug UX cancel annidato riprodotto. |
| T+~120s | Conferma Cancel dialog | `screenshots/05-cancel-review-dialog-after-button.jpg` | Stato torna a `No local changes to send`; nessun `Try again` esposto, `Sync now` resta disponibile. |
| T+~130s | History tab | `screenshots/06-history-tab.jpg` | UI vuota: `No history`. |

## Log privacy-safe disponibile

```text
[InventorySnapshot] start products=19695 suppliers=57 categories=27 prices=41109
[InventorySnapshot] done elapsedMs=3038 products=19695 suppliers=57 categories=27 prices=41109
[PullPreview] summary complete=true partial=false signals=true failure=none remoteProducts=19695 remoteSuppliers=57 remoteCategories=27 remotePrices=1000 new=0 updates=0 conflicts=0 tombstones=0 warnings=1 sourceErrors=0 supplierDiffs=0 categoryDiffs=0 priceSignals=0
```

## Lacune osservabilita'

- `operationID`: non esposto nei log del dry-run/root preview corrente; per Wave 1 ho solo l'equivalente parziale da stato UI + runtime log.
- `source`: inferito da scenario e codice (`rootForeground` per cold launch; `optionsCard`/sheet per Review), non stampato nel log runtime.
- `ownerHash`: non stampato dal client; UI redige l'email (`x***@gmail.com`).
- `selectedTab`: inferito da screenshot e UI automation, non loggato.
- `allowsCancel`: visibile indirettamente da UI (`Cancel` nella review), non loggato per operation.

## Root cause preliminare

Classificazione Wave 1 sul build corrente:

- Options-scoped trigger: **non riprodotto come causa primaria corrente**. Il root check parte da Inventory senza Options.
- Auth hydrate race: **non riprodotta** nel run corrente; sessione gia' signed-in.
- Single-flight/operation identity: **osservabilita' insufficiente**. Non c'e' operationID condiviso visibile nei log/superfici; Options conserva comunque un trigger `onAppear` staticamente presente.
- Review stale/no-op: **riprodotto**. `Sync now` apre review con `Device already updated` e CTA primaria `Recheck`.
- Cancellation UX: **riprodotto**. Cancel review produce dialog annidato `Cancel this review?` con ulteriore `Cancel`.
- History saltata/non salvata/UI stale: **non dimostrabile con remoto corrente** perche' `shared_sheet_sessions` dev risulta `0`; SwiftData/Options/History sono coerentemente `0`.
