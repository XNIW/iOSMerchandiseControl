# TASK-112 - Audit Gap Matrix

Timestamp: 2026-05-20 20:34 -0400

Legenda: `coperto`, `parziale`, `mancante`, `bloccato`, `non applicabile`.

## Dominio matrice

| Dominio | Stato | Nota |
|---|---|---|
| suppliers/fornitori | parziale | Schema Supabase e Android refs presenti; iOS/Android auto E2E non verificato. |
| categories/categorie | parziale | Come suppliers. |
| products/prodotti | parziale | Push/pull esistenti, automaticita' cross-platform non provata. |
| ProductPrice/storico prezzi | parziale | Schema unique e paging storico presenti; offline/outbox e live gated mancanti. |
| HistoryEntry/History sessions | parziale | History coordinators e shared_sheet_sessions presenti; sync_events non copre History. |
| tombstone/delete | parziale | Tombstone DB presente; conflict/offline live non provato. |
| remote refs/bridges | parziale | Android Room refs e iOS baseline/ref services esistono; recovery completa non provata. |
| sync_events | parziale | Catalog/prices coperti parzialmente; History e retention gap mancanti. |
| outbox | parziale | sync_events outbox presente; business outbox generale mancante. |
| watermarks | parziale | Android sync_event_watermarks presente; iOS equivalente non completo. |
| baselines | parziale | iOS baseline presente; semantics last-success non completamente provate. |
| offline writes | mancante | Atomicita' local DB + outbox non dimostrata per tutti i domini. |
| reconnect push | parziale | Android coperto staticamente; iOS mancante NWPath. |
| reconnect pull | parziale | Android events/foreground; iOS foreground check parziale. |
| conflict handling | mancante | Policy deterministica non implementata/provata per tutti i domini. |
| account boundary | parziale | Owner/RLS e reset auth esistono; pending/outbox switch live non provato. |
| schema/version mismatch | parziale | Error classification esiste, ma UI action-needed e retry policy non provate. |
| crash/retry recovery | mancante | App kill/restart with pending non verificato. |
| Options status card | mancante | CTA pubbliche ancora presenti. |

## CA-01..CA-68 audit state

