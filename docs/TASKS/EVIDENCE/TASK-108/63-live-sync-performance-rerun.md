# TASK-108 — Live sync performance rerun

Date: 2026-05-14 14:24 -0400  
Executor: Codex

## Stato

PARTIAL / NOT FULL LIVE.

Il fix di responsiveness e' stato applicato, ma il nuovo full live app-auth post-patch richiesto non e' stato completato in questo pass: dopo rebuild la app iOS e' in stato signed-out e non ho un test account/OAuth umano da completare.

## Numeri disponibili

### iOS

| Metrica | Valore |
|---|---:|
| Debug build/run | PASS, 12.966 s, warning 0 |
| Release simulator build | PASS |
| Idle RSS post-run | 330,288 KB |
| Idle CPU post-run | 0.0% |
| Options scroll smoke signed-out | PASS |
| Full ProductPrice live precedente | 290,955 remote, 290,953 linked/apply, 2 tombstoned skipped |
| Durata full live precedente | ~25m50s |
| Peak RSS full live precedente | ~3.5 GB osservato |

### Android

| Metrica | Valore |
|---|---:|
| `assembleDebug` | PASS, 14 s |
| ProductPrice paging test | PASS, 8 s |
| installDebug | PASS, 7 s |
| Device launch | PASS, OnePlus IN2013 |
| TOTAL PSS | 182,569 KB |
| TOTAL RSS | 281,960 KB |

## Checkpoint richiesti full iOS

| Checkpoint | Esito |
|---|---|
| 0 | NOT RUN in full live post-patch |
| 9,000 | NOT RUN in full live post-patch |
| 53,000 | NOT RUN in full live post-patch |
| 90,000 | NOT RUN in full live post-patch |
| 150,000 | NOT RUN in full live post-patch |
| completion | NOT RUN in full live post-patch |

## Conclusione

Non dichiaro speedup live. Il miglioramento e' dimostrato staticamente/build/smoke e dai nuovi timing hooks; serve run app-auth firmato per misurare durata/RSS peak post-patch.

