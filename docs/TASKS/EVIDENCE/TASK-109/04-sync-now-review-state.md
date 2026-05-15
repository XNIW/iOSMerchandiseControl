# TASK-109 — 04 Sync Now / Review State

Scenario: premere `Sync now` da Options dopo il root check.

## Esito

Bug riprodotto: `Sync now` apre una Review incoerente/stale/no-op.

Evidence:

- Screenshot: `screenshots/04-sync-now-after-tap.jpg`
- Video: `wave1-runtime-smoke.mp4`

## UI osservata

Sheet:

- Titolo: `Review cloud changes`
- Sottotitolo: `Check what may change before updating this device.`
- Sezioni visibili: `Needs review`, `Attention`, `From cloud to device`
- Testo contraddittorio: `Device already updated.`
- CTA primaria: `Recheck`
- Azione secondaria: `Cancel`

## Valutazione rispetto TASK-109

- No-op/review stale: **FAIL riprodotto**. La sheet presenta review/needs-review ma contiene `Device already updated`.
- CTA: **FAIL riprodotto**. `Recheck` e' primaria in una review che dichiara cambi da rivedere.
- `Sync now` fresh operationID: **non verificabile**. Nessun operationID/log correlabile esposto.

## Log schema

| Campo | Valore |
|---|---|
| timestamp | 2026-05-15 00:39 -0400 |
| operationID | non disponibile |
| source | `manualSyncNow` inferito da tap CTA |
| ownerHash | non disponibile; UI redatta |
| phase | review sheet/stale summary |
| isBusy | card CTA disabilitata mentre sheet aperta |
| selectedTab | Options |
| allowsCancel | review dismiss/cancel disponibile |
| reason | stale/no-op review presentation |
| domain | catalog/prices/history summary non separata nella sheet |
| counts | nessun count reale applicabile mostrato nella sheet; local count History `0` in Options |
