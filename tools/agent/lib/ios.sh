#!/usr/bin/env bash

mc_ios_destination() {
  if [[ -n "${MC_IOS_SIMULATOR_ID:-}" ]]; then
    printf 'platform=iOS Simulator,id=%s' "$MC_IOS_SIMULATOR_ID"
    return 0
  fi
  if [[ -n "${MC_IOS_SIMULATOR_UDID:-}" ]]; then
    printf 'platform=iOS Simulator,id=%s' "$MC_IOS_SIMULATOR_UDID"
    return 0
  fi
  printf '%s' "${MC_IOS_DESTINATION:-platform=iOS Simulator,name=${MC_IOS_SIMULATOR_NAME},OS=${MC_IOS_SIMULATOR_OS}}"
}

mc_ios_simulator_target() {
  if [[ -n "${MC_IOS_SIMULATOR_ID:-}" ]]; then
    printf '%s\n' "$MC_IOS_SIMULATOR_ID"
    return "$MC_EXIT_PASS"
  fi
  if [[ -n "${MC_IOS_SIMULATOR_UDID:-}" ]]; then
    printf '%s\n' "$MC_IOS_SIMULATOR_UDID"
    return "$MC_EXIT_PASS"
  fi
  local target
  target="$(MC_IOS_SIMULATOR_NAME="$MC_IOS_SIMULATOR_NAME" MC_IOS_SIMULATOR_OS="${MC_IOS_SIMULATOR_OS:-}" python3 - <<'PY'
import json, os, subprocess, sys

name = os.environ.get("MC_IOS_SIMULATOR_NAME", "")
version = os.environ.get("MC_IOS_SIMULATOR_OS", "")
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "--json"], text=True)
data = json.loads(raw)

def runtime_matches(runtime):
    if not version:
        return True
    suffix = "iOS-" + version.replace(".", "-")
    return runtime.endswith(suffix)

matches = []
booted_matches = []
for runtime, devices in data.get("devices", {}).items():
    if not runtime_matches(runtime):
        continue
    for device in devices:
        if device.get("name") != name:
            continue
        if not device.get("isAvailable", True):
            continue
        matches.append(device)
        if device.get("state") == "Booted":
            booted_matches.append(device)

candidates = booted_matches or matches
if len(candidates) == 1:
    print(candidates[0]["udid"])
    sys.exit(0)
if len(candidates) == 0:
    sys.exit(2)
sys.exit(3)
PY
)"
  case "$?" in
    0)
      printf '%s\n' "$target"
      return "$MC_EXIT_PASS"
      ;;
    2)
      MC_SUMMARY="No configured iOS simulator target found for name=${MC_IOS_SIMULATOR_NAME} OS=${MC_IOS_SIMULATOR_OS:-any}."
      MC_NEXT_ACTION="Boot/configure the intended simulator or set MC_IOS_SIMULATOR_ID explicitly."
      return "$MC_EXIT_BLOCKED"
      ;;
    *)
      MC_SUMMARY="Ambiguous iOS simulator target for name=${MC_IOS_SIMULATOR_NAME} OS=${MC_IOS_SIMULATOR_OS:-any}."
      MC_NEXT_ACTION="Set MC_IOS_SIMULATOR_ID to the simulator the user actually opens, then retry."
      return "$MC_EXIT_BLOCKED"
      ;;
  esac
}

mc_ios_result_bundle() {
  local slug="$1"
  printf '%s' "/tmp/mc-agent-ios-${slug}-${MC_TIMESTAMP}.xcresult"
}

mc_ios_runtime_derived_data() {
  local slug="$1"
  printf '%s' "/tmp/mc-agent-ios-${slug}-${MC_TIMESTAMP}-DerivedData"
}

mc_ios_app_bundle_id() {
  printf '%s' "${MC_IOS_BUNDLE_ID:-com.niwcyber.iOSMerchandiseControl}"
}

mc_ios_boot_simulator() {
  local target
  target="$(mc_ios_simulator_target)" || return $?
  xcrun simctl boot "$target" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$target" -b
}

mc_ios_build_app_for_runtime() {
  local derived_data="$1"
  local dest app_path
  dest="$(mc_ios_destination)"
  (
    cd "$MC_IOS_REPO" || exit 3
    xcodebuild build -project iOSMerchandiseControl.xcodeproj \
      -scheme "${MC_IOS_SCHEME}" \
      -configuration Debug \
      -destination "$dest" \
      -derivedDataPath "$derived_data" \
      -parallel-testing-enabled NO
  ) >&2 || return $?
  app_path="$(find "$derived_data/Build/Products" -path '*/Debug-iphonesimulator/iOSMerchandiseControl.app' -type d | sort | head -1)"
  [[ -n "$app_path" && -d "$app_path" ]] || return "$MC_EXIT_BLOCKED"
  printf '%s\n' "$app_path"
}

mc_ios_runtime_launch_app() {
  local app_path="$1"
  local bundle_id target
  bundle_id="$(mc_ios_app_bundle_id)"
  target="$(mc_ios_simulator_target)" || return $?
  mc_ios_boot_simulator || return "$MC_EXIT_BLOCKED"
  xcrun simctl terminate "$target" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install "$target" "$app_path" || return "$MC_EXIT_BLOCKED"
  xcrun simctl terminate "$target" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl launch "$target" "$bundle_id" || return "$MC_EXIT_BLOCKED"
}

mc_ios_runtime_foreground_installed_app() {
  local bundle_id target
  bundle_id="$(mc_ios_app_bundle_id)"
  target="$(mc_ios_simulator_target)" || return $?
  mc_ios_boot_simulator || return "$MC_EXIT_BLOCKED"
  if [[ "${MC_IOS_RUNTIME_FORCE_RELAUNCH:-0}" == "1" ]]; then
    xcrun simctl terminate "$target" "$bundle_id" >/dev/null 2>&1 || true
  fi
  xcrun simctl launch "$target" "$bundle_id" || return "$MC_EXIT_BLOCKED"
}

mc_ios_store_runtime_guard() {
  local store="$1"
  if [[ -z "$store" || ! -f "$store" ]]; then
    MC_SUMMARY="iOS runtime store guard FAIL: default.store was not found after app launch."
    MC_NEXT_ACTION="Install/launch the app, then retry ios runtime-ui-counts --live."
    return "$MC_EXIT_BLOCKED"
  fi
  if [[ "$store" != *"/Containers/Data/Application/"* || "$store" == *"DerivedData"* || "$store" == *".xctest"* ]]; then
    MC_SUMMARY="iOS runtime store guard FAIL: store path does not look like the launched app data container."
    MC_NEXT_ACTION="Inspect simctl get_app_container output; do not use XCTest/test-host stores for runtime evidence."
    return "$MC_EXIT_FAIL"
  fi
  return "$MC_EXIT_PASS"
}

mc_ios_runtime_store_metadata_json() {
  local container="$1"
  local store="$2"
  BUNDLE_ID="$(mc_ios_app_bundle_id)" CONTAINER_PATH="$container" STORE_PATH="$store" python3 - <<'PY'
import hashlib, json, os, plistlib, sqlite3

container = os.environ["CONTAINER_PATH"]
store = os.environ["STORE_PATH"]
bundle_id = os.environ["BUNDLE_ID"]

def sha(value):
    return hashlib.sha256(value.encode()).hexdigest()

def apple_ts(value):
    if value is None:
        return None
    try:
        # SwiftData/CoreData timestamps are seconds from 2001-01-01.
        import datetime as dt
        return (dt.datetime(2001, 1, 1, tzinfo=dt.timezone.utc) + dt.timedelta(seconds=float(value))).strftime("%Y-%m-%dT%H:%M:%SZ")
    except Exception:
        return None

container_kind = os.environ.get("IOS_CONTAINER_KIND", "")
is_physical_copy = container_kind == "physical"
metadata = {
    "containerPathHash": sha(container),
    "storePathHash": sha(store),
    "storeFile": os.path.basename(store),
    "containerKind": container_kind or "simulator",
    "isRuntimeAppContainer": is_physical_copy or ("/Containers/Data/Application/" in store and "DerivedData" not in store and ".xctest" not in store),
    "lastSuccessfulSync": None,
    "baseline": None,
    "diagnostics": {
        "plistPresent": False,
        "runtime": {},
        "syncEventWatermarks": [],
    },
}
prefs_candidates = [
    os.path.join(container, "Library", "Preferences", f"{bundle_id}.plist"),
    os.path.join(container, "Preferences", f"{bundle_id}.plist"),
]
prefs_path = next((path for path in prefs_candidates if os.path.exists(path)), prefs_candidates[0])
def plist_value(value):
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)
try:
    with open(prefs_path, "rb") as handle:
        prefs = plistlib.load(handle)
    runtime = {}
    watermarks = []
    for key, value in prefs.items():
        if key.startswith("sync.runtime."):
            runtime[key.replace("sync.runtime.", "", 1)] = plist_value(value)
        elif key.startswith("task114.runtime."):
            runtime.setdefault(key.replace("task114.runtime.", "", 1), plist_value(value))
        elif key.startswith("task115.runtime."):
            runtime.setdefault(key.replace("task115.runtime.", "", 1), plist_value(value))
        elif key.startswith("sync.events.watermark.account."):
            watermarks.append({"scopeHash": sha(key)[:12], "value": plist_value(value), "source": "sync"})
        elif key.startswith("task114.syncEvents.watermark."):
            owner = key.replace("task114.syncEvents.watermark.", "", 1)
            watermarks.append({"ownerHash": sha(owner)[:12], "value": plist_value(value), "source": "legacyOwner"})
        elif key.startswith("task115.syncEvents.watermark.account."):
            watermarks.append({"scopeHash": sha(key)[:12], "value": plist_value(value), "source": "legacyAccount"})
        elif key == "sync.accountBinding.v1":
            binding = {"present": True, "decoded": False}
            try:
                raw = value.decode() if isinstance(value, (bytes, bytearray)) else str(value)
                decoded = json.loads(raw)
                binding.update({
                    "decoded": True,
                    "accountHashPresent": bool(decoded.get("accountHash")),
                    "accountHashHash": sha(str(decoded.get("accountHash") or ""))[:12],
                    "storeIdentityHash": sha(str(decoded.get("storeIdentity", {}).get("rawValue") or ""))[:12],
                    "boundAtPresent": bool(decoded.get("boundAt")),
                })
            except Exception:
                binding["decodeError"] = "redacted"
            metadata["diagnostics"]["accountBinding"] = binding
    metadata["diagnostics"] = {
        "plistPresent": True,
        "runtime": runtime,
        "syncEventWatermarks": watermarks,
        "accountBinding": metadata["diagnostics"].get("accountBinding", {"present": False}),
    }
