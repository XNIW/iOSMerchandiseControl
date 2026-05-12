# TASK-102 Accessibility Notes

## S102-A

- Stato: PASS WITH NOTES
- Verifica statica: `InventoryHomeView` usa `Label` per CTA e azioni secondarie, bottoni `.controlSize(.large)`, `ScrollView` e testi `.fixedSize(horizontal: false, vertical: true)` per ridurre rotture Dynamic Type.
- Ordine lettura atteso: titolo/descrizione -> CTA import -> stato file/import -> azioni secondarie manuale/scanner.
- Stato file/import: icona decorativa nascosta a VoiceOver e contenuto testuale combinato con `.accessibilityElement(children: .combine)`.
- Evidenza SIM: screenshot `screenshots/S102-A-home-after.jpg` catturato dopo build+launch.
- Nota residua: VoiceOver manuale e Dynamic Type L/XL campionati restano da eseguire nella review trasversale S102-I.

## S102-C

- Stato: PASS WITH NOTES.
- La preview orizzontale ha label accessibile `pregenerate.preview.title`.
- Le icone di riconoscimento colonna sono decorative (`accessibilityHidden(true)`) e lo stato resta comunicato dal testo ruolo/colonna.
- CTA `Genera` usa `Label`, `.buttonStyle(.borderedProminent)` e `.controlSize(.large)`.
- VoiceOver manuale/Dynamic Type su dataset sintetico non eseguiti manualmente; coperti solo da static review e snapshot simulator.

## S102-D

- Stato: PASS WITH NOTES.
- Header griglia ha label accessibile aggregata.
- Stati riga non dipendono solo dal colore: oltre al background esiste bordo semantico per errore/shortage/completata/highlight.
- Azione bulk `mark all` è un Button visibile con Label e SF Symbol, oltre al menu esistente.
- Verifica VoiceOver/Dynamic Type su dataset sintetico rimandata a S102-I/final smoke.

## S102-E

- Stato: PASS WITH NOTES.
- Scanner nel form manuale ora ha frame 44x44 e Label accessibile esistente.
- Campi barcode/prezzi/quantita usano tastiere piu coerenti e digit monospaced per numeri/prezzi.
- CTA `Aggiungi e continua` usa Label, controlSize large e ampiezza piena.
- Sheet runtime/Dynamic Type non interagiti manualmente; coperti solo da static review, build e full XCTest.

## S102-F

- Stato: PASS WITH NOTES.
- Fallback scanner manuale usa Button localizzato e controlSize large nei fallback camera/permessi.
- Callsite manual entry/search riportano focus al campo manuale quando il fallback viene scelto.
- Runtime camera/VoiceOver non interagito in questa slice; previsto final smoke.

## S102-G

- Stato: PASS WITH NOTES.
- Empty state Cronologia usa `ContentUnavailableView` con Label/SF Symbol nativo.
- Lista cronologia espone status sync come badge testuale + simbolo, non solo colore.
- Riepilogo numerico usa griglia adattiva per ridurre overflow a Dynamic Type piu grandi.
- Row combina i figli per lettura VoiceOver piu lineare; runtime VoiceOver su entry sintetica non eseguito manualmente.

## S102-H

- Stato: PASS WITH NOTES.
- Toolbar Database usa `Label` con accessibilità esplicita per import, export e nuovo prodotto.
- Search bar ha clear action nominata e scanner target 44pt.
- Empty state prodotti e filtro usano `ContentUnavailableView` con CTA/azione recuperabile.
- Row prodotto combina titolo, barcode, prezzi, supplier/category e azioni; prezzi usano digit monospaced.
- Form prodotto segnala barcode mancante con messaggio user-facing; runtime VoiceOver/Dynamic Type resta nel pass S102-I/final smoke.

## S102-I

- Stato: PASS WITH NOTES.
- Card sync Release mantiene accessibility label/hint esistenti del view model.
- Stato running combina `ProgressView` e testo per VoiceOver.
- Azioni primarie/secondarie e review sheet usano `.controlSize(.large)`.
- Screenshot sync signed-out: `screenshots/S102-I-options-sync-after.jpg`.
- VoiceOver manuale completo non eseguito; campionamento statico + snapshot UI simulator completati.

## Final validation

- Snapshot UI/accessibility hierarchy campionati per Home, PreGenerate, GeneratedView, Database, History, Options e sheet principali: elementi principali hanno label leggibili e azioni raggiungibili.
- Dynamic Type OS-level verificato in Simulator con content size `extra-large`; i flussi campionati restano navigabili senza blocker evidente.
- VoiceOver gestuale completo non eseguito; rischio residuo accettato come **PASS WITH NOTES** dopo campionamento hierarchy/snapshot.

## Review finale 2026-05-12 15:52 -0400

- Fix applicato in `DatabaseView.swift`: la row prodotto usa `.accessibilityElement(children: .contain)` invece di `.combine`, così le azioni interne come Modifica e Storico prezzi restano elementi accessibili separati.
- Fix applicato in `GeneratedView.swift`: il fallback manuale dello scanner principale non è più solo una chiusura dello sheet; porta a inserimento manuale o ricerca manuale quando il flusso lo consente.
- `EditProductView.swift`: validazione barcode meno fragile rispetto a cambio lingua/localizzazione.
- Verifica post-fix: Release build+launch PASS; full XCTest Debug PASS 640/0/12.
- Nota storica review 15:52: VoiceOver manuale completo e Dynamic Type OS-level non erano ancora stati eseguiti; l'ultimo pass di chiusura ha poi verificato Dynamic Type OS-level a `extra-large`.

## Chiusura finale 2026-05-12 16:46 -0400

- Dynamic Type OS-level ora verificato a `extra-large` su iPhone 17 Pro iOS 26.4.
- Campionamento accessibility hierarchy completato sui flussi principali richiesti: Home, PreGenerate, GeneratedView, Database, History, Options, manual entry, scanner fallback, storico prezzi e superfici import/export.
- Fix a11y/UX finale: `ProductPriceHistoryView` espone `Chiudi` in toolbar; il banner root `blockedAuth` non copre più la toolbar Database fuori da Opzioni a Dynamic Type extra-large.
- Esito a11y finale: **PASS WITH NOTES** solo per full gestural VoiceOver traversal non eseguito e scansione camera reale hardware-only.
