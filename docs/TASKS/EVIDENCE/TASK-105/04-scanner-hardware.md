# TASK-105 Evidence 04 - Scanner Hardware / Fallback

## Verifiche

| Scenario | Stato | Evidenza |
|----------|-------|----------|
| Scanner su simulator senza camera | PASS | UI mostra recovery "Inserisci manualmente" invece di bloccare il flusso. |
| Fallback manuale Database | PASS_AFTER_FIX | Tap fallback chiude scanner e porta focus al campo ricerca. |
| Camera hardware iPhone reale | PASS | iPhone fisico redatto: XCTest ha verificato camera autorizzata/capability barcode; owner/operator ha confermato live scan reale PASS. |
| Scanner dentro flusso reale app | PASS | Owner/operator confirmation received, identity redacted. |
| Barcode trovato/non trovato | PASS | Owner/operator confirmation received, identity redacted; fallback manuale confermato. |
| Permesso camera negato | STATIC_PASS | `BarcodeScannerView` ha stato denied/unavailable con CTA settings/manuale. |

## Fix TASK-105

- In `DatabaseView`, aggiunto focus esplicito al campo ricerca dopo fallback manuale scanner.
- Il fix evita un vicolo cieco UX sul simulator quando la camera non e' disponibile.

## Screenshot/artefatti

- Screenshot simulator scanner unavailable conservato fuori evidence con contenuto privacy-safe.
- Screenshot simulator Database fallback focus conservato fuori evidence con contenuto privacy-safe.
- Log test fisico redatto: `Task105RealOpsClosureTests.testPhysicalCameraBarcodeCaptureCapabilityWhenAvailable` PASS su iPhone reale.

## Conferma owner/operatore

Owner/operator confirmation received, identity redacted, 2026-05-13: live scan operatore reale su iPhone fisico, scanner nel flusso app, barcode trovato/non trovato e fallback manuale sono PASS. Nessun barcode reale o screenshot non mascherato inserito.

## Stato

PASS.
