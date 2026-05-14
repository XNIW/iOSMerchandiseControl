# TASK-108 Evidence 47 — iOS/Android Performance Final Snapshot

Timestamp: 2026-05-14 12:34 -0400.

Status: **iOS ProductPrice performance measured live; Android not rerun signed-in in this focused pass**.

## iOS Live Result

| Metric | iOS result |
| --- | ---: |
| Remote ProductPrice total | 290,955 |
| Page size | 900 |
| Remote-linked ProductPrice applied/linked | 290,953 |
| Explicit tombstoned skips | 2 |
| Total local ProductPrice rows | 328,589 |
| Baseline records | 20,012 |
| Approx duration | ~25m 50s |
| Peak observed RSS | ~3.5 GB |
| UI responsiveness | Scroll remained responsive |
| Crash/freeze | None observed |

## Android Comparison

Android was used as architectural reference in earlier TASK-108 passes:
- ProductPrice paging pattern is page-based and bounded.
- Local database status card was aligned previously.

Android was **not** rerun signed-in for this final ProductPrice-focused fix. Therefore no fresh Android timing is claimed here.

## Performance Verdict

- iOS correctness: PASS for full ProductPrice keyset/apply and baseline.
- iOS stability: PASS on simulator, no crash.
- iOS performance: ACCEPTABLE FOR VALIDATION, but memory-heavy.
- Android parity timing: NOT UPDATED in this focused pass.

Recommended follow-up:
- Move iOS ProductPrice full bootstrap to a private/bounded SwiftData context or chunked importer that releases inserted objects between pages.
