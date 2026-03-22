#!/bin/zsh
# ⚠️ DEPRECATED (2026-03-22) — Questo wrapper NON è parte del workflow standard del progetto.
# Uso: solo sperimentale / legacy / su richiesta esplicita dell'utente.
# Il workflow standard prevede verifiche build/statiche + test manuali su richiesta.
#
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
# Timeout esterno JXA (CA-2): configurabile via env, default 30s
# ---------------------------------------------------------------------------
: "${SIM_UI_JXA_TIMEOUT:=30}"

# ---------------------------------------------------------------------------
# Utilità di output (CA-19: prefisso [sim_ui], tutto su stderr)
# ---------------------------------------------------------------------------
log_ok()    { echo "[sim_ui] OK: $*" >&2; }
log_err()   { echo "[sim_ui] ERROR: $*" >&2; }

_validate_arg_count() {
  local cmd="$1"
  local actual="$2"
  local min="$3"
  local max="$4"
  if (( actual < min || actual > max )); then
    if (( min == max )); then
      log_err "$cmd richiede $min argomenti, ricevuti $actual"
    else
      log_err "$cmd richiede $min-$max argomenti, ricevuti $actual"
    fi
    return 1
  fi
}

_is_number() {
  [[ "$1" =~ ^-?([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]]
}

_require_numeric_arg() {
  local cmd="$1"
  local label="$2"
  local value="$3"
  if ! _is_number "$value"; then
    log_err "$cmd: $label deve essere numerico, ricevuto '$value'"
    return 1
  fi
}

_batch_require_numeric_arg() {
  local line_num="$1"
  local cmd="$2"
  local label="$3"
  local value="$4"
  if ! _is_number "$value"; then
    log_err "riga $line_num: $cmd richiede $label numerico, ricevuto '$value'"
    return 1
  fi
}

_validate_batch_numeric_args() {
  local cmd="$1"
  local line_num="$2"
  shift 2
  case "$cmd" in
    tap-relative)
      _batch_require_numeric_arg "$line_num" "$cmd" "relX" "$1" || return 1
      _batch_require_numeric_arg "$line_num" "$cmd" "relY" "$2" || return 1
      ;;
    tap-name)
      if [[ $# -eq 3 ]]; then
        _batch_require_numeric_arg "$line_num" "$cmd" "timeout" "$3" || return 1
      fi
      ;;
    wait-for)
      if [[ $# -ge 2 ]]; then
        _batch_require_numeric_arg "$line_num" "$cmd" "timeout" "$2" || return 1
      fi
      ;;
    wait)
      _batch_require_numeric_arg "$line_num" "$cmd" "seconds" "$1" || return 1
      ;;
    replace-field)
      _batch_require_numeric_arg "$line_num" "$cmd" "relX" "$1" || return 1
      _batch_require_numeric_arg "$line_num" "$cmd" "relY" "$2" || return 1
      ;;
  esac
}

_RUN_CAPTURED_STDOUT=""

_run_capture_stdout() {
  local out_file
  local rc=0
  out_file="$(mktemp /tmp/sim_ui_stdout_XXXXXX)"
  "$@" >"$out_file" || rc=$?
  _RUN_CAPTURED_STDOUT=""
  [[ -f "$out_file" ]] && _RUN_CAPTURED_STDOUT="$(cat "$out_file")"
  rm -f "$out_file"
  return $rc
}

# ---------------------------------------------------------------------------
# Watchdog / cleanup state (CA-1, CA-3, D-10, D-11)
# ---------------------------------------------------------------------------
_JXA_PID=""
_WATCHDOG_PID=""
_SENTINEL_FILE="/tmp/sim_ui_timeout.$$"
_BATCH_TMPFILE=""
_SIGNAL_RECEIVED=""

_cleanup_jxa() {
  # Kill watchdog se esiste
  if [[ -n "$_WATCHDOG_PID" ]] && kill -0 "$_WATCHDOG_PID" 2>/dev/null; then
    kill "$_WATCHDOG_PID" 2>/dev/null || true
    wait "$_WATCHDOG_PID" 2>/dev/null || true
  fi
  _WATCHDOG_PID=""
  # Kill child osascript se esiste
  if [[ -n "$_JXA_PID" ]] && kill -0 "$_JXA_PID" 2>/dev/null; then
    kill -TERM "$_JXA_PID" 2>/dev/null || true
    sleep 2
    kill -KILL "$_JXA_PID" 2>/dev/null || true
  fi
  _JXA_PID=""
  # Cleanup sentinel orfano (D-11)
  rm -f "$_SENTINEL_FILE"
  # Cleanup temp file batch orfano (D-15, CA-21)
  [[ -n "$_BATCH_TMPFILE" ]] && rm -f "$_BATCH_TMPFILE"
  _BATCH_TMPFILE=""
}

_on_signal() {
  _SIGNAL_RECEIVED="$1"
  log_err "processo interrotto (signal)"
  _cleanup_jxa
  exit 1
}

trap '_on_signal INT' INT
trap '_on_signal TERM' TERM
trap _cleanup_jxa EXIT

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
  ./tools/sim_ui.sh replace-field <relX> <relY> <value>
  ./tools/sim_ui.sh batch  (reads actions from stdin)

Exit codes:
  0  Successo
  1  Fallimento operativo (elemento non trovato, timeout)
  2  Errore di configurazione / ambiente (no Simulator booted, AX non disponibile, device richiesto non presente)

Environment:
  SIM_UI_BUNDLE_ID    Bundle ID dell'app (default: com.niwcyber.iOSMerchandiseControl)
  SIM_UI_DEVICE_ID    Device ID del Simulator (default: booted)
  SIM_UI_JXA_TIMEOUT  Timeout JXA in secondi (default: 30)
EOF
}

