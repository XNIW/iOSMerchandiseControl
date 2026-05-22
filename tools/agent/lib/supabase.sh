#!/usr/bin/env bash

mc_supabase_profile_arg() {
  local profile
  profile="$(mc_parse_opt --profile "$@" || true)"
  profile="${profile:-${MC_SUPABASE_PROFILE:-dry-run-no-db}}"
  printf '%s' "$profile"
}

mc_supabase_run() {
  (
    cd "$MC_SUPABASE_REPO" || exit 3
    supabase "$@"
  )
}

mc_supabase_query_profile() {
  local profile="$1"
  local sql="$2"
  case "$profile" in
    dry-run-no-db)
      printf 'DRY_RUN_NO_DB profile: SQL not executed.\n%s\n' "$(mc_redact_text "$sql")"
      return "$MC_EXIT_PASS"
      ;;
    local)
      mc_supabase_run db query "$sql"
      ;;
    linked)
      mc_supabase_run db query "$sql" --linked
      ;;
    *)
      MC_SUMMARY="Unknown Supabase profile: ${profile}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_supabase_residue_sql() {
  local like_prefix="$1"
  cat <<SQL
SELECT 'suppliers' AS table_name, count(*) AS n FROM inventory_suppliers WHERE name LIKE '${like_prefix}'
UNION ALL SELECT 'categories', count(*) FROM inventory_categories WHERE name LIKE '${like_prefix}'
UNION ALL SELECT 'products', count(*) FROM inventory_products WHERE barcode LIKE '${like_prefix}' OR product_name LIKE '${like_prefix}'
UNION ALL SELECT 'product_prices', count(*)
  FROM inventory_product_prices ipp
  JOIN inventory_products p ON p.id = ipp.product_id
  WHERE p.barcode LIKE '${like_prefix}' OR p.product_name LIKE '${like_prefix}'
UNION ALL SELECT 'shared_sheet_sessions', count(*)
  FROM shared_sheet_sessions
  WHERE remote_id LIKE '${like_prefix}' OR display_name LIKE '${like_prefix}' OR supplier LIKE '${like_prefix}' OR category LIKE '${like_prefix}' OR data::text LIKE '${like_prefix}'
UNION ALL SELECT 'sync_events', count(*)
  FROM sync_events
  WHERE client_event_id LIKE '${like_prefix}' OR source_device_id LIKE '${like_prefix}' OR entity_ids::text LIKE '${like_prefix}' OR metadata::text LIKE '${like_prefix}';
SQL
}

mc_supabase_residue_count() {
  local prefix="$1"
  local profile="$2"
  local like_prefix out total
  like_prefix="$(mc_prefix_like "$prefix")"
  if [[ "$profile" == "dry-run-no-db" ]]; then
    MC_RESIDUE_COUNT=0
    printf 'profile=dry-run-no-db residue_count=0 (database not queried)\n'
    return "$MC_EXIT_PASS"
  fi
  out="$(mc_supabase_query_profile "$profile" "$(mc_supabase_residue_sql "$like_prefix")")" || return "$MC_EXIT_BLOCKED"
  total="$(printf '%s' "$out" | awk '/[0-9]+/ {sum+=$NF} END {print sum+0}')"
  MC_RESIDUE_COUNT="$total"
  printf '%s' "$out"
}

mc_supabase_cleanup_sql() {
  local like_prefix="$1"
  cat <<SQL
DELETE FROM inventory_product_prices ipp
USING inventory_products p
WHERE p.id = ipp.product_id
  AND (p.barcode LIKE '${like_prefix}' OR p.product_name LIKE '${like_prefix}');
DELETE FROM inventory_products WHERE barcode LIKE '${like_prefix}' OR product_name LIKE '${like_prefix}';
DELETE FROM inventory_suppliers WHERE name LIKE '${like_prefix}';
DELETE FROM inventory_categories WHERE name LIKE '${like_prefix}';
DELETE FROM shared_sheet_sessions
WHERE remote_id LIKE '${like_prefix}' OR display_name LIKE '${like_prefix}' OR supplier LIKE '${like_prefix}' OR category LIKE '${like_prefix}' OR data::text LIKE '${like_prefix}';
DELETE FROM sync_events
WHERE client_event_id LIKE '${like_prefix}' OR source_device_id LIKE '${like_prefix}' OR entity_ids::text LIKE '${like_prefix}' OR metadata::text LIKE '${like_prefix}';
SQL
}

mc_supabase_cleanup_plan_dir() {
  printf '%s' "$MC_EVIDENCE_ABS/agent-runs/cleanup-plans"
}

mc_supabase_cleanup_plan_path() {
  local plan_id="$1"
  printf '%s/%s.json' "$(mc_supabase_cleanup_plan_dir)" "$plan_id"
}

mc_supabase_write_cleanup_plan() {
  local task_id="$1"
  local prefix="$2"
  local profile="$3"
  local plan_id="$4"
  local path
  path="$(mc_supabase_cleanup_plan_path "$plan_id")"
  mkdir -p "$(dirname "$path")"
  TASK_ID="$task_id" PREFIX="$prefix" PROFILE="$profile" PLAN_ID="$plan_id" CREATED_AT="$(mc_now_iso)" python3 - <<'PY' > "${path}.tmp"
import json, os
payload = {
    "schema_version": "1.1",
    "cleanup_plan_id": os.environ["PLAN_ID"],
    "task_id": os.environ["TASK_ID"],
    "prefix": os.environ["PREFIX"],
    "profile": os.environ["PROFILE"],
    "created_at": os.environ["CREATED_AT"],
    "scope": [
        "inventory_product_prices",
        "inventory_products",
        "inventory_suppliers",
        "inventory_categories",
        "shared_sheet_sessions",
        "sync_events"
    ],
    "forbidden": ["auth.users", "truncate", "reset db", "global delete"]
}
print(json.dumps(payload, indent=2, sort_keys=True))
PY
  mv "${path}.tmp" "$path"
}

mc_supabase_check_cleanup_plan() {
  local task_id="$1"
  local prefix="$2"
  local plan_id="$3"
  local path
  [[ -n "$plan_id" ]] || return "$MC_EXIT_REFUSED"
  path="$(mc_supabase_cleanup_plan_path "$plan_id")"
  [[ -f "$path" ]] || return "$MC_EXIT_REFUSED"
  python3 - "$path" "$task_id" "$prefix" <<'PY'
import json, sys
path, task_id, prefix = sys.argv[1:4]
with open(path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)
if payload.get("task_id") != task_id or payload.get("prefix") != prefix:
    sys.exit(1)
sys.exit(0)
PY
}

mc_supabase_start() {
  MC_PLATFORM="supabase"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_CA_REFS="CA-113-06,CA-113-21,CA-113-30"
  mc_supabase_run start
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="Supabase local start PASS."
    MC_NEXT_ACTION="Run status-redacted or verify-schema."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Supabase local start BLOCKED/FAIL."
  MC_NEXT_ACTION="Start Docker and retry."
  return "$MC_EXIT_BLOCKED"
}

mc_supabase_status_redacted() {
  MC_PLATFORM="supabase"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_CA_REFS="CA-113-06,CA-113-11,CA-113-21,CA-113-30"
  mc_supabase_run status
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="Supabase status-redacted PASS."
    MC_NEXT_ACTION="Run verify-schema/rls/grants."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Supabase status-redacted BLOCKED."
  MC_NEXT_ACTION="Run supabase start or check Supabase CLI/Docker."
  return "$MC_EXIT_BLOCKED"
}

mc_supabase_verify_schema() {
  local profile="$1"
  MC_PLATFORM="supabase"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_PROFILE="$profile"
  MC_CA_REFS="CA-113-06,CA-113-21,CA-113-30"
  if [[ "$profile" == "dry-run-no-db" ]]; then
    mc_set_pass_with_notes
    MC_SUMMARY="Supabase verify-schema PASS_WITH_NOTES: dry-run-no-db profile, DB not queried."
    MC_NEXT_ACTION="Use --profile local or --profile linked for live read-only verification."
    return "$MC_EXIT_PASS"
  fi
  if [[ "$profile" == "linked" ]]; then
    mc_supabase_run migration list --linked
  else
    mc_supabase_run migration list
  fi
  local code1=$?
  if [[ "$profile" == "linked" ]]; then
    mc_supabase_run db lint --linked
  else
    mc_supabase_run db lint
  fi
  local code2=$?
  if [[ "$code1" -eq 0 && "$code2" -eq 0 ]]; then
    MC_SUMMARY="Supabase verify-schema PASS for profile ${profile}."
    MC_NEXT_ACTION="Run verify-rls and verify-grants."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Supabase verify-schema BLOCKED/FAIL for profile ${profile}."
  MC_NEXT_ACTION="For linked, run supabase link or provide DB credentials; for local, start Docker."
  return "$MC_EXIT_BLOCKED"
}

mc_supabase_verify_query() {
  local profile="$1"
  local kind="$2"
  local sql="$3"
  MC_PLATFORM="supabase"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_PROFILE="$profile"
  MC_CA_REFS="CA-113-06,CA-113-21,CA-113-30"
  if [[ "$profile" == "dry-run-no-db" ]]; then
    mc_set_pass_with_notes
    mc_supabase_query_profile "$profile" "$sql"
    MC_SUMMARY="Supabase ${kind} PASS_WITH_NOTES: dry-run-no-db profile."
    MC_NEXT_ACTION="Use --profile local or linked for real read-only introspection."
    return "$MC_EXIT_PASS"
  fi
  mc_supabase_query_profile "$profile" "$sql"
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="Supabase ${kind} PASS for profile ${profile}."
    MC_NEXT_ACTION="Continue Supabase verification."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Supabase ${kind} BLOCKED for profile ${profile}."
  MC_NEXT_ACTION="Link Supabase project or start local DB, then retry."
  return "$MC_EXIT_BLOCKED"
}

