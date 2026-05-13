# TASK-106 Design Decision

## Selected option
**C - Hybrid**.

## Why not A only
The pre-TASK-102 layout was simpler, but a direct restore would discard useful recent work around empty states, accessibility containment, delete handling context, and the TASK-105 scanner fallback focus behavior.

## Why not B only
A pure micro-fix on top of the current layout would leave the underlying row hierarchy too dependent on trailing chips and cramped metadata. The row needed a cleaner iOS-native structure, not only spacing tweaks.

## Implemented shape
- Keep the existing screen structure, data flow, sheets, toolbar actions, and localized labels.
- Replace the row's ad hoc trailing chip layout with a local `DatabaseProductRow`.
- Use `ViewThatFits` for responsive horizontal-to-vertical adaptation instead of hardcoded device thresholds.
- Use iOS grouped list/background styling and row insets instead of custom safe-area math.
- Make editing card-level: the visible `Edit` button was removed because the entire product card opens the edit sheet.
- Move `Price history` into the price/stock metric area so it remains logically close to price information while not dominating the card.
- Review feedback refinement: show supplier/category names directly, keep barcode and item code inline, keep prices below the title, reduce the search-to-list gap, and use a compact plain scanner button instead of a heavy bordered control.
- Dynamic Type refinement: metric labels and the history control keep their natural word width; when the row cannot fit, `ViewThatFits` drops to a vertical arrangement instead of compressing labels into broken words.

## Compatibility choice
The deployment target is iOS 26.1, so the SwiftUI APIs used here are within target. No availability gates or target changes were needed.
