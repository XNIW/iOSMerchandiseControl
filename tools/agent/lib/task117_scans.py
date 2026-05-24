#!/usr/bin/env python3
import json
import os
import pathlib
import re
import sys
from datetime import datetime, timezone


TASK = os.environ.get("TASK_ID", os.environ.get("MC_TASK_ID", "TASK-117"))
REPO = pathlib.Path(os.environ.get("IOS_REPO", os.environ.get("MC_IOS_REPO", ".")))


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read(rel):
    try:
        return (REPO / rel).read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def line_hits(text, pattern, flags=0):
    hits = []
    for match in re.finditer(pattern, text, flags):
        line = text.count("\n", 0, match.start()) + 1
        snippet = text.splitlines()[line - 1].strip() if line > 0 else match.group(0)
        hits.append({"line": line, "snippet": snippet[:220]})
    return hits


def check_absent(checks, check_id, rel, pattern, reason, flags=0):
    text = read(rel)
    hits = line_hits(text, pattern, flags)
    checks.append({
        "id": check_id,
        "status": "FAIL" if hits else "PASS",
        "file": rel,
        "reason": reason,
        "evidence": hits[:20],
    })


def check_present(checks, check_id, rel, pattern, reason, flags=0):
    text = read(rel)
    hits = line_hits(text, pattern, flags)
    checks.append({
        "id": check_id,
        "status": "PASS" if hits else "FAIL",
        "file": rel,
        "reason": reason,
        "evidence": hits[:20] if hits else [{"line": 0, "snippet": "pattern missing"}],
    })


def check_absent_text(checks, check_id, rel, text, pattern, reason, flags=0):
    hits = line_hits(text, pattern, flags)
    checks.append({
        "id": check_id,
        "status": "FAIL" if hits else "PASS",
        "file": rel,
        "reason": reason,
        "evidence": hits[:20],
    })


def file_exists(checks, check_id, rel, reason):
    exists = (REPO / rel).exists()
    checks.append({
        "id": check_id,
        "status": "PASS" if exists else "FAIL",
        "file": rel,
        "reason": reason,
        "evidence": [] if exists else [{"line": 0, "snippet": "file missing"}],
    })


def all_swift_sources():
    return sorted(
        path.relative_to(REPO).as_posix()
        for path in (REPO / "iOSMerchandiseControl").rglob("*.swift")
        if path.is_file()
    )


def task118_automatic_source_files():
    explicit = {
        "iOSMerchandiseControl/iOSMerchandiseControlApp.swift",
        "iOSMerchandiseControl/ContentView.swift",
        "iOSMerchandiseControl/OptionsView.swift",
        "iOSMerchandiseControl/AutomaticSyncReconnectScheduler.swift",
        "iOSMerchandiseControl/HistorySessionSyncService.swift",
        "iOSMerchandiseControl/SupabaseInventoryService.swift",
    }
    for rel in all_swift_sources():
        name = pathlib.Path(rel).name
        parts = pathlib.Path(rel).parts
        if rel.startswith("iOSMerchandiseControl/Sync/"):
            explicit.add(rel)
        elif name.startswith("SyncEventOutbox") or name.startswith("SupabaseSyncEvent"):
            explicit.add(rel)
    excluded_tokens = (
        "/Manual/",
        "ManualSync",
        "Debug",
        "Preview",
        "Task087",
        "Sandbox",
    )
    return [
        rel for rel in sorted(explicit)
        if (REPO / rel).exists() and not any(token in rel for token in excluded_tokens)
    ]


def check_absent_in_files(checks, check_id_prefix, files, pattern, reason, flags=0):
    for rel in files:
        check_absent(
            checks,
            f"{check_id_prefix}_{pathlib.Path(rel).stem}",
            rel,
            pattern,
            reason,
            flags,
        )


