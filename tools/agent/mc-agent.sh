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
        sensitive) handler=(mc_cmd_scan_sensitive "${args[@]:2}") ;;
        evidence) handler=(mc_cmd_scan_evidence "${args[@]:2}") ;;
        repo-diff) handler=(mc_cmd_scan_repo_diff) ;;
        release-cta) handler=(mc_cmd_scan_release_cta) ;;
        sync-boundaries) handler=(mc_cmd_scan_task117_static sync-boundaries "${args[@]:2}") ;;
        sync-architecture) handler=(mc_cmd_scan_task119_static sync-architecture "${args[@]:2}") ;;
        manual-boundary) handler=(mc_cmd_scan_task119_static manual-boundary "${args[@]:2}") ;;
        dead-code) handler=(mc_cmd_scan_task119_static dead-code "${args[@]:2}") ;;
        xcode-membership) handler=(mc_cmd_scan_task119_static xcode-membership "${args[@]:2}") ;;
        no-legacy-runtime-path) handler=(mc_cmd_scan_no_legacy_runtime_path "${args[@]:2}") ;;
        automatic-contracts-clean) handler=(mc_cmd_scan_task117_static automatic-contracts-clean "${args[@]:2}") ;;
        root-host-clean) handler=(mc_cmd_scan_task117_static root-host-clean "${args[@]:2}") ;;
        options-observer-only) handler=(mc_cmd_scan_task117_static options-observer-only "${args[@]:2}") ;;
        duplicate-sync-owner) handler=(mc_cmd_scan_task117_static duplicate-sync-owner "${args[@]:2}") ;;
        incremental-apply-contract) handler=(mc_cmd_scan_task117_static incremental-apply-contract "${args[@]:2}") ;;
        swiftdata-mainactor-heavy) handler=(mc_cmd_scan_task117_static swiftdata-mainactor-heavy "${args[@]:2}") ;;
        l10n-sync-keys) handler=(mc_cmd_scan_task117_static l10n-sync-keys "${args[@]:2}") ;;
        no-full-pull-normal-path)
          local scan_task_id
          scan_task_id="$(mc_parse_opt --task "${args[@]:2}" 2>/dev/null || true)"
          scan_task_id="${scan_task_id:-${MC_TASK_ID:-}}"
          if [[ "$scan_task_id" == "TASK-119" ]]; then
            handler=(mc_cmd_scan_task119_static no-full-pull-normal-path "${args[@]:2}")
          else
            handler=(mc_cmd_scan_task117_static no-full-pull-normal-path "${args[@]:2}")
          fi
          ;;
        *) echo "Usage: scan sensitive|evidence|repo-diff|release-cta|sync-architecture|manual-boundary|dead-code|xcode-membership|no-legacy-runtime-path|no-full-pull-normal-path|automatic-contracts-clean|root-host-clean|options-observer-only|duplicate-sync-owner|incremental-apply-contract|swiftdata-mainactor-heavy|l10n-sync-keys" >&2; exit "$MC_EXIT_MISCONFIGURED" ;;
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