| CA | Stato | Nota |
|---|---|---|
| CA-01 | coperto | Planning/task/MASTER aggiornati in execution. |
| CA-02 | mancante | CTA pubbliche iOS/Android ancora presenti. |
| CA-03 | parziale | Trigger auth/foreground esistono, non E2E. |
| CA-04 | bloccato | Live iOS -> Android non eseguito. |
| CA-05 | bloccato | Live Android -> iOS non eseguito. |
| CA-06 | parziale | Schema e servizi presenti, live tombstone/create/update non eseguiti. |
| CA-07 | parziale | ProductPrice paging/schema presenti, perf/live non eseguiti TASK-112. |
| CA-08 | parziale | History services presenti, cross-platform live non eseguito. |
| CA-09 | mancante | Offline-first completo non provato. |
| CA-10 | parziale | Bootstrap Android/iOS foreground parziale; clean install live non eseguito. |
| CA-11 | mancante | Conflict policy non testata. |
| CA-12 | parziale | Android sync_events gap support parziale; iOS mancante realtime. |
| CA-13 | parziale | Hardening storico presente; TASK-112 perf smoke non eseguito. |
| CA-14 | parziale | Nessun evidence TASK-112 su scroll Database. |
| CA-15 | bloccato | SQL live read-back non eseguito. |
| CA-16 | parziale | Error classification/copy parziali. |
| CA-17 | mancante | Sensitive log scan TASK-112 non eseguito. |
| CA-18 | mancante | Build/test iOS TASK-112 non eseguiti. |
| CA-19 | mancante | Build/test Android TASK-112 non eseguiti. |
| CA-20 | bloccato | Cross-platform live gated non eseguito. |
| CA-21 | coperto | Processo vieta DONE senza live gate. |
| CA-22 | parziale | Android tracker e iOS lifecycle gate parziali. |
| CA-23 | parziale | Idempotenza ProductPrice/sync_events parziale, crash replay mancante. |
| CA-24 | parziale | RLS/owner/reset presenti, account switch live mancante. |
| CA-25 | parziale | Options onAppear non avvia full sync staticamente; log test mancante. |
| CA-26 | parziale | Android debounce presente; iOS/network flapping mancante. |
| CA-27 | mancante | Release diagnostics/source scan non eseguito. |
| CA-28 | mancante | Accessibility smoke TASK-112 non eseguito. |
| CA-29 | parziale | Schema mismatch audit statico solo parziale. |
| CA-30 | parziale | Reason code non centralizzati su tutti i full reconciliation. |
| CA-31 | mancante | Kill/restart pending recovery non provato. |
| CA-32 | parziale | Import/generate dirty-set non provato TASK-112. |
| CA-33 | parziale | Local DB status esiste; no-sync-storm log mancante. |
| CA-34 | coperto | Freshness contract documentato; runtime resta parziale. |
| CA-35 | mancante | Conflict per dominio non provato. |
| CA-36 | parziale | Invarianti schema presenti; live/read-back mancante. |
| CA-37 | coperto | Safety policy prefissi/cleanup documentata, nessuna mutation eseguita. |
| CA-38 | parziale | Retry/schema compatibility non provata. |
| CA-39 | parziale | Go/no-go audit iniziale creato; review finale mancante. |
| CA-40 | parziale | Semantics last success non completamente testata. |
| CA-41 | parziale | UI status card non ancora patchata. |
| CA-42 | mancante | Scroll/selection apply automatico non testato. |
| CA-43 | mancante | Atomic local write + outbox non dimostrata. |
| CA-44 | parziale | Outbox sync_events persistente, non business outbox/kills. |
| CA-45 | parziale | Android reconnect statico, iOS mancante. |
| CA-46 | parziale | Android debounce, no full cross-platform flapping sim. |
| CA-47 | parziale | Unique/idempotency parziale; live replay mancante. |
| CA-48 | parziale | Android pull/drain parziale; iOS/live mancante. |
| CA-49 | parziale | Baseline/watermark presenti; atomic advancement non provato. |
| CA-50 | mancante | Offline import/generate large non provato. |
| CA-51 | parziale | ProductPrice unique/paging; offline reconnect mancante. |
| CA-52 | parziale | History fingerprint/remote refs parziali; retry live mancante. |
| CA-53 | mancante | Offline tombstone vs remote update non provato. |
| CA-54 | mancante | Offline UI status card senza CTA non implementata. |
| CA-55 | parziale | Android network callback; iOS NWPath mancante. |
| CA-56 | mancante | Local mutation + outbox atomicita' non provata. |
| CA-57 | mancante | Recovery scan local-without-outbox non provato. |
| CA-58 | parziale | Ordering presente in alcuni sync paths; scheduler dependency graph non unico. |
| CA-59 | parziale | Alcuni summary/partial counters; partial ack lane generale mancante. |
| CA-60 | parziale | Android validated network + error classifier; truth table completa mancante. |
| CA-61 | mancante | Long-offline retention gap policy runtime non implementata/provata. |
| CA-62 | mancante | Storage failure UX/fault injection non provata. |
| CA-63 | parziale | Priorita' implicite, queue fairness esplicita mancante. |
| CA-64 | mancante | Offline pending UI TASK-112 non implementata/provata. |
| CA-65 | mancante | Backend reachability preflight rate-limit non provato. |
| CA-66 | parziale | Outbox pruning sync_events parziale, audit generale mancante. |
| CA-67 | coperto | Audit segnala NO_GO offline-first prima di CTA. |
| CA-68 | mancante | Fake clock/scheduler tests non presenti per entrambe. |

## Test scenario 1..62 audit state

