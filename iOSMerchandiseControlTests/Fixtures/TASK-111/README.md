# TASK-111 Fixtures

OBSERVED:
- Runtime-generated XLSX fixtures are covered by `Task111ExcelImportParityTests`, `Task105RealOpsClosureTests`, and `Task100LargeDatasetAcceptanceTests`.
- Static HTML colspan/rowspan coverage is retained by `ExcelAnalyzerHTMLParsingTests` and the TASK-036 HTML fixtures.

ASSUMED:
- Binary `.xlsx` / `.xls` fixtures are intentionally not committed in this slice to keep the fixture pack privacy-safe and lightweight; tests generate synthetic workbooks where binary coverage is needed.

NOT_RUN:
- No real shop workbook was retained or committed for TASK-111.
