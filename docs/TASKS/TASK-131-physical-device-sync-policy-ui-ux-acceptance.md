# TASK-131 — Physical-device Sync Policy UI/UX Acceptance iOS + Android

## 1. Stato

- Task ID: TASK-131
- Titolo: Physical-device Sync Policy UI/UX Acceptance iOS + Android
- Stato: ACTIVE / BLOCKED — PHYSICAL_REVIEW_ACCESSIBILITY_OPERATOR_EVIDENCE_REQUIRED
- Fase corrente: Execution-completion full physical; full physical sync/offline core PASS e account-switch split PASS per i casi senza account B, ma Conflict/Review tap evidence e accessibility operator evidence restano bloccanti
- Priorita: P0 final acceptance
- Repo iOS target: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- Repo Android target fisico: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`
- Supabase locale/dev: `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- Canonicalita corrente: LOCAL_CANONICAL_AHEAD_OF_REMOTE (worktree locale non ancora pubblicato/committato)
- Scope corrente Execution: `FULL_PHYSICAL_IOS_ANDROID_SCOPE`; iPhone fisico e Android fisico autorizzati, testati e usati per le matrix disponibili
- Scope bloccato esterno: `OPERATOR_CONFLICT_REVIEW_CHECKLIST_NOT_PROVIDED`, `OPERATOR_ACCESSIBILITY_CHECKLIST_NOT_PROVIDED`, sotto-caso `BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY`; i soli veri casi Account A -> B C126-14/15/16/17/40 restano case-level `BLOCKED_EXTERNAL_SECOND_ACCOUNT`, non PASS
- Non-scope: refactor architetturale, nuove migration Supabase, production-ready claim globale
- Data creazione draft: 2026-05-28
- Ultimo aggiornamento: 2026-05-29
- Ultimo agente: Codex / Executor-Fixer
- Evidence dir prevista: `docs/TASKS/EVIDENCE/TASK-131/`

## 2. Regola Execution scope corrente

L'utente ha autorizzato Execution-completion il 2026-05-28 con iPhone fisico reale disponibile. Dopo una pausa per distacco temporaneo del device, l'esecuzione e' stata ripresa con iPhone fisico e Android fisico collegati e sbloccati. I gate core full physical, offline/reconnect e account-policy non-B sono stati rieseguiti con report canonici; TASK-131 resta bloccato solo per evidence operator-assisted P0 di Conflict/Review e accessibilita'. I veri casi Account A -> B restano case-level `BLOCKED_EXTERNAL_SECOND_ACCOUNT` finche' non viene fornito un secondo account sintetico.

Per questa esecuzione sono ammessi:

- canonicalizzazione locale TASK-131 nel repo iOS;
- aggiornamento `MASTER-PLAN`, evidence README e report;
- miglioramento harness `mc-agent` automation-first;
- build/test/smoke iPhone fisico, Android fisico e iOS Simulator di supporto;
- Supabase read-only e live scoped solo con `MC_ALLOW_LIVE=1`;
- cleanup scoped `TASK131_*` solo dry-run prima, execute solo con `MC_ALLOW_CLEANUP=1` e `cleanup_plan_id`;
- fix mirati di bug reali emersi dai gate disponibili.

Non sono ammessi claim di:

- background/locked iOS fisico PASS;
- account switch PASS senza secondo account reale;
- production-ready globale;
- DONE senza review indipendente e accettazione esplicita utente.

Full physical iOS+Android acceptance e iPhone physical PASS sono ammessi solo per i gate gia' coperti da report PASS con sessione Supabase valida, screenshot/log redatti e matrix P0 senza `NOT_RUN` mandatory. REVIEW full acceptance resta vietato finche' Conflict/Review tap evidence e accessibility traversal non sono completati.

## 3. Obiettivo

Definire una acceptance fisica reale per verificare che la sync policy TASK-126 funzioni correttamente su:

- comportamento dati;
- UI/UX Options / Sync status;
- Review/Recovery;
- account switch;
- offline/reconnect;
- background/locked;
- conflitti;
- ProductPrice;
- no full pull nascosto;
- no push cross-account/store;
- cleanup e residue Supabase.

TASK-131 deve trasformare in evidence fisica reale i casi C126-00...C126-60 ancora statici/simulator/emulator. `NOT_RUN` non e' un PASS: qualunque caso obbligatorio non eseguito blocca REVIEW.

## 4. Canonicalita e stato repo

| Area | Stato Execution corrente | Evidenza / nota |
|---|---|---|
| Task file presence | PRESENT_LOCAL_CANONICAL | `docs/TASKS/TASK-131-physical-device-sync-policy-ui-ux-acceptance.md` esiste nel repo iOS target. |
| Evidence README presence | PRESENT_LOCAL_CANONICAL | `docs/TASKS/EVIDENCE/TASK-131/README.md` esiste nel repo iOS target. |
| Master Plan consistency | BLOCKED_SCOPE_RECORDED | Aggiornato in questa ripresa a `ACTIVE / BLOCKED — PHYSICAL_REVIEW_ACCESSIBILITY_OPERATOR_EVIDENCE_REQUIRED` con `FULL_PHYSICAL_IOS_ANDROID_SCOPE`; secondo account registrato solo come blocker case-level C126-14/15/16/17/40. |
| GitHub/local/origin alignment | LOCAL_CANONICAL_AHEAD_OF_REMOTE | HEAD locale iOS `96b900ef` era allineato a `origin/main`; TASK-131 e harness sono ora sorgente locale corrente, non ancora remote canonical. |
| Android repo alignment | READ_ONLY_REFERENCE | HEAD Android locale e `origin/main` erano allineati nell'audit precedente; modifica IDE Android preesistente fuori scope non e' evidence TASK-131. |
| Harness physical/hybrid command presence | IN_EXECUTION_HARDENING | I comandi TASK-131 devono essere dimostrati via `help-json` e `list commands-json` prima di contare come canonici. |

Classificazione corrente: `LOCAL_CANONICAL_AHEAD_OF_REMOTE` per il worktree locale in Execution-completion. Non dichiarare `CANONICAL_ALIGNED` finche' commit/push/origin non sono riallineati.

## 5. Fonti di planning

