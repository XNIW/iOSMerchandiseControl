# Supabase Store Scope Mode

- status: `PASS`
- task: `TASK-126`
- safety: safe-readonly / privacy-redacted

## Evidence
- Chosen mode: `localDefaultStoreOnly`.
- Reason: remote runtime inventory/prezzo tables do not expose store_id; sync_events has optional store_id only for ledger events.
- TASK-126 does not invent remote columns.
