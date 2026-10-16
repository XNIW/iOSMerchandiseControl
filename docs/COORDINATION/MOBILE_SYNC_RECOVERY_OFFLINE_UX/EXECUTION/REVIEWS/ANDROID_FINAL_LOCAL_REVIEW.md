# Android — review finale locale dello snapshot congelato

Reviewer `/root/android_r01_final_review`, distinto dai writer. Seconda lettura indipendente di `/root/android_r01_final_review/transport_check` sul trasporto eventi, schema e semantica SDK. Perimetro: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`, HEAD `4b74ed5cfb4e4bce024513561e7dc1b6998003ae` con modifiche locali non integrate; [manifest finale dei 20 file](../20261015-01/android-final-gates-01-input.json).

**APPROVED_LOCAL_DELTA** per il codice esaminato. Tutti i 20 pin coincidevano alla verifica finale del reviewer. I gate unit/build/lint del coordinator sullo stesso snapshot sono ancora in corso alla redazione: nessun loro PASS viene anticipato. Questa è una review locale del delta, non una dichiarazione di risoluzione globale o di app installate accettate.

## Delta finale rispetto alla regressione02

La review eredita il perimetro esaminato in [regression candidata2](ANDROID_REGRESSION_CANDIDATE2.md) e [D01 candidata5](ANDROID_D01_CANDIDATE5.md), incluse le rispettive limitazioni ed evidenze rosse preservate. Dopo regression02 cambiano soltanto:

1. Application `49a412…` → `0d2e1c6401268999f899618e3b7556059b3c23661c14b5039df46bfc52cc53dc`: l'helper readiness legge i campi lazy dalla classe che li dichiara, `MerchandiseControlApplication::class.java`, invece della sottoclasse JVM. La [receipt](../20261015-01/android-readiness-declaring-class-repair-receipt.json) descrive il RED `BLOCKED_UNAVAILABLE` e l'unica espressione sostituita. Controlli `isInitialized`, cast, catch e divieto di inizializzare dipendenze restano invariati.
2. Event writer `c07c892…` → `199bc154cfcfdd8eb513c0a4f6e1277361839b42829db54470cb537f77539617`: il solo RPC canonico `record_sync_event_v6` usa un body non ripetibile dal trasporto. Il ramo legacy continua a usare `postgrest.rpc`; DTO, normalizzazione V6, ID, metadata, fallback e policy della coda non cambiano in questo delta.

Il percorso recovery reader con il precedente body non ripetibile è invariato. Nessuna nuova dipendenza o migrazione introdotta dalla correzione eventi.

## Confronto con le fonti SDK effettive

Lettura primaria dei source jar locali Supabase Android 3.6.0, coerenti con il progetto, e Ktor OkHttp 3.5.0. Nessuna ricerca web, build o chiamata SDK eseguita dal reviewer.

La [receipt di implementazione](../20261015-01/android-event-one-shot-implementation.receipt.json), SHA256 `4b3237db8bc046d6ed42013f49d5ba39e7d81262b529fa5d193262dbbd74bf17`, e la [raccolta delle fonti primarie locali](../20261015-01/android-event-one-shot-cached-primary-proof.json), SHA256 `68af9af10310aab8a7fc5da7e3a14b2a2755ce2c076e9ee2c858911ce44901df`, sono state lette e confrontate con questa review. Descrivono esplicitamente il limite dello schema blank nel pin intermedio; la [receipt di applicazione](../20261015-01/android-event-schema-blank-parity-apply.json) registra il passaggio finale a `199bc154…` soltanto dopo l'archiviazione di regression03.

- `PostgrestImpl.rpcRequest` costruisce il path `rpc/<function>` e usa il request builder con POST predefinito; il nuovo ramo usa lo stesso path e metodo. `authenticatedSupabaseApi` conserva risoluzione URL, access token/header, limite URL e parser errori del plugin PostgREST. La prova HTTP qualifica che il 503 originario rimanga un errore PostgREST strutturato, non un errore di body replay.
- `PostgrestRequestBuilder.apply` usa JSON, Accept application/json, Prefer vuoto nel caso RPC senza opzioni, e aggiunge Content-Profile soltanto quando lo schema non è blank. La prima patch `021884c…` aveva una differenza per schema blank: finding concreto preservato, corretto nel pin finale con la stessa condizione `isNotBlank()`. Non viene affermata equivalenza dello snapshot precedente per quel caso.
- Il body JsonObject viene codificato dalla stessa `supabaseJson` del percorso Ktor precedente. La response usa `PostgrestResult(..., postgrest).decodeAs`, conservando il serializer del plugin. Il timeout è quello effettivo di `postgrest.config.timeout`; nessun aumento introdotto.
- `ReadChannelContent` è trasformato dall'engine OkHttp in `StreamRequestBody` con `isOneShot() == true`. La guard atomica del body impedisce una seconda apertura; il cambiamento non disabilita auth, parser errori, timeout o admission.
- `GenerationOwnedSupabaseClient` viene catturato una volta all'inizio dell'invocazione RPC. Client, plugin, request e decoding dell'operazione usano quella cattura, senza ricatturare una nuova generazione a metà invio. Le guard repository/claim restano necessarie e invariate.

Nessun altro difetto concreto rilevato nel delta finale. L'ultima differenza rispetto a regression03 è soltanto la condizione sullo schema; la seconda lettura indipendente la conferma anche per stringhe vuote o composte da spazi.

## Prove eseguite e gate finali distinti

[Regressione03](../20261015-01/android-regression-03-summary.json), receipt 2026-10-16T04:41:46Z: **1328 casi JVM, 1321 PASS / 0 FAIL / 7 SKIP, exit 0**; [20 pin invariati](../20261015-01/android-regression-03-output.json). Include i precedenti due FAIL della regression02: readiness raggiunge la verifica locale e il vero invoker eventi riceve il 503 originale con un solo POST fisico per l'invocazione applicativa, conservando codice e body. Queste prove appartengono al pin eventi intermedio `021884c…`.

Dopo l'archiviazione è stata applicata la sola condizione sullo schema, pin finale `199bc154…`. Il coordinator sta eseguendo sul [manifest finale](../20261015-01/android-final-gates-01-input.json) regressione unit completa, assembleDebug, release non firmata e lint. I risultati e le receipt finali devono essere registrati separatamente; un risultato precedente non viene attribuito al nuovo pin per equivalenza presunta.

Le evidenze dei 32 FAIL e dei due FAIL successivi restano nei rispettivi summary/XML e nelle review precedenti; nessuno skip nuovo introdotto per nasconderle. Gli esiti locali non certificano CI sull'esatto SHA finale, installazione/upgrade, configurazione delle app già installate, UI reale, sincronizzazione TEST bidirezionale, performance, accessibilità o i legacy effettivamente presenti. Nessun DONE globale, push, merge o deploy autorizzato da questo documento.


### Risultati finali del runner — aggiunta executor

2026-10-16T05:01:31.715523+00:00. Il giudizio statico sopra resta del reviewer indipendente; questa sezione riporta soltanto l'esecuzione del root sul medesimo freeze20file `android-final-gates-01-input.json` (Event199bc154…). Unit:1328casi/1321PASS/0FAIL/7SKIP; assemblaDebug PASS; assembleRelease PASS unsigned; lint PASS con57warning/0error, nessunfinding sulle linee aggiunte (correlazione, non baseline lint). Exit0 e20pin invariati. Nessun warningKotlin; warningD8 del jarWeChat invariato conservati.

XML, reportlint, outputmanifest e due APK preservati nel runfolder. Gli APK non sono stati installati; Releaseunsigned non è un pacchetto distribuibile. Gradle9.6/AGP9.4.1/KSP2.3.6 sono WIPpreesistente preservato, distinti dalla configurazioneHEAD9.5.1/9.2.1/2.3.4. CIexactfinalSHA, ambienteTEST/app effettive, upgradelegacy e accettazione globale rimangono NOT_RUN/UNKNOWN secondo i rispettivi gate.
