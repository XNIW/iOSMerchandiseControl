#!/usr/bin/env python3
"""Shared sync architecture scanners for mc-agent.

The scanner is intentionally read-only. It reports architecture, boundary,
dead-code, and project-membership findings without editing or deleting files.
"""

from __future__ import annotations

import datetime as _dt
import json
import os
import re
import sys
from pathlib import Path
from typing import Iterable


TASK_ID = os.environ.get("TASK_ID", "TASK-119")
REPO = Path(os.environ.get("IOS_REPO", os.getcwd())).resolve()
SCHEMA_VERSION = "1.1"


def _now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()


def _rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO).as_posix()
    except ValueError:
        return path.as_posix()


def _path(rel_path: str) -> Path:
    return REPO / rel_path


def _read(rel_path: str) -> str:
    return _path(rel_path).read_text(encoding="utf-8")


def _line_count(rel_path: str) -> int:
    path = _path(rel_path)
    if not path.exists():
        return 0
    return len(path.read_text(encoding="utf-8", errors="replace").splitlines())


def _line_hits(rel_path: str, pattern: str, flags: int = 0) -> list[dict[str, object]]:
    path = _path(rel_path)
    if not path.exists():
        return []
    rx = re.compile(pattern, flags)
    hits: list[dict[str, object]] = []
    for idx, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
        if rx.search(line):
            hits.append({"line": idx, "snippet": line.strip()[:220]})
    return hits


def _regex_present(rel_path: str, pattern: str, flags: int = 0) -> tuple[bool, list[dict[str, object]]]:
    path = _path(rel_path)
    if not path.exists():
        return False, [{"line": 0, "snippet": "file missing"}]
    text = path.read_text(encoding="utf-8", errors="replace")
    match = re.search(pattern, text, flags)
    if not match:
        return False, [{"line": 0, "snippet": "pattern missing"}]
    line = text.count("\n", 0, match.start()) + 1
    snippet = text.splitlines()[line - 1].strip() if line > 0 else match.group(0)
    return True, [{"line": line, "snippet": snippet[:220]}]


def _swift_files(*roots: str) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        base = _path(root)
        if base.is_file() and base.suffix == ".swift":
            files.append(base)
        elif base.is_dir():
            files.extend(sorted(base.rglob("*.swift")))
    return sorted(set(files))


def _all_repo_text_files() -> Iterable[Path]:
    excluded_parts = {".git", "DerivedData", "agent-runs", ".build", "build"}
    for path in REPO.rglob("*"):
        if not path.is_file():
            continue
        if any(part in excluded_parts for part in path.parts):
            continue
        if path.suffix.lower() in {".swift", ".md", ".m", ".mm", ".h", ".py", ".sh", ".mjs", ".json", ".pbxproj"}:
            yield path


def _check(
    checks: list[dict[str, object]],
    check_id: str,
    status: str,
    reason: str,
    *,
    file: str | None = None,
    evidence: object | None = None,
    fix_hint: str | None = None,
) -> None:
    item: dict[str, object] = {"id": check_id, "status": status, "reason": reason}
    if file:
        item["file"] = file
    if evidence is not None:
        item["evidence"] = evidence
    if fix_hint:
        item["fix_hint"] = fix_hint
    checks.append(item)


def _report(scan: str, checks: list[dict[str, object]], next_action: str) -> dict[str, object]:
    failing = [c for c in checks if c.get("status") == "FAIL"]
    misconfigured = [c for c in checks if c.get("status") == "MISCONFIGURED"]
    if misconfigured:
        status = "MISCONFIGURED"
    elif failing:
        status = "FAIL"
    else:
        status = "PASS"

    return {
        "schema_version": SCHEMA_VERSION,
        "schemaVersion": SCHEMA_VERSION,
        "task_id": TASK_ID,
        "taskId": TASK_ID,
        "source": f"scan.{scan}",
        "scan": scan,
        "result_status": status,
        "status": status,
        "summary": f"{scan}: {status} ({len(failing)} failing checks, {len(checks)} total checks)",
        "started_at": _now(),
        "completed_at": _now(),
        "safety_level": "read_only_static_scan",
        "repository": str(REPO),
        "checks": checks,
        "NEXT_ACTION": next_action,
    }


