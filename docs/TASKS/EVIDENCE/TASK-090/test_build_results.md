# TASK-090 — Test, build e check

Timestamp locale: 2026-05-09 17:10 -0400

## Preflight

| Check | Esito | Evidenza |
|-------|-------|----------|
| `git status --short` | PASS | Working tree contiene tracking/evidence TASK-090; nessuna patch Swift/Kotlin/SQL |
| Branch/commit | PASS | `main` @ `8264c96` |
| `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` | PASS | Scheme `iOSMerchandiseControl`, target app/test, config Debug/Release |
| Schema Supabase locale read-only | PASS | Migration lette da `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations` |

## Build

| Check | Esito | Evidenza |
|-------|-------|----------|
| Build Debug iPhone 16e iOS 26.2 | PASS | `xcodebuild build -configuration Debug` -> `BUILD SUCCEEDED` |
| Build Release iPhone 16e iOS 26.2 | PASS | `xcodebuild build -configuration Release` -> `BUILD SUCCEEDED` |
| Warning nuovi | PARTIAL | Solo warning tooling `Metadata extraction skipped. No AppIntents.framework dependency found.`; nessuna patch codice applicata, quindi nessun warning nuovo attribuibile a TASK-090 |

## XCTest

| Check | Esito | Evidenza |
|-------|-------|----------|
| XCTest mirati manual sync / ProductPrice / pull / export benchmark / localizzazioni | PASS | `** TEST SUCCEEDED **`; 299 test case passati, 0 failure nel log mirato |
| Full XCTest | PASS | `** TEST SUCCEEDED **`; xcresult summary: 567 passed, 0 failed, 0 skipped |

## Static checks

| Check | Esito | Evidenza |
|-------|-------|----------|
| `git diff --check` | PASS | Nessun output |
| `plutil -lint iOSMerchandiseControl/*.lproj/Localizable.strings` | PASS | IT/EN/ES/zh-Hans OK |
| Grep `TASK090` in source/test iOS | PASS | Nessun match |
| Release binary `TASK090` strings | PASS | Nessun match |
| Evidence secret scan | PASS | Nessun match per pattern token/JWT/service_role/connection string |

## Check non eseguiti

| Check | Stato | Motivo |
|-------|-------|--------|
| Supabase live sandbox write/read-back `TASK090_*` | NON ESEGUIBILE / BLOCKED_ENV | Owner/session/collision scan DB non verificati immediatamente prima di write sicuro |
| Android runtime fresh | NON ESEGUIBILE / SKIPPED | Android e' riferimento funzionale in TASK-090; nessuna patch Kotlin e nessun runtime obbligatorio autorizzato |
| Import/export UI manual app -> file -> app | NON ESEGUIBILE / PARTIAL | Non necessario duplicare TASK-089 senza patch export/import; scenario documentato come PARTIAL |

## Review rerun

Timestamp locale: 2026-05-09 17:26 -0400

| Check | Esito | Evidenza |
|-------|-------|----------|
| `git status --short` | PASS | Working tree limitato a tracking/evidence TASK-090 non ancora staged |
| `git diff --check` | PASS | Nessun output |
| `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` | PASS | Scheme `iOSMerchandiseControl`, target app/test, config Debug/Release |
| Build Debug iPhone 16e iOS 26.2 | PASS | `/tmp/task090_review_debug_build.log` contiene `** BUILD SUCCEEDED **` |
| Build Release iPhone 16e iOS 26.2 | PASS | `/tmp/task090_review_release_build.log` contiene `** BUILD SUCCEEDED **` |
| XCTest mirati manual sync/ProductPrice/pull/export/localization | PASS | `/tmp/task090_review_targeted_tests.log`: 314 test, 0 failure, `** TEST SUCCEEDED **` |
| Full XCTest | PASS | `/tmp/task090_review_full_tests.log`: 567 test, 0 failure, `** TEST SUCCEEDED **` |
| `plutil -lint iOSMerchandiseControl/*.lproj/Localizable.strings` | PASS | IT/EN/ES/zh-Hans OK |
| Grep `TASK090` in source/test iOS | PASS | Nessun match |
| Release binary `TASK090` strings | PASS | Nessun match |
| Evidence/tracking secret scan | PASS | Nessun pattern token/JWT/service_role/connection string |
| Warning nuovi | PARTIAL | Solo warning tooling AppIntents `Metadata extraction skipped`; nessuna patch codice TASK-090 applicata |
| Supabase live sandbox write/read-back `TASK090_*` | BLOCKED_ENV | Non rieseguito in review: owner/session/collision gate non verificati per write sicuro |
| Android runtime fresh | SKIPPED | Android resta riferimento funzionale; nessuna patch/runtime Android richiesto per chiusura PARTIAL_ACCEPTED |
| Import/export UI manual app -> file -> app | PARTIAL | Non rieseguito; resta coperto da review statica e TASK-089 synthetic evidence |