# ---------------------------------------------------------------------------
# run_jxa_with_timeout — lancia osascript con watchdog (CA-1, CA-1b, CA-2)
# ---------------------------------------------------------------------------
run_jxa_with_timeout() {
  local timeout="${SIM_UI_JXA_TIMEOUT}"

  # 0. Rimuove eventuale sentinel residuo
  rm -f "$_SENTINEL_FILE"

  # 1. Assicurarsi che Simulator sia in foreground
  local udid
  udid="$(booted_udid)"
  if [[ -n "$udid" ]]; then
    open -a Simulator --args -CurrentDeviceUDID "$udid" >/dev/null 2>&1 || true
  else
    open -a Simulator >/dev/null 2>&1 || true
  fi

  # 2. Lancia osascript in background
  /usr/bin/osascript -l JavaScript "$@" &
  _JXA_PID=$!

  # 3. Lancia watchdog (D-11: scrive sentinel prima di TERM)
  local _jxa_pid_copy="$_JXA_PID"
  local _sentinel_copy="$_SENTINEL_FILE"
  (
    sleep "$timeout"
    if kill -0 "$_jxa_pid_copy" 2>/dev/null; then
      touch "$_sentinel_copy"
      kill -TERM "$_jxa_pid_copy" 2>/dev/null || true
      sleep 2
      kill -KILL "$_jxa_pid_copy" 2>/dev/null || true
    fi
  ) 2>/dev/null &
  _WATCHDOG_PID=$!

  # 4. Attende il child (bloccante)
  local exit_code=0
  wait "$_JXA_PID" || exit_code=$?
  _JXA_PID=""

  # 5. Cancella il watchdog
  if kill -0 "$_WATCHDOG_PID" 2>/dev/null; then
    kill "$_WATCHDOG_PID" 2>/dev/null || true
    wait "$_WATCHDOG_PID" 2>/dev/null || true
  fi
  _WATCHDOG_PID=""

  # 6. Timeout provenance (CA-1b, D-11)
  # Check signal flag first (set by _on_signal trap)
  if [[ -n "$_SIGNAL_RECEIVED" ]]; then
    rm -f "$_SENTINEL_FILE"
    log_err "processo interrotto (signal)"
    return 1
  fi

  # osascript may exit with code 1 (not 143/137) when killed by SIGTERM,
  # because the JXA runtime catches the signal and exits gracefully.
  # Check sentinel FIRST to detect watchdog timeout regardless of exit code.
  if [[ -f "$_SENTINEL_FILE" ]]; then
    rm -f "$_SENTINEL_FILE"
    log_err "JXA timeout dopo ${timeout}s"
    return 124
  fi

  # External signal (SIGTERM/SIGKILL from outside, not our watchdog)
  if [[ $exit_code -eq 143 ]] || [[ $exit_code -eq 137 ]]; then
    log_err "processo interrotto (signal)"
    return 1
  fi

  # Normal exit (JXA completed on its own)
  rm -f "$_SENTINEL_FILE"
  return $exit_code
}

