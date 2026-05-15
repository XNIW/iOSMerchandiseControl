# TASK-110 — P3 Android auth/logout/login/re-login runtime

Data: 2026-05-15

## Verdict

PASS runtime su emulatore Android.

PASS_WITH_NOTES per device fisico Android: `8ac48ff0` rilevato via adb, app installata, ma il device resta su schermata di blocco/keyguard dopo tentativi `KEYCODE_WAKEUP`, swipe e `KEYCODE_MENU`; non ho usato credenziali/passcode del dispositivo.

## Ambiente

- Android workspace: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`
- Emulatore: `emulator-5554`, `Medium_Phone_API_35`, Android 15
- Package: `com.example.merchandisecontrolsplitview`
- Account runtime: `x***@gmail.com`
- Owner hash: `ad3d747e936c` (coerente con iOS auth preflight)

## Sequenza runtime emulatore

1. Stato iniziale verificato: Options signed-out, `Sign in with Google`, `Sync now` disabilitato.
2. Login Google via account chooser: account `x***@gmail.com` selezionato.
3. UI post-login: `Signed in as x***@gmail.com`; `Sync now` abilitato.
4. Auto sync post-auth:
   - `sync_start source=automatic_session_bootstrap`
   - History bootstrap: `inserted=2 updated=0 skipped=0 dirtyLocalSkips=0 failed=0`
   - Catalog bootstrap: `productsPulled=19695 suppliersPulled=57 categoriesPulled=27 pricesPulled=41109 priceSyncFailed=false`
   - `pricesSkippedNoProductRef=0`
5. DB locale Android verificato via `run-as` + sqlite:
   - products: 19695
   - suppliers: 57
   - categories: 27
   - product_prices: 41109
   - product_refs: 19695
   - price_refs: 41109
   - duplicate ProductPrice logical keys: 0
6. Logout UI:
   - UI: `Not signed in`
   - `Sync now` disabilitato
   - log: realtime disconnesso per assenza sessione
   - log: `cycle=catalog_auto outcome=skip reason=signed_out`
   - log: `cycle=push outcome=skip reason=skipped_signed_out`
7. Re-login UI con account chooser:
   - UI: `Signed in as x***@gmail.com`
   - log: `Sign-in Google completato`
   - realtime e `sync_events` risottoscritti
   - push/catalog no-op senza sovrapposizione bloccante
8. Force-stop + launch:
   - log: `restoreSession: got status=Authenticated`
   - log: `Sessione ripristinata`
   - UI: account connesso
   - realtime/sync-events riattivati

## Test strumentali

### Auth preflight

Comando:

```bash
ANDROID_SERIAL=emulator-5554 ./gradlew :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.merchandisecontrolsplitview.Task103AuthPreflightTest \
  -Pandroid.testInstrumentationRunnerArguments.task103AuthPreflight=true
```

Esito: PASS.

Evidenza:

```text
TASK103_ANDROID_AUTH_PREFLIGHT project_hash=42a5d0119a30 owner_hash=ad3d747e936c signed_in=true
```

### Full pull / no-op / push no-op

Il primo tentativo con `connectedDebugAndroidTest` ha fallito con `AuthState.SignedOut` perché il runner Gradle reinstalla/rimuove il package app durante il ciclo connected test, perdendo la sessione OAuth creata via UI. Il log mostra `installPackageLI`, force-stop e poi package fully removed.

Per validare il runtime reale senza reinstall/uninstall automatico:

```bash
./gradlew :app:assembleDebug :app:assembleDebugAndroidTest
adb -s emulator-5554 install -r -t app/build/outputs/apk/debug/app-debug.apk
adb -s emulator-5554 install -r -t app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
# login UI con x***@gmail.com
adb -s emulator-5554 shell am instrument -w -r \
  -e class com.example.merchandisecontrolsplitview.Task108AndroidAppAuthLiveTest \
  -e task108AndroidLiveSync true \
  com.example.merchandisecontrolsplitview.test/androidx.test.runner.AndroidJUnitRunner
```

Esito: PASS.

Evidenza:

```text
OK (1 test)
TASK108_ANDROID_APP_AUTH_PULL_NOOP_PUSH_NOOP products=19695 suppliers=57 categories=27 product_prices=41109 product_refs=19695 price_refs=41109 remote_prices=41109 pushed_noop=0 first_pull_ms=23819 second_pull_ms=17081 push_ms=33
```

## Error handling osservato

- `sessionMissing`: non osservato.
- `42501`: non osservato nel runtime Android P3.
- `Operation cancelled` stale app-level: non osservato.
- Voci `onCancelled`/`Canceling task` osservate solo da servizi Android/Google system-level durante transizioni UI/Google Sign-In; non sono messaggi app né stati sync mostrati all'utente.

## Note residue

- Device fisico Android disponibile via adb ma non operabile per keyguard sicuro; emulatore usato come canale runtime completo.
- Il ciclo Gradle `connectedDebugAndroidTest` non è adatto a riusare una sessione OAuth manuale tra test live perché reinstalla/rimuove il package. La validazione runtime live è stata eseguita con `am instrument` dopo install e login UI.
