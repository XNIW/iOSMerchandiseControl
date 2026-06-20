# TASK-136: iOS Sync Shop-Scope Reconciliation + Source-of-Truth Audit

## Informazioni generali
- **Task ID**: TASK-136
- **Titolo**: iOS Sync Shop-Scope Reconciliation + Source-of-Truth Audit
- **File task**: `docs/TASKS/TASK-136-ios-sync-shop-scope-reconciliation-source-of-truth-audit.md`
- **Stato**: ACTIVE
- **Fase attuale**: REVIEW
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-06-20
- **Ultimo aggiornamento**: 2026-06-20 16:35 -0400
- **Ultimo agente che ha operato**: CODEX

## Dipendenze
- **Dipende da**: TASK-135 chiuso come baseline storica; user override esplicito del 2026-06-20 apre questo nuovo task operativo.
- **Sblocca**: Chiusura reale della divergenza Admin Web / Android / iOS / Supabase sullo stesso account, shop e source.

## Scopo
Determinare la fonte di verita' runtime per la divergenza attuale fra Admin Web/Android (~11 prodotti) e iOS (~19710 prodotti), distinguendo fra shop-scope intenzionale e owner-scope legacy. Applicare poi il fix minimo sul lato realmente incoerente, senza distruggere dati cloud reali e senza usare reset manuale del simulatore come soluzione finale.

## Contesto
TASK-135 ha chiuso e accettato come baseline il dataset grande owner-scoped (~19704 prodotti attivi, 66 fornitori, 35 categorie, 41131 price rows). Il 2026-06-20 l'utente ha fornito un override esplicito: non fermarsi su MASTER-PLAN IDLE/TASK-135 DONE, creare un nuovo TAC/TASK-136 se necessario, eseguire prima un source-of-truth audit e poi correggere in base al caso reale.

## Non incluso
- Commit o push Git senza richiesta esplicita.
- Cancellazione distruttiva di dati cloud reali.
- Reset manuale del simulatore/emulatore come soluzione finale.
- Mascherare la divergenza tramite filtri UI senza dimostrare il runtime/env/shop effettivo.
- Dichiarare DONE se Admin Web, Android, iOS e Supabase non convergono nello stesso scope provato.

## File potenzialmente coinvolti
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-136-ios-sync-shop-scope-reconciliation-source-of-truth-audit.md`
- `docs/TASKS/EVIDENCE/TASK-136/`
- `iOSMerchandiseControl/Sync/Remote/*.swift`
- `iOSMerchandiseControl/Sync/Recovery/*.swift`
- `iOSMerchandiseControl/Sync/Automatic/**/*.swift`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `tools/agent/**/*.sh`
- Admin Web runtime/read-model/mutation files under `/Users/minxiang/Projects/merchandise-control-admin-web`
- Android runtime/local sync files under `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

## Criteri di accettazione
Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.
- [ ] **CA-136-1 Source-of-truth audit**: produrre una tabella redatta ma confrontabile per Admin Web runtime, Android runtime, iOS runtime e Supabase direct con project ref, shop hash, owner hash, mapping/source, products, suppliers, categories, price history, history sessions, active/deleted/archive/tombstone.
- [ ] **CA-136-2 Runtime reale**: verificare runtime/env effettivi, non solo file `.env` o plist statici, includendo browser/Admin, app Android installata e app iOS installata.
- [ ] **CA-136-3 Caso reale deciso**: classificare esplicitamente CASO A (shop corretto da ~11, iOS over-scoped) oppure CASO B (catalogo corretto da ~19704, Admin/Android filtrano o puntano a runtime/shop errato), con evidenza.
- [ ] **CA-136-4 Fix minimo in base al caso**: applicare solo le modifiche necessarie sul lato incoerente, senza nuove dipendenze non richieste, senza refactor opportunistici e senza modifiche distruttive cloud.
- [ ] **CA-136-5 Convergenza conteggi**: dimostrare prima/dopo conteggi Admin Web, Android, iOS e Supabase sullo stesso account/shop/source.
- [ ] **CA-136-6 Test create/update/delete catalogo**: verificare create, update e archive/delete/tombstone Admin Web -> Android/iOS e iOS -> Android/Admin Web.
- [ ] **CA-136-7 Fornitori/categorie**: verificare create/update/delete o archive, inclusi prodotti collegati e lookup/fallback coerenti.
- [ ] **CA-136-8 Price history**: verificare update prezzo, nuova riga storico e conteggio coerente sui lati coinvolti.
- [ ] **CA-136-9 History entries**: verificare lista, dettaglio, conteggio e create/import/delete/archive/tombstone se supportati nello scope.
- [ ] **CA-136-10 Build/test/check finali**: eseguire iOS `xcodebuild`, Android Gradle build/test se Android coinvolto, Admin npm verify/typecheck/lint/build se Admin coinvolto, `git diff --check` e `git status`.
- [ ] **CA-136-11 Evidence completa**: salvare evidenza e report finale in `docs/TASKS/EVIDENCE/TASK-136/`.
- [ ] **CA-136-12 Nessun DONE improprio**: dichiarare DONE solo se i tre lati convergono nello stesso scope senza reset manuale; altrimenti documentare stato, blocco o rischi residui reali.

