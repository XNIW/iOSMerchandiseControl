# TASK-107 Price History Action Dedup

## Decision
Kept the contextual `Update current price` action inside the current-price card and removed the toolbar `+` action.

## Screenshot
- `11-fix-price-history-action-dedup.jpg`

## Rationale
- The contextual action is closer to the value being changed, so it is clearer for users.
- Removing the toolbar `+` avoids two controls opening the same add/update price flow.
- The sheet keeps the standard close button and native Form flow for saving the new price.

## Cross-Platform Note
Android already uses a single contextual update action in the Price history sheet after the parity patch, so no Android code change was required for this micro-fix.

## Checks
- PASS: `git diff --check`
- PASS: `plutil -lint` localizations
- PASS: Debug simulator build via XcodeBuildMCP, warnings 0
- PASS: Simulator UI hierarchy/screenshot confirms `Update current price` is present and the toolbar `+` action is absent.

## Final review addendum - 2026-05-13
- PASS: iOS final targeted tests 44/44 after pending-state stability fix.
- PASS: Android targeted repository/coordinator unit slice and `assembleDebug`.
- PASS: Android parity still has one contextual update action and no duplicate toolbar add action.
