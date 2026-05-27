#!/usr/bin/env bash

mc_android_connected_devices() {
  adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1}'
}

mc_android_available_devices_json() {
  local raw
  raw="$(adb devices -l 2>/dev/null || true)"
  ADB_DEVICES_RAW="$raw" python3 - <<'PY'
import json, os
rows = []
for line in os.environ.get("ADB_DEVICES_RAW", "").splitlines()[1:]:
    line = line.strip()
    if not line:
        continue
    parts = line.split()
    serial = parts[0]
    status = parts[1] if len(parts) > 1 else "unknown"
    details = {}
    for token in parts[2:]:
        if ":" in token:
            key, value = token.split(":", 1)
            details[key] = value
    rows.append({
        "serial": "<REDACTED>",
        "serialHash": __import__("hashlib").sha256(serial.encode()).hexdigest()[:12],
        "status": status,
        "targetType": "emulator" if serial.startswith("emulator-") else "physical",
        "model": details.get("model"),
        "device": details.get("device"),
        "transport": details.get("transport_id"),
    })
print(json.dumps(rows, sort_keys=True))
PY
}

mc_android_target_type() {
  local serial="$1"
  local qemu
  qemu="$(adb -s "$serial" shell getprop ro.kernel.qemu 2>/dev/null | tr -d '\r' || true)"
  if [[ "$serial" == emulator-* || "$qemu" == "1" ]]; then
    printf 'emulator'
  else
    printf 'physical'
  fi
}

mc_android_app_installed() {
  local serial="$1"
  adb -s "$serial" shell pm path com.example.merchandisecontrolsplitview >/dev/null 2>&1
}

mc_android_foreground_package() {
  local serial="$1"
  adb -s "$serial" shell dumpsys window 2>/dev/null \
    | awk -F'[ /}]+' '/mCurrentFocus|mFocusedApp/ {for (i=1;i<=NF;i++) if ($i ~ /^com\\./) {print $i; exit}}' \
    | tr -d '\r'
}

mc_android_lock_state_json() {
  local serial="$1"
  local power keyguard
  power="$(adb -s "$serial" shell dumpsys power 2>/dev/null || true)"
  keyguard="$(adb -s "$serial" shell dumpsys window 2>/dev/null || true)"
  ANDROID_POWER="$power" ANDROID_KEYGUARD="$keyguard" python3 - <<'PY'
import json, os, re
power = os.environ.get("ANDROID_POWER", "")
keyguard = os.environ.get("ANDROID_KEYGUARD", "")
screen_on = bool(re.search(r"mWakefulness=Awake|Display Power: state=ON|state=ON", power))
locked = bool(re.search(r"mDreamingLockscreen=true|mShowingLockscreen=true", keyguard))
print(json.dumps({
    "screenOn": screen_on,
    "locked": locked,
    "unlocked": screen_on and not locked,
}, sort_keys=True))
PY
}

mc_android_preflight_json() {
  local serial="${1:-}"
  local devices target_type state boot_completed app_installed foreground lock_json
  devices="$(mc_android_available_devices_json)"
  target_type=""
  state=""
  boot_completed=""
  app_installed="false"
  foreground=""
  lock_json='{"locked":null,"screenOn":null,"unlocked":null}'
  if [[ -n "$serial" ]]; then
    target_type="$(mc_android_target_type "$serial")"
    state="$(adb -s "$serial" get-state 2>/dev/null || true)"
    boot_completed="$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if mc_android_app_installed "$serial"; then
      app_installed="true"
    fi
    foreground="$(mc_android_foreground_package "$serial" || true)"
    lock_json="$(mc_android_lock_state_json "$serial")"
  fi
  ANDROID_DEVICES_JSON="$devices" ANDROID_HAS_SERIAL="$([[ -n "$serial" ]] && printf true || printf false)" \
  ANDROID_TARGET_TYPE="$target_type" ANDROID_STATE="$state" ANDROID_BOOT="$boot_completed" \
  ANDROID_APP_INSTALLED="$app_installed" ANDROID_FOREGROUND="$foreground" ANDROID_LOCK_JSON="$lock_json" python3 - <<'PY'
import json, os
print(json.dumps({
    "schemaVersion": "1.1",
    "source": "android.live-preflight",
    "availableAdbDevices": json.loads(os.environ["ANDROID_DEVICES_JSON"]),
    "selectedSerial": "<REDACTED>" if os.environ["ANDROID_HAS_SERIAL"] == "true" else None,
    "selectedTargetType": os.environ["ANDROID_TARGET_TYPE"] or None,
    "adbState": os.environ["ANDROID_STATE"] or None,
    "bootCompleted": os.environ["ANDROID_BOOT"] or None,
    "appInstalled": os.environ["ANDROID_APP_INSTALLED"] == "true",
    "foregroundPackage": os.environ["ANDROID_FOREGROUND"] or None,
    "foregroundAppMatches": os.environ["ANDROID_FOREGROUND"] == "com.example.merchandisecontrolsplitview",
    "lockState": json.loads(os.environ["ANDROID_LOCK_JSON"]),
}, sort_keys=True))
PY
}

