#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
from datetime import datetime, timezone


TASK_ID = os.environ.get("TASK_ID", "TASK-125")
IOS_REPO = pathlib.Path(os.environ.get("IOS_REPO", ".")).resolve()
ANDROID_REPO = pathlib.Path(os.environ.get("ANDROID_REPO", "")).resolve()
SUPABASE_REPO = pathlib.Path(os.environ.get("SUPABASE_REPO", "")).resolve()
SCAN = sys.argv[1] if len(sys.argv) > 1 else ""


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def rel(path: pathlib.Path) -> str:
    try:
        return str(path.resolve().relative_to(IOS_REPO))
    except Exception:
        return str(path)


def sha(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:12]


def read(relpath: str, repo: pathlib.Path = IOS_REPO) -> str:
    try:
        return (repo / relpath).read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def iter_files(repo: pathlib.Path, suffixes: tuple[str, ...], excluded_parts: tuple[str, ...] = ()) -> list[pathlib.Path]:
    if not repo.exists():
        return []
    files = []
    for path in repo.rglob("*"):
        if not path.is_file() or path.suffix not in suffixes:
            continue
        parts = set(path.parts)
        if any(part in parts for part in excluded_parts):
            continue
        files.append(path)
    return files


def grep_files(repo: pathlib.Path, suffixes: tuple[str, ...], pattern: str, excluded_parts: tuple[str, ...] = ()) -> list[dict]:
    rx = re.compile(pattern, re.IGNORECASE | re.MULTILINE)
    hits = []
    for path in iter_files(repo, suffixes, excluded_parts):
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for m in rx.finditer(text):
            line = text[: m.start()].count("\n") + 1
            hits.append({"file": rel(path) if repo == IOS_REPO else str(path.relative_to(repo)), "line": line, "hash": sha(m.group(0))})
    return hits


def check(checks: list[dict], check_id: str, ok: bool, reason: str, evidence=None, status_fail="FAIL") -> None:
    checks.append({
        "id": check_id,
        "status": "PASS" if ok else status_fail,
        "reason": reason,
        "evidence": evidence if evidence is not None else {},
    })


def result(checks: list[dict], next_action: str | None = None) -> tuple[int, dict]:
    statuses = [c["status"] for c in checks]
    if "MISCONFIGURED" in statuses:
        status, code = "MISCONFIGURED", 3
    elif "BLOCKED_EXTERNAL" in statuses:
        status, code = "BLOCKED_EXTERNAL", 2
    elif "UNSAFE_OPERATION_REFUSED" in statuses:
        status, code = "UNSAFE_OPERATION_REFUSED", 4
    elif "FAIL" in statuses:
        status, code = "FAIL", 1
    else:
        status, code = "PASS", 0
    payload = {
        "schemaVersion": "1.1",
        "taskId": TASK_ID,
        "source": f"scan.{SCAN}",
        "startedAt": now(),
        "completedAt": now(),
        "status": status,
        "redactionApplied": True,
        "checks": checks,
        "NEXT_ACTION": next_action or ("Continue TASK-125 gates." if status == "PASS" else f"Fix {SCAN} findings and rerun."),
    }
    return code, payload


def scan_no_hidden_manual_sync() -> tuple[int, dict]:
    checks = []
    normal_files = [
        "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
        "iOSMerchandiseControl/Sync/Automatic/AutomaticSyncRuntimeFacade.swift",
        "iOSMerchandiseControl/Sync/Automatic/AutomaticSyncEngine.swift",
    ]
    hits = []
    for f in normal_files:
        text = read(f)
        for needle in ["SupabaseManualSyncViewModel", "ManualSync", "manualSync", "compatibilityAdapter", "legacyAdapter"]:
            if needle in text:
                hits.append({"file": f, "needleHash": sha(needle)})
    check(checks, "automatic_path_has_no_manual_or_compat_dependency", not hits, "Normal automatic path must not call manual/compat sync.", hits)
    return result(checks)