except FileNotFoundError:
    pass
except Exception as exc:
    metadata["diagnostics"]["error"] = type(exc).__name__
try:
    con = sqlite3.connect(f"file:{store}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    tables = {row[0].upper(): row[0] for row in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    run_table = tables.get("ZSUPABASECATALOGBASELINERUN")
    if run_table:
        row = con.execute(
            f"""
            SELECT ZSTATUS, ZSOURCE, ZPRODUCTCOUNT, ZSUPPLIERCOUNT, ZCATEGORYCOUNT,
                   ZTOMBSTONECOUNT, ZAPPLIEDAT, ZCREATEDAT, ZUPDATEDAT
            FROM {run_table}
            WHERE ZSTATUS = 'valid'
            ORDER BY ZAPPLIEDAT DESC
            LIMIT 1
            """
        ).fetchone()
        if row:
            metadata["lastSuccessfulSync"] = apple_ts(row["ZAPPLIEDAT"])
            metadata["baseline"] = {
                "status": row["ZSTATUS"],
                "source": row["ZSOURCE"],
                "products": row["ZPRODUCTCOUNT"],
                "suppliers": row["ZSUPPLIERCOUNT"],
                "categories": row["ZCATEGORYCOUNT"],
                "tombstones": row["ZTOMBSTONECOUNT"],
                "appliedAt": apple_ts(row["ZAPPLIEDAT"]),
                "createdAt": apple_ts(row["ZCREATEDAT"]),
                "updatedAt": apple_ts(row["ZUPDATEDAT"]),
            }
except Exception as exc:
    metadata["metadataError"] = type(exc).__name__
print(json.dumps(metadata, sort_keys=True))
PY
}

mc_ios_runtime_counts_payload() {
  local source="$1"
  local wait_seconds="$2"
  local container="$3"
  local store="$4"
  local counts_json metadata_json

  MC_IOS_CONTAINER_OVERRIDE="$container" MC_IOS_STORE_OVERRIDE="$store" mc_sync_counts_ios "$MC_TASK_ID"
  counts_json="$MC_SYNC_JSON_RESULT"
  metadata_json="$(IOS_CONTAINER_KIND="${MC_IOS_CONTAINER_KIND:-}" mc_ios_runtime_store_metadata_json "$container" "$store")"
  IOS_COUNTS_JSON="$counts_json" IOS_METADATA_JSON="$metadata_json" IOS_WAIT_SECONDS="$wait_seconds" IOS_RUNTIME_SOURCE="$source" python3 - > /tmp/mc-agent-ios-runtime-ui-counts.$$.json <<'PY'
import json, os
from datetime import datetime, timezone

counts = json.loads(os.environ["IOS_COUNTS_JSON"])
metadata = json.loads(os.environ["IOS_METADATA_JSON"])
status = "PASS"
blocker = None
if counts.get("status") != "PASS":
    status = "BLOCKED"
    blocker = counts.get("blocker", "iOS runtime count source unavailable")
if not metadata.get("isRuntimeAppContainer"):
    status = "FAIL"
    blocker = "Store path is not the launched app runtime container"
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
payload = dict(counts)
payload.update({
    "completedAt": now,
    "source": os.environ["IOS_RUNTIME_SOURCE"],
    "runtime": {
        "launchedAppBundleID": "com.niwcyber.iOSMerchandiseControl",
        "waitSecondsAfterLaunch": int(float(os.environ["IOS_WAIT_SECONDS"])),
        **metadata,
    },
    "lastPull": metadata.get("lastSuccessfulSync"),
    "lastFullReconciliation": metadata.get("lastSuccessfulSync"),
    "status": status,
})
if blocker:
    payload["blocker"] = blocker
print(json.dumps(payload, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-ios-runtime-ui-counts.$$.json)"
  rm -f /tmp/mc-agent-ios-runtime-ui-counts.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
}

mc_ios_physical_device_json() {
  local json device_json
  json="$(mktemp /tmp/mc-agent-ios-physical-devices.XXXXXX)"
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || return "$MC_EXIT_BLOCKED"
  device_json="$(MC_IOS_DEVICE_ID="${MC_IOS_DEVICE_ID:-}" python3 - "$json" <<'PY'
import json, os, sys
path = sys.argv[1]
target = os.environ.get("MC_IOS_DEVICE_ID") or ""
with open(path) as handle:
    data = json.load(handle)
devices = data.get("result", {}).get("devices", [])
iphones = []
for device in devices:
    hw = device.get("hardwareProperties", {})
    props = device.get("deviceProperties", {})
    conn = device.get("connectionProperties", {})
    if hw.get("platform") != "iOS":
        continue
    ident = device.get("identifier")
    candidates = {
        ident,
        hw.get("udid"),
        hw.get("serialNumber"),
        props.get("name"),
        *(conn.get("potentialHostnames") or []),
    }
    if target and target not in candidates:
        continue
    iphones.append({
        "identifier": ident,
        "name": props.get("name"),
        "productType": hw.get("productType"),
        "osVersion": props.get("osVersionNumber"),
        "state": conn.get("tunnelState") or "unknown",
        "udidHash": __import__("hashlib").sha256(str(hw.get("udid") or ident or "").encode()).hexdigest()[:12],
    })
if len(iphones) == 1:
    print(json.dumps(iphones[0], sort_keys=True))
    sys.exit(0)
if len(iphones) == 0:
    sys.exit(2)
sys.exit(3)
PY
)"
  local code=$?
  rm -f "$json"
  if [[ "$code" -ne 0 ]]; then
    return "$code"
  fi
  printf '%s\n' "$device_json"
}

mc_ios_physical_device_id() {
  local device_json
  device_json="$(mc_ios_physical_device_json)" || return $?
  DEVICE_JSON="$device_json" python3 - <<'PY'
import json, os
print(json.loads(os.environ["DEVICE_JSON"])["identifier"])
PY
}

mc_ios_physical_launch_app() {
  local device_id="$1"
  local bundle_id
  bundle_id="$(mc_ios_app_bundle_id)"
  xcrun devicectl device process launch \
    --device "$device_id" \
    --terminate-existing \
    "$bundle_id" >/dev/null 2>&1
}

mc_ios_physical_copy_library() {
  local device_id="$1"
  local dest
  dest="$(mktemp -d /tmp/mc-agent-ios-physical-library.XXXXXX)"
  xcrun devicectl device copy from \
    --device "$device_id" \
    --domain-type appDataContainer \
    --domain-identifier "$(mc_ios_app_bundle_id)" \
    --source Library \
    --destination "$dest" >/dev/null 2>&1 || {
      rm -rf "$dest"
      return "$MC_EXIT_BLOCKED"
    }
  printf '%s\n' "$dest"
}

mc_ios_physical_runtime_counts_payload() {
  local source="$1"
  local wait_seconds="${2:-60}"
  local device_json device_id container store
  device_json="$(mc_ios_physical_device_json)" || {
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$MC_TASK_ID" "$source" "No single connected physical iPhone was found by devicectl.")"
    return "$MC_EXIT_BLOCKED"
  }
  device_id="$(DEVICE_JSON="$device_json" python3 - <<'PY'
import json, os
print(json.loads(os.environ["DEVICE_JSON"])["identifier"])
PY
)"
  mc_ios_physical_launch_app "$device_id" || {
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$MC_TASK_ID" "$source" "Physical iPhone app launch failed; unlock/trust the device and ensure the app is installed.")"
    return "$MC_EXIT_BLOCKED"
  }
  if [[ "$wait_seconds" != "0" && "$wait_seconds" != "0.0" ]]; then
    sleep "$wait_seconds"
  fi
  container="$(mc_ios_physical_copy_library "$device_id")" || {
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$MC_TASK_ID" "$source" "Physical iPhone appDataContainer copy failed; unlock/trust the device.")"
    return "$MC_EXIT_BLOCKED"
  }
  store="$(mc_sync_ios_store_path "$container" 2>/dev/null || true)"
  if [[ -z "$store" ]]; then
    rm -rf "$container"
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$MC_TASK_ID" "$source" "Physical iPhone SwiftData store was not found in copied appDataContainer.")"
    return "$MC_EXIT_BLOCKED"
  fi
  MC_IOS_CONTAINER_KIND="physical" mc_ios_runtime_counts_payload "$source" "$wait_seconds" "$container" "$store"
  DEVICE_JSON="$device_json" CURRENT_JSON="$MC_SYNC_JSON_RESULT" python3 - > /tmp/mc-agent-ios-physical-counts.$$.json <<'PY'
import json, os
payload = json.loads(os.environ["CURRENT_JSON"])
device = json.loads(os.environ["DEVICE_JSON"])
payload.setdefault("runtime", {})["physicalDevice"] = {
    "name": device.get("name"),
    "productType": device.get("productType"),
    "osVersion": device.get("osVersion"),
    "state": device.get("state"),
    "udidHash": device.get("udidHash"),
}
print(json.dumps(payload, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-ios-physical-counts.$$.json)"
  rm -f /tmp/mc-agent-ios-physical-counts.$$.json
  rm -rf "$container"
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
}

