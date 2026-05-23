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
    doctor|preflight) handler=(mc_cmd_preflight) ;;
    config) handler=(mc_cmd_config "${args[@]:1}") ;;
    list) handler=(mc_cmd_list "${args[@]:1}") ;;
    report) handler=(mc_cmd_report "${args[@]:1}") ;;
    scan)
      case "${args[1]:-}" in
        sensitive) handler=(mc_cmd_scan_sensitive "${args[@]:2}") ;;
        evidence) handler=(mc_cmd_scan_evidence "${args[@]:2}") ;;
        repo-diff) handler=(mc_cmd_scan_repo_diff) ;;
        release-cta) handler=(mc_cmd_scan_release_cta) ;;
        no-legacy-runtime-path) handler=(mc_cmd_scan_no_legacy_runtime_path "${args[@]:2}") ;;
        *) echo "Usage: scan sensitive|evidence|repo-diff|release-cta|no-legacy-runtime-path" >&2; exit "$MC_EXIT_MISCONFIGURED" ;;
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
