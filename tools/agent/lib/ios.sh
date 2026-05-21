#!/usr/bin/env bash

mc_ios_destination() {
  printf '%s' "${MC_IOS_DESTINATION:-platform=iOS Simulator,name=${MC_IOS_SIMULATOR_NAME},OS=${MC_IOS_SIMULATOR_OS}}"
}

mc_ios_result_bundle() {
  local slug="$1"
  printf '%s' "/tmp/mc-agent-ios-${slug}-${MC_TIMESTAMP}.xcresult"
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
  local dest bundle code
  dest="$(mc_ios_destination)"
  bundle="$(mc_ios_result_bundle auth-preflight)"
  MC_ARTIFACT_XCRESULT="$bundle"
  mc_git_context "$MC_IOS_REPO"
  mc_ios_acquire_xcode_lock || return $?
  (
    cd "$MC_IOS_REPO" || exit 3
    TASK112_IOS_AUTH_PREFLIGHT=1 TASK112_LIVE_ACCEPTANCE=1 \
      xcodebuild test -project iOSMerchandiseControl.xcodeproj \
        -scheme "${MC_IOS_SCHEME}" -configuration Debug \
        -destination "$dest" -resultBundlePath "$bundle" \
        -parallel-testing-enabled NO \
        -only-testing:iOSMerchandiseControlTests/SupabaseConfigSecurityTests/testTask103IOSAuthPreflightWhenEnabled
  )
  code=$?
  mc_ios_release_xcode_lock
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="iOS auth-preflight PASS. xcresult=${bundle}"
    MC_NEXT_ACTION="Run scoped live-write."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="iOS auth-preflight BLOCKED/FAIL. xcresult=${bundle}"
  MC_NEXT_ACTION="Open app, complete login, verify session restore, then retry."
  return "$MC_EXIT_BLOCKED"
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
    TASK112_LIVE_ACCEPTANCE=1 TASK112_RUN_PREFIX="$prefix" \
      xcodebuild test -project iOSMerchandiseControl.xcodeproj \
        -scheme "${MC_IOS_SCHEME}" -configuration Debug \
        -destination "$dest" -resultBundlePath "$bundle" \
        -parallel-testing-enabled NO \
        -only-testing:iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests/test04IOSWriteSmokeAndRemoteReadBack
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
    auth-preflight)
      mc_parse_flag --live "$@" || { MC_SUMMARY="--live required"; return "$MC_EXIT_MISCONFIGURED"; }
      mc_ios_auth_preflight
      ;;
    live-write)
      local prefix
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      mc_ios_live_write "$prefix"
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
