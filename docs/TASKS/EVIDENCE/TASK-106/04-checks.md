# TASK-106 Checks

Legend:
- `STATIC`: source/config inspection.
- `BUILD`: Xcode/MCP build.
- `SIM`: simulator interaction/screenshot/UI hierarchy.
- `MANUAL`: manual simulator smoke through visible UI.

## Required checks
- ✅ ESEGUITO - REVIEW/BUILD - Final review Debug build/run on iPhone 16e simulator PASS after review fixes; MCP diagnostics reported no warnings/errors.
- ✅ ESEGUITO - REVIEW/BUILD - Final review Release simulator build PASS after review fixes; MCP diagnostics reported no warnings/errors.
- ✅ ESEGUITO - REVIEW/TEST - Targeted iOS tests PASS after stability fix: 44/44 passed across `LocalPendingChangeAccumulatorTests`, `LocalPendingAggregatedPushPlannerTests`, and `SupabaseProductPriceApplyServiceTests`.
- ✅ ESEGUITO - REVIEW/STATIC - Final `git diff --check` PASS after review fixes and Android parity checks.
- ✅ ESEGUITO - REVIEW/STATIC - Final `plutil -lint` PASS for `it`, `en`, `es`, `zh-Hans` Localizable.strings.
- ✅ ESEGUITO - REVIEW/STATIC - Final iOS localization key consistency PASS: 1289 keys in each localization, 0 duplicates, 0 missing, 0 extra.
- ✅ ESEGUITO - REVIEW/SIM - Final Dynamic Type `extra-large` and `extra-extra-large` checked on Database product list; bottom row remains scrollable above tab bar at the end position.
- ✅ ESEGUITO - REVIEW/SIM - Accessibility minimum check: scanner target 48x44, `Price history` target 132x44 in visible hierarchy, explicit form text-field labels added for reviewed fields.
- ✅ ESEGUITO - BUILD - Debug build/run on iPhone 15 Pro Max iOS 26.1 PASS after patch; MCP diagnostics reported no warnings/errors.
- ✅ ESEGUITO - BUILD - Debug build/run on iPhone 15 Pro Max iOS 26.1 PASS after latest compact-card review fix; MCP diagnostics reported no warnings/errors.
- ✅ ESEGUITO - BUILD - Debug build/run on iPhone 16e class simulator PASS for small-device layout smoke; MCP diagnostics reported no warnings/errors.
- ✅ ESEGUITO - BUILD - Release build on iPhone 15 Pro Max iOS 26.1 PASS; MCP diagnostics reported no warnings/errors.
- ✅ ESEGUITO - STATIC - `git diff --check` PASS before tracking/evidence finalization; final pass repeated after markdown updates.
- ✅ ESEGUITO - STATIC - Deployment target confirmed as `IPHONEOS_DEPLOYMENT_TARGET = 26.1`; target was not raised.
- ✅ ESEGUITO - STATIC - `ContentView.swift` checked for TabView/NavigationStack/safe-area cause; no change needed.
- ✅ ESEGUITO - STATIC - `DatabaseView.swift` checked for scope: UI-only changes, no SwiftData/Supabase/import-export business logic changes.
- ✅ ESEGUITO - SIM/MANUAL - Empty Database state visible before data creation; screenshot saved as `01-before-current-database.png`.
- ✅ ESEGUITO - SIM/MANUAL - Populated Database state verified with three synthetic rows; screenshot saved as `03-after-fixed-database.png`.
- ✅ ESEGUITO - SIM/MANUAL - Review fix visual spacing verified: search/scanner header sits closer to the first product card without appearing attached.
- ✅ ESEGUITO - SIM/MANUAL - Review fix scanner button verified: compact 48x44 control, lighter grouped background, no heavy bordered halo.
- ✅ ESEGUITO - SIM/MANUAL - Compact-card review fix verified: visible `Edit` button removed, whole product card tap opens `Edit product`, and `Price history` appears next to the metrics row.
- ✅ ESEGUITO - SIM/MANUAL - Search filtering verified with query `Short`; list filtered to the matching synthetic row.
- ✅ ESEGUITO - SIM/MANUAL - Clear search verified; full synthetic list returned and search field remained usable.
- ✅ ESEGUITO - SIM/MANUAL - Scanner presentation/fallback verified: camera permission denial screen appeared, manual fallback returned focus to search, typed `TASK106`; rerun after scanner button restyle confirmed `Product scanner` sheet and `Enter manually` fallback.
- ✅ ESEGUITO - SIM/MANUAL - Edit product verified: `Edit product` sheet opened from full-card tap after the visible `Edit` button removal.
- ✅ ESEGUITO - SIM/MANUAL - Price history verified: relocated metric-row `Price history` control opened the sheet and showed a purchase entry for the synthetic product.
- ✅ ESEGUITO - SIM/MANUAL - Import menu verified: import popover opened with Excel, full database, and CSV options; dismissed without importing.
- ✅ ESEGUITO - SIM/MANUAL - Export menu verified: export popover opened with product/full database options; dismissed without exporting.
- ✅ ESEGUITO - SIM/MANUAL - Scroll to last row verified on iPhone 15 Pro Max and iPhone 16e class simulator; final row/action remains scrollable above tab bar.
- ✅ ESEGUITO - SIM/MANUAL - Dynamic Type default (`large`) verified.
- ✅ ESEGUITO - SIM/MANUAL - Dynamic Type larger (`extra-extra-large`) verified; row wraps and remains scrollable, and metric/history labels are not split mid-word or vertically clipped. Screenshot saved as `03-after-fixed-database-dynamic-type-large.png`.
- ✅ ESEGUITO - SIM/MANUAL - Safe area/tab bar verified on large and small simulators.
- ✅ ESEGUITO - SIM/MANUAL - Synthetic row variants verified: short name, long name, long/short barcode, long/short item code inline with barcode, long supplier/category without prefixes, prices present/missing, stock zero/non-zero.
- ✅ ESEGUITO - STATIC - Performance/scope review PASS: no custom layout engine, no new fetches/services, no repeated heavy work added to row/body.
- ⚠️ NON ESEGUIBILE - AUTOMATED UI TEST - No dedicated automated UI test target exists for TASK-106 Database layout. Coverage for this UI-only regression is build + simulator smoke + static review.

## Notes
- A first Release build invocation was rejected by tooling because `-configuration` was passed twice; the valid Release build was rerun with the session configuration and passed.
- All screenshots/evidence use empty state or synthetic `TASK106` data only.
- Final targeted test run initially exposed a deterministic crash in `LocalPendingAggregatedPushPlannerTests.testStateTransitionsAreBatchScoped()` during `LocalPendingAggregatedPushStateStore` deallocation. The store was identity-less and had no mutable reference semantics, so it was converted to a `struct`; rerun passed 44/44.
- Warnings reported by the final targeted test run are pre-existing warnings in unrelated test files (`Task097RuntimeSmokeTests.swift`, `SyncEventOutboxDrainDebugViewModelTests.swift`) and were not introduced by TASK-106/107 review fixes.
