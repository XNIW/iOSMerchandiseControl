# TASK-112 — 00 Preflight

Timestamp: 2026-05-20 20:13:12 -0400

## Scope

Preflight iniziale richiesto prima di EXECUTION-AUDIT e implementation.

## Tracking state

| Voce | Stato |
|------|-------|
| TASK-112 | ACTIVE / EXECUTION |
| Responsabile | CURSOR / Executor |
| Override utente | User authorized full end-to-end execution after final planning approval |
| TASK-109 | BLOCKED / SOSPESO, non ripreso |
| TASK-110 | DONE, invariato |
| TASK-111 | DONE, invariato |
| Altri task | Nessuno riaperto |

## Git baseline

| Repo | Path | Branch | Dirty state |
|------|------|--------|-------------|
| iOSMerchandiseControl | `/Users/minxiang/Desktop/iOSMerchandiseControl` | `main` | Dirty prima di TASK-112 execution: `docs/MASTER-PLAN.md` modificato, `docs/TASKS/TASK-112-automatic-cross-platform-sync-no-manual-options-cta.md` e `docs/TASKS/EVIDENCE/TASK-112/` non tracciati dalla fase planning |
| MerchandiseControlSplitView | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` | `main` | Clean (`## main...origin/main`) |
| MerchandiseControlSupabase | `/Users/minxiang/Desktop/MerchandiseControlSupabase` | N/A | Non è un repository git in questa working copy (`fatal: not a git repository`) |

## Toolchain / environment

| Check | Esito | Evidenza |
|------|-------|----------|
| Xcode | ESEGUITO | `xcodebuild -version` → Xcode 26.5, build 17F42 |
| iOS simulators | ESEGUITO | XcodeBuildMCP `list_sims` mostra simulatori iOS 26.1/26.2/26.4/26.5 disponibili, tutti Shutdown al preflight |
| XcodeBuildMCP defaults | ESEGUITO | `session_show_defaults` senza project/workspace/scheme/simulator configurati |
| Android SDK adb | ESEGUITO | `adb` non è nel PATH; `/Users/minxiang/Library/Android/sdk/platform-tools/adb` esiste |
| Android devices | ESEGUITO | `/Users/minxiang/Library/Android/sdk/platform-tools/adb devices` → device `8ac48ff0` con stato `device` |
| Java | ESEGUITO | OpenJDK 21.0.10 |
| Gradle tasks | ESEGUITO | `./gradlew tasks --all` in Android repo PASS; warning AGP/Kotlin preesistenti su API deprecate |
| Supabase CLI | ESEGUITO | `supabase --version` → 2.98.2; avviso update a 2.100.1 |
| Supabase local status | ESEGUITO con esito negativo | `supabase status` in Supabase workspace fallisce: Docker daemon non raggiungibile |
| Supabase changelog | ESEGUITO | `curl https://supabase.com/changelog.md` letto; note rilevanti: breaking change 2026-04-28 su tabelle non esposte automaticamente alla Data API; self-hosted breaking changes 2026-05-18 non applicati automaticamente al client mobile |

## Risk notes

- Supabase workspace non è un repo git; eventuali modifiche schema/migration vanno trattate con cautela aggiuntiva e documentate come file locali, non come diff git autonomo.
- Docker non disponibile: test Supabase local stack/lint/status non eseguibili finché Docker non è avviato.
- Nessun simulatore iOS è booted al preflight; simulatori disponibili. Per build/test iOS verrà configurato un simulatore esplicito quando necessario.
- `adb` non è nel PATH ma un device Android reale/emulatore è connesso via path assoluto SDK.
- iOS repo contiene già modifiche/untracked planning TASK-112 prima della execution; non revertite perché parte del tracking task attivo.

## Preflight verdict

GO_WITH_NOTES per EXECUTION-AUDIT: i tre workspace sono accessibili, Android build tools sono disponibili, Xcode è disponibile, Supabase local Docker è bloccato ma non impedisce audit statico/schema locale. Live Supabase e simulator/emulator evidence restano gate separati da verificare dopo implementation.
