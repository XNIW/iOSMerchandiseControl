# TASK-138 iOS Final Review Runbook

## Stato

- task: `DONE / DONE_RECONCILED`;
- scope: sola lane iOS, nessun Supabase live;
- Simulator: `PASS`, runtime seriale completato e device spento;
- build generica app + intero target test: `PASS`,
  `** TEST BUILD SUCCEEDED **`;
- Xcode Analyze generico: `PASS`, exit `0`;
- trasformazione offline della copia `.xctestrun`: `PASS`;
- assenza configurazione parity: skip XCTest esplicito preservato;
- nessun token viene aggiunto alla `.xctestrun`, al repository o agli
  attachment.

La soluzione evita il data container dell'app, che Xcode ruota quando reinstalla
il test host. La config esterna viene copiata invece nel `/tmp` stabile del
Simulator con mode esatto `0600`; la `.xctestrun` contiene soltanto il path
`/tmp/task138-ios-local-parity.json` e, per i due test mutanti, la singola parola
`replace` oppure `remove`.

## Precondizioni runtime

Il coordinatore fornisce `TASK138_HOST_CONFIG` come path assoluto a un JSON
esterno al repository. Il file contiene la sola fixture locale autorizzata e
deve essere gia `0600`. Non usare `cat`, `plutil -p`, shell tracing o comandi che
ne stampino il contenuto.

```text
TASK138_SIMULATOR_UDID=240F400E-5EFA-486A-9137-FFBBE70F604D
TASK138_DERIVED_DATA=/tmp/task138-ios-final-review-derived
TASK138_XCTESTRUN_SOURCE=/tmp/task138-ios-final-review-derived/Build/Products/iOSMerchandiseControl_iOSMerchandiseControl_iphonesimulator26.5-arm64-x86_64.xctestrun
TASK138_SIMULATOR_DATA_DIR="$HOME/Library/Developer/CoreSimulator/Devices/$TASK138_SIMULATOR_UDID/data"
TASK138_SIMULATOR_CONFIG_HOST="$TASK138_SIMULATOR_DATA_DIR/tmp/task138-ios-local-parity.json"
TASK138_CONFIG_IN_RUNNER=/tmp/task138-ios-local-parity.json
TASK138_APP=/tmp/task138-ios-final-review-derived/Build/Products/Debug-iphonesimulator/iOSMerchandiseControl.app
TASK138_BUNDLE_ID=com.niwcyber.iOSMerchandiseControl

test -f "$TASK138_HOST_CONFIG"
test "$(stat -f '%Lp' "$TASK138_HOST_CONFIG")" = 600
test -f "$TASK138_XCTESTRUN_SOURCE"
test -d "$TASK138_APP"
xcrun simctl boot "$TASK138_SIMULATOR_UDID"
xcrun simctl bootstatus "$TASK138_SIMULATOR_UDID" -b
install -m 600 "$TASK138_HOST_CONFIG" "$TASK138_SIMULATOR_CONFIG_HOST"
test "$(stat -f '%Lp' "$TASK138_SIMULATOR_CONFIG_HOST")" = 600
```

`TASK138_HOST_CONFIG` non va mai valorizzata con il contenuto JSON: e solo il
path esterno gia concordato. Il device scelto e iPhone 17 Pro iOS 26.5 ed era
`Shutdown` al momento della preparazione.

## Helper `.xctestrun`

Per ogni gate creare una copia nuova. `mktemp` e la copia non contengono la
config; `plutil` aggiunge solo path e autorizzazione mutazione.

La copia deve restare adiacente alla `.xctestrun` originale: spostarla in
`/tmp` rompe i riferimenti relativi `__TESTROOT__`. Su macOS il suffisso
`.xctestrun` va aggiunto dopo `mktemp`, altrimenti puo diventare parte letterale
del template.

```text
task138_make_xctestrun_copy() {
  local label="$1" seed target directory
  directory=$(dirname "$TASK138_XCTESTRUN_SOURCE")
  seed=$(mktemp "$directory/task138-$label.XXXXXX")
  target="$seed.xctestrun"
  mv "$seed" "$target"
  cp "$TASK138_XCTESTRUN_SOURCE" "$target"
  chmod 600 "$target"
  printf '%s\n' "$target"
}
```

### Read-only

```text
TASK138_READ_XCTESTRUN=$(task138_make_xctestrun_copy read)
plutil -insert TestConfigurations.0.TestTargets.0.EnvironmentVariables.TASK138_LOCAL_PARITY_CONFIG_PATH \
  -string "$TASK138_CONFIG_IN_RUNNER" "$TASK138_READ_XCTESTRUN"

xcodebuild test-without-building \
  -xctestrun "$TASK138_READ_XCTESTRUN" \
  -destination "platform=iOS Simulator,id=$TASK138_SIMULATOR_UDID" \
  -resultBundlePath docs/TASKS/EVIDENCE/TASK-138/final-local-parity-read.xcresult \
  -only-testing:iOSMerchandiseControlTests/ProductImageAPIClientTests/testOptInLocalParityNoImageAndProgressiveProductImage
```