### Tracking / policy

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-126-sync-policy-multistore-cache-mvp.md`
- `docs/TASKS/TASK-128-release-hardening-final-production-gap-plan.md`
- `docs/TASKS/TASK-130-price-contract-current-previous-old.md`
- `tools/agent/README.md`
- `tools/agent/mc-agent.sh`
- `tools/agent/lib/common.sh`
- `tools/agent/lib/ios.sh`
- `tools/agent/lib/android.sh`
- `tools/agent/lib/supabase.sh`
- `tools/agent/lib/sync.sh`

### iOS audit target

- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Sync/Account/AccountSyncDecisionView.swift`
- `iOSMerchandiseControl/Sync/Account/*`
- `iOSMerchandiseControl/Sync/Automatic/*`
- `iOSMerchandiseControl/Sync/Outbox/*`
- `iOSMerchandiseControl/Sync/Recovery/*`
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`
- `iOSMerchandiseControl/LocalPendingChange.swift`
- `iOSMerchandiseControl/Localizable.strings`
- `iOSMerchandiseControlTests/*Sync*`

### Android audit target

- `OptionsScreen.kt`
- `CatalogSyncViewModel.kt`
- `InventoryRepository.kt`
- `CatalogAutoSyncCoordinator.kt`
- `SupabaseSyncEventRealtimeSubscriber.kt`
- `SupabaseCatalogRemoteDataSource.kt`
- `SupabaseProductPriceRemoteDataSource.kt`
- `ProductPrice*`
- `AppDatabase.kt`
- DAO/entities/migrations/test sync rilevanti

### Supabase audit target

- migrations locali per `inventory_products`
- migrations locali per `inventory_suppliers`
- migrations locali per `inventory_categories`
- migrations locali per `inventory_product_prices`
- migrations locali per `shared_sheet_sessions`
- migrations locali per `sync_events`
- RLS/grants/RPC/realtime solo read-only

## 6. Stato funzionale da verificare in futura Execution

iOS e' strutturalmente pronto per essere testato: Options ha sezione cloud, summary provider, AccountSyncDecisionView, pending locali, status card, SyncOrchestrator, SyncStateStore, LocalStoreIdentity, LocalPendingChange e outbox/recovery.

Android e' sync-aware e ha Options piu' dashboard-like: `OptionsScreen`, `CatalogCloudSection`, `CatalogSyncViewModel`, auth state, pending local changes, status, progress e repository/remote data sources.

TASK-131 non deve copiare UI Android in iOS o viceversa. Deve verificare che entrambe dicano la stessa verita' all'utente, con UX nativa diversa.

Supabase resta backend dev/live controllato con dati sintetici `TASK131_*`. Non inventare store remoto se lo schema resta `localDefaultStoreOnly`; non introdurre migration/RLS/grants salvo blocker esplicito e nuova autorizzazione.

## 7. Strumenti: esistenti, mancanti, da migliorare, da creare

### Strumenti gia' esistenti

| Strumento | Uso previsto | Limite Planning |
|---|---|---|
| `mc-agent.sh help-json` / `list commands-json` | Discovery comandi canonici | Da rieseguire in Execution; non usare output storico come PASS corrente. |
| `config validate`, `git head-consistency`, `preflight` | Canonical audit | Solo Planning/readiness finche' non parte Execution. |
| `ios build`, `android build`, `ios test`, `android test` | Build/test locali | Vietati in questa review Planning-only. |
| `supabase verify-*`, `supabase contract * --read-only` | Schema/RLS/grants/RPC read-only | Ammessi solo in futura Execution se richiesti; live/write vietati senza gate. |
| TASK-126 scanners | Policy/static guard | Supportano audit, non sostituiscono device fisico. |
| TASK-125 live physical commands | Riferimento storico real-device | Non coprono tutta la policy TASK-126 C126-00...C126-60. |

### Strumenti mancanti

| Gap | Perche' serve |
|---|---|
| Parser/report matrix C126-00...C126-60 TASK-131 | Deve impedire REVIEW se un mandatory case resta `NOT_RUN`. |
| Harness fisico tap/screenshot/video Options iOS/Android | Screenshot statici non bastano per UI/UX no-false-state e CTA reali. |
| Fixture generator scoped `TASK131_*` per conflict/account/offline | Serve dataset sintetico ripetibile senza dati reali. |
| Device lock/background/long offline coordinator | Serve classificare correttamente iOS scheduler e Android WorkManager/logcat. |
| Accessibility runner/report | Serve evidence Dynamic Type/VoiceOver/TalkBack reale o operator-assisted strutturata. |

### Strumenti da migliorare

| Strumento | Miglioramento richiesto |
|---|---|
| `mc-agent` report | Includere case matrix, screenshot/video paths, cleanup/residue status, device info redatto. |
| Redaction comune | Coprire device fisici, OAuth/logcat/xcodebuild e screenshot/video metadata. |
| Live lock | Garantire lock unico per live/cleanup TASK-131. |
| Timeout/heartbeat | Ogni physical matrix lunga deve emettere heartbeat e timeout espliciti. |
| JSON validation | Validare schema `1.1` piu' payload TASK-131 specifico. |

### Strumenti da creare/migliorare in questa Execution hybrid

```bash
./tools/agent/mc-agent.sh physical devices list --task TASK-131
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios physical sync-policy-ui --task TASK-131 --prefix TASK131_IOS_
./tools/agent/mc-agent.sh ios simulator sync-policy-ui --task TASK-131 --prefix TASK131_IOS_SIM_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh android physical sync-policy-ui --task TASK-131 --prefix TASK131_ANDROID_PHYS_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical sync-policy-matrix --task TASK-131 --prefix TASK131_POLICY_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical conflict-review-matrix --task TASK-131 --prefix TASK131_CONFLICT_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical account-switch-matrix --task TASK-131 --prefix TASK131_ACCOUNT_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical offline-background-matrix --task TASK-131 --prefix TASK131_OFFLINE_
./tools/agent/mc-agent.sh physical accessibility-smoke --task TASK-131
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical hybrid-sync-policy-matrix --task TASK-131 --prefix TASK131_HYBRID_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical hybrid-conflict-review-matrix --task TASK-131 --prefix TASK131_CONFLICT_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical hybrid-offline-reconnect-matrix --task TASK-131 --prefix TASK131_OFFLINE_
./tools/agent/mc-agent.sh physical hybrid-accessibility-smoke --task TASK-131
./tools/agent/mc-agent.sh scan task131-matrix-completeness --task TASK-131 --strict
./tools/agent/mc-agent.sh scan task131-redaction --task TASK-131 --strict
./tools/agent/mc-agent.sh scan task131-final-gates --task TASK-131 --strict
```

Questi comandi devono apparire in `help-json` e `list commands-json` prima di essere considerati canonici. I wrapper iOS physical restano bloccanti per i casi iPhone reale nel perimetro corrente e devono emettere `BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE`, non PASS.

## 8. Exit taxonomy

| Stato | Significato | Exit code comando |
|---|---|---|
| PASS | Gate/caso obbligatorio eseguito e superato con evidence richiesta. | `0` |
| FAIL | Gate/caso eseguito e fallito, oppure omissione interna di caso obbligatorio. | `1` |
| BLOCKED_EXTERNAL | Prerequisito esterno mancante: device, trust, account, iOS scheduler, credenziali test. | `2` |
| MISCONFIGURED | Harness/config/task id/prefix/schema report errato. | `3` |
| UNSAFE_OPERATION_REFUSED | Live/cleanup/prefix/SQL vietato o gate safety assente. | `4` |
| NOT_RUN | Stato di singolo caso matrix non eseguito. Non e' successo operativo e non puo' abilitare REVIEW per mandatory P0. | N/A case status |
| PASS_WITH_NOTES | Solo limite non P0, documentato e non incidente su final acceptance P0. | `0` con result override esplicito |

## 9. Physical redaction hardening

Ogni report, log, screenshot manifest, video manifest e JSON TASK-131 deve redigere:

- iOS UDID, device identifier, pairing identifier;
- nome iPhone se identifica utente/persona;
- Android serial, transport id, modello se potenzialmente identificante;
- screenshot/video paths e metadata personali;
- logcat;
- xcodebuild/device logs;
- OAuth callback URL, token, refresh token, JWT, bearer;
- email e account provider;
- Supabase project ref, URL e anon/service key;
- path personali `/Users/...`;
- barcode, prodotti, negozi, store name e supplier/category reali;
- query SQL con valori reali non sintetici.

Le fixture ammesse devono usare solo prefissi `TASK131_*`.

## 10. Safety live / cleanup

- Live/mutation solo con `MC_ALLOW_LIVE=1`.
- Cleanup execute solo con `MC_ALLOW_CLEANUP=1`.
- Cleanup dry-run obbligatorio prima di execute.
- `cleanup_plan_id` obbligatorio e deve corrispondere a task/prefix/profile.
- Prefissi ammessi solo `TASK131_*`.
- Vietato `auth.users`.
- Vietato `truncate`.
- Vietato cleanup globale o pattern non scoped.
- Vietato `service_role` nel client.
- Vietato indebolire RLS/grants per far passare test.
- Residue finale obbligatorio: Supabase `TASK131_* = 0`, iOS local `TASK131_* = 0` o nota motivata, Android local `TASK131_* = 0` o nota motivata.

## 11. Harness governance

Nuovi comandi fisici TASK-131 devono:

- apparire in `help-json` e `list commands-json`;
- produrre Markdown e JSON schema `1.1`;
- stampare `RESULT`, `EXIT_CODE`, `REPORT_MD`, `REPORT_JSON`, `NEXT_ACTION`;
- usare redaction comune;
- avere timeout e heartbeat per run lunghe;
- usare lock per live/cleanup;
- non passare se non trova device fisico, test target o sessione richiesta;
- distinguere simulator/emulator/supporting evidence da physical acceptance;
- allegare screenshot/video paths quando disponibili;
- includere device info solo redatto/hashato;
- includere prefix, cleanup status e residue status;
- avere self-test RED/GREEN per parser matrix, exit taxonomy e redaction.

## 12. Phase -0.5 — Canonicalization gap

Prima di Execution:

| Check | Required result | Blocco se fallisce |
|---|---|---|
| Task file presence | TASK-131 presente nel repo iOS target | MISCONFIGURED |
| Evidence README presence | README evidence presente | MISCONFIGURED |
| Master Plan consistency | TASK-131 ACTIVE / PLANNING-REVIEW o approvato a EXECUTION | FAIL/MISCONFIGURED |
| GitHub/local/origin alignment | branch/head/publish state classificato | BLOCKED_EXTERNAL_CANONICAL_MISMATCH oppure LOCAL_DRAFT_NOT_REMOTE documentato |
| Harness physical command presence | discovery comandi via help-json/list commands-json | FAIL se dichiarati ma non discoverable |

## 13. Phase -0.4 — Physical redaction hardening

Prima di qualunque screenshot/log/video/device run:

- eseguire scanner redaction TASK-131 su report fixtures RED/GREEN;
- verificare redaction device ids iOS/Android;
- verificare redaction email/OAuth/Supabase;
- verificare che screenshot/video manifest non contenga path personali non redatti;
- vietare upload di screenshot con barcode/prodotti/negozi reali visibili;
- usare dataset sintetico visivamente riconoscibile `TASK131_*`.

## 14. Fasi operative future

### Phase -1 — GitHub/local canonical audit

```bash
MC_TASK_ID=TASK-131 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-131 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-131 ./tools/agent/mc-agent.sh config validate
MC_TASK_ID=TASK-131 ./tools/agent/mc-agent.sh git head-consistency --task TASK-131
MC_TASK_ID=TASK-131 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-131
```

Non dichiarare wrapper TASK-131 discoverable finche' questi due comandi non mostrano i comandi richiesti:

- `help-json`
- `list commands-json`

### Phase 0 — Audit UI/UX iOS + Android + Supabase

Audit read-only dei file in sezione 5. Supabase store mode deve essere dichiarato:

- `localDefaultStoreOnly`: non inviare store remoto o promettere multi-store cloud completo;
- `remoteStoreAware`: usare solo se schema/RLS/grants dimostrano owner+store scope.

### Phase 1 — Device readiness

Evidence reale richiesta:

- iPhone fisico rilevato, trusted, build installata, launch OK, sessione Supabase restore/login OK, screenshot Options iniziale;
- Android fisico rilevato via adb, APK installata, launch OK, sessione Supabase restore/login OK, screenshot Options iniziale.

Se manca un device: `BLOCKED_EXTERNAL_DEVICE_NOT_READY`, non PASS.

### Phase 2 — UI/UX Options first-sync e no-false-state

Su entrambi i device:

- signed out;
- signed in, local empty, remote empty;
- signed in, local empty, remote populated;
- signed in, local dirty;
- signed in, remote dirty;
- sync running;
- offline;
- reconnecting;
- conflict/review required;
- blocked auth/RLS;
- recovery required;
- pending local changes.

Expected UX: Options non deve mai dire "Tutto aggiornato" se ci sono pending, recovery, conflict, blocked auth o drift. Retry/sign-in/review devono essere raggiungibili con tap reale. CTA distruttive devono essere chiare e annullabili.

### Phase 3 — Normal sync physical matrix

Eseguire iOS fisico <-> Android fisico:

- iOS modifica prodotto -> Android riceve;
- Android modifica prodotto -> iOS riceve;
- iOS modifica ProductPrice -> Android riceve;
- Android modifica ProductPrice -> iOS riceve;
- iOS crea supplier/category/product -> Android riceve;
- Android crea supplier/category/product -> iOS riceve;
- no-op sync non fa full pull;
- burst 10 modifiche non crea duplicati;
- kill/restart durante pending non perde outbox;
- network flap durante ack non marca ack falso.

### Phase 4 — Conflict / Review / Recovery UX fisica

Fixture `TASK131_CONFLICT_*`:

1. iOS offline cambia `productName`, Android online cambia `retailPrice`: merge automatico, niente popup.
2. iOS offline cambia `productName=A`, Android online cambia `productName=B`: Review conflitto.
3. iOS modifica prodotto, Android elimina/tombstone: Review delete-vs-edit, niente resurrection silenziosa.
4. ProductPrice stesso product/type/effectiveAt/value: dedupe idempotente.
5. ProductPrice stesso product/type/effectiveAt ma value diverso: Review/stale reject, niente overwrite silenzioso.

### Phase 5 — Account switch physical UX

Serve secondo account test. Se manca: `BLOCKED_EXTERNAL_SECOND_ACCOUNT`, non PASS.

Scenari:

- Account A clean -> logout -> Account B vuoto;
- Account A clean -> logout -> Account B popolato;
- Account A dirty -> tentativo Account B;
- Account A dirty -> export backup;
- Account A dirty -> cancel;
- Account A dirty -> discard and switch con conferma forte.

Expected: mai push A -> B, dirty preservato finche' utente decide, export backup accessibile prima di scarto, cancel non perde pending.

### Phase 6 — Background / locked / long offline fisico

Scenari:

- iOS foreground 15 min con sync events;
- Android foreground 15 min con sync events;
- iOS background 15 min;
- Android background 15 min;
- iOS locked screen 15 min;
- Android locked screen 15 min;
- offline 30 min con modifiche locali su entrambi;
- reconnect dopo offline lungo;
- kill app durante pending;
- riapertura app e drain/recovery.

iOS BGTask scheduler non deve diventare PASS tecnico se il sistema non esegue la task: usare `BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY`.

### Phase 7 — Accessibility

iOS:

- Dynamic Type XXXL su Options, Account Decision, Conflict Review;
- VoiceOver traversal Options;
- VoiceOver su destructive actions;
- VoiceOver su pending/conflict badge.

Android:

- Font scale alto;
- TalkBack traversal Options;
- TalkBack su badge cloud/local pending;
- TalkBack su azioni destructive.

### Phase 8 — Cleanup, residue, final drift

```bash
./tools/agent/mc-agent.sh supabase cleanup --task TASK-131 --prefix TASK131_ --dry-run
MC_ALLOW_CLEANUP=1 ./tools/agent/mc-agent.sh supabase cleanup --task TASK-131 --prefix TASK131_ --execute --cleanup-plan-id <id>
./tools/agent/mc-agent.sh supabase residue-check --task TASK-131 --prefix TASK131_ --profile linked
```

Expected finale:

- Supabase residue `TASK131_* = 0`;
- iOS local residue `TASK131_* = 0` o documentato;
- Android local residue `TASK131_* = 0` o documentato;
- drift Supabase/iOS/Android = 0;
- pending = 0 salvo casi intenzionalmente blocked/recovery;
- duplicate ProductPrice = 0;
- no full pull normal path PASS;
- no cross-owner/store pending push PASS.

## 15. Matrix C126-00...C126-60

Schema obbligatorio per ogni caso:

| caseId | scenario | requiredEvidenceTier | platforms | command | prefix | expectedUserUX | expectedDataInvariant | result | reportJson | reportMd | cleanupRequired | residueResult | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C126-00 | No account / signed out | physical-live | iOS, Android | `ios/android physical sync-policy-ui` | `TASK131_IOS_`, `TASK131_ANDROID_` | Options mostra sign-in/retry, non sync updated | Nessun push/pull senza account | NOT_RUN |  |  | no | NOT_RUN | P0 |
| C126-01 | Login / session restore | physical-live | iOS, Android | `ios/android physical sync-policy-ui` | `TASK131_AUTH_` | Stato account chiaro | Owner scope inizializzato | NOT_RUN |  |  | no | NOT_RUN | P0 |
| C126-02 | Logout/login stesso account | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Nessuna perdita pending | Owner invariato, pending preservati | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-03 | Local dirty push | physical-live | iOS->Android, Android->iOS | `physical sync-policy-matrix` | `TASK131_POLICY_` | Pending visibile finche' ack | Push scoped owner/store, ack reale | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-04 | Remote dirty pull | physical-live | iOS, Android | `physical sync-policy-matrix` | `TASK131_POLICY_` | Stato refresh/reconnect chiaro | Pull incrementale, no full pull | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-05 | Local+remote dirty campi diversi | physical-live | iOS, Android | `physical conflict-review-matrix` | `TASK131_CONFLICT_` | Nessun popup se merge sicuro | Merge field-level senza rompere invarianti | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-06 | Single-flight sync | physical-live | iOS, Android | `physical sync-policy-matrix` | `TASK131_POLICY_` | UI non duplica progress | Una run mutativa per scope | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-07 | Same-field conflict | physical-live | iOS, Android | `physical conflict-review-matrix` | `TASK131_CONFLICT_` | Review conflitto raggiungibile | Nessun overwrite silenzioso | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-08 | Delete-vs-edit | physical-live | iOS, Android | `physical conflict-review-matrix` | `TASK131_CONFLICT_` | Review delete-vs-edit | Nessuna resurrection silenziosa | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-09 | Barcode duplicate | physical-live | iOS, Android | `physical conflict-review-matrix` | `TASK131_CONFLICT_` | Review/blocked chiaro | Business key non duplicata | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-10 | Offline local edit | physical-live | iOS, Android | `physical offline-background-matrix` | `TASK131_OFFLINE_` | Offline/pending visibile | Pending durable | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-11 | Reconnect drain | physical-live | iOS, Android | `physical offline-background-matrix` | `TASK131_OFFLINE_` | Reconnecting/drain chiaro | Ack solo dopo remote write | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-12 | Kill/restart pending | physical-live | iOS, Android | `physical offline-background-matrix` | `TASK131_OFFLINE_` | Pending ancora visibile al ritorno | Outbox non persa | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-13 | Network flap during ack | physical-live | iOS, Android | `physical offline-background-matrix` | `TASK131_OFFLINE_` | Stato non falso updated | Nessun ack parziale | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-14 | Account A -> B clean empty | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Switch chiaro | Nessun push cross-account | NOT_RUN |  |  | yes | NOT_RUN | P0 if second account exists |
| C126-15 | Account A -> B clean populated | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Pull/switch decision chiara | Owner B only | NOT_RUN |  |  | yes | NOT_RUN | P0 if second account exists |
| C126-16 | Account A dirty -> B | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Review/backup/cancel | Dirty A non pushato a B | NOT_RUN |  |  | yes | NOT_RUN | P0 if second account exists |
| C126-17 | Cancel account switch | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Cancel non distruttivo | Pending invariati | NOT_RUN |  |  | yes | NOT_RUN | P0 if second account exists |
| C126-18 | Token/session expired | physical-live | iOS, Android | `ios/android physical sync-policy-ui` | `TASK131_AUTH_` | Sign-in/retry, no updated falso | Fail closed, no mutation | NOT_RUN |  |  | no | NOT_RUN | P0 |
| C126-19 | Logout/login same account dirty | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Pending/recovery chiaro | Owner same, pending durable | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-20 | Permission denied / RLS | physical-live + read-only schema | iOS, Android, Supabase | `physical sync-policy-matrix` + `supabase verify-rls` | `TASK131_POLICY_` | Blocked auth/RLS, retry | Fail closed, no local ack | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-21 | Schema/protocol mismatch | physical-live/supporting static | iOS, Android | `physical sync-policy-matrix` | `TASK131_POLICY_` | Recovery required | No write with incompatible protocol | NOT_RUN |  |  | no | NOT_RUN | P0 |
| C126-22 | Recovery required | physical-live | iOS, Android | `ios/android physical sync-policy-ui` | `TASK131_RECOVERY_` | Recovery CTA chiara | No hidden reseed | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-23 | Review required | physical-live | iOS, Android | `physical conflict-review-matrix` | `TASK131_CONFLICT_` | Review reachable | Conflict state durable | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-24 | ProductPrice stale | physical-live | iOS, Android | `physical conflict-review-matrix` | `TASK131_CONFLICT_` | Review/stale reject | No silent overwrite | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-25 | ProductPrice dedupe | physical-live | iOS, Android | `physical conflict-review-matrix` | `TASK131_CONFLICT_` | No duplicate warning if idempotent | Duplicate ProductPrice = 0 | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-26 | ProductPrice append | physical-live | iOS, Android | `physical sync-policy-matrix` | `TASK131_POLICY_` | Price state updated | Append-only history coherent | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-27 | Cursor gap / remote reset | physical-live | iOS, Android | `physical offline-background-matrix` | `TASK131_OFFLINE_` | Recovery not silent updated | Full pull only recovery/setup | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-28 | Store switch clean | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Store switch clear | Pending scoped | NOT_RUN |  |  | yes | NOT_RUN | P1 if backend localDefaultStoreOnly |
| C126-29 | Store switch dirty | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Backup/cancel/discard | Dirty cache preserved until decision | NOT_RUN |  |  | yes | NOT_RUN | P1 if backend localDefaultStoreOnly |
| C126-30 | Cleanup clean cache | physical-live/local | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Non destructive warning appropriate | Clean cache only deleted | NOT_RUN |  |  | yes | NOT_RUN | P1 |
| C126-31 | Dirty cache cleanup refused | physical-live/local | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Strong warning/export | Dirty cache preserved | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-32 | Pending scoped by owner/store | physical-live/static scan | iOS, Android | `scan no-cross-owner-store-pending-push` | `TASK131_POLICY_` | No misleading account state | No cross-scope push | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-33 | Revoked access | physical-live | iOS, Android | `physical sync-policy-matrix` | `TASK131_POLICY_` | Permission denied fail-closed | No mutation/ack | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-34 | Protocol version mismatch | physical-live/static | iOS, Android | `physical sync-policy-matrix` | `TASK131_POLICY_` | Recovery/protocol message | No stale client writes | NOT_RUN |  |  | no | NOT_RUN | P0 |
| C126-35 | Legacy local data | physical-live/local | iOS, Android | `physical account-switch-matrix` | `TASK131_LEGACY_` | Bind/recovery choice | No silent owner assignment | NOT_RUN |  |  | yes | NOT_RUN | P1 |
| C126-36 | Owner mismatch fail-closed | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Blocked/review | No owner mismatch push | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-37 | Switch during sync | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Sync lock/cancel clear | No partial cross-account writes | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-38 | Export before discard | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Export offered | Dirty data recoverable best-effort | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-39 | Bulk import offline | physical-live | iOS, Android | `physical offline-background-matrix` | `TASK131_OFFLINE_` | Bulk pending visible | Drain idempotent, no dupes | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-40 | Account B populated merge decision | physical-live | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Merge/replace/upload choices clear | No implicit destructive merge | NOT_RUN |  |  | yes | NOT_RUN | P0 if second account exists |
| C126-41 | No-op sync | physical-live | iOS, Android | `physical sync-policy-matrix` | `TASK131_POLICY_` | No progress lie | No full pull, no writes | NOT_RUN |  |  | no | NOT_RUN | P0 |
| C126-42 | Burst 10 changes | physical-live | iOS, Android | `physical sync-policy-matrix` | `TASK131_POLICY_` | Progress remains usable | No duplicates, pending drains | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-43 | Realtime/safety loop | physical-live | iOS, Android | `physical sync-policy-matrix` | `TASK131_POLICY_` | Status eventually updated | Incremental events applied | NOT_RUN |  |  | yes | NOT_RUN | P1 |
| C126-44 | Legacy/unbound account | physical-live/local | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Decision shown | No silent cloud upload | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-45 | Domain invariant conflict | physical-live | iOS, Android | `physical conflict-review-matrix` | `TASK131_CONFLICT_` | Review not auto-merge | Business invariant preserved | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-46 | Active store cache only | physical-live/static | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Active store status clear | Inactive dirty not pushed | NOT_RUN |  |  | yes | NOT_RUN | P1 |
| C126-47 | Inactive clean cache cleanup | physical-live/local | iOS, Android | `physical account-switch-matrix` | `TASK131_ACCOUNT_` | Cleanup scoped | Only clean inactive cache removed | NOT_RUN |  |  | yes | NOT_RUN | P1 |
| C126-48 | Permission/schema/cache fail closed | physical-live/read-only | iOS, Android, Supabase | `physical sync-policy-matrix` | `TASK131_POLICY_` | Blocked/recovery clear | No unsafe mutation | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-49 | Options pending count truth | physical-live | iOS, Android | `ios/android physical sync-policy-ui` | `TASK131_UI_` | Pending count visible | Pending count matches local state | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-50 | Options conflict truth | physical-live | iOS, Android | `ios/android physical sync-policy-ui` | `TASK131_UI_` | Review CTA visible | Conflict remains until resolved | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-51 | Options recovery truth | physical-live | iOS, Android | `ios/android physical sync-policy-ui` | `TASK131_UI_` | Recovery CTA visible | No hidden full pull | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-52 | Destructive CTA clarity | physical-live/accessibility | iOS, Android | `physical accessibility-smoke` | `TASK131_UI_` | Strong confirmation/cancel | No data loss on cancel | NOT_RUN |  |  | no | NOT_RUN | P0 |
| C126-53 | Dynamic Type / font scale | physical-live/accessibility | iOS, Android | `physical accessibility-smoke` | `TASK131_UI_` | Text readable, no overlap | No data mutation | NOT_RUN |  |  | no | NOT_RUN | P1 |
| C126-54 | VoiceOver/TalkBack traversal | physical-live/accessibility | iOS, Android | `physical accessibility-smoke` | `TASK131_UI_` | Labels meaningful | No data mutation | NOT_RUN |  |  | no | NOT_RUN | P1 |
| C126-55 | Background foreground return | physical-live | iOS, Android | `physical offline-background-matrix` | `TASK131_OFFLINE_` | State refreshed on return | Pending not lost | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-56 | Locked screen | physical-live | iOS, Android | `physical offline-background-matrix` | `TASK131_OFFLINE_` | Correct state after unlock | No false ack | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-57 | Long offline reconnect | physical-live | iOS, Android | `physical offline-background-matrix` | `TASK131_OFFLINE_` | Reconnect/drain visible | Drift 0 after drain | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-58 | Sensitive evidence validation | static/report | iOS, Android, Supabase | `scan task131-redaction` | n/a | N/A | No sensitive leaks | NOT_RUN |  |  | no | NOT_RUN | P0 |
| C126-59 | Cleanup/residue | live cleanup | Supabase, iOS, Android | `supabase cleanup/residue-check` | `TASK131_` | N/A | Residue 0 or documented local residue | NOT_RUN |  |  | yes | NOT_RUN | P0 |
| C126-60 | Final drift/pending gate | physical-live | iOS, Android, Supabase | `physical sync-policy-matrix` | `TASK131_POLICY_` | Updated only when true | Drift 0, pending 0, duplicates 0 | NOT_RUN |  |  | yes | NOT_RUN | P0 |

## 16. P0 physical-live mandatory subset

Questi casi sono mandatory per passare da Execution a REVIEW:

- auth/session iOS fisico;
- auth/session Android fisico;
- local dirty push;
- remote dirty pull;
- merge campi diversi;
- same-field conflict Review;
- delete-vs-edit Review;
- ProductPrice append/dedupe/stale;
- offline/reconnect;
- kill/restart pending;
- account switch clean/dirty se secondo account disponibile;
- Options no false updated;
- no full pull normal path;
- no cross-owner/store pending push;
- cleanup/residue `TASK131_*`.

Se il secondo account non e' disponibile, classificare solo quei casi come `BLOCKED_EXTERNAL_SECOND_ACCOUNT`; non trasformarli in PASS. Se il blocker impedisce una garanzia P0, TASK-131 non puo' andare a DONE senza accettazione esplicita.

## 17. Criteri finali

| Criterio | Stato Planning-review | Gate futuro |
|---|---|---|
| TASK-131 tracking professionale creato | ESEGUITO_LOCAL_DRAFT | Pubblicare/canonicalizzare prima di Execution. |
| MASTER-PLAN coerente | ESEGUITO_PLANNING | Indica ACTIVE / PLANNING-REVIEW. |
| Wrapper TASK-131 discoverable | NON DICHIARATO | Serve evidence `help-json` + `list commands-json` futura. |
| iOS physical build/install/launch | NOT_RUN | Richiede device fisico e approvazione Execution. |
| Android physical build/install/launch | NOT_RUN | Richiede device fisico e approvazione Execution. |
| iOS auth/session | NOT_RUN | P0 mandatory. |
| Android auth/session | NOT_RUN | P0 mandatory. |
| Supabase linked/dev schema/RLS read-only | NOT_RUN | Read-only gate in Execution. |
| C126-00...C126-60 classificati | NOT_RUN | Matrix report obbligatorio. |
| Cross-platform drift finale 0 | NOT_RUN | P0 mandatory. |
| Pending finale 0 salvo blocked/recovery | NOT_RUN | P0 mandatory. |
| Duplicate ProductPrice 0 | NOT_RUN | P0 mandatory. |
| No full pull normal path scan | NOT_RUN | P0 mandatory. |
| No cross-owner/store pending push | NOT_RUN | P0 mandatory. |
| Sensitive/evidence/JSON validation | NOT_RUN | P0 mandatory. |
| Cleanup/residue `TASK131_*` | NOT_RUN | P0 mandatory. |

Massimo dopo Planning: `ACTIVE / PLANNING-REVIEW — READY_FOR_EXECUTION_AFTER_USER_APPROVAL`.

Massimo dopo Execution: `ACTIVE / REVIEW`.

`DONE` solo dopo review indipendente + accettazione esplicita utente.

Nessun claim production-ready globale.

## 18. Draft Codex execution claims — NOT ACCEPTED AS CANONICAL EVIDENCE

Questa sezione conserva le affermazioni del draft precedente solo come contesto non canonico. Non sono evidence finale TASK-131 e non autorizzano REVIEW.

### Draft locale — 2026-05-28

**Claim dichiarati nel draft precedente:**

- task file creato;
- evidence README creato;
- Master Plan aggiornato a `ACTIVE / EXECUTION`;
- route `physical` proposta in `mc-agent`;
- route `ios physical sync-policy-ui` proposta;
- route `android physical sync-policy-ui` proposta;
- wrapper fisici proposti;
- discovery fisica e JSON validation dichiarati eseguiti nel draft.

**Planning-review verdict:**

- Questi claim sono `LOCAL_DRAFT_NOT_REMOTE`.
- Non sono accettati come evidence canonica di Execution.
- Non sostituiscono `help-json`, `list commands-json`, device readiness, matrix fisica, cleanup/residue o review indipendente.
- Il task deve tornare a Planning-review prima di una futura Execution approvata.

## 19. Handoff Planning

Stato raccomandato dopo questa review:

```text
ACTIVE / PLANNING-REVIEW — READY_FOR_EXECUTION_AFTER_USER_APPROVAL
```

Limiti residui:

- TASK-131 e relative modifiche sono local draft, non remote canonical.
- Nessun caso C126-00...C126-60 e' stato eseguito in questa review.
- Nessuna build/test/runtime/live/cleanup eseguita in questa review.
- Harness fisico va completato e provato con self-test RED/GREEN in futura Execution.
- Device fisici, secondo account test, VoiceOver/TalkBack e iOS background scheduler restano prerequisiti/blocchi potenziali.

Prompt per futura Execution:

```text
Esegui TASK-131 solo dopo approvazione utente esplicita. Prima canonicalizza GitHub/local/origin e dimostra con help-json/list commands-json che i comandi TASK-131 sono discoverable. Implementa o completa gli harness fisici con report Markdown/JSON schema 1.1, redaction comune, timeout/heartbeat, live lock, self-test RED/GREEN per parser matrix/exit taxonomy/redaction. Poi esegui device readiness su iPhone fisico e Android fisico, matrix P0 physical-live C126-00...C126-60 con dati sintetici TASK131_*, cleanup dry-run/execute con cleanup_plan_id e residue finale. Non passare a REVIEW con mandatory NOT_RUN. Non dichiarare DONE senza review indipendente e accettazione esplicita utente.
```

## 20. Planning acceptance gate

TASK-131 puo' passare da PLANNING-REVIEW a EXECUTION solo se:

- il file task e' committato o comunque presente nel repo iOS target;
- `docs/MASTER-PLAN.md` e' aggiornato e coerente;
- `docs/TASKS/EVIDENCE/TASK-131/README.md` esiste;
- lo stato GitHub/local/origin e' classificato;
- l'utente approva esplicitamente Execution;
- non ci sono claim runtime, build, test, live o cleanup gia' dichiarati come PASS in Planning;
- l'harness fisico e' ancora dichiarato "da creare/migliorare", salvo prova reale via `help-json` e `list commands-json`.

Stato massimo dopo questa review:

```text
ACTIVE / PLANNING-REVIEW — READY_FOR_EXECUTION_AFTER_USER_APPROVAL
```

Vietato passare automaticamente a Execution.

## 21. Execution — 2026-05-28 — ANDROID_PHYSICAL_IOS_SIMULATOR_SCOPE

Autorizzazione utente ricevuta il 2026-05-28 per procedere in Execution end-to-end nel perimetro realistico disponibile:

- Android dispositivo fisico reale: mandatory;
- iOS Simulator: mandatory;
- iPhone fisico reale: non disponibile, quindi `BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE`;
- secondo account test: da verificare; se assente, `BLOCKED_EXTERNAL_SECOND_ACCOUNT`.

Stato task aggiornato:

```text
ACTIVE / EXECUTION — ANDROID_PHYSICAL_IOS_SIMULATOR_SCOPE
```

### Esecuzione — 2026-05-28

**File modificati:**

- `docs/TASKS/TASK-131-physical-device-sync-policy-ui-ux-acceptance.md` — stato Execution hybrid, canonicalita locale e perimetro bloccato iPhone fisico.
- `docs/TASKS/EVIDENCE/TASK-131/README.md` — indice evidence aggiornato per Android physical + iOS Simulator.
- `docs/MASTER-PLAN.md` — TASK-131 aggiornato da Planning-review a Execution hybrid.
- `tools/agent/lib/redact.sh` — hardening redaction per OAuth callback, project ref URL, seriali Android e UDID/device identifiers iOS.
- `tools/agent/lib/task131_physical.sh` — wrapper TASK-131 fisici/hybrid, device discovery redatto, iOS Simulator scope, Android physical scope e matrix hybrid.
- `tools/agent/lib/task131_scans.py` — scanner TASK-131 per redaction, matrix completeness e final gates.
- `tools/agent/lib/common.sh` — help/help-json e scanner routing TASK-131.
- `tools/agent/mc-agent.sh` — routing scanner TASK-131.
- `tools/agent/lib/ios.sh` — routing `ios simulator sync-policy-ui`.

**Azioni eseguite:**

1. Avviata canonicalizzazione locale del task nel repo iOS target.
2. Aggiornato il perimetro corrente a Android fisico + iOS Simulator, con iPhone fisico marcato come blocker esterno.
3. Avviato hardening harness/redaction prima dei gate live.

**Check obbligatori iniziali:**

| Check | Stato | Note |
|---|---|---|
| Planning acceptance gate | ESEGUITO | Utente ha approvato Execution, ma solo hybrid scope. |
| iPhone physical scope | NON ESEGUIBILE | `BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE`. |
| Canonicalita GitHub/local/origin | ESEGUITO_PARZIALE | Local worktree e' sorgente corrente; non dichiarare remote aligned. |
| Harness discovery | IN_CORSO | Deve passare `help-json` e `list commands-json` dopo i fix harness. |
| Live/build/test/device gates | IN_CORSO | Non ancora dichiarati PASS in questa sezione. |

**Incertezze:**

- Disponibilita' effettiva Android fisico, sessioni Supabase e secondo account test da verificare con wrapper.

**Handoff notes:**

- Stato massimo finale senza iPhone fisico: `ACTIVE / REVIEW — ANDROID_PHYSICAL_IOS_SIMULATOR_SCOPE_PASS_WITH_EXTERNAL_BLOCKERS`.
- Se i gate P0 disponibili restano NOT_RUN/FAIL per ragioni non esterne, usare `ACTIVE / BLOCKED`, `ACTIVE / FIX` o `ACTIVE / REVIEW_WITH_NOTES` secondo evidenza reale.

### Chiusura Execution disponibile — 2026-05-28

**Stato finale impostato:**

```text
ACTIVE / FIX — ANDROID_PHYSICAL_IOS_SIMULATOR_SCOPE_NEEDS_IOS_SIM_AUTH_AND_HYBRID_AUTOMATION_FIXES
```

Motivo: i gate disponibili non sono promuovibili a REVIEW perche' le matrix P0 hybrid non hanno PASS reale. Android fisico, iOS Simulator smoke, build/test, scans, Supabase read-only e cleanup/residue hanno evidence; normal sync/offline hybrid sono bloccati dalla sessione iOS Simulator non valida, conflict/review e accessibility richiedono ancora fixture/tap traversal reali o evidence operator-assisted strutturata.

**File modificati aggiuntivi:**

- `iOSMerchandiseControl/ContentView.swift` — hook DEBUG-only `TASK131_INITIAL_TAB=options` per screenshot Options simulator deterministico, senza cambiare Release behavior.
- `iOSMerchandiseControlTests/Task131HarnessLaunchTests.swift` — test mirato per garantire che l'hook TASK-131 resti DEBUG-only e punti alla tab Options.
- `tools/agent/lib/redact.sh` — fix ulteriore: le regex URL non consumano piu' le virgolette JSON durante la redazione di callback OAuth.
- `docs/TASKS/EVIDENCE/TASK-131/final-hybrid-execution-summary.md` / `.json` — riepilogo finale.
- `docs/TASKS/EVIDENCE/TASK-131/final-review-checklist.md` / `.json` — checklist finale case/gate.

**Gate PASS nel perimetro eseguito:**

| Gate | Result | Report |
|---|---:|---|
| `config validate` | PASS | `agent-runs/20260528T161641Z-config-validate-p46635.json` |
| `git head-consistency --task TASK-131` | PASS | `agent-runs/20260528T161641Z-git-head-consistency-task-TASK-131-p47048.json` |
| `preflight --require-head-consistency --task TASK-131` | PASS | `agent-runs/20260528T161644Z-preflight-require-head-consistency-task-TASK-131-p46624.json` |
| Supabase schema/RLS/grants/RPC/realtime/price read-only | PASS | `agent-runs/20260528T161704Z...` through `20260528T161740Z...` |
| iOS Debug/Release build | PASS | `agent-runs/20260528T163640Z-ios-build-debug-p82092.json`, `agent-runs/20260528T163644Z-ios-build-release-p82653.json` |
| iOS sync, price-contract, TASK-131 harness tests | PASS | `agent-runs/20260528T163752Z...`, `20260528T164039Z...`, `20260528T164223Z...` |
| Android debug build, sync tests, price-contract tests | PASS | `agent-runs/20260528T162223Z...`, `20260528T162235Z...`, `20260528T162243Z...` |
| Device discovery | PASS | `agent-runs/20260528T162358Z-physical-devices-list-task-TASK-131-p62110.json` |
| iOS Simulator Options smoke | PASS | `agent-runs/20260528T162939Z-ios-simulator-sync-policy-ui-task-TASK-131-prefix-TASK131_IOS_SIM_-p67594.json` |
| Android physical Options/auth/launch smoke | PASS | `agent-runs/20260528T163130Z-android-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_ANDROID_PHYS_-p70194.json` |
| Redaction, sensitive, evidence, JSON validation | PASS | `agent-runs/20260528T164855Z...`, `20260528T165541Z...`, `20260528T165555Z...` |
| No full pull / no cross-owner-store / no service role / no RLS bypass scans | PASS | `agent-runs/20260528T163628Z...`, `20260528T163629Z...`, `20260528T163630Z...` |
| Supabase cleanup dry-run, execute, residue | PASS / residue 0 | `agent-runs/20260528T164252Z...`, `20260528T164323Z...`, `20260528T164330Z...` |

**Gate bloccati o falliti:**

| Gate | Result | Motivo | Report |
|---|---:|---|---|
| iOS physical sync-policy-ui | BLOCKED_EXTERNAL | Scope utente: iPhone fisico non disponibile; il wrapper non consente PASS fisico senza opt-in esplicito. | `agent-runs/20260528T163615Z-ios-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_IOS_-p79402.json` |
| Hybrid sync-policy matrix | BLOCKED_EXTERNAL | iOS Simulator auth preflight richiede una sessione non scaduta; mandatory cases restano NOT_RUN. | `agent-runs/20260528T163217Z-physical-hybrid-sync-policy-matrix-task-TASK-131-prefix-TASK131_HYBRID_-p71543.json` |
| Hybrid offline/reconnect matrix | BLOCKED_EXTERNAL | Stesso prerequisito iOS Simulator auth; pending/drift/ack non provati. | `agent-runs/20260528T163432Z-physical-hybrid-offline-reconnect-matrix-task-TASK-131-prefix-TASK131_OFFLINE_-p75195.json` |
| Hybrid conflict/review matrix | FAIL | Mancano fixture live scoped e tap Review/Recovery reali; i test statici di supporto PASS non bastano. | `agent-runs/20260528T163358Z-physical-hybrid-conflict-review-matrix-task-TASK-131-prefix-TASK131_CONFLICT_-p74026.json` |
| Hybrid accessibility smoke | FAIL | Mancano traversal VoiceOver/TalkBack reali o checklist operator-assisted firmata. | `agent-runs/20260528T163605Z-physical-hybrid-accessibility-smoke-task-TASK-131-p78588.json` |
| Final gates TASK-131 | FAIL | Richiede PASS reale per hybrid sync/conflict/offline; correttamente non promosso. | `agent-runs/20260528T165430Z-scan-task131-final-gates-task-TASK-131-strict-p24477.json` |

**Criteri di accettazione Execution disponibili:**

| Criterio | Stato | Evidenza |
|---|---|---|
| Android physical build/install/launch/session smoke | ESEGUITO | PASS Android physical sync-policy-ui. |
| iOS Simulator build/install/launch/Options smoke | ESEGUITO | PASS iOS simulator sync-policy-ui. |
| iPhone physical evidence | NON ESEGUIBILE | `BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE`. |
| Supabase read-only schema/RLS/grants/RPC | ESEGUITO | PASS verify reports. |
| Live hybrid normal sync | NON ESEGUIBILE | Bloccato da sessione iOS Simulator non valida. |
| Conflict/ProductPrice live review matrix | NON ESEGUITO | FAIL harness/evidence gap; non PASS. |
| Offline/reconnect/kill-restart hybrid | NON ESEGUIBILE | Bloccato da sessione iOS Simulator non valida. |
| Account switch A/B | NON ESEGUIBILE | Secondo account test non fornito in questa Execution: `BLOCKED_EXTERNAL_SECOND_ACCOUNT`. |
| Accessibility VoiceOver/TalkBack | NON ESEGUITO | Serve automation traversal o checklist manuale strutturata. |
| Drift finale Supabase/iOS Simulator/Android fisico | NON ESEGUITO | Non provabile senza hybrid matrix PASS. |
| Pending finale | NON ESEGUITO | Non provabile senza hybrid matrix PASS. |
| Duplicate ProductPrice finale | NON ESEGUITO | Non provabile senza hybrid matrix PASS. |
| Cleanup/residue Supabase `TASK131_*` | ESEGUITO | PASS, residue 0. |

**Store mode dichiarato:** `localDefaultStoreOnly`. Le tabelle inventory remote risultano owner-scoped senza store remoto inventory completo; non sono state introdotte migration, colonne store, RLS/grants o scorciatoie full pull.

**Prossimo passo concreto:**

1. Ripristinare o creare una sessione Supabase valida su iOS Simulator, oppure fornire credenziali/test flow operator-assisted.
2. Completare `hybrid-conflict-review-matrix` con fixture live scoped `TASK131_CONFLICT_*` e tap/screenshot Review/Recovery reali.
3. Completare `hybrid-accessibility-smoke` con traversal automatico o checklist operator-assisted redatta.
4. Rieseguire hybrid sync/conflict/offline, final gates, cleanup/residue e JSON validation.
5. Solo dopo, con iPhone fisico disponibile, rieseguire il perimetro full physical iOS+Android.

## 22. Execution-completion — 2026-05-28 — FULL_PHYSICAL_IOS_ANDROID_SCOPE interrotto

L'utente ha reso disponibile e trusted l'iPhone fisico e ha sbloccato Android fisico; TASK-131 e' quindi ripartito nel perimetro full physical. La ripresa ha prodotto readiness/build/test/harness evidence utile, ma la matrix finale `physical sync-policy-matrix` non ha prodotto un report canonico PASS perche' l'utente ha dovuto staccare il dispositivo iOS fisico durante l'esecuzione.

**Stato corrente impostato:**

```text
ACTIVE / BLOCKED — IOS_PHYSICAL_DEVICE_DETACHED_DURING_FULL_MATRIX
```

Questo blocco e' esterno al codice: impedisce la verifica P0 full physical iPhone <-> Android. Non sono quindi dichiarati `REVIEW`, `DONE`, full physical acceptance o production-ready globale.

**File modificati in questa ripresa:**

- `tools/agent/lib/ios.sh` — supporto iOS physical migliorato e fix del riuso `xcresult` nel preflight auth, cosi' i rerun lunghi non falliscono per bundle precedente.
- `tools/agent/lib/task131_physical.sh` — matrix TASK-131 resa piu' robusta: record step via file temporaneo invece che env/arg JSON grande; no-op TASK-131 con soglia configurabile coerente con readback physical.
- `tools/agent/lib/supabase.sh` — conteggi scoped Supabase `TASK131_*`, no-op max ms configurabile e parity physical scoped per prefisso sintetico.
- `tools/agent/lib/sync.sh` — conteggi scoped iOS/Android per prodotti, supplier, category, ProductPrice e history collegati al prefisso.
- Android `HistorySessionPushCoordinator` e wiring applicazione/test — fix mirato per sync event history con fallback outbox durevole.
- `docs/TASKS/TASK-131-physical-device-sync-policy-ui-ux-acceptance.md`, `docs/MASTER-PLAN.md`, `docs/TASKS/EVIDENCE/TASK-131/README.md` — handoff dello stato bloccato e resume plan.

**Evidence PASS prodotta prima del blocco:**

| Gate | Result | Report |
|---|---:|---|
| Device discovery full physical | PASS | `agent-runs/20260528T185853Z-physical-devices-list-task-TASK-131-p4202.json` |
| iOS physical Options/auth/launch smoke | PASS | `agent-runs/20260528T185853Z-ios-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_IOS_PHYS_-p4260.json` |
| Android physical Options/auth/launch smoke | PASS | `agent-runs/20260528T190355Z-android-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_ANDROID_PHYS_-p13552.json` |
| iOS Debug/Release build e sync/price tests | PASS | `agent-runs/20260528T190236Z-ios-build-debug-p11153.json`, `20260528T190236Z-ios-build-release-p11152.json`, `20260528T190236Z-ios-test-sync-p11166.json`, `20260528T190236Z-ios-test-price-contract-task-TASK-131-p11170.json` |
| Android build/debug, sync, price-contract | PASS | `agent-runs/20260528T194705Z-android-build-debug-p60765.json`, `20260528T194801Z-android-test-sync-p78001.json`, `20260528T194812Z-android-test-price-contract-task-TASK-131-p78664.json`; lint diretto Gradle PASS (`./gradlew lint`) |
| Scoped empty parity probe | PASS | `agent-runs/20260528T193356Z-live-physical-runtime-parity-task-TASK-131-prefix-TASK131_EMPTYPROBE_-profile-linked-p43154.json` |
| Redaction / sensitive / JSON validation | PASS | `agent-runs/20260528T195435Z-scan-task131-redaction-task-TASK-131-strict-p81848.json`, `20260528T195435Z-scan-sensitive-task-TASK-131-docs-TASKS-EVIDENCE-TASK-131-p81849.json`, `20260528T195435Z-report-validate-json-task-TASK-131-path-docs-TASKS-EVIDENCE-TASK-131-agent-runs-p81890.json` |
| Supabase cleanup/residue `TASK131_*` | PASS / residue 0 | Dry-run `20260528T194616Z...p59081.json`, execute `20260528T194630Z...p59648.json`, residue `20260528T194641Z...p60187.json` |

**Evidence non accettata come PASS finale:**

- `physical sync-policy-matrix --prefix TASK131_POLICY_FINAL_` e' stata avviata dopo i fix harness ma interrotta prima della produzione di report Markdown/JSON canonico, perche' l'iPhone fisico doveva essere staccato. Il log temporaneo e' stato eliminato per non conservare artifact incompleti/non redatti. Risultato: `BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_DETACHED_DURING_FULL_MATRIX`, non PASS.
- I report `physical sync-policy-matrix` precedenti con prefisso `TASK131_POLICY_` restano evidence diagnostica/fix-loop: hanno dimostrato propagation parziale e bug harness, ma non soddisfano il gate finale per drift/pending/duplicate/no full pull.
- Conflict/review, offline/background/locked, account switch e accessibility full physical restano `NOT_RUN` o `BLOCKED_EXTERNAL` nel perimetro full physical finche' l'iPhone non viene ricollegato.

**Cleanup e residue:**

- Cleanup Supabase scoped `TASK131_*` completato con dry-run prima di execute e `cleanup_plan_id` obbligatorio.
- Residue Supabase finale per `TASK131_*`: `0`.
- Nessun cleanup globale, nessun `auth.users`, nessun `truncate`, nessuna migration/RLS/grants e nessun service-role client.
- Residui locali iOS/Android `TASK131_*` non vengono dichiarati 0 in questa chiusura interrotta: la verifica locale completa richiede ricollegare i device e completare la matrix/residue locale.

**Criteri bloccati:**

| Criterio P0 | Stato | Motivo |
|---|---|---|
| Full physical sync matrix iPhone <-> Android | BLOCKED_EXTERNAL | iPhone fisico staccato durante il rerun finale. |
| Drift finale Supabase/iPhone/Android = 0 | NOT_RUN_BLOCKING | Richiede matrix full physical conclusa con report canonico. |
| Pending finale = 0 | NOT_RUN_BLOCKING | Richiede matrix full physical conclusa con report canonico. |
| Duplicate ProductPrice finale = 0 | NOT_RUN_BLOCKING | Richiede matrix full physical conclusa con report canonico. |
| Conflict/Review/ProductPrice stale full physical | NOT_RUN_BLOCKING | Richiede device iOS fisico collegato e tap/checklist reali. |
| Offline/reconnect/background/locked full physical | NOT_RUN_BLOCKING | Richiede device iOS fisico collegato; iOS BGTask resta classificabile come scheduler policy se non forzabile. |
| Account switch A/B | BLOCKED_EXTERNAL_SECOND_ACCOUNT oppure NOT_RUN | Serve secondo account test prima di dichiarare PASS. |

**Prossimo passo concreto alla ripresa:**

1. Ricollegare l'iPhone fisico, confermare trust e lasciare Android sbloccato.
2. Rieseguire `physical devices list`, `ios physical sync-policy-ui` e `android physical sync-policy-ui`.
3. Lanciare una nuova matrix con prefisso fresco, per esempio `TASK131_POLICY_RESUME_`, senza riusare il run interrotto.
4. Completare `physical conflict-review-matrix`, `physical offline-background-matrix`, `physical account-switch-matrix` se il secondo account e' disponibile, e `physical accessibility-smoke`.
5. Rieseguire scans finali, cleanup scoped dry-run/execute/residue e JSON validation.

## 23. Execution-resume — 2026-05-28 — iOS physical recovered, Android locked

L'utente ha ricollegato l'iPhone fisico e autorizzato la ripresa. I gate iniziali sono stati rieseguiti con evidence fresca.

**Stato corrente impostato:**

```text
ACTIVE / BLOCKED — ANDROID_PHYSICAL_DEVICE_LOCKED_AFTER_IOS_RESUME
```

**Evidence fresca:**

| Gate | Result | Report |
|---|---:|---|
| `help-json` / `commands-json` resume discovery | PASS | `discovery/04-help-json-resume-full-physical.json`, `discovery/04-commands-json-resume-full-physical.json` |
| `config validate` | PASS | `agent-runs/20260528T205357Z-config-validate-p4143.json` |
| `git head-consistency --task TASK-131` | PASS | `agent-runs/20260528T205357Z-git-head-consistency-task-TASK-131-p4142.json` |
| `preflight --require-head-consistency --task TASK-131` | PASS | `agent-runs/20260528T205403Z-preflight-require-head-consistency-task-TASK-131-p5133.json` |
| `physical devices list --task TASK-131` | PASS | `agent-runs/20260528T205412Z-physical-devices-list-task-TASK-131-p5883.json` |
| `ios physical sync-policy-ui --prefix TASK131_IOS_PHYS_RESUME_` | PASS | `agent-runs/20260528T205420Z-ios-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_IOS_PHYS_RESUME_-p6451.json` |

**Blocco corrente:**

| Gate | Result | Report | Motivo |
|---|---:|---|---|
| `android physical sync-policy-ui --prefix TASK131_ANDROID_PHYS_RESUME_` | BLOCKED_EXTERNAL | `agent-runs/20260528T205547Z-android-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_ANDROID_PHYS_RESUME_-p9101.json` | Android fisico risulta `screenOn: False` / `locked: True`; dopo wake via `adb`, `mDreamingLockscreen=true`. Serve sblocco manuale. |

**Nota safety:** un primo tentativo Android parallelo durante il live lock iOS e' stato rifiutato correttamente dal lock (`agent-runs/20260528T205420Z-android-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_ANDROID_PHYS_RESUME_-p6452.json`). Non e' un bug applicativo.

**Prossimo passo concreto:**

1. Sbloccare manualmente Android fisico e tenerlo awake.
2. Rieseguire `MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh android physical sync-policy-ui --task TASK-131 --prefix TASK131_ANDROID_PHYS_RESUME_`.
3. Se PASS, lanciare `MC_TASK131_ENABLE_IOS_PHYSICAL=1 MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical sync-policy-matrix --task TASK-131 --prefix TASK131_POLICY_RESUME_`.

## 24. Execution-resume — 2026-05-28 — Android ProductPrice FK fix and core physical PASS

Dopo lo sblocco Android successivo alla sezione 23, il gate Android physical readiness e' passato e la matrix full physical e' stata rieseguita. Il primo rerun ha esposto un bug reale Android nel push ProductPrice: righe locali stale `TASK131_*` con `product_remote_refs` puliti ma prodotto remoto mancante causavano errore Supabase/PostgREST `23503` e bloccavano l'intero batch prezzi. Il risultato era assenza di `prices` sync_events Android e mancata propagazione ProductPrice verso iOS.

**Stato corrente impostato:**

```text
ACTIVE / BLOCKED — ANDROID_PHYSICAL_DEVICE_LOCKED_AFTER_CORE_FIX
```

**Fix applicato:**

| File | Modifica |
|---|---|
| Android `InventoryRepository.kt` | `pushProductPricesToRemote` ora isola FK `23503`: prova il batch, poi fallback per-riga, ack solo righe riuscite, lascia pending/stale quelle con FK mancante e continua a emettere sync events validi. |
| Android `DefaultInventoryRepositoryTest.kt` | Aggiunto test regressione `131 quick price push isolates stale product foreign key and emits valid price event`, con fake PostgREST FK violation. |
| iOS repo `tools/agent/lib/ios.sh` | Timeout xcodebuild per matrix live TASK-114/TASK-131, con marker espliciti di timeout invece di hang indefinito. |
| iOS repo `tools/agent/lib/supabase.sh` | Runtime parity fisica ora gestisce `checkpoint: null` senza crash parser JSON. |

**Evidence dopo fix:**

| Gate | Result | Report / nota |
|---|---:|---|
| Android physical readiness dopo unlock | PASS | `agent-runs/20260528T205916Z-android-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_ANDROID_PHYS_RESUME_-p11275.json` |
| Android local cleanup `TASK131_*` dry-run | PASS | `agent-runs/20260528T211500Z-android-cleanup-scoped-prefix-TASK131_-dry-run-p20872.json` |
| Android local cleanup `TASK131_*` execute | PASS | `agent-runs/20260528T211519Z-android-cleanup-scoped-prefix-TASK131_-execute-p21790.json` |
| Android targeted RED/GREEN regression | PASS after fix | `DefaultInventoryRepositoryTest.131 quick price push isolates stale product foreign key and emits valid price event` |
| Android quick/price sync targeted suite | PASS | direct Gradle targeted run after fix |
| Android `assembleDebug lint` | PASS | direct Gradle run after fix |
| `android test sync` wrapper | PASS | `agent-runs/20260528T213405Z-android-test-sync-p39834.json` |
| `android test price-contract --task TASK-131` wrapper | PASS | `agent-runs/20260528T213405Z-android-test-price-contract-task-TASK-131-p39833.json` |
| Full physical `TASK131_POLICY_FIX1_` near-realtime bidirectional Product/ProductPrice/History | PASS | `agent-runs/20260528T211537Z-physical-sync-policy-matrix-task-TASK-131-prefix-TASK131_POLICY_FIX1_-p22695.json`; targeted ProductPrice sync events presenti in entrambe le direzioni, `fullPullUsed: false` |
| Full physical no-op/no full pull | PASS | stesso report `TASK131_POLICY_FIX1_` |
| Full physical burst 10 | FAIL / not accepted | stesso report; iOS XCTest ha hung durante burst ed e' stato terminato manualmente; timeout harness aggiunto, serve rerun |
| Full physical final runtime parity | FAIL / harness parser fixed | stesso report; crash parser su `checkpoint: null` risolto in `supabase.sh`, serve rerun |
| Supabase price schema read-only | PASS | `agent-runs/20260528T213435Z-supabase-contract-price-schema-task-TASK-131-read-only-p41189.json` |
| Supabase grants read-only | PASS | `agent-runs/20260528T213435Z-supabase-verify-grants-task-TASK-131-profile-linked-p41184.json` |
| Supabase RLS read-only | BLOCKED_EXTERNAL | `agent-runs/20260528T213435Z-supabase-verify-rls-task-TASK-131-profile-linked-p41185.json` |
| Supabase schema linked verify | BLOCKED_EXTERNAL / CLI hang | `supabase migration list --linked` non ha prodotto report finale ed e' stato terminato; non PASS |

**Blocco corrente dopo fix:**

| Gate | Result | Report | Motivo |
|---|---:|---|---|
| Android cleanup `TASK131_*` dry-run post-fix | BLOCKED_EXTERNAL | `agent-runs/20260528T213251Z-android-cleanup-scoped-prefix-TASK131_-dry-run-p37691.json`, `agent-runs/20260528T213349Z-android-cleanup-scoped-prefix-TASK131_-dry-run-p39231.json`, `agent-runs/20260528T213747Z-android-cleanup-scoped-prefix-TASK131_-dry-run-p43102.json`, `agent-runs/20260528T214015Z-android-cleanup-scoped-prefix-TASK131_-dry-run-p44041.json`, `agent-runs/20260528T214409Z-android-cleanup-scoped-prefix-TASK131_-dry-run-p46622.json` | Android fisico e' tornato su keyguard/screen-off. Wake e `wm dismiss-keyguard` non rimuovono `isKeyguardShowing=true` / `mInputRestricted=true`; serve sblocco manuale reale e display awake. |

**Gates non ancora accettabili:**

- `physical sync-policy-matrix` non e' ancora PASS finale: core near-realtime e no-op sono PASS, ma burst/parity richiedono rerun con Android unlocked e harness fixato.
- `physical conflict-review-matrix`, `physical offline-background-matrix`, `physical account-switch-matrix` e `physical accessibility-smoke` restano `NOT_RUN`/blocked in questo resume.
- Drift finale 0, pending finale 0 e duplicate ProductPrice 0 non vengono dichiarati finche' la matrix finale e il cleanup/residue non passano.
- Nessun claim `REVIEW`, `DONE`, production-ready globale o full physical acceptance.

**Prossimo passo concreto:**

1. Sbloccare fisicamente il OnePlus e mantenerlo awake.
2. Rerun locale cleanup Android scoped:
   `MC_ANDROID_DEVICE_SERIAL=<REDACTED_SERIAL> ./tools/agent/mc-agent.sh android cleanup-scoped --prefix TASK131_ --dry-run`
3. Se dry-run PASS:
   `MC_ANDROID_DEVICE_SERIAL=<REDACTED_SERIAL> MC_ALLOW_CLEANUP=1 ./tools/agent/mc-agent.sh android cleanup-scoped --prefix TASK131_ --execute`
4. Rilanciare la matrix con prefisso fresco:
   `MC_ANDROID_DEVICE_SERIAL=<REDACTED_SERIAL> MC_TASK131_ENABLE_IOS_PHYSICAL=1 MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical sync-policy-matrix --task TASK-131 --prefix TASK131_POLICY_FIX2_`

## 25. Execution-completion — 2026-05-29 — full physical core PASS, non-B account policy PASS, mandatory operator evidence blocked

L'Execution e' stata ripresa con iPhone fisico e Android fisico disponibili. I gate runtime disponibili sono stati rieseguiti con report canonici Markdown/JSON schema 1.1, prefissi `TASK131_*`, redaction attiva e cleanup scoped. Questa sezione supersede i blocchi intermedi delle sezioni 23-24 dove i rerun erano ancora incompleti.

**Stato finale impostato:**

```text
ACTIVE / BLOCKED — PHYSICAL_REVIEW_ACCESSIBILITY_OPERATOR_EVIDENCE_REQUIRED
```

**Scope effettivo:**

- `FULL_PHYSICAL_IOS_ANDROID_SCOPE` per device readiness, sync matrix, offline/reconnect/restart/flap e cleanup.
- Conflict/Review fisico: policy/UI contract PASS, ma manca checklist tap fisica/operator-assisted.
- Accessibility fisica: preflight iPhone/Android PASS, ma manca checklist VoiceOver/TalkBack operator-assisted.
- Account switch: wrapper split completato; same-account logout/login, token/session fail-closed, owner mismatch fixture, legacy/unbound dirty Review/Recovery, export-before-discard/cancel e localDefaultStoreOnly PASS senza account B. Solo i veri casi A->B C126-14/15/16/17/40 restano `BLOCKED_EXTERNAL_SECOND_ACCOUNT` e non sono PASS.
- iOS BGTask scheduler: solo sotto-caso `BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY`; non trasformato in PASS tecnico.

**Fix reali applicati durante Execution:**

| Area | File | Root cause / fix |
|---|---|---|
| iOS ProductPrice sync events | `SyncEventOutboxEnqueueService.swift`, `SupabaseManualSyncOutboxProducerConversions.swift`, `SupabaseManualSyncReleaseFactory.swift`, `CatalogGeneratedProductPriceSyncEventRecorder.swift` | Le righe ProductPrice generate dal catalogo non emettevano sempre eventi coerenti nel path matrix; aggiunto recorder dedicato e test mirati. |
| Android ProductPrice FK isolation | Android `InventoryRepository.kt`, `DefaultInventoryRepositoryTest.kt` | Una FK `23503` su ProductPrice stale bloccava il batch e impediva eventi validi; ora fallback per-riga, ack solo per righe scritte e regressione JVM. |
| Supabase scoped counts | `tools/agent/lib/supabase.sh` | I conteggi scoped includevano prodotti tombstoned; il filtro ora usa righe attive dove necessario. |
| Offline/restart/flap harness | `tools/agent/lib/supabase.sh` | Prefissi riusati contaminavano store locale/remote fixture tra subcase; ora ogni mode usa prefisso unico. |
| TASK-131 matrix JSON | `tools/agent/lib/task131_physical.sh` | Bug Bash su `${detail:-{}}` produceva JSON con graffa extra; corretto e aggiunto fallback parse. |
| Account-switch split | `tools/agent/lib/task131_physical.sh`, `tools/agent/lib/ios.sh`, `tools/agent/lib/android.sh`, `tools/agent/README.md` | Il vecchio wrapper bloccava tutta la matrix senza account B; ora divide same-account, auth fail-closed, owner mismatch, legacy/unbound dirty, export/cancel e localDefaultStoreOnly dai soli casi A->B. |
| Final scanner | `tools/agent/lib/task131_scans.py` | Gate aggiornati dal vecchio scope hybrid al full physical scope e ai blocker esterni ammessi solo se documentati. |

**Evidence PASS full physical / safety:**

| Gate | Result | Evidence |
|---|---:|---|
| Device discovery | PASS | `agent-runs/20260529T011315Z-physical-devices-list-task-TASK-131-p18223.json` |
| iOS physical Options/auth/launch smoke | PASS | `agent-runs/20260528T233735Z-ios-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_IOS_PHYS_RESUME7_-p7604.json` |
| Android physical Options/auth/launch smoke | PASS | `agent-runs/20260528T233201Z-android-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_ANDROID_PHYS_RESUME2_-p99950.json` |
| Full physical sync matrix | PASS | `agent-runs/20260529T013114Z-physical-sync-policy-matrix-task-TASK-131-prefix-TASK131_POLICY_FIX9_-p39908.json` |
| Offline/reconnect/restart/flap matrix | PASS | `agent-runs/20260529T014751Z-physical-offline-background-matrix-task-TASK-131-prefix-TASK131_OFFLINE_FIX6_-p63716.json` |
| iOS build debug/release/sync/price-contract | PASS | `agent-runs/20260529T020113Z-ios-test-price-contract-task-TASK-131-p83470.json` plus latest build/test reports in `agent-runs/` |
| Android build debug/sync/price-contract | PASS | `agent-runs/20260529T020036Z-android-build-debug-p81532.json`, `20260529T020052Z-android-test-sync-p82137.json`, `20260529T020104Z-android-test-price-contract-task-TASK-131-p82807.json` |
| Supabase schema/RLS/grants/RPC/realtime/price read-only | PASS | `agent-runs/20260529T020159Z...` through `20260529T020233Z...` |
| No full pull normal path | PASS | `agent-runs/20260529T020548Z-scan-no-full-pull-normal-path-task-TASK-131-strict-p93816.json` |
| No cross-owner/store pending push | PASS | `agent-runs/20260529T020548Z-scan-no-cross-owner-store-pending-push-task-TASK-131-strict-p93828.json` |
| No service-role client | PASS | `agent-runs/20260529T020548Z-scan-no-service-role-client-task-TASK-131-strict-p93827.json` |
| No RLS bypass | PASS | `agent-runs/20260529T020824Z-scan-no-rls-bypass-task-TASK-131-strict-p95752.json` |
| Sensitive/evidence/JSON validation | PASS | `agent-runs/20260529T020824Z-scan-sensitive-task-TASK-131-docs-TASKS-EVIDENCE-TASK-131-p95753.json`, `20260529T021033Z-scan-evidence-task-TASK-131-p69426.json`, `20260529T020824Z-report-validate-json-task-TASK-131-path-docs-TASKS-EVIDENCE-TASK-131-agent-runs-p95758.json` |
| Supabase cleanup/residue `TASK131_*` | PASS / residue 0 | dry-run `20260529T020421Z...p89944.json`, execute `20260529T020431Z...p90491.json`, residue `20260529T020442Z...p91020.json` |
| Android local cleanup `TASK131_*` | PASS | dry-run `20260529T020502Z...p91589.json`, execute `20260529T020521Z...p92471.json` |
| Account-switch non-B policy split | PASS per sotto-casi senza account B; C126-14/15/16/17/40 `BLOCKED_EXTERNAL_SECOND_ACCOUNT` | `agent-runs/20260529T022420Z-physical-account-switch-matrix-task-TASK-131-prefix-TASK131_ACCOUNT_SPLIT2_-p50384.json` |
| Final scans post account split | PASS | final gates `20260529T023314Z-scan-task131-final-gates-task-TASK-131-strict-p13839.json`, sensitive `20260529T023314Z-scan-sensitive-task-TASK-131-docs-TASKS-EVIDENCE-TASK-131-p13847.json`, evidence `20260529T023314Z-scan-evidence-task-TASK-131-p13860.json`, JSON validation `20260529T023314Z-report-validate-json-task-TASK-131-path-docs-TASKS-EVIDENCE-TASK-131-agent-runs-p13836.json` |
| Supabase cleanup/residue `TASK131_*` post account split | PASS / residue 0 | dry-run `20260529T022610Z...p54450.json`, execute `20260529T022628Z...p55016.json`, residue `20260529T022634Z...p55005.json` |

**Invarianti dimostrate dal report full physical `TASK131_POLICY_FIX9_`:**

| Invariante | Stato |
|---|---:|
| iPhone physical -> Android physical product/ProductPrice/history propagation | PASS |
| Android physical -> iPhone physical product/ProductPrice/history propagation | PASS |
| No-op sync senza full pull | PASS |
| Burst 10 senza duplicati | PASS |
| Drift finale Supabase/iPhone/Android | PASS / 0 |
| Pending finale aggregati | PASS / 0 |
| Duplicate ProductPrice keys | PASS / 0 |
| Normal path incremental, no full pull | PASS |
| Logout/login stesso account con cache/pending/cursor preservati | PASS |
| Token expired/session missing fail-closed | PASS |
| Owner mismatch fail-closed e no cross-owner/store pending push fixture | PASS |
| Legacy/unbound local store dirty -> Review/Recovery, no silent cloud upload | PASS |
| Export before discard / cancel non distruttivo con pending dirty locali | PASS |
| localDefaultStoreOnly: nessuno `store_id` remoto inventato e nessuna promessa UI multi-store cloud | PASS |

**Blocker non convertiti in PASS:**

| Gate | Stato | Evidence / next action |
|---|---:|---|
| Physical Conflict/Review tap evidence | BLOCKED_EXTERNAL | `agent-runs/20260529T013030Z-physical-conflict-review-matrix-task-TASK-131-prefix-TASK131_CONFLICT_FIX6_-p38740.json`; serve `MC_TASK131_CONFLICT_REVIEW_CHECKLIST_JSON` o automazione UI fisica affidabile. |
| Physical VoiceOver/TalkBack traversal | BLOCKED_EXTERNAL | `agent-runs/20260529T015938Z-physical-accessibility-smoke-task-TASK-131-p80272.json`; serve checklist operator-assisted redatta o automazione equivalente. |
| Account switch A/B C126-14/15/16/17/40 | BLOCKED_EXTERNAL_SECOND_ACCOUNT | `agent-runs/20260529T022420Z-physical-account-switch-matrix-task-TASK-131-prefix-TASK131_ACCOUNT_SPLIT2_-p50384.json`; solo i veri casi A->B richiedono secondo account test sintetico. I sotto-casi same-account/local fixture sono PASS nello stesso report. |
| iOS background scheduler | BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY | Sotto-caso in `TASK131_OFFLINE_FIX6_`; OS scheduler non forzato dal tooling, nessun PASS tecnico dichiarato. |
| iOS local residue 0 | NOT_DECLARED | `ios cleanup-scoped --prefix TASK131_ --dry-run` PASS (`20260529T020539Z...p93364.json`), ma wrapper non esegue cleanup locale fisico completo; nessun residue 0 locale iOS dichiarato. |

**Chiusura Execution corrente:**

- `DONE` vietato: manca review indipendente e accettazione esplicita utente.
- `REVIEW` full acceptance vietato: Conflict/Review physical tap evidence e accessibility traversal sono P0/UX mandatory e restano bloccati da evidence operator-assisted mancante.
- Nessun claim production-ready globale.
- Prossimo passo concreto: fornire checklist/automazione fisica per Conflict/Review e VoiceOver/TalkBack; poi rerun `physical conflict-review-matrix`, `physical accessibility-smoke`, `scan task131-final-gates`, cleanup/residue se vengono creati nuovi dati live. Quando sara' disponibile un secondo account sintetico, rerun solo i sotto-casi A->B C126-14/15/16/17/40.

## 26. Review Codex — 2026-05-29 — blocker-aware review con fix diretti, non promossa a REVIEW

**User override documentato:** l'utente ha richiesto una REVIEW severa repo-grounded con correzione diretta di bug/fragilita' reali, pur con il workflow standard che assegna la review a Claude. Codex ha operato come reviewer/fixer solo dentro TASK-131, senza dichiarare DONE, production-ready globale o full multi-account/accessibility PASS.

**Stato finale mantenuto:**

```text
ACTIVE / BLOCKED — PHYSICAL_REVIEW_ACCESSIBILITY_OPERATOR_EVIDENCE_REQUIRED
```

**Verdict review:** core full physical data path confermato PASS tramite evidence esistente e rerun mirati; TASK-131 non e' promuovibile a REVIEW piena perche' Conflict/Review tap fisici e VoiceOver/TalkBack restano privi di evidence operator-assisted. I casi Account A->B restano solo case-level `BLOCKED_EXTERNAL_SECOND_ACCOUNT`.

**Bug / fragilita' trovati e corretti durante review:**

| Area | Root cause | Fix applicato |
|---|---|---|
| Evidence privacy/redaction | Alcuni report TASK-131 contenevano nomi device, modelli, seriali o identificatori fisici raw in log/evidence legacy. | Rafforzata redaction in `tools/agent/lib/redact.sh`, `ios.sh`, `android.sh`, `task131_physical.sh`, `task131_scans.py`; evidence TASK-131 legacy redatte; scan redaction/sensitive PASS. |
| Android ProductPrice log privacy | Il fallback ProductPrice FK stale loggava identificativi prodotto/prezzo/remoti raw. | `InventoryRepository.kt` ora logga solo il motivo tecnico redatto senza ID. |
| Supabase verify-schema hang | `supabase migration list --linked` poteva restare appeso senza report finale. | `tools/agent/lib/supabase.sh` ora usa timeout CLI configurabile per `verify-schema`; rerun linked schema PASS con report tracciato. |
| TASK-131 matrix blocked classifier | Lo summary riconosceva solo `BLOCKED`/`BLOCKED_EXTERNAL`, non status specifici come `BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY`. | Classificazione allargata a tutti gli status `BLOCKED*`, senza trasformarli in PASS non documentati. |
| Accessibility harness classification | In assenza di live allowance/checklist, lo smoke poteva uscire `FAIL` e riusare detail JSON stale tra step. | Step detail isolato, status `MISCONFIGURED`/`UNSAFE_OPERATION_REFUSED` distinti, rerun con live esplicito produce `BLOCKED_EXTERNAL` corretto per checklist mancante. |
| Operator evidence assente | Mancava un artifact esplicito che definisse la checklist minima Review/Accessibility. | Creati `operator-review-accessibility-checklist.md/json` con casi `NOT_RUN` e blocker `BLOCKED_EXTERNAL_OPERATOR_EVIDENCE_REQUIRED`. |

**Rerun review principali:**

| Gate | Stato | Evidence |
|---|---:|---|
| Preflight/head/config | PASS | `20260529T024134Z-config-validate-p25676.json`, `20260529T024137Z-git-head-consistency-task-TASK-131-p26176.json`, `20260529T024147Z-preflight-require-head-consistency-task-TASK-131-p26910.json` |
| iOS build Debug/Release | PASS | `20260529T025228Z-ios-build-debug-p64924.json`, `20260529T025314Z-ios-build-release-p66007.json` |
| iOS sync/price/task131-harness tests | PASS | `20260529T025429Z-ios-test-sync-p67035.json`, `20260529T025727Z-ios-test-price-contract-task-TASK-131-p68839.json`, `20260529T025759Z-ios-test-task131-harness-task-TASK-131-p70889.json` |
| Android targeted repo tests | PASS | `DefaultInventoryRepositoryTest`, `HistorySessionPushCoordinatorTest` via Gradle/JBR |
| Android wrapper build/sync/price | PASS | `20260529T025429Z-android-build-debug-p67034.json`, `20260529T025727Z-android-test-sync-p68840.json`, `20260529T025748Z-android-test-price-contract-task-TASK-131-p70162.json` |
| Supabase linked schema/RLS/grants/RPC/realtime/price | PASS | `20260529T030122Z-supabase-verify-schema-task-TASK-131-profile-linked-p75527.json`, `20260529T030138Z-supabase-verify-rls-task-TASK-131-profile-linked-p76230.json`, grants/RPC/price `20260529T025817Z...`, realtime `20260529T030150Z...` |
| Account-switch split rerun | PASS blocker-aware | `20260529T030217Z-physical-account-switch-matrix-task-TASK-131-prefix-TASK131_REVIEW_ACCOUNT_-p77663.json`; A->B solo case-level `BLOCKED_EXTERNAL_SECOND_ACCOUNT`. |
| Conflict/Review rerun | BLOCKED_EXTERNAL | `20260529T030338Z-physical-conflict-review-matrix-task-TASK-131-prefix-TASK131_REVIEW_CONFLICT_-p80048.json`; policy/UI PASS, checklist tap mancante. |
| Accessibility rerun | BLOCKED_EXTERNAL | `20260529T030624Z-physical-accessibility-smoke-task-TASK-131-p83429.json`; iOS/Android preflight PASS, checklist VoiceOver/TalkBack mancante. |
| Supabase cleanup/residue `TASK131_` | PASS / residue 0 | dry-run `20260529T030703Z...p84875.json`, execute `20260529T030727Z...p85615.json`, residue `20260529T030737Z...p86323.json` |
| Android cleanup `TASK131_` | PASS | dry-run `20260529T030748Z...p87037.json`, execute `20260529T030803Z...p88057.json` |
| Security/redaction/evidence scans | PASS after fix | redaction `20260529T030827Z...p89115.json`, sensitive `20260529T030827Z...p89114.json`, evidence rerun `20260529T030953Z...p61898.json`, no-service-role `20260529T030937Z...p60614.json`, no-RLS-bypass `20260529T030939Z...p60613.json` |

**Rischi / blocker rimasti:**

- `OPERATOR_CONFLICT_REVIEW_CHECKLIST_NOT_PROVIDED`: serve checklist fisica redatta o automazione affidabile per Review CTA, cancel, destructive confirmation, same-field/delete-vs-edit/ProductPrice stale review.
- `OPERATOR_ACCESSIBILITY_CHECKLIST_NOT_PROVIDED`: serve checklist VoiceOver/TalkBack/Dynamic Type/font scale redatta.
- `BLOCKED_EXTERNAL_SECOND_ACCOUNT`: solo per C126-14/15/16/17/40 con secondo account sintetico.
- `BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY`: BGTask scheduler iOS non forzato dal tooling; non dichiarato PASS tecnico.
- iOS local cleanup resta dry-run/support-only; nessun claim residue 0 locale iOS.

**Handoff verso prossimo reviewer/operatore:**

Non promuovere a REVIEW/DONE finche' non arrivano le checklist/automazioni operator-assisted mancanti. Prossimo passo concreto: compilare `docs/TASKS/EVIDENCE/TASK-131/operator-review-accessibility-checklist.md/json` con evidenze redatte, poi rerun `physical conflict-review-matrix`, `physical accessibility-smoke`, `scan task131-final-gates`, `report validate-json`, `scan sensitive` e cleanup/residue se vengono creati nuovi dati live.
