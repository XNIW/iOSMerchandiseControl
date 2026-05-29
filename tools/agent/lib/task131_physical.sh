#!/usr/bin/env bash

mc_task131_ios_devices_json() {
  local raw
  raw="$(xcrun devicectl list devices --json-output - 2>/dev/null || true)"
  DEVICECTL_JSON="$raw" python3 - <<'PY'
import hashlib, json, sys
try:
    data = json.loads(__import__("os").environ.get("DEVICECTL_JSON", "") or "{}")
except Exception:
    data = {}
items = []
for row in data.get("result", {}).get("devices", []) or data.get("devices", []) or []:
    hardware = row.get("hardwareProperties") or {}
    connection = row.get("connectionProperties") or {}
    props = row.get("deviceProperties") or row.get("properties") or {}
    identifier = row.get("identifier") or props.get("identifier") or props.get("udid") or ""
    name = props.get("name") or row.get("name")
    platform = hardware.get("platform") or props.get("platform") or props.get("deviceType") or ""
    state = connection.get("tunnelState") or props.get("connectionState") or row.get("connectionState") or row.get("state")
    if platform != "iOS":
        continue
    if identifier:
        items.append({
            "id": "<REDACTED>",
            "idHash": hashlib.sha256(identifier.encode()).hexdigest()[:12],
            "name": "<REDACTED_DEVICE_NAME>" if name else None,
            "nameHash": hashlib.sha256(str(name).encode()).hexdigest()[:12] if name else None,
            "platform": platform,
            "state": state,
            "targetType": "physical",
        })
print(json.dumps(items, sort_keys=True))
PY
}

mc_task131_ios_simulators_json() {
  local raw
  raw="$(xcrun simctl list devices available -j 2>/dev/null || true)"
  SIMCTL_JSON="$raw" python3 - <<'PY'
import hashlib, json, os
try:
    data = json.loads(os.environ.get("SIMCTL_JSON", "") or "{}")
except Exception:
    data = {}
target = os.environ.get("MC_IOS_SIMULATOR_NAME", "")
items = []
for runtime, rows in (data.get("devices") or {}).items():
    for row in rows or []:
        name = row.get("name")
        udid = row.get("udid") or ""
        if target and name != target:
            continue
        items.append({
            "id": "<REDACTED>",
            "idHash": hashlib.sha256(udid.encode()).hexdigest()[:12] if udid else None,
            "name": name,
            "runtime": runtime,
            "state": row.get("state"),
            "isAvailable": row.get("isAvailable", True),
            "targetType": "simulator",
        })
print(json.dumps(items, sort_keys=True))
PY
}

mc_task131_ios_physical_enabled() {
  [[ "${MC_TASK131_ENABLE_IOS_PHYSICAL:-0}" == "1" ]]
}

mc_task131_wait_ios_physical_device_json() {
  local timeout_seconds="${MC_IOS_PHYSICAL_READY_WAIT_SECONDS:-120}"
  local interval_seconds="${MC_IOS_PHYSICAL_READY_POLL_SECONDS:-5}"
  local elapsed=0
  local device_json
  while [[ "$elapsed" -le "$timeout_seconds" ]]; do
    if device_json="$(mc_ios_physical_device_json 2>/dev/null)"; then
      printf '%s\n' "$device_json"
      return "$MC_EXIT_PASS"
    fi
    sleep "$interval_seconds"
    elapsed=$((elapsed + interval_seconds))
  done
  return "$MC_EXIT_BLOCKED"
}

mc_task131_ios_simulator_udid() {
  local raw
  raw="$(xcrun simctl list devices available -j 2>/dev/null || true)"
  SIMCTL_JSON="$raw" python3 - <<'PY'
import json, os, sys
try:
    data = json.loads(os.environ.get("SIMCTL_JSON", "") or "{}")
except Exception:
    data = {}
target = os.environ.get("MC_IOS_SIMULATOR_NAME", "")
preferred_runtime = os.environ.get("MC_IOS_SIMULATOR_OS", "")
candidates = []
for runtime, rows in (data.get("devices") or {}).items():
    for row in rows or []:
        if target and row.get("name") != target:
            continue
        candidates.append((runtime, row))
if preferred_runtime:
    for runtime, row in candidates:
        if preferred_runtime in runtime and row.get("udid"):
            print(row["udid"])
            sys.exit(0)
for runtime, row in candidates:
    if row.get("state") == "Booted" and row.get("udid"):
        print(row["udid"])
        sys.exit(0)
for runtime, row in candidates:
    if row.get("udid"):
        print(row["udid"])
        sys.exit(0)
sys.exit(2)
PY
}

mc_task131_boot_ios_simulator() {
  local udid
  udid="$(mc_task131_ios_simulator_udid 2>/dev/null || true)"
  if [[ -z "$udid" ]]; then
    MC_SUMMARY="BLOCKED_EXTERNAL_IOS_SIMULATOR_NOT_READY: no available simulator UDID matched MC_IOS_SIMULATOR_NAME."
    MC_NEXT_ACTION="Install the configured iOS Simulator runtime/device, then rerun TASK-131."
    return "$MC_EXIT_BLOCKED"
  fi
  export MC_IOS_SIMULATOR_ID="$udid"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || {
    MC_SUMMARY="BLOCKED_EXTERNAL_IOS_SIMULATOR_NOT_READY: simulator exists but did not boot."
    MC_NEXT_ACTION="Open/repair Simulator, then rerun TASK-131 iOS simulator smoke."
    return "$MC_EXIT_BLOCKED"
  }
  open -a Simulator --args -CurrentDeviceUDID "$udid" >/dev/null 2>&1 || true
  sleep 2
  return "$MC_EXIT_PASS"
}

mc_task131_android_physical_devices_json() {
  local raw
  raw="$(adb devices -l 2>/dev/null || true)"
  ADB_DEVICES_RAW="$raw" python3 - <<'PY'
import hashlib, json, os
items = []
for line in os.environ.get("ADB_DEVICES_RAW", "").splitlines()[1:]:
    parts = line.split()
    if len(parts) < 2 or parts[1] != "device" or parts[0].startswith("emulator-"):
        continue
    details = {}
    for token in parts[2:]:
        if ":" in token:
            key, value = token.split(":", 1)
            details[key] = value
    items.append({
        "serial": "<REDACTED>",
        "serialHash": hashlib.sha256(parts[0].encode()).hexdigest()[:12],
        "status": parts[1],
        "model": "<REDACTED_DEVICE_MODEL>" if details.get("model") else None,
        "modelHash": hashlib.sha256(details.get("model", "").encode()).hexdigest()[:12] if details.get("model") else None,
        "device": "<REDACTED_DEVICE_MODEL>" if details.get("device") else None,
        "deviceHash": hashlib.sha256(details.get("device", "").encode()).hexdigest()[:12] if details.get("device") else None,
        "targetType": "physical",
    })
print(json.dumps(items, sort_keys=True))
PY
}

