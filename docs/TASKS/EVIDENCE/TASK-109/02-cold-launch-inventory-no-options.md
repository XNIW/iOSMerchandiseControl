# TASK-109 — 02 Cold Launch Inventory / No Options

Scenario: cold launch signed-in partendo da Inventory/Home, senza aprire Options per almeno 10-15 secondi.

## Esito

Il bug originale "non parte auto-check finche' non apro Options" **non si riproduce** sul worktree corrente.

Evidence:

- Screenshot: `screenshots/02-cold-launch-inventory-no-options.jpg`
- Runtime log:

```text
[InventorySnapshot] start products=19695 suppliers=57 categories=27 prices=41109
[InventorySnapshot] done elapsedMs=3038 products=19695 suppliers=57 categories=27 prices=41109
[PullPreview] summary complete=true partial=false signals=true failure=none remoteProducts=19695 remoteSuppliers=57 remoteCategories=27 remotePrices=1000 new=0 updates=0 conflicts=0 tombstones=0 warnings=1 sourceErrors=0 supplierDiffs=0 categoryDiffs=0 priceSignals=0
```

## UI osservata

- Tab iniziale: Inventory.
- Banner root visibile prima di aprire Options.
- Copy banner: `Cloud updates are ready to review`; dettaglio `Updates are ready to review`; CTA `Review`.
- L'app resta interattiva; nessun overlay modale bloccante.

## Log schema

| Campo | Valore |
|---|---|
| timestamp | 2026-05-15 00:37 -0400 circa |
| operationID | non disponibile nei log preview |
| source | `rootForeground` inferito |
| ownerHash | non disponibile; UI redatta `x***@gmail.com` |
| phase | snapshot locale -> pull preview -> review-ready |
| isBusy | non loggato; UI interattiva |
| selectedTab | Inventory |
| allowsCancel | non applicabile in banner root |
| reason | remote preview con signals/warnings |
| domain | catalog/prices preview; history non loggata |
| counts | local `19695/57/27/41109`; remote preview `19695/57/27/1000(sample)` |

## Nota baseline

Questa prova gira sul worktree dirty registrato in `00-preflight-tracking.md`; quindi non prova il comportamento di `origin/main` pulito, ma prova il runtime corrente oggetto di execution.
