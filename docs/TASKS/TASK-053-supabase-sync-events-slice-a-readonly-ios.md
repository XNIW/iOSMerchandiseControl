# TASK-053: Supabase `sync_events` Slice A iOS — DTO + service read-only + test decode/fake

## Informazioni generali
- **Task ID**: TASK-053
- **Titolo**: Supabase sync_events Slice A iOS: DTO + service read-only + test decode/fake
- **File task**: `docs/TASKS/TASK-053-supabase-sync-events-slice-a-readonly-ios.md`
- **Stato**: ACTIVE
- **Fase attuale**: EXECUTION
- **Responsabile attuale**: Cursor / Codex
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-06 *(Execution tecnica Slice A read-only completata; handoff pronto per REVIEW. Per check utente, tracking lasciato ACTIVE / EXECUTION.)*
- **Ultimo agente che ha operato**: Codex / Executor

## Dipendenze
- **Dipende da**:
  - **TASK-052** — ACTIVE / READY FOR REVIEW documentale; non DONE e non chiuso da questa execution.
  - **TASK-048 -> TASK-051** — catena ProductPrice completata; pattern read-only, fake/mock, guard anti-scope.
  - Supabase locale: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`.
  - Android / Supabase come riferimento funzionale: TASK-065 object/array/extra fields, TASK-068 PARTIAL, TASK-070 retry outbox, TASK-071 `p_changed_count > 1000`.

## Scopo
Implementare solo la Slice A read-only iOS per `sync_events`:
- DTO Swift `Decodable` coerente con lo schema locale letto.
- Service read-only per leggere gli ultimi N eventi.
- Decoder tollerante per campi extra e risposta object/array dove applicabile.
- XCTest con fixture e fake/mock, senza chiamate live Supabase.

## Non incluso
- Nessuna UI / `OptionsView`.
- Nessuna write Supabase.
- Nessuna chiamata RPC mutante.
- Nessun outbox locale/remoto.
- Nessun realtime subscribe.
- Nessun background sync.
- Nessuna modifica Android.
- Nessuna modifica schema Supabase, migration, RLS, grant o publication.
- Nessun uso di `service_role`, token reali o dati utente reali nei test.

## Fonti lette
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-052-supabase-sync-events-outbox-foundation-ios.md`
- `docs/TASKS/TASK-048-supabase-productprice-foundation-ios.md`
- `docs/TASKS/TASK-049-supabase-productprice-apply-locale-swiftdata-ios.md`
- `docs/TASKS/TASK-050-supabase-productprice-manual-push-preflight-dry-run-ios.md`
- `docs/TASKS/TASK-051-supabase-productprice-push-live-manuale-controllato-ios.md`
- `docs/TASKS/TASK-045-supabase-live-manual-validation-ios-small-dataset.md`
- `docs/TASKS/TASK-046-supabase-baseline-recovery-full-pull-ios.md`
- `iOSMerchandiseControl/SupabaseClientProvider.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabaseInventoryDTOs.swift`
- `iOSMerchandiseControl/SupabaseProductPricePreviewService.swift`
- test Supabase esistenti in `iOSMerchandiseControlTests/`
- `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`
- `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/README.md`
- `/Users/minxiang/Desktop/MerchandiseControlSupabase/MASTER_PLAN.md`
- `/Users/minxiang/Desktop/MASTER-PLAN Android.md`
- `/Users/minxiang/Desktop/MASTER_PLAN Supabase.md`

## Schema locale verificato
Fonte locale: `20260424021936_task045_sync_events.sql`.

Tabella `public.sync_events`:
- `id bigint generated always as identity primary key`
- `owner_user_id uuid not null`
- `store_id uuid null`
- `domain text not null` con check locale `catalog | prices`
- `event_type text not null` con check locale `catalog_changed | prices_changed | catalog_tombstone | prices_tombstone`
- `source text null`
- `source_device_id text null`
- `batch_id uuid null`
- `client_event_id text null`
- `changed_count integer not null default 0`, check `>= 0`
- `entity_ids jsonb null`, check object se presente
- `created_at timestamptz not null default now()`
- `expires_at timestamptz null`
- `metadata jsonb not null default '{}'::jsonb`, check object

