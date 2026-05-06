# TASK-048: Supabase ProductPrice foundation iOS — preview read-only + mapping SwiftData, **no push**, **no apply locale** *(Slice A)*

## Informazioni generali
- **Task ID**: TASK-048
- **Titolo**: Supabase ProductPrice foundation iOS: preview read-only + mapping SwiftData, **nessun push**, **nessuna apply locale** *(Slice A consigliata)*
- **File task**: `docs/TASKS/TASK-048-supabase-productprice-foundation-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: —
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-06 *(REVIEW completa TASK-048 eseguita da Codex su override utente: fix mirati applicati, build/test/check anti-scope verdi, task chiuso **DONE / Chiusura**. Slice A resta read-only: nessun push/apply ProductPrice).*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

## Dipendenze
- **Dipende da**:
  - **TASK-033** — DONE — audit schema/mapping (`inventory_product_prices`, RLS, gap timestamp/text).
  - **TASK-034/035** — DONE — DTO `RemoteInventoryProductPriceRow`, preview catalogo con storico **secondario** e budget (**§H-ter TASK-035**).
  - **TASK-038** — DONE — sessione Google / client auth-gated.
  - **TASK-039** — DONE — apply locale catalogo; **ProductPrice remoto esplicitamente fuori** dall’apply.
  - **TASK-040** — DONE — `Product.remoteID` bridge; join logico prezzo↔prodotto deve usare **UUID remota prodotto**.
  - **TASK-043** — DONE — baseline/fingerprint *(TASK-048 non modifica policy baseline salvo handoff esplicito futuro)*.
  - **TASK-044/045/046/047** — DONE — push/manuali/scoping; **ProductPrice push resta vietato** nel perimetro TASK-048.
- **Sblocca** *(non attivare senza review/user override)*:
  - **TASK-049** *(proposto)* — apply locale controllato `ProductPrice` da piano derivato da preview completa / conflict policy dedicata.
  - Task futuri: **ProductPrice push** remoto, `record_sync_event`/outbox, tombstone outbound, realtime/background.

### Confine TASK-048 vs TASK-049 *(obbligatorio)*
- **TASK-048** = **fondazione read-only**: fetch paginato **con cap rigidi** (vedi § *Cap e paginazione*), modelli/DTO/summary di preview, mapping documentato, UI DEBUG **solo lettura** (conteggi, campioni **limitati**, warning), XCTest **puramente locali/mock**. **Non** tentare di scaricare l’intero storico prezzi su tenant con dataset grande.
- **TASK-048 non produce** un **diff definitivo** dell’intero storico prezzi remoto, né un confronto completo con lo storico SwiftData: produce una **preview diagnostica limitata** («**campione letto**» entro i cap) e un **mapping verificabile** (tipo, timestamp, join `remoteID`, orphan). I numeri mostrati sono **righe lette nel campione**, **non** «totale righe remote assolute» del tenant.
- **TASK-049** *(o task successivo dedicato)* = eventuale **preview più ampia / completa** controllata (budget più alto o strategia diversa documentata), **`prepareApplyPlan`/`apply`**, **full diff**, **merge policy** storico prezzi — **tutto fuori** dal contratto TASK-048.

## Scopo
Allineare progressivamente iOS allo **storico prezzi cloud** (`inventory_product_prices`) in modo **sicuro**: validare lettura, normalizzazione e join tramite `Product.remoteID`, esporre in DEBUG una **preview diagnostica read-only** *(campione limitato)*, senza scrivere nel cloud né applicare righe storiche in SwiftData in questo task.

## Contesto

### Stato attuale iOS *(rilevato nel repo)*
- **`ProductPrice`** SwiftData (`Models.swift`): `PriceType` **lowercase** (`purchase`/`retail`), `effectiveAt`/`createdAt` **`Date`**, relazione opzionale `product`; **nessun** `remoteID` sulla riga storico.
- **`RemoteInventoryProductPriceRow`** (`SupabaseInventoryDTOs.swift`): `type` **`String`**, `effectiveAt`/`createdAt` **`String`**, `productID: UUID`, `price: Double` — allineato allo schema audit **text** + **PURCHASE/RETAIL** maiuscolo remoto.
- **`SupabasePullPreviewService`** / **`SwiftDataInventorySnapshotService`**: già calcolano diff storico con chiave logica **`PriceHistoryLogicalKey(barcode, type, effectiveAt)`** e warning **`priceHistoryIncomplete`**, **`priceHistoryUnmatchedProduct`**, tipo/data non normalizzabili; snapshot locale per storico usa **`price.type.rawValue`** e **`canonicalDateString`** per confronto.
- **`SupabasePullApplyService`**: **blocca** apply se storico remoto incompleto (**guard anti-applicazione prezzi**); **non** crea/aggiorna `ProductPrice` da cloud nei task completati finora.
- **Manual push / preflight**: ProductPrice **escluso** esplicitamente (copy UI + servizi TASK-041/044).
- **Baseline/fingerprint**: coprono catalogo post-pull/apply; TASK-048 **non** richiede nuova persistenza baseline per prezzi salvo decisione esplicita successiva.

### Riferimento Android *(funzionale, non copia codice)*
Fonti nel workspace iOS:
- `docs/SUPABASE/TASK-033-schema-audit.md` — **`ProductPrice.kt`**, **`ProductPriceSummary`**, ruolo audit trail e stringhe tipo/timestamp; **`InventoryRepository.kt`** menzionato come orchestratore fetch/push catalogo/prezzi.

In EXECUTION, se disponibile sul disco di sviluppo, consultare il repo Android citato nell’audit (**path storico audit**: clone locale `MerchandiseControlSplitView`) **solo** per confermare semantica campi e ordinamenti UX — **nessuna dipendenza di build incrociata**.

**Guardrail utente**: **TASK-068 Android PARTIAL** (bulk product push / no-op live) **non** è contratto per iOS.

### Riferimento Supabase *(schema, non ambiente live inventato)*
Fonte di verità nel workspace iOS:
- `docs/SUPABASE/TASK-033-schema-audit.md` — tabella **`inventory_product_prices`**:
  - PK **`id`** UUID *(generazione client-side documentata in audit)*;
  - **`owner_user_id`** → `auth.users`;
  - **`product_id`** UUID **NOT NULL** → **`inventory_products` ON DELETE CASCADE**;
  - **`type`** CHECK **`PURCHASE` | `RETAIL`**;
  - **`price`** `float8`;
  - **`effective_at`**, **`created_at`** — **`text`** NOT NULL *(formato canonico allineato Room — vedi commenti migrazione in audit)*;
  - **`source`**, **`note`** opzionali;
  - **UNIQUE** `(owner_user_id, product_id, type, effective_at)`;
  - **RLS** owner-scoped; **DELETE** revocato su `authenticated` (**migrazione 038** in audit) — implicazione: modello **append-only** lato client; cleanup diverso = task/backend dedicato.

Path migrazioni SQL **storico TASK-033**: repo Supabase locale **`MerchandiseControlSupabase/supabase/migrations/`** (file tipo `*_inventory_product_prices.sql`).

### Gate schema DDL *(obbligatorio prima di EXECUTION Swift)*

- **Prima di qualsiasi EXECUTION** che tocchi query/postgrest su `inventory_product_prices`: rileggere la **migration reale locale** della tabella nel repo Supabase (file effettivo sotto `supabase/migrations/`), non solo TASK-033.
- Verificare: colonne effettive, **RLS/policy**, **CHECK** su `type`, **unique key**, formato **`effective_at` / `created_at`** (text vs altro), eventuali differenze rispetto alla sintesi TASK-033.
- Se lo schema reale **differisce** da quanto ipotizzato nel planning iOS: **STOP**, aggiornare **questo file task** (planning) e solo poi codificare — **nessuna** modifica SQL nel task iOS.
- **TASK-068 Android PARTIAL**, **TASK-071** o altro contesto Android **non** diventano contratto iOS senza **verifica schema** e allineamento documentale.

**TASK-048 EXECUTION**: **nessuna modifica** SQL/RLS/RPC nel repo Supabase; solo lettura DDL per conformità client.

**Nota workspace**: i file **`MASTER-PLAN Android.md`** / **`MASTER_PLAN Supabase.md`** indicati dall’utente **non** sono presenti sotto `/Users/minxiang/Desktop/iOSMerchandiseControl`; integrare in review se aggiunti, senza contraddire le migrazioni reali.

### Gap iOS vs Android / Supabase
| Area | Android / Supabase | iOS oggi | Gap TASK-048 |
|------|-------------------|----------|--------------|
| Chiave join storico↔prodotto | `product_id` UUID | `Product.remoteID` post TASK-040 | Join solo dove `remoteID` valorizzato; altrimenti **warning/statistiche**, niente inferenza barcode dalla sola riga prezzo |
| Tipo prezzo | `PURCHASE`/`RETAIL` | `PriceType` lowercase + normalizer preview | Riutilizzare / consolidare **`SupabasePullPreviewNormalizer.normalizedPriceType`** e percorsi equivalenti per righe **solo remote** |
| Timestamp | text canonico | `Date` locale + `canonicalDateString` in snapshot | Parser unico **documentato** per confronto read-only; gestione fallimento = warning già tipizzati |
| Volume dati | storico potenzialmente grande | budget **H-ter** nel pull preview completo | TASK-048 può introdurre fetch **dedicato** prezzi con **cap/pagine** e indicatori **truncation** in UI DEBUG |
| Sync metadata | `sync_events` / RPC | assente iOS | **Fuori scope** (vedi sotto) |

### Perché `sync_events` / outbox / realtime **non** entrano in TASK-048
- Allineamento storico prezzi richiede prima **certezza di lettura/parsing/dedupe** e policy conflitti **locali**.
- **`record_sync_event`**: caveat documentati (**TASK-071** / mismatch backend `p_changed_count > 1000`); niente telemetria sync obbligatoria finché il perimetro prezzi read-only non è stabile.
- Outbox/realtime aumentano superficie di errore e regressione **TASK-039/043** senza beneficio immediato per la sola **preview**.

### Perché ProductPrice **read-only** viene prima del **push** remoto
- Il backend impone **unique** su `(owner, product, type, effective_at)` e **no DELETE** policy client: errori di push sono costosi da ripulire.
- Senza preview/QA su volumi e orphans, il push creerebbe duplicati rigettati o conflitti opachi.
- Android ha già integrazione storica verificata **live** in task passati; iOS deve recuperare **osservabilità** (DEBUG + test) prima delle write.

## Slice raccomandata: **A** *(accettata in PLANNING)*

| Slice | Contenuto | In TASK-048? |
|-------|-----------|--------------|
| **A — consigliata** | Fetch read-only paginato; modelli summary preview; UI DEBUG read-only; mapping + XCTest puri; **zero** `context.insert`/`delete` `ProductPrice` da flusso Supabase | **Sì** |
| **B — solo se banale** | Oltre ad A: costruire struttura **`ApplyPlan`** pura per prezzi **senza** eseguire `apply` | **Opzionale** solo se implementazione **≤ piccolo incremento** testabile senza toccare `SupabasePullApplyService` behavior — altrimenti **TASK-049** |

**Decisione planner**: adottare **Slice A** come contratto TASK-048; Slice B **non** è obiettivo primario.

## Non incluso *(anti-scope tassativo)*
- **Nessun push** remoto `inventory_product_prices` (POST/PATCH/UPSERT concetti equivalenti).
- **Nessuna apply locale** SwiftData che crei/aggiorni/cancelli **`ProductPrice`** da dati Supabase *(incluso «dry-run apply» che persiste)*.
- **Nessun** `record_sync_event`, **`sync_events`**, outbox locale/remota, watermark incrementale.
- **Nessun** tombstone outbound / delete remota / cleanup catalogo remoto.
- **Nessun** realtime / background sync / polling automatico *(solo azioni utente DEBUG esplicite)*.
- **Nessuna** modifica schema Supabase, migration, RLS, RPC, Edge Functions.
- **Nessun** file Android; **nessun** contratto parity con **TASK-068** bulk quirks.

---

## Fonti lette *(PLANNING — repo iOS)*

### Documentazione / task
- `docs/MASTER-PLAN.md`
- `docs/SUPABASE/TASK-033-schema-audit.md` *(schema `inventory_product_prices`, mapping, decision log D-04/D-09/D-15, gap G-11)*
- `docs/TASKS/TASK-033-supabase-schema-audit-ios-android-model-mapping.md` *(sezioni inventory_product_prices)*
- `docs/TASKS/TASK-035-manual-supabase-pull-swiftdata-dry-run.md` *(§H-ter storico secondario)*
- `docs/TASKS/TASK-039-supabase-preview-apply-locale-controllato-swiftdata.md` *(esclusione ProductPrice apply)*
- `docs/TASKS/TASK-040-supabase-full-pull-remote-identity-bridge-swiftdata-android-alignment.md` *(bridge `remoteID`)*
- `docs/TASKS/TASK-041` … **TASK-047** *(anti-scope ProductPrice push / guardrail)*

### Codice iOS *(indicazioni file — lettura approfondita in EXECUTION)*
- `iOSMerchandiseControl/Models.swift` — `Product`, `ProductPrice`, `PriceType`
- `iOSMerchandiseControl/SupabaseInventoryDTOs.swift` — `RemoteInventoryProductPriceRow`
- `iOSMerchandiseControl/SupabaseInventoryService.swift` — `fetchProductPrices` / `fetchProductPricesPage`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift` — fetch merge, warning storico, diff
- `iOSMerchandiseControl/SupabasePullPreviewModels.swift` — `SyncPreview`, `PriceHistoryLogicalKey`, normalizer
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift` — snapshot locale storico
- `iOSMerchandiseControl/SupabasePullApplyService.swift` — guard **priceHistoryIncomplete**
- `iOSMerchandiseControl/OptionsView.swift` — sezione DEBUG Supabase esistente
- Test: `iOSMerchandiseControlTests/SupabasePullPreviewDiffEngineTests.swift`, `SupabasePullApplyServiceTests.swift`, `SupabaseCatalogBaselinePreflightIntegrationTests.swift` *(pattern guard/regole)*

### Fonti Android / Supabase DDL *(EXECUTION: rileggere dal clone locale se presente)*
- Repo Android: entità **`ProductPrice`**, view **`ProductPriceSummary`**, **`InventoryRepository`** *(solo lettura)*.
- Repo **`MerchandiseControlSupabase`**: migration `inventory_product_prices` *(DDL effettivo)*.

---

## Planning (Claude) — approccio EXECUTION futura *(Slice A)*

### Obiettivo execution *(sintesi)*
1. Servizio/wrapper **read-only** sottile (vedi § *Riutilizzo codice*) che incapsula cap/pagine/completed/truncated.
2. **`ProductPricePreviewSummary`** (+ righe campione per UI/test) con flag **`truncated`**, conteggi, orphan/warning — **senza** scrittura SwiftData né remota.
3. **UI DEBUG** in **`OptionsView`**, sezione Supabase esistente — § *UX DEBUG prevista*.
4. Mapping/timezone/tipo come già documentato in questo task; error handling § *Matrice errori*.
5. Privacy/logging § *Privacy e logging*.

### Cap e paginazione *(numeri contratto TASK-048)*

| Parametro | Valore consigliato | Ruolo |
|-----------|-------------------|--------|
| **`pageSize`** | **200** righe | Dimensione richiesta per ogni pagina Supabase (range/limit coerente con client esistente). |
| **`maxRows`** | **1000** righe | Massimo cumulativo di righe accettate in una singola sessione preview TASK-048. |
| **`maxPages`** | **5** pagine | Tetto pagine consecutive per sessione (**200 × 5 = 1000** allineato a `maxRows`). |

**Regole operative:**
- Il fetch deve **fermarsi immediatamente** non appena **uno** tra questi eventi si verifica: `righe_accumulate >= maxRows`, oppure `pagine_eseguite >= maxPages`, oppure una pagina restituisce **0 righe** *(fine dataset)*.
- **Ordine di fetch**: pagine successive solo mentre `righe < maxRows` **e** `pagine < maxPages` **e** l’ultima pagina non era vuota.
- **TASK-048 non ha obiettivo “full history sync”**: con cataloghi grandi, questi numeri sono **volutamente** bassi; una preview che vuole copertura totale o merge storico completo è **TASK-049+**.
- **`truncated` nel summary** (Bool): deve essere **`true`** quando vi sono **probabilmente** altre righe non caricate. Regola pianificata per EXECUTION:
  - **`true`** se il loop termina perché si raggiunge **`maxRows`** oppure **`maxPages`** *(stop anticipato ⇒ dati oltre il campione possibile)*;
  - **`false`** se una pagina restituisce **0 righe** *(fine naturale del cursore/offset corrente)*;
  - **`false`** se l’ultima pagina ha **`> 0` e `< pageSize`** righe *(ultima pagina “parziale” ⇒ tipicamente non esistono altre righe con lo stesso schema di query)*;
  - Se in futuro si introducesse `hasMore` esplicito dal backend *(fuori scope TASK-048)*, aggiornare la regola in TASK-049+.

*(Ambiguità API offset/cursor: documentare nel diff EXECUTION mantenendo invarianti: **stop ai cap**, niente caricamento illimitato.)*

#### Ordinamento remoto deterministico *(paginazione sicura)*

- La futura **EXECUTION** deve applicare un **`order` stabile lato Supabase/PostgREST** **prima** di `range` / paginazione. **È vietato** paginare senza ordinamento esplicito: su dataset grandi l’ordine non garantito può causare **righe duplicate o saltate** tra pagine.
- **Ordine proposto** (tie-break completo): **`product_id` asc**, poi **`type` asc**, poi **`effective_at` asc**, poi **`id` asc** *(UUID PK riga)* — così l’ordinamento è deterministico anche con più righe per stesso prodotto/tipo/data.
- Se **Supabase/PostgREST** o il **client Swift** limitano il **multi-order** *(una sola colonna, ordinamenti ridotti)*: la EXECUTION deve scegliere il **massimo ordinamento stabile effettivamente supportato**, documentarlo **nel diff del task** *(campo/i effettivi + motivazione stabilità)* e solo così applicare `range`; se non è possibile garantire stabilità multi-page senza estensione client → **blocco planning / TASK-049** per adeguamento API *(non improvvisare pagination fragile)*.
- **Dedupe difensivo** lato client **resta obbligatorio** dove utile, ma **non sostituisce** l’ordinamento remoto stabile.

### UX DEBUG prevista *(OptionsView — coerenza app)*

**Debug gate** *(obbligatorio)*
- La card **«Storico prezzi cloud»** deve stare **solo** nella **sezione Supabase / Debug già esistente** di `OptionsView` — coerente con le altre superfici diagnostiche.
- **Riusare** il pattern già presente nel progetto per contenuti DEBUG *(es. `#if DEBUG`, sezioni visibili solo in build Debug, o equivalente già usato per Supabase in `OptionsView`)* — **nessun** nuovo sistema di feature flag o gate parallelo.
- **Non promuovere** questa preview a **feature principale** per l’utente finale in TASK-048: resta strumento **diagnostico**.
- In **Release**, se oggi una sezione debug è visibile per scelta storica dell’app, **mantenere coerenza** con quel comportamento; **non** introdurre nuovi percorsi Release-specific per questa card salvo allineamento esplicito documentato nel diff.

