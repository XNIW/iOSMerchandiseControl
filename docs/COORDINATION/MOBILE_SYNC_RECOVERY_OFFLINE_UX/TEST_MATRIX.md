# Criteri di accettazione e matrice di prova

Fonte canonica, 2026-10-15. Questi sono test da preparare per l'execution, **non esiti inventati**. Le letture STATIC e le osservazioni aggregate odierne sono in RCA; non soddisfano i gate applicativi finali. iOS usa STATIC/BUILD/SIM/MANUAL; Android S/B/E/M sono equivalenti rispettivamente. Test unitari/Robolectric/SwiftData sono marcati UNIT per chiarezza e riportati separatamente dai test runtime.

## Criteri applicativi obbligatori

| CA | Risultato verificabile | Tipo richiesto | Casi / prova | Stato attuale |
|---|---|---|---|---|
| CA01 | Sorgente candidata, config, installazione e ambiente legati da hash/receipt; WIP e storico preservati | STATIC+BUILD | Manifest baseline/candidato e T17 | NOT_RUN sul candidato futuro; baseline STATIC eseguita |
| CA02 | Store locale valido/scope autorizzato: startup, navigazione, ricerca, editor e Save offline disponibili senza rete | UNIT+SIM/E | T01/T02/T06/T14; readback durevole | NOT_RUN |
| CA03 | Pending conservato al restart e ripreso senza Opzioni/tap dopo errore transient, anche oltre finestra tentativi | UNIT+SIM/E | T03/T04/T05; clock/log tentativi | NOT_RUN |
| CA04 | Logout/revoca/mismatch/corruzione non consentono dati o mutazioni foreign; vecchie callback ignorate | UNIT+SIM/E | T06/T07/T12; negativi scope/generation | NOT_RUN |
| CA05 | Merge disgiunto corretto, conflitto reale isolato, nessuna sovrascrittura fuori changedFields | UNIT+SIM/E | T08/T09; baseline/current/intent/readback | NOT_RUN |
| CA06 | Commit locale+intent atomici, replay/ACK esatti, prezzo/history senza duplicati, Save B preservato | UNIT+SIM/E | T03/T10/T13/T16; identity/revision rows | NOT_RUN |
| CA07 | Elemento stabile invalido non impedisce lavoro indipendente; dipendenze e barriere restano efficaci | UNIT+SIM/E | T11; negativo supplier/product e scope | NOT_RUN |
| CA08 | Recovery A–G riprendibile con shell accessibile e qualificazione sicura; nessuna perdita durante cutover | UNIT+SIM/E | T07/T12/T13/T14; journal/manifest/replay | NOT_RUN |
| CA09 | UI unica/coerente, niente false6 localOnly o false date, niente stale rosso dopo successo pertinente | UNIT+SIM/E | T15/T19; resolver+view e provenance | NOT_RUN |
| CA10 | Layout native, ultima riga, input/draft, quattro lingue e accessibilità verificati | SIM/E+MANUAL | T14/T18, screenshot/AX e giudizio operatore | NOT_RUN |
| CA11 | Create/update/delete/prezzi/history convergono bidirezionalmente; no-op invarianti e target prestazioni rispettati | SIM/E+BUILD | T16/T19/T20; readback per record, p50/p95/max | NOT_RUN |
| CA12 | Build/gate finali, review indipendente, FIX→REVIEW, integrazione protetta e conferma finale | BUILD+STATIC+MANUAL | Diff immutabile, CI exact-SHA, review, tracking | NOT_RUN |

## Ambiente e prove comuni

UNIT: storage in memoria o directory temporanea isolata, account/shop/device sintetici, transport e clock controllabili, nessuna config TEST/production reale. Verificare fixture/entrypoint prima del run; niente esclusioni per far passare suite. Salvare RED originale, GREEN e guardrail adiacenti con SHA, command/exit, test IDs e motivi SKIP. Un errore setup è NOT_TRAVERSED, non un RED applicativo.

SIM/E: app vere, iOS Simulator e Android Emulator separati dalle installazioni utente. Prima verificare endpoint non-production, account/shop/store/device autorizzati, schema/protocollo, build hash e config sanitizzata, identità test e finestra owner. Token installati tramite canali protetti; niente token in argv/log. Fixture sintetiche con manifest ID, base/revisioni, relazioni e tag; cleanup esatto delle sole fixture dopo readback ed evidenze, con residuo zero. Non cancellare vecchi dati che sembrano test.

Ogni record di risultato: ID caso/sottocaso, piattaforma/build/commit/config, precondizioni, trigger/fault, tempi monotonic e UTC, esito locale, remoto e UI, phase/operation/category/code, attempt/revision, source/destination scopes sanitizzati, strumenti e file di prova. PASS/FAIL/NOT_RUN/BLOCKED/UNKNOWN/NOT_TRAVERSED restano distinti. Nessun screenshot o HTTP200 sostituisce assert di contenuto.

## T01–T20 (equivalenti, implementazioni native)

