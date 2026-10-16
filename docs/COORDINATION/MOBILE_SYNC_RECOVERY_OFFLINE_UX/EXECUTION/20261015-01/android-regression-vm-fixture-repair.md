# Android VM regression fixture repair

- UTC: 2026-10-16T04:26:30Z.
- Coordination: MOBILE_SYNC_RECOVERY_OFFLINE_UX / Android TASK-144.
- Owner: android_dates_red_design, on the root executor's explicit assignment.
- Checkout: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`.
- HEAD: `4b74ed5cfb4e4bce024513561e7dc1b6998003ae`; local candidate changes remain uncommitted.

## Original failure preserved

Input: `android-regression-01-summary.json`, `android-regression-01.log`, and the archived `android-regression-01-results/TEST-com.example.merchandisecontrolsplitview.viewmodel.CatalogSyncViewModelTest.xml` in this directory. Full Debug regression: 1,327 tests, 1,288 PASS, 32 FAIL, 7 SKIP. The VM class has 52 tests, 51 PASS and one FAIL:

`canonicalHistoryBootstrapDefersWithoutErrorOrFalseCompletion` fails with `IllegalStateException: Method addObserver must be called on the main thread`. The stack enters `LifecycleRegistry.jvm.kt:300`, then `LifecycleRegistry.addObserver`, Supabase Auth `SetupPlatformKt.addLifecycleCallbacks`, and `AuthImpl.init`, running on `LimitedDispatcher` / `CoroutineScheduler` worker frames. There is no `CatalogSyncViewModel` or target-test assertion frame. Robolectric also records queued main-looper runnables.

The manifest selects `MerchandiseControlApplication`. Its `onCreate` eagerly starts process coordinators and auth restoration; the configured client installs Supabase Auth with platform lifecycle callbacks. Previously this fully injected ViewModel unit fixture used that manifest Application implicitly. The stack and wiring support an unrelated process-auth initialization callback interfering with the fixture's replacement of `Dispatchers.Main`. They do not identify the exact client instance that delivered the asynchronous exception, and do not establish a D01 product regression.

## Bounded repair

Only `app/src/test/java/com/example/merchandisecontrolsplitview/viewmodel/CatalogSyncViewModelTest.kt` changed:

- The class now uses `@Config(application = Application::class, sdk = [33])`.
- Setup asserts that the actual Application class is `android.app.Application`.

The fixture still uses Android resources/preferences, the production ViewModel and tracker, and its explicitly injected repositories/auth/remotes. All existing product assertions, the 13 D01 scenarios, real scope-flight admission, clocks and scheduler behavior remain unchanged. Application/process auth wiring belongs to the separate Application and auth suites; this repair does not qualify those suites or alter production lifecycle enforcement.

No lifecycle guard was disabled, no looper drain or sleep added, and no error was caught or suppressed. No production source, SDK, dependency, build/toolchain configuration or device state changed.

## Pins and verification

SHA-256 after the fixture repair:

| File | SHA-256 |
|---|---|
| `viewmodel/CatalogSyncViewModelTest.kt` | `30add9441e8b7606d30560a64d5abbf5e51d18097e24b7a1ace93d6c57323327` |
| `viewmodel/CatalogSyncViewModel.kt` (unchanged) | `d601505d512d954883624ca697250bdf8d41cfefb3defea860ccb7e0ac9f3975` |
| `data/CatalogSyncStateTracker.kt` (unchanged) | `5e4f914bb147e82feb9d8c24a0d9fee9da3c735a2cf4903b4e5dc0a251a3b925` |
| `data/CatalogAutoSyncCoordinator.kt` (unchanged) | `6f104f23b09d1029dc7c358651212a8058fb9f60bdc92df4eeee878a09576c66` |

`git diff --check` for the changed fixture: PASS. No SDK/build/test runner was started by this owner. Repaired fixture execution and full-suite confirmation are **NOT_RUN**, reserved for the root's serialized runner. The original FAIL remains historical evidence; the other 31 full-regression failures are outside this repair. This receipt is an executor diagnosis and handoff, not an independent review approval or app/device acceptance.
