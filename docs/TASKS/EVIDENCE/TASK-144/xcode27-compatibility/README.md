# TASK-144 — Xcode 27 XCTest compatibility

The app target keeps its existing `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` setting. Apple Swift 6.4 rejects the baseline actor test doubles that conform to protocols imported as MainActor-isolated. No production source, public API, build setting, dependency, schema or test exclusion belongs to this compatibility patch.

The first canonical red log contains 48 unique conformance diagnostics affecting 36 actor fakes in 23 files, including two Storefront fakes owned by the main iOS executor. Once those diagnostics were cleared, two additional identical errors were exposed in Task118AutomaticDomainTests. Local compiler probes rejected `@preconcurrency`, `nonisolated` conformance, `nonisolated actor`, and a nonisolated refining protocol. `@MainActor final class` compiled.

The compatibility batch converts 36 fake declarations in 23 test files to MainActor final classes. Mutable fake state remains serialized. All async protocol method bodies, counters, injected errors, checked continuations, suspension gates, sleeps, yields, assertions, and skips are preserved. Independent gate/recorder actors remain actors. Controlled async operations still suspend and permit reentrancy. These doubles now run on the production protocol's declared actor; they do not model an independent background executor.

Six initializers in five remote fakes are explicitly nonisolated and initialize only Sendable fixture data. This preserves synchronous fixture setup without moving the calling test onto MainActor. Other affected Task119 setup uses explicit await when constructing the MainActor fake. Redundant awaits on synchronous helpers accessed from MainActor are removed only at compiler-diagnosed sites.

Task103CrossPlatformAcceptanceTests also needed its existing timing log decomposed into four integer totals and a typed string array joined with spaces. Output keys and values are unchanged. The original long concatenation exceeded the Xcode 27 type checker limit, even after extracting the numeric totals. No business step or assertion changed.

## Verification

- Canonical `build-for-testing`: **PASS**, exit 0, simulator arm64 and x86_64, no actor-isolation override.
- Final command: `xcodebuild build-for-testing -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mc-task144-ios/compiler-check/DerivedData CODE_SIGNING_ALLOWED=NO`.
- Final log: `/tmp/mc-task144-ios/compiler-check/build-for-testing-pass5.log`; terminal verdict `TEST BUILD SUCCEEDED`.
- Zero errors. Eight test warnings: seven match exact diagnostics in the initial red log. The remaining warning (Task098CrossPlatformSmokeTests.swift:612) is exposed after compilation progresses; both its test helper and HistorySessionSyncService initializer are unchanged. No warning introduced by this patch remains.
- A source invariant check compares all 24 owned files with HEAD: assertion/failure/skip lines, checked-continuation registrations, sleeps and yields are identical.
- `git diff --check`: PASS.
- This agent did not run XCTest or any simulator. Full behavioral/unit/UI gates belong to the coordinating iOS executor and are separate evidence. The compiled DerivedData was handed back for reuse.

## Scope and evidence

24 test files: 23 contain 36 fake conversions; Task103 contains the timing-log correction. Storefront source/tests/UI, app configuration, master plan and task status are owned by other executors and were not edited by this batch.

Transient evidence remains at `/tmp/mc-task144-ios/compiler-check/` and `/tmp/mc-task144-ios/compiler-probe/`: all five compile passes, parsed diagnostics, exact patch, assertion checks, compiler probes and owned-file manifest. No commit was created by this executor.

Primary references: [Swift SE-0449](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0449-nonisolated-for-global-actor-cutoff.md) and [Swift SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md). The locally executed compiler probes establish behavior for the installed toolchain.