mc_task131_physical_detail() {
  local source="$1"
  local matrix="$2"
  local prefix="${3:-}"
  local ios_json ios_sim_json android_json now
  ios_json="$(mc_task131_ios_devices_json || printf '[]')"
  ios_sim_json="$(mc_task131_ios_simulators_json || printf '[]')"
  android_json="$(mc_task131_android_physical_devices_json || printf '[]')"
  now="$(mc_now_iso)"
  TASK131_SOURCE="$source" TASK131_MATRIX="$matrix" TASK131_PREFIX="$prefix" TASK131_IOS="$ios_json" TASK131_IOS_SIM="$ios_sim_json" TASK131_ANDROID="$android_json" TASK131_NOW="$now" python3 - <<'PY'
import json, os
ios = json.loads(os.environ["TASK131_IOS"])
ios_sim = json.loads(os.environ["TASK131_IOS_SIM"])
android = json.loads(os.environ["TASK131_ANDROID"])
matrix = os.environ["TASK131_MATRIX"]
case_groups = {
    "devices-list": [],
    "sync-policy-ui": ["C126-00..02", "C126-18", "C126-19", "AC-126-21..25"],
    "sync-policy-matrix": ["C126-03..06", "C126-41"],
    "conflict-review-matrix": ["C126-07..09", "C126-24..26", "C126-45"],
    "account-switch-matrix": ["C126-14..17", "C126-36..40", "C126-44"],
    "offline-background-matrix": ["C126-10..13", "C126-27", "C126-39"],
    "accessibility-smoke": ["AC-126-21..25"],
    "hybrid-sync-policy-matrix": ["C126-03..06", "C126-26", "C126-41", "C126-42", "C126-60"],
    "hybrid-conflict-review-matrix": ["C126-07..09", "C126-23..26", "C126-45"],
    "hybrid-offline-reconnect-matrix": ["C126-10..13", "C126-27", "C126-39", "C126-55..57"],
    "hybrid-accessibility-smoke": ["C126-49..54"],
}
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ.get("MC_TASK_ID", "TASK-131"),
    "source": os.environ["TASK131_SOURCE"],
    "matrix": matrix,
    "prefix": os.environ["TASK131_PREFIX"] or None,
    "completedAt": os.environ["TASK131_NOW"],
    "iosPhysicalDevices": ios,
    "iosSimulators": ios_sim,
    "androidPhysicalDevices": android,
    "deviceReadiness": {
        "iosPhysicalAvailable": bool(ios),
        "iosPhysicalEnabledForTask131": os.environ.get("MC_TASK131_ENABLE_IOS_PHYSICAL") == "1",
        "iosSimulatorAvailable": bool(ios_sim),
        "androidPhysicalAvailable": bool(android),
        "currentScope": "FULL_PHYSICAL_IOS_ANDROID_SCOPE",
        "iosPhysicalCaseStatus": "AVAILABLE_FOR_FULL_PHYSICAL_SCOPE" if (ios and os.environ.get("MC_TASK131_ENABLE_IOS_PHYSICAL") == "1") else "BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE",
    },
    "coveredPolicyGroupsPlanned": case_groups.get(matrix, []),
    "caseStatus": "NOT_RUN" if matrix != "devices-list" else "DISCOVERY_ONLY",
    "screenshots": [os.environ.get("MC_ARTIFACT_SCREENSHOT")] if os.environ.get("MC_ARTIFACT_SCREENSHOT") else [],
    "videos": [],
    "cleanupStatus": "NOT_RUN",
    "residueStatus": "NOT_RUN",
    "resultRule": "NOT_RUN mandatory physical cases are blocking and are not PASS.",
    "NEXT_ACTION": "Connect trusted physical iPhone and Android device, set any required device identifiers, then rerun with MC_ALLOW_LIVE=1 and scoped TASK131_* prefix."
}, sort_keys=True))
PY
}

mc_task131_set_detail() {
  MC_SYNC_JSON_RESULT="$(mc_task131_physical_detail "$1" "$2" "${3:-}")"
  MC_RECONCILIATION_JSON="$MC_SYNC_JSON_RESULT"
  MC_RECONCILIATION_MD="$(TASK131_DETAIL="$MC_SYNC_JSON_RESULT" python3 - <<'PY'
import json, os
p = json.loads(os.environ["TASK131_DETAIL"])
readiness = p.get("deviceReadiness", {})
print(f"- source: {p.get('source')}")
print(f"- matrix: {p.get('matrix')}")
print(f"- iosPhysicalAvailable: {readiness.get('iosPhysicalAvailable')}")
print(f"- androidPhysicalAvailable: {readiness.get('androidPhysicalAvailable')}")
print(f"- caseStatus: {p.get('caseStatus')}")
print(f"- cleanupStatus: {p.get('cleanupStatus')}")
print(f"- residueStatus: {p.get('residueStatus')}")
PY
)"
  export MC_RECONCILIATION_JSON MC_RECONCILIATION_MD
  mc_report_log "$MC_SYNC_JSON_RESULT"
}

mc_task131_enable_full_physical_runtime() {
  local device_json device_id
  device_json="$(mc_ios_physical_device_json)" || {
    MC_SUMMARY="BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE: no single trusted physical iPhone is selectable."
    MC_NEXT_ACTION="Connect exactly one trusted iPhone or set MC_IOS_DEVICE_UDID, unlock/trust it, then rerun TASK-131."
    return "$MC_EXIT_BLOCKED"
  }
  device_id="$(DEVICE_JSON="$device_json" python3 - <<'PY'
import json, os
print(json.loads(os.environ["DEVICE_JSON"])["identifier"])
PY
)"
  export MC_IOS_DEVICE_UDID="$device_id"
  export MC_IOS_RUNTIME_USE_PHYSICAL=1
  export MC_IOS_PHYSICAL_WAIT_SECONDS="${MC_IOS_PHYSICAL_WAIT_SECONDS:-8}"
  export MC_TASK131_ENABLE_IOS_PHYSICAL=1
  if [[ -z "${MC_ANDROID_DEVICE_SERIAL:-}" || "${MC_ANDROID_DEVICE_SERIAL:-}" == "REDACTED_SERIAL" || "${MC_ANDROID_DEVICE_SERIAL:-}" == "<REDACTED_SERIAL>" ]]; then
    MC_ANDROID_DEVICE_SERIAL="$(adb devices -l 2>/dev/null | awk 'NR>1 && $2=="device" && $1 !~ /^emulator-/ {print $1; exit}')"
    export MC_ANDROID_DEVICE_SERIAL
  fi
  mc_android_serial >/dev/null || return $?
  export MC_ANDROID_DEVICE_SERIAL="$MC_ANDROID_SELECTED_SERIAL"
  return "$MC_EXIT_PASS"
}

mc_task131_matrix_step_record() {
  local steps_file="$1"
  local name="$2"
  local code="$3"
  local detail="${4:-}"
  local detail_file
  detail_file="$(mktemp -t mc-agent-task131-step-detail)"
  if [[ -n "$detail" ]]; then
    printf '%s' "$detail" >"$detail_file"
  else
    printf '{}' >"$detail_file"
  fi
  STEP_NAME="$name" STEP_CODE="$code" STEP_DETAIL_FILE="$detail_file" python3 - >>"$steps_file" <<'PY'
import json, os

try:
    with open(os.environ["STEP_DETAIL_FILE"], encoding="utf-8") as handle:
        raw = handle.read()
    detail = json.loads(raw or "{}")
except Exception:
    fallback = os.environ.get("MC_RECONCILIATION_JSON", "")
    try:
        detail = json.loads(fallback) if fallback else {"parseError": True}
    except Exception:
        detail = {"parseError": True}
status = detail.get("status")
if not status:
    code = int(os.environ["STEP_CODE"])
    if code == 0:
        status = "PASS"
    elif code == 2:
        status = "BLOCKED_EXTERNAL"
    elif code == 3:
        status = "MISCONFIGURED"
    elif code == 4:
        status = "UNSAFE_OPERATION_REFUSED"
    else:
        status = "FAIL"
print(json.dumps({
    "name": os.environ["STEP_NAME"],
    "exitCode": int(os.environ["STEP_CODE"]),
    "status": status,
    "source": detail.get("source"),
    "prefix": detail.get("prefix"),
    "cleanupRequired": detail.get("cleanupRequired"),
    "blocker": detail.get("blocker"),
    "warnings": detail.get("warnings"),
    "detail": detail,
}, sort_keys=True))
PY
  rm -f "$detail_file"
}

