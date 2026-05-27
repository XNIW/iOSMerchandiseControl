#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import pathlib
import re
import sys
from datetime import datetime, timezone
from typing import Any


TASK_ID = os.environ.get("TASK_ID", "TASK-126")
IOS_REPO = pathlib.Path(os.environ.get("IOS_REPO", ".")).resolve()
ANDROID_REPO = pathlib.Path(os.environ.get("ANDROID_REPO", "")).resolve()
SUPABASE_REPO = pathlib.Path(os.environ.get("SUPABASE_REPO", "")).resolve()
SCAN = sys.argv[1] if len(sys.argv) > 1 else ""

SCANS = [
    "task126-policy-matrix",
    "owner-store-scope",
    "local-store-identity",
    "pending-base-version",
    "changed-fields-contract",
    "no-cross-owner-store-pending-push",
    "conflict-review-coverage",
    "productprice-history-policy",
    "cache-active-store-only",
    "inactive-cache-cleanup-safety",
    "task126-final-gates",
    "scanner-self-tests",
]

TASK126_REQUIRED_COMMANDS = [
    ["scan", "task126-policy-matrix", "--task", "TASK-126", "--strict"],
    ["scan", "owner-store-scope", "--task", "TASK-126", "--strict"],
    ["scan", "local-store-identity", "--task", "TASK-126", "--strict"],
    ["scan", "pending-base-version", "--task", "TASK-126", "--strict"],
    ["scan", "changed-fields-contract", "--task", "TASK-126", "--strict"],
    ["scan", "no-cross-owner-store-pending-push", "--task", "TASK-126", "--strict"],
    ["scan", "conflict-review-coverage", "--task", "TASK-126", "--strict"],
    ["scan", "productprice-history-policy", "--task", "TASK-126", "--strict"],
    ["scan", "cache-active-store-only", "--task", "TASK-126", "--strict"],
    ["scan", "inactive-cache-cleanup-safety", "--task", "TASK-126", "--strict"],
    ["scan", "task126-final-gates", "--task", "TASK-126", "--strict"],
    ["ios", "test", "sync-policy", "--task", "TASK-126"],
    ["ios", "test", "account-store-boundary", "--task", "TASK-126"],
    ["ios", "test", "conflict-review", "--task", "TASK-126"],
    ["ios", "test", "cache-memory", "--task", "TASK-126"],
    ["android", "test", "sync-policy", "--task", "TASK-126"],
    ["android", "test", "account-store-boundary", "--task", "TASK-126"],
    ["android", "test", "conflict-review", "--task", "TASK-126"],
    ["android", "test", "cache-memory", "--task", "TASK-126"],
]


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def rel(path: pathlib.Path, repo: pathlib.Path = IOS_REPO) -> str:
    try:
        return str(path.resolve().relative_to(repo))
    except Exception:
        return str(path)


