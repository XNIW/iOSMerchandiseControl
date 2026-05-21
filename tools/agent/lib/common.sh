#!/usr/bin/env bash

MC_AGENT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MC_AGENT_VERSION="0.2.0-task113"
MC_SCHEMA_VERSION="1.1"

MC_IOS_REPO="${MC_IOS_REPO:-/Users/minxiang/Desktop/iOSMerchandiseControl}"
MC_ANDROID_REPO="${MC_ANDROID_REPO:-/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView}"
MC_SUPABASE_REPO="${MC_SUPABASE_REPO:-/Users/minxiang/Desktop/MerchandiseControlSupabase}"
MC_TASK_ID="${MC_TASK_ID:-TASK-113}"
MC_EVIDENCE_DIR="${MC_EVIDENCE_DIR:-docs/TASKS/EVIDENCE/TASK-113}"

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
}

mc_load_config() {
  local cfg="${MC_AGENT_CONFIG:-${MC_AGENT_ROOT}/config.env}"
  local had_allow_live="${MC_ALLOW_LIVE+x}"
  local had_allow_cleanup="${MC_ALLOW_CLEANUP+x}"
  local had_profile="${MC_SUPABASE_PROFILE+x}"
  local env_allow_live="${MC_ALLOW_LIVE:-}"
  local env_allow_cleanup="${MC_ALLOW_CLEANUP:-}"
  local env_profile="${MC_SUPABASE_PROFILE:-}"
  if [[ -f "$cfg" ]]; then
    # shellcheck source=/dev/null
    source "$cfg"
  elif [[ -f "${MC_AGENT_ROOT}/config.example.env" ]]; then
    # shellcheck source=/dev/null
    source "${MC_AGENT_ROOT}/config.example.env"
  fi
  [[ -n "$had_allow_live" ]] && MC_ALLOW_LIVE="$env_allow_live"
  [[ -n "$had_allow_cleanup" ]] && MC_ALLOW_CLEANUP="$env_allow_cleanup"
  [[ -n "$had_profile" ]] && MC_SUPABASE_PROFILE="$env_profile"

  export MC_IOS_REPO MC_ANDROID_REPO MC_SUPABASE_REPO MC_TASK_ID MC_EVIDENCE_DIR
  export MC_AGENT_VERSION MC_SCHEMA_VERSION MC_ALLOW_LIVE MC_ALLOW_CLEANUP
  export MC_IOS_SCHEME MC_IOS_SIMULATOR_NAME MC_IOS_SIMULATOR_OS MC_IOS_DESTINATION
  export MC_ANDROID_DEVICE_SERIAL MC_ANDROID_SDK_ROOT MC_SUPABASE_PROJECT_REF MC_SUPABASE_PROFILE
  export MC_REDACT_EMAILS MC_REDACT_PATHS MC_RUN_PREFIX

  if [[ -d "$MC_IOS_REPO" ]]; then
    MC_EVIDENCE_ABS="$(cd "$MC_IOS_REPO" && mkdir -p "$MC_EVIDENCE_DIR" && cd "$MC_EVIDENCE_DIR" && pwd)"
  else
    MC_EVIDENCE_ABS="$MC_IOS_REPO/$MC_EVIDENCE_DIR"
  fi
  export MC_EVIDENCE_ABS

  export MC_ANDROID_SDK_ROOT="${MC_ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
  export PATH="${MC_ANDROID_SDK_ROOT}/platform-tools:${MC_ANDROID_SDK_ROOT}/tools:${PATH}"
  if [[ -n "${MC_ANDROID_JAVA_HOME:-}" && -d "$MC_ANDROID_JAVA_HOME" ]]; then
    export JAVA_HOME="$MC_ANDROID_JAVA_HOME"
  fi
  export GRADLE_OPTS="${MC_ANDROID_GRADLE_OPTS:-}"
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
    MC_NEXT_ACTION="Example: --prefix TASK113_DRYRUN_ or --prefix 'TASK113_*'."
    return "$MC_EXIT_REFUSED"
  fi
  if [[ "$require_offline" == "1" && "$prefix" != *OFFLINE* ]]; then
    MC_SUMMARY="Offline prefix must contain OFFLINE."
    MC_NEXT_ACTION="Example: --prefix TASK113_OFFLINE_L2_"
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
  MC_RESULT_OVERRIDE="pass_with_notes"
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
  ./tools/agent/mc-agent.sh doctor | preflight | config validate | config print-redacted
  ./tools/agent/mc-agent.sh list commands | list commands-json
  ./tools/agent/mc-agent.sh report --task TASK-113 | report --latest | report validate-json --path <file>
  ./tools/agent/mc-agent.sh scan sensitive [path...] | scan evidence --task TASK-113 | scan repo-diff | scan release-cta
  ./tools/agent/mc-agent.sh safety check-prefix --prefix TASK113_* | safety dry-run-required --command "<command>"
  ./tools/agent/mc-agent.sh ios build debug|release | ios test sync|lifecycle|offline | ios smoke simulator|options
  ./tools/agent/mc-agent.sh android build debug|release | android test sync|offline | android offline-tier-status
  ./tools/agent/mc-agent.sh android offline-write|reconnect-drain --tier L1|L2|L3 --prefix TASK113_OFFLINE_*
  ./tools/agent/mc-agent.sh supabase status-redacted|verify-schema|verify-rls|verify-grants|residue-check --profile local|linked|dry-run-no-db
  ./tools/agent/mc-agent.sh live sync-matrix|offline-matrix|cleanup-and-verify --task TASK-113 --prefix TASK113_*

Exit codes: 0=PASS 1=FAIL 2=BLOCKED 3=MISCONFIGURED 4=UNSAFE_OPERATION_REFUSED
Reports: docs/TASKS/EVIDENCE/<task>/agent-runs/<timestamp>-<command>.{log,md,json}
HELP
}

