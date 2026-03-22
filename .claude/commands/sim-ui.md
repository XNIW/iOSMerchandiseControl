> **⚠️ DEPRECATED (2026-03-22)**: Questo comando NON è parte del workflow standard. Uso solo sperimentale / legacy / su richiesta esplicita.

Stai per eseguire test UI nel Simulator iOS usando il wrapper `tools/sim_ui.sh`.
NON generare comandi `osascript` inline. Usa SEMPRE il wrapper.

## Subcomandi disponibili

| Subcomando | Sintassi | Descrizione |
|------------|----------|-------------|
| `show` | `./tools/sim_ui.sh show` | Porta il Simulator in foreground |
| `launch` | `./tools/sim_ui.sh launch [bundle-id]` | Avvia l'app (default: com.niwcyber.iOSMerchandiseControl) |
| `terminate` | `./tools/sim_ui.sh terminate [bundle-id]` | Termina l'app |
| `tap-name` | `./tools/sim_ui.sh tap-name <fragment> [role] [timeout]` | Trova elemento AX per nome e clicca (default timeout: 5s) |
| `wait-for` | `./tools/sim_ui.sh wait-for <fragment> [timeout]` | Attende elemento AX (default timeout: 10s). Stdout: FOUND/NOT_FOUND |
| `type` | `./tools/sim_ui.sh type <text>` | Digita testo nel campo focalizzato |
| `clear-field` | `./tools/sim_ui.sh clear-field` | Svuota campo focalizzato (40 backspace) |
| `capture` | `./tools/sim_ui.sh capture <path.png>` | Screenshot. Stdout: path del file salvato |
| `wait` | `./tools/sim_ui.sh wait <seconds>` | Pausa |
| `dump-names` | `./tools/sim_ui.sh dump-names [filter]` | Lista elementi AX visibili (ROLE\tNAME) |
| `tap-relative` | `./tools/sim_ui.sh tap-relative <relX> <relY>` | Click a coordinate relative al device frame |
| `replace-field` | `./tools/sim_ui.sh replace-field <relX> <relY> <value>` | Tap + clear + type in una sola invocazione |
| `batch` | `./tools/sim_ui.sh batch` | Esegue una sequenza di azioni da stdin in una singola sessione JXA |

## Exit codes

- **0**: successo
- **1**: fallimento operativo (elemento non trovato, timeout)
- **2**: errore di configurazione / ambiente (no Simulator booted, AX non disponibile, device richiesto non presente) — fermarsi immediatamente

## Flusso tipico

```bash
# Verifica ambiente e avvia app
./tools/sim_ui.sh show
./tools/sim_ui.sh launch

# Attendi schermata
./tools/sim_ui.sh wait-for "Inventario" 10

# Esegui azioni
./tools/sim_ui.sh tap-name "NomeBottone"
./tools/sim_ui.sh wait-for "RisultatoAtteso" 5

# Screenshot diagnostico
./tools/sim_ui.sh capture /tmp/sim_test.png

# Cleanup
./tools/sim_ui.sh terminate
```

## Batch ed esempi

Preferisci `batch` quando devi fare molte micro-azioni seriali.

```bash
./tools/sim_ui.sh batch <<'BATCH'
tap-name "Aggiungi riga"
wait-for "Barcode" 5
replace-field 0.5 0.35 "8001234567890"
replace-field 0.5 0.45 "10"
tap-name "Conferma"
wait-for "Inventario" 5
capture /tmp/after_add.png
BATCH
```

```bash
./tools/sim_ui.sh replace-field 0.5 0.35 "8001234567890"
```

```bash
./tools/sim_ui.sh batch <<'BATCH'
type "prezzo unitario"
replace-field 0.5 0.4 "valore con spazi"
wait-for "Aggiungi riga" 5
BATCH
```

Se una riga fallisce, il batch si ferma subito:

```bash
./tools/sim_ui.sh batch <<'BATCH'
tap-relative 0.5 0.5
wait 0.5
tap-name "Conferma"
capture /tmp/should_not_reach.png
BATCH
# stderr:
# [sim_ui] BATCH FAIL at line 3: tap-name — Elemento 'Conferma' non trovato entro 5s
```

`capture` e' supportato anche dentro il batch. Se il file atteso non viene creato davvero, il batch fallisce.

## Strategia di fallback

1. Primo tentativo: `tap-name "NomeElemento"` (AX tree)
2. Se exit 1: ispezionare con `dump-names` + `capture` per debug
3. Fallback: `tap-relative <relX> <relY>` (documentare device e scala)
4. Se tutto fallisce: fermarsi e riportare contesto all'utente

## Regola stop-on-failure

Se `wait-for` ritorna exit 1 (NOT_FOUND):
- NON continuare il test corrente
- Catturare screenshot + dump-names per diagnostica
- Riportare il fallimento all'utente
- Proseguire al test successivo solo se indipendente

## Limiti

- Solo Simulator iOS (no device fisici)
- No multi-touch / gesture avanzate
- Richiede permessi macOS: Accessibility + Screen Recording
- AX tree lento su view complesse (1-3s)
- `wait-for` e `dump-names` possono ancora diventare molto lenti su stati UI complessi; `SIM_UI_JXA_TIMEOUT` limita la durata massima del JXA ma non elimina il costo della scansione AX
- Coordinate relative dipendono da device e scala finestra

## Configurazione

- `SIM_UI_BUNDLE_ID`: override bundle ID (default: com.niwcyber.iOSMerchandiseControl)
- `SIM_UI_DEVICE_ID`: override device (default: booted)
- `SIM_UI_JXA_TIMEOUT`: watchdog esterno per ogni invocazione JXA (default: `30`)
