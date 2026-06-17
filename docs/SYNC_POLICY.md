# Sync Policy

Fonte operativa per iOS, Android e Supabase. Questa policy descrive il comportamento live atteso; i task possono aggiungere evidenza, ma non devono cambiare queste regole senza aggiornare esplicitamente questo file.

## Regole comuni

- Un client non deve fare push automatico se la baseline locale non e' verificata, se serve bootstrap/recovery/reconcile, se ci sono retry remoti non risolti o se la decisione account/store e' pending.
- Un client puo' pushare solo lavoro locale effettivamente dirty e owner-scoped.
- Le scritture live devono essere idempotenti per `remote_id` e filtrate per `owner_user_id`.
- Le fixture runtime devono essere task-scoped; per la final live strict closure del task canonico TASK-132 e' stato usato lo storico prefisso `TASK134_*` come harness label, non come task canonico TASK-134. Le fixture vanno rimosse a fine gate; non vanno toccati dati production fuori scope.

## Catalogo

- Le create prodotto/fornitore/categoria possono inviare la riga completa necessaria alla creazione.
- Gli update di righe gia' sincronizzate devono usare patch parziali basate sui campi locali cambiati.
- Una patch prodotto non deve riscrivere campi non inclusi nella maschera locale `changedFields` / `localChangedFields`.
- I campi prodotto ammessi in patch sono: `barcode`, `itemNumber`, `productName`, `secondProductName`, `purchasePrice`, `retailPrice`, `supplier`, `category`, `stockQuantity`, `tombstone`.
- Se la maschera e' assente, legacy o non affidabile, il client deve usare il percorso conservativo esistente e non dichiarare field-merge strict.

## Prezzi

- Lo storico prezzi resta append-only e deduplicato per identita' remota/evento.
- Un cambio di prezzo corrente deve produrre solo lo storico prezzo del tipo cambiato (`PURCHASE` o `RETAIL`) e non deve forzare la riscrittura completa del prodotto.
- Un update catalogo non-price non deve creare nuove righe prezzo e non deve sovrascrivere prezzi remoti concorrenti.

## Protezione Dirty

- Un apply remoto non deve sovrascrivere una riga locale dirty.
- Se una riga locale e una remota cambiano campi diversi, il merge deve preservare entrambi i lati.
- Se la relazione supplier/category e' inclusa nella patch, il client deve usare remote ref gia' affidabili o saltare la patch finche' la dipendenza non e' risolta.

## Evidenza Minima

- Ogni gate strict deve riportare conteggi Supabase/iOS/Android prima e dopo.
- Ogni fixture live deve riportare creazione, osservazione cross-platform e cleanup con residuo zero.
- Build/test/lint devono essere riportati separando eseguito, non eseguibile e non eseguito.