**Posizione e forma**
- **Dove**: `OptionsView`, nella **sezione Supabase / Debug già esistente** — **nessuna** nuova tab, **nessuna** `NavigationLink` verso schermata dedicata, **nessuna** sheet/modal pesante; layout **card compatta** stile SwiftUI nativo allineato alle altre card DEBUG (es. pattern TASK-043/044: card + disclosure/`DisclosureGroup` se serve dettaglio).
- **Decisione UX**: **card compatta + dettaglio espandibile** (seconda riga o disclosure) per lista sample e metriche — strumento **diagnostico** chiaro, non feature per utente finale Release.

**Componenti visivi e copy UX** *(chiavi localizzate IT / EN / ES / ZH-Hans — testo base pianificato)*
- **Titolo**: «Storico prezzi cloud»
- **Badge**: «Sola lettura»
- **Sottotitolo fisso consigliato** *(sotto titolo/badge)*: «Anteprima limitata: legge un campione dal cloud, non modifica i dati.»
- **CTA primaria**: «Carica preview»
- **CTA secondaria** *(solo dopo `success` / `partial` / `capped`, mai in idle iniziale)*: **unicamente** «**Aggiorna preview**» *(reset sessione + rifetch da pagina 0 entro gli stessi cap)*.
  - **Decisione UX TASK-048**: **non** usare «Carica altra pagina» né navigazione pagina-per-pagina manuale — evita la percezione di **sync progressivo** o **download completo**; navigazione paginata manuale esplicita = **TASK-049+** se mai richiesta.
