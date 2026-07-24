#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$REPO_ROOT/iOSMerchandiseControl.xcodeproj"
SCHEME="iOSMerchandiseControl"
TEMP_ROOT="${TMPDIR:-$(getconf DARWIN_USER_TEMP_DIR)}"
DERIVED_DATA="$(mktemp -d "${TEMP_ROOT%/}/task139-atomic-crash.XXXXXX")"
SIMULATOR_UDID=""

cleanup() {
  local status=$?
  set +e
  if [[ -n "$SIMULATOR_UDID" ]]; then
    xcrun simctl shutdown "$SIMULATOR_UDID" >/dev/null 2>&1
    xcrun simctl delete "$SIMULATOR_UDID" >/dev/null 2>&1
  fi
  case "$DERIVED_DATA" in
    "${TEMP_ROOT%/}"/task139-atomic-crash.*) /bin/rm -rf -- "$DERIVED_DATA" ;;
  esac
  exit "$status"
}
trap cleanup EXIT INT TERM

for command_name in xcrun xcodebuild jq uuidgen; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "BLOCKED missing_command=$command_name" >&2
    exit 2
  }
done

RUNTIME_ID="$({
  xcrun simctl list runtimes -j
} | jq -r '
  .runtimes
  | map(select(.isAvailable == true and (.name | startswith("iOS"))))
  | sort_by(.version | split(".") | map(tonumber))
  | last
  | .identifier // empty
')"
DEVICE_TYPE_ID="$({
  xcrun simctl list devicetypes -j
} | jq -r '.devicetypes[] | select(.name == "iPhone 17") | .identifier' | head -1)"
if [[ -z "$RUNTIME_ID" || -z "$DEVICE_TYPE_ID" ]]; then
  echo "BLOCKED simulator_runtime_or_device_type_unavailable" >&2
  exit 2
fi

SIMULATOR_NAME="TASK-139 Atomic Crash $(uuidgen)"
SIMULATOR_UDID="$(xcrun simctl create "$SIMULATOR_NAME" "$DEVICE_TYPE_ID" "$RUNTIME_ID")"
if [[ ! "$SIMULATOR_UDID" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
  echo "BLOCKED invalid_created_simulator_identifier" >&2
  exit 2
fi
xcrun simctl boot "$SIMULATOR_UDID" >&2
xcrun simctl bootstatus "$SIMULATOR_UDID" -b >&2

xcodebuild -quiet \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  -jobs 2 \
  ONLY_ACTIVE_ARCH=YES \
  build >&2

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/iOSMerchandiseControl.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "FAIL app_bundle_missing" >&2
  exit 1
fi
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
if [[ -z "$BUNDLE_ID" ]]; then
  echo "FAIL bundle_identifier_missing" >&2
  exit 1
fi
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH" >&2
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
HARNESS_ROOT="$DATA_CONTAINER/Library/Application Support/Task139AtomicGenerationCrashHarness"

wait_for_path() {
  local wanted="$1"
  local failure="$2"
  local index
  for index in $(seq 1 300); do
    if [[ -f "$wanted" ]]; then
      return 0
    fi
    if [[ -f "$failure" ]]; then
      jq . "$failure" >&2 || true
      return 1
    fi
    sleep 0.1
  done
  echo "FAIL timeout_waiting_for=$wanted" >&2
  return 1
}

launch_mode() {
  local mode="$1"
  local output
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  output="$(SIMCTL_CHILD_TASK139_ATOMIC_CRASH_MODE="$mode" \
    xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID")"
  local pid="${output##*: }"
  if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
    echo "FAIL invalid_launch_pid mode=$mode output=$output" >&2
    return 1
  fi
  printf '%s\n' "$pid"
}

run_scenario() {
  local scenario="$1"
  local scenario_root="$HARNESS_ROOT/$scenario"
  local failure_seed="$HARNESS_ROOT/failure-seed-$scenario.json"
  local failure_crash="$HARNESS_ROOT/failure-crash-$scenario.json"
  local failure_verify="$HARNESS_ROOT/failure-verify-$scenario.json"

  local seed_pid
  seed_pid="$(launch_mode "seed-$scenario")"
  wait_for_path "$scenario_root/seed-result.json" "$failure_seed"
  jq -e '.passed == true and .storeBytes > 0 and .ledgerBytes > 0' \
    "$scenario_root/seed-result.json" >/dev/null
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1

  local crash_pid
  crash_pid="$(launch_mode "crash-$scenario")"
  wait_for_path "$scenario_root/boundary-marker.json" \
    "$scenario_root/boundary-marker-error.json"
  local marker="$scenario_root/boundary-marker.json"
  local expected_boundary="$scenario"
  if [[ "$scenario" == "pre" ]]; then
    expected_boundary="before"
  else
    expected_boundary="after"
  fi
  jq -e \
    --argjson pid "$crash_pid" \
    --arg boundary "$expected_boundary" \
    '.pid == $pid
      and .boundary == $boundary
      and .storeBytes > 0
      and .walBytes > 0
      and .ledgerBytes > 0
      and (if $boundary == "before"
           then .manifestGenerationID == .oldGenerationID
           else .manifestGenerationID == .candidateGenerationID
           end)' "$marker" >/dev/null

  # This is the destructive step under test. It targets only the PID emitted
  # by the just-created isolated Simulator and never the authenticated device.
  xcrun simctl spawn "$SIMULATOR_UDID" kill -9 "$crash_pid" >/dev/null 2>&1
  local index
  for index in $(seq 1 100); do
    if ! xcrun simctl spawn "$SIMULATOR_UDID" kill -0 "$crash_pid" \
      >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
  if xcrun simctl spawn "$SIMULATOR_UDID" kill -0 "$crash_pid" \
    >/dev/null 2>&1; then
    echo "FAIL sigkill_did_not_terminate scenario=$scenario pid=$crash_pid" >&2
    return 1
  fi

  local verify_pid
  verify_pid="$(launch_mode "verify-$scenario")"
  wait_for_path "$scenario_root/verify-result.json" "$failure_verify"
  jq -e \
    --arg expected_supplier "TASK139-G$([[ "$scenario" == "pre" ]] && echo 1 || echo 2)" \
    '.passed == true
      and .activeGenerationID == .expectedGenerationID
      and .supplierNames == [$expected_supplier]
      and .storeBytes > 0
      and .ledgerBytes > 0' "$scenario_root/verify-result.json" >/dev/null
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1

  jq -n \
    --arg scenario "$scenario" \
    --slurpfile marker "$marker" \
    --slurpfile result "$scenario_root/verify-result.json" \
    '{scenario:$scenario, marker:$marker[0], verification:$result[0]}'
}

PRE_RESULT="$(run_scenario pre)"
POST_RESULT="$(run_scenario post)"
jq -n \
  --argjson pre "$PRE_RESULT" \
  --argjson post "$POST_RESULT" \
  '{
    gate:"TASK139_ATOMIC_GENERATION_SIGKILL",
    executed:2,
    passed:2,
    failed:0,
    skipped:0,
    scenarios:[$pre,$post],
    authenticatedSimulatorTouched:false,
    networkCalls:0
  }'