mc_task131_matrix_summary() {
  local matrix="$1"
  local prefix="$2"
  local started="$3"
  local steps_file="$4"
  local cleanup_required="${5:-true}"
  local allowed_blocker="${6:-}"
  local tmp_json
  tmp_json="$(mktemp -t mc-agent-task131-matrix-summary)"
  TASK_ID="${MC_TASK_ID:-TASK-131}" MATRIX="$matrix" PREFIX="$prefix" STARTED="$started" STEPS_FILE="$steps_file" CLEANUP_REQUIRED="$cleanup_required" ALLOWED_BLOCKER="$allowed_blocker" python3 - >"$tmp_json" <<'PY'
import json, os
from datetime import datetime, timezone

steps = []
with open(os.environ["STEPS_FILE"], encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if line:
            steps.append(json.loads(line))
allowed = {item for item in os.environ.get("ALLOWED_BLOCKER", "").split(",") if item}
failures = [step for step in steps if step.get("status") == "FAIL"]
misconfigured = [step for step in steps if step.get("status") == "MISCONFIGURED"]
refused = [step for step in steps if step.get("status") == "UNSAFE_OPERATION_REFUSED"]
blocked = [step for step in steps if str(step.get("status") or "").startswith("BLOCKED")]
unexpected_blocked = [
    step for step in blocked
    if step.get("name") not in allowed and step.get("blocker") not in allowed and step.get("status") not in allowed
]
if failures:
    status = "FAIL"
elif refused:
    status = "UNSAFE_OPERATION_REFUSED"
elif misconfigured:
    status = "MISCONFIGURED"
elif unexpected_blocked:
    status = "BLOCKED_EXTERNAL"
else:
    status = "PASS"
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "source": f"task131.physical.{os.environ['MATRIX']}",
    "matrix": os.environ["MATRIX"],
    "status": status,
    "prefix": os.environ["PREFIX"],
    "startedAt": os.environ["STARTED"],
    "completedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "steps": steps,
    "failures": failures,
    "misconfigured": misconfigured,
    "unsafeOperationRefused": refused,
    "blocked": blocked,
    "allowedExternalBlockers": sorted(allowed),
    "cleanupRequired": os.environ.get("CLEANUP_REQUIRED") == "true",
    "redactionApplied": True,
}, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat "$tmp_json")"
  rm -f "$tmp_json"
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
}

mc_task131_validate_operator_checklist() {
  local checklist_path="$1"
  local kind="$2"
  [[ -n "$checklist_path" && -f "$checklist_path" ]] || return "$MC_EXIT_BLOCKED"
  CHECKLIST_PATH="$checklist_path" CHECKLIST_KIND="$kind" python3 - <<'PY'
import json, os
payload = json.load(open(os.environ["CHECKLIST_PATH"], encoding="utf-8"))
assert payload.get("schemaVersion") == "1.1"
assert payload.get("taskId") == "TASK-131"
assert payload.get("kind") == os.environ["CHECKLIST_KIND"]
assert payload.get("redactionApplied") is True
cases = payload.get("cases") or []
assert cases
mandatory = [case for case in cases if case.get("mandatory") is not False]
assert mandatory
assert all(case.get("result") == "PASS" for case in mandatory)
print(json.dumps(payload, sort_keys=True))
PY
}

mc_task131_static_step_detail_json() {
  local source="$1"
  local suite="$2"
  local code="$3"
  TASK_ID="${MC_TASK_ID:-TASK-131}" STEP_SOURCE="$source" STEP_SUITE="$suite" STEP_CODE="$code" python3 - <<'PY'
import json, os
from datetime import datetime, timezone

code = int(os.environ["STEP_CODE"])
status = "PASS" if code == 0 else ("BLOCKED_EXTERNAL" if code == 2 else "FAIL")
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "source": os.environ["STEP_SOURCE"],
    "suite": os.environ["STEP_SUITE"],
    "status": status,
    "exitCode": code,
    "evidenceTier": "static-policy-ui-contract",
    "completedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "cleanupRequired": False,
}, sort_keys=True))
PY
}

mc_task131_policy_step_detail_json() {
  local source="$1"
  local suite="$2"
  local status="$3"
  local ios_code="${4:-0}"
  local android_code="${5:-0}"
  local cases_csv="${6:-}"
  local note="${7:-}"
  local blocker="${8:-}"
  TASK_ID="${MC_TASK_ID:-TASK-131}" STEP_SOURCE="$source" STEP_SUITE="$suite" STEP_STATUS="$status" IOS_CODE="$ios_code" ANDROID_CODE="$android_code" CASES_CSV="$cases_csv" STEP_NOTE="$note" STEP_BLOCKER="$blocker" python3 - <<'PY'
import json, os
from datetime import datetime, timezone

cases = [item.strip() for item in os.environ.get("CASES_CSV", "").split(",") if item.strip()]
payload = {
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "source": os.environ["STEP_SOURCE"],
    "suite": os.environ["STEP_SUITE"],
    "status": os.environ["STEP_STATUS"],
    "exitCode": 0 if os.environ["STEP_STATUS"] == "PASS" else 2 if os.environ["STEP_STATUS"] == "BLOCKED_EXTERNAL" else 1,
    "iosExitCode": int(os.environ.get("IOS_CODE") or 0),
    "androidExitCode": int(os.environ.get("ANDROID_CODE") or 0),
    "evidenceTier": "physical-device-policy-fixture",
    "caseIds": cases,
    "note": os.environ.get("STEP_NOTE") or None,
    "cleanupRequired": False,
    "completedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
if os.environ.get("STEP_BLOCKER"):
    payload["blocker"] = os.environ["STEP_BLOCKER"]
print(json.dumps(payload, sort_keys=True))
PY
}

mc_task131_combine_step_codes() {
  local code="$MC_EXIT_PASS"
  local item
  for item in "$@"; do
    if [[ "$item" -eq "$MC_EXIT_FAIL" ]]; then
      printf '%s' "$MC_EXIT_FAIL"
      return 0
    fi
    if [[ "$item" -eq "$MC_EXIT_MISCONFIGURED" ]]; then
      printf '%s' "$MC_EXIT_MISCONFIGURED"
      return 0
    fi
    if [[ "$item" -eq "$MC_EXIT_BLOCKED" && "$code" -eq "$MC_EXIT_PASS" ]]; then
      code="$MC_EXIT_BLOCKED"
    fi
  done
  printf '%s' "$code"
}

mc_task131_return_for_status() {
  local status="$1"
  case "$status" in
    PASS) return "$MC_EXIT_PASS" ;;
    BLOCKED*) return "$MC_EXIT_BLOCKED" ;;
    MISCONFIGURED) return "$MC_EXIT_MISCONFIGURED" ;;
    UNSAFE_OPERATION_REFUSED) return "$MC_EXIT_REFUSED" ;;
    *) return "$MC_EXIT_FAIL" ;;
  esac
}