- La card deve **sempre** comunicare campione limitato (sottotitolo + eventuali metriche «campione letto»).

**Metriche mostrate** *(card / disclosure — tutte nel vocabolario «campione letto» / diagnostica)*
- Righe lette nel campione *(cumulo fetch nella sessione preview)*.
- Pagine lette.
- Righe sample mostrate nella lista *(≤ costante UI, es. 15)*.
- `orphanCount`.
- `invalidTypeCount`.
- `invalidEffectiveAtCount` *(timestamp non valido / non confrontabile)*.
- Stato **`truncated` / capped** *(boolean + messaggio dedicato se vero)*.
- **`stoppedReason`** *(enum summary)* — in UI principale solo se utile; dettaglio completo preferibilmente nel disclosure DEBUG.

**Non mostrare mai come metriche user-facing principali** *(vietato nella card primaria)*:
- «Totale prezzi nel cloud» / «Totale storico remoto» *(totale assoluto non noto senza query dedicata — fuori scope)*.
- «Stato sincronizzazione» / linguaggio equivalente.
- «Numero definitivo di differenze» / diff globale rispetto a SwiftData *(TASK-049+)*.

**Localizzazione e copy** *(EXECUTION futura)*
- Nuove stringhe: chiavi e stile allineati alle **`Localizable.strings`** esistenti *(prefissi/naming coerenti con altre card Supabase/Debug)*.
- Lingue obbligatorie: **IT / EN / ES / ZH-Hans**.
- Traduzione incerta → copy **semplice e neutro**, non jargon tecnico.
- Evitare in **tutte** le lingue termini tipo **sync**, **merge**, **apply**, **push**, **import** *(e equivalenti idiomatici troppo vicini al sync)*.
- Tono: **diagnostico ma curato**, visivamente coerente con le altre card Supabase/Debug dell’app.

**Messaggi di stato** *(evitare termini: sync, applica, importa, salva, push, merge)*
- **Success** quando il fetch termina sotto i cap con fine naturale dataset: «**Anteprima caricata.**»
- **Capped / truncated**: «**Limite anteprima raggiunto: potrebbero esistere altri prezzi non mostrati.**»
- **Idle / hint**: richiamare che è un campione (coerente con sottotitolo).

**Stati UI**
| Stato | Comportamento |
|-------|----------------|
| **idle** | Card visibile; CTA primaria attiva; sottotitolo campione limitato; metriche eventualmente «Campione letto: … righe» (**non** «totale cloud»). |
| **loading** | Righe/pagine accumulate; CTA primaria disabilitata; opzionale «Annulla» se implementazione semplice. |
| **success** | Messaggio «Anteprima caricata.» + disclosure/sample; CTA secondaria **solo** «Aggiorna preview». |
| **success (vuoto)** | Fetch terminato correttamente con **`totalFetched == 0`**: **non** è errore; **`truncated == false`**; messaggio consigliato: «**Nessuno storico prezzi trovato nel campione cloud.**» — **nessun** warning automatico obbligatorio. |
| **partial / capped** | Banner «Limite anteprima raggiunto…» + **`truncated`**; stessa CTA secondaria **solo** «Aggiorna preview». |
| **partial (errore dopo pagine)** | Se **≥1 pagina** letta con dati accumulati **coerenti** e poi errore rete/decode: stato **partial** dedicato — messaggio che la preview è **incompleta**; **non** promuovere a **success** pieno; **nessuna** apply/write SwiftData/remota *(invariato Slice A)*. |
| **failed** | Messaggio **breve** all’utente; dettaglio tecnico solo se già pattern DEBUG nel progetto *(collapsible)*. |
| **cancelled** | Utente ha annullato durante fetch: mostrare **risultato parziale** *(righe già lette)* + stato «Annullato» **senza** side-effect persistence; coerente con § *Matrice errori*. |