mc_android_set_preflight_detail() {
  local serial="${1:-}"
  MC_RECONCILIATION_JSON="$(mc_android_preflight_json "$serial")"
  MC_RECONCILIATION_MD="$(ANDROID_PREFLIGHT_JSON="$MC_RECONCILIATION_JSON" python3 - <<'PY'
import json, os
p = json.loads(os.environ["ANDROID_PREFLIGHT_JSON"])
lock = p.get("lockState") or {}
print(f"- android.selectedTargetType: {p.get('selectedTargetType')}")
print(f"- android.availableAdbDevices: {len(p.get('availableAdbDevices') or [])}")
print(f"- android.adbState: {p.get('adbState')}")
print(f"- android.bootCompleted: {p.get('bootCompleted')}")
print(f"- android.appInstalled: {p.get('appInstalled')}")
print(f"- android.foregroundPackage: {p.get('foregroundPackage')}")
print(f"- android.screenOn: {lock.get('screenOn')}")
print(f"- android.locked: {lock.get('locked')}")
PY
)"
}

mc_android_serial() {
  MC_ANDROID_SELECTED_SERIAL=""
  MC_ANDROID_TARGET_TYPE=""
  local configured="${MC_ANDROID_DEVICE_SERIAL:-}"
  if [[ -n "$configured" && "$configured" != "REDACTED_SERIAL" && "$configured" != "<REDACTED_SERIAL>" ]]; then
    if adb -s "$configured" get-state >/dev/null 2>&1; then
      MC_ANDROID_SELECTED_SERIAL="$configured"
      MC_ANDROID_TARGET_TYPE="$(mc_android_target_type "$configured")"
      export MC_ANDROID_SELECTED_SERIAL MC_ANDROID_TARGET_TYPE
      mc_android_set_preflight_detail "$configured"
      printf '%s' "$configured"
      return "$MC_EXIT_PASS"
    fi
    mc_android_set_preflight_detail ""
    MC_SUMMARY="BLOCKED_DEVICE_OFFLINE: configured Android device serial is not connected or not in adb device state."
    MC_NEXT_ACTION="Connect/wake serial ${configured}, or rerun with an explicit emulator serial such as MC_ANDROID_DEVICE_SERIAL=emulator-5554."
    return "$MC_EXIT_BLOCKED"
  fi
  if [[ "${MC_REQUIRES_LIVE:-false}" == "true" ]]; then
    mc_android_set_preflight_detail ""
    MC_SUMMARY="BLOCKED_ANDROID_TARGET_UNSPECIFIED: live Android commands require MC_ANDROID_DEVICE_SERIAL."
    MC_NEXT_ACTION="Set MC_ANDROID_DEVICE_SERIAL to the physical device or emulator serial, then rerun."
    return "$MC_EXIT_BLOCKED"
  fi
  local devices count
  devices="$(mc_android_connected_devices || true)"
  count="$(printf '%s\n' "$devices" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$count" -eq 0 ]]; then
    mc_android_set_preflight_detail ""
    MC_SUMMARY="No Android device/emulator connected."
    MC_NEXT_ACTION="Connect/unlock one device or start an emulator."
    return "$MC_EXIT_BLOCKED"
  fi
  if [[ "$count" -gt 1 ]]; then
    mc_android_set_preflight_detail ""
    MC_SUMMARY="Multiple Android devices connected."
    MC_NEXT_ACTION="Set MC_ANDROID_DEVICE_SERIAL to the intended device."
    return "$MC_EXIT_BLOCKED"
  fi
  MC_ANDROID_SELECTED_SERIAL="$devices"
  MC_ANDROID_TARGET_TYPE="$(mc_android_target_type "$devices")"
  export MC_ANDROID_SELECTED_SERIAL MC_ANDROID_TARGET_TYPE
  mc_android_set_preflight_detail "$devices"
  printf '%s' "$devices"
}

