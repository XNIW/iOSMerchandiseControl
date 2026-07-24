# TASK-139 iOS — Evidence ledger e handoff

Esito corrente:
`REVIEW_WITH_IOS_V6_PREBOUND_RUNTIME_VERIFIED_ISOLATED / REVIEW`.

Responsabile: `Claude/ChatGPT / Reviewer`. TASK-139 non è `DONE` e non ha un
PASS globale. Il checkpoint autorevole V6 è
[`15-v6-atomic-recovery-contract-ios.md`](15-v6-atomic-recovery-contract-ios.md).

## Verdict corrente

Il contratto sync-event V6 e il recovery fisicamente atomico sono verificati
sul candidato isolato: bigint wire come stringhe decimali canoniche, scope e
fence durevoli, staging generation non visibile, manifest fsync/rename atomico
e prova SIGKILL/relaunch pre/post publication `2/2`. La continuation principale
aggiunge la prova `64` completion stale + `100` consumer single-flight e la
prova app-process prepare/verify con PID distinto `2/2`. L'audit della migration
reale ha corretto anche la catena digest UTF-8, `item_number`, tombstone
prodotto, `price_canonical`/tipo raw e digest redatti history. La full suite
esatta finale è `1.262` eseguiti (`1.227` pass, `0` failure, `35` skip
espliciti); sostituisce il run da `1.261` anteriore alla prova pre-bound.

Il task resta `REVIEW`: manca ancora il singolo replace E2E autorizzato su
shop non-production con confronto forte cloud/local, immagini, outbox e tre
relaunch. Nessun PASS globale o `DONE` è dichiarato.

Il dettaglio con XCResult, gate e limiti è in
[`15-v6-atomic-recovery-contract-ios.md`](15-v6-atomic-recovery-contract-ios.md).

## Checkpoint precedente della FIX

Le lacune correggibili nel perimetro autorizzato sono state chiuse sul candidato
e verificate su fixture/Simulator isolati:

- matrice integrata unica di `28` classi: `386` totali = `383` pass + `3` skip
  opt-in + `0` failure; recovery/cancel finale `94/94`;
- focus engine storico della FIX `90/90`, RPC `29/29`, outbox `32/32`, recovery preflight/W0
  budget `3/3`, lease interleaving singolo + repeat-5;
- Debug build e Analyze verdi nel loro perimetro; le sole issue analyzer sono
  in `Vendor 2/libxls` (`xls.c`, `ole.c`);
- contract hash/byte parity Admin/Android, quattro localizzazioni `plutil`,
  workflow YAML e `git diff --check` verdi; staged vuoto. Il sensitive scan
  storico resta evidence storica: la Codex Security diff scan formale sull'exact
  diff non è stata avviata e non viene dichiarata PASS.

Xcresult integrato: artifact esterno del run, non versionato.

Artifact recovery/cancel: xcresult esterno del run, non versionato.

I tre skip restano opt-in e non vengono trasformati in PASS. I mirati si
sovrappongono alla matrice integrata e non vengono sommati. Il legacy scanner
TASK-117 `no-full-pull` ha risultato `4/5`: richiede un divieto assoluto di
bootstrap/fullRecovery ormai incompatibile con la policy source/context. È
classificato `NOT_APPLICABLE / legacy guard`, superseduto da test dinamici, non
PASS.

## Correzioni verificate

- RPC exactly-one, con empty/multi-row fail-closed.
- Outbox `automatic_scope_mismatch` in `blockedAuth`, batch abortito e nessuna
  entry successiva mutata; rollback per scope/lease stale.
- Interleaving lease deterministico.
- Duplicate lookup/product conflict rilevati prima di qualsiasi mutazione
  downstream.
- Nel percorso replacement, budget W0 `512 x 200`; tail
  `50 x 200 = 10.000` eventi.
- Fase `recoveryRequired` persistita: gap/reconnect/`Check again` normali non
  avviano snapshot; solo Retry CTA esplicito `releaseCard` abilita recovery.
- Pending push prima di drain/recovery, senza snapshot implicito.
- Replacement journal con massimo due snapshot, bootstrap automatico, tail e
  reconcile prima del clear.