**Lista campione (sample)**
- Mostrare **al massimo 10–20 righe** *(costante UI, es. 15 default)* — **mai** l’intero buffer preview in lista scrollabile lunga.
- **Privacy UI**: non mostrare **barcode** o **nome prodotto** completi nelle sample row **salvo** il progetto abbia già uno **pattern consolidato** sulla stessa schermata per mostrarli interi *(preferenza: no)* — usare **troncamento** *(es. barcode abbreviato / nome max **24–32** caratteri con ellissi)*.
- Le **note remote** (`note`): **non** mostrarle nella preview TASK-048 *(solo conteggio eventuale in summary tecnico se serve — senza testo)*.
- **UUID** remoti (`id` riga, `product_id`): in UI **solo abbreviati** se necessari *(primi segmenti + `…`)*; dettaglio full solo in log vietato comunque § Privacy.
- Ogni riga sample include:
  - **Tipo** prezzo **normalizzato** *(Acquisto/Vendita o purchase/retail — coerente localizzazione)*;
  - **Prezzo** *(formato leggibile)*;
  - **`effectiveAt`**: mostrare **raw + canonico** se diverso *(es. due colonne o sottotitolo)* — utile in DEBUG;
  - **Prodotto risoluito**: etichetta **troncata** se join tramite `Product.remoteID == product_id`;
  - **Badge orphan** se nessun `Product` locale con quel `remoteID`.

**CTA vietate**
- Nessuna «Applica», «Sincronizza prezzi», «Push», «Salva sul cloud», «Merge».

### Privacy e logging

**Gate EXECUTION**
- Log **privacy-safe** solo canali esistenti o `Logger` con livelli appropriati; **mai** log di audit contenenti payload completi di risposta Supabase.
- **Non loggare**: barcode **completi**, nomi prodotto **completi**, note **complete**, stringhe `effective_at` **lunghe** rilevanti PII, né JSON interi di riga.
- **Ammesso** in log DEBUG: **contegi** (righe, pagine, orphan, invalid), **codici errore**, **UUID troncati** *(primi 8 char + `…`)*, **hash** opzionale di chiave solo se necessario per dedupe diagnostico.
- **UI utente**: messaggi errore **sintetici**; **dettaglio tecnico** (codice HTTP, snippet sanitizzato) solo in sezione DEBUG espandibile se il progetto già usa questo pattern altrove — non introdurre popup tecnici invadenti.

**Privacy anche nella UI sample** *(oltre ai log)* — vedi § *Lista campione* sopra: troncamento barcode/nome, **no** note, UUID abbreviati.

### Persistenza preview *(decisione esplicita — TASK-048)*

- **TASK-048 non deve** persistere la preview in **SwiftData**, **`UserDefaults`**, **file cache** né nella **baseline/fingerprint** TASK-043.
- La preview resta **solo stato in memoria** della View / ViewModel DEBUG *(volatile)*.
- Chiusura app o cambio sessione → perdita accettabile senza recovery obbligatoria.
- Baseline/fingerprint **per storico prezzi** restano **fuori scope** → **TASK-049+** se mai richiesti.

### Concorrenza prevista *(EXECUTION futura)*

- Fetch **async** con **Task** cancellabile *(timeout/cooperative cancellation)*.
- Aggiornamenti di stato UI **solo su `MainActor`**.
- **Nessuna** mutation SwiftData nel task; lettura SwiftData **solo** per costruire lookup **read-only** `Product.remoteID → stringa display troncata`.
- Se l’utente **esce da `OptionsView`** durante il fetch: implementazione deve **annullare** o **ignorare** risultati tardivi in modo sicuro *(no aggiornamenti UI su view distrutta; no side-effect persistence)*.
- **Sessione Supabase / auth**: la preview è **legata alla sessione corrente**. Su **logout**, **cambio account**, **cambio sessione** o **invalidazione client auth**, il summary/caricamento precedente va considerato **stale**: **rimuovere da UI** o **ignorare** risultati tardivi — il summary **non** deve sopravvivere a un cambio utente; **nessuna** preview riutilizzata tra utenti diversi. Resta **solo comportamento UI volatile** § *Persistenza preview*.
- Stati terminali possibili: **idle**, **loading**, **success**, **capped/partial**, **failed**, **cancelled**.
- **Nessun** background task / refresh silenzioso / polling: solo azione utente esplicita sulla card DEBUG.

### Riutilizzo codice e anti-duplicazione *(vincoli EXECUTION)*

Prima di aggiungere query o normalizzatori nuovi, verificare riuso di:
- `SupabaseInventoryService.fetchProductPrices` / **`fetchProductPricesPage`**
- `RemoteInventoryProductPriceRow`
- `SupabasePullPreviewNormalizer` *(tipo / effectiveAt string)*
- `PriceHistoryLogicalKey` *(se serve allineamento concettuale con diff catalogo)*

**Preferenza**: **wrapper/adapter read-only** sottile (es. `SupabaseProductPricePreviewBuilder` / servizio dedicato) che:
- **Input**: client o `SupabaseInventoryService` esistente + **lookup in-memory** `remoteID → (barcode o etichetta display troncata)` derivato da snapshot **già letto** *(fetch SwiftData read-only per sola costruzione dizionario — OK se **nessuna** mutazione)* oppure da DTO passato dal caller.
- **Output**: `ProductPricePreviewSummary` + array limitato di **`ProductPricePreviewSampleRow`** per UI.
- **Divieto**: il modulo preview **non** deve dipendere da **`SupabasePullApplyService`** *(no coupling apply)*.
- **Divieto**: **nessun** uso di `ModelContext` **per insert/update/delete** `ProductPrice` nel percorso TASK-048; lettura contesto solo se indispensabile per lookup **read-only** e isolata nel wrapper/documentata.

### Mapping SwiftData ↔ Supabase *(preview read-only)*

- **`product_id`** remoto ↔ **`Product.remoteID`** locale (UUID); **nessun** join barcode-only dalla sola riga prezzo.
- **`type`**: `PURCHASE`/`RETAIL` → **`SupabasePullPreviewNormalizer.normalizedPriceType`** *(fonte unica)*.
- **`effective_at` / `created_at`**: **string** nel path TASK-048; merge contro storico SwiftData = **TASK-049+**.
- **`price`**: `Double`; tolleranza display coerente con preview catalogo ove riusata.
- **Senza `remoteID` locale**: righe con quel `product_id` ⇒ **orphan** / statistiche.
- **Duplicati**: dedupe difensivo `(productID, typeNorm, effectiveAtRaw)` se necessario.
- **Ordinamento sample**: `effective_at` desc se confrontabile; altrimenti ordinamento stabile su `id` remoto riga.
- **Timezone**: non reinterpretare stringhe con fuso arbitrario; UI mostra raw + eventuale canonica solo da normalizer documentato.

### Matrice errori *(UI / log / severità)*

| Condizione | UI (user-facing) | Log / diagnostica | Severità |
|------------|------------------|-------------------|----------|
| Fetch OK con **0 righe** *(campione vuoto)* | «Nessuno storico prezzi trovato nel campione cloud.» | Solo conteggi zero | **Success vuoto** — **non** errore; **`truncated == false`**; **nessun** warning automatico richiesto |
| Non autenticato / sessione assente | «Accedi a Supabase per continuare» *(allineato copy TASK-038)* | Conteggio stato auth; **no** token | **Bloccante** *(fetch non parte)* |
| Logout / cambio account / sessione invalidata *(durante o dopo preview)* | Summary **rimosso** o ignorato; **nessuna** preview stale visibile | Reset stato preview *(solo memoria)* | **Informativo** — coerente § *Concorrenza* / *Persistenza* |
| RLS / 401 / 403 | «Permessi insufficienti o sessione non valida» | Codice errore sanitizzato; UUID tenant opzionale troncato | **Bloccante** |
| Rete offline / timeout *(prima di aver letto pagine utili)* | «Connessione non disponibile» / «Timeout» breve | Tipo errore + durata ms; no payload | **Bloccante** *(failed)* |
| Errore rete/decode **dopo ≥1 pagina** con accumulo coerente | Messaggio che l’**anteprima è incompleta** *(partial)*; mostrare metriche «campione letto» fino al punto di stop | Pagina/stop reason; **no** payload PII | **Partial** — **non** mappare a success pieno; **nessuna** write |
| Decode error (DTO) | «Dati ricevuti non leggibili» | Campo chiave fallito **senza** valore raw completo | **Bloccante** sessione o **partial** se skip-riga documentato — preferire **fail della pagina** con retry |
| `type` non valido | *(Riga in lista)* badge warning / esclusa da confronto | Contatore `invalidType` incrementato | **Warning** riga; non crash |
| `effectiveAt` non valido / non confrontabile | Come sopra | Contatore `invalidEffectiveAt` | **Warning** |
| `product_id` senza `Product.local` con stesso `remoteID` | Badge **orphan** sulla sample row | `orphanCount++`; log solo conteggio | **Warning** informativo |
| Cap `maxRows` / `maxPages` raggiunto | «Limite anteprima raggiunto: potrebbero esistere altri prezzi non mostrati.» + **`truncated`** | Log: stop reason = cap | **Informativo** *(success/partial capped)* — non errore |
| Cancellazione utente / task cancelled | «Anteprima annullata» + mostra parziale | Log: cancelled at page N, rows M | **Cancelled** — zero side-effect persistenza |

