# TASK-111 — 07 Performance / Stability Plan

## OBSERVED

- `ExcelSessionViewModel` loads via `Task.detached` and checks cancellation on file reads.
- `DatabaseImportPipeline.prepareProductsImport` runs in `Task.detached`.
- `DatabaseImportPipeline.applyImportAnalysisInBackground` runs in `Task.detached`.
- Apply progress is throttled and saves in batches of 250.
- TASK-100 medium import benchmark PASS after patch.
- TASK-105 large import performance band PASS after patch.
- Release simulator build PASS with 0 warnings.

## INFERRED

- The new parser is string-local and does not add row-by-row MainActor publication.
- Memory remains bounded by existing dataRows/analysis model; no additional global cache/singleton introduced.
- ImportAnalysis UI preview limit remains capped by existing `previewItemLimit` / `previewErrorLimit`.

## NOT_RUN

- Instruments memory trace not run.
- ETTrace not run.
- Manual cancel under active file import not run.

## Risk controls

- Keep ProductImportCore pure/nonisolated.
- Keep SwiftUI rows thin.
- Keep apply through existing background pipeline and SwiftData context.