| ID | Precondizioni e trigger/fault | Risultato locale | Risultato remoto e UI | Strumento e prova | Stato |
|---|---|---|---|---|---|
| T01 | Store qualificato stesso scope, rete assente prima cold start; varianti token cached/SDK Initializing | Dati locali leggibili; shell/Options accessibili; nessuna attesa rete per mount | Nessun falso cloud success; offline discreto | UNIT auth/gate + SIM/E startup, timestamp first data/frame | NOT_RUN |
| T02 | T01 ammesso, cercare/aprire editor/modificare nome e prezzo/Save | Draft e intent atomici, readback dopo dismiss; navigazione e ultima riga raggiungibili | Nessuna richiesta necessaria al successo locale; pending reale distinto | UNIT fallimento disco + UI vera e readback per ID/campi/prezzo | NOT_RUN |
| T03 | Intent e outbox sintetici, restart prima invio e dopo commit ignoto | Identity/body/base/revision conservati; nessun doppio prezzo | Ripresa ammessa al ritorno rete, nessun tap | UNIT reopen persistence + SIM/E restart non distruttivo, manifest | NOT_RUN |
| T04 | Pending offline, poi rete sana; variante finestra retry esaurita | Locale sempre disponibile | Convergenza automatica senza aprire Opzioni o premere Retry | Clock/transport; runtime network controlled, trace trigger→ACK/readback peer | NOT_RUN |
| T05 | Timeout pre/postcommit, HTTP429 Retry-After, 500/503, DNS; superare3/5 tentativi poi server sano | Pending intatto; niente busy eterno né perdita | Backoff/jitter/rate/deadline conformi, nuovo ciclo bounded; errore stable non ritentato | UNIT clock seeded+transport; SIM/E fault su fixture isolata, istanti/count RPC | NOT_RUN |
| T06 | Session refresh differito, success/failure, SDK nil temporaneo; controlli logout esplicito | Capacità locale solo se prova autorizzata valida; logout distinto | Refresh serializzato; stale reply non ripristina sessione ritirata | SDK controllato UNIT + SIM/E con sessione test, no secret logging | NOT_RUN |
| T07 | Cambio account/shop, revoca confermata, vecchia callback, scope sconosciuto e corrotto | Zero esposizione/mutazione foreign; shell/Options e spiegazione corretta | Nessun push stale; timer vecchi cancellati; ripresa solo authority nuova | UNIT negative + due scope TEST ammessi SIM/E, assert per ID | NOT_RUN |
| T08 | Stessa base, device A cambia nome, B campo disgiunto; anche categoria/ref e prezzo | Entrambe modifiche conservate; changedFields affidabile | Readback entrambe, nessuna riscrittura riga/prezzi estranei | UNIT writer effettivo + SIM/E bidirezionale, SQL/readback autorizzato per fixture | NOT_RUN |
| T09 | Stesso campo incompatibile e delete-vs-edit non auto-risolvibile | Versioni/intent preservati, altre schermate/record utilizzabili | Stato record azionabile, scelta reale non LWW; no retry aggressivo | UNIT+SIM/E conflitto controllato, prova decisione e dato finale | NOT_RUN |
| T10 | Commit remoto poi ACK perso; replay stesso envelope; Save B mentre ACK A ritorna | B resta dirty; ACK soltanto A; riapertura stesso stato | Una mutation/evento/prezzo/history pertinente, niente duplicato | UNIT storage+transport e SIM/E fixture; IDs/revisioni/hash body prima/dopo | NOT_RUN |
| T11 | Malformed head, payload stabile invalido, elemento valido indipendente; variante supplier invalido→product dipendente | Record invalido conservato e diagnosticato; indipendente progredisce | Dipendente resta sospeso; scope/seal/corruzione blocca correttamente | UNIT queue reali + SIM/E fixture; per-item ledger, zero dropped rows | NOT_RUN |
| T12 | Gap vero/invalid cursor/snapshot_changed, stop durante staging/publish/finalization; B/C/D/E/F/G | Shell accessibile, store valido ammesso; resume journal/qualificazione senza reset | Incrementale ordinario; full solo causa contrattuale; old callbacks innocue | UNIT recovery real store+fault injection, SIM/E interrupt su fixture; journal/fence/manifest | NOT_RUN |
| T13 | Save nome/prezzo/history durante pagine recovery e a cavallo cutover; writer vecchio dopo publish | Save durevole, overlay/rebase conservato, writer stale rifiutato | Replay nuovo intent e ACK esatto; nessuna perdita o dup prezzo | UNIT controlled barriers+restart, SIM/E editor aperto, readback revisioni | NOT_RUN |
| T14 | Sync/recovery attiva, cambiare tab, cercare, scroll, tastiera/edit; annullare review | Navigation stack, focus, selezione/draft e scroll conservati; Opzioni sempre raggiungibili | Nessun modal rete; trigger successore dopo attività; no starvation durante uso prolungato | UI nativa SIM/E con AX/input/log; 10min editing normale più quiet gap | NOT_RUN |
| T15 | Errore→successo pertinente, errore altro dominio, scope A→B, nuova VM; 6ACK+3sent+6localOnly | Proof conservate; count0 (poi1 vero pending); dettagli blocked separati | Errore corretto rimosso, nessun falso success/date now al replay; scoped labels | UNIT resolver/tracker + SIM/E tab/remount, assert date e numeri | NOT_RUN |
| T16 | Entrambe direzioni, fixture create/update/delete, supplier/category refs, purchase/retail e history | Record e relazioni coerenti, pending reale terminale | Convergenza per ID/campi/versione/tombstone e prezzo/history; non conteggi soli | SIM/E app vere+backend TEST, manifest e peer/readback, cleanup esatto | NOT_RUN |
| T17 | Installazione sintetica con pending, upgrade non distruttivo Debug→Release e Release→Release, config compatibile | DB/pending/journal/draft/sessione preservati; compatibilità schema/readback | Nessuna sync/reset accidentale durante setup; normale resume poi testata | BUILD+SIM/E packaging/signature/hash e readback; nessun downgrade non supportato | NOT_RUN |
| T18 | Idle/offline/retrying/action/recovery su tutte tab, IT/EN/ES/ZH, font normale/max accessibilità, light/dark | Ultima riga/controlli raggiungibili; no etichette spezzate, hit target e keyboard corretti | Banner unico/discreto, semantica annunci e focus pertinenti | SIM/E screenshot+AX; MANUAL VoiceOver/TalkBack/giudizio native, fisico separato | NOT_RUN |
| T19 | 30 cicli no-op, ricreazione VM/tab, own ACK/eventi duplicati, vecchia diagnostica | Nessun dirty/proof duplicato, count pending corretto, store invariato | Nessun full recovery ingiustificato o falso lastSuccess, richieste bounded | UNIT ledger+SIM/E DB diff per fixture e trace RPC | NOT_RUN |
| T20 | Dataset sintetico locale20.000 prodotti e almeno40.000 prezzi, piccolo delta foreground e Save durante sync/recovery | Reattività e durata lock misurate senza aspettare rete | Latenza bidirezionale e no-work misurate; background distinto | Instrumentation/clock+profiling nativo, CSV raw e p50/p95/max | NOT_RUN |