Senza `TASK138_LOCAL_PARITY_CONFIG_PATH` lo stesso test deve risultare `SKIP`,
non failure. Con config valida verifica Product A senza `versionID` e Product B
progressivo thumb/main usando solo endpoint loopback.

### Replace locale, separato

```text
TASK138_REPLACE_XCTESTRUN=$(task138_make_xctestrun_copy replace)
plutil -insert TestConfigurations.0.TestTargets.0.EnvironmentVariables.TASK138_LOCAL_PARITY_CONFIG_PATH \
  -string "$TASK138_CONFIG_IN_RUNNER" "$TASK138_REPLACE_XCTESTRUN"
plutil -insert TestConfigurations.0.TestTargets.0.EnvironmentVariables.TASK138_LOCAL_PARITY_MUTATION_MODE \
  -string replace "$TASK138_REPLACE_XCTESTRUN"

xcodebuild test-without-building \
  -xctestrun "$TASK138_REPLACE_XCTESTRUN" \
  -destination "platform=iOS Simulator,id=$TASK138_SIMULATOR_UDID" \
  -resultBundlePath docs/TASKS/EVIDENCE/TASK-138/final-local-parity-replace.xcresult \
  -only-testing:iOSMerchandiseControlTests/ProductImageAPIClientTests/testOptInLocalParityMutationReplacesProductImage
```

Il test usa un JPEG sintetico, richiede endpoint loopback, esegue il service
reale e lascia la nuova versione sul Product B per la verifica cross-platform.
L'attachment riporta solo operazione, stato e fingerprint della versione.

Fermarsi dopo `replace`: il coordinatore verifica il medesimo Product B dalle
altre piattaforme e aggiorna fuori repository `versionID` nella config 0600 con
la versione corrente ottenuta dal backend locale. Nessun UUID completo viene
stampato o scritto nell'evidence iOS.

### Remove locale, separato

Ricopiare la config aggiornata nel `/tmp` Simulator prima del run:

```text
install -m 600 "$TASK138_HOST_CONFIG" "$TASK138_SIMULATOR_CONFIG_HOST"
TASK138_REMOVE_XCTESTRUN=$(task138_make_xctestrun_copy remove)
plutil -insert TestConfigurations.0.TestTargets.0.EnvironmentVariables.TASK138_LOCAL_PARITY_CONFIG_PATH \
  -string "$TASK138_CONFIG_IN_RUNNER" "$TASK138_REMOVE_XCTESTRUN"
plutil -insert TestConfigurations.0.TestTargets.0.EnvironmentVariables.TASK138_LOCAL_PARITY_MUTATION_MODE \
  -string remove "$TASK138_REMOVE_XCTESTRUN"

xcodebuild test-without-building \
  -xctestrun "$TASK138_REMOVE_XCTESTRUN" \
  -destination "platform=iOS Simulator,id=$TASK138_SIMULATOR_UDID" \
  -resultBundlePath docs/TASKS/EVIDENCE/TASK-138/final-local-parity-remove.xcresult \
  -only-testing:iOSMerchandiseControlTests/ProductImageAPIClientTests/testOptInLocalParityMutationRemovesProductImage
```

`replace` e `remove` hanno gate indipendenti: il valore sbagliato o assente
produce uno skip esplicito. Non eseguire entrambi in un solo comando.

## Sei stati visuali sintetici

Il target esistente non contiene un UI-test target separato. Il pass aggiunge
quindi due superfici verificabili senza dipendenze o modifiche al progetto:

1. test visuale hosted che renderizza e allega sei PNG phone-size;
2. root DEBUG dell'app, attivata solo con una delle sei stringhe note, per
   screenshot reali dal Simulator.

La fixture usa UUID, testo e immagini sintetici; il root DEBUG usa dipendenze
hosted nil e non registra background sync, quindi non inizializza Supabase e non
esegue rete.

```text
xcodebuild test-without-building \
  -xctestrun "$TASK138_XCTESTRUN_SOURCE" \
  -destination "platform=iOS Simulator,id=$TASK138_SIMULATOR_UDID" \
  -resultBundlePath docs/TASKS/EVIDENCE/TASK-138/final-visual-snapshots.xcresult \
  -only-testing:iOSMerchandiseControlTests/Task138ProductImageVisualHarnessTests

xcrun simctl install "$TASK138_SIMULATOR_UDID" "$TASK138_APP"
```

