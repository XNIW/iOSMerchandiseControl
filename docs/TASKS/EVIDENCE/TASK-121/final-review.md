# TASK-121 final independent review

Review date: 2026-05-24 17:21 -0400.

Verdict: `TASK-121 ACTIVE / FIX — CHANGES_REQUIRED`.

Do not mark DONE. Do not use `ARCHITECTURE_TARGET_MET` as the current verdict.

## Reviewed SHA

- local `HEAD`: `a7564857128d08d4e15eaf0977617fbd8a91806a`
- `origin/main`: `a7564857128d08d4e15eaf0977617fbd8a91806a`
- GitHub canonical `main`: `a7564857128d08d4e15eaf0977617fbd8a91806a`
- architecture code commit referenced by earlier evidence: `2ac8cb02587657307a0ec136e8153f6ee29808a2`

The SHA mismatch in prior evidence is explained but still blocks approval of the old certification wording: `2ac8cb0...` is the historical architecture commit; `a756485...` is current canonical HEAD and contains later evidence/tracking alignment.

## GitHub/local alignment

PASS for repository alignment:
- `git fetch origin main`: PASS.
- `git rev-parse HEAD`, `git rev-parse origin/main`, and `git ls-remote origin refs/heads/main`: all `a7564857128d08d4e15eaf0977617fbd8a91806a`.
- `git branch --show-current`: `main`.
- `git ls-tree` and Python urllib no-cache raw checks confirm old root `iOSMerchandiseControl/SupabaseInventoryService.swift` is absent/404 and `Sync/Remote/SupabaseTransportClient.swift` plus Remote adapters are present/200.

CHANGES_REQUIRED remains because alignment does not prove the architecture target.

## Files reviewed

