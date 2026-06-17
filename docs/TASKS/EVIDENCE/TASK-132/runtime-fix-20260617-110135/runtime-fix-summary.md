# TASK-132 Runtime Fix Summary

## PASS

- iOS signed-in reopen no-push: Supabase `sync_events` stayed `1979 -> 1979`.
- Android signed-in reopen after fix no-push: Supabase `sync_events` stayed `1980 -> 1980`.
- Android first failure reproduced: pre-fix reopen inserted history event id `3035`.
- Android history fix verified: after fix no new history event, history push logs `sessionsAttempted=0`.
- Android catalog guard refined: foreground/network/login push paths blocked; local mutation path still allowed only with usable baseline and real pending work.
- Android targeted tests PASS.
- Android `assembleDebug` + `lintDebug` PASS.
- iOS and Android `git diff --check` PASS.
- Supabase cleanup dry-run PASS.

## BLOCKED

- Supabase cleanup apply not executed: live deletion requires explicit COMMIT approval.
- iOS local store remains contaminated: suppliers `193` vs Supabase `59`, categories `162` vs Supabase `28`, local `TASK%` suppliers/categories `134/134`.
- Android local store still has small residue: suppliers/categories `TASK%` `2/2`.
- Cross-platform clean mutation sync was not executed because baseline parity is not clean and cleanup/reset is not approved.

## Current Counts

| surface | products | suppliers | categories | product_prices |
|---|---:|---:|---:|---:|
| Supabase | 19696 | 59 | 28 | 41111 |
| iOS simulator | 19891 | 193 | 162 | 41524 |
| Android emulator | 19698 | 61 | 30 | 41115 |