| # | Stato | Nota |
|---|---|---|
| 1 | bloccato | iOS clean install signed-in live non eseguito. |
| 2 | bloccato | Android clean install signed-in live non eseguito. |
| 3 | bloccato | iOS -> Android live non eseguito. |
| 4 | bloccato | Android -> iOS live non eseguito. |
| 5 | bloccato | iOS History live non eseguito. |
| 6 | bloccato | Android History live non eseguito. |
| 7 | bloccato | iOS edit live non eseguito. |
| 8 | bloccato | Android edit live non eseguito. |
| 9 | bloccato | iOS tombstone live non eseguito. |
| 10 | bloccato | Android tombstone live non eseguito. |
| 11 | bloccato | Offline dual conflict live non eseguito. |
| 12 | bloccato | Gap simulation live/sim non eseguita. |
| 13 | mancante | Performance ProductPrice TASK-112 non eseguita. |
| 14 | mancante | Options CTA Release presente al pre-audit. |
| 15 | mancante | Release diagnostics scan non eseguito. |
| 16 | mancante | UI responsiveness smoke non eseguito. |
| 17 | bloccato | Logout during sync non eseguito. |
| 18 | bloccato | Account switch pending non eseguito. |
| 19 | bloccato | Kill/restart ProductPrice apply non eseguito. |
| 20 | mancante | Network flapping realtime sim non eseguita. |
| 21 | parziale | Staticamente Options non full-sync onAppear; logs mancanti. |
| 22 | parziale | Schema mismatch audit statico parziale. |
| 23 | mancante | Replay push batch non eseguito. |
| 24 | mancante | Replay ProductPrice page non eseguito. |
| 25 | mancante | Large import dirty-set non eseguito. |
| 26 | mancante | Large import unsafe full reason non eseguito. |
| 27 | mancante | Accessibility card non eseguita. |
| 28 | mancante | Release forbidden strings scan non eseguito. |
| 29 | bloccato | Long background foreground live non eseguito. |
| 30 | bloccato | Product conflict live non eseguito. |
| 31 | bloccato | Tombstone vs update live non eseguito. |
| 32 | mancante | History retry no duplicate sim non eseguita. |
| 33 | parziale | Safety policy definita; live data/cleanup non eseguiti. |
| 34 | mancante | lastSuccessfulSync semantics test non eseguito. |
| 35 | mancante | Scroll preservation smoke non eseguito. |
| 36 | parziale | Go/no-go audit iniziale presente. |
| 37 | bloccato | iOS offline catalog live non eseguito. |
| 38 | bloccato | Android offline catalog live non eseguito. |
| 39 | bloccato | iOS offline ProductPrice live non eseguito. |
| 40 | bloccato | Android offline ProductPrice live non eseguito. |
| 41 | bloccato | iOS offline History live non eseguito. |
| 42 | bloccato | Android offline History live non eseguito. |
| 43 | mancante | Offline import large non eseguito. |
| 44 | mancante | Offline kill/restart drain non eseguito. |
| 45 | mancante | Network flapping outbox drain non eseguito. |
| 46 | parziale | Pull post-offline audit statico solo parziale. |
| 47 | mancante | Remote tombstone/offline update non provato. |
| 48 | bloccato | Dual offline product conflict live non eseguito. |
| 49 | bloccato | Offline logout/account boundary live non eseguito. |
| 50 | mancante | Options offline states non implementati/provati. |
| 51 | mancante | Crash local commit/outbox recovery non eseguito. |
| 52 | mancante | ProductPrice dependency wait non eseguito. |
| 53 | mancante | History dependency wait non eseguito. |
| 54 | mancante | Partial ack retry lane non eseguito. |
| 55 | mancante | Network no backend sim non eseguita. |
| 56 | mancante | Auth expired reconnect sim non eseguita. |
| 57 | bloccato | Long offline retention live non eseguito. |
| 58 | mancante | Storage failure simulation non eseguita. |
| 59 | mancante | Queue fairness priority non eseguita. |
| 60 | mancante | Offline pending UX smoke non eseguito. |
| 61 | mancante | Outbox pruning audit/test non eseguito. |
| 62 | mancante | Fake clock/scheduler tests non eseguiti. |