## Test case obbligatori
| Test | Tipo | Descrizione |
|------|------|-------------|
| T-136-01 | STATIC/RUNTIME | Admin Web runtime/source dump: URL, project ref, selected workspace, shop/source/mapping e query conteggi. |
| T-136-02 | RUNTIME | Android runtime dump: account, project/env, shop/source/mapping se presenti, last sync, pending outbox, conteggi locali/cloud. |
| T-136-03 | RUNTIME/SIM | iOS runtime dump: account, project/env bundlato installato, owner, shop/source se presenti, watermark, pending, conteggi locali/remoti. |
| T-136-04 | RUNTIME | Supabase scoped counts per shop_id, owner_user_id, legacy `shop_id IS NULL`, deleted/archive/tombstone e mapping. |
| T-136-05 | RUNTIME | Decisione CASO A/CASO B con tabella comparativa. |
| T-136-06 | BUILD/STATIC/RUNTIME | Fix applicato e verificato nel lato coerente col caso reale. |
| T-136-07 | BROWSER/EMULATOR/SIM | Admin create product -> Android/iOS convergono. |
| T-136-08 | BROWSER/EMULATOR/SIM | Admin update name/price/quantity -> Android/iOS convergono. |
| T-136-09 | BROWSER/EMULATOR/SIM | Admin archive/delete/tombstone -> Android/iOS convergono. |
| T-136-10 | SIM/BROWSER/EMULATOR | iOS create product -> Admin/Android convergono. |
| T-136-11 | SIM/BROWSER/EMULATOR | iOS update product -> Admin/Android convergono. |
| T-136-12 | SIM/BROWSER/EMULATOR | iOS delete/archive -> Admin/Android convergono. |
| T-136-13 | BROWSER/EMULATOR/SIM | Supplier/category create/update/delete/archive e prodotti collegati coerenti. |
| T-136-14 | BROWSER/EMULATOR/SIM | Price update produce nuova price-history row e conteggi coerenti. |
| T-136-15 | BROWSER/EMULATOR/SIM | History entries lista/dettaglio/conteggio e mutate supportate coerenti. |

## Decisioni
Decisioni superate o cambiate non vanno cancellate: marcarle come OBSOLETA con nota esplicita.
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | User override apre TASK-136 direttamente in EXECUTION a Codex. | Fermarsi su MASTER-PLAN IDLE / TASK-135 DONE. | L'utente ha esplicitamente autorizzato nuovo TAC operativo e modifiche locali. | attiva |
| 2 | FASE 1 obbligatoria prima del fix. | Patchare subito iOS come se fosse sicuramente sbagliato. | La divergenza puo' essere CASO A o CASO B; serve runtime source-of-truth. | attiva |

---

## Planning (Claude) <- solo Claude aggiorna questa sezione

### Nota di override
Non c'e' planning Claude per TASK-136 al momento della creazione. L'utente ha fornito un override operativo esplicito e un handoff diretto a Codex per aprire TASK-136 in EXECUTION.

### Handoff -> Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: eseguire prima la FASE 1 source-of-truth audit; non patchare finche' CASO A/CASO B non e' provato.

---

## Execution (Codex) <- solo Codex aggiorna questa sezione

