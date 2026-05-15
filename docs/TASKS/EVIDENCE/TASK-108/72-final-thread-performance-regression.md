# TASK-108 — Final thread performance regression

Date: 2026-05-14 15:25 -0400  
Executor: Codex  
Status: FIX EVIDENCE

## iOS checks

| Check | Stato | Evidenza |
|---|---|---|
| iOS `git diff --check` | ✅ ESEGUITO | PASS, no output |
| iOS Debug build | ✅ ESEGUITO | XcodeBuildMCP `build_sim` PASS, warnings `[]`, log `build_sim_2026-05-14T19-17-00-209Z_pid80685_33a60300.log` |
| iOS Debug run | ✅ ESEGUITO | XcodeBuildMCP `build_run_sim` PASS, pid `94292`, warnings `[]` |
| iOS Release build | ✅ ESEGUITO | `xcodebuild build -configuration Release` PASS |
| Targeted ProductPrice tests | ✅ ESEGUITO | `SupabaseProductPriceApplyServiceTests` PASS via direct `xcodebuild test`, `144.996s` |
| Targeted preview/apply/history/baseline/ViewModel tests | ✅ ESEGUITO | Direct `xcodebuild test` PASS, `10.362s` |
| XcodeBuildMCP `test_sim` | ⚠️ NON ESEGUIBILE | Simulator clone stuck/launch infrastructure error; direct `xcodebuild test` used successfully |
| Simulator smoke responsiveness | ✅ ESEGUITO | Final Options tab tap `0.3708s`; main thread idle sample `3822/3822` run loop samples |
| Main thread profiler before/after | ✅ ESEGUITO | Before root cause sample and after idle sample copied under `profiles/` |
| `plutil` | ✅ ESEGUITO | `Info.plist`, `SupabaseConfig.example.plist`, `SupabaseConfig.plist` OK |
| Privacy scan | ✅ ESEGUITO | No raw token/JWT/email/service_role added; `service_role` hits are defensive guards/docs |
| iOS physical smoke | ⚠️ NON ESEGUIBILE | iPhone physical device offline |
| Full live ProductPrice post-patch | ❌ NON ESEGUITO | Not rerun after this structural worker/backfill fix |
| Incremental pull/push live | ❌ NON ESEGUITO | Not run in this turn |
| Generated/History live | ❌ NON ESEGUITO | Not run in this turn |
| Cross-platform E2E | ❌ NON ESEGUITO | Not run in this turn |

## Android checks

| Check | Stato | Evidenza |
|---|---|---|
| Android `git diff --check` | ✅ ESEGUITO | PASS, no output |
| Android `assembleDebug` | ✅ ESEGUITO | PASS in `599ms`; only existing Gradle/AGP deprecation warnings |
| Android targeted repository tests | ✅ ESEGUITO | `DefaultInventoryRepositoryTest` PASS in `12s` |
| Android combined ViewModel tests | ⚠️ NON ESEGUIBILE | `CatalogSyncViewModelTest` failed during test initialization with `AttachNotSupportedException` / MockK attach, not sync assertions |
| Android device/emulator smoke | ⚠️ NON ESEGUIBILE | `adb` not found in PATH in this environment |
| Android logcat privacy scan | ⚠️ NON ESEGUIBILE | `adb` unavailable |

## Supabase checks

| Check | Stato | Evidenza |
|---|---|---|
| Supabase project sanity | ✅ ESEGUITO | MCP project `jpgoimipbothfgkokyvm`, `ACTIVE_HEALTHY`, Postgres `17.6.1.104` |
| Supabase live write/read-back | ❌ NON ESEGUITO | No new scoped `TASK108_THREAD_*` data created in this structural thread fix |
| Supabase cleanup scoped | ⚠️ NON ESEGUIBILE | No new scoped data was created by this pass |

## Final thread verdict

Thread/UI freeze fix: **FIXED BY MEASUREMENT for launch/foreground root path**.

TASK-108 global acceptance: **NOT DONE**.

Remaining acceptance gaps:
- full live post-patch ProductPrice `~290k` rerun;
- incremental pull;
- incremental push;
- Generated live;
- History/session live;
- Android app-auth/device/logcat verification;
- cross-platform E2E with `TASK108_THREAD_*` data.

Do not mark TASK-108 DONE based on this evidence alone.