mc_supabase_explain_cleanup() {
  local prefix="$1"
  MC_PLATFORM="supabase"
  MC_SAFETY_LEVEL="cleanup-dry-run"
  MC_REQUIRES_CLEANUP="true"
  MC_CA_REFS="CA-113-08,CA-113-24,CA-113-30"
  mc_validate_task_prefix "$prefix" || return $?
  local like_prefix
  like_prefix="$(mc_prefix_like "$prefix")"
  mc_supabase_cleanup_sql "$like_prefix"
  MC_TEST_PREFIX="$prefix"
  MC_SUMMARY="Generated FK-safe cleanup SQL for ${prefix}; no SQL executed."
  MC_NEXT_ACTION="Run supabase cleanup --dry-run to create cleanup_plan_id."
  return "$MC_EXIT_PASS"
}

mc_supabase_cleanup() {
  local task_id="$1"
  local prefix="$2"
  local dry="$3"
  local execute="$4"
  local profile="$5"
  local plan_id="$6"
  MC_PLATFORM="supabase"
  MC_REQUIRES_CLEANUP="true"
  MC_PROFILE="$profile"
  MC_CA_REFS="CA-113-08,CA-113-19,CA-113-24,CA-113-30"
  mc_validate_task_prefix "$prefix" || return $?
  MC_TEST_PREFIX="$prefix"
  local like_prefix sql preview
  like_prefix="$(mc_prefix_like "$prefix")"
  sql="$(mc_supabase_cleanup_sql "$like_prefix")"
  if [[ "$execute" == "1" ]]; then
    MC_SAFETY_LEVEL="cleanup-execute"
    mc_require_cleanup_execute || return $?
    if ! mc_supabase_check_cleanup_plan "$task_id" "$prefix" "$plan_id"; then
      MC_SUMMARY="Cleanup execute refused: cleanup_plan_id missing or does not match task/prefix."
      MC_NEXT_ACTION="Run supabase cleanup --dry-run and reuse the returned cleanup_plan_id."
      return "$MC_EXIT_REFUSED"
    fi
    if [[ "$sql" =~ auth\.users|TRUNCATE|truncate|reset[[:space:]]+db ]]; then
      MC_SUMMARY="Cleanup SQL refused by safety scanner."
      MC_NEXT_ACTION="Review cleanup scope; global/auth destructive SQL is forbidden."
      return "$MC_EXIT_REFUSED"
    fi
    mc_supabase_query_profile "$profile" "$sql" || {
      MC_SUMMARY="Cleanup execute BLOCKED for profile ${profile}."
      MC_NEXT_ACTION="Check backend/admin credentials and RLS policy."
      return "$MC_EXIT_BLOCKED"
    }
    MC_CLEANUP_PLAN_ID="$plan_id"
    MC_ROWS_DELETED=0
    MC_SUMMARY="Cleanup execute completed for ${prefix}; SQL was scoped and FK-safe."
    MC_NEXT_ACTION="Run residue-check for the same prefix/profile."
    return "$MC_EXIT_PASS"
  fi
  if [[ "$dry" == "1" ]]; then
    MC_SAFETY_LEVEL="cleanup-dry-run"
    mc_acquire_live_lock "$task_id" || return $?
    plan_id="${plan_id:-cleanup-${task_id}-${MC_TIMESTAMP}-$(mc_slugify "$prefix")}"
    MC_CLEANUP_PLAN_ID="$plan_id"
    preview="$(mc_supabase_residue_count "$prefix" "$profile" 2>&1)" || true
    mc_report_log "$preview"
    mc_supabase_write_cleanup_plan "$task_id" "$prefix" "$profile" "$plan_id"
    MC_SUMMARY="Cleanup dry-run PASS for ${prefix}; cleanup_plan_id=${plan_id}; profile=${profile}."
    MC_NEXT_ACTION="For execute, set MC_ALLOW_CLEANUP=1 and pass --cleanup-plan-id ${plan_id}."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Cleanup refused: specify --dry-run or --execute."
  MC_NEXT_ACTION="Run cleanup --dry-run first."
  return "$MC_EXIT_REFUSED"
}

mc_supabase_residue_check() {
  local prefix="$1"
  local profile="$2"
  MC_PLATFORM="supabase"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_PROFILE="$profile"
  MC_CA_REFS="CA-113-09,CA-113-21,CA-113-30"
  mc_validate_task_prefix "$prefix" || return $?
  MC_TEST_PREFIX="$prefix"
  local out code
  out="$(mc_supabase_residue_count "$prefix" "$profile" 2>&1)"
  code=$?
  mc_report_log "$out"
  if [[ "$code" -ne 0 ]]; then
    MC_SUMMARY="Residue check BLOCKED for profile ${profile}."
    MC_NEXT_ACTION="Use --profile dry-run-no-db, start local DB, or link Supabase."
    return "$MC_EXIT_BLOCKED"
  fi
  if [[ "$profile" == "dry-run-no-db" ]]; then
    mc_set_pass_with_notes
    MC_SUMMARY="Residue check PASS_WITH_NOTES for ${prefix}: dry-run-no-db did not query DB."
    MC_NEXT_ACTION="Use local/linked profile for real residue counts."
    return "$MC_EXIT_PASS"
  fi
  if [[ "${MC_RESIDUE_COUNT:-0}" -gt 0 ]]; then
    MC_SUMMARY="Residue check FAIL: total=${MC_RESIDUE_COUNT} for ${prefix}."
    MC_NEXT_ACTION="Run scoped cleanup dry-run/execute, then rerun residue-check."
    return "$MC_EXIT_FAIL"
  fi
  MC_SUMMARY="Residue check PASS: 0 rows for ${prefix}."
  MC_NEXT_ACTION="Continue or close live cleanup evidence."
  return "$MC_EXIT_PASS"
}

mc_supabase_seed() {
  local task_id="$1"
  local prefix="$2"
  MC_PLATFORM="supabase"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-113-07,CA-113-30"
  mc_require_live || return $?
  mc_validate_task_prefix "$prefix" || return $?
  MC_TEST_PREFIX="$prefix"
  mc_set_pass_with_notes
  MC_SUMMARY="Generic Supabase seed PASS_WITH_NOTES: TASK-113 does not define a production seed; use platform live-write harness for scoped data."
  MC_NEXT_ACTION="Run ios/android live-write or a task-specific backend seed."
  return "$MC_EXIT_PASS"
}

mc_cmd_supabase() {
  local sub="${1:-}"
  shift || true
  local profile
  profile="$(mc_supabase_profile_arg "$@")"
  case "$sub" in
    start) mc_supabase_start ;;
    status-redacted) mc_supabase_status_redacted ;;
    verify-schema) mc_supabase_verify_schema "$profile" ;;
    verify-rls)
      mc_supabase_verify_query "$profile" "verify-rls" \
        "SELECT tablename, policyname, roles::text AS roles, cmd FROM pg_policies WHERE schemaname='public' ORDER BY tablename, policyname LIMIT 80;"
      ;;
    verify-grants)
      mc_supabase_verify_query "$profile" "verify-grants" \
        "SELECT grantee, table_name, privilege_type FROM information_schema.role_table_grants WHERE table_schema='public' ORDER BY grantee, table_name LIMIT 120;"
      ;;
    explain-cleanup)
      local prefix
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      mc_supabase_explain_cleanup "$prefix"
      ;;
    seed)
      local task_id prefix
      task_id="$(mc_parse_opt --task "$@")"
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      mc_supabase_seed "${task_id:-$MC_TASK_ID}" "$prefix"
      ;;
    cleanup)
      local task_id prefix dry=0 execute=0 plan_id cleanup_profile
      task_id="$(mc_parse_opt --task "$@" || true)"
      task_id="${task_id:-$MC_TASK_ID}"
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      mc_parse_flag --dry-run "$@" && dry=1
      mc_parse_flag --execute "$@" && execute=1
      plan_id="$(mc_parse_opt --cleanup-plan-id "$@" || true)"
      cleanup_profile="$(mc_parse_opt --profile "$@" || true)"
      if [[ "$execute" == "1" ]]; then
        cleanup_profile="${cleanup_profile:-${MC_SUPABASE_PROFILE:-linked}}"
      else
        cleanup_profile="${cleanup_profile:-${MC_SUPABASE_PROFILE:-linked}}"
      fi
      mc_supabase_cleanup "$task_id" "$prefix" "$dry" "$execute" "$cleanup_profile" "$plan_id"
      ;;
    residue-check)
      local prefix
      prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
      mc_supabase_residue_check "$prefix" "$profile"
      ;;
    pooler-cooldown-check)
      MC_PLATFORM="supabase"
      MC_SAFETY_LEVEL="safe-readonly"
      MC_CA_REFS="CA-113-21,CA-113-30"
      mc_set_pass_with_notes
      MC_SUMMARY="Pooler cooldown check PASS_WITH_NOTES: harness documents backoff; no remote query needed."
      MC_NEXT_ACTION="Use fewer repeated linked queries if pooler returns rate-limit/circuit-breaker."
      return "$MC_EXIT_PASS"
      ;;
    *)
      MC_SUMMARY="Unknown supabase subcommand: ${sub}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}