mc_ios_physical_runtime_counts() {
  local wait_seconds="${MC_IOS_PHYSICAL_WAIT_SECONDS:-60}"
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="live-readonly"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-03,CA-04,CA-05,CA-10"
  mc_require_live || return $?
  mc_ios_physical_runtime_counts_payload "ios.physical-runtime-counts" "$wait_seconds"
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="iOS physical-runtime-counts PASS: launched physical iPhone app and read copied runtime SwiftData store."
    MC_NEXT_ACTION="Run ios physical-sync-loop-diagnostics or physical-sync-acceptance."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="iOS physical-runtime-counts BLOCKED: physical iPhone runtime store unavailable."
  MC_NEXT_ACTION="Unlock/trust the iPhone, verify the app is installed/logged in, then rerun."
  return "$code"
}

mc_ios_physical_auth_store_diagnostics() {
  local wait_seconds="${MC_IOS_PHYSICAL_DIAGNOSTIC_WAIT_SECONDS:-10}"
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="live-readonly"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-115-04,CA-115-13,CA-115-16"
  mc_require_live || return $?
  mc_ios_physical_runtime_counts_payload "ios.physical-auth-store-diagnostics" "$wait_seconds"
  local code=$?
  [[ "$code" -eq 0 ]] || {
    MC_SUMMARY="iOS physical-auth-store-diagnostics BLOCKED: physical runtime store/session evidence unavailable."
    MC_NEXT_ACTION="Unlock/trust the iPhone, install/open the app, sign in, then rerun diagnostics."
    return "$code"
  }
  CURRENT_JSON="$MC_SYNC_JSON_RESULT" python3 - > /tmp/mc-agent-ios-physical-auth-store.$$.json <<'PY'
import json, os

payload = json.loads(os.environ["CURRENT_JSON"])
runtime = payload.get("runtime", {})
diagnostics = runtime.get("diagnostics", {})
runtime_flags = diagnostics.get("runtime", {})
counts = payload.get("counts", {})
binding = diagnostics.get("accountBinding") or {"present": False}
pending = sum((counts.get(k, {}) or {}).get("pending") or 0 for k in ["products", "suppliers", "categories", "product_prices", "history_entries"])
auth_ready = runtime_flags.get("auth.isSignedIn") is True and runtime_flags.get("auth.userIDPresent") is True
baseline_present = payload.get("baseline") is not None
watermark_count = len(diagnostics.get("syncEventWatermarks") or [])
blocked = []
if not auth_ready:
    blocked.append("AUTH_SESSION_NOT_READY")
if not runtime.get("isRuntimeAppContainer"):
    blocked.append("NOT_RUNTIME_APP_CONTAINER")
payload["physicalAuthStoreDiagnostics"] = {
    "authReady": auth_ready,
    "accountBindingPresent": bool(binding.get("present")),
    "accountBindingDecoded": bool(binding.get("decoded")),
    "pendingAggregate": pending,
    "baselinePresent": baseline_present,
    "watermarkCount": watermark_count,
    "storePathHashPresent": bool(runtime.get("storePathHash")),
    "containerPathHashPresent": bool(runtime.get("containerPathHash")),
    "blockers": blocked,
}
if blocked:
    payload["status"] = "BLOCKED"
    payload["blocker"] = ",".join(blocked)
print(json.dumps(payload, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-ios-physical-auth-store.$$.json)"
  rm -f /tmp/mc-agent-ios-physical-auth-store.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  if [[ "$(printf '%s' "$MC_SYNC_JSON_RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status"))')" == "PASS" ]]; then
    MC_SUMMARY="iOS physical-auth-store-diagnostics PASS: physical session/store/binding diagnostics were collected."
    MC_NEXT_ACTION="Run ios physical-sync-acceptance."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="iOS physical-auth-store-diagnostics BLOCKED: physical app session is not ready for acceptance."
  MC_NEXT_ACTION="Open the app on the physical iPhone, complete login/session restore, then rerun."
  return "$MC_EXIT_BLOCKED"
}

mc_ios_physical_sync_loop_diagnostics() {
  local wait_seconds="${MC_IOS_PHYSICAL_DIAGNOSTIC_WAIT_SECONDS:-60}"
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="live-readonly"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-03,CA-04,CA-05,CA-10"
  mc_require_live || return $?
  mc_ios_physical_runtime_counts_payload "ios.physical-sync-loop-diagnostics" "$wait_seconds"
  local code=$?
  [[ "$code" -eq 0 ]] || {
    MC_SUMMARY="iOS physical-sync-loop-diagnostics BLOCKED: could not collect physical runtime counts/diagnostics."
    MC_NEXT_ACTION="Unlock/trust the iPhone and rerun diagnostics."
    return "$code"
  }
  CURRENT_JSON="$MC_SYNC_JSON_RESULT" python3 - > /tmp/mc-agent-ios-physical-loop.$$.json <<'PY'
import json, os
payload = json.loads(os.environ["CURRENT_JSON"])
runtime = payload.get("runtime", {}).get("diagnostics", {}).get("runtime", {})
last_page = {
    "eventsFetched": runtime.get("incremental.lastPage.eventsFetched"),
    "eventsProcessed": runtime.get("incremental.lastPage.eventsProcessed"),
    "watermarkBefore": runtime.get("incremental.lastPage.watermarkBefore"),
    "watermarkAfter": runtime.get("incremental.lastPage.watermarkAfter"),
    "targetedProductsFetched": runtime.get("incremental.lastPage.productsFetched"),
    "targetedPricesFetched": runtime.get("incremental.lastPage.pricesFetched"),
    "targetedHistoryFetched": runtime.get("incremental.lastPage.historyFetched"),
    "applied": runtime.get("incremental.lastPage.applied"),
}
requires_recovery = bool(runtime.get("incremental.lastRequiresFullRecovery") or runtime.get("incremental.lastRequiresFullRecoveryReason"))
attempts = int(runtime.get("incremental.attemptWindow.count") or 0)
auth_ready = runtime.get("auth.isSignedIn") is True and runtime.get("auth.userIDPresent") is True
classification = []
if not auth_ready:
    classification.append("AUTH_SESSION_NOT_READY")
if auth_ready and last_page["eventsFetched"] == 50 and last_page["applied"] == 0 and requires_recovery:
    classification.append("FULL_RECOVERY_REQUIRED_BUT_NOT_SCHEDULED")
if auth_ready and last_page["eventsFetched"] == 50 and last_page["targetedProductsFetched"] == 0 and last_page["targetedPricesFetched"] == 0 and last_page["targetedHistoryFetched"] == 0:
    classification.append("EMPTY_TARGET_EVENTS_LOOP")
if auth_ready and last_page["watermarkAfter"] == last_page["watermarkBefore"] and last_page["eventsFetched"]:
    classification.append("STALE_WATERMARK_NOT_ADVANCING")
if attempts > 12:
    classification.append("APP_RUNTIME_BUG")
payload["loopDiagnostics"] = {
    "attemptsLast60s": attempts,
    "lastPage": last_page,
    "requiresFullRecovery": requires_recovery,
    "requiresFullRecoveryReason": runtime.get("incremental.lastRequiresFullRecoveryReason"),
    "sameEventPageRepeated": runtime.get("incremental.samePageRepeatCount"),
    "classification": classification or ["NO_LOOP_EVIDENCE_IN_CAPTURE"],
    "currentSyncPhase": runtime.get("incremental.lastOutcome"),
    "currentSyncSource": runtime.get("incremental.lastSource"),
    "currentSyncType": runtime.get("incremental.lastSyncType"),
    "progressNumerator": runtime.get("progress.current"),
    "progressDenominator": runtime.get("progress.total"),
}
print(json.dumps(payload, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-ios-physical-loop.$$.json)"
  rm -f /tmp/mc-agent-ios-physical-loop.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  MC_SUMMARY="iOS physical-sync-loop-diagnostics PASS: collected physical runtime counts, diagnostics, and loop classification."
  MC_NEXT_ACTION="Fix any loop classification, then run ios physical-sync-acceptance."
  return "$MC_EXIT_PASS"
}

mc_ios_physical_smoke_options() {
  local wait_seconds="${MC_IOS_PHYSICAL_SMOKE_WAIT_SECONDS:-20}"
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="live-readonly"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-03,CA-04,CA-05,CA-10"
  mc_require_live || return $?
  mc_ios_physical_runtime_counts_payload "ios.physical-smoke-options" "$wait_seconds"
  local code=$?
  [[ "$code" -eq 0 ]] || {
    MC_SUMMARY="iOS physical-smoke-options BLOCKED: physical runtime counts unavailable."
    MC_NEXT_ACTION="Unlock/trust the iPhone, open Options if needed, then rerun."
    return "$code"
  }
  CURRENT_JSON="$MC_SYNC_JSON_RESULT" python3 - > /tmp/mc-agent-ios-physical-smoke.$$.json <<'PY'
import json, os
payload = json.loads(os.environ["CURRENT_JSON"])
runtime = payload.get("runtime", {}).get("diagnostics", {}).get("runtime", {})
progress_current = runtime.get("progress.current")
progress_total = runtime.get("progress.total")
active = runtime.get("progress.isActive")
payload["optionsSmoke"] = {
    "automaticSyncInProgress": bool(active),
    "spinnerZeroOfZero": bool(active and progress_current == 0 and progress_total == 0),
    "localDatabaseNeedsCloudCheck": runtime.get("reconcile.mismatches") not in (None, ""),
    "lastOutcome": runtime.get("incremental.lastOutcome"),
    "lastSyncType": runtime.get("incremental.lastSyncType"),
}
if payload["optionsSmoke"]["spinnerZeroOfZero"]:
    payload["status"] = "FAIL"
    payload["blocker"] = "Physical Options reports active progress with 0/0 work."
print(json.dumps(payload, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-ios-physical-smoke.$$.json)"
  rm -f /tmp/mc-agent-ios-physical-smoke.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  if [[ "$(printf '%s' "$MC_SYNC_JSON_RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status"))')" == "PASS" ]]; then
    MC_SUMMARY="iOS physical-smoke-options PASS: physical runtime status has no 0/0 active spinner signal."
    MC_NEXT_ACTION="Run ios physical-sync-loop-diagnostics or physical-sync-acceptance."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="iOS physical-smoke-options FAIL: Options zero-work spinner signal detected."
  MC_NEXT_ACTION="Fix progress state and rerun physical smoke."
  return "$MC_EXIT_FAIL"
}

mc_ios_physical_sync_acceptance() {
  local wait_seconds="${MC_IOS_PHYSICAL_ACCEPTANCE_WAIT_SECONDS:-60}"
  local physical_json supabase_json supabase_code
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="live-readonly"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-115-13,CA-115-14,CA-115-16"
  mc_require_live || return $?
  mc_ios_physical_runtime_counts_payload "ios.physical-sync-acceptance" "$wait_seconds"
  local code=$?
  [[ "$code" -eq 0 ]] || {
    MC_SUMMARY="iOS physical-sync-acceptance BLOCKED: physical runtime evidence unavailable."
    MC_NEXT_ACTION="Unlock/trust the iPhone, verify login, then rerun acceptance."
    return "$code"
  }
  physical_json="$MC_SYNC_JSON_RESULT"
  mc_sync_counts_supabase "$MC_TASK_ID" "${MC_SUPABASE_PROFILE:-linked}"
  supabase_code=$?
  supabase_json="$MC_SYNC_JSON_RESULT"
  if [[ "$supabase_code" -ne 0 ]]; then
    MC_SYNC_JSON_RESULT="$physical_json"
    mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
    MC_SUMMARY="iOS physical-sync-acceptance BLOCKED: Supabase linked counts unavailable for physical comparison."
    MC_NEXT_ACTION="Retry serially after Supabase pooler/backoff; do not treat physical counts as accepted without remote comparison."
    return "$supabase_code"
  fi
  PHYSICAL_JSON="$physical_json" SUPABASE_JSON="$supabase_json" python3 - > /tmp/mc-agent-ios-physical-acceptance.$$.json <<'PY'
import json, os
payload = json.loads(os.environ["PHYSICAL_JSON"])
remote = json.loads(os.environ["SUPABASE_JSON"])
runtime = payload.get("runtime", {}).get("diagnostics", {}).get("runtime", {})
counts = payload.get("counts", {})
pending = sum((counts.get(k, {}) or {}).get("pending") or 0 for k in ["products", "suppliers", "categories", "product_prices", "history_entries"])
attempts = int(runtime.get("incremental.attemptWindow.count") or 0)
requires_recovery = bool(runtime.get("incremental.lastRequiresFullRecovery") or runtime.get("incremental.lastRequiresFullRecoveryReason"))
active_zero = bool(runtime.get("progress.isActive") and runtime.get("progress.current") == 0 and runtime.get("progress.total") == 0)
auth_ready = runtime.get("auth.isSignedIn") is True and runtime.get("auth.userIDPresent") is True
blockers = []
failures = []
drift = {}
for table in ["products", "suppliers", "categories", "product_prices"]:
    local_active = (counts.get(table) or {}).get("active")
    remote_active = (remote.get("counts", {}).get(table) or {}).get("active")
    if local_active != remote_active:
        drift[table] = {"physical": local_active, "supabase": remote_active}
local_history = (counts.get("history_entries") or {}).get("userVisible")
remote_history = (remote.get("counts", {}).get("history_entries") or {}).get("userVisible")
if local_history != remote_history:
    drift["history_entries"] = {"physical": local_history, "supabase": remote_history}
if active_zero:
    failures.append("spinner_zero_of_zero")
if not auth_ready:
    blockers.append("AUTH_SESSION_NOT_READY")
if auth_ready and attempts > 12:
    failures.append("too_many_sync_attempts_last_60s")
if auth_ready and runtime.get("incremental.lastSyncType") == "EVENT_INCREMENTAL" and runtime.get("incremental.lastPage.applied") == 0 and requires_recovery:
    failures.append("event_incremental_requires_recovery_no_apply")
if auth_ready and drift and not requires_recovery:
    failures.append("physical_counts_drift_without_recovery")
payload["physicalAcceptance"] = {
    "pendingAggregate": pending,
    "attemptsLast60s": attempts,
    "requiresFullRecovery": requires_recovery,
    "authReady": auth_ready,
    "spinnerZeroOfZero": active_zero,
    "lastSyncType": runtime.get("incremental.lastSyncType"),
    "lastOutcome": runtime.get("incremental.lastOutcome"),
    "drift": drift,
    "blockers": blockers,
    "failures": failures,
}
if blockers:
    payload["status"] = "BLOCKED"
    payload["blocker"] = ",".join(blockers)
elif failures:
    payload["status"] = "FAIL"
    payload["blocker"] = ",".join(failures)
print(json.dumps(payload, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-ios-physical-acceptance.$$.json)"
  rm -f /tmp/mc-agent-ios-physical-acceptance.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  local status
  status="$(printf '%s' "$MC_SYNC_JSON_RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status"))')"
  case "$status" in
    PASS)
      MC_SUMMARY="iOS physical-sync-acceptance PASS: physical iPhone runtime has no loop/0-work spinner signal in the acceptance window."
      MC_NEXT_ACTION="Run cross-platform regression gates."
      return "$MC_EXIT_PASS"
      ;;
    BLOCKED)
      MC_SUMMARY="iOS physical-sync-acceptance BLOCKED: physical iPhone auth/session is not ready for acceptance."
      MC_NEXT_ACTION="Open the physical iPhone app, complete login/session restore, then rerun physical-sync-acceptance."
      return "$MC_EXIT_BLOCKED"
      ;;
    *)
      MC_SUMMARY="iOS physical-sync-acceptance FAIL: physical iPhone runtime loop or zero-work spinner signal remains."
      MC_NEXT_ACTION="Inspect physicalAcceptance and loopDiagnostics, fix, rerun."
      return "$MC_EXIT_FAIL"
      ;;
  esac
}

mc_ios_runtime_store_counts() {
  local wait_seconds="${1:-${MC_IOS_RUNTIME_REUSE_WAIT_SECONDS:-0}}"
  local container store

  if [[ "$wait_seconds" != "0" && "$wait_seconds" != "0.0" ]]; then
    sleep "$wait_seconds"
  fi
  container="$(mc_sync_ios_container 2>/dev/null || true)"
  store="$(mc_sync_ios_store_path "$container" 2>/dev/null || true)"
  mc_ios_store_runtime_guard "$store" || return $?
  mc_ios_runtime_counts_payload "ios.runtime-store-counts" "$wait_seconds" "$container" "$store"
  return "$MC_EXIT_PASS"
}

mc_ios_plist_set_or_add() {
  local plist="$1"
  local path="$2"
  local value="$3"
  /usr/libexec/PlistBuddy -c "Set ${path} ${value}" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add ${path} string ${value}" "$plist"
}

mc_ios_plist_ensure_dict() {
  local plist="$1"
  local path="$2"
  /usr/libexec/PlistBuddy -c "Print ${path}" "$plist" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Add ${path} dict" "$plist"
}

mc_ios_xctestrun_set_env() {
  local plist="$1"
  local key="$2"
  local value="$3"
  local env_path=":TestConfigurations:0:TestTargets:0:EnvironmentVariables"
  mc_ios_plist_ensure_dict "$plist" "$env_path" || return $?
  mc_ios_plist_set_or_add "$plist" "${env_path}:${key}" "$value"
}

mc_ios_simulator_auth_session_probe() {
  local target container bundle_id
  target="$(mc_ios_simulator_target)" || return $?
  bundle_id="$(mc_ios_app_bundle_id)"
  container="$(xcrun simctl get_app_container "$target" "$bundle_id" data 2>/dev/null)" || return "$MC_EXIT_BLOCKED"
  AUTH_CONTAINER="$container" AUTH_BUNDLE_ID="$bundle_id" python3 - <<'PY'
import base64
import hashlib
import json
import os
import plistlib
import time
from pathlib import Path

container = Path(os.environ["AUTH_CONTAINER"])
bundle_id = os.environ["AUTH_BUNDLE_ID"]
plist = container / "Library" / "Preferences" / f"{bundle_id}.plist"
payload = {
    "schemaVersion": "1.1",
    "source": "ios.auth-preflight.runtime-fallback",
    "status": "BLOCKED",
    "authPreflightFallback": {
        "simulatorFallbackSessionPresent": False,
        "subjectHashPresent": False,
        "expiresInFuture": False,
    },
}
if not plist.exists():
    payload["blocker"] = "AUTH_PLIST_MISSING"
    print(json.dumps(payload, sort_keys=True))
    raise SystemExit(2)

data = plistlib.loads(plist.read_bytes())
candidate_keys = [
    key for key in data
    if key.startswith("debug.simulator.") and "auth-token" in key
]
payload["authPreflightFallback"]["candidateCount"] = len(candidate_keys)
for key in sorted(candidate_keys):
    raw = data.get(key)
    try:
        decoded = json.loads(raw.decode() if isinstance(raw, (bytes, bytearray)) else str(raw))
    except Exception:
        continue
    access_token = decoded.get("accessToken") or decoded.get("access_token")
    if not access_token or access_token.count(".") < 2:
        continue
    try:
        segment = access_token.split(".")[1]
        padded = segment + ("=" * (-len(segment) % 4))
        claims = json.loads(base64.urlsafe_b64decode(padded.encode()))
    except Exception:
        continue
    sub = str(claims.get("sub") or "")
    exp = int(claims.get("exp") or 0)
    seconds_until_expiry = exp - time.time()
    payload["authPreflightFallback"].update({
        "simulatorFallbackSessionPresent": True,
        "subjectHashPresent": bool(sub),
        "subjectHash": hashlib.sha256(sub.encode()).hexdigest()[:12] if sub else None,
        "expiresInFuture": exp > time.time(),
        "secondsUntilExpiryBucket": (
            "gt_1h" if seconds_until_expiry > 3600
            else "gt_5m" if seconds_until_expiry > 300
            else "expired_or_near"
        ),
    })
    if sub and exp > time.time():
        payload["status"] = "PASS"
        payload.pop("blocker", None)
        print(json.dumps(payload, sort_keys=True))
        raise SystemExit(0)

payload["blocker"] = "AUTH_SESSION_NOT_READY"
print(json.dumps(payload, sort_keys=True))
raise SystemExit(2)
PY
}

mc_ios_xcode_lock_path() {
  printf '%s' "$MC_EVIDENCE_ABS/agent-runs/.mc-agent-xcode.lock"
}

mc_ios_acquire_xcode_lock() {
  local lock now lock_mtime lock_pid
  lock="$(mc_ios_xcode_lock_path)"
  mkdir -p "$(dirname "$lock")"
  if mkdir "$lock" 2>/dev/null; then
    printf 'pid=%s command=%s timestamp=%s\n' "$$" "${MC_COMMAND:-unknown}" "$(mc_now_iso)" > "$lock/owner"
    MC_IOS_XCODE_LOCK="$lock"
    trap mc_ios_release_xcode_lock EXIT INT TERM
    return "$MC_EXIT_PASS"
  fi
  now="$(date +%s)"
  lock_mtime="$(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null || echo "$now")"
  lock_pid="$(sed -n 's/^pid=\([0-9][0-9]*\).*/\1/p' "$lock/owner" 2>/dev/null | head -1)"
  if { [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; } || (( now - lock_mtime >= ${MC_LOCK_STALE_SECONDS:-3600} )); then
    rm -rf "$lock"
    if mkdir "$lock" 2>/dev/null; then
      printf 'pid=%s command=%s timestamp=%s\n' "$$" "${MC_COMMAND:-unknown}" "$(mc_now_iso)" > "$lock/owner"
      MC_IOS_XCODE_LOCK="$lock"
      trap mc_ios_release_xcode_lock EXIT INT TERM
      return "$MC_EXIT_PASS"
    fi
  fi
  MC_SUMMARY="Xcode build/test lock is already held."
  MC_NEXT_ACTION="Wait for pid=${lock_pid:-unknown} or inspect $(mc_relpath "$lock")."
  return "$MC_EXIT_BLOCKED"
}

mc_ios_release_xcode_lock() {
  if [[ -n "${MC_IOS_XCODE_LOCK:-}" ]]; then
    rm -rf "$MC_IOS_XCODE_LOCK"
    MC_IOS_XCODE_LOCK=""
  fi
  trap - EXIT INT TERM
}

mc_ios_build() {
  local config="$1"
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_CA_REFS="CA-113-02,CA-113-15,CA-113-30"
  case "$(printf '%s' "$config" | tr '[:upper:]' '[:lower:]')" in
    debug) config="Debug" ;;
    release) config="Release" ;;
    *) MC_SUMMARY="Unknown iOS build config: ${config}"; return "$MC_EXIT_MISCONFIGURED" ;;
  esac
  local dest bundle code
  dest="$(mc_ios_destination)"
  bundle="$(mc_ios_result_bundle "build-${config}")"
  MC_ARTIFACT_XCRESULT="$bundle"
  mc_git_context "$MC_IOS_REPO"
  mc_ios_acquire_xcode_lock || return $?
  (
    cd "$MC_IOS_REPO" || exit 3
    xcodebuild -project iOSMerchandiseControl.xcodeproj \
      -scheme "${MC_IOS_SCHEME}" \
      -configuration "$config" \
      -destination "$dest" \
      -resultBundlePath "$bundle" \
      build
  )
  code=$?
  mc_ios_release_xcode_lock
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="iOS ${config} build PASS. xcresult=${bundle}"
    MC_NEXT_ACTION="Run iOS targeted tests or release CTA scan."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="iOS ${config} build FAIL. xcresult=${bundle}"
  MC_NEXT_ACTION="Inspect xcodebuild log and xcresult."
  return "$MC_EXIT_FAIL"
}

