# TASK-132 Counts Before

Status: NOT_RUN

No Supabase live query or device-local count extraction was executed in this pass. The repository now contains read-only audit SQL at:

- `scripts/supabase/task132_audit_test_residue.sql`
- `scripts/supabase/task132_cleanup_test_residue_DRY_RUN.sql`

Required manual/live checks remain:

| Check | Status |
|---|---|
| iOS Products equals Supabase | NOT_RUN |
| Android Products equals Supabase | NOT_RUN |
| iOS Suppliers equals Android/Supabase | NOT_RUN |
| iOS Categories equals Android/Supabase | NOT_RUN |
| TASK% in suppliers/categories cloud | NOT_RUN |
| TASK% in iOS suppliers/categories | NOT_RUN |
| TASK% in Android suppliers/categories | NOT_RUN |
