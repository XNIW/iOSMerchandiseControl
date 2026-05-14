# TASK-108 Evidence 19 — Generated Sync Parity

Status: PARTIAL PASS (CODE + UNIT), live/manual matrix NOT RUN.

Initial audit:
- Product import analysis can create pending catalog/ProductPrice changes.
- Inventory apply currently updates SwiftData/History status but does not consistently enqueue pending cloud changes for product/price/history/session.

Result:
- Primary guided action implemented.
- Product import + inventory apply are composed into one flow.
- ProductPrice history insertion is idempotent on same-price retry.
- Product/ProductPrice local pending created when owner account is available.
- HistoryEntry sync status remains updated by `InventorySyncService`.

Blocked/remaining:
- History/session cloud pending for generated entries requires Wave 6 backend/entity support.
- Offline/retry/second-tap simulator matrix not run beyond unit idempotence.

FIX/COMPLETION update 2026-05-13:
- History/session cloud pending for generated entries is now implemented in iOS using `LocalPendingChange.EntityKind.historySession`.
- `GeneratedView` marks history pending on save/unified apply/sync when the payload changes.
- `HistorySessionSyncServiceTests` and `InventorySyncServiceTests` passed in the targeted and full suites.
- Offline/retry/second-tap manual UI matrix remains partly covered by unit idempotence, not live manual smoke.

Targeted Options cleanup FIX update 2026-05-13 20:45 -0400:
- Generated/Inventory tab smoke after cleanup did not crash and still presents the file/manual inventory entry points.
- Live Generated sync remains NOT RUN / BLOCKED_APP_AUTH. Evidence: `27-live-generated-sync-smoke.md`.
