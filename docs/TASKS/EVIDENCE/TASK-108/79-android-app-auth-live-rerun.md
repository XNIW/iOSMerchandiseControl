# TASK-108 Evidence 79 — Android app-auth live rerun after device login

**Data:** 2026-05-14 21:20 -0400  
**iOS repo branch:** `main`  
**iOS repo HEAD:** `74480c20c654a07174ba99dede2458d914426ab2`  
**Android repo branch:** `main`  
**Android repo HEAD:** `7cfc536b7200a7e2e4a2224800650d2e0b7f7ac0`  
**Supabase project:** `merchandisecontrol-dev`  
**Supabase project ref:** `jpgoimipbothfgkokyvm`  
**Verdict aggiornato:** Android app-auth pull/no-op/push-no-op `PASS` su dispositivo fisico e su emulatore.

## Contesto

Dopo la chiusura `TASK-108 DONE / PASS_WITH_NOTES`, l'utente ha confermato di aver eseguito login Android sia sul dispositivo fisico sia sull'emulatore. Questa evidence rivaluta il gap Android app-auth cross-device che in `78-final-codebase-review-and-regression.md` era rimasto non completato.

## Device e auth preflight

- `adb`: `/Users/minxiang/Library/Android/sdk/platform-tools/adb`
- Device fisico: `8ac48ff0`, OnePlus IN2013, Android 13.
- Emulatore: `emulator-5554`, Android API 35.
- Auth preflight strumentato: `Task103AuthPreflightTest#authSessionOwnerHashWhenEnabled`.
- Esito auth preflight:
  - `8ac48ff0`: `OK (1 test)`.
  - `emulator-5554`: `OK (1 test)`.

Nessun token, sessione raw, password o email e' riportato in questa evidence.

## Problemi trovati e fix applicati

1. **HIGH — log Android stampavano lo stato sessione Supabase raw.**  
   Durante il preflight logcat e' emerso che `SupabaseAuthManager.restoreSession()` poteva serializzare oggetti sessione completi nei log debug. Fix: sostituito il log raw con `SessionStatus.safeLogLabel()`, limitato a label non sensibili (`Authenticated`, `Initializing`, `NotAuthenticated`, `Timeout`).

2. **MEDIUM/HIGH — ProductPrice pull Android troppo lento per dataset reale.**  
   Primo run live fisico: timeout interno `300000 ms` dopo apply parziale (`25.200` ProductPrice locali, duplicati `0`). Root cause nel path Android: apply ProductPrice faceva piu' query Room per ogni riga remota. Fix: batch per pagina in `applyProductPriceRows`, con query bulk per remote refs, product refs, prezzi esistenti, chunk a `900` parametri per query Room `IN (...)` e insert bulk dei bridge prezzo.

3. **MEDIUM — timeout HTTP Android troppo basso per pagine Supabase grandi su rete device.**  
   Dopo il batch apply, il secondo pull no-op ha colpito `HttpRequestTimeoutException` a `30000 ms` su una pagina `inventory_products`. Fix: `SupabaseClient.requestTimeout = 90.seconds` in `MerchandiseControlApplication`.

4. **LOW/MEDIUM — test live usava sync completa per verificare push no-op.**  
   La sync completa rifaceva un altro pull full prima del push, rendendo il check push-no-op rumoroso e lento. Fix: il test live ora usa `pushDirtyCatalogDeltaToRemote(...)`, lane incrementale corretta per verificare che non vengano inviate righe quando il locale e' gia' allineato.

## File Android modificati in questo rerun

- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/MerchandiseControlApplication.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/ProductPriceDao.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/ProductPriceRemoteRefDao.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/ProductRemoteRefDao.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/SupabaseAuthManager.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/androidTest/java/com/example/merchandisecontrolsplitview/Task108AndroidAppAuthLiveTest.kt`

Nota: il worktree Android conteneva gia' altre modifiche TASK-108 prima di questo rerun; non sono state revertite.

## Build e unit test Android

- `./gradlew assembleDebug assembleDebugAndroidTest --console=plain`: `BUILD SUCCESSFUL`.
- `./gradlew test --console=plain`: primo retry locale fallito per `AttachNotSupportedException` ByteBuddy/MockK nel daemon Gradle; dopo `./gradlew --stop`, rerun `./gradlew test --console=plain`: `BUILD SUCCESSFUL`, `:app:testDebugUnitTest` PASS.
- `git diff --check`: PASS.
- Warning Gradle/AGP presenti: deprecazioni note `android.builtInKotlin=false`, `android.newDsl=false`, legacy variant API; non introdotte come blocker TASK-108.

## Live test Android app-auth

Test aggiunto:

- `Task108AndroidAppAuthLiveTest#fullPullNoOpAndPushNoOpWhenEnabled`
- Gating esplicito: `-e task108AndroidLiveSync true`
- Flusso:
  1. verifica sessione app-auth signed-in;
  2. stop auto sync foreground/background;
  3. clear solo Room locale, non auth prefs;
  4. full pull catalogo/prezzi da Supabase;
  5. assert conteggi locali = conteggi remote fetch;
  6. assert duplicati ProductPrice locali = `0`;
  7. secondo full pull no-op;
  8. assert conteggi invariati e duplicati = `0`;
  9. push incrementale no-op;
  10. assert righe push = `0`.

Esiti:

- Device fisico `8ac48ff0`: `OK (1 test)`, tempo finale con APK corrente `237,516s`.
- Emulatore `emulator-5554`: `OK (1 test)`, tempo finale con APK corrente `39,33s`.

## Conteggi locali Android finali

Device fisico `8ac48ff0`:

- `products`: `19.695`
- `suppliers`: `57`
- `categories`: `27`
- `product_prices`: `41.109`
- `product_remote_refs`: `19.695`
- `product_price_remote_refs`: `41.109`
- duplicati `(productId,type,effectiveAt)`: `0`
- pending price bridge: `0`

Emulatore `emulator-5554`:

- `products`: `19.695`
- `suppliers`: `57`
- `categories`: `27`
- `product_prices`: `41.109`
- `product_remote_refs`: `19.695`
- `product_price_remote_refs`: `41.109`
- duplicati `(productId,type,effectiveAt)`: `0`
- pending price bridge: `0`

## Log privacy/security

Scan logcat post-fix:

- `8ac48ff0`: `sensitive_pattern_hits=0`, auth safe label hits `1`.
- `emulator-5554`: `sensitive_pattern_hits=0`, auth safe label hits `1`.

Pattern cercati senza stampare contenuti: token/sessione raw, bearer authorization, JWT-like strings, `UserSession`.

## Supabase finale non distruttivo

Query remote non distruttive via MCP Supabase:

- `inventory_suppliers`: `57`, owner distinti `1`
- `inventory_categories`: `27`, owner distinti `1`
- `inventory_products`: `19.695`, owner distinti `1`
- `inventory_product_prices`: `41.109`, owner distinti `1`
- duplicati remoti `inventory_product_prices(owner_user_id, product_id, type, effective_at)`: `0`
- ProductPrice senza prodotto attivo: `0`
- ProductPrice/Product owner mismatch: `0`
- indice remoto presente: `inventory_product_prices_owner_product_type_effective_uniq`

Nessun reset remoto, delete remoto o uso `service_role` eseguito in questo rerun.

## Verdict

Il gap Android app-auth live indicato in evidence `78` e' stato rieseguito e ora e' **PASS** per il flusso non mutativo: pull completo, secondo pull no-op e push incrementale no-op su entrambi i device autenticati.

Resta non eseguito volutamente un test mutativo Android prezzo `+1` verso Supabase seguito da pull iOS: il remote dev era gia' nello stato pulito atteso `41.109` e questa evidence ha evitato di sporcarlo ulteriormente senza richiesta esplicita. Il rischio residuo e' basso per TASK-108 iOS-first perche' iOS mutative push/repull e' gia' coperto da evidence `77`, e Android ora dimostra app-auth pull/no-op/no-op push idempotente su dataset reale.

**Verdict complessivo TASK-108 resta:** `DONE / PASS_WITH_NOTES`, con nota Android migliorata da "non completato" a "app-auth non mutativo PASS; mutativo Android->Supabase->iOS non rieseguito per non alterare il remote pulito".