def check_present_any(checks, check_id, files, pattern, reason, flags=0):
    evidence = []
    for rel in files:
        hits = line_hits(read(rel), pattern, flags)
        for hit in hits[:5]:
            evidence.append({"file": rel, **hit})
        if evidence:
            break
    checks.append({
        "id": check_id,
        "status": "PASS" if evidence else "FAIL",
        "file": "; ".join(files[:6]) + ("; ..." if len(files) > 6 else ""),
        "reason": reason,
        "evidence": evidence[:20] if evidence else [{"line": 0, "snippet": "pattern missing"}],
    })


def extract_body(text, start_pattern, end_pattern):
    start = re.search(start_pattern, text)
    if not start:
        return "", 0
    end = re.search(end_pattern, text[start.end():])
    if not end:
        return text[start.start():], start.start()
    return text[start.start(): start.end() + end.start()], start.start()


def root_host_clean():
    checks = []
    content = "iOSMerchandiseControl/ContentView.swift"
    forbidden = (
        r"SupabaseManualSyncForegroundRootHost|"
        r"SupabaseManualSyncCompatibilityAdapter|"
        r"SupabaseManualSyncReleaseFactory|"
        r"SupabaseManualSyncViewModel"
    )
    check_absent(
        checks,
        "contentview_no_manual_sync_runtime_types",
        content,
        forbidden,
        "ContentView must not instantiate or pass SupabaseManualSync runtime/facade types.",
    )
    check_absent(
        checks,
        "contentview_no_manual_vm_closure",
        content,
        r"manualSyncViewModel|manualSyncCancelHandler",
        "ContentView root host/content closure must not carry a manual sync VM through the normal app tree.",
    )
    check_present(
        checks,
        "contentview_has_clean_root_host",
        content,
        r"\b(AppSyncRootHost|SyncRootHost)\b",
        "ContentView should compose a clean app-level sync root host.",
    )
    return checks


def automatic_contracts_clean():
    checks = []
    providers = "iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift"
    runtime = "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift"
    forbidden_contracts = (
        r"SupabaseManualSync[A-Za-z0-9_]*|"
        r"\bManualPushPlan\b|"
        r"\bSupabaseManualPushResult\b|"
        r"\bProductPriceManualPushResult\b|"
        r"\bSupabaseSyncEventIncrementalApplySummary\b"
    )
    check_absent(
        checks,
        "providers_no_legacy_or_manual_contracts",
        providers,
        forbidden_contracts,
        "Automatic provider contracts must not expose Manual/SupabaseManualSync DTOs or results.",
    )
    check_absent(
        checks,
        "runtime_no_legacy_or_manual_contracts",
        runtime,
        forbidden_contracts,
        "Automatic runtime must consume only clean sync contracts/results.",
    )
    check_present(
        checks,
        "providers_has_clean_incremental_summary",
        providers,
        r"\bSyncIncrementalPullSummary\b",
        "Automatic incremental pull contract should expose a clean SyncIncrementalPullSummary.",
    )
    return checks


def options_observer_only():
    checks = []
    options = "iOSMerchandiseControl/OptionsView.swift"
    check_present(
        checks,
        "options_uses_summary_provider",
        options,
        r"\bOptionsSyncSummaryProvider\b",
        "Options should observe a summary provider.",
    )
    check_present(
        checks,
        "options_uses_status_presenter",
        options,
        r"\bSyncStatusPresenter\b",
        "Options should use SyncStatusPresenter for UI-only status decisions.",
    )
    check_absent(
        checks,
        "options_no_manual_vm_or_factory",
        options,
        r"SupabaseManualSyncViewModel|SupabaseManualSyncReleaseFactory|SupabaseManualSyncCompatibilityAdapter",
        "Options public sync surface must not own or instantiate the manual VM/factory/adapter.",
    )
    check_absent(
        checks,
        "options_no_sync_start_owner",
        options,
        r"\.start\s*\(|startRun\s*\(|viewModel\.start|syncNow|downloadCloudDatabase|checkCloud",
        "Options must not start automatic foreground/realtime/reconnect sync.",
    )
    check_absent(
        checks,
        "options_no_direct_remote_decision_fetch",
        options,
        r"fetchReconciliationRemoteCounts\s*\(",
        "Options view must not directly perform remote decision fetches.",
    )
    check_absent(
        checks,
        "options_automatic_ui_no_manual_l10n_keys",
        options,
        r"options\.supabase\.manualSync\.(root|action\.signIn)",
        "Options automatic/account UI must not use manualSync localization keys.",
    )
    return checks


