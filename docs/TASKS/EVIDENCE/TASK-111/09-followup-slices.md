# TASK-111 — 09 Follow-up Slices

## OBSERVED — No blocker follow-up for REVIEW

- No P0/Critical blocker remains from local parser/import/apply parity evidence.

## P1 Follow-up candidates

- Add a committed minimal `.xls` legacy fixture or generate one in a controlled helper if tooling is approved.
- Add file-level duplicate-header warning model if reviewer wants visible diagnostics beyond safe first non-empty handling.
- Add explicit cancel XCTest/harness for large file import.
- Add SwiftData transaction/recovery note in user-facing import failure copy if needed after review.

## P2 Follow-up candidates

- Hidden columns/filtered rows style semantics.
- Formula error cell diagnostics.
- Dynamic Type and VoiceOver manual pass with screenshots.
- Full end-to-end Files picker import smoke on device/simulator with temporary workbook.

## Supabase follow-up boundary

- Do not fold TASK-109 sync lifecycle into TASK-111. Any live cloud mutation should be a dedicated gated follow-up with `TASK111_*` data only.
