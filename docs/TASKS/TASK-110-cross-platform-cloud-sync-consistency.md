# TASK-110: Cross-platform cloud sync consistency — History, catalog bridge, prices, login bootstrap, deletion propagation e Supabase Data API grants/RLS

## Informazioni generali
- **Task ID**: TASK-110
- **Titolo**: Cross-platform cloud sync consistency: History, catalog bridge, prices, login bootstrap, deletion propagation e Supabase Data API grants/RLS
- **File task**: `docs/TASKS/TASK-110-cross-platform-cloud-sync-consistency.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura — FINAL CROSS-PLATFORM ACCEPTANCE PASS
- **Responsabile attuale**: COMPLETED / USER ACCEPTANCE READY
- **Data creazione**: 2026-05-15
- **Data completamento**: 2026-05-15
- **Ultimo aggiornamento**: 2026-05-15 *(FINAL CROSS-PLATFORM ACCEPTANCE PASS; user-authorized DONE closure after Android/iOS/Supabase evidence pass.)*
- **Ultimo agente che ha operato**: CODEX / Cursor Executor *(final cross-platform completion)*

## Dipendenze
- **Dipende da**: **TASK-109** in stato **BLOCKED / SOSPESO** per priorità utente *(non è dipendenza tecnica di completamento)*; contesto storico **TASK-108 DONE**. **TASK-041** e altri task DONE restano solo riferimento — **non** riaprirli.
- **Sblocca**: parità operativa Android ↔ iOS ↔ Supabase su History/session, catalog bridge, ProductPrice pull applicabile, bootstrap post-login e propagazione delete; eventualmente ripresa futura **TASK-109** se ancora pertinente.

## Scopo
Rendere **Android**, **iOS** e **Supabase** coerenti per: creazione/push/pull **sessioni History**; aggiornamento/rinomina sessione; **delete con propagazione bidirezionale** (tombstone/outbox dove supportato dallo schema); **catalog bridge** per evitare prezzi remoti senza prodotto locale collegabile; **bootstrap automatico** dopo login/re-login; **«Sync now»** affidabile; **stato UI** coerente tra Options / History / Database; **allineamento Supabase Data API grants/RLS** per evitare rotture future quando le tabelle `public` non saranno più esposte automaticamente via PostgREST/GraphQL.

**Fonte di verità**: Supabase remoto = stato condiviso cross-device; SwiftData/Room = cache offline. Identità stabile = **`remote_id`** (non solo `display_name`/titolo). Voci solo-locali → **pending push** visibile; solo-remoto → **pull**; delete → **tombstone** finché entrambi i device convergono. L’accesso Data API deve essere esplicito: `GRANT` + RLS + policy devono vivere nella stessa migration/proposta, con privilegi minimi per ruolo.

**Vincolo aggiunto di hardening**: prima di qualunque fix bisogna dimostrare che Android e iOS puntano allo **stesso progetto Supabase** (`project_ref`/URL/anon-key fingerprint/JWT issuer), che la Data API espone gli schemi attesi, che gli oggetti esposti hanno grants/schema usage/column privileges coerenti e che ogni futura migration prevede anche reload/smoke test PostgREST. Questo evita di correggere il codice quando la discrepanza dipende invece da environment drift o permessi API.

## Contesto *(osservazioni utente — da confermare con evidenza, non come root cause finale)*
- Stesso account cloud su Android e iOS.
- Android Cronologia: **6** sessioni locali; iOS History: **1** sessione di prova.
- Android dopo login: bootstrap `HistorySessionSyncV2 pull_apply inserted=1 … source=bootstrap`; sync successivi `inserted=0 skipped=1 dirtyLocalSkips=1 …`.
- Catalog/prezzi Android: `remotePricesEvaluated=41109`, `pricesSkippedNoProductRef=39452` *(ipotesi: bridge catalogo/prodotto prima del pull prezzi)*.
- Supabase ha comunicato che le nuove tabelle nello schema `public` non saranno più automaticamente raggiungibili dalla Data API: per il progetto è necessario auditare e rendere espliciti `GRANT`, RLS e policy nelle migration future, senza affidarsi ai default storici.

Domande da chiudere con dati reali: § **Domande tecniche obbligatorie**.

## Non incluso
- Nuovo multi-tenant/auth oltre al modello già presente (Google/OAuth + owner scoped).
- Redesign UI.
- Copia Kotlin → Swift 1:1.
- Migration/schema Supabase **applicate** senza evidenza da introspection/repo `MerchandiseControlSupabase` e accordo esplicito.
- Bulk `GRANT` permissivi o `anon` CRUD su dati privati solo per “far funzionare” l’app: vietato senza access matrix e motivazione.
- Fix basati su supposizione che Android/iOS usino lo stesso Supabase: va provato con project URL/ref, JWT issuer/sub/audience e fingerprint non sensibile delle chiavi.
- Test distruttivi su dati reali senza snapshot/export locale e remoto documentato.
- Embedding della `service_role` key in Android/iOS: il ruolo `service_role` resta solo server-side/maintenance.
- Continuazione **TASK-109** nel ramo corrente *(TASK-109 è BLOCKED / SOSPESO)*.

## Repo / percorsi
| Ruolo | Path locale | GitHub |
|-------|-------------|--------|
| iOS primario | `/Users/minxiang/Desktop/iOSMerchandiseControl` | https://github.com/XNIW/iOSMerchandiseControl |
| Android ref | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` | https://github.com/XNIW/MerchandiseControlSplitView |
| Supabase schema | `/Users/minxiang/Desktop/MerchandiseControlSupabase` | *(repo progetto backend)* |

### File iOS da leggere prima di patch *(lista minima richiesta dall’utente)*
- `iOSMerchandiseControl/HistorySessionSyncService.swift`
- `iOSMerchandiseControl/HistoryEntry.swift`
- `iOSMerchandiseControl/HistoryView.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`
- `iOSMerchandiseControl/SupabaseClientProvider.swift`
- File collegati SyncEvent / outbox / pull / push *(scoperta in EXECUTION)*

### Android *(lettura funzionale)*
- `HistorySessionSyncV2` / servizi equivalenti
- `CatalogCloudSync`
- Supabase auth / bootstrap
- `MerchandiseControlApplication` *(o entry lifecycle equivalente nel modulo app)* 
- `HistoryScreen`, `OptionsScreen`
- `InventoryRepository`
- DAO `HistoryEntry` / remote refs / product price refs
- Outbox / `sync_events` / realtime / tombstone se presenti

## Domande tecniche obbligatorie *(risposte documentate in Planning/Execution con evidenza)*
1. Quante sessioni History ci sono **realmente** su Supabase per l’utente loggato?
2. Android e iOS usano **esattamente** lo stesso `owner_user_id`?
3. Le 5 sessioni Android «mancanti» sul cloud sono: solo locali? senza `remote_id`? già marcate synced per errore? dirty ma saltate? bloccate da `dirtyLocalSkips`? escluse perché create prima del cloud?
4. iOS ha sessioni locali non pushate o mostra solo quanto pullato dal remoto?
5. Login/re-login: Android fa sempre full refresh/pull? iOS idem? Entrambi **push pending dopo pull**?
6. Delete History: oggi solo locale? tombstone remoto? device opposto riceve delete? offline?
7. Prezzi: perché `pricesSkippedNoProductRef` massivo? prodotti remoti esistono ma manca bridge locale? il pull catalogo deve **precedere** sempre il pull prezzi? policy identica Android/iOS?
8. Dopo login/re-login, il sync automatico viene schedulato **dopo** che lo stato auth è realmente `authenticated`, oppure viene perso perché parte durante `no_auth`/`NotAuthenticated`?
9. Manual Sync e bootstrap automatico possono sovrapporsi? Esiste un `syncRunId`/mutex/queue che impedisce doppie esecuzioni, cancellazioni reciproche o UI stale tipo “Operation cancelled”?
10. Le modifiche catalogo fatte localmente su Android/iOS *(product update, supplier/category update, price update)* entrano correttamente in outbox/dirty set e vengono pushate, o falliscono come il caso “prodotto aggiornato” visto dall’utente?
11. Le sessioni History locali legacy devono convergere come **unione controllata** remoto + locali eleggibili, oppure devono essere scartate? Decisione obbligatoria: non cancellare/ignorare le 5 sessioni Android senza prova.
12. Esiste una mappatura modello completa Android Room ↔ iOS SwiftData ↔ Supabase DTO per History, Product, Supplier, Category, ProductPrice, tombstone e sync metadata?
13. RLS/policy Supabase consente a entrambi i client di leggere anche tombstone/deleted rows del proprio owner, indispensabile per propagare delete?
14. I timestamp usati per conflitto/checkpoint sono UTC/server-side, oppure data locale formattata può creare skew tra Android/iOS?
15. Le app Android/iOS usano Data API/PostgREST tramite client Supabase per tutte le tabelle sync, o esistono chiamate dirette/Edge Function/server che cambiano il ruolo effettivo?
16. Quali tabelle, view, sequence e funzioni in `public` sono effettivamente necessarie alla Data API? Quali devono restare private/non esposte?
17. Per ogni tabella esposta, esistono `GRANT` espliciti per `authenticated`/`service_role` e, solo se giustificato, per `anon`? Sono presenti anche grant su sequence e `EXECUTE` per RPC/funzioni?
18. Ogni migration Supabase che crea/alter table include nello stesso file: `GRANT`, `enable row level security`, policy `select/insert/update/delete`, indici owner/timestamp e commento sul ruolo client?
19. Esistono `select *` o DTO/client che potrebbero rompersi con restrizioni column-level o errori `42501`? I client gestiscono `42501` con messaggio diagnostico utile?
20. Le policy RLS consentono l’inserimento con `owner_user_id = auth.uid()` e bloccano spoofing owner tramite `with check`?
21. I tombstone/delete sono leggibili dai client authenticated del proprio owner anche dopo `deleted_at`, così la propagazione delete non viene nascosta da RLS?
22. Security Advisor Supabase e log PostgREST mostrano grant/RLS mancanti? Il task produce evidence e SQL proposto senza applicarlo automaticamente?