def duplicate_sync_owner():
    checks = []
    orchestrator = "iOSMerchandiseControl/Sync/SyncOrchestrator.swift"
    text = read(orchestrator)
    check_absent(
        checks,
        "orchestrator_no_manual_or_legacy_facade",
        orchestrator,
        r"manualAdapter|legacyAdapter|legacyManualSyncViewModel|SyncOrchestratorLegacySyncAdapter|SupabaseManualSync[A-Za-z0-9_]*",
        "SyncOrchestrator must not depend on manual/legacy facade types.",
    )
    check_absent(
        checks,
        "orchestrator_no_manual_root_l10n_keys",
        orchestrator,
        r"options\.supabase\.manualSync\.root",
        "Automatic root banner must use automatic sync localization keys.",
    )
    for rel in [
        orchestrator,
        "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift",
        "iOSMerchandiseControl/Sync/SyncStateStore.swift",
        "iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalDomainApplyService.swift",
    ]:
        check_absent(
            checks,
            f"{pathlib.Path(rel).stem}_no_task115_runtime_keys",
            rel,
            r"task115\.runtime|task114\.runtime|task115\.syncEvents\.lightReconcile",
            "Automatic runtime diagnostics must not write task115/task114 legacy runtime keys.",
        )
    body, offset = extract_body(
        text,
        r"func\s+submitForegroundTrigger",
        r"\n    func\s+cancelForegroundCheck",
    )
    hits = []
    for match in re.finditer(r"manualAdapter|legacyAdapter|SupabaseManualSync|fullPull|FullPull", body):
        line = text.count("\n", 0, offset + match.start()) + 1
        hits.append({"line": line, "snippet": text.splitlines()[line - 1].strip()})
    checks.append({
        "id": "submit_foreground_clean_call_graph",
        "status": "FAIL" if hits else "PASS",
        "file": orchestrator,
        "reason": "submitForegroundTrigger must route only through SyncDecisionEngine and SyncAutomaticRuntime.",
        "evidence": hits[:20],
    })
    safety_loop_defs = line_hits(text, r"startSyncEventSafetyLoopIfNeeded\s*\(")
    checks.append({
        "id": "orchestrator_single_safety_loop_definition",
        "status": "PASS" if len(safety_loop_defs) <= 3 else "FAIL",
        "file": orchestrator,
        "reason": "Safety loop ownership must remain centralized in SyncOrchestrator.",
        "evidence": safety_loop_defs[:20],
    })
    return checks


