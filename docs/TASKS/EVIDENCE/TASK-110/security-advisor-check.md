# TASK-110 — Security Advisor Check

Checkpoint: 2026-05-15 12:15 -0400.

Comando eseguito:
`supabase db advisors --linked --type security --level warn -o json`

## Findings

| Level | Name | Oggetto | Valutazione TASK-110 |
|---|---|---|---|
| WARN | security definer executable by authenticated | `public.record_sync_event(...)` | RPC intenzionale per insert sync_events; mantiene validazione owner con `auth.uid()`. Da tenere sotto review perché `SECURITY DEFINER` callable da auth. |
| WARN | `auth_leaked_password_protection` | Auth | Fuori scope TASK-110 client sync, ma da segnalare come hardening. |

## Nessun finding critico immediato
- Nessun `ERROR` bloccante rilevato dal Security Advisor al checkpoint.
- Resta criticità manuale non evidenziata come fatal: grants anon legacy su `shared_sheet_sessions` e `product_prices`.