Core/runtime:
- `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift`
- `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRetryPolicy.swift`
- `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift`
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`
- `iOSMerchandiseControl/Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift`

Remote:
- `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`
- `iOSMerchandiseControl/Sync/Remote/CatalogRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/HistorySessionRemoteSupabaseAdapter.swift`
- `iOSMerchandiseControl/Sync/Remote/SyncEventRemoteSupabaseAdapter.swift`

Manual/Recovery/Outbox:
- `iOSMerchandiseControl/Sync/Manual/SupabaseProductPricePreviewService.swift`
- `iOSMerchandiseControl/Sync/Manual/SupabaseProductPricePushDryRunService.swift`
- `iOSMerchandiseControl/Sync/Manual/SupabasePushPreflightViewModel.swift`
- `iOSMerchandiseControl/Sync/Manual/SupabaseSyncEventPreviewService.swift`
- `iOSMerchandiseControl/Sync/Recovery/InventorySyncService.swift`
- `iOSMerchandiseControl/Sync/Recovery/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewModels.swift`
- `iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxDrainService.swift`
- `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxEnqueueService.swift`

Harness:
- `tools/agent/lib/task121_scans.py`
- `tools/agent/mc-agent.sh`
- `tools/agent/lib/supabase.sh`
- `tools/agent/mcp/server.mjs`

## Architecture findings

P1 blocker: `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift` is still a renamed mega-service, not a thin transport/client. It is 1866 lines and owns catalog, product price, history session, sync event, manual preview/dry-run, reconciliation, insert/update helpers, and `TASK087`/`TASK088` debug hooks.

P1 blocker: Remote adapters exist but are mostly pass-through wrappers over `SupabaseTransportClient`. They do not yet own the domain-specific Supabase behavior required by the target architecture.

PASS: root forbidden files are 0 locally and on GitHub canonical. `iOSMerchandiseControl/SupabaseInventoryService.swift` root is gone and there are no root+moved duplicates.

PASS: `AutomaticSyncRuntimeFacade` is a real facade, not a typealias; `SyncAutomaticRuntime.swift` is a zero-behavior marker.

PASS: busy retry ownership is in Automatic core retry policy/engine; no `retry_after_sync_busy` sleep remains in `SyncOrchestrator`.

PASS: Shared static scan did not find `ModelContext`, SwiftData model annotations, HistoryEntry, `ensureRemoteID`, or concrete Supabase leakage.

## Code quality findings

The main code quality issue is concentration of unrelated responsibilities in `SupabaseTransportClient`: domain operations, debug harness helpers, remote row decoding, manual dry-run paths, and generic insert/update helpers are still interleaved. This makes the architecture hard to test and easy to regress despite the folder move.

Naming is currently misleading: `SupabaseTransportClient` suggests a thin transport, but the file still behaves as the former central service. This is a review blocker because it can mislead future maintainers and scanner reviewers.

## Performance findings

No new runtime performance regression was proven by this review pass. Existing ProductPrice paging/keyset behavior appears preserved by tests and code inspection. The remaining P1 is architectural/performance-risk: the multi-domain transport still encourages broad snapshots and large in-memory responsibilities in one actor.

No heavy Automatic core work on `MainActor` was found beyond the facade/presentation boundary pattern, but the mega-service split is still needed before claiming the ideal architecture.

## Security findings

PASS: no schema, RLS, grant, RPC, migration, cleanup, or live write was performed.

PASS: Supabase checks were read-only:
- `20260524T211023Z-supabase-status-redacted-task-TASK-121-p12132`
- `20260524T211023Z-supabase-contract-sync-schema-task-TASK-121-read-only-p12133`

PASS: sensitive scan passed at `20260524T211559Z-scan-sensitive-task-TASK-121-p18305`.

## Testability findings

PASS: targeted test suites passed:
- automatic architecture: `20260524T211201Z-ios-test-automatic-architecture-task-TASK-121-p14753`
- automatic domain: `20260524T211224Z-ios-test-automatic-domain-task-TASK-121-p15486`
- sync: `20260524T211235Z-ios-test-sync-task-TASK-121-p16090`
- manual sync regression: `20260524T211507Z-ios-test-manual-sync-regression-task-TASK-121-p16952`

CHANGES_REQUIRED: existing tests did not catch the renamed mega-service. The scanner has been strengthened to cover this gap.

## Harness/scanner findings

P1 fixed during review: `scan sync-architecture --task TASK-121 --strict` was a false negative before this pass. The scanner now has `remote_transport_is_thin` and fails on the current code:
- `20260524T211916Z-scan-sync-architecture-task-TASK-121-strict-p40244`: FAIL
- `20260524T212607Z-scan-sync-architecture-task-TASK-121-strict-p46362`: FAIL after tracking updates; `remote_transport_is_thin` evidence is line count 1866, direct domain conformances 7, domain method hits 14, debug task hooks 40.
- `20260524T212756Z-scan-sync-architecture-task-TASK-121-strict-p70446`: final rerun remains FAIL with the same blocker evidence.

PASS after scanner fix:
- `20260524T211916Z-scan-source-format-task-TASK-121-strict-p40218`
- `20260524T211916Z-scan-scanner-self-tests-task-TASK-121-strict-p40243`
- `20260524T212559Z-scan-source-format-task-TASK-121-strict-p44756`
- `20260524T212607Z-scan-scanner-self-tests-task-TASK-121-strict-p46364`

## Evidence integrity findings

P1 evidence correction: earlier top-level evidence and tracking stated `ARCHITECTURE_TARGET_MET` and cited `2ac8cb0...` as local/origin/GitHub HEAD. Current canonical HEAD is `a756485...`. The older SHA is now documented as the historical architecture commit, not the current reviewed SHA.

P1 evidence correction: `docs/TASKS/EVIDENCE/TASK-121/README.md` previously described planning-only state. It has been updated to the current FIX/CHANGES_REQUIRED state.

Historical `final-architecture-certification.md` is retained but explicitly superseded by this review.

## Build/test/smoke results

- PASS: Debug build `20260524T211032Z-ios-build-debug-task-TASK-121-p13238`
- PASS: Release build `20260524T211046Z-ios-build-release-task-TASK-121-p13956`
- PASS: automatic architecture tests `20260524T211201Z-ios-test-automatic-architecture-task-TASK-121-p14753`
- PASS: automatic domain tests `20260524T211224Z-ios-test-automatic-domain-task-TASK-121-p15486`
- PASS: sync tests `20260524T211235Z-ios-test-sync-task-TASK-121-p16090`
- PASS: manual sync regression tests `20260524T211507Z-ios-test-manual-sync-regression-task-TASK-121-p16952`
- PASS_WITH_NOTES: Options smoke `20260524T211520Z-ios-smoke-options-task-TASK-121-p17571`

## Supabase read-only results

- PASS: `supabase status-redacted --task TASK-121` at `20260524T211023Z-supabase-status-redacted-task-TASK-121-p12132`
- PASS: `supabase contract sync-schema --task TASK-121 --read-only` at `20260524T211023Z-supabase-contract-sync-schema-task-TASK-121-read-only-p12133`

## PASS_WITH_NOTES

Only `ios smoke options --task TASK-121` is PASS_WITH_NOTES. It is acceptable only as a wrapper-recognized XcodeBuildMCP fallback for JXA/Accessibility tooling blockage, not as a live/manual/device proof.

## NOT_RUN

- live reconcile counts
- live sync matrix
- cleanup

These are not counted as PASS.

## Warnings

Build logs still include Swift actor-isolation warnings and AppIntents metadata warnings that are documented in prior TASK-121 evidence. They are not attributed to this scanner/tracking review pass, but they remain residual warnings and must not be reported as "no warnings globally" without a dedicated baseline.

## Fixes applied during review

- `tools/agent/lib/task121_scans.py`: added `remote_transport_is_thin` to `scan_sync_architecture`.
- `tools/agent/fixtures/task121_scanners/sync-architecture/README.md`: added RED/GREEN coverage requirement for renamed Remote mega-service.
- `tools/agent/fixtures/task121_scanners/sync-architecture/red/fixture.txt`: documents failing renamed-mega-service scenario.
- `tools/agent/fixtures/task121_scanners/sync-architecture/green/fixture.txt`: documents thin-transport success scenario.
- Tracking/evidence updated to `CHANGES_REQUIRED`.

## Post-tracking validation

- PASS: `scan task-docs --task TASK-121 --strict` at `20260524T212741Z-scan-task-docs-task-TASK-121-strict-p69155`
- PASS: `scan master-plan-consistency --task TASK-121 --strict` at `20260524T212741Z-scan-master-plan-consistency-task-TASK-121-strict-p69154`
- PASS: `scan evidence-metadata --task TASK-121 --strict` at `20260524T212741Z-scan-evidence-metadata-task-TASK-121-strict-p69156`
- PASS: `scan source-format --task TASK-121 --strict` at `20260524T212559Z-scan-source-format-task-TASK-121-strict-p44756`
- FAIL expected/current blocker: `scan sync-architecture --task TASK-121 --strict` at `20260524T212756Z-scan-sync-architecture-task-TASK-121-strict-p70446`
- PASS: `scan scanner-self-tests --task TASK-121 --strict` at `20260524T212607Z-scan-scanner-self-tests-task-TASK-121-strict-p46364`
- PASS: `scan evidence --task TASK-121` at `20260524T212756Z-scan-evidence-task-TASK-121-p70413`
- PASS: `report validate-json --task TASK-121 --path docs/TASKS/EVIDENCE/TASK-121/agent-runs` at `20260524T212834Z-report-validate-json-task-TASK-121-path-docs-TASKS-EVIDENCE-TASK-121-agent-runs-p91739`
- PASS: `git diff --check`, no output.

## Residual risks

- P1 open: Remote split still incomplete.
- Adapter boundaries are still too thin/delegating to prove ideal architecture.
- Warning baseline is historical rather than freshly eliminated.
- Options smoke primary path remains tooling-blocked; fallback is useful but not equivalent to live/device acceptance.

## Required user acceptance

No DONE and no final architecture acceptance should be granted in this state. User acceptance can only follow a later review after the Remote mega-service is actually split and the full TASK-121 matrix is rerun.

## Next action

Move domain-specific Supabase behavior out of `SupabaseTransportClient` into focused Remote/Manual/Recovery adapters, keep the transport limited to client/session/error/shared helper responsibilities, then rerun:

```bash
./tools/agent/mc-agent.sh scan sync-architecture --task TASK-121 --strict
./tools/agent/mc-agent.sh scan scanner-self-tests --task TASK-121 --strict
./tools/agent/mc-agent.sh ios build debug --task TASK-121
./tools/agent/mc-agent.sh ios build release --task TASK-121
./tools/agent/mc-agent.sh ios test automatic-architecture --task TASK-121
./tools/agent/mc-agent.sh ios test automatic-domain --task TASK-121
./tools/agent/mc-agent.sh ios test sync --task TASK-121
./tools/agent/mc-agent.sh ios test manual-sync-regression --task TASK-121
./tools/agent/mc-agent.sh supabase contract sync-schema --task TASK-121 --read-only
```
