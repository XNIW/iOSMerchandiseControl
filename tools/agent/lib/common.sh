#!/usr/bin/env bash

MC_AGENT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MC_AGENT_VERSION="0.5.5-task130-consolidated"
MC_SCHEMA_VERSION="1.1"

MC_IOS_REPO="${MC_IOS_REPO:-/Users/minxiang/Desktop/iOSMerchandiseControl}"
MC_ANDROID_REPO="${MC_ANDROID_REPO:-/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView}"
MC_SUPABASE_REPO="${MC_SUPABASE_REPO:-/Users/minxiang/Desktop/MerchandiseControlSupabase}"
MC_TASK_ID_EXPLICIT="${MC_TASK_ID+x}"
MC_EVIDENCE_DIR_EXPLICIT="${MC_EVIDENCE_DIR+x}"
MC_RUN_PREFIX_EXPLICIT="${MC_RUN_PREFIX+x}"
MC_TASK_ID="${MC_TASK_ID:-TASK-115}"
MC_EVIDENCE_DIR="${MC_EVIDENCE_DIR:-docs/TASKS/EVIDENCE/TASK-115}"

MC_EXIT_PASS=0
MC_EXIT_FAIL=1
MC_EXIT_BLOCKED=2
MC_EXIT_MISCONFIGURED=3
MC_EXIT_REFUSED=4

MC_QUIET="${MC_QUIET:-0}"
MC_VERBOSE="${MC_VERBOSE:-0}"

mc_agent_source_libs() {
  # shellcheck source=/dev/null
  source "${MC_AGENT_ROOT}/lib/redact.sh"
  # shellcheck source=/dev/null
  source "${MC_AGENT_ROOT}/lib/report.sh"
  # shellcheck source=/dev/null
  source "${MC_AGENT_ROOT}/lib/ios.sh"
  # shellcheck source=/dev/null
  source "${MC_AGENT_ROOT}/lib/android.sh"
  # shellcheck source=/dev/null
  source "${MC_AGENT_ROOT}/lib/supabase.sh"
  # shellcheck source=/dev/null
  source "${MC_AGENT_ROOT}/lib/sync.sh"
}

mc_load_config() {
  local cfg="${MC_AGENT_CONFIG:-${MC_AGENT_ROOT}/config.env}"
  local loaded_example=0
  local had_task_id="$MC_TASK_ID_EXPLICIT"
  local had_evidence_dir="$MC_EVIDENCE_DIR_EXPLICIT"
  local had_run_prefix="$MC_RUN_PREFIX_EXPLICIT"
  local had_allow_live="${MC_ALLOW_LIVE+x}"
  local had_allow_cleanup="${MC_ALLOW_CLEANUP+x}"
  local had_profile="${MC_SUPABASE_PROFILE+x}"
  local had_android_serial="${MC_ANDROID_DEVICE_SERIAL+x}"
  local had_ios_simulator_id="${MC_IOS_SIMULATOR_ID+x}"
  local had_ios_simulator_udid="${MC_IOS_SIMULATOR_UDID+x}"
  local had_ios_device_udid="${MC_IOS_DEVICE_UDID+x}"
  local env_task_id="${MC_TASK_ID:-}"
  local env_evidence_dir="${MC_EVIDENCE_DIR:-}"
  local env_run_prefix="${MC_RUN_PREFIX:-}"
  local env_allow_live="${MC_ALLOW_LIVE:-}"
  local env_allow_cleanup="${MC_ALLOW_CLEANUP:-}"
  local env_profile="${MC_SUPABASE_PROFILE:-}"
  local env_android_serial="${MC_ANDROID_DEVICE_SERIAL:-}"
  local env_ios_simulator_id="${MC_IOS_SIMULATOR_ID:-}"
  local env_ios_simulator_udid="${MC_IOS_SIMULATOR_UDID:-}"
  local env_ios_device_udid="${MC_IOS_DEVICE_UDID:-}"
  if [[ -f "$cfg" ]]; then
    # shellcheck source=/dev/null
    source "$cfg"
  elif [[ -f "${MC_AGENT_ROOT}/config.example.env" ]]; then
    # shellcheck source=/dev/null
    source "${MC_AGENT_ROOT}/config.example.env"
    loaded_example=1
  fi
  [[ -n "$had_task_id" ]] && MC_TASK_ID="$env_task_id"
  [[ -n "$had_evidence_dir" ]] && MC_EVIDENCE_DIR="$env_evidence_dir"
  [[ -n "$had_run_prefix" ]] && MC_RUN_PREFIX="$env_run_prefix"
  [[ -n "$had_allow_live" ]] && MC_ALLOW_LIVE="$env_allow_live"
  [[ -n "$had_allow_cleanup" ]] && MC_ALLOW_CLEANUP="$env_allow_cleanup"
  [[ -n "$had_profile" ]] && MC_SUPABASE_PROFILE="$env_profile"
  [[ -n "$had_android_serial" ]] && MC_ANDROID_DEVICE_SERIAL="$env_android_serial"
  [[ -n "$had_ios_simulator_id" ]] && MC_IOS_SIMULATOR_ID="$env_ios_simulator_id"
  [[ -n "$had_ios_simulator_udid" ]] && MC_IOS_SIMULATOR_UDID="$env_ios_simulator_udid"
  [[ -n "$had_ios_device_udid" ]] && MC_IOS_DEVICE_UDID="$env_ios_device_udid"

  if [[ "$loaded_example" == "1" && -z "$had_task_id" ]]; then
    local inferred_task_id
    inferred_task_id="$(mc_infer_task_id_from_master || true)"
    if [[ -n "$inferred_task_id" ]]; then
      MC_TASK_ID="$inferred_task_id"
      [[ -z "$had_evidence_dir" ]] && MC_EVIDENCE_DIR="docs/TASKS/EVIDENCE/${inferred_task_id}"
      [[ -z "$had_run_prefix" ]] && MC_RUN_PREFIX="${inferred_task_id/-/}_RUN_"
    fi
  fi
  if [[ -n "$had_task_id" && -z "$had_evidence_dir" && "$MC_TASK_ID" =~ ^TASK-[0-9]{3,}$ ]]; then
    MC_EVIDENCE_DIR="docs/TASKS/EVIDENCE/${MC_TASK_ID}"
  fi
  if [[ -n "$had_task_id" && -z "$had_run_prefix" && "$MC_TASK_ID" =~ ^TASK-[0-9]{3,}$ ]]; then
    MC_RUN_PREFIX="${MC_TASK_ID/-/}_RUN_"
  fi

  export MC_IOS_REPO MC_ANDROID_REPO MC_SUPABASE_REPO MC_TASK_ID MC_EVIDENCE_DIR
  export MC_AGENT_VERSION MC_SCHEMA_VERSION MC_ALLOW_LIVE MC_ALLOW_CLEANUP
  export MC_IOS_SCHEME MC_IOS_SIMULATOR_NAME MC_IOS_SIMULATOR_OS MC_IOS_DESTINATION
  export MC_IOS_SIMULATOR_ID MC_IOS_SIMULATOR_UDID MC_IOS_BUNDLE_ID
  export MC_IOS_DEVICE_UDID MC_IOS_DEVICE_ID
  export MC_ANDROID_DEVICE_SERIAL MC_ANDROID_SDK_ROOT MC_SUPABASE_PROJECT_REF MC_SUPABASE_PROFILE
  export MC_REDACT_EMAILS MC_REDACT_PATHS MC_RUN_PREFIX

  mc_refresh_evidence_abs

  export MC_ANDROID_SDK_ROOT="${MC_ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
  export PATH="${MC_ANDROID_SDK_ROOT}/platform-tools:${MC_ANDROID_SDK_ROOT}/tools:${PATH}"
  if [[ -n "${MC_ANDROID_JAVA_HOME:-}" && -d "$MC_ANDROID_JAVA_HOME" ]]; then
    export JAVA_HOME="$MC_ANDROID_JAVA_HOME"
  fi
  export GRADLE_OPTS="${MC_ANDROID_GRADLE_OPTS:-}"
}

mc_infer_task_id_from_master() {
  local master="${MC_IOS_REPO}/docs/MASTER-PLAN.md"
  [[ -f "$master" ]] || return 1
  LC_ALL=C grep -Eo 'TASK-[0-9]+' "$master" | head -n 1
}

mc_refresh_evidence_abs() {
  if [[ -d "$MC_IOS_REPO" ]]; then
    MC_EVIDENCE_ABS="$(cd "$MC_IOS_REPO" && mkdir -p "$MC_EVIDENCE_DIR" && cd "$MC_EVIDENCE_DIR" && pwd)"
  else
    MC_EVIDENCE_ABS="$MC_IOS_REPO/$MC_EVIDENCE_DIR"
  fi
  export MC_TASK_ID MC_EVIDENCE_DIR MC_EVIDENCE_ABS
}

mc_set_task_context() {
  local task_id="$1"
  [[ -n "$task_id" ]] || return 0
  MC_TASK_ID="$task_id"
  MC_EVIDENCE_DIR="docs/TASKS/EVIDENCE/${task_id}"
  mc_refresh_evidence_abs
}

mc_prepare_task_context_from_args() {
  local task_id
  task_id="$(mc_parse_opt --task "$@" 2>/dev/null || true)"
  if [[ -n "$task_id" ]]; then
    mc_set_task_context "$task_id"
  fi
}

mc_now_ms() {
  python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

mc_now_iso() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

mc_slugify() {
  printf '%s' "$1" | tr ' /:' '---' | tr -cd '[:alnum:]-_' | sed -E 's/-+/-/g; s/^-//; s/-$//'
}

mc_relpath() {
  local path="$1"
  if [[ "$path" == "$MC_IOS_REPO/"* ]]; then
    printf '%s' "${path#$MC_IOS_REPO/}"
  else
    printf '%s' "$path"
  fi
}

mc_git_context() {
  local repo="${1:-$MC_IOS_REPO}"
  MC_ACTIVE_REPO="$repo"
  if [[ ! -d "$repo/.git" ]]; then
    MC_GIT_BRANCH="n/a"
    MC_GIT_SHA="n/a"
    MC_GIT_DIRTY="unknown"
    return 0
  fi
  MC_GIT_BRANCH="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  MC_GIT_SHA="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  if git -C "$repo" diff --quiet 2>/dev/null && git -C "$repo" diff --cached --quiet 2>/dev/null; then
    MC_GIT_DIRTY="clean"
  else
    MC_GIT_DIRTY="dirty"
  fi
}

mc_tool_path() {
  command -v "$1" 2>/dev/null || true
}

mc_require_tool() {
  local tool="$1"
  local path
  path="$(mc_tool_path "$tool")"
  [[ -n "$path" ]] || return 1
  printf '%s' "$path"
}

mc_parse_flag() {
  local name="$1"
  shift
  while [[ $# -gt 0 ]]; do
    [[ "$1" == "$name" ]] && return 0
    shift
  done
  return 1
}

mc_parse_opt() {
  local name="$1"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      "$name")
        [[ -n "${2:-}" ]] || return 1
        printf '%s' "$2"
        return 0
        ;;
      "$name="*)
        printf '%s' "${1#*=}"
        return 0
        ;;
    esac
    shift
  done
  return 1
}

mc_normalize_exit() {
  case "${1:-1}" in
    0|1|2|3|4) printf '%s' "$1" ;;
    *) printf '1' ;;
  esac
}

