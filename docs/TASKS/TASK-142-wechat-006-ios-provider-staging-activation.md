# TASK-142 — WECHAT-006 iOS provider and staging activation

## Stato

- Stato: `REVIEW_READY`
- Fase: `REVIEW / EXTERNAL_ACTIVATION_PENDING`
- Coordination key: `WECHAT-006`
- Repository: `XNIW/iOSMerchandiseControl`
- Baseline: `origin/main` `99aa69c483b6c98c70d20d0fc9311f41240b325b`
- Branch applicativa/merge: `codex/wechat-006-ios-provider` / `6571f4b661c4b815cfad4f6ad9139071b978f76d`
- Branch documentale corrente: `codex/wechat-006-ios-closeout`
- Apertura: `2026-08-13`
- Responsabile attuale: `DESIGNATED_REVIEWER`
- Autorizzazione: mandato utente WECHAT-006 per task, SDK/provider, test,
  commit, push, PR e merge normali; produzione e App Store esclusi.

## Contesto governance

TASK-141 resta `DONE / USER_CONFIRMED_CLOSURE` e non viene riaperto. Il progetto
era IDLE, quindi TASK-142 assume la singola lane iOS. WECHAT-004 ha integrato il
contratto Auth ma il provider principale resta strutturalmente non configurato;
il device/AppID/Universal Link possono restare esterni senza impedire il
completamento device-free del provider ufficiale fail-closed.

## Obiettivo

Integrare una distribuzione Tencent verificata e pinned del WeChat OpenSDK,
implementare il provider reale e i callback cold/warm con configurazione
pubblica environment-driven, preservando AppSecret server-only, flag OFF fino
all'approvazione e tutte le regressioni Auth/sync esistenti.

## Scope

- Verifica versione/provenienza ufficiale corrente di WechatOpenSDK.
- Dipendenza pinned e integrazione minima nel progetto.
- WXApi registration, URL scheme, Universal Link e Associated Domains pubblici/configurabili.
- Provider reale, cold/warm/duplicate callback, cancel/deny/state/replay/expiry.
- App non installata, backend error, session import/restore/logout e flag staging.
- Localizzazioni/VoiceOver applicabili, Google regression, sync regression.
- Test, build, bundle secret scan, commit/PR/CI/merge normale.
- Live device test solo con AppID/Universal Link/device approvati disponibili.

## Non incluso

- AppSecret, session_key o token WeChat nel bundle/log/storage.
- App Store/TestFlight, produzione, pagamenti/contratti/2FA/legal declarations.
- Modifiche Supabase/Android/Mini o refactor iOS non necessari.
- Provider improvvisato, JWT artigianale o fake email identity.

## Criteri di accettazione

| ID | Criterio |
|---|---|
| I-142-01 | SDK e artifact provengono dalla distribuzione Tencent ufficiale corrente e sono pinned. |
| I-142-02 | Il main path usa un provider reale quando la configurazione pubblica è valida; in assenza resta fail-closed con flag OFF. |
| I-142-03 | AppSecret/session_key/token/codice Auth non entrano nel bundle, log o storage durevole. |
| I-142-04 | WXApi, scheme, Universal Link, Associated Domains e cold/warm callback sono integrati senza valori inventati. |
| I-142-05 | Cancel/deny/state mismatch/replay/expiry/duplicate/uninstalled/backend error hanno test deterministici. |
| I-142-06 | Restore/logout, Google Auth e sync regressions passano. |
| I-142-07 | Focused/full XCTest, simulator build, Release/Analyze applicabili e secret scan passano. |
| I-142-08 | Live device Auth passa oppure registra l'esatto prerequisito AppID/Universal Link/device senza falso PASS. |
| I-142-09 | Ogni modifica è integrata con commit, ready PR, required CI e merge normale. |

## Decisioni

| # | Decisione | Motivazione |
|---|---|---|
| 1 | Usare soltanto una distribuzione Tencent ufficialmente verificabile. | Evita mirror/fork non fidati. |
| 2 | Configurazione AppID/Universal Link pubblica e environment-driven; flag default OFF. | Consente il completamento strutturale senza inventare approvazioni. |
| 3 | Il code exchange e tutti i secret restano nel gateway Admin. | Preserva il boundary Auth canonico. |
| 4 | Un test device-free non equivale a login WeChat live. | Mantiene evidence fattuale. |

## Planning

1. Auditare progetto, provider esistente, dependency manager, callback e test.
2. Verificare versione/provenienza ufficiale corrente.
3. Implementare l'integrazione minima fail-closed e i test negativi.
4. Eseguire focused/full/build/analyze/secret gates.
5. Eseguire live device solo se i prerequisiti reali esistono.
6. Integrare normalmente e consegnare evidence a WECHAT-006.

## Execution

- Worktree isolato creato dall'attuale `origin/main`.
- Verificata la pagina download Tencent ufficiale il `2026-08-13`: OpenSDK
  iOS corrente `2.0.7`; scaricato l'XCFramework ufficiale
  `OpenSDK2.0.7_NoPay.zip` e verificato SHA-256
  `882d99dabd26aceb6ad3e7a12c4b7da8a37626e68a04c8b89740c2275db24258`.
