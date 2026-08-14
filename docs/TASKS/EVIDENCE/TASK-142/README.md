# TASK-142 evidence index

## Scope

Evidence privacy-safe per l'integrazione iOS device-free di WECHAT-006. Nessun
AppSecret, `session_key`, token, codice Auth o identificatore portale completo è
registrato qui.

## SDK provenance

| Campo | Valore |
|---|---|
| Distribuzione | Tencent ufficiale, XCFramework artifact etichettato `NoPay` |
| Versione | `2.0.7` |
| Download SHA-256 | `882d99dabd26aceb6ad3e7a12c4b7da8a37626e68a04c8b89740c2275db24258` |
| Device binary SHA-256 | `d762a75ab8129fe5331de39c3a01370dc3f0284897baefb6339422c56c668e45` |
| Simulator binary SHA-256 | `8bc77e5a56f9bdbaab69c51fae7b003f28ce64e21befcf0255fc8fde8a2b4b07` |
| Payment exposure | target `BUILD_WITHOUT_PAY=1`; applicazione login-only, nessun uso payment |

## Verification matrix

| Gate | Risultato | Nota |
|---|---|---|
| Focused WeChat XCTest | `PASS` | 12 eseguiti, 0 failure/skip |
| Full unit/integration | `PASS` | 1.336 eseguiti, 36 skip opt-in, 0 failure |
| Full XCUITest | `PASS` | 4 eseguiti, 0 failure |
| Release Simulator build | `PASS` | `BUILD SUCCEEDED`; solo warning AppIntents baseline |
| Debug Analyze canonico | `PASS_WITH_NOTES` | `ANALYZE SUCCEEDED`; issue solo in `Vendor 2/libxls`, 0 nei file task |
| Repository sensitive scan | `PASS` | nessuna credenziale introdotta |
| Release bundle sensitive scan | `PASS` | nessuna stringa WeChat/server secret o service role |
| Release install/launch | `PASS` | processo stabile su Simulator, flag WeChat OFF |
| `git diff --check` | `PASS` | nessun whitespace error |
| Commit / PR | `PASS / MERGED` | commit `2a632d27`; PR `#7`; CI `31761529498` PASS; normal merge `6571f4b661c4b815cfad4f6ad9139071b978f76d` |
| Live WeChat Auth | `BLOCKED_EXTERNAL` | AppID/Universal Link/Associated Domains/device/accesso portale mancanti |

## External evidence

I log completi e gli screenshot sono fuori dal repository nella directory
ristretta del closeout WECHAT-006:

`/Users/minxiang/Projects/_codex-evidence/wechat-006-shared-staging-closeout-20260813T234745Z/ios`

Il full gate canonico è `ios-full-xctest-final.log`; build Release
`ios-release-build.log`; Analyze valido `ios-debug-analyze-final.log`. Il log
`ios-release-analyze.log` conserva il tentativo non applicabile che fallisce
per `@testable` su modulo Release senza testability e non viene rappresentato
come analyzer finding.

## External activation prerequisites

- Mac sbloccato e accesso portale WeChat approvato.
- AppID iOS reale per bundle `com.niwcyber.iOSMerchandiseControl`.
- Universal Link verificato e Associated Domains entitlement corrispondente.
- AppID URL scheme esatto nel bundle.
- Device fisico con WeChat e account autorizzato.
- Conferma puntuale prima di ogni modifica persistente nel portale.

Fino al completamento di questi prerequisiti la feature resta OFF e nessun live
login/cold callback/cross-platform identity test è dichiarato PASS.
