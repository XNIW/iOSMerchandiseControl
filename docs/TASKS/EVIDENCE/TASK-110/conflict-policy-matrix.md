# TASK-110 — Conflict Policy Matrix

Checkpoint: 2026-05-15 12:15 -0400.

| Locale | Remoto | Azione target | Note |
|---|---|---|---|
| missing | active | pull | remote-only diventa local |
| active clean | missing | verify/push idempotente | caso Android stale-clean osservato |
| active dirty | missing | push | assegna/usa remote_id stabile |
| active clean | active newer | pull | cache locale aggiornata |
| active dirty | active clean | push | dirty local vince |
| active dirty | active dirty/newer | conflict esplicito | per TASK-110: last-write-wins solo se documentato e loggato |
| deleted pending | active/missing | push tombstone | richiede `deleted_at` History |
| active clean | tombstone | apply delete/hide | non mostrare come sessione attiva |
| dirty local | tombstone remoto | conflict | non skip infinito; loggare |

## Decisione execution iniziale
- Per History Android stale-clean remoto missing: push idempotente durante full reconciliation.
- Per delete History: schema attuale blocca tombstone; serve migration minima o policy alternativa documentata.
