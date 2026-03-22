#!/bin/zsh
# -----------------------------------------------------------------------
# sim_ui_task008.sh — Wrapper task-specifico per TASK-008 (ManualEntrySheet).
# Per il wrapper universale con subcomandi generici, usare: tools/sim_ui.sh
# Questo file è mantenuto per backward compatibility e contiene coordinate
# e flussi hardcoded specifici del dialog ManualEntrySheet.
# -----------------------------------------------------------------------
set -euo pipefail

BUNDLE_ID="${SIM_UI_BUNDLE_ID:-com.niwcyber.iOSMerchandiseControl}"
DEVICE_ID="${SIM_UI_DEVICE_ID:-booted}"

usage() {
  cat <<'EOF'
Usage:
  ./tools/sim_ui_task008.sh launch-app
  ./tools/sim_ui_task008.sh launch-manual
  ./tools/sim_ui_task008.sh show-simulator
  ./tools/sim_ui_task008.sh open-add
  ./tools/sim_ui_task008.sh fill-add <barcode> <retail> <qty> [product_name] [purchase_price]
  ./tools/sim_ui_task008.sh confirm
  ./tools/sim_ui_task008.sh tap-text <name_fragment>
  ./tools/sim_ui_task008.sh delete-current-row
  ./tools/sim_ui_task008.sh open-history-tab
  ./tools/sim_ui_task008.sh open-latest-manual
  ./tools/sim_ui_task008.sh dump-names [filter]
  ./tools/sim_ui_task008.sh terminate
  ./tools/sim_ui_task008.sh capture <output_png>
  ./tools/sim_ui_task008.sh wait <seconds>
EOF
}

booted_udid() {
  xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -n 1
}

run_ui() {
  local action="$1"
  local arg1="${2:-}"
  local arg2="${3:-}"
  local arg3="${4:-}"
  local arg4="${5:-}"
  local arg5="${6:-}"

  local udid
  udid="$(booted_udid || true)"
  if [[ -n "$udid" ]]; then
    open -a Simulator --args -CurrentDeviceUDID "$udid" >/dev/null 2>&1 || true
  else
    open -a Simulator >/dev/null 2>&1 || true
  fi

  ACTION="$action" \
  ARG1="$arg1" \
  ARG2="$arg2" \
  ARG3="$arg3" \
  ARG4="$arg4" \
  ARG5="$arg5" \
  /usr/bin/osascript -l JavaScript <<'JXA'
ObjC.import("Cocoa");
ObjC.import("Quartz");
ObjC.import("stdlib");

function env(name) {
  const raw = $.getenv(name);
  return raw ? ObjC.unwrap(raw) : "";
}

const action = env("ACTION");
const args = [env("ARG1"), env("ARG2"), env("ARG3"), env("ARG4"), env("ARG5")];
const se = Application("System Events");
const sim = Application("Simulator");
se.includeStandardAdditions = true;
sim.includeStandardAdditions = true;

const keyCodes = {
  "0": 29,
  "1": 18,
  "2": 19,
  "3": 20,
  "4": 21,
  "5": 23,
  "6": 22,
  "7": 26,
  "8": 28,
  "9": 25,
  "-": 27
};

function delaySeconds(seconds) {
  delay(Number(seconds));
}

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
      if (windows.length > 0) {
        return windows[0];
      }
    } catch (error) {
      try {
        return proc.windows[0];
      } catch (fallbackError) {
        // Retry until the window appears.
      }
    }

    delay(0.2);
  }

  throw new Error("Finestra Simulator non trovata.");
}

function deviceFrame() {
  const win = frontWindow();
  const elements = win.uiElements();
  let best = null;

  for (let index = 0; index < elements.length; index += 1) {
    try {
      const pos = elements[index].position();
      const size = elements[index].size();
      const width = Number(size[0]);
      const height = Number(size[1]);
      if (width < 250 || height < 500 || height <= width) {
        continue;
      }

      const area = width * height;
      if (!best || area > best.area) {
        best = {
          x: Number(pos[0]),
          y: Number(pos[1]),
          width,
          height,
          area
        };
      }
    } catch (error) {
      // Ignore non-geometry elements.
    }
  }

  if (!best) {
    throw new Error("Impossibile individuare l'area del device nel Simulator.");
  }

  return best;
}

function clickPoint(x, y) {
  const point = $.NSMakePoint(Number(x), Number(y));
  const down = $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseDown, point, $.kCGMouseButtonLeft);
  const up = $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseUp, point, $.kCGMouseButtonLeft);
  $.CGEventPost($.kCGHIDEventTap, down);
  $.CGEventPost($.kCGHIDEventTap, up);
}

function clickRelative(relX, relY) {
  const frame = deviceFrame();
  clickPoint(frame.x + frame.width * Number(relX), frame.y + frame.height * Number(relY));
  delay(0.3);
}

function elementCenter(element) {
  const pos = element.position();
  const size = element.size();
  return {
    x: Number(pos[0]) + Number(size[0]) / 2,
    y: Number(pos[1]) + Number(size[1]) / 2
  };
}

function allElements() {
  const win = frontWindow();
  try {
    return win.entireContents();
  } catch (error) {
    return [];
  }
}

function elementName(element) {
  try {
    return String(element.name());
  } catch (error) {
    return "";
  }
}

function elementRole(element) {
  try {
    return String(element.role());
  } catch (error) {
    return "";
  }
}

function lower(value) {
  return String(value || "").toLowerCase();
}