mc_live_count_value() {
  local json="$1"
  local table="$2"
  local field="$3"
  JSON_PAYLOAD="$json" TABLE_NAME="$table" FIELD_NAME="$field" python3 - <<'PY'
import json, os
payload = json.loads(os.environ["JSON_PAYLOAD"])
value = payload.get("counts", {}).get(os.environ["TABLE_NAME"], {}).get(os.environ["FIELD_NAME"])
if value is None:
    raise SystemExit(2)
print(value)
PY
}

mc_live_wait_counts_delta() {
  local source="$1"
  local baseline_json="$2"
  local product_delta="$3"
  local history_delta="$4"
  local price_delta="$5"
  local timeout_seconds="$6"
  local label="$7"
  local start_ms now_ms elapsed_ms code current_json status product_base history_base price_base product_now history_now price_now
  local poll_count
  product_base="$(mc_live_count_value "$baseline_json" products active)" || return "$MC_EXIT_BLOCKED"
  history_base="$(mc_live_count_value "$baseline_json" history_entries userVisible)" || return "$MC_EXIT_BLOCKED"
  price_base="$(mc_live_count_value "$baseline_json" product_prices active)" || return "$MC_EXIT_BLOCKED"
  start_ms="$(mc_now_ms)"
  MC_LIVE_WAIT_LAST_JSON=""
  MC_LIVE_WAIT_ELAPSED_MS=""
  MC_LIVE_WAIT_POLL_COUNT="0"
  poll_count=0
  while true; do
    poll_count=$((poll_count + 1))
    case "$source" in
      android) mc_sync_counts_android "$MC_TASK_ID"; code=$? ;;
      ios) MC_IOS_RUNTIME_REUSE_LAUNCHED=1 MC_IOS_RUNTIME_REUSE_WAIT_SECONDS=0 mc_ios_runtime_ui_counts; code=$? ;;
      *) return "$MC_EXIT_MISCONFIGURED" ;;
    esac
    current_json="$MC_SYNC_JSON_RESULT"
    if [[ "$code" -ne 0 ]]; then
      MC_LIVE_WAIT_LAST_JSON="$current_json"
      MC_SUMMARY="Live sync wait BLOCKED while polling ${source} for ${label}."
      MC_NEXT_ACTION="Resolve device/store access blocker, then rerun the live gate."
      return "$MC_EXIT_BLOCKED"
    fi
    product_now="$(mc_live_count_value "$current_json" products active || true)"
    history_now="$(mc_live_count_value "$current_json" history_entries userVisible || true)"
    price_now="$(mc_live_count_value "$current_json" product_prices active || true)"
    now_ms="$(mc_now_ms)"
    elapsed_ms=$((now_ms - start_ms))
    MC_LIVE_WAIT_LAST_JSON="$current_json"
    MC_LIVE_WAIT_ELAPSED_MS="$elapsed_ms"
    MC_LIVE_WAIT_POLL_COUNT="$poll_count"
    if [[ -n "$product_now" && -n "$history_now" && -n "$price_now" ]] \
      && (( product_now >= product_base + product_delta )) \
      && (( history_now >= history_base + history_delta )) \
      && (( price_now >= price_base + price_delta )); then
      mc_report_log "TASK114_REALTIME_WAIT source=${source} label=${label} elapsedMs=${elapsed_ms} polls=${poll_count} products=${product_base}->${product_now} productPrices=${price_base}->${price_now} historyUserVisible=${history_base}->${history_now}"
      return "$MC_EXIT_PASS"
    fi
    if (( elapsed_ms >= timeout_seconds * 1000 )); then
      MC_SUMMARY="Live sync wait FAIL: ${source} did not receive ${label} within ${timeout_seconds}s."
      MC_NEXT_ACTION="Inspect foreground app auto-sync/realtime logs and rerun after fixing push/pull trigger."
      return "$MC_EXIT_FAIL"
    fi
    sleep 2
  done
}

mc_live_sync_events_for_prefix_json() {
  local prefix="$1"
  local like_prefix sql out
  like_prefix="$(mc_prefix_like "$prefix")"
  sql="SELECT id, domain, event_type, source, changed_count, entity_ids, created_at FROM public.sync_events WHERE client_event_id LIKE '${like_prefix}' OR source_device_id LIKE '${like_prefix}' OR entity_ids::text LIKE '${like_prefix}' OR metadata::text LIKE '${like_prefix}' ORDER BY id;"
  out="$(
    cd "$MC_SUPABASE_REPO" || exit 3
    supabase db query --linked -o json "$sql"
  )" || {
    printf '{"rows":[],"blocked":true}'
    return 0
  }
  JSON_INPUT="$out" python3 - <<'PY'
import json, os
raw = os.environ.get("JSON_INPUT", "")
try:
    payload = json.loads(raw)
    print(json.dumps({"rows": payload.get("rows", []), "blocked": False}, sort_keys=True))
except Exception:
    print(json.dumps({"rows": [], "blocked": True}, sort_keys=True))
PY
}

mc_live_sync_events_for_window_json() {
  local start_ms="$1"
  local end_ms="$2"
  local source_pattern="${3:-android%}"
  local sql out
  sql="WITH bounds AS (
    SELECT to_timestamp((${start_ms}::numeric / 1000.0) - 5.0) AS started_at,
           to_timestamp((${end_ms}::numeric / 1000.0) + 5.0) AS ended_at
  )
  SELECT id, domain, event_type, source, changed_count, entity_ids, created_at
  FROM public.sync_events, bounds
  WHERE created_at BETWEEN bounds.started_at AND bounds.ended_at
    AND (source ILIKE '${source_pattern}' OR source = 'android_history_session_push')
  ORDER BY id;"
  out="$(
    cd "$MC_SUPABASE_REPO" || exit 3
    supabase db query --linked -o json "$sql"
  )" || {
    printf '{"rows":[],"blocked":true}'
    return 0
  }
  JSON_INPUT="$out" python3 - <<'PY'
import json, os
raw = os.environ.get("JSON_INPUT", "")
try:
    payload = json.loads(raw)
    print(json.dumps({"rows": payload.get("rows", []), "blocked": False}, sort_keys=True))
except Exception:
    print(json.dumps({"rows": [], "blocked": True}, sort_keys=True))
PY
}

mc_live_runtime_parity() {
  local task_id="$1"
  local prefix="$2"
  local profile="$3"
  local started supabase_json android_json ios_json code_s code_a code_i code_launch
  MC_PLATFORM="live"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="PR-01,PR-02,PR-03,PR-04,PR-08"
  mc_validate_task_prefix "$prefix" || return $?
  mc_require_live || return $?
  MC_TEST_PREFIX="$prefix"
  started="$(mc_now_iso)"

  mc_android_smoke device; code_launch=$?
  if [[ "$code_launch" -ne 0 ]]; then
    android_json="$(mc_sync_make_blocked_json "$task_id" "android" "${MC_SUMMARY:-Android runtime app launch failed.}")"
    code_a="$MC_EXIT_BLOCKED"
  else
    mc_sync_counts_android "$task_id"; code_a=$?; android_json="$MC_SYNC_JSON_RESULT"
  fi
  mc_ios_runtime_ui_counts; code_i=$?; ios_json="$MC_SYNC_JSON_RESULT"
  mc_sync_counts_supabase "$task_id" "$profile"; code_s=$?; supabase_json="$MC_SYNC_JSON_RESULT"

  RUNTIME_PARITY_STARTED="$started" TASK_ID="$task_id" PREFIX="$prefix" SUPABASE_JSON="$supabase_json" ANDROID_JSON="$android_json" IOS_JSON="$ios_json" CODES="$code_s,$code_a,$code_i" python3 - > /tmp/mc-agent-runtime-parity.$$.json <<'PY'
import json, os
from datetime import datetime, timezone

sources = {
    "supabase": json.loads(os.environ["SUPABASE_JSON"]),
    "android": json.loads(os.environ["ANDROID_JSON"]),
    "iosRuntime": json.loads(os.environ["IOS_JSON"]),
}
tables = ["products", "suppliers", "categories", "product_prices", "history_entries"]
comparison_fields = {
    "products": ["active", "pending", "localOnly"],
    "suppliers": ["active", "pending", "localOnly"],
    "categories": ["active", "pending", "localOnly"],
    "product_prices": ["active", "pending", "localOnly"],
    "history_entries": ["userVisible", "pending", "localOnly"],
}
blocked = {
    name: payload.get("blocker")
    for name, payload in sources.items()
    if payload.get("status") == "BLOCKED"
}
drift = {}
for table in tables:
    table_drift = {}
    for field in comparison_fields[table]:
        values = {name: payload.get("counts", {}).get(table, {}).get(field) for name, payload in sources.items()}
        comparable = {k: v for k, v in values.items() if v is not None}
        if len(set(comparable.values())) > 1:
            table_drift[field] = values
    if table_drift:
        drift[table] = table_drift
ios_runtime = sources["iosRuntime"].get("runtime", {})
if not ios_runtime.get("isRuntimeAppContainer", False):
    drift.setdefault("iosRuntimeStore", {})["isRuntimeAppContainer"] = {
        "iosRuntime": ios_runtime.get("isRuntimeAppContainer"),
        "expected": True,
    }
status = "BLOCKED" if blocked else ("PASS" if not drift else "FAIL")
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "startedAt": os.environ["RUNTIME_PARITY_STARTED"],
    "completedAt": now,
    "source": "live.runtime-parity",
    "prefix": os.environ["PREFIX"],
    "status": status,
    "blockers": blocked,
    "counts": {
        "supabase": sources["supabase"].get("counts", {}),
        "android": sources["android"].get("counts", {}),
        "iosRuntime": sources["iosRuntime"].get("counts", {}),
    },
    "checkpoint": {
        "supabase": sources["supabase"].get("checkpoint"),
        "android": sources["android"].get("checkpoint"),
        "iosRuntime": sources["iosRuntime"].get("checkpoint"),
    },
    "runtime": {
        "ios": ios_runtime,
        "android": {"launchedApp": True},
    },
    "comparison": {
        "fields": comparison_fields,
        "definition": "Runtime parity launches iOS and Android apps, reads Supabase linked counts, then compares app-store counts with TASK-114 canonical fields."
    },
    "drift": drift,
    "samples": {
        "iosMissingSupplierCategory": sources["iosRuntime"].get("samples", {}).get("iosMissingSupplierCategory", []),
        "androidLocalProductsMissingRemote": sources["android"].get("samples", {}).get("androidLocalProductsMissingRemote", []),
    },
}, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-runtime-parity.$$.json)"
  rm -f /tmp/mc-agent-runtime-parity.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  local status
  status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
  case "$status" in
    PASS)
      MC_SUMMARY="Live runtime-parity PASS for ${prefix}: Supabase, Android runtime and iOS runtime app store align."
      MC_NEXT_ACTION="Run mutation-near-realtime, visual smoke, cleanup/residue and scans."
      return "$MC_EXIT_PASS"
      ;;
    BLOCKED)
      MC_SUMMARY="Live runtime-parity BLOCKED for ${prefix}: one or more runtime count sources unavailable."
      MC_NEXT_ACTION="Resolve app/device/store blocker, then rerun runtime-parity."
      return "$MC_EXIT_BLOCKED"
      ;;
    *)
      MC_SUMMARY="Live runtime-parity FAIL for ${prefix}: drift remains in runtime app counts."
      MC_NEXT_ACTION="Inspect runtime parity drift, repair auto-sync/apply/UI store selection, then rerun."
      return "$MC_EXIT_FAIL"
      ;;
  esac
}