mc_help_json() {
  cat <<'JSON'
{
  "schema_version": "1.1",
  "name": "mc-agent",
  "version": "0.2.0-task113",
  "exit_codes": {
    "0": "PASS",
    "1": "FAIL",
    "2": "BLOCKED",
    "3": "MISCONFIGURED",
    "4": "UNSAFE_OPERATION_REFUSED"
  },
  "commands": [
    {"name":"help","argv":["help"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"help-json","argv":["help-json"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"version","argv":["version"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"doctor","argv":["doctor"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"preflight","argv":["preflight"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"config validate","argv":["config","validate"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"config print-redacted","argv":["config","print-redacted"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"list commands","argv":["list","commands"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"list commands-json","argv":["list","commands-json"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report --task","argv":["report","--task","TASK-113"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report --latest","argv":["report","--latest"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"report validate-json","argv":["report","validate-json","--path","<file>"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan sensitive","argv":["scan","sensitive"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan evidence","argv":["scan","evidence","--task","TASK-113"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan repo-diff","argv":["scan","repo-diff"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"scan release-cta","argv":["scan","release-cta"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"safety check-prefix","argv":["safety","check-prefix","--prefix","TASK113_*"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"safety dry-run-required","argv":["safety","dry-run-required","--command","<command>"],"platform":"general","safety_level":"safe-readonly"},
    {"name":"ios build debug","argv":["ios","build","debug"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios build release","argv":["ios","build","release"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test sync","argv":["ios","test","sync"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test lifecycle","argv":["ios","test","lifecycle"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios test offline","argv":["ios","test","offline"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke simulator","argv":["ios","smoke","simulator"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios smoke options","argv":["ios","smoke","options"],"platform":"ios","safety_level":"safe-readonly"},
    {"name":"ios auth-preflight","argv":["ios","auth-preflight","--live"],"platform":"ios","safety_level":"live-write","requires_live":true},
    {"name":"ios live-write","argv":["ios","live-write","--prefix","TASK113_*"],"platform":"ios","safety_level":"live-write","requires_live":true},
    {"name":"ios cleanup-scoped","argv":["ios","cleanup-scoped","--prefix","TASK113_*","--dry-run"],"platform":"ios","safety_level":"cleanup-dry-run"},
    {"name":"android build debug","argv":["android","build","debug"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android build release","argv":["android","build","release"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test sync","argv":["android","test","sync"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android test offline","argv":["android","test","offline"],"platform":"android","safety_level":"safe-readonly","android_offline_tier":"L1"},
    {"name":"android smoke device","argv":["android","smoke","device"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android smoke options","argv":["android","smoke","options"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android auth-preflight","argv":["android","auth-preflight","--live"],"platform":"android","safety_level":"live-write","requires_live":true},
    {"name":"android live-pull","argv":["android","live-pull","--prefix","TASK113_*"],"platform":"android","safety_level":"live-write","requires_live":true},
    {"name":"android live-write","argv":["android","live-write","--prefix","TASK113_*"],"platform":"android","safety_level":"live-write","requires_live":true},
    {"name":"android offline-tier-status","argv":["android","offline-tier-status"],"platform":"android","safety_level":"safe-readonly"},
    {"name":"android offline-write","argv":["android","offline-write","--tier","L1","--prefix","TASK113_OFFLINE_*"],"platform":"android","safety_level":"safe-readonly","android_offline_tier":"L1"},
    {"name":"android reconnect-drain","argv":["android","reconnect-drain","--tier","L1","--prefix","TASK113_OFFLINE_*"],"platform":"android","safety_level":"safe-readonly","android_offline_tier":"L1"},
    {"name":"supabase start","argv":["supabase","start"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase status-redacted","argv":["supabase","status-redacted"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase verify-schema","argv":["supabase","verify-schema"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase verify-rls","argv":["supabase","verify-rls"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase verify-grants","argv":["supabase","verify-grants"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase explain-cleanup","argv":["supabase","explain-cleanup","--prefix","TASK113_*"],"platform":"supabase","safety_level":"cleanup-dry-run"},
    {"name":"supabase cleanup dry-run","argv":["supabase","cleanup","--task","TASK-113","--prefix","TASK113_*","--dry-run"],"platform":"supabase","safety_level":"cleanup-dry-run","requires_cleanup":true},
    {"name":"supabase cleanup execute","argv":["supabase","cleanup","--task","TASK-113","--prefix","TASK113_*","--execute","--cleanup-plan-id","<id>"],"platform":"supabase","safety_level":"cleanup-execute","requires_cleanup":true},
    {"name":"supabase residue-check","argv":["supabase","residue-check","--prefix","TASK113_*","--profile","dry-run-no-db"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"supabase pooler-cooldown-check","argv":["supabase","pooler-cooldown-check"],"platform":"supabase","safety_level":"safe-readonly"},
    {"name":"live sync-matrix","argv":["live","sync-matrix","--task","TASK-113","--prefix","TASK113_FINAL_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live offline-matrix","argv":["live","offline-matrix","--task","TASK-113","--prefix","TASK113_OFFLINE_*"],"platform":"live","safety_level":"live-write","requires_live":true},
    {"name":"live cleanup-and-verify","argv":["live","cleanup-and-verify","--task","TASK-113","--prefix","TASK113_*"],"platform":"live","safety_level":"cleanup-execute","requires_cleanup":true}
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
import json, sys
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

mc_cmd_preflight() {
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
  MC_NEXT_ACTION="Run build/test commands."
  return "$MC_EXIT_PASS"
}

mc_cmd_report_validate_json() {
  local paths=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
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
import json, sys
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
for path in sys.argv[1:]:
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
if invalid:
    print("INVALID")
    for item in invalid:
        print(item)
    sys.exit(1)
print(f"VALID {len(sys.argv) - 1} JSON report(s)")
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
  MC_NEXT_ACTION="Use evidence in TASK-113 closure matrix."
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
