# TASK-109 — 41 Performance / UX Evidence

Date: 2026-05-15

## Observed runtime timeline

Final app-auth smoke:

- app launch on Inventory: root UI responsive;
- auto check scheduled without Options;
- root banner visible only while job is active;
- Options tab navigation remains usable during/after sync;
- manual Sync now progress did not block local database scrolling;
- warning-only/no-action result settles to normal manual card state.

Runtime log sample:

```text
[PullPreview] summary complete=true partial=false signals=true failure=none remoteProducts=19695 remoteSuppliers=57 remoteCategories=27 remotePrices=1000 new=0 updates=0 conflicts=0 tombstones=0 warnings=1 sourceErrors=0 supplierDiffs=0 categoryDiffs=0 priceSignals=0
```

## Performance-relevant checks

- ProductPrice preview remains bounded (`remotePrices=1000` sample) and no longer forces Review.
- Options local status uses count summaries, including History count; final UI shows `Products 19695`, `Suppliers 57`, `Categories 27`, `Price history 41109`, `History sessions 0`.
- Targeted XCTest slice includes large ProductPrice apply/paging tests and passed.
- No Debug/Release build warnings were emitted by the final builds.

## UX cleanup confirmed

- Options no longer starts foreground auto-check on appear/active.
- `Cancel` in Review no longer opens a nested "Cancel this review?" dialog.
- Warning-only/no-op sync does not show stale Review.
- Root and Options no longer disagree by showing Review for ProductPrice preview warnings.