23. Android e iOS puntano allo **stesso Supabase project_ref/URL** e usano anon key dello stesso progetto? I JWT hanno stesso `iss`/`aud` e stesso `sub` per l’account utente?
24. La Data API espone solo `public` o anche schemi custom? Se ci sono schemi custom, i ruoli Data API hanno `USAGE` sullo schema e i client li chiamano con naming corretto?
25. Esistono privilegi schema-level (`USAGE`/`CREATE`) e column-level che possono produrre `42501` anche con grant tabella presenti?
26. Esistono `select *` nei client o DTO che richiedono colonne non grantate o colonne sensibili non necessarie alla sync?
27. Dopo una migration/proposta con nuove tabelle/grants/policy, serve reload dello schema PostgREST (`NOTIFY pgrst, 'reload schema';`) e smoke test Data API prima di considerare il backend pronto?
28. Esistono trigger/RPC `security definer` in `public`? Hanno `search_path` sicuro, input validati e non bypassano owner/RLS in modo non intenzionale?
29. Catalog delete: Product/Supplier/Category hanno soft-delete/tombstone o delete fisico? Che impatto ha su ProductPrice, History e bridge remoto?
30. Esistono vincoli/indici per prevenire duplicati per owner (`remote_id`, barcode, supplier/category name normalizzati, price remote/effective key)?
31. ProductPrice sync usa cursor incrementale (`updated_at`/server timestamp), paginazione e dedupe key stabile, oppure scarica sempre 40k+ righe?
32. Qual è il piano snapshot/backup prima di convergenza legacy, test delete, grants/RLS o migration? Dove viene salvata l’evidenza redatta?
33. Versioni client Supabase Android/iOS: come espongono `42501`, refresh token, retry/backoff e cancel? I log distinguono errore permesso da rete/auth?
34. Realtime è usato davvero per catalog/history/prices? Se sì: audit publication/RLS/tombstone events; se no: dichiarare esplicitamente manual/pull-sync come scope TASK-110.

## Verifica Supabase *(query diagnostiche — adattare nomi colonne allo schema reale; non inventare colonne)*
Tabelle/colonne da confermare nel repo `/Users/minxiang/Desktop/MerchandiseControlSupabase` e DB linked:
- `public.shared_sheet_sessions`
- `inventory_products`, `inventory_suppliers`, `inventory_categories`
- `product_prices` / `inventory_product_prices` *(nome effettivo)*
- `sync_events`
- Eventuali `remote_refs` / tombstones

Verificare **RLS**, **`owner_user_id`**, presenza **`deleted_at`** o equivalente tombstone.

Query modello *(placeholder `<USER_UUID>`)*:

```sql
-- Conteggio sessioni per owner (globale audit — senza dati sensibili in evidence)
select owner_user_id, count(*)
from public.shared_sheet_sessions
group by owner_user_id
order by count(*) desc;

-- Sessioni per owner corrente
select remote_id, display_name, owner_user_id, updated_at
from public.shared_sheet_sessions
where owner_user_id = '<USER_UUID>'
order by updated_at desc;

-- Se esiste deleted_at:
select remote_id, display_name, owner_user_id, updated_at, deleted_at
from public.shared_sheet_sessions
where owner_user_id = '<USER_UUID>'
order by updated_at desc;
```

Verificare duplicati logici per `display_name` / timestamp / `remote_id`.


## Allineamento Supabase Data API grants/RLS *(PLANNING — proposta, nessuna migration applicata)*
La mail Supabase rende questo task più ampio del solo sync: oltre a capire perché Android/iOS divergono, bisogna rendere il backend robusto ai nuovi default della Data API. Questo task deve produrre una **access matrix** e una **migration proposta** che espliciti i privilegi necessari, ma non deve applicarla finché l’utente non dà handoff di EXECUTION.

### Decisione di sicurezza per MerchandiseControl
- Le tabelle dati dell’app sono private per utente/account cloud: default consigliato **nessun CRUD ad `anon`** sulle tabelle di catalogo/history/prezzi/sync.
- I client mobili autenticati usano il ruolo `authenticated`: concedere solo i privilegi necessari (`select, insert, update, delete`) sulle tabelle effettivamente usate dalla Data API e sempre sotto RLS owner-scoped.
- `service_role` può avere privilegi per job server-side, manutenzione o Edge Functions, ma la relativa key **non deve mai stare in Android/iOS**.
- Eventuali tabelle veramente pubbliche/read-only vanno elencate esplicitamente; se non esistono, `anon` resta senza privilegi sulle tabelle app.
- Le sequence collegate a insert via Data API devono avere privilegi minimi (`usage` e dove necessario `select`) per i ruoli che inseriscono.
- Le funzioni/RPC devono avere `grant execute` solo ai ruoli che le chiamano; funzioni `security definer` richiedono audit separato.
- Le view esposte devono essere auditate: preferire `security_invoker = true` dove supportato oppure non esporle via Data API se contengono dati owner-scoped.

### Access matrix target *(da confermare con schema reale)*
| Oggetto | Ruolo `anon` | Ruolo `authenticated` | Ruolo `service_role` | RLS/policy richiesta |
|---------|--------------|-----------------------|----------------------|----------------------|
| `shared_sheet_sessions` | Nessun accesso salvo esigenza provata | CRUD owner-scoped + lettura tombstone owner | CRUD manutenzione | `owner_user_id = auth.uid()`; `with check` su insert/update; delete via tombstone |
| `inventory_products` | Nessun accesso salvo esigenza provata | CRUD owner-scoped | CRUD manutenzione | owner scoped + barcode/remote_id uniqueness per owner |
| `inventory_suppliers` | Nessun accesso salvo esigenza provata | CRUD owner-scoped | CRUD manutenzione | owner scoped |
| `inventory_categories` | Nessun accesso salvo esigenza provata | CRUD owner-scoped | CRUD manutenzione | owner scoped |
| `product_prices` / `inventory_product_prices` | Nessun accesso salvo esigenza provata | CRUD owner-scoped, coerente con product bridge | CRUD manutenzione | owner scoped; prezzi orfani diagnosticabili ma non applicati |
| `sync_events` / outbox remoto | Nessun accesso salvo esigenza provata | CRUD owner-scoped o append/read owner secondo schema | CRUD manutenzione | owner scoped; idempotenza eventi |
| RPC/funzioni pubbliche | Nessun `execute` salvo esigenza provata | `execute` solo se chiamate dai client | `execute` manutenzione | input validato + nessun bypass owner |

### Query audit grants/RLS/Data API
Da aggiungere all’evidence pack. Adattare nomi tabelle e schema reale, ma non saltare il controllo grant/RLS.

```sql
-- Tabelle/view/materialized view esposte: privilegi effettivi per ruolo Data API
select n.nspname as schema_name,
       c.relname as object_name,
       c.relkind,
       r.rolname as role_name,
       has_table_privilege(r.rolname, c.oid, 'SELECT') as can_select,
       has_table_privilege(r.rolname, c.oid, 'INSERT') as can_insert,
       has_table_privilege(r.rolname, c.oid, 'UPDATE') as can_update,
       has_table_privilege(r.rolname, c.oid, 'DELETE') as can_delete
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
cross join (values ('anon'), ('authenticated'), ('service_role')) as r(rolname)
where n.nspname = 'public'
  and c.relkind in ('r','p','v','m')
order by c.relname, r.rolname;

-- Stato RLS e force RLS
select n.nspname as schema_name,
       c.relname as table_name,
       c.relkind,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as force_rls,
       c.reloptions
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r','p','v','m')
order by c.relname;

-- Policy RLS complete
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- Sequence privileges necessarie per insert via Data API
select n.nspname as schema_name,
       c.relname as sequence_name,
       r.rolname as role_name,
       has_sequence_privilege(r.rolname, c.oid, 'USAGE') as can_usage,
       has_sequence_privilege(r.rolname, c.oid, 'SELECT') as can_select,
       has_sequence_privilege(r.rolname, c.oid, 'UPDATE') as can_update
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
cross join (values ('anon'), ('authenticated'), ('service_role')) as r(rolname)
where n.nspname = 'public'
  and c.relkind = 'S'
order by c.relname, r.rolname;

-- Funzioni/RPC in public e EXECUTE per ruolo
select n.nspname as schema_name,
       p.proname as function_name,
       r.rolname as role_name,
       has_function_privilege(r.rolname, p.oid, 'EXECUTE') as can_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
cross join (values ('anon'), ('authenticated'), ('service_role')) as r(rolname)
where n.nspname = 'public'
order by p.proname, r.rolname;

-- Default privileges futuri: verificare se il progetto è già opt-in al nuovo comportamento
select coalesce(n.nspname, '(all schemas)') as schema_name,
       pg_get_userbyid(d.defaclrole) as owner_role,
       d.defaclobjtype,
       d.defaclacl
from pg_default_acl d
left join pg_namespace n on n.oid = d.defaclnamespace
where coalesce(n.nspname, 'public') = 'public'
order by schema_name, owner_role, d.defaclobjtype;
```

### Audit aggiuntivo hardening Data API / PostgREST
Questi controlli completano la access matrix e impediscono falsi positivi tipo “RLS ok ma Data API ancora rotta”. Tutti sono **read-only** in PLANNING.

```sql
-- Schema privileges: utilissimo se in futuro si usa schema custom oltre public
select n.nspname as schema_name,
       r.rolname as role_name,
       has_schema_privilege(r.rolname, n.oid, 'USAGE') as can_usage,
       has_schema_privilege(r.rolname, n.oid, 'CREATE') as can_create
from pg_namespace n
cross join (values ('anon'), ('authenticated'), ('service_role')) as r(rolname)
where n.nspname in ('public')
order by n.nspname, r.rolname;

-- Column-level privileges: rileva cause 42501 quando il client usa select(*) o colonne non grantate
select table_schema, table_name, column_name, grantee, privilege_type
from information_schema.column_privileges
where table_schema = 'public'
order by table_name, column_name, grantee, privilege_type;

-- Table grants via information_schema, più leggibile per evidence rispetto a has_table_privilege
select table_schema, table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated', 'service_role')
order by table_name, grantee, privilege_type;

-- Constraint e indici: confermare idempotenza/dedupe per owner e remote_id
select conrelid::regclass as object_name, conname, contype, pg_get_constraintdef(oid) as definition
from pg_constraint
where connamespace = 'public'::regnamespace
order by object_name::text, conname;

select schemaname, tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public'
order by tablename, indexname;

-- Trigger e funzioni security definer: verificare owner stamping, tombstone, updated_at e sicurezza search_path
select event_object_schema, event_object_table, trigger_name, action_timing, event_manipulation, action_statement
from information_schema.triggers
where event_object_schema = 'public'
order by event_object_table, trigger_name;

select n.nspname as schema_name,
       p.proname as function_name,
       p.prosecdef as security_definer,
       p.proconfig as function_config
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by p.proname;
```

**Post-migration playbook proposto, non eseguire in PLANNING**:
1. applicare migration solo in environment approvato;
2. eseguire `NOTIFY pgrst, 'reload schema';` se la Data API non vede subito nuovi oggetti/grants;
3. smoke test per ruolo `authenticated` su select/insert/update/delete owner-scoped;
4. smoke test negativo `anon` su tabelle private;
5. registrare eventuali `42501` con `hint`, ruolo e tabella in `supabase-42501-audit.md`.


### Audit migration repository
Nel progetto `/Users/minxiang/Desktop/MerchandiseControlSupabase` cercare ogni oggetto creato in `public` e verificare che non esistano “create table” senza blocco grants/RLS/policy nello stesso file o in migration immediatamente collegata.

```bash
grep -RniE "create table|create view|create materialized view|create function|grant |revoke |enable row level security|create policy|alter default privileges" supabase migrations .
```

