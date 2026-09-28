# CI97b6c812 — iOS 26.2 isolated-deinit crash

## Observed failure and reproduction

The [failed CI run](https://github.com/XNIW/iOSMerchandiseControl/actions/runs/36464969429) built SHA `97b6c812c53420b30a0151344a40425296427a6c` with Xcode 26.6 / iPhoneSimulator SDK 26.5, but selected an iPhone 16e **running iOS 26.2**. Its log starts `testFileStorageReportsActualFilesystemError` and then aborts with `malloc: pointer being freed was not allocated`; this is a crash, not a failed assertion. The CI run has no uploaded xcresult or crash-report artifact. Original CI logs and failure summary remain in the coordinator evidence directory.

A new, exclusively owned local iPhone 16e simulator running iOS 26.2 (23C54) reproduced the unmodified test: **0 PASS / 1 CRASH / 0 SKIP**, xcodebuild exit 65. Local compilation used **Xcode 27.0 (27A266a)**, so compiler versions differ; the old runtime and crash signature match. This distinguishes the installed runtime from the compiler/SDK selected in CI. The simulator was separate from all live/shared devices and was shut down only after its final test process exited.

The local `.ips` shows SIGABRT on the main thread through:

```text
TaskLocal::StopLookupScope::~StopLookupScope()
swift_task_deinitOnExecutorImpl
StorefrontPendingFileStorage.__deallocating_deinit
StorefrontAuthoringStoreTests.testFileStorageReportsActualFilesystemError() :627
```

The source location is the original test's closing brace, after the real filesystem-error assertion. This local stack isolates the crash to destruction of the MainActor storage object by the synchronous XCTest entry point, rather than Foundation's directory-creation error. See [baseline-stack.json](baseline-stack.json). The exact CI stack is unavailable; attribution of the CI event relies on this same-case, same-runtime reproduction and matching allocator signature.

## Cause and minimal fix

The Swift runtime has a documented task-local allocation mismatch when no Swift task is active. [Upstream fix 29245e4](https://github.com/swiftlang/swift/commit/29245e4) changes allocation to match the later free in this case. [The Swift maintainers' reproduction discussion](https://forums.swift.org/t/pointer-being-freed-was-not-allocated-unless-i-have-an-empty-deinit/84034) describes the isolated-deinit path and task-context relationship.

Only `testFileStorageReportsActualFilesystemError` changes: its signature becomes `async throws`, giving XCTest a Swift task for the MainActor object lifetime. The existing `XCTAssertThrowsError` still invokes real `StorefrontPendingFileStorage.write`; added assertions require `NSCocoaErrorDomain` / `fileWriteFileExists` and prove the blocking file's bytes are unchanged. No fake error, test skip, retry policy, storage implementation, global actor setting, build dependency, or production code is changed. The test is stronger, and the framework's affected no-task path is avoided through the appropriate XCTest async entry point.

## Verification

- Original test on iOS 26.2: **0 PASS / 1 CRASH / 0 SKIP**, exit 65, original log/xcresult/ips preserved.
- Patched entire `StorefrontAuthoringStoreTests` class on the **same** simulator/runtime: **29 PASS / 0 FAIL / 0 SKIP**, exit 0, no crash and no runner restart. The filesystem test passes in 0.002 seconds with all added assertions.
- Scope check: content outside that test function is byte-for-byte unchanged; `StorefrontAuthoring.swift` matches its pre-diagnosis SHA-256.
- `git diff --check`: PASS.
- The coordinating executor must run the broader final gates and exact-SHA CI; this local result does not claim CI rerun success or global iOS 26.2 acceptance.

Commands used the normal scheme and existing actor isolation, `CODE_SIGNING_ALLOWED=NO`, `-parallel-testing-enabled NO`, and an explicitly owned iOS 26.2 destination. The red run selected only the original filesystem test; the green run selected the entire Storefront store test class. Compiled data at `/tmp/mc-task144-ios/compiler-check/DerivedData` was handed back to the coordinating executor, including its newly added R-I02 tests (compiled, not executed by this lane).

Local raw artifacts: `/tmp/mc-task144-ios/ci97b6-deinit-diagnosis/`. Device identity is redacted from tracked summaries; log hashes are in [artifact-manifest.json](artifact-manifest.json). No commit or master/task-state change was made by this diagnostic lane.