mc_android_require_unlocked() {
  local serial="$1"
  local power keyguard
  power="$(adb -s "$serial" shell dumpsys power 2>/dev/null || true)"
  keyguard="$(adb -s "$serial" shell dumpsys window 2>/dev/null || true)"
  if ! grep -Eq 'mWakefulness=Awake|Display Power: state=ON|state=ON' <<< "$power"; then
    mc_android_set_preflight_detail "$serial"
    MC_SUMMARY="BLOCKED_DEVICE_LOCKED: Android target appears screen-off/asleep."
    MC_NEXT_ACTION="Wake and unlock the selected Android target, then retry; or rerun with an explicit emulator serial."
    return "$MC_EXIT_BLOCKED"
  fi
  if grep -Eq 'mDreamingLockscreen=true|mShowingLockscreen=true' <<< "$keyguard"; then
    if [[ "${MC_ANDROID_ALLOW_LOCKED_INSTRUMENTATION:-0}" == "1" ]]; then
      MC_WARNINGS="${MC_WARNINGS:+${MC_WARNINGS},}android-locked-instrumentation-override"
      return "$MC_EXIT_PASS"
    fi
    mc_android_set_preflight_detail "$serial"
    MC_SUMMARY="BLOCKED_DEVICE_LOCKED: Android target appears locked."
    MC_NEXT_ACTION="Unlock the selected Android target, then retry; or rerun with an explicit emulator serial."
    return "$MC_EXIT_BLOCKED"
  fi
  mc_android_set_preflight_detail "$serial"
  return "$MC_EXIT_PASS"
}

mc_android_timeout_seconds() {
  printf '%s' "${MC_ANDROID_ADB_TIMEOUT_SECONDS:-180}"
}

mc_android_instrument_timeout_seconds() {
  printf '%s' "${MC_ANDROID_INSTRUMENT_TIMEOUT_SECONDS:-240}"
}

mc_android_adb_timed() {
  local seconds="$1"
  shift
  perl -e 'alarm shift @ARGV; exec @ARGV' "$seconds" adb "$@"
}

mc_android_device_state_redacted() {
  local serial="$1"
  local state boot_completed
  state="$(adb -s "$serial" get-state 2>/dev/null || true)"
  boot_completed="$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  printf 'state=%s boot_completed=%s' "${state:-unknown}" "${boot_completed:-unknown}"
}

mc_android_gradle() {
  (
    cd "$MC_ANDROID_REPO" || exit 3
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djdk.attach.allowAttachSelf=true"
    ./gradlew "$@"
  )
}

mc_android_build() {
  local kind="$1"
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_CA_REFS="CA-113-03,CA-113-15,CA-113-29,CA-113-30"
  mc_git_context "$MC_ANDROID_REPO"
  local code
  case "$kind" in
    debug) mc_android_gradle :app:assembleDebug ;;
    release) mc_android_gradle --no-daemon :app:assembleRelease ;;
    *) MC_SUMMARY="Unknown Android build kind: ${kind}"; return "$MC_EXIT_MISCONFIGURED" ;;
  esac
  code=$?
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="Android build ${kind} PASS."
    MC_NEXT_ACTION="Run Android targeted tests."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Android build ${kind} FAIL."
  MC_NEXT_ACTION="Inspect Gradle log."
  return "$MC_EXIT_FAIL"
}

mc_android_test_sync() {
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_CA_REFS="CA-113-05,CA-113-15,CA-113-29,CA-113-30"
  mc_git_context "$MC_ANDROID_REPO"
  mc_android_gradle :app:testDebugUnitTest \
    --tests '*DefaultInventoryRepositoryTest*114*' \
    --tests 'CatalogAutoSyncCoordinatorTest' \
    --tests 'CatalogSyncViewModelTest' \
    --tests 'HistorySessionPushCoordinatorTest' \
    --tests 'SyncErrorClassifierTest' \
    --tests 'InventoryRemoteFetchSupportTest'
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="Android test sync PASS."
    MC_NEXT_ACTION="Run Android offline harness."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Android test sync FAIL."
  MC_NEXT_ACTION="Inspect Gradle test report."
  return "$MC_EXIT_FAIL"
}

mc_android_test_offline() {
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_ANDROID_OFFLINE_TIER="L1"
  MC_CA_REFS="CA-113-05,CA-113-10,CA-113-20,CA-113-29,CA-113-30"
  mc_git_context "$MC_ANDROID_REPO"
  mc_android_gradle :app:testDebugUnitTest \
    --tests 'com.example.merchandisecontrolsplitview.data.Task113AndroidOfflineHarnessJvmTest'
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="Android offline L1 JVM deterministic harness PASS."
    MC_NEXT_ACTION="Run android offline-write --tier L2 if a device/emulator is available."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Android offline L1 JVM deterministic harness FAIL."
  MC_NEXT_ACTION="Inspect JVM test report."
  return "$MC_EXIT_FAIL"
}