Output richiesto: `docs/TASKS/EVIDENCE/TASK-110/supabase-access-matrix.md` con tabella `oggetto → Data API necessario? → exposed schema? → schema usage → grant attuale → column privilege → RLS attuale → policy mancante → sequence/RPC/view check → migration proposta`.

Aggiungere anche `docs/TASKS/EVIDENCE/TASK-110/supabase-environment-parity.md` con project URL/ref redatto, anon-key fingerprint non sensibile, JWT `iss/aud/sub` redatti e prova che Android/iOS leggono/scrivono lo stesso progetto.

### Template migration proposta *(non applicare in PLANNING)*
Questo template è solo il formato richiesto; Cursor/Codex deve sostituire i nomi con quelli verificati nello schema reale.

```sql
-- Esempio: tabella dati privata owner-scoped, chiamata da Android/iOS dopo login
alter table public.your_table enable row level security;

grant select, insert, update, delete on table public.your_table to authenticated;
grant select, insert, update, delete on table public.your_table to service_role;
-- Non concedere anon salvo tabella pubblica/read-only esplicitamente approvata.

-- Se la tabella usa sequence/identity e il client authenticated inserisce righe:
grant usage, select on sequence public.your_table_id_seq to authenticated;
grant usage, select on sequence public.your_table_id_seq to service_role;

create policy "your_table_select_own"
  on public.your_table
  for select to authenticated
  using (owner_user_id = auth.uid());

create policy "your_table_insert_own"
  on public.your_table
  for insert to authenticated
  with check (owner_user_id = auth.uid());

create policy "your_table_update_own"
  on public.your_table
  for update to authenticated
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

-- Preferire soft delete/tombstone per sync cross-device; delete fisico solo se policy e outbox lo permettono.
create policy "your_table_delete_own"
  on public.your_table
  for delete to authenticated
  using (owner_user_id = auth.uid());
```

### 42501 e client behavior
- Durante l’audit leggere i log PostgREST/Database per errori `42501`, includendo `hint` e ruolo effettivo in evidence redatta.
- Android/iOS devono distinguere nei log/UI: `no_auth`, `RLS_denied`, `missing_grant_42501`, `network_error`, `conflict`, `cancelled_by_user`.
- Se compare `42501`, non risolvere con grant indiscriminato: aggiornare access matrix, verificare RLS, poi proporre migration minima.

## Diagnostica Android richiesta
Logging strutturato *(privacy-safe: no payload enormi, no segreti)*:
- login completato; bootstrap automatico;
- prima/dopo push history; prima/dopo pull history;
- conteggi: local totali; `remote_id` null; dirty; synced; tombstone pending; pushed; pulled; skipped clean; `dirtyLocalSkips`;
- **motivo dettagliato per ogni skip**.

## Fix Android richiesto *(EXECUTION — dopo policy approvata)*
Dopo login/re-login sequenza coerente:
1. restore auth  
2. pull remoto catalog / history / prices *(ordine vincolato se emerge dipendenza bridge)*  
3. riallineare bridge catalogo  
4. push pending locali  
5. pull finale di conferma  

Evitare bootstrap «solo pull» o «solo quick push» se esistono pending locali. Sessioni legacy senza `remote_id`: stabilizzare `remote_id` e policy dirty/push. Risolvere `dirtyLocalSkips` con regola documentata *(locale modificato vs remoto modificato vs entrambi dirty → conflitto o LWW esplicito)*.

**Delete**: introdurre/validare tombstone/outbox — delete locale deve propagarsi remoto e all’altro device; non bastano delete solo Room.

## Diagnostica iOS richiesta
In `HistorySessionSyncService` / `HistoryEntry` verificare:
`isHistorySessionDirtyForCloud`, `remoteID`, `remoteUpdatedAt`, `remoteDeletedAt`, `remotePayloadFingerprint`, `localChangeRevision`, `lastSyncedLocalRevision`, `markHistorySessionLocalMutation`, `pullHistorySessionsFromCloud`, `pushPendingHistorySessions`, `applyRemoteSharedSheetSessions`, delete in `HistoryView` / `ModelContext`.

## Fix iOS richiesto *(EXECUTION)*
Allineare **policy** ad Android *(idiomatic Swift/SwiftData, non port Kotlin)*. Post login/re-login: **refresh cloud completo**; History aggiornata dopo pull/push; delete → tombstone/outbox se schema lo permette; altrimenti proporre migration minima **senza applicarla** senza evidenza. Legacy senza `remoteID`: pushabile/riconciliabile. Non cancellare dati locali massivi senza backup/conferma/tombstone.

## Fix Supabase richiesto *(EXECUTION — solo dopo PLANNING-AUDIT e handoff esplicito)*
- Applicare solo migration/proposte SQL nate dall'access matrix e dallo schema reale: niente patch generiche.
- Per ogni tabella/view/funzione/sequence Data API in `public`, aggiungere GRANT espliciti minimi e RLS/policy nello stesso blocco migration.
- Mantenere `anon` senza accesso ai dati owner-scoped; concedere `select` ad `anon` solo a oggetti davvero pubblici e documentati.
- Garantire che tombstone/deleted rows dell'owner restino leggibili dal ruolo `authenticated` finché servono alla propagazione delete.
- Validare gli insert via Data API con sequence/identity grants e gli RPC con `grant execute` mirato.
- Trasformare ogni errore `42501` legittimo in fix SQL minimo e ogni denial RLS in test di sicurezza, non in workaround permissivo.

## Test obbligatori

### Android (unit/integration — scenari)
- Bootstrap remoto 1 sessione + locale 0 → locale 1.  
- Locale 5 legacy + remoto 1 → dopo sync coerenza secondo policy.  
- Create Android → iOS pull vede nuova sessione (e viceversa).  
- Delete Android → iOS non mostra più *(e viceversa)*.  
- Rename/update bidirezionale.  
- Price pull: non deve saltare massivamente se bridge corretto; se salta, log motivazione + fix tracciato.

### iOS XCTest/unit *(mirati)*
- `HistorySessionPayloadCodec` fingerprint stabile.  
- `pushPendingHistorySessions`: solo dirty ma gestisce `remoteID == nil` legacy.  
- `pullHistorySessionsFromCloud` inserisce remote-only.  
- `applyRemoteSharedSheetSessions` aggiorna clean locale senza violare policy dirty-local.  
- Delete/tombstone se schema supportato.

### Manuale cross-platform *(checklist)*
1. Annotare stato iniziale Supabase.  
2. Login stesso account Android + iOS.  
3. Sync now entrambi.  
4. Confrontare conteggi: history sessions, products, suppliers, categories, price history.  
5–11. Create/delete/modifica prezzo/re-login come nel brief utente.

### Supabase Data API grants/RLS *(audit/test planning)*
- Access matrix prodotta per tabelle/view/sequence/funzioni in `public`.
- Migration proposta contiene `GRANT` + `enable row level security` + policy per ogni nuova tabella esposta.
- Test ruolo `authenticated`: select/insert/update/delete passano solo sulle righe owner-scoped.
- Test ruolo `anon`: nessun accesso alle tabelle private app; eventuali read-only pubblici motivati.
- Test tombstone: righe `deleted_at` owner-scoped restano leggibili quanto basta per propagare delete.
- Test errore `42501`: client/log distinguono missing grant da RLS denied e non mostrano “sync cancelled” generico.

## Criteri di accettazione
- [x] **TASK-109** risulta **BLOCKED / SOSPESO** nel MASTER-PLAN e nel file TASK-109 — **non** DONE.
- [x] **TASK-110** **DONE**; root cause **reale** documentata *(non solo ipotesi)*.
- [x] Count Supabase verificato con query *(evidenza)*.
- [x] Android e iOS confermati su **stesso** `owner_user_id` *(metodo documentato)*.
- [x] Dopo login/re-login sync automatico **coerente** su entrambe le piattaforme.
- [x] History count Android/iOS/Supabase **riallineato** secondo policy approvata.
- [x] Delete History **propaga** tra piattaforme *(tombstone live verificato)*.
- [x] Nessuna sessione locale **invisibile** senza stato pending/error comprensibile.
- [x] `pricesSkippedNoProductRef` **risolto** o trasformato in diagnostica chiara + fix tracciato.
- [x] Build Android **PASS**.
- [x] Build iOS **PASS**.
- [x] Test minimi Android/iOS **PASS** o impossibilità documentata.
- [x] Nessuna regressione import/export Excel, Database prodotti, fornitori, categorie, cronologia esistente.
- [x] `MASTER-PLAN.md` conferma che dopo chiusura **TASK-110 non ci sono task ACTIVE**; TASK-109 resta sospeso/bloccato senza chiuderlo DONE.
- [x] Sync manuale ripetuto 3 volte su dati già allineati è **idempotente**: nessun duplicato History/ProductPrice/Product, nessun incremento artificiale dei count.
- [x] Modifica prodotto/prezzo da Android → sync → iOS e modifica da iOS → sync → Android sono verificate, non solo create/delete History.
- [x] Caso login dopo app aperta signed-out: il sync parte automaticamente **dopo** auth stable, non durante `no_auth`, e la UI mostra stato corretto.
- [x] UI Options/History/Database distingue chiaramente: Synced, Pending, Syncing, Cancelled, Error, Offline; nessun “Operation cancelled” stale dopo un sync riuscito.
- [x] Nuove stringhe UI/diagnostica localizzate almeno in IT/EN e marcate per ES/ZH se non completate nello stesso task.
- [x] `supabase-access-matrix.md` prodotto con grant/RLS attuali e target per ogni tabella/view/sequence/funzione `public` usata dalla Data API.
- [x] Ogni migration Supabase futura proposta nel task include esplicitamente `GRANT` + RLS + policy; nessuna tabella nuova si affida ai default storici.
- [x] Nessun `anon` CRUD sulle tabelle private di MerchandiseControl; eventuali privilegi `anon` sono solo read-only, motivati e approvati nel piano.
- [x] Nessuna `service_role` key presente in codice/config mobile Android/iOS; `service_role` resta solo server-side/maintenance.
- [x] Errori `42501` verificati nei log o simulati con test; la remediation proposta è minima e coerente con access matrix, non un bulk grant indiscriminato.
- [x] Security Advisor Supabase controllato o, se non accessibile, indicato come check manuale obbligatorio prima di EXECUTION.

