# TASK-110 regression check

Date: 2026-05-15 15:04 -0400

## Result
- ⚠️ PASS_WITH_NOTES — targeted regression checks passed; broad manual app regression remains pending until P8 rerun.

## Checked
- ✅ PASS — iOS build after auth fix.
- ✅ PASS — iOS auth session restore after stop/launch.
- ✅ PASS — iOS History sync service tests.
- ✅ PASS — Android targeted History/tombstone repository tests.
- ✅ PASS — Supabase grants/RLS/tombstone smoke from final-review preflight.
- ✅ PASS — no diff whitespace issues in iOS/Android.

## Not yet rerun
- ❌ CHANGES_REQUIRED — import/export Excel.
- ❌ CHANGES_REQUIRED — scanner barcode.
- ❌ CHANGES_REQUIRED — full Options/History/Database manual cross-platform regression.
- ❌ CHANGES_REQUIRED — full ProductPrice/catalog bidirectional update live.

## Decision
- Keep TASK-110 in FIX until the remaining runtime matrix/regression is executed.