- `recoveryRequired` persiste su cancel/failure/block/busy/no-op/relaunch e si
  libera solo dopo successo verificato; il replacement rimuove il latch solo
  per journal/bootstrap. La race Cancel→Retry immediato viene drenata dopo la
  chiusura cooperativa del run cancellato.
- Default DI coerenti con lo scope iniettato.

Le otto classi Product Images richieste erano già nel workflow CI e sono state
riconfermate; non è stata inventata una patch CI.

## Runtime reale storico, non ripetuto

L'utente ha eseguito realmente una volta `Sostituisci con dati cloud` sulla
build già installata. Il replace locale è avvenuto preservando account, shop,
login e device identity. I conteggi locali reconciliation-aware e i conteggi
raw staging riportati nel checkpoint storico non sono confrontabili uno-a-uno;
non sono una prova autonoma di drift o convergenza.

Il finding runtime certo era Diagnostics
`policyBlocked / sync_event_missing_entity_ids` insieme a orchestrator
`idle/noWork`. Dopo la FIX non sono stati eseguiti un secondo replace,
installazione, clear-data o mutazione live. La convergenza del database reale
non è quindi stata riprovata.

Il checkpoint
[`13-post-choice-runtime-checkpoint-ios.md`](13-post-choice-runtime-checkpoint-ios.md)
resta evidence storica ed è superseduto nel verdict da evidence 15.

## Indice evidence

- [`15-v6-atomic-recovery-contract-ios.md`](15-v6-atomic-recovery-contract-ios.md)
  — checkpoint autorevole V6: contratto, staging atomico, SIGKILL/relaunch,
  full suite finale e limite E2E esplicito.
- [`14-fix-post-replace-convergence-ios.md`](14-fix-post-replace-convergence-ios.md)
  — evidence storica della FIX isolata, gate, limiti e handoff REVIEW.
- [`13-post-choice-runtime-checkpoint-ios.md`](13-post-choice-runtime-checkpoint-ios.md)
  — checkpoint storico del tap reale, ora superseduto nel verdict.
- [`12-product-image-owner-store-race-hardening-ios.md`](12-product-image-owner-store-race-hardening-ios.md)
  — hardening storico Product Images/owner-store.
- [`11-final-verification-ios.md`](11-final-verification-ios.md) — verifica
  storica iniziale.
- [`ios-account-shop-owner-safety-p0.md`](ios-account-shop-owner-safety-p0.md) —
  audit P0 storico con appendice correttiva.
- [`addendum-ui-mobile-ios/README.md`](addendum-ui-mobile-ios/README.md) — addendum
  UX mobile; i NOT_RUN iniziali restano storici.

## Stato coordinato

- Android non è più `review-only` esclusivamente per la patch UX autorizzata:
  mirati `182/182`, immagini P1 `69/69`, JVM `697` (`692` pass + `5` skip),
  device `4/4` da sintesi (report raw non conservato), lint `0` errori / `22`
  warning, build gate e diff check verdi. Nessun replace autenticato reale;
  atomicità/rollback su fixture Room isolata.
- Admin TASK-139 `42/42`; Admin TASK-140 `21/21`.
- Win7POS/security globale `BLOCKED_EXTERNAL`; nessun PASS inventato.

## Rischi residui e handoff

- Il precedente `P1` di atomicità fisica è chiuso sul candidato V6 con staging,
  fence, manifest fsync/rename e crash/relaunch isolato `2/2`.
- Il P1 di serializzazione/digest trovato dopo il precedente full run è chiuso
  localmente e coperto da `41/41` mirati + full `1.261/0/35` sul sorgente
  esatto.
- Il replace E2E e la convergenza forte cloud/local sullo shop non-production
  autorizzato non sono ancora stati eseguiti sulla build corretta.
- Tre opt-in Product Images, camera fisica e staging mutativo dedicato non
  eseguiti.
- La diagnostica SwiftData `DefaultStore` osservata una volta nella full suite
  ProductImage resta P2 non riprodotto in isolamento; security diff scan
  formale ancora `NOT_RUN`.
- Device Android `4/4` disponibile solo come sintesi; raw report non conservato.
- Win7POS resta una precondizione esterna.

Nessun commit, stage, push, merge o deploy. Production e Win7POS sono intatti.
Handoff a reviewer in `REVIEW`; `DONE` richiede conferma esplicita dell'utente.
