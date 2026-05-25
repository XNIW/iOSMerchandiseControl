#!/usr/bin/env python3
"""TASK-122 scanner suite.

Read-only gates for the iOS sync Remote domain strangler. These scanners are
deliberately content-based: they inspect files, imports, conformances, method
names, query usage, and report metadata instead of trusting filenames.
"""

from __future__ import annotations

import csv
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Callable, Iterable


TASK_ID = os.environ.get("TASK_ID", os.environ.get("MC_TASK_ID", "TASK-122"))
REPO = Path(os.environ.get("IOS_REPO", os.environ.get("MC_IOS_REPO", os.getcwd()))).resolve()
SCHEMA_VERSION = "1.1"
EVIDENCE_DIR = REPO / f"docs/TASKS/EVIDENCE/{TASK_ID}"
AGENT_RUNS = EVIDENCE_DIR / "agent-runs"

REMOTE_TRANSPORT = "iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift"
REMOTE_ADAPTERS = [
    "iOSMerchandiseControl/Sync/Remote/CatalogRemoteSupabaseAdapter.swift",
    "iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift",
    "iOSMerchandiseControl/Sync/Remote/HistorySessionRemoteSupabaseAdapter.swift",
    "iOSMerchandiseControl/Sync/Remote/SyncEventRemoteSupabaseAdapter.swift",
]
DOMAIN_PROTOCOLS = {
    "OptionsSyncRemoteCountFetching",
    "SupabaseInventoryFetching",
    "SupabaseProductPriceKeysetFetching",
    "SupabaseProductPriceDeletedProductFetching",
    "SupabaseProductPriceManualPushRemoteAccessing",
    "SupabaseProductPricePushDryRunRemoteFetching",
    "SyncAutomaticIncrementalRemote",
    "SyncAutomaticCatalogRemoteWriting",
    "SyncAutomaticProductPriceRemoteWriting",
    "HistorySessionRemoteWriting",
}
CANONICAL_STATUSES = {
    "PASS",
    "FAIL",
    "BLOCKED_EXTERNAL",
    "MISCONFIGURED",
    "UNSAFE_OPERATION_REFUSED",
    "NOT_RUN",
    "PASS_WITH_NOTES",
}
def local_canonical_override_enabled() -> bool:
    return os.environ.get("LOCAL_CANONICAL_EXECUTION_OVERRIDE") == "1" or "LOCAL_CANONICAL_EXECUTION_OVERRIDE" in read("docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md")


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def path(rel_path: str) -> Path:
    return REPO / rel_path


def rel(candidate: Path) -> str:
    try:
        return candidate.resolve().relative_to(REPO).as_posix()
    except ValueError:
        return candidate.as_posix()


def read(rel_path: str) -> str:
    try:
        return path(rel_path).read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def sha256_file(candidate: Path) -> str | None:
    if not candidate.exists() or not candidate.is_file():
        return None
    return hashlib.sha256(candidate.read_bytes()).hexdigest()


def run_cmd(args: list[str], cwd: Path | None = None, timeout: int = 90) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd or REPO),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        return proc.returncode, proc.stdout
    except Exception as exc:
        return 99, str(exc)


def swift_files(*roots: str) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        base = path(root)
        if base.is_file() and base.suffix == ".swift":
            files.append(base)
        elif base.is_dir():
            files.extend(sorted(base.rglob("*.swift")))
    return sorted(set(files))


def all_repo_text_files() -> Iterable[Path]:
    excluded = {".git", "DerivedData", "node_modules", "agent-runs", ".build", "build"}
    for candidate in REPO.rglob("*"):
        if not candidate.is_file() or any(part in excluded for part in candidate.parts):
            continue
        if candidate.suffix.lower() in {".swift", ".md", ".py", ".sh", ".mjs", ".json", ".pbxproj"}:
            yield candidate


def line_hits(rel_path: str, pattern: str, flags: int = 0) -> list[dict[str, object]]:
    text = read(rel_path)
    rx = re.compile(pattern, flags)
    hits: list[dict[str, object]] = []
    for idx, line in enumerate(text.splitlines(), start=1):
        if rx.search(line):
            hits.append({"line": idx, "snippet": line.strip()[:240]})
    return hits