def scan_no_full_pull_normal_path() -> tuple[int, dict]:
    checks = []
    engine = read("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift")
    orchestrator = read("iOSMerchandiseControl/Sync/SyncOrchestrator.swift")
    blocked = "blocked_full_pull_requires_explicit_context" in engine and "fullRecovery" in engine
    normal_hits = []
    for needle in ["performForegroundFullRecoveryIfNeeded", "fullPullBootstrap", "fullPullRecovery", "live-full-pull"]:
        if needle in orchestrator:
            normal_hits.append({"file": "iOSMerchandiseControl/Sync/SyncOrchestrator.swift", "needleHash": sha(needle)})
    check(checks, "automatic_engine_blocks_full_pull_contexts", blocked, "Automatic engine must fail closed for bootstrap/full recovery contexts.")
    check(checks, "orchestrator_no_full_pull_callsite", not normal_hits, "Normal orchestrator path must not call full pull APIs.", normal_hits)
    return result(checks)


def scan_no_service_role_client() -> tuple[int, dict]:
    checks = []
    hits = []
    pattern = r"SUPABASE_SERVICE_ROLE|SERVICE_ROLE_KEY|serviceRole(Key|Secret)?"
    hits += grep_files(IOS_REPO / "iOSMerchandiseControl", (".swift",), pattern, ("Tests",))
    if ANDROID_REPO.exists():
        hits += grep_files(ANDROID_REPO, (".kt", ".java"), pattern, ("build", ".gradle"))
    check(checks, "client_code_has_no_service_role_secret", not hits, "Client code must not reference service_role credentials.", hits)
    return result(checks)


def scan_no_rls_bypass() -> tuple[int, dict]:
    checks = []
    pattern = r"bypassrls|disable\s+row\s+level\s+security|alter\s+table.+disable\s+row\s+level\s+security"
    hits = grep_files(IOS_REPO / "iOSMerchandiseControl", (".swift",), pattern)
    if ANDROID_REPO.exists():
        hits += grep_files(ANDROID_REPO, (".kt", ".java"), pattern, ("build", ".gradle"))
    check(checks, "client_code_has_no_rls_bypass", not hits, "App clients must not bypass or disable RLS.", hits)
    return result(checks)


def scan_no_mainactor_heavy_sync() -> tuple[int, dict]:
    checks = []
    heavy_paths = [
        "iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift",
        "iOSMerchandiseControl/Sync/AutomaticPushServices.swift",
        "iOSMerchandiseControl/Sync/Remote/SupabaseRemoteQueryExecutor.swift",
    ]
    hits = []
    for f in heavy_paths:
        text = read(f)
        if "@MainActor" in text:
            hits.append({"file": f, "reason": "@MainActor on heavy automatic/remote sync file"})
    check(checks, "heavy_automatic_sync_not_mainactor", not hits, "Heavy sync engine/push/remote primitives must not be MainActor-bound.", hits)
    return result(checks)


def scan_no_stale_pbxproj_reference() -> tuple[int, dict]:
    checks = []
    pbx = read("iOSMerchandiseControl.xcodeproj/project.pbxproj")
    swift_refs = sorted(set(re.findall(r"path = ([^;]+\.swift);", pbx)))
    missing = []
    for ref in swift_refs:
        cleaned = ref.strip('"')
        if cleaned.startswith("..") or cleaned.startswith("/"):
            continue
        if not (IOS_REPO / cleaned).exists() and not (IOS_REPO / "iOSMerchandiseControl" / cleaned).exists():
            missing.append(cleaned)
    check(checks, "pbxproj_swift_references_exist", not missing, "No stale Swift pbxproj references.", missing)
    return result(checks)