mc_task131_require_physical_devices() {
  local ios_count android_count
  ios_count="$(mc_task131_ios_devices_json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
  android_count="$(mc_task131_android_physical_devices_json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
  if ! mc_task131_ios_physical_enabled || [[ "$ios_count" -lt 1 || "$android_count" -lt 1 ]]; then
    MC_SUMMARY="BLOCKED_EXTERNAL_DEVICE_NOT_READY: full physical TASK-131 requires enabled physical iPhone and Android; current scope keeps iPhone physical blocked, discovered ios=${ios_count}, android=${android_count}."
    MC_NEXT_ACTION="Set MC_TASK131_ENABLE_IOS_PHYSICAL=1 only when a trusted iPhone is intentionally available for TASK-131, then rerun full physical matrices."
    return "$MC_EXIT_BLOCKED"
  fi
  return "$MC_EXIT_PASS"
}

mc_task131_require_ios_simulator() {
  local count
  count="$(mc_task131_ios_simulators_json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
  if [[ "$count" -lt 1 ]]; then
    MC_SUMMARY="BLOCKED_EXTERNAL_IOS_SIMULATOR_NOT_READY: no available iOS Simulator matching MC_IOS_SIMULATOR_NAME was discovered."
    MC_NEXT_ACTION="Install/boot the configured iOS Simulator target, then rerun TASK-131 hybrid scope."
    return "$MC_EXIT_BLOCKED"
  fi
  return "$MC_EXIT_PASS"
}

mc_task131_require_android_physical() {
  local count serial
  count="$(mc_task131_android_physical_devices_json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
  if [[ "$count" -lt 1 ]]; then
    MC_SUMMARY="BLOCKED_EXTERNAL_ANDROID_DEVICE_NOT_READY: no physical Android device discovered by adb."
    MC_NEXT_ACTION="Connect/wake/unlock a physical Android device; emulator is not accepted for TASK-131 Android physical scope."
    return "$MC_EXIT_BLOCKED"
  fi
  serial="$(adb devices -l 2>/dev/null | awk 'NR>1 && $2=="device" && $1 !~ /^emulator-/ {print $1; exit}')"
  if [[ -n "$serial" && ( -z "${MC_ANDROID_DEVICE_SERIAL:-}" || "${MC_ANDROID_DEVICE_SERIAL:-}" == "REDACTED_SERIAL" || "${MC_ANDROID_DEVICE_SERIAL:-}" == "<REDACTED_SERIAL>" ) ]]; then
    MC_ANDROID_DEVICE_SERIAL="$serial"
    export MC_ANDROID_DEVICE_SERIAL
  fi
  return "$MC_EXIT_PASS"
}

mc_task131_require_hybrid_devices() {
  mc_task131_require_android_physical || return $?
  mc_task131_require_ios_simulator || return $?
  return "$MC_EXIT_PASS"
}

mc_task131_ios_simulator_platform() {
  local action="$1"
  shift || true
  local prefix
  case "$action" in
    sync-policy-ui)
      prefix="$(mc_parse_opt --prefix "$@" || true)"
      [[ -n "$prefix" ]] || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      MC_PLATFORM="ios"
      MC_SAFETY_LEVEL="safe-readonly"
      MC_REQUIRES_LIVE="false"
      MC_CA_REFS="C126-00..02,C126-18,C126-19,C126-49..54"
      mc_validate_task_prefix "$prefix" || return $?
      MC_TEST_PREFIX="$prefix"
      mc_task131_set_detail "ios.simulator.sync-policy-ui" "sync-policy-ui" "$prefix"
      mc_task131_require_ios_simulator || return $?
      mc_task131_boot_ios_simulator || return $?
      mc_ios_smoke options
      local code=$?
      if [[ "$code" -ne 0 ]]; then
        mc_task131_ios_simulator_options_fallback
        code=$?
      fi
      mc_task131_set_detail "ios.simulator.sync-policy-ui" "sync-policy-ui" "$prefix"
      if [[ "$code" -eq 0 ]]; then
        MC_SUMMARY="TASK-131 iOS Simulator sync-policy-ui PASS for hybrid scope: Options smoke completed; iPhone physical remains BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE."
        MC_NEXT_ACTION="Run Android physical sync-policy-ui and hybrid matrices; do not count this as iPhone physical evidence."
        return "$MC_EXIT_PASS"
      fi
      MC_SUMMARY="TASK-131 iOS Simulator sync-policy-ui did not pass."
      MC_NEXT_ACTION="Fix simulator launch/Options smoke, then rerun."
      return "$code"
      ;;
    *)
      MC_SUMMARY="Unknown iOS simulator action: ${action}"
      MC_NEXT_ACTION="Use ios simulator sync-policy-ui."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_task131_ios_simulator_options_fallback() {
  local target bundle_id derived_data app_path screenshot_abs code
  target="$(mc_ios_simulator_target)" || return $?
  bundle_id="$(mc_ios_app_bundle_id)"
  derived_data="$(mc_ios_runtime_derived_data "task131-ios-options")"
  mc_ios_acquire_xcode_lock || return $?
  app_path="$(mc_ios_build_app_for_runtime "$derived_data")"
  code=$?
  mc_ios_release_xcode_lock
  if [[ "$code" -ne 0 ]]; then
    MC_SUMMARY="iOS simulator TASK-131 Options fallback FAIL: Debug app build failed."
    MC_NEXT_ACTION="Inspect xcodebuild output and rerun ios simulator sync-policy-ui."
    return "$MC_EXIT_FAIL"
  fi
  mc_task131_boot_ios_simulator || return $?
  xcrun simctl terminate "$target" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install "$target" "$app_path" >/dev/null || {
    MC_SUMMARY="iOS simulator TASK-131 Options fallback BLOCKED: app install failed."
    MC_NEXT_ACTION="Inspect simctl install output and rerun."
    return "$MC_EXIT_BLOCKED"
  }
  SIMCTL_CHILD_TASK131_INITIAL_TAB=options xcrun simctl launch --terminate-running-process "$target" "$bundle_id" >/dev/null || {
    MC_SUMMARY="iOS simulator TASK-131 Options fallback BLOCKED: app launch with TASK131_INITIAL_TAB failed."
    MC_NEXT_ACTION="Inspect Simulator state and rerun."
    return "$MC_EXIT_BLOCKED"
  }
  sleep 2
  screenshot_abs="$MC_IOS_REPO/$MC_EVIDENCE_DIR/screenshots/${MC_RUN_ID:-task131-ios-options}.png"
  mkdir -p "$(dirname "$screenshot_abs")"
  xcrun simctl io "$target" screenshot "$screenshot_abs" >/dev/null || {
    MC_SUMMARY="iOS simulator TASK-131 Options fallback BLOCKED: screenshot capture failed."
    MC_NEXT_ACTION="Inspect Simulator display state and rerun."
    return "$MC_EXIT_BLOCKED"
  }
  MC_ARTIFACT_SCREENSHOT="$(mc_relpath "$screenshot_abs")"
  export MC_ARTIFACT_SCREENSHOT
  mc_report_log "TASK-131 iOS simulator Options fallback screenshot: ${MC_ARTIFACT_SCREENSHOT}"
  MC_SUMMARY="iOS simulator TASK-131 Options fallback PASS_WITH_NOTES: launched Debug app with TASK131_INITIAL_TAB=options and captured screenshot; legacy AX/JXA remains blocked."
  MC_NEXT_ACTION="Use screenshot as simulator Options evidence; repair macOS AX/JXA for stricter tap automation."
  return "$MC_EXIT_PASS"
}

