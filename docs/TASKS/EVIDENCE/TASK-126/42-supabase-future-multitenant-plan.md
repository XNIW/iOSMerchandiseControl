# Supabase Future Multitenant Plan

- status: `PASS`
- task: `TASK-126`
- safety: safe-readonly / privacy-redacted

## Evidence
- Future `remoteStoreAware` requires explicit store_id on runtime inventory/prezzo tables plus RLS/grants audit.
- Rollout must be feature-flagged and keep old clients on localDefaultStoreOnly until migration is complete.
- TASK-126 leaves backend read-only.