# ---------------------------------------------------------------------------
# JXA engine — tutte le operazioni UI passano da qui
# Usa run_jxa_with_timeout per il timeout esterno
# ---------------------------------------------------------------------------
run_jxa() {
  local action="$1"
  local arg1="${2:-}"
  local arg2="${3:-}"
  local arg3="${4:-}"

  local jxa_script
  jxa_script="$(mktemp /tmp/sim_ui_jxa_XXXXXX)"

  cat > "$jxa_script" <<'JXASCRIPT'
ObjC.import("Cocoa");
ObjC.import("Quartz");
ObjC.import("stdlib");
ObjC.import("Foundation");

function env(name) {
  try {
    const raw = $.getenv(name);
    return raw ? ObjC.unwrap(raw) : "";
  } catch (e) {
    return "";
  }
}

function writeLine(handle, msg) {
  const data = $.NSString.alloc.initWithUTF8String(msg + "\n");
  handle.writeDataError(data.dataUsingEncoding($.NSUTF8StringEncoding), null);
}

function stdoutPrint(msg) {
  writeLine($.NSFileHandle.fileHandleWithStandardOutput, msg);
}

// CA-19, D-14: diagnostica esplicita su stderr via ObjC bridge
function stderrPrint(msg) {
  writeLine($.NSFileHandle.fileHandleWithStandardError, msg);
}

const action = env("ACTION");
const args = [env("ARG1"), env("ARG2"), env("ARG3")];
const se = Application("System Events");
const sim = Application("Simulator");
se.includeStandardAdditions = true;
sim.includeStandardAdditions = true;
let simulatorProcessCache = null;
let simulatorWindowCache = null;
let deviceFrameCache = null;

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
// CA-15: skip delay se già frontmost
function activateSimulator() {
  if (simulatorProcessCache) return simulatorProcessCache;
  const proc = se.processes.byName("Simulator");
  if (proc.frontmost()) {
    simulatorProcessCache = proc;
    return proc;
  }
  sim.activate();
  delay(0.5);
  proc.frontmost = true;
  delay(0.2);
  simulatorProcessCache = proc;
  return proc;
}

function frontWindow() {
  if (simulatorWindowCache) return simulatorWindowCache;
  const proc = activateSimulator();
  const startedAt = Date.now();
  while ((Date.now() - startedAt) < 5000) {
    try {
      const windows = proc.windows();
      if (windows.length > 0) {
        simulatorWindowCache = windows[0];
        return simulatorWindowCache;
      }
    } catch (e) {
      try {
        simulatorWindowCache = proc.windows[0];
        return simulatorWindowCache;
      } catch (f) { /* retry */ }
    }
    delay(0.2);
  }
  throw new Error("[sim_ui] Finestra Simulator non trovata");
}

function deviceFrame() {
  if (deviceFrameCache) return deviceFrameCache;
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
  deviceFrameCache = best;
  return deviceFrameCache;
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

// Click using a pre-computed frame (batch mode — CA-9)
function clickRelativeCached(relX, relY, frame) {
  clickPoint(frame.x + frame.width * Number(relX), frame.y + frame.height * Number(relY));
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
    stderrPrint("[sim_ui] AX_ERROR: impossibile leggere AX tree: " + e.message);
    $.exit(2);
  }
}

function elementName(el) {
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

// -------------------------------------------------------------------------
// Helpers: batch actions loader (CA-21, D-15)
// -------------------------------------------------------------------------
function loadBatchActions() {
  // Prima controlla BATCH_ACTIONS_FILE (temp file per batch grandi)
  try {
    const filePath = env("BATCH_ACTIONS_FILE");
    if (filePath) {
      const nsData = $.NSString.stringWithContentsOfFileEncodingError(
        filePath, $.NSUTF8StringEncoding, null);
      if (nsData) return JSON.parse(ObjC.unwrap(nsData));
    }
  } catch (e) { /* fallthrough to env var */ }
  // Poi controlla BATCH_ACTIONS (env var per batch normali)
  return JSON.parse(env("BATCH_ACTIONS"));
}

// =========================================================================
// Dispatch azioni
// =========================================================================
switch (action) {
  // --- show ---
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
      stderrPrint("[sim_ui] ERROR: Elemento '" + fragment + "' non trovato entro " + timeout + "s");
      $.exit(1);
    }
    const c = elementCenter(match.element);
    clickPoint(c.x, c.y);
    delay(0.4);
    break;
  }

  // --- wait-for <fragment> [timeout] ---
  case "wait-for": {
    const fragment = args[0];
    const timeout = Number(args[1]) || 10;
    const match = waitForElement(fragment, "", timeout);
    if (match) {
      stdoutPrint("FOUND");
    } else {
      stdoutPrint("NOT_FOUND");
      stderrPrint("[sim_ui] ERROR: Elemento '" + fragment + "' non trovato entro " + timeout + "s");
      $.exit(1);
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

  // --- replace-field <relX> <relY> <value> (CA-11, CA-12) ---
  case "replace-field":
    clickRelative(args[0], args[1]);
    delay(0.3);
    clearFocusedField();
    typeSmart(args[2]);
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
      const line = role + "\t" + name;
      if (!seen[line]) { seen[line] = true; stdoutPrint(line); }
    }
    break;
  }

  // --- batch (CA-4..CA-9, CA-18) ---
  case "batch": {
    const actions = loadBatchActions();
    if (actions.length === 0) break;

    activateSimulator();
    // CA-9: deviceFrame calcolato una volta sola per la sessione batch.
    // INVARIANTE CACHE: frame è valido per la durata della sessione batch.
    // Se in futuro arrivano subcomandi che cambiano geometria/finestra/orientamento
    // del Simulator, dovranno invalidare questa cache e ricalcolare deviceFrame().
    const frame = deviceFrame();

    for (let i = 0; i < actions.length; i++) {
      const a = actions[i];
      try {
        switch (a.cmd) {
          case "tap-relative":
            clickRelativeCached(Number(a.args[0]), Number(a.args[1]), frame);
            break;
          case "tap-name": {
            const fragment = a.args[0];
            const role = a.args[1] || "";
            const timeout = Number(a.args[2]) || 5;
            const match = waitForElement(fragment, role, timeout);
            if (!match) throw new Error("Elemento '" + fragment + "' non trovato entro " + timeout + "s");
            const c = elementCenter(match.element);
            clickPoint(c.x, c.y);
            delay(0.4);
            break;
          }
          case "wait-for": {
            const fragment = a.args[0];
            const timeout = Number(a.args[1]) || 10;
            const match = waitForElement(fragment, "", timeout);
            if (!match) throw new Error("Elemento '" + fragment + "' non trovato entro " + timeout + "s");
            break;
          }
          case "type":
            typeSmart(a.args[0]);
            break;
          case "clear-field":
            clearFocusedField();
            break;
          case "wait":
            delay(Number(a.args[0]));
            break;
          case "replace-field":
            clickRelativeCached(Number(a.args[0]), Number(a.args[1]), frame);
            delay(0.3);
            clearFocusedField();
            typeSmart(a.args[2]);
            break;
          case "capture":
            // CA-18: capture via NSTask/ObjC bridge (preserva sessione JXA, ordine, stop-on-failure)
            {
              const fileManager = $.NSFileManager.defaultManager;
              const capturePath = a.args[0];
              const task = $.NSTask.alloc.init;
              const stdoutPipe = $.NSPipe.pipe;
              const stderrPipe = $.NSPipe.pipe;
              task.launchPath = "/usr/bin/xcrun";
              task.arguments = $([
                "simctl", "io", env("DEVICE_ID") || "booted", "screenshot", capturePath
              ]);
              task.standardOutput = stdoutPipe;
              task.standardError = stderrPipe;
              task.launch;
              task.waitUntilExit;
              if (task.terminationStatus !== 0) {
                const outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile;
                const errData = stderrPipe.fileHandleForReading.readDataToEndOfFile;
                const outStr = $.NSString.alloc.initWithDataEncoding(outData, $.NSUTF8StringEncoding);
                const errStr = $.NSString.alloc.initWithDataEncoding(errData, $.NSUTF8StringEncoding);
                const detail = [ObjC.unwrap(outStr || ""), ObjC.unwrap(errStr || "")]
                  .filter(Boolean)
                  .join(" ")
                  .trim();
                throw new Error(detail ? "screenshot fallito: " + detail : "screenshot fallito");
              }
              if (!fileManager.fileExistsAtPath($(capturePath))) {
                throw new Error("screenshot fallito: file non creato");
              }
            }
            break;
          default:
            throw new Error("Subcomando sconosciuto: " + a.cmd);
        }
      } catch (e) {
        // CA-7, CA-19, D-14: stop-on-failure con diagnostica su stderr
        stderrPrint("[sim_ui] BATCH FAIL at line " + a.line + ": " + a.cmd + " — " + e.message);
        $.exit(1);
      }
    }
    break;
  }

  default:
    stderrPrint("[sim_ui] ERROR: Azione JXA non supportata: " + action);
    $.exit(1);
}
// Sopprimere output return value di osascript
"";
JXASCRIPT

  # Export env vars needed by JXA (ACTION, ARG1-3, DEVICE_ID, and any BATCH_* vars)
  export ACTION="$action"
  export ARG1="$arg1"
  export ARG2="$arg2"
  export ARG3="$arg3"
  export DEVICE_ID="$DEVICE_ID"

  local rc=0
  run_jxa_with_timeout "$jxa_script" || rc=$?
  rm -f "$jxa_script"
  return $rc
}

