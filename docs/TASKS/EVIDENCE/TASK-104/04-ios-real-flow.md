# iOS Real Flow

Status: `PASS_WITH_NOTES`

## PASS 1 Executed

- Release simulator build/run: PASS.
- Release physical iPhone build: PASS.
- Release physical iPhone install: PASS.
- Release physical iPhone launch: PASS.
- Targeted XCTest suites for Supabase config/security, ProductPrice push/apply, manual sync, release UI, and TASK-103 cross-platform regression: PASS, with expected live-gated skips.
- Import/export analyzer benchmark tests on synthetic fixtures: PASS.

## PASS 1 Not Executed

- Real shop Excel import from file provider.
- PreGenerate to Generated on a real file.
- Real row edit/save/history.
- Real scanner/fallback acceptance.
- Real iOS database product/price mutation.
- Real Supabase push/read-back.

## Reason

The execution did not have safe operator-selected real files, backup/rollback confirmation, sentinels, or authenticated owner/session proof. Mutating real shop data without those gates would violate TASK-104 stop conditions.
## PASS 2 Update

Executed on authenticated physical iOS device with run prefix `TASK104_PASS2_20260512_214804_`.

- Auth preflight: PASS.
- Collision scan: PASS, prefix free before writes.
- iOS write smoke: PASS, catalog sentinel and four ProductPrice rows inserted; no-op replan true.
- Small import/export: PASS, 50 synthetic rows imported, 102 ProductPrice rows inserted, remote read-back 50 products, export spot-check true.
- Conflict/stale guard: PASS, stale catalog preview and ProductPrice same-key/different-price conflict failed closed; remote unchanged true.
- Offline/retry: PASS, failed-before-write then retry completed; remote product count 1; no duplicate; no-op true.
- iOS pull of Android sentinel: PASS, inserted one catalog product and four prices; no-op true.
- Residue scan: PASS, 55 products, 114 prices, no duplicate active barcode, retained for review.

UI note: this pass validated the service/model/live sync path, not a full manual operator tap-through of PreGenerate/Generated/History.
