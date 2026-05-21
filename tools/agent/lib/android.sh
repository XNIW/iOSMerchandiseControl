#!/usr/bin/env bash

mc_android_connected_devices() {
  adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1}'
}

mc_android_serial() {
  local configured="${MC_ANDROID_DEVICE_SERIAL:-}"
  if [[ -n "$configured" && "$configured" != "REDACTED_SERIAL" && "$configured" != "<REDACTED_SERIAL>" ]]; then
    if adb -s "$configured" get-state >/dev/null 2>&1; then
      printf '%s' "$configured"
      return "$MC_EXIT_PASS"
    fi
    MC_SUMMARY="Configured Android device serial is not connected."
    MC_NEXT_ACTION="Connect device ${configured} or update MC_ANDROID_DEVICE_SERIAL."
    return "$MC_EXIT_BLOCKED"
  fi
  local devices count
  devices="$(mc_android_connected_devices || true)"
  count="$(printf '%s\n' "$devices" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$count" -eq 0 ]]; then
    MC_SUMMARY="No Android device/emulator connected."
    MC_NEXT_ACTION="Connect/unlock one device or start an emulator."
    return "$MC_EXIT_BLOCKED"
  fi
  if [[ "$count" -gt 1 ]]; then
    MC_SUMMARY="Multiple Android devices connected."
    MC_NEXT_ACTION="Set MC_ANDROID_DEVICE_SERIAL to the intended device."
    return "$MC_EXIT_BLOCKED"
  fi
  printf '%s' "$devices"
}

mc_android_require_unlocked() {
  local serial="$1"
  local power keyguard
  power="$(adb -s "$serial" shell dumpsys power 2>/dev/null || true)"
  keyguard="$(adb -s "$serial" shell dumpsys window 2>/dev/null || true)"
  if ! grep -Eq 'mWakefulness=Awake|Display Power: state=ON|state=ON' <<< "$power"; then
    MC_SUMMARY="Android device appears screen-off/asleep."
    MC_NEXT_ACTION="Wake and unlock the device, then retry."
    return "$MC_EXIT_BLOCKED"
  fi
  if grep -Eq 'mDreamingLockscreen=true|mShowingLockscreen=true' <<< "$keyguard"; then
    MC_SUMMARY="Android device appears locked."
    MC_NEXT_ACTION="Unlock the device, then retry."
    return "$MC_EXIT_BLOCKED"
  fi
  return "$MC_EXIT_PASS"
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
  serial="$(mc_android_serial)" || return $?
  mc_android_require_unlocked "$serial" || return $?
  mc_git_context "$MC_ANDROID_REPO"
  mc_android_gradle :app:assembleDebug :app:assembleDebugAndroidTest || return "$MC_EXIT_FAIL"
  local apk_app="$MC_ANDROID_REPO/app/build/outputs/apk/debug/app-debug.apk"
  local apk_test="$MC_ANDROID_REPO/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
  adb -s "$serial" install -r "$apk_app" >/dev/null || return "$MC_EXIT_BLOCKED"
  adb -s "$serial" install -r "$apk_test" >/dev/null || return "$MC_EXIT_BLOCKED"
  adb -s "$serial" shell am instrument -w -r \
    "${extra_args[@]}" \
    -e class "$class" \
    com.example.merchandisecontrolsplitview.test/androidx.test.runner.AndroidJUnitRunner
  code=$?
  [[ "$code" -eq 0 ]] && return "$MC_EXIT_PASS"
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
    -e task112LiveAcceptance true -e task112RunPrefix "$prefix"
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
    -e task112LiveAcceptance true -e task112RunPrefix "$prefix"
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

mc_android_smoke() {
  local kind="$1"
  MC_PLATFORM="android"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_CA_REFS="CA-113-29,CA-113-30"
  local serial
  serial="$(mc_android_serial)" || return $?
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

mc_cmd_android() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    build) mc_android_build "${1:-debug}" ;;
    test)
      case "${1:-sync}" in
        sync) mc_android_test_sync ;;
        offline) mc_android_test_offline ;;
        *) MC_SUMMARY="Unknown android test suite: ${1:-}"; return "$MC_EXIT_MISCONFIGURED" ;;
      esac
      ;;
    smoke) mc_android_smoke "${1:-device}" ;;
    auth-preflight)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_android_auth_preflight
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
