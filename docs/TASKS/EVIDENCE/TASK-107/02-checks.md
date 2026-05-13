# TASK-107 Checks

## Build
- FINAL REVIEW PASS: iOS Debug build/run via XcodeBuildMCP on iPhone 16e simulator after review fixes, warnings 0.
- FINAL REVIEW PASS: iOS Release simulator build via XcodeBuildMCP after review fixes, warnings 0.
- FINAL REVIEW PASS: Android `./gradlew assembleDebug` in `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`.
- PASS: Debug simulator build via XcodeBuildMCP on iPhone 15 Pro Max simulator.
- PASS: Debug simulator build/run via XcodeBuildMCP on iPhone 15 Pro Max simulator.
- PASS: Release simulator build via XcodeBuildMCP on iPhone 15 Pro Max simulator.
- NOTE: one Release attempt failed before build because `-configuration Release` was passed while the MCP profile already injected a configuration. The profile was then set to Release and the build passed.
- FIX PASS: Debug simulator build after linked-delete and Price history changes, warnings 0.
- FIX PASS: Release simulator build after linked-delete and Price history changes, warnings 0.

## Static Checks
- FINAL REVIEW PASS: iOS `git diff --check`.
- FINAL REVIEW PASS: iOS `plutil -lint` for `it`, `en`, `es`, `zh-Hans` Localizable.strings.
- FINAL REVIEW PASS: iOS localization key consistency: 1289 keys in each localization, 0 duplicates, 0 missing, 0 extra.
- FINAL REVIEW PASS: Android `git diff --check`.
- FINAL REVIEW PASS: Android `xmllint --noout` for `values`, `values-en`, `values-es`, `values-zh` string resources.
- FINAL REVIEW NOTE: Android localized string files are missing only pre-existing `language_endonym_en/es/it/zh` keys relative to default; TASK-107 Price history keys are present in all checked locales.
- PASS: `git diff --check`
- PASS: `plutil -lint` for `it`, `en`, `es`, `zh-Hans` Localizable.strings.
- PASS: Deployment target verified in project settings: `IPHONEOS_DEPLOYMENT_TARGET = 26.1`; no deployment target increase.
- FIX PASS: `git diff --check` after the final pending-change refinement.
- FIX PASS: `plutil -lint` after new localization keys.

## Simulator Smoke
- FINAL REVIEW PASS: Products tab, search/scanner header, product rows, full-card edit, Price history, update current price, and import/export toolbar rechecked.
- FINAL REVIEW PASS: Dynamic Type `extra-large` and `extra-extra-large` rechecked on Database product rows; bottom content remains scrollable above tab bar at end position.
- FINAL REVIEW PASS: Edit product field accessibility labels present for reviewed TextFields.
- FINAL REVIEW PASS: Price history update flow previously verified with synthetic value change: new history row added and current purchase price updated.
- PASS: Database Products section still loads product list.
- PASS: Suppliers section shows existing suppliers and linked product counts.
- PASS: Suppliers search filters rows and clear search returns to the list/empty filtered state.
- PASS: Supplier add, rename, delete confirmation and local-only cleanup tested with synthetic `TASK107 Smoke Supplier`.
- PASS: Categories section shows existing categories and linked product counts.
- PASS: Category add sheet presentation and cancel path verified.
- PASS: Contextual `+` button changes labels: New product / Add supplier / Add category.
- PASS: Import/export toolbar buttons remain available.
- PASS: Dynamic Type `extra-extra-large` quick visual check on Categories list; simulator content size restored to `large`.
- FIX PASS: Edit product shows Price history inside the Prices section.
- FIX PASS: Price history opens from Edit product, shows current price, opens New price sheet, saves a synthetic same-price row, and returns to the history list.
- FIX PASS: Category in use delete presents Replace existing, Create replacement, and Remove assignment options.
- FIX PASS: Category replacement picker, create replacement sheet, and remove-assignment confirmation present correctly; destructive confirmation was not executed on fixture data.
- FIX PASS: Supplier in use delete presents Replace existing, Create replacement, and Remove assignment options.
- FIX PASS: Dynamic Type `extra-extra-large` on supplier delete options keeps text visible; simulator content size restored to `large`.
- MICRO-FIX PASS: Price history action dedup keeps only the contextual `Update current price` button; toolbar `+` removed.
- MICRO-FIX PASS: Debug simulator build via XcodeBuildMCP after dedup, warnings 0.
- MICRO-FIX PASS: Simulator UI hierarchy/screenshot confirms `Update current price` is present and the toolbar `+` action is absent.
- MICRO-FIX PASS: Android parity static check: Android sheet already has a single contextual update action, no Android patch required.

## Privacy
- Evidence uses synthetic TASK106/TASK107 fixture names only.
- No real shop data or sensitive personal data was included.

## Targeted automated tests
- FINAL REVIEW PASS: iOS targeted tests 44/44 across `LocalPendingChangeAccumulatorTests`, `LocalPendingAggregatedPushPlannerTests`, and `SupabaseProductPriceApplyServiceTests`.
- FINAL REVIEW PASS: Android targeted unit test command for Price history parity repository/coordinator slice: `./gradlew testDebugUnitTest --tests "com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest.updateCurrentPriceFromHistory*" --tests "com.example.merchandisecontrolsplitview.data.RealtimeRefreshCoordinatorTest"`.
- FINAL REVIEW NOTE: Android Gradle emitted existing deprecation/configuration warnings for AGP/Kotlin setup; build and tests succeeded.
- FINAL REVIEW NOTE: iOS targeted test build emitted unrelated pre-existing warnings in `Task097RuntimeSmokeTests.swift` and `SyncEventOutboxDrainDebugViewModelTests.swift`; tests passed.
