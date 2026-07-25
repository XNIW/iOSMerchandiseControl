# TASK-139 — Checkpoint runtime iOS dopo la scelta cloud

> **CHECKPOINT STORICO — SUPERSEDED NEL VERDICT.** Questo documento conserva le
> osservazioni della build installata al momento del tap reale. Il verdict e i
> gate correnti sono in
> [`14-fix-post-replace-convergence-ios.md`](14-fix-post-replace-convergence-ios.md):
> `REVIEW_WITH_IOS_FIXES_VERIFIED_ISOLATED / REVIEW`.

Data: `2026-07-21`

Stato consegnato allora:
`REVIEW_WITH_IOS_POST_REPLACE_CONVERGENCE_BLOCKER / REVIEW`.

Responsabile corrente: `Claude/ChatGPT / Reviewer`. Mai `DONE` senza conferma
esplicita dell'utente.

## Scelta realmente eseguita

L'utente ha aperto la dialog nativa iOS e ha toccato realmente
`Sostituisci con dati cloud` sulla build già installata; non era un mock o una
fixture. La dialog mostrava esattamente le due azioni condivise
`Mantieni dati locali` e `Sostituisci con dati cloud`, senza seconda conferma.

Il tap distruttivo ha costituito la conferma esplicita. Da quel momento non sono
stati eseguiti un secondo replace, installazione, clear-data, reset o altra
mutazione live sul database autenticato reale.

## Osservazioni prima e dopo il tap

I conteggi privacy-safe osservati nel container iOS autenticato erano:

| Entità | Prima | Dopo |
|---|---:|---:|
| Prodotti | 1 | 19.734 |
| Fornitori | 0 | 85 |
| Categorie | 0 | 54 |
| Prezzi | 1 | 10.799 |
| History | 0 | 77 |
| Pending change | 2 | 0 |
| Event outbox | 0 | 0 |

Dopo il replace era presente `1` baseline con totale osservato `19.873`.
Binding account/shop, login, shop selezionato e device identity risultavano
preservati. La fixture barcode `9913907182329` risultava presente localmente
come prodotto + immagine e sullo staging come riga + immagine.

## Conteggi staging e finding certo

Furono osservati anche questi conteggi raw staging:

| Entità | Locale post-replace | Raw staging osservato |
|---|---:|---:|
| Prodotti | 19.734 | 19.746 |
| Fornitori | 85 | 83 |
| Categorie | 54 | 55 |
| Prezzi | 10.799 | 41.158 |

La lettura originaria li trattava come conteggi direttamente comparabili. La
qualifica corretta è che i conteggi locali sono reconciliation-aware/scoped,
mentre quelli staging erano raw: non sono confrontabili uno-a-uno. Le
differenze numeriche, da sole, non provano né drift né convergenza.

Il finding runtime certo e riproducibile nelle Diagnostics era invece:

- orchestrator `idle` / `noWork`;
- `lastOutcome = completed` osservato;
- `lastError = policyBlocked` con codice
  `sync_event_missing_entity_ids`.

`completed` non annullava il policy block. Il replace locale era un fatto
runtime; bootstrap/pull/reconcile convergenti non erano dimostrati.

## Hardening successivo, non applicato al database reale

Dopo il checkpoint furono introdotti journal `prepared/wipeCommitted`, lease
owner/shop, watermark W0 pre-snapshot nel percorso replacement, tail +
reconcile prima del clear,
validazione owner/shop per riga/batch e lease esplicite per i save eseguiti da
`Task.detached`. Questi fix furono verificati su fixture e Simulator isolato e
non applicati retroattivamente al database reale.

La FIX successiva documentata in evidence 14 ha inoltre corretto RPC
exactly-one, outbox fail-closed, interleaving lease, preflight dei conflitti,
budget W0/tail e policy durevole `recoveryRequired`. Anche questi esiti restano
isolati: nessuna seconda esecuzione reale è stata autorizzata.

## Qualifica dell'atomicità

Le prove isolate verificano che il journal non venga completato dopo errore e
che la recovery/retry resti obbligatoria. Non dimostrano una singola transazione
fisica globale tra catalogo, history, prezzi e baseline: i save paginati e
cross-domain possono lasciare stato fisico intermedio in caso di failure
tardiva/crash. Il journal impedisce di dichiarare completion, ma non equivale a
rollback fisico globale. Questo rischio P1 letterale resta aperto in REVIEW.

## Gate storico, superseduto

Il gate più recente disponibile a questo checkpoint era `340` eseguiti:
`337` pass, `3` skip opt-in e `0` failure, con build/analyze verdi nel relativo
perimetro. È evidence storica e non il gate autorevole corrente. La matrice
integrata successiva `383 + 3 / 386` e i mirati finali sono registrati in
evidence 14.

## Stato coordinato storico

Android era autorizzato a uscire dal precedente `review-only` esclusivamente
per la patch UX Material 3. Nessun replace autenticato reale Android fu
eseguito; atomicità e rollback erano fixture Room. Admin risultava `42/42` per
TASK-139 e `21/21` per TASK-140. Win7POS/security globale restava
`BLOCKED_EXTERNAL`.

## Handoff storico

Questo checkpoint non è un PASS e non è DONE. È conservato perché prova il tap
reale e il policy block della build allora installata. Il verdict corrente è in
evidence 14; la convergenza del database reale non è stata riprovata e nessun
commit, stage, push, merge o deploy è stato eseguito.