def scan_no_test_fixture_in_app_target() -> tuple[int, dict]:
    checks = []
    pbx = read("iOSMerchandiseControl.xcodeproj/project.pbxproj")
    hits = []
    for m in re.finditer(r"(Fixture|fixture|TestData|Mock|Fake).*", pbx):
        line = pbx[: m.start()].count("\n") + 1
        hits.append({"file": "iOSMerchandiseControl.xcodeproj/project.pbxproj", "line": line, "hash": sha(m.group(0))})
    check(checks, "no_fixture_or_fake_reference_in_pbxproj", not hits, "App target must not include fixture/test-only files.", hits)
    return result(checks)


def scan_no_root_legacy_sync_service() -> tuple[int, dict]:
    checks = []
    root_swift = [p.name for p in (IOS_REPO / "iOSMerchandiseControl").glob("*.swift")]
    legacy = [name for name in root_swift if re.search(r"(Legacy|Manual.*Sync|SupabaseInventoryService|OldSync)", name)]
    check(checks, "no_root_legacy_sync_services", not legacy, "Root app folder must not retain legacy mixed sync services.", legacy)
    return result(checks)


def scan_remote_adapter_single_domain() -> tuple[int, dict]:
    checks = []
    expected = [
        "iOSMerchandiseControl/Sync/Remote/CatalogRemoteSupabaseAdapter.swift",
        "iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift",
        "iOSMerchandiseControl/Sync/Remote/HistorySessionRemoteSupabaseAdapter.swift",
        "iOSMerchandiseControl/Sync/Remote/SyncEventRemoteSupabaseAdapter.swift",
    ]
    missing = [f for f in expected if not (IOS_REPO / f).exists()]
    mixed_hits = []
    for f in expected:
        text = read(f)
        domains = sum(1 for needle in ["ProductPrice", "History", "SyncEvent"] if needle in text)
        if "CatalogRemoteDataSource" in f:
            domains += 1 if "inventory_products" in text or "Catalog" in text else 0
        if text and domains > 3 and "Composite" not in text:
            mixed_hits.append({"file": f, "domainSignalCount": domains})
    check(checks, "remote_domain_adapters_present", not missing, "Catalog/ProductPrice/History/SyncEvent remote adapters must be distinct.", missing)
    check(checks, "remote_adapters_not_obvious_megaservices", not mixed_hits, "Remote adapters must not mix unrelated domains without composite justification.", mixed_hits)
    return result(checks)


def scan_background_task_registration() -> tuple[int, dict]:
    checks = []
    swift_hits = grep_files(IOS_REPO / "iOSMerchandiseControl", (".swift",), r"BGTaskScheduler|BGAppRefreshTask|BGProcessingTask|BackgroundTasks")
    plist = read("iOSMerchandiseControl/Info.plist")
    check(checks, "backgroundtasks_swift_registration_present", bool(swift_hits), "BackgroundTasks framework registration/handler must exist.", swift_hits)
    check(checks, "plist_permitted_identifiers_present", "BGTaskSchedulerPermittedIdentifiers" in plist, "Info.plist must declare permitted background identifiers.")
    return result(checks)


def scan_background_task_no_ui_context() -> tuple[int, dict]:
    checks = []
    bg_files = [p for p in iter_files(IOS_REPO / "iOSMerchandiseControl/Sync", (".swift",)) if "Background" in str(p) or "BGTask" in p.name]
    ui_hits = []
    for path in bg_files:
        text = path.read_text(encoding="utf-8", errors="ignore")
        if "@Environment" in text or "Environment(\\.modelContext" in text or "View" in text:
            ui_hits.append({"file": rel(path)})
    has_model_container = any("ModelContainer" in p.read_text(encoding="utf-8", errors="ignore") for p in bg_files)
    check(checks, "background_runner_uses_modelcontainer", has_model_container, "Background runner must use ModelContainer/ModelContext independent of UI.")
    check(checks, "background_runner_no_swiftui_environment_context", not ui_hits, "Background runner must not depend on SwiftUI View or @Environment ModelContext.", ui_hits)
    return result(checks)


