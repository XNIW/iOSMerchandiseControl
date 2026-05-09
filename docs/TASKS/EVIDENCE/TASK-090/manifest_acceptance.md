# TASK-090 manifest acceptance

Timestamp locale: 2026-05-09 17:03 -0400

## Scope

- Target principale: iOS.
- Android: riferimento funzionale/documentale, nessuna patch Kotlin.
- Supabase: schema condiviso verificato solo da filesystem locale; nessuna patch SQL/migration/RLS.
- Namespace runtime previsto: `TASK090_*`.
- Stato namespace in questa execution slice: proposto ma non usato per write live.

## Safety gates

| Gate | Esito | Evidenza |
|------|-------|----------|
| Override utente per EXECUTION | PASS | Prompt utente del 2026-05-09 richiede promozione TASK-090 a EXECUTION. |
| Repo preflight | PASS | Branch `main`, commit `8264c96`, scheme Xcode `iOSMerchandiseControl`. |
| Owner/session live prima di write | BLOCKED_ENV | Non verificati in modo privacy-safe senza aprire runtime mutativo. |
| Collision scan remoto `TASK090_*` | BLOCKED_ENV | Non eseguito: richiederebbe query live/sessione; nessun write cieco. |
| Collision scan codice locale `TASK090_*` | PASS_CANDIDATE | Nessun harness/source iOS `TASK090_*` introdotto; solo docs/evidenze TASK-090. |
| Dati reali come fixture | PASS | Non usati. Solo riferimenti a dataset sintetici/prior task sandbox. |
| Segreti in output | PASS | Nessun token/JWT/refresh/service role/connection string stampato. |
| Operazioni distruttive | PASS | Nessun drop/truncate/delete/reset/wipe/backfill massivo. |
| Sync automatica/background nuova | PASS | Nessuna patch Swift; audit statico su Release manual sync. |

## Decisione runtime

Nuovi scenari live `TASK090_*` sono marcati `BLOCKED_ENV`/`PARTIAL` finche' owner, sessione e collision scan remoto non sono verificabili in modo privacy-safe. La execution procede con evidenze statiche, test locali/fakeable e riuso esplicito delle evidenze runtime gia' documentate in TASK-087/TASK-088.
