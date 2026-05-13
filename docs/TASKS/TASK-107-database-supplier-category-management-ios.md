# TASK-107: Database supplier/category management iOS

## Informazioni generali
- **Task ID**: TASK-107
- **Titolo**: Database supplier/category management iOS
- **File task**: `docs/TASKS/TASK-107-database-supplier-category-management-ios.md`
- **Stato**: DONE
- **Fase attuale**: CHIUSURA
- **Responsabile attuale**: OWNER / USER
- **Data creazione**: 2026-05-13
- **Ultimo aggiornamento**: 2026-05-13
- **Ultimo agente che ha operato**: CODEX_REVIEW

## User override
- L'utente ha richiesto esplicitamente di implementare subito la gestione Fornitori/Categorie nella schermata Database iOS, prendendo Android solo come riferimento funzionale.
- TASK-106 era rimasto separato durante execution/review iniziale perche' questa feature introduceva nuova superficie CRUD e non era un fix layout; al 2026-05-13 TASK-106 e TASK-107 sono entrambi **DONE / CHIUSURA / PASS_WITH_NOTES** dopo review finale su override utente.
- 2026-05-13: l'utente ha richiesto un FIX immediato su TASK-107 prima della review: delete fornitore/categoria piu' completo come flusso funzionale Android, pulsante Price history in Edit product e inserimento nuovo prezzo dallo storico.
- 2026-05-13: l'utente ha richiesto un micro-fix UX sulla sheet Price history per rimuovere l'azione duplicata tra `+` toolbar e `Update current price`; Codex ha mantenuto l'azione contestuale nella card del prezzo corrente.

## Scopo
Implementare nella schermata Database iOS la gestione completa e iOS-native di:
- Prodotti
- Fornitori
- Categorie

## Perimetro
- UI Database iOS e operazioni locali SwiftData su `Supplier` e `ProductCategory`.
- Creazione, rinomina e cancellazione sicura di fornitori/categorie.
- Conteggio prodotti collegati e scollegamento prodotti in caso di eliminazione.
- Pending local changes coerenti con il flusso manual catalog save esistente.

## Non incluso
- Nessuna modifica schema SwiftData.
- Nessuna modifica Supabase, RLS, sync service, repository, import/export parser o migrazioni.
- Nessuna nuova dipendenza.
- Nessun aumento deployment target.
- Android usato solo come riferimento funzionale, non visivo.

## Criteri di accettazione
- [x] Database iOS mostra navigazione iOS-native tra Prodotti, Fornitori e Categorie.
- [x] Fornitori: lista, ricerca, add, rename, delete con conteggio prodotti collegati.
- [x] Categorie: lista, ricerca, add, rename, delete con conteggio prodotti collegati.
- [x] Delete fornitore/categoria scollega i prodotti collegati senza eliminare prodotti.
- [x] Rename/add blocca nome vuoto e duplicati case-insensitive.
- [x] Pending local changes registrati per create/update/delete supplier/category e per prodotti scollegati.
- [x] UI accessibile, leggibile con Dynamic Type e coerente con stile iOS.
- [x] Build iOS PASS.
- [x] `git diff --check` PASS.

## Execution (Codex)
- **Stato**: COMPLETED_FOR_REVIEW
- **Fase**: EXECUTION -> REVIEW
- **Responsabile**: CODEX
- **Trigger**: richiesta esplicita utente dopo TASK-106.
- **Piano minimo**:
  - Aggiungere selector iOS-native nella schermata Database.
  - Riutilizzare i modelli locali `Supplier` / `ProductCategory`.
  - Implementare editor sheet unico per add/rename/delete.
  - Scollegare prodotti collegati prima di eliminare supplier/category.
  - Verificare build, diff check e smoke simulator.
- **Implementazione**:
  - Aggiunto selector iOS-native `Prodotti / Fornitori / Categorie` nella schermata Database.
  - Aggiunte query SwiftData locali per `Supplier` e `ProductCategory`.
  - Aggiunte liste native per fornitori/categorie con ricerca, conteggio prodotti collegati e apertura row.
  - Aggiunto editor sheet condiviso per add/rename/delete.
  - Aggiunta gestione pending local changes per create/update/delete supplier/category.
  - Aggiunto scollegamento prodotti su delete supplier/category con pending update dei prodotti coinvolti.
  - Aggiunta localizzazione IT/EN/ES/ZH per la nuova UI.
- **Check**:
  - PASS: Debug simulator build.
  - PASS: Debug simulator build/run.
  - PASS: Release simulator build.
  - PASS: `git diff --check`.
  - PASS: `plutil -lint` localizzazioni.
  - PASS: smoke simulator su Prodotti/Fornitori/Categorie, ricerca, add/rename/delete fornitore, presentation sheet categoria, toolbar contestuale.
  - PASS: Dynamic Type `extra-extra-large` quick visual check su lista Categorie; simulatore ripristinato a `large`.
