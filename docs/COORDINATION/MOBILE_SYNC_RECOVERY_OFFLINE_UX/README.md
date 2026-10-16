# MOBILE_SYNC_RECOVERY_OFFLINE_UX — planning coordinato

Data: 2026-10-15, America/Santiago. Writer unico: Codex planner/coordinatore, chat `01a141f7-f97d-7351-a5dd-e2dd23113697`. Analisti distinti iOS, Android e backend in sola lettura.

**PLANNING_COMPLETE / READY_FOR_EXECUTION (documentale).** L'execution non è iniziata né autorizzata da questo verdetto: sarà assegnata dall'utente a un agente distinto. La review del codice finale dovrà essere indipendente dal writer. Nessun task è DONE.

## Obiettivo compreso

Garantire lavoro locale durevole nello stesso scope autorizzato, ripresa automatica bounded della sync e informazioni veritiere e poco invasive. Conservare isolamento, revoche, journal, generazioni, intent e ACK esatti. Il mandato allegato autorizza esplicitamente Codex come planner e la scrittura del tracking, in deroga al ruolo executor storico; non autorizza patch applicative o cambi alle regole globali.

## Documenti canonici

1. [Baseline e root-cause analysis](ROOT_CAUSE_ANALYSIS.md): prove attuali, finding, ipotesi, trigger e salvaguardie già integrate.
2. [Contratto condiviso](CONTRACT.md): unica fonte della proposta stati/retry/recovery/UX; nessuna copia indipendente negli altri repository.
3. [Batch di implementazione](IMPLEMENTATION_PLAN.md): file, simboli, dipendenze, alternative e stop.
4. [Criteri e matrice T01–T20](TEST_MATRIX.md): protocolli deterministici, runtime e prestazioni; tutti i nuovi test applicativi NOT_RUN.
5. [Handoff all'executor](EXECUTION_HANDOFF.md): baseline, ownership, comandi esistenti, prove e gate.
6. [Checklist review indipendente](REVIEW_CHECKLIST.md).
7. [Osservazione locale sanitizzata](ios-readonly-observation.json) e [baseline Git/WIP](baseline.json).
8. [Validazione del planning](PLANNING_VALIDATION.md): controlli eseguiti e limiti della verifica indipendente.

Task iOS: [TASK-145](../../TASKS/TASK-145-mobile-sync-recovery-offline-ux-ios.md). Task Android: [TASK-144](/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/TASKS/TASK-144-mobile-sync-recovery-offline-ux-android.md). Backend: [riferimento nel workspace Supabase](/Users/minxiang/Desktop/MerchandiseControlSupabase/docs/mobile_sync_recovery_offline_ux_planning_reference.md).

## Esito verificato

- iOS: GitHub/main/checkout `314cf5332d0b889331802a3f886c1910b9b377b0`; Android: `4b74ed5cfb4e4bce024513561e7dc1b6998003ae`. WIP preesistente preservato, nessun branch/commit/push.
- iOS attuale: journal same-scope/staging, budget della stessa identità a tre tentativi; `.exhausted` persistente e safety poll senza resume. Questo spiega il mancato nuovo tentativo automatico nel percorso corrente. L'origine dell'HTTP500 resta da discriminare.
- I sei intent business nel database sono `acknowledged`. Sei ricevute `local_catalog_body_proof/localOnly` entrano erroneamente nel contatore pubblico: il numero sei non prova sei modifiche da inviare. Nessun record cancellato.
- I gate di disponibilità locale e il trasferimento dei pending durante recovery sono già in buona parte integrati. Il piano corregge le lacune residue; non ricostruisce un secondo motore.
- Supabase locale è un workspace non Git e storico; le RPC recovery correnti sono nei migration del repository Admin. Destinazione TEST riconosciuta, schema applicato attuale non verificato.

## Check di questa consegna

| Check | Stato e ambito |
|---|---|
| Sorgenti, GitHub, PR/CI exact-SHA, metadati installati, letture locali aggregate | ✅ ESEGUITO — evidenze in RCA/JSON; non acceptance runtime |
| Coerenza planning, link e preservazione WIP | ✅ ESEGUITO — report finale di validazione documentale |
| Build/lint/warning nuovi | ❌ NON ESEGUITO — solo documenti, nessun file compilabile modificato; CI preesistente distinta |
| T01–T20 e CA applicativi finali | ❌ NON ESEGUITO — execution futura, matrice con stati espliciti |
| Schema/RLS/timeout live e collaudo autenticato finale | ⚠️ NON ESEGUIBILE in questo planning — richiedono ammissione e witness circoscritti descritti nell'handoff |

Nessuna promessa di sync continua durante sospensione/force-stop; nessuna chiusura dei FAIL storici, del caso A, delle prove fisiche o degli altri task. La nuova assegnazione sospende i precedenti task operativi senza cancellarne evidenze o considerarli risolti.


## Pubblicazione selettiva e limiti delle evidenze — 2026-10-16

Questa revisione pubblica piano, contratto, review e un’allowlist di ricevute testuali; l’[indice di pubblicazione](EVIDENCE_PUBLICATION_INDEX.json) dichiara ogni file e il relativo hash. I riferimenti degli originali a log, xcresult, APK, bundle, script temporanei e snapshot intermedi sono **locatori locali dell’archivio**, non file ospitati da GitHub: non va dedotta disponibilità web dai link relativi originali. Le evidenze originali e i FAIL restano preservati fuori dal checkout nel backup privato verificato e nel runfolder locale.

I binari, i log host e le configurazioni private non fanno parte della pubblicazione. I documenti storici del producer mantengono date e limiti originali; la qualifica CI dei nuovi SHA è distinta dai gate locali eseguiti con WIP. Le ricevute finali SHA/PR/CI sono esterne al repository per evitare una catena di commit di rendicontazione. Il candidato non certifica le app installate o l’accettazione TEST.