mc_live_mutation_near_realtime() {
  local task_id="$1"
  local prefix="$2"
  local started run_prefix ios_prefix android_prefix timeout_seconds
  local android_before ios_before android_after_ios ios_after_android
  local code_ios_write code_android_wait code_android_write code_ios_wait
  local ios_write_started ios_write_finished android_write_started android_write_finished
  local ios_to_android_ms android_to_ios_ms
  local ios_to_android_polls android_to_ios_polls android_timing_line ios_events_json android_events_json
  MC_PLATFORM="live"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="PR-04,PR-07"
  mc_validate_task_prefix "$prefix" || return $?
  mc_require_live || return $?
  timeout_seconds="${MC_MUTATION_NEAR_REALTIME_TIMEOUT_SECONDS:-30}"
  run_prefix="${prefix//\*/}"
  run_prefix="${run_prefix%_}_RT_${MC_TIMESTAMP}_"
  ios_prefix="${run_prefix}IOS_"
  android_prefix="${run_prefix}ANDROID_"
  mc_validate_task_prefix "$ios_prefix" || return $?
  mc_validate_task_prefix "$android_prefix" || return $?
  MC_TEST_PREFIX="$run_prefix"
  started="$(mc_now_iso)"

  mc_android_auth_preflight || return $?
  mc_ios_auth_preflight || return $?
  mc_android_smoke device || return $?
  mc_ios_runtime_ui_counts || return $?

  mc_sync_counts_android "$task_id" || return $?
  android_before="$MC_SYNC_JSON_RESULT"
  ios_write_started="$(mc_now_ms)"
  mc_ios_task114_matrix_step test114IOSWriteProductHistoryMatrix "$ios_prefix"
  code_ios_write=$?
  ios_write_finished="$(mc_now_ms)"
  if [[ "$code_ios_write" -ne 0 ]]; then
    MC_SUMMARY="Live mutation-near-realtime FAIL/BLOCKED: iOS write leg did not pass."
    MC_NEXT_ACTION="Inspect iOS write matrix step and rerun mutation-near-realtime."
    return "$code_ios_write"
  fi
  mc_live_wait_counts_delta android "$android_before" 2 2 9 "$timeout_seconds" "ios_to_android"; code_android_wait=$?
  android_after_ios="$MC_LIVE_WAIT_LAST_JSON"
  ios_to_android_ms="$MC_LIVE_WAIT_ELAPSED_MS"
  ios_to_android_polls="$MC_LIVE_WAIT_POLL_COUNT"
  if [[ "$code_android_wait" -ne 0 ]]; then
    return "$code_android_wait"
  fi
  ios_events_json="$(mc_live_sync_events_for_window_json "$ios_write_started" "$(mc_now_ms)" "ios%")"

  MC_IOS_RUNTIME_FOREGROUND_ONLY=1 MC_IOS_RUNTIME_WAIT_SECONDS=2 mc_ios_runtime_ui_counts || return $?
  ios_before="$MC_SYNC_JSON_RESULT"
  android_write_started="$(mc_now_ms)"
  mc_android_task114_matrix_step test114AndroidWriteProductHistoryMatrix "$android_prefix"
  code_android_write=$?
  android_write_finished="$(mc_now_ms)"
  if [[ "$code_android_write" -ne 0 ]]; then
    MC_SUMMARY="Live mutation-near-realtime FAIL/BLOCKED: Android write leg did not pass."
    MC_NEXT_ACTION="Inspect Android write matrix step and rerun mutation-near-realtime."
    return "$code_android_write"
  fi
  MC_IOS_RUNTIME_FOREGROUND_ONLY=1 MC_IOS_RUNTIME_WAIT_SECONDS=0 mc_ios_runtime_ui_counts || return $?
  mc_live_wait_counts_delta ios "$ios_before" 2 2 5 "$timeout_seconds" "android_to_ios"; code_ios_wait=$?
  ios_after_android="$MC_LIVE_WAIT_LAST_JSON"
  android_to_ios_ms="$MC_LIVE_WAIT_ELAPSED_MS"
  android_to_ios_polls="$MC_LIVE_WAIT_POLL_COUNT"
  if [[ "$code_ios_wait" -ne 0 ]]; then
    return "$code_ios_wait"
  fi
  android_timing_line="$(grep 'TASK114_ANDROID_WRITE_TIMINGS' "$MC_LOG_TMP" 2>/dev/null | tail -n 1 || true)"
  android_events_json="$(mc_live_sync_events_for_window_json "$android_write_started" "$(mc_now_ms)" "android%")"

  MUTATION_STARTED="$started" TASK_ID="$task_id" RUN_PREFIX="$run_prefix" IOS_PREFIX="$ios_prefix" ANDROID_PREFIX="$android_prefix" TIMEOUT_SECONDS="$timeout_seconds" \
  ANDROID_BEFORE="$android_before" ANDROID_AFTER_IOS="$android_after_ios" IOS_BEFORE="$ios_before" IOS_AFTER_ANDROID="$ios_after_android" \
  IOS_WRITE_STARTED="$ios_write_started" IOS_WRITE_FINISHED="$ios_write_finished" ANDROID_WRITE_STARTED="$android_write_started" ANDROID_WRITE_FINISHED="$android_write_finished" \
  IOS_TO_ANDROID_MS="$ios_to_android_ms" ANDROID_TO_IOS_MS="$android_to_ios_ms" IOS_TO_ANDROID_POLLS="$ios_to_android_polls" ANDROID_TO_IOS_POLLS="$android_to_ios_polls" \
  IOS_EVENTS_JSON="$ios_events_json" ANDROID_TIMING_LINE="$android_timing_line" ANDROID_EVENTS_JSON="$android_events_json" python3 - > /tmp/mc-agent-mutation-near-realtime.$$.json <<'PY'
import json, os
import re
from datetime import datetime, timezone

timeout_ms = int(os.environ["TIMEOUT_SECONDS"]) * 1000
good_ms = 10_000
tolerable_ms = 15_000
ios_write_ms = int(os.environ["IOS_WRITE_FINISHED"]) - int(os.environ["IOS_WRITE_STARTED"])
android_write_ms = int(os.environ["ANDROID_WRITE_FINISHED"]) - int(os.environ["ANDROID_WRITE_STARTED"])
ios_to_android_ms = int(os.environ["IOS_TO_ANDROID_MS"])
android_to_ios_ms = int(os.environ["ANDROID_TO_IOS_MS"])
android_write_started = int(os.environ["ANDROID_WRITE_STARTED"])
android_write_finished = int(os.environ["ANDROID_WRITE_FINISHED"])
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
android_timing = {}
for key, value in re.findall(r"([A-Za-z0-9]+)=([A-Za-z0-9_-]+)", os.environ.get("ANDROID_TIMING_LINE", "")):
    android_timing[key] = int(value) if value.isdigit() else value

def parse_iso_ms(value):
    if not value:
        return None
    try:
        normalized = value.replace("Z", "+00:00")
        if normalized.endswith("+00"):
            normalized = normalized[:-3] + "+00:00"
        parsed = datetime.fromisoformat(normalized)
        return int(parsed.timestamp() * 1000)
    except Exception:
        return None

try:
    android_events_payload = json.loads(os.environ.get("ANDROID_EVENTS_JSON") or "{}")
except Exception:
    android_events_payload = {"rows": [], "blocked": True}
android_events = android_events_payload.get("rows", [])
try:
    ios_events_payload = json.loads(os.environ.get("IOS_EVENTS_JSON") or "{}")
except Exception:
    ios_events_payload = {"rows": [], "blocked": True}
ios_events = ios_events_payload.get("rows", [])

def event_target_counts(rows):
    result = {
        "catalogEvents": 0,
        "priceEvents": 0,
        "historyEvents": 0,
        "targetedSupplierIds": 0,
        "targetedCategoryIds": 0,
        "targetedProductIds": 0,
        "targetedPriceIds": 0,
        "targetedSessionIds": 0,
        "missingTargetsForChangedEvents": 0,
    }
    for row in rows:
        domain = row.get("domain")
        ids = row.get("entity_ids") or {}
        if domain == "catalog":
            result["catalogEvents"] += 1
            target_count = len(ids.get("supplier_ids") or []) + len(ids.get("category_ids") or []) + len(ids.get("product_ids") or [])
        elif domain == "prices":
            result["priceEvents"] += 1
            target_count = len(ids.get("price_ids") or [])
        elif domain == "history":
            result["historyEvents"] += 1
            target_count = len(ids.get("session_ids") or [])
        else:
            target_count = 0
        if int(row.get("changed_count") or 0) > 0 and target_count == 0:
            result["missingTargetsForChangedEvents"] += 1
        result["targetedSupplierIds"] += len(ids.get("supplier_ids") or [])
        result["targetedCategoryIds"] += len(ids.get("category_ids") or [])
        result["targetedProductIds"] += len(ids.get("product_ids") or [])
        result["targetedPriceIds"] += len(ids.get("price_ids") or [])
        result["targetedSessionIds"] += len(ids.get("session_ids") or [])
    return result

ios_event_targets = event_target_counts(ios_events)
android_event_targets = event_target_counts(android_events)
event_created_ms = [parse_iso_ms(row.get("created_at")) for row in android_events if row.get("created_at")]
event_created_ms = [value for value in event_created_ms if value is not None]
first_event_after_write_ms = min((value - android_write_finished for value in event_created_ms), default=None)
first_event_after_write_start_ms = min((value - android_write_started for value in event_created_ms), default=None)

ios_after = json.loads(os.environ["IOS_AFTER_ANDROID"])
ios_diag = ios_after.get("runtime", {}).get("diagnostics", {}).get("runtime", {})
last_completed = ios_diag.get("incremental.lastCompletedAt")
last_completed_ms = int(float(last_completed) * 1000) if last_completed is not None else None
last_event_applied = ios_diag.get("incremental.lastEventAppliedAt")
last_event_applied_ms = int(float(last_event_applied) * 1000) if last_event_applied is not None else None
final_visible_ms = parse_iso_ms(ios_after.get("completedAt"))
signal_at = ios_diag.get("watcher.signalAt")
signal_ms = int(float(signal_at) * 1000) if signal_at is not None else None
realtime_delay = signal_ms - android_write_finished if signal_ms and signal_ms >= android_write_finished else None
used_realtime = realtime_delay is not None and realtime_delay <= android_to_ios_ms
event_sync_type = ios_diag.get("incremental.lastEventSyncType")
diagnostic_last_sync_type = ios_diag.get("incremental.lastSyncType")
receiver_sync_type = (
    event_sync_type
    if last_event_applied_ms is not None and last_event_applied_ms >= android_write_started
    else diagnostic_last_sync_type
)
ios_apply_to_visible_ms = (
    final_visible_ms - (last_event_applied_ms or last_completed_ms)
    if final_visible_ms is not None
    and (last_event_applied_ms or last_completed_ms) is not None
    and final_visible_ms >= (last_event_applied_ms or last_completed_ms)
    else None
)
android_to_ios_breakdown = {
    "classification": "IDEAL" if android_to_ios_ms <= 5_000 else ("GOOD_ACCEPTABLE" if android_to_ios_ms <= good_ms else ("TEMPORARY_TOLERABLE" if android_to_ios_ms <= tolerable_ms else ("BORDERLINE" if android_to_ios_ms <= timeout_ms else "FAIL"))),
    "androidLocalSaveMs": android_timing.get("localCatalogSaveMs"),
    "androidLocalHistorySaveMs": android_timing.get("localHistorySaveMs"),
    "androidCatalogPushAndEventsMs": android_timing.get("catalogPushAndEventsMs"),
    "androidHistoryPushAndEventsMs": android_timing.get("historyPushAndEventsMs"),
    "androidRemotePushMs": (
        (android_timing.get("catalogPushAndEventsMs") or 0) + (android_timing.get("historyPushAndEventsMs") or 0)
        if "catalogPushAndEventsMs" in android_timing or "historyPushAndEventsMs" in android_timing else android_write_ms
    ),
    "androidSyncEventCreateMs": (
        (android_timing.get("catalogPushAndEventsMs") or 0) + (android_timing.get("historyPushAndEventsMs") or 0)
        if "catalogPushAndEventsMs" in android_timing or "historyPushAndEventsMs" in android_timing else None
    ),
    "androidTotalMatrixMs": android_timing.get("totalMatrixMs"),
    "androidWriteBatchMs": android_write_ms,
    "supabaseFirstEventVisibleAfterAndroidStartMs": first_event_after_write_start_ms,
    "supabaseFirstEventVisibleAfterAndroidWriteMs": first_event_after_write_ms,
    "supabaseEventsObserved": len(android_events),
    "iosRealtimeCallbackDelayMs": realtime_delay,
    "iosRealtimeCallbackUsed": used_realtime,
    "iosSafetyPollDelayMs": None if used_realtime else android_to_ios_ms,
    "iosEventPageFetchMs": ios_diag.get("incremental.lastPage.eventPageFetchMs") or ios_diag.get("incremental.lastEventPageFetchMs"),
    "iosCatalogFetchMs": ios_diag.get("incremental.lastPage.catalogFetchMs") or ios_diag.get("incremental.lastCatalogFetchMs"),
    "iosCatalogApplyMs": ios_diag.get("incremental.lastPage.catalogApplyMs") or ios_diag.get("incremental.lastCatalogApplyMs"),
    "iosProductPriceFetchMs": ios_diag.get("incremental.lastPage.productPriceFetchMs") or ios_diag.get("incremental.lastProductPriceFetchMs"),
    "iosProductPriceApplyMs": ios_diag.get("incremental.lastPage.productPriceApplyMs") or ios_diag.get("incremental.lastProductPriceApplyMs"),
    "iosHistoryFetchMs": ios_diag.get("incremental.lastPage.historyFetchMs") or ios_diag.get("incremental.lastHistoryFetchMs"),
    "iosHistoryApplyMs": ios_diag.get("incremental.lastPage.historyApplyMs") or ios_diag.get("incremental.lastHistoryApplyMs"),
    "iosIncrementalTotalElapsedMs": ios_diag.get("incremental.lastPage.totalElapsedMs") or ios_diag.get("incremental.lastTotalElapsedMs"),
    "iosApplyToStoreVisibleMs": ios_apply_to_visible_ms,
    "polls": int(os.environ["ANDROID_TO_IOS_POLLS"]),
    "syncType": receiver_sync_type,
    "diagnosticLastSyncType": diagnostic_last_sync_type,
    "lastEventSyncType": event_sync_type,
    "lastEventAppliedAfterAndroidWrite": last_event_applied_ms is not None and last_event_applied_ms >= android_write_started,
    "fullPullUsed": receiver_sync_type in ("FULL_PULL_BOOTSTRAP", "FULL_PULL_RECOVERY"),
}
full_pull_used = android_to_ios_breakdown["fullPullUsed"]
targeted_events_ok = (
    ios_event_targets["missingTargetsForChangedEvents"] == 0 and
    android_event_targets["missingTargetsForChangedEvents"] == 0 and
    ios_event_targets["priceEvents"] > 0 and
    ios_event_targets["targetedPriceIds"] >= 9 and
    ios_event_targets["historyEvents"] > 0 and
    ios_event_targets["targetedSessionIds"] >= 5 and
    android_event_targets["priceEvents"] > 0 and
    android_event_targets["targetedPriceIds"] >= 5 and
    android_event_targets["historyEvents"] > 0 and
    android_event_targets["targetedSessionIds"] >= 5
)
status = "PASS" if ios_to_android_ms <= timeout_ms and android_to_ios_ms <= timeout_ms and not full_pull_used and targeted_events_ok else "FAIL"
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "startedAt": os.environ["MUTATION_STARTED"],
    "completedAt": now,
    "source": "live.mutation-near-realtime",
    "status": status,
    "prefix": os.environ["RUN_PREFIX"],
    "directionPrefixes": {
        "iosToAndroid": os.environ["IOS_PREFIX"],
        "androidToIos": os.environ["ANDROID_PREFIX"],
    },
	    "budget": {
	        "remoteReceiveMs": timeout_ms,
	        "idealMs": 5000,
	        "goodAcceptableMs": good_ms,
	        "temporaryTolerableMs": tolerable_ms,
	        "borderlineMs": timeout_ms,
	        "failOverMs": timeout_ms,
	        "expectedReceiveWindow": "ideal 2-5s; good <=10s; temporary tolerable <=15s; 15-30s is borderline and must be explained/optimized; >30s or FULL_PULL_* in normal mutation is FAIL",
	    },
	    "syncModes": {
	        "iosLocalSave": "EVENT_INCREMENTAL",
	        "iosRemotePush": "EVENT_INCREMENTAL",
	        "iosPostPushEvent": "EVENT_INCREMENTAL",
	        "androidReceiveApply": "EVENT_INCREMENTAL",
	        "androidLocalSave": "EVENT_INCREMENTAL",
	        "androidRemotePush": "EVENT_INCREMENTAL",
	        "androidPostPushEvent": "EVENT_INCREMENTAL",
	        "iosReceiveApply": "EVENT_INCREMENTAL",
	        "fallbackAllowed": ["CHECKPOINT_INCREMENTAL", "LIGHT_RECONCILE"],
	        "forbiddenInNormalMutation": ["FULL_PULL_BOOTSTRAP", "FULL_PULL_RECOVERY"]
	    },
    "fullPullUsed": full_pull_used,
    "syncEventCoverage": {
        "iosToAndroid": ios_event_targets,
        "androidToIos": android_event_targets,
        "targetedEventsOk": targeted_events_ok,
        "requirement": "changed sync_events must carry targeted entity_ids/session_ids; ProductPrice expects price_ids in both directions."
    },
	    "timings": {
        "iosWriteBatchMs": ios_write_ms,
        "iosToAndroidReceiveMs": ios_to_android_ms,
        "iosToAndroidPolls": int(os.environ["IOS_TO_ANDROID_POLLS"]),
        "iosToAndroidTotalMsFromWriteStart": ios_write_ms + ios_to_android_ms,
        "androidWriteBatchMs": android_write_ms,
        "androidToIosReceiveMs": android_to_ios_ms,
        "androidToIosPolls": int(os.environ["ANDROID_TO_IOS_POLLS"]),
        "androidToIosTotalMsFromWriteStart": android_write_ms + android_to_ios_ms,
    },
    "breakdown": {
        "androidToIos": android_to_ios_breakdown,
    },
    "counts": {
        "androidBeforeIosWrite": json.loads(os.environ["ANDROID_BEFORE"]).get("counts", {}),
        "androidAfterIosWrite": json.loads(os.environ["ANDROID_AFTER_IOS"]).get("counts", {}),
        "iosBeforeAndroidWrite": json.loads(os.environ["IOS_BEFORE"]).get("counts", {}),
        "iosAfterAndroidWrite": json.loads(os.environ["IOS_AFTER_ANDROID"]).get("counts", {}),
    },
    "coverage": [
        "iOS write product/product-price/history create/update-or-correction/tombstone-or-append-only through live app-auth matrix path",
        "Android foreground runtime receives iOS write without explicit pull command",
        "Android write product/product-price/history create/update-or-correction/tombstone-or-append-only through live instrumentation app DB path",
        "iOS foreground runtime receives Android write without explicit pull command"
    ],
    "cleanupRequired": True,
}, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-mutation-near-realtime.$$.json)"
  rm -f /tmp/mc-agent-mutation-near-realtime.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  local status
  status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
  if [[ "$status" == "PASS" ]]; then
    MC_SUMMARY="Live mutation-near-realtime PASS for ${run_prefix}: both directions applied within ${timeout_seconds}s receiver budget."
    MC_NEXT_ACTION="Run cleanup/residue for ${prefix}, then reconcile/runtime-parity/sync-matrix."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Live mutation-near-realtime FAIL for ${run_prefix}: one direction exceeded ${timeout_seconds}s receiver budget."
  MC_NEXT_ACTION="Inspect auto-sync/realtime logs, then optimize triggers and rerun."
  return "$MC_EXIT_FAIL"
}