mc_ios_test() {
  local suite="$1"
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_CA_REFS="CA-113-04,CA-113-15,CA-113-30"
  local dest bundle code
  local tests=()
  dest="$(mc_ios_destination)"
  bundle="$(mc_ios_result_bundle "test-${suite}")"
  MC_ARTIFACT_XCRESULT="$bundle"
  case "$suite" in
    sync)
      tests=(
        -only-testing:iOSMerchandiseControlTests/SyncCountReconciliationTests
        -only-testing:iOSMerchandiseControlTests/OptionsLocalDatabaseSummaryTests
        -only-testing:iOSMerchandiseControlTests/SupabasePullApplyServiceTests
        -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests
        -only-testing:iOSMerchandiseControlTests/HistorySessionSyncServiceTests
        -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests
        -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncCoordinatorTests
        -only-testing:iOSMerchandiseControlTests/LocalPendingAggregatedPushPlannerTests
        -only-testing:iOSMerchandiseControlTests/SyncDecisionEngineTests
        -only-testing:iOSMerchandiseControlTests/AccountSyncPolicyTests
        -only-testing:iOSMerchandiseControlTests/WatermarkStoreTests
        -only-testing:iOSMerchandiseControlTests/PendingChangeCoalescerTests
        -only-testing:iOSMerchandiseControlTests/SyncRecoveryPolicyTests
        -only-testing:iOSMerchandiseControlTests/SyncStatusPresenterTests
      )
      ;;
    automatic-domain)
      MC_CA_REFS="CA-118-06,CA-118-07,CA-118-08,CA-118-11,CA-118-12,CA-118-16"
      tests=(
        -only-testing:iOSMerchandiseControlTests/SyncDecisionEngineTests
        -only-testing:iOSMerchandiseControlTests/AccountSyncPolicyTests
        -only-testing:iOSMerchandiseControlTests/WatermarkStoreTests
        -only-testing:iOSMerchandiseControlTests/PendingChangeCoalescerTests
        -only-testing:iOSMerchandiseControlTests/SyncRecoveryPolicyTests
        -only-testing:iOSMerchandiseControlTests/SyncStatusPresenterTests
        -only-testing:iOSMerchandiseControlTests/OptionsLocalDatabaseSummaryTests
        -only-testing:iOSMerchandiseControlTests/HistorySessionSyncServiceTests
        -only-testing:iOSMerchandiseControlTests/Task118AutomaticDomainTests
      )
      ;;
    lifecycle)
      tests=(
        -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncLifecycleRunGateTests
        -only-testing:iOSMerchandiseControlTests/AutomaticSyncReconnectSchedulerTests
      )
      ;;
    offline)
      tests=(-only-testing:iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests/test06OfflineRetryCatalogPendingNoDuplicate)
      ;;
    *)
      MC_SUMMARY="Unknown iOS test suite: ${suite}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
  mc_git_context "$MC_IOS_REPO"
  mc_ios_acquire_xcode_lock || return $?
  (
    cd "$MC_IOS_REPO" || exit 3
    xcodebuild test -project iOSMerchandiseControl.xcodeproj \
      -scheme "${MC_IOS_SCHEME}" \
      -configuration Debug \
      -destination "$dest" \
      -resultBundlePath "$bundle" \
      -parallel-testing-enabled NO \
      "${tests[@]}"
  )
  code=$?
  mc_ios_release_xcode_lock
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="iOS test ${suite} PASS. xcresult=${bundle}"
    MC_NEXT_ACTION="Continue next iOS or cross-platform gate."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="iOS test ${suite} FAIL or BLOCKED by live/auth gate. xcresult=${bundle}"
  MC_NEXT_ACTION="Inspect xcresult; if sessionMissing, perform app-auth login and retry."
  return "$MC_EXIT_FAIL"
}

