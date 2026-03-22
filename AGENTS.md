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

## Protocollo di execution per task UI / Simulator

Quando il task tocca UI, navigazione, o comportamento visibile nel Simulator, il protocollo completo è in **`docs/CODEX-EXECUTION-PROTOCOL.md`**. Lettura **obbligatoria** prima di iniziare l'execution di questi task.

Punti chiave:
- Self-test Simulator obbligatorio: dopo le modifiche, Codex usa `tools/sim_ui.sh` per verificare gli effetti nel Simulator
- Guida operativa wrapper: `tools/sim-ui-guide-codex.md`
- Ogni CA e T-NN richiede riga con tipo verifica (STATIC/BUILD/SIM/MANUAL) ed evidenza
- Un handoff è valido solo se conforme al protocollo — handoff incompleto viene rifiutato in review indipendentemente dalla qualità del codice
- Se l'ambiente Simulator non è disponibile e il task richiede verifica SIM → il task non avanza a REVIEW, resta BLOCKED

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
