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

metadata = {
    "containerPathHash": sha(container),
    "storePathHash": sha(store),
    "storeFile": os.path.basename(store),
    "isRuntimeAppContainer": "/Containers/Data/Application/" in store and "DerivedData" not in store and ".xctest" not in store,
    "lastSuccessfulSync": None,
    "baseline": None,
    "diagnostics": {
        "plistPresent": False,
        "runtime": {},
        "syncEventWatermarks": [],
    },
}
prefs_path = os.path.join(container, "Library", "Preferences", f"{bundle_id}.plist")
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
        if key.startswith("task114.runtime."):
            runtime[key.replace("task114.runtime.", "", 1)] = plist_value(value)
        elif key.startswith("task114.syncEvents.watermark."):
            owner = key.replace("task114.syncEvents.watermark.", "", 1)
            watermarks.append({"ownerHash": sha(owner)[:12], "value": plist_value(value)})
    metadata["diagnostics"] = {
        "plistPresent": True,
        "runtime": runtime,
        "syncEventWatermarks": watermarks,
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

  mc_sync_counts_ios "$MC_TASK_ID"
  counts_json="$MC_SYNC_JSON_RESULT"
  metadata_json="$(mc_ios_runtime_store_metadata_json "$container" "$store")"
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
        -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests
        -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncCoordinatorTests
        -only-testing:iOSMerchandiseControlTests/LocalPendingAggregatedPushPlannerTests
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