### Obiettivo execution *(dettaglio tecnico)*
1. Implementare il wrapper sopra con costanti **`pageSize=200`**, **`maxRows=1000`**, **`maxPages=5`** *(costanti nominate, override solo test)* e **`order` remoto stabile** § *Ordinamento remoto deterministico*.
2. Righe campione ordinate per display *(vedi § Mapping)*; summary distingue sempre **campione letto** vs totale remoto **sconosciuto**.
3. Verificare gate § *Gate schema DDL pre-EXECUTION* leggendo migration reale.
4. Test § *Matrice test XCTest* + grep § *Comandi/grep anti-scope*.

### File probabilmente coinvolti *(EXECUTION)*
| File | Ruolo |
|------|--------|
| `SupabaseInventoryService.swift` | Riuso **`fetchProductPricesPage`**; evitare duplicazione HTTP |
| Nuovo file wrapper preview *(consigliato)* | Cap/truncated/orphan/warning + summary sendable |
| `OptionsView.swift` (+ eventuale micro-VM DEBUG) | Card § UX DEBUG |
| `SupabasePullPreviewNormalizer.swift` *(o estensione file esistente)* | Un solo posto per normalizzazione tipo/stringhe |
| `Localizable.strings` *(IT / EN / ES / ZH-Hans)* | Titoli, badge, stati, CTA |
| `iOSMerchandiseControlTests/*Tests.swift` | XCTest puri |

**Esplicitamente da NON modificare** salvo bug bloccante preview *(documentare in review)*:
- `SupabasePullApplyService` — **nessuna** nuova dipendenza inversa dal preview service; **nessun** side-effect `ProductPrice`.

### Modelli / DTO previsti *(proposta)*
- **`ProductPricePreviewSampleRow`**: dati per UI lista (tipo norm, price, effectiveRaw, effectiveCanonical?, display prodotto troncato, `isOrphan`, optional `remoteRowID` troncato in UI).
- **`ProductPricePreviewSummary`**: `totalFetched`, `pagesFetched`, `truncated`, `orphanCount`, `invalidTypeCount`, `invalidEffectiveAtCount`, `stoppedReason` *(enum: naturalEnd, maxRows, maxPages, error, cancelled)*, `samples: [ProductPricePreviewSampleRow]` *(max 15–20)* — in UI i conteggi devono essere etichettati come **campione letto** / righe caricate nella sessione, **mai** come «totale prezzi nel cloud» *(totale remoto non noto senza count/query dedicata — fuori scope TASK-048)*.

### Gate anti-scrittura remota *(CA obbligatori)*
- Grep / review: **nessuna** chiamata insert/update/delete/RPC verso `inventory_product_prices` o RPC sync nel codice aggiunto.
- UI: **nessuna** CTA «push» / «sync» / «merge» / «importa» / «salva» / «applica» prezzi.

### Gate anti-apply locale *(Slice A)*
- **Nessun** `ModelContext.insert(ProductPrice)` / `delete` / mutazione relazione `product` **nel ramo** TASK-048.
- Se si riusa codice condiviso con apply: **`#if DEBUG`** o percorsi compilatore che **non** invocano mai apply da questo entrypoint *(documentato nel diff)*.

### Matrice test XCTest prevista *(TASK-048)*

| ID | Tipo | Descrizione |
|----|------|-------------|
| **T48-01** | STATIC | Decodifica JSON → `RemoteInventoryProductPriceRow` *(campi tipici)* |
| **T48-02** | STATIC | `normalizedPriceType`: `PURCHASE`, `RETAIL`, case mixed; invalid → non crash |
| **T48-03** | STATIC | Dedupe difensivo: due pagine sintetiche con stessa chiave logica `(productID, typeNorm, effectiveAtRaw)` → una sola riga nel modello merged |
| **T48-04** | STATIC | Orphan: `product_id` senza match in dizionario `remoteID → …` → `isOrphan` / count |
| **T48-05** | STATIC | Prodotto locale senza `remoteID`: non entra nel dizionario join → righe remote possono risultare orphan |
| **T48-06** | STATIC | Cap raggiunto: merge sintetico **`totalFetched >= maxRows`** ⇒ **`truncated == true`** |
| **T48-07** | STATIC | Sotto cap: ultima pagina `< pageSize` ⇒ **`truncated == false`** |
| **T48-08** | STATIC | Pagina vuota finale ⇒ stop; **`truncated == false`**; `pagesFetched` corretto |
| **T48-09** | STATIC | Due pagine senza duplicati ⇒ conteggio righe = sum |
| **T48-10** | STATIC | Type non valido ⇒ warning counter / esclusione sample; **no** fatal |
| **T48-11** | STATIC | `effectiveAt` non normalizzabile ⇒ warning; **no** fatal |
| **T48-12** | STATIC / ASYNC | Cancellazione durante fetch *(mock)* ⇒ stato **cancelled** o partial + `stoppedReason`; **nessun** insert `ProductPrice` |
| **T48-13** | REGRESSION | Grep statico o test infrastruttura: **nessun** riferimento a `record_sync_event` nel modulo preview |
| **T48-14** | REGRESSION | Nessuna API write verso tabella prezzi *(mock client)* |
| **T48-15** | BUILD | Progetto compila dopo modifiche |
| **T48-16** | REGRESSION | Suite mirata TASK-039/040/043/044/047 non rotta |
| **T48-17** | STATIC / CONTRACT | La query pianificata include **`order`** coerente con § *Ordinamento remoto* *(assert su builder URL/param o snapshot stringa documentata)* |

*(SIM/manuali: solo su user override — non nel contratto base.)*

### Comandi / grep anti-scope *(review EXECUTION / REVIEW — **non eseguire in PLANNING**)*

Da pianificare ed eseguire **dopo** modifiche Swift, prima della chiusura review:

```bash
# Eseguire dalla root del repo iOS; adattare percorsi se diversi.
rg "record_sync_event" iOSMerchandiseControl iOSMerchandiseControlTests --glob "*.swift"
rg "sync_events" iOSMerchandiseControl iOSMerchandiseControlTests --glob "*.swift"
rg "inventory_product_prices" iOSMerchandiseControl --glob "*.swift"
rg -n "upsert|\\.insert\\(|\\.update\\(|\\.delete\\(" iOSMerchandiseControl --glob "Supabase*.swift"
# Review: `git diff --name-only` → per ogni `.swift` toccato, verificare assenza di insert/delete SwiftData su ProductPrice nel flusso preview.
# Migrazioni / Android: nessun file toccato nel diff TASK-048
git diff --name-only -- "*.sql" "supabase/**" "**/migrations/**"
git diff --name-only | rg "\\.kt$" || true
```

Interpretazione attesa: **zero** nuove write/sync non giustificate; **nessun** diff su SQL migration o sorgenti Android nel perimetro TASK-048.

### Rischi regressione
- **Performance DEBUG**: mitigato dai cap **200 / 1000 / 5**; evitare richieste extra oltre il contratto senza nuovo task.
- **Confusione UX** → sottotitolo fisso «Anteprima limitata…», messaggi «Anteprima caricata.» / «Limite anteprima raggiunto…», metriche come **campione letto** (non totale remoto).
- **Drift normalizer** tra preview prezzi e `SupabasePullPreviewService` → helper condiviso **minimo** (§ Riutilizzo).
- **Privacy**: logging verboso per errore decode — mitigare § *Privacy e logging*.
- **Segreti**: `SupabaseConfig.plist` — policy invariata *(gitignore)*.

### Check finali *(EXECUTION — dopo modifiche Swift)*