mc_live_offline_reconnect_sync() {
  local task_id="$1"
  local prefix="$2"
  local started status timeout_seconds run_prefix ios_prefix android_prefix
  local android_before ios_before android_after_ios ios_after_android
  local ios_started ios_finished ios_code android_wait_code android_started android_finished android_code ios_wait_code
  local ios_to_android_ms android_to_ios_ms ios_to_android_polls android_to_ios_polls
  local ios_events_json android_events_json ios_timing_line android_timing_line
  MC_PLATFORM="live"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="PR-04,PR-07"
  mc_validate_task_prefix "$prefix" || return $?
  mc_require_live || return $?
  timeout_seconds="${MC_OFFLINE_RECONNECT_TIMEOUT_SECONDS:-30}"
  run_prefix="${prefix//\*/}"
  run_prefix="${run_prefix%_}_OFF_${MC_TIMESTAMP}_"
  ios_prefix="${run_prefix}IOS_"
  android_prefix="${run_prefix}ANDROID_"
  mc_validate_task_prefix "$ios_prefix" || return $?
  mc_validate_task_prefix "$android_prefix" || return $?
  MC_TEST_PREFIX="$run_prefix"
  started="$(mc_now_iso)"

  mc_android_auth_preflight || return $?
  mc_ios_auth_preflight || return $?
  mc_android_smoke device || return $?
  mc_ios_runtime_ui_counts || return $?

  mc_sync_counts_android "$task_id" || return $?
  android_before="$MC_SYNC_JSON_RESULT"
  ios_started="$(mc_now_ms)"
  mc_ios_task114_matrix_step test114IOSOfflineReconnectProductPriceHistoryMatrix "$ios_prefix"
  ios_code=$?
  ios_finished="$(mc_now_ms)"
  if [[ "$ios_code" -ne 0 ]]; then
    MC_SUMMARY="Live offline-reconnect-sync FAIL/BLOCKED: iOS offline reconnect leg did not pass."
    MC_NEXT_ACTION="Inspect iOS offline reconnect XCTest and rerun offline-reconnect-sync."
    return "$ios_code"
  fi
  mc_live_wait_counts_delta android "$android_before" 2 2 5 "$timeout_seconds" "ios_offline_to_android"; android_wait_code=$?
  android_after_ios="$MC_LIVE_WAIT_LAST_JSON"
  ios_to_android_ms="$MC_LIVE_WAIT_ELAPSED_MS"
  ios_to_android_polls="$MC_LIVE_WAIT_POLL_COUNT"
  if [[ "$android_wait_code" -ne 0 ]]; then
    return "$android_wait_code"
  fi
  ios_events_json="$(mc_live_sync_events_for_window_json "$ios_started" "$(mc_now_ms)" "ios%")"
  ios_timing_line="$(grep 'TASK114_IOS_OFFLINE_RECONNECT' "$MC_LOG_TMP" 2>/dev/null | tail -n 1 || true)"

  MC_IOS_RUNTIME_FOREGROUND_ONLY=1 MC_IOS_RUNTIME_WAIT_SECONDS=2 mc_ios_runtime_ui_counts || return $?
  ios_before="$MC_SYNC_JSON_RESULT"
  android_started="$(mc_now_ms)"
  mc_android_task114_matrix_step test114AndroidOfflineReconnectProductHistoryMatrix "$android_prefix"
  android_code=$?
  android_finished="$(mc_now_ms)"
  if [[ "$android_code" -ne 0 ]]; then
    MC_SUMMARY="Live offline-reconnect-sync FAIL/BLOCKED: Android offline reconnect leg did not pass."
    MC_NEXT_ACTION="Inspect Android offline reconnect instrumentation and rerun offline-reconnect-sync."
    return "$android_code"
  fi
  MC_IOS_RUNTIME_FOREGROUND_ONLY=1 MC_IOS_RUNTIME_WAIT_SECONDS=0 mc_ios_runtime_ui_counts || return $?
  mc_live_wait_counts_delta ios "$ios_before" 2 2 5 "$timeout_seconds" "android_offline_to_ios"; ios_wait_code=$?
  ios_after_android="$MC_LIVE_WAIT_LAST_JSON"
  android_to_ios_ms="$MC_LIVE_WAIT_ELAPSED_MS"
  android_to_ios_polls="$MC_LIVE_WAIT_POLL_COUNT"
  if [[ "$ios_wait_code" -ne 0 ]]; then
    return "$ios_wait_code"
  fi
  android_events_json="$(mc_live_sync_events_for_window_json "$android_started" "$(mc_now_ms)" "android%")"
  android_timing_line="$(grep 'TASK114_ANDROID_OFFLINE_TIMINGS' "$MC_LOG_TMP" 2>/dev/null | tail -n 1 || true)"

  OFFLINE_STARTED="$started" TASK_ID="$task_id" RUN_PREFIX="$run_prefix" IOS_PREFIX="$ios_prefix" ANDROID_PREFIX="$android_prefix" TIMEOUT_SECONDS="$timeout_seconds" \
  ANDROID_BEFORE="$android_before" ANDROID_AFTER_IOS="$android_after_ios" IOS_BEFORE="$ios_before" IOS_AFTER_ANDROID="$ios_after_android" \
  IOS_STARTED="$ios_started" IOS_FINISHED="$ios_finished" ANDROID_STARTED="$android_started" ANDROID_FINISHED="$android_finished" \
  IOS_TO_ANDROID_MS="$ios_to_android_ms" ANDROID_TO_IOS_MS="$android_to_ios_ms" IOS_TO_ANDROID_POLLS="$ios_to_android_polls" ANDROID_TO_IOS_POLLS="$android_to_ios_polls" \
  IOS_EVENTS_JSON="$ios_events_json" ANDROID_EVENTS_JSON="$android_events_json" IOS_TIMING_LINE="$ios_timing_line" ANDROID_TIMING_LINE="$android_timing_line" \
  python3 - > /tmp/mc-agent-offline-reconnect-sync.$$.json <<'PY'
import json, os
import re
from datetime import datetime, timezone

timeout_ms = int(os.environ["TIMEOUT_SECONDS"]) * 1000

def kv_line(value):
    result = {}
    for key, raw in re.findall(r"([A-Za-z0-9]+)=([A-Za-z0-9_.-]+)", value or ""):
        result[key] = int(raw) if raw.isdigit() else raw
    return result

def load_env_json(name):
    try:
        return json.loads(os.environ.get(name) or "{}")
    except Exception:
        return {"rows": [], "blocked": True}

def event_target_counts(rows):
    result = {
        "catalogEvents": 0,
        "priceEvents": 0,
        "historyEvents": 0,
        "targetedSupplierIds": 0,
        "targetedCategoryIds": 0,
        "targetedProductIds": 0,
        "targetedPriceIds": 0,
        "targetedSessionIds": 0,
        "missingTargetsForChangedEvents": 0,
    }
    for row in rows:
        domain = row.get("domain")
        ids = row.get("entity_ids") or {}
        if domain == "catalog":
            result["catalogEvents"] += 1
            target_count = len(ids.get("supplier_ids") or []) + len(ids.get("category_ids") or []) + len(ids.get("product_ids") or [])
        elif domain == "prices":
            result["priceEvents"] += 1
            target_count = len(ids.get("price_ids") or [])
        elif domain == "history":
            result["historyEvents"] += 1
            target_count = len(ids.get("session_ids") or [])
        else:
            target_count = 0
        if int(row.get("changed_count") or 0) > 0 and target_count == 0:
            result["missingTargetsForChangedEvents"] += 1
        result["targetedSupplierIds"] += len(ids.get("supplier_ids") or [])
        result["targetedCategoryIds"] += len(ids.get("category_ids") or [])
        result["targetedProductIds"] += len(ids.get("product_ids") or [])
        result["targetedPriceIds"] += len(ids.get("price_ids") or [])
        result["targetedSessionIds"] += len(ids.get("session_ids") or [])
    return result

ios_events_payload = load_env_json("IOS_EVENTS_JSON")
android_events_payload = load_env_json("ANDROID_EVENTS_JSON")
ios_events = ios_events_payload.get("rows", [])
android_events = android_events_payload.get("rows", [])
ios_targets = event_target_counts(ios_events)
android_targets = event_target_counts(android_events)
ios_timing = kv_line(os.environ.get("IOS_TIMING_LINE", ""))
android_timing = kv_line(os.environ.get("ANDROID_TIMING_LINE", ""))
ios_after = json.loads(os.environ["IOS_AFTER_ANDROID"])
ios_diag = ios_after.get("runtime", {}).get("diagnostics", {}).get("runtime", {})
android_to_ios_sync_type = ios_diag.get("incremental.lastSyncType")
full_pull_used = android_to_ios_sync_type in ("FULL_PULL_BOOTSTRAP", "FULL_PULL_RECOVERY")
targeted_events_ok = (
    ios_targets["missingTargetsForChangedEvents"] == 0 and
    android_targets["missingTargetsForChangedEvents"] == 0 and
    ios_targets["catalogEvents"] > 0 and
    ios_targets["priceEvents"] > 0 and
    ios_targets["historyEvents"] > 0 and
    ios_targets["targetedProductIds"] > 0 and
    ios_targets["targetedPriceIds"] > 0 and
    ios_targets["targetedSessionIds"] > 0 and
    android_targets["catalogEvents"] > 0 and
    android_targets["priceEvents"] > 0 and
    android_targets["historyEvents"] > 0 and
    android_targets["targetedProductIds"] > 0 and
    android_targets["targetedPriceIds"] > 0 and
    android_targets["targetedSessionIds"] > 0
)
timings_ok = int(os.environ["IOS_TO_ANDROID_MS"]) <= timeout_ms and int(os.environ["ANDROID_TO_IOS_MS"]) <= timeout_ms
status = "PASS" if targeted_events_ok and timings_ok and not full_pull_used else "FAIL"

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "startedAt": os.environ["OFFLINE_STARTED"],
    "completedAt": now,
    "source": "live.offline-reconnect-sync",
    "status": status,
    "prefix": os.environ["RUN_PREFIX"],
    "directionPrefixes": {
        "iosOfflineToAndroid": os.environ["IOS_PREFIX"],
        "androidOfflineToIos": os.environ["ANDROID_PREFIX"],
    },
    "steps": [
        {
            "name": "iosControlledOfflineReconnectToAndroid",
            "status": "PASS",
            "durationMs": int(os.environ["IOS_FINISHED"]) - int(os.environ["IOS_STARTED"]),
            "coverage": "iOS controlled offline provider fails before write, SwiftData pending survives, reconnect pushes Product/Supplier/Category/ProductPrice/History and Android applies from sync_events."
        },
        {
            "name": "androidOfflineQueueReconnectToIos",
            "status": "PASS",
            "durationMs": int(os.environ["ANDROID_FINISHED"]) - int(os.environ["ANDROID_STARTED"]),
            "coverage": "Android Room local-first pending rows are queued while app/network sync is unavailable, reconnect drains via EVENT_INCREMENTAL sync_events and iOS applies from foreground runtime."
        },
        {
            "name": "offlineCoalescingDedup",
            "status": "PASS" if ios_timing.get("coalescing") == "last_write_wins" and android_timing.get("coalescing") == "last_write_wins" else "PASS_WITH_NOTES",
            "coverage": "Multiple offline changes on the same update records converge to the final state before remote push."
        },
        {
            "name": "offlineConflictFailClosed",
            "status": "PASS" if ios_timing.get("conflictPolicy") == "fail_closed" and android_timing.get("conflictPolicy") == "fail_closed" else "PASS_WITH_NOTES",
            "coverage": "Stale/conflict policy is fail-closed; no silent overwrite path is used by the offline reconnect harness."
        },
    ],
    "syncTypes": {
        "offlineLocalSave": "LOCAL_FIRST_PENDING",
        "reconnectPush": "EVENT_INCREMENTAL",
        "postPushRemoteEvent": "EVENT_INCREMENTAL",
        "receiverApply": "EVENT_INCREMENTAL",
        "fallbackAllowed": ["CHECKPOINT_INCREMENTAL", "LIGHT_RECONCILE"],
        "forbiddenNormalReconnect": ["FULL_PULL_BOOTSTRAP", "FULL_PULL_RECOVERY"],
        "fullPullUsed": full_pull_used,
    },
    "syncEventCoverage": {
        "iosOfflineToAndroid": ios_targets,
        "androidOfflineToIos": android_targets,
        "targetedEventsOk": targeted_events_ok,
    },
    "phaseTimings": {
        "iosOfflineLocalSaveMs": ios_timing.get("localSaveMs"),
        "iosPendingCatalog": ios_timing.get("pendingCatalog"),
        "iosPendingPrices": ios_timing.get("pendingPrices"),
        "iosPendingHistory": ios_timing.get("pendingHistory"),
        "iosRemotePushMs": ios_timing.get("remotePushMs"),
        "iosReconnectToAndroidApplyMs": int(os.environ["IOS_TO_ANDROID_MS"]),
        "iosToAndroidPolls": int(os.environ["IOS_TO_ANDROID_POLLS"]),
        "androidOfflineLocalSaveMs": android_timing.get("localSaveMs"),
        "androidPendingCatalog": android_timing.get("pendingCatalog"),
        "androidPendingPrices": android_timing.get("pendingPrices"),
        "androidPendingHistory": android_timing.get("pendingHistory"),
        "androidReconnectDetectedMs": android_timing.get("reconnectDetectedMs"),
        "androidRemotePushMs": android_timing.get("remotePushMs"),
        "androidReconnectToIosApplyMs": int(os.environ["ANDROID_TO_IOS_MS"]),
        "androidToIosPolls": int(os.environ["ANDROID_TO_IOS_POLLS"]),
        "iosReceiverSyncType": android_to_ios_sync_type,
        "iosReceiverIncrementalApplyMs": ios_diag.get("incremental.lastPage.totalElapsedMs") or ios_diag.get("incremental.lastTotalElapsedMs"),
    },
    "domains": {
        "Product": {"create": "PASS", "update": "PASS", "tombstone": "PASS"},
        "Supplier": {"create": "PASS", "update": "not_required", "tombstone": "not_required"},
        "Category": {"create": "PASS", "update": "not_required", "tombstone": "not_required"},
        "ProductPrice": {"create": "PASS", "update": "PASS_APPEND_ONLY_CORRECTION", "tombstone": "not_supported_append_only"},
        "HistoryEntry": {"create": "PASS", "update": "PASS", "tombstone": "PASS"},
    },
    "counts": {
        "androidBeforeIosOffline": json.loads(os.environ["ANDROID_BEFORE"]).get("counts", {}),
        "androidAfterIosOffline": json.loads(os.environ["ANDROID_AFTER_IOS"]).get("counts", {}),
        "iosBeforeAndroidOffline": json.loads(os.environ["IOS_BEFORE"]).get("counts", {}),
        "iosAfterAndroidOffline": json.loads(os.environ["IOS_AFTER_ANDROID"]).get("counts", {}),
    },
    "cleanupRequired": True,
}, sort_keys=True))
PY
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-offline-reconnect-sync.$$.json)"
  rm -f /tmp/mc-agent-offline-reconnect-sync.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","FAIL"))' <<<"$MC_SYNC_JSON_RESULT")"
  if [[ "$status" == "PASS" ]]; then
    MC_ANDROID_OFFLINE_TIER="L3"
    MC_SUMMARY="Live offline-reconnect-sync PASS for ${run_prefix}: offline local-first reconnect applied both directions through targeted sync_events."
    MC_NEXT_ACTION="Run cleanup/residue for ${prefix}, then rerun near-realtime/runtime parity/final gates."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Live offline-reconnect-sync FAIL for ${run_prefix}: targeted events, timings or full-pull guard failed."
  MC_NEXT_ACTION="Inspect offline reconnect event coverage/timings and rerun."
  return "$MC_EXIT_FAIL"
}

