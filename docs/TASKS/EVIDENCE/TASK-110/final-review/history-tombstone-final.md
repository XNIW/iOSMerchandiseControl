# TASK-110 History/tombstone final

Date: 2026-05-15 15:04 -0400

## Result
- ✅ PASS — service-level tombstone handling and dirty-local guard verified.
- ❌ CHANGES_REQUIRED — live UI bidirectional delete propagation still pending in P8 matrix after iOS app-auth fix.

## Verified
- ✅ PASS — Supabase tombstone column/grants/RLS smoke.
- ✅ PASS — iOS `HistorySessionSyncServiceTests` passed after adding dirty-local tombstone protection.
- ✅ PASS — Android `DefaultInventoryRepositoryTest` targeted tombstone guard passed.
- ✅ PASS — synchronized tombstones are hidden from normal History lists; pending deletes remain visible with a pending/deleted state from earlier fix-completion work.

## Remaining
- Rerun live Android create/delete -> sync -> iOS hidden active/tombstone observed.
- Rerun live iOS create/delete -> sync -> Android hidden active/tombstone observed.