mc_ios_smoke() {
  local kind="$1"
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_CA_REFS="CA-113-29,CA-113-30"
  local dest code
  dest="$(mc_ios_destination)"
  mc_git_context "$MC_IOS_REPO"
  case "$kind" in
    simulator)
      mc_ios_acquire_xcode_lock || return $?
      (
        cd "$MC_IOS_REPO" || exit 3
        xcodebuild build -project iOSMerchandiseControl.xcodeproj \
          -scheme "${MC_IOS_SCHEME}" -configuration Debug -destination "$dest" build
        xcrun simctl bootstatus "$MC_IOS_SIMULATOR_NAME" -b 2>/dev/null || true
      )
      code=$?
      mc_ios_release_xcode_lock
      ;;
    options)
      if [[ -x "$MC_IOS_REPO/tools/sim_ui.sh" ]]; then
        (
          cd "$MC_IOS_REPO" || exit 3
          ./tools/sim_ui.sh launch
          ./tools/sim_ui.sh wait-for "Opzioni" 15
        )
        code=$?
        if [[ "$code" -ne 0 ]]; then
          mc_report_log "legacy sim_ui/JXA options smoke returned ${code}; evaluating XcodeBuildMCP fallback evidence."
          mc_ios_options_fallback && return "$MC_EXIT_PASS"
          code=$?
        fi
      else
        mc_report_log "tools/sim_ui.sh unavailable; evaluating XcodeBuildMCP fallback evidence."
        mc_ios_options_fallback && return "$MC_EXIT_PASS"
        code=$?
      fi
      ;;
    history)
      mc_ios_runtime_ui_counts || return $?
      if ! grep -q "HistorySessionDisplayFormatter.displayTitle" "$MC_IOS_REPO/iOSMerchandiseControl/HistoryView.swift"; then
        MC_SUMMARY="iOS smoke history FAIL: HistoryView is not using the TASK-114 display title formatter."
        MC_NEXT_ACTION="Wire HistoryView through HistorySessionDisplayFormatter and rerun history smoke."
        return "$MC_EXIT_FAIL"
      fi
      mc_set_pass_with_notes
      MC_SUMMARY="iOS smoke history PASS_WITH_NOTES: runtime app launched and HistoryView uses the UUID/technical-title display formatter; capture visual/XcodeBuildMCP evidence for strict UI proof."
      MC_NEXT_ACTION="Capture iOS History screenshot/accessibility evidence and run live runtime-parity."
      return "$MC_EXIT_PASS"
      ;;
    *)
      MC_SUMMARY="Unknown iOS smoke kind: ${kind}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="iOS smoke ${kind} PASS."
    MC_NEXT_ACTION="Continue smoke matrix."
    return "$MC_EXIT_PASS"
  fi
  if [[ "$kind" == "options" ]]; then
    MC_SUMMARY="iOS smoke options BLOCKED: legacy sim_ui AX wait did not reach Options."
    MC_NEXT_ACTION="Grant/verify macOS Accessibility for osascript or perform manual Options smoke."
    return "$MC_EXIT_BLOCKED"
  fi
  MC_SUMMARY="iOS smoke ${kind} FAIL/BLOCKED."
  MC_NEXT_ACTION="Boot simulator or inspect smoke log."
  return "$MC_EXIT_FAIL"
}

