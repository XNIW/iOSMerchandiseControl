# TASK-110 — ProductPrice Incremental Plan

Checkpoint: 2026-05-15 12:15 -0400.

## Stato osservato
- Supabase/iOS product prices: 41109.
- Android product prices: 39498.
- Delta Android mancante: 1611.
- Android product refs: 19695, allineati al count products remoto.

## Root cause probabile
- `pullProductPricesFromRemote` salta righe se il product remote ref non è collegato localmente.
- Run storici possono avere eseguito price pull prima del bridge catalogo o con bridge incompleto.
- Il pull attuale è paginato per id ma full scan: non è incrementale per `updated_at`/watermark.

## Piano minimo
1. Garantire in ogni full sync: catalog pull + bridge realign prima di prices.
2. Classificare `pricesSkippedNoProductRef` con esempi redatti e conteggio.
3. Evitare skip infinito: se bridge mancante, marcare deferred e riprovare dopo bridge realign.
4. Non introdurre full pull cieco ripetuto come soluzione definitiva; usare paging stabile e checkpoint quando schema/eventi lo permettono.

## Stato implementazione
- Non patchato in questa execution: i counts dimostrano drift Android prices (39498 vs 41109) ma il fix completo richiede una seconda iterazione sul bridge/catalog price pipeline.
- La patch applicata chiude la root cause History clean-stale; ProductPrice resta rischio residuo documentato per review.