def incremental_apply_contract():
    checks = []
    pull = "iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalPullService.swift"
    domain = "iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalDomainApplyService.swift"
    providers = "iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift"
    wrapper = "iOSMerchandiseControl/SupabaseSyncEventIncrementalApplyService.swift"
    check_absent(
        checks,
        "pull_service_no_manual_protocol",
        pull,
        r"SupabaseManualSyncIncrementalPullProviding",
        "SyncEventIncrementalPullService must not conform to manual sync protocols.",
    )
    check_absent(
        checks,
        "automatic_incremental_contract_no_legacy_summary",
        providers,
        r"SupabaseSyncEventIncrementalApplySummary",
        "Automatic provider contract must not expose legacy Supabase incremental summary.",
    )
    check_present(
        checks,
        "pull_service_fetch_dispatch_watermark",
        pull,
        r"fetchSyncEventsAfter|applyNextEvents|WatermarkStore|domainApplyServiceFactory",
        "SyncEventIncrementalPullService should own fetch/dispatch/watermark path.",
    )
    domain_text = read(domain)
    for service in [
        "CatalogIncrementalApplyService",
        "ProductPriceIncrementalApplyService",
        "HistoryIncrementalApplyService",
    ]:
        hits = line_hits(domain_text, rf"\b{service}\b")
        checks.append({
            "id": f"domain_dispatches_to_{service}",
            "status": "PASS" if hits else "FAIL",
            "file": domain,
            "reason": "Domain apply dispatcher must call catalog, product price and history apply services.",
            "evidence": hits[:20] if hits else [{"line": 0, "snippet": "service missing"}],
        })
    check_absent_text(
        checks,
        "wrapper_not_used_by_automatic_path",
        f"{pull}; {providers}",
        read(pull) + "\n" + read(providers),
        r"SupabaseSyncEventIncrementalApplyService",
        "Automatic incremental path must not call the legacy compatibility wrapper.",
    )
    if read(wrapper):
        checks.append({
            "id": "legacy_incremental_wrapper_classified",
            "status": "PASS",
            "file": wrapper,
            "reason": "Legacy incremental wrapper exists and must remain non-automatic or be deleted.",
            "evidence": [{"line": 0, "snippet": "wrapper present for classification"}],
        })
    return checks


def swiftdata_mainactor_heavy():
    checks = []
    heavy_files = [
        "iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalPullService.swift",
        "iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalDomainApplyService.swift",
        "iOSMerchandiseControl/Sync/Incremental/CatalogIncrementalApplyService.swift",
        "iOSMerchandiseControl/Sync/Incremental/ProductPriceIncrementalApplyService.swift",
        "iOSMerchandiseControl/Sync/Incremental/HistoryIncrementalApplyService.swift",
    ]
    for rel in heavy_files:
        file_exists(checks, f"{pathlib.Path(rel).stem}_present", rel, "Required incremental apply source file must exist.")
        check_absent(
            checks,
            f"{pathlib.Path(rel).stem}_not_mainactor_file",
            rel,
            r"^\s*@MainActor\s*$",
            "Heavy incremental fetch/apply files should not be file/type isolated to MainActor.",
            re.M,
        )
    check_present(
        checks,
        "domain_apply_uses_background_modelcontext",
        "iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalDomainApplyService.swift",
        r"Task\.detached|ModelContext\(modelContainer\)",
        "Domain apply path should use background SwiftData contexts for heavy work.",
    )
    return checks


def l10n_sync_keys():
    checks = []
    locales = ["it.lproj", "en.lproj", "es.lproj", "zh-Hans.lproj"]
    required_prefixes = [
        "options.supabase.automaticSync.",
        "options.supabase.automaticSync.root.",
        "options.cloud.account.",
        "options.localDatabase.",
    ]
    key_sets = {}
    for locale in locales:
        rel = f"iOSMerchandiseControl/{locale}/Localizable.strings"
        text = read(rel)
        keys = set(re.findall(r'"([^"]+)"\s*=', text))
        key_sets[locale] = keys
        for prefix in required_prefixes:
            matches = sorted(k for k in keys if k.startswith(prefix))
            checks.append({
                "id": f"{locale}_{prefix}_present".replace(".", "_").replace("-", "_"),
                "status": "PASS" if matches else "FAIL",
                "file": rel,
                "reason": f"Locale must include sync keys with prefix {prefix}",
                "evidence": [{"line": 0, "snippet": f"{len(matches)} key(s)"}],
            })
    reference = key_sets.get("en.lproj", set())
    sync_reference = {k for k in reference if any(k.startswith(prefix) for prefix in required_prefixes)}
    for locale, keys in key_sets.items():
        missing = sorted(sync_reference - keys)
        checks.append({
            "id": f"{locale}_sync_key_parity".replace("-", "_"),
            "status": "FAIL" if missing else "PASS",
            "file": f"iOSMerchandiseControl/{locale}/Localizable.strings",
            "reason": "Locale must contain the same EN sync/status keys.",
            "evidence": [{"line": 0, "snippet": key} for key in missing[:20]],
        })
    return checks


