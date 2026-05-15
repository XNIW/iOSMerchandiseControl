# TASK-110 final cross-platform completion — 00 baseline

Data: 2026-05-15  
Agente: CODEX / Cursor Executor  
Account runtime autorizzato in evidence: `x***@gmail.com`  
Scope: P0 baseline prima di smoke finale Supabase, runtime auth Android/iOS e matrice P8.

## Comandi eseguiti

- iOS: `git status --short --branch`
- iOS: `git diff --stat`
- iOS: `git log --oneline --decorate -5 --all`
- Android: `git status --short --branch`
- Android: `git diff --stat`
- Android: `git log --oneline --decorate -5 --all`
- Supabase: `git status --short --branch` *(workspace non git)*
- Supabase: `git diff --stat` *(workspace non git)*
- Supabase: `supabase --version`
- Supabase: `supabase status` *(output redatto: contiene chiavi locali di sviluppo, non riportate integralmente)*
- Supabase: `supabase migration list --linked`
- Evidence: `find docs/TASKS/EVIDENCE/TASK-110 -maxdepth 2 -type f -print | sort`
- Privacy/redaction spot-check: `rg -l "xniw97@gmail\\.com" ...` e scan mirato TASK-110/MASTER-PLAN.

## iOS workspace

- Path: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- Branch: `codex/task-110-sync-consistency`
- HEAD locale/remoto: `d4a0f89 (HEAD -> codex/task-110-sync-consistency, origin/main, origin/HEAD, main) Task 109`
- Ultimi commit visibili:
  - `d4a0f89 Task 109`
  - `48a6956 Task 108.2`
  - `74480c2 Task 108.1`
  - `b95c031 Task 108`
  - `27aa4a5 Task 107`

### Stato git iOS

```text
## codex/task-110-sync-consistency
 M docs/MASTER-PLAN.md
 M docs/TASKS/TASK-109-ios-supabase-sync-lifecycle-ux-regression.md
 M iOSMerchandiseControl/HistoryEntry.swift
 M iOSMerchandiseControl/HistorySessionSyncService.swift
 M iOSMerchandiseControl/HistoryView.swift
 M iOSMerchandiseControl/SupabaseAuthViewModel.swift
 M iOSMerchandiseControl/SupabaseClientProvider.swift
 M iOSMerchandiseControl/SupabaseInventoryService.swift
 M iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift
 M iOSMerchandiseControl/en.lproj/Localizable.strings
 M iOSMerchandiseControl/es.lproj/Localizable.strings
 M iOSMerchandiseControl/it.lproj/Localizable.strings
 M iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings
 M iOSMerchandiseControlTests/HistorySessionSyncServiceTests.swift
?? docs/TASKS/EVIDENCE/TASK-110/
?? docs/TASKS/TASK-110-cross-platform-cloud-sync-consistency.md
```

### Diff stat iOS

```text
docs/MASTER-PLAN.md                                |  53 +++++--
docs/TASKS/TASK-109-ios-supabase-sync-lifecycle-ux-regression.md |  18 ++-
iOSMerchandiseControl/HistoryEntry.swift           |  14 +-
iOSMerchandiseControl/HistorySessionSyncService.swift |  83 +++++++++--
iOSMerchandiseControl/HistoryView.swift            |  55 ++++++-
iOSMerchandiseControl/SupabaseAuthViewModel.swift  |  65 ++++++++-
iOSMerchandiseControl/SupabaseClientProvider.swift |  85 +++++++++++
iOSMerchandiseControl/SupabaseInventoryService.swift |   2 +-
iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift |  17 ++-
iOSMerchandiseControl/en.lproj/Localizable.strings |   2 +
iOSMerchandiseControl/es.lproj/Localizable.strings |   2 +
iOSMerchandiseControl/it.lproj/Localizable.strings |   2 +
iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings |   2 +
iOSMerchandiseControlTests/HistorySessionSyncServiceTests.swift | 160 ++++++++++++++++++++-
14 files changed, 504 insertions(+), 56 deletions(-)
```

## Android workspace

- Path: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`
- Branch: `codex/task-110-sync-consistency`
- HEAD locale/remoto: `4152069 (HEAD -> codex/task-110-sync-consistency, origin/main, origin/HEAD, main) iOS task 109`
- Ultimi commit visibili:
  - `4152069 iOS task 109`
  - `1d6b1a3 iOS task 108.2`
  - `3c26497 iOS task 108.2`
  - `7cfc536 iOS task 108`
  - `570bb3c iOS task 107`

### Stato git Android

```text
## codex/task-110-sync-consistency
 M app/src/main/java/com/example/merchandisecontrolsplitview/data/AppDatabase.kt
 M app/src/main/java/com/example/merchandisecontrolsplitview/data/HistoryEntry.kt
 M app/src/main/java/com/example/merchandisecontrolsplitview/data/HistoryEntryDao.kt
 M app/src/main/java/com/example/merchandisecontrolsplitview/data/HistorySessionPushCoordinator.kt
 M app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt
 M app/src/main/java/com/example/merchandisecontrolsplitview/data/SessionRemotePayload.kt
 M app/src/main/java/com/example/merchandisecontrolsplitview/data/SharedSheetSessionRecord.kt
 M app/src/main/java/com/example/merchandisecontrolsplitview/ui/screens/HistoryScreen.kt
 M app/src/main/res/values-en/strings.xml
 M app/src/main/res/values-es/strings.xml
 M app/src/main/res/values-zh/strings.xml
 M app/src/main/res/values/strings.xml
 M app/src/test/java/com/example/merchandisecontrolsplitview/data/AppDatabaseMigrationTest.kt
 M app/src/test/java/com/example/merchandisecontrolsplitview/data/DefaultInventoryRepositoryTest.kt
 M app/src/test/java/com/example/merchandisecontrolsplitview/data/HistorySessionPushCoordinatorTest.kt
