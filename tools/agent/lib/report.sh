#!/usr/bin/env bash

mc_report_init_paths() {
  MC_TIMESTAMP="${MC_TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
  MC_CMD_SLUG="${MC_CMD_SLUG:-$(mc_slugify "${MC_COMMAND:-unknown}")}"
  MC_RUN_ID="${MC_RUN_ID:-${MC_TIMESTAMP}-${MC_CMD_SLUG}-p$$}"
  MC_RUN_DIR="${MC_EVIDENCE_ABS}/agent-runs"
  mkdir -p "$MC_RUN_DIR"
  MC_LOG_PATH="${MC_RUN_DIR}/${MC_RUN_ID}.log"
  MC_MD_PATH="${MC_RUN_DIR}/${MC_RUN_ID}.md"
  MC_JSON_PATH="${MC_RUN_DIR}/${MC_RUN_ID}.json"
  MC_LOG_TMP="${MC_LOG_PATH}.tmp"
  MC_MD_TMP="${MC_MD_PATH}.tmp"
  MC_JSON_TMP="${MC_JSON_PATH}.tmp"
  : > "$MC_LOG_TMP"
}

mc_report_log() {
  local line="${1:-}"
  line="$(mc_redact_text "$line")"
  printf '%s\n' "$line" >> "${MC_LOG_TMP:-/dev/null}"
}

mc_report_map_result() {
  local code="$1"
  if [[ -n "${MC_RESULT_OVERRIDE:-}" ]]; then
    printf '%s' "$MC_RESULT_OVERRIDE"
    return 0
  fi
  case "$code" in
    0) printf 'pass' ;;
    1) printf 'fail' ;;
    2) printf 'blocked' ;;
    3) printf 'misconfigured' ;;
    4) printf 'refused' ;;
    *) printf 'fail' ;;
  esac
}

mc_report_json_array_from_csv() {
  local value="${1:-}"
  python3 - "$value" <<'PY'
import json, sys
items = [x.strip() for x in sys.argv[1].replace("\n", ",").split(",") if x.strip()]
print(json.dumps(items))
PY
}

mc_report_write() {
  local exit_code="${1:-1}"
  local summary="${2:-}"
  local next_action="${3:-Review log and retry.}"
  local duration_ms="${4:-0}"
  local rows_created="${5:-0}"
  local rows_deleted="${6:-0}"
  local residue_count="${7:-0}"
  local test_prefix="${8:-}"
  local result ca_json warnings_json env_json device_json

  result="$(mc_report_map_result "$exit_code")"
  summary="$(mc_redact_text "$summary")"
  next_action="$(mc_redact_text "$next_action")"
  ca_json="$(mc_report_json_array_from_csv "${MC_CA_REFS:-}")"
  warnings_json="$(mc_report_json_array_from_csv "${MC_WARNINGS:-}")"

  env_json="$(python3 - <<'PY'
import json, os, re
keys = [
    "MC_TASK_ID","MC_IOS_REPO","MC_ANDROID_REPO","MC_SUPABASE_REPO",
    "MC_EVIDENCE_DIR","MC_ALLOW_LIVE","MC_ALLOW_CLEANUP","MC_IOS_SCHEME",
    "MC_IOS_SIMULATOR_NAME","MC_ANDROID_DEVICE_SERIAL","MC_SUPABASE_PROFILE",
    "MC_RUN_PREFIX"
]
redact_paths = os.environ.get("MC_REDACT_PATHS", "1") == "1"
out = {}
for key in keys:
    value = os.environ.get(key, "")
    if not value:
        out[key] = "<unset>"
    elif "SERIAL" in key or "PROJECT_REF" in key:
        out[key] = "<REDACTED>"
    elif redact_paths and value.startswith("/Users/"):
        out[key] = re.sub(r"^/Users/[^/]+", "<HOME_REDACTED>", value)
    else:
        out[key] = value
print(json.dumps(out))
PY
)"
  device_json="$(python3 - <<'PY'