def scan_sync_architecture() -> dict[str, object]:
    checks: list[dict[str, object]] = []

    required_dirs = [
        "iOSMerchandiseControl/Sync/Automatic/Core",
        "iOSMerchandiseControl/Sync/Automatic/Decision",
        "iOSMerchandiseControl/Sync/Automatic/Catalog",
        "iOSMerchandiseControl/Sync/Automatic/ProductPrice",
        "iOSMerchandiseControl/Sync/Automatic/History",
        "iOSMerchandiseControl/Sync/Automatic/Outbox",
        "iOSMerchandiseControl/Sync/Automatic/Pull",
        "iOSMerchandiseControl/Sync/Automatic/Presentation",
        "iOSMerchandiseControl/Sync/Manual",
        "iOSMerchandiseControl/Sync/Shared",
    ]
    for rel_dir in required_dirs:
        exists = _path(rel_dir).is_dir()
        _check(
            checks,
            f"target_dir:{rel_dir}",
            "PASS" if exists else "FAIL",
            "Target architecture directory is present." if exists else "Target architecture directory is missing.",
            file=rel_dir,
            fix_hint="Create the target domain directory during TASK-119 refactor and move only cohesive ownership into it.",
        )

    god_file_threshold = int(os.environ.get("MC_SYNC_GOD_FILE_THRESHOLD", "600"))
    god_files = [
        "iOSMerchandiseControl/Sync/AutomaticPushServices.swift",
        "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift",
    ]
    god_files.extend(_rel(path) for path in _swift_files("iOSMerchandiseControl/Sync/Automatic"))
    for rel_file in sorted(set(god_files)):
        line_count = _line_count(rel_file)
        status = "PASS" if line_count and line_count <= god_file_threshold else "FAIL"
        _check(
            checks,
            f"god_file:{rel_file}",
            status,
            f"{line_count} lines; threshold is {god_file_threshold}.",
            file=rel_file,
            evidence={"line_count": line_count, "threshold": god_file_threshold},
            fix_hint="Split by domain responsibility or document reviewer-approved justification if retained.",
        )

    engine_file = "iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift"
    main_actor_hits = _line_hits(engine_file, r"@MainActor")
    _check(
        checks,
        "automatic_core_non_ui_mainactor",
        "FAIL" if main_actor_hits else "PASS",
        "Automatic engine contains @MainActor markers." if main_actor_hits else "Automatic engine has no @MainActor marker.",
        file=engine_file,
        evidence=main_actor_hits,
        fix_hint="Move non-UI work to an engine/service that is not MainActor-isolated; keep MainActor usage in the SwiftUI facade only.",
    )

    runtime_file = "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift"
    runtime_text = _read(runtime_file) if _path(runtime_file).exists() else ""
    engine_text = _read(engine_file) if _path(engine_file).exists() else ""
    single_flight_file = _path("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncSingleFlight.swift")
    cancellation_file = _path("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncCancellationPolicy.swift")
    placeholder_active_task = "activeTask" in runtime_text
    engine_owns_single_flight = (
        single_flight_file.exists()
        and cancellation_file.exists()
        and "AutomaticSyncSingleFlight" in engine_text
        and "AutomaticSyncCancellationPolicy" in engine_text
    )
    _check(
        checks,
        "single_flight_owned_by_automatic_engine",
        "PASS" if engine_owns_single_flight and not placeholder_active_task else "FAIL",
        "Dedicated single-flight/cancellation ownership is present in AutomaticSyncEngine."
        if engine_owns_single_flight and not placeholder_active_task
        else "Runtime still owns placeholder state or engine single-flight/cancellation ownership is incomplete.",
        file=runtime_file,
        evidence={
            "activeTask_in_runtime": placeholder_active_task,
            "single_flight_file_exists": single_flight_file.exists(),
            "cancellation_file_exists": cancellation_file.exists(),
            "engine_references_single_flight": "AutomaticSyncSingleFlight" in engine_text,
            "engine_references_cancellation_policy": "AutomaticSyncCancellationPolicy" in engine_text,
        },
        fix_hint="Extract single-flight/cancel/retry semantics into the automatic engine layer and cover it with tests.",
    )

    fresh_context_files = [
        "iOSMerchandiseControl/Sync/Automatic/Catalog/CatalogPushService.swift",
        "iOSMerchandiseControl/Sync/Automatic/ProductPrice/ProductPricePushService.swift",
        "iOSMerchandiseControl/Sync/Automatic/History/HistorySessionAutomaticPushService.swift",
        "iOSMerchandiseControl/Sync/Automatic/Outbox/SyncActivityRegistrationService.swift",
        "iOSMerchandiseControl/Sync/SyncDecisionInputProvider.swift",
    ]
    for rel_file in fresh_context_files:
        text = _read(rel_file) if _path(rel_file).exists() else ""
        has_fresh_context = "ModelContext(modelContainer)" in text or "ModelContext(" in text and "modelContainer" in text
        _check(
            checks,
            f"fresh_model_context:{rel_file}",
            "PASS" if has_fresh_context else "FAIL",
            "File appears to create SwiftData context from ModelContainer."
            if has_fresh_context
            else "File does not show a fresh ModelContext from ModelContainer.",
            file=rel_file,
            fix_hint="Use ModelContainer + fresh ModelContext for automatic/background SwiftData work.",
        )

    shared_helper = "iOSMerchandiseControl/Sync/Shared/SyncStringCollectionHelpers.swift"
    helper_exists = _path(shared_helper).exists()
    helper_manual_hits = _line_hits(shared_helper, r"SupabaseManual|ManualPush|Compatibility|Adapter") if helper_exists else []
    _check(
        checks,
        "shared_string_collection_helpers_pure",
        "PASS" if helper_exists and not helper_manual_hits else "FAIL",
        "Shared string collection helper exists and does not reference manual-only symbols."
        if helper_exists and not helper_manual_hits
        else "Shared string collection helper is missing or leaks manual-only symbols.",
        file=shared_helper,
        evidence=helper_manual_hits,
        fix_hint="Keep common helper code in Sync/Shared pure and free from manual/automatic ownership leakage.",
    )

    return _report(
        "sync-architecture",
        checks,
        "Resolve failing ownership/structure checks before REVIEW; do not treat file moves alone as completion.",
    )


