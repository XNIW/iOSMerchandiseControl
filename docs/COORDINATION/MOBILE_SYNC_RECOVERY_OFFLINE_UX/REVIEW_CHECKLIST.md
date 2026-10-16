# Checklist per reviewer indipendente

Review applicativa futura: **NON ESEGUITA**. Il controllo di completezza dei documenti non è approvazione del codice. Il reviewer deve essere distinto da writer/executor; fissare SHA/diff e identità dei ruoli.

- [ ] Baseline reale, WIP/worktree/stash/PR/CI e installazioni distinti; nessun PASS trasferito da SHA diverso senza equivalenza verificata.
- [ ] ROSSO autentico prima della patch per finding confermati; setup FAIL preservato come tale; stessi assert/timeout oppure cambiamento contrattuale motivato e separato.
- [ ] Nessun reset dei dati, cancellazione proof/pending/journal, privilegio più ampio o service-role client.
- [ ] Local data, autorizzazione locale, sessione cloud, rete e sync success distinti; transient refresh non equivale a revoca; logout/scope switch restano fail-closed.
- [ ] Tutti i casi A–G, shell/Options accessibili e business protetto; dismiss review non intrappola né autorizza dati illegittimi.
- [ ] Retry classificato, jitter/backoff/deadline/Retry-After e riattivazione dopo finestra; nessun pending recoverable dimenticato e nessun payload stabile ritentato in loop.
- [ ] Single-flight, coalescing del lavoro durante run, finally/cancel e timer vecchio scope; nessun RUNNING permanente o listener duplicato.
- [ ] Business+intent atomici; identity/body/base immutabili in replay; ACK A non conferma B; timeout postcommit non duplica prezzi/eventi/history.
- [ ] Invalid item conservato, dipendenze esplicite e negativi; nessun catch-and-continue oltre scope/seal/integrity barrier.
- [ ] ChangedFields e merge disgiunti verificati col writer effettivo; no full-row overwrite, LWW globale o clock device come arbitro; tombstone/price/history preservati.
- [ ] Recovery staging/manifest/body proof/overlay e cutover revision-fenced; rete fuori writer lock, nessuna perdita di Save concorrente.
- [ ] `localOnly` escluso dal pending cloud, proof intatte; successo/date scoped e al tempo reale dell'esito; una nuova VM non inventa lastSuccessAt.
- [ ] Errore pertinente rimosso dopo successo pertinente, altri errori non cancellati; database locale non etichettato guasto dal solo cloud error.
- [ ] Layout/input/scroll/draft, IT/EN/ES/ZH, grandi font e VoiceOver/TalkBack realmente verificati; effetti native non scambiati per difetti senza hit-test/occlusione.
- [ ] T01–T20 e CA01–CA12 completi per piattaforma con STATIC/BUILD/UNIT/SIM/E/MANUAL ed evidenze; NOT_RUN non mascherato.
- [ ] Runtime vero in TEST ammesso, readback per ID/campi/relazioni in due direzioni, fixture manifest e cleanup esatto; nessuna equivalenza fra peer read e uso UI.
- [ ] Performance p50/p95/max, campioni e incertezza clock; niente miglior campione selezionato, carico sintetico isolato, nessun proof indebolito.
- [ ] Backend RPC/schema/runtime provenance; correlazione57014 non presentata come join esatto; replica sintetica e contratto invariato per eventuale SQL patch.
- [ ] Build Debug/Release, lint/analyze, warning e CI final SHA; skip e FAIL originali preservati, nessuna escalation di timeout per ottenere verde.
- [ ] Policy precedente aggiornata esplicitamente per sole eccezioni dimostrate; nessuna modifica implicita a conflitti/autorità.
- [ ] FIX ritorna a REVIEW; main integrato secondo protezioni; nessun DONE prima di conferma finale utente/pipeline.

Esito da compilare: APPROVED / CHANGES_REQUIRED / BLOCKED con finding P0–P3, file:line, prova, modifica richiesta e retest. Miglioramenti fuori scope separati; bug introdotti non chiamati follow-up. Se un gate esterno manca, descrivere la singola operazione e il prerequisito, mantenendo valida la parte già verificata senza dichiarare completamento globale.
