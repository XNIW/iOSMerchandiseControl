#!/bin/zsh
# sim_ui.sh — Core wrapper universale per automazione UI nel Simulator iOS.
# Subcomandi deterministici, exit code semantici, nessun riferimento task-specifico.
# Vedi: tools/sim-ui-guide-codex.md (adapter Codex)
#       .claude/commands/sim-ui.md   (adapter Claude Code)
set -euo pipefail

# ---------------------------------------------------------------------------
# Configurazione
# ---------------------------------------------------------------------------
BUNDLE_ID="${SIM_UI_BUNDLE_ID:-com.niwcyber.iOSMerchandiseControl}"
DEVICE_ID="${SIM_UI_DEVICE_ID:-booted}"

# ---------------------------------------------------------------------------
# Utilità di output
# ---------------------------------------------------------------------------
log_ok()    { echo "[sim_ui] OK: $*" >&2; }
log_err()   { echo "[sim_ui] ERROR: $*" >&2; }

# ---------------------------------------------------------------------------
# Verifica Simulator booted (exit 2 se nessuno)
# ---------------------------------------------------------------------------
require_booted() {
  local udid
  udid="$(xcrun simctl list devices booted 2>/dev/null | grep -oE '[A-F0-9-]{36}' | head -n 1 || true)"
  if [[ -z "$udid" ]]; then
    log_err "Nessun Simulator booted trovato (DEVICE_ID=$DEVICE_ID)"
    exit 2
  fi
  # Se DEVICE_ID è un UDID specifico (non "booted"), verificare che sia tra i booted
  if [[ "$DEVICE_ID" != "booted" ]]; then
    if ! xcrun simctl list devices booted 2>/dev/null | grep -q "$DEVICE_ID"; then
      log_err "Device '$DEVICE_ID' non trovato tra i Simulator booted"
      exit 2
    fi
  fi
  echo "$udid"
}

booted_udid() {
  xcrun simctl list devices booted 2>/dev/null | grep -oE '[A-F0-9-]{36}' | head -n 1 || true
}

# ---------------------------------------------------------------------------
# Risoluzione bundle-id: argomento CLI > env > default
# ---------------------------------------------------------------------------
resolve_bundle_id() {
  local cli_arg="${1:-}"
  if [[ -n "$cli_arg" ]]; then
    echo "$cli_arg"
  else
    echo "$BUNDLE_ID"
  fi
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
sim_ui.sh — Wrapper universale per automazione UI nel Simulator iOS.

Usage:
  ./tools/sim_ui.sh show
  ./tools/sim_ui.sh launch [bundle-id]
  ./tools/sim_ui.sh terminate [bundle-id]
  ./tools/sim_ui.sh tap-name <fragment> [role] [timeout]
  ./tools/sim_ui.sh wait-for <fragment> [timeout]
  ./tools/sim_ui.sh type <text>
  ./tools/sim_ui.sh clear-field
  ./tools/sim_ui.sh capture <output.png>
  ./tools/sim_ui.sh wait <seconds>
  ./tools/sim_ui.sh dump-names [filter]
  ./tools/sim_ui.sh tap-relative <relX> <relY>

Exit codes:
  0  Successo
  1  Fallimento operativo (elemento non trovato, timeout)
  2  Errore di configurazione / ambiente (no Simulator booted, AX non disponibile, device richiesto non presente)

Environment:
  SIM_UI_BUNDLE_ID  Bundle ID dell'app (default: com.niwcyber.iOSMerchandiseControl)
  SIM_UI_DEVICE_ID  Device ID del Simulator (default: booted)
EOF
}