def scan_manual_boundary() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    automatic_files = [
        "iOSMerchandiseControl/ContentView.swift",
        "iOSMerchandiseControl/iOSMerchandiseControlApp.swift",
        "iOSMerchandiseControl/OptionsView.swift",
        "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift",
        "iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift",
        "iOSMerchandiseControl/Sync/AutomaticPushServices.swift",
        "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
        "iOSMerchandiseControl/Sync/SyncDecisionEngine.swift",
        "iOSMerchandiseControl/Sync/SyncDecisionInputProvider.swift",
        "iOSMerchandiseControl/Sync/SyncState.swift",
        "iOSMerchandiseControl/Sync/SyncStateStore.swift",
    ]
    automatic_files.extend(_rel(path) for path in _swift_files("iOSMerchandiseControl/Sync/Automatic"))
    automatic_files.extend(_rel(path) for path in _swift_files("iOSMerchandiseControl/Sync/Presentation"))

    forbidden = (
        r"\bSupabaseManual[A-Za-z0-9_]*\b|"
        r"\b[A-Za-z0-9_]*ManualPush[A-Za-z0-9_]*\b|"
        r"\bManual[A-Za-z0-9_]*(DTO|Dto|Result|Factory|Coordinator|ViewModel|Adapter|Conversion)[A-Za-z0-9_]*\b|"
        r"\b[A-Za-z0-9_]*Compatibility[A-Za-z0-9_]*\b"
    )
    for rel_file in sorted(set(automatic_files)):
        hits = _line_hits(rel_file, forbidden)
        _check(
            checks,
            f"manual_boundary:{rel_file}",
            "FAIL" if hits else "PASS",
            "Automatic source references manual-only or compatibility symbols."
            if hits
            else "No manual-only or compatibility symbols found in automatic source.",
            file=rel_file,
            evidence=hits,
            fix_hint="Move the dependency behind Sync/Manual or a pure Sync/Shared value type; automatic runtime must not import manual DTO/result/adapter/factory types.",
        )

    shared_remote = "iOSMerchandiseControl/SupabaseInventoryService.swift"
    shared_hits = _line_hits(shared_remote, forbidden)
    remote_contract_protocols = all(
        _path(rel).exists()
        for rel in [
            "iOSMerchandiseControl/Sync/Automatic/Catalog/CatalogRemoteWriting.swift",
            "iOSMerchandiseControl/Sync/Automatic/ProductPrice/ProductPriceRemoteWriting.swift",
            "iOSMerchandiseControl/Sync/Automatic/History/HistorySessionRemoteWriting.swift",
        ]
    )
    _check(
        checks,
        "manual_boundary:shared_remote_contract_visibility",
        "PASS" if not shared_hits or remote_contract_protocols else "FAIL",
        "Shared remote service still contains manual-only symbols, but automatic writes are narrowed through automatic remote-writing protocols."
        if shared_hits and remote_contract_protocols
        else (
            "Shared remote service contains manual-only symbols and automatic remote-writing protocols are missing."
            if shared_hits
            else "Shared remote service does not expose manual-only/compatibility symbols."
        ),
        file=shared_remote,
        evidence={"manual_symbol_hits_sample": shared_hits[:25], "automatic_remote_protocols_present": remote_contract_protocols},
        fix_hint="If manual sync remains supported, keep it in Sync/Manual and prevent automatic runtime imports.",
    )

    return _report(
        "manual-boundary",
        checks,
        "Fix FAIL rows by isolating manual sync as an explicit boundary before automatic runtime REVIEW.",
    )