# ===========================================================================
# Batch parsing helpers (CA-5, D-8, D-13, CA-20)
# ===========================================================================
# Arity table per validazione shell-side
# Returns expected arity as "min:max"
_batch_arity() {
  case "$1" in
    tap-relative)  echo "2:2" ;;
    tap-name)      echo "1:3" ;;
    wait-for)      echo "1:2" ;;
    type)          echo "1:1" ;;
    clear-field)   echo "0:0" ;;
    wait)          echo "1:1" ;;
    capture)       echo "1:1" ;;
    replace-field) echo "3:3" ;;
    *)             echo "" ;;
  esac
}

# ===========================================================================
# Dispatcher shell
# ===========================================================================
command="${1:-}"
[[ $# -gt 0 ]] && shift

case "$command" in
  # -----------------------------------------------------------------------
  show)
    _validate_arg_count "show" "$#" 0 0 || exit 1
    require_booted >/dev/null
    run_jxa show 2>/dev/null
    log_ok "Simulator portato in foreground"
    ;;

  # -----------------------------------------------------------------------
  launch)
    _validate_arg_count "launch" "$#" 0 1 || exit 1
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
    _validate_arg_count "terminate" "$#" 0 1 || exit 1
    require_booted >/dev/null
    local_bid="$(resolve_bundle_id "${1:-}")"
    xcrun simctl terminate "$DEVICE_ID" "$local_bid" >/dev/null 2>&1 || true
    log_ok "App $local_bid terminata"
    ;;

  # -----------------------------------------------------------------------
  tap-name)
    _validate_arg_count "tap-name" "$#" 1 3 || exit 1
    if [[ $# -eq 3 ]]; then
      _require_numeric_arg "tap-name" "timeout" "$3" || exit 1
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
    _validate_arg_count "wait-for" "$#" 1 2 || exit 1
    if [[ $# -eq 2 ]]; then
      _require_numeric_arg "wait-for" "timeout" "$2" || exit 1
    fi
    require_booted >/dev/null
    jxa_rc=0
    _run_capture_stdout run_jxa wait-for "${1:-}" "${2:-}" || jxa_rc=$?
    if [[ $jxa_rc -eq 2 ]]; then
      log_err "AX non disponibile — impossibile cercare '${1}'"
      exit 2
    elif [[ $jxa_rc -eq 124 ]]; then
      echo "NOT_FOUND"
      exit 1
    elif [[ $jxa_rc -eq 0 ]]; then
      [[ -n "$_RUN_CAPTURED_STDOUT" ]] && printf '%s\n' "$_RUN_CAPTURED_STDOUT"
      log_ok "Elemento '${1}' trovato"
      exit 0
    else
      [[ -n "$_RUN_CAPTURED_STDOUT" ]] && printf '%s\n' "$_RUN_CAPTURED_STDOUT"
      exit 1
    fi
    ;;

  # -----------------------------------------------------------------------
  type)
    _validate_arg_count "type" "$#" 1 1 || exit 1
    require_booted >/dev/null
    run_jxa type "$1" 2>/dev/null
    log_ok "Testo digitato"
    ;;

  # -----------------------------------------------------------------------
  clear-field)
    _validate_arg_count "clear-field" "$#" 0 0 || exit 1
    require_booted >/dev/null
    run_jxa clear-field 2>/dev/null
    log_ok "Campo svuotato"
    ;;

  # -----------------------------------------------------------------------
  capture)
    _validate_arg_count "capture" "$#" 1 1 || exit 1
    require_booted >/dev/null
    [[ -f "$1" ]] && rm -f "$1"
    if ! xcrun simctl io "$DEVICE_ID" screenshot "$1" >/dev/null 2>&1; then
      log_err "Screenshot fallito"
      exit 1
    fi
    if [[ ! -f "$1" ]]; then
      log_err "Screenshot fallito: file non creato"
      exit 1
    fi
    echo "$1"
    log_ok "Screenshot salvato: $1"
    ;;

  # -----------------------------------------------------------------------
  wait)
    _validate_arg_count "wait" "$#" 1 1 || exit 1
    _require_numeric_arg "wait" "seconds" "$1" || exit 1
    sleep "$1"
    ;;

  # -----------------------------------------------------------------------
  dump-names)
    require_booted >/dev/null
    jxa_rc=0
    _run_capture_stdout run_jxa dump-names "${1:-}" || jxa_rc=$?
    if [[ $jxa_rc -eq 2 ]]; then
      log_err "AX non disponibile — impossibile leggere elementi"
      exit 2
    elif [[ $jxa_rc -eq 124 ]]; then
      exit 1
    fi
    [[ -n "$_RUN_CAPTURED_STDOUT" ]] && printf '%s\n' "$_RUN_CAPTURED_STDOUT"
    ;;

  # -----------------------------------------------------------------------
  tap-relative)
    _validate_arg_count "tap-relative" "$#" 2 2 || exit 1
    _require_numeric_arg "tap-relative" "relX" "$1" || exit 1
    _require_numeric_arg "tap-relative" "relY" "$2" || exit 1
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
  # replace-field <relX> <relY> <value> (CA-11, CA-12, CA-20)
  # -----------------------------------------------------------------------
  replace-field)
    _validate_arg_count "replace-field" "$#" 3 3 || exit 1
    _require_numeric_arg "replace-field" "relX" "$1" || exit 1
    _require_numeric_arg "replace-field" "relY" "$2" || exit 1
    require_booted >/dev/null
    jxa_rc=0
    run_jxa replace-field "$1" "$2" "$3" 2>/dev/null || jxa_rc=$?
    if [[ $jxa_rc -eq 2 ]]; then
      log_err "Simulator non in foreground o AX non disponibile"
      exit 2
    elif [[ $jxa_rc -ne 0 ]]; then
      log_err "replace-field fallito"
      exit 1
    fi
    log_ok "replace-field ($1, $2) = '$3'"
    ;;

  # -----------------------------------------------------------------------
  # batch — CA-4..CA-8, CA-9, CA-18, CA-20, CA-21
  # Legge azioni da stdin, una per riga. Parsing via python3/shlex (D-8).
  # -----------------------------------------------------------------------
  batch)
    require_booted >/dev/null

    # Verifica python3 disponibile (R-6)
    if ! command -v /usr/bin/python3 >/dev/null 2>&1; then
      log_err "/usr/bin/python3 not found — required for batch mode"
      exit 2
    fi

    # 1. Legge e parsifica stdin riga per riga
    _bn_line_num=0
    _bn_json_actions="["
    _bn_first_action=true
    _bn_has_actions=false
    _bn_tokens=""
    _bn_cmd=""
    _bn_nargs=""
    _bn_arity=""
    _bn_min_args=""
    _bn_max_args=""
    _bn_args_json=""

    while IFS= read -r line || [[ -n "$line" ]]; do
      _bn_line_num=$((_bn_line_num + 1))

      # Ignora righe vuote
      [[ -z "${line//[[:space:]]/}" ]] && continue
      # Ignora commenti
      [[ "$line" == \#* ]] && continue

      # D-8: parsing con python3/shlex (eval VIETATO)
      _bn_tokens="$(/usr/bin/python3 -c 'import shlex,sys,json; print(json.dumps(shlex.split(sys.stdin.readline())))' <<< "$line" 2>/dev/null)" || {
        log_err "riga $_bn_line_num: parsing fallito per: $line"
        exit 1
      }

      # Estrae cmd e args dal JSON array
      _bn_cmd="$(/usr/bin/python3 -c "import sys,json; t=json.loads(sys.stdin.readline()); print(t[0] if t else '')" <<< "$_bn_tokens")"
      _bn_nargs="$(/usr/bin/python3 -c "import sys,json; t=json.loads(sys.stdin.readline()); print(len(t)-1)" <<< "$_bn_tokens")"

      # Valida subcomando (CA-5)
      _bn_arity="$(_batch_arity "$_bn_cmd")"
      if [[ -z "$_bn_arity" ]]; then
        log_err "riga $_bn_line_num: subcomando sconosciuto: $_bn_cmd"
        exit 1
      fi

      # Valida arity shell-side (D-13, CA-20)
      _bn_min_args="${_bn_arity%%:*}"
      _bn_max_args="${_bn_arity##*:}"
      if [[ $_bn_nargs -lt $_bn_min_args ]] || [[ $_bn_nargs -gt $_bn_max_args ]]; then
        if [[ "$_bn_min_args" == "$_bn_max_args" ]]; then
          log_err "riga $_bn_line_num: $_bn_cmd richiede $_bn_min_args argomenti, ricevuti $_bn_nargs"
        else
          log_err "riga $_bn_line_num: $_bn_cmd richiede $_bn_min_args-$_bn_max_args argomenti, ricevuti $_bn_nargs"
        fi
        exit 1
      fi

      _bn_args=()
      _bn_args=("${(@f)$(/usr/bin/python3 -c 'import sys,json; [print(item) for item in json.loads(sys.stdin.readline())[1:]]' <<< "$_bn_tokens")}")
      _validate_batch_numeric_args "$_bn_cmd" "$_bn_line_num" "${_bn_args[@]}" || exit 1

      # Serializza in JSON per il JXA
      _bn_args_json="$(/usr/bin/python3 -c "import sys,json; t=json.loads(sys.stdin.readline()); print(json.dumps(t[1:]))" <<< "$_bn_tokens")"

      if $_bn_first_action; then
        _bn_first_action=false
      else
        _bn_json_actions="$_bn_json_actions,"
      fi
      _bn_json_actions="$_bn_json_actions{\"cmd\":\"$_bn_cmd\",\"args\":$_bn_args_json,\"line\":$_bn_line_num}"
      _bn_has_actions=true

    done

    _bn_json_actions="$_bn_json_actions]"

    # Batch vuoto → exit 0 (CA-6: T-6)
    if ! $_bn_has_actions; then
      exit 0
    fi

    # CA-21, D-15: se il JSON è troppo grande, usa temp file
    _bn_json_len=${#_bn_json_actions}
    if [[ $_bn_json_len -gt 120000 ]]; then
      _BATCH_TMPFILE="/tmp/sim_ui_batch.$$.json"
      echo "$_bn_json_actions" > "$_BATCH_TMPFILE"
      export BATCH_ACTIONS_FILE="$_BATCH_TMPFILE"
      export BATCH_ACTIONS=""
      _bn_batch_rc=0
      run_jxa batch || _bn_batch_rc=$?
      rm -f "$_BATCH_TMPFILE"
      _BATCH_TMPFILE=""
      unset BATCH_ACTIONS
      unset BATCH_ACTIONS_FILE
      [[ $_bn_batch_rc -eq 124 ]] && _bn_batch_rc=1
      exit $_bn_batch_rc
    else
      export BATCH_ACTIONS="$_bn_json_actions"
      export BATCH_ACTIONS_FILE=""
      _bn_batch_rc=0
      run_jxa batch || _bn_batch_rc=$?
      unset BATCH_ACTIONS
      unset BATCH_ACTIONS_FILE
      # Map exit 124 (watchdog timeout) to exit 1 for callers
      [[ $_bn_batch_rc -eq 124 ]] && _bn_batch_rc=1
      exit $_bn_batch_rc
    fi
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