- **Evidenze**:
  - `docs/TASKS/EVIDENCE/TASK-107/00-summary.md`
  - `docs/TASKS/EVIDENCE/TASK-107/01-after-supplier-category-tabs.jpg`
  - `docs/TASKS/EVIDENCE/TASK-107/02-checks.md`
  - `docs/TASKS/EVIDENCE/TASK-107/03-implementation-notes.md`
  - `docs/TASKS/EVIDENCE/TASK-107/04-visual-qa.md`
  - `docs/TASKS/EVIDENCE/TASK-107/05-dynamic-type-extra-extra-large.jpg`

## Handoff post-execution (Codex)
- **Esito**: READY_FOR_REVIEW.
- **Stato task**: ACTIVE.
- **Fase successiva**: REVIEW.
- **Responsabile prossimo**: CLAUDE / REVIEWER.
- **Note reviewer**:
  - Verificare che il CRUD locale supplier/category sia considerato nel perimetro approvato dall'override utente.
  - Verificare il comportamento di delete su entita' remote-linked: il codice scollega i prodotti e registra tombstone/pending changes senza toccare sync service o schema.
  - Verificare che TASK-106 resti separato e non marcato DONE.
- **TASK-107 NON DONE**.

## Fix (Codex)
- **Stato**: COMPLETED_FOR_REVIEW
- **Fase**: FIX -> REVIEW
- **Responsabile**: CODEX
- **Trigger**: feedback utente post execution su delete supplier/category e flussi Price history.
- **Piano minimo**:
  - Rendere la cancellazione di fornitore/categoria completa per entita' con prodotti collegati: sostituisci con esistente, crea nuovo e sostituisci, oppure rimuovi assegnazione.
  - Aggiungere accesso a Price history dentro Edit product, vicino alla sezione Prezzi.
  - Aggiungere inserimento nuovo prezzo da Price history con aggiornamento prezzo corrente del Product e pending changes coerenti.
  - Build, lint, `git diff --check`, smoke simulator.
- **Implementazione**:
  - Delete fornitore/categoria collegati ora apre un flusso esplicito con tre opzioni: sostituzione con item esistente, creazione replacement e sostituzione, oppure rimozione assegnazione.
  - Replacement esistente usa sheet con ricerca e selezione iOS-native.
  - Replacement nuovo usa Form con validazione nome vuoto/duplicato e poi riassegna i prodotti collegati prima della delete.
  - Rimozione assegnazione usa conferma distruttiva dedicata e non elimina prodotti.
  - Edit product mostra Price history nella sezione Prezzi.
  - Price history mostra prezzo corrente, pulsante `Update current price`, primary action `Add price`, Form per nuovo prezzo e salvataggio ProductPrice + update corrente.
  - Micro-fix UX successivo: rimossa la primary action `+` dalla toolbar di Price history; resta solo `Update current price` accanto al prezzo corrente.
  - Pending changes: product update viene registrato solo se il prezzo corrente cambia davvero; la riga ProductPrice viene comunque registrata.
- **Check**:
  - PASS: Debug simulator build via XcodeBuildMCP, warnings 0.
  - PASS: Debug simulator build/run via XcodeBuildMCP, warnings 0.
  - PASS: Release simulator build via XcodeBuildMCP, warnings 0.
  - PASS: `git diff --check`.
  - PASS: `plutil -lint` localizzazioni IT/EN/ES/ZH.
  - PASS: deployment target verificato `IPHONEOS_DEPLOYMENT_TARGET = 26.1`, nessun aumento target.
  - PASS: smoke Edit product -> Price history -> New price -> save riga sintetica.
  - PASS: smoke category delete in use: opzioni replace existing/create replacement/remove assignment, picker replacement, create replacement sheet, conferma remove assignment.
  - PASS: smoke supplier delete in use: opzioni replace existing/create replacement/remove assignment.
  - PASS: Dynamic Type `extra-extra-large` su dialog delete supplier in use; simulatore ripristinato a `large`.
  - PASS: Micro-fix Price history action dedup — `ToolbarItem(.primaryAction)` rimosso, resta un solo punto di inserimento prezzo nella card corrente.
  - PASS: Debug simulator build via XcodeBuildMCP dopo micro-fix dedup, warnings 0.
  - PASS: `git diff --check` dopo micro-fix dedup.
  - PASS: `plutil -lint` localizzazioni IT/EN/ES/ZH dopo micro-fix dedup.
  - PASS: Android parity check statico: Android Price history ha gia' una sola azione contestuale di update, quindi nessuna patch Android necessaria.
- **Evidenze**:
  - `docs/TASKS/EVIDENCE/TASK-107/06-fix-edit-product-price-history.jpg`
  - `docs/TASKS/EVIDENCE/TASK-107/07-fix-price-history-add-price.jpg`
  - `docs/TASKS/EVIDENCE/TASK-107/08-fix-category-delete-options.jpg`
  - `docs/TASKS/EVIDENCE/TASK-107/09-fix-supplier-delete-options.jpg`
  - `docs/TASKS/EVIDENCE/TASK-107/10-fix-dynamic-type-delete-options.jpg`
  - `docs/TASKS/EVIDENCE/TASK-107/11-fix-price-history-action-dedup.md`
  - `docs/TASKS/EVIDENCE/TASK-107/11-fix-price-history-action-dedup.jpg`
  - Aggiornati `00-summary.md`, `02-checks.md`, `03-implementation-notes.md`, `04-visual-qa.md`.

