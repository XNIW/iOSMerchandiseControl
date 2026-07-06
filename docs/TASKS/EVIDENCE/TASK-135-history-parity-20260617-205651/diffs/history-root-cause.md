# TASK-135 History Root Cause

Root cause verified statically in iOS:

1. Count parity was weaker than row-level parity.
   - iOS Options local/reconcile count used all non-tombstoned `HistoryEntry` rows.
   - History UI filters non-user-facing technical rows such as `TASK*`.
   - Supabase remote count used all active `shared_sheet_sessions`.

2. History apply lacked a cross-platform logical identity bridge.
   - iOS full pull and incremental drain matched only `remote_id` or local `uid`.
   - Existing fingerprint included `remoteID`, so it could not match the same logical payload when the remote id differed.
   - Result: a row with the same logical History payload but a different remote id could be inserted as a second visible/local row.

3. Pending acknowledgement could remain stale after relinking.
   - `LocalPendingChange` keys are remote-id based.
   - If a local-only session is linked to a remote row with a different id, the previous pending key must be acknowledged too.

Android/Supabase live root cause remains NOT RUN in this environment:

- Android repo/files are not present under `/Users/minxiang/Desktop/iOSMerchandiseControl` or the searched Desktop paths.
- `adb` is unavailable.
- Local Supabase container status is unavailable.

Applied iOS fix:

- Added a logical History fingerprint excluding `remoteID`.
- Full pull and incremental apply now link matching logical sessions instead of inserting duplicates.
- Pending History changes are acknowledged across previous/new remote keys.
- iOS local and remote Options counts now use active user-visible non-tombstoned History sessions.

