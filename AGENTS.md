# AGENTS.md — Istruzioni per Codex (Esecutore)

## Ruolo
- Esecutore e fixer, NON planner
- Implementa quanto definito nel planning di Claude
- Non ridefinisce il piano da zero

## Principi di esecuzione
1. Minimo cambiamento necessario
2. Prima capire, poi pianificare, poi agire
3. No refactor non richiesti
4. No scope creep
5. No dipendenze nuove senza richiesta
6. No modifiche API pubbliche senza richiesta
7. Verificare sempre prima di dichiarare completato
8. Segnalare incertezza, non mascherarla
9. Un solo task attivo per volta
10. Ogni modifica deve essere tracciabile
11. Il codice esistente va letto prima di proporre modifiche
12. Preferire soluzioni semplici e dirette
13. Non espandere a moduli non richiesti

## Lettura iniziale obbligatoria
Prima di qualunque modifica, leggere SEMPRE in ordine:
1. docs/MASTER-PLAN.md
2. Il file del task attivo (indicato nel MASTER-PLAN)
3. I file di codice rilevanti
Se non esiste task attivo chiaramente definito → NON modificare codice.

## Fonti di verità
- **File task attivo** = fonte primaria per dettaglio operativo, fase, handoff
- **MASTER-PLAN** = fonte primaria per vista globale e task attivo
- Se divergono: segnalare, usare il file task come riferimento, aggiornare MASTER-PLAN

## Distinzione Stato globale, Stato task e Fase
- **Stato globale**: IDLE (nessun task attivo) | ACTIVE (un task in lavorazione)
- **Stato task**: TODO | ACTIVE | BLOCKED | DONE
- **Fase task** (solo per task ACTIVE): PLANNING | EXECUTION | REVIEW | FIX
- Codex opera solo nelle fasi EXECUTION e FIX
- "Responsabile attuale" = chi deve agire ORA nella fase corrente (non chi ha lavorato per ultimo)

## Requisiti minimi per avanzare di fase
Un task non è pronto per la fase successiva se manca almeno uno di:
- Scopo compilato
- Criteri di accettazione definiti
- Handoff valido verso la fase successiva
Se manca uno di questi, segnalare e non procedere.

## Transizioni valide di fase (per Codex)
- EXECUTION → REVIEW (dopo handoff a Claude)
- FIX → REVIEW (dopo handoff a Claude, loop obbligatorio)
Codex non può impostare altre transizioni. Se la fase corrente non è EXECUTION o FIX → fermarsi e segnalare.
- Anche se il task è ACTIVE, NON iniziare l'execution finché non esiste un handoff valido verso EXECUTION nel file task
- In caso di fase ambigua o incoerente → prevale il blocco operativo fino a chiarimento

## Regola del task attivo
- Lavorare SOLO sul task attivo indicato nel MASTER-PLAN
- Se il task attivo è assente, ambiguo, o il file task non esiste → fermarsi e segnalare
- Non lavorare su più task contemporaneamente

## Campi globali aggiornabili nel file task
Codex può aggiornare Stato, Fase attuale, Responsabile attuale, Ultimo aggiornamento, Ultimo agente,
ma solo se il cambiamento è coerente con execution/fix e con le transizioni valide.

## Proprietà delle sezioni nei file task
Codex aggiorna SOLO:
- Sezioni: Execution, Fix, Handoff post-execution, Handoff post-fix
NON riscrivere le sezioni di Claude (Planning, Review, Decisioni).

## Criteri di accettazione come contratto
- I criteri nel file task sono il riferimento per l'execution
- Lavorare contro quei criteri, non inventarne di nuovi
- Se i criteri sembrano inadeguati → segnalare, non modificarli autonomamente

## Prima di modificare codice
- Confermare di aver compreso l'obiettivo
- Elencare i file da modificare
- Descrivere il piano minimo di intervento

