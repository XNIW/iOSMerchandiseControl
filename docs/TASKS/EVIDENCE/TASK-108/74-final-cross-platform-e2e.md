# TASK-108 — Final cross-platform E2E

Date: 2026-05-14 15:25 -0400  
Executor: Codex  
Status: NOT EXECUTED IN THIS FIX

## Requested cross-platform scenarios

- iOS -> Supabase -> Android.
- Android -> Supabase -> iOS.
- ProductPrice.
- Catalog.
- History/session.
- Pending retry.
- Scoped prefixes:
  - `TASK108_THREAD_E2E_*`
  - `TASK108_THREAD_PULL_*`
  - `TASK108_THREAD_PUSH_*`

## Android status in this pass

| Check | Stato | Evidence |
|---|---|---|
| `git diff --check` | ✅ ESEGUITO | PASS |
| `assembleDebug` | ✅ ESEGUITO | PASS |
| Repository/ProductPrice targeted tests | ✅ ESEGUITO | `DefaultInventoryRepositoryTest` PASS |
| ViewModel sync tests | ⚠️ NON ESEGUIBILE | MockK/attach infrastructure failure (`AttachNotSupportedException`) |
| Device/emulator smoke | ⚠️ NON ESEGUIBILE | `adb` not found in PATH |
| Logcat privacy scan | ⚠️ NON ESEGUIBILE | `adb` not found in PATH |

## Cross-platform live status

| Scenario | Stato | Evidence |
|---|---|---|
| iOS -> Supabase -> Android | ❌ NON ESEGUITO | No scoped live row created |
| Android -> Supabase -> iOS | ❌ NON ESEGUITO | No scoped live row created |
| ProductPrice cross-platform | ❌ NON ESEGUITO | Not run after thread fix |
| Catalog cross-platform | ❌ NON ESEGUITO | Not run after thread fix |
| History/session cross-platform | ❌ NON ESEGUITO | Not run after thread fix |
| Pending retry cross-platform | ❌ NON ESEGUITO | Not run after thread fix |
| Cleanup scoped | ⚠️ NON ESEGUIBILE | No scoped live data created |

## Verdict

Cross-platform E2E remains open and must not be marked PASS. This evidence intentionally records the unexecuted matrix after the thread/MainActor fix.
