# TASK-109 — 05 Cancel / Retry State

Scenario: osservare cancel/retry dopo la Review aperta da `Sync now`.

## Esito

Bug riprodotto: Cancel e' annidato e usa copy ambiguo.

Evidence:

- Review prima del cancel: `screenshots/04-sync-now-after-tap.jpg`
- Dialog post Cancel: `screenshots/05-after-cancel-review.jpg`
- Stato dopo conferma: `screenshots/05-cancel-review-dialog-after-button.jpg`
- Video: `wave1-runtime-smoke.mp4`

## UI osservata

1. La Review ha azione secondaria `Cancel`.
2. Tap su `Cancel` apre un dialog sopra la sheet:
   - Titolo: `Cancel this review?`
   - Messaggio: `The prepared summary will be discarded. You can run a new check.`
   - Pulsante unico visibile: `Cancel`
3. Dopo il secondo tap, la sheet sparisce e la card torna a:
   - `No local changes to send`
   - `You can run Check cloud again whenever you want.`
   - CTA `Sync now`

## Valutazione rispetto TASK-109

- Doppio Cancel: **FAIL riprodotto**.
- Cancel review come sync failure: non riprodotto in questo run; dopo conferma non appare `Operation cancelled`.
- Try again: non esposto; il recupero e' tramite `Sync now`, quindi non ho potuto verificare `Try again`.
- Retry sticky: non osservato come deadlock; stato card torna idle-ish con CTA attiva.

## Log schema

| Campo | Valore |
|---|---|
| timestamp | 2026-05-15 00:40 -0400 |
| operationID | non disponibile |
| source | review cancel |
| ownerHash | non disponibile; UI redatta |
| phase | review dismiss -> idle/no-local-changes |
| isBusy | false dopo dismiss |
| selectedTab | Options |
| allowsCancel | review cancel disponibile; secondo dialog annidato |
| reason | user dismissed review |
| domain | review summary only |
| counts | invariati: products `19695`, suppliers `57`, categories `27`, prices `41109`, history `0` |
