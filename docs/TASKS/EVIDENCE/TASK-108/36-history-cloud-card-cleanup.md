# TASK-108 Evidence 36 — History Cloud Card Cleanup

Date: 2026-05-14 00:38 -0400

Scope:
- Remove public History-only `Send` / `Download` actions from the primary History user path.
- Keep History visibility read-only and point the operator to the global Options `Sync now` flow.
- Verify that Options sees dirty History/session work as part of global pending work.

iOS changes verified:
- `HistoryView` no longer exposes public push/pull buttons for cloud History.
- The History cloud card is read-only and shows one of these user-facing states: signed-out hint, unavailable, pending local History changes, last synced time, or “will sync with Sync now”.
- Empty History still shows the read-only cloud status card.
- Dirty local History entries are counted by `LocalPendingChangeSnapshotProvider` even when no `LocalPendingChange` row exists yet, so Options review no longer hides pending History/session work.
- EN/IT/ES/ZH localizations were updated for the read-only status and Options sync hint.

Simulator evidence:
- ✅ SIM — History showed `Cronologia cloud`, pending local History count, and the hint to use `Sincronizza ora` from Options.
- ✅ SIM — No public `Send` / `Download` buttons were visible on History.
- ✅ SIM — Options showed a single public `Sincronizza ora` action.
- ✅ SIM — Options pending summary changed from “no local changes” to `elementi locali in attesa: 2` after the snapshot provider fix.

Static checks:
- ✅ STATIC — History-only button handlers `pushHistorySessions()` / `pullHistorySessions()` were removed from `HistoryView`.
- ✅ STATIC — `history.cloud.push` / `history.cloud.pull` localization keys are no longer used by the public History UI.
- ✅ TEST — Added `SupabaseManualSyncLocalPendingSnapshotProviderTests.testDirtyHistoryEntriesAreReportedAsQueuedCloudOperationsWithoutPendingRows`.

Verdict:
- PASS for the UX cleanup requirement.
- `Send` / `Download` are no longer public primary History actions.
- History is now represented as part of the global cloud synchronization surface instead of a separate primary sync path.