def scan_outbox_pending_survives_restart() -> tuple[int, dict]:
    checks = []
    pending = read("iOSMerchandiseControl/LocalPendingChange.swift")
    outbox = read("iOSMerchandiseControl/Sync/Outbox/LocalOutboxStore.swift")
    check(checks, "local_pending_swiftdata_model_present", "@Model" in pending and "LocalPendingChange" in pending, "Local pending changes must be persisted in SwiftData.")
    check(checks, "outbox_store_persists_pending", "ModelContext" in outbox and "LocalPendingChange" in outbox, "Outbox store must query/save persisted pending rows.")
    return result(checks)


def scan_evidence_redaction() -> tuple[int, dict]:
    checks = []
    evidence = IOS_REPO / "docs/TASKS/EVIDENCE/TASK-125"
    hits = []
    if evidence.exists():
        for path in evidence.rglob("*"):
            if path.is_file() and path.suffix in {".md", ".json", ".log"}:
                text = path.read_text(encoding="utf-8", errors="ignore")
                for pattern in [r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}", r"[0-9a-fA-F]{40}-[0-9a-fA-F]{8,}"]:
                    if re.search(pattern, text):
                        hits.append({"file": rel(path), "patternHash": sha(pattern)})
    check(checks, "evidence_no_obvious_raw_secret_or_device_id", not hits, "Evidence must redact JWT/token/service_role/device identifiers.", hits)
    return result(checks)


def scan_source_format() -> tuple[int, dict]:
    checks = []
    proc = subprocess.run(["git", "-C", str(IOS_REPO), "diff", "--check", "--"], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = proc.stdout.strip()
    check(checks, "git_diff_check_clean", proc.returncode == 0, "git diff --check must pass.", {"outputHash": sha(output), "lines": output.splitlines()[:20]})
    return result(checks)


def scan_dead_code_residue() -> tuple[int, dict]:
    checks = []
    sync_files = iter_files(IOS_REPO / "iOSMerchandiseControl/Sync", (".swift",))
    residue = []
    for path in sync_files:
        text = path.read_text(encoding="utf-8", errors="ignore")
        if "TODO TASK-125 dead" in text or "LEGACY_UNUSED" in text:
            residue.append({"file": rel(path)})
    check(checks, "no_marked_dead_sync_residue", not residue, "No known dead-code residue markers may remain in Sync.")
    return result(checks)


SCANS = {
    "no-hidden-manual-sync": scan_no_hidden_manual_sync,
    "no-full-pull-normal-path": scan_no_full_pull_normal_path,
    "no-service-role-client": scan_no_service_role_client,
    "no-rls-bypass": scan_no_rls_bypass,
    "no-mainactor-heavy-sync": scan_no_mainactor_heavy_sync,
    "no-stale-pbxproj-reference": scan_no_stale_pbxproj_reference,
    "no-test-fixture-in-app-target": scan_no_test_fixture_in_app_target,
    "no-root-legacy-sync-service": scan_no_root_legacy_sync_service,
    "no-root-supabase-legacy": scan_no_root_legacy_sync_service,
    "remote-adapter-single-domain": scan_remote_adapter_single_domain,
    "background-task-registration": scan_background_task_registration,
    "background-task-no-ui-context": scan_background_task_no_ui_context,
    "outbox-pending-survives-restart": scan_outbox_pending_survives_restart,
    "evidence-redaction": scan_evidence_redaction,
    "source-format": scan_source_format,
    "dead-code-residue": scan_dead_code_residue,
}


if SCAN not in SCANS:
    code, payload = result([{
        "id": "known_scan_name",
        "status": "MISCONFIGURED",
        "reason": f"Unknown TASK-125 scan: {SCAN}",
        "evidence": {"known": sorted(SCANS)},
    }])
else:
    code, payload = SCANS[SCAN]()

print(json.dumps(payload, indent=2, sort_keys=True))
sys.exit(code)
