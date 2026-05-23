# 01 - HEAD / Raw Consistency Audit

## Verdict
`HEAD_CONSISTENCY_PASS`

TASK-117 may remain `ACTIVE / PLANNING`. No `PLANNING-BLOCKED_HEAD_MISMATCH` was found in this planning audit.

If any future source differs, set task state to `ACTIVE / PLANNING-BLOCKED_HEAD_MISMATCH` and add `HEAD_CONSISTENCY_RECHECK_REQUIRED`.

## Branch / commit sources
| Source | Value | Result |
|---|---|---|
| `git rev-parse HEAD` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` | match |
| `git rev-parse origin/main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` | match |
| `git ls-remote origin main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` | match |
| GitHub API `commits/main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` | match |
| GitHub rendered `commits/main` latest short SHA | `e14b433` | match |

## File consistency
| File | Raw HTTP | Rendered HTTP | `git show HEAD:<path>` SHA256 | Raw SHA256 | Match | Rendered sentinel |
|---|---:|---:|---|---|---|---|
| `iOSMerchandiseControl/ContentView.swift` | 200 | 200 | `3b9870192c5742c1025912c8df0fd73819e4ef38eaa82501e69a72be306e62cc` | `3b9870192c5742c1025912c8df0fd73819e4ef38eaa82501e69a72be306e62cc` | yes | yes |
| `iOSMerchandiseControl/Sync/SyncOrchestrator.swift` | 200 | 200 | `95e9985948b21708569ee31bd2aea7c9c9a0d85ddfa8aa96a313eb6a43de2330` | `95e9985948b21708569ee31bd2aea7c9c9a0d85ddfa8aa96a313eb6a43de2330` | yes | yes |
| `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift` | 200 | 200 | `d2c0646b264a5521b71a1e7f1b6bad6d8aeeac1a5a96fb8f85fcc98d4579dbc2` | `d2c0646b264a5521b71a1e7f1b6bad6d8aeeac1a5a96fb8f85fcc98d4579dbc2` | yes | yes |
| `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift` | 200 | 200 | `69eb751d93db745d7fda4f52a5019a74e7a328a02d1dee4c4aaf563fd2b82909` | `69eb751d93db745d7fda4f52a5019a74e7a328a02d1dee4c4aaf563fd2b82909` | yes | yes |
| `iOSMerchandiseControl/Sync/SupabaseManualSyncCompatibilityAdapter.swift` | 200 | 200 | `d06884ba1405268a28df8f407b5126668a006f0cbc9ec05a557510234db77675` | `d06884ba1405268a28df8f407b5126668a006f0cbc9ec05a557510234db77675` | yes | yes |
| `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift` | 200 | 200 | `38d9057b9c0c771a7a3f400df06bc1861451f4808d5a597ef1eab51c576e324e` | `38d9057b9c0c771a7a3f400df06bc1861451f4808d5a597ef1eab51c576e324e` | yes | yes |
| `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift` | 200 | 200 | `ba62a073fa4c63bab0522331ec831f4e4c1afc0fe9277005eb4161cc2b7afa0e` | `ba62a073fa4c63bab0522331ec831f4e4c1afc0fe9277005eb4161cc2b7afa0e` | yes | yes |
| `iOSMerchandiseControl/SupabaseSyncEventIncrementalApplyService.swift` | 200 | 200 | `bdba14a1f082d97c25b7701fc86553d5f13ad16e55d22d62584a4434e84078dd` | `bdba14a1f082d97c25b7701fc86553d5f13ad16e55d22d62584a4434e84078dd` | yes | yes |

## Required future behavior
HEAD consistency is a critical gate. It cannot be `PASS_WITH_NOTES`. If raw, rendered, local, origin or API values diverge, execution must stop before any code or harness change.
