# TASK-139 — FIX iOS post-replace: convergence policy e hardening finale

Data: `2026-07-21`

Verdict: `REVIEW_WITH_IOS_FIXES_VERIFIED_ISOLATED / REVIEW`

Responsabile successivo: `Claude/ChatGPT / Reviewer`

Chiusura: mai `DONE` senza conferma esplicita dell'utente. Questo documento
supersede evidence 13 esclusivamente come verdict corrente; le osservazioni
runtime storiche del tap reale restano valide nel loro perimetro.

## Esito

Le lacune correggibili senza modificare la sync policy, introdurre una nuova
state machine o ripetere la sostituzione sul database reale sono state corrette
nel candidato iOS. La matrice integrata isolata unica di `28` classi è verde
con `386` test totali: `383` pass, `3` skip opt-in e `0` failure.

La FIX non viene usata per dichiarare convergenza live: non è stato eseguito un
secondo replace, né installazione, clear-data o mutazione sul container
autenticato. TASK-139 torna a REVIEW e conserva un rischio P1 letterale di
atomicità fisica descritto sotto.

## Finding corretti

### RPC exactly-one

Il recorder `sync_event` accetta una risposta oggetto oppure array solo quando
contiene esattamente una riga valida. Risposta vuota e risposta multi-riga
falliscono con errore tipizzato; nessuna riga extra viene ignorata. Il risultato
continua a essere validato contro owner e shop esatti.

Evidence mirata: `29/29`.

### Outbox fail-closed

`automatic_scope_mismatch` durante la lane automatica viene persistito come
`blockedAuth`, non retryable, sotto lease valida. Il batch si interrompe dopo la
prima RPC e l'entry successiva resta invariata. Gli errori owner/shop e la lease
stale mantengono rollback/fail-closed; la lane manuale non è stata riscritta.

Evidence mirata: `32/32`.

### Lease owner/shop deterministica

Un test con semafori forza l'interleaving invalidazione/commit invece di
limitarsi a simulare uno scope stale. Il confine è risultato verde sia nel run
singolo sia in cinque ripetizioni consecutive.

Evidence mirata: singolo + repeat-5.

### Preflight recovery prima delle mutazioni

Duplicate lookup name e product conflict vengono rifiutati prima di qualsiasi
save catalogo, history, prezzi o baseline. Le fixture sentinella restano
invariate e le chiamate downstream sono zero.

Nel percorso replacement, la ricerca del watermark iniziale W0 è bounded a
massimo `512` pagine da `200` righe. L'esaurimento produce un errore tipizzato
invece di un loop indefinito.

Evidence mirata preflight + W0 budget: `3/3`.

### Recovery policy e progress bounded

È stata introdotta la fase durevole già coerente con lo state store esistente
`recoveryRequired`, senza duplicare la sync policy:

- un gap osservato durante drain/light reconcile, reconnect o `Check again`
  normale non viene promosso implicitamente a full snapshot;
- il run termina fail-closed in `recoveryRequired`, senza snapshot e senza
  falsi `success/noWork`;
- no-op, safety gate, recomposition e relaunch non cancellano la fase;
- cancel, failure, block e busy preservano il latch; `recoveryRequired` si
  libera soltanto dopo un successo verificato;
- solo il Retry CTA esplicito, identificato dal source `releaseCard`, può
  richiedere la recovery;
- una `requestRecovery` prodotta automaticamente dalla decision policy non è
  considerata consenso utente;
- i pending vengono pushati prima del drain e non autorizzano snapshot;
- nel percorso replacement, il tail incrementale è bounded a `50` pagine da
  `200` eventi, massimo `10.000`; su esaurimento il run fallisce, il watermark
  viene ripristinato e il journal resta disponibile per recovery;
- il replacement journal continua ad avviare automaticamente bootstrap/pull,
  con massimo due snapshot, quindi tail e reconcile; viene cancellato soltanto
  dopo conclusione verificata e rimuove il latch solo per il proprio percorso
  journal/bootstrap;
- una race Cancel→Retry immediato non perde il retry: la richiesta viene drenata
  dopo la chiusura cooperativa del run cancellato.

I default DI dell'engine ora vengono costruiti dallo stesso binding/scope
iniettato, evitando store impliciti incoerenti.

Evidence focus engine precedente all'estensione cancel: `90/90`; il gate
mirato finale recovery/cancel è `94/94`.

## Gate finali reali iOS

I run sono stati eseguiti su Simulator/fixture isolati. I test mirati si
sovrappongono alla matrice integrata e non vengono sommati.

| Gate | Risultato reale |
|---|---|
| Matrice integrata unica, 28 classi | `386` totali = `383` pass + `3` skip opt-in + `0` failure |
| Recovery/cancel finale | `94/94` |
| Focus engine precedente all'estensione cancel | `90/90` |
| RPC exactly-one | `29/29` |
| Outbox fail-closed | `32/32` |
| Recovery preflight + W0 budget | `3/3` |
| Lease interleaving | run singolo + repeat-5 verdi |
| Debug build | `PASS` |
| Analyze | `PASS`; sole issue analyzer in `Vendor 2/libxls`, file `xls.c` e `ole.c` |
| Contract shared | hash e byte parity con Admin e Android `PASS` |
| Localizzazioni | `4` `Localizable.strings`, `plutil` `PASS` |
| Workflow | YAML `PASS`; tutte le `8` classi Product Images presenti |
| Sensitive scan canonico | `PASS` |
| Git diff | `git diff --check` `PASS` |
| Index Git | staged vuoto |