mc_ios_options_fallback() {
  local evidence screenshot_rel
  evidence="${MC_IOS_OPTIONS_FALLBACK_PATH:-$MC_IOS_REPO/$MC_EVIDENCE_DIR/ios-options-xcodebuildmcp-fallback.txt}"
  if [[ ! -f "$evidence" ]]; then
    MC_SUMMARY="iOS smoke options BLOCKED: legacy JXA/AX failed and no XcodeBuildMCP fallback evidence file was found."
    MC_NEXT_ACTION="Capture XcodeBuildMCP UI hierarchy/screenshot and write $(mc_relpath "$evidence"), or fix macOS Accessibility for sim_ui."
    return "$MC_EXIT_BLOCKED"
  fi
  if ! grep -qx 'screen=Opzioni' "$evidence" ||
     ! grep -qx 'automatic_sync_visible=true' "$evidence" ||
     ! grep -qx 'sync_badge=Attiva' "$evidence" ||
     ! grep -qx 'pending_local_changes=0' "$evidence" ||
     ! grep -qx 'manual_sync_cta_visible=false' "$evidence"; then
    MC_SUMMARY="iOS smoke options BLOCKED: XcodeBuildMCP fallback evidence is incomplete."
    MC_NEXT_ACTION="Refresh fallback evidence with Options screen, automatic sync active, pending local changes 0, and manual sync CTA absence."
    return "$MC_EXIT_BLOCKED"
  fi
  screenshot_rel="$(awk -F= '$1 == "screenshot" { print $2; exit }' "$evidence")"
  if [[ -n "$screenshot_rel" ]]; then
    MC_ARTIFACT_SCREENSHOT="$screenshot_rel"
  fi
  mc_report_log "XcodeBuildMCP fallback evidence accepted: $(mc_relpath "$evidence")"
  mc_set_pass_with_notes
  MC_SUMMARY="iOS smoke options PASS_WITH_NOTES: legacy JXA/AX smoke is tooling-blocked, while XcodeBuildMCP fallback evidence verifies Options reached, automatic sync active, pending local changes 0, and no public manual sync CTA visible."
  MC_NEXT_ACTION="Use the fallback artifact as functional Options evidence; repair JXA/Accessibility separately if strict automation is required."
  return "$MC_EXIT_PASS"
}

mc_ios_auth_preflight() {
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-113-07,CA-113-19,CA-113-30"
  mc_require_live || return $?
  local dest bundle code test_log derived_data xctestrun generated_xctestrun skipped
  dest="$(mc_ios_destination)"
  bundle="$(mc_ios_result_bundle auth-preflight)"
  test_log="$(mktemp /tmp/mc-agent-ios-auth-preflight.XXXXXX.log)"
  derived_data="/tmp/mc-agent-ios-auth-preflight-${MC_TIMESTAMP}-DerivedData"
  xctestrun="${derived_data}/Build/Products/task114-ios-auth-preflight.xctestrun"
  MC_ARTIFACT_XCRESULT="$bundle"
  mc_git_context "$MC_IOS_REPO"
  mc_ios_acquire_xcode_lock || return $?
  (
    cd "$MC_IOS_REPO" || exit 3
    xcodebuild build-for-testing -project iOSMerchandiseControl.xcodeproj \
        -scheme "${MC_IOS_SCHEME}" -configuration Debug \
        -destination "$dest" -derivedDataPath "$derived_data" \
        -parallel-testing-enabled NO \
        -only-testing:iOSMerchandiseControlTests/SupabaseConfigSecurityTests/testTask103IOSAuthPreflightWhenEnabled
  ) >"$test_log" 2>&1
  code=$?
  if [[ "$code" -eq 0 ]]; then
    generated_xctestrun="$(find "$derived_data/Build/Products" -name '*.xctestrun' 2>/dev/null | sort | head -1)"
    if [[ -z "$generated_xctestrun" ]]; then
      code=2
      printf '\nTASK114_IOS_AUTH_PREFLIGHT_XCTESTRUN_MISSING\n' >>"$test_log"
    else
      mkdir -p "$(dirname "$xctestrun")"
      cp "$generated_xctestrun" "$xctestrun"
      mc_ios_xctestrun_set_env "$xctestrun" "TASK112_IOS_AUTH_PREFLIGHT" "1" >>"$test_log" 2>&1
      mc_ios_xctestrun_set_env "$xctestrun" "TEST_RUNNER_TASK112_IOS_AUTH_PREFLIGHT" "1" >>"$test_log" 2>&1
      mc_ios_xctestrun_set_env "$xctestrun" "TASK112_LIVE_ACCEPTANCE" "1" >>"$test_log" 2>&1
      mc_ios_xctestrun_set_env "$xctestrun" "TEST_RUNNER_TASK112_LIVE_ACCEPTANCE" "1" >>"$test_log" 2>&1
      (
        cd "$MC_IOS_REPO" || exit 3
        xcodebuild test-without-building -xctestrun "$xctestrun" \
          -destination "$dest" -resultBundlePath "$bundle" \
          -only-testing:iOSMerchandiseControlTests/SupabaseConfigSecurityTests/testTask103IOSAuthPreflightWhenEnabled
      ) >>"$test_log" 2>&1
      code=$?
    fi
  fi
  mc_ios_release_xcode_lock
  skipped=0
  if grep -q "Test skipped" "$test_log"; then
    skipped=1
  fi
  mc_report_log "$(mc_redact_text "$(tail -n 80 "$test_log")")"
  rm -f "$test_log"
  rm -rf "$derived_data"
  if [[ "$code" -eq 0 && "$skipped" -eq 0 ]]; then
    MC_SUMMARY="iOS auth-preflight PASS. xcresult=${bundle}"
    MC_NEXT_ACTION="Run scoped live-write."
    return "$MC_EXIT_PASS"
  fi
  local fallback_json fallback_code
  fallback_json="$(mc_ios_simulator_auth_session_probe 2>/dev/null)"
  fallback_code=$?
  if [[ "$fallback_code" -eq 0 ]]; then
    MC_SYNC_JSON_RESULT="$fallback_json"
    mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
    MC_SUMMARY="iOS auth-preflight PASS via redacted runtime fallback. xcresult=${bundle}"
    MC_NEXT_ACTION="Run scoped live-write."
    return "$MC_EXIT_PASS"
  fi
  if [[ -n "$fallback_json" ]]; then
    MC_SYNC_JSON_RESULT="$fallback_json"
    mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  fi
  MC_SUMMARY="iOS auth-preflight BLOCKED/FAIL. xcresult=${bundle}"
  MC_NEXT_ACTION="Open app, complete login, verify session restore, then retry."
  return "$MC_EXIT_BLOCKED"
}