mc_android_instrument() {
  local class="$1"
  shift
  local extra_args=("$@")
  local serial code
  mc_android_serial >/dev/null || return $?
  serial="$MC_ANDROID_SELECTED_SERIAL"
  mc_android_require_unlocked "$serial" || return $?
  mc_git_context "$MC_ANDROID_REPO"
  mc_android_gradle :app:assembleDebug :app:assembleDebugAndroidTest || return "$MC_EXIT_FAIL"
  local apk_app="$MC_ANDROID_REPO/app/build/outputs/apk/debug/app-debug.apk"
  local apk_test="$MC_ANDROID_REPO/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
  local adb_timeout instrument_timeout state_summary instrument_log
  adb_timeout="$(mc_android_timeout_seconds)"
  instrument_timeout="$(mc_android_instrument_timeout_seconds)"
  if ! mc_android_adb_timed "$adb_timeout" -s "$serial" install -r "$apk_app" >/dev/null; then
    state_summary="$(mc_android_device_state_redacted "$serial")"
    mc_android_set_preflight_detail "$serial"
    MC_SUMMARY="Android instrumentation BLOCKED: app install failed or timed out after ${adb_timeout}s (${state_summary})."
    MC_NEXT_ACTION="Verify the device is connected/unlocked, then retry; if adb remains stuck, restart the selected emulator/device."
    return "$MC_EXIT_BLOCKED"
  fi
  if ! mc_android_adb_timed "$adb_timeout" -s "$serial" install -r "$apk_test" >/dev/null; then
    state_summary="$(mc_android_device_state_redacted "$serial")"
    mc_android_set_preflight_detail "$serial"
    MC_SUMMARY="Android instrumentation BLOCKED: test APK install failed or timed out after ${adb_timeout}s (${state_summary})."
    MC_NEXT_ACTION="Verify device storage/install state and retry; restart only the selected emulator/device if adb is still stuck."
    return "$MC_EXIT_BLOCKED"
  fi
  instrument_log="$(mktemp -t mc-agent-android-instrument)"
  mc_android_adb_timed "$instrument_timeout" -s "$serial" shell am instrument -w -r \
    "${extra_args[@]}" \
    -e class "$class" \
    com.example.merchandisecontrolsplitview.test/androidx.test.runner.AndroidJUnitRunner >"$instrument_log" 2>&1
  code=$?
  mc_report_log "$(mc_redact_text "$(tail -n 260 "$instrument_log")")"
  if [[ "$code" -eq 0 ]] \
    && grep -q "OK (" "$instrument_log" \
    && ! grep -Eq "FAILURES!!!|INSTRUMENTATION_STATUS_CODE: -2" "$instrument_log"; then
    rm -f "$instrument_log"
    mc_android_set_preflight_detail "$serial"
    MC_SUMMARY="Android instrumentation PASS for ${class} on ${MC_ANDROID_TARGET_TYPE:-unknown} target."
    MC_NEXT_ACTION="Continue Android live/device gate."
    return "$MC_EXIT_PASS"
  fi
  state_summary="$(mc_android_device_state_redacted "$serial")"
  if [[ "$code" -eq 142 ]]; then
    rm -f "$instrument_log"
    mc_android_set_preflight_detail "$serial"
    MC_SUMMARY="Android instrumentation BLOCKED: am instrument timed out after ${instrument_timeout}s (${state_summary})."
    MC_NEXT_ACTION="Inspect device/emulator responsiveness and test runner logs; retry after restarting only the selected device if needed."
    return "$MC_EXIT_BLOCKED"
  fi
  if grep -Eq "requires signed-in session|Supabase session is not signed in|not signed in" "$instrument_log"; then
    rm -f "$instrument_log"
    mc_android_set_preflight_detail "$serial"
    MC_SUMMARY="AUTH_BLOCKED: Android target is reachable but Supabase session is signed out or unavailable."
    MC_NEXT_ACTION="Open the selected Android target, sign in to Supabase, then rerun the same command with MC_ANDROID_DEVICE_SERIAL=${serial}."
    return "$MC_EXIT_BLOCKED"
  fi
  rm -f "$instrument_log"
  mc_android_set_preflight_detail "$serial"
  MC_SUMMARY="Android instrumentation FAIL for ${class}; adb exit=${code} (${state_summary})."
  MC_NEXT_ACTION="Inspect instrumentation output/logcat and rerun after fixing the reported failure."
  return "$MC_EXIT_FAIL"
}

mc_android_auth_preflight() {
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-113-07,CA-113-19,CA-113-30"
  mc_require_live || return $?
  mc_android_instrument 'com.example.merchandisecontrolsplitview.Task103AuthPreflightTest#authSessionOwnerHashWhenEnabled' \
    -e task112AuthPreflight true
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="Android auth-preflight PASS on ${MC_ANDROID_TARGET_TYPE:-unknown} target."
    MC_NEXT_ACTION="Run Android live-full-pull or live matrix."
    return "$MC_EXIT_PASS"
  fi
  return "$code"
}