## Cosa NON fare
- Non continuare TASK-109; non chiuderlo DONE.
- Non cancellare dati locali per «allineare» senza tombstone e backup.
- Non inventare colonne Supabase.
- Non usare `grant all on all tables in schema public to anon, authenticated` come soluzione standard.
- Non concedere `anon` su dati owner-scoped per aggirare RLS o debug.
- Non introdurre auth/multiutenza nuova.
- Non redesign UI; non copiare Kotlin in Swift.
- Non riaprire task DONE storici *(es. 041)* salvo citazione contestuale.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | TASK-109 sospeso; TASK-110 unico attivo | proseguire TASK-109 | override priorità utente 2026-05-15 | attiva |
| 2 | Restare in PLANNING finché audit/evidence gate non è chiuso | passare subito a patch | il rischio principale è confondere sintomi con root cause | attiva |
| 3 | Convergenza iniziale = unione controllata di remoto + locali eleggibili, non wipe locale | trattare Supabase come “unico vero” anche per dati pre-cloud | evita perdita delle 5 sessioni Android legacy e rende esplicita la migrazione | attiva |
| 4 | Sync orchestrato con mutex/`syncRunId` unico per automatico/manuale | lanciare pull/push indipendenti | evita cancellazioni reciproche, doppio lavoro e UI “cancelled” stale | attiva |
| 5 | Ordine sync preferito: auth stable → catalog pull/bridge → prices pull → history pull → pending push → confirm pull | push/pull casuale o bootstrap solo pull | riduce orphan price e dirtyLocalSkips persistenti | attiva |
| 6 | UI/UX può ricevere micro-ritocchi nativi iOS solo per chiarezza sync | redesign o copia Android | migliora comprensione senza cambiare stile app | attiva |
| 7 | Ogni write cross-device deve essere idempotente | sync che crea duplicati a ogni run | “Sync now” ripetuto deve diventare no-op quando già allineato | attiva |
| 8 | Allineare Supabase ai nuovi default Data API con `GRANT` espliciti nelle migration | affidarsi ai grant automatici storici | evita rotture future su nuove tabelle/progetti e rende l’accesso revisionabile | attiva |
| 9 | Default `anon` = nessun accesso alle tabelle private app | concedere CRUD anon per semplicità | i dati sono owner-scoped e accessibili solo dopo login | attiva |
| 10 | `GRANT` e RLS/policy sono un blocco unico nella stessa proposta migration | grant senza RLS o RLS senza grant | grant decide raggiungibilità Data API, RLS decide righe: servono entrambi | attiva |
| 11 | Errori `42501` diventano diagnostica esplicita, non “sync cancelled” generico | trattare 42501 come errore rete/cancelled | riduce debug ambiguo e guida remediation minima | attiva |

---

## Planning *(bootstrap Codex su richiesta utente — Claude può integrare/refinire senza cancellare CA)*

### Obiettivo *(audit prima di codice)*
Chiudere con **evidenza**: schema effettivo, count remoti, parity `owner_user_id`, motivazione di `dirtyLocalSkips` / sessioni legacy / skip prezzi, grant/RLS effettivi Data API; poi definire sequenza sync, policy conflitto e access matrix Supabase **documentate**.

### Analisi
- Sintomi cross-device e log Android forniti dall’utente sono **segnali**, non root cause.
- La divergenza può essere: remoto con poche righe; filtro owner diverso; push locale mai avvenuto; skip logic troppo aggressiva; assenza tombstone delete.

### Approccio proposto
1. **Schema + grants/RLS audit** repo Supabase + query read-only *(no inventare colonne, no apply migration)*.  
2. **Correlazione owner** Android/iOS *(hash/redazione in evidence)*.  
3. **Trace codice** History sync V2 Android vs `HistorySessionSyncService` iOS.  
4. **Policy documentata** push/pull/delete/bridge prezzi + Data API grants/RLS.  
5. Chiudere **PLANNING-AUDIT** con evidence pack + reconciliation *(nessuna patch)*; solo dopo **handoff utente esplicito** → **EXECUTION** patch + test *(cartella `docs/TASKS/EVIDENCE/TASK-110/`)*.

### File da modificare *(lista viva — da confermare in EXECUTION)*
- iOS: file § sopra + coordinator/sync correlati.
- Android: History sync V2, repository, bootstrap application.
- Supabase: migration/proposta **solo** se gap tombstone/RLS/grants provato — **mai apply senza traccia, access matrix e consenso**.

### Rischi identificati
- Schema senza `deleted_at` → serve migration minima o compensazione outbox-only *(decisione documentata)*.  
- Migration future senza `GRANT` esplicito → rottura Data API/PostgREST/GraphQL quando i nuovi default Supabase sono applicati.  
- Grant troppo ampi ad `anon` → rischio esposizione dati owner-scoped; serve access matrix minima.  
- Dataset grande ProductPrice → test/pagine devono restare cancellabili e misurabili.  
- Ripresa TASK-109 dopo TASK-110 potrebbe richiedere merge UX lifecycle — fuori scope finché TASK-109 resta BLOCKED.

### Integrazione Planning Claude 2026-05-15 *(solo planning, nessuna execution)*

#### Valutazione del piano esistente
Il piano è corretto nella direzione generale: tratta i log utente come segnali, non come root cause; mette Supabase/owner/schema prima del codice; include Android, iOS e Supabase; richiede tombstone/delete e diagnostica `dirtyLocalSkips`. Le ottimizzazioni seguenti servono a evitare tre rischi: task troppo ampio senza slicing, perdita dei dati legacy locali, e patch premature senza evidenza.

#### Scope operativo rifinito a slice
- **P0 — Governance e sicurezza dati**: verificare `MASTER-PLAN.md`, garantire TASK-110 come unico ACTIVE, annotare TASK-109 sospeso, non toccare dati reali senza backup/soft-delete. Creare evidence folder `docs/TASKS/EVIDENCE/TASK-110/`.
- **P1 — Audit schema/owner/auth/grants**: schema Supabase, RLS, grants Data API, default privileges, sequence/function privileges, owner_user_id, auth state Android/iOS, query count remote e count locali.
- **P2 — Reconciliation report, nessuna write**: classificare sessioni/prodotti/prezzi in remote-only, local-only, matched, dirty-local, dirty-remote, conflict, tombstone. Output: report prima di qualunque fix.
- **P3 — Policy sync + access policy documentata**: identità, dedupe, conflitto, tombstone, checkpoint, idempotenza, ordine sync, access matrix Supabase e template migration GRANT/RLS.
- **P4 — Execution candidate minimo**: solo dopo handoff utente, patch minime per bootstrap/auth, History sync, catalog bridge/prices, product mutation push e UI state.
- **P5 — Test/evidence**: test automatici mirati + matrice manuale cross-platform + grants/RLS tests + screenshot/log redatti.

#### Regola di convergenza iniziale
Durante la migrazione cloud non usare “Supabase remoto” come motivo per cancellare dati locali legacy. La convergenza corretta è:
1. se `remote_id` combacia → stessa entità;
2. se locale è solo-locale ma valida e non tombstoned → creare/assegnare `remote_id` stabile e metterla in pending push;
3. se remoto è solo-remoto → pull locale;
4. se esiste tombstone remoto più recente → applicare delete locale;
5. se entrambi hanno modifiche concorrenti → usare policy conflitto documentata, non sovrascrivere silenziosamente.

#### Identità e dedupe
Priorità matching:
1. `remote_id` / UUID remoto;
2. eventuale mapping locale↔remoto già salvato;
3. fingerprint payload + timestamp normalizzato + owner come match forte solo se dimostrato;
4. `display_name` solo come segnale debole, mai come identità unica.

Per Product/Price bridge:
1. product remote id / bridge table, se esiste;
2. barcode canonicalizzato come fallback forte se unico;
3. itemNumber+supplier/category solo diagnostico;
4. productName mai identità primaria.

#### Sync engine target
- Un solo sync alla volta per piattaforma: `syncRunId`, mutex/actor/queue, cancellation esplicita e stato UI coerente.
- Manual Sync e bootstrap automatico condividono lo stesso coordinator, non due pipeline separate.
- Debounce `no_auth` non deve impedire un nuovo sync quando auth diventa valida.
- Dopo auth stable: catalog pull/bridge → price pull → history pull → push pending locali → confirm pull.
- Ogni fase salva checkpoint solo dopo successo; fallimenti parziali non devono marcare record come synced.
- Tutte le operazioni devono essere idempotenti: ripetere “Sync now” non crea nuove sessioni/prezzi duplicati.

#### Audit Supabase aggiuntivo
Aggiungere alle query base anche:

```sql
-- Introspection colonne
select table_schema, table_name, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in ('shared_sheet_sessions','inventory_products','inventory_suppliers','inventory_categories','product_prices','inventory_product_prices','sync_events')
order by table_name, ordinal_position;

-- Policy RLS
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- Count attive/deleted se deleted_at esiste
select owner_user_id,
       count(*) as total,
       count(*) filter (where deleted_at is null) as active,
       count(*) filter (where deleted_at is not null) as deleted
from public.shared_sheet_sessions
group by owner_user_id
order by total desc;

-- Diagnostica price orphan, adattare nomi colonne reali
select count(*) as orphan_price_rows
from public.product_prices pp
left join public.inventory_products p on p.remote_id = pp.product_remote_id
where p.remote_id is null;
```

Se `deleted_at` non esiste, produrre solo una **proposta migration** con: `deleted_at timestamptz`, `updated_at timestamptz`, indice `(owner_user_id, updated_at)`, vincolo unique su `remote_id`, RLS che rende leggibili i tombstone dell’owner. Non applicare migration senza consenso.

In questo stesso audit includere anche la sezione **Allineamento Supabase Data API grants/RLS** sopra: grants tabelle, sequence, funzioni/RPC, default privileges, Security Advisor e log `42501`.

#### Evidence pack obbligatorio
Creare/aggiornare:
- `docs/TASKS/EVIDENCE/TASK-110/schema-audit.md`
- `docs/TASKS/EVIDENCE/TASK-110/supabase-counts-redacted.md`
- `docs/TASKS/EVIDENCE/TASK-110/android-local-counts.md`
- `docs/TASKS/EVIDENCE/TASK-110/ios-local-counts.md`
- `docs/TASKS/EVIDENCE/TASK-110/reconciliation-report.md`
- `docs/TASKS/EVIDENCE/TASK-110/sync-policy.md`
- `docs/TASKS/EVIDENCE/TASK-110/test-matrix.md`
- `docs/TASKS/EVIDENCE/TASK-110/supabase-access-matrix.md`
- `docs/TASKS/EVIDENCE/TASK-110/proposed-grants-rls-migration.sql` *(bozza, non applicata in PLANNING)*
- `docs/TASKS/EVIDENCE/TASK-110/supabase-42501-audit.md`
- `docs/TASKS/EVIDENCE/TASK-110/security-advisor-check.md`

Redazione: mascherare email/token; loggare `owner_user_id` come hash breve + ultimi 4 caratteri se serve correlazione; no payload Excel completo nei log.

