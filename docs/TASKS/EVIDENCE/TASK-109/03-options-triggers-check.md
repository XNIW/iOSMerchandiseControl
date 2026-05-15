# TASK-109 — 03 Options Trigger / Acceleration Check

Scenario: aprire Options dopo aver lasciato Inventory senza Options e verificare se Options avvia o accelera il check.

## Esito

Nel run corrente Options **non e' necessaria** per avviare il primo check: il root banner e i log sono gia' presenti prima di entrare in Options.

Evidence:

- Prima di Options: `screenshots/02-cold-launch-inventory-no-options.jpg`
- Options top: `screenshots/03-options-top-after-open.jpg`
- Options sync card: `screenshots/03-options-sync-card-history-count.jpg`
- Runtime log: nessuna nuova riga `InventorySnapshot`/`PullPreview` osservata dopo apertura Options; il log contiene solo il root preview iniziale.

## UI osservata in Options

- Card cloud: `There are changes to review`
- Stato: `Updates are ready to review`
- Last check: `items on the cloud need review`
- CTA: `Sync now`
- Local database status include `History sessions, 0`

## Rischio statico ancora presente

Lettura codice pre-patch:

- `SupabaseManualSyncForegroundRootHost` avvia `startForegroundSemiAutomaticCheckIfAllowed(source: .rootForeground)`.
- `SupabaseManualSyncReleaseCard` conserva `startSemiAutomaticCheckIfNeeded()` su `onAppear`, che dopo delay chiama `viewModel.startForegroundSemiAutomaticCheckIfAllowed()` con source default `.releaseCard`.

Quindi il sintomo "Options come acceleratore" non e' riprodotto nel run corrente, ma il coupling Options/onAppear resta parte dell'audit implementativo per Gate 2.

## Log schema

| Campo | Valore |
|---|---|
| timestamp | 2026-05-15 00:38-00:39 -0400 |
| operationID | non disponibile |
| source | root gia' completato; Options source non evidenziato nei log |
| ownerHash | non disponibile; UI redatta |
| phase | review-ready/no new preview log |
| isBusy | non loggato |
| selectedTab | Options |
| allowsCancel | false per card idle/review-ready |
| reason | root preview precedente gia' aveva `signals=true` |
| domain | catalog/prices; history count locale |
| counts | Options local: products `19695`, suppliers `57`, categories `27`, prices `41109`, history `0` |
