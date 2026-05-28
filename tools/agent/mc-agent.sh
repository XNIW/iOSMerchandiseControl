#!/usr/bin/env bash
set -uo pipefail

MC_AGENT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${MC_AGENT_ROOT}/lib/common.sh"
mc_agent_source_libs
mc_load_config

main() {
  local raw_args=("$@")
  local args=()
  local arg
  for arg in "${raw_args[@]}"; do
    case "$arg" in
      --quiet) MC_QUIET=1 ;;
      --verbose) MC_VERBOSE=1 ;;
      *) args+=("$arg") ;;
    esac
  done
  local cmd="${args[0]:-help}"

  case "$cmd" in
    help|-h|--help)
      mc_help_text
      exit 0
      ;;
    help-json)
      mc_help_json
      exit 0
      ;;
    list)
      if [[ "${args[1]:-}" == "commands-json" ]]; then
        mc_help_json
        exit 0
      fi
      ;;
  esac

  local handler=()
  case "$cmd" in
    version) handler=(mc_cmd_version) ;;
    doctor|preflight) handler=(mc_cmd_preflight "${args[@]:1}") ;;
    config) handler=(mc_cmd_config "${args[@]:1}") ;;
    list) handler=(mc_cmd_list "${args[@]:1}") ;;
    report) handler=(mc_cmd_report "${args[@]:1}") ;;
    git)
      case "${args[1]:-}" in
        head-consistency) handler=(mc_cmd_git head-consistency "${args[@]:2}") ;;
        *) echo "Usage: git head-consistency --task <TASK-ID>" >&2; exit "$MC_EXIT_MISCONFIGURED" ;;
      esac
      ;;
    scan)
      case "${args[1]:-}" in
        price-contract)
          handler=(mc_cmd_scan_task130_price_contract "${args[@]:2}")
          ;;
        swiftdata-fetch-budget)
          handler=(mc_cmd_task130_consolidation swiftdata-fetch-budget "${args[@]:2}")
          ;;
        options-mainactor-heavy-fetch|productprice-full-fetch-mainactor|options-refresh-debounce|task127-debug-hook-release-safety|task127-final-gates|android-options-performance)
          handler=(mc_cmd_scan_task127_static "${args[1]}" "${args[@]:2}")
          ;;
        task126-policy-matrix|owner-store-scope|local-store-identity|pending-base-version|changed-fields-contract|no-cross-owner-store-pending-push|conflict-review-coverage|productprice-history-policy|cache-active-store-only|inactive-cache-cleanup-safety|task126-final-gates)
          handler=(mc_cmd_scan_task126_static "${args[1]}" "${args[@]:2}")
          ;;
        sensitive) handler=(mc_cmd_scan_sensitive "${args[@]:2}") ;;
        evidence) handler=(mc_cmd_scan_evidence "${args[@]:2}") ;;
        repo-diff) handler=(mc_cmd_scan_repo_diff) ;;
        release-cta) handler=(mc_cmd_scan_release_cta) ;;
        sync-boundaries) handler=(mc_cmd_scan_task117_static sync-boundaries "${args[@]:2}") ;;
        sync-architecture|manual-boundary|dead-code|xcode-membership)
          local scan_task_id
          scan_task_id="$(mc_parse_opt --task "${args[@]:2}" 2>/dev/null || true)"
          scan_task_id="${scan_task_id:-${MC_TASK_ID:-}}"
          if [[ "$scan_task_id" == "TASK-125" ]]; then
            handler=(mc_cmd_scan_task125_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-124" ]]; then
            handler=(mc_cmd_scan_task124_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-122" ]]; then
            handler=(mc_cmd_scan_task122_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-121" ]]; then
            handler=(mc_cmd_scan_task121_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-120" ]]; then
            handler=(mc_cmd_scan_task120_static "${args[1]}" "${args[@]:2}")
          else
            handler=(mc_cmd_scan_task119_static "${args[1]}" "${args[@]:2}")
          fi
          ;;
        sync-inventory|retry-ownership|root-residue|shared-purity)
          local scan_task_id
          scan_task_id="$(mc_parse_opt --task "${args[@]:2}" 2>/dev/null || true)"
          scan_task_id="${scan_task_id:-${MC_TASK_ID:-}}"
          if [[ "$scan_task_id" == "TASK-125" ]]; then
            handler=(mc_cmd_scan_task125_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-124" ]]; then
            handler=(mc_cmd_scan_task124_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-122" ]]; then
            handler=(mc_cmd_scan_task122_static "${args[1]}" "${args[@]:2}")
          else
            handler=(mc_cmd_scan_task121_static "${args[1]}" "${args[@]:2}")
          fi
          ;;
        swift-source-shape|remote-transport-thin|adapter-delegation-depth|domain-method-ownership|manual-debug-boundary|transport-protocol-conformance|composition-import-boundary|remote-query-ownership|debug-seed-boundary|dto-mapper-duplication|supabase-query-map|transport-callsite-map|protocol-conformance-map|supabase-contract-map|android-parity-ledger|performance-baseline|offline-outbox-conflict|sync-efficiency-acceptance)
          handler=(mc_cmd_scan_task122_static "${args[1]}" "${args[@]:2}")
          ;;
        task-docs|harness-routing|harness-health|source-format|duplicate-symbols|automatic-legacy-monolith|mainactor-boundary|swiftdata-context-boundary|manual-root-residue|master-plan-consistency|mcp-wrapper|scanner-self-tests|status-taxonomy|evidence-metadata|automation-discovery)
          local scan_task_id
          scan_task_id="$(mc_parse_opt --task "${args[@]:2}" 2>/dev/null || true)"
          scan_task_id="${scan_task_id:-${MC_TASK_ID:-}}"
          if [[ "$scan_task_id" == "TASK-127" && "${args[1]}" == "scanner-self-tests" ]]; then
            handler=(mc_cmd_scan_task127_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-126" && "${args[1]}" == "scanner-self-tests" ]]; then
            handler=(mc_cmd_scan_task126_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-125" ]]; then
            handler=(mc_cmd_scan_task125_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-124" ]]; then
            handler=(mc_cmd_scan_task124_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-122" ]]; then
            handler=(mc_cmd_scan_task122_static "${args[1]}" "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-121" ]]; then
            handler=(mc_cmd_scan_task121_static "${args[1]}" "${args[@]:2}")
          else
            handler=(mc_cmd_scan_task120_static "${args[1]}" "${args[@]:2}")
          fi
          ;;
        no-legacy-runtime-path) handler=(mc_cmd_scan_no_legacy_runtime_path "${args[@]:2}") ;;
        automatic-contracts-clean) handler=(mc_cmd_scan_task117_static automatic-contracts-clean "${args[@]:2}") ;;
        root-host-clean) handler=(mc_cmd_scan_task117_static root-host-clean "${args[@]:2}") ;;
        options-observer-only) handler=(mc_cmd_scan_task117_static options-observer-only "${args[@]:2}") ;;
        duplicate-sync-owner) handler=(mc_cmd_scan_task117_static duplicate-sync-owner "${args[@]:2}") ;;
        incremental-apply-contract) handler=(mc_cmd_scan_task117_static incremental-apply-contract "${args[@]:2}") ;;
        swiftdata-mainactor-heavy) handler=(mc_cmd_scan_task117_static swiftdata-mainactor-heavy "${args[@]:2}") ;;
        l10n-sync-keys) handler=(mc_cmd_scan_task117_static l10n-sync-keys "${args[@]:2}") ;;
        no-root-supabase-legacy|no-automatic-manual-dependency|transport-thin-only|remote-adapter-single-domain|no-hidden-manual-sync|no-stale-pbxproj-reference|no-mainactor-heavy-sync|no-service-role-client|no-rls-bypass|dead-code-residue|no-test-fixture-in-app-target|no-root-legacy-sync-service|background-task-registration|background-task-no-ui-context|outbox-pending-survives-restart|evidence-redaction|task125-final-gates)
          local scan_task_id
          scan_task_id="$(mc_parse_opt --task "${args[@]:2}" 2>/dev/null || true)"
          scan_task_id="${scan_task_id:-${MC_TASK_ID:-}}"
          if [[ "$scan_task_id" == "TASK-125" ]]; then
            handler=(mc_cmd_scan_task125_static "${args[1]}" "${args[@]:2}")
          else
            handler=(mc_cmd_scan_task124_static "${args[1]}" "${args[@]:2}")
          fi
          ;;
        no-full-pull-normal-path)
          local scan_task_id
          scan_task_id="$(mc_parse_opt --task "${args[@]:2}" 2>/dev/null || true)"
          scan_task_id="${scan_task_id:-${MC_TASK_ID:-}}"
          if [[ "$scan_task_id" == "TASK-125" ]]; then
            handler=(mc_cmd_scan_task125_static no-full-pull-normal-path "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-124" ]]; then
            handler=(mc_cmd_scan_task124_static no-full-pull-normal-path "${args[@]:2}")
          elif [[ "$scan_task_id" == "TASK-119" ]]; then
            handler=(mc_cmd_scan_task119_static no-full-pull-normal-path "${args[@]:2}")
          else
            handler=(mc_cmd_scan_task117_static no-full-pull-normal-path "${args[@]:2}")
          fi
          ;;
        *)
          echo "Usage: scan <known-scan-name>; run help-json or list commands-json for discoverable commands." >&2
          exit "$MC_EXIT_MISCONFIGURED"
          ;;
      esac
      ;;
    evidence) handler=(mc_cmd_evidence "${args[@]:1}") ;;
    account) handler=(mc_cmd_account "${args[@]:1}") ;;
    safety) handler=(mc_cmd_safety "${args[@]:1}") ;;
    harness) handler=(mc_cmd_harness "${args[@]:1}") ;;
    ios) handler=(mc_cmd_ios "${args[@]:1}") ;;
    android) handler=(mc_cmd_android "${args[@]:1}") ;;
    sync) handler=(mc_cmd_sync "${args[@]:1}") ;;
    supabase) handler=(mc_cmd_supabase "${args[@]:1}") ;;
    live) handler=(mc_cmd_live "${args[@]:1}") ;;
    *)
      echo "Unknown command: $cmd" >&2
      mc_help_text >&2
      exit "$MC_EXIT_MISCONFIGURED"
      ;;
  esac

  mc_prepare_task_context_from_args "${args[@]}"
  mc_run_wrapped "${args[*]}" "${handler[@]}"
  exit $?
}

main "$@"
