#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import pathlib
import re
import sys
from datetime import datetime, timezone
from typing import Any


TASK_ID = os.environ.get("TASK_ID", "TASK-127")
IOS_REPO = pathlib.Path(os.environ.get("IOS_REPO", ".")).resolve()
ANDROID_REPO = pathlib.Path(os.environ.get("ANDROID_REPO", "")).resolve()
SCAN = sys.argv[1] if len(sys.argv) > 1 else ""

TASK127_SCANS = {
    "options-mainactor-heavy-fetch",
    "productprice-full-fetch-mainactor",
    "options-refresh-debounce",
    "task127-debug-hook-release-safety",
    "task127-final-gates",
    "scanner-self-tests",
    "android-options-performance",
}


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def rel(path: pathlib.Path, root: pathlib.Path = IOS_REPO) -> str:
    try:
        return str(path.resolve().relative_to(root))
    except Exception:
        return str(path)


def read(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def repo_files(root: pathlib.Path, suffixes: tuple[str, ...]) -> list[pathlib.Path]:
    ignored = {".git", "DerivedData", "build", ".gradle", ".idea", "agent-runs"}
    if root.is_file():
        return [root]
    if not root.exists():
        return []
    return [
        path for path in root.rglob("*")
        if path.is_file()
        and path.suffix in suffixes
        and not ignored.intersection(path.parts)
    ]


def repo_text(root: pathlib.Path, suffixes: tuple[str, ...]) -> str:
    chunks: list[str] = []
    for path in repo_files(root, suffixes):
        chunks.append(f"\n// FILE: {rel(path, root)}\n")
        chunks.append(read(path))
    return "\n".join(chunks)


def check(checks: list[dict[str, Any]], check_id: str, ok: bool, reason: str, evidence: Any = None, fail_status: str = "FAIL") -> None:
    checks.append({
        "id": check_id,
        "status": "PASS" if ok else fail_status,
        "reason": reason,
        "evidence": evidence if evidence is not None else {},
    })


def status_and_code(checks: list[dict[str, Any]]) -> tuple[str, int]:
    statuses = [str(item.get("status", "MISCONFIGURED")) for item in checks]
    if "MISCONFIGURED" in statuses:
        return "MISCONFIGURED", 3
    if "BLOCKED_EXTERNAL" in statuses:
        return "BLOCKED_EXTERNAL", 2
    if "UNSAFE_OPERATION_REFUSED" in statuses:
        return "UNSAFE_OPERATION_REFUSED", 4
    if "FAIL" in statuses:
        return "FAIL", 1
    return "PASS", 0


def report(scan: str, checks: list[dict[str, Any]], next_action: str, details: dict[str, Any] | None = None) -> tuple[int, dict[str, Any]]:
    status, code = status_and_code(checks)
    return code, {
        "schemaVersion": "1.1",
        "taskId": TASK_ID,
        "source": f"scan.{scan}",
        "startedAt": now(),
        "completedAt": now(),
        "status": status,
        "result": status,
        "redactionApplied": True,
        "checks": checks,
        "details": details or {},
        "NEXT_ACTION": "Use this TASK-127 scanner as evidence." if status == "PASS" else next_action,
    }


def line_hits(path: pathlib.Path, pattern: str) -> list[dict[str, Any]]:
    rx = re.compile(pattern, re.S)
    text = read(path)
    hits = []
    for match in rx.finditer(text):
        line = text.count("\n", 0, match.start()) + 1
        excerpt = re.sub(r"\s+", " ", match.group(0)).strip()
        hits.append({"file": rel(path), "line": line, "excerpt": excerpt[:180]})
    return hits


def productprice_full_fetch_hits(root: pathlib.Path) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    patterns = [
        r"context\.fetch\s*\(\s*FetchDescriptor\s*<\s*ProductPrice\s*>\s*\([^)]*\)\s*\)\s*\.filter",
        r"context\.fetch\s*\(\s*FetchDescriptor\s*<\s*ProductPrice\s*>\s*\(\s*\)\s*\)\s*\.filter",
        r"FetchDescriptor\s*<\s*ProductPrice\s*>\s*\([^)]*\)[\s\S]{0,260}\.filter\s*\{[\s\S]{0,220}remoteDeletedAt\s*==\s*nil",
    ]
    for path in repo_files(root, (".swift",)):
        if any(part.endswith("Tests") for part in path.parts) or path.name.startswith("red_") or path.name.startswith("green_"):
            continue
        for pattern in patterns:
            hits.extend(line_hits(path, pattern))
    return hits


def pending_query_hits(root: pathlib.Path) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    for path in repo_files(root, (".swift",)):
        if path.name != "OptionsView.swift" and "Options" not in path.name:
            continue
        hits.extend(line_hits(path, r"@Query\s+(?:private\s+)?var\s+localPendingChanges\s*:\s*\[\s*LocalPendingChange\s*\]"))
    return hits


def refresh_debounce_failures(root: pathlib.Path) -> list[dict[str, Any]]:
    path = root if root.is_file() else root / "iOSMerchandiseControl/Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift"
    text = read(path)
    failures: list[dict[str, Any]] = []
    has_refresh_all = "func refreshAll(" in text
    has_single_flight = re.search(r"is[A-Za-z0-9_]*Refresh[A-Za-z0-9_]*InFlight|singleFlight|refreshTask|summaryTask", text) is not None
    has_debounce = re.search(r"debounce|Task\.sleep|coalescedEvents|refreshReason", text) is not None
    if has_refresh_all and not has_single_flight:
        failures.append({"file": rel(path), "line": 1, "excerpt": "refreshAll lacks explicit single-flight/in-flight guard"})
    if has_refresh_all and not has_debounce:
        failures.append({"file": rel(path), "line": 1, "excerpt": "refreshAll lacks debounce/coalescing markers"})
    return failures


def debug_hook_release_hits(root: pathlib.Path) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    search_root = root if root.is_file() else root / "iOSMerchandiseControl"
    for path in repo_files(search_root, (".swift",)):
        text = read(path)
        if "OptionsPerformanceProbe" not in text and "TASK127_PERF_" not in text:
            continue
        for match in re.finditer(r"(OptionsPerformanceProbe|TASK127_PERF_)", text):
            prefix = text[max(0, match.start() - 220):match.start()]
            if "#if DEBUG" not in prefix:
                hits.append({
                    "file": rel(path),
                    "line": text.count("\n", 0, match.start()) + 1,
                    "excerpt": match.group(0),
                })
    return hits


def scan_options_mainactor(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    root = root or IOS_REPO
    checks: list[dict[str, Any]] = []
    pp_hits = productprice_full_fetch_hits(root)
    pending_hits = pending_query_hits(root)
    check(checks, "no-productprice-full-fetch-filter", not pp_hits, "Options path must not full-fetch ProductPrice and filter relationships on MainActor.", pp_hits)
    check(checks, "no-options-unscoped-pending-query", not pending_hits, "OptionsView must not materialize all LocalPendingChange rows through @Query.", pending_hits)
    provider = read(root / "iOSMerchandiseControl/Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift")
    check(checks, "provider-has-loading-stale-state", all(token in provider for token in ["isLoading", "isStale", "lastRefreshedAt"]), "Provider/cache state must expose loading/stale/last refreshed metadata.")
    return report("options-mainactor-heavy-fetch", checks, "Move heavy summary/pending work out of OptionsView/MainActor.")


def scan_productprice(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    root = root or IOS_REPO
    hits = productprice_full_fetch_hits(root)
    checks: list[dict[str, Any]] = []
    check(checks, "no-productprice-fetch-filter-mainactor", not hits, "ProductPrice count must avoid full fetch/filter on the MainActor.", hits)
    text = read(root) if root.is_file() else repo_text(root / "iOSMerchandiseControl", (".swift",))
    check(checks, "efficient-count-marker", "fetchCount" in text or "OptionsLocalSummaryService" in text, "Implementation must use fetchCount, background summary service, or a documented cached count path.")
    return report("productprice-full-fetch-mainactor", checks, "Replace ProductPrice full fetch/filter with efficient counted/background summary path.")


def scan_refresh_debounce(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    root = root or IOS_REPO
    failures = refresh_debounce_failures(root)
    checks: list[dict[str, Any]] = []
    check(checks, "refresh-single-flight-debounced", not failures, "Options summary refresh must be single-flight/debounced/coalesced.", failures)
    return report("options-refresh-debounce", checks, "Add single-flight/debounce/coalescing to Options summary refresh.")


def scan_debug_release(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    root = root or IOS_REPO
    hits = debug_hook_release_hits(root)
    checks: list[dict[str, Any]] = []
    check(checks, "task127-debug-probe-debug-only", not hits, "TASK-127 debug performance hooks must be compiled only in DEBUG.", hits)
    return report("task127-debug-hook-release-safety", checks, "Wrap TASK-127 debug hooks in #if DEBUG or remove them from app target.")


def android_audit(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    root = root or ANDROID_REPO
    checks: list[dict[str, Any]] = []
    if not root.exists():
        check(checks, "android-repo-present", False, "Android repo must be available for audit.", {"repo": "<redacted>"}, "BLOCKED_EXTERNAL")
        return report("android-options-performance", checks, "Open/configure Android repo and rerun audit.")
    text = repo_text(root / "app/src/main/java", (".kt",))
    options = repo_text(root / "app/src/main/java", (".kt",))
    status_ok = "LocalDatabaseStatusUiState" in text and ("StateFlow" in text or "Flow<" in text)
    check(checks, "status-state-viewmodel-flow", status_ok, "Options status should be emitted as ViewModel/Flow state.")
    check(checks, "repository-uses-dispatchers-io", "Dispatchers.IO" in text or "withContext(ioDispatcher" in text, "Repository/status queries should run on IO dispatcher.")
    check(checks, "options-no-direct-dao", not re.search(r"@Composable[\s\S]{0,800}(Dao|Repository)\.", options), "Options Composable must not call DAO/repository directly.")
    check(checks, "productprice-summary-view-present", "ProductPriceSummary" in text and "product_prices" in text, "ProductPriceSummary/index support should exist for large datasets.")
    status, _ = status_and_code(checks)
    verdict = "NO_RUNTIME_PATCH_REQUIRED" if status == "PASS" else "CHANGES_REQUIRED_OPTIONS_STATUS_THREADING"
    details = {"verdict": verdict}
    return report("android-options-performance", checks, "Fix Android Options status threading/cost if required.", details)


def scan_final_gates() -> tuple[int, dict[str, Any]]:
    checks: list[dict[str, Any]] = []
    evidence = IOS_REPO / "docs/TASKS/EVIDENCE/TASK-127"
    required = [
        "20a-options-summary-semantics-adr.md",
        "58-plan-vs-execution-delta.md",
        "59-final-performance-comparison.json",
        "60-final-review-handoff.md",
        "61-final-sensitive-evidence-repo-diff.md",
    ]
    for name in required:
        path = evidence / name
        check(checks, f"evidence-{name}", path.exists(), f"Required TASK-127 final evidence exists: {name}.", {"path": rel(path)})
    comparison = {}
    try:
        comparison = json.loads(read(evidence / "59-final-performance-comparison.json"))
    except Exception:
        pass
    post = comparison.get("postFix") or {}
    limits = comparison.get("measurementLimits") or {}
    has_ui_metrics = post.get("tapToFirstFrameMs") is not None and post.get("maxMainThreadStallMs") is not None
    if has_ui_metrics:
        budget_ok = post.get("tapToFirstFrameMs", 999999) <= 200 and post.get("maxMainThreadStallMs", 999999) <= 100
    else:
        budget_ok = comparison.get("status") == "PASS_WITH_NOTES" and limits.get("simulatorUiTapProbeAvailable") is False
    check(checks, "postfix-performance-budget", bool(post) and budget_ok, "Post-fix Options performance budget must be documented; missing UI tap metrics require PASS_WITH_NOTES fallback evidence.", post)
    return report("task127-final-gates", checks, "Complete missing final evidence/performance gate artifacts.")


def run_fixture(scan_name: str, fixture: pathlib.Path) -> tuple[str, int]:
    if scan_name == "options-mainactor-heavy-fetch":
        code, _ = scan_options_mainactor(fixture)
    elif scan_name == "productprice-full-fetch-mainactor":
        code, _ = scan_productprice(fixture)
    elif scan_name == "options-refresh-debounce":
        code, _ = scan_refresh_debounce(fixture)
    elif scan_name == "task127-debug-hook-release-safety":
        code, _ = scan_debug_release(fixture)
    else:
        return "MISCONFIGURED", 3
    return ("PASS" if code == 0 else "FAIL" if code == 1 else "MISCONFIGURED"), code


def scanner_self_tests() -> tuple[int, dict[str, Any]]:
    fixtures = IOS_REPO / "tools/agent/fixtures/task127_scanners"
    matrix = [
        ("red_productprice_fetch_filter_mainactor.swift", "productprice-full-fetch-mainactor", "FAIL"),
        ("red_options_view_unscoped_pending_query.swift", "options-mainactor-heavy-fetch", "FAIL"),
        ("red_refreshall_no_debounce.swift", "options-refresh-debounce", "FAIL"),
        ("red_debug_hook_release_string.swift", "task127-debug-hook-release-safety", "FAIL"),
        ("green_background_summary_service.swift", "productprice-full-fetch-mainactor", "PASS"),
        ("green_debounced_presenter.swift", "options-refresh-debounce", "PASS"),
        ("green_debug_only_probe.swift", "task127-debug-hook-release-safety", "PASS"),
    ]
    checks: list[dict[str, Any]] = []
    for filename, scan_name, expected in matrix:
        fixture = fixtures / filename
        if not fixture.exists():
            check(checks, f"fixture-{filename}", False, "Required scanner fixture is missing.", {"path": rel(fixture)}, "MISCONFIGURED")
            continue
        actual, _ = run_fixture(scan_name, fixture)
        check(checks, f"{filename}-{scan_name}", actual == expected, f"Fixture {filename} must produce {expected}.", {"actual": actual, "expected": expected, "scan": scan_name})
    return report("scanner-self-tests", checks, "Fix TASK-127 scanner fixture RED/GREEN expectations.")


def main() -> int:
    if SCAN not in TASK127_SCANS:
        code, payload = report(SCAN or "unknown", [{"id": "known-scan", "status": "MISCONFIGURED", "reason": "Unknown TASK-127 scan.", "evidence": {"scan": SCAN}}], "Use a registered TASK-127 scan.")
    elif SCAN == "options-mainactor-heavy-fetch":
        code, payload = scan_options_mainactor()
    elif SCAN == "productprice-full-fetch-mainactor":
        code, payload = scan_productprice()
    elif SCAN == "options-refresh-debounce":
        code, payload = scan_refresh_debounce()
    elif SCAN == "task127-debug-hook-release-safety":
        code, payload = scan_debug_release()
    elif SCAN == "android-options-performance":
        code, payload = android_audit()
    elif SCAN == "task127-final-gates":
        code, payload = scan_final_gates()
    else:
        code, payload = scanner_self_tests()
    print(json.dumps(payload, indent=2, sort_keys=True))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