RLS/grants/publication locali:
- RLS enabled.
- Policy SELECT owner-scoped: `owner_user_id = auth.uid()`.
- `authenticated` ha solo SELECT sulla tabella.
- RPC `record_sync_event(...)` esiste nel locale, ritorna single row/object (`returns public.sync_events`) e valida `p_changed_count` 0...1000, ma TASK-053 non la chiama.
- `sync_events` viene aggiunta alla publication `supabase_realtime` se presente, ma TASK-053 non introduce subscribe.

Stato live:
- Non verificato da questa execution. Locale != live finché non auditato separatamente.

## Criteri di accettazione TASK-053
- [ ] DTO `sync_events` read-only coerente con schema locale reale.
- [ ] Decoder ignora campi extra.
- [ ] Decoder supporta object/array dove applicabile.
- [ ] Date `created_at` / `expires_at` parseate con percorso stabile.
- [ ] Service read-only legge ultimi N eventi, default 50, massimo documentato.
- [ ] Ordinamento deterministico su `created_at` e `id`, coerente con schema locale.
- [ ] Nessuna write Supabase, nessuna RPC mutante, nessun outbox/realtime/background.
- [ ] Test con fixture/fake/mock; nessuna chiamata live, nessun token o dato reale.
- [ ] Grep/check no-write eseguito e documentato.
- [ ] Handoff finale verso REVIEW compilato; TASK-053 non marcato DONE.

## Execution (Codex)

### Obiettivo compreso
Avviare una nuova execution tecnica separata da TASK-052: implementare Slice A read-only per `sync_events` iOS, senza UI e senza qualunque side effect cloud o locale.

### Piano minimo
1. Creare tracking TASK-053 e aggiornare `MASTER-PLAN`.
2. Aggiungere DTO `RemoteSyncEventRow` + decoder object/array tollerante.
3. Aggiungere service read-only con protocol/fake-friendly, default 50 e max 200.
4. Aggiungere XCTest decode/service/no-write con fixture locali.
5. Eseguire test/build mirati disponibili e grep anti-scope.
6. Aggiornare questa sezione e compilare handoff a REVIEW.

### File previsti
- `docs/TASKS/TASK-053-supabase-sync-events-slice-a-readonly-ios.md`
- `docs/MASTER-PLAN.md`
- `iOSMerchandiseControl/SupabaseSyncEventDTOs.swift`
- `iOSMerchandiseControl/SupabaseSyncEventPreviewService.swift`
- `iOSMerchandiseControlTests/SupabaseSyncEventPreviewServiceTests.swift`

### Azioni eseguite
- Creato DTO `RemoteSyncEventRow` in `SupabaseSyncEventDTOs.swift`, aderente allo schema locale `sync_events` letto:
  - `id` `Int64`, UUID opzionali/non opzionali coerenti, `changedCount` `Int`, `createdAt` / `expiresAt` `Date`.
  - `entityIDs` e `metadata` tramite `SyncEventJSONValue`, senza modellare business logic o payload sensibili.
- Aggiunto decoder `SyncEventRowsResponse` tollerante a risposta object oppure array, utile per allineamento al rischio Android TASK-065 senza chiamare RPC.
- Aggiunto parser date stabile per shape ISO/Supabase timestamptz.
- Aggiunto `SupabaseSyncEventPreviewService` con protocol `SupabaseSyncEventPreviewFetching` e `SupabaseSyncEventRemoteReader` production read-only:
  - default ultimi **50** eventi;
  - massimo **200** eventi;
  - ordinamento deterministico `created_at desc`, `id desc`;
  - query solo `from("sync_events").select(...).order(...).limit(...)`;
  - errori PostgREST/decoding convertiti in `SupabaseInventoryServiceError`.
- Aggiunti XCTest `SupabaseSyncEventPreviewServiceTests`:
  - decode JSON valido;
  - campi extra ignorati;
  - response array;
  - response object;
  - date parsing;
  - default limit 50;
  - clamp max 200;
  - fake/mock senza Supabase live;
  - source scan read-only sui file production.

### Azioni non eseguite
- Nessuna UI / `OptionsView`.
- Nessuna write Supabase.
- Nessuna chiamata RPC mutante.
- Nessun outbox.
- Nessun realtime subscribe.
- Nessun background sync.
- Nessuna modifica Android.
- Nessuna modifica Supabase SQL/RLS/grant/publication.
- Nessuna chiamata live Supabase nei test.