def _reference_count(symbol: str, candidate_path: Path) -> tuple[int, list[dict[str, object]]]:
    rx = re.compile(rf"\b{re.escape(symbol)}\b")
    count = 0
    samples: list[dict[str, object]] = []
    for path in _all_repo_text_files():
        if path.resolve() == candidate_path.resolve():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for idx, line in enumerate(text.splitlines(), start=1):
            if rx.search(line):
                count += 1
                if len(samples) < 10:
                    samples.append({"file": _rel(path), "line": idx, "snippet": line.strip()[:180]})
    return count, samples


def scan_dead_code() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    project_text = _read("iOSMerchandiseControl.xcodeproj/project.pbxproj")
    candidates = sorted(
        {
            *_swift_files("iOSMerchandiseControl/Sync"),
            *_swift_files("iOSMerchandiseControl"),
        }
    )
    candidate_names = [
        path
        for path in candidates
        if any(
            token in path.name
            for token in [
                "Manual",
                "Compatibility",
                "Adapter",
                "Outbox",
                "HistorySessionSyncService",
            ]
        )
    ]

    if not candidate_names:
        _check(
            checks,
            "dead_code:candidate_inventory",
            "PASS",
            "No manual/compatibility/outbox/history candidate files were found by the inventory heuristic.",
            evidence=[],
        )

    for path in candidate_names:
        symbol = path.stem
        refs, samples = _reference_count(symbol, path)
        xcode_membership = path.name in project_text or _rel(path) in project_text
        _check(
            checks,
            f"dead_code_candidate:{_rel(path)}",
            "PASS",
            "Read-only delete-candidate inventory; no deletion performed.",
            file=_rel(path),
            evidence={
                "symbol": symbol,
                "reference_count_excluding_self": refs,
                "xcode_membership_detected": xcode_membership,
                "samples": samples,
                "delete_candidate": refs == 0,
            },
            fix_hint="Deletion is allowed only after reference scan, Xcode membership audit, build/test plan, and reviewer acceptance.",
        )

    return _report(
        "dead-code",
        checks,
        "Use this read-only inventory to decide future delete candidates; do not delete without xcode-membership/build/test evidence.",
    )