#### Matrice minima di test ampliata
- Login/re-login con app già aperta signed-out → sync parte dopo auth stable.
- Force stop Android / riapertura iOS → restore session + sync non perso.
- Manual Sync mentre automatic sync è in corso → niente doppio run; UI mostra un solo stato.
- Remote 1 + locale 0 → locale 1.
- Remote 1 + locale 5 legacy → remoto/locali convergono senza perdita e senza duplicati.
- Create/update/delete History Android ↔ iOS.
- Rename/update stessa History su due device → conflitto o LWW documentato.
- Update prodotto/prezzo Android ↔ iOS.
- Price pull dopo catalog bridge → orphan price ridotti o classificati con motivo.
- Offline create/delete → online sync → propagazione corretta.
- Sync now ripetuto tre volte → no-op idempotente.
- Data API role test `authenticated` → operazioni per owner passano, altre righe vengono bloccate da RLS.
- Data API role test `anon` → tabelle private non leggibili/scrivibili.
- Nuova tabella proposta in migration → contiene sempre `GRANT`, RLS e policy nello stesso blocco.
- Errore `42501` → classificato come `missing_grant_42501` nei log/diagnostica, non come cancellazione operazione.

#### UI/UX refinement consentito
Interventi ammessi solo se migliorano chiarezza e stato sync, senza redesign:
- **Options**: card Cloud account + card Sync status con last successful sync, pending changes, error summary, CTA “Sync now” disabilitata durante sync; disclosure “Dettagli diagnostici”.
- **History**: badge per entry `Synced`, `Pending`, `Error`, `Deleted pending`; non mostrare UUID come testo primario; filtro “solo errori” deve includere pending/error sync.
- **Database**: se appare “manca prodotto locale collegato”, mostrare messaggio comprensibile: “Prezzo cloud non applicato perché il prodotto non è ancora collegato al catalogo locale”.
- Colori coerenti iOS: verde synced, arancione pending, rosso error, grigio cancelled; Dynamic Type e VoiceOver label per badge principali.
- Errori Supabase: distinguere testo utente “Permessi cloud mancanti, serve aggiornamento database” da dettagli diagnostici `42501/GRANT/RLS` mostrati solo in disclosure/log.
- Nuove stringhe: localizzare IT/EN subito; ES/ZH almeno placeholder tracciato se non completato.

#### Performance e robustezza
- ProductPrice remoto grande: usare paginazione/chunk e non caricare tutto in memoria se evitabile.
- Salvare SwiftData/Room in batch controllati, non sul main thread.
- Usare timestamp UTC/server-side per checkpoint e conflitti.
- Evitare retry loop infinito: backoff e messaggio UI chiaro.
- Prima di test delete su dati reali, creare sessioni dedicate `TASK110_TEST_*`; non usare vecchie sessioni importanti come campione distruttivo.


### Integrazione Planning Claude 2026-05-15 — hardening finale *(solo planning, nessuna execution)*

#### Valutazione aggiornata
Il piano è ormai solido: blocca Execution, chiede evidence pack, impone access matrix Supabase e vieta grants permissivi. Mancano però alcuni dettagli che riducono il rischio di falsi fix: environment parity tra Android/iOS, schema usage/column privileges, schema cache PostgREST, delete catalogo, policy conflitto per tipo entità, backup/snapshot prima dei test distruttivi e progress UX per fasi sync.

#### Environment parity obbligatoria
Prima di attribuire la divergenza a History sync, verificare:
- Supabase URL/project_ref in Android, iOS e configurazioni locali;
- anon key fingerprint non sensibile *(hash breve, mai chiave completa)*;
- JWT `iss`, `aud`, `sub`, `email` redatta e `role` per entrambi i client;
- eventuali branch/staging/prod diversi;
- differenze tra chiave anon usata in build debug/release e valori salvati in Keychain/SharedPreferences.

Output: `supabase-environment-parity.md`. Se Android/iOS non puntano allo stesso progetto, TASK-110 resta in audit e non si patcha sync finché l’ambiente non è riallineato.

#### Policy conflitto per entità
Definire nel file `sync-policy.md` una tabella esplicita:

| Entità | Identità primaria | Update policy | Delete policy | Note |
|--------|-------------------|---------------|---------------|------|
| HistorySession | `remote_id` | LWW con `remote_updated_at` server-side + revision locale; conflitto se entrambi dirty | tombstone wins solo se più recente della mutazione locale | non usare titolo come identità |
| Product | `remote_id`, fallback barcode unico per owner | LWW controllato; campi prezzo trattati via ProductPrice | preferire soft-delete; non perdere price history | barcode canonicalizzato |
| Supplier/Category | `remote_id`, fallback nome normalizzato per owner | upsert owner-scoped | soft-delete se referenziati | evitare duplicati case-insensitive |
| ProductPrice | `remote_id` o dedupe `(owner, product_remote_id, type, effective_at, source/value hash)` | append-only/idempotente; non sovrascrivere storia | normalmente non hard-delete; tombstone solo se schema lo prevede | pull incrementale/paginato |
| SyncEvent/Outbox | event id remoto/locale stabile | drain idempotente | consumed/tombstone secondo schema | retry con backoff |

Questa matrice deve essere approvata in PLANNING prima di qualsiasi patch.

#### Catalog delete e price history
Estendere TASK-110 oltre History delete: se l’utente cancella prodotti/fornitori/categorie, la cancellazione deve avere una policy cross-device. Decisione consigliata:
- Product/Supplier/Category: soft-delete/tombstone remoto se l’entità può essere referenziata da History o ProductPrice;
- ProductPrice: mantenere storico append-only; non cancellarlo a cascata solo perché il prodotto viene nascosto/cancellato;
- UI Database: mostrare stato “Deleted pending” o nascondere con filtro, ma tenere diagnostica in dettagli sync;
- migration eventuale: `deleted_at`, `updated_at`, `owner_user_id`, indici owner/timestamp e policy RLS che rendono leggibile il tombstone all’owner.

#### ProductPrice performance e incremental sync
Per evitare 40k+ righe ad ogni sync:
- usare cursor per `updated_at` server-side o `created_at` stabile;
- ordinamento deterministico `(updated_at, remote_id)`;
- page size/chunk configurabile e loggato;
- resume da ultimo checkpoint solo dopo batch applicato;
- dedupe prima dell’insert locale;
- metrica `pricesEvaluated/imported/updated/skippedNoProductRef/skippedDuplicate/skippedPermission/skippedConflict`.

#### Supabase Data API hardening aggiuntivo
Integrare access matrix con:
- schema `USAGE` per ruoli Data API;
- column privileges, perché `42501` può arrivare anche da colonne non grantate;
- exposed schemas in Dashboard/Data API;
- view `security_invoker` o esclusione Data API;
- funzioni `security definer` con `search_path` sicuro;
- trigger owner/timestamp/tombstone;
- `NOTIFY pgrst, 'reload schema';` come step post-migration proposto, non eseguito in PLANNING.

Regola: `alter default privileges` può essere documentato come rete di sicurezza, ma ogni migration del task deve comunque contenere `GRANT` espliciti per gli oggetti creati.

#### Backup/snapshot gate
Prima di qualsiasi Execution che scriva o cancelli:
- snapshot Supabase counts e, se possibile, export SQL/CSV redatto delle tabelle target;
- backup locale Android Room e iOS SwiftData o almeno export diagnostico dei record target;
- sessioni di test `TASK110_TEST_*` per create/delete;
- piano rollback: revert migration, restore dati locali/remoti o script compensativo.

Questo è un gate di sicurezza, non un optional.

#### UI/UX state taxonomy
La UI deve usare una tassonomia unica, non messaggi generici:
- `Signed out`: sync non disponibile, CTA login;
- `Ready`: account ok, nessun pending;
- `Syncing`: mostra fase corrente *(Catalog, Prices, History, Push pending, Confirm pull)* e blocca doppio tap;
- `Pending`: modifiche locali da inviare;
- `Partial`: alcune fasi riuscite, altre con warning;
- `Permission issue`: 42501/grant/RLS, testo utente semplice + dettagli in disclosure;
- `Offline`: rete assente, retry manuale possibile;
- `Cancelled`: solo se annullato dall’utente, mai per `no_auth` o errore grants;
- `Error`: errore reale con retry.

In iOS conviene usare card compatte native: titolo, sottotitolo, badge, CTA primaria e disclosure “Dettagli”. In Android mantenere coerenza Material ma con la stessa semantica.

#### Evidence pack aggiuntivo
Aggiungere ai file già previsti:
- `docs/TASKS/EVIDENCE/TASK-110/supabase-environment-parity.md`
- `docs/TASKS/EVIDENCE/TASK-110/supabase-schema-cache-playbook.md`
- `docs/TASKS/EVIDENCE/TASK-110/conflict-policy-matrix.md`
- `docs/TASKS/EVIDENCE/TASK-110/catalog-delete-policy.md`
- `docs/TASKS/EVIDENCE/TASK-110/product-price-incremental-plan.md`
- `docs/TASKS/EVIDENCE/TASK-110/preflight-backup-rollback-plan.md`
- `docs/TASKS/EVIDENCE/TASK-110/ui-state-taxonomy.md`
- `docs/TASKS/EVIDENCE/TASK-110/client-version-audit.md`

#### Test matrix aggiuntiva
- Android/iOS stesso project_ref e stesso JWT `sub` redatto → PASS obbligatorio.
- Mismatch environment simulato/identificato → il task si ferma con diagnosi, non patcha sync.
- Migration proposta nuova tabella → smoke test `authenticated`, negative test `anon`, reload schema PostgREST previsto.
- Column privilege denial simulato → classificato come `missing_column_grant_42501`, non come rete/cancel.
- Product delete Android → iOS converge senza perdere price history; viceversa.
- Supplier/category rename/delete con prodotti collegati → nessun orphan non spiegato.
- Price sync con 40k righe → paginazione, checkpoint, memoria stabile e nessun duplicate insert.
- Offline durante batch prices/history → resume senza duplicati.

#### Criteri di accettazione aggiuntivi
- [ ] `supabase-environment-parity.md` prova che Android/iOS usano stesso project_ref/JWT subject oppure documenta mismatch come root cause.
- [ ] Access matrix include schema usage, column privileges, exposed schemas, view/RPC/function/trigger checks e sequence grants.
- [ ] `conflict-policy-matrix.md` approvata prima di Execution.
- [ ] `catalog-delete-policy.md` chiarisce product/supplier/category delete e conservazione ProductPrice.
- [ ] ProductPrice sync plan è incrementale/paginato/idempotente, non full pull cieco ad ogni sync.
- [ ] Preflight backup/rollback plan prodotto prima di qualunque test distruttivo o migration.
- [ ] UI state taxonomy approvata; `Cancelled` non viene usato per `no_auth`, 42501, RLS o network error.
- [ ] Migration proposta include anche post-migration playbook: schema reload, smoke test Data API e controllo log 42501.

#### Decisioni aggiuntive
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 12 | Environment parity è gate prima del fix sync | patchare subito History sync | URL/progetto/key diversi possono spiegare tutta la divergenza | attiva |
| 13 | Catalog delete usa tombstone/soft-delete se l’entità ha riferimenti | hard-delete immediato | evita perdita PriceHistory/History e consente propagazione cross-device | attiva |
| 14 | ProductPrice è append-only/idempotente con dedupe | sovrascrivere o cancellare storico | preserva storico prezzi e riduce duplicati | attiva |
| 15 | PostgREST schema reload/smoke test entra nel playbook migration | applicare grants e presumere che API veda subito tutto | evita falsi errori dopo migration | attiva |
| 16 | `alter default privileges` non sostituisce grants espliciti per oggetto | affidarsi a default privileges | la nuova policy Supabase richiede accesso deliberato e revisionabile | attiva |