# ---------------------------------------------------------------------------
# JXA engine — tutte le operazioni UI passano da qui
# ---------------------------------------------------------------------------
run_jxa() {
  local action="$1"
  local arg1="${2:-}"
  local arg2="${3:-}"
  local arg3="${4:-}"

  # Assicurarsi che Simulator sia in foreground
  local udid
  udid="$(booted_udid)"
  if [[ -n "$udid" ]]; then
    open -a Simulator --args -CurrentDeviceUDID "$udid" >/dev/null 2>&1 || true
  else
    open -a Simulator >/dev/null 2>&1 || true
  fi

  ACTION="$action" \
  ARG1="$arg1" \
  ARG2="$arg2" \
  ARG3="$arg3" \
  /usr/bin/osascript -l JavaScript <<'JXA'
ObjC.import("Cocoa");
ObjC.import("Quartz");
ObjC.import("stdlib");

function env(name) {
  try {
    const raw = $.getenv(name);
    return raw ? ObjC.unwrap(raw) : "";
  } catch (e) {
    return "";
  }
}

const action = env("ACTION");
const args = [env("ARG1"), env("ARG2"), env("ARG3")];
const se = Application("System Events");
const sim = Application("Simulator");
se.includeStandardAdditions = true;
sim.includeStandardAdditions = true;

// -------------------------------------------------------------------------
// Key codes per cifre e segno meno (layout US)
// -------------------------------------------------------------------------
const keyCodes = {
  "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
  "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
  "-": 27
};

// -------------------------------------------------------------------------
// Helpers: Simulator window e device frame
// -------------------------------------------------------------------------
function activateSimulator() {
  sim.activate();
  delay(0.5);
  const proc = se.processes.byName("Simulator");
  proc.frontmost = true;
  delay(0.2);
  return proc;
}

function frontWindow() {
  const proc = activateSimulator();
  const startedAt = Date.now();
  while ((Date.now() - startedAt) < 5000) {
    try {
      const windows = proc.windows();
      if (windows.length > 0) return windows[0];
    } catch (e) {
      try { return proc.windows[0]; } catch (f) { /* retry */ }
    }
    delay(0.2);
  }
  throw new Error("[sim_ui] Finestra Simulator non trovata");
}

function deviceFrame() {
  const win = frontWindow();
  const elements = win.uiElements();
  let best = null;
  for (let i = 0; i < elements.length; i++) {
    try {
      const pos = elements[i].position();
      const sz = elements[i].size();
      const w = Number(sz[0]), h = Number(sz[1]);
      if (w < 250 || h < 500 || h <= w) continue;
      const area = w * h;
      if (!best || area > best.area) {
        best = { x: Number(pos[0]), y: Number(pos[1]), width: w, height: h, area };
      }
    } catch (e) { /* skip */ }
  }
  if (!best) throw new Error("[sim_ui] Device frame non trovato nel Simulator");
  return best;
}

// -------------------------------------------------------------------------
// Helpers: click
// -------------------------------------------------------------------------
function clickPoint(x, y) {
  const pt = $.NSMakePoint(Number(x), Number(y));
  const down = $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseDown, pt, $.kCGMouseButtonLeft);
  const up   = $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseUp,   pt, $.kCGMouseButtonLeft);
  $.CGEventPost($.kCGHIDEventTap, down);
  $.CGEventPost($.kCGHIDEventTap, up);
}

function clickRelative(relX, relY) {
  const f = deviceFrame();
  clickPoint(f.x + f.width * Number(relX), f.y + f.height * Number(relY));
  delay(0.3);
}

function elementCenter(el) {
  const pos = el.position();
  const sz  = el.size();
  return { x: Number(pos[0]) + Number(sz[0]) / 2, y: Number(pos[1]) + Number(sz[1]) / 2 };
}

// -------------------------------------------------------------------------
// Helpers: AX tree
// -------------------------------------------------------------------------
function allElements() {
  const win = frontWindow();
  try {
    return win.entireContents();
  } catch (e) {
    // AX tree non accessibile (permessi mancanti o Simulator in stato anomalo)
    console.log("[sim_ui] AX_ERROR: impossibile leggere AX tree: " + e.message);
    $.exit(2);
  }
}

function elementName(el) {
  // Nel Simulator, gli elementi iOS espongono il testo in description(), non in name().
  // Cerchiamo in entrambi: name ha priorità, ma se è vuoto/null usiamo description.
  try {
    const n = String(el.name());
    if (n && n !== "null" && n !== "") return n;
  } catch (e) { /* fallthrough */ }
  try {
    const d = String(el.description());
    if (d && d !== "null" && d !== "") return d;
  } catch (e) { /* fallthrough */ }
  return "";
}

function elementRole(el) {
  try { return String(el.role()); } catch (e) { return ""; }
}

function lower(v) { return String(v || "").toLowerCase(); }

function findElementByName(fragment, preferredRole) {
  const needle = lower(fragment);
  const matches = [];
  const elems = allElements();
  for (let i = 0; i < elems.length; i++) {
    try {
      const name = elementName(elems[i]);
      if (!name || !lower(name).includes(needle)) continue;
      matches.push({ element: elems[i], role: elementRole(elems[i]), name });
    } catch (e) { /* skip */ }
  }
  if (preferredRole) {
    const pref = matches.find(m => m.role === preferredRole);
    if (pref) return pref;
  }
  return matches.length > 0 ? matches[0] : null;
}