def no_legacy_runtime_path():
    checks = []
    for group in [
        root_host_clean(),
        automatic_contracts_clean(),
        options_observer_only(),
        duplicate_sync_owner(),
        incremental_apply_contract(),
    ]:
        checks.extend(group)
    runtime = "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift"
    check_present(
        checks,
        "runtime_blocks_full_pull_in_normal_path",
        runtime,
        r"case\s+\.bootstrap,\s*\.fullRecovery:[\s\S]*blocked_full_pull_requires_explicit_context",
        "Automatic runtime must refuse bootstrap/full recovery in normal run(action:) path.",
        re.M,
    )
    return checks


def no_full_pull_normal_path():
    if TASK == "TASK-118":
        return task118_no_full_pull_normal_path()
    checks = []
    runtime = "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift"
    orchestrator = "iOSMerchandiseControl/Sync/SyncOrchestrator.swift"
    content = "iOSMerchandiseControl/ContentView.swift"
    options = "iOSMerchandiseControl/OptionsView.swift"
    check_present(
        checks,
        "runtime_blocks_bootstrap_and_full_recovery",
        runtime,
        r"case\s+\.bootstrap,\s*\.fullRecovery:[\s\S]*blocked_full_pull_requires_explicit_context",
        "Automatic runtime must refuse bootstrap/full recovery in normal run(action:) path.",
        re.M,
    )
    check_present(
        checks,
        "orchestrator_normal_decision_has_no_bootstrap_or_full_recovery",
        orchestrator,
        r"requiresBootstrap:\s*false[\s\S]*requiresFullRecovery:\s*false[\s\S]*fullRecoveryContext:\s*\.normalForeground",
        "Normal foreground decision input must not request bootstrap/full recovery.",
        re.M,
    )
    check_absent(
        checks,
        "root_and_options_do_not_call_full_pull_services",
        content,
        r"SupabasePullApplyService|applyPagedFullPull|pullHistorySessionsFromCloud|fullReconciliation|fullRecovery|bootstrapRequested",
        "Root app view must not call full pull/recovery services.",
    )
    check_absent(
        checks,
        "options_do_not_call_full_pull_services",
        options,
        r"SupabasePullApplyService|applyPagedFullPull|pullHistorySessionsFromCloud|fullReconciliation|fullRecovery|bootstrapRequested",
        "Options public view must not call full pull/recovery services.",
    )
    check_absent(
        checks,
        "orchestrator_submit_body_does_not_start_full_pull",
        orchestrator,
        r"SupabasePullApplyService|applyPagedFullPull|pullHistorySessionsFromCloud|fullReconciliation|bootstrapRequested",
        "SyncOrchestrator normal trigger path must not start full pull services.",
    )
    return checks