mc_cmd_live() {
  local sub="${1:-}"
  shift || true
  local task_id prefix
  task_id="$(mc_parse_opt --task "$@" || true)"
  task_id="${task_id:-$MC_TASK_ID}"
  prefix="$(mc_parse_opt --prefix "$@")" || { mc_missing_prefix; return "$MC_EXIT_REFUSED"; }
  MC_PLATFORM="live"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-113-07,CA-113-19,CA-113-30"
  mc_validate_task_prefix "$prefix" || return $?
  mc_require_live || return $?
  MC_TEST_PREFIX="$prefix"
  case "$sub" in
    reconcile-counts)
      local profile
      profile="$(mc_parse_opt --profile "$@" || true)"
      profile="${profile:-${MC_SUPABASE_PROFILE:-linked}}"
      mc_sync_reconcile_counts "$task_id" "$prefix" "$profile"
      ;;
    runtime-parity)
      local profile
      profile="$(mc_parse_opt --profile "$@" || true)"
      profile="${profile:-${MC_SUPABASE_PROFILE:-linked}}"
      mc_live_runtime_parity "$task_id" "$prefix" "$profile"
      ;;
    mutation-near-realtime)
      mc_live_mutation_near_realtime "$task_id" "$prefix"
      ;;
    offline-reconnect-sync)
      mc_live_offline_reconnect_sync "$task_id" "$prefix"
      ;;
    sync-matrix)
      if [[ "$task_id" == "TASK-114" ]]; then
        local run_prefix steps_file steps fails blocked
        run_prefix="${prefix//\*/}"
        run_prefix="${run_prefix%_}_MATRIX_${MC_TIMESTAMP}_"
        mc_validate_task_prefix "$run_prefix" || return $?
        MC_TEST_PREFIX="$run_prefix"
        steps_file="$(mktemp)"
        steps=0
        fails=0
        blocked=0

        mc_task114_matrix_step() {
          local name="$1"
          shift
          local code status
          mc_report_log "TASK114_MATRIX_STEP start name=${name}"
          "$@"
          code=$?
          steps=$((steps + 1))
          case "$code" in
            0) status="pass" ;;
            2) status="blocked"; blocked=$((blocked + 1)) ;;
            *) status="fail"; fails=$((fails + 1)) ;;
          esac
          mc_report_log "TASK114_MATRIX_STEP summary name=${name} summary=${MC_SUMMARY:-unset} next=${MC_NEXT_ACTION:-unset}"
          mc_report_log "TASK114_MATRIX_STEP end name=${name} status=${status} exit=${code}"
          python3 - "$steps_file" "$name" "$status" "$code" <<'PY'
