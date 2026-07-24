#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$REPO_ROOT/iOSMerchandiseControl.xcodeproj"
SCHEME="iOSMerchandiseControl"
TEMP_ROOT="${TMPDIR:-$(getconf DARWIN_USER_TEMP_DIR)}"
DERIVED_DATA="$(mktemp -d "${TEMP_ROOT%/}/task139-prebound-runtime.XXXXXX")"
SIMULATOR_UDID=""

cleanup() {
  local status=$?
  set +e
  if [[ -n "$SIMULATOR_UDID" ]]; then
    xcrun simctl shutdown "$SIMULATOR_UDID" >/dev/null 2>&1
    xcrun simctl delete "$SIMULATOR_UDID" >/dev/null 2>&1
  fi
  case "$DERIVED_DATA" in
    "${TEMP_ROOT%/}"/task139-prebound-runtime.*) /bin/rm -rf -- "$DERIVED_DATA" ;;
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

SIMULATOR_NAME="TASK-139 Prebound Runtime $(uuidgen)"
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
HARNESS_ROOT="$DATA_CONTAINER/Library/Application Support/Task139PreboundResourceRuntimeHarness"

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
  output="$(SIMCTL_CHILD_TASK139_PREBOUND_RUNTIME_MODE="$mode" \
    xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID")"
  local pid="${output##*: }"
  if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
    echo "FAIL invalid_launch_pid mode=$mode output=$output" >&2
    return 1
  fi
  printf '%s\n' "$pid"
}

PREPARE_PID="$(launch_mode prepare)"
wait_for_path "$HARNESS_ROOT/prepare-result.json" "$HARNESS_ROOT/failure-prepare.json"
jq -e \
  --argjson pid "$PREPARE_PID" \
  '.passed == true
    and .pid == $pid
    and .oldCacheReadable == true
    and .watermarkA == 41
    and .pendingMarkerReadable == true' \
  "$HARNESS_ROOT/prepare-result.json" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1

VERIFY_PID="$(launch_mode verify)"
wait_for_path "$HARNESS_ROOT/verify-result.json" "$HARNESS_ROOT/failure-verify.json"
jq -e \
  --argjson prepare_pid "$PREPARE_PID" \
  --argjson verify_pid "$VERIFY_PID" \
  '.passed == true
    and .pid == $verify_pid
    and .preparePID == $prepare_pid
    and .pid != .preparePID
    and .automaticGateError == "bindingMismatch"
    and .productImageScopeBAllowed == false
    and .oldCacheReadable == true
    and .newScopeCacheEmpty == true
    and .watermarkA == 41
    and .watermarkB == 0
    and .fenceAReadable == true
    and .fenceBEmpty == true
    and .pendingMarkerReadable == true
    and .stalePublishMarkersAbsent == true' \
  "$HARNESS_ROOT/verify-result.json" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1

jq -n \
  --argjson prepare_pid "$PREPARE_PID" \
  --argjson verify_pid "$VERIFY_PID" \
  --slurpfile prepare "$HARNESS_ROOT/prepare-result.json" \
  --slurpfile verify "$HARNESS_ROOT/verify-result.json" \
  '{
    gate:"TASK139_PREBOUND_RESOURCE_PROCESS_RELAUNCH",
    executed:2,
    passed:2,
    failed:0,
    skipped:0,
    preparePID:$prepare_pid,
    verifyPID:$verify_pid,
    processRelaunched:($prepare_pid != $verify_pid),
    prepare:$prepare[0],
    verification:$verify[0],
    authenticatedSimulatorTouched:false,
    networkCalls:0
  }'