mc_android_cleanup_scoped() {
  local prefix="$1"
  local execute="$2"
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="cleanup-dry-run"
  MC_REQUIRES_CLEANUP="true"
  MC_CA_REFS="CA-06,CA-10"
  mc_validate_task_prefix "$prefix" || return $?
  MC_TEST_PREFIX="$prefix"
  if [[ "$execute" == "1" ]]; then
    MC_SAFETY_LEVEL="cleanup-execute"
    mc_require_cleanup_execute || return $?
  fi
  mc_android_instrument 'com.example.merchandisecontrolsplitview.Task103CrossPlatformAcceptanceTest#test114AndroidCleanupLocalHistoryResidue' \
    -e task114LocalCleanup true \
    -e task114CleanupPrefix "$prefix" \
    -e task114CleanupExecute "$execute"
}

mc_android_live_pull() {
  local prefix="$1"
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-113-07,CA-113-19,CA-113-30"
  mc_validate_task_prefix "$prefix" || return $?
  mc_require_live || return $?
  MC_TEST_PREFIX="$prefix"
  mc_android_instrument 'com.example.merchandisecontrolsplitview.Task103CrossPlatformAcceptanceTest#test02AndroidPullIOSSmokeAndLocalReadBack' \
    -e task114LiveAcceptance true -e task114RunPrefix "$prefix"
}

mc_android_live_write() {
  local prefix="$1"
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-113-07,CA-113-19,CA-113-30"
  mc_validate_task_prefix "$prefix" || return $?
  mc_require_live || return $?
  MC_TEST_PREFIX="$prefix"
  mc_android_instrument 'com.example.merchandisecontrolsplitview.Task103CrossPlatformAcceptanceTest#test03AndroidWriteSmokeAndRemoteReadBack' \
    -e task114LiveAcceptance true -e task114RunPrefix "$prefix"
}

mc_android_live_full_pull() {
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-02,CA-07,CA-10"
  mc_require_live || return $?
  mc_android_instrument 'com.example.merchandisecontrolsplitview.Task114AndroidFullReconciliationTest#fullPullFromSupabaseWithoutClearingLocalData' \
    -e task114AndroidFullReconcile true
}

mc_android_task114_matrix_step() {
  local method="$1"
  local prefix="$2"
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-114-06,T-06"
  mc_validate_task_prefix "$prefix" || return $?
  mc_require_live || return $?
  MC_TEST_PREFIX="$prefix"
  mc_android_instrument "com.example.merchandisecontrolsplitview.Task103CrossPlatformAcceptanceTest#${method}" \
    -e task114LiveAcceptance true -e task114RunPrefix "$prefix"
}

mc_android_offline_l1() {
  local mode="$1"
  local test_name='offlineWriteKeepsPendingWhenRemoteFails'
  [[ "$mode" == "reconnect" ]] && test_name='reconnectDrainRetriesPendingWithoutDuplicates'
  mc_git_context "$MC_ANDROID_REPO"
  mc_android_gradle :app:testDebugUnitTest \
    --tests "com.example.merchandisecontrolsplitview.data.Task113AndroidOfflineHarnessJvmTest.${test_name}"
}

mc_android_offline_l2() {
  local mode="$1"
  local prefix="$2"
  local method='offlineWriteAndReconnectDrainInstrumentedL2'
  [[ "$mode" == "reconnect" ]] && method='offlineWriteAndReconnectDrainInstrumentedL2'
  mc_git_context "$MC_ANDROID_REPO"
  mc_android_gradle :app:assembleDebugAndroidTest || return "$MC_EXIT_FAIL"
  mc_android_instrument "com.example.merchandisecontrolsplitview.Task113AndroidOfflineHarnessTest#${method}" \
    -e task113OfflineHarnessL2 true -e task113RunPrefix "$prefix"
}

mc_android_offline_l3() {
  local prefix="$1"
  mc_require_live || return $?
  mc_android_instrument 'com.example.merchandisecontrolsplitview.Task113AndroidOfflineHarnessTest#offlineWriteAndReconnectDrainLiveWhenEnabled' \
    -e task113OfflineHarness true -e task113RunPrefix "$prefix"
}

