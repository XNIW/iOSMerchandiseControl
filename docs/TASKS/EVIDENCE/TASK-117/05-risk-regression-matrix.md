# 05 - Risk / Regression Matrix

| Area | Risk | Required future evidence |
|---|---|---|
| Excel import/export/share XLSX | Sync cleanup breaks import/export flows or share sheet state. | iOS regression tests and smoke evidence. |
| PreGenerate and Generated flow | Pending changes not recorded or generated rows drift. | Import/generate targeted tests. |
| Database CRUD | Product/supplier/category CRUD stops recording pending/outbox. | CRUD regression tests. |
| Supplier/category CRUD | Lookup creation/delete and local pending semantics regress. | Supplier/category targeted tests. |
| ProductPrice current/previous/history | Current/previous price parity or identity linking regresses. | ProductPrice apply/push tests. |
| History entries/session sync | History dedupe/tombstone/visibility regresses. | History session tests and UI smoke. |
| Scanner/barcode search | Scanner fallback or barcode search route breaks. | Simulator/manual smoke where available. |
| Options UI and root banner | Spinner 0/0, duplicate CTA, stale "Up to date", bad auth state. | Options smoke, l10n, Dynamic Type/VoiceOver. |
| Auth sign-in/out/session restore | Account-bound state or session restore breaks. | Auth preflight and simulator/device gates. |
| Pending/outbox local mutations | Cross-account leakage or ack/retry regression. | Owner-bound outbox tests. |
| `sync_events` realtime drain | Realtime event no longer drains or loops. | Near-realtime live gate. |
| Offline reconnect | Reconnect misses pending push/drain or full-pulls wrongly. | Offline reconnect live gate. |
| Account switch/store identity | Wrong store or wrong owner mutation. | Account matrix A-L. |
| Localization IT/EN/ES/ZH | New copy missing or stale. | `scan l10n-sync-keys` plus plutil/l10n tests. |
| Large dataset/performance | MainActor-heavy apply or memory growth. | SwiftData/MainActor scan, performance budget. |
| Operator UX | Manual untracked commands or noisy logs. | Harness reports with NEXT_ACTION and evidence scan. |

## Critical no-notes gates
`PASS_WITH_NOTES` is forbidden for HEAD consistency, no-legacy-runtime-path, no-full-pull-normal-path, account matrix, physical iPhone, near-realtime, offline reconnect, cleanup/residue, sensitive scan, Debug/Release builds and iOS sync tests.