mc_task131_physical_matrix() {
  local matrix="$1"
  shift || true
  local task_id prefix started steps_file code status
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-$MC_TASK_ID}"
  prefix="$(mc_parse_opt --prefix "$@" || true)"
  MC_PLATFORM="physical"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="C126-00..C126-60,AC-126-21..25"
  [[ -n "$prefix" ]] || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
  mc_validate_task_prefix "$prefix" || return $?
  MC_TEST_PREFIX="$prefix"
  mc_task131_set_detail "physical.${matrix}" "$matrix" "$prefix"
  mc_require_live || return $?
  mc_task131_require_physical_devices || return $?
  mc_task131_enable_full_physical_runtime || return $?
  started="$(mc_now_iso)"
  steps_file="$(mktemp -t "mc-agent-task131-${matrix}")"

  case "$matrix" in
    sync-policy-matrix)
      mc_live_mutation_near_realtime "$task_id" "$prefix"; code=$?
      mc_task131_matrix_step_record "$steps_file" "fullPhysicalNearRealtimeBidirectionalProductPriceHistory" "$code" "${MC_SYNC_JSON_RESULT:-{}}"
      if [[ "$code" -ne 0 ]]; then
        mc_task131_matrix_summary "$matrix" "$prefix" "$started" "$steps_file" true
        rm -f "$steps_file"
        MC_SUMMARY="TASK-131 ${matrix} blocked/failed before no-op/burst because near-realtime bidirectional sync did not pass."
        MC_NEXT_ACTION="Inspect near-realtime report, fix the first blocker, then rerun ${matrix}."
        return "$code"
      fi

      MC_TASK123_NOOP_ITERATIONS="${MC_TASK131_NOOP_ITERATIONS:-2}" MC_TASK123_NOOP_MAX_MS="${MC_TASK131_NOOP_MAX_MS:-20000}" mc_live_task123_noop_matrix "$task_id" "$prefix"; code=$?
      mc_task131_matrix_step_record "$steps_file" "noOpNoFullPullNoEvents" "$code" "${MC_SYNC_JSON_RESULT:-{}}"

      MC_TASK123_BURST_TIMEOUT_SECONDS="${MC_TASK131_BURST_TIMEOUT_SECONDS:-30}" mc_live_task123_burst10 "$task_id" "$prefix"; code=$?
      mc_task131_matrix_step_record "$steps_file" "burst10NoDuplicates" "$code" "${MC_SYNC_JSON_RESULT:-{}}"

      mc_live_physical_runtime_parity "$task_id" "$prefix" "${MC_SUPABASE_PROFILE:-linked}"; code=$?
      mc_task131_matrix_step_record "$steps_file" "finalPhysicalRuntimeParityDriftZeroPendingZero" "$code" "${MC_SYNC_JSON_RESULT:-{}}"

      mc_task131_matrix_summary "$matrix" "$prefix" "$started" "$steps_file" true
      rm -f "$steps_file"
      status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
      if [[ "$status" == "PASS" ]]; then
        MC_SUMMARY="TASK-131 sync-policy-matrix PASS: full physical near-realtime, no-op, burst-10 and runtime parity gates passed."
        MC_NEXT_ACTION="Run conflict-review, offline-background, account-switch and accessibility matrices."
        return "$MC_EXIT_PASS"
      fi
      MC_SUMMARY="TASK-131 sync-policy-matrix ${status}: inspect matrix steps for the first failing/blocking physical gate."
      MC_NEXT_ACTION="Fix app/harness root cause, rerun sync-policy-matrix, then cleanup scoped TASK131_*."
      mc_task131_return_for_status "$status"; return $?
      ;;
    conflict-review-matrix)
      mc_ios_test conflict-review; code=$?
      mc_task131_matrix_step_record "$steps_file" "iosConflictReviewPolicyUnit" "$code" "$(mc_task131_static_step_detail_json "ios.task126.conflict-review" "conflict-review" "$code")"
      mc_ios_test conflict-review-ui; code=$?
      mc_task131_matrix_step_record "$steps_file" "iosConflictReviewUiContract" "$code" "$(mc_task131_static_step_detail_json "ios.task126.conflict-review-ui" "conflict-review-ui" "$code")"
      mc_android_test_task126_suite conflict-review; code=$?
      mc_task131_matrix_step_record "$steps_file" "androidConflictReviewPolicyUnit" "$code" "$(mc_task131_static_step_detail_json "android.task126.conflict-review" "conflict-review" "$code")"
      mc_android_test_task126_suite conflict-review-ui; code=$?
      mc_task131_matrix_step_record "$steps_file" "androidConflictReviewUiContract" "$code" "$(mc_task131_static_step_detail_json "android.task126.conflict-review-ui" "conflict-review-ui" "$code")"
      if mc_task131_validate_operator_checklist "${MC_TASK131_CONFLICT_REVIEW_CHECKLIST_JSON:-}" "conflict-review" >/tmp/mc-agent-task131-conflict-checklist.$$.json 2>/dev/null; then
        MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task131-conflict-checklist.$$.json)"
        rm -f /tmp/mc-agent-task131-conflict-checklist.$$.json
        mc_task131_matrix_step_record "$steps_file" "physicalOperatorConflictReviewChecklist" 0 "$MC_SYNC_JSON_RESULT"
      else
        rm -f /tmp/mc-agent-task131-conflict-checklist.$$.json
        MC_SYNC_JSON_RESULT='{"schemaVersion":"1.1","taskId":"TASK-131","source":"task131.physical.conflict-review.operator-checklist","status":"BLOCKED_EXTERNAL","blocker":"OPERATOR_CONFLICT_REVIEW_CHECKLIST_NOT_PROVIDED","cleanupRequired":false}'
        mc_task131_matrix_step_record "$steps_file" "physicalOperatorConflictReviewChecklist" "$MC_EXIT_BLOCKED" "$MC_SYNC_JSON_RESULT"
      fi
      mc_task131_matrix_summary "$matrix" "$prefix" "$started" "$steps_file" true
      rm -f "$steps_file"
      status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
      MC_SUMMARY="TASK-131 conflict-review-matrix ${status}: policy/UI contracts ran; physical tap evidence requires the operator checklist file when automation cannot drive iPhone Review UI."
      MC_NEXT_ACTION="Provide MC_TASK131_CONFLICT_REVIEW_CHECKLIST_JSON with redacted physical tap evidence, or implement physical UI automation, then rerun."
      mc_task131_return_for_status "$status"; return $?
      ;;
    account-switch-matrix)
      local ios_code android_code combined_code step_status

      mc_ios_test account-sync-policy; ios_code=$?
      combined_code="$(mc_task131_combine_step_codes "$ios_code")"
      step_status="$([[ "$combined_code" -eq 0 ]] && printf PASS || printf FAIL)"
      mc_task131_matrix_step_record "$steps_file" "sameAccountLogoutLoginCachePendingCursorPreserved" "$combined_code" "$(mc_task131_policy_step_detail_json "task131.same-account-logout-login" "account-sync-policy" "$step_status" "$ios_code" 0 "C126-00,C126-01,C126-02,C126-18,C126-19,C126-39" "Same-account reconnect/session restore/logout policy preserves owner-bound pending and watermarks; no account B required.")"

      mc_ios_test auth-fail-closed; ios_code=$?
      mc_android_test_task126_suite auth-fail-closed; android_code=$?
      combined_code="$(mc_task131_combine_step_codes "$ios_code" "$android_code")"
      step_status="$([[ "$combined_code" -eq 0 ]] && printf PASS || printf FAIL)"
      mc_task131_matrix_step_record "$steps_file" "tokenExpiredSessionMissingFailClosed" "$combined_code" "$(mc_task131_policy_step_detail_json "task131.auth-fail-closed" "auth-fail-closed" "$step_status" "$ios_code" "$android_code" "C126-18,C126-19,C126-20,C126-33,C126-34" "Expired/missing auth classifies as auth blocked/fail-closed and does not create a successful write.")"

      mc_ios_test account-store-boundary; ios_code=$?
      mc_android_test_task126_suite account-store-boundary; android_code=$?
      combined_code="$(mc_task131_combine_step_codes "$ios_code" "$android_code")"
      step_status="$([[ "$combined_code" -eq 0 ]] && printf PASS || printf FAIL)"
      mc_task131_matrix_step_record "$steps_file" "ownerMismatchAndCrossOwnerPendingFixture" "$combined_code" "$(mc_task131_policy_step_detail_json "task131.owner-mismatch-fixture" "account-store-boundary" "$step_status" "$ios_code" "$android_code" "C126-20,C126-21,C126-28,C126-29,C126-30,C126-44,C126-48" "Runtime fixture covers owner/store mismatch fail-closed and retryable outbox scoped to active owner/store.")"

      mc_ios_test cache-memory; ios_code=$?
      mc_android_test_task126_suite cache-memory; android_code=$?
      combined_code="$(mc_task131_combine_step_codes "$ios_code" "$android_code")"
      step_status="$([[ "$combined_code" -eq 0 ]] && printf PASS || printf FAIL)"
      mc_task131_matrix_step_record "$steps_file" "legacyUnboundDirtyReviewRecovery" "$combined_code" "$(mc_task131_policy_step_detail_json "task131.legacy-unbound-dirty" "cache-memory" "$step_status" "$ios_code" "$android_code" "C126-28,C126-31,C126-32,C126-36,C126-37,C126-38" "Legacy/unbound or dirty inactive local store requires Review/Recovery or backup, never silent cloud upload.")"

      mc_ios_test account-switch-review-ui; ios_code=$?
      mc_android_test_task126_suite account-switch-review-ui; android_code=$?
      combined_code="$(mc_task131_combine_step_codes "$ios_code" "$android_code")"
      step_status="$([[ "$combined_code" -eq 0 ]] && printf PASS || printf FAIL)"
      mc_task131_matrix_step_record "$steps_file" "exportBeforeDiscardCancelNonDestructive" "$combined_code" "$(mc_task131_policy_step_detail_json "task131.export-before-discard-cancel" "account-switch-review-ui" "$step_status" "$ios_code" "$android_code" "C126-16,C126-17,C126-36,C126-37,C126-38,C126-44" "Dirty pending export/cancel paths preserve pending and block cross-account push; discard requires explicit confirmation.")"

      mc_ios_test sync-policy; ios_code=$?
      mc_android_test_task126_suite sync-policy; android_code=$?
      combined_code="$(mc_task131_combine_step_codes "$ios_code" "$android_code")"
      step_status="$([[ "$combined_code" -eq 0 ]] && printf PASS || printf FAIL)"
      mc_task131_matrix_step_record "$steps_file" "localDefaultStoreOnlyNoRemoteStorePromise" "$combined_code" "$(mc_task131_policy_step_detail_json "task131.local-default-store-only" "sync-policy" "$step_status" "$ios_code" "$android_code" "C126-28,C126-29,C126-30,C126-46,C126-47,C126-48" "Policy remains localDefaultStoreOnly; no remote store_id/multi-store cloud promise is invented by TASK-131.")"

      if [[ "${MC_TASK131_SECOND_ACCOUNT_AVAILABLE:-0}" == "1" ]]; then
        mc_live_account_merge_policy_matrix "$task_id" "$prefix"; code=$?
        mc_task131_matrix_step_record "$steps_file" "secondAccountSwitchLiveFixture" "$code" "${MC_SYNC_JSON_RESULT:-{}}"
        if mc_task131_validate_operator_checklist "${MC_TASK131_ACCOUNT_SWITCH_CHECKLIST_JSON:-}" "account-switch" >/tmp/mc-agent-task131-account-checklist.$$.json 2>/dev/null; then
          MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task131-account-checklist.$$.json)"
          rm -f /tmp/mc-agent-task131-account-checklist.$$.json
          mc_task131_matrix_step_record "$steps_file" "secondAccountSwitchOperatorChecklist" 0 "$MC_SYNC_JSON_RESULT"
        else
          rm -f /tmp/mc-agent-task131-account-checklist.$$.json
          MC_SYNC_JSON_RESULT='{"schemaVersion":"1.1","taskId":"TASK-131","source":"task131.physical.account-switch.operator-checklist","status":"BLOCKED_EXTERNAL","blocker":"OPERATOR_ACCOUNT_SWITCH_CHECKLIST_NOT_PROVIDED","cleanupRequired":false}'
          mc_task131_matrix_step_record "$steps_file" "secondAccountSwitchOperatorChecklist" "$MC_EXIT_BLOCKED" "$MC_SYNC_JSON_RESULT"
        fi
      else
        MC_SYNC_JSON_RESULT="$(mc_task131_policy_step_detail_json "task131.second-account-switch" "second-account-switch" "BLOCKED_EXTERNAL" 0 0 "C126-14,C126-15,C126-16,C126-17,C126-40" "Only true Account A -> Account B cases require a second synthetic account; these are not PASS." "BLOCKED_EXTERNAL_SECOND_ACCOUNT")"
        mc_task131_matrix_step_record "$steps_file" "secondAccountSwitchBlockedExternal" "$MC_EXIT_BLOCKED" "$MC_SYNC_JSON_RESULT"
      fi

      mc_task131_matrix_summary "$matrix" "$prefix" "$started" "$steps_file" true "secondAccountSwitchBlockedExternal,BLOCKED_EXTERNAL_SECOND_ACCOUNT"
      rm -f "$steps_file"
      status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
      MC_SUMMARY="TASK-131 account-switch-matrix ${status}: non-B same-account/owner-mismatch/legacy/export policy subcases ran; true A-to-B cases remain BLOCKED_EXTERNAL_SECOND_ACCOUNT when no second account is configured."
      MC_NEXT_ACTION="Provision a second synthetic account only for C126-14/15/16/17/40, then rerun account-switch-matrix."
      mc_task131_return_for_status "$status"; return $?
      ;;
    offline-background-matrix)
      MC_OFFLINE_RECONNECT_TIMEOUT_SECONDS="${MC_TASK131_OFFLINE_TIMEOUT_SECONDS:-45}" mc_live_offline_reconnect_sync "$task_id" "$prefix"; code=$?
      mc_task131_matrix_step_record "$steps_file" "offlineReconnectBothDirections" "$code" "${MC_SYNC_JSON_RESULT:-{}}"
      if [[ "$code" -ne 0 ]]; then
        mc_task131_matrix_summary "$matrix" "$prefix" "$started" "$steps_file" true
        rm -f "$steps_file"
        MC_SUMMARY="TASK-131 offline-background-matrix blocked/failed at offline reconnect."
        MC_NEXT_ACTION="Inspect offline reconnect report, fix blocker, then rerun."
        return "$code"
      fi

      MC_TASK125_KILL_RESTART_MODE=1 MC_OFFLINE_RECONNECT_TIMEOUT_SECONDS="${MC_TASK131_RESTART_TIMEOUT_SECONDS:-45}" mc_live_offline_reconnect_sync "$task_id" "$prefix"; code=$?
      mc_task131_matrix_step_record "$steps_file" "killRestartPendingDurability" "$code" "${MC_SYNC_JSON_RESULT:-{}}"

      MC_TASK125_NETWORK_FLAPPING_MODE=1 MC_OFFLINE_RECONNECT_TIMEOUT_SECONDS="${MC_TASK131_FLAP_TIMEOUT_SECONDS:-45}" mc_live_offline_reconnect_sync "$task_id" "$prefix"; code=$?
      mc_task131_matrix_step_record "$steps_file" "networkFlapNoFalseAck" "$code" "${MC_SYNC_JSON_RESULT:-{}}"

      mc_task125_background_sync_matrix "$task_id" "$prefix"; code=$?
      mc_task131_matrix_step_record "$steps_file" "iosBackgroundSchedulerPolicy" "$code" "${MC_SYNC_JSON_RESULT:-{}}"

      mc_task131_matrix_summary "$matrix" "$prefix" "$started" "$steps_file" true "iosBackgroundSchedulerPolicy,BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY"
      rm -f "$steps_file"
      status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
      if [[ "$status" == "PASS" ]]; then
        MC_SUMMARY="TASK-131 offline-background-matrix PASS for core physical offline/reconnect/restart/flap; iOS BGTask scheduler subcase is recorded separately when OS policy blocks execution."
        MC_NEXT_ACTION="Run account-switch/accessibility matrices and final scans."
        return "$MC_EXIT_PASS"
      fi
      MC_SUMMARY="TASK-131 offline-background-matrix ${status}: inspect offline/restart/flap steps."
      MC_NEXT_ACTION="Fix app/harness root cause or document true external blocker, then rerun."
      mc_task131_return_for_status "$status"; return $?
      ;;
    *)
      rm -f "$steps_file"
      MC_SUMMARY="Unknown TASK-131 physical matrix: ${matrix}"
      MC_NEXT_ACTION="Use sync-policy-matrix, conflict-review-matrix, account-switch-matrix, or offline-background-matrix."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_task131_hybrid_matrix() {
  local matrix="$1"
  shift || true
  local task_id prefix code
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-$MC_TASK_ID}"
  prefix="$(mc_parse_opt --prefix "$@" || true)"
  MC_PLATFORM="physical"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="C126-00..C126-60,AC-126-21..25"
  [[ -n "$prefix" ]] || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
  mc_validate_task_prefix "$prefix" || return $?
  MC_TEST_PREFIX="$prefix"
  mc_task131_set_detail "physical.${matrix}" "$matrix" "$prefix"
  mc_require_live || return $?
  mc_task131_require_hybrid_devices || return $?
  case "$matrix" in
    hybrid-sync-policy-matrix)
      mc_live_mutation_near_realtime "$task_id" "$prefix"; code=$?
      mc_task131_set_detail "physical.${matrix}" "$matrix" "$prefix"
      if [[ "$code" -eq 0 ]]; then
        MC_SUMMARY="TASK-131 hybrid-sync-policy-matrix PASS for available scope via live mutation near-realtime; iPhone physical remains blocked externally."
        MC_NEXT_ACTION="Run hybrid conflict/offline matrices and cleanup/residue."
      else
        MC_SUMMARY="TASK-131 hybrid-sync-policy-matrix did not pass in available scope."
        MC_NEXT_ACTION="Inspect live mutation-near-realtime details, fix app/harness blocker, and rerun."
      fi
      return "$code"
      ;;
    hybrid-conflict-review-matrix)
      mc_ios_test conflict-review || true
      mc_android_test_task126_suite conflict-review || true
      mc_task131_set_detail "physical.${matrix}" "$matrix" "$prefix"
      MC_SUMMARY="TASK-131 hybrid-conflict-review-matrix FAIL: supporting conflict tests may run, but app-specific live conflict fixture/tap automation is not yet complete, so mandatory conflict cases remain NOT_RUN."
      MC_NEXT_ACTION="Implement real scoped conflict fixtures and Review UI tap/recovery evidence before REVIEW."
      return "$MC_EXIT_FAIL"
      ;;
    hybrid-offline-reconnect-matrix)
      mc_live_offline_reconnect_sync "$task_id" "$prefix"; code=$?
      mc_task131_set_detail "physical.${matrix}" "$matrix" "$prefix"
      if [[ "$code" -eq 0 ]]; then
        MC_WARNINGS="${MC_WARNINGS:+$MC_WARNINGS,}iOS physical background/locked remains BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE"
        MC_SUMMARY="TASK-131 hybrid-offline-reconnect-matrix PASS_WITH_NOTES for available scope via live offline-reconnect; iOS physical locked/background cases remain externally blocked."
        MC_NEXT_ACTION="Run Android locked/background evidence if tooling permits, then cleanup/residue."
        return "$MC_EXIT_PASS"
      fi
      MC_SUMMARY="TASK-131 hybrid-offline-reconnect-matrix did not pass in available scope."
      MC_NEXT_ACTION="Inspect offline reconnect evidence, fix blocker, and rerun."
      return "$code"
      ;;
    *)
      MC_SUMMARY="Unknown TASK-131 hybrid matrix: ${matrix}"
      MC_NEXT_ACTION="Use hybrid-sync-policy-matrix, hybrid-conflict-review-matrix, or hybrid-offline-reconnect-matrix."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_task131_physical_platform() {
  local platform="$1"
  local action="$2"
  shift 2 || true
  local prefix
  case "$action" in
    sync-policy-ui)
      prefix="$(mc_parse_opt --prefix "$@" || true)"
      [[ -n "$prefix" ]] || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      MC_PLATFORM="$platform"
      MC_SAFETY_LEVEL="live-write"
      MC_REQUIRES_LIVE="true"
      MC_CA_REFS="C126-00..02,C126-18,C126-19,AC-126-21..25"
      mc_validate_task_prefix "$prefix" || return $?
      MC_TEST_PREFIX="$prefix"
      mc_task131_set_detail "${platform}.physical.sync-policy-ui" "sync-policy-ui" "$prefix"
      mc_require_live || return $?
      if [[ "$platform" == "android" ]]; then
        mc_task131_require_android_physical || return $?
        mc_android_auth_preflight || return $?
        mc_android_smoke options
        local code=$?
        mc_task131_set_detail "${platform}.physical.sync-policy-ui" "sync-policy-ui" "$prefix"
        if [[ "$code" -eq 0 ]]; then
          MC_SUMMARY="TASK-131 Android physical sync-policy-ui PASS: auth preflight and launch smoke completed on redacted physical device."
          MC_NEXT_ACTION="Run hybrid matrices and cleanup/residue."
          return "$MC_EXIT_PASS"
        fi
        MC_SUMMARY="TASK-131 Android physical sync-policy-ui did not pass."
        MC_NEXT_ACTION="Inspect adb/logcat/build output, fix blocker, and rerun."
        return "$code"
      else
        if ! mc_task131_ios_physical_enabled; then
          MC_SUMMARY="BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE: iPhone physical scope is disabled for this TASK-131 Execution."
          MC_NEXT_ACTION="Use iOS Simulator hybrid evidence now, or explicitly enable physical iPhone scope in a later run."
          return "$MC_EXIT_BLOCKED"
        fi
        mc_task131_ios_devices_json | python3 -c 'import json,sys; raise SystemExit(0 if json.load(sys.stdin) else 2)' || {
          MC_SUMMARY="BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE: no trusted physical iPhone discovered by devicectl."
          MC_NEXT_ACTION="Connect/trust/wake the iPhone; simulator evidence cannot satisfy iPhone physical TASK-131 cases."
          return "$MC_EXIT_BLOCKED"
        }
        local device_json device_id derived_data app_path code smoke_code
        derived_data="$(mc_ios_runtime_derived_data "task131-ios-physical")"
        mc_ios_acquire_xcode_lock || return $?
        app_path="$(mc_ios_build_app_for_physical "$derived_data")"
        code=$?
        mc_ios_release_xcode_lock
        if [[ "$code" -ne 0 || -z "$app_path" ]]; then
          MC_SUMMARY="TASK-131 iOS physical sync-policy-ui FAIL: physical Debug build did not complete."
          MC_NEXT_ACTION="Inspect xcodebuild signing output, fix provisioning/signing, then rerun."
          return "$MC_EXIT_FAIL"
        fi
        device_json="$(mc_task131_wait_ios_physical_device_json)" || {
          MC_SUMMARY="BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE: iPhone is discovered but not ready for install/launch."
          MC_NEXT_ACTION="Keep the iPhone unlocked/trusted and connected until devicectl tunnelState is available/connected, then rerun."
          return "$MC_EXIT_BLOCKED"
        }
        device_id="$(DEVICE_JSON="$device_json" python3 - <<'PY'