### Obiettivo compreso
Stabilire lo scope reale Admin/Android/iOS/Supabase e chiudere i tre nodi finali richiesti dall'utente: Admin Products exact total non indefinito, iOS sync state non infinito, History Entries con definizione unica mobile-visible.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/CODEX-EXECUTION-PROTOCOL.md`
- `docs/TASKS/TASK-TEMPLATE.md`
- `/Users/minxiang/.codex/attachments/02439f0c-6173-4c84-8d77-3ac7d9f340b2/pasted-text.txt`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift`
- `iOSMerchandiseControl/Sync/Automatic/Presentation/SyncStateStore.swift`
- `iOSMerchandiseControl/Sync/Recovery/SupabasePullApplyService.swift`
- `iOSMerchandiseControlTests/Task118AutomaticDomainTests.swift`
- `iOSMerchandiseControlTests/Task119AutomaticArchitectureTests.swift`
- `iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests.swift`
- `/Users/minxiang/Projects/merchandise-control-admin-web/src/app/shop/products/page.tsx`
- `/Users/minxiang/Projects/merchandise-control-admin-web/src/app/shop/history/page.tsx`
- `/Users/minxiang/Projects/merchandise-control-admin-web/src/app/shop/_components/HistoryEntriesClientList.tsx`
- `/Users/minxiang/Projects/merchandise-control-admin-web/src/server/shop-admin/history-read-model.ts`
- `/Users/minxiang/Projects/merchandise-control-admin-web/src/server/shop-admin/shop-section-data.ts`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/MerchandiseControlApplication.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/CatalogAutoSyncCoordinator.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/androidTest/java/com/example/merchandisecontrolsplitview/Task103CrossPlatformAcceptanceTest.kt`
- `tools/task136/*.mjs`
- `docs/TASKS/EVIDENCE/TASK-136/**`

### Piano minimo
1. Non riaprire FASE 1 completa; usare le evidenze runtime gia' raccolte per chiudere i nodi finali.
2. Admin Products: separare exact total server-side dalla paginazione e provarlo in browser.
3. iOS: impedire stato automatico "in corso" persistente e distinguere catalogo locale allineato da eventi cloud incompleti.
4. History: rendere Admin esplicito su total/active/deleted/mobile-visible e spiegare 45 -> 41.
5. Rieseguire build/check finali e aggiornare evidence.
6. Non dichiarare DONE se la matrice create/update/delete cross-platform resta incompleta.

### Modifiche fatte
- Creato e popolato `docs/TASKS/EVIDENCE/TASK-136/`.
- Decisione scope: CASO B / mapped owner mobile catalog. Admin direct shop non e' la fonte mobile completa; Admin Products usa legacy mobile bridge/mapped owner.
- Admin Products: exact total e filtered exact total server-side separati dalla pagina da 10 righe; range visibile `1-10 of 19,710`; search dichiarata server-side; lower bound `11+` separato dal totale.
- Admin History: light list portata a 200 righe, summary exact quando disponibile, metriche `History entries 126`, `Active 45`, `Deleted 81`, `Mobile visible 41`; default list mobile-visible filtra le 4 righe tecniche attive.
- Admin History: corretto anche il titolo mese client/server con locale deterministico per evitare hydration mismatch `June 2026` / `giugno 2026`.
- iOS: `SyncStateStore` idrata stato/outcome persistiti, non ripristina phase active vecchie al relaunch, non promuove `noWork` decisionale a last verified success e pulisce error/block stale; `AutomaticSyncEngine` considera un drain cloud completato senza delta come success verificato; Options mostra diagnostica cloud-events incomplete con catalogo locale allineato.
- iOS recovery: full replacement catalogo non cancella piu' distruttivamente ProductPrice per prodotti mantenuti nel remote snapshot.
- Android: runtime bootstrap/drain dopo device active e busy drain queue gia' sbloccati; whitelist test live aggiornata per prefisso `TASK136_`.
- Live mutation matrix tentata con prefisso `TASK136_MATRIX_RT_20260620T201103Z_`: iOS write matrix PASS e Android ricezione delta iOS PASS; Android write matrix FAIL per timeout push auto entro 35s. Residui remoti e Android locali del prefisso ripuliti e residue-check PASS.

### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [x] Build compila: ✅ ESEGUITO — iOS `build_run_sim` PASS senza warning MCP; Android `./gradlew assembleDebug --console=plain` PASS; Admin `npm run verify` PASS.
- [x] Nessun warning nuovo: ✅ ESEGUITO — iOS build MCP warning 0; Admin build mostra solo warning tooling/deprecation Next middleware e Node `module.register()`; Android assembleDebug senza warning nuovi riportati.
- [x] Modifiche coerenti con planning: ✅ ESEGUITO — fix limitati ai nodi scope/Admin/iOS/Android runtime richiesti, senza cancellazione cloud distruttiva e senza reset manuale come soluzione.
- [x] Criteri di accettazione verificati: ✅ ESEGUITO — esito REVIEW/PASS_WITH_NOTES, non DONE: CA scope/conteggi/build/evidence coperti; CA create/update/delete cross-platform non pienamente chiusa per failure Android write matrix.
- [x] Admin exact total: ✅ ESEGUITO — screenshot `docs/TASKS/EVIDENCE/TASK-136/screenshots/admin-products-page1-exact-total.png` mostra `1-10 of 19,710`, `Exact total 19,710`, `Filtered exact total 19,710`, `Search scope Server-side`.
- [x] iOS sync state: ✅ ESEGUITO — screenshot `docs/TASKS/EVIDENCE/TASK-136/screenshots/ios-options-sync-state-final-expanded-20260620T2025.jpg` mostra phase `Completata`, last progress, last verified success, device `active / can write`, error redatto e cloud events incomplete con catalogo locale allineato.
- [x] Android restart Room counts: ✅ ESEGUITO — app force-stop/launch, `sync counts --source android` PASS, copia Room main+WAL+SHM in `docs/TASKS/EVIDENCE/TASK-136/live-audit/android-room-after-restart-20260620T2029/`, conteggi `19710/70/39/41137`, History mobile visible `41`.
- [x] iOS runtime counts: ✅ ESEGUITO — `sync counts --source ios` PASS, report `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T203108Z-sync-counts-task-TASK-136-source-ios-p48127.json`, conteggi `19710/70/39/41137`, History userVisible `41`.
- [x] Supabase scoped audit: ✅ ESEGUITO — `docs/TASKS/EVIDENCE/TASK-136/live-audit/supabase-scope-audit-final-20260620T2032.json` conferma mapped owner `19710/70/39`, direct selected shop non e' lo scope mobile completo.
- [x] History Entries definition: ✅ ESEGUITO — Admin screenshot `admin-history-post-history-fix-localhost-window.png` mostra `126/45/81/mobile visible 41`; row-level diff `history-visible-only-diff-post-fix.md` conferma Admin/Android/iOS/Supabase visible-only parity 41.
- [x] Test mirati iOS: ✅ ESEGUITO — XcodeBuildMCP `test_sim` PASS 4/4 per `SyncStateStore` hydration/noWork e `AutomaticSyncEngine` no-change drain.
- [x] Localizzazioni: ✅ ESEGUITO — `plutil -lint` PASS per EN/IT/ES/ZH.
- [x] `git diff --check`: ✅ ESEGUITO — PASS su iOS repo, Admin Web repo e Android repo.
- [x] `git status`: ✅ ESEGUITO — raccolto su iOS/Admin/Android; worktree gia' dirty con molte modifiche/evidence non tutte introdotte in questo ultimo pass.

### Rischi rimasti
- NOT DONE tecnico: live create/update/delete cross-platform non e' completamente verde. Il gate `live mutation near realtime` ha fallito nel segmento Android write matrix per timeout push auto entro 35s.
- Il count Supabase globale/unscoped include righe fuori scope e non va usato per parity mobile; usare solo scoped audit mapped owner/direct shop.
- Safari automation finale non e' riuscita a riaprire localhost e una cattura errata ChatGPT/start-page e' stata rimossa; la prova Admin Products valida resta la screenshot browser gia' salvata dopo patch.
- Repo iOS/Admin/Android restano dirty con modifiche ed evidence preesistenti; nessun commit/push richiesto o fatto.

### Handoff -> Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: review finale PASS_WITH_NOTES / NOT DONE. Verificare che Admin exact total e iOS sync state siano accettabili; non marcare DONE finche' la matrice create/update/delete cross-platform Android write non viene chiusa o esplicitamente accettata come nota.

---

## Review (Claude) <- solo Claude aggiorna questa sezione

### Problemi critici
Da compilare.

### Problemi medi
Da compilare.

### Miglioramenti opzionali
Da compilare.

### Fix richiesti
- [ ] Da compilare.

### Esito
Esito: [APPROVED | CHANGES_REQUIRED | REJECTED]

### Handoff -> Fix (se CHANGES_REQUIRED)
- **Prossima fase**: FIX
- **Prossimo agente**: CODEX
- **Azione consigliata**: da compilare.

### Handoff -> nuovo Planning (se REJECTED)
- **Prossima fase**: PLANNING
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: da compilare.

---

## Fix (Codex) <- solo Codex aggiorna questa sezione

### Fix applicati
- [ ] Da compilare.

### Check post-fix
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [ ] Build compila: ❌ NON ESEGUITO
- [ ] Fix coerenti con review: ❌ NON ESEGUITO
- [ ] Criteri di accettazione ancora soddisfatti: ❌ NON ESEGUITO

### Handoff -> Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare i fix applicati.

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento.

### Follow-up candidate
Da compilare.

### Riepilogo finale
Da compilare.

### Data completamento
N/A