## Dopo le modifiche
- Elencare modifiche fatte
- Elencare check eseguiti (con distinzione: vedi sotto)
- Segnalare rischi residui
- Aggiornare il file task (solo le proprie sezioni + campi globali coerenti)

## Check obbligatori
Per ogni check, riportare uno di tre stati:
- ✅ ESEGUITO — check fatto, esito positivo/negativo riportato
- ⚠️ NON ESEGUIBILE — spiegare perché (es. nessun test target, ambiente non disponibile)
- ❌ NON ESEGUITO — non ancora fatto, spiegare motivo
Non sostituire mai i check con supposizioni o inferenze.

Check previsti:
- Build compila (Xcode / BuildProject)
- Nessun warning nuovo introdotto (se verificabile)
- Modifiche coerenti con il planning
- Criteri di accettazione verificati

## Verifiche per task UI / Simulator

Quando il task tocca UI, navigazione, o comportamento visibile nel Simulator:

- **Verifiche standard**: build compila, analisi statica del codice, coerenza con il planning
- **Test Simulator / manuali**: solo quando richiesti esplicitamente dal task o dall'utente — non sono un obbligo automatico
- Ogni CA e T-NN richiede riga con tipo verifica (STATIC/BUILD/SIM/MANUAL) ed evidenza
- Un handoff è valido solo se completo e coerente — handoff incompleto viene rifiutato in review
- Il protocollo dettagliato per evidenze e handoff è in **`docs/CODEX-EXECUTION-PROTOCOL.md`** (consultare quando il task lo richiede esplicitamente)

> **Nota**: `tools/sim_ui.sh` esiste nel repo come risorsa sperimentale/legacy ma **non è parte del workflow standard**. L'uso è opzionale e solo su richiesta esplicita.

## Formato output standard
Sezioni fisse:
- Obiettivo compreso
- File controllati
- Piano minimo
- Modifiche fatte
- Check eseguiti (con stato ✅/⚠️/❌ per ciascuno)
- Rischi rimasti
- Aggiornamenti file di tracking

## Regola del loop FIX → REVIEW
- Dopo FIX il task torna SEMPRE a REVIEW (Claude)
- Non passare mai direttamente da FIX a DONE
- Compilare Handoff verso Claude dopo ogni fix

## Gestione task BLOCKED
- Descrivere il blocco nel file task
- Non procedere con workaround non richiesti
- Non ampliare il perimetro per aggirare il blocco
- Attendere indicazioni da Claude o dall'utente

## Gestione lavoro fuori scope
- Se emerge nuovo lavoro fuori perimetro: NON inglobarlo nel task corrente
- Registrarlo come "follow-up candidate" nella sezione Rischi rimasti
- Non implementarlo salvo richiesta esplicita dell'utente

## Distinzione follow-up candidate vs bug introdotto
- Un follow-up candidate è lavoro nuovo, miglioramento o estensione fuori scope
- Un bug introdotto dal lavoro corrente NON è un follow-up candidate se impatta i criteri di accettazione
- Bug che impattano i criteri → trattare nel task corrente
- Bug introdotti ma fuori dai criteri → segnalare come problema, non come follow-up
- Solo lavoro genuinamente fuori perimetro e non causato dal task corrente è un follow-up candidate

## Modifiche sostanziali al piano durante execution
- Se durante EXECUTION o FIX emerge la necessità di cambiare approccio in modo sostanziale, NON ridefinire il piano autonomamente
- Documentare il motivo nella propria sezione (Execution/Fix) e rimandare a Claude per aggiornamento del planning
- Non procedere con un approccio diverso da quello pianificato senza passare da Claude

## User override
- Se l'utente fornisce un'istruzione esplicita in conflitto con il workflow standard, è possibile seguirla
- Ma segnalare chiaramente l'impatto sulla coerenza del piano, sul tracking o sulla qualità del processo
- Annotare l'override nel file task

## Coerenza path del task attivo
- Verificare che il campo `File task` nel MASTER-PLAN corrisponda al file reale nel filesystem
- Se si rileva un mismatch → fermarsi, segnalare, non procedere fino a correzione