def check(
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
    if file is not None:
        item["file"] = file
    if evidence is not None:
        item["evidence"] = evidence
    if fix_hint is not None:
        item["fix_hint"] = fix_hint
    checks.append(item)


def status_from_checks(checks: list[dict[str, object]]) -> str:
    statuses = [str(item.get("status", "MISCONFIGURED")) for item in checks]
    if "MISCONFIGURED" in statuses:
        return "MISCONFIGURED"
    if "UNSAFE_OPERATION_REFUSED" in statuses:
        return "UNSAFE_OPERATION_REFUSED"
    if "FAIL" in statuses:
        return "FAIL"
    if "BLOCKED_EXTERNAL" in statuses:
        return "BLOCKED_EXTERNAL"
    if "PASS_WITH_NOTES" in statuses:
        return "PASS_WITH_NOTES"
    if statuses and all(value == "PASS" for value in statuses):
        return "PASS"
    return "MISCONFIGURED"


def git_head(ref: str) -> str | None:
    code, out = run_cmd(["git", "rev-parse", ref])
    return out.strip() if code == 0 else None


def report(scan: str, checks: list[dict[str, object]], next_action: str) -> dict[str, object]:
    local_head = git_head("HEAD")
    origin_head = git_head("origin/main")
    github_code, github_out = run_cmd(["git", "ls-remote", "origin", "refs/heads/main"])
    github_head = github_out.split()[0] if github_code == 0 and github_out.split() else None
    status = status_from_checks(checks)
    started = now()
    return {
        "schema_version": SCHEMA_VERSION,
        "schemaVersion": SCHEMA_VERSION,
        "task_id": TASK_ID,
        "taskId": TASK_ID,
        "source": f"scan.{scan}",
        "scannerName": scan,
        "scan": scan,
        "status": status,
        "result_status": status,
        "exitCode": exit_code_for_status(status),
        "summary": f"{scan}: {status} ({len(checks)} checks)",
        "started_at": started,
        "startedAt": started,
        "completed_at": started,
        "finishedAt": started,
        "safety_level": "read_only_static_scan",
        "repository": str(REPO),
        "canonicalHead": github_head,
        "localHead": local_head,
        "originHead": origin_head,
        "githubHead": github_head,
        "localCanonicalOverride": local_canonical_override_enabled(),
        "checks": checks,
        "redactionSummary": {
            "paths_redacted_by_wrapper": True,
            "emails_redacted_by_wrapper": True,
            "scanner_outputs_do_not_include_secret_values": True,
        },
        "NEXT_ACTION": next_action,
        "nextAction": next_action,
    }


def exit_code_for_status(status: str) -> int:
    return {
        "PASS": 0,
        "PASS_WITH_NOTES": 0,
        "FAIL": 1,
        "BLOCKED_EXTERNAL": 2,
        "MISCONFIGURED": 3,
        "UNSAFE_OPERATION_REFUSED": 4,
        "NOT_RUN": 1,
    }.get(status, 3)


def exit_code(payload: dict[str, object]) -> int:
    return exit_code_for_status(str(payload.get("status", "MISCONFIGURED")))


def load_help_json() -> tuple[dict[str, object] | None, str]:
    code, out = run_cmd(["bash", str(path("tools/agent/mc-agent.sh")), "help-json"])
    if code != 0:
        return None, out
    try:
        return json.loads(out), out
    except json.JSONDecodeError as exc:
        return None, f"invalid json: {exc}\n{out[:500]}"


def command_patterns_from_help() -> set[tuple[str, ...]]:
    payload, _ = load_help_json()
    if not payload:
        return set()
    patterns: set[tuple[str, ...]] = set()
    for command in payload.get("commands", []):
        argv = command.get("argv", [])
        if isinstance(argv, list):
            patterns.add(tuple(str(item) for item in argv))
    return patterns


def command_is_discoverable(command: list[str], patterns: set[tuple[str, ...]]) -> bool:
    wanted = tuple(command)
    if wanted in patterns:
        return True
    for pattern in patterns:
        if len(pattern) != len(wanted):
            continue
        ok = True
        for expected, actual in zip(pattern, wanted):
            if expected.startswith("<") and expected.endswith(">"):
                continue
            if expected != actual:
                ok = False
                break
        if ok:
            return True
    return False


TASK122_SCANS = [
    "task-docs",
    "master-plan-consistency",
    "evidence-metadata",
    "harness-routing",
    "harness-health",
    "mcp-wrapper",
    "status-taxonomy",
    "scanner-self-tests",
    "source-format",
    "swift-source-shape",
    "sync-inventory",
    "sync-architecture",
    "remote-transport-thin",
    "adapter-delegation-depth",
    "domain-method-ownership",
    "manual-debug-boundary",
    "transport-protocol-conformance",
    "composition-import-boundary",
    "remote-query-ownership",
    "debug-seed-boundary",
    "dto-mapper-duplication",
    "supabase-query-map",
    "transport-callsite-map",
    "protocol-conformance-map",
    "supabase-contract-map",
    "android-parity-ledger",
    "performance-baseline",
    "offline-outbox-conflict",
    "xcode-membership",
    "dead-code",
    "sensitive",
    "evidence",
    "sync-efficiency-acceptance",
]


def task122_matrix_commands() -> list[list[str]]:
    commands = [
        ["git", "head-consistency", "--task", "TASK-122"],
        ["preflight", "--require-head-consistency", "--task", "TASK-122"],
        ["config", "validate", "--task", "TASK-122"],
        ["help-json"],
        ["list", "commands-json"],
    ]
    commands.extend([["scan", scan, "--task", "TASK-122", "--strict"] for scan in TASK122_SCANS])
    commands.extend([
        ["scan", "supabase-query-map", "--task", "TASK-122", "--strict", "--read-only"],
        ["scan", "supabase-contract-map", "--task", "TASK-122", "--strict", "--read-only"],
        ["report", "validate-json", "--task", "TASK-122", "--path", "docs/TASKS/EVIDENCE/TASK-122/agent-runs"],
        ["ios", "build", "debug", "--task", "TASK-122"],
        ["ios", "build", "release", "--task", "TASK-122"],
    ])
    return commands


def scan_task_docs() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    task_rel = "docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md"
    evidence_rel = "docs/TASKS/EVIDENCE/TASK-122/README.md"
    master = read("docs/MASTER-PLAN.md")
    task = read(task_rel)
    check(checks, "task_file_exists", "PASS" if path(task_rel).exists() else "FAIL", "TASK-122 file exists.", file=task_rel)
    check(checks, "evidence_readme_exists", "PASS" if path(evidence_rel).exists() else "FAIL", "TASK-122 evidence README exists.", file=evidence_rel)
    if local_canonical_override_enabled():
        task_state_ok = "Fase attuale**: EXECUTION" in task and "Stato**: ACTIVE" in task
        task_state_reason = "TASK-122 is ACTIVE / EXECUTION under LOCAL_CANONICAL_EXECUTION_OVERRIDE."
    else:
        task_state_ok = "Fase attuale**: PLANNING" in task and "Stato**: ACTIVE" in task
        task_state_reason = "TASK-122 remains ACTIVE / PLANNING."
    check(checks, "task_active_state", "PASS" if task_state_ok else "FAIL", task_state_reason, file=task_rel)
    check(checks, "local_canonical_override_recorded", "PASS" if "LOCAL_CANONICAL_EXECUTION_OVERRIDE" in task else "FAIL", "Local canonical override is documented when used.", file=task_rel)
    check(checks, "master_points_task122", "PASS" if "TASK-122" in master and task_rel in master else "FAIL", "MASTER-PLAN references TASK-122 current task.", file="docs/MASTER-PLAN.md")
    check(checks, "task121_not_done_superseded", "PASS" if "SUPERSEDED_BY_TASK-122_REMOTE_MEGA_SERVICE_BLOCKER" in master and "TASK-121 resta non DONE" in master else "FAIL", "TASK-121 remains non-DONE and superseded only for remote blocker.", file="docs/MASTER-PLAN.md")
    return report("task-docs", checks, "Fix TASK-122 tracking docs before execution.")


def scan_master_plan_consistency() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    master = read("docs/MASTER-PLAN.md")
    workflow = master.split("## Workflow task attivo", 1)[1] if "## Workflow task attivo" in master else ""
    if local_canonical_override_enabled():
        workflow_ok = "TASK-122" in master and "ACTIVE / EXECUTION" in master and "LOCAL_CANONICAL_EXECUTION_OVERRIDE" in master
        workflow_reason = "Workflow task is TASK-122 ACTIVE / EXECUTION under local canonical override."
    else:
        workflow_ok = "Task attivo:** **TASK-122" in workflow and "Stato TASK-122:** **ACTIVE / PLANNING" in workflow
        workflow_reason = "Workflow task is TASK-122 ACTIVE / PLANNING."
    check(checks, "workflow_task122", "PASS" if workflow_ok else "FAIL", workflow_reason, file="docs/MASTER-PLAN.md")
    task122_current_mentions = len(re.findall(r"task corrente \*\*`TASK-122`|Task attivo:\*\* \*\*TASK-122|ACTIVE — TASK-122 (?:PLANNING|EXECUTION)|TASK-122 EXECUTION", master))
    stale_current_121 = bool(re.search(r"task corrente \*\*`TASK-121`|Task attivo:\*\* \*\*TASK-121|ACTIVE — TASK-121 FIX", master))
    check(checks, "no_stale_task121_current", "PASS" if not stale_current_121 else "FAIL", "MASTER-PLAN has no TASK-121 operative-current wording.", file="docs/MASTER-PLAN.md")
    check(checks, "task122_current_present", "PASS" if task122_current_mentions >= 1 else "FAIL", "MASTER-PLAN has TASK-122 current wording.", file="docs/MASTER-PLAN.md", evidence={"matches": task122_current_mentions})
    return report("master-plan-consistency", checks, "Keep exactly one operative current task: TASK-122.")


def scan_harness_routing() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    payload, raw = load_help_json()
    patterns = command_patterns_from_help()
    missing = [" ".join(cmd) for cmd in task122_matrix_commands() if not command_is_discoverable(cmd, patterns)]
    agent = read("tools/agent/mc-agent.sh")
    common = read("tools/agent/lib/common.sh")
    check(checks, "help_json_parseable", "PASS" if payload else "MISCONFIGURED", "help-json parses.", evidence=raw[:600] if payload is None else {"command_count": len(payload.get("commands", []))})
    check(checks, "task122_commands_discoverable", "PASS" if not missing else "FAIL", "Every TASK-122 command is discoverable.", evidence={"missing": missing[:80], "missing_count": len(missing)})
    routed = "mc_cmd_scan_task122_static" in agent and "task122_scans.py" in common and "mc_cmd_scan_task122_static" in common
    check(checks, "task122_scanner_module_routed", "PASS" if routed else "FAIL", "mc-agent routes TASK-122 scanners to task122_scans.py.")
    return report("harness-routing", checks, "Add TASK-122 CLI routing and discovery before trusting scanners.")


def scan_harness_health() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    for rel_path in ["tools/agent/mc-agent.sh", "tools/agent/lib/common.sh", "tools/agent/lib/task122_scans.py", "tools/agent/mcp/server.mjs"]:
        check(checks, f"exists:{rel_path}", "PASS" if path(rel_path).exists() else "FAIL", "Harness file exists.", file=rel_path)
    code, out = run_cmd(["bash", "-n", str(path("tools/agent/mc-agent.sh"))])
    check(checks, "mc_agent_shell_syntax", "PASS" if code == 0 else "FAIL", "mc-agent.sh shell syntax is valid.", evidence=out[-500:])
    code, out = run_cmd(["python3", "-m", "py_compile", str(path("tools/agent/lib/task122_scans.py"))])
    check(checks, "task122_python_syntax", "PASS" if code == 0 else "FAIL", "task122_scans.py compiles.", evidence=out[-500:])
    return report("harness-health", checks, "Fix harness syntax/module health before execution.")


def scan_mcp_wrapper() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    server = read("tools/agent/mcp/server.mjs")
    required = [
        "mc_task122_scan_task_docs",
        "mc_task122_scan_remote_transport_thin",
        "mc_task122_scan_adapter_delegation_depth",
        "mc_task122_scan_sync_efficiency_acceptance",
        "mc_task122_report_validate_json",
    ]
    missing = [name for name in required if name not in server]
    check(checks, "mcp_task122_allowlist_present", "PASS" if not missing else "FAIL", "MCP allowlists safe TASK-122 commands.", file="tools/agent/mcp/server.mjs", evidence={"missing": missing})
    check(checks, "mcp_no_auto_live_cleanup", "PASS" if "MC_ALLOW_LIVE" in server and "process.env.MC_ALLOW_LIVE = " not in server else "FAIL", "MCP does not auto-enable live/cleanup gates.", file="tools/agent/mcp/server.mjs")
    return report("mcp-wrapper", checks, "Update MCP allowlist for TASK-122 safe commands.")


def scan_status_taxonomy() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    payload, raw = load_help_json()
    exit_codes = set((payload or {}).get("exit_codes", {}).values()) if payload else set()
    check(checks, "help_json_status_taxonomy", "PASS" if CANONICAL_STATUSES - {"NOT_RUN", "PASS_WITH_NOTES"} <= exit_codes else "FAIL", "help-json exposes canonical exit code statuses.", evidence={"exit_codes": sorted(exit_codes), "raw": raw[:300] if not payload else None})
    task = read("docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md")
    check(checks, "task_claim_guard", "PASS" if "NOT_RUN" in task and "PASS_WITH_NOTES" in task and "100% efficiente" in task else "FAIL", "TASK-122 documents status and claim guard.", file="docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md")
    return report("status-taxonomy", checks, "Keep status taxonomy and claim guard explicit.")


def scan_evidence_metadata() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    check(checks, "agent_runs_exists", "PASS" if AGENT_RUNS.exists() else "FAIL", "TASK-122 agent-runs directory exists.", file=rel(AGENT_RUNS))
    required_discovery = [AGENT_RUNS / "00-help-json.json", AGENT_RUNS / "00-commands-json.json"]
    for candidate in required_discovery:
        check(checks, f"discovery:{candidate.name}", "PASS" if candidate.exists() else "FAIL", "Discovery JSON exists.", file=rel(candidate))
    bad_reports = []
    for candidate in sorted(AGENT_RUNS.glob("*.json")):
        if candidate.name in {"00-help-json.json", "00-commands-json.json"}:
            continue
        try:
            payload = json.loads(candidate.read_text(encoding="utf-8"))
        except Exception as exc:
            bad_reports.append({"file": rel(candidate), "error": str(exc)})
            continue
        missing = [key for key in ["task_id", "status", "exit_code", "artifact_paths", "redaction_summary", "NEXT_ACTION"] if key not in payload]
        if payload.get("task_id") != TASK_ID or missing:
            bad_reports.append({"file": rel(candidate), "task_id": payload.get("task_id"), "missing": missing})
    check(checks, "task122_reports_metadata", "PASS" if not bad_reports else "FAIL", "TASK-122 JSON reports have task/status/artifacts/redaction/NEXT_ACTION.", evidence=bad_reports[:60])
    return report("evidence-metadata", checks, "Regenerate non-compliant TASK-122 reports with mc-agent.")


def critical_text_files_for_format() -> Iterable[Path]:
    roots = [
        path("iOSMerchandiseControl/Sync"),
        path("tools/agent"),
        path("iOSMerchandiseControl"),
    ]
    root_patterns = ("Supabase", "Sync", "Outbox")
    seen: set[Path] = set()
    for root in roots:
        if root.is_dir():
            for candidate in root.rglob("*"):
                if candidate.is_file() and candidate.suffix in {".swift", ".sh", ".py", ".mjs"}:
                    if (
                        "agent-runs" not in candidate.parts
                        and "fixtures" not in candidate.parts
                        and "node_modules" not in candidate.parts
                        and candidate not in seen
                    ):
                        seen.add(candidate)
                        yield candidate
        elif root.is_file():
            yield root
    for candidate in path("iOSMerchandiseControl").glob("*.swift"):
        if candidate.name.startswith(root_patterns) or "Sync" in candidate.name or "Outbox" in candidate.name:
            if candidate not in seen:
                yield candidate


def scan_source_format() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    offenders = []
    for candidate in critical_text_files_for_format():
        lines = candidate.read_text(encoding="utf-8", errors="replace").splitlines()
        if not lines:
            continue
        long_1000 = [idx for idx, line in enumerate(lines, 1) if len(line) > 1000]
        long_300 = sum(1 for line in lines if len(line) > 300)
        if long_1000 or long_300 / max(len(lines), 1) > 0.05:
            offenders.append({"file": rel(candidate), "line_count": len(lines), "long_1000": long_1000[:10], "pct_long_300": round(long_300 / max(len(lines), 1), 3)})
    check(checks, "critical_sources_not_minified", "PASS" if not offenders else "FAIL", "Critical Swift/harness files are reviewable, not flattened/minified.", evidence=offenders[:80])
    return report("source-format", checks, "Reformat source before semantic refactor if this fails.")


def scan_swift_source_shape() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    flattened = []
    for candidate in swift_files("iOSMerchandiseControl/Sync", REMOTE_TRANSPORT, *REMOTE_ADAPTERS):
        text = candidate.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        declarations = len(re.findall(r"\b(?:class|struct|enum|actor|protocol|func)\s+\w+", text))
        if len(lines) <= 5 and declarations > 5:
            flattened.append({"file": rel(candidate), "line_count": len(lines), "declarations": declarations})
    check(checks, "swift_not_flattened", "PASS" if not flattened else "FAIL", "Swift source shape is scanner/review friendly.", evidence=flattened)
    return report("swift-source-shape", checks, "Restore readable Swift source shape before architecture scans.")


def sync_category(rel_path: str) -> str:
    if "/Sync/Automatic/" in rel_path:
        return "Automatic"
    if "/Sync/Manual/" in rel_path:
        return "Manual"
    if "/Sync/Recovery/" in rel_path:
        return "Recovery"
    if "/Sync/Remote/" in rel_path:
        return "Remote"
    if "/Sync/Shared/" in rel_path:
        return "Shared"
    if "/Sync/Account/" in rel_path:
        return "Shared"
    if "/Sync/Outbox/" in rel_path:
        return "Automatic"
    if rel_path.endswith("/SyncOrchestrator.swift") or rel_path.endswith("/SyncAutomaticRuntime.swift"):
        return "Automatic"
    if rel_path.endswith("/SyncAutomaticRuntimeProviders.swift"):
        return "Automatic"
    if rel_path.endswith("/SyncRecoveryPolicy.swift"):
        return "Recovery"
    if rel_path.endswith("/AutomaticPushServices.swift"):
        return "Automatic"
    if "/Sync/" in rel_path and "Composition" in rel_path:
        return "Composition"
    if "Tests/" in rel_path or rel_path.startswith("iOSMerchandiseControlTests/"):
        return "Tests"
    return "Uncategorized"


def write_evidence_file(name: str, text: str) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    (EVIDENCE_DIR / name).write_text(text, encoding="utf-8")


def scan_sync_inventory() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    rows = []
    for candidate in swift_files("iOSMerchandiseControl/Sync", "iOSMerchandiseControlTests"):
        rel_path = rel(candidate)
        rows.append({"file": rel_path, "category": sync_category(rel_path), "loc": len(candidate.read_text(encoding="utf-8", errors="replace").splitlines())})
    uncategorized = [row for row in rows if row["category"] == "Uncategorized"]
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    write_evidence_file("sync-inventory.json", json.dumps({"taskId": TASK_ID, "files": rows}, indent=2, sort_keys=True))
    with (EVIDENCE_DIR / "sync-inventory.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["file", "category", "loc"])
        writer.writeheader()
        writer.writerows(rows)
    write_evidence_file("sync-inventory.md", "\n".join(["# TASK-122 Sync Inventory", "", *[f"- `{row['category']}` `{row['file']}` ({row['loc']} LOC)" for row in rows]]) + "\n")
    check(checks, "sync_inventory_written", "PASS", "Sync inventory Markdown/JSON/CSV written.", evidence={"file_count": len(rows)})
    check(checks, "no_uncategorized_sync_files", "PASS" if not uncategorized else "FAIL", "No Sync file remains Uncategorized.", evidence=uncategorized[:80])
    return report("sync-inventory", checks, "Classify every Sync file before refactor.")


def transport_text() -> str:
    return read(REMOTE_TRANSPORT)


def transport_methods() -> list[dict[str, object]]:
    methods = []
    for match in re.finditer(r"^\s*(?:private\s+|nonisolated\s+|static\s+|public\s+|internal\s+)*func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", transport_text(), re.M):
        name = match.group(1)
        line = transport_text()[:match.start()].count("\n") + 1
        methods.append({"name": name, "line": line, "category": method_category(name)})
    return methods


def method_category(name: str) -> str:
    lower = name.lower()
    if "client" in lower or "authenticateduserid" in lower or "map" in lower or "networkerror" in lower:
        return "transport"
    if any(token in lower for token in ["supplier", "categor", "product", "catalog"]):
        if "productprice" not in lower and "product_price" not in lower and "price" not in lower:
            return "catalog"
    if "price" in lower:
        return "product-price"
    if "session" in lower or "history" in lower or "sheet" in lower:
        return "history-session"
    if "syncevent" in lower or "sync_events" in lower or "outbox" in lower or "reconciliation" in lower:
        return "sync-event"
    if "task0" in lower or "debug" in lower or "dryrun" in lower or "dry" in lower:
        return "manual-debug-dry-run"
    if "session" in lower and "authenticated" in lower:
        return "transport"
    return "unknown"


def scan_remote_transport_thin() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    text = transport_text()
    loc = len(text.splitlines())
    domain_methods = [item for item in transport_methods() if item["category"] not in {"transport", "unknown"}]
    check(checks, "transport_exists", "PASS" if path(REMOTE_TRANSPORT).exists() else "FAIL", "SupabaseTransportClient exists.", file=REMOTE_TRANSPORT)
    check(checks, "transport_loc_under_hard_limit", "PASS" if loc <= 500 else "FAIL", "Transport hard limit is 500 LOC.", file=REMOTE_TRANSPORT, evidence={"loc": loc})
    check(checks, "transport_loc_prefer_under_300", "PASS" if loc < 300 else "PASS_WITH_NOTES", "Preferred transport size is <300 LOC.", file=REMOTE_TRANSPORT, evidence={"loc": loc})
    check(checks, "transport_no_domain_methods", "PASS" if not domain_methods else "FAIL", "Transport has no domain-specific methods.", file=REMOTE_TRANSPORT, evidence=domain_methods[:80])
    return report("remote-transport-thin", checks, "Move domain behavior out of SupabaseTransportClient.")


def scan_transport_protocol_conformance() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    text = transport_text()
    hits = []
    for proto in sorted(DOMAIN_PROTOCOLS):
        if re.search(rf"extension\s+SupabaseTransportClient\s*:\s*{re.escape(proto)}\b|actor\s+SupabaseTransportClient\s*:\s*[^\n{{]*\b{re.escape(proto)}\b", text):
            hits.append(proto)
    check(checks, "transport_no_domain_conformance", "PASS" if not hits else "FAIL", "Transport does not conform to domain protocols.", file=REMOTE_TRANSPORT, evidence={"conformances": hits})
    write_evidence_file("transport-protocol-conformance.json", json.dumps({"taskId": TASK_ID, "conformances": hits}, indent=2, sort_keys=True))
    write_evidence_file("transport-protocol-conformance.md", "# Transport Protocol Conformance\n\n" + ("\n".join(f"- FAIL `{item}`" for item in hits) if hits else "- PASS no domain conformances\n"))
    return report("transport-protocol-conformance", checks, "Move domain protocol conformance to adapters/services.")


def scan_protocol_conformance_map() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    rows = []
    rx = re.compile(r"(?:struct|class|actor|extension)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^{\n]+)")
    for candidate in swift_files("iOSMerchandiseControl/Sync"):
        text = candidate.read_text(encoding="utf-8", errors="replace")
        for match in rx.finditer(text):
            protocols = [item.strip() for item in match.group(2).split(",")]
            rows.append({"file": rel(candidate), "type": match.group(1), "protocols": protocols})
    write_evidence_file("protocol-conformance-map.json", json.dumps({"taskId": TASK_ID, "conformances": rows}, indent=2, sort_keys=True))
    write_evidence_file("protocol-conformance-map.md", "# Protocol Conformance Map\n\n" + "\n".join(f"- `{row['file']}` `{row['type']}`: {', '.join(row['protocols'])}" for row in rows) + "\n")
    check(checks, "protocol_map_written", "PASS", "Protocol conformance map written.", evidence={"count": len(rows)})
    return report("protocol-conformance-map", checks, "Use protocol map to validate ownership boundaries.")


def scan_transport_callsite_map() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    hits = []
    for candidate in all_repo_text_files():
        if rel(candidate) == REMOTE_TRANSPORT:
            continue
        text = candidate.read_text(encoding="utf-8", errors="replace")
        for idx, line in enumerate(text.splitlines(), 1):
            if "SupabaseTransportClient" in line:
                hits.append({"file": rel(candidate), "line": idx, "snippet": line.strip()[:220]})
    write_evidence_file("transport-callsite-map.json", json.dumps({"taskId": TASK_ID, "callsites": hits}, indent=2, sort_keys=True))
    write_evidence_file("transport-callsite-map.md", "# SupabaseTransportClient Call-Site Map\n\n" + "\n".join(f"- `{hit['file']}:{hit['line']}` {hit['snippet']}" for hit in hits) + "\n")
    check(checks, "callsite_map_written", "PASS", "Transport call-site map written.", evidence={"count": len(hits)})
    return report("transport-callsite-map", checks, "Use call-site map before changing transport API.")


def scan_domain_method_ownership() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    methods = transport_methods()
    domain_methods = [item for item in methods if item["category"] in {"catalog", "product-price", "history-session", "sync-event", "manual-debug-dry-run"}]
    write_evidence_file("method-responsibility-map.json", json.dumps({"taskId": TASK_ID, "methods": methods}, indent=2, sort_keys=True))
    write_evidence_file("method-responsibility-map.md", "# Transport Method Responsibility Map\n\n" + "\n".join(f"- `{item['name']}` line {item['line']}: {item['category']}" for item in methods) + "\n")
    check(checks, "transport_domain_methods_removed", "PASS" if not domain_methods else "FAIL", "Transport owns no domain methods.", evidence=domain_methods[:120], file=REMOTE_TRANSPORT)
    return report("domain-method-ownership", checks, "Move listed domain methods to the correct adapter/service.")


def adapter_pass_throughs() -> list[dict[str, object]]:
    hits = []
    for rel_path in REMOTE_ADAPTERS:
        text = read(rel_path)
        function_count = len(re.findall(r"\bfunc\s+\w+\s*\(", text))
        remote_calls = len(re.findall(r"try\s+await\s+remote\.\w+\s*\(", text))
        query_hits = len(re.findall(r"\.from\s*\(|\.rpc\s*\(|\.select\s*\(|\.insert\s*\(|\.upsert\s*\(|\.update\s*\(|\.delete\s*\(", text))
        if function_count and remote_calls >= function_count and query_hits == 0:
            hits.append({"file": rel_path, "function_count": function_count, "remote_calls": remote_calls, "query_hits": query_hits})
    return hits


def scan_adapter_delegation_depth() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    pass_through = adapter_pass_throughs()
    check(checks, "adapters_not_pure_passthrough", "PASS" if not pass_through else "FAIL", "Remote adapters own behavior instead of pure delegation.", evidence=pass_through)
    return report("adapter-delegation-depth", checks, "Move query/mapping/domain behavior into adapters.")


def scan_remote_query_ownership() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    adapter_queries = []
    for rel_path in REMOTE_ADAPTERS:
        text = read(rel_path)
        hits = re.findall(r"\.from\s*\(\s*\"([^\"]+)\"|\.rpc\s*\(\s*\"([^\"]+)\"|table:\s*\"([^\"]+)\"", text)
        adapter_queries.append({"file": rel_path, "query_count": len(hits), "queries": [a or b or c for a, b, c in hits]})
    missing = [item for item in adapter_queries if item["query_count"] == 0]
    write_evidence_file("remote-query-ownership.json", json.dumps({"taskId": TASK_ID, "adapters": adapter_queries}, indent=2, sort_keys=True))
    write_evidence_file("remote-query-ownership.md", "# Remote Query Ownership\n\n" + "\n".join(f"- `{item['file']}` queries={item['query_count']}" for item in adapter_queries) + "\n")
    check(checks, "adapters_own_queries", "PASS" if not missing else "FAIL", "Each Remote adapter owns query/RPC behavior.", evidence=missing)
    return report("remote-query-ownership", checks, "Move Supabase queries out of the transport.")


def scan_composition_import_boundary() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    allowed_fragments = ["/Sync/Remote/", "/Sync/Automatic/Composition/"]
    violations = []
    for candidate in swift_files("iOSMerchandiseControl/Sync"):
        rel_path = rel(candidate)
        if any(fragment in f"/{rel_path}" for fragment in allowed_fragments) or rel_path.endswith("RecoveryRemoteSupabaseAdapter.swift"):
            continue
        text = candidate.read_text(encoding="utf-8", errors="replace")
        if re.search(r"\bSupabaseTransportClient\b(?!Error)", text):
            violations.append({"file": rel_path})
    check(checks, "concrete_transport_only_remote_or_composition", "PASS" if not violations else "FAIL", "Concrete SupabaseTransportClient is only used in Remote/Composition.", evidence=violations)
    write_evidence_file("composition-import-boundary.json", json.dumps({"taskId": TASK_ID, "violations": violations}, indent=2, sort_keys=True))
    write_evidence_file("composition-import-boundary.md", "# Composition Import Boundary\n\n" + ("\n".join(f"- FAIL `{item['file']}`" for item in violations) if violations else "- PASS\n"))
    return report("composition-import-boundary", checks, "Route concrete transport through Composition/adapter construction only.")


def scan_manual_debug_boundary() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    auto_hits = []
    for candidate in swift_files("iOSMerchandiseControl/Sync/Automatic"):
        text = candidate.read_text(encoding="utf-8", errors="replace")
        filtered = re.sub(r"\b[A-Za-z0-9_]*DebugSummary\b", "", text)
        filtered = filtered.replace("hiddenDebugEntries", "hiddenEntries")
        if re.search(r"ManualSync|ManualPush|DryRun|Debug|TASK0", filtered):
            auto_hits.append({"file": rel(candidate)})
    check(checks, "automatic_no_manual_debug", "PASS" if not auto_hits else "FAIL", "Automatic does not import manual/debug/dry-run behavior.", evidence=auto_hits)
    return report("manual-debug-boundary", checks, "Keep manual/debug/dry-run outside Automatic.")


def scan_debug_seed_boundary() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    hits = line_hits(REMOTE_TRANSPORT, r"TASK0[0-9]+|ensureTask|Collision|Seed|Debug", re.I)
    write_evidence_file("debug-seed-boundary.json", json.dumps({"taskId": TASK_ID, "hits": hits}, indent=2, sort_keys=True))
    write_evidence_file("debug-seed-boundary.md", "# Debug Seed Boundary\n\n" + ("\n".join(f"- line {hit['line']}: {hit['snippet']}" for hit in hits) if hits else "- PASS\n"))
    check(checks, "transport_no_debug_seed", "PASS" if not hits else "FAIL", "Transport contains no DEBUG/TASK seed/collision/probe behavior.", file=REMOTE_TRANSPORT, evidence=hits[:80])
    return report("debug-seed-boundary", checks, "Move debug/test seed behavior out of thin transport.")


def scan_dto_mapper_duplication() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    declarations: dict[str, list[str]] = {}
    for candidate in swift_files("iOSMerchandiseControl/Sync"):
        text = candidate.read_text(encoding="utf-8", errors="replace")
        for match in re.finditer(r"^\s*(?:struct|enum|class)\s+([A-Za-z_][A-Za-z0-9_]*(?:DTO|Row|Mapper|Payload|Request))\b", text, re.M):
            declarations.setdefault(match.group(1), []).append(rel(candidate))
    dupes = {name: paths for name, paths in declarations.items() if len(set(paths)) > 1}
    write_evidence_file("dto-mapper-duplication.json", json.dumps({"taskId": TASK_ID, "duplicates": dupes}, indent=2, sort_keys=True))
    write_evidence_file("dto-mapper-duplication.md", "# DTO/Mapper Duplication\n\n" + ("\n".join(f"- `{name}`: {paths}" for name, paths in dupes.items()) if dupes else "- PASS\n"))
    check(checks, "dto_mapper_no_duplicate_declarations", "PASS" if not dupes else "FAIL", "DTO/query mapper declarations are not duplicated across domains.", evidence=dict(list(dupes.items())[:40]))
    return report("dto-mapper-duplication", checks, "Remove or document DTO/mapper duplication.")


def query_usage_map() -> list[dict[str, object]]:
    rows = []
    rx = re.compile(r"\.(from|rpc)\s*\(\s*\"([^\"]+)\"|(\.insert|\.upsert|\.update|\.delete)\s*\(")
    for candidate in swift_files("iOSMerchandiseControl/Sync"):
        text = candidate.read_text(encoding="utf-8", errors="replace")
        for idx, line in enumerate(text.splitlines(), 1):
            if rx.search(line):
                rows.append({"file": rel(candidate), "line": idx, "snippet": line.strip()[:220]})
    return rows


def scan_supabase_query_map() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    rows = query_usage_map()
    write_evidence_file("supabase-query-map.md", "# Supabase Query Map\n\n" + "\n".join(f"- `{row['file']}:{row['line']}` {row['snippet']}" for row in rows) + "\n")
    write_evidence_file("supabase-query-map.json", json.dumps({"taskId": TASK_ID, "queries": rows}, indent=2, sort_keys=True))
    check(checks, "supabase_query_map_written", "PASS" if rows else "PASS_WITH_NOTES", "Supabase query usage map written.", evidence={"count": len(rows)})
    return report("supabase-query-map", checks, "Use read-only query map before changing schema-facing code.")


def scan_supabase_contract_map() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    rows = query_usage_map()
    write_evidence_file("supabase-contract-map-readonly.md", "# Supabase Contract Map Read-Only\n\n" + "\n".join(f"- `{row['file']}:{row['line']}` {row['snippet']}" for row in rows) + "\n")
    write_evidence_file("supabase-contract-map-readonly.json", json.dumps({"taskId": TASK_ID, "readonly": True, "queries": rows}, indent=2, sort_keys=True))
    check(checks, "supabase_contract_readonly_map_written", "PASS", "Read-only Supabase contract map written.", evidence={"query_count": len(rows)})
    return report("supabase-contract-map", checks, "Review read-only Supabase contract map.")


def scan_android_parity_ledger() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    android_repo = Path(os.environ.get("MC_ANDROID_REPO", "/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView"))
    exists = android_repo.exists()
    topics = ["ProductPrice paging/keyset", "catalog push/pull", "history/session", "sync_events/outbox", "manual sync", "import/export side effects"]
    ledger = [{"topic": topic, "androidRepoAvailable": exists, "status": "PENDING_EXECUTION_AUDIT"} for topic in topics]
    write_evidence_file("android-parity-ledger.json", json.dumps({"taskId": TASK_ID, "ledger": ledger}, indent=2, sort_keys=True))
    write_evidence_file("android-parity-ledger.md", "# Android Parity Ledger\n\n" + "\n".join(f"- {item['topic']}: {item['status']}" for item in ledger) + "\n")
    check(checks, "android_reference_available", "PASS" if exists else "BLOCKED_EXTERNAL", "Android reference repo is available read-only.", evidence={"path": str(android_repo)})
    check(checks, "android_parity_ledger_written", "PASS", "Android parity ledger skeleton written.", evidence={"topics": topics})
    return report("android-parity-ledger", checks, "Fill parity ledger with method-level evidence during execution.")


def latest_agent_report(command_slug: str) -> dict[str, object] | None:
    candidates = sorted(AGENT_RUNS.glob(f"*-{command_slug}-*.json"))
    for candidate in reversed(candidates):
        try:
            return json.loads(candidate.read_text(encoding="utf-8"))
        except Exception:
            continue
    return None


def latest_agent_report_path(command_slug: str) -> str | None:
    candidates = sorted(AGENT_RUNS.glob(f"*-{command_slug}-*.json"))
    return rel(candidates[-1]) if candidates else None


def scan_performance_baseline() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    sync_report = latest_agent_report("ios-test-sync-task-TASK-122")
    product_price = read("iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift")
    automatic = "\n".join(candidate.read_text(encoding="utf-8", errors="replace") for candidate in swift_files("iOSMerchandiseControl/Sync/Automatic"))
    manual = "\n".join(candidate.read_text(encoding="utf-8", errors="replace") for candidate in swift_files("iOSMerchandiseControl/Sync/Manual"))

    sync_ms = sync_report.get("duration_ms") if sync_report else None
    page_limit_ok = "min(limit, 1_000)" in product_price
    keyset_ok = ".gt(\"id\"" in product_price and ".order(\"id\", ascending: true)" in product_price
    chunking_ok = ".range(from: start, to: end)" in product_price or "min(to, start + 999)" in product_price
    mainactor_heavy_hits = [
        match.group(0)
        for match in re.finditer(r"@MainActor[\s\S]{0,800}", automatic)
        if ".from(" in match.group(0) or "Task.sleep" in match.group(0) or "while true" in match.group(0)
    ]
    sleep_hits = len(re.findall(r"Task\.sleep", automatic))
    unbounded_sleep_loop = bool(re.search(r"while\s+true[\s\S]{0,800}Task\.sleep|Task\.sleep[\s\S]{0,800}while\s+true", automatic))
    manual_auto_coupling = "ManualSync" in automatic or "ManualPush" in automatic or "DryRun" in automatic

    baseline = {
        "taskId": TASK_ID,
        "status": "PASS_WITH_NOTES",
        "current": {
            "latestSyncTestReport": latest_agent_report_path("ios-test-sync-task-TASK-122"),
            "latestSyncTestDurationMs": sync_ms,
            "productPriceKeysetPaging": keyset_ok,
            "productPricePageLimitClampedTo1000": page_limit_ok,
            "productPriceChunkingOrRangePaging": chunking_ok,
            "automaticMainActorHeavyWorkHits": len(mainactor_heavy_hits),
            "automaticTaskSleepHits": sleep_hits,
            "automaticUnboundedTaskSleepLoop": unbounded_sleep_loop,
            "manualDryRunServiceBytes": len(manual),
            "manualContaminatesAutomatic": manual_auto_coupling,
        },
        "before": {
            "status": "NOT_RUN",
            "reason": "No comparable pre-TASK-122 runtime baseline was captured by the harness before the local refactor.",
        },
        "claim": "Current runtime invariants are measured/static-verified, but no before/after improvement claim is authorized without a comparable historical baseline.",
    }
    write_evidence_file("performance-baseline-before-after.json", json.dumps(baseline, indent=2, sort_keys=True))
    write_evidence_file(
        "performance-baseline-before-after.md",
        "\n".join([
            "# TASK-122 Performance Baseline Before/After",
            "",
            f"- Current broad sync test duration: `{sync_ms}` ms.",
            f"- Latest sync test report: `{baseline['current']['latestSyncTestReport']}`.",
            f"- ProductPrice keyset paging static evidence: `{keyset_ok}`.",
            f"- ProductPrice page limit clamp <=1000: `{page_limit_ok}`.",
            f"- ProductPrice chunk/range paging evidence: `{chunking_ok}`.",
            f"- Automatic MainActor heavy-work hits: `{len(mainactor_heavy_hits)}`.",
            f"- Automatic Task.sleep hits: `{sleep_hits}`.",
            f"- Automatic unbounded Task.sleep loop: `{unbounded_sleep_loop}`.",
            f"- Manual/dry-run contaminates Automatic: `{manual_auto_coupling}`.",
            "",
            "Before baseline: `NOT_RUN`; no comparable pre-TASK-122 harness measurement is available.",
            "Verdict: `PASS_WITH_NOTES`; architecture/runtime invariants are evidence-backed, but no performance improvement claim is authorized.",
            "",
        ])
    )
    check(checks, "broad_sync_duration_measured", "PASS" if sync_ms else "PASS_WITH_NOTES", "Latest broad sync test duration is available from harness report.", evidence={"duration_ms": sync_ms, "report": baseline["current"]["latestSyncTestReport"]})
    check(checks, "product_price_keyset_preserved", "PASS" if keyset_ok else "FAIL", "ProductPrice keyset paging is preserved.", file="iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift")
    check(checks, "product_price_chunking_preserved", "PASS" if page_limit_ok and chunking_ok else "FAIL", "ProductPrice page size/chunking remains bounded.", file="iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift")
    sleep_status = "FAIL" if unbounded_sleep_loop else ("PASS_WITH_NOTES" if sleep_hits else "PASS")
    check(
        checks,
        "automatic_no_unbounded_ui_retry_sleep",
        sleep_status,
        "Automatic runtime has no unbounded Task.sleep UI retry loop; bounded debounce/retry sleeps are recorded as notes.",
        evidence={"task_sleep_hits": sleep_hits, "unbounded_sleep_loop": unbounded_sleep_loop},
    )
    check(checks, "manual_not_blocking_automatic_static", "PASS" if not manual_auto_coupling else "FAIL", "Manual/debug/dry-run does not contaminate Automatic statically.")
    check(checks, "before_baseline_available", "PASS_WITH_NOTES", "Comparable pre-refactor performance baseline was not captured; current baseline is recorded.")
    return report("performance-baseline", checks, "Use current baseline; do not claim performance improvement without comparable before data.")


def scan_offline_outbox_conflict() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    sync_report = latest_agent_report("ios-test-sync-task-TASK-122")
    automatic_domain = latest_agent_report("ios-test-automatic-domain-task-TASK-122")
    evidence = {
        "latestSyncTestReport": latest_agent_report_path("ios-test-sync-task-TASK-122"),
        "latestAutomaticDomainReport": latest_agent_report_path("ios-test-automatic-domain-task-TASK-122"),
        "runtimeOfflineDeviceValidation": "BLOCKED_EXTERNAL",
        "nextAction": "Run simulator/device offline reconnect acceptance with TASK122_* data and authenticated Supabase session.",
    }
    write_evidence_file("offline-outbox-conflict-acceptance.json", json.dumps({"taskId": TASK_ID, **evidence}, indent=2, sort_keys=True))
    write_evidence_file(
        "offline-outbox-conflict-acceptance.md",
        "\n".join([
            "# TASK-122 Offline / Outbox / Conflict Acceptance",
            "",
            f"- Static/unit sync evidence: `{evidence['latestSyncTestReport']}`.",
            f"- Automatic domain evidence: `{evidence['latestAutomaticDomainReport']}`.",
            "- Runtime offline reconnect/device acceptance: `BLOCKED_EXTERNAL`.",
            "- NEXT_ACTION: Run simulator/device offline reconnect acceptance with `TASK122_*` data and authenticated Supabase session.",
            "",
        ])
    )
    check(checks, "sync_tests_cover_outbox_conflict_units", "PASS" if sync_report and sync_report.get("status") == "PASS" else "FAIL", "Broad sync tests passed and cover outbox/conflict units.", evidence={"report": evidence["latestSyncTestReport"]})
    check(checks, "automatic_domain_tests_passed", "PASS" if automatic_domain and automatic_domain.get("status") == "PASS" else "FAIL", "Automatic domain tests passed.", evidence={"report": evidence["latestAutomaticDomainReport"]})
    check(checks, "runtime_offline_device_acceptance", "BLOCKED_EXTERNAL", "Device/account offline reconnect validation was not executed in this local acceptance run.", evidence={"NEXT_ACTION": evidence["nextAction"]})
    return report("offline-outbox-conflict", checks, "Run device/account offline reconnect acceptance before any 100% production claim.")


def scan_sync_architecture() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    thin = scan_remote_transport_thin()
    conf = scan_transport_protocol_conformance()
    delegation = scan_adapter_delegation_depth()
    composition = scan_composition_import_boundary()
    for payload in [thin, conf, delegation, composition]:
        check(checks, f"subscan:{payload['scan']}", str(payload["status"]), str(payload["summary"]), evidence=payload.get("checks", [])[:20])
    return report("sync-architecture", checks, "Resolve all TASK-122 architecture subscan failures.")


def scan_dead_code() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    stale_hits = []
    for candidate in swift_files("iOSMerchandiseControl/Sync"):
        if re.search(r"Compatibility|Legacy|Task087|Task088", candidate.name):
            stale_hits.append(rel(candidate))
    check(checks, "legacy_task_or_compat_inventory", "PASS" if not stale_hits else "FAIL", "No legacy compatibility/task helper files remain in Sync.", evidence=stale_hits)
    return report("dead-code", checks, "Remove stale compatibility/task helper files or document exceptions.")


def scan_xcode_membership() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    project_rel = "iOSMerchandiseControl.xcodeproj/project.pbxproj"
    project = read(project_rel)
    missing = []
    for ref in sorted(set(re.findall(r"[\w./-]+\.swift", project))):
        normalized = ref.strip('"')
        if normalized.startswith("../") or normalized.startswith("//") or "://" in normalized:
            continue
        if not any((REPO / prefix / normalized).exists() for prefix in ["", "iOSMerchandiseControl", "iOSMerchandiseControlTests"]):
            missing.append(normalized)
    write_evidence_file("xcode-membership-before-after.json", json.dumps({"taskId": TASK_ID, "missing": missing}, indent=2, sort_keys=True))
    write_evidence_file("xcode-membership-before-after.md", "# Xcode Membership\n\n" + ("\n".join(f"- missing `{item}`" for item in missing) if missing else "- PASS\n"))
    check(checks, "explicit_swift_refs_exist", "PASS" if not missing else "FAIL", "Explicit Swift references in project exist.", file=project_rel, evidence={"missing": missing[:80]})
    return report("xcode-membership", checks, "Update Xcode membership after move/delete.")


def scan_sync_efficiency_acceptance() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    performance = json.loads((EVIDENCE_DIR / "performance-baseline-before-after.json").read_text(encoding="utf-8")) if (EVIDENCE_DIR / "performance-baseline-before-after.json").exists() else {}
    live = (EVIDENCE_DIR / "live-validation-limitations.md").read_text(encoding="utf-8", errors="replace") if (EVIDENCE_DIR / "live-validation-limitations.md").exists() else ""
    cross = json.loads((EVIDENCE_DIR / "cross-platform-acceptance.json").read_text(encoding="utf-8")) if (EVIDENCE_DIR / "cross-platform-acceptance.json").exists() else {}
    offline = json.loads((EVIDENCE_DIR / "offline-outbox-conflict-acceptance.json").read_text(encoding="utf-8")) if (EVIDENCE_DIR / "offline-outbox-conflict-acceptance.json").exists() else {}
    runtime_status = performance.get("status", "NOT_RUN")
    production_status = "BLOCKED_EXTERNAL" if "BLOCKED_EXTERNAL" in live or cross.get("status") == "BLOCKED_EXTERNAL" or offline.get("runtimeOfflineDeviceValidation") == "BLOCKED_EXTERNAL" else "NOT_RUN"
    matrix = {
        "Architecture efficiency": "PENDING" if adapter_pass_throughs() else "PASS",
        "Runtime efficiency": runtime_status,
        "Production readiness": production_status,
        "100% user claim": "NOT_ELIGIBLE",
        "reason": "100% claim requires live/account/device/cross-platform/offline/performance acceptance, review approval, and explicit user acceptance.",
        "performanceBaseline": "docs/TASKS/EVIDENCE/TASK-122/performance-baseline-before-after.json" if performance else None,
        "crossPlatformAcceptance": "docs/TASKS/EVIDENCE/TASK-122/cross-platform-acceptance.json" if cross else None,
        "offlineOutboxConflictAcceptance": "docs/TASKS/EVIDENCE/TASK-122/offline-outbox-conflict-acceptance.json" if offline else None,
    }
    write_evidence_file("sync-efficiency-acceptance-matrix.json", json.dumps({"taskId": TASK_ID, "matrix": matrix}, indent=2, sort_keys=True))
    write_evidence_file("sync-efficiency-acceptance-matrix.md", "# Sync Efficiency Acceptance Matrix\n\n" + "\n".join(f"- {key}: {value}" for key, value in matrix.items()) + "\n")
    if not live:
        write_evidence_file("live-validation-limitations.md", "# Live Validation Limitations\n\n- Live/account/device/cross-platform/offline checks are not automatically PASS.\n")
    write_evidence_file("post-task122-next-step-recommendation.md", "# Post TASK-122 Next Step Recommendation\n\nIf live/offline/performance acceptance remains blocked, open a focused final acceptance task rather than another cosmetic refactor.\n")
    check(checks, "matrix_written", "PASS", "Efficiency acceptance matrix written.", evidence=matrix)
    check(checks, "architecture_efficiency_pass", matrix["Architecture efficiency"], "Architecture efficiency has no adapter pass-through residue.")
    check(checks, "runtime_efficiency_status_recorded", "PASS_WITH_NOTES" if runtime_status in {"PASS_WITH_NOTES", "NOT_RUN"} else runtime_status, "Runtime efficiency status is explicit and not promoted to 100%.")
    check(checks, "production_readiness_status_recorded", "PASS_WITH_NOTES" if production_status in {"BLOCKED_EXTERNAL", "NOT_RUN"} else production_status, "Production readiness live/device limits are explicit.")
    check(checks, "claim_not_eligible_without_acceptance", "PASS", "100% efficient claim is not eligible without all hard acceptance evidence.")
    return report("sync-efficiency-acceptance", checks, "Do not claim 100% efficient unless every hard acceptance dimension is PASS.")


def scan_scanner_self_tests() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    base = path("tools/agent/fixtures/task122_scanners")
    required = [
        "transport-mega-service-renamed",
        "transport-over-500-loc",
        "adapter-pass-through",
        "domain-method-in-transport",
        "manual-debug-in-automatic",
        "uncategorized-sync-file",
        "concrete-transport-outside-composition",
        "sensitive-report-unredacted",
        "swift-source-flattened",
        "transport-domain-conformance",
        "adapter-without-query-ownership",
        "unauthorized-efficiency-claim",
    ]
    for name in required:
        fixture = base / name
        manifest = fixture / "README.md"
        red = fixture / "red"
        green = fixture / "green"
        ok = manifest.exists() and red.exists() and green.exists() and "expected" in manifest.read_text(encoding="utf-8", errors="replace").lower()
        check(checks, f"fixture:{name}", "PASS" if ok else "FAIL", "TASK-122 fixture has RED/GREEN and expected manifest.", file=rel(fixture))
    return report("scanner-self-tests", checks, "Add TASK-122 RED/GREEN fixtures before trusting scanners.")


def scan_sensitive_proxy() -> dict[str, object]:
    code, out = run_cmd(["bash", str(path("tools/agent/mc-agent.sh")), "scan", "sensitive", str(EVIDENCE_DIR), "--task", TASK_ID])
    status = "PASS" if code == 0 else "FAIL"
    return report("sensitive", [{"id": "sensitive_proxy", "status": status, "reason": "Delegated to common sensitive scanner.", "evidence": out[-1000:]}], "Fix sensitive scan hits.")


def scan_evidence_proxy() -> dict[str, object]:
    code, out = run_cmd(["bash", str(path("tools/agent/mc-agent.sh")), "scan", "evidence", "--task", TASK_ID])
    status = "PASS" if code == 0 else "FAIL"
    return report("evidence", [{"id": "evidence_proxy", "status": status, "reason": "Delegated to common evidence scanner.", "evidence": out[-1000:]}], "Fix evidence scan hits.")


SCANS: dict[str, Callable[[], dict[str, object]]] = {
    "task-docs": scan_task_docs,
    "master-plan-consistency": scan_master_plan_consistency,
    "evidence-metadata": scan_evidence_metadata,
    "harness-routing": scan_harness_routing,
    "harness-health": scan_harness_health,
    "mcp-wrapper": scan_mcp_wrapper,
    "status-taxonomy": scan_status_taxonomy,
    "scanner-self-tests": scan_scanner_self_tests,
    "source-format": scan_source_format,
    "swift-source-shape": scan_swift_source_shape,
    "sync-inventory": scan_sync_inventory,
    "sync-architecture": scan_sync_architecture,
    "remote-transport-thin": scan_remote_transport_thin,
    "adapter-delegation-depth": scan_adapter_delegation_depth,
    "domain-method-ownership": scan_domain_method_ownership,
    "manual-debug-boundary": scan_manual_debug_boundary,
    "transport-protocol-conformance": scan_transport_protocol_conformance,
    "composition-import-boundary": scan_composition_import_boundary,
    "remote-query-ownership": scan_remote_query_ownership,
    "debug-seed-boundary": scan_debug_seed_boundary,
    "dto-mapper-duplication": scan_dto_mapper_duplication,
    "supabase-query-map": scan_supabase_query_map,
    "transport-callsite-map": scan_transport_callsite_map,
    "protocol-conformance-map": scan_protocol_conformance_map,
    "supabase-contract-map": scan_supabase_contract_map,
    "android-parity-ledger": scan_android_parity_ledger,
    "performance-baseline": scan_performance_baseline,
    "offline-outbox-conflict": scan_offline_outbox_conflict,
    "xcode-membership": scan_xcode_membership,
    "dead-code": scan_dead_code,
    "sensitive": scan_sensitive_proxy,
    "evidence": scan_evidence_proxy,
    "sync-efficiency-acceptance": scan_sync_efficiency_acceptance,
}


def main(argv: list[str]) -> int:
    if len(argv) < 2 or argv[1] not in SCANS:
        payload = report(
            "unknown",
            [{"id": "scanner_argument", "status": "MISCONFIGURED", "reason": f"Expected one of {', '.join(sorted(SCANS))}.", "evidence": {"argv": argv[1:]}}],
            "Call task122_scans.py with a supported scan name.",
        )
        print(json.dumps(payload, indent=2, sort_keys=True))
        return exit_code(payload)
    payload = SCANS[argv[1]]()
    print(json.dumps(payload, indent=2, sort_keys=True))
    return exit_code(payload)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
