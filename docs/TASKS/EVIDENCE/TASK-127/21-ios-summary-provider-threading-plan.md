# TASK-127 Evidence 21 - Summary Provider Threading Plan

`OptionsSyncSummaryProvider` remains `@MainActor` for SwiftUI state publication, but expensive work is no longer run directly from `OptionsView` entry callbacks. Refresh is scheduled through a cancellable `Task`, debounced, and coalesced while in flight. Count work uses SwiftData count queries rather than full object materialization.

