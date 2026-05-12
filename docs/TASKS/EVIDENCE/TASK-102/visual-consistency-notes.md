# TASK-102 Visual Consistency Notes

## S102-A

- Target: una CTA primaria evidente per import file, azioni manuali secondarie meno dominanti, stato file/import sempre visibile e leggibile.
- Pattern repo osservati: `ContentUnavailableView` già usato in `GeneratedView`; `Label` e SF Symbols già usati in Home.
- Stato: PASS WITH NOTES.
- Modifica applicata: CTA primaria import file prominente e full-width; azioni manuale/scanner secondarie con button style coerente; stato file/import in blocco compatto con SF Symbol semantico.
- Screenshot: `screenshots/S102-A-home-after.jpg`.
- Nota residua: la root foreground cloud banner preesistente può comparire sopra la Home se serve accesso cloud; non è stato modificato in S102-A e sarà rivalutato in S102-I.

## S102-B

- Stato: PASS WITH NOTES.
- Import da picker e "Apri con" ora usano lo stesso percorso, quindi errori e transizione verso PreGenerate restano coerenti.
- L'annullamento del picker non genera alert; errori reali continuano a usare l'alert esistente con messaggio user-facing.
- Screenshot: `screenshots/S102-B-home-import-ready.jpg`.

## S102-C

- Stato: PASS WITH NOTES.
- L'azione `Genera` è ora la CTA primaria della schermata; seleziona/deseleziona colonne usa Label con SF Symbols coerenti.
- Preview e badge ruolo restano nel Form nativo, senza nuova struttura grafica o refactor.

## S102-D

- Stato: PASS WITH NOTES.
- Header griglia usa raggio 8 coerente con il resto del polish.
- Azione bulk è visibile nella sezione inventario; il menu toolbar resta per azioni rare o distruttive.
- Righe con errori/completate/shortage hanno bordo oltre al colore, aumentando leggibilità senza ridisegnare la tabella.

## S102-E

- Stato: PASS WITH NOTES.
- Form manuale mantiene Form/Section nativi; scanner e add-and-continue sono più riconoscibili senza nuovo layout.
- Dettaglio riga mantiene le sezioni esistenti e rende l'azione di edit più leggibile.

## S102-F

- Stato: PASS WITH NOTES.
- Scanner fallback mantiene overlay scuro esistente, con CTA primaria impostazioni quando utile e fallback manuale secondario.
- Callsite inventario/database/search usano la stessa CTA manuale, evitando copy divergente.

## S102-G

- Stato: PASS WITH NOTES.
- Cronologia vuota usa pattern nativo `ContentUnavailableView`, coerente con empty state iOS.
- Lista cronologia mostra badge sync/export testuali e riepilogo adattivo; lo stato non dipende solo da colore o icona.
- Filtro senza risultati ora mostra uno stato vuoto dedicato invece di una lista silenziosa.
- Screenshot: `screenshots/S102-G-history-empty-after.jpg`.

## S102-H

- Stato: PASS WITH NOTES.
- Database vuoto/filtro vuoto usa `ContentUnavailableView` e una CTA/azione chiara.
- Toolbar import/export/add resta icon-only ma con Label/accessibility coerenti.
- Row prodotto usa gerarchia titolo -> codici -> prezzi -> supplier/category -> azioni, senza card annidate o redesign.
- Import/export restano `confirmationDialog` con copy breve e share sheet esistente.
- Screenshot: `screenshots/S102-H-database-empty-after.jpg`.

## S102-I

- Stato: PASS WITH NOTES.
- Opzioni/sync Release mantiene Form/Section nativo; nessun redesign della superficie cloud.
- Azioni sync e review sheet sono piu tappabili e coerenti con le CTA grandi applicate nelle slice precedenti.
- Nessun nuovo jargon cloud/Supabase introdotto.
- Screenshot: `screenshots/S102-I-options-sync-after.jpg`.

## Review finale 2026-05-12 15:52 -0400

- Fallback scanner principale: la CTA "Inserisci manualmente" ora produce un percorso coerente con il contesto invece di limitarsi a chiudere lo scanner.
- Database: correzione accessibilità non altera layout/gerarchia visiva, ma preserva le azioni interne della row.
- Form prodotto: validazione barcode resta user-facing e non aggiunge gergo tecnico.
- Nessun redesign radicale introdotto in review; decisione finale visuale **PASS WITH NOTES** per limiti manuali runtime non bloccanti.

## Chiusura finale 2026-05-12 16:46 -0400

- Dynamic Type `extra-large` campionato sui flussi principali; la toolbar Database resta raggiungibile dopo la soppressione del banner root `blockedAuth` fuori da Opzioni.
- `ProductPriceHistoryView` ora ha una chiusura toolbar esplicita, coerente con le sheet native usate nel resto del polish.
- Import, PreGenerate, GeneratedView, manual entry, Database CRUD, History e Options sync mantengono pattern nativi SwiftUI senza redesign radicale.
- Esito visuale finale: **PASS WITH NOTES** per limiti non bloccanti di camera reale, file provider e sync live.
