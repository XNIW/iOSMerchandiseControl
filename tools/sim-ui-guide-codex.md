# Guida operativa Simulator UI — per Codex

Questa guida insegna a Codex come usare `tools/sim_ui.sh` per eseguire test UI nel Simulator iOS.
Lettura obbligatoria prima di qualsiasi test UI nel Simulator (vedi `AGENTS.md`).

## Quando usare questa guida

Usarla quando il task attivo richiede:
- Verifica interattiva nel Simulator iOS (tipo `SIM` nel protocollo)
- Test end-to-end su schermate, navigazione, tap, inserimento dati
- Screenshot diagnostici dopo azioni UI

Non usarla per verifiche statiche (analisi codice) o build-only.

## Prerequisiti

1. **Simulator booted**: verificare con `xcrun simctl list devices booted` (almeno 1 device)
2. **App installata**: l'app deve essere stata buildata e installata nel Simulator
3. **Permessi macOS**: Accessibility e Screen Recording devono essere attivi per il terminale/agente
4. **Smoke test**: eseguire `./tools/sim_ui.sh dump-names` — se produce 0 righe su un'app visibile, i permessi non sono attivi

## Subcomandi

| Subcomando | Sintassi | Exit 0 | Exit 1 | Exit 2 |
|------------|----------|--------|--------|--------|
| `show` | `sim_ui.sh show` | Simulator in foreground | — | No Simulator booted |
| `launch` | `sim_ui.sh launch [bundle-id]` | App lanciata | simctl fallito | No Simulator booted |
| `terminate` | `sim_ui.sh terminate [bundle-id]` | App terminata | — | No Simulator booted |
| `tap-name` | `sim_ui.sh tap-name <fragment> [role] [timeout]` | Click eseguito | Non trovato | AX non disponibile |
| `wait-for` | `sim_ui.sh wait-for <fragment> [timeout]` | stdout: `FOUND` | stdout: `NOT_FOUND` | AX non disponibile |
| `type` | `sim_ui.sh type <text>` | Testo digitato | — | Simulator non foreground |
| `clear-field` | `sim_ui.sh clear-field` | Campo svuotato | — | Simulator non foreground |
| `capture` | `sim_ui.sh capture <path.png>` | stdout: path | Fallito | No Simulator booted |
| `wait` | `sim_ui.sh wait <seconds>` | Sempre 0 | — | — |
| `dump-names` | `sim_ui.sh dump-names [filter]` | stdout: ROLE\tNAME | — | AX non disponibile |
| `tap-relative` | `sim_ui.sh tap-relative <relX> <relY>` | Click eseguito | Frame non trovato | Simulator non foreground |

Default: timeout `tap-name` = 5s, timeout `wait-for` = 10s.
Bundle-id: se omesso, usa `SIM_UI_BUNDLE_ID` env o default `com.niwcyber.iOSMerchandiseControl`.

## Exit code semantici

- **Exit 0**: operazione riuscita
- **Exit 1**: fallimento operativo (elemento non trovato, timeout) — il test ha prodotto un risultato negativo
- **Exit 2**: errore di configurazione / ambiente (nessun Simulator booted, AX non disponibile, device richiesto non presente) — l'ambiente non funziona

Azione in base all'exit code:
- Exit 0: continuare al prossimo step
- Exit 1: il test corrente FAIL — applicare regola stop-on-failure (vedi sotto)
- Exit 2: **fermarsi immediatamente** — l'ambiente non e' disponibile, marcare tutti i test SIM come NOT RUN

## Flusso tipico test end-to-end

```bash
# 1. Verifica ambiente
./tools/sim_ui.sh show
./tools/sim_ui.sh launch

# 2. Attendi schermata iniziale
./tools/sim_ui.sh wait-for "Inventario" 10

# 3. Esegui azioni
./tools/sim_ui.sh tap-name "NomeBottone"
./tools/sim_ui.sh wait-for "RisultatoAtteso" 5

# 4. Screenshot diagnostico
./tools/sim_ui.sh capture /tmp/sim_T-01_result.png

# 5. Cleanup
./tools/sim_ui.sh terminate
```

## Strategia di fallback

1. **Primo tentativo**: `tap-name "NomeElemento"` (usa AX tree)
2. **Se exit 1**: eseguire `dump-names` per ispezionare cosa e' visibile + `capture` per screenshot
3. **Fallback esplicito**: `tap-relative 0.50 0.40` (coordinate relative al device frame) — documentare perche' il fallback e' necessario e con quale device/scala e' stato calibrato
4. **Se anche il fallback fallisce**: fermarsi, riportare screenshot + dump-names + exit code

## Regola stop-on-failure

**Se `wait-for` ritorna exit 1 (NOT_FOUND)**:
1. NON continuare il test corrente
2. Catturare screenshot: `./tools/sim_ui.sh capture /tmp/debug_T-NN.png`
3. Eseguire `./tools/sim_ui.sh dump-names` per documentare lo stato AX
4. Riportare il test come FAIL con causa e artefatti
5. Proseguire al test successivo **solo se indipendente** dal test fallito

**Se exit 2**: fermarsi completamente, l'ambiente non funziona.

## Limiti noti

- Solo Simulator iOS, nessun supporto per device fisici
- No multi-touch, no gesture avanzate (pinch, swipe continuo, drag)
- Richiede permessi Accessibility e Screen Recording su macOS
- Prompt di approvazione agente possibile per ogni chiamata `osascript` (pre-approvare il pattern `./tools/sim_ui.sh *` se possibile)
- `win.entireContents()` puo' essere lento su view complesse (1-3s)
- Le coordinate relative (`tap-relative`) dipendono dal modello device e dalla scala della finestra

## Reporting

Formato standard per ogni test:

```
T-NN: STATO [TIPO] — nota
```

Stati:
- `PASS [SIM]` — verifica superata
- `FAIL [SIM]` — verifica fallita (riportare causa)
- `NOT RUN [SIM]` — non eseguito (riportare causa ambientale)
- `BLOCKED [SIM]` — bloccato da fattore esterno (riportare causa + tentativo + richiesta sblocco)

Esempio:
```
T-01: PASS  [SIM]    — tap su "Conferma" -> sheet chiuso, riga visibile
T-02: FAIL  [SIM]    — wait-for "Risultato" exit 1, screenshot /tmp/debug_T-02.png
T-03: NOT RUN [SIM]  — Simulator non booted
```

## Smoke test

Prima di iniziare qualsiasi suite di test, eseguire:

```bash
# 1. Simulator attivo?
xcrun simctl list devices booted  # deve mostrare almeno 1 device

# 2. App raggiungibile?
./tools/sim_ui.sh launch
./tools/sim_ui.sh wait-for "Inventario" 10  # o altro elemento della home

# 3. AX tree funzionante?
./tools/sim_ui.sh dump-names  # deve produrre almeno 1 riga

# Se uno di questi fallisce, l'ambiente non e' pronto — non iniziare i test.
```