| Check | Note |
|-------|------|
| Build Debug | `xcodebuild -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build` *(adattare destination allo scheme corrente)* |
| Build Release | Stesso scheme, `-configuration Release` |
| XCTest | `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16'` *(o dest già usato in TASK-047)* |
| `git diff --check` | No whitespace errors |
| Grep anti-scope | Eseguire § *Comandi / grep anti-scope* + verifica assenza write `inventory_product_prices` |

*(In **PLANNING** questo turno: **nessun** comando obbligatorio eseguito.)*

---

## Criteri di accettazione *(CA48)*

### Planning *(refinement accumulati — ultimo turno documentale)*
- [x] **CA48-P01** — File task presente con obiettivo, stato iOS, gap, slice **A**, confini TASK-049.
- [x] **CA48-P02** — Riferimenti Supabase basati su **TASK-033/migrazioni**, senza inventare colonne.
- [x] **CA48-P03** — Motivazioni esplicite: no sync_events/outbox/realtime; read-only prima di push.
- [x] **CA48-P04** — Lista file/test pianificati + gate anti-write remota e anti-apply locale.
- [x] **CA48-P05** — `MASTER-PLAN` aggiornato: progetto **ACTIVE**, task attivo **TASK-048** con fase/stato coerenti nel tracking *(post-promozione **EXECUTION** 2026-05-06)*.
- [x] **CA48-P06** — Cap/paginazione **numerici** definiti (`pageSize` 200, `maxRows` 1000, `maxPages` 5, stop immediato, `truncated`).
- [x] **CA48-P07** — UX DEBUG **OptionsView** concretizzata (card, CTA «Carica preview» + **solo** «Aggiorna preview», stati, sample 10–20, badge orphan).
- [x] **CA48-P08** — Privacy logging + **privacy UI sample**, matrice errori, riuso codice senza dipendenza da `SupabasePullApplyService`.
- [x] **CA48-P09** — Matrice test **T48-01…T48-17** + grep anti-scope documentati *(non eseguiti in PLANNING)*.
- [x] **CA48-P10** — Ordinamento remoto **deterministico** obbligatorio prima di `range`; vietato paginare senza `order`.
- [x] **CA48-P11** — **Debug gate**: card solo sezione DEBUG esistente; nessun nuovo feature flag; non promuovere a feature principale.
- [x] **CA48-P12** — Copy UX esplicito § *Componenti visivi e copy UX* (evitare sync/applica/importa/salva/push/merge).
- [x] **CA48-P13** — § *Concorrenza prevista* (async cancellabile, MainActor, leave OptionsView safe).
- [x] **CA48-P14** — Chiarezza preview vs diff/apply completo; § *Gate schema DDL pre-EXECUTION*.
- [x] **CA48-P15** — Preview definita come **volatile** / **session-scoped**: **zero** persistenza *(SwiftData/UserDefaults/file/baseline)*; reset su logout/cambio sessione pianificato § *Persistenza* / *Concorrenza*.

### Execution *(CA verificabili — durante EXECUTION)*

Autorizzazione alla fase **EXECUTION**: **concessa** *(override utente; transizione documentale **PLANNING → EXECUTION** registrata in questo turno)*.
- [x] **CA48-E01** — Build Debug + Release PASS.
- [x] **CA48-E02** — XCTest **T48-01…T48-17** *(o sottoinsieme concordato)* + regressione mirata PASS.
- [x] **CA48-E03** — UI DEBUG in **OptionsView** sezione esistente: copy § UX + **solo** CTA secondaria «Aggiorna preview»; auth gate come TASK-038; **Debug gate** rispettato.
- [x] **CA48-E04** — Costanti **`pageSize=200`**, **`maxRows=1000`**, **`maxPages=5`**; **`order` stabile** documentato; **`truncated`** corretto; stop immediato ai cap; **nessun** full-download.
- [x] **CA48-E05** — **Nessuna** scrittura remota `inventory_product_prices`; grep/review PASS.
- [x] **CA48-E06** — **Nessuna** mutazione SwiftData `ProductPrice`; grep/review PASS.
- [x] **CA48-E07** — Localizzazioni **IT / EN / ES / ZH-Hans** per nuove stringhe UI *(inclusi copy pianificati)*, conformi § *Localizzazione e copy*.
- [x] **CA48-E08** — Nessun `record_sync_event`, `sync_events`, outbox, tombstone outbound, realtime/background nel diff.
- [x] **CA48-E09** — **cancelled** + leave view: sicuro; log privacy-safe § *Privacy*.
- [x] **CA48-E10** — Sample UI **≤20** righe; troncamento barcode/nome; **no** note remote in lista; nessun log PII completo.
- [x] **CA48-E11** — Evidenza lettura **migration reale** `inventory_product_prices` nel repo Supabase prima del merge EXECUTION *(nota/commit message o checklist review)*.
- [x] **CA48-E12** — Presentazione conteggi come **campione letto**, mai come totale remoto assoluto.
- [x] **CA48-E13** — Preview **reset** / **ignorata** su logout, cambio account o sessione invalidata; **nessuna** cache persistente creata per la preview prezzi TASK-048.

---

## Anti-scope checklist *(ripetibile in EXECUTION)*
- [x] Nessun SQL/migration/RLS/RPC nuovo o modificato nel repo Supabase *(verifica anche `git diff` su `*.sql` / `supabase/`)*.
- [x] Nessun push manual/automatic ProductPrice
- [x] Nessun apply locale ProductPrice / nessun `insert(ProductPrice)` nel flusso TASK-048
- [x] Nessun `record_sync_event`, tabella `sync_events`, outbox, realtime/background
- [x] Nessun `service_role` / segreto tracciato
- [x] Nessuna modifica Android / `.kt`
- [x] Nessun cleanup delete remoto / tombstone outbound
- [x] Nessuna persistenza preview prezzi in SwiftData / UserDefaults / file / baseline TASK-048 § *Persistenza preview*
- [x] Eseguiti i comandi § *Comandi / grep anti-scope* in review prima di dichiarare EXECUTION completata

---

## Decisioni

| # | Decisione | Motivazione | Stato |
|---|-----------|-------------|-------|
| **D48-01** | Slice **A** read-only | Riduce rischio dati SwiftData e cloud; allinea a roadmap «preview prima di merge» | attiva |
| **D48-02** | Join prezzo ↔ prodotto tramite **`Product.remoteID`** | Coerente TASK-040 e FK Supabase `product_id` | attiva |
| **D48-03** | TASK-049 per apply `ProductPrice` | Separazione netta review e gate utente | attiva |
| **D48-04** | Non introdurre `remoteID` su `ProductPrice` SwiftData in TASK-048 | Complessità migration SwiftData non necessaria per read-only; dedupe cloud usa `id` remoto nel DTO preview | attiva *(rivalutare in TASK-049)* |
| **D48-05** | UX: card compatta + disclosure in **OptionsView** DEBUG | Diagnostica chiara senza modal/tab nuove; coerenza TASK-043/044 | attiva |
| **D48-06** | Cap numerici: **200 / 1000 / 5** | Bilanciamento UX/rete/sicurezza; full storico = TASK-049+ | attiva |
| **D48-07** | Preview service **senza** dipendenza da `SupabasePullApplyService` | Evita accoppiamento apply/read; testabilità | attiva |
| **D48-08** | CTA secondaria **solo** «Aggiorna preview» | Evita percezione sync/download progressivo; paginazione manuale = TASK-049+ | attiva |
| **D48-09** | Ordine remoto **stabile obbligatorio** prima di `range` | Anti duplicate/skip tra pagine | attiva |
| **D48-10** | Gate schema: migration reale prima di EXECUTION | TASK-033 può divergere dal DDL effettivo | attiva |
| **D48-11** | Preview **volatile** e **session-scoped** | Evita leakage tra account; evita baseline/cache prematura su storico prezzi; mantiene TASK-048 **read-only** e diagnostico | attiva |

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

- **Stato execution (2026-05-06):** **COMPLETATA — handoff a REVIEW**. Implementata Slice A read-only; nessuna chiusura DONE.

### Gate schema DDL Supabase

