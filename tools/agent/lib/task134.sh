#!/usr/bin/env bash

mc_task134_default_prefix() {
  printf '%s' "${MC_TASK134_PREFIX:-TASK134_FINAL_}"
}

mc_task134_run_python() {
  local action="$1"
  shift
  local out_file code
  out_file="$(mktemp -t mc-agent-task134)"
  TASK134_ACTION="$action" \
  MC_AGENT_ROOT="$MC_AGENT_ROOT" \
  MC_IOS_REPO="$MC_IOS_REPO" \
  MC_ANDROID_REPO="$MC_ANDROID_REPO" \
  MC_SUPABASE_REPO="$MC_SUPABASE_REPO" \
  MC_TASK_ID="$MC_TASK_ID" \
  MC_EVIDENCE_ABS="$MC_EVIDENCE_ABS" \
  MC_EVIDENCE_DIR="$MC_EVIDENCE_DIR" \
  MC_ALLOW_LIVE="${MC_ALLOW_LIVE:-}" \
  MC_ALLOW_CLEANUP="${MC_ALLOW_CLEANUP:-}" \
  MC_ANDROID_DEVICE_SERIAL="${MC_ANDROID_DEVICE_SERIAL:-}" \
  MC_IOS_SIMULATOR_ID="${MC_IOS_SIMULATOR_ID:-}" \
  MC_IOS_SIMULATOR_UDID="${MC_IOS_SIMULATOR_UDID:-}" \
  python3 "$MC_AGENT_ROOT/lib/task134_live.py" "$action" "$@" > "$out_file" 2>&1
  code=$?
  cat "$out_file"
  MC_TASK134_LAST_OUTPUT="$(cat "$out_file")"
  rm -f "$out_file"
  return "$code"
}

mc_task134_load_result_detail() {
  local json_path="$1"
  if [[ -f "$json_path" ]]; then
    MC_SYNC_JSON_RESULT="$(cat "$json_path")"
    mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
    MC_SUMMARY="$(python3 - "$json_path" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
print(payload.get("summary") or f"{payload.get('command')} {payload.get('status')}")
PY
)"
    MC_NEXT_ACTION="$(python3 - "$json_path" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
print(payload.get("nextAction") or "Review TASK-134 evidence.")
PY
)"
    MC_ROWS_CREATED="$(python3 - "$json_path" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
print(int(payload.get("rowsCreated", 0) or 0))
PY
)"
    MC_ROWS_DELETED="$(python3 - "$json_path" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
print(int(payload.get("rowsDeleted", 0) or 0))
PY
)"
    MC_RESIDUE_COUNT="$(python3 - "$json_path" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
print(int(payload.get("residueCount", 0) or 0))
PY
)"
  fi
}

mc_cmd_task134_live() {
  local sub="$1"
  shift || true
  local task_id prefix
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-$MC_TASK_ID}"
  prefix="$(mc_parse_opt --prefix "$@" || true)"
  prefix="${prefix:-$(mc_task134_default_prefix)}"
  MC_PLATFORM="live"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_REQUIRES_CLEANUP="true"
  MC_CA_REFS="TASK-134-F2,TASK-134-F3,TASK-134-F4,TASK-134-F5,TASK-134-F6,TASK-134-F7,TASK-134-F8,TASK-134-F9,TASK-134-F10"
  MC_TEST_PREFIX="$prefix"
  mc_require_live || return $?
  if [[ "$task_id" != "TASK-134" ]]; then
    MC_SUMMARY="TASK-134 live command refused for task ${task_id}."
    MC_NEXT_ACTION="Rerun with MC_TASK_ID=TASK-134 or --task TASK-134."
    return "$MC_EXIT_REFUSED"
  fi
  mc_validate_task_prefix "$prefix" || return $?
  if ! [[ "$prefix" == TASK134_* ]]; then
    MC_SUMMARY="TASK-134 prefix must start with TASK134_."
    MC_NEXT_ACTION="Use --prefix TASK134_FINAL_."
    return "$MC_EXIT_REFUSED"
  fi
  mc_task134_run_python live "$sub" --task "$task_id" --prefix "$prefix" "$@"
  local code=$?
  mc_task134_load_result_detail "$MC_EVIDENCE_ABS/task134-${sub#task134-}.json"
  return "$code"
}

mc_cmd_task134_cleanup() {
  local sub="${1:-}"
  shift || true
  if [[ "$sub" != "task134-all" ]]; then
    MC_SUMMARY="Unknown cleanup subcommand: ${sub}"
    MC_NEXT_ACTION="Use cleanup task134-all --task TASK-134 --prefix TASK134_."
    return "$MC_EXIT_MISCONFIGURED"
  fi
  local task_id prefix
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-$MC_TASK_ID}"
  prefix="$(mc_parse_opt --prefix "$@" || true)"
  prefix="${prefix:-TASK134_}"
  MC_PLATFORM="live"
  MC_SAFETY_LEVEL="cleanup-execute"
  MC_REQUIRES_LIVE="true"
  MC_REQUIRES_CLEANUP="true"
  MC_TEST_PREFIX="$prefix"
  mc_require_live || return $?
  if [[ "$task_id" != "TASK-134" ]]; then
    MC_SUMMARY="TASK-134 cleanup refused for task ${task_id}."
    MC_NEXT_ACTION="Rerun with MC_TASK_ID=TASK-134 or --task TASK-134."
    return "$MC_EXIT_REFUSED"
  fi
  mc_validate_task_prefix "$prefix" || return $?
  if ! [[ "$prefix" == TASK134_* ]]; then
    MC_SUMMARY="TASK-134 cleanup prefix must start with TASK134_."
    MC_NEXT_ACTION="Use --prefix TASK134_."
    return "$MC_EXIT_REFUSED"
  fi
  mc_task134_run_python cleanup task134-all --task "$task_id" --prefix "$prefix" "$@"
  local code=$?
  mc_task134_load_result_detail "$MC_EVIDENCE_ABS/task134-cleanup-all.json"
  return "$code"
}

mc_cmd_task134_report_final() {
  local task_id prefix
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-$MC_TASK_ID}"
  prefix="$(mc_parse_opt --prefix "$@" || true)"
  prefix="${prefix:-TASK134_}"
  MC_PLATFORM="live"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_REQUIRES_LIVE="false"
  MC_REQUIRES_CLEANUP="false"
  MC_TEST_PREFIX="$prefix"
  if [[ "$task_id" != "TASK-134" ]]; then
    MC_SUMMARY="TASK-134 final report refused for task ${task_id}."
    MC_NEXT_ACTION="Rerun with MC_TASK_ID=TASK-134 or --task TASK-134."
    return "$MC_EXIT_REFUSED"
  fi
  mc_task134_run_python report task134-final --task "$task_id" --prefix "$prefix" "$@"
  local code=$?
  mc_task134_load_result_detail "$MC_EVIDENCE_ABS/task134-final.json"
  return "$code"
}
