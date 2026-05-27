# TASK-127 Evidence 06 - Scanner Fixtures RED/GREEN Plan

Date: 2026-05-27

Fixture directory:

- `tools/agent/fixtures/task127_scanners/`

Fixtures added:

- RED: `red_options_view_unscoped_pending_query.swift`
- RED: `red_productprice_fetch_filter_mainactor.swift`
- RED: `red_refreshall_no_debounce.swift`
- RED: `red_debug_hook_release_string.swift`
- GREEN: `green_background_summary_service.swift`
- GREEN: `green_debounced_presenter.swift`
- GREEN: `green_debug_only_probe.swift`

Validation:

- `./tools/agent/mc-agent.sh scan scanner-self-tests --task TASK-127 --strict`: PASS