function waitForElement(fragment, preferredRole, timeoutSec) {
  const startedAt = Date.now();
  const ms = Number(timeoutSec) * 1000;
  while ((Date.now() - startedAt) < ms) {
    const found = findElementByName(fragment, preferredRole);
    if (found) return found;
    delay(0.2);
  }
  return null;
}

// -------------------------------------------------------------------------
// Helpers: typing
// -------------------------------------------------------------------------
function clearFocusedField() {
  for (let i = 0; i < 40; i++) se.keyCode(51);
  delay(0.1);
}

function typeSmart(text) {
  const t = String(text || "");
  for (let i = 0; i < t.length; i++) {
    const ch = t[i];
    if (Object.prototype.hasOwnProperty.call(keyCodes, ch)) {
      se.keyCode(keyCodes[ch]);
    } else {
      se.keystroke(ch);
    }
    delay(0.03);
  }
}

// =========================================================================
// Dispatch azioni
// =========================================================================
switch (action) {
  // --- show (noop nel JXA — Simulator già attivato da activateSimulator) ---
  case "show":
    activateSimulator();
    break;

  // --- tap-name <fragment> [role] [timeout] ---
  case "tap-name": {
    const fragment = args[0];
    const role = args[1] || "";
    const timeout = Number(args[2]) || 5;
    const match = waitForElement(fragment, role, timeout);
    if (!match) {
      console.log("NOT_FOUND");
      const msg = `[sim_ui] ERROR: Elemento '${fragment}' non trovato entro ${timeout}s`;
      // stderr via console.log goes to stderr in JXA? No — we throw for exit 1
      throw new Error(msg);
    }
    const c = elementCenter(match.element);
    clickPoint(c.x, c.y);
    delay(0.4);
    const roleName = match.role ? ` (${match.role})` : "";
    // informativo su stderr (il layer shell lo gestisce)
    break;
  }

  // --- wait-for <fragment> [timeout] ---
  case "wait-for": {
    const fragment = args[0];
    const timeout = Number(args[1]) || 10;
    const match = waitForElement(fragment, "", timeout);
    if (match) {
      console.log("FOUND");
    } else {
      console.log("NOT_FOUND");
      throw new Error(`[sim_ui] ERROR: Elemento '${fragment}' non trovato entro ${timeout}s`);
    }
    break;
  }

  // --- type <text> ---
  case "type":
    activateSimulator();
    typeSmart(args[0]);
    break;

  // --- clear-field ---
  case "clear-field":
    activateSimulator();
    clearFocusedField();
    break;

  // --- tap-relative <relX> <relY> ---
  case "tap-relative":
    clickRelative(args[0], args[1]);
    break;

  // --- dump-names [filter] ---
  case "dump-names": {
    const filter = lower(args[0] || "");
    const seen = {};
    const elems = allElements();
    for (let i = 0; i < elems.length; i++) {
      const name = elementName(elems[i]);
      if (!name) continue;
      if (filter && !lower(name).includes(filter)) continue;
      const role = elementRole(elems[i]);
      const line = `${role}\t${name}`;
      if (!seen[line]) { seen[line] = true; console.log(line); }
    }
    break;
  }

  default:
    throw new Error(`[sim_ui] Azione JXA non supportata: ${action}`);
}
// Sopprimere output return value di osascript
"";
JXA
}

