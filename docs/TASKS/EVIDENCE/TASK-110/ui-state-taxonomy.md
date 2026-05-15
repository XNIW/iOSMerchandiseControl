# TASK-110 — UI State Taxonomy

Checkpoint: 2026-05-15 12:15 -0400.

## Tassonomia target

| Stato | Significato | Colore target |
|---|---|---|
| Signed out | Nessuna sessione auth stabile | grigio/info |
| Ready | Auth OK e nessun lavoro pending | verde/info |
| Syncing | Sync in corso | blu |
| Pending | Modifiche locali in attesa | arancione |
| Partial | Sync completato con skip/deferred non bloccanti | arancione |
| Permission issue | 42501/RLS/grant denied | rosso |
| Offline | Network assente o endpoint non raggiungibile | arancione/grigio |
| Cancelled | Annullamento utente reale | grigio |
| Error | Errore non classificato | rosso |

## Regole
- `Cancelled` solo per cancel utente o `CancellationError` reale.
- `no_auth`, `42501`, RLS e network non devono diventare "Operation cancelled".
- Sync now disabilitato durante sync.
- Mostrare fase corrente: Catalog, Prices, History, Push pending, Confirm pull.
- Dettagli tecnici solo in disclosure/log.

## Stato al checkpoint
- iOS ha mapping service per permission/RLS, ma UI da verificare/raffinare.
- Android Material state taxonomy da verificare/raffinare.