mc_ios_live_full_pull() {
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-03,CA-06,CA-10"
  mc_require_live || return $?
  local dest bundle before_json after_json code test_log store_path store_hash derived_data xctestrun generated_xctestrun detail_status
  dest="$(mc_ios_destination)"
  bundle="$(mc_ios_result_bundle live-full-pull)"
  test_log="$(mktemp /tmp/mc-agent-ios-live-full-pull.XXXXXX.log)"
  derived_data="/tmp/mc-agent-ios-live-full-pull-${MC_TIMESTAMP}-DerivedData"
  xctestrun="${derived_data}/Build/Products/task114-ios-live-full-pull.xctestrun"
  MC_ARTIFACT_XCRESULT="$bundle"
  mc_git_context "$MC_IOS_REPO"

  mc_sync_counts_ios "$MC_TASK_ID"
  before_json="$MC_SYNC_JSON_RESULT"
  store_path="$(mc_sync_ios_container | { read -r container && mc_sync_ios_store_path "$container"; } 2>/dev/null || true)"
  if [[ -z "$store_path" ]]; then
    MC_SUMMARY="iOS live-full-pull BLOCKED. App SwiftData store path is unavailable."
    MC_NEXT_ACTION="Install/launch the iOS app on the booted simulator, then retry ios live-full-pull."
    return "$MC_EXIT_BLOCKED"
  fi
  store_hash="$(printf '%s' "$store_path" | shasum -a 256 | awk '{print $1}')"

  mc_ios_acquire_xcode_lock || return $?
  (
    cd "$MC_IOS_REPO" || exit 3
    xcodebuild build-for-testing -project iOSMerchandiseControl.xcodeproj \
      -scheme "${MC_IOS_SCHEME}" -configuration Debug \
      -destination "$dest" -derivedDataPath "$derived_data" \
      -parallel-testing-enabled NO
  ) >"$test_log" 2>&1
  code=$?
  if [[ "$code" -eq 0 ]]; then
    generated_xctestrun="$(find "$derived_data/Build/Products" -name '*.xctestrun' 2>/dev/null | sort | head -1)"
    if [[ -z "$generated_xctestrun" ]]; then
      code=2
      printf '\nTASK114_IOS_FULL_PULL_XCTESTRUN_MISSING\n' >>"$test_log"
    else
      mkdir -p "$(dirname "$xctestrun")"
      cp "$generated_xctestrun" "$xctestrun"
      mc_ios_plist_set_or_add "$xctestrun" ":TestConfigurations:0:TestTargets:0:EnvironmentVariables:TASK114_IOS_FULL_PULL" "1" >>"$test_log" 2>&1
      mc_ios_plist_set_or_add "$xctestrun" ":TestConfigurations:0:TestTargets:0:EnvironmentVariables:TASK114_LIVE_ACCEPTANCE" "1" >>"$test_log" 2>&1
      (
        cd "$MC_IOS_REPO" || exit 3
        xcodebuild test-without-building -xctestrun "$xctestrun" \
          -destination "$dest" -resultBundlePath "$bundle" \
          -only-testing:iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests/test114IOSFullPullMaterializesRemoteLookupOnlyRowsInAppStore
      ) >>"$test_log" 2>&1
      code=$?
    fi
  fi
  mc_ios_release_xcode_lock
  mc_report_log "$(mc_redact_text "$(tail -n 80 "$test_log")")"

  mc_sync_counts_ios "$MC_TASK_ID"
  after_json="$MC_SYNC_JSON_RESULT"

  IOS_FULL_PULL_STARTED="${MC_TIMESTAMP_ISO:-$(mc_now_iso)}" \
  TASK_ID="$MC_TASK_ID" \
  BEFORE_JSON="$before_json" \
  AFTER_JSON="$after_json" \
  XCODE_EXIT="$code" \
  XCODE_LOG="$test_log" \
  STORE_HASH="$store_hash" \
  SOURCE="ios.live-full-pull" \
  python3 - > /tmp/mc-agent-ios-live-full-pull.$$.json <<'PY'
import json, os, re
from datetime import datetime, timezone

before = json.loads(os.environ["BEFORE_JSON"])
after = json.loads(os.environ["AFTER_JSON"])
code = int(os.environ["XCODE_EXIT"])
log_path = os.environ["XCODE_LOG"]
line = ""
skipped = False
try:
    with open(log_path, "r", encoding="utf-8", errors="replace") as fh:
        for candidate in fh:
            if "Test skipped" in candidate:
                skipped = True
            if "TASK114_IOS_FULL_PULL_LOOKUPS" in candidate:
                line = candidate.strip()
except OSError:
    pass

metrics = {}
for key, value in re.findall(r"([a-zA-Z_]+)=([^ ]+)", line):
    if key.endswith("hash"):
        continue
    try:
        metrics[key] = int(value)
    except ValueError:
        metrics[key] = value

before_counts = before.get("counts", {})
after_counts = after.get("counts", {})
supplier_delta = (after_counts.get("suppliers", {}).get("active") or 0) - (before_counts.get("suppliers", {}).get("active") or 0)
category_delta = (after_counts.get("categories", {}).get("active") or 0) - (before_counts.get("categories", {}).get("active") or 0)
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
remote_suppliers = metrics.get("remote_suppliers")
remote_categories = metrics.get("remote_categories")
remote_product_prices = metrics.get("price_total")
after_suppliers = after_counts.get("suppliers", {}).get("active")
after_categories = after_counts.get("categories", {}).get("active")
after_product_prices = after_counts.get("product_prices", {}).get("active")
counts_match = True
if isinstance(remote_suppliers, int):
    counts_match = counts_match and after_suppliers == remote_suppliers
if isinstance(remote_categories, int):
    counts_match = counts_match and after_categories == remote_categories
if isinstance(remote_product_prices, int):
    materialized_prices = metrics.get("after_prices")
    if isinstance(materialized_prices, int):
        counts_match = counts_match and materialized_prices <= remote_product_prices
status = "PASS" if code == 0 and after.get("status") == "PASS" and line and not skipped and counts_match else "FAIL"
payload = {
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "startedAt": os.environ["IOS_FULL_PULL_STARTED"],
    "completedAt": now,
    "source": os.environ["SOURCE"],
    "account": {"state": "redacted"},
    "session": {"state": "device-app-auth-redacted"},
    "store": {"pathHash": os.environ.get("STORE_HASH")},
    "counts": {"before": before_counts, "after": after_counts},
    "checkpoint": {"local": after.get("checkpoint"), "remote": "app-auth-full-pull"},
    "lastPush": None,
    "lastPull": now if status == "PASS" else None,
    "lastFullReconciliation": now if status == "PASS" else None,
    "inserted": metrics.get("products_inserted", 0),
    "updated": metrics.get("products_updated", 0),
    "deleted": 0,
    "pruned": {
        "wouldPrune": 0,
        "didPrune": metrics.get("product_pruned", 0) + metrics.get("price_pruned", 0),
        "skippedDirty": 0,
        "skippedLocalOnly": 0,
        "skippedPendingTombstone": 0,
        "skippedScopedSnapshot": 0,
        "isCompleteSnapshot": True
    },
    "lookupApply": {
        "suppliersInserted": metrics.get("suppliers_created", max(0, supplier_delta)),
        "categoriesInserted": metrics.get("categories_created", max(0, category_delta)),
        "supplierDelta": supplier_delta,
        "categoryDelta": category_delta,
        "plannedSuppliers": metrics.get("planned_suppliers"),
        "plannedCategories": metrics.get("planned_categories"),
        "skippedSuppliers": 0,
        "skippedCategories": 0
    },
    "productPriceApply": {
        "inserted": metrics.get("price_inserted", 0),
        "linked": metrics.get("price_linked", 0),
        "pruned": metrics.get("price_pruned", 0),
        "skipped": metrics.get("price_skipped", 0),
        "remoteTotal": remote_product_prices,
        "after": metrics.get("after_prices")
    },
    "skipped": 0,
    "drift": {},
    "samples": after.get("samples", {}),
    "status": status,
    "xcodeExit": code,
    "xcodeSkipped": skipped,
    "metricsLineFound": bool(line)
}
print(json.dumps(payload, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-ios-live-full-pull.$$.json)"
  detail_status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
  rm -f /tmp/mc-agent-ios-live-full-pull.$$.json "$test_log"
  rm -rf "$derived_data"
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"

  if [[ "$detail_status" == "PASS" ]]; then
    MC_SUMMARY="iOS live-full-pull PASS. xcresult=${bundle}"
    MC_NEXT_ACTION="Run sync counts ios and live reconcile-counts."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="iOS live-full-pull FAIL/BLOCKED. xcresult=${bundle}"
  MC_NEXT_ACTION="Inspect xcresult/log; verify app-auth session and persistent SwiftData store."
  return "$MC_EXIT_FAIL"
}

mc_ios_runtime_ui_counts() {
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="PR-01,PR-03,PR-04,PR-08"
  mc_require_live || return $?
  local derived_data app_path code wait_seconds container store status
  derived_data="$(mc_ios_runtime_derived_data runtime-ui-counts)"
  wait_seconds="${MC_IOS_RUNTIME_WAIT_SECONDS:-20}"
  if [[ "${MC_IOS_RUNTIME_REUSE_LAUNCHED:-0}" == "1" ]]; then
    wait_seconds="${MC_IOS_RUNTIME_REUSE_WAIT_SECONDS:-0}"
  elif [[ "${MC_IOS_RUNTIME_FOREGROUND_ONLY:-0}" == "1" ]]; then
    mc_ios_runtime_foreground_installed_app || {
      rm -rf "$derived_data"
      MC_SUMMARY="iOS runtime-ui-counts BLOCKED: installed runtime app could not be launched foreground."
      MC_NEXT_ACTION="Install/launch the app once, then retry the live gate."
      return "$MC_EXIT_BLOCKED"
    }
  else
    mc_git_context "$MC_IOS_REPO"
    mc_ios_acquire_xcode_lock || return $?
    app_path="$(mc_ios_build_app_for_runtime "$derived_data")"
    code=$?
    mc_ios_release_xcode_lock
    if [[ "$code" -ne 0 || -z "$app_path" ]]; then
      rm -rf "$derived_data"
      MC_SUMMARY="iOS runtime-ui-counts BLOCKED: Debug app build failed or app bundle was not found."
      MC_NEXT_ACTION="Inspect xcodebuild log, then rerun ios runtime-ui-counts --live."
      return "$MC_EXIT_BLOCKED"
    fi
    mc_ios_runtime_launch_app "$app_path" || {
      rm -rf "$derived_data"
      MC_SUMMARY="iOS runtime-ui-counts BLOCKED: install/launch failed for the simulator app."
      MC_NEXT_ACTION="Boot the configured simulator and retry; verify bundle id $(mc_ios_app_bundle_id)."
      return "$MC_EXIT_BLOCKED"
    }
  fi
  if [[ "$wait_seconds" != "0" && "$wait_seconds" != "0.0" ]]; then
    sleep "$wait_seconds"
  fi
  container="$(mc_sync_ios_container 2>/dev/null || true)"
  store="$(mc_sync_ios_store_path "$container" 2>/dev/null || true)"
  mc_ios_store_runtime_guard "$store" || {
    rm -rf "$derived_data"
    return $?
  }
  if [[ "${MC_IOS_RUNTIME_REUSE_LAUNCHED:-0}" == "1" ]]; then
    mc_ios_runtime_counts_payload "ios.runtime-store-counts" "$wait_seconds" "$container" "$store"
  else
    mc_ios_runtime_counts_payload "ios.runtime-ui-counts" "$wait_seconds" "$container" "$store"
  fi
  rm -rf "$derived_data"
  status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
  case "$status" in
    PASS)
      MC_SUMMARY="iOS runtime-ui-counts PASS: launched app, read runtime default.store, and captured counts/baseline metadata."
      MC_NEXT_ACTION="Compare with Supabase/Android and run iOS live smoke Options/History."
      return "$MC_EXIT_PASS"
      ;;
    BLOCKED)
      MC_SUMMARY="iOS runtime-ui-counts BLOCKED: launched app but count source was unavailable."
      MC_NEXT_ACTION="Inspect simulator app container and retry after app reaches foreground."
      return "$MC_EXIT_BLOCKED"
      ;;
    *)
      MC_SUMMARY="iOS runtime-ui-counts FAIL: store/container guard failed."
      MC_NEXT_ACTION="Fix harness/container selection before using iOS counts as runtime evidence."
      return "$MC_EXIT_FAIL"
      ;;
  esac
}

