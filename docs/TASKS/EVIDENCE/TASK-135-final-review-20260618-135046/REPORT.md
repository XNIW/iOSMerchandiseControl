# TASK-135 Final Review + Self-Fix Report

Verdict: READY_FOR_USER_ACCEPTANCE / DONE candidate. Non marcato DONE per policy locale.

## Scope
- iOS repo: `/Users/minxiang/Desktop/iOSMerchandiseControl`.
- Android repo: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`.
- Supabase workspace: `/Users/minxiang/Desktop/MerchandiseControlSupabase` (non e' un git repo locale).
- Obiettivo: confermare stabilita' congiunta di Catalog sync e History sync dopo i fix TASK-135, correggendo solo problemi emersi in review.

## Review Fixes
- iOS Catalog push: `clientEventFingerprint` ora include event type, change IDs e IDs entita', evitando collisioni tra eventi successivi dello stesso plan.
- iOS ProductPrice push: pending price gia' linkati vengono acknowledged, pending price orfani/cascaded vengono superseded, delete ProductPrice viene terminalizzato senza inventare delete remote.
- iOS Product delete: quando un Product viene tombstoned/hard-deleted, i pending ProductPrice collegati vengono superseded e il cache count dell'accumulator viene invalidato.
- CodeRabbit scoped iOS source:
  - Primo run: 1 major valido su `LocalPendingChange.swift` (`cachedActiveCount` stale).
  - Fix applicato e rerun: 0 issues.
- Android: nessun nuovo codice richiesto in questo pass; commit remoto gia' allineato.
- Supabase: hardening live applicato alle tabelle backup TASK-108 tramite SQL linked; migration/docs locali aggiornati nel workspace Supabase, ma non pushabili da qui per assenza di `.git`.

## History Parity
Tool obbligatori usati: `history_snapshot_ios.sh`, `history_snapshot_android.sh`, `history_snapshot_supabase.sh`, `history_diff.py --visible-only`.

Final post-reopen:

| Source | active | userVisible | shown | hidden_active |
| --- | ---: | ---: | ---: | ---: |
| iOS | 39 | 35 | 35 | 4 |
| Android | 39 | 35 | 35 | 4 |
| Supabase | 39 | 35 | 35 | 4 |

Visible parity: 35/35/35, present_on_all 35, duplicate remote_id 0, duplicate fingerprint 0, payload mismatch 0, missing visible rows 0.

Le 4 fisiche non visibili sono fixture tecniche owner-scoped, non dati reali utente:

| remote_id | title | reasonHidden |
| --- | --- | --- |
| `560da308-71a5-43f2-9bf3-4c92502c0f8a` | `TASK135_MATRIX_20260617_192636_RT_20260617T232636Z_IOS_MATRIX_IOS_HISTORY_CREATE` | title technical/TASK |
| `7be52c5a-2e8b-4090-a43f-7845c49bb13b` | `TASK135_MATRIX_20260617_192636_RT_20260617T232636Z_IOS_MATRIX_IOS_HISTORY_UPDATE_FINAL` | title technical/TASK |
| `53d91b99-1a32-4711-bfdc-6636a7cce6c1` | `TASK135_MATRIX_20260617_192636_RT_20260617T232636Z_ANDROID_MATRIX_ANDROID_HISTORY_CREATE` | title technical/TASK |
| `7b22539f-95b4-4165-a3b6-869bfedc27b4` | `TASK135_MATRIX_20260617_192636_RT_20260617T232636Z_ANDROID_MATRIX_ANDROID_HISTORY_UPDATE_FINAL` | title technical/TASK |

Quindi 39 fisiche = 35 visibili perche' Options e History UI ora condividono la predicate user-visible: active non tombstone meno fixture tecniche `TASK135_MATRIX_*`.

## Catalog Stability
Final post-reopen counts:

| Source | products | suppliers | categories | product_prices | pendingAggregate |
| --- | ---: | ---: | ---: | ---: | ---: |
| iOS | 19704 | 66 | 35 | 41131 | 0 |
| Android | 19704 | 66 | 35 | 41131 | 0 |
| Supabase | 19704 | 66 | 35 | 41131 | n/a |

Live matrix via TASK-114 path with TASK-135 prefix passed all 12 create/update/tombstone legs for product and history. Scoped cleanup removed TASK135_REVIEW residues. Clean reopen/no false push passed: `sync_events` count 1886 and max id 3138 unchanged before/after.

Nota hygiene: due outbox entries iOS erano residue locali di harness gia' ripulito da remote e senza Product/ProductPrice risolvibile; sono state terminalizzate local-only per evitare eventi falsi. Dopo cleanup pendingAggregate iOS e Android restano 0.

## UI Evidence
- iOS Options current: `screenshots/ios-options-history-count-35-current.png` mostra `Sessioni cronologia 35`.
- Android Options current: `screenshots/android-options-history-count-35-current.png` mostra `Sessioni cronologia 35`.
- iOS History current: `screenshots/ios-history-visible-current.png` mostra lista user-visible senza `TASK135_MATRIX`.
- Android History current: `screenshots/android-history-visible-current.png` mostra lista user-visible senza `TASK135_MATRIX`.

## Checks
- iOS targeted new-fix tests after CodeRabbit cache fix: PASS, 5/5.
- iOS targeted History/Options tests after review fix: PASS.
- iOS Debug build after CodeRabbit cache fix: PASS.
- iOS `git diff --check`: PASS.
- Android targeted History/Catalog tests: PASS.
- Android `assembleDebug` + `lintDebug`: PASS.
- Android `git diff --check`: PASS.
- CodeRabbit iOS source rerun after self-fix: 0 issues.
- CodeRabbit Android committed review: 0 issues. Earlier Android all-change review only flagged unrelated local IDE state and was excluded from final evidence.
- Evidence hygiene scan: no full email, no large raw DB dump, no backup store file, no IDE local path, no client secret pattern.

## Git State
- iOS pre-final-review base: `3d1ac950 Fix TASK-135 catalog product tombstone sync`, HEAD == origin/main before this review fix.
- Android final state: `3a96c4d Fix TASK-135 product tombstone realign drain`, HEAD == origin/main; one unrelated local IDE file remains dirty and is not included.
- Final iOS commit hash is recorded by the git history after this report is committed/pushed.

## Residual Risk
- TASK-135 remains ACTIVE / REVIEW by local policy until user/Claude acceptance.
- Supabase workspace changes are applied live and saved locally, but the workspace has no git metadata here, so there is no Supabase push from this environment.
