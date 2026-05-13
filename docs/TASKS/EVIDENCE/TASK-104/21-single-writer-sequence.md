# Single Writer Sequence

Status: `PASS_WITH_NOTES`

## Protocol

TASK-104 requires one writer and one reader during each real round-trip:

| Direction | Writer | Reader | Status |
|-----------|--------|--------|--------|
| iOS to Supabase to Android | iOS | Android | PASS2 synthetic live sequence executed; see below. |
| Android to Supabase to iOS | Android | iOS | PASS2 synthetic live sequence executed; see below. |

## Guard

- Do not edit the same sentinel on both clients during one cycle.
- Do not push/apply if baseline is stale.
- Do not treat a retry as safe until read-back confirms the expected delta.
- Record the temporal sequence before moving to the next mutation.

## Result

The protocol is documented and no concurrent mutation occurred. The criterion is `PASS` for realistic synthetic PASS2 sequencing; real user data remains outside this verdict.
## PASS 2 Single-Writer Sequences

iOS -> Supabase -> Android:

1. pre-read collision scan: prefix free.
2. mutate on iOS only.
3. push using authenticated iOS session.
4. remote read-back on iOS.
5. Android pull/read.
6. post-check: Room detail true; no second writer mutation.

Android -> Supabase -> iOS:

1. Android auth preflight after sign-in.
2. mutate on Android only.
3. push using authenticated Android session.
4. remote read-back on Android.
5. iOS pull/read.
6. post-check: inserted catalog 1, inserted prices 4, no-op true.