function findElementByName(fragment, preferredRole) {
  const needle = lower(fragment);
  const matches = [];
  const elements = allElements();

  for (let index = 0; index < elements.length; index += 1) {
    try {
      const name = elementName(elements[index]);
      if (!name || !lower(name).includes(needle)) {
        continue;
      }

      const role = elementRole(elements[index]);
      matches.push({ element: elements[index], role, name });
    } catch (error) {
      // Ignore inaccessible elements.
    }
  }

  if (preferredRole) {
    const preferred = matches.find((match) => match.role === preferredRole);
    if (preferred) {
      return preferred.element;
    }
  }

  return matches.length > 0 ? matches[0].element : null;
}

function waitForElement(fragment, preferredRole, timeoutSeconds) {
  const startedAt = Date.now();
  const timeoutMs = Number(timeoutSeconds) * 1000;

  while ((Date.now() - startedAt) < timeoutMs) {
    const found = findElementByName(fragment, preferredRole);
    if (found) {
      return found;
    }
    delay(0.2);
  }

  return null;
}

function clickNamed(fragment, preferredRole, timeoutSeconds) {
    const element = waitForElement(fragment, preferredRole, timeoutSeconds);
    if (!element) {
        return false;
    }

    const center = elementCenter(element);
    clickPoint(center.x, center.y);
    delay(0.4);
    return true;
}

function clearFocusedField() {
  for (let index = 0; index < 40; index += 1) {
    se.keyCode(51);
  }
  delay(0.1);
}

function typeSmart(value) {
  const text = String(value || "");
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (Object.prototype.hasOwnProperty.call(keyCodes, character)) {
      se.keyCode(keyCodes[character]);
    } else {
      se.keystroke(character);
    }
    delay(0.03);
  }
}

function replaceField(relX, relY, value) {
  clickRelative(relX, relY);
  clearFocusedField();
  if (String(value || "").length > 0) {
    typeSmart(value);
  }
  delay(0.15);
}

switch (action) {
  case "launch-manual":
    if (!clickNamed("Nuovo inventario manuale", "AXButton", 4)) {
      clickRelative(0.50, 0.468);
    }
    break;

  case "open-add":
    if (!clickNamed("Aggiungi riga", "AXButton", 4)) {
      clickRelative(0.50, 0.409);
    }
    break;

  case "fill-add":
    replaceField(0.50, 0.218, args[0]);
    replaceField(0.50, 0.341, args[1]);
    replaceField(0.50, 0.464, args[2]);
    if (args[3]) {
      replaceField(0.50, 0.280, args[3]);
    }
    if (args[4]) {
      replaceField(0.50, 0.403, args[4]);
    }
    break;

  case "confirm":
    if (!clickNamed("Conferma", "AXButton", 4)) {
      clickRelative(0.815, 0.101);
    }
    break;

  case "tap-text":
    if (!clickNamed(args[0], "", 5)) {
      throw new Error(`Elemento non trovato: ${args[0]}`);
    }
    break;

  case "delete-current-row":
    if (!clickNamed("Elimina", "AXButton", 5)) {
      throw new Error("Elemento non trovato: Elimina");
    }
    break;

  case "open-history-tab":
    if (!clickNamed("Cronologia", "AXButton", 2)) {
      clickRelative(0.625, 0.932);
    }
    break;

  case "open-latest-manual":
    if (!clickNamed("Inventario manuale", "", 8)) {
      throw new Error("Elemento non trovato: Inventario manuale");
    }
    break;

  case "wait":
    delaySeconds(args[0] || "1");
    break;

  case "dump-names": {
    const filter = lower(args[0] || "");
    const seen = {};
    const elements = allElements();
    for (let index = 0; index < elements.length; index += 1) {
      const name = elementName(elements[index]);
      if (!name) {
        continue;
      }

      const lowered = lower(name);
      if (filter && !lowered.includes(filter)) {
        continue;
      }

      const role = elementRole(elements[index]);
      const line = `${role}\t${name}`;
      if (!seen[line]) {
        seen[line] = true;
        console.log(line);
      }
    }
    break;
  }

  default:
    throw new Error(`Azione non supportata: ${action}`);
}
JXA
}

command="${1:-}"
shift || true

case "$command" in
  launch-app)
    xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" >/dev/null
    ;;
  launch-manual)
    xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" >/dev/null
    run_ui launch-manual
    ;;
  show-simulator)
    udid="$(booted_udid || true)"
    if [[ -n "$udid" ]]; then
      open -a Simulator --args -CurrentDeviceUDID "$udid" >/dev/null 2>&1 || true
    else
      open -a Simulator >/dev/null 2>&1 || true
    fi
    sleep 1
    ;;
  open-add)
    run_ui open-add
    ;;
  fill-add)
    if [[ $# -lt 3 ]]; then
      usage
      exit 1
    fi
    run_ui fill-add "${1:-}" "${2:-}" "${3:-}" "${4:-}" "${5:-}"
    ;;
  confirm)
    run_ui confirm
    ;;
  tap-text)
    if [[ $# -lt 1 ]]; then
      usage
      exit 1
    fi
    run_ui tap-text "$1"
    ;;
  delete-current-row)
    run_ui delete-current-row
    ;;
  open-history-tab)
    run_ui open-history-tab
    ;;
  open-latest-manual)
    run_ui open-latest-manual
    ;;
  dump-names)
    run_ui dump-names "${1:-}"
    ;;
  terminate)
    xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null || true
    ;;
  capture)
    if [[ $# -lt 1 ]]; then
      usage
      exit 1
    fi
    xcrun simctl io "$DEVICE_ID" screenshot "$1" >/dev/null
    ;;
  wait)
    if [[ $# -lt 1 ]]; then
      usage
      exit 1
    fi
    run_ui wait "$1"
    ;;
  ""|help|-h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