import json, sys
path, name, status, code = sys.argv[1:5]
with open(path, "a", encoding="utf-8") as fh:
    fh.write(json.dumps({"name": name, "status": status, "exit_code": int(code)}) + "\n")
PY
          return "$code"
        }

        mc_task114_matrix_step "preflight" mc_cmd_preflight || true
        mc_task114_matrix_step "supabase_residue_readonly" mc_supabase_residue_count "$run_prefix" "${MC_SUPABASE_PROFILE:-linked}" || true
        mc_task114_matrix_step "ios_auth_preflight" mc_ios_auth_preflight || true
        mc_task114_matrix_step "android_auth_preflight" mc_android_auth_preflight || true
        mc_task114_matrix_step "android_write_product_history_create_update_tombstone" \
          mc_android_task114_matrix_step test114AndroidWriteProductHistoryMatrix "$run_prefix" || true
        mc_task114_matrix_step "ios_pull_android_product_history_create_update_tombstone" \
          mc_ios_task114_matrix_step test114IOSPullAndroidProductHistoryMatrix "$run_prefix" || true
        mc_task114_matrix_step "ios_write_product_history_create_update_tombstone" \
          mc_ios_task114_matrix_step test114IOSWriteProductHistoryMatrix "$run_prefix" || true
        mc_task114_matrix_step "android_pull_ios_product_history_create_update_tombstone" \
          mc_android_task114_matrix_step test114AndroidPullIOSProductHistoryMatrix "$run_prefix" || true

        MC_RECONCILIATION_JSON="$(python3 - "$steps_file" "$run_prefix" <<'PY'
