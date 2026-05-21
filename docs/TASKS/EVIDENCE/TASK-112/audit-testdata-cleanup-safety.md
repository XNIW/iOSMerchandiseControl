# TASK-112 - Audit Testdata Cleanup Safety

Timestamp: 2026-05-20 20:34 -0400

## Policy

- Prefissi consentiti: `TASK112_*`, `TASK112_OFFLINE_*`.
- Nessun truncate/drop/reset globale.
- Nessun cleanup non filtrato per owner/prefisso.
- Nessun token/JWT/email raw in evidence.
- Nessuna mutation Supabase in audit iniziale.

## Stato ambiente

| Check | Stato | Evidenza |
|---|---|---|
| Supabase local Docker | bloccato | `supabase status` fallisce per Docker daemon non raggiungibile. |
| Live data operations | bloccato | Non eseguite in audit. |
| Cleanup scoped | parziale | Policy definita; nessun dato creato da pulire. |

## Cleanup plan se live viene eseguito

1. Usare owner test autenticato dal client, mai service_role nel client.
2. Creare nomi/barcode/note con prefisso `TASK112_YYYYMMDD_` o `TASK112_OFFLINE_`.
3. Read-back scoped per owner + prefisso.
4. Cleanup solo su prefisso creato dal test, registrando conteggi prima/dopo.
5. Se cleanup non e' verificabile, documentare retention esplicita.

## Verdict

**GO_WITH_SAFETY_NOTES**: audit sicuro; live mutation rimane bloccata finche' non esiste sessione/account test e read-back verificabile.