import json, os
print(json.dumps({
    "ios_simulator": os.environ.get("MC_IOS_SIMULATOR_NAME", ""),
    "ios_destination": os.environ.get("MC_IOS_DESTINATION", ""),
    "android_serial": "<REDACTED>" if os.environ.get("MC_ANDROID_DEVICE_SERIAL") else ""
}))
PY
)"

  export MC_REPORT_SCHEMA_VERSION="$MC_SCHEMA_VERSION"
  export MC_REPORT_RUN_ID="$MC_RUN_ID"
  export MC_REPORT_TASK_ID="${MC_TASK_ID:-TASK-113}"
  export MC_REPORT_COMMAND="${MC_COMMAND:-unknown}"
  export MC_REPORT_COMMAND_SLUG="$MC_CMD_SLUG"
  export MC_REPORT_PLATFORM="${MC_PLATFORM:-general}"
  export MC_REPORT_SAFETY_LEVEL="${MC_SAFETY_LEVEL:-safe-readonly}"
  export MC_REPORT_REQUIRES_LIVE="${MC_REQUIRES_LIVE:-false}"
  export MC_REPORT_REQUIRES_CLEANUP="${MC_REQUIRES_CLEANUP:-false}"
  export MC_REPORT_PROFILE="${MC_PROFILE:-null}"
  export MC_REPORT_ANDROID_TIER="${MC_ANDROID_OFFLINE_TIER:-none}"
  export MC_REPORT_TIMESTAMP_START="${MC_TIMESTAMP_START_ISO:-}"
  export MC_REPORT_TIMESTAMP_END="${MC_TIMESTAMP_END_ISO:-}"
  export MC_REPORT_DURATION_MS="$duration_ms"
  export MC_REPORT_REPO="${MC_ACTIVE_REPO:-$MC_IOS_REPO}"
  export MC_REPORT_BRANCH="${MC_GIT_BRANCH:-unknown}"
  export MC_REPORT_GIT_SHA="${MC_GIT_SHA:-unknown}"
  export MC_REPORT_DIRTY="${MC_GIT_DIRTY:-unknown}"
  export MC_REPORT_ENV_JSON="$env_json"
  export MC_REPORT_DEVICE_JSON="$device_json"
  export MC_REPORT_TEST_PREFIX="${test_prefix:-}"
  export MC_REPORT_CLEANUP_PLAN_ID="${MC_CLEANUP_PLAN_ID:-}"
  export MC_REPORT_RESULT="$result"
  export MC_REPORT_EXIT_CODE="$exit_code"
  export MC_REPORT_ROWS_CREATED="$rows_created"
  export MC_REPORT_ROWS_DELETED="$rows_deleted"
  export MC_REPORT_RESIDUE_COUNT="$residue_count"
  export MC_REPORT_MD_REL="$(mc_relpath "$MC_MD_PATH")"
  export MC_REPORT_JSON_REL="$(mc_relpath "$MC_JSON_PATH")"
  export MC_REPORT_LOG_REL="$(mc_relpath "$MC_LOG_PATH")"
  export MC_REPORT_XCRESULT="${MC_ARTIFACT_XCRESULT:-}"
  export MC_REPORT_SCREENSHOT="${MC_ARTIFACT_SCREENSHOT:-}"
  export MC_REPORT_CA_JSON="$ca_json"
  export MC_REPORT_WARNINGS_JSON="$warnings_json"
  export MC_REPORT_NEXT_ACTION="$next_action"
  export MC_REPORT_RECONCILIATION_JSON="${MC_RECONCILIATION_JSON:-}"

  python3 - <<'PY' > "$MC_JSON_TMP"
import json, os

def bool_env(name):
    return os.environ.get(name, "false").lower() in {"1", "true", "yes"}

payload = {
    "schema_version": os.environ["MC_REPORT_SCHEMA_VERSION"],
    "run_id": os.environ["MC_REPORT_RUN_ID"],
    "task_id": os.environ["MC_REPORT_TASK_ID"],
    "command": os.environ["MC_REPORT_COMMAND"],
    "command_slug": os.environ["MC_REPORT_COMMAND_SLUG"],
    "platform": os.environ["MC_REPORT_PLATFORM"],
    "safety_level": os.environ["MC_REPORT_SAFETY_LEVEL"],
    "requires_live": bool_env("MC_REPORT_REQUIRES_LIVE"),
    "requires_cleanup": bool_env("MC_REPORT_REQUIRES_CLEANUP"),
    "profile": os.environ["MC_REPORT_PROFILE"] or "null",
    "android_offline_tier": os.environ["MC_REPORT_ANDROID_TIER"],
    "timestamp_start": os.environ["MC_REPORT_TIMESTAMP_START"],
    "timestamp_end": os.environ["MC_REPORT_TIMESTAMP_END"],
    "duration_ms": int(os.environ["MC_REPORT_DURATION_MS"]),
    "repo": os.environ["MC_REPORT_REPO"],
    "branch": os.environ["MC_REPORT_BRANCH"],
    "git_sha": os.environ["MC_REPORT_GIT_SHA"],
    "dirty_state": os.environ["MC_REPORT_DIRTY"],
    "env_redacted": json.loads(os.environ["MC_REPORT_ENV_JSON"]),
    "device_simulator_redacted": json.loads(os.environ["MC_REPORT_DEVICE_JSON"]),
    "test_prefix": os.environ["MC_REPORT_TEST_PREFIX"] or None,
    "cleanup_plan_id": os.environ["MC_REPORT_CLEANUP_PLAN_ID"] or None,
    "result": os.environ["MC_REPORT_RESULT"],
    "exit_code": int(os.environ["MC_REPORT_EXIT_CODE"]),
    "rows_created": int(os.environ["MC_REPORT_ROWS_CREATED"]),
    "rows_deleted": int(os.environ["MC_REPORT_ROWS_DELETED"]),
    "residue_count": int(os.environ["MC_REPORT_RESIDUE_COUNT"]),
    "raw_log_redacted": True,
    "artifact_paths": {
        "markdown": os.environ["MC_REPORT_MD_REL"],
        "json": os.environ["MC_REPORT_JSON_REL"],
        "log": os.environ["MC_REPORT_LOG_REL"],
        "xcresult": os.environ["MC_REPORT_XCRESULT"] or None,
        "screenshot": os.environ["MC_REPORT_SCREENSHOT"] or None,
    },
    "ca_refs": json.loads(os.environ["MC_REPORT_CA_JSON"]),
    "warnings": json.loads(os.environ["MC_REPORT_WARNINGS_JSON"]),
    "next_action_recommended": os.environ["MC_REPORT_NEXT_ACTION"],
}
detail = os.environ.get("MC_REPORT_RECONCILIATION_JSON", "").strip()
if detail:
    try:
        payload["reconciliation"] = json.loads(detail)
    except Exception as exc:
        payload["reconciliation_parse_error"] = str(exc)
