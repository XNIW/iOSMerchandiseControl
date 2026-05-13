# TASK-105 Evidence 12 - Build / Device / Environment

## Provenance

| Voce | Valore |
|------|--------|
| Repo | iOSMerchandiseControl |
| Xcode | 26.5, build 17F42 |
| Scheme | iOSMerchandiseControl |
| Configuration build finale | Release |
| Simulator | iPhone 17 Pro, iOS 26.5 |
| Physical iPhone | iPhone reale, modello/iOS redatti: iPhone 15 Pro Max, iOS 26.5 |
| Supabase project | merchandisecontrol-dev, project ref redacted |
| Network/Supabase | MCP read-only queries eseguite |

## Build

| Check | Stato | Note |
|-------|-------|------|
| `xcodebuild -list` | PASS | Scheme iOSMerchandiseControl rilevato. |
| Release simulator build | PASS | Exit 0. |
| Release simulator build/run via XcodeBuildMCP | PASS | Build/install/launch su iPhone 17 Pro simulator, screenshot smoke acquisito fuori evidence. |
| Physical iPhone Debug build | PASS | Build firmata localmente; output personale/profilo non riportato in evidence. |
| Physical iPhone install/launch | PASS | `devicectl` install e launch exit 0, bundle id redatto in log evidence. |
| Warning nuovi da file TASK-105 | PASS | Nessun warning osservato nei file modificati. |
| Warnings legacy regression slice | PASS_WITH_NOTES | Warnings preesistenti in test legacy non modificati da TASK-105. |
| Xcode project membership | PASS | App e test usano `PBXFileSystemSynchronizedRootGroup`; nessun duplicato file TASK-105 rilevato. |

## Stato

PASS.