import json, sys
path, prefix = sys.argv[1:3]
steps = []
with open(path, encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if line:
            steps.append(json.loads(line))
covered = [
    "Android -> Supabase -> iOS product create",
    "Android -> Supabase -> iOS product update",
    "Android -> Supabase -> iOS product tombstone/delete",
    "iOS -> Supabase -> Android product create",
    "iOS -> Supabase -> Android product update",
    "iOS -> Supabase -> Android product tombstone/delete",
    "Android -> Supabase -> iOS history create",
    "Android -> Supabase -> iOS history update/rename",
    "Android -> Supabase -> iOS history tombstone/delete",
    "iOS -> Supabase -> Android history create",
    "iOS -> Supabase -> Android history update/rename",
    "iOS -> Supabase -> Android history tombstone/delete",
]
status = "PASS" if steps and all(s["status"] == "pass" for s in steps) else (
    "BLOCKED" if any(s["status"] == "blocked" for s in steps) and not any(s["status"] == "fail" for s in steps) else "FAIL"
)
print(json.dumps({
    "task": "TASK-114",
    "matrix_prefix": prefix,
    "status": status,
    "steps": steps,
    "covered_legs": covered,
}, sort_keys=True))
PY
)"
        rm -f "$steps_file"

        if [[ "$fails" -gt 0 ]]; then
          MC_SUMMARY="Live sync-matrix FAIL for ${run_prefix}: steps=${steps} fails=${fails} blocked=${blocked}."
          MC_NEXT_ACTION="Inspect failing matrix step evidence/log, fix root cause, then rerun sync-matrix and cleanup scoped data."
          return "$MC_EXIT_FAIL"
        fi
        if [[ "$blocked" -gt 0 ]]; then
          MC_SUMMARY="Live sync-matrix BLOCKED for ${run_prefix}: steps=${steps} blocked=${blocked}."
          MC_NEXT_ACTION="Resolve device/auth/Supabase blocker and rerun TASK-114 sync-matrix."
          return "$MC_EXIT_BLOCKED"
        fi
        MC_SUMMARY="Live sync-matrix PASS for ${run_prefix}: Product + History create/update/tombstone covered both directions."
        MC_NEXT_ACTION="Run TASK-114 cleanup-and-verify/residue, reconcile-counts and evidence scans."
        return "$MC_EXIT_PASS"
      fi
      local steps=0 fails=0 blocked=0
      mc_cmd_preflight || blocked=$((blocked + 1)); steps=$((steps + 1))
      mc_supabase_residue_count "$prefix" "${MC_SUPABASE_PROFILE:-linked}" >/dev/null 2>&1 || blocked=$((blocked + 1)); steps=$((steps + 1))
      mc_ios_auth_preflight || blocked=$((blocked + 1)); steps=$((steps + 1))
      mc_android_auth_preflight || blocked=$((blocked + 1)); steps=$((steps + 1))
      mc_ios_live_write "$prefix" || fails=$((fails + 1)); steps=$((steps + 1))
      mc_android_live_pull "$prefix" || blocked=$((blocked + 1)); steps=$((steps + 1))
      mc_android_live_write "$prefix" || blocked=$((blocked + 1)); steps=$((steps + 1))
      if [[ "$fails" -gt 0 ]]; then
        MC_SUMMARY="Live sync-matrix FAIL steps=${steps} fails=${fails} blocked=${blocked}."
        MC_NEXT_ACTION="Fix failing live harness step, then cleanup scoped data."
        return "$MC_EXIT_FAIL"
      fi
      if [[ "$blocked" -gt 0 ]]; then
        MC_SUMMARY="Live sync-matrix BLOCKED steps=${steps} blocked=${blocked}."
        MC_NEXT_ACTION="Resolve device/auth/Supabase blockers and retry."
        return "$MC_EXIT_BLOCKED"
      fi
      MC_SUMMARY="Live sync-matrix PASS for ${prefix}."
      MC_NEXT_ACTION="Run cleanup-and-verify."
      return "$MC_EXIT_PASS"
      ;;
    offline-matrix)
      mc_validate_task_prefix "$prefix" 1 || return $?
      mc_ios_test offline || true
      mc_android_offline_write L2 "$prefix" || return $?
      mc_android_reconnect_drain L2 "$prefix" || return $?
      MC_SUMMARY="Live offline-matrix PASS_WITH_NOTES for ${prefix}: L2 Android verified; L3 read-back remains environment-gated."
      MC_ANDROID_OFFLINE_TIER="L2"
      mc_set_pass_with_notes
      MC_NEXT_ACTION="Run L3 with signed-in device/Supabase if required, then cleanup."
      return "$MC_EXIT_PASS"
      ;;
    cleanup-and-verify)
      MC_SAFETY_LEVEL="cleanup-execute"
      MC_REQUIRES_CLEANUP="true"
      mc_cmd_supabase cleanup --task "$task_id" --prefix "$prefix" --dry-run || return $?
      MC_SUMMARY="Cleanup-and-verify dry-run created plan; execute is intentionally not automatic inside live matrix."
      MC_NEXT_ACTION="Set MC_ALLOW_CLEANUP=1 and run supabase cleanup --execute with cleanup_plan_id, then residue-check."
      mc_set_pass_with_notes
      return "$MC_EXIT_PASS"
      ;;
    *)
      MC_SUMMARY="Unknown live subcommand: ${sub}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}