def task118_sync_boundaries():
    checks = []
    automatic_files = task118_automatic_source_files()
    all_files = all_swift_sources()
    forbidden_manual_symbols = (
        r"\bSupabaseManualSync[A-Za-z0-9_]*\b|"
        r"\bManualPushPlan\b|"
        r"\bSupabaseManualPushResult\b|"
        r"\bProductPriceManualPushResult\b|"
        r"\bProductPriceManualPushSnapshot\b|"
        r"\bProductPriceManualPushSnapshotFactory\b"
    )
    check_absent_in_files(
        checks,
        "task118_automatic_no_manual_symbol",
        automatic_files,
        forbidden_manual_symbols,
        "TASK-118 automatic sources must not contain manual sync symbols or manual DTO/result types.",
    )
    check_absent(
        checks,
        "task118_content_no_manual_push_service_wiring",
        "iOSMerchandiseControl/ContentView.swift",
        r"SupabaseManualPushService|manualPushService",
        "Root sync wiring must not pass SupabaseManualPushService to automatic runtime.",
    )
    check_absent(
        checks,
        "task118_app_no_manual_push_service_root_dependency",
        "iOSMerchandiseControl/iOSMerchandiseControlApp.swift",
        r"SupabaseManualPushService|manualPushService",
        "App dependency root must not wire manual push service into the automatic path.",
    )
    check_absent(
        checks,
        "task118_runtime_factory_no_manual_push_argument",
        "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift",
        r"SupabaseManualPushService\?|manualPushService\s*:",
        "SyncAutomaticRuntimeFactory.make must not accept SupabaseManualPushService.",
    )
    check_absent(
        checks,
        "task118_runtime_no_catalog_adapter_manual_push",
        "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift",
        r"SyncCatalogPushAdapter[\s\S]*manualPushService",
        "Automatic runtime must not construct SyncCatalogPushAdapter with manualPushService.",
        re.M,
    )
    for type_name in [
        "SyncCatalogPushPlan",
        "SyncCatalogPushResult",
        "SyncProductPricePushPlan",
        "SyncProductPricePushResult",
        "SyncHistorySessionPushPlan",
        "SyncHistorySessionPushResult",
        "SyncActivityRegistrationResult",
        "SyncAutomaticRunResult",
    ]:
        check_present_any(
            checks,
            f"task118_type_present_{type_name}",
            all_files,
            rf"\b{type_name}\b",
            f"TASK-118 automatic domain type {type_name} must exist.",
        )
    check_absent(
        checks,
        "task118_runtime_run_not_bool",
        "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift",
        r"func\s+run\s*\([^)]*\)\s*async\s*->\s*Bool",
        "Automatic runtime run() must return SyncAutomaticRunResult, not Bool.",
        re.M,
    )
    check_absent(
        checks,
        "task118_provider_protocols_not_mainactor",
        "iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift",
        r"@MainActor\s+(?:public\s+|internal\s+)?protocol\s+Sync[A-Za-z0-9_]*Providing",
        "Automatic provider protocols must not be @MainActor.",
        re.M,
    )
    check_absent(
        checks,
        "task118_options_no_idle_progress_hardcode",
        "iOSMerchandiseControl/OptionsView.swift",
        r"CloudSyncProgressState\.idle\(\)",
        "Options/root banner must observe real sync state rather than hardcoded idle progress.",
    )
    check_present_any(
        checks,
        "task118_options_observes_sync_state",
        [
            "iOSMerchandiseControl/OptionsView.swift",
            "iOSMerchandiseControl/Sync/Presentation/OptionsSyncSummaryProvider.swift",
            "iOSMerchandiseControl/Sync/SyncStateStore.swift",
        ],
        r"SyncStateStore|SyncState|OptionsSyncSummaryProvider|SyncStatusPresenter",
        "Options/root banner must read real runtime/sync state through sync presentation/state APIs.",
    )
    return checks


def task118_no_full_pull_normal_path():
    checks = []
    orchestrator = "iOSMerchandiseControl/Sync/SyncOrchestrator.swift"
    runtime = "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift"
    content = "iOSMerchandiseControl/ContentView.swift"
    options = "iOSMerchandiseControl/OptionsView.swift"
    check_present_any(
        checks,
        "task118_decision_input_provider_present",
        all_swift_sources(),
        r"SyncDecisionInputProvider|SyncDecisionInputSnapshot|SyncDecisionSnapshotProvider",
        "TASK-118 must add a real decision input/snapshot provider.",
    )
    check_absent(
        checks,
        "task118_no_hardcoded_network_available",
        orchestrator,
        r"isNetworkAvailable:\s*true",
        "SyncDecisionEngine input must use real reachability, not hardcoded network availability.",
    )
    check_absent(
        checks,
        "task118_no_hardcoded_bootstrap_false",
        orchestrator,
        r"requiresBootstrap:\s*false",
        "Bootstrap status must come from real state, not a hardcoded false.",
    )
    check_absent(
        checks,
        "task118_no_hardcoded_full_recovery_false",
        orchestrator,
        r"requiresFullRecovery:\s*false",
        "Full recovery status must come from real state, not a hardcoded false.",
    )
    check_absent(
        checks,
        "task118_no_source_localmutation_pending_proxy",
        orchestrator,
        r"hasPendingLocalChanges:\s*source\s*==\s*\.localMutation",
        "Pending local changes/outbox must be read from real stores, not inferred from trigger source.",
    )
    check_absent(
        checks,
        "task118_runtime_no_bool_success_failure_ambiguity",
        runtime,
        r"catch[\s\S]*return\s+true|case\s+\.none:[\s\S]*return\s+true",
        "Runtime result semantics must not collapse failure/no-work into true.",
        re.M,
    )
    for rel, check_id in [
        (content, "task118_content_no_full_pull_services"),
        (options, "task118_options_no_full_pull_services"),
        (orchestrator, "task118_orchestrator_no_full_pull_services"),
    ]:
        check_absent(
            checks,
            check_id,
            rel,
            r"SupabasePullApplyService|applyPagedFullPull|pullHistorySessionsFromCloud|fullReconciliation|bootstrapRequested",
            "Foreground/timer/realtime/local mutation normal path must not call full pull services.",
        )
    return checks