# ===========================================================================
# Dispatcher shell
# ===========================================================================
command="${1:-}"
[[ $# -gt 0 ]] && shift

case "$command" in
  # -----------------------------------------------------------------------
  show)
    require_booted >/dev/null
    run_jxa show 2>/dev/null
    log_ok "Simulator portato in foreground"
    ;;

  # -----------------------------------------------------------------------
  launch)
    require_booted >/dev/null
    local_bid="$(resolve_bundle_id "${1:-}")"
    if ! xcrun simctl launch "$DEVICE_ID" "$local_bid" >/dev/null 2>&1; then
      log_err "simctl launch fallito per $local_bid"
      exit 1
    fi
    log_ok "App $local_bid lanciata"
    ;;

  # -----------------------------------------------------------------------
  terminate)
    require_booted >/dev/null
    local_bid="$(resolve_bundle_id "${1:-}")"
    xcrun simctl terminate "$DEVICE_ID" "$local_bid" >/dev/null 2>&1 || true
    log_ok "App $local_bid terminata"
    ;;

  # -----------------------------------------------------------------------
  tap-name)
    if [[ $# -lt 1 ]]; then
      log_err "Uso: sim_ui.sh tap-name <fragment> [role] [timeout]"
      exit 1
    fi
    require_booted >/dev/null
    jxa_rc=0
    run_jxa tap-name "${1:-}" "${2:-}" "${3:-}" 2>/dev/null || jxa_rc=$?
    if [[ $jxa_rc -eq 2 ]]; then
      log_err "AX non disponibile — impossibile cercare '${1}'"
      exit 2
    elif [[ $jxa_rc -ne 0 ]]; then
      log_err "Elemento '${1}' non trovato"
      exit 1
    fi
    log_ok "Click su '${1}'"
    ;;

  # -----------------------------------------------------------------------
  wait-for)
    if [[ $# -lt 1 ]]; then
      log_err "Uso: sim_ui.sh wait-for <fragment> [timeout]"
      exit 1
    fi
    require_booted >/dev/null
    # console.log() in JXA va su stderr — catturare tutto per leggere FOUND/NOT_FOUND e AX_ERROR
    jxa_rc=0
    jxa_out="$(run_jxa wait-for "${1:-}" "${2:-}" 2>&1)" || jxa_rc=$?
    if [[ $jxa_rc -eq 2 ]]; then
      log_err "AX non disponibile — impossibile cercare '${1}'"
      exit 2
    elif [[ "$jxa_out" == *"FOUND"* && "$jxa_out" != *"NOT_FOUND"* ]]; then
      echo "FOUND"
      log_ok "Elemento '${1}' trovato"
      exit 0
    else
      echo "NOT_FOUND"
      log_err "Elemento '${1}' non trovato entro ${2:-10}s"
      exit 1
    fi
    ;;

  # -----------------------------------------------------------------------
  type)
    if [[ $# -lt 1 ]]; then
      log_err "Uso: sim_ui.sh type <text>"
      exit 1
    fi
    require_booted >/dev/null
    run_jxa type "$1" 2>/dev/null
    log_ok "Testo digitato"
    ;;

  # -----------------------------------------------------------------------
  clear-field)
    require_booted >/dev/null
    run_jxa clear-field 2>/dev/null
    log_ok "Campo svuotato"
    ;;

  # -----------------------------------------------------------------------
  capture)
    if [[ $# -lt 1 ]]; then
      log_err "Uso: sim_ui.sh capture <output.png>"
      exit 1
    fi
    require_booted >/dev/null
    if ! xcrun simctl io "$DEVICE_ID" screenshot "$1" >/dev/null 2>&1; then
      log_err "Screenshot fallito"
      exit 1
    fi
    echo "$1"
    log_ok "Screenshot salvato: $1"
    ;;

  # -----------------------------------------------------------------------
  wait)
    if [[ $# -lt 1 ]]; then
      log_err "Uso: sim_ui.sh wait <seconds>"
      exit 1
    fi
    sleep "$1"
    ;;

  # -----------------------------------------------------------------------
  dump-names)
    require_booted >/dev/null
    # console.log() in JXA va su stderr — catturare per output dati e distinguere AX error
    jxa_rc=0
    jxa_out="$(run_jxa dump-names "${1:-}" 2>&1)" || jxa_rc=$?
    if [[ $jxa_rc -eq 2 ]]; then
      log_err "AX non disponibile — impossibile leggere elementi"
      exit 2
    fi
    # Output dati su stdout (può essere vuoto se nessun elemento con nome)
    [[ -n "$jxa_out" ]] && echo "$jxa_out"
    ;;

  # -----------------------------------------------------------------------
  tap-relative)
    if [[ $# -lt 2 ]]; then
      log_err "Uso: sim_ui.sh tap-relative <relX> <relY>"
      exit 1
    fi
    require_booted >/dev/null
    jxa_rc=0
    run_jxa tap-relative "$1" "$2" 2>/dev/null || jxa_rc=$?
    if [[ $jxa_rc -eq 2 ]]; then
      log_err "Simulator non in foreground o AX non disponibile"
      exit 2
    elif [[ $jxa_rc -ne 0 ]]; then
      log_err "tap-relative fallito"
      exit 1
    fi
    log_ok "Click relativo a ($1, $2)"
    ;;

  # -----------------------------------------------------------------------
  ""|help|-h|--help)
    usage
    exit 0
    ;;

  # -----------------------------------------------------------------------
  *)
    log_err "Subcomando sconosciuto: $command"
    usage >&2
    exit 1
    ;;
esac