Xcresult integrato: artifact esterno del run, non versionato.

Il comando `xcodebuild` è terminato con exit `0` in `154.678s`; la durata XCTest
riportata è `142.064s`. Il run ha usato
`-parallel-testing-enabled NO -test-timeouts-enabled NO`.

Artifact recovery/cancel `94/94`: xcresult esterno del run, non versionato.

I tre skip sono opt-in Product Images e restano skip. Camera fisica e staging
mutativo dedicato non sono stati eseguiti.

Le otto classi Product Images già incluse nel workflow e riconfermate sono:

1. `ProductImageAPIClientTests`
2. `ProductImageCacheTests`
3. `ProductImageOwnerStoreRaceTests`
4. `ProductImageProcessorTests`
5. `ProductImageSharedContractTests`
6. `ProductImageSyncContractTests`
7. `Task138ProductImageVisualHarnessTests`
8. `Task139ProductImageAddendumTests`

La copertura CI era già completa; non è stata aggiunta una modifica fittizia per
questo punto.

## Legacy scanner TASK-117

Il guard statico `no-full-pull` TASK-117 ha risultato `4/5` perché pretende un
blocco assoluto di ogni bootstrap/fullRecovery. Tale premessa è superseduta:
l'architettura corrente consente recovery soltanto in base a source/context
espliciti e mantiene il replacement journal automatico owner-safe.

Il risultato è quindi `NOT_APPLICABLE / legacy guard`, non PASS. La policy
effettiva è coperta dai test dinamici: gap/reconnect/check normali non eseguono
snapshot; Retry CTA esplicito e replacement journal seguono i soli percorsi
autorizzati.

## Qualifica del checkpoint live precedente

Nel checkpoint storico l'utente aveva toccato realmente
`Sostituisci con dati cloud` sulla build già installata. Il replace era avvenuto
e account, shop, login e device identity erano stati preservati.

I conteggi locali post-replace erano reconciliation-aware/scoped, mentre i
conteggi staging erano raw. Non sono comparabili uno-a-uno; la loro differenza
non è una prova autonoma di drift e non può essere usata come prova di
convergenza.

Il blocker runtime certo era:

- Diagnostics `policyBlocked / sync_event_missing_entity_ids`;
- orchestrator `idle/noWork`.

La build corretta non è stata installata sul container reale e non è stato
ripetuto il replace. Perciò la convergenza reale rimane `NOT_RUN` dopo la FIX,
non PASS e non failure nuovamente osservata.

## Stato coordinato Android, Admin e Win7POS

Android non è più `review-only` esclusivamente per la patch UX minima
autorizzata dall'utente. I risultati preservati sono:

- mirati TASK-139 `182/182`;
- immagini P1 `69/69`;
- JVM `697` totali = `692` pass + `5` skip;
- device UI `4/4` da sintesi; il report raw del device run non è stato
  conservato;
- lint `0` errori / `22` warning;
- `assembleDebug`, `assembleDebugAndroidTest` e `git diff --check` verdi.

Android non ha eseguito un replace autenticato reale. Atomicità e rollback sono
coperti su fixture Room isolata, inclusi zero preprocessing/upload/remove
immagini cross-scope.

Admin TASK-139 resta `42/42`; Admin TASK-140 resta `21/21`. Win7POS/security
globale è `BLOCKED_EXTERNAL` per il file esterno mancante e non viene promosso a
PASS.

## Rischio residuo P1: atomicità fisica globale

Il replacement journal impedisce che una sostituzione incompleta venga marcata
come completata e forza recovery/retry. Tuttavia i save paginati e cross-domain
di catalogo, history, prezzi e baseline possono lasciare stato fisico
intermedio dopo una failure tardiva o un crash.

Questa è recovery atomicity logica, non una singola transazione fisica globale.
Una garanzia letterale richiederebbe shadow store o redesign transazionale
multi-domain, fuori dallo scope minimo e dai vincoli dell'addendum. Il rischio è
classificato `P1` e resta aperto per la review; non viene nascosto dietro ai gate
verdi.

## Handoff

- Stato: `REVIEW_WITH_IOS_FIXES_VERIFIED_ISOLATED / REVIEW`.
- Responsabile: `Claude/ChatGPT / Reviewer`.
- Nessun PASS globale e nessun `DONE`.
- Nessun secondo replace, installazione, clear-data o live mutation.
- Nessun commit, stage, push, merge o deploy.
- Production e Win7POS intatti.

La prossima decisione è del reviewer e dell'utente. Qualsiasi nuova operazione
sul database autenticato reale richiede una nuova autorizzazione esplicita.