- **Repo letto:** `/Users/minxiang/Desktop/MerchandiseControlSupabase`.
- **Migration tabella letta:** `supabase/migrations/20260417200000_task016_inventory_product_prices.sql`.
- **Migration policy letta:** `supabase/migrations/20260421120000_task038_restrict_authenticated_delete_inventory.sql`.
- **DDL effettivo verificato:**
  - `id uuid PRIMARY KEY`
  - `owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`
  - `product_id uuid NOT NULL REFERENCES public.inventory_products(id) ON DELETE CASCADE`
  - `type text NOT NULL`
  - `price double precision NOT NULL`
  - `effective_at text NOT NULL`
  - `source text`
  - `note text`
  - `created_at text NOT NULL`
  - `CHECK (type IN ('PURCHASE', 'RETAIL'))`
  - `UNIQUE (owner_user_id, product_id, type, effective_at)`
  - index su `(owner_user_id, product_id)`
  - RLS abilitata; policy owner-scoped create/read/update/delete nella migration 016; migration 038 revoca la delete policy client-side / `authenticated`.
- **Esito gate:** ✅ **verde**. Nessun drift reale rispetto a TASK-048/TASK-033; nessuna modifica SQL/RLS/RPC/migration effettuata.

### Audit riuso iOS

- Letti prima della modifica: `Models.swift`, `SupabaseInventoryDTOs.swift`, `SupabaseInventoryService.swift`, `SupabasePullPreviewService.swift`, `SupabasePullPreviewModels.swift`, `SwiftDataInventorySnapshotService.swift`, `SupabasePullApplyService.swift`, `OptionsView.swift`, localizzazioni IT/EN/ES/ZH-Hans e test Supabase esistenti.
- Riusati: `RemoteInventoryProductPriceRow`, `SupabasePullPreviewNormalizer.normalizedPriceType`, pattern debug `OptionsView`, `Product.remoteID`.
- Verificato che `fetchProductPricesPage` esisteva ma ordinava solo per `id`; per TASK-048 è stato aggiunto un fetch dedicato read-only con ordine stabile multi-colonna.

### Modifiche implementate

- `iOSMerchandiseControl/SupabaseInventoryService.swift`
  - Aggiunto `productPriceStablePageOrderColumns = ["product_id", "type", "effective_at", "id"]`.
  - Aggiunto `fetchProductPricesPreviewPage(from:to:)`, read-only `select` su `inventory_product_prices`, con `.order("product_id")`, `.order("type")`, `.order("effective_at")`, `.order("id")` prima di `range`.
  - Nessuna insert/update/delete/upsert su `inventory_product_prices`.
- `iOSMerchandiseControl/SupabaseProductPricePreviewService.swift`
  - Nuovo wrapper testabile read-only con `pageSize=200`, `maxRows=1000`, `maxPages=5`, `sampleLimit=15` e hard cap UI `20`.
  - Output: `ProductPricePreviewSummary`, `ProductPricePreviewSampleRow`, stato UI volatile.
  - Stop: pagina vuota, pagina parziale, cap righe, cap pagine, errore, cancellazione.
  - `truncated == true` solo su `maxRows` / `maxPages`.
  - Lookup read-only `Product.remoteID -> display troncato`; prodotti locali senza `remoteID` esclusi.
  - Normalizzazione tipo tramite normalizer esistente; warning counter per type/effectiveAt invalidi; orphan counter; dedupe difensivo tra pagine.
  - Nessuna dipendenza da `SupabasePullApplyService`; nessuna persistenza; nessun `ModelContext.insert(ProductPrice)`.
- `iOSMerchandiseControl/OptionsView.swift`
  - Aggiunta card compatta DEBUG nella sezione Supabase/Debug esistente: titolo “Storico prezzi cloud”, badge “Sola lettura”, copy campione limitato, CTA iniziale “Carica preview” e dopo risultato solo “Aggiorna preview”.
  - Disclosure per metriche e sample; sample max 15; note remote non mostrate; prodotto/UUID abbreviati.
  - Fetch cancellabile; update UI su `MainActor`; risultati tardivi ignorati tramite request id; reset/ignore su uscita view, logout, cambio account/sessione.
  - Nessuna schermata/tab/sheet nuova; nessuna CTA apply/push/merge/import.
- Localizzazioni aggiornate in `it`, `en`, `es`, `zh-Hans`.
- Test aggiunti/aggiornati:
  - `iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests.swift`
  - `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`

### Check eseguiti

- ✅ **Build Debug compila** — `xcodebuild -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,id=423B9CA2-9C81-4850-898A-AE064A3A1C09' build` → PASS.
- ✅ **Build Release compila** — stesso scheme/destination con `-configuration Release` → PASS.
- ✅ **XCTest mirati TASK-048** — `SupabaseProductPricePreviewServiceTests` + coverage localizzazioni TASK-048 → PASS.
- ✅ **XCTest completo** — `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,id=423B9CA2-9C81-4850-898A-AE064A3A1C09'` → PASS finale.
- ✅ **Nessun warning nuovo introdotto verificabile** — log Debug/Release senza warning Swift TASK-048; unico warning visto in build Debug/Release prima dei test finali è toolchain `appintentsmetadataprocessor` “No AppIntents.framework dependency found”. Log XCTest completo finale: nessun `warning:` / `error:` rilevato.
- ✅ **Localizable.strings validi** — `plutil -lint` su IT/EN/ES/ZH-Hans → OK.
- ✅ **`git diff --check`** → PASS.
- ✅ **Grep anti-scope**:
  - `rg "record_sync_event" iOSMerchandiseControl iOSMerchandiseControlTests --glob "*.swift"` → zero match.
  - `rg "sync_events" iOSMerchandiseControl iOSMerchandiseControlTests --glob "*.swift"` → zero match.
  - `rg "inventory_product_prices" iOSMerchandiseControl --glob "*.swift"` → match solo su preview/pull read path (`SupabasePullPreviewService`, `SupabaseInventoryService`); nessuna write prezzi.
  - `rg -n "upsert|\\.insert\\(|\\.update\\(|\\.delete\\(" iOSMerchandiseControl --glob "Supabase*.swift"` → match su codice pre-esistente catalogo/baseline/apply e insert in set locali; nessun nuovo write path `inventory_product_prices`, nessun `ProductPrice` insert nel nuovo flusso.
  - `git diff --name-only -- "*.sql" "supabase/**" "**/migrations/**"` → zero file.
  - `git diff --name-only | rg "\\.kt$" || true` → zero file.
- ⚠️ **Simulator/manuale UI** — non eseguito: non richiesto esplicitamente dal task/utente; task UI verificato via build, test, static review e copy/localizzazioni.

### Rischi rimasti / note review

- La preview resta volutamente un campione capped: non indica totale remoto assoluto, stato completo o diff globale.
- `effective_at` viene validato con parser canonico stretto `yyyy-MM-dd HH:mm:ss` UTC; valori diversi sono warning read-only e non crash.
- Le write matchate dal grep sono codice esistente fuori dal path TASK-048; reviewer può confermare nel diff che il nuovo servizio non invoca apply né write Supabase.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
> **User override 2026-05-06:** la review e la chiusura sono state richieste esplicitamente a Codex. Impatto workflow: Codex ha operato come **Reviewer+Fixer** invece del reviewer Claude, mantenendo invariati i guardrail Slice A read-only e documentando fix/check in questa sezione.

- **Esito review:** ✅ **APPROVED_FIXED_DIRECTLY / DONE**.
- **Schema gate repo-grounded:** riletto `/Users/minxiang/Desktop/MerchandiseControlSupabase`; DDL reale `20260417200000_task016_inventory_product_prices.sql` coerente con iOS (`id`, `owner_user_id`, `product_id`, `type`, `price`, `effective_at`, `created_at`, `source`, `note`, CHECK `PURCHASE/RETAIL`, unique owner/product/type/effective, RLS owner-scoped). Migration `20260421120000_task038_restrict_authenticated_delete_inventory.sql` conferma delete client restricted. Nessuna modifica SQL/Supabase.
- **Supabase Swift multi-order:** verificato nel checkout locale pinato `supabase-swift v2.46.0` (`PostgrestTransformBuilder.order`) che chiamate `.order(...)` multiple vengono concatenate nello stesso parametro `order`; ordine preview `product_id,type,effective_at,id` valido prima di `range`.
- **Correttezza funzionale:** preview read-only, cap `200 / 1000 / 5`, `sampleLimit=15`, hard cap `<=20`, stop page empty/partial/maxRows/maxPages/error/cancel, `truncated` true solo per maxRows/maxPages, dedupe difensivo stabile, invalid type/effectiveAt come warning, orphan lookup tramite `Product.remoteID`, prodotti senza `remoteID` esclusi.
- **Concorrenza/sessione:** UI aggiornata su `MainActor`; task cancellabile; risultati tardivi ignorati via `requestID`; reset su logout/cambio account/sessione e su uscita `OptionsView`; nessuna cache o persistenza preview.
- **UI/UX OptionsView:** card compatta nella sezione Supabase DEBUG esistente; copy “Anteprima limitata” e metriche “campione”; CTA iniziale “Carica preview”, dopo risultato solo “Aggiorna preview”; nessuna sheet/tab/modal; no termini apply/push/sync/import/merge; sample limitato, prodotto/UUID abbreviati, note remote non mostrate.
- **Anti-scope:** nessun push/apply `ProductPrice`, nessun insert/update/delete SwiftData `ProductPrice` nel flusso TASK-048, nessuna write remota `inventory_product_prices`, nessun `record_sync_event`, `sync_events`, outbox, realtime/background, migration SQL/RLS/RPC, Android, UserDefaults/file/baseline preview.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

