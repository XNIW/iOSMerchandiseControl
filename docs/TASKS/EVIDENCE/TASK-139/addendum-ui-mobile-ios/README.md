# TASK-139 addendum UI mobile — iOS evidence draft

> **Evidence storico superseduto per lo stato corrente.** I `NOT_RUN_BY_P0`
> sotto descrivono soltanto il primo checkpoint senza boot. XCTest e gate
> successivi sono stati eseguiti e sono riepilogati in
> [`../13-post-choice-runtime-checkpoint-ios.md`](../13-post-choice-runtime-checkpoint-ios.md).
> Camera fisica e gli opt-in esplicitamente saltati restano invece non eseguiti;
> nessun PASS viene dedotto retroattivamente.

Stato del checkpoint originario: `READY_FOR_REVIEW / REVIEW`.
Stato corrente: `REVIEW_WITH_IOS_POST_REPLACE_CONVERGENCE_BLOCKER / REVIEW`.

Questa cartella documenta l'addendum iOS autorizzato dopo l'handoff originale
di TASK-139. Non sostituisce il ledger precedente e non marca il task `DONE`.

## Risultato implementato

- `DatabaseProductRow` è rimasta invariata: thumbnail `72×72` a sinistra e
  informazioni prodotto/azioni a destra.
- L'editor di un prodotto sincronizzato espone camera primaria per prima quando
  disponibile, libreria secondaria sempre presente e rimozione separata/distruttiva.
- `ViewThatFits` passa da layout orizzontale a verticale quando la larghezza o il
  Dynamic Type non permettono la riga compatta.
- Un prodotto nuovo o solo locale continua a mostrare esclusivamente il messaggio
  save/sync-first; nessun picker o upload viene esposto in quel ramo.
- Dopo il preprocessing bounded, lo store espone una preview locale transiente
  senza cambiare il riferimento remoto del modello. La preview viene rimossa su
  cancel/failure/scope switch; su finalize riuscito main e thumb nuovi entrano in
  memoria prima della rimozione della versione precedente.
- Gli upload/remove hanno un UUID per prodotto: un'operazione precedente non può
  azzerare stage/preview/cache di quella successiva.
- Il picker camera conserva e cancella il task fallback, elimina la lease del file
  temporaneo su dismantle/dismiss/cancel e trasferisce il file solo al callback di
  capture riuscito.
- Il cambio account/shop chiude editor, storico, add-product e scanner, annullando
  anche il focus task dello scanner.
- Aggiunte label/accessibility identifier, rispetto Reduce Motion e localizzazioni
  `it/en/es/zh-Hans` per import e preview transiente.

## Evidence host eseguita (nessun boot)

| Check | Esito | Evidence |
|---|---|---|
| Build app Debug, destination generica | `PASS` | `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath <external-derived-data> build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED` |
| Compilazione app + intero target XCTest | `PASS` | stesso comando con `build-for-testing` → `TEST BUILD SUCCEEDED`; include `Task139ProductImageAddendumTests.swift` e la fixture |
| `git diff --check` | `PASS` | exit `0`, nessun output |
| Fixture test | `PASS_COPY` | PNG `1254×1254`; SHA-256 origine/copia `48611b9ec51fc9ec743b06b8a91d971fa6932cbf47418b2c41c143be9d86255b` |
| Esecuzione XCTest | `NOT_RUN_BY_P0` | l'utente ha richiesto stop dopo i gate host; nessun Simulator può essere avviato |
| Visual QA finale / screenshot | `NOT_RUN_BY_P0` | nessun nuovo screenshot generato; le immagini del precheck non sono riusate come PASS |
| Camera fisica | `DEVICE_PHYSICAL_NOT_RUN` | nessun device fisico disponibile/autorizzato |

## Copertura test aggiunta

- processing della fixture tramite `ProductImageProcessor` reale e verifica
  JPEG/budget/metadata/dimensioni;
- preview transiente con vecchia immagine ancora presente, finalize e seed main/thumb;
- failure e cancel: preview rimossa, immagine corrente preservata;
- injection disponibilità camera e ordine reale camera → libreria;
- separazione remove, save-first locale, stage/cancel, Reduce Motion e identifier;
- lease temporanea camera eliminata su dismantle;
- cambio scope chiude editor/storico/add/scanner;
- composizione riga database e presenza delle nuove chiavi nelle quattro lingue.

I test sono stati compilati dal gate `build-for-testing`, ma non eseguiti per il
vincolo P0. Nessun `PASS` runtime viene quindi dichiarato.

## Precheck runtime non usato come acceptance

Prima del P0 era stato usato il Simulator dedicato `TASK-139 iPhone 17`, UDID
`9947126B-C72D-4A9A-BF75-087C3032C200`, poi spento con shutdown puntuale. Il
precheck aveva confermato soltanto il ramo save/sync-first e aveva trovato il
cloud non configurato; prodotti sincronizzati con/senza immagine erano
`BLOCKED_ENV`. Gli screenshot sintetici precedenti non sono evidence finale.

## Rischi residui del checkpoint originario

- Gli XCTest addendum erano `NOT_RUN_BY_P0` in questo checkpoint; il loro run
  successivo è registrato sotto. Il visual QA manuale non viene promosso a PASS
  per inferenza dai test.
- Verificare camera su device fisico.
- Convalidare prodotti sincronizzati con e senza immagine in un ambiente cloud
  privacy-safe configurato.
- Handoff a reviewer; `DONE` resta subordinato alla conferma esplicita dell'utente.

## Checkpoint successivo che supersede i NOT_RUN storici

Il vincolo del primo checkpoint è stato successivamente rimosso e i gate sono
stati eseguiti su Simulator isolato. Il risultato centrale finale è:

- core owner/shop/journal/scope `162/162`;
- UX/lifecycle, incluso l'addendum UI, `82/82`;
- Product Images `73` eseguiti: `70` pass e `3` skip opt-in;
- automatic domain `23/23`;
- totale `340` eseguiti: `337` pass, `3` skip, `0` failure;
- supplementare mirato `58/58`, sovrapposto al core e non sommato;
- `build-for-testing` PASS con `8` warning soltanto nei test legacy;
- analyze PASS con `18` issue esclusivamente in `Vendor 2/libxls`, `xls.c` e
  `ole.c`.

L'audit post-fix ha rilevato che `Task.detached` non eredita il `TaskLocal`.
Lease esplicite ora proteggono nove save automatici + outbox, tre watermark e
la baseline catalogo; sessione e result `sync_event` sono validati per
owner/shop. Due test nuovi coprono il confine. Gate eseguiti sul Simulator
isolato `2B23…`; xcresult conservato fuori dal repository.

Il run iniziale `178/183` con cinque failure resta evidence reale: le failure
sono state corrette, non mascherate. I vecchi `NOT_RUN_BY_P0` per l'esecuzione
XCTest non sono quindi il verdict corrente; camera fisica, i tre opt-in Product
Images e staging mutativo dedicato restano non eseguiti.

Separatamente, l'utente ha toccato realmente `Sostituisci con dati cloud` sulla
build installata. Il replace è avvenuto ma la convergenza non è dimostrata:
orchestrator `idle/noWork` e
`policyBlocked / sync_event_missing_entity_ids`. Per questo TASK-139 resta
`REVIEW_WITH_IOS_POST_REPLACE_CONVERGENCE_BLOCKER / REVIEW`, mai `DONE`.
