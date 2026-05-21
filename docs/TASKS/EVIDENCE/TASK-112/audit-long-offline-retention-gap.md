# TASK-112 - Audit Long Offline Retention Gap

Timestamp: 2026-05-20 20:34 -0400

## Observed

- `sync_events` contains ordered ids and expires metadata in Supabase migration logic.
- Android has watermarks and detects gap/too-large states in summary fields.

## Missing

- No verified retention policy query/live evidence.
- No iOS event gap subscriber path.
- No test ensuring exactly one motivated full reconciliation after long offline.
- No cooldown against repeated full reconciliation loop proven.

## Verdict

**mancante/parziale** for CA-61 and scenario 57.
