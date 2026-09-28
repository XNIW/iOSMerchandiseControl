# iOS execution — mobile parity root causes

Baseline `30d226d0fb9b8679a1dd034c6e82319645337f22`; isolated branch `codex/mobile-parity-root-cause-ios`, checkout `/Users/minxiang/.codex/worktrees/mobile-parity-root-cause/ios`. Primary checkout/scheme preserved. No production deployment, new account, new dependency, database reset, or suspended Excel harness activation.

## Findings and evidence

| Finding | Root cause and fix | Before | After |
|---|---|---|---|
| F01 iOS counterpart, P1 | UserDefaults has no fallible durable commit; an evicted editor cache prevented reading an independently saved draft. Account/shop/product journal now uses atomic file writes with explicit failure, preserves draft and immutable attempted intent separately, migrates legacy only after successful durable write, and restores saved base/version without an editor cache. Logout/switch isolate rather than delete. | `testSavedDraftIsRecoverableOfflineWithoutEditorCache` threw offline in `root-causes-red-4.xcresult`. | Canonical focused storage tests PASS; actual filesystem failure, disk fault injection, ACK cleanup fault, new storage, 2 products × 3 scopes, migration, cache eviction covered. |
| F02, P1 | reset cancelled Task but left loading owned by old request; query identity and error guards missing. Filter generation + scope/filter/query ownership now governs rows/errors/page/defer; reset releases loading immediately. | Controlled A continuation prevented B from starting; All retained spinner. `root-causes-red-4.xcresult`, 2 failing assertions in test. | Six controlled continuation tests PASS, including query, inverted response, late error/cancel, scope and next page; real reused filter component/binding XCUITest PASS in synthetic DEBUG harness. |
| F03 iOS counterpart, P1 | Non-draft mutations regenerated keys; save-draft load compared version before resolving lost ACK. Persisted canonical scope/product/op/payload/version/key/date intent is replayed exactly, then successor can obtain new identity. Authorization/precondition rejection before receipt lookup does not erase unknown earlier work; expired receipts use conservative version check. | Lost ACK + restart, and lost ACK + edited B both threw false conflict. | Every operation retry, same/different payload, precommit timeout, validation/edit, receipt expiration, scope switch, ACK cleanup disk fault, concurrent server change covered locally. Real SQL semantics independently validated by coordinator; local fake is not live app E2E. |
| F05, P1 | Editable fields permitted B while ACK A would replace draft. | Actual XCUITest with suspended mutation timed out waiting for public-name to become disabled: `inflight-input-red.xcresult`, 1 test/1 failure. | `expandedEditor` disabled only during load/mutation/image adoption. `testFieldsCannotBeEditedWhileMutationAckIsPending` PASS. |
| R-I01, P1 independent review | Receipt A was compared with newer C before durable settlement. This retained base Original and could reapply acknowledged name A over C when B changed only price. | `review-r-i01-red.xcresult`: 2 tests failed; base/version/delta/reapply and identical retry assertions. | Receipt + current row distinguished; settle A first, rebase saved successor to A, send with receipt version, expose settled base to current editor. Identical retry adopts C; B only-price retains C name on reapply. `review-r-i01-green.xcresult`: 34 store/filter PASS. Final gate runs after the complete batch. |

UI/UX intentional: editor fields temporarily disabled during pending ACK and image adoption to prevent input overwrite. Scope changes reset editor version/busy flags and canceled old-scope completions cannot clear a newer busy indicator. No redesign or operational data behavior change.

## Commands and environment

Xcode 27.0 `27A266a`, Swift 6.4; scheme `iOSMerchandiseControl`; dedicated simulator `TASK144 Parity Isolated iPhone 17`, runtime iOS 27.0, UDID `<REDACTED_SIMULATOR_ID>`. Created from enumerated runtime/device type, no existing simulator reset. No physical-device claim.

Canonical test form:

```sh
xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=TASK144 Parity Isolated iPhone 17' -derivedDataPath /tmp/mc-task144-ios/compiler-check/DerivedData -resultBundlePath /tmp/mc-task144-ios/full-final.xcresult -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Focused uses `-only-testing` for StorefrontAuthoringContractTests, StorefrontImageAdoptionTests, StorefrontAuthoringStoreTests, StorefrontFilterGenerationTests and StorefrontEditorUITests. `focused-final.xcresult`: 43 unit/integration and 4 XCUITest PASS before independent-review batch. Unit tests use SwiftData/local disk/fakes/URLProtocol as specified; XCUITest drives actual SwiftUI components in a DEBUG synthetic harness, not authenticated Database E2E.

Initial Xcode27 baseline test compilation failed before tests. Diagnostic red/green slice temporarily used `SWIFT_DEFAULT_ACTOR_ISOLATION=nonisolated` and five excluded test files; this is NOT the canonical gate. The final test-only compatibility batch fixes 36 existing fake conformances in 23 files plus Task103 typechecker expression, preserving assertions and scheduling gates. Original app default MainActor and all production protocols remain unchanged; final gates have no overrides or exclusions. Details: `xcode27-compatibility/README.md`.

Two first UI failures were test automation navigation-bar taps that scrolled Form back to top on iOS27, virtualizing the target button. Removed those irrelevant taps and retained assertions; actual input-red case was rerun separately after fixing automation. This is distinct from the reproduced app defect.

## Capability map and remaining validation

The sources below identify existing behavior; source inspection alone is STATIC, never business acceptance. Final XCTest log identifies which cases actually ran and which opt-in cases skipped.

| Capability | iOS path / requirement source | Local test path | Backend / limits | Evidence status |
|---|---|---|---|---|
| Inventory, generation, preview, results, save/cancel | InventoryHomeView, PreGenerateView, GeneratedView; historical task 018/025/027, TASK111 | Task111ExcelImportParityTests (deferred creates, generation, relations); Task141NumericInputTests | Local SwiftData saves; live cross-device generated History not verified here. | VERIFIED local automated coverage; EXTERNAL_DEPENDENCY for stated live/hardware gates. |
| Database search/barcode/filters/pagination | DatabaseView; ProductImportCore; TASK140/141/143 | CatalogTextPolicyTests, CatalogTextIntegrationTests, Task141NumericInputTests; new StorefrontFilterGenerationTests, CatalogTextImportUITests | SwiftData locally; Storefront summary RPC for public filters. Physical scanner/camera unavailable in this lane. | VERIFIED local automated coverage; EXTERNAL_DEPENDENCY for stated live/hardware gates. |
| Suppliers/categories create/rename/assign/replace/delete | DatabaseView named entity editor and Task126OwnerStoreGate; fresh context + LocalPendingChangeAccumulator + same save | Task111 relation resolver, CatalogTextIntegrationTests, AccountOwnerStoreSafetyTests | Local transactional paths audited; authenticated opposite-device outcomes external. | VERIFIED local automated coverage; EXTERNAL_DEPENDENCY for stated live/hardware gates. |
| Prices/history entry/filter/grouping | GeneratedView, HistoryView, HistoryMonthGrouping, HistoryEntryRuntimeSummary, PriceFormatting | Task130PriceContractTests, Task141NumericInputTests, HistoryMonthGroupingTests, HistoryViewStateTests, HistorySessionSyncServiceTests | Price/history remote contracts needed for actual convergence. | VERIFIED local automated coverage; EXTERNAL_DEPENDENCY for stated live/hardware gates. |
| Import/export errors/duplicate/no-op | ProductImportCore/ViewModel, ExcelAnalyzer, InventoryXLSXExporter; TASK111/140 | Task111ExcelImportParityTests, CatalogTextIntegrationTests, Task130PriceContractTests; existing standard suite only | No suspended Excel project/harness reopened. Shared intent fixture adds Unicode/CLP contract consumption. | VERIFIED local automated coverage; EXTERNAL_DEPENDENCY for stated live/hardware gates. |
| Product images | Existing ProductImages processor/cache/store/API and EditProductView staging; TASK137-139 | ProductImageProcessor/Cache/APIClient/SharedContract/OwnerStoreRace/SyncContract and StorefrontImageAdoptionTests | Synthetic image/URLProtocol contract tests do not prove physical camera, real upload, or remote lifecycle. No second image pipeline. | VERIFIED local automated coverage; EXTERNAL_DEPENDENCY for stated live/hardware gates. |
| Login/logout/account/shop/name/permissions | Auth view model, AccountBindingStore, ShopContextStore | SupabaseAuthSignOutScopeTests, ShopContextTests, AccountOwnerStoreSafetyTests | Real login/account pairing and permission E2E require authorized session; no new account created. | VERIFIED local automated coverage; EXTERNAL_DEPENDENCY for stated live/hardware gates. |
| Automatic sync/outbox/conflict/reconnect/recovery | AutomaticSyncEngine, trigger, SingleFlight, RetryPolicy, reconnect scheduler, Catalog/ProductPrice/History push, incremental apply, WatermarkStore, recovery | AutomaticSyncReconnectSchedulerTests, Task118/119, SyncDecisionEngineTests, WatermarkStoreTests, outbox suites, recovery suites | Source shows local write/pending same SwiftData context and normal automatic triggers. Fake tests do not replace Android↔iOS row-level live convergence, expired token, suspended/force-stop device tests. | VERIFIED local automated coverage; EXTERNAL_DEPENDENCY for stated live/hardware gates. |
| Storefront draft/publish/schedule/hide/archive/public preview | TASK143 contract + new TASK144; StorefrontAuthoring and Views | New journal/identity/generation tests, public-only payload tests, four XCUITest | Real RPC receipt contract from staging report; actual mobile HTTP ACK-loss and dual-device app flow still separate gates. No public client write path. | VERIFIED local automated coverage; EXTERNAL_DEPENDENCY for stated live/hardware gates. |
| IT/EN/ES/ZH/accessibility/empty/loading/error | Existing Localizable.strings plus new local persistence message | LocalizationCoverageTests, plutil four locales; Dynamic Type XCUITest; filter All/empty/error state tests | VoiceOver gesture traversal and physical accessibility judgment not claimed. Native UI differences intentional; business parity remains contract-based. | VERIFIED local automated coverage; EXTERNAL_DEPENDENCY for stated live/hardware gates. |

Operational save inspection: EditProductView.save writes product/relations/prices and LocalPendingChangeAccumulator through a fresh owner/store-fenced ModelContext, calls save before dismiss, and preserves editor on error. Database named entity editor similarly saves before dismiss; pre-generation quick create is an intentional unsaved selection, covered by deferred-create tests. GeneratedView.saveChanges retains unsaved/error state after failure. These statements are STATIC findings with adjacent regression suites, not newly performed authenticated manual flows.

## Performance scope

Durable save + new storage object + reload, one synthetic product, offline service, temporary file storage inside dedicated simulator: final n=30, p50 **1.156 ms** / p95 **1.367 ms** / max **2.597 ms** (`post-review-final.log`). This is a local file-write/reopen metric, with no network, Database opening, scrolling, UI rendering or convergence guarantee. Earlier run labels incorrectly said app_support although the injection used temporaryDirectory; the final test log label is corrected. Pre-fix offline recovery threw and filter B did not start while A remained suspended: functional before/after, not comparable latency statistics.

The two separately enabled, existing D100-L XCTest cases both PASS: S100-E preview **5.147 s** (12000 products, 480 suppliers, 320 categories, 48000 price rows, pages13/49 at page size1000); S100-F prepare/apply + current/previous audit **82.485 s** (12000 products/48000 prices). Each is n=1, so p50/p95 estimates are not meaningful. Seed/setup time is outside the instrumented interval where defined by the existing test. Tests use fake fetcher/in-memory SwiftData, not network or UI. No algorithm/dataset oracle changed. Background diagnostics from the earlier full run were still collecting; no other test/build was running. `synthetic-benchmarks.json` records the scope and conditions.

Final runs are recorded in the result annex. No live sync timestamps or row-level convergence claim from this lane.

## Modified files and acceptance boundaries

- `StorefrontAuthoring.swift`: durable scoped journal, legacy migration, immutable mutation identity/receipt settlement, filter generation and scope cancellation fences.
- `StorefrontAuthoringViews.swift`: preserve reconciled base/version and errors, disable editable fields while ACK/adoption is pending, clear local state only after successful storage.
- `iOSMerchandiseControlApp.swift`: extend the existing DEBUG synthetic harness with the production filter component and controlled services; no Release test route.
- Four `Localizable.strings`: translated local storage failure text, preserving input for retry.
- `StorefrontAuthoringTests.swift`: deterministic local regression and shared fixture consumer; `StorefrontEditorUITests.swift`: real XCUITest automation over reused production components in the DEBUG harness.
- Shared `Fixtures/MOBILE-PARITY/mobile-storefront-intent-parity-v1.json`: byte-identical Android/iOS Unicode and CLP draft/intent input.
- The 24 compatibility-only test files and rationale are listed separately in `xcode27-compatibility/owned-files.json`.
- The parent owns master/TASK-143 reconciliation and staging reports. No executor change to migration, schema, RLS, public client, credentials or production environment.

The capability table's VERIFIED status is confined to named local automated tests. It does not turn a source inspection, fake service, URLProtocol, SQL rollback test or simulator launch into authenticated cross-device acceptance. No confirmed MISSING_REQUIRED capability was found in this bounded implementation pass; missing *evidence* stays NOT_TESTED/EXTERNAL_DEPENDENCY. Native UI/accessibility differences are INTENTIONAL_PLATFORM_DIFFERENCE where functionality is equivalent, with hardware/VoiceOver judgment still NOT_TESTED.

## Independent review and first full-run failure

Independent review found only R-I01 on iOS; two red tests demonstrated the receipt/base defect. The single batch fix, plus a scoped readback completion guard, was re-reviewed and APPROVED with no open P0/P1/P2 on the frozen source. Review is not a substitute for runtime or live gates.

The first full run was **FAILED**: official `full-first-summary.json` gives 1353 PASS / 1 FAIL / 36 SKIP. A prior Xcode runner's delayed cleanup requested simulator shutdown during the 30000-row price test, causing SIGTERM; the full runner resumed remaining cases, not the interrupted test. Source and diagnostics provenance: `full-first-runtime-failure.md`, `full-first-failure.json`. The unchanged case then passed alone. Final full execution is repeated sequentially on the final source with no previous runner/build alive. All earlier failures remain evidence, not silently replaced by retries.

`post-review-summary.json`: 50 PASS / 0 FAIL / 0 SKIP on final source (46 local unit/integration +4 real XCUITest using production SwiftUI components in the synthetic DEBUG harness). `d100l-two-tests-summary.json`: 2 PASS /0 FAIL /0 SKIP, separate opt-in benchmark run.

Release simulator build and Debug analyze on final source: PASS. Analyze reports18 vendor C warnings and8 Swift warnings. Seven Swift warnings match the first canonical red compile, including2 Task119 diagnostics whose helper declarations/bodies are unchanged; `warning-provenance.json` proves those two predate fake conversion. The eighth warning is exposed on unchanged Task098 source. No source warning is attributable to the modified runtime or compatibility declarations. AppIntents metadata extraction reports no framework dependency (non-source build-tool warning). Four localization plutil checks and git diff whitespace validation PASS.

## Final result annex — frozen source

**Canonical full final: 1355 PASS / 0 FAIL / 36 SKIP; total 1391 unique cases.** Official xcresult summary and test-tree agree: 1347 unit/integration PASS, 36 unit skips, and8 XCUITest PASS. Final source fingerprint `3d33a15ce689a1aeb7b64082c249ef3a921a1816c520a228f9b475f8ea905d7d`; all303 source entries match the frozen manifest. The final full includes the last scope guard test. No test retries, runner restarts, exclusions or actor-isolation override. One runtime QoS warning is observed in an unchanged sync lease test; no test failure. Initial full failure is preserved separately, with source reconstruction and shutdown provenance.

| Final gate | PASS | FAIL | SKIP | Evidence |
|---|---:|---:|---:|---|
| Complete XCTest + XCUITest |1355|0|36|`full-final-summary.json`, `full-final-test-cases.json`|
| Storefront final unit/integration + UI |50|0|0|`post-review-summary.json`, `post-review-tests.json`|
| Previously interrupted price case alone |1|0|0|`full-crash-isolated-summary.json`|
| Existing S100-E/F D100-L selected benchmarks |2|0|0|`d100l-two-tests-summary.json`, `synthetic-benchmarks.json`|
| Release simulator build / Debug analyze |PASS|0|N/A|Commands/log hashes in `ios-gate-manifest.json`|

Skip categories:29 live/external prerequisites,4 expensive synthetic opt-in,2 suspended Excel harness,1 physical camera. Two of the4 synthetic cases were executed separately; the complete suite's36 SKIP count is retained unchanged. Exact IDs and reasons: `full-skips.json`.

The final command differs from the project's full command only by selecting the dedicated simulator/DerivedData and `-collect-test-diagnostics never`, which prevents delayed simulator diagnostics after failure. It does not alter which tests run, assertions, timeout budgets, or failure handling. `ios-gate-manifest.json` records complete commands, counts, source fingerprints, raw log paths and SHA256. The temporary D100-L xctestrun enables only `TASK100_D100L=1` for the two explicitly selected cases; no scheme or global sentinel was changed.

Canonical sensitive scan on app/tests/contracts/workflow PASS; additional scan of UI tests/new evidence/task PASS after redacting the synthetic simulator identifier in the reproduction command. The scanner initially routed its9 own report files to the primary checkout through config.example; only those newly created files were relocated to `/tmp`, and the commands rerun with explicit isolated configuration. Preexisting primary source/scheme/evidence were preserved. Scanning receipts are in `sensitive-scan-summary.json`; no credential values are included. Git diff whitespace check and four localization plist checks PASS.

The coordinator owns commits/PR/CI and live sessions. A separately requested TEST-configured Release app is built from the same source with only the ignored, parent-authorized publishable client configuration added to bundle resources. Its receipt is outside tracked files and it is not installed by this executor. This does not change the frozen source or substitute for authenticated device acceptance.