def evidence_bundle():
    checks = []
    evidence_dir = REPO / f"docs/TASKS/EVIDENCE/{TASK}"
    required = [
        "README.md",
        "10-execution-start.md",
        "11-preflight-and-baseline.md",
        "12-automation-harness-baseline.md",
    ]
    for name in required:
        exists = (evidence_dir / name).exists()
        checks.append({
            "id": f"evidence_{name.replace('.', '_').replace('-', '_')}",
            "status": "PASS" if exists else "FAIL",
            "file": f"docs/TASKS/EVIDENCE/{TASK}/{name}",
            "reason": "Required evidence file must exist.",
            "evidence": [] if exists else [{"line": 0, "snippet": "missing"}],
        })
    json_reports = list((evidence_dir / "agent-runs").glob("*.json")) if (evidence_dir / "agent-runs").exists() else []
    checks.append({
        "id": "agent_run_json_reports_present",
        "status": "PASS" if json_reports else "FAIL",
        "file": f"docs/TASKS/EVIDENCE/{TASK}/agent-runs",
        "reason": "Harness evidence bundle should include JSON reports.",
        "evidence": [{"line": 0, "snippet": str(len(json_reports))}],
    })
    return checks


SCAN_MAP = {
    "sync-boundaries": task118_sync_boundaries,
    "automatic-contracts-clean": automatic_contracts_clean,
    "root-host-clean": root_host_clean,
    "options-observer-only": options_observer_only,
    "duplicate-sync-owner": duplicate_sync_owner,
    "incremental-apply-contract": incremental_apply_contract,
    "swiftdata-mainactor-heavy": swiftdata_mainactor_heavy,
    "l10n-sync-keys": l10n_sync_keys,
    "no-legacy-runtime-path": no_legacy_runtime_path,
    "no-full-pull-normal-path": no_full_pull_normal_path,
    "evidence-bundle": evidence_bundle,
}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in SCAN_MAP:
        print(json.dumps({
            "schemaVersion": "1.1",
            "taskId": TASK,
            "source": "task117.scan",
            "status": "MISCONFIGURED",
            "NEXT_ACTION": "Use one of: " + ", ".join(sorted(SCAN_MAP)),
        }, sort_keys=True))
        return 3

    name = sys.argv[1]
    started = now()
    checks = SCAN_MAP[name]()
    failures = [item for item in checks if item["status"] == "FAIL"]
    status = "FAIL" if failures else "PASS"
    payload = {
        "schemaVersion": "1.1",
        "taskId": TASK,
        "source": f"scan.{name}",
        "startedAt": started,
        "completedAt": now(),
        "status": status,
        "NEXT_ACTION": "Fix failing source/call-graph checks and rerun." if failures else f"Use this report in {TASK} evidence matrix.",
        "failureCount": len(failures),
        "checks": checks,
    }
    print(json.dumps(payload, sort_keys=True))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