- Vendorizzato senza repackaging `Vendor/WeChat/WechatOpenSDK-NoPay.xcframework`.
  Hash binari: device
  `d762a75ab8129fe5331de39c3a01370dc3f0284897baefb6339422c56c668e45`,
  Simulator
  `8bc77e5a56f9bdbaab69c51fae7b003f28ce64e21befcf0255fc8fde8a2b4b07`.
- L'archivio Tencent etichettato `NoPay` conserva header/simboli condivisi dietro
  `BUILD_WITHOUT_PAY`; il target definisce esplicitamente
  `BUILD_WITHOUT_PAY=1`. Il codice applicativo integra soltanto
  `WXApi`/`SendAuthReq`/`SendAuthResp` e non contiene richieste, UI o config di
  pagamento.
- Implementato `OpenSDKWeChatAuthorizationCodeProvider`: registrazione AppID +
  Universal Link, handoff `snsapi_userinfo`, callback URL/Universal Link,
  mapping success/cancel/deny/error, single pending continuation e fail-closed
  per app WeChat assente/non supportata o invio SDK fallito.
- La configurazione pubblica legge environment e `SupabaseConfig.plist` locale
  ignorato; richiede flag, AppID valido, Universal Link HTTPS con slash finale e
  gateway HTTPS. Il provider richiede inoltre che il bundle contenga l'esatto
  AppID come URL scheme prima di chiamare `WXApi.registerApp`.
- Aggiunti query schemes Tencent pubblici, callback warm/cold SwiftUI e routing
  coordinato con il callback OAuth Google esistente. Nessun AppID, Universal
  Link o entitlement inventato è stato inserito.
- Il primo full XCTest ha rilevato un solo failure nel contratto statico storico
  del callback OAuth (`TASK-112`); applicato il fix sintattico minimo senza
  cambiare il comportamento. Rerun finale verde.
- Focused WeChat finale: `12/12`, zero failure/skip.
- Full XCTest finale: `1.336` unit/integration, `36` skip opt-in attesi,
  `0` failure; XCUITest `4/4`, `0` failure.
- Build Release Simulator: `PASS`. Analyze Debug canonico: `PASS_WITH_NOTES`,
  con soli issue storici nel vendorizzato `Vendor 2/libxls` e zero warning/error
  nei file WECHAT-006. Il tentativo Analyze Release non è un gate valido per lo
  scheme corrente perché i test `@testable` non possono importare il modulo
  Release senza testability; build Release resta verde.
- Secret scan repository e scan del bundle Release: `PASS`; nessuna stringa
  AppSecret, `session_key` o service role nel prodotto. Privacy manifest
  aggregato presente nel bundle.
- Install/launch Release su Simulator: `PASS`, processo stabile con flag WeChat
  OFF e nessun valore provider nel bundle.
- Commit applicativo `2a632d2772072e3f2efc00ac8b1fc433fa3ee1e2`
  pushato sul branch `codex/wechat-006-ios-provider`; PR normale GitHub
  `XNIW/iOSMerchandiseControl#7` aperta ready-for-review e mergeable.
- Required CI pull request `31761529498` completata `PASS` in `25m55s`:
  contract hashes, Debug build, full XCTest, Analyze e secret scan verdi.
- PR `#7` unita normalmente il `2026-08-14` con merge commit
  `6571f4b661c4b815cfad4f6ad9139071b978f76d`; commit applicativo e handoff
  documentale sono antenati di `origin/main`, branch feature remoto rimosso.
- Evidence privacy-safe: `docs/TASKS/EVIDENCE/TASK-142/README.md` e directory
  esterna ristretta WECHAT-006 indicata nel closeout coordinato.

## Review

- Esito tecnico device-free: `READY_FOR_DESIGNATED_REVIEW`.
- P0/P1 tecnici noti nel diff: `0`.
- Login WeChat live, cold callback reale e cross-platform same-user non sono
  dichiarati PASS: mancano AppID, Universal Link/Associated Domains approvati,
  accesso portale e device con WeChat.
- Nessun test non eseguito è marcato PASS o DONE.

## Fix

- `F-142-01` — contratto sorgente OAuth Google storico fallito nel primo full
  test: corretto mantenendo `authService?.handleOpenURL(url)` e il nuovo routing
  WeChat. Rerun full verde.
- Nessun finding P0/P1 aperto nel perimetro device-free.

## Handoff

`MERGED_DEVICE_FREE_EXTERNAL_ACTIVATION_HANDOFF` — required CI e merge normale
sono completati. L'attivazione live resta separata e richiede: Mac sbloccato,
accesso portale WeChat approvato, AppID iOS reale, Universal Link verificato,
Associated Domains e AppID URL scheme corrispondenti, device con WeChat e
conferma puntuale prima di ogni modifica persistente nel portale. Fino ad allora
`WECHAT_AUTH_IOS_ENABLED=0` e nessun claim live.