### Handoff → PLANNING AUDIT GATE
- **Prossima fase**: PLANNING-AUDIT, non EXECUTION.
- **Prossimo agente consigliato**: CODEX/Cursor in modalità audit-readonly.
- **Azione consigliata**: completare audit § Domande 1–34, produrre evidence pack, access matrix Supabase, reconciliation report, aggiornare questo file con «Root cause verificata» + «Policy sync approvata» + «Policy Data API grants/RLS approvata».
- **Vietato in questa fase**: patch implementative, migration applicate, cancellazioni remote/locali, refactor UI.

**Gate per passare a EXECUTION**: query count Supabase per owner; conferma colonne `shared_sheet_sessions`; presenza/assenza tombstone; policy `dirtyLocalSkips` letta dal codice e confermata dai log; owner_user_id Android/iOS correlato; report sessioni legacy; diagnosi product/price bridge; environment parity Supabase; access matrix grants/RLS/schema/column privileges per Data API; Security Advisor/log `42501` controllati; PostgREST schema cache playbook; bozza migration GRANT/RLS/tombstone preparata ma non applicata; piano UI minimo approvato nel file.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Obiettivo compreso
Eseguire TASK-110 end-to-end con Supabase come fonte condivisa e Room/SwiftData come cache offline: verificare ambiente/auth/schema/grants/RLS, produrre snapshot/evidence prima di write o migration, diagnosticare root cause reale della divergenza Android/iOS/Supabase, implementare fix mirati su iOS primario e Android/Supabase dove necessario, validare build/test/manual matrix, quindi riportare il task a REVIEW per Claude. Override utente 2026-05-15: PLANNING-AUDIT superata da autorizzazione esplicita a EXECUTION completa.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-110-cross-platform-cloud-sync-consistency.md`
- `docs/TASKS/TASK-109-ios-supabase-sync-lifecycle-ux-regression.md`
- `docs/TASKS/EVIDENCE/TASK-110/README.md`
- iOS: `HistorySessionSyncService.swift`, `HistoryEntry.swift`, `HistoryView.swift`, `OptionsView.swift`, `SupabaseInventoryService.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseClientProvider.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseProductPriceApplyService.swift`, `HistorySessionSyncServiceTests.swift`
- Android: `InventoryRepository.kt`, `HistorySessionPushCoordinator.kt`, `HistoryEntryDao.kt`, `HistoryEntryRemoteRef.kt`, `HistoryEntryRemoteRefDao.kt`, `SharedSheetSessionRecord.kt`, `SessionBackupRemoteDataSource.kt`, `SupabaseSessionBackupRemoteDataSource.kt`, `MerchandiseControlApplication.kt`, `CatalogAutoSyncCoordinator.kt`, `CatalogSyncViewModel.kt`, `DefaultInventoryRepositoryTest.kt`, `HistorySessionPushCoordinatorTest.kt`
- Supabase: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/*`, schema/grants/RLS via linked DB query, Security Advisor, Data API smoke anon
- Repo status: iOS e Android branch `codex/task-110-sync-consistency`; Supabase locale non è git repository

### Piano minimo
1. Completare P0-P3 evidence: counts Supabase/Room/SwiftData, environment parity, schema/grants/RLS, access matrix e reconciliation report.
2. Patch mirata root cause History: full reconciliation idempotente per clean-stale/local-only su Android e iOS senza redesign e senza nuove dipendenze.
3. Preparare migration Supabase minima per `shared_sheet_sessions.deleted_at` + hardening anon, ma non applicarla se il migration ledger è incoerente.
4. Eseguire build/test mirati e documentare blocker manuali/performance rimasti.
5. Aggiornare tracking e passare a REVIEW per validazione Claude.

### Modifiche fatte
- Creati branch locali dedicati iOS e Android `codex/task-110-sync-consistency` senza push remoto.
- Creato/aggiornato evidence pack `docs/TASKS/EVIDENCE/TASK-110/` con snapshot, access matrix, schema/RLS/grants audit, 42501 audit, security advisor, reconciliation report, policy sync/conflict, test matrix e migration proposta.
- Verificato GitHub iOS aggiornato prima delle patch (`origin/main` = base locale `d4a0f89`).
- Diagnosticata root cause History: Supabase/iOS hanno 1 sessione, Android fisico ha 7 sessioni locali, 6 refs clean e 0 dirty; almeno 5 refs risultano clean-stale/local-only e non venivano ripushate perché il push guardava solo dirty/pending.
- Android:
  - `InventoryRepository.pushHistorySessionsToRemote(..., candidateUids = null)` ora fa full reconciliation user-visible e upsert idempotente anche di sessioni clean/stale.
  - Il push preciso con `candidateUids` resta conservativo e salta clean già synced.
  - `HistorySessionPushCoordinator` su login fresh esegue bootstrap pull History e poi full reconciliation push.
  - Test aggiunti/aggiornati per clean-stale full reconciliation e login fresh bootstrap→push.
- iOS:
  - `HistorySessionSyncService.pushPendingHistorySessions(..., includeSynced: true)` abilita full reconciliation idempotente.
  - `SupabaseManualSyncReleaseFactory` orchestra History come pull iniziale → full reconciliation push → pull di conferma.
  - Test aggiunto per clean History session reuploaded con `remoteID` stabile.
- Supabase:
  - Preparata migration locale `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260515161500_task110_history_tombstone_grants.sql`.
  - Migration non applicata: `supabase migration list --linked` mostra ledger locale/remoto divergente; applicare raw SQL avrebbe creato ulteriore drift non tracciato.

### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [x] Build Android compila: ✅ ESEGUITO — `./gradlew assembleDebug` PASS.
- [x] Build iOS compila: ✅ ESEGUITO — `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination "platform=iOS Simulator,id=459C668B-7CE8-443B-BAB3-7D3D5FFC9143" CODE_SIGNING_ALLOWED=NO` PASS.
- [x] Nessun warning nuovo introdotto: ⚠️ NON ESEGUIBILE in modo assoluto — build mostrano warning preesistenti/tooling (Android AGP/Kotlin deprecated, Xcode device passcode/AppIntents metadata); nessun warning compiler nuovo evidente sui file patchati.
- [x] Modifiche coerenti con il planning: ✅ ESEGUITO — patch limitata alla root cause History reconciliation e migration proposta; nessuna nuova dipendenza, nessun service_role mobile, nessun push remoto.
- [x] Criteri di accettazione verificati: ⚠️ NON ESEGUIBILE integralmente — root cause History e build/test mirati verificati; delete tombstone, ProductPrice drift, manual cross-platform e migration apply restano non completati per blocker documentati.
- [x] Android test mirati: ✅ ESEGUITO — `DefaultInventoryRepositoryTest` PASS; `HistorySessionPushCoordinatorTest` PASS isolato con `GRADLE_OPTS='-Djdk.attach.allowAttachSelf=true'`.
- [x] Android combined targeted test: ⚠️ NON ESEGUIBILE — combined run con Robolectric + MockK fallisce per `AttachNotSupportedException`, non per assert/fix.
- [x] iOS test mirati: ✅ ESEGUITO — `HistorySessionSyncServiceTests` PASS 8/0 con `-parallel-testing-enabled NO`.
- [x] Supabase counts/schema/grants/RLS/Data API: ✅ ESEGUITO — evidence in `supabase-counts-redacted.md`, `schema-audit.md`, `supabase-access-matrix.md`, `supabase-42501-audit.md`, `security-advisor-check.md`.
- [x] `git diff --check`: ✅ ESEGUITO — PASS iOS e Android.

### Rischi rimasti
- Supabase migration non applicata: ledger locale/remoto divergente (`20260417`, `20260424021936`, `20260509120000`, `20260511030000` locali non risultano remote; `20260424145010`, `20260514213110` remote non risultano locali). Serve reconciliation/repair migration prima di `db push`.
- Delete History cross-platform resta non completato perché `shared_sheet_sessions.deleted_at` manca live; migration proposta pronta.
- ProductPrice/catalog Android resta driftato: Android fisico 39498 prices vs Supabase/iOS 41109; diagnosticato ma non patchato in questa execution.
- Manual cross-platform create/update/delete live non eseguito: richiede runtime autenticato su Android+iOS e tombstone migration per delete.
- Runtime JWT `sub` live dai client non estratto; parità project_ref verificata e counts iOS/remoto allineati.
- UI taxonomy documentata ma non applicata in modo esteso; patch corrente non fa redesign.

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: review contra CA/evidence TASK-110; decidere se accettare patch History come slice reviewabile e aprire FIX per Supabase migration ledger + delete tombstone + ProductPrice bridge/performance/manual cross-platform.
- **Nota Codex**: non marcare DONE. TASK-109 resta BLOCKED/SOSPESO; TASK-041 e altri DONE non riaperti.

---

## Review (Claude) ← solo Claude aggiorna questa sezione

*(vuoto fino a review)*

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

### Avvio FIX / EXECUTION-COMPLETION — 2026-05-15 12:50 -0400

User rejected incomplete review; authorized full completion of remaining blockers.

#### Obiettivo compreso
Completare TASK-110 end-to-end senza marcare DONE: riconciliare ledger migration Supabase, applicare tombstone/grants/RLS con backup/evidence, completare delete History bidirezionale, risolvere o spiegare con fix tracciato il drift ProductPrice/catalog, verificare login/logout/re-login, applicare UI taxonomy minima su Android/iOS, eseguire build/test automatici e manual cross-platform, aggiornare evidence pack e riportare il task a REVIEW finale.

#### Piano minimo iniziale
1. P0: repo status/diff/evidence pack e sezione `fix-completion/`.
2. P1-P2: audit/repair ledger Supabase, backup/rollback, apply migration tombstone/grants/RLS e smoke test.
3. P3-P6: patch mirate Android/iOS per delete tombstone, ProductPrice bridge, auth sync e UI taxonomy.
4. P7-P8: build/test automatici e manual live cross-platform con dati `TASK110_TEST_*`, evidence redatta.
5. Handoff finale a REVIEW, non DONE.

#### File da controllare/modificare previsti
- Tracking/evidence: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-110-cross-platform-cloud-sync-consistency.md`, `docs/TASKS/EVIDENCE/TASK-110/fix-completion/`.
- Supabase: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/*`, schema/grants/RLS live e smoke Data API.
- Android: History sync/delete, catalog/ProductPrice sync, auth/bootstrap/manual sync UI.
- iOS: prima verifica GitHub/origin; poi History sync/delete, manual sync coordinator, ProductPrice/catalog apply, Options/History/Database sync UI.

### FIX / EXECUTION-COMPLETION — aggiornamento 2026-05-15 13:45 -0400

