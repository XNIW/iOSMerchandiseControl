# TASK-090 — Retry e idempotenza

Timestamp locale: 2026-05-09 17:10 -0400

## Risultato

| Area | Esito | Evidenza |
|------|-------|----------|
| ProductPrice push/apply/reconciler | PASS | Deterministic ID namespace, exact read-back, all-or-nothing `ProductPriceManualPushIdentityReconciler`, test mirati PASS, TASK-088 secondo push idempotente |
| Catalog apply/push guards | PARTIAL | Fingerprint/staged-plan guards e owner/session recheck verificati staticamente; nuovo runtime `TASK090_*` non eseguito |
| Cross-platform retry completo | PARTIAL | TASK-087 prior runtime copre smoke bidirezionale; nessun retry fresh Android/iOS live in TASK-090 |

## Invarianti verificati staticamente

- Staged plan fingerprint ricontrollato prima di apply/push.
- Owner/session mismatch blocca operazioni mutative.
- ProductPrice apply blocca conflitti, duplicate logical rows e mapping ambiguo.
- ProductPrice manual push verifica read-back exact-match prima della riconciliazione locale.
- Riconciliazione `remoteID` e' fail-closed e all-or-nothing.

## Stop gate

Un retry live `TASK090_*` non e' stato eseguito perche' richiederebbe owner/session/collision scan DB immediati. Scenario mantenuto `PARTIAL`, non promosso a PASS narrativo.

