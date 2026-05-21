# TASK-112 - Audit Offline Conflict Policy

Timestamp: 2026-05-20 20:34 -0400

## Observed

- Tombstone catalog backend blocks post-tombstone update on already tombstoned rows.
- ProductPrice dedupes by effective key.
- Owner boundary RLS protects cross-account remote writes.

## Missing

- Dual offline edit same product deterministic policy.
- Remote tombstone while local offline update waits.
- Conflict UI state `offlineConflictBlocked`.
- Per-domain reason code and retry lane for conflicts.

## Verdict

**mancante/parziale**: backend invariants help, but offline conflict policy is not evidence-backed end-to-end.
