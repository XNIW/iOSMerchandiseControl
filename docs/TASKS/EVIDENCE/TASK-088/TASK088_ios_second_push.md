# TASK088 iOS Second Push Idempotence

Data: 2026-05-09 13:10 -0400

## Tipo verifica

- `TEST`: secondo dry-run iOS dopo remote identity link.
- `READ-BACK`: Supabase read-only post runtime.
- Nessun cleanup/delete/truncate/drop/reset/wipe.

## Evidenza test

Il test `testTask088VerifiedPushLinksRemoteIDAcrossReloadAndSecondDryRun` verifica:

| Passo | Valore atteso | Valore osservato |
|---|---:|---:|
| primo dry-run ready candidates | 4 | 4 |
| `remoteID` linkati dopo push verificato | 4 | 4 |
| `remoteID` ancora presenti dopo nuovo `ModelContext` | 4 | 4 |
| secondo dry-run ready candidates | 0 | 0 |

## Evidenza Supabase

Read-back post runtime:

| Metrica | Valore |
|---|---:|
| price rows `TASK088_BAR_PRICE` | 4 |
| duplicate logical keys | 0 |
| price rows labelled `TASK088_*` | 4 |

La chiave logica reale verificata nello schema e nel read-back e':

`owner_user_id + product_id + type + effective_at`

## Nota di confine

Il runner iOS esegue il controllo post-push e il secondo dry-run in container SwiftData isolato; il riepilogo `debugPrint` non e' stato catturato da `simctl launch --console`. La prova primaria di idempotenza locale e' quindi il test mirato; la prova remota e' il conteggio Supabase stabile a 4 righe e 0 duplicati logici.

## Esito

**PASS TEST + READ-BACK remoto**: il secondo push non ha candidati locali dopo identity link; il remote non contiene duplicati logici.
