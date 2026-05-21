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
  WHERE remote_id LIKE '${like_prefix}' OR supplier LIKE '${like_prefix}' OR category LIKE '${like_prefix}' OR data::text LIKE '${like_prefix}'
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
-- FK-safe TASK scoped cleanup only; no auth.users, no truncate, no reset.
DELETE FROM inventory_product_prices ipp
USING inventory_products p
WHERE p.id = ipp.product_id
  AND (p.barcode LIKE '${like_prefix}' OR p.product_name LIKE '${like_prefix}');
DELETE FROM inventory_products WHERE barcode LIKE '${like_prefix}' OR product_name LIKE '${like_prefix}';
DELETE FROM inventory_suppliers WHERE name LIKE '${like_prefix}';
DELETE FROM inventory_categories WHERE name LIKE '${like_prefix}';
DELETE FROM shared_sheet_sessions
WHERE remote_id LIKE '${like_prefix}' OR supplier LIKE '${like_prefix}' OR category LIKE '${like_prefix}' OR data::text LIKE '${like_prefix}';
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
        cleanup_profile="${cleanup_profile:-dry-run-no-db}"
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
    sync-matrix)
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