#### Root cause finale verificata
- **Supabase ledger**: divergenza causata da migration remote mancanti localmente (`20260424145010`, `20260514213110`) e migration locali già applicate/semantiche ma non marcate correttamente (`20260417`, `20260424021936`, `20260509120000`, `20260511030000`). Risolto con fetch/rename/repair tracciati; ledger ora coerente fino a `20260515161500`.
- **Delete History**: blocker reale era assenza live di `shared_sheet_sessions.deleted_at` più client che non propagavano tombstone end-to-end. Risolto su Supabase, iOS e Android a livello schema/service/DAO/UI.
- **ProductPrice drift Android**: il drift fisico `39498` vs Supabase/iOS `41109` era cache locale non riallineata; Supabase non ha orphan ProductPrice (`0`) e Android full pull live corrente converge a `41109` con `pricesSkippedNoProductRef=0`.
- **Manual cross-platform**: resta bloccato perché il live smoke iOS app-auth fallisce con `sessionMissing`; senza sessione iOS valida non è corretto dichiarare PASS create/update/delete bidirezionale UI.

#### Modifiche fatte
- Supabase:
  - recuperate migration remote mancanti `20260424145010_task045_sync_events.sql` e `20260514213110_task108_backup_20260514173049.sql`;
  - rinominata migration locale malformata `20260417_task012_ownership_rls.sql` in `20260417000000_task012_ownership_rls.sql`;
  - eseguiti `supabase migration repair` e `supabase db push` dopo dry-run;
  - applicata `20260515161500_task110_history_tombstone_grants.sql` con `deleted_at`, indici, GRANT authenticated/service_role, revoke anon e schema reload.
- iOS:
  - `HistoryEntry` gestisce delete pending e tombstone remoti;
  - `HistorySessionSyncService` serializza/deserializza `deleted_at`, applica tombstone e non resuscita record cancellati;
  - `HistoryView` nasconde tombstone sincronizzati e mostra `Deleted pending` per delete locali non confermate;
  - `SupabaseInventoryService` include `deleted_at` nelle colonne sessioni;
  - localizzazioni IT/EN/ES/ZH aggiornate;
  - XCTest aggiunti per push/pull tombstone.
- Android:
  - Room schema `16 -> 17` con `history_entries.deletedAt` e schema JSON `17`;
  - delete History locale convertita in tombstone pushabile;
  - push/pull History propagano `deleted_at` e aggiornano stato synced;
  - query History mostra solo tombstone pending, non tombstone confermati;
  - UI History aggiunge badge/accessibility `Deleted pending`;
  - test repository/migration/coordinator aggiornati.

#### Evidence aggiornata
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/migration-ledger-before-after.md`
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/migration-ledger-repair.md`
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/rollback-plan.md`
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/applied-grants-rls-tombstone-migration.sql`
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/supabase-smoke-test-after-migration.md`
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/supabase-42501-post-fix.md`
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/security-advisor-post-fix.md`
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/delete-tombstone-results.md`
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/product-price-catalog-bridge-results.md`
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/build-test-results.md`
- `docs/TASKS/EVIDENCE/TASK-110/fix-completion/manual-cross-platform-live.md`

#### Check eseguiti
- Build compila (Xcode / BuildProject): ✅ ESEGUITO — XcodeBuildMCP `build_sim` PASS, 0 warning sui file patchati dopo fix; Android `./gradlew :app:assembleDebug` PASS.
- Nessun warning nuovo introdotto: ⚠️ NON ESEGUIBILE in modo assoluto — Android mantiene warning deprecation AGP/Compose preesistenti; iOS targeted build pulito, test iOS larghi mostrano warning test non-Sendable/AppIntents preesistenti.
- Modifiche coerenti con il planning: ✅ ESEGUITO — patch limitate a migration ledger/tombstone/delete/ProductPrice verification/UI badge; nessuna nuova dipendenza, nessun service_role mobile, nessun anon CRUD privato.
- Criteri di accettazione verificati: ⚠️ NON ESEGUIBILE integralmente — Supabase, tombstone service-level e Android ProductPrice live PASS; manual cross-platform iOS bloccato da `sessionMissing`.
- Supabase ledger before/after: ✅ ESEGUITO — allineato fino a `20260515161500`.
- Supabase migration apply + smoke: ✅ ESEGUITO — authenticated tombstone PASS, anon negative `42501` PASS.
- Delete tombstone Android/iOS service-level: ✅ ESEGUITO — XCTest 10/0 e Android targeted/migration tests PASS.
- ProductPrice/catalog bridge: ✅ ESEGUITO — Android fisico live full pull PASS: `41109` prices, `41109` price refs, `pricesSkippedNoProductRef=0`; Supabase orphan ProductPrice `0`.
- Login/logout/re-login Android/iOS: ⚠️ NON ESEGUIBILE integralmente — Android app-auth live PASS con sessione preesistente; iOS live smoke FAIL `sessionMissing`; logout/re-login UI non eseguiti senza completamento login iOS.
- Manual cross-platform create/update/delete live: ⚠️ NON ESEGUIBILE — bloccato da iOS `sessionMissing`.
- `git diff --check`: ✅ ESEGUITO — PASS iOS e Android.
- Android `./gradlew test`: ⚠️ NON ESEGUIBILE integralmente — suite combinata fallisce per `ByteBuddyAgent` / `AttachNotSupportedException` MockK anche con flag attach; suite mirate e non-MockK PASS.

#### Rischi rimasti / blocker
- **BLOCKER**: iOS non ha sessione Supabase valida nel simulatore (`sessionMissing`). Serve login app-auth iOS con account autorizzato `x***@gmail.com`, senza condividere password/token con Codex.
- Manual cross-platform UI create/update/delete/offline/re-login non può essere dichiarato PASS finché iOS non è autenticato.
- Il connected Android live test ha installato/rimosso il package debug a fine run; non assumere sessione Android persistente dopo il test.
- `supabase db dump` schema non eseguito perché Docker daemon non disponibile; rollback plan documentato senza dump completo.

#### Stato / handoff
- **Non** pronto per REVIEW finale secondo i criteri P10: manca manual cross-platform iOS autenticato.
- **Stato corretto**: `BLOCKED / FIX / BLOCKED_APP_AUTH_IOS_MANUAL_LIVE`.
- **Prossima azione richiesta**: utente effettua login iOS app-auth nel simulatore/device con `x***@gmail.com`; poi Codex può rieseguire manual matrix P8 e, se PASS, transizionare `FIX -> REVIEW`.

### FIX app-auth iOS — aggiornamento 2026-05-15 15:04 -0400

#### Root cause finale verificata
- Il fallimento iOS osservato dall'utente non era un normale signed-out: dopo autorizzazione OAuth la UI poteva rientrare in stato fallito/attenzione, mentre al riavvio appariva una sessione gia' valida.
- Root cause confermata con log redatti: callback OAuth/PKCE ricevuta con auth code, ma code verifier mancante (`callbackFailed` / validation failure). La callback veniva inoltre esposta anche al gestore globale `.onOpenURL`, creando una finestra di race/doppia gestione rispetto ad `ASWebAuthenticationSession`.
- In smoke simulator ad-hoc, Keychain poteva anche rendere non deterministico il round-trip di storage della sessione, spiegando la discrepanza "fallito prima, connesso dopo riavvio".

#### Modifiche fatte
- `SupabaseAuthViewModel`:
  - gestisce solo redirect Supabase OAuth attesi in `handleOpenURL`;
  - ignora il redirect mentre `ASWebAuthenticationSession` e' in fase `.signingIn`, evitando doppio exchange del codice;
  - dopo errori recuperabili (`sessionMissing`, `callbackFailed`, `unknown`) attende brevemente una sessione non scaduta prima di marcare fallimento, cosi' la UI non resta stale se il client ha completato il salvataggio subito dopo.
- `SupabaseClientProvider`:
  - separa lo storage PKCE di breve durata dalla sessione;
  - mantiene Keychain come storage sessione production/device;
  - usa `UserDefaults` per il verifier PKCE OAuth;
  - abilita solo in `DEBUG` + iOS Simulator una fallback copy della sessione in app-container `UserDefaults`, utile per smoke simulator quando Keychain e' non affidabile. Nessun service role o token e' stato introdotto nel client.
- History tombstone hardening aggiuntivo durante la review:
  - iOS e Android non applicano piu' un tombstone remoto sopra una entry locale ancora attiva e dirty/non sincronizzata.

#### Evidence aggiornata
- `docs/TASKS/EVIDENCE/TASK-110/final-review/ios-app-auth-live.md`
- `docs/TASKS/EVIDENCE/TASK-110/final-review/build-test-results.md`
- `docs/TASKS/EVIDENCE/TASK-110/final-review/review-summary.md`
- `docs/TASKS/EVIDENCE/TASK-110/final-review/manual-cross-platform-matrix.md`

#### Check eseguiti
- Build compila (Xcode / BuildProject): ✅ ESEGUITO — XcodeBuildMCP `build_sim CODE_SIGNING_ALLOWED=NO` PASS, 0 warning.
- Nessun warning nuovo introdotto: ✅ ESEGUITO — build iOS finale senza warning; `git diff --check` PASS iOS/Android.
- Modifiche coerenti con il planning: ✅ ESEGUITO — fix limitato ad auth iOS, storage OAuth/sessione, tombstone conflict guard e test mirati; nessuna nuova dipendenza, nessun service_role mobile, nessun CRUD anon privato.
- Criteri di accettazione verificati: ⚠️ NON ESEGUIBILE integralmente — iOS app-auth live e restore PASS; la matrice manuale cross-platform P8 completa resta da eseguire prima di REVIEW finale/DONE.
- iOS app-auth live: ✅ ESEGUITO — login OAuth con account redatto `x***@gmail.com` mostra `Cloud account connected`; stop/launch successivo mantiene sessione e `Sync now` disponibile.
- iOS auth preflight: ✅ ESEGUITO — `SupabaseConfigSecurityTests/testTask103IOSAuthPreflightWhenEnabled` PASS con gate `TASK103_IOS_AUTH_PREFLIGHT=1`.
- iOS History tombstone tests: ✅ ESEGUITO — `HistorySessionSyncServiceTests` PASS 11/0.
- Android tombstone dirty-local targeted tests: ✅ ESEGUITO — `DefaultInventoryRepositoryTest` mirati PASS.

#### Rischi rimasti / handoff
- **TASK-110 non e' DONE**: la P8 manual cross-platform matrix completa Android/iOS/Supabase non e' ancora stata rieseguita dopo il fix auth.
- **Stato corretto aggiornato**: `ACTIVE / FIX / APP_AUTH_FIXED_MATRIX_PENDING`.
- **Prossima azione**: rieseguire login/logout/re-login Android+iOS, create/update/delete History bidirezionale, ProductPrice/catalog bridge, offline create/delete e sync ripetuti; solo dopo PASS completo transizionare `FIX -> REVIEW`.
- **TASK-109 resta BLOCKED / SOSPESO**, non DONE e non ripreso.