def scan_xcode_membership() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    project_rel = "iOSMerchandiseControl.xcodeproj/project.pbxproj"
    project_path = _path(project_rel)
    if not project_path.exists():
        _check(checks, "xcode_project_exists", "MISCONFIGURED", "project.pbxproj is missing.", file=project_rel)
        return _report("xcode-membership", checks, "Restore or locate the Xcode project before continuing.")

    project_text = project_path.read_text(encoding="utf-8", errors="replace")
    synchronized = "PBXFileSystemSynchronizedRootGroup" in project_text
    _check(
        checks,
        "xcode_filesystem_synchronized_group",
        "PASS" if synchronized else "FAIL",
        "Project uses filesystem synchronized groups." if synchronized else "Project does not show filesystem synchronized groups.",
        file=project_rel,
        fix_hint="After every move/delete, audit explicit refs, build phases, synchronized exceptions, tests, and scripts.",
    )

    swift_refs = sorted(set(re.findall(r"[\w./-]+\.swift", project_text)))
    missing_refs = []
    for ref in swift_refs:
        normalized = ref.strip('"')
        if normalized.startswith("../") or "://" in normalized or normalized.startswith("//"):
            continue
        if not any((REPO / prefix / normalized).exists() for prefix in ["", "iOSMerchandiseControl", "iOSMerchandiseControlTests"]):
            missing_refs.append(normalized)

    _check(
        checks,
        "xcode_explicit_swift_refs_exist",
        "FAIL" if missing_refs else "PASS",
        "All explicit Swift file references found in project.pbxproj exist."
        if not missing_refs
        else "project.pbxproj references missing Swift files.",
        file=project_rel,
        evidence={"missing_refs": missing_refs[:50], "explicit_swift_ref_count": len(swift_refs)},
        fix_hint="Remove stale membership/build-phase refs after move/delete.",
    )

    stale_exception_hits = _line_hits(project_rel, r"AutomaticPushServices|SupabaseManual|Compatibility|Adapter|HistorySessionSyncService")
    _check(
        checks,
        "xcode_sync_exception_audit",
        "PASS",
        "Read-only project membership audit completed for TASK-119-sensitive symbols.",
        file=project_rel,
        evidence=stale_exception_hits[:50],
        fix_hint="Any future move/delete must rerun xcode-membership and inspect synchronized exceptions.",
    )

    return _report(
        "xcode-membership",
        checks,
        "Rerun after every TASK-119 file move/delete; FAIL must block REVIEW.",
    )