Poi, serialmente per ciascun valore, lanciare l'app e acquisire il PNG:

```text
TASK138_VISUAL_STATE=list
SIMCTL_CHILD_TASK138_PRODUCT_IMAGE_VISUAL_STATE="$TASK138_VISUAL_STATE" \
  xcrun simctl launch --terminate-running-process \
  "$TASK138_SIMULATOR_UDID" "$TASK138_BUNDLE_ID"
sleep 1
xcrun simctl io "$TASK138_SIMULATOR_UDID" screenshot \
  "docs/TASKS/EVIDENCE/TASK-138/screenshots/ios-$TASK138_VISUAL_STATE.png"
```

Ripetere sostituendo soltanto `TASK138_VISUAL_STATE` con:

- `list`;
- `detail-thumb`;
- `detail-main`;
- `editor-picker`;
- `offline-cache`;
- `error-fallback`.

Valori assenti o sconosciuti non attivano l'harness e preservano il root
normale. Prima del runtime creare la directory screenshot solo se assente.

## Cache/memoria 200 scroll e open20

I nuovi test sono deterministici e non usano la config locale:

```text
xcodebuild test-without-building \
  -xctestrun "$TASK138_XCTESTRUN_SOURCE" \
  -destination "platform=iOS Simulator,id=$TASK138_SIMULATOR_UDID" \
  -resultBundlePath docs/TASKS/EVIDENCE/TASK-138/final-cache-stability.xcresult \
  -only-testing:iOSMerchandiseControlTests/ProductImageAPIClientTests/testFullScrollOfTwoHundredThumbnailsKeepsMemoryAndDiskBounded \
  -only-testing:iOSMerchandiseControlTests/ProductImageAPIClientTests/testTwentyProductsReopenedTwentyTimesDoNotGrowCachesMonotonically
```

Gli attachment JSON contengono solo contatori: download, massimo byte/entry
memoria, byte disco, prodotti e iterazioni. I gate assertano `<= 100` entry,
`<= 48 MiB` decoded, `<= 128 MiB` disco e nessuna crescita dopo il primo ciclo
open20.

## Cleanup obbligatorio

Eseguire anche dopo un failure, con target esatti:

```text
xcrun simctl terminate "$TASK138_SIMULATOR_UDID" "$TASK138_BUNDLE_ID" || true
test ! -e "$TASK138_SIMULATOR_CONFIG_HOST" || unlink "$TASK138_SIMULATOR_CONFIG_HOST"
test -z "${TASK138_READ_XCTESTRUN:-}" || test ! -e "$TASK138_READ_XCTESTRUN" || unlink "$TASK138_READ_XCTESTRUN"
test -z "${TASK138_REPLACE_XCTESTRUN:-}" || test ! -e "$TASK138_REPLACE_XCTESTRUN" || unlink "$TASK138_REPLACE_XCTESTRUN"
test -z "${TASK138_REMOVE_XCTESTRUN:-}" || test ! -e "$TASK138_REMOVE_XCTESTRUN" || unlink "$TASK138_REMOVE_XCTESTRUN"
xcrun simctl shutdown "$TASK138_SIMULATOR_UDID"
xcrun simctl list devices | rg Booted
```

L'ultimo comando deve produrre output vuoto. Non conservare la config nel
Simulator. Gli `.xcresult` devono essere sottoposti allo stesso scan pattern
JWT/Bearer/service-role gia usato nell'evidence 09; non copiare il contenuto
della config in alcun riepilogo.

## Gate non-Simulator eseguiti in questo pass

```text
git diff --check
xcodebuild -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/task138-ios-final-review-derived \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

Risultato reale: exit `0`, `** TEST BUILD SUCCEEDED **`. Il build ha compilato
anche i test parity read/replace/remove, i test cache 200/open20, l'harness e i
test visuali. La prova offline ha creato una copia temporanea della `.xctestrun`,
aggiunto path e `replace`, letto soltanto questi due valori e cancellato la
copia; output atteso osservato, nessun dato config letto.

`xcodebuild -quiet ... analyze`, con destination generica, DerivedData separato
in `/tmp` e signing disabilitato: exit `0`. Il primo output completo riportava
soltanto i finding vendor `Vendor 2/libxls` e warning test legacy gia documentati,
piu una deprecazione nel nuovo renderer hosted; quest'ultima e stata rimossa e
il rerun incrementale finale e uscito `0` senza output. Build-for-testing
rieseguita dopo la correzione: exit `0`.

Stato finale: runtime `PASS`; il task e `DONE` dopo conferma esplicita utente.
Device fisico e staging/dev autenticato restano prerequisiti esterni non
disponibili e non sono dichiarati PASS.
