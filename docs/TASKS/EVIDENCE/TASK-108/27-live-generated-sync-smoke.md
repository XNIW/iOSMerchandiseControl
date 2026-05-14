# TASK-108 Evidence 27 — Live Generated Sync Smoke

Status: NOT RUN / BLOCKED_APP_AUTH.

Planned:
- Create/open a Generated sheet with scoped `TASK108_GENERATED_` rows.
- Use the primary guided action `Aggiorna database da questo foglio`.
- Verify preview, local SwiftData apply, quantity/stock, ProductPrice history, HistoryEntry, pending cloud, safe push/read-back, and idempotent second tap.

Actual:
- No authenticated app session was obtained.
- No live Generated push/read-back was executed.
- No scoped Generated test data was created.

Non-live coverage:
- Generated/Inventory tab smoke did not crash: `screenshots/2026-05-13-generated-inventory-smoke-after-fix.jpg`.
- Existing targeted and full XCTest coverage includes Generated local apply/idempotence/pending paths.

