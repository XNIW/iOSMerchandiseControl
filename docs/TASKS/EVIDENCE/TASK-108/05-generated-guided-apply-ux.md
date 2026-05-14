# TASK-108 Evidence 05 — Generated Guided Apply UX

Status: EXECUTED (CODE + UNIT), simulator Generated sheet smoke NOT RUN.

Initial finding:
- Generated currently exposes separate product import and inventory apply actions.
- TASK-108 requires one primary guided action: "Aggiorna database da questo foglio".

Result:
- Generated now exposes one primary action: `Aggiorna database da questo foglio`.
- The previous separate actions remain under an advanced disclosure.
- Guided sheet previews new products, updated products, quantity rows, skipped rows and cloud pending availability.
- Unified apply saves the sheet, applies product import changes, applies inventory quantities/prices, updates `HistoryEntry` sync status through `InventorySyncService`, and records local pending changes for product/ProductPrice when an owner is available.
- `InventorySyncService` avoids duplicate ProductPrice insertion on retry when the retail price is unchanged.

Evidence:
- `InventorySyncServiceTests/testGeneratedInventorySyncRecordsPendingAndAvoidsDuplicatePriceOnRetry` PASS.
- Live/offline Generated manual matrix NOT RUN.

FIX/COMPLETION update 2026-05-13:
- `GeneratedView` now marks History/session pending when the sheet payload or sync status changes during save, unified apply, or inventory sync.
- `EntryInfoEditor` marks History/session pending when title/supplier/category metadata changes.
- Full XCTest PASS 659/0; Generated idempotence and pending tests are included.
- Live Generated app-auth push/read-back remains NOT RUN.

Targeted Options cleanup FIX update 2026-05-13 20:45 -0400:
- Generated/Inventory tab smoke after Options cleanup: PASS, no crash.
- Live Generated app-auth push/read-back remains NOT RUN / BLOCKED_APP_AUTH. Evidence: `27-live-generated-sync-smoke.md`.