mc_ios_live_write() {
  local prefix="$1"
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-113-07,CA-113-19,CA-113-30"
  mc_validate_task_prefix "$prefix" || return $?
  mc_require_live || return $?
  MC_TEST_PREFIX="$prefix"
  local dest bundle code
  dest="$(mc_ios_destination)"
  bundle="$(mc_ios_result_bundle live-write)"
  MC_ARTIFACT_XCRESULT="$bundle"
  mc_git_context "$MC_IOS_REPO"
  mc_ios_acquire_xcode_lock || return $?
  (
    cd "$MC_IOS_REPO" || exit 3
    TASK114_LIVE_ACCEPTANCE=1 TASK114_RUN_PREFIX="$prefix" \
      xcodebuild test -project iOSMerchandiseControl.xcodeproj \
        -scheme "${MC_IOS_SCHEME}" -configuration Debug \
        -destination "$dest" -resultBundlePath "$bundle" \
        -parallel-testing-enabled NO \
        -only-testing:iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests/test02IOSWriteSmokeAndRemoteReadBack
  )
  code=$?
  mc_ios_release_xcode_lock
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="iOS live-write PASS for prefix ${prefix}. xcresult=${bundle}"
    MC_NEXT_ACTION="Run Android live-pull or cleanup scoped."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="iOS live-write FAIL/BLOCKED for prefix ${prefix}. xcresult=${bundle}"
  MC_NEXT_ACTION="Inspect auth/session, RLS and xcresult."
  return "$MC_EXIT_FAIL"
}

mc_ios_task114_matrix_step() {
  local method="$1"
  local prefix="$2"
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-114-06,T-06"
  mc_validate_task_prefix "$prefix" || return $?
  mc_require_live || return $?
  MC_TEST_PREFIX="$prefix"
  local dest bundle code test_log derived_data xctestrun generated_xctestrun skipped store_path
  dest="$(mc_ios_destination)"
  bundle="$(mc_ios_result_bundle "task114-${method}")"
  test_log="$(mktemp "/tmp/mc-agent-ios-task114-${method}.XXXXXX.log")"
  derived_data="/tmp/mc-agent-ios-task114-${method}-${MC_TIMESTAMP}-DerivedData"
  xctestrun="${derived_data}/Build/Products/task114-${method}.xctestrun"
  MC_ARTIFACT_XCRESULT="$bundle"
  mc_git_context "$MC_IOS_REPO"
  store_path="$(mc_sync_ios_container | { read -r container && mc_sync_ios_store_path "$container"; } 2>/dev/null || true)"
  if [[ -n "$store_path" ]]; then
    mc_ios_store_runtime_guard "$store_path" || return $?
  fi
  mc_ios_acquire_xcode_lock || return $?
  (
    cd "$MC_IOS_REPO" || exit 3
    xcodebuild build-for-testing -project iOSMerchandiseControl.xcodeproj \
        -scheme "${MC_IOS_SCHEME}" -configuration Debug \
        -destination "$dest" -derivedDataPath "$derived_data" \
        -parallel-testing-enabled NO \
        "-only-testing:iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests/${method}"
  ) >"$test_log" 2>&1
  code=$?
  if [[ "$code" -eq 0 ]]; then
    generated_xctestrun="$(find "$derived_data/Build/Products" -name '*.xctestrun' 2>/dev/null | sort | head -1)"
    if [[ -z "$generated_xctestrun" ]]; then
      code=2
      printf '\nTASK114_IOS_MATRIX_XCTESTRUN_MISSING method=%s\n' "$method" >>"$test_log"
    else
      mkdir -p "$(dirname "$xctestrun")"
      cp "$generated_xctestrun" "$xctestrun"
      mc_ios_xctestrun_set_env "$xctestrun" "TASK114_LIVE_ACCEPTANCE" "1" >>"$test_log" 2>&1
      mc_ios_xctestrun_set_env "$xctestrun" "TEST_RUNNER_TASK114_LIVE_ACCEPTANCE" "1" >>"$test_log" 2>&1
      mc_ios_xctestrun_set_env "$xctestrun" "TASK114_RUN_PREFIX" "$prefix" >>"$test_log" 2>&1
      mc_ios_xctestrun_set_env "$xctestrun" "TEST_RUNNER_TASK114_RUN_PREFIX" "$prefix" >>"$test_log" 2>&1
      if [[ "$prefix" == TASK115_* ]]; then
        mc_ios_xctestrun_set_env "$xctestrun" "TASK115_IOS_SIMULATOR_AUTH_FALLBACK" "1" >>"$test_log" 2>&1
        mc_ios_xctestrun_set_env "$xctestrun" "TEST_RUNNER_TASK115_IOS_SIMULATOR_AUTH_FALLBACK" "1" >>"$test_log" 2>&1
      fi
      (
        cd "$MC_IOS_REPO" || exit 3
        xcodebuild test-without-building -xctestrun "$xctestrun" \
          -destination "$dest" -resultBundlePath "$bundle" \
          "-only-testing:iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests/${method}"
      ) >>"$test_log" 2>&1
      code=$?
    fi
  fi
  mc_ios_release_xcode_lock
  skipped=0
  if grep -q "Test skipped" "$test_log"; then
    skipped=1
  fi
  mc_report_log "$(mc_redact_text "$(tail -n 80 "$test_log")")"
  rm -f "$test_log"
  rm -rf "$derived_data"
  if [[ "$code" -eq 0 && "$skipped" -eq 0 ]]; then
    MC_SUMMARY="iOS TASK-114 matrix step ${method} PASS for prefix ${prefix}. xcresult=${bundle}"
    MC_NEXT_ACTION="Continue TASK-114 live sync-matrix."
    return "$MC_EXIT_PASS"
  fi
  if [[ "$skipped" -eq 1 ]]; then
    MC_SUMMARY="iOS TASK-114 matrix step ${method} BLOCKED/SKIPPED for prefix ${prefix}. xcresult=${bundle}"
    MC_NEXT_ACTION="Inspect xctestrun environment injection for TASK114_LIVE_ACCEPTANCE/TASK114_RUN_PREFIX."
    return "$MC_EXIT_BLOCKED"
  fi
  MC_SUMMARY="iOS TASK-114 matrix step ${method} FAIL/BLOCKED for prefix ${prefix}. xcresult=${bundle}"
  MC_NEXT_ACTION="Inspect xcresult/log; verify app-auth session, RLS and scoped remote rows."
  return "$MC_EXIT_FAIL"
}

mc_ios_cleanup_scoped() {
  local prefix="$1"
  local dry="$2"
  MC_PLATFORM="ios"
  MC_SAFETY_LEVEL="cleanup-dry-run"
  MC_REQUIRES_CLEANUP="true"
  MC_CA_REFS="CA-113-08,CA-113-24,CA-113-30"
  mc_validate_task_prefix "$prefix" || return $?
  if [[ "$dry" != "1" ]]; then
    MC_SUMMARY="iOS cleanup-scoped refused: only --dry-run is supported; remote cleanup is Supabase-scoped."
    MC_NEXT_ACTION="Run supabase cleanup --dry-run for remote rows."
    return "$MC_EXIT_REFUSED"
  fi
  MC_TEST_PREFIX="$prefix"
  MC_SUMMARY="iOS cleanup-scoped dry-run PASS for prefix ${prefix}. No client delete executed."
  MC_NEXT_ACTION="Use supabase cleanup for backend scoped rows."
  return "$MC_EXIT_PASS"
}

mc_cmd_ios() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    build) mc_ios_build "${1:-debug}" ;;
    test) mc_ios_test "${1:-sync}" ;;
    smoke) mc_ios_smoke "${1:-simulator}" ;;
    runtime-ui-counts)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_ios_runtime_ui_counts
      ;;
    physical-runtime-counts)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_ios_physical_runtime_counts
      ;;
    physical-auth-store-diagnostics)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_ios_physical_auth_store_diagnostics
      ;;
    physical-smoke-options)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_ios_physical_smoke_options
      ;;
    physical-sync-loop-diagnostics)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_ios_physical_sync_loop_diagnostics
      ;;
    physical-sync-acceptance)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_ios_physical_sync_acceptance
      ;;
    auth-preflight)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_ios_auth_preflight
      ;;
    live-write)
      local prefix
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      mc_ios_live_write "$prefix"
      ;;
    live-full-pull)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_ios_live_full_pull
      ;;
    cleanup-scoped)
      local prefix dry=0
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      mc_parse_flag --dry-run "$@" && dry=1
      mc_ios_cleanup_scoped "$prefix" "$dry"
      ;;
    *)
      MC_SUMMARY="Unknown ios subcommand: ${sub}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}