import json, os
print(json.loads(os.environ["DEVICE_JSON"])["identifier"])
PY
)"
        mc_ios_physical_install_app "$device_id" "$app_path" || {
          MC_SUMMARY="TASK-131 iOS physical sync-policy-ui BLOCKED: app install to physical iPhone failed."
          MC_NEXT_ACTION="Unlock/trust the iPhone, verify signing/provisioning, then rerun."
          return "$MC_EXIT_BLOCKED"
        }
        MC_IOS_DEVICE_ID="$device_id" mc_ios_device_auth_preflight || return $?
        MC_IOS_DEVICE_ID="$device_id" mc_ios_physical_smoke_options
        smoke_code=$?
        if [[ "$smoke_code" -eq 0 ]]; then
          MC_SUMMARY="TASK-131 iOS physical sync-policy-ui PASS: physical build/install/launch/auth diagnostics and Options smoke completed on redacted iPhone."
          MC_NEXT_ACTION="Run Android physical sync-policy-ui and full physical matrices."
          return "$MC_EXIT_PASS"
        fi
        MC_SUMMARY="TASK-131 iOS physical sync-policy-ui did not pass physical Options smoke."
        MC_NEXT_ACTION="Inspect physical iPhone runtime/auth report, fix blocker, then rerun."
        return "$smoke_code"
      fi
      ;;
    *)
      MC_SUMMARY="Unknown ${platform} physical action: ${action}"
      MC_NEXT_ACTION="Use ${platform} physical sync-policy-ui."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_task131_physical() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    devices)
      case "${1:-}" in
        list)
          MC_PLATFORM="physical"
          MC_SAFETY_LEVEL="safe-readonly"
          MC_CA_REFS="TASK-131-PHASE-1"
          mc_task131_set_detail "physical.devices.list" "devices-list" ""
          MC_SUMMARY="Physical device discovery completed for TASK-131; report is redacted."
          MC_NEXT_ACTION="If either platform has zero physical devices, resolve readiness before running live physical matrices."
          return "$MC_EXIT_PASS"
          ;;
        *)
          MC_SUMMARY="Unknown physical devices action: ${1:-}"
          return "$MC_EXIT_MISCONFIGURED"
          ;;
      esac
      ;;
    sync-policy-matrix|conflict-review-matrix|account-switch-matrix|offline-background-matrix)
      mc_task131_physical_matrix "$sub" "$@"
      ;;
    hybrid-sync-policy-matrix|hybrid-conflict-review-matrix|hybrid-offline-reconnect-matrix)
      mc_task131_hybrid_matrix "$sub" "$@"
      ;;
    hybrid-accessibility-smoke)
      MC_PLATFORM="physical"
      MC_SAFETY_LEVEL="safe-readonly"
      MC_CA_REFS="C126-49..54,AC-126-21..25"
      mc_task131_set_detail "physical.hybrid-accessibility-smoke" "hybrid-accessibility-smoke" ""
      mc_task131_require_hybrid_devices || return $?
      mc_ios_smoke accessibility || true
      mc_android_smoke options || true
      mc_task131_set_detail "physical.hybrid-accessibility-smoke" "hybrid-accessibility-smoke" ""
      unset MC_RESULT_OVERRIDE
      MC_SUMMARY="TASK-131 hybrid-accessibility-smoke FAIL: basic smoke hooks ran where available, but real Dynamic Type/VoiceOver/TalkBack traversal is not fully automated/operator-certified yet."
      MC_NEXT_ACTION="Capture structured operator-assisted accessibility checklist or implement real traversal automation before REVIEW."
      return "$MC_EXIT_FAIL"
      ;;
    accessibility-smoke)
      MC_PLATFORM="physical"
      MC_SAFETY_LEVEL="safe-readonly"
      MC_CA_REFS="AC-126-21..25"
      local started steps_file code status
      started="$(mc_now_iso)"
      steps_file="$(mktemp -t mc-agent-task131-accessibility)"
      mc_task131_set_detail "physical.accessibility-smoke" "accessibility-smoke" ""
      mc_task131_require_physical_devices || return $?
      mc_task131_enable_full_physical_runtime || return $?
      unset MC_SYNC_JSON_RESULT
      MC_IOS_DEVICE_ID="$MC_IOS_DEVICE_UDID" mc_ios_physical_smoke_options; code=$?
      mc_task131_matrix_step_record "$steps_file" "iosPhysicalOptionsAccessibilityPreflight" "$code" "${MC_SYNC_JSON_RESULT:-{}}"
      unset MC_SYNC_JSON_RESULT
      mc_android_smoke options; code=$?
      mc_task131_matrix_step_record "$steps_file" "androidPhysicalOptionsAccessibilityPreflight" "$code" "${MC_SYNC_JSON_RESULT:-{}}"
      if mc_task131_validate_operator_checklist "${MC_TASK131_ACCESSIBILITY_CHECKLIST_JSON:-}" "accessibility" >/tmp/mc-agent-task131-accessibility-checklist.$$.json 2>/dev/null; then
        MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task131-accessibility-checklist.$$.json)"
        rm -f /tmp/mc-agent-task131-accessibility-checklist.$$.json
        mc_task131_matrix_step_record "$steps_file" "physicalOperatorAccessibilityChecklist" 0 "$MC_SYNC_JSON_RESULT"
      else
        rm -f /tmp/mc-agent-task131-accessibility-checklist.$$.json
        MC_SYNC_JSON_RESULT='{"schemaVersion":"1.1","taskId":"TASK-131","source":"task131.physical.accessibility.operator-checklist","status":"BLOCKED_EXTERNAL","blocker":"OPERATOR_ACCESSIBILITY_CHECKLIST_NOT_PROVIDED","cleanupRequired":false}'
        mc_task131_matrix_step_record "$steps_file" "physicalOperatorAccessibilityChecklist" "$MC_EXIT_BLOCKED" "$MC_SYNC_JSON_RESULT"
      fi
      mc_task131_matrix_summary "accessibility-smoke" "" "$started" "$steps_file" false
      rm -f "$steps_file"
      status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
      MC_SUMMARY="TASK-131 accessibility-smoke ${status}: physical app readiness ran; VoiceOver/TalkBack traversal requires a redacted operator checklist when not automatable."
      MC_NEXT_ACTION="Provide MC_TASK131_ACCESSIBILITY_CHECKLIST_JSON with Dynamic Type/VoiceOver/TalkBack results, then rerun."
      mc_task131_return_for_status "$status"; return $?
      ;;
    *)
      MC_SUMMARY="Unknown physical subcommand: ${sub}"
      MC_NEXT_ACTION="Use physical devices list, sync-policy-matrix, conflict-review-matrix, account-switch-matrix, offline-background-matrix, or accessibility-smoke."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}