def scan_no_full_pull_normal_path() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    forbidden_full_pull_services = (
        r"SupabasePullApplyService|applyPagedFullPull|pullHistorySessionsFromCloud|"
        r"fullReconciliation|bootstrapRequested|BootstrapPullService|FullRecoveryService"
    )

    engine = "iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift"
    found, evidence = _regex_present(
        engine,
        r"case\s+\.bootstrap,\s*\.fullRecovery:[\s\S]*blocked_full_pull_requires_explicit_context[\s\S]*\.blocked\(\.accountDecisionRequired\)",
        re.M,
    )
    _check(
        checks,
        "engine_blocks_bootstrap_and_full_recovery",
        "PASS" if found else "FAIL",
        "Automatic engine refuses bootstrap/fullRecovery in the normal automatic run path."
        if found
        else "Automatic engine does not show an explicit bootstrap/fullRecovery block in normal run(action:) handling.",
        file=engine,
        evidence=evidence,
        fix_hint="Keep full pull/recovery behind explicit account/recovery context; normal automatic run must return a blocked result.",
    )

    runtime = "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift"
    runtime_text = _read(runtime) if _path(runtime).exists() else ""
    runtime_full_pull_hits = _line_hits(runtime, forbidden_full_pull_services)
    _check(
        checks,
        "runtime_facade_delegates_without_full_pull_services",
        "PASS" if "AutomaticSyncEngine" in runtime_text and not runtime_full_pull_hits else "FAIL",
        "Runtime facade delegates to AutomaticSyncEngine and does not instantiate full-pull services."
        if "AutomaticSyncEngine" in runtime_text and not runtime_full_pull_hits
        else "Runtime facade either does not delegate to AutomaticSyncEngine or still references full-pull services.",
        file=runtime,
        evidence={
            "references_engine": "AutomaticSyncEngine" in runtime_text,
            "full_pull_hits": runtime_full_pull_hits,
        },
        fix_hint="Keep UI/auth facade separate from non-UI automatic engine and do not start bootstrap/fullRecovery services here.",
    )

    orchestrator = "iOSMerchandiseControl/Sync/SyncOrchestrator.swift"
    found, evidence = _regex_present(
        orchestrator,
        r"case\s+\.fullRecovery,\s*\.bootstrap:[\s\S]{0,900}recordRunResult\(\.blocked\(\.accountDecisionRequired\)\)[\s\S]{0,500}return",
        re.M,
    )
    _check(
        checks,
        "orchestrator_blocks_full_recovery_before_runtime",
        "PASS" if found else "FAIL",
        "SyncOrchestrator blocks bootstrap/fullRecovery decisions before invoking the automatic runtime."
        if found
        else "SyncOrchestrator does not show an explicit block for bootstrap/fullRecovery decisions before runtime execution.",
        file=orchestrator,
        evidence=evidence,
        fix_hint="The normal foreground path must request explicit account/recovery context instead of starting full pull.",
    )

    provider = "iOSMerchandiseControl/Sync/SyncDecisionInputProvider.swift"
    provider_text = _read(provider) if _path(provider).exists() else ""
    provider_uses_normal_context = "fullRecoveryContext: .normalForeground" in provider_text
    provider_uses_state = (
        "requiresBootstrap(" in provider_text
        and "requiresFullRecovery(" in provider_text
        and "baselineSummary" in provider_text
    )
    _check(
        checks,
        "decision_input_uses_state_and_normal_context",
        "PASS" if provider_uses_normal_context and provider_uses_state else "FAIL",
        "Decision input reads recovery/bootstrap state and marks normal foreground context explicitly."
        if provider_uses_normal_context and provider_uses_state
        else "Decision input does not clearly read recovery/bootstrap state with normal foreground context.",
        file=provider,
        evidence={
            "normal_foreground_context": provider_uses_normal_context,
            "uses_state_helpers": provider_uses_state,
        },
        fix_hint="Do not hardcode bootstrap/fullRecovery false; read state, then force normal foreground into requestRecovery/block semantics.",
    )

    decision = "iOSMerchandiseControl/Sync/SyncDecisionEngine.swift"
    found, evidence = _regex_present(
        decision,
        r"requiresFullRecovery[\s\S]{0,180}allowsFullRecovery\s*\?\s*\.fullRecovery\s*:\s*\.requestRecovery",
        re.M,
    )
    _check(
        checks,
        "decision_engine_normal_recovery_becomes_request_recovery",
        "PASS" if found else "FAIL",
        "Decision engine converts normal foreground full-recovery need into requestRecovery unless context explicitly allows full recovery."
        if found
        else "Decision engine does not show context-gated fullRecovery routing.",
        file=decision,
        evidence=evidence,
        fix_hint="Keep .fullRecovery only for explicit bootstrap/recovery/manual/harness contexts.",
    )

    for rel in [
        "iOSMerchandiseControl/ContentView.swift",
        "iOSMerchandiseControl/OptionsView.swift",
        orchestrator,
    ]:
        hits = _line_hits(rel, forbidden_full_pull_services)
        _check(
            checks,
            f"no_full_pull_services:{rel}",
            "FAIL" if hits else "PASS",
            "Normal UI/orchestrator path references full-pull service symbols."
            if hits
            else "Normal UI/orchestrator path does not reference full-pull service symbols.",
            file=rel,
            evidence=hits,
            fix_hint="Move full pull/recovery work behind explicit account/recovery context, not root/options/foreground normal path.",
        )

    automatic_hits: list[dict[str, object]] = []
    for path in _swift_files("iOSMerchandiseControl/Sync/Automatic"):
        rel = _rel(path)
        for hit in _line_hits(rel, forbidden_full_pull_services):
            automatic_hits.append({"file": rel, **hit})
    _check(
        checks,
        "automatic_domain_no_full_pull_service_instantiation",
        "FAIL" if automatic_hits else "PASS",
        "Automatic domain files instantiate or reference full-pull services."
        if automatic_hits
        else "Automatic domain files do not instantiate full-pull services.",
        evidence=automatic_hits[:50],
        fix_hint="Keep automatic pull incremental-only; explicit full recovery belongs outside normal automatic path.",
    )

    return _report(
        "no-full-pull-normal-path",
        checks,
        "Keep normal automatic sync incremental/request-recovery only; explicit full recovery requires a separate account/recovery context.",
    )


SCANS = {
    "sync-architecture": scan_sync_architecture,
    "manual-boundary": scan_manual_boundary,
    "dead-code": scan_dead_code,
    "xcode-membership": scan_xcode_membership,
    "no-full-pull-normal-path": scan_no_full_pull_normal_path,
}


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in SCANS:
        report = _report(
            "unknown",
            [
                {
                    "id": "scanner_argument",
                    "status": "MISCONFIGURED",
                    "reason": f"Expected one of {', '.join(sorted(SCANS))}.",
                    "evidence": {"argv": argv[1:]},
                }
            ],
            "Call the scanner through mc-agent with a supported TASK-119 scan name.",
        )
        print(json.dumps(report, indent=2, sort_keys=True))
        return 3

    report = SCANS[argv[1]]()
    print(json.dumps(report, indent=2, sort_keys=True))
    status = str(report.get("result_status", "MISCONFIGURED"))
    if status == "PASS":
        return 0
    if status == "FAIL":
        return 1
    if status == "BLOCKED_EXTERNAL":
        return 2
    return 3


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