## Handoff post-fix (Codex)
- **Esito**: READY_FOR_REVIEW.
- **Stato task**: ACTIVE.
- **Fase successiva**: REVIEW.
- **Responsabile prossimo**: CLAUDE / REVIEWER.
- **Note reviewer**:
  - Verificare il flusso delete collegato su supplier e category: le opzioni sono simmetriche e non toccano schema/sync/import-export parser.
  - Verificare che l'update prezzo dallo storico sia accettabile come UX: e' una riga storica nuova che aggiorna anche il prezzo corrente, con pending ProductPrice sempre registrato e pending Product solo se il valore cambia. Dopo il micro-fix dedup resta solo l'azione contestuale `Update current price`, non il `+` in toolbar.
  - Smoke distruttivo completo di delete/replacement non e' stato finalizzato sui dati fixture per non consumare i dataset sintetici di review; sono state verificate presentation, picker, create sheet e conferme.
- **TASK-107 NON DONE**.

## Review finale (Codex, override utente)
- **Data**: 2026-05-13
- **Reviewer**: CODEX_REVIEW
- **Override workflow**: l'utente ha richiesto esplicitamente a Codex una review completa, severa e con chiusura task se PASS/PASS_WITH_NOTES; Codex ha quindi compilato la review e marcato il task DONE.
- **Verdict**: **PASS_WITH_NOTES**.

### Problemi trovati
- Alcuni TextField nei flussi Edit product / Price history e nelle sheet Database non esponevano label accessibili esplicite in modo robusto.
- La verifica automatica mirata delle pending changes ha esposto un crash deterministico in `LocalPendingAggregatedPushStateStore` durante la deallocazione; il problema era reale per stabilita' test/runtime anche se non specifico della UI.
- Android presenta omissioni localizzative preesistenti solo per `language_endonym_*` nei file localizzati; le stringhe TASK-107/Price history risultano presenti e valide.

### Fix applicati direttamente
- Aggiunte accessibility label esplicite ai TextField in `EditProductView.swift`, `ProductPriceHistoryView.swift` e nei flussi Database interessati.
- `LocalPendingAggregatedPushStateStore` convertito da `final class` a `struct`, mantenendo uguale l'uso chiamante e chiudendo il crash del test mirato.
- Nessuna patch Android in review finale: la parita' funzionale Price history/update prezzo corrente era gia' presente e i check Android sono passati.

### Verifica funzionale iOS
- Prodotti/Fornitori/Categorie: selector iOS-native coerente.
- Fornitori/Categorie: lista, ricerca, add, rename, delete, conteggi collegati e validazioni nome vuoto/duplicato case-insensitive verificati da review statica + smoke precedenti/evidenze.
- Delete avanzato per entita' in uso: replace existing, create replacement e remove assignment implementati; prodotti non eliminati.
- Pending changes: create/update/delete supplier/category, prodotti riassegnati/scollegati e ProductPrice/update Product risultano coerenti con il piano.
- Edit product: accesso Price history nella sezione Prezzi.
- Price history: una sola azione contestuale `Update current price`, nessun `+` duplicato.
- Update current price: crea riga storico e aggiorna prezzo corrente; update Product registrato solo quando il valore corrente cambia.

### Verifica Android parity
- Edit product Android espone Price history.
- Price history Android usa una sola azione contestuale di update, senza duplicazione del `+`.
- Repository/ViewModel Android supportano update prezzo corrente da storico con inserimento riga storico.
- Build/test mirati Android PASS; nessuna modifica Android aggiuntiva necessaria.

### Check review
- ✅ ESEGUITO — iOS Debug build/run simulator: PASS via XcodeBuildMCP, warnings 0.
- ✅ ESEGUITO — iOS Release simulator build: PASS via XcodeBuildMCP, warnings 0.
- ✅ ESEGUITO — iOS test automatici mirati: PASS 44/44.
- ✅ ESEGUITO — iOS `git diff --check`: PASS.
- ✅ ESEGUITO — iOS `plutil -lint`: PASS.
- ✅ ESEGUITO — iOS localizzazioni: 1289 chiavi per locale, 0 duplicati/missing/extra.
- ✅ ESEGUITO — Android targeted unit slice Price history/parity: PASS.
- ✅ ESEGUITO — Android `assembleDebug`: PASS.
- ✅ ESEGUITO — Android `git diff --check` e `xmllint`: PASS.

### Esito
- TASK-107 soddisfa i criteri di accettazione dopo fix review.
- Note non bloccanti: warning Gradle preesistenti e omissioni `language_endonym_*` Android fuori scope; nessun blocker TASK-107.
- **TASK-107 marcato DONE** per istruzione esplicita utente, verdict PASS_WITH_NOTES senza blocker reali.