?? app/schemas/com.example.merchandisecontrolsplitview.data.AppDatabase/17.json
```

### Diff stat Android

```text
app/src/main/java/.../data/AppDatabase.kt                     |  12 +-
app/src/main/java/.../data/HistoryEntry.kt                    |   6 +-
app/src/main/java/.../data/HistoryEntryDao.kt                 |  38 ++++++-
app/src/main/java/.../data/HistorySessionPushCoordinator.kt   |  51 ++++++---
app/src/main/java/.../data/InventoryRepository.kt             | 110 ++++++++++++++----
app/src/main/java/.../data/SessionRemotePayload.kt            |   7 +-
app/src/main/java/.../data/SharedSheetSessionRecord.kt        |  14 ++-
app/src/main/java/.../ui/screens/HistoryScreen.kt             |  26 +++--
app/src/main/res/values-en/strings.xml                        |   1 +
app/src/main/res/values-es/strings.xml                        |   1 +
app/src/main/res/values-zh/strings.xml                        |   1 +
app/src/main/res/values/strings.xml                           |   1 +
app/src/test/java/.../data/AppDatabaseMigrationTest.kt        |  66 ++++++++++-
app/src/test/java/.../data/DefaultInventoryRepositoryTest.kt  | 126 +++++++++++++++++++--
app/src/test/java/.../data/HistorySessionPushCoordinatorTest.kt | 54 +++++++++
15 files changed, 444 insertions(+), 70 deletions(-)
```

## Supabase workspace

- Path: `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- Git status: non eseguibile come git status, la directory non è un repository git.
- `supabase --version`: `2.98.2`
- `supabase status`: local development setup running; local services partially stopped: `imgproxy`, `edge_runtime`, `pooler`. Local publishable/secret/storage keys were printed by the CLI and intentionally redacted from this evidence.
- Migrations directory present and readable: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations`

### Linked migration ledger

```text
Local          | Remote
20260416       | 20260416
20260417000000 | 20260417000000
20260417120000 | 20260417120000
20260417200000 | 20260417200000
20260418200000 | 20260418200000
20260421120000 | 20260421120000
20260422120000 | 20260422120000
20260424021936 | 20260424021936
20260424145010 | 20260424145010
20260509120000 | 20260509120000
20260511030000 | 20260511030000
20260514213110 | 20260514213110
20260515161500 | 20260515161500
```

### Migration files currently present

```text
20260416_task010_shared_sheet_sessions_realtime.sql
20260417000000_task012_ownership_rls.sql
20260417120000_task013_inventory_catalog_rls.sql
20260417200000_task016_inventory_product_prices.sql
20260418200000_task019_inventory_catalog_tombstone.sql
20260421120000_task038_restrict_authenticated_delete_inventory.sql
20260422120000_task040_shared_sheet_sessions_v2.sql
20260424021936_task045_sync_events.sql
20260424145010_task045_sync_events.sql
20260509120000_task086_inventory_catalog_updated_at_triggers.sql
20260511030000_task101_revoke_rls_auto_enable_public_execute.sql
20260514213110_task108_backup_20260514173049.sql
20260515161500_task110_history_tombstone_grants.sql
README.md
```

## Evidence già presenti

Cartelle presenti prima del nuovo pass:

- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/`
- `docs/TASKS/EVIDENCE/TASK-110/final-review/`
- evidence root TASK-110: schema/access matrix/counts/policy/client-version files già presenti.

Nuova cartella creata:

- `docs/TASKS/EVIDENCE/TASK-110/final-cross-platform-completion/`

## Classificazione modifiche baseline

| Area | Classificazione | Note |
|------|-----------------|------|
| `docs/TASKS/TASK-110-cross-platform-cloud-sync-consistency.md` | parte di TASK-110 | File task attivo; aggiornato per `FIX / FINAL_CROSS_PLATFORM_EXECUTION`. |
| `docs/MASTER-PLAN.md` | parte di TASK-110 | Tracking globale aggiornato; TASK-109 resta `BLOCKED / SOSPESO`. |
| `docs/TASKS/TASK-109-ios-supabase-sync-lifecycle-ux-regression.md` | parte di tracking TASK-110/preesistente | Solo sospensione/override; non proseguire TASK-109. |
| iOS Swift/test/localizzazioni elencati | parte di TASK-110 preesistente | Fix già applicati nelle fasi tombstone/auth precedenti; da verificare in questo pass. |
| Android Kotlin/test/resources/schema elencati | parte di TASK-110 preesistente | Fix già applicati nelle fasi tombstone/ProductPrice precedenti; da verificare in questo pass. |
| Supabase migrations fino a `20260515161500` | parte di TASK-110 preesistente | Ledger locale/remoto ora coerente; workspace non git. |
| `docs/TASKS/EVIDENCE/TASK-110/final-cross-platform-completion/` | parte di TASK-110 corrente | Evidence finale P0-P10. |
| Modifiche accidentalmente fuori TASK-110 | nessuna nuova rilevata | Nessun file non collegato a TASK-110 è stato modificato in questo pass. |

## Redaction/privacy

- Nessuna email completa aggiunta nelle evidence TASK-110 correnti; usare sempre `x***@gmail.com`.
- `supabase status` ha stampato chiavi locali di sviluppo; non sono riportate qui.
- Nessun token JWT, service role key, password o anon key completa è stato scritto in questa evidence.