mc_android_offline_write() {
  local tier="$1"
  local prefix="$2"
  MC_PLATFORM="android"
  MC_ANDROID_OFFLINE_TIER="$tier"
  MC_CA_REFS="CA-113-10,CA-113-20,CA-113-26,CA-113-29,CA-113-30"
  mc_validate_task_prefix "$prefix" 1 || return $?
  MC_TEST_PREFIX="$prefix"
  case "$tier" in
    L1)
      MC_SAFETY_LEVEL="safe-readonly"
      mc_android_offline_l1 write
      ;;
    L2)
      MC_SAFETY_LEVEL="safe-readonly"
      mc_android_offline_l2 write "$prefix"
      ;;
    L3)
      MC_SAFETY_LEVEL="live-write"
      MC_REQUIRES_LIVE="true"
      mc_android_offline_l3 "$prefix"
      ;;
    *)
      MC_SUMMARY="Unknown Android offline tier: ${tier}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    if [[ "$tier" == "L3" ]]; then
      mc_set_pass_with_notes
      MC_SUMMARY="Android offline-write L3 PASS_WITH_NOTES for ${prefix}: live remote read-back harness ran, but CLI does not force device network-off/on."
      MC_NEXT_ACTION="Use as supporting evidence only; full Android live offline PASS still requires explicit offline/reconnect proof plus cleanup."
      return "$MC_EXIT_PASS"
    fi
    MC_SUMMARY="Android offline-write ${tier} PASS for ${prefix}."
    MC_NEXT_ACTION="Run reconnect-drain for same tier/prefix."
    return "$MC_EXIT_PASS"
  fi
  local detail="${MC_SUMMARY:-see log}"
  MC_SUMMARY="Android offline-write ${tier} FAIL/BLOCKED for ${prefix}. Detail: ${detail}"
  if [[ -z "${MC_NEXT_ACTION:-}" || "${MC_NEXT_ACTION:-}" == "Review report." ]]; then
    MC_NEXT_ACTION="For L2, connect/unlock emulator/device; for L3, set live gates and signed-in app."
  fi
  return "$code"
}

mc_android_reconnect_drain() {
  local tier="$1"
  local prefix="$2"
  MC_PLATFORM="android"
  MC_ANDROID_OFFLINE_TIER="$tier"
  MC_CA_REFS="CA-113-10,CA-113-20,CA-113-26,CA-113-29,CA-113-30"
  mc_validate_task_prefix "$prefix" 1 || return $?
  MC_TEST_PREFIX="$prefix"
  case "$tier" in
    L1)
      MC_SAFETY_LEVEL="safe-readonly"
      mc_android_offline_l1 reconnect
      ;;
    L2)
      MC_SAFETY_LEVEL="safe-readonly"
      mc_android_offline_l2 reconnect "$prefix"
      ;;
    L3)
      MC_SAFETY_LEVEL="live-write"
      MC_REQUIRES_LIVE="true"
      mc_android_offline_l3 "$prefix"
      ;;
    *)
      MC_SUMMARY="Unknown Android offline tier: ${tier}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    if [[ "$tier" == "L3" ]]; then
      mc_set_pass_with_notes
      MC_SUMMARY="Android reconnect-drain L3 PASS_WITH_NOTES for ${prefix}: live remote read-back harness ran, but CLI does not force device network-off/on."
      MC_NEXT_ACTION="Use as supporting evidence only; full Android live offline PASS still requires explicit offline/reconnect proof plus cleanup."
      return "$MC_EXIT_PASS"
    fi
    MC_SUMMARY="Android reconnect-drain ${tier} PASS for ${prefix}."
    MC_NEXT_ACTION="Run residue/read-back where applicable."
    return "$MC_EXIT_PASS"
  fi
  local detail="${MC_SUMMARY:-see log}"
  MC_SUMMARY="Android reconnect-drain ${tier} FAIL/BLOCKED for ${prefix}. Detail: ${detail}"
  if [[ -z "${MC_NEXT_ACTION:-}" || "${MC_NEXT_ACTION:-}" == "Review report." ]]; then
    MC_NEXT_ACTION="Inspect tier-specific harness log."
  fi
  return "$code"
}

mc_android_offline_tier_status() {
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_ANDROID_OFFLINE_TIER="none"
  MC_CA_REFS="CA-113-10,CA-113-20,CA-113-26"
  cat <<'STATUS'
Android offline tier status:
L1 = JVM deterministic offline harness: implemented via Task113AndroidOfflineHarnessJvmTest.
L2 = instrumented Room + fake network harness: implemented via Task113AndroidOfflineHarnessTest#offlineWriteAndReconnectDrainInstrumentedL2.
L3 = live offline matrix with Supabase read-back + cleanup: gated by MC_ALLOW_LIVE and signed-in device.
Claim rule: L1 is not live offline PASS; DONE_FULL requires L2 PASS or accepted PASS_WITH_NOTES.
STATUS
  MC_SUMMARY="Android offline tiering documented: L1 implemented, L2 implemented, L3 gated."
  MC_NEXT_ACTION="Run android offline-write --tier L2 when device/emulator is available."
  return "$MC_EXIT_PASS"
}