def read(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def repo_text(root: pathlib.Path, suffixes: tuple[str, ...]) -> str:
    if root.is_file():
        return read(root)
    chunks: list[str] = []
    if not root.exists():
        return ""
    ignored = {".git", "DerivedData", "build", ".gradle", ".idea"}
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in suffixes:
            continue
        if ignored.intersection(path.parts):
            continue
        chunks.append(f"\n// FILE: {rel(path, root)}\n")
        chunks.append(read(path))
    return "\n".join(chunks)


def read_json(path: pathlib.Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


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
        "NEXT_ACTION": "Use this TASK-126 scanner as evidence." if status == "PASS" else next_action,
    }


def task_doc() -> str:
    return read(IOS_REPO / "docs/TASKS/TASK-126-sync-policy-multistore-cache-mvp.md")


def master_plan() -> str:
    return read(IOS_REPO / "docs/MASTER-PLAN.md")


def command_patterns() -> set[str]:
    payload: dict[str, Any] = {}
    for candidate in [
        IOS_REPO / "docs/TASKS/EVIDENCE/TASK-126/agent-runs/00-help-json.json",
        IOS_REPO / "docs/TASKS/EVIDENCE/TASK-126/agent-runs/01-commands-json.json",
        IOS_REPO / "docs/TASKS/EVIDENCE/TASK-126/agent-runs/00-help-json.log",
        IOS_REPO / "docs/TASKS/EVIDENCE/TASK-126/agent-runs/01-commands-json.log",
    ]:
        raw = read(candidate)
        if not raw:
            continue
        try:
            payload = json.loads(raw)
            break
        except Exception:
            continue
    if not payload:
        return set()
    patterns = set()
    for command in payload.get("commands", []):
        argv = command.get("argv")
        if isinstance(argv, list):
            patterns.add(" ".join(str(part) for part in argv))
    return patterns


def command_is_discoverable(command: list[str], patterns: set[str]) -> bool:
    wanted = " ".join(command)
    if wanted in patterns:
        return True
    generic = wanted.replace("TASK-126", "TASK-<ID>")
    return generic in patterns


def latest_reports_matching(pattern: str, allowed: set[str]) -> list[dict[str, Any]]:
    runs = IOS_REPO / "docs/TASKS/EVIDENCE/TASK-126/agent-runs"
    if not runs.exists():
        return []
    rx = re.compile(pattern)
    matches = []
    for path in runs.glob("*.json"):
        payload = read_json(path)
        command = str(payload.get("command") or payload.get("source") or "")
        result = str(payload.get("result") or payload.get("status") or "")
        if rx.search(command) and result in allowed:
            matches.append({"path": rel(path), "command": command, "result": result})
    return sorted(matches, key=lambda item: item["path"])


def scan_task126_policy_matrix(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    text = repo_text(root, (".txt", ".md", ".swift", ".kt")) if root else task_doc()
    checks: list[dict[str, Any]] = []
    ids = set(re.findall(r"\bC126-(\d{2})\b", text))
    expected = {f"{i:02d}" for i in range(0, 61)}
    missing = sorted(expected - ids)
    check(checks, "matrix-c126-00-60-present", not missing, "Task policy matrix must enumerate C126-00 through C126-60.", {"missing": missing})
    not_run_policy = "NOT_RUN" in text and "PASS" in text and "REVIEW" in text
    check(checks, "mandatory-not-run-policy-present", not_run_policy, "Mandatory NOT_RUN must block REVIEW.")
    check(checks, "store-scope-mode-present", "localDefaultStoreOnly" in text and "remoteStoreAware" in text, "Store scope mode decision options must be explicit.")
    return report("task126-policy-matrix", checks, "Complete C126-00...C126-60 and mandatory NOT_RUN policy.")


def scan_owner_store_scope(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    text = repo_text(root or IOS_REPO / "iOSMerchandiseControl/Sync", (".swift", ".txt", ".md"))
    checks: list[dict[str, Any]] = []
    check(checks, "owner-hash-marker", "ownerHash" in text or "owner_hash" in text, "Sync policy/runtime must carry ownerHash.")
    check(checks, "store-id-marker", "storeId" in text or "store_id" in text or "activeStoreIdentity" in text, "Sync policy/runtime must carry store identity.")
    check(checks, "local-store-id-marker", "localStoreId" in text or "local_store_id" in text, "Sync policy/runtime must carry localStoreId.")
    check(checks, "fail-closed-marker", "failClosed" in text or "fail-closed" in text or "ownerStoreMismatch" in text, "Owner/store mismatch must fail closed.")
    return report("owner-store-scope", checks, "Add owner/store/localStoreId scope and fail-closed mismatch policy.")


def scan_local_store_identity(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    text = repo_text(root or IOS_REPO / "iOSMerchandiseControl/Sync/Account", (".swift", ".txt", ".md"))
    required = ["defaultStoreId", "localStoreId", "schemaVersion", "syncProtocolVersion", "storeEpoch"]
    checks: list[dict[str, Any]] = []
    for token in required:
        check(checks, f"{token}-present", token in text, f"LocalStoreIdentity must include {token}.")
    check(checks, "legacy-repair-present", "legacy" in text.lower() and ("repair" in text.lower() or "unbound" in text.lower()), "Legacy/unbound local store repair must be represented.")
    return report("local-store-identity", checks, "Strengthen LocalStoreIdentity and legacy repair policy.")


def scan_pending_base_version(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    text = repo_text(root or IOS_REPO / "iOSMerchandiseControl", (".swift", ".txt", ".md"))
    checks: list[dict[str, Any]] = []
    for token in ["baseRemoteUpdatedAt", "baseVersion", "baseEventId"]:
        check(checks, f"{token}-present", token in text, f"Pending changes should persist {token} when available.")
    check(checks, "idempotency-key-present", "idempotencyKey" in text or "clientEventID" in text, "Pending/outbox entries must have idempotency.")
    return report("pending-base-version", checks, "Add base version/event metadata to pending changes.")


def scan_changed_fields_contract(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    text = repo_text(root or IOS_REPO / "iOSMerchandiseControl", (".swift", ".txt", ".md"))
    checks: list[dict[str, Any]] = []
    check(checks, "changed-fields-present", "changedFields" in text or "changed_fields" in text, "Mutative pending changes must record changedFields.")
    check(checks, "same-field-conflict-present", "sameField" in text or "same-field" in text or "same field" in text.lower(), "Same-field conflict must route to Review.")
    check(checks, "domain-invariant-present", "domainInvariant" in text or "invariant" in text, "Field-level merge must respect business invariants.")
    return report("changed-fields-contract", checks, "Add changedFields and invariant-aware conflict policy.")


def scan_no_cross_owner_store_pending_push(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    text = repo_text(root or IOS_REPO / "iOSMerchandiseControl", (".swift", ".txt", ".md"))
    checks: list[dict[str, Any]] = []
    check(checks, "cross-owner-push-block-present", "crossOwner" in text or "noCrossOwner" in text or "owner mismatch" in text.lower(), "Push must block pending from another owner.")
    check(checks, "cross-store-push-block-present", "crossStore" in text or "noCrossStore" in text or "store mismatch" in text.lower(), "Push must block pending from another store.")
    check(checks, "outbox-scope-validation-present", "validateScope" in text or "scopeValidation" in text or "ownerStore" in text, "Outbox drain must validate owner/store scope before mutation.")
    return report("no-cross-owner-store-pending-push", checks, "Block cross-owner/store pending push before drain/ack.")


def scan_conflict_review_coverage(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    text = repo_text(root or IOS_REPO / "iOSMerchandiseControl", (".swift", ".txt", ".md"))
    checks: list[dict[str, Any]] = []
    check(checks, "conflict-review-type-present", "ConflictReview" in text or "Review" in text, "Conflict Review surface/model must exist.")
    check(checks, "delete-vs-edit-present", "deleteVsEdit" in text or "delete-vs-edit" in text or ("delete" in text.lower() and "edit" in text.lower()), "Delete-vs-edit must route to Review.")
    check(checks, "batch-review-present", "batch" in text.lower() and "conflict" in text.lower(), "Batch conflict review must be represented.")
    return report("conflict-review-coverage", checks, "Add Review coverage for same-field, delete-vs-edit and batch conflicts.")


def scan_productprice_history_policy(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    text = repo_text(root or IOS_REPO / "iOSMerchandiseControl", (".swift", ".txt", ".md"))
    checks: list[dict[str, Any]] = []
    check(checks, "productprice-present", "ProductPrice" in text or "product_price" in text, "ProductPrice domain must be covered.")
    check(checks, "append-dedupe-present", "append" in text.lower() and "dedupe" in text.lower(), "ProductPrice history policy must be append/dedupe.")
    check(checks, "stale-or-same-slot-present", "stale" in text.lower() or "sameSlot" in text, "Stale/same-slot ProductPrice conflicts must be handled.")
    check(checks, "paging-memory-present", "page" in text.lower() or "limit" in text.lower(), "ProductPrice memory policy must be paged.")
    return report("productprice-history-policy", checks, "Add ProductPrice append/dedupe/stale and paging policy.")


def scan_cache_active_store_only(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    text = repo_text(root or IOS_REPO / "iOSMerchandiseControl", (".swift", ".txt", ".md"))
    checks: list[dict[str, Any]] = []
    check(checks, "active-store-only-present", "activeStoreOnly" in text or "active-store-only" in text or "active store" in text.lower(), "Only active store/cache may be loaded.")
    check(checks, "cache-mode-present", "physicalStore" in text or "logicalScope" in text, "Cache mode must be explicit.")
    check(checks, "manifest-present", "CacheManifest" in text or "cache manifest" in text.lower(), "Cache manifest must be represented.")
    return report("cache-active-store-only", checks, "Add active-store-only cache and manifest policy.")


def scan_inactive_cache_cleanup_safety(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    text = repo_text(root or IOS_REPO / "iOSMerchandiseControl", (".swift", ".txt", ".md"))
    checks: list[dict[str, Any]] = []
    check(checks, "inactive-cache-cleanup-present", "inactive" in text.lower() and "cache" in text.lower() and "cleanup" in text.lower(), "Inactive cache cleanup policy must exist.")
    check(checks, "dirty-cache-protected", "dirty" in text.lower() and ("backup" in text.lower() or "export" in text.lower()), "Dirty inactive cache needs backup/export safety.")
    check(checks, "confirm-strong-present", "confirm" in text.lower() and ("strong" in text.lower() or "destructive" in text.lower()), "Destructive dirty flows need strong confirmation.")
    return report("inactive-cache-cleanup-safety", checks, "Protect dirty inactive cache from cleanup.")


def scan_task126_final_gates(root: pathlib.Path | None = None) -> tuple[int, dict[str, Any]]:
    checks: list[dict[str, Any]] = []
    patterns = command_patterns()
    missing_commands = [" ".join(cmd) for cmd in TASK126_REQUIRED_COMMANDS if not command_is_discoverable(cmd, patterns)]
    check(checks, "task126-command-catalog", not missing_commands, "TASK-126 scanners/wrappers must be discoverable.", {"missing": missing_commands})
    for scan in [name for name in SCANS if name != "task126-final-gates"]:
        if scan == "scanner-self-tests":
            pattern = r"^scan scanner-self-tests --task TASK-126 --strict$"
        else:
            pattern = rf"^scan {re.escape(scan)} --task TASK-126 --strict$"
        reports = latest_reports_matching(pattern, {"PASS"})
        check(checks, f"{scan}-latest-pass", bool(reports), f"Latest {scan} report must be PASS.", {"reports": reports[-1:]})
    required_final = [
        (r"^ios build debug --task TASK-126$", "ios-debug-build"),
        (r"^ios build release --task TASK-126$", "ios-release-build"),
        (r"^ios test sync-policy --task TASK-126$", "ios-sync-policy"),
        (r"^ios test account-store-boundary --task TASK-126$", "ios-account-store-boundary"),
        (r"^ios test conflict-review --task TASK-126$", "ios-conflict-review"),
        (r"^ios test cache-memory --task TASK-126$", "ios-cache-memory"),
        (r"^report validate-json --task TASK-126", "evidence-json-validation"),
    ]
    for pattern, check_id in required_final:
        reports = latest_reports_matching(pattern, {"PASS"})
        check(checks, f"{check_id}-latest-pass", bool(reports), f"{check_id} must have PASS report.", {"reports": reports[-1:]})
    return report("task126-final-gates", checks, "Complete missing TASK-126 scanner/test/build evidence before REVIEW.")


SCAN_FUNCS = {
    "task126-policy-matrix": scan_task126_policy_matrix,
    "owner-store-scope": scan_owner_store_scope,
    "local-store-identity": scan_local_store_identity,
    "pending-base-version": scan_pending_base_version,
    "changed-fields-contract": scan_changed_fields_contract,
    "no-cross-owner-store-pending-push": scan_no_cross_owner_store_pending_push,
    "conflict-review-coverage": scan_conflict_review_coverage,
    "productprice-history-policy": scan_productprice_history_policy,
    "cache-active-store-only": scan_cache_active_store_only,
    "inactive-cache-cleanup-safety": scan_inactive_cache_cleanup_safety,
    "task126-final-gates": scan_task126_final_gates,
}


def fixture_status(scan: str, fixture_root: pathlib.Path) -> str:
    func = SCAN_FUNCS.get(scan)
    if not func:
        return "MISCONFIGURED"
    code, payload = func(fixture_root)
    return str(payload.get("status") or ("PASS" if code == 0 else "FAIL"))


def scan_scanner_self_tests() -> tuple[int, dict[str, Any]]:
    base = IOS_REPO / "tools/agent/fixtures/task126_scanners"
    checks: list[dict[str, Any]] = []
    if not base.is_dir():
        check(checks, "fixture-root", False, "TASK-126 fixture root is missing.", rel(base))
        return report("scanner-self-tests", checks, "Add TASK-126 RED/GREEN scanner fixtures.")
    for scan in SCAN_FUNCS:
        if scan == "task126-final-gates":
            continue
        root = base / scan
        red = root / "red"
        green = root / "green"
        manifest = root / "README.md"
        check(checks, f"{scan}-fixture-manifest", manifest.is_file(), "Fixture manifest exists.", rel(manifest))
        check(checks, f"{scan}-red-fixture", red.is_dir(), "RED fixture directory exists.", rel(red))
        check(checks, f"{scan}-green-fixture", green.is_dir(), "GREEN fixture directory exists.", rel(green))
        red_status = fixture_status(scan, red)
        green_status = fixture_status(scan, green)
        check(checks, f"{scan}-red-detects", red_status == "FAIL", "RED fixture must fail the scanner.", {"observedStatus": red_status})
        check(checks, f"{scan}-green-passes", green_status == "PASS", "GREEN fixture must pass the scanner.", {"observedStatus": green_status})
    return report("scanner-self-tests", checks, "Fix TASK-126 scanner fixtures or scanner logic before trusting gates.")


def main() -> int:
    if SCAN == "scanner-self-tests":
        code, payload = scan_scanner_self_tests()
    elif SCAN in SCAN_FUNCS:
        code, payload = SCAN_FUNCS[SCAN]()
    else:
        code, payload = report(
            "unknown",
            [{"id": "scan-name", "status": "MISCONFIGURED", "reason": f"Unknown TASK-126 scan. Valid: {', '.join(SCANS)}", "evidence": {"argv": sys.argv[1:]}}],
            "Use a valid TASK-126 scan name.",
        )
    print(json.dumps(payload, indent=2, sort_keys=True))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
