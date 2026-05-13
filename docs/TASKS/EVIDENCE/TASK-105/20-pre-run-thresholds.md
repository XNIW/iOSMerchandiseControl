# TASK-105 Evidence 20 - Pre-Run Thresholds

| Area | Soglia | Risultato | Stato |
|------|--------|-----------|-------|
| Small import | 25...250 righe o fixture equivalente | Fixture 30 righe con errori/duplicati | PASS |
| Large import | >= 5.000 righe | 5.000 prodotti | PASS |
| Parse/analyze large | <= 60s | Sotto soglia nel test mirato | PASS |
| Export integrity | File > 0 e riapribile | Riaperto e confrontato | PASS |
| Freeze apparente | Nessun blocco >2s senza feedback | Parsing off MainActor; smoke simulator senza blocchi osservati | PASS_WITH_NOTES |
| Privacy scan | 0 leak confermati | Nessun leak TASK-105 confermato | PASS |
| UX-P0 | 0 aperti | 0 | PASS |
| UX-P1 | 0 aperti non accettati | 0, scanner fallback corretto | PASS |
| Build | Exit 0 | Release simulator build exit 0 | PASS |

## Stato

PASS_WITH_NOTES: le soglie tecniche principali sono rispettate; alcune verifiche operative reali restano manuali.