print(json.dumps(payload, indent=2, sort_keys=True))
PY

  cat > "$MC_MD_TMP" <<MD
# mc-agent report

- **Schema**: ${MC_SCHEMA_VERSION}
- **Run ID**: ${MC_RUN_ID}
- **Task**: ${MC_TASK_ID:-TASK-113}
- **Command**: \`${MC_COMMAND:-unknown}\`
- **Platform**: ${MC_PLATFORM:-general}
- **Safety**: ${MC_SAFETY_LEVEL:-safe-readonly}
- **Result**: ${result} (exit ${exit_code})
- **Duration**: ${duration_ms} ms
- **Repo**: $(mc_redact_text "${MC_ACTIVE_REPO:-$MC_IOS_REPO}")
- **Branch**: ${MC_GIT_BRANCH:-unknown}
- **Git SHA**: ${MC_GIT_SHA:-unknown}
- **Dirty**: ${MC_GIT_DIRTY:-unknown}
- **Profile**: ${MC_PROFILE:-null}
- **Android offline tier**: ${MC_ANDROID_OFFLINE_TIER:-none}
- **Cleanup plan ID**: ${MC_CLEANUP_PLAN_ID:-n/a}

## Summary

${summary}

## Counts

- rows_created: ${rows_created}
- rows_deleted: ${rows_deleted}
- residue_count: ${residue_count}

## Artifacts

- Markdown: \`$(mc_relpath "$MC_MD_PATH")\`
- JSON: \`$(mc_relpath "$MC_JSON_PATH")\`
- Log: \`$(mc_relpath "$MC_LOG_PATH")\`
- xcresult: \`${MC_ARTIFACT_XCRESULT:-n/a}\`
- screenshot: \`${MC_ARTIFACT_SCREENSHOT:-n/a}\`

## Next Action

${next_action}
MD

  if [[ -n "${MC_RECONCILIATION_MD:-}" ]]; then
    {
      printf '\n## Reconciliation Detail\n\n'
      printf '%s\n' "$(mc_redact_text "$MC_RECONCILIATION_MD")"
    } >> "$MC_MD_TMP"
  fi

  mc_redact_file_inplace "$MC_LOG_TMP"
  mc_redact_file_inplace "$MC_MD_TMP"
  mc_redact_file_inplace "$MC_JSON_TMP"
  mv "$MC_LOG_TMP" "$MC_LOG_PATH"
  mv "$MC_MD_TMP" "$MC_MD_PATH"
  mv "$MC_JSON_TMP" "$MC_JSON_PATH"
}

mc_print_final_summary() {
  local exit_code="$1"
  local result
  result="$(mc_report_map_result "$exit_code")"
  printf 'RESULT %s\n' "$result"
  printf 'EXIT_CODE %s\n' "$exit_code"
  printf 'REPORT_MD %s\n' "$(mc_relpath "$MC_MD_PATH")"
  printf 'REPORT_JSON %s\n' "$(mc_relpath "$MC_JSON_PATH")"
  printf 'NEXT_ACTION %s\n' "${MC_NEXT_ACTION:-Review report.}"
}