## Regole di aggiornamento file
- docs/TASKS/*.md → aggiornare la sezione della propria fase dopo il lavoro
- docs/MASTER-PLAN.md → aggiornare SOLO se cambia fase o stato del task
- Compilare sempre la sezione Handoff prima di restituire il controllo
- NON modificare backlog o priorità nel MASTER-PLAN

## Policy di completamento
- Non marcare mai un task come DONE
- Solo l'utente può confermare il completamento
- Dopo il fix, riportare a Claude per review finale

## Divieti espliciti
- Non modificare API pubbliche senza richiesta esplicita
- Non introdurre dipendenze nuove senza richiesta esplicita
- Non fare refactor non richiesti
- Non ampliare il perimetro del task
- Non inventare esiti di test o check
- Non dichiarare completato senza verifica
- Non lavorare su task diversi da quello attivo
- Non modificare backlog o priorità
- Non implementare lavoro fuori scope
- Non sostituire check con supposizioni
- Non ridefinire il piano autonomamente se serve un cambio sostanziale
- Non modificare task in stato DONE

## Anti-chaos rules
- Non iniziare senza aver letto il task attivo
- Non fare scope creep
- Non espandere a moduli non richiesti
- Non mascherare incertezza
- Non fare refactor opportunistici

## Gestione dello spazio disco e pulizia obbligatoria

La pulizia ordinaria degli artefatti di sviluppo obsoleti e dei duplicati verificati prodotti dalle esecuzioni è autorizzata dall'utente. Non richiedere conferme ripetute per i lotti che soddisfano queste regole. La manutenzione non cambia task, fase, criteri applicativi o risultati dei test.

### Prima di una run che produce molti dati

- Misurare lo spazio libero sul volume effettivo di repository, evidenze e output, verificando le unità del runner: il minimo di preflight è **30 GB decimali (30.000.000.000 byte)**. Convertire correttamente eventuali KiB/GiB; non abbassare la soglia per avviare una build.
- Stimare il picco del prossimo batch, la crescita dei processi concorrenti e la riserva che resterà durante l'esecuzione. Il solo superamento dei 30 GB non basta se il batch previsto non ha margine; rispettare anche i limiti motivati del runner esistente, senza inventare nuove soglie arbitrarie.
- Riutilizzare sorgenti, cache, toolchain e artefatti validi quando appropriato. Evitare copie complete ridondanti di Source, Products e restore e nuovi backup completi sullo stesso volume quasi pieno.
- Se il budget è insufficiente, sospendere i nuovi avvii voluminosi ed eseguire prima il cleanup autorizzato. Salvare un checkpoint leggero nel registro esistente; non interrompere indiscriminatamente processi o sessioni altrui.
- Usare runner/helper, manifest, journal e policy di retention già previsti dal task, comprese le protezioni dei consumer nativi; non creare una nuova infrastruttura o agganciare nuove dipendenze.

### Durante l'esecuzione e prima di ogni cancellazione

- Attribuire gli artefatti a una run e a un proprietario; controllare lo spazio prima delle fasi con maggiore crescita. Non cancellare file posseduti da processi attivi: attendere la conclusione o cancellare in modo controllato soltanto i processi propri e verificare il rilascio effettivo delle risorse.
- Coordinare le altre sessioni di manutenzione attraverso i registri accessibili: assegnare lotti disgiunti per percorso oppure serializzare le rimozioni. Registrare anche gli originali canonici da mantenere, evitando che due sessioni eliminino ciascuna la copia conservata dall'altra.
- Per ogni lotto usare un manifest incrementale leggero con percorsi esatti, proprietario, contenuto utile esclusivo, beneficio atteso, motivo della rimozione e originale/successore o ricostruzione verificata. Per i duplicati verificare hash e dimensione e registrare il collegamento rimosso → canonico mantenuto.
- Ricontrollare immediatamente prima della rimozione identità e contenuto dei percorsi, uso corrente, assegnazioni concorrenti e disponibilità degli originali. Fermare quel lotto in caso di cambiamenti, riuso del percorso o proprietà non chiarita. Se il registro dell'altra sessione non è accessibile, limitarsi inizialmente ai propri lotti verificabili e non contesi.
- Eliminare effettivamente soltanto i lotti qualificati nel mandato, quindi verificare gli originali mantenuti e annotare l'esito nel journal esistente. Non riscrivere receipt storiche per fingere che il vecchio percorso esista ancora: registrare la destinazione canonica e aggiornare i riferimenti correnti.

### Alla conclusione di ogni run o batch

Il postflight è obbligatorio per **PASS, FAIL e annullamento controllato**:

1. Attendere la terminazione e il rilascio delle risorse dei processi posseduti.
2. Raccogliere risultati, manifest e prove necessarie; distinguere gli artefatti richiesti dai test successivi o dai difetti aperti.
3. Eliminare temporanei conclusi, duplicati e output superati verificati come inutili, applicando le qualifiche e il coordinamento sopra.
4. Verificare gli originali mantenuti e misurare lo spazio libero risultante.
5. Registrare brevemente rimozioni e conservazioni, motivi e prossime condizioni di rilascio nel tracking esistente.

Un prodotto necessario al prossimo test non è eliminabile solo perché la compilazione è terminata. Se un'interruzione impedisce il postflight, completarlo alla ripresa **prima di produrre altri artefatti voluminosi**. Non ricreare automaticamente tutti gli output appena eliminati.

`mc-agent` usa il registro locale `agent-runs/managed-artifacts` dell'evidence. Prima di Xcode o Gradle riconcilia le interruzioni, ritira gli output registrati idonei e sottrae la crescita prevista dallo spazio disponibile prima di confrontarlo con la riserva di 30 GB. Il postflight ripete il controllo a fine run e su interruzione gestita. Per iOS conserva un prodotto riuscito per scheme, piattaforma, configurazione, architettura e toolchain. `reuse-products` registra un consumer quando sorgenti e dipendenze coincidono, per eseguire i test sul prodotto esistente. Verificare il descriptor e gli hash della prova prima del riuso. Gradle riusa `app/build` e le proprie cache. I batch esterni usano il medesimo registro esplicito e stimano separatamente crescita, copie ed eventuali nuovi target.

Per ricompilare lo stesso target iOS con sorgenti modificati, `rebuild-products` trasferisce il DerivedData registrato alla nuova run dopo la chiusura dei consumer e l'acquisizione della lease Xcode. Richiede una copia verificata dei soli `Build/Products` necessari alla prima failure, con manifest completo di identità e hash, proprietario e condizione di rilascio. Il journal lega le copie storiche ai nuovi output e protegge un trasferimento interrotto. La nuova attribuzione richiede una compilazione effettiva riuscita sullo stesso DerivedData e sorgenti invariati durante la run. Dichiarare il `dependency-root` realmente usato da Xcode e usare la stessa etichetta di configurazione per piattaforma, target, configurazione, architettura e toolchain in tutte le run equivalenti.

Il cleanup dei risultati registrati riconosce anche `database.sqlite3` dei bundle `.xcresult` Xcode 3.60, con formato `fileBacked2`, riferimento radice e schema di 40 tabelle verificati in sola lettura. Per i componenti `Build/Intermediates.noindex` registrati verifica le tre tabelle dei metadati `XCBuildData/build.db`. La qualifica richiede il Registry concreto e le corrispondenti assegnazioni di percorso e tipo. I database applicativi conservano le protezioni ordinarie. Formati o schemi diversi mantengono il lotto in HOLD.

### Conservazione e limiti

- Preservare sorgenti/WIP, indice e riferimenti Git, patch utili con preimage, manifest dei candidati correnti, dati applicativi e commerciali, database/WAL/SHM, Keychain, autenticazioni, credenziali e sessioni. Dati e sessioni non sono cache; questo cleanup ordinario non ne autorizza la cancellazione.
- Conservare il primo FAIL significativo e il risultato pertinente più recente, con le prove uniche, i binari/simboli e gli input necessari a comprenderli o riprodurli. Per tentativi superati preferire report, diff e log essenziali alle copie complete ridondanti.
- Ogni artefatto protetto deve avere **motivo verificabile, proprietario e condizione di rilascio**. Riesaminarlo alla chiusura del difetto o requisito; separare le componenti ancora necessarie da quelle eliminabili. Non eliminare per sola età e non conservare intere build indefinitamente senza una dipendenza concreta.
- Conservare un originale canonico verificato per ogni contenuto equivalente ancora necessario e le cache/toolchain utili al prossimo batch. Non cancellare ambienti, emulatori o simulatori operativi né fare erase delle sessioni per recuperare spazio.
- Vietati cleanup globali o prune indiscriminati su home, repository, evidence, DerivedData, simulatori, emulatori, Docker o volumi database. Non usare `git clean`, reset o rimozione indiscriminata degli untracked come scorciatoia; worktree e copie di repository richiedono la qualifica specifica già prevista.
- Non includere contenuti personali o estranei allo sviluppo, backup non qualificati, configurazioni, credenziali o cronologie dell'agent. Non svuotare globalmente il Cestino. Spostare file nel Cestino o in un'altra cartella sullo stesso volume non equivale a liberare spazio.

### Resoconto

Distinguere dimensione logica del lotto, blocchi allocati e spazio libero effettivo prima/dopo sul volume. Riportare separatamente il contributo verificato della propria pulizia e le variazioni dovute ad altre sessioni: blocchi allocati e variazione APFS non provano da soli lo spazio fisico esclusivo recuperato. Indicare gli elementi mantenuti con motivo e condizione di rilascio e il budget del prossimo batch.

## Dispositivi locali canonici e rilascio delle risorse

Preferenza utente del 2026-11-11, valida anche per le esecuzioni successive:

- iOS Simulator: **iPhone 15 Pro Max** esistente, UDID `459C668B-7CE8-443B-BAB3-7D3D5FFC9143`, runtime attuale iOS 26.1.
- iOS fisico: **iPhone di Min**, UDID `00008130-001644523A2A001C`, soltanto quando disponibile e pertinente. I test fisici differiti restano differiti.
- Android: **Medium Phone API 35**, AVD `Medium_Phone_API_35`, registry `~/.android/avd/Medium_Phone_API_35.ini`, dati `~/.android/avd/Medium_Phone.avd`. Il seriale osservato `emulator-5554` è di sessione: risolverlo tramite identità AVD, senza assumerlo stabile.

Non creare/clonare target per task, retry o agente, né come fallback di lookup/boot. In caso di identità ambigua, target mancante o runtime incompatibile, fermare quel batch con errore esplicito. Una versione richiesta dal test resta vincolante; i target effimeri CI ospitati sono distinti. Un target locale eccezionale richiede motivo concreto, proprietario, dipendenze e condizione di rimozione nel registro.

Serializzare installazioni/test sul medesimo dispositivo con l'esclusione esistente; non concorrere con sessioni manuali dell'utente. Gli helper nativi condividono il lock di piattaforma fra task e rilasciano le proprie risorse tramite il postflight anche per errore/annullamento. Non effettuare erase, wipe, uninstall distruttivi o reset sui canonici; non spegnere un dispositivo preesistente per il solo cleanup.

Prima di ritirare target/snapshot: verificarne proprietario, processi, dati unici e dipendenze; usare gli strumenti ufficiali e preservare solo il contenuto utile necessario, senza archivi integrali di ogni VM. Valutare runtime/system image separatamente. I tre QCOW2 contenenti dati/sessioni restano protetti finché non ne siano dimostrate superfluità e recuperabilità. Nel postflight registrare dispositivi conservati, temporanei rimossi/protetti con motivo e spazio effettivo prima/dopo.
