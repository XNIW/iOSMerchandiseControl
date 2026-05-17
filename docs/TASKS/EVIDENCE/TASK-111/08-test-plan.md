# TASK-111 — 08 Test Plan / Results

## OBSERVED — Build

- Debug simulator build: PASS, 0 warnings.
  - Log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/MerchandiseControlSplitView-65fd32597f5d/logs/build_sim_2026-05-17T16-48-35-345Z_pid69843_f4df4fbd.log`
- Release simulator build: PASS, 0 warnings.
  - Log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/MerchandiseControlSplitView-65fd32597f5d/logs/build_sim_2026-05-17T16-41-55-366Z_pid69843_cf5ab95a.log`

## OBSERVED — TASK-111 targeted XCTest

- `Task111ExcelImportParityTests`: PASS 7/7, 0 warnings.
  - Covers parser/header/numeric/discount/scientific barcode, duplicates, validations, side-effect-free preview, resolver, ProductPrice history, HTML fixture.
  - Log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/MerchandiseControlSplitView-65fd32597f5d/logs/test_sim_2026-05-17T16-48-04-171Z_pid69843_78784830.log`
  - Result: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/MerchandiseControlSplitView-65fd32597f5d/result-bundles/test_sim_2026-05-17T16-48-04-171Z_pid69843_182964a8.xcresult`

## OBSERVED — Regression

- TASK-105 selected import/export/apply/performance: PASS 4/4, 0 warnings.
  - Log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/MerchandiseControlSplitView-65fd32597f5d/logs/test_sim_2026-05-17T16-39-59-450Z_pid69843_c80a9979.log`
- HTML parser + TASK-100 medium benchmarks: PASS 11/11, 0 warnings.
  - Log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/MerchandiseControlSplitView-65fd32597f5d/logs/test_sim_2026-05-17T16-40-42-415Z_pid69843_8018bf3a.log`

## OBSERVED — Simulator smoke

- Installed and launched `com.niwcyber.iOSMerchandiseControl` on iPhone 17 Pro simulator.
- Home visible and responsive.
- Database tab reachable; list/search/toolbar visible.
- Options tab reachable after tab switch; settings list visible.
- Runtime log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/MerchandiseControlSplitView-65fd32597f5d/logs/com.niwcyber.iOSMerchandiseControl_2026-05-17T16-44-17-820Z_helperpid79028_ownerpid69843_f85d9589.log`

## NOT_RUN

- Full test suite: not run due scope/time; selected import/export/ProductPrice/HTML/performance baselines run.
- Android tests: not run; no Android patch.
- Supabase live tests: not run; no Supabase mutation.
