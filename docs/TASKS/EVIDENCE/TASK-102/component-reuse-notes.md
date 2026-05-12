# TASK-102 Component Reuse Notes

## S102-A

- Pattern esistenti controllati: `Label` + SF Symbols, `NavigationStack`, `ContentUnavailableView`, `ProgressView`, toolbar/tab native.
- Decisione: non creare componente condiviso nuovo per S102-A; la Home è piccola e una patch locale è più reversibile.
- Riuso applicato: `Label`, SF Symbols, `ProgressView`, `NavigationStack` esistente, `foregroundCloudWorkflowActivity` esistente.
- Nuovo componente condiviso: nessuno.

## S102-B

- Pattern esistenti controllati: `fileImporter`, `ExcelSessionViewModel.load(from:in:)`, `ProgressView`, alert errori esistente, validazione UTType/estensione già presente in Home.
- Decisione: riusare `InventoryHomeView` e `ExcelSessionViewModel` esistenti; nessun nuovo componente e nessuna modifica parser.
- Esito: PASS WITH NOTES; path import condiviso locale creato in Home senza introdurre componenti globali.

## S102-C

- Pattern esistenti riusati: `Form`, `Section`, `Label`, SF Symbols, `ProgressView`, `Menu`, `Toggle`, `ViewThatFits`.
- Nuovo componente condiviso: nessuno; aggiunto solo helper locale `columnBulkActions`.

## S102-D

- Pattern esistenti riusati: `Form`, `Section`, `Label`, SF Symbols, `Button`, `Toggle`, `LazyVStack`, `ScrollView`.
- Nuovo componente condiviso: nessuno; aggiunti helper locali per bulk button e bordo riga.

## S102-E

- Pattern esistenti riusati: `Form`, `Section`, `Label`, toolbar cancellation/confirmation actions, `TextField`, `ScannerView`.
- Nuovo componente condiviso: nessuno.

## S102-F

- Pattern esistenti riusati: `ScannerView`, `ScannerFallbackView`, existing sheet callsites, localized `L(...)`.
- Nuovo componente condiviso: nessuno; estesa API interna del componente scanner con default backward-compatible.

## S102-G

- Pattern esistenti riusati: `List`, `Section`, `NavigationLink`, `swipeActions`, `ContentUnavailableView`, `Label`, SF Symbols, localizzazioni `L(...)`.
- Nuovo componente condiviso: nessuno; aggiunti solo helper locali `filteredEmptyState` e `HistoryStatusBadge` in `HistoryView.swift`.
- Logica dati/export/detail non modificata.

## S102-H

- Pattern esistenti riusati: `List`, `Form`, `Section`, `NavigationStack`, `sheet`, `confirmationDialog`, `ShareSheet`, `ScannerView`, `ContentUnavailableView`, `Label`, `ViewThatFits`.
- Nuovo componente condiviso: nessuno; aggiunto solo `DatabaseValueChip` locale a `DatabaseView.swift`.
- Parser/import core/export writer, modelli SwiftData e sync outbox non modificati.

## S102-I

- Pattern esistenti riusati: `Form`, `Section`, `Button`, `Label`, `ProgressView`, `sheet`, `confirmationDialog`, foreground workflow activity.
- Nuovo componente condiviso: nessuno.
- View model sync, servizi Supabase e trigger semi-automatici non modificati.

## Review finale 2026-05-12 15:52 -0400

- Nessun componente condiviso nuovo introdotto durante review.
- Fix scanner riusa `ScannerView`, `ManualEntrySheet` e `InventorySearchSheet` esistenti.
- Fix Database riusa API SwiftUI accessibility esistente; nessun nuovo layout/component.
- Fix form prodotto usa stato locale già presente nella view; nessun ViewModel o servizio nuovo.

## Chiusura finale 2026-05-12 16:46 -0400

- Nessun componente condiviso nuovo introdotto nel pass finale.
- `ProductPriceHistoryView` riusa toolbar/cancellation action SwiftUI nativa e la chiave esistente `common.close`.
- `ContentView` riusa la recovery surface esistente in Opzioni per `blockedAuth` invece di introdurre un nuovo banner/layout.
- Nessuna nuova dipendenza, nessun ViewModel nuovo, nessun servizio o schema modificato.
