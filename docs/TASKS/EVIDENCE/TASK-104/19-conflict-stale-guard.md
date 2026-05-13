# Conflict Stale Guard

Status: `PASS`

## Evidence Available

- iOS manual sync and ProductPrice targeted tests passed.
- Existing release-flow tests cover stale/conflict behavior at code level.
- No real shop round-trip or sentinel mismatch test was executed.

## Required Real-Run Guard

Every future mutation must follow:

1. pre-read sentinels;
2. mutate on exactly one writer client;
3. push/sync;
4. remote read-back;
5. other-client pull/read;
6. post-check against the expected delta.

If owner/session, current/previous, pending/outbox, or remote/local state is ambiguous, the mutation stops and the result becomes at least `PARTIAL`.

## PASS 1 Verdict Impact

In PASS 1, CA-104-34 was `PARTIAL` and CA-104-37 was `BLOCKED` because no full temporal sequence was executed.
## PASS 2 Update

Conflict/stale behavior passed:

- Catalog stale baseline path produced stale preview and recovery action `recheck`.
- Missing/auth recovery path produced action `signInAgain`.
- ProductPrice same logical key with different price produced conflict count 1 and ready count 0.
- Remote state was verified unchanged after blocked/conflict path.
- No silent overwrite occurred.