## Prestazioni: protocollo e soglie proposte

Usare fixture locale sintetica deterministica (seed e hash documentati), almeno20k prodotti/40k prezzi; nessun carico massivo nel negozio reale. Riutilizzabile benchmark Android TASK-143 20k/300k, ma le sue metriche host-only non sono acceptance device/sync attuale. Fixture grande nel backend solo su clone/sandbox separato esplicitamente ammesso; nel TEST condiviso usare piccoli delta e nessun bulk load.

Tre warmup esclusi, poi **30 campioni per direzione**, almeno6 ciascuno per create, update, delete, prezzo e history; alternare ordine e registrare rete/RTT, hardware/runtime, configurazione build, dimensioni payload e stato foreground. Per Save locale e no-work: ulteriori30 campioni per piattaforma a riposo e30 durante recovery. Riportare tutte le osservazioni, timeout inclusi, più p50/p95/max; niente selezione del migliore.

T0 = commit durevole locale+intent; T1 = admission scheduler; T2/T3 = inizio/fine rete; T4 = apply/ACK persistito; T5 = riga/campi visibili sul peer. Misurare separatamente cold opening, local Save, scheduler wait, network, apply e peer UI. Cross-device usare monotonic locale con correlazione evento/revision e offset clock documentato; riportare incertezza, niente sottrazione ingenua di orologi non sincronizzati.

Target di accettazione **proposto** per piccoli delta foreground/rete sana: p95 T0→T5 ≤3s, max≤5s; p95 Save locale≤300ms e max≤1s sul dataset sintetico, senza dipendenza dalla rete; nessuna attesa network sotto writer lock. Se non rispettato, FAIL del target con scomposizione cause, non allargamento silenzioso della soglia. Recupero outage/full recovery non usa il target3s: verifica liveness/correctness e metriche separate. Sessione background/sospesa/force-stop descritta senza promessa di execution continua.

Misurare Android no-work transaction/proof duration e contesa Save, paging/decoding/apply su thread UI, query count per evento, invalidazioni per riga e crescita memoria. Proporre ottimizzazione soltanto con hotspot misurato e test equivalenza delle prove di integrità. Sorgenti lenti ipotizzati non diventano diagnosi senza misura.

## Prove fisiche e condizioni di arresto

Simulator/Emulator soddisfano soltanto la lane virtuale. Device fisici iOS/Android, VoiceOver/TalkBack effettivi, lifecycle e provider reali seguono la pipeline esistente come gate separato: NOT_RUN finché non c'è receipt esplicita, nessun riuso di screenshot virtuali.

Arrestare il singolo esperimento su scope mismatch, fixture non isolata, perdita authority, save failure, timeout non classificato o setup non attraversato. Preservare primo FAIL, journal e traccia; non continuare i casi dipendenti. Le lane documentali/UNIT indipendenti possono proseguire. Dopo una modifica causale nuova, un rerun è legittimo con nuovo ID e collegamento al FAIL originale; vietato retry-until-green.