### Check eseguiti
- ✅ ESEGUITO — **Build compila (Debug Simulator)**: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — **XCTest mirati TASK-053**: `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:iOSMerchandiseControlTests/SupabaseSyncEventPreviewServiceTests` → **TEST SUCCEEDED**, 9/9 test passati.
- ✅ ESEGUITO — **Destination retry documentato**: primo comando test con `name=iPhone 16e` senza `OS=26.2` non ha trovato la destination; rerun con OS esplicito PASS.
- ✅ ESEGUITO — **Nessun warning nuovo introdotto (se verificabile)**: build/test PASS; unico warning osservato = AppIntents metadata extraction skipped, gia' noto/preesistente nella catena TASK-050/051.
- ✅ ESEGUITO — **Modifiche coerenti con planning**: implementati solo DTO/service read-only/test fake; niente UI/write/outbox/realtime/background.
- ✅ ESEGUITO — **Criteri di accettazione verificati**: CA DTO, object/array/extra fields, date parsing, limit default/max, fake/mock, no live, no UI e no write coperti da test/static check.
- ✅ ESEGUITO — **Grep no-write production Swift**: `rg -n "record_sync_event|\\.insert\\(|\\.upsert\\(|\\.update\\(|\\.delete\\(|\\.rpc\\(|\\.channel\\(|\\.subscribe\\(|BGTask" iOSMerchandiseControl/SupabaseSyncEventDTOs.swift iOSMerchandiseControl/SupabaseSyncEventPreviewService.swift` → nessun match.
- ✅ ESEGUITO — **Static source scan test**: `testProductionSyncEventSourcesExposeReadOnlySurfaceOnly` passa sui file production.
- ✅ ESEGUITO — **Whitespace**: `git diff --check` PASS; `git diff --no-index --check /dev/null` sui nuovi file Swift/test/task non riporta errori.
- ✅ ESEGUITO — **Tracking**: `MASTER-PLAN` indica TASK-053 come task attivo `ACTIVE / EXECUTION`; TASK-052 resta non DONE / ready for review documentale separata.
- ✅ ESEGUITO — **Nessuna UI modificata**: `git status --short iOSMerchandiseControl/OptionsView.swift` senza output.
- ✅ ESEGUITO — **Nessuna API mutante Supabase introdotta nei file production TASK-053**: grep no-write production Swift senza match; unica query production nuova e' read-only `select` su `sync_events`.

### Rischi residui
- Stato live Supabase non verificato: questa execution usa schema locale e non assume locale = live.
- `record_sync_event` resta fuori perimetro: il decoder object/array e' preparatorio/testabile, non una chiamata RPC.
- TASK-052 resta da review separata e non viene marcata DONE.
- Per istruzione utente, TASK-053 resta formalmente `ACTIVE / EXECUTION` nel tracking; prossimo passo operativo consigliato e' REVIEW.

### Handoff post-execution
**READY FOR REVIEW — TASK-053 Slice A read-only.**

- **Implementato**: DTO `sync_events`, parser date, JSON value decoder, envelope object/array, service read-only ultimi N eventi, fake-friendly protocol, XCTest locali.
- **Non implementato**: UI DEBUG, write Supabase, `record_sync_event`, outbox, realtime, background sync, Android, schema Supabase.
- **File toccati**:
  - `docs/MASTER-PLAN.md`
  - `docs/TASKS/TASK-053-supabase-sync-events-slice-a-readonly-ios.md`
  - `iOSMerchandiseControl/SupabaseSyncEventDTOs.swift`
  - `iOSMerchandiseControl/SupabaseSyncEventPreviewService.swift`
  - `iOSMerchandiseControlTests/SupabaseSyncEventPreviewServiceTests.swift`
- **File gia' presenti/non miei nel working tree**:
  - `docs/TASKS/TASK-052-supabase-sync-events-outbox-foundation-ios.md` era gia' non tracciato all'avvio; letto e preservato, non chiuso.
- **Prossimo passo consigliato**: REVIEW di TASK-053. Eventuale TASK-054 / Slice B solo dopo approvazione separata, eventualmente UI DEBUG read-only in `OptionsView`.

## Review (Claude)
*(Da compilare in REVIEW.)*

## Fix (Codex)
*(N/A finché non esiste review con CHANGES_REQUIRED.)*

## Chiusura
- [ ] Utente ha confermato il completamento dopo REVIEW.
