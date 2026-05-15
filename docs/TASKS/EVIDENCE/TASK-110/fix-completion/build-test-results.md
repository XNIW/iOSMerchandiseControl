# TASK-110 FIX completion — Build/test results

Data: 2026-05-15

## Supabase

- `supabase migration list --linked`: PASS, ledger allineato fino a `20260515161500`.
- `supabase db push --linked --yes`: PASS, migration tombstone/grants/RLS applicata.
- Authenticated SQL smoke: PASS.
- Anon Data API negative smoke: PASS con `42501`.
- Security advisor: WARN residui non introdotti dalla migration TASK-110:
  - RPC `record_sync_event` security definer executable by authenticated;
  - leaked password protection disabled.
- `supabase db dump --linked --schema public`: NON ESEGUIBILE, Docker daemon non disponibile; file dump pre-task creato ma vuoto.

## iOS

- XcodeBuildMCP `build_sim`: PASS, 0 warning sui file patchati dopo fix warning `ensureHistorySessionRemoteID`.
- `HistorySessionSyncServiceTests`: PASS 10/0.
- Run mirato History + ProductPrice apply + ManualSync price tests: PASS 41/0, result bundle:
  `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/result-bundles/test_sim_2026-05-15T17-38-13-391Z_pid98309_75dbf1dd.xcresult`
- Live smoke iOS `Task098CrossPlatformSmokeTests/test01PreflightAndCollisionScanReadOnly`:
  - prima run senza sentinel: SKIP atteso dal gate;
  - seconda run con sentinel: FAIL `sessionMissing`.

## Android

- `./gradlew :app:assembleDebug`: PASS.
- `DefaultInventoryRepositoryTest.110*` + `AppDatabaseMigrationTest`: PASS.
- `DefaultInventoryRepositoryTest` completo: PASS.
- `HistorySessionPushCoordinatorTest` isolato con `GRADLE_OPTS='-Djdk.attach.allowAttachSelf=true'`: PASS.
- `./gradlew test`: NON ESEGUIBILE integralmente nel runner corrente: fallisce per `ByteBuddyAgent` / `AttachNotSupportedException` in classi MockK quando la suite è combinata. Il problema resta tooling/test-runner; i test mirati e le suite non-MockK PASS.
- Android fisico live app-auth ProductPrice no-op: PASS.

## Static checks

- `git diff --check` iOS: PASS.
- `git diff --check` Android: PASS.