mc_android_prefer_emulator_for_task126_ui() {
  if [[ -n "${MC_ANDROID_DEVICE_SERIAL:-}" ]]; then
    return 0
  fi
  local emulator
  emulator="$(adb devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"
  if [[ -n "$emulator" ]]; then
    MC_ANDROID_DEVICE_SERIAL="$emulator"
    export MC_ANDROID_DEVICE_SERIAL
  fi
}

mc_android_task126_ui_smoke() {
  local kind="$1"
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_CA_REFS="AC-126-05,AC-126-12,AC-126-52"
  local serial pkg component apk code run_id screenshot_abs screenshot_rel artifact_json
  pkg="com.example.merchandisecontrolsplitview"
  component="${pkg}/.MainActivity"
  run_id="${MC_RUN_ID:-${MC_TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}-android-smoke-${kind}-p$$}"

  mc_android_prefer_emulator_for_task126_ui
  mc_android_serial >/dev/null || return $?
  serial="$MC_ANDROID_SELECTED_SERIAL"
  mc_android_require_unlocked "$serial" || return $?
  mc_android_gradle :app:assembleDebug || return "$MC_EXIT_FAIL"
  apk="$MC_ANDROID_REPO/app/build/outputs/apk/debug/app-debug.apk"
  adb -s "$serial" install -r "$apk" >/dev/null || return "$MC_EXIT_BLOCKED"
  adb -s "$serial" shell am force-stop "$pkg" >/dev/null 2>&1 || true
  adb -s "$serial" shell run-as "$pkg" rm -f "files/task126-ui-smoke-${kind}.json" >/dev/null 2>&1 || true
  adb -s "$serial" shell am start -n "$component" --es task126_ui_smoke_kind "$kind" >/dev/null
  code=$?
  if [[ "$code" -ne 0 ]]; then
    MC_SUMMARY="Android smoke ${kind} BLOCKED: emulator launch intent failed."
    MC_NEXT_ACTION="Inspect adb am start output and selected emulator state."
    return "$MC_EXIT_BLOCKED"
  fi

  mkdir -p "$MC_EVIDENCE_ABS/agent-runs/runtime"
  artifact_json="$MC_EVIDENCE_ABS/agent-runs/runtime/${run_id}-android-${kind}-smoke.json"
  local artifact_tmp valid_json
  artifact_tmp="${artifact_json}.tmp"
  valid_json=0
  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
    adb -s "$serial" exec-out run-as "$pkg" cat "files/task126-ui-smoke-${kind}.json" > "$artifact_tmp" 2>/dev/null || true
    if [[ -s "$artifact_tmp" ]] && python3 - "$artifact_tmp" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload.get("status") == "PASS"
assert payload.get("dialogVisible") is True
assert payload.get("buttons")
for key in ["timeToReviewShownMs", "timeToApplyChoiceMs", "timeToFinalStateMs", "pendingBefore", "pendingAfter", "conflictCountBefore", "conflictCountAfter", "mergedCount", "reviewRemainingCount"]:
    int(payload[key])
PY
    then
      mv "$artifact_tmp" "$artifact_json"
      valid_json=1
      break
    fi
    sleep 1
  done
  rm -f "$artifact_tmp"
  if [[ "$valid_json" != "1" ]]; then
    MC_SUMMARY="Android smoke ${kind} FAIL: runtime UI smoke evidence JSON was not written by the emulator app."
    MC_NEXT_ACTION="Inspect app launch logs and task126_ui_smoke_kind handling."
    return "$MC_EXIT_FAIL"
  fi

  screenshot_abs="$MC_EVIDENCE_ABS/agent-runs/${run_id}-android-${kind}.png"
  if adb -s "$serial" exec-out screencap -p > "$screenshot_abs"; then
    screenshot_rel="$MC_EVIDENCE_DIR/agent-runs/$(basename "$screenshot_abs")"
    MC_ARTIFACT_SCREENSHOT="$screenshot_rel"
  else
    MC_SUMMARY="Android smoke ${kind} FAIL: emulator screenshot capture failed."
    MC_NEXT_ACTION="Verify the emulator display is available and rerun smoke."
    return "$MC_EXIT_FAIL"
  fi
  mc_report_log "TASK-126 Android UI smoke JSON: $(mc_relpath "$artifact_json")"
  MC_SUMMARY="Android smoke ${kind} PASS on Android Emulator with visible Review/Recovery dialog, buttons, screenshot, and timing/state JSON."
  MC_NEXT_ACTION="Use the screenshot and smoke JSON as emulator UI interaction evidence."
  return "$MC_EXIT_PASS"
}