mc_validate_task_prefix() {
  local prefix="${1:-}"
  local require_offline="${2:-0}"
  if [[ -z "$prefix" ]]; then
    MC_SUMMARY="Prefix is required."
    MC_NEXT_ACTION="Retry with --prefix TASKNNN_* scoped to test data."
    return "$MC_EXIT_REFUSED"
  fi
  if [[ "$prefix" == *"%"* || "$prefix" == *"/"* || "$prefix" == *".."* || "$prefix" =~ [\;\|\&\`\$\<\>] ]]; then
    MC_SUMMARY="Unsafe prefix refused: ${prefix}"
    MC_NEXT_ACTION="Use a simple TASKNNN_ prefix with letters, digits, underscore, dash or literal *."
    return "$MC_EXIT_REFUSED"
  fi
  if [[ "$prefix" =~ ^(GLOBAL|ALL|PUBLIC|PROD|LIVE)_? ]]; then
    MC_SUMMARY="Global-looking prefix refused: ${prefix}"
    MC_NEXT_ACTION="Use TASKNNN_* scoped test data only."
    return "$MC_EXIT_REFUSED"
  fi
  if [[ ! "$prefix" =~ ^TASK[0-9]{3,}_[A-Za-z0-9_.*-]*$ ]]; then
    MC_SUMMARY="Prefix must match TASKNNN_* scoped pattern."
    MC_NEXT_ACTION="Example: --prefix TASK115_DRYRUN_ or --prefix 'TASK115_*'."
    return "$MC_EXIT_REFUSED"
  fi
  if [[ "$require_offline" == "1" && "$prefix" != *OFFLINE* ]]; then
    MC_SUMMARY="Offline prefix must contain OFFLINE."
    MC_NEXT_ACTION="Example: --prefix TASK115_OFFLINE_L2_"
    return "$MC_EXIT_REFUSED"
  fi
  return "$MC_EXIT_PASS"
}

mc_missing_prefix() {
  MC_SUMMARY="--prefix is required."
  MC_NEXT_ACTION="Retry with --prefix TASKNNN_* scoped to test data."
  return "$MC_EXIT_REFUSED"
}

mc_prefix_like() {
  local prefix="$1"
  prefix="${prefix//\*/%}"
  if [[ "$prefix" != *% ]]; then
    prefix="${prefix}%"
  fi
  printf '%s' "$prefix"
}

mc_lock_path() {
  local task="${1:-$MC_TASK_ID}"
  printf '%s' "$MC_IOS_REPO/docs/TASKS/EVIDENCE/${task}/agent-runs/.mc-agent-live.lock"
}

mc_acquire_live_lock() {
  local task="${1:-$MC_TASK_ID}"
  [[ "${MC_LOCK_HELD:-0}" == "1" ]] && return "$MC_EXIT_PASS"
  local lock
  lock="$(mc_lock_path "$task")"
  mkdir -p "$(dirname "$lock")"
  if [[ -f "$lock" ]]; then
    local lock_pid lock_ts lock_mtime now
    lock_pid="$(sed -n 's/^pid=\([0-9][0-9]*\).*/\1/p' "$lock" 2>/dev/null | head -1)"
    lock_ts="$(sed -n 's/.*timestamp=\([^ ]*\).*/\1/p' "$lock" 2>/dev/null | head -1)"
    if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -f "$lock"
    else
      now="$(date +%s)"
      lock_mtime="$(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null || echo "$now")"
      if (( now - lock_mtime >= ${MC_LOCK_STALE_SECONDS:-3600} )); then
        rm -f "$lock"
      else
        MC_SUMMARY="Live/cleanup lock is already held for ${task}."
        MC_NEXT_ACTION="Wait for pid=${lock_pid:-unknown} (${lock_ts:-unknown}) or inspect $(mc_relpath "$lock")."
        return "$MC_EXIT_BLOCKED"
      fi
    fi
  fi
  if ( set -o noclobber; printf 'pid=%s command=%s timestamp=%s\n' "$$" "${MC_COMMAND:-unknown}" "$(mc_now_iso)" > "$lock" ) 2>/dev/null; then
    MC_LOCK_HELD=1
    MC_LOCK_FILE="$lock"
    trap mc_release_live_lock EXIT INT TERM
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Live/cleanup lock is already held for ${task}."
  MC_NEXT_ACTION="Wait for the other mc-agent run to finish or inspect $(mc_relpath "$lock")."
  return "$MC_EXIT_BLOCKED"
}

mc_release_live_lock() {
  if [[ "${MC_LOCK_HELD:-0}" == "1" && -n "${MC_LOCK_FILE:-}" ]]; then
    rm -f "$MC_LOCK_FILE"
  fi
  MC_LOCK_HELD=0
  trap - EXIT INT TERM
}

mc_require_live() {
  if [[ "${MC_ALLOW_LIVE:-0}" != "1" ]]; then
    MC_SUMMARY="Live operation refused. MC_ALLOW_LIVE=1 is required."
    MC_NEXT_ACTION="Set MC_ALLOW_LIVE=1 only for intentional scoped live tests."
    return "$MC_EXIT_REFUSED"
  fi
  mc_acquire_live_lock "$MC_TASK_ID"
}

mc_require_cleanup_execute() {
  if [[ "${MC_ALLOW_CLEANUP:-0}" != "1" ]]; then
    MC_SUMMARY="Cleanup execute refused. MC_ALLOW_CLEANUP=1 is required."
    MC_NEXT_ACTION="Run cleanup dry-run first, then set MC_ALLOW_CLEANUP=1 with a matching cleanup_plan_id."
    return "$MC_EXIT_REFUSED"
  fi
  mc_acquire_live_lock "$MC_TASK_ID"
}

mc_set_pass_with_notes() {
  MC_RESULT_OVERRIDE="PASS_WITH_NOTES"
}

mc_task118_evidence_context_mismatch() {
  [[ "$MC_TASK_ID" == "TASK-118" && "$MC_EVIDENCE_DIR" != "docs/TASKS/EVIDENCE/TASK-118" ]]
}

mc_run_wrapped() {
  MC_COMMAND="$1"
  shift
  MC_PLATFORM="${MC_PLATFORM:-general}"
  MC_SAFETY_LEVEL="${MC_SAFETY_LEVEL:-safe-readonly}"
  MC_REQUIRES_LIVE="${MC_REQUIRES_LIVE:-false}"
  MC_REQUIRES_CLEANUP="${MC_REQUIRES_CLEANUP:-false}"
  MC_PROFILE="${MC_PROFILE:-null}"
  MC_ANDROID_OFFLINE_TIER="${MC_ANDROID_OFFLINE_TIER:-none}"
  MC_TIMESTAMP_START_ISO="$(mc_now_iso)"
  MC_START_MS="$(mc_now_ms)"
  mc_git_context "$MC_IOS_REPO"
  if mc_task118_evidence_context_mismatch; then
    local requested_evidence_dir end_ms duration_ms exit_code
    requested_evidence_dir="$MC_EVIDENCE_DIR"
    MC_EVIDENCE_DIR="docs/TASKS/EVIDENCE/TASK-118"
    mc_refresh_evidence_abs
    mc_report_init_paths
    mc_report_log "=== mc-agent ${MC_COMMAND} ==="
    exit_code="$MC_EXIT_MISCONFIGURED"
    end_ms="$(mc_now_ms)"
    duration_ms=$((end_ms - MC_START_MS))
    MC_TIMESTAMP_END_ISO="$(mc_now_iso)"
    MC_SUMMARY="TASK-118 evidence context MISCONFIGURED: requested evidence dir '${requested_evidence_dir}' is outside docs/TASKS/EVIDENCE/TASK-118."
    MC_NEXT_ACTION="Pass --task TASK-118 or set MC_TASK_ID=TASK-118 without overriding MC_EVIDENCE_DIR."
    mc_report_write "$exit_code" "$MC_SUMMARY" "$MC_NEXT_ACTION" "$duration_ms" 0 0 0 ""
    if [[ "${MC_QUIET:-0}" != "1" ]]; then
      mc_print_final_summary "$exit_code"
    fi
    return "$exit_code"
  fi
  mc_report_init_paths
  mc_report_log "=== mc-agent ${MC_COMMAND} ==="

  local raw_tmp exit_code end_ms duration_ms
  raw_tmp="$(mktemp)"
  "$@" > "$raw_tmp" 2>&1
  exit_code="$(mc_normalize_exit "$?")"
  if [[ -s "$raw_tmp" ]]; then
    mc_redact_file_to_stdout "$raw_tmp" >> "$MC_LOG_TMP"
  fi
  if [[ "${MC_VERBOSE:-0}" == "1" && "${MC_QUIET:-0}" != "1" ]]; then
    tail -20 "$MC_LOG_TMP" >&2 || true
  fi
  rm -f "$raw_tmp"

  end_ms="$(mc_now_ms)"
  duration_ms=$((end_ms - MC_START_MS))
  MC_TIMESTAMP_END_ISO="$(mc_now_iso)"
  MC_SUMMARY="${MC_SUMMARY:-Command completed with exit ${exit_code}.}"
  MC_NEXT_ACTION="${MC_NEXT_ACTION:-Review report.}"
  mc_report_write "$exit_code" "$MC_SUMMARY" "$MC_NEXT_ACTION" "$duration_ms" \
    "${MC_ROWS_CREATED:-0}" "${MC_ROWS_DELETED:-0}" "${MC_RESIDUE_COUNT:-0}" "${MC_TEST_PREFIX:-}"
  mc_release_live_lock
  if [[ "${MC_QUIET:-0}" != "1" ]]; then
    mc_print_final_summary "$exit_code"
  fi
  return "$exit_code"
}

mc_help_text() {
  cat <<'HELP'
mc-agent.sh — agent-friendly CLI harness for iOS/Android/Supabase

Usage:
  ./tools/agent/mc-agent.sh help | help-json | version
  ./tools/agent/mc-agent.sh doctor | preflight [--require-head-consistency] | harness doctor | config validate | config print-redacted
  ./tools/agent/mc-agent.sh list commands | list commands-json
  ./tools/agent/mc-agent.sh git head-consistency --task TASK-118
  ./tools/agent/mc-agent.sh report --task <TASK-ID> | report --latest | report validate-json --task <TASK-ID> --path <file-or-dir>
  ./tools/agent/mc-agent.sh scan sensitive [path...] | scan evidence --task <TASK-ID> | scan repo-diff | scan release-cta | scan no-legacy-runtime-path --task TASK-117
  ./tools/agent/mc-agent.sh scan sync-boundaries --task TASK-118 --strict
  ./tools/agent/mc-agent.sh scan no-full-pull-normal-path --task TASK-118 --strict
  ./tools/agent/mc-agent.sh scan sync-architecture|manual-boundary|dead-code|xcode-membership|no-full-pull-normal-path --task TASK-119 --strict
  ./tools/agent/mc-agent.sh scan task-docs|harness-routing|harness-health|source-format|duplicate-symbols|automatic-legacy-monolith|mainactor-boundary|swiftdata-context-boundary|manual-root-residue|master-plan-consistency|mcp-wrapper|scanner-self-tests|status-taxonomy|evidence-metadata --task TASK-120 --strict
  ./tools/agent/mc-agent.sh scan sync-architecture|manual-boundary|dead-code|xcode-membership --task TASK-120 --strict
  ./tools/agent/mc-agent.sh scan no-root-supabase-legacy|no-automatic-manual-dependency|transport-thin-only|remote-adapter-single-domain|no-full-pull-normal-path|no-hidden-manual-sync|no-stale-pbxproj-reference|no-mainactor-heavy-sync|no-service-role-client|no-rls-bypass|source-format|dead-code-residue --task TASK-124 --strict
  ./tools/agent/mc-agent.sh scan no-hidden-manual-sync|no-full-pull-normal-path|no-service-role-client|no-rls-bypass|no-mainactor-heavy-sync|no-stale-pbxproj-reference|no-test-fixture-in-app-target|no-root-legacy-sync-service|remote-adapter-single-domain|background-task-registration|background-task-no-ui-context|outbox-pending-survives-restart|evidence-redaction|source-format|dead-code-residue --task TASK-125 --strict
  ./tools/agent/mc-agent.sh scan task126-policy-matrix|owner-store-scope|local-store-identity|pending-base-version|changed-fields-contract|no-cross-owner-store-pending-push|conflict-review-coverage|productprice-history-policy|cache-active-store-only|inactive-cache-cleanup-safety|task126-final-gates --task TASK-126 --strict
  ./tools/agent/mc-agent.sh scan options-mainactor-heavy-fetch|productprice-full-fetch-mainactor|options-refresh-debounce|task127-debug-hook-release-safety|task127-final-gates --task TASK-127 --strict
  ./tools/agent/mc-agent.sh scan price-contract|swiftdata-fetch-budget --task TASK-130 --strict
  ./tools/agent/mc-agent.sh harness golden-corpus validate|roundtrip --task TASK-130
  ./tools/agent/mc-agent.sh harness real-device-feasibility --task TASK-130
  ./tools/agent/mc-agent.sh ios test options-summary-performance|options-summary-provider --task TASK-127
  ./tools/agent/mc-agent.sh ios test price-contract --task TASK-130
  ./tools/agent/mc-agent.sh ios benchmark import-large --task TASK-130
  ./tools/agent/mc-agent.sh ios smoke options-first-sync|scanner-edge|accessibility --task TASK-130
  ./tools/agent/mc-agent.sh ios smoke options-performance --task TASK-127
  ./tools/agent/mc-agent.sh android audit options-performance --task TASK-127
  ./tools/agent/mc-agent.sh ios test sync-policy|account-store-boundary|conflict-review|conflict-review-ui|account-switch-review-ui|cache-memory --task TASK-126
  ./tools/agent/mc-agent.sh ios smoke conflict-review-ui|account-switch-review-ui --task TASK-126
  ./tools/agent/mc-agent.sh android test sync-policy|account-store-boundary|conflict-review|conflict-review-ui|account-switch-review-ui|cache-memory --task TASK-126
  ./tools/agent/mc-agent.sh android smoke conflict-review-ui|account-switch-review-ui --task TASK-126
  ./tools/agent/mc-agent.sh scan no-full-pull-normal-path|automatic-contracts-clean|root-host-clean|options-observer-only|duplicate-sync-owner|incremental-apply-contract|swiftdata-mainactor-heavy|l10n-sync-keys --task TASK-117
  ./tools/agent/mc-agent.sh evidence hygiene|bundle --task TASK-117
  ./tools/agent/mc-agent.sh account fixture prepare|cleanup --task TASK-116 --prefix TASK116_ACCOUNT_ [--dry-run]
  ./tools/agent/mc-agent.sh safety check-prefix --prefix TASK115_* | safety dry-run-required --command "<command>"
  ./tools/agent/mc-agent.sh ios build debug|release | ios test sync|automatic-domain|automatic-architecture|lifecycle|offline | ios smoke simulator|options|history
  MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios live-full-pull --live --task TASK-115
  MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios runtime-ui-counts --live --task TASK-115
  ./tools/agent/mc-agent.sh android build debug|release | android test sync|offline|broad|quarantine-report|price-contract | android offline-tier-status
  MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh android live-full-pull --live
  ./tools/agent/mc-agent.sh android offline-write|reconnect-drain --tier L1|L2|L3 --prefix TASK115_OFFLINE_*
  ./tools/agent/mc-agent.sh sync counts --task TASK-115 --source supabase|android|ios [--profile linked]
  ./tools/agent/mc-agent.sh supabase status-redacted|verify-schema|verify-rls|verify-grants|residue-check --profile local|linked|dry-run-no-db
  ./tools/agent/mc-agent.sh supabase contract sync-schema --task TASK-120 --read-only
  ./tools/agent/mc-agent.sh supabase contract price-schema --task TASK-130 --read-only
  ./tools/agent/mc-agent.sh live sync-matrix|runtime-parity|physical-runtime-parity|mutation-near-realtime|offline-reconnect-sync|account-merge-policy-matrix|sync-performance-budget|offline-matrix|reconcile-counts|cleanup-and-verify --task TASK-115 --prefix TASK115_*
  MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live real-device-realtime|real-device-offline-reconnect|real-device-background-sync|real-device-kill-restart-pending|real-device-network-flapping --task TASK-125 --prefix TASK125_*
  MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live task123-single-propagation|task123-cold-restart|task123-noop|task123-burst-10 --task TASK-123 --prefix TASK123_REVIEW_*

Exit codes: 0=PASS 1=FAIL 2=BLOCKED_EXTERNAL 3=MISCONFIGURED 4=UNSAFE_OPERATION_REFUSED
Reports: docs/TASKS/EVIDENCE/<task>/agent-runs/<timestamp>-<command>.{log,md,json}
HELP
}

mc_help_json() {
  cat <<'JSON'
{
  "schema_version": "1.1",
  "name": "mc-agent",
  "version": "0.5.5-task130-consolidated",
  "exit_codes": {
    "0": "PASS",
    "1": "FAIL",
    "2": "BLOCKED_EXTERNAL",
    "3": "MISCONFIGURED",
    "4": "UNSAFE_OPERATION_REFUSED"
  },
  "commands": [
    {"name":"help","argv":["help"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"help-json","argv":["help-json"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"version","argv":["version"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"doctor","argv":["doctor"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"harness doctor","argv":["harness","doctor"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"preflight","argv":["preflight"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"preflight require head consistency","argv":["preflight","--require-head-consistency","--task","TASK-118"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"git head-consistency","argv":["git","head-consistency","--task","TASK-118"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"git head-consistency task122","argv":["git","head-consistency","--task","TASK-122"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"config validate","argv":["config","validate"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"config validate task122","argv":["config","validate","--task","TASK-122"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"config print-redacted","argv":["config","print-redacted"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"list commands","argv":["list","commands"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"list commands-json","argv":["list","commands-json"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report --task","argv":["report","--task","TASK-115"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report --latest","argv":["report","--latest"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report validate-json","argv":["report","validate-json","--path","<file>"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report validate-json task118","argv":["report","validate-json","--task","TASK-118","--path","docs/TASKS/EVIDENCE/TASK-118/agent-runs"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report validate-json task120","argv":["report","validate-json","--task","TASK-120","--path","docs/TASKS/EVIDENCE/TASK-120/agent-runs"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan sensitive","argv":["scan","sensitive"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan evidence","argv":["scan","evidence","--task","TASK-115"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan repo-diff","argv":["scan","repo-diff"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan release-cta","argv":["scan","release-cta"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan task126-policy-matrix","argv":["scan","task126-policy-matrix","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan owner-store-scope task126","argv":["scan","owner-store-scope","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan local-store-identity task126","argv":["scan","local-store-identity","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan pending-base-version task126","argv":["scan","pending-base-version","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan changed-fields-contract task126","argv":["scan","changed-fields-contract","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-cross-owner-store-pending-push task126","argv":["scan","no-cross-owner-store-pending-push","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan conflict-review-coverage task126","argv":["scan","conflict-review-coverage","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan productprice-history-policy task126","argv":["scan","productprice-history-policy","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan cache-active-store-only task126","argv":["scan","cache-active-store-only","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan inactive-cache-cleanup-safety task126","argv":["scan","inactive-cache-cleanup-safety","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan task126-final-gates","argv":["scan","task126-final-gates","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan scanner-self-tests task126","argv":["scan","scanner-self-tests","--task","TASK-126","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan options-mainactor-heavy-fetch task127","argv":["scan","options-mainactor-heavy-fetch","--task","TASK-127","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan productprice-full-fetch-mainactor task127","argv":["scan","productprice-full-fetch-mainactor","--task","TASK-127","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan options-refresh-debounce task127","argv":["scan","options-refresh-debounce","--task","TASK-127","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan task127-debug-hook-release-safety","argv":["scan","task127-debug-hook-release-safety","--task","TASK-127","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan task127-final-gates","argv":["scan","task127-final-gates","--task","TASK-127","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan scanner-self-tests task127","argv":["scan","scanner-self-tests","--task","TASK-127","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"ios test options-summary-performance task127","argv":["ios","test","options-summary-performance","--task","TASK-127"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test options-summary-provider task127","argv":["ios","test","options-summary-provider","--task","TASK-127"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke options-performance task127","argv":["ios","smoke","options-performance","--task","TASK-127"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"android audit options-performance task127","argv":["android","audit","options-performance","--task","TASK-127"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"ios test sync-policy task126","argv":["ios","test","sync-policy","--task","TASK-126"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test account-store-boundary task126","argv":["ios","test","account-store-boundary","--task","TASK-126"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test conflict-review task126","argv":["ios","test","conflict-review","--task","TASK-126"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test conflict-review-ui task126","argv":["ios","test","conflict-review-ui","--task","TASK-126"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test account-switch-review-ui task126","argv":["ios","test","account-switch-review-ui","--task","TASK-126"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke conflict-review-ui task126","argv":["ios","smoke","conflict-review-ui","--task","TASK-126"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke account-switch-review-ui task126","argv":["ios","smoke","account-switch-review-ui","--task","TASK-126"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test cache-memory task126","argv":["ios","test","cache-memory","--task","TASK-126"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"android test sync-policy task126","argv":["android","test","sync-policy","--task","TASK-126"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test account-store-boundary task126","argv":["android","test","account-store-boundary","--task","TASK-126"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test conflict-review task126","argv":["android","test","conflict-review","--task","TASK-126"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test conflict-review-ui task126","argv":["android","test","conflict-review-ui","--task","TASK-126"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test account-switch-review-ui task126","argv":["android","test","account-switch-review-ui","--task","TASK-126"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android smoke conflict-review-ui task126","argv":["android","smoke","conflict-review-ui","--task","TASK-126"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android smoke account-switch-review-ui task126","argv":["android","smoke","account-switch-review-ui","--task","TASK-126"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test cache-memory task126","argv":["android","test","cache-memory","--task","TASK-126"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"scan sync-boundaries","argv":["scan","sync-boundaries","--task","TASK-118","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-full-pull-normal-path task118","argv":["scan","no-full-pull-normal-path","--task","TASK-118","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan sync-architecture task119","argv":["scan","sync-architecture","--task","TASK-119","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan manual-boundary task119","argv":["scan","manual-boundary","--task","TASK-119","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan dead-code task119","argv":["scan","dead-code","--task","TASK-119","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan xcode-membership task119","argv":["scan","xcode-membership","--task","TASK-119","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-full-pull-normal-path task119","argv":["scan","no-full-pull-normal-path","--task","TASK-119","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan task-docs task120","argv":["scan","task-docs","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan harness-routing task120","argv":["scan","harness-routing","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan harness-health task120","argv":["scan","harness-health","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan source-format task120","argv":["scan","source-format","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan duplicate-symbols task120","argv":["scan","duplicate-symbols","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan automatic-legacy-monolith task120","argv":["scan","automatic-legacy-monolith","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan mainactor-boundary task120","argv":["scan","mainactor-boundary","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan swiftdata-context-boundary task120","argv":["scan","swiftdata-context-boundary","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan manual-root-residue task120","argv":["scan","manual-root-residue","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan master-plan-consistency task120","argv":["scan","master-plan-consistency","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan mcp-wrapper task120","argv":["scan","mcp-wrapper","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan scanner-self-tests task120","argv":["scan","scanner-self-tests","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan status-taxonomy task120","argv":["scan","status-taxonomy","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan evidence-metadata task120","argv":["scan","evidence-metadata","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan sync-architecture task120","argv":["scan","sync-architecture","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan manual-boundary task120","argv":["scan","manual-boundary","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan dead-code task120","argv":["scan","dead-code","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan xcode-membership task120","argv":["scan","xcode-membership","--task","TASK-120","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report validate-json task121","argv":["report","validate-json","--task","TASK-121","--path","docs/TASKS/EVIDENCE/TASK-121/agent-runs"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan task-docs task121","argv":["scan","task-docs","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan master-plan-consistency task121","argv":["scan","master-plan-consistency","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan harness-routing task121","argv":["scan","harness-routing","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan harness-health task121","argv":["scan","harness-health","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan mcp-wrapper task121","argv":["scan","mcp-wrapper","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan status-taxonomy task121","argv":["scan","status-taxonomy","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan evidence-metadata task121","argv":["scan","evidence-metadata","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan scanner-self-tests task121","argv":["scan","scanner-self-tests","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan source-format task121","argv":["scan","source-format","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan sync-inventory task121","argv":["scan","sync-inventory","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan sync-architecture task121","argv":["scan","sync-architecture","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan retry-ownership task121","argv":["scan","retry-ownership","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan manual-boundary task121","argv":["scan","manual-boundary","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan root-residue task121","argv":["scan","root-residue","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan shared-purity task121","argv":["scan","shared-purity","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan dead-code task121","argv":["scan","dead-code","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan xcode-membership task121","argv":["scan","xcode-membership","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan duplicate-symbols task121","argv":["scan","duplicate-symbols","--task","TASK-121","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report validate-json task122","argv":["report","validate-json","--task","TASK-122","--path","docs/TASKS/EVIDENCE/TASK-122/agent-runs"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"preflight require head consistency task122","argv":["preflight","--require-head-consistency","--task","TASK-122"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan task-docs task122","argv":["scan","task-docs","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan master-plan-consistency task122","argv":["scan","master-plan-consistency","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan evidence-metadata task122","argv":["scan","evidence-metadata","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan harness-routing task122","argv":["scan","harness-routing","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan harness-health task122","argv":["scan","harness-health","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan mcp-wrapper task122","argv":["scan","mcp-wrapper","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan status-taxonomy task122","argv":["scan","status-taxonomy","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan scanner-self-tests task122","argv":["scan","scanner-self-tests","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan source-format task122","argv":["scan","source-format","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan swift-source-shape task122","argv":["scan","swift-source-shape","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan sync-inventory task122","argv":["scan","sync-inventory","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan sync-architecture task122","argv":["scan","sync-architecture","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan remote-transport-thin task122","argv":["scan","remote-transport-thin","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan adapter-delegation-depth task122","argv":["scan","adapter-delegation-depth","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan domain-method-ownership task122","argv":["scan","domain-method-ownership","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan manual-debug-boundary task122","argv":["scan","manual-debug-boundary","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan transport-protocol-conformance task122","argv":["scan","transport-protocol-conformance","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan composition-import-boundary task122","argv":["scan","composition-import-boundary","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan remote-query-ownership task122","argv":["scan","remote-query-ownership","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan debug-seed-boundary task122","argv":["scan","debug-seed-boundary","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan dto-mapper-duplication task122","argv":["scan","dto-mapper-duplication","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan supabase-query-map task122","argv":["scan","supabase-query-map","--task","TASK-122","--strict","--read-only"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan supabase-query-map task122 strict","argv":["scan","supabase-query-map","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan transport-callsite-map task122","argv":["scan","transport-callsite-map","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan protocol-conformance-map task122","argv":["scan","protocol-conformance-map","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan supabase-contract-map task122","argv":["scan","supabase-contract-map","--task","TASK-122","--strict","--read-only"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan supabase-contract-map task122 strict","argv":["scan","supabase-contract-map","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan android-parity-ledger task122","argv":["scan","android-parity-ledger","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan performance-baseline task122","argv":["scan","performance-baseline","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan offline-outbox-conflict task122","argv":["scan","offline-outbox-conflict","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan xcode-membership task122","argv":["scan","xcode-membership","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan dead-code task122","argv":["scan","dead-code","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan sensitive task122","argv":["scan","sensitive","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan evidence task122","argv":["scan","evidence","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan sync-efficiency-acceptance task122","argv":["scan","sync-efficiency-acceptance","--task","TASK-122","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"ios build debug task122","argv":["ios","build","debug","--task","TASK-122"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios build release task122","argv":["ios","build","release","--task","TASK-122"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"report validate-json task124","argv":["report","validate-json","--task","TASK-124","--path","docs/TASKS/EVIDENCE/TASK-124/agent-runs"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"preflight require head consistency task124","argv":["preflight","--require-head-consistency","--task","TASK-124"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan automation-discovery task124","argv":["scan","automation-discovery","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan harness-routing task124","argv":["scan","harness-routing","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan scanner-self-tests task124","argv":["scan","scanner-self-tests","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-root-supabase-legacy task124","argv":["scan","no-root-supabase-legacy","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-automatic-manual-dependency task124","argv":["scan","no-automatic-manual-dependency","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan transport-thin-only task124","argv":["scan","transport-thin-only","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan remote-adapter-single-domain task124","argv":["scan","remote-adapter-single-domain","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-full-pull-normal-path task124","argv":["scan","no-full-pull-normal-path","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-hidden-manual-sync task124","argv":["scan","no-hidden-manual-sync","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-stale-pbxproj-reference task124","argv":["scan","no-stale-pbxproj-reference","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-mainactor-heavy-sync task124","argv":["scan","no-mainactor-heavy-sync","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-service-role-client task124","argv":["scan","no-service-role-client","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-rls-bypass task124","argv":["scan","no-rls-bypass","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan source-format task124","argv":["scan","source-format","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan dead-code-residue task124","argv":["scan","dead-code-residue","--task","TASK-124","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-legacy-runtime-path","argv":["scan","no-legacy-runtime-path","--task","TASK-116"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-full-pull-normal-path","argv":["scan","no-full-pull-normal-path","--task","TASK-117"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan automatic-contracts-clean","argv":["scan","automatic-contracts-clean","--task","TASK-117"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan root-host-clean","argv":["scan","root-host-clean","--task","TASK-117"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan options-observer-only","argv":["scan","options-observer-only","--task","TASK-117"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan duplicate-sync-owner","argv":["scan","duplicate-sync-owner","--task","TASK-117"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan incremental-apply-contract","argv":["scan","incremental-apply-contract","--task","TASK-117"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan swiftdata-mainactor-heavy","argv":["scan","swiftdata-mainactor-heavy","--task","TASK-117"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan l10n-sync-keys","argv":["scan","l10n-sync-keys","--task","TASK-117"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan price-contract task130","argv":["scan","price-contract","--task","TASK-130","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan swiftdata-fetch-budget task130","argv":["scan","swiftdata-fetch-budget","--task","TASK-130","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"harness golden-corpus validate task130","argv":["harness","golden-corpus","validate","--task","TASK-130"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"harness golden-corpus roundtrip task130","argv":["harness","golden-corpus","roundtrip","--task","TASK-130"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"harness real-device-feasibility task130","argv":["harness","real-device-feasibility","--task","TASK-130"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"evidence hygiene","argv":["evidence","hygiene","--task","TASK-116"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"evidence bundle","argv":["evidence","bundle","--task","TASK-117"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"account fixture prepare","argv":["account","fixture","prepare","--task","TASK-116","--prefix","TASK116_ACCOUNT_","--dry-run"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"account fixture cleanup","argv":["account","fixture","cleanup","--task","TASK-116","--prefix","TASK116_ACCOUNT_"],"platform":"general","safety_level":"cleanup-dry-run"},
    {"name":"safety check-prefix","argv":["safety","check-prefix","--prefix","TASK115_*"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"safety dry-run-required","argv":["safety","dry-run-required","--command","<command>"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"ios build debug","argv":["ios","build","debug"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios build release","argv":["ios","build","release"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test sync","argv":["ios","test","sync"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test automatic-domain","argv":["ios","test","automatic-domain","--task","TASK-118"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test automatic-architecture","argv":["ios","test","automatic-architecture","--task","TASK-119"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test automatic-domain task120","argv":["ios","test","automatic-domain","--task","TASK-120"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test automatic-architecture task120","argv":["ios","test","automatic-architecture","--task","TASK-120"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test automatic-domain task121","argv":["ios","test","automatic-domain","--task","TASK-121"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test automatic-architecture task121","argv":["ios","test","automatic-architecture","--task","TASK-121"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test sync task121","argv":["ios","test","sync","--task","TASK-121"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test manual-sync-regression task121","argv":["ios","test","manual-sync-regression","--task","TASK-121"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test price-contract task130","argv":["ios","test","price-contract","--task","TASK-130"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios benchmark import-large task130","argv":["ios","benchmark","import-large","--task","TASK-130"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke options-first-sync task130","argv":["ios","smoke","options-first-sync","--task","TASK-130"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke scanner-edge task130","argv":["ios","smoke","scanner-edge","--task","TASK-130"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke accessibility task130","argv":["ios","smoke","accessibility","--task","TASK-130"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test lifecycle","argv":["ios","test","lifecycle"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test offline","argv":["ios","test","offline"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke simulator","argv":["ios","smoke","simulator"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke options","argv":["ios","smoke","options"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke history","argv":["ios","smoke","history"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios auth-preflight","argv":["ios","auth-preflight","--live"],"platform":"ios","safety_level":"live-write","requires_live":true},
    {"name":"ios live-write","argv":["ios","live-write","--prefix","TASK115_*"],"platform":"ios","safety_level":"live-write","requires_live":true},
    {"name":"ios live-full-pull","argv":["ios","live-full-pull","--live","--task","TASK-115"],"platform":"ios","safety_level":"live-write","requires_live":true},
    {"name":"ios runtime-ui-counts","argv":["ios","runtime-ui-counts","--live","--task","TASK-115"],"platform":"ios","safety_level":"live-write","requires_live":true},
    {"name":"ios physical-runtime-counts","argv":["ios","physical-runtime-counts","--live","--task","TASK-115"],"platform":"ios","safety_level":"live-readonly","requires_live":true},
    {"name":"ios physical-auth-store-diagnostics","argv":["ios","physical-auth-store-diagnostics","--live","--task","TASK-115"],"platform":"ios","safety_level":"live-readonly","requires_live":true},
    {"name":"ios physical-sync-acceptance","argv":["ios","physical-sync-acceptance","--live","--task","TASK-115"],"platform":"ios","safety_level":"live-readonly","requires_live":true},
    {"name":"ios cleanup-scoped","argv":["ios","cleanup-scoped","--prefix","TASK115_*","--dry-run"],"platform":"ios","safety_level":"cleanup-dry-run"},
    {"name":"android build debug","argv":["android","build","debug"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android build release","argv":["android","build","release"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test sync","argv":["android","test","sync"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test offline","argv":["android","test","offline"],"platform":"android","safety_level":"safe-readonly","android_offline_tier":"L1"},
    {"name":"android test broad task129","argv":["android","test","broad","--task","TASK-129"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test quarantine-report task129","argv":["android","test","quarantine-report","--task","TASK-129"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test price-contract task130","argv":["android","test","price-contract","--task","TASK-130"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android smoke device","argv":["android","smoke","device"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android smoke options","argv":["android","smoke","options"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android auth-preflight","argv":["android","auth-preflight","--live"],"platform":"android","safety_level":"live-write","requires_live":true},
    {"name":"android live-pull","argv":["android","live-pull","--prefix","TASK115_*"],"platform":"android","safety_level":"live-write","requires_live":true},
    {"name":"android live-write","argv":["android","live-write","--prefix","TASK115_*"],"platform":"android","safety_level":"live-write","requires_live":true},
    {"name":"android live-full-pull","argv":["android","live-full-pull","--live"],"platform":"android","safety_level":"live-write","requires_live":true},
    {"name":"android offline-tier-status","argv":["android","offline-tier-status"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android offline-write","argv":["android","offline-write","--tier","L1","--prefix","TASK115_OFFLINE_*"],"platform":"android","safety_level":"safe-readonly","android_offline_tier":"L1"},
    {"name":"android reconnect-drain","argv":["android","reconnect-drain","--tier","L1","--prefix","TASK115_OFFLINE_*"],"platform":"android","safety_level":"safe-readonly","android_offline_tier":"L1"},
    {"name":"sync counts","argv":["sync","counts","--task","TASK-115","--source","supabase","--profile","linked"],"platform":"sync","safety_level":"safe-readonly"},
    {"name":"supabase start","argv":["supabase","start"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase status-redacted","argv":["supabase","status-redacted"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase contract sync-schema task120","argv":["supabase","contract","sync-schema","--task","TASK-120","--read-only"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase contract sync-schema task121","argv":["supabase","contract","sync-schema","--task","TASK-121","--read-only"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase contract price-schema task130","argv":["supabase","contract","price-schema","--task","TASK-130","--read-only"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase verify-schema","argv":["supabase","verify-schema"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase verify-rls","argv":["supabase","verify-rls"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase verify-grants","argv":["supabase","verify-grants"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase verify-rpc","argv":["supabase","verify-rpc"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase verify-realtime","argv":["supabase","verify-realtime"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase explain-cleanup","argv":["supabase","explain-cleanup","--prefix","TASK115_*"],"platform":"supabase","safety_level":"cleanup-dry-run"},
    {"name":"supabase cleanup dry-run","argv":["supabase","cleanup","--task","TASK-115","--prefix","TASK115_*","--dry-run"],"platform":"supabase","safety_level":"cleanup-dry-run","requires_cleanup":true},
    {"name":"supabase cleanup execute","argv":["supabase","cleanup","--task","TASK-115","--prefix","TASK115_*","--execute","--cleanup-plan-id","<id>"],"platform":"supabase","safety_level":"cleanup-execute","requires_cleanup":true},
    {"name":"supabase residue-check","argv":["supabase","residue-check","--prefix","TASK115_*","--profile","dry-run-no-db"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase pooler-cooldown-check","argv":["supabase","pooler-cooldown-check"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"live sync-matrix","argv":["live","sync-matrix","--task","TASK-115","--prefix","TASK115_FINAL_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live reconcile-counts","argv":["live","reconcile-counts","--task","TASK-115","--prefix","TASK115_RECON_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live runtime-parity","argv":["live","runtime-parity","--task","TASK-115","--prefix","TASK115_RUNTIME_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live physical-runtime-parity","argv":["live","physical-runtime-parity","--task","TASK-115","--prefix","TASK115_PHYSICAL_*"],"platform":"live","safety_level":"live-readonly","requires_live":true},
    {"name":"live mutation-near-realtime","argv":["live","mutation-near-realtime","--task","TASK-115","--prefix","TASK115_REALTIME_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live offline-reconnect-sync","argv":["live","offline-reconnect-sync","--task","TASK-115","--prefix","TASK115_OFFLINE_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live account-merge-policy-matrix","argv":["live","account-merge-policy-matrix","--task","TASK-115","--prefix","TASK115_ACCOUNT_*"],"platform":"live","safety_level":"live-readonly","requires_live":true},
    {"name":"live sync-performance-budget","argv":["live","sync-performance-budget","--task","TASK-115","--prefix","TASK115_PERF_*"],"platform":"live","safety_level":"live-readonly","requires_live":true},
    {"name":"live offline-matrix","argv":["live","offline-matrix","--task","TASK-115","--prefix","TASK115_OFFLINE_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live cleanup-and-verify","argv":["live","cleanup-and-verify","--task","TASK-115","--prefix","TASK115_*"],"platform":"live","safety_level":"cleanup-execute","requires_cleanup":true},
    {"name":"live task123-single-propagation","argv":["live","task123-single-propagation","--task","TASK-123","--prefix","TASK123_REVIEW_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live task123-cold-restart","argv":["live","task123-cold-restart","--task","TASK-123","--prefix","TASK123_REVIEW_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live task123-noop","argv":["live","task123-noop","--task","TASK-123","--prefix","TASK123_REVIEW_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live task123-burst-10","argv":["live","task123-burst-10","--task","TASK-123","--prefix","TASK123_REVIEW_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"preflight task125","argv":["preflight","--task","TASK-125"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"git head-consistency task125","argv":["git","head-consistency","--task","TASK-125"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report validate-json task125","argv":["report","validate-json","--task","TASK-125","--path","docs/TASKS/EVIDENCE/TASK-125/agent-runs"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-hidden-manual-sync task125","argv":["scan","no-hidden-manual-sync","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-full-pull-normal-path task125","argv":["scan","no-full-pull-normal-path","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-service-role-client task125","argv":["scan","no-service-role-client","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-rls-bypass task125","argv":["scan","no-rls-bypass","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-mainactor-heavy-sync task125","argv":["scan","no-mainactor-heavy-sync","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-stale-pbxproj-reference task125","argv":["scan","no-stale-pbxproj-reference","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-test-fixture-in-app-target task125","argv":["scan","no-test-fixture-in-app-target","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan no-root-legacy-sync-service task125","argv":["scan","no-root-legacy-sync-service","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan remote-adapter-single-domain task125","argv":["scan","remote-adapter-single-domain","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan background-task-registration task125","argv":["scan","background-task-registration","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan background-task-no-ui-context task125","argv":["scan","background-task-no-ui-context","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan outbox-pending-survives-restart task125","argv":["scan","outbox-pending-survives-restart","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan evidence-redaction task125","argv":["scan","evidence-redaction","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan source-format task125","argv":["scan","source-format","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan dead-code-residue task125","argv":["scan","dead-code-residue","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan task125-final-gates","argv":["scan","task125-final-gates","--task","TASK-125","--strict"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"ios device-auth-preflight task125","argv":["ios","device-auth-preflight","--live","--task","TASK-125"],"platform":"ios","safety_level":"live-readonly","requires_live":true},
    {"name":"android auth-preflight task125","argv":["android","auth-preflight","--live","--task","TASK-125"],"platform":"android","safety_level":"live-write","requires_live":true},
    {"name":"live real-device-realtime task125","argv":["live","real-device-realtime","--task","TASK-125","--prefix","TASK125_RT_"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live real-device-offline-reconnect task125","argv":["live","real-device-offline-reconnect","--task","TASK-125","--prefix","TASK125_OFFLINE_"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live real-device-background-sync task125","argv":["live","real-device-background-sync","--task","TASK-125","--prefix","TASK125_BG_"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live real-device-kill-restart-pending task125","argv":["live","real-device-kill-restart-pending","--task","TASK-125","--prefix","TASK125_RESTART_"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live real-device-network-flapping task125","argv":["live","real-device-network-flapping","--task","TASK-125","--prefix","TASK125_FLAP_"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live runtime-parity task125","argv":["live","runtime-parity","--task","TASK-125","--prefix","TASK125_PARITY_","--profile","linked"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"supabase cleanup task125","argv":["supabase","cleanup","--task","TASK-125","--prefix","TASK125_"],"platform":"supabase","safety_level":"cleanup-dry-run","requires_cleanup":true},
    {"name":"supabase residue-check task125","argv":["supabase","residue-check","--task","TASK-125","--prefix","TASK125_"],"platform":"supabase","safety_level":"safe-readonly"}
  ]
}
JSON
}

mc_cmd_version() {
  MC_SUMMARY="mc-agent ${MC_AGENT_VERSION}; report schema ${MC_SCHEMA_VERSION}"
  MC_NEXT_ACTION="Run help-json or preflight."
  printf 'mc-agent %s\nreport_schema %s\n' "$MC_AGENT_VERSION" "$MC_SCHEMA_VERSION"
  return "$MC_EXIT_PASS"
}

mc_cmd_config() {
  local sub="${1:-}"
  case "$sub" in
    validate)
      local bad=0
      [[ -d "$MC_IOS_REPO" ]] || bad=$((bad + 1))
      [[ -d "$MC_ANDROID_REPO" ]] || bad=$((bad + 1))
      [[ -d "$MC_SUPABASE_REPO" ]] || bad=$((bad + 1))
      [[ "$MC_TASK_ID" =~ ^TASK-[0-9]{3,}$ ]] || bad=$((bad + 1))
      if [[ "$bad" -gt 0 ]]; then
        MC_SUMMARY="Config validation found ${bad} missing/invalid value(s)."
        MC_NEXT_ACTION="Edit tools/agent/config.env or set MC_* env vars."
        return "$MC_EXIT_MISCONFIGURED"
      fi
      MC_SUMMARY="Config validation PASS for ${MC_TASK_ID}."
      MC_NEXT_ACTION="Run preflight."
      return "$MC_EXIT_PASS"
      ;;
    print-redacted)
      {
        printf 'MC_IOS_REPO=%s\n' "$MC_IOS_REPO"
        printf 'MC_ANDROID_REPO=%s\n' "$MC_ANDROID_REPO"
        printf 'MC_SUPABASE_REPO=%s\n' "$MC_SUPABASE_REPO"
        printf 'MC_TASK_ID=%s\n' "$MC_TASK_ID"
        printf 'MC_EVIDENCE_DIR=%s\n' "$MC_EVIDENCE_DIR"
        printf 'MC_IOS_SCHEME=%s\n' "${MC_IOS_SCHEME:-}"
        printf 'MC_IOS_DESTINATION=%s\n' "${MC_IOS_DESTINATION:-}"
        printf 'MC_IOS_DEVICE_UDID=%s\n' "$(mc_redact_text "${MC_IOS_DEVICE_UDID:-}")"
        printf 'MC_ANDROID_DEVICE_SERIAL=%s\n' "$(mc_redact_text "${MC_ANDROID_DEVICE_SERIAL:-}")"
        printf 'MC_SUPABASE_PROFILE=%s\n' "${MC_SUPABASE_PROFILE:-}"
        printf 'MC_ALLOW_LIVE=%s\n' "${MC_ALLOW_LIVE:-0}"
        printf 'MC_ALLOW_CLEANUP=%s\n' "${MC_ALLOW_CLEANUP:-0}"
      }
      MC_SUMMARY="Config printed with redaction."
      MC_NEXT_ACTION="Run config validate or preflight."
      return "$MC_EXIT_PASS"
      ;;
    *)
      MC_SUMMARY="Unknown config subcommand: ${sub}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_list() {
  local sub="${1:-commands}"
  case "$sub" in
    commands)
      mc_help_json | python3 -c '
import json, os, sys
data = json.load(sys.stdin)
for c in data["commands"]:
    print(c["name"])
'
      MC_SUMMARY="Listed canonical commands."
      MC_NEXT_ACTION="Run a listed command."
      return "$MC_EXIT_PASS"
      ;;
    commands-json)
      mc_help_json
      MC_SUMMARY="Listed canonical commands as JSON."
      MC_NEXT_ACTION="Use help-json as MCP contract."
      return "$MC_EXIT_PASS"
      ;;
    *)
      MC_SUMMARY="Unknown list subcommand: ${sub}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_git_github_url_from_origin() {
  local remote_url="$1"
  python3 - "$remote_url" <<'PY'
import re
import sys

value = sys.argv[1].strip()
if value.endswith(".git"):
    value = value[:-4]
if value.startswith("git@github.com:"):
    value = "https://github.com/" + value.split(":", 1)[1]
elif value.startswith("https://github.com/"):
    pass
elif value.startswith("http://github.com/"):
    value = "https://" + value[len("http://"):]
else:
    value = ""
if value and re.match(r"^https://github\.com/[^/]+/[^/]+$", value):
    print(value)
PY
}

mc_git_head_consistency() {
  local task_id repo local_head origin_main ls_remote remote_url github_url rendered_status rendered_contains rendered_sample status payload
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-$MC_TASK_ID}"
  repo="$MC_IOS_REPO"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  case "$task_id" in
    TASK-119) MC_CA_REFS="CA-119-21" ;;
    TASK-118) MC_CA_REFS="CA-118-25" ;;
    *) MC_CA_REFS="HEAD-CONSISTENCY" ;;
  esac

  local_head="$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)"
  origin_main="$(git -C "$repo" rev-parse origin/main 2>/dev/null || true)"
  ls_remote="$(git -C "$repo" ls-remote origin main 2>/dev/null | awk 'NR == 1 {print $1}' || true)"
  remote_url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
  github_url="$(mc_git_github_url_from_origin "$remote_url")"
  rendered_status="NOT_RUN"
  rendered_contains="false"
  rendered_sample=""
  if [[ -n "$github_url" && -n "$ls_remote" ]] && command -v curl >/dev/null 2>&1; then
    local rendered_tmp
    rendered_tmp="$(mktemp)"
    if curl -L --max-time 20 -s "${github_url}/commits/main" > "$rendered_tmp"; then
      rendered_status="FETCHED"
      if grep -Fq "$ls_remote" "$rendered_tmp"; then
        rendered_contains="true"
      fi
      rendered_sample="$(grep -Eo '[0-9a-f]{40}' "$rendered_tmp" | head -1 || true)"
    else
      rendered_status="BLOCKED"
    fi
    rm -f "$rendered_tmp"
  elif [[ -z "$github_url" ]]; then
    rendered_status="MISCONFIGURED"
  else
    rendered_status="BLOCKED"
  fi

  if [[ "$task_id" == "TASK-125" ]]; then
    local branch dirty task_path evidence_readme master_contains task_contains advisory_ok task125_payload task125_status
    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if git -C "$repo" diff --quiet 2>/dev/null && git -C "$repo" diff --cached --quiet 2>/dev/null; then
      dirty="clean"
    else
      dirty="dirty_documented"
    fi
    task_path="$repo/docs/TASKS/TASK-125-real-device-cross-platform-sync-final-architecture.md"
    evidence_readme="$repo/docs/TASKS/EVIDENCE/TASK-125/README.md"
    master_contains="false"
    task_contains="false"
    grep -Fq "TASK-125" "$repo/docs/MASTER-PLAN.md" 2>/dev/null && grep -Fq "EXECUTION" "$repo/docs/MASTER-PLAN.md" 2>/dev/null && master_contains="true"
    grep -Fq "Phase A+++++" "$task_path" 2>/dev/null && grep -Fq "EXECUTION_AUTHORIZED_BY_USER" "$task_path" 2>/dev/null && task_contains="true"
    advisory_ok="false"
    [[ -n "$origin_main" && -n "$ls_remote" && "$origin_main" == "$ls_remote" ]] && advisory_ok="true"
    task125_payload="$(
      TASK_ID="$task_id" LOCAL_HEAD="$local_head" ORIGIN_MAIN="$origin_main" LS_REMOTE="$ls_remote" \
      BRANCH="$branch" DIRTY="$dirty" TASK_PATH="$task_path" EVIDENCE_README="$evidence_readme" \
      MASTER_CONTAINS="$master_contains" TASK_CONTAINS="$task_contains" RENDERED_STATUS="$rendered_status" \
      RENDERED_CONTAINS="$rendered_contains" ADVISORY_OK="$advisory_ok" python3 - <<'PY'
import json, os
from datetime import datetime, timezone

def sha_ok(value):
    return isinstance(value, str) and len(value) == 40 and all(c in "0123456789abcdef" for c in value.lower())

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
local_head = os.environ.get("LOCAL_HEAD", "")
checks = [
    {"id": "local_head_present", "status": "PASS" if sha_ok(local_head) else "MISCONFIGURED", "value": local_head or None},
    {"id": "branch_present", "status": "PASS" if os.environ.get("BRANCH") else "MISCONFIGURED", "value": os.environ.get("BRANCH") or None},
    {"id": "dirty_state_classified", "status": "PASS", "value": os.environ.get("DIRTY")},
    {"id": "master_plan_local_task125_execution", "status": "PASS" if os.environ.get("MASTER_CONTAINS") == "true" else "FAIL"},
    {"id": "task125_local_present_and_execution_authorized", "status": "PASS" if os.environ.get("TASK_CONTAINS") == "true" else "FAIL"},
    {"id": "task125_evidence_readme_present", "status": "PASS" if os.path.exists(os.environ.get("EVIDENCE_README", "")) else "FAIL"},
]
remote_advisory = {
    "originMain": os.environ.get("ORIGIN_MAIN") or None,
    "lsRemoteMain": os.environ.get("LS_REMOTE") or None,
    "originAndLsRemoteMatch": os.environ.get("ADVISORY_OK") == "true",
    "githubRenderedStatus": os.environ.get("RENDERED_STATUS"),
    "githubRenderedContainsRemoteSha": os.environ.get("RENDERED_CONTAINS") == "true",
    "status": "PASS" if os.environ.get("ADVISORY_OK") == "true" and os.environ.get("RENDERED_CONTAINS") == "true" else "REMOTE_PUBLISH_PENDING",
}
statuses = [item["status"] for item in checks]
if "MISCONFIGURED" in statuses:
    status = "MISCONFIGURED"
elif "FAIL" in statuses:
    status = "FAIL"
else:
    status = "PASS" if remote_advisory["status"] == "PASS" else "PASS_WITH_NOTES_REMOTE_NOT_PUBLISHED"
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ.get("TASK_ID", "TASK-125"),
    "source": "git.head-consistency.task125-local-canonical",
    "startedAt": now,
    "completedAt": now,
    "status": status,
    "redactionApplied": True,
    "localCanonical": True,
    "checks": checks,
    "remotePublishCheck": remote_advisory,
    "NEXT_ACTION": "Continue local TASK-125 execution." if status.startswith("PASS") else "Fix local TASK-125 canonical files before execution.",
}, sort_keys=True))
PY
    )"
    MC_SYNC_JSON_RESULT="$task125_payload"
    mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
    task125_status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","MISCONFIGURED"))' <<<"$task125_payload")"
    case "$task125_status" in
      PASS)
        MC_SUMMARY="TASK-125 local canonical gate PASS; remote publish check is aligned."
        MC_NEXT_ACTION="Continue TASK-125 Phase 0/A gates."
        return "$MC_EXIT_PASS"
        ;;
      PASS_WITH_NOTES_REMOTE_NOT_PUBLISHED)
        mc_set_pass_with_notes
        MC_SUMMARY="TASK-125 local canonical gate PASS_WITH_NOTES: local worktree is canonical; remote publish check is advisory/pending."
        MC_NEXT_ACTION="Continue local execution; publish GitHub alignment later if requested."
        return "$MC_EXIT_PASS"
        ;;
      FAIL)
        MC_SUMMARY="TASK-125 local canonical gate FAIL: local MASTER-PLAN/task/evidence README are not coherent."
        MC_NEXT_ACTION="Fix local tracking files before continuing TASK-125 execution."
        return "$MC_EXIT_FAIL"
        ;;
      *)
        MC_SUMMARY="TASK-125 local canonical gate MISCONFIGURED."
        MC_NEXT_ACTION="Fix git/local task configuration before continuing."
        return "$MC_EXIT_MISCONFIGURED"
        ;;
    esac
  fi

  payload="$(
    TASK_ID="$task_id" LOCAL_HEAD="$local_head" ORIGIN_MAIN="$origin_main" LS_REMOTE="$ls_remote" \
    REMOTE_URL="$remote_url" GITHUB_URL="$github_url" RENDERED_STATUS="$rendered_status" \
    RENDERED_CONTAINS="$rendered_contains" RENDERED_SAMPLE="$rendered_sample" python3 - <<'PY'
import json
import os
from datetime import datetime, timezone

def sha_ok(value):
    return isinstance(value, str) and len(value) == 40 and all(c in "0123456789abcdef" for c in value.lower())

local_head = os.environ.get("LOCAL_HEAD", "")
origin_main = os.environ.get("ORIGIN_MAIN", "")
ls_remote = os.environ.get("LS_REMOTE", "")
rendered_contains = os.environ.get("RENDERED_CONTAINS") == "true"
rendered_status = os.environ.get("RENDERED_STATUS", "NOT_RUN")
checks = []
for name, value in [
    ("local_head", local_head),
    ("origin_main", origin_main),
    ("ls_remote_origin_main", ls_remote),
]:
    checks.append({
        "id": name,
        "status": "PASS" if sha_ok(value) else "MISCONFIGURED",
        "value": value or None,
    })
values = [value for value in [local_head, origin_main, ls_remote] if sha_ok(value)]
all_git_values_match = len(values) == 3 and len(set(values)) == 1
checks.append({
    "id": "local_origin_remote_match",
    "status": "PASS" if all_git_values_match else "BLOCKED",
    "value": {"local": local_head or None, "origin": origin_main or None, "remote": ls_remote or None},
})
checks.append({
    "id": "github_rendered_main_contains_remote_sha",
    "status": "PASS" if rendered_status == "FETCHED" and rendered_contains else "BLOCKED",
    "value": {
        "githubUrl": os.environ.get("GITHUB_URL") or None,
        "renderedStatus": rendered_status,
        "renderedSample": os.environ.get("RENDERED_SAMPLE") or None,
    },
})
statuses = [item["status"] for item in checks]
if "MISCONFIGURED" in statuses:
    status = "MISCONFIGURED"
elif all(item["status"] == "PASS" for item in checks):
    status = "PASS"
else:
    status = "BLOCKED"
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ.get("TASK_ID", "TASK-118"),
    "source": "git.head-consistency",
    "startedAt": now,
    "completedAt": now,
    "status": status,
    "remoteUrlRedacted": os.environ.get("REMOTE_URL", ""),
    "checks": checks,
    "NEXT_ACTION": f"Proceed with {os.environ.get('TASK_ID', 'TASK')} gates." if status == "PASS" else f"Stop {os.environ.get('TASK_ID', 'TASK')} and resolve HEAD mismatch or GitHub rendered-main access.",
}, sort_keys=True))
PY
  )"
  MC_SYNC_JSON_RESULT="$payload"
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","MISCONFIGURED"))' <<<"$payload")"
  case "$status" in
    PASS)
      MC_SUMMARY="HEAD consistency PASS for ${task_id}: local HEAD, origin/main, remote main and GitHub rendered main agree."
      MC_NEXT_ACTION="Continue ${task_id} preflight/scans."
      return "$MC_EXIT_PASS"
      ;;
    BLOCKED)
      MC_SUMMARY="HEAD consistency BLOCKED for ${task_id}: local/origin/remote/GitHub rendered main do not all agree."
      MC_NEXT_ACTION="Riallineare branch/origin/GitHub main prima di qualunque execution."
      return "$MC_EXIT_BLOCKED"
      ;;
    *)
      MC_SUMMARY="HEAD consistency MISCONFIGURED for ${task_id}: git remote or GitHub rendered main could not be verified."
      MC_NEXT_ACTION="Fix git/GitHub harness configuration, then rerun head-consistency."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_git() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    head-consistency) mc_git_head_consistency "$@" ;;
    *)
      MC_SUMMARY="Unknown git subcommand: ${sub}"
      MC_NEXT_ACTION="Use git head-consistency --task <TASK-ID>."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_preflight() {
  local require_head=0
  mc_parse_flag --require-head-consistency "$@" && require_head=1
  local blocked=0 misconfigured=0 summary=""
  local repo_name var path
  for repo_name in IOS ANDROID SUPABASE; do
    var="MC_${repo_name}_REPO"
    path="${!var}"
    if [[ -d "$path" ]]; then
      summary+="${repo_name} repo OK: $(mc_redact_text "$path")"$'\n'
    else
      summary+="${repo_name} repo MISSING: $(mc_redact_text "$path")"$'\n'
      misconfigured=$((misconfigured + 1))
    fi
  done

  local tool
  for tool in xcodebuild xcrun java docker supabase adb; do
    if mc_require_tool "$tool" >/dev/null; then
      summary+="${tool} OK"$'\n'
    else
      summary+="${tool} MISSING"$'\n'
      case "$tool" in
        xcodebuild|xcrun|java) misconfigured=$((misconfigured + 1)) ;;
        *) blocked=$((blocked + 1)) ;;
      esac
    fi
  done
  if [[ -d "$MC_ANDROID_REPO" && -x "$MC_ANDROID_REPO/gradlew" ]]; then
    summary+="gradlew OK"$'\n'
  else
    summary+="gradlew MISSING"$'\n'
    misconfigured=$((misconfigured + 1))
  fi
  mkdir -p "$MC_EVIDENCE_ABS/agent-runs"
  if [[ -w "$MC_EVIDENCE_ABS/agent-runs" ]]; then
    summary+="evidence dir OK: $(mc_relpath "$MC_EVIDENCE_ABS")"$'\n'
  else
    summary+="evidence dir NOT WRITABLE"$'\n'
    misconfigured=$((misconfigured + 1))
  fi

  MC_SUMMARY="$summary"
  if [[ "$misconfigured" -gt 0 ]]; then
    MC_NEXT_ACTION="Fix required repo/tool configuration."
    return "$MC_EXIT_MISCONFIGURED"
  fi
  if [[ "$blocked" -gt 0 ]]; then
    MC_NEXT_ACTION="Install/start optional tools for live/device/Supabase commands."
    return "$MC_EXIT_BLOCKED"
  fi
  if [[ "$require_head" == "1" ]]; then
    local preflight_summary="$summary"
    mc_git_head_consistency --task "$MC_TASK_ID"
    local head_code=$?
    summary="${preflight_summary}"$'\n'"HEAD consistency: ${MC_SUMMARY}"
    MC_SUMMARY="$summary"
    [[ "$head_code" -eq "$MC_EXIT_PASS" ]] || return "$head_code"
  fi
  MC_NEXT_ACTION="Run build/test commands."
  return "$MC_EXIT_PASS"
}

mc_cmd_task130_consolidation() {
  local mode="$1"
  shift || true
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-130}}"
  local tmp payload_status code

  case "$mode" in
    golden-corpus-validate|golden-corpus-roundtrip|real-device-feasibility)
      MC_PLATFORM="general"
      MC_SAFETY_LEVEL="safe-readonly"
      ;;
    swiftdata-fetch-budget)
      MC_PLATFORM="general"
      MC_SAFETY_LEVEL="safe-readonly"
      MC_CA_REFS="AC-130-CONSOLIDATED-SWIFTDATA"
      ;;
    ios-benchmark-import-large|ios-smoke-options-first-sync|ios-smoke-scanner-edge|ios-smoke-accessibility)
      MC_PLATFORM="ios"
      MC_SAFETY_LEVEL="safe-readonly"
      ;;
    *)
      MC_SUMMARY="Unknown TASK-130 consolidation mode: ${mode}"
      MC_NEXT_ACTION="Use documented TASK-130 consolidation commands."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac

  MC_REQUIRES_LIVE="false"
  tmp="/tmp/mc-agent-task130-consolidation-${mode}.$$.json"
  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" ANDROID_REPO="$MC_ANDROID_REPO" SUPABASE_REPO="$MC_SUPABASE_REPO" \
    python3 "$MC_AGENT_ROOT/lib/task130_consolidation.py" "$mode" "$@" > "$tmp"
  code=$?
  MC_SYNC_JSON_RESULT="$(cat "$tmp")"
  rm -f "$tmp"
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  payload_status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","MISCONFIGURED"))' <<<"$MC_SYNC_JSON_RESULT")"

  case "$payload_status" in
    PASS)
      MC_SUMMARY="TASK-130 ${mode} PASS."
      MC_NEXT_ACTION="Use this report in the consolidated TASK-130 ledger."
      return "$MC_EXIT_PASS"
      ;;
    PASS_WITH_NOTES)
      mc_set_pass_with_notes
      MC_SUMMARY="TASK-130 ${mode} PASS_WITH_NOTES: static/local evidence includes PARTIAL or NOT_RUN limits."
      MC_NEXT_ACTION="Review PARTIAL/NOT_RUN rows in the report before accepting consolidation."
      return "$MC_EXIT_PASS"
      ;;
    FAIL)
      MC_SUMMARY="TASK-130 ${mode} FAIL."
      MC_NEXT_ACTION="Fix failing checks and rerun the TASK-130 consolidation command."
      return "$MC_EXIT_FAIL"
      ;;
    BLOCKED_EXTERNAL)
      MC_SUMMARY="TASK-130 ${mode} BLOCKED_EXTERNAL."
      MC_NEXT_ACTION="Resolve external prerequisite or keep the blocker explicit in TASK-130 review."
      return "$MC_EXIT_BLOCKED"
      ;;
    UNSAFE_OPERATION_REFUSED)
      MC_SUMMARY="TASK-130 ${mode} UNSAFE_OPERATION_REFUSED."
      MC_NEXT_ACTION="Respect the safety gate; do not bypass live/cleanup restrictions."
      return "$MC_EXIT_REFUSED"
      ;;
    *)
      MC_SUMMARY="TASK-130 ${mode} MISCONFIGURED."
      MC_NEXT_ACTION="Fix harness routing or scanner config."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_harness() {
  local sub="${1:-doctor}"
  case "$sub" in
    golden-corpus)
      local action="${2:-validate}"
      shift 2 || true
      case "$action" in
        validate) mc_cmd_task130_consolidation golden-corpus-validate "$@" ;;
        roundtrip) mc_cmd_task130_consolidation golden-corpus-roundtrip "$@" ;;
        *)
          MC_SUMMARY="Unknown harness golden-corpus action: ${action}"
          MC_NEXT_ACTION="Use harness golden-corpus validate or harness golden-corpus roundtrip."
          return "$MC_EXIT_MISCONFIGURED"
          ;;
      esac
      ;;
    real-device-feasibility)
      shift || true
      mc_cmd_task130_consolidation real-device-feasibility "$@"
      ;;
    doctor)
      MC_PLATFORM="general"
      MC_SAFETY_LEVEL="safe-readonly"
      MC_CA_REFS="CA-115-16,CA-115-18"
      local status="PASS"
      local warnings=()
      local checks=()

      [[ "$MC_TASK_ID" != "TASK-113" ]] || warnings+=("default_task_still_TASK-113")
      [[ -d "$MC_IOS_REPO" ]] && checks+=("ios_repo=present") || { status="FAIL"; checks+=("ios_repo=missing"); }
      [[ -d "$MC_ANDROID_REPO" ]] && checks+=("android_repo=present") || { status="FAIL"; checks+=("android_repo=missing"); }
      [[ -d "$MC_SUPABASE_REPO" ]] && checks+=("supabase_repo=present") || warnings+=("supabase_repo=missing_or_unavailable")
      mkdir -p "$MC_EVIDENCE_ABS/agent-runs"
      [[ -w "$MC_EVIDENCE_ABS/agent-runs" ]] && checks+=("evidence_dir=writable") || { status="FAIL"; checks+=("evidence_dir=not_writable"); }

      mc_require_tool xcodebuild >/dev/null && checks+=("xcodebuild=present") || { status="FAIL"; checks+=("xcodebuild=missing"); }
      mc_require_tool xcrun >/dev/null && checks+=("xcrun=present") || { status="FAIL"; checks+=("xcrun=missing"); }
      mc_require_tool adb >/dev/null && checks+=("adb=present") || warnings+=("adb=missing")
      mc_require_tool supabase >/dev/null && checks+=("supabase_cli=present") || warnings+=("supabase_cli=missing")

      if xcrun simctl list devices --json >/dev/null 2>&1; then
        checks+=("ios_simulators=listable")
      else
        warnings+=("ios_simulators_not_listable")
      fi
      if xcrun devicectl list devices >/dev/null 2>&1; then
        checks+=("ios_physical_devices=listable")
      else
        warnings+=("ios_physical_devices_not_listable")
      fi
      if adb devices >/dev/null 2>&1; then
        checks+=("android_devices=listable")
      else
        warnings+=("android_devices_not_listable")
      fi

      HARNESS_STATUS="$status" \
      HARNESS_CHECKS="$(printf '%s\n' "${checks[@]}")" \
      HARNESS_WARNINGS="$(printf '%s\n' "${warnings[@]}")" \
      python3 - > /tmp/mc-agent-harness-doctor.$$.json <<'PY'
import json, os
from datetime import datetime, timezone

checks = [line for line in os.environ.get("HARNESS_CHECKS", "").splitlines() if line]
warnings = [line for line in os.environ.get("HARNESS_WARNINGS", "").splitlines() if line]
status = os.environ["HARNESS_STATUS"]
if status == "PASS" and warnings:
    status = "PASS_WITH_NOTES"
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ.get("MC_TASK_ID", "TASK-115"),
    "source": "harness.doctor",
    "status": status,
    "completedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "checks": checks,
    "warnings": warnings,
    "nextAction": "Resolve FAIL checks before gates; resolve warnings before physical/live acceptance if they apply."
}, sort_keys=True))
PY
      MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-harness-doctor.$$.json)"
      rm -f /tmp/mc-agent-harness-doctor.$$.json
      mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
      local payload_status
      payload_status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
      case "$payload_status" in
        PASS)
          MC_SUMMARY="Harness doctor PASS: required repos, tools and evidence directory are usable."
          MC_NEXT_ACTION="Run config validate, build/test, then live gates as needed."
          return "$MC_EXIT_PASS"
          ;;
        PASS_WITH_NOTES)
          mc_set_pass_with_notes
          MC_WARNINGS="$(IFS=,; printf '%s' "${warnings[*]}")"
          MC_SUMMARY="Harness doctor PASS_WITH_NOTES: required core checks passed with optional device/tool warnings."
          MC_NEXT_ACTION="Address listed warnings before physical iPhone, Android device or Supabase live gates."
          return "$MC_EXIT_PASS"
          ;;
        *)
          MC_SUMMARY="Harness doctor FAIL: core repo/tool/evidence checks are not usable."
          MC_NEXT_ACTION="Fix failing harness doctor checks, then rerun."
          return "$MC_EXIT_FAIL"
          ;;
      esac
      ;;
    *)
      MC_SUMMARY="Unknown harness subcommand: ${sub}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_report_validate_json() {
  local paths=()
  local task_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task)
        [[ -n "${2:-}" ]] || {
          MC_SUMMARY="--task requires a value."
          return "$MC_EXIT_MISCONFIGURED"
        }
        task_id="$2"
        mc_set_task_context "$task_id"
        shift 2
        ;;
      --task=*)
        task_id="${1#*=}"
        mc_set_task_context "$task_id"
        shift
        ;;
      --path)
        [[ -n "${2:-}" ]] || {
          MC_SUMMARY="--path requires a value."
          return "$MC_EXIT_MISCONFIGURED"
        }
        paths+=("$2")
        shift 2
        ;;
      --path=*)
        paths+=("${1#*=}")
        shift
        ;;
      *)
        paths+=("$1")
        shift
        ;;
    esac
  done
  if [[ ${#paths[@]} -eq 0 ]]; then
    MC_SUMMARY="--path is required."
    return "$MC_EXIT_MISCONFIGURED"
  fi
  if [[ "$MC_TASK_ID" == "TASK-118" ]]; then
    local canonical_abs input_abs input_path
    canonical_abs="$MC_IOS_REPO/docs/TASKS/EVIDENCE/TASK-118"
    for input_path in "${paths[@]}"; do
      if [[ "$input_path" == /* ]]; then
        input_abs="$input_path"
      else
        input_abs="$MC_IOS_REPO/$input_path"
      fi
      case "$input_abs" in
        "$canonical_abs"|"$canonical_abs"/*) ;;
        *)
          MC_SUMMARY="TASK-118 JSON validation path MISCONFIGURED: ${input_path} is outside docs/TASKS/EVIDENCE/TASK-118."
          MC_NEXT_ACTION="Validate only TASK-118 evidence reports."
          return "$MC_EXIT_MISCONFIGURED"
          ;;
      esac
    done
  fi
  local expanded=()
  local path
  for path in "${paths[@]}"; do
    if [[ -d "$path" ]]; then
      while IFS= read -r candidate; do
        expanded+=("$candidate")
      done < <(find "$path" -maxdepth 1 -name '*.json' -print 2>/dev/null | sort)
    else
      expanded+=("$path")
    fi
  done
  python3 - "${expanded[@]}" <<'PY'
import json, os, sys
required = [
    "schema_version", "run_id", "task_id", "command", "command_slug",
    "platform", "safety_level", "requires_live", "requires_cleanup",
    "profile", "android_offline_tier", "timestamp_start", "timestamp_end",
    "duration_ms", "repo", "branch", "git_sha", "dirty_state",
    "env_redacted", "device_simulator_redacted", "test_prefix",
    "cleanup_plan_id", "result", "exit_code", "rows_created",
    "rows_deleted", "residue_count", "raw_log_redacted", "artifact_paths",
    "ca_refs", "warnings", "next_action_recommended"
]
if len(sys.argv) == 1:
    print("INVALID no JSON files")
    sys.exit(1)
invalid = []
validated = 0
for path in sys.argv[1:]:
    if os.path.basename(path) in {"00-help-json.json", "00-commands-json.json", "01-commands-json.json"}:
        continue
    try:
        with open(path, "r", encoding="utf-8") as fh:
            payload = json.load(fh)
    except Exception as exc:
        invalid.append(f"{path}: unreadable/non-json ({exc})")
        continue
    missing = [k for k in required if k not in payload]
    if payload.get("schema_version") != "1.1":
        missing.append("schema_version=1.1")
    artifacts = payload.get("artifact_paths", {})
    for k in ["markdown", "json", "log", "xcresult", "screenshot"]:
        if k not in artifacts:
            missing.append(f"artifact_paths.{k}")
    if missing:
        invalid.append(f"{path}: {', '.join(missing)}")
    else:
        validated += 1
if invalid:
    print("INVALID")
    for item in invalid:
        print(item)
    sys.exit(1)
if validated == 0:
    print("INVALID no JSON reports")
    sys.exit(1)
print(f"VALID {validated} JSON report(s)")
PY
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="JSON schema v1.1 validation PASS for ${#expanded[@]} report(s)."
    MC_NEXT_ACTION="Use report in CA evidence."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="JSON schema v1.1 validation FAIL for one or more report(s)."
  MC_NEXT_ACTION="Regenerate report with mc-agent."
  return "$MC_EXIT_FAIL"
}

mc_cmd_report() {
  if [[ "${1:-}" == "validate-json" ]]; then
    shift
    mc_cmd_report_validate_json "$@"
    return $?
  fi
  local task_id latest run_id since
  task_id="$(mc_parse_opt --task "$@" || true)"
  latest=0
  mc_parse_flag --latest "$@" && latest=1
  run_id="$(mc_parse_opt --run-id "$@" || true)"
  since="$(mc_parse_opt --since "$@" || true)"
  task_id="${task_id:-$MC_TASK_ID}"
  local dir="$MC_IOS_REPO/docs/TASKS/EVIDENCE/${task_id}/agent-runs"
  if [[ ! -d "$dir" ]]; then
    MC_SUMMARY="No agent-runs directory for ${task_id}."
    MC_NEXT_ACTION="Run a command first."
    return "$MC_EXIT_BLOCKED"
  fi
  local count latest_json latest_md
  count="$(find "$dir" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
  latest_json="$(find "$dir" -maxdepth 1 -name '*.json' -print 2>/dev/null | sort | tail -1)"
  latest_md="${latest_json%.json}.md"
  if [[ -n "$run_id" ]]; then
    latest_json="$(find "$dir" -maxdepth 1 -name "*${run_id}*.json" -print 2>/dev/null | sort | tail -1)"
    latest_md="${latest_json%.json}.md"
  fi
  if [[ "$latest" == "1" && -n "$latest_md" && -f "$latest_md" ]]; then
    sed -n '1,80p' "$latest_md"
  elif [[ -n "$since" ]]; then
    find "$dir" -maxdepth 1 -name '*.json' -newermt "$since" -print 2>/dev/null | sort
  else
    find "$dir" -maxdepth 1 -name '*.json' -print 2>/dev/null | sort | tail -20
  fi
  MC_SUMMARY="Found ${count} JSON report(s) for ${task_id}. Latest: $(mc_relpath "${latest_json:-none}")"
  MC_NEXT_ACTION="Validate JSON reports or open latest markdown."
  return "$MC_EXIT_PASS"
}

mc_scan_file_for_sensitive() {
  local file="$1"
  local hits=0 pattern
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    if grep -IEn "$pattern" "$file" 2>/dev/null | grep -Ev '<REDACTED|REDACTED_|REDACTED>' >/tmp/mc-agent-scan-hit.$$; then
      cat /tmp/mc-agent-scan-hit.$$
      hits=$((hits + $(wc -l < /tmp/mc-agent-scan-hit.$$ | tr -d ' ')))
    fi
  done < <(mc_scan_sensitive_patterns)
  rm -f /tmp/mc-agent-scan-hit.$$
  [[ "$hits" -eq 0 ]]
}

mc_cmd_scan_sensitive() {
  local paths=("$@")
  if [[ ${#paths[@]} -eq 0 ]]; then
    paths=("$MC_EVIDENCE_ABS/agent-runs")
  fi
  local hits=0 p file
  for p in "${paths[@]}"; do
    if [[ -d "$p" ]]; then
      while IFS= read -r file; do
        mc_scan_file_for_sensitive "$file" || hits=$((hits + 1))
      done < <(find "$p" -type f \( -name '*.log' -o -name '*.md' -o -name '*.json' -o -name '*.txt' \) -not -path '*/node_modules/*')
    elif [[ -f "$p" ]]; then
      mc_scan_file_for_sensitive "$p" || hits=$((hits + 1))
    fi
  done
  if [[ "$hits" -gt 0 ]]; then
    MC_SUMMARY="Sensitive scan FAIL: ${hits} file(s) with unredacted hits."
    MC_NEXT_ACTION="Redact or remove unsafe evidence and rerun."
    return "$MC_EXIT_FAIL"
  fi
  MC_SUMMARY="Sensitive scan PASS."
  MC_NEXT_ACTION="Run scan evidence or continue validation."
  return "$MC_EXIT_PASS"
}

mc_cmd_scan_evidence() {
  local task_id dir hits=0 large_logs tmp_files node_modules tmp_file tmp_mtime now current_tmp_base
  task_id="$(mc_parse_opt --task "$@")"
  task_id="${task_id:-$MC_TASK_ID}"
  dir="$MC_IOS_REPO/docs/TASKS/EVIDENCE/${task_id}"
  [[ -d "$dir" ]] || {
    MC_SUMMARY="Evidence directory missing: ${dir}"
    return "$MC_EXIT_BLOCKED"
  }
  node_modules="$(find "$dir" -type d -name node_modules -print -quit 2>/dev/null || true)"
  current_tmp_base="$(basename "${MC_LOG_TMP:-__none__}")"
  now="$(date +%s)"
  tmp_files=""
  while IFS= read -r tmp_file; do
    [[ "$(basename "$tmp_file")" == "$current_tmp_base" ]] && continue
    tmp_mtime="$(stat -f %m "$tmp_file" 2>/dev/null || stat -c %Y "$tmp_file" 2>/dev/null || echo "$now")"
    # Atomic report writers keep .tmp files open while a sibling command is still running.
    # Treat only stale .tmp files as residue so parallel read-only scans do not self-fail.
    if (( now - tmp_mtime >= 60 )); then
      tmp_files="$tmp_file"
      break
    fi
  done < <(find "$dir" -name '*.tmp' -print 2>/dev/null)
  large_logs="$(find "$dir" -type f -name '*.log' -size +2M -print -quit 2>/dev/null || true)"
  [[ -z "$node_modules" ]] || { echo "node_modules in evidence: $node_modules"; hits=$((hits + 1)); }
  [[ -z "$tmp_files" ]] || { echo "tmp residue in evidence: $tmp_files"; hits=$((hits + 1)); }
  [[ -z "$large_logs" ]] || { echo "large raw log in evidence: $large_logs"; hits=$((hits + 1)); }
  mc_cmd_scan_sensitive "$dir" || hits=$((hits + 1))
  if [[ "$hits" -gt 0 ]]; then
    MC_SUMMARY="Evidence scan FAIL for ${task_id}: ${hits} issue group(s)."
    MC_NEXT_ACTION="Remove node_modules/tmp/raw logs or redact sensitive data."
    return "$MC_EXIT_FAIL"
  fi
  MC_SUMMARY="Evidence scan PASS for ${task_id}."
  MC_NEXT_ACTION="Use evidence in ${task_id} closure matrix."
  return "$MC_EXIT_PASS"
}

mc_cmd_scan_repo_diff() {
  local hits=0 diff_tmp status_tmp
  diff_tmp="$(mktemp)"
  status_tmp="$(mktemp)"
  git -C "$MC_IOS_REPO" diff -- . ':!tools/agent/mcp/package-lock.json' > "$diff_tmp" || true
  git -C "$MC_IOS_REPO" status --short > "$status_tmp" || true
  if [[ -d "$MC_ANDROID_REPO/.git" ]]; then
    git -C "$MC_ANDROID_REPO" diff -- app/src/test app/src/androidTest >> "$diff_tmp" || true
    git -C "$MC_ANDROID_REPO" status --short -- app/src/test app/src/androidTest >> "$status_tmp" || true
  fi
  if grep -n 'node_modules' "$status_tmp"; then
    hits=$((hits + 1))
  fi
  mc_scan_file_for_sensitive "$diff_tmp" || hits=$((hits + 1))
  rm -f "$diff_tmp" "$status_tmp"
  if [[ "$hits" -gt 0 ]]; then
    MC_SUMMARY="Repo diff scan FAIL: node_modules or sensitive-looking diff found."
    MC_NEXT_ACTION="Remove generated dependencies and redact diff."
    return "$MC_EXIT_FAIL"
  fi
  MC_SUMMARY="Repo diff scan PASS."
  MC_NEXT_ACTION="Run git diff --check and evidence scan."
  return "$MC_EXIT_PASS"
}

mc_cmd_scan_release_cta() {
  local hits=0 summary="" term
  local terms=("Sync now" "Sincronizza ora" "Sincronizar ahora" "立即同步")
  for term in "${terms[@]}"; do
    if grep -R --include='*.swift' -n "$term" "$MC_IOS_REPO/iOSMerchandiseControl" 2>/dev/null | grep -v DEBUG | head -5; then
      hits=$((hits + 1))
      summary+="Found '${term}' in iOS main sources"$'\n'
    fi
  done
  if [[ -d "$MC_ANDROID_REPO/app/src/main" ]]; then
    for term in "${terms[@]}"; do
      if grep -R --include='*.kt' --include='*.xml' -n "$term" "$MC_ANDROID_REPO/app/src/main" 2>/dev/null | head -5; then
        hits=$((hits + 1))
        summary+="Found '${term}' in Android main sources"$'\n'
      fi
    done
  fi
  MC_SUMMARY="${summary:-Release CTA scan PASS: no public manual sync CTA strings found.}"
  if [[ "$hits" -gt 0 ]]; then
    MC_NEXT_ACTION="Review whether hits are public Release CTA or internal diagnostics."
    return "$MC_EXIT_FAIL"
  fi
  MC_NEXT_ACTION="Continue release gate validation."
  return "$MC_EXIT_PASS"
}

mc_cmd_scan_no_legacy_runtime_path() {
  local task_id="${MC_TASK_ID:-TASK-116}"
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-116}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  MC_CA_REFS="CA-116-01,CA-116-02,CA-116-03,CA-116-10,CA-116-11"

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" python3 "$MC_AGENT_ROOT/lib/task117_scans.py" no-legacy-runtime-path > /tmp/mc-agent-no-legacy-runtime.$$.json
  local scan_code=$?
  if [[ "$scan_code" -ne 0 && "$scan_code" -ne 1 ]]; then
    MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-no-legacy-runtime.$$.json)"
    rm -f /tmp/mc-agent-no-legacy-runtime.$$.json
    mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
    MC_SUMMARY="No-legacy-runtime-path scan MISCONFIGURED for ${task_id}."
    MC_NEXT_ACTION="Fix task117 scanner configuration and rerun."
    return "$MC_EXIT_MISCONFIGURED"
  fi
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-no-legacy-runtime.$$.json)"
  rm -f /tmp/mc-agent-no-legacy-runtime.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  if [[ "$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status"))' <<<"$MC_SYNC_JSON_RESULT")" == "PASS" ]]; then
    MC_SUMMARY="No-legacy-runtime-path scan PASS for ${task_id}: strict TASK-117 source/call-graph checks passed."
    MC_NEXT_ACTION="Run live no-legacy-runtime-path and no-full-pull-normal-path."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="No-legacy-runtime-path scan FAIL for ${task_id}: strict TASK-117 source/call-graph checks found forbidden automatic legacy path."
  MC_NEXT_ACTION="Remove automatic VM/adapter/legacy apply/full-pull path and rerun."
  return "$MC_EXIT_FAIL"
}

mc_cmd_scan_task117_static() {
  local scan_name="$1"
  shift || true
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-117}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  case "${task_id}:${scan_name}" in
    TASK-118:sync-boundaries) MC_CA_REFS="CA-118-01,CA-118-02,CA-118-03,CA-118-04,CA-118-05,CA-118-06,CA-118-10,CA-118-12,CA-118-13,CA-118-21" ;;
    TASK-118:no-full-pull-normal-path) MC_CA_REFS="CA-118-07,CA-118-08,CA-118-09,CA-118-14,CA-118-22" ;;
    *) MC_CA_REFS="${MC_CA_REFS:-CA-117-20,CA-117-21}" ;;
  esac

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" python3 "$MC_AGENT_ROOT/lib/task117_scans.py" "$scan_name" > /tmp/mc-agent-task117-static.$$.json
  local scan_code=$?
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task117-static.$$.json)"
  rm -f /tmp/mc-agent-task117-static.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  case "$scan_code" in
    0)
      MC_SUMMARY="${scan_name} scan PASS for ${task_id}."
      MC_NEXT_ACTION="Use this report in ${task_id} evidence matrix."
      return "$MC_EXIT_PASS"
      ;;
    1)
      MC_SUMMARY="${scan_name} scan FAIL for ${task_id}: source/call-graph checks failed."
      MC_NEXT_ACTION="Fix failing checks and rerun ${scan_name}."
      return "$MC_EXIT_FAIL"
      ;;
    *)
      MC_SUMMARY="${scan_name} scan MISCONFIGURED for ${task_id}."
      MC_NEXT_ACTION="Fix scanner command/configuration."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_scan_task119_static() {
  local scan_name="$1"
  shift || true
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-119}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  case "$scan_name" in
    sync-architecture) MC_CA_REFS="CA-119-01,CA-119-03,CA-119-04,CA-119-05,CA-119-06,CA-119-29,CA-119-30,CA-119-31,CA-119-39" ;;
    manual-boundary) MC_CA_REFS="CA-119-01,CA-119-02,CA-119-19,CA-119-33" ;;
    dead-code) MC_CA_REFS="CA-119-10,CA-119-11,CA-119-27" ;;
    xcode-membership) MC_CA_REFS="CA-119-10,CA-119-34" ;;
    no-full-pull-normal-path) MC_CA_REFS="CA-119-08,CA-119-37" ;;
    *) MC_CA_REFS="CA-119-21,CA-119-22,CA-119-23,CA-119-24" ;;
  esac

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" python3 "$MC_AGENT_ROOT/lib/task119_scans.py" "$scan_name" > /tmp/mc-agent-task119-static.$$.json
  local scan_code=$?
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task119-static.$$.json)"
  rm -f /tmp/mc-agent-task119-static.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  case "$scan_code" in
    0)
      MC_SUMMARY="${scan_name} scan PASS for ${task_id}."
      MC_NEXT_ACTION="Use this report in ${task_id} evidence matrix."
      return "$MC_EXIT_PASS"
      ;;
    1)
      MC_SUMMARY="${scan_name} scan FAIL for ${task_id}: TASK-119 architecture/boundary checks found required future work."
      MC_NEXT_ACTION="Fix failing checks during TASK-119 execution, then rerun ${scan_name}."
      return "$MC_EXIT_FAIL"
      ;;
    2)
      MC_SUMMARY="${scan_name} scan BLOCKED_EXTERNAL for ${task_id}."
      MC_NEXT_ACTION="Resolve the listed external prerequisite and rerun ${scan_name}."
      return "$MC_EXIT_BLOCKED"
      ;;
    *)
      MC_SUMMARY="${scan_name} scan MISCONFIGURED for ${task_id}."
      MC_NEXT_ACTION="Fix TASK-119 scanner command/configuration."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_scan_task120_static() {
  local scan_name="$1"
  shift || true
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-120}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  case "$scan_name" in
    task-docs) MC_CA_REFS="CA-120-40,CA-120-49,CA-120-65,CA-120-68" ;;
    harness-routing) MC_CA_REFS="CA-120-42,CA-120-43,CA-120-62" ;;
    harness-health) MC_CA_REFS="CA-120-44" ;;
    source-format) MC_CA_REFS="CA-120-41,CA-120-60,CA-120-66" ;;
    duplicate-symbols) MC_CA_REFS="CA-120-02,CA-120-32" ;;
    automatic-legacy-monolith) MC_CA_REFS="CA-120-01,CA-120-33" ;;
    mainactor-boundary) MC_CA_REFS="CA-120-05,CA-120-34" ;;
    swiftdata-context-boundary) MC_CA_REFS="CA-120-06,CA-120-35" ;;
    manual-root-residue) MC_CA_REFS="CA-120-07,CA-120-45" ;;
    master-plan-consistency) MC_CA_REFS="CA-120-48" ;;
    mcp-wrapper) MC_CA_REFS="CA-120-55" ;;
    scanner-self-tests) MC_CA_REFS="CA-120-15,CA-120-31,CA-120-54,CA-120-61,CA-120-67" ;;
    status-taxonomy) MC_CA_REFS="CA-120-50,CA-120-56,CA-120-63" ;;
    evidence-metadata) MC_CA_REFS="CA-120-28,CA-120-49,CA-120-58" ;;
    sync-architecture) MC_CA_REFS="CA-120-03,CA-120-04,CA-120-09,CA-120-10,CA-120-11,CA-120-12,CA-120-24,CA-120-38,CA-120-46,CA-120-47,CA-120-53" ;;
    manual-boundary) MC_CA_REFS="CA-120-07,CA-120-08,CA-120-21,CA-120-37,CA-120-45" ;;
    dead-code) MC_CA_REFS="CA-120-25" ;;
    xcode-membership) MC_CA_REFS="CA-120-16,CA-120-36" ;;
    *) MC_CA_REFS="CA-120-15" ;;
  esac

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" python3 "$MC_AGENT_ROOT/lib/task120_scans.py" "$scan_name" > /tmp/mc-agent-task120-static.$$.json
  local scan_code=$?
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task120-static.$$.json)"
  rm -f /tmp/mc-agent-task120-static.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  case "$scan_code" in
    0)
      MC_SUMMARY="${scan_name} scan PASS for ${task_id}."
      MC_NEXT_ACTION="Use this report in ${task_id} evidence matrix."
      return "$MC_EXIT_PASS"
      ;;
    1)
      MC_SUMMARY="${scan_name} scan FAIL for ${task_id}: TASK-120 gate found required work."
      MC_NEXT_ACTION="Fix failing checks and rerun ${scan_name}."
      return "$MC_EXIT_FAIL"
      ;;
    2)
      MC_SUMMARY="${scan_name} scan BLOCKED_EXTERNAL for ${task_id}."
      MC_NEXT_ACTION="Resolve the listed external prerequisite and rerun ${scan_name}."
      return "$MC_EXIT_BLOCKED"
      ;;
    4)
      MC_SUMMARY="${scan_name} scan UNSAFE_OPERATION_REFUSED for ${task_id}."
      MC_NEXT_ACTION="Keep safety gate refused unless this was an expected refusal test."
      return "$MC_EXIT_REFUSED"
      ;;
    *)
      MC_SUMMARY="${scan_name} scan MISCONFIGURED for ${task_id}."
      MC_NEXT_ACTION="Fix TASK-120 scanner command/configuration."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_scan_task121_static() {
  local scan_name="$1"
  shift || true
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-121}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  case "$scan_name" in
    task-docs) MC_CA_REFS="CA-121-01,CA-121-51" ;;
    harness-routing) MC_CA_REFS="CA-121-41,CA-121-42,CA-121-45" ;;
    harness-health) MC_CA_REFS="CA-121-42" ;;
    mcp-wrapper) MC_CA_REFS="CA-121-43" ;;
    status-taxonomy) MC_CA_REFS="CA-121-36,CA-121-49" ;;
    evidence-metadata) MC_CA_REFS="CA-121-24,CA-121-25,CA-121-48,CA-121-51,CA-121-52" ;;
    scanner-self-tests) MC_CA_REFS="CA-121-23" ;;
    source-format) MC_CA_REFS="CA-121-39,CA-121-45" ;;
    sync-inventory) MC_CA_REFS="CA-121-01,CA-121-44,CA-121-54" ;;
    sync-architecture) MC_CA_REFS="CA-121-02,CA-121-03,CA-121-04,CA-121-05,CA-121-06,CA-121-07" ;;
    retry-ownership) MC_CA_REFS="CA-121-02,CA-121-03,CA-121-04,CA-121-35" ;;
    manual-boundary) MC_CA_REFS="CA-121-10,CA-121-11" ;;
    root-residue) MC_CA_REFS="CA-121-07,CA-121-30" ;;
    shared-purity) MC_CA_REFS="CA-121-09" ;;
    dead-code) MC_CA_REFS="CA-121-30" ;;
    xcode-membership) MC_CA_REFS="CA-121-15,CA-121-30" ;;
    duplicate-symbols) MC_CA_REFS="CA-121-38" ;;
    *) MC_CA_REFS="CA-121-01" ;;
  esac

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" python3 "$MC_AGENT_ROOT/lib/task121_scans.py" "$scan_name" > /tmp/mc-agent-task121-static.$$.json
  local scan_code=$?
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task121-static.$$.json)"
  rm -f /tmp/mc-agent-task121-static.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  case "$scan_code" in
    0)
      MC_SUMMARY="${scan_name} scan PASS for ${task_id}."
      MC_NEXT_ACTION="Use this report in ${task_id} evidence matrix."
      return "$MC_EXIT_PASS"
      ;;
    1)
      MC_SUMMARY="${scan_name} scan FAIL for ${task_id}: TASK-121 gate found required work."
      MC_NEXT_ACTION="Fix failing checks and rerun ${scan_name}."
      return "$MC_EXIT_FAIL"
      ;;
    2)
      MC_SUMMARY="${scan_name} scan BLOCKED_EXTERNAL for ${task_id}."
      MC_NEXT_ACTION="Resolve the listed external prerequisite and rerun ${scan_name}."
      return "$MC_EXIT_BLOCKED"
      ;;
    4)
      MC_SUMMARY="${scan_name} scan UNSAFE_OPERATION_REFUSED for ${task_id}."
      MC_NEXT_ACTION="Keep safety gate refused unless this was an expected refusal test."
      return "$MC_EXIT_REFUSED"
      ;;
    *)
      MC_SUMMARY="${scan_name} scan MISCONFIGURED for ${task_id}."
      MC_NEXT_ACTION="Fix TASK-121 scanner command/configuration."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_scan_task122_static() {
  local scan_name="$1"
  shift || true
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-122}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  case "$scan_name" in
    task-docs) MC_CA_REFS="CA-122-01,CA-122-02,CA-122-03,CA-122-53" ;;
    master-plan-consistency) MC_CA_REFS="CA-122-02,CA-122-03,CA-122-53" ;;
    evidence-metadata) MC_CA_REFS="CA-122-01,CA-122-53,CA-122-56,CA-122-58" ;;
    harness-routing) MC_CA_REFS="CA-122-04,CA-122-54,CA-122-60" ;;
    harness-health) MC_CA_REFS="CA-122-54,CA-122-60" ;;
    mcp-wrapper) MC_CA_REFS="CA-122-54,CA-122-60" ;;
    status-taxonomy) MC_CA_REFS="CA-122-57" ;;
    scanner-self-tests) MC_CA_REFS="CA-122-55" ;;
    source-format) MC_CA_REFS="CA-122-06,CA-122-32" ;;
    swift-source-shape) MC_CA_REFS="CA-122-61" ;;
    sync-inventory) MC_CA_REFS="CA-122-05" ;;
    sync-architecture) MC_CA_REFS="CA-122-25,CA-122-50,CA-122-74" ;;
    remote-transport-thin) MC_CA_REFS="CA-122-11,CA-122-12,CA-122-26,CA-122-68" ;;
    adapter-delegation-depth) MC_CA_REFS="CA-122-13,CA-122-14,CA-122-15,CA-122-16,CA-122-27,CA-122-64" ;;
    domain-method-ownership) MC_CA_REFS="CA-122-12,CA-122-28" ;;
    manual-debug-boundary) MC_CA_REFS="CA-122-17,CA-122-20,CA-122-29" ;;
    transport-protocol-conformance) MC_CA_REFS="CA-122-62" ;;
    composition-import-boundary) MC_CA_REFS="CA-122-19,CA-122-63" ;;
    remote-query-ownership) MC_CA_REFS="CA-122-64" ;;
    debug-seed-boundary) MC_CA_REFS="CA-122-65,CA-122-68" ;;
    dto-mapper-duplication) MC_CA_REFS="CA-122-66" ;;
    supabase-query-map) MC_CA_REFS="CA-122-09,CA-122-47,CA-122-67" ;;
    transport-callsite-map) MC_CA_REFS="CA-122-07" ;;
    protocol-conformance-map) MC_CA_REFS="CA-122-08" ;;
    supabase-contract-map) MC_CA_REFS="CA-122-09,CA-122-46,CA-122-47,CA-122-48" ;;
    android-parity-ledger) MC_CA_REFS="CA-122-10" ;;
    xcode-membership) MC_CA_REFS="CA-122-24,CA-122-30" ;;
    dead-code) MC_CA_REFS="CA-122-22,CA-122-31" ;;
    sensitive) MC_CA_REFS="CA-122-33,CA-122-48,CA-122-59" ;;
    evidence) MC_CA_REFS="CA-122-33,CA-122-56,CA-122-58" ;;
    sync-efficiency-acceptance) MC_CA_REFS="CA-122-76,CA-122-77,CA-122-78,CA-122-79,CA-122-80,CA-122-81,CA-122-82,CA-122-83,CA-122-84,CA-122-85" ;;
    *) MC_CA_REFS="CA-122-54" ;;
  esac

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" python3 "$MC_AGENT_ROOT/lib/task122_scans.py" "$scan_name" > /tmp/mc-agent-task122-static.$$.json
  local scan_code=$?
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task122-static.$$.json)"
  rm -f /tmp/mc-agent-task122-static.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  case "$scan_code" in
    0)
      MC_SUMMARY="${scan_name} scan PASS for ${task_id}."
      MC_NEXT_ACTION="Use this report in ${task_id} evidence matrix."
      return "$MC_EXIT_PASS"
      ;;
    1)
      MC_SUMMARY="${scan_name} scan FAIL for ${task_id}: TASK-122 gate found required work."
      MC_NEXT_ACTION="Fix failing checks and rerun ${scan_name}."
      return "$MC_EXIT_FAIL"
      ;;
    2)
      MC_SUMMARY="${scan_name} scan BLOCKED_EXTERNAL for ${task_id}."
      MC_NEXT_ACTION="Resolve the listed external prerequisite and rerun ${scan_name}."
      return "$MC_EXIT_BLOCKED"
      ;;
    4)
      MC_SUMMARY="${scan_name} scan UNSAFE_OPERATION_REFUSED for ${task_id}."
      MC_NEXT_ACTION="Keep safety gate refused unless this was an expected refusal test."
      return "$MC_EXIT_REFUSED"
      ;;
    *)
      MC_SUMMARY="${scan_name} scan MISCONFIGURED for ${task_id}."
      MC_NEXT_ACTION="Fix TASK-122 scanner command/configuration."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_scan_task124_static() {
  local scan_name="$1"
  shift || true
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-124}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  case "$scan_name" in
    automation-discovery|harness-routing) MC_CA_REFS="AC-124-23,AC-124-24" ;;
    scanner-self-tests) MC_CA_REFS="AC-124-24" ;;
    no-root-supabase-legacy) MC_CA_REFS="AC-124-01,AC-124-07" ;;
    no-automatic-manual-dependency|no-hidden-manual-sync) MC_CA_REFS="AC-124-02,AC-124-10" ;;
    transport-thin-only) MC_CA_REFS="AC-124-01,AC-124-03" ;;
    remote-adapter-single-domain) MC_CA_REFS="AC-124-04,AC-124-05" ;;
    no-full-pull-normal-path) MC_CA_REFS="AC-124-09,AC-124-19" ;;
    no-stale-pbxproj-reference) MC_CA_REFS="AC-124-08,AC-124-27" ;;
    no-mainactor-heavy-sync) MC_CA_REFS="AC-124-15,AC-124-21" ;;
    no-service-role-client|no-rls-bypass) MC_CA_REFS="AC-124-11,AC-124-22" ;;
    source-format) MC_CA_REFS="AC-124-12,AC-124-28" ;;
    dead-code-residue) MC_CA_REFS="AC-124-06,AC-124-26" ;;
    *) MC_CA_REFS="AC-124-24" ;;
  esac

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" python3 "$MC_AGENT_ROOT/lib/task124_scans.py" "$scan_name" > /tmp/mc-agent-task124-static.$$.json
  local scan_code=$?
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task124-static.$$.json)"
  rm -f /tmp/mc-agent-task124-static.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  case "$scan_code" in
    0)
      MC_SUMMARY="${scan_name} scan PASS for ${task_id}."
      MC_NEXT_ACTION="Use this report in ${task_id} evidence matrix."
      return "$MC_EXIT_PASS"
      ;;
    1)
      MC_SUMMARY="${scan_name} scan FAIL for ${task_id}: TASK-124 gate found required work."
      MC_NEXT_ACTION="Fix failing checks and rerun ${scan_name}."
      return "$MC_EXIT_FAIL"
      ;;
    2)
      MC_SUMMARY="${scan_name} scan BLOCKED_EXTERNAL for ${task_id}."
      MC_NEXT_ACTION="Resolve the listed external prerequisite and rerun ${scan_name}."
      return "$MC_EXIT_BLOCKED"
      ;;
    4)
      MC_SUMMARY="${scan_name} scan UNSAFE_OPERATION_REFUSED for ${task_id}."
      MC_NEXT_ACTION="Keep safety gate refused unless this was an expected refusal test."
      return "$MC_EXIT_REFUSED"
      ;;
    *)
      MC_SUMMARY="${scan_name} scan MISCONFIGURED for ${task_id}."
      MC_NEXT_ACTION="Fix TASK-124 scanner command/configuration."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_scan_task125_static() {
  local scan_name="$1"
  shift || true
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-125}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  case "$scan_name" in
    no-hidden-manual-sync) MC_CA_REFS="AC-125-A05,AC-125-30" ;;
    no-full-pull-normal-path) MC_CA_REFS="AC-125-A06,AC-125-29" ;;
    no-service-role-client|no-rls-bypass) MC_CA_REFS="AC-125-26,AC-125-28" ;;
    no-mainactor-heavy-sync) MC_CA_REFS="AC-125-A07,AC-125-A22" ;;
    no-stale-pbxproj-reference|no-test-fixture-in-app-target|no-root-legacy-sync-service) MC_CA_REFS="AC-125-A09,AC-125-A13" ;;
    remote-adapter-single-domain) MC_CA_REFS="AC-125-A08" ;;
    background-task-registration|background-task-no-ui-context) MC_CA_REFS="AC-125-17,AC-125-18" ;;
    outbox-pending-survives-restart) MC_CA_REFS="AC-125-A16,AC-125-11" ;;
    evidence-redaction) MC_CA_REFS="AC-125-27,AC-125-28" ;;
    source-format|dead-code-residue) MC_CA_REFS="AC-125-26" ;;
    *) MC_CA_REFS="AC-125-A13" ;;
  esac

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" ANDROID_REPO="$MC_ANDROID_REPO" SUPABASE_REPO="$MC_SUPABASE_REPO" \
    python3 "$MC_AGENT_ROOT/lib/task125_scans.py" "$scan_name" > /tmp/mc-agent-task125-static.$$.json
  local scan_code=$?
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task125-static.$$.json)"
  rm -f /tmp/mc-agent-task125-static.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  case "$scan_code" in
    0)
      MC_SUMMARY="${scan_name} scan PASS for ${task_id}."
      MC_NEXT_ACTION="Use this report in TASK-125 architecture/evidence matrix."
      return "$MC_EXIT_PASS"
      ;;
    1)
      MC_SUMMARY="${scan_name} scan FAIL for ${task_id}: TASK-125 gate found required work."
      MC_NEXT_ACTION="Fix failing checks and rerun ${scan_name}."
      return "$MC_EXIT_FAIL"
      ;;
    2)
      MC_SUMMARY="${scan_name} scan BLOCKED_EXTERNAL for ${task_id}."
      MC_NEXT_ACTION="Resolve the listed external prerequisite and rerun ${scan_name}."
      return "$MC_EXIT_BLOCKED"
      ;;
    4)
      MC_SUMMARY="${scan_name} scan UNSAFE_OPERATION_REFUSED for ${task_id}."
      MC_NEXT_ACTION="Keep safety gate refused unless this was an expected refusal test."
      return "$MC_EXIT_REFUSED"
      ;;
    *)
      MC_SUMMARY="${scan_name} scan MISCONFIGURED for ${task_id}."
      MC_NEXT_ACTION="Fix TASK-125 scanner command/configuration."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_scan_task126_static() {
  local scan_name="$1"
  shift || true
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-126}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  case "$scan_name" in
    task126-policy-matrix) MC_CA_REFS="AC-126-01,AC-126-35" ;;
    owner-store-scope|no-cross-owner-store-pending-push) MC_CA_REFS="AC-126-01,AC-126-02,AC-126-12" ;;
    local-store-identity) MC_CA_REFS="AC-126-01,AC-126-36" ;;
    pending-base-version|changed-fields-contract) MC_CA_REFS="AC-126-03,AC-126-04" ;;
    conflict-review-coverage) MC_CA_REFS="AC-126-05,AC-126-06,AC-126-24" ;;
    productprice-history-policy) MC_CA_REFS="AC-126-07,AC-126-41" ;;
    cache-active-store-only|inactive-cache-cleanup-safety) MC_CA_REFS="AC-126-08,AC-126-09,AC-126-40" ;;
    scanner-self-tests) MC_CA_REFS="AC-126-37" ;;
    task126-final-gates) MC_CA_REFS="AC-126-32,AC-126-35,AC-126-37,AC-126-60" ;;
    *) MC_CA_REFS="AC-126-35" ;;
  esac

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" ANDROID_REPO="$MC_ANDROID_REPO" SUPABASE_REPO="$MC_SUPABASE_REPO" \
    python3 "$MC_AGENT_ROOT/lib/task126_scans.py" "$scan_name" > /tmp/mc-agent-task126-static.$$.json
  local scan_code=$?
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task126-static.$$.json)"
  rm -f /tmp/mc-agent-task126-static.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  case "$scan_code" in
    0)
      MC_SUMMARY="${scan_name} scan PASS for ${task_id}."
      MC_NEXT_ACTION="Use this report in TASK-126 evidence matrix."
      return "$MC_EXIT_PASS"
      ;;
    1)
      MC_SUMMARY="${scan_name} scan FAIL for ${task_id}: TASK-126 gate found required work."
      MC_NEXT_ACTION="Fix failing checks and rerun ${scan_name}."
      return "$MC_EXIT_FAIL"
      ;;
    2)
      MC_SUMMARY="${scan_name} scan BLOCKED_EXTERNAL for ${task_id}."
      MC_NEXT_ACTION="Resolve the listed external prerequisite and rerun ${scan_name}."
      return "$MC_EXIT_BLOCKED"
      ;;
    4)
      MC_SUMMARY="${scan_name} scan UNSAFE_OPERATION_REFUSED for ${task_id}."
      MC_NEXT_ACTION="Keep safety gate refused unless this was an expected refusal test."
      return "$MC_EXIT_REFUSED"
      ;;
    *)
      MC_SUMMARY="${scan_name} scan MISCONFIGURED for ${task_id}."
      MC_NEXT_ACTION="Fix TASK-126 scanner command/configuration."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_scan_task127_static() {
  local scan_name="$1"
  shift || true
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-127}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  case "$scan_name" in
    options-mainactor-heavy-fetch|productprice-full-fetch-mainactor) MC_CA_REFS="AC-127-01,AC-127-02,AC-127-03" ;;
    options-refresh-debounce) MC_CA_REFS="AC-127-05,AC-127-06" ;;
    task127-debug-hook-release-safety) MC_CA_REFS="AC-127-09,AC-127-14,AC-127-15" ;;
    android-options-performance) MC_CA_REFS="AC-127-13" ;;
    scanner-self-tests) MC_CA_REFS="AC-127-02,AC-127-04,AC-127-05,AC-127-15" ;;
    task127-final-gates) MC_CA_REFS="AC-127-01,AC-127-02,AC-127-03,AC-127-04,AC-127-05,AC-127-06,AC-127-07,AC-127-08,AC-127-09,AC-127-10,AC-127-11,AC-127-13,AC-127-14,AC-127-15" ;;
    *) MC_CA_REFS="AC-127-15" ;;
  esac

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" ANDROID_REPO="$MC_ANDROID_REPO" SUPABASE_REPO="$MC_SUPABASE_REPO" \
    python3 "$MC_AGENT_ROOT/lib/task127_scans.py" "$scan_name" > /tmp/mc-agent-task127-static.$$.json
  local scan_code=$?
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task127-static.$$.json)"
  rm -f /tmp/mc-agent-task127-static.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  case "$scan_code" in
    0)
      MC_SUMMARY="${scan_name} scan PASS for ${task_id}."
      MC_NEXT_ACTION="Use this report in TASK-127 evidence matrix."
      return "$MC_EXIT_PASS"
      ;;
    1)
      MC_SUMMARY="${scan_name} scan FAIL for ${task_id}: TASK-127 gate found required work."
      MC_NEXT_ACTION="Fix failing checks and rerun ${scan_name}."
      return "$MC_EXIT_FAIL"
      ;;
    2)
      MC_SUMMARY="${scan_name} scan BLOCKED_EXTERNAL for ${task_id}."
      MC_NEXT_ACTION="Resolve the listed external prerequisite and rerun ${scan_name}."
      return "$MC_EXIT_BLOCKED"
      ;;
    4)
      MC_SUMMARY="${scan_name} scan UNSAFE_OPERATION_REFUSED for ${task_id}."
      MC_NEXT_ACTION="Keep safety gate refused unless this was an expected refusal test."
      return "$MC_EXIT_REFUSED"
      ;;
    *)
      MC_SUMMARY="${scan_name} scan MISCONFIGURED for ${task_id}."
      MC_NEXT_ACTION="Fix TASK-127 scanner command/configuration."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_scan_task130_price_contract() {
  local task_id
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-${MC_TASK_ID:-TASK-130}}"
  MC_PLATFORM="general"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  MC_CA_REFS="AC-130-01,AC-130-02,AC-130-03,AC-130-04,AC-130-05,AC-130-06"

  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" ANDROID_REPO="$MC_ANDROID_REPO" SUPABASE_REPO="$MC_SUPABASE_REPO" \
    python3 "$MC_AGENT_ROOT/lib/task130_price_contract.py" scan-price-contract "$@" > /tmp/mc-agent-task130-price-contract.$$.json
  local scan_code=$?
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-task130-price-contract.$$.json)"
  rm -f /tmp/mc-agent-task130-price-contract.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  case "$scan_code" in
    0)
      MC_SUMMARY="price-contract scan PASS for ${task_id}."
      MC_NEXT_ACTION="Use this report in TASK-130 price contract matrix."
      return "$MC_EXIT_PASS"
      ;;
    1)
      MC_SUMMARY="price-contract scan FAIL for ${task_id}: contract checks found required work."
      MC_NEXT_ACTION="Fix failing checks and rerun scan price-contract."
      return "$MC_EXIT_FAIL"
      ;;
    2)
      MC_SUMMARY="price-contract scan BLOCKED_EXTERNAL for ${task_id}."
      MC_NEXT_ACTION="Resolve the listed external prerequisite and rerun scan price-contract."
      return "$MC_EXIT_BLOCKED"
      ;;
    4)
      MC_SUMMARY="price-contract scan UNSAFE_OPERATION_REFUSED for ${task_id}."
      MC_NEXT_ACTION="Keep safety gate refused unless this was an expected refusal test."
      return "$MC_EXIT_REFUSED"
      ;;
    *)
      MC_SUMMARY="price-contract scan MISCONFIGURED for ${task_id}."
      MC_NEXT_ACTION="Fix TASK-130 price contract scanner command/configuration."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

: <<'TASK117_LEGACY_SCANNER_DISABLED'
  TASK_ID="$task_id" IOS_REPO="$MC_IOS_REPO" python3 - > /tmp/mc-agent-no-legacy-runtime.$$.json <<'PY'
import json, os, pathlib, re
from datetime import datetime, timezone

repo = pathlib.Path(os.environ["IOS_REPO"])
task = os.environ["TASK_ID"]
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def read(rel):
    path = repo / rel
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""

checks = []

def add(check_id, status, file, reason, evidence):
    checks.append({
        "id": check_id,
        "status": status,
        "file": file,
        "reason": reason,
        "evidence": evidence[:12],
    })

orchestrator = read("iOSMerchandiseControl/Sync/SyncOrchestrator.swift")
automatic_runtime = read("iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift")
content = read("iOSMerchandiseControl/ContentView.swift")
pull = read("iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalPullService.swift")
domain = read("iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalDomainApplyService.swift")
options = read("iOSMerchandiseControl/OptionsView.swift")
domain_service_files = {
    "catalog": "iOSMerchandiseControl/Sync/Incremental/CatalogIncrementalApplyService.swift",
    "product_prices": "iOSMerchandiseControl/Sync/Incremental/ProductPriceIncrementalApplyService.swift",
    "history": "iOSMerchandiseControl/Sync/Incremental/HistoryIncrementalApplyService.swift",
}

patterns = [
    (
        "automatic_legacy_adapter_call",
        "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
        orchestrator,
        r"(?:legacyAdapter|manualAdapter)\.startForeground(?:IncrementalCheckNow|SemiAutomaticCheckIfAllowed)|via_legacy_incremental_adapter",
        "automatic foreground sync calls compatibility adapter",
    ),
    (
        "automatic_runtime_legacy_facade_reference",
        "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift",
        automatic_runtime,
        r"SupabaseManualSyncViewModel|SupabaseManualSyncCompatibilityAdapter|SupabaseSyncEventIncrementalApplyService|SupabaseManualSyncReleaseFactory|SupabaseManualSync[A-Za-z0-9_]*Providing|SupabaseManualSyncRelease[A-Za-z0-9_]*Adapter",
        "automatic runtime must not reference legacy VM, compatibility adapter, legacy incremental apply, legacy release factory, or ManualSync-named automatic provider protocols/adapters",
    ),
    (
        "automatic_runtime_missing",
        "iOSMerchandiseControl/ContentView.swift",
        content,
        r"automaticRuntime:\s*SyncAutomaticRuntimeFactory\.make",
        "ContentView must inject a non-legacy automatic runtime into SyncOrchestrator",
    ),
    (
        "legacy_incremental_apply_pass_through",
        "iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalPullService.swift",
        pull,
        r"SupabaseSyncEventIncrementalApplyService",
        "incremental pull still invokes legacy apply service",
    ),
    (
        "options_decision_remote_fetch",
        "iOSMerchandiseControl/OptionsView.swift",
        options,
        r"fetchReconciliationRemoteCounts\s*\(",
        "Options performs direct remote decision fetch",
    ),
]

for check_id, file, text, pattern, reason in patterns:
    hits = []
    for match in re.finditer(pattern, text):
        line = text.count("\n", 0, match.start()) + 1
        snippet = text.splitlines()[line - 1].strip()
        hits.append({"line": line, "snippet": snippet})
    if check_id == "automatic_runtime_missing":
        add(check_id, "PASS" if hits else "FAIL", file, reason, hits)
    else:
        add(check_id, "FAIL" if hits else "PASS", file, reason, hits)

submit_body = ""
submit_match = re.search(r"func\s+submitForegroundTrigger[\s\S]*?\n    func\s+cancelForegroundCheck", orchestrator)
if submit_match:
    submit_body = submit_match.group(0)
submit_manual_hits = []
for match in re.finditer(r"manualAdapter\.|legacyAdapter\.|legacyManualSyncViewModel", submit_body):
    line = orchestrator.count("\n", 0, submit_match.start() + match.start()) + 1 if submit_match else 0
    submit_manual_hits.append({
        "line": line,
        "snippet": orchestrator.splitlines()[line - 1].strip() if line else match.group(0),
    })
add(
    "submit_foreground_manual_facade_reference",
    "FAIL" if submit_manual_hits else "PASS",
    "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
    "submitForegroundTrigger must schedule SyncAutomaticRuntime without manual facade calls",
    submit_manual_hits,
)

missing_domain_files = []
for domain_name, rel in domain_service_files.items():
    if not (repo / rel).exists():
        missing_domain_files.append({"line": 0, "snippet": f"missing {rel}"})
add(
    "domain_service_files_present",
    "FAIL" if missing_domain_files else "PASS",
    "iOSMerchandiseControl/Sync/Incremental",
    "Catalog/ProductPrice/History domain service files must be physical services, not DTO-only summaries",
    missing_domain_files,
)

domain_dispatch_hits = []
for service_name in [
    "CatalogIncrementalApplyService",
    "ProductPriceIncrementalApplyService",
    "HistoryIncrementalApplyService",
]:
    if service_name not in domain:
        domain_dispatch_hits.append({"line": 0, "snippet": f"missing dispatcher reference to {service_name}"})
add(
    "domain_dispatcher_uses_real_services",
    "FAIL" if domain_dispatch_hits else "PASS",
    "iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalDomainApplyService.swift",
    "SyncEventIncrementalDomainApplyService must dispatch to concrete domain services",
    domain_dispatch_hits,
)

duplicate_owner_hits = []
if "startSyncEventSafetyLoopIfNeeded" in orchestrator and "manualAdapter.presentationState.isRunning" in orchestrator:
    duplicate_owner_hits.append({
        "line": 0,
        "snippet": "SyncOrchestrator has safety loop while consulting legacy adapter running state",
    })
add(
    "duplicate_sync_owner_risk",
    "FAIL" if duplicate_owner_hits else "PASS",
    "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
    "duplicate automatic owner/timer risk",
    duplicate_owner_hits,
)

failures = [check for check in checks if check["status"] == "FAIL"]
payload = {
    "schemaVersion": "1.1",
    "taskId": task,
    "source": "scan.no-legacy-runtime-path",
    "startedAt": now,
    "completedAt": now,
    "status": "FAIL" if failures else "PASS",
    "NEXT_ACTION": "Remove automatic legacy path and rerun." if failures else "Run live no-legacy-runtime-path.",
    "checks": checks,
    "failureCount": len(failures),
}
print(json.dumps(payload, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-no-legacy-runtime.$$.json)"
  rm -f /tmp/mc-agent-no-legacy-runtime.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  if [[ "$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status"))' <<<"$MC_SYNC_JSON_RESULT")" == "PASS" ]]; then
    MC_SUMMARY="No-legacy-runtime-path scan PASS for ${task_id}: automatic runtime path has no forbidden legacy calls."
    MC_NEXT_ACTION="Run live no-legacy-runtime-path and no-full-pull-normal-path."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="No-legacy-runtime-path scan FAIL for ${task_id}: forbidden automatic legacy path remains."
  MC_NEXT_ACTION="Remove automatic VM/adapter/legacy apply/full-pull path and rerun."
  return "$MC_EXIT_FAIL"
}
TASK117_LEGACY_SCANNER_DISABLED

mc_cmd_evidence() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    hygiene)
      mc_cmd_scan_evidence "$@"
      ;;
    bundle)
      mc_cmd_scan_task117_static evidence-bundle "$@"
      ;;
    *)
      MC_SUMMARY="Unknown evidence subcommand: ${sub}"
      MC_NEXT_ACTION="Use evidence hygiene|bundle --task TASK-117."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_account_fixture_report() {
  local action="$1"
  local task_id="$2"
  local prefix="$3"
  local dry_run="$4"
  TASK_ID="$task_id" PREFIX="$prefix" ACTION="$action" DRY_RUN="$dry_run" python3 - > /tmp/mc-agent-account-fixture.$$.json <<'PY'
import json, os
from datetime import datetime, timezone

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
scenarios = list("ABCDEFGHIJKL")
status = "PASS" if os.environ["DRY_RUN"] == "1" else "BLOCKED"
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "source": f"account.fixture.{os.environ['ACTION']}",
    "startedAt": now,
    "completedAt": now,
    "status": status,
    "prefix": os.environ["PREFIX"],
    "dryRun": os.environ["DRY_RUN"] == "1",
    "NEXT_ACTION": "Review fixture plan; enable live credentials before execute." if status == "PASS" else "Use --dry-run or provide explicit live fixture approval.",
    "mutationPerformed": False,
    "scenarios": [{"scenario": name, "fixturePrefix": f"{os.environ['PREFIX']}{name}_", "status": "NOT_RUN"} for name in scenarios],
}, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-account-fixture.$$.json)"
  rm -f /tmp/mc-agent-account-fixture.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
}

mc_cmd_account() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    fixture)
      local action="${1:-}"
      shift || true
      local task_id prefix dry_run
      task_id="$(mc_parse_opt --task "$@" || true)"
      task_id="${task_id:-$MC_TASK_ID}"
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      dry_run="0"
      [[ " $* " == *" --dry-run "* ]] && dry_run="1"
      mc_validate_task_prefix "$prefix" || return $?
      MC_PLATFORM="general"
      MC_SAFETY_LEVEL="safe-readonly"
      MC_TEST_PREFIX="$prefix"
      case "$action" in
        prepare|cleanup)
          if [[ "$action" == "cleanup" ]]; then
            dry_run="1"
          fi
          mc_account_fixture_report "$action" "$task_id" "$prefix" "$dry_run"
          MC_SUMMARY="Account fixture ${action} dry-run PASS for ${prefix}: no mutation performed."
          MC_NEXT_ACTION="Implement scoped live fixtures before strict account matrix can PASS."
          return "$MC_EXIT_PASS"
          ;;
        *)
          MC_SUMMARY="Unknown account fixture action: ${action}"
          MC_NEXT_ACTION="Use account fixture prepare|cleanup."
          return "$MC_EXIT_MISCONFIGURED"
          ;;
      esac
      ;;
    *)
      MC_SUMMARY="Unknown account subcommand: ${sub}"
      MC_NEXT_ACTION="Use account fixture prepare|cleanup."
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_cmd_safety() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    check-prefix)
      local prefix
      prefix="$(mc_parse_opt --prefix "$@")" || return "$MC_EXIT_REFUSED"
      mc_validate_task_prefix "$prefix" || return $?
      MC_SUMMARY="Prefix safety PASS: ${prefix}"
      MC_NEXT_ACTION="Use prefix only for scoped test data."
      return "$MC_EXIT_PASS"
      ;;
    dry-run-required)
      local command
      command="$(mc_parse_opt --command "$@")" || return "$MC_EXIT_MISCONFIGURED"
      if [[ "$command" == *cleanup* && "$command" == *--execute* && "$command" != *--cleanup-plan-id* ]]; then
        MC_SUMMARY="Unsafe command refused: cleanup execute requires cleanup_plan_id from dry-run."
        MC_NEXT_ACTION="Run cleanup --dry-run first and pass --cleanup-plan-id."
        return "$MC_EXIT_REFUSED"
      fi
      if [[ "$command" == *cleanup* && "$command" != *--dry-run* && "$command" != *--execute* ]]; then
        MC_SUMMARY="Unsafe command refused: cleanup requires --dry-run or --execute."
        MC_NEXT_ACTION="Add --dry-run for preview."
        return "$MC_EXIT_REFUSED"
      fi
      MC_SUMMARY="Safety dry-run-required check PASS for command."
      MC_NEXT_ACTION="Run through mc-agent, not raw shell."
      return "$MC_EXIT_PASS"
      ;;
    *)
      MC_SUMMARY="Unknown safety subcommand: ${sub}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}