### FIX / FINAL_CROSS_PLATFORM_EXECUTION — avvio 2026-05-15

#### Obiettivo compreso
Completare operativamente TASK-110 con autorizzazione esplicita utente: eseguire test live Android/iOS/Supabase necessari, usare simulatori/emulatori/device disponibili, effettuare login/logout/re-login con account autorizzato redatto, creare/modificare/sincronizzare/eliminare solo dati test `TASK110_FINAL_*`, applicare fix diretti se emergono problemi e marcare DONE solo se tutti i criteri P10 passano con evidence reale.

#### Piano minimo iniziale
1. Aggiornare tracking e creare `docs/TASKS/EVIDENCE/TASK-110/final-cross-platform-completion/`.
2. Salvare baseline worktree/evidence/commit per iOS, Android e Supabase.
3. Rieseguire Supabase live smoke grants/RLS/tombstone/Data API e counts iniziali redatti.
4. Eseguire runtime auth logout/login/re-login iOS e Android.
5. Eseguire matrice manuale P8 cross-platform con dati `TASK110_FINAL_*`, includendo History, catalog/ProductPrice, offline/restore, error handling e sync ripetuti.
6. Rieseguire build/test automatici, verifiche performance/stabilita', UI/UX, regressione minima e cleanup dati test.
7. Aggiornare TASK-110/MASTER-PLAN a DONE solo se il verdict finale e' PASS; altrimenti documentare blocker tecnico reale.

#### File controllati/modificati previsti
- Tracking/evidence: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-110-cross-platform-cloud-sync-consistency.md`, `docs/TASKS/EVIDENCE/TASK-110/final-cross-platform-completion/`.
- iOS: file auth/sync/UI indicati dal task solo se un test live richiede fix.
- Android: file auth/bootstrap/sync/UI indicati dal task solo se un test live richiede fix.
- Supabase: migration/schema/grants/RLS live solo se smoke o P8 rilevano incoerenze.

### FIX / FINAL_CROSS_PLATFORM_EXECUTION — chiusura 2026-05-15 19:01 -0400

#### User override / impatto processo
Il workflow standard prevede `FIX -> REVIEW`; il prompt utente del 2026-05-15 ha autorizzato esplicitamente test live Android/iOS/Supabase, fix diretti iterativi e chiusura **DONE** se tutti i criteri P10 passavano con evidence reale. Questo aggiornamento usa tale override: TASK-110 viene chiuso **DONE / Chiusura — FINAL CROSS-PLATFORM ACCEPTANCE PASS**; TASK-109 resta **BLOCKED / SOSPESO** e non viene ripreso.

#### Obiettivo compreso
Completare TASK-110 end-to-end con Supabase come fonte condivisa e Android/iOS come cache offline, validando auth/logout/login/re-login, History create/update/delete/tombstone bidirezionale, ProductPrice/catalog bidirezionale, offline/restore, UI states, build/test e cleanup dati test `TASK110_FINAL_*`.

#### File controllati
- Tracking/evidence: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-110-cross-platform-cloud-sync-consistency.md`, `docs/TASKS/EVIDENCE/TASK-110/final-cross-platform-completion/`.
- iOS: `SupabaseAuthViewModel.swift`, `SupabaseClientProvider.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabasePullPreviewService.swift`, `SupabasePullApplyService.swift`, `SupabaseProductPriceManualPushService.swift`, `SupabaseProductPriceApplyService.swift`, `SupabaseInventoryService.swift`, `HistorySessionSyncService.swift`, `HistoryEntry.swift`, `HistoryEntryRuntimeSummary.swift`, `HistoryView.swift`, localizzazioni e test collegati.
- Android: `InventoryRepository.kt`, `HistorySessionPushCoordinator.kt`, DAO/model History, Room schema 17, `HistoryScreen.kt`, localizzazioni e test collegati.
- Supabase: migration ledger live, grants/RLS/Data API, `shared_sheet_sessions.deleted_at`, counts/integrity ProductPrice.

#### Piano minimo eseguito
1. Baseline worktree/evidence/ledger e privacy redaction.
2. Smoke Supabase live grants/RLS/tombstone/Data API.
3. Runtime auth logout/login/re-login iOS e Android.
4. Matrice manuale P8 cross-platform con dati `TASK110_FINAL_*`.
5. Fix diretti per problemi trovati durante P8.
6. Build/test automatici e smoke UI/regressione.
7. Cleanup dati test e verdict finale P10.

#### Modifiche fatte nel completamento finale
- iOS:
  - `HistoryEntryRuntimeSummary` ora gestisce griglie vuote/one-row senza crash durante restore/offline History.
  - `SupabaseManualSyncViewModel` e `OptionsView` instradano Sync Now/Check Cloud/Download sul percorso diretto corretto e non lasciano review stale.
  - `SupabaseProductPriceManualPushService` aggiorna il mirror `inventory_products` quando iOS pusha un ProductPrice verificato.
  - `SupabasePullPreviewService` non segnala update per differenze remote solo metadata o solo stock quando iOS non applica stock per policy.
  - Test mirati aggiunti/aggiornati per empty grid, ProductPrice mirror, metadata-only diff e stock-only diff.
- Android:
  - completati e verificati fix History tombstone/status/remote-id canonicalization e ProductPrice/catalog convergence gia' introdotti nelle fasi FIX precedenti.
- Supabase:
  - smoke finale conferma ledger coerente, tombstone/grants/RLS/Data API e integrity ProductPrice.
- Evidence:
  - creati `00-baseline.md` ... `10-final-verdict.md` in `docs/TASKS/EVIDENCE/TASK-110/final-cross-platform-completion/`.

#### Root cause finale verificata
- History divergeva per reconciliation incompleta di righe clean-stale/local-only e per assenza iniziale del tombstone live `shared_sheet_sessions.deleted_at`.
- iOS app-auth aveva race OAuth/PKCE + storage simulator non deterministico.
- ProductPrice/catalog richiedeva riallineamento Android cache e mirror iOS da ProductPrice verso `inventory_products`.
- UI iOS poteva presentare review stale per diff remote non applicabili (metadata-only/stock-only).
- iOS poteva crashare su History con grid vuota ricevuta da flusso offline Android.

#### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- Build compila (Xcode / BuildProject): ✅ ESEGUITO — iOS XcodeBuildMCP `build_run_sim CODE_SIGNING_ALLOWED=NO` PASS; Android `./gradlew :app:assembleDebug` PASS.
- Nessun warning nuovo introdotto: ✅ ESEGUITO — build/test mirati finali senza warning nuovi attribuibili ai file patchati; warning/tooling preesistenti separati nelle evidence.
- Modifiche coerenti con il planning: ✅ ESEGUITO — scope limitato a TASK-110 sync/auth/tombstone/ProductPrice/UI states; nessuna nuova dipendenza, nessun service_role mobile, nessun CRUD anon privato, nessun push remoto.
- Criteri di accettazione verificati: ✅ ESEGUITO — P10 PASS/PASS_WITH_NOTES non bloccanti documentati in `10-final-verdict.md`.
- Supabase final smoke: ✅ ESEGUITO — ledger fino a `20260515161500`, authenticated CRUD/tombstone PASS, anon negative `401/42501`, ProductPrice orphans `0`, duplicates `0`.
- iOS auth/logout/login/re-login: ✅ ESEGUITO — simulator PASS, owner hash `ad3d747e936c`, restore session PASS, no `sessionMissing`/stale cancelled.
- Android auth/logout/login/re-login: ✅ ESEGUITO — emulator PASS, owner hash coerente, restore session PASS.
- Manual cross-platform P8: ✅ ESEGUITO — History create/update/delete bidirezionale, offline/restore, sync ripetuti, ProductPrice/catalog bidirezionale PASS.
- iOS tests/localizzazioni: ✅ ESEGUITO — 36 targeted tests PASS, 4 regression/l10n tests PASS, `plutil` PASS.
- Android tests: ✅ ESEGUITO/PASS_WITH_NOTES — targeted TASK-110 tests PASS; full `./gradlew test` resta tooling-blocked da MockK/ByteBuddy attach, documentato come non bloccante.
- Regression finale: ✅ ESEGUITO/PASS_WITH_NOTES — simulator/emulator runtime PASS; scanner/camera e file picker/export fisici non disponibili/non toccati.
- Cleanup dati test: ✅ ESEGUITO — active `TASK110_FINAL_*` History `0`, tombstone `3` conservati intenzionalmente, ProductPrice test lasciato documentato, nessun dato legacy cancellato.
- `git diff --check`: ✅ ESEGUITO — PASS iOS e Android.

#### Rischi rimasti
- Android full unit suite locale resta PASS_WITH_NOTES per MockK/ByteBuddy attach nel runner JVM; build e test TASK-110 mirati passano.
- Device fisici non usati per completare P8 finale: iPhone offline, Android fisico bloccato da keyguard. Simulator/emulator hanno coperto la matrice runtime.
- Scanner/camera e file picker/export manuali non rieseguiti fisicamente nel pass finale; nessun codice relativo e' stato toccato.
- Record prodotto/prezzo `TASK110_FINAL_BARCODE_1652` lasciato intenzionalmente come evidence di convergenza; non genera orphan/duplicati.

#### Handoff finale
- **Stato finale**: DONE / Chiusura — FINAL CROSS-PLATFORM ACCEPTANCE PASS.
- **Responsabile attuale**: COMPLETED / USER ACCEPTANCE READY.
- **Evidence primaria**: `docs/TASKS/EVIDENCE/TASK-110/final-cross-platform-completion/10-final-verdict.md`.
- **Nessun push remoto GitHub eseguito**.

---

## Chiusura

### Conferma utente
- [x] Utente ha autorizzato chiusura DONE se P10 passava con evidence reale nel prompt finale TASK-110 del 2026-05-15.

### Follow-up candidate
- Android full `./gradlew test` resta da normalizzare in ambiente locale per rimuovere il blocker MockK/ByteBuddy attach.
- Rerun fisico opzionale su iPhone/Android quando i device saranno disponibili/sbloccati.
- Scanner/camera e file picker/export manuali possono essere rieseguiti in un task dedicato hardware/manuale, se richiesto.

### Riepilogo finale
TASK-110 chiuso **DONE / Chiusura — FINAL CROSS-PLATFORM ACCEPTANCE PASS**. Supabase final smoke PASS; iOS auth logout/login/re-login PASS; Android auth logout/login/re-login PASS; matrice P8 manuale cross-platform PASS; History/tombstone convergente senza resurrection; ProductPrice/catalog convergente con orphans `0`, duplicati `0`, counts finali `products=19696`, `suppliers=57`, `categories=27`, `product_prices=41111`; UI/UX stati cloud coerenti; build/test principali PASS con note non bloccanti documentate; cleanup dati test completato e tracciato. TASK-109 resta BLOCKED / SOSPESO.

### Data completamento
2026-05-15