mc_android_smoke() {
  local kind="$1"
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_CA_REFS="CA-113-29,CA-113-30"
  case "$kind" in
    conflict-review-ui|account-switch-review-ui)
      mc_android_task126_ui_smoke "$kind"
      return $?
      ;;
  esac
  local serial
  mc_android_serial >/dev/null || return $?
  serial="$MC_ANDROID_SELECTED_SERIAL"
  mc_android_require_unlocked "$serial" || return $?
  mc_android_gradle :app:assembleDebug || return "$MC_EXIT_FAIL"
  local apk="$MC_ANDROID_REPO/app/build/outputs/apk/debug/app-debug.apk"
  adb -s "$serial" install -r "$apk" >/dev/null || return "$MC_EXIT_BLOCKED"
  adb -s "$serial" shell monkey -p com.example.merchandisecontrolsplitview -c android.intent.category.LAUNCHER 1
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="Android smoke ${kind} PASS on redacted device."
    MC_NEXT_ACTION="Run Options smoke or targeted tests."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Android smoke ${kind} FAIL."
  MC_NEXT_ACTION="Inspect adb/logcat or unlock device."
  return "$MC_EXIT_FAIL"
}

mc_android_test_task126_suite() {
  local suite="$1"
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="safe-readonly"
  local pattern
  case "$suite" in
    sync-policy)
      MC_CA_REFS="AC-126-01,AC-126-03,AC-126-04"
      pattern="*Task126SyncPolicyTest*"
      ;;
    account-store-boundary)
      MC_CA_REFS="AC-126-01,AC-126-02,AC-126-12"
      pattern="*Task126AccountStoreBoundaryTest*"
      ;;
    conflict-review)
      MC_CA_REFS="AC-126-05,AC-126-06,AC-126-24"
      pattern="*Task126ConflictReviewTest*"
      ;;
    conflict-review-ui)
      MC_CA_REFS="AC-126-05,AC-126-06,AC-126-24,AC-126-52"
      pattern="*Task126ConflictReviewUiTest*"
      ;;
    account-switch-review-ui)
      MC_CA_REFS="AC-126-02,AC-126-12,AC-126-13,AC-126-52"
      pattern="*Task126AccountSwitchReviewUiTest*"
      ;;
    cache-memory)
      MC_CA_REFS="AC-126-08,AC-126-09,AC-126-40,AC-126-41"
      pattern="*Task126CacheMemoryTest*"
      ;;
    *)
      MC_SUMMARY="Unknown Android TASK-126 test suite: ${suite}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
  mc_git_context "$MC_ANDROID_REPO"
  if mc_android_gradle testDebugUnitTest --tests "$pattern"; then
    MC_SUMMARY="Android TASK-126 ${suite} tests PASS."
    MC_NEXT_ACTION="Continue TASK-126 Android parity gates."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Android TASK-126 ${suite} tests FAIL or are missing."
  MC_NEXT_ACTION="Implement/fix Android TASK-126 parity tests for ${suite}, then rerun."
  return "$MC_EXIT_FAIL"
}

mc_cmd_android() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    build) mc_android_build "${1:-debug}" ;;
    test)
      case "${1:-sync}" in
        sync) mc_android_test_sync ;;
        offline) mc_android_test_offline ;;
        sync-policy|account-store-boundary|conflict-review|conflict-review-ui|account-switch-review-ui|cache-memory) mc_android_test_task126_suite "${1:-}" ;;
        *) MC_SUMMARY="Unknown android test suite: ${1:-}"; return "$MC_EXIT_MISCONFIGURED" ;;
      esac
      ;;
    smoke) mc_android_smoke "${1:-device}" ;;
    auth-preflight)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_android_auth_preflight
      ;;
    cleanup-scoped)
      local prefix execute=0
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      if mc_parse_flag --execute "$@"; then
        execute=1
      elif ! mc_parse_flag --dry-run "$@"; then
        MC_SUMMARY="Android cleanup-scoped refused: specify --dry-run or --execute."
        MC_NEXT_ACTION="Run android cleanup-scoped --prefix TASK114_ --dry-run first."
        return "$MC_EXIT_REFUSED"
      fi
      mc_android_cleanup_scoped "$prefix" "$execute"
      ;;
    live-pull)
      local prefix
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      mc_android_live_pull "$prefix"
      ;;
    live-write)
      local prefix
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      mc_android_live_write "$prefix"
      ;;
    live-full-pull)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_android_live_full_pull
      ;;
    offline-tier-status)
      mc_android_offline_tier_status
      ;;
    offline-write)
      local prefix tier
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      tier="$(mc_parse_opt --tier "$@" || true)"
      tier="${tier:-L1}"
      mc_android_offline_write "$tier" "$prefix"
      ;;
    reconnect-drain)
      local prefix tier
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      tier="$(mc_parse_opt --tier "$@" || true)"
      tier="${tier:-L1}"
      mc_android_reconnect_drain "$tier" "$prefix"
      ;;
    *)
      MC_SUMMARY="Unknown android subcommand: ${sub}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}