### Fix mirati applicati in REVIEW *(2026-05-06)*

- `OptionsView.swift`: su `onDisappear` ora viene chiamato `resetProductPricePreview()` invece di ignorare soltanto i risultati; evita stato `loading` stale al rientro nella schermata.
- `SupabaseInventoryService.swift`: la query dedicata `fetchProductPricesPreviewPage` non seleziona piu' `source`/`note`, colonne opzionali non usate dalla preview UI; riduce payload e superficie privacy, mantenendo DTO compatibile.
- Localizzazioni: copy IT/ES/EN rifinito per naturalezza e badge orphan meno tecnico; ES/IT `common.yes` accentato; nessun termine di write/sync nelle chiavi `pricePreview`.
- `SupabaseProductPricePreviewServiceTests.swift`: aggiunti test per partial error dopo pagina valida, range inclusivi/off-by-one, cap robusto se il fetcher restituisce troppe righe, sample default/hard cap.
- `LocalizationCoverageTests.swift`: aggiunto test che vieta termini di write/sync/apply/push/import nelle nuove stringhe `options.supabase.pricePreview.*`.

### Check post-fix

- ✅ **Build Debug compila** — `xcodebuild build -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B'` → PASS.
- ✅ **Build Release compila** — stesso comando con `-configuration Release` → PASS.
- ✅ **Nessun warning nuovo introdotto** — build Debug/Release quiet senza warning; full XCTest segnala solo warning toolchain pre-esistente `Metadata extraction skipped. No AppIntents.framework dependency found`.
- ✅ **XCTest mirati TASK-048/localizzazione** — `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests -only-testing:iOSMerchandiseControlTests/LocalizationCoverageTests` su iPhone 16e iOS 26.2 → PASS.
- ✅ **XCTest completo** — `xcodebuild test -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B'` → PASS.
- ✅ **`plutil -lint` localizzazioni** — IT/EN/ES/ZH-Hans → OK.
- ✅ **`git diff --check`** → PASS.
- ✅ **Anti-scope grep/review** — `record_sync_event` e `sync_events` zero match Swift; `inventory_product_prices` solo read path; write Supabase/SwiftData matchate sono pre-esistenti fuori dal nuovo flusso; nessun SQL/migration/Android/UserDefaults/file/baseline preview nel diff.
- ⚠️ **Simulator/manuale UI** — NON ESEGUIBILE / non eseguito per protocollo TASK-048: non richiesto esplicitamente dal task o dall'utente; UI verificata con build, test e review statica.

---

## Handoff

### Handoff — transizione **PLANNING → EXECUTION** *(2026-05-06 — solo documentale)*

- **Refinement planning**: considerato **concluso**; piano **approvato** dall’utente.
- **Azione svolta in questo turno**: **solo** aggiornamento **metadata**, **Handoff**, § **Execution (Codex)** e **`MASTER-PLAN`** — **nessuna** implementazione Swift/UI/test, **nessun** wrapper preview, **nessun** `Localizable.strings`, **nessun** build/test eseguito.
- **Stato task dopo patch**: **ACTIVE / EXECUTION**, **Slice A read-only** **invariata** *(vietati: ProductPrice push/apply, `record_sync_event`, `sync_events`, outbox, realtime/background, tombstone outbound/delete remoto, migration SQL Supabase, Android, cache persistente preview, baseline/fingerprint prezzi TASK-048)*.
- **Oltre questo turno**: **nessuna** «execution automatica» — il **CODEX / Executor** deve iniziare dal **Gate schema DDL** come primo lavoro tecnico reale.

### Handoff → CODEX / Executor *(EXECUTION — primo lavoro tecnico)*

- **Prossima fase**: **EXECUTION** *(implementazione, dopo questo handoff)*.
- **Prossimo agente**: **CODEX / Executor**.
- **Primo step obbligatorio**: **Gate schema DDL** — rileggere la **migration reale** Supabase locale per **`inventory_product_prices`** *(non solo sintesi TASK-033)*; verificare colonne, **RLS**, **CHECK** `type`, **unique**, timestamp/text; se **drift** → **STOP**, aggiornare planning nel file task e **tornare a PLANNING**.
- **Solo dopo** gate DDL verde: audit riuso iOS (`fetchProductPricesPage`, DTO, normalizer, `OptionsView`); poi wrapper read-only; poi UI DEBUG card; poi XCTest + grep anti-scope *(sequenza dettagliata § **Execution (Codex)**)*.

### Handoff → Review *(Claude — dopo handoff tecnico Codex)*

- **Fase successiva:** **REVIEW**.
- **Prossimo agente:** **Claude / Reviewer**.
- **Sintesi handoff:** TASK-048 Slice A read-only implementata e verificata. Gate DDL reale Supabase verde; nessuna modifica SQL/RLS/RPC/backend/Android. Wrapper preview volatile/session-scoped, UI Debug `OptionsView`, localizzazioni e XCTest aggiunti. Nessun push `ProductPrice`, nessuna apply locale `ProductPrice`, nessun `record_sync_event`, nessun `sync_events`, nessuna outbox/realtime/background/cache persistente.
- **File principali modificati/aggiunti:**
  - `iOSMerchandiseControl/SupabaseInventoryService.swift`
  - `iOSMerchandiseControl/SupabaseProductPricePreviewService.swift`
  - `iOSMerchandiseControl/OptionsView.swift`
  - `iOSMerchandiseControl/*/Localizable.strings`
  - `iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests.swift`
  - `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`
- **Verifiche verdi:** Build Debug PASS, Build Release PASS, XCTest mirati PASS, XCTest completo PASS finale, `plutil -lint` localizzazioni PASS, `git diff --check` PASS, grep anti-scope PASS.
- **Da revieware con attenzione:** semantica UX “campione letto” (non totale remoto), ordine Supabase multi-colonna prima di `range`, reset/ignore preview su cambio sessione, assenza di write `inventory_product_prices` e assenza di `ModelContext.insert(ProductPrice)` nel nuovo flusso.
- **Stato finale del task prima della review override:** **ACTIVE / REVIEW**, **non DONE**.

### Handoff — REVIEW override → Chiusura *(2026-05-06)*

- **Reviewer/Fixer:** Codex / Reviewer+Fixer, su istruzione esplicita utente.
- **Esito:** **APPROVED_FIXED_DIRECTLY / DONE**.
- **Fix diretti:** reset preview volatile su uscita view, select preview senza `source/note`, copy/localizzazioni rifinite, test aggiunti per partial error/range/cap/sample/copy.
- **Verifiche finali:** Build Debug PASS, Build Release PASS, XCTest mirati PASS, XCTest completo PASS, `plutil -lint` PASS, `git diff --check` PASS, anti-scope PASS.
- **Stato finale:** **DONE / Chiusura**.

---

## Chiusura

- **Data chiusura:** 2026-05-06.
- **Esito finale:** **DONE / Chiusura** su override utente dopo review completa e fix mirati.
- **Criteri TASK-048:** soddisfatti per Slice A read-only.
- **Confini invariati:** nessun push/apply `ProductPrice`, nessuna write remota `inventory_product_prices`, nessun `record_sync_event`/`sync_events`/outbox/realtime/background, nessuna migration Supabase/SQL/RLS/RPC, nessun Android, nessuna persistenza preview in SwiftData/UserDefaults/file/baseline.
- **Follow-up candidate non attivi:** TASK-049 per eventuale apply locale controllato `ProductPrice`; task futuro separato per ProductPrice push remoto; task futuri separati per `record_sync_event`/outbox/realtime/tombstone outbound.
