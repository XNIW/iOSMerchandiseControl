#!/usr/bin/env python3
"""TASK-121 architecture and harness scanners.

These gates are intentionally conservative. They verify that TASK-121 has its
own discoverable harness surface before allowing semantic Swift refactors, and
they report concrete architecture residue instead of silently accepting legacy
compatibility.
"""

from __future__ import annotations

import csv
import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Callable, Iterable


TASK_ID = os.environ.get("TASK_ID", os.environ.get("MC_TASK_ID", "TASK-121"))
REPO = Path(os.environ.get("IOS_REPO", os.environ.get("MC_IOS_REPO", os.getcwd()))).resolve()
SCHEMA_VERSION = "1.1"
EVIDENCE_DIR = REPO / "docs/TASKS/EVIDENCE/TASK-121"
AGENT_RUNS = EVIDENCE_DIR / "agent-runs"
CANONICAL_STATUSES = {
    "PASS",
    "FAIL",
    "BLOCKED_EXTERNAL",
    "NOT_RUN",
    "PASS_WITH_NOTES",
    "MISCONFIGURED",
    "UNSAFE_OPERATION_REFUSED",
}


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


def run_cmd(args: list[str], cwd: Path | None = None) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd or REPO),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=90,
            check=False,
        )
        return proc.returncode, proc.stdout
    except Exception as exc:
        return 99, str(exc)


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
    if file:
        item["file"] = file
    if evidence is not None:
        item["evidence"] = evidence
    if fix_hint:
        item["fix_hint"] = fix_hint
    checks.append(item)


def report(scan: str, checks: list[dict[str, object]], next_action: str) -> dict[str, object]:
    statuses = [str(item.get("status", "MISCONFIGURED")) for item in checks]
    if "MISCONFIGURED" in statuses:
        status = "MISCONFIGURED"
    elif "UNSAFE_OPERATION_REFUSED" in statuses:
        status = "UNSAFE_OPERATION_REFUSED"
    elif "FAIL" in statuses:
        status = "FAIL"
    elif "BLOCKED_EXTERNAL" in statuses:
        status = "BLOCKED_EXTERNAL"
    elif "PASS_WITH_NOTES" in statuses:
        status = "PASS_WITH_NOTES"
    elif statuses and all(value == "PASS" for value in statuses):
        status = "PASS"
    else:
        status = "MISCONFIGURED"
    return {
        "schema_version": SCHEMA_VERSION,
        "schemaVersion": SCHEMA_VERSION,
        "task_id": TASK_ID,
        "taskId": TASK_ID,
        "source": f"scan.{scan}",
        "scan": scan,
        "status": status,
        "result_status": status,
        "summary": f"{scan}: {status} ({len(checks)} checks)",
        "started_at": now(),
        "completed_at": now(),
        "safety_level": "read_only_static_scan",
        "repository": str(REPO),
        "checks": checks,
        "NEXT_ACTION": next_action,
    }


def exit_code(payload: dict[str, object]) -> int:
    return {
        "PASS": 0,
        "PASS_WITH_NOTES": 0,
        "FAIL": 1,
        "BLOCKED_EXTERNAL": 2,
        "MISCONFIGURED": 3,
        "UNSAFE_OPERATION_REFUSED": 4,
    }.get(str(payload.get("status", "MISCONFIGURED")), 3)


def swift_files(*roots: str) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        base = path(root)
        if base.is_file() and base.suffix == ".swift":
            files.append(base)
        elif base.is_dir():
            files.extend(sorted(base.rglob("*.swift")))
    return sorted(set(files))


def line_hits(rel_path: str, pattern: str, flags: int = 0) -> list[dict[str, object]]:
    text = read(rel_path)
    rx = re.compile(pattern, flags)
    hits: list[dict[str, object]] = []
    for idx, line in enumerate(text.splitlines(), start=1):
        if rx.search(line):
            hits.append({"line": idx, "snippet": line.strip()[:220]})
    return hits


def task121_matrix_commands() -> list[list[str]]:
    scans = [
        "task-docs",
        "master-plan-consistency",
        "harness-routing",
        "harness-health",
        "mcp-wrapper",
        "status-taxonomy",
        "evidence-metadata",
        "sync-inventory",
        "sync-architecture",
        "retry-ownership",
        "manual-boundary",
        "root-residue",
        "shared-purity",
        "dead-code",
        "xcode-membership",
        "duplicate-symbols",
        "source-format",
        "scanner-self-tests",
        "sensitive",
        "evidence",
    ]
    commands = [
        ["git", "head-consistency", "--task", "TASK-121"],
        ["preflight", "--require-head-consistency", "--task", "TASK-121"],
        ["config", "validate", "--task", "TASK-121"],
        ["help-json"],
        ["list", "commands-json"],
    ]
    commands.extend([["scan", scan, "--task", "TASK-121", "--strict"] for scan in scans])
    commands.extend([
        ["report", "validate-json", "--task", "TASK-121", "--path", "docs/TASKS/EVIDENCE/TASK-121/agent-runs"],
        ["supabase", "status-redacted", "--task", "TASK-121"],
        ["supabase", "contract", "sync-schema", "--task", "TASK-121", "--read-only"],
        ["ios", "build", "debug", "--task", "TASK-121"],
        ["ios", "build", "release", "--task", "TASK-121"],
        ["ios", "test", "automatic-architecture", "--task", "TASK-121"],
        ["ios", "test", "automatic-domain", "--task", "TASK-121"],
        ["ios", "test", "sync", "--task", "TASK-121"],
        ["ios", "test", "manual-sync-regression", "--task", "TASK-121"],
        ["ios", "smoke", "options", "--task", "TASK-121"],
    ])
    return commands


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
    patterns: set[tuple[str, ...]] = set()
    if not payload:
        return patterns
    for command in payload.get("commands", []):
        argv = command.get("argv", [])
        if isinstance(argv, list):
            patterns.add(tuple(str(item) for item in argv if not str(item).startswith("TASK-")))
    return patterns


def command_is_discoverable(required: list[str], patterns: set[tuple[str, ...]]) -> bool:
    normalized = [item for item in required if not item.startswith("TASK-")]
    for pattern in patterns:
        if len(pattern) <= len(normalized) and tuple(normalized[: len(pattern)]) == pattern:
            return True
    return False


def relevant_sync_files() -> list[Path]:
    files: set[Path] = set(swift_files("iOSMerchandiseControl/Sync"))
    root = path("iOSMerchandiseControl")
    if root.exists():
        for pattern in ("Supabase*.swift", "*Sync*.swift", "InventorySyncService.swift"):
            files.update(root.glob(pattern))
    return sorted(files)


def categorize(rel_path: str) -> tuple[str, str, str]:
    name = Path(rel_path).name
    if "/Tests/" in rel_path or rel_path.startswith("iOSMerchandiseControlTests/"):
        return "TEST_ONLY", "Tests", "Keep in test target."
    if "/Sync/Automatic/Core/" in rel_path:
        return "KEEP_AUTOMATIC_CORE", "Automatic", "Keep automatic core."
    if "/Sync/Automatic/Composition/" in rel_path:
        return "KEEP_AUTOMATIC_COMPOSITION", "Automatic", "Keep automatic composition."
    if "/Sync/Automatic/Presentation/" in rel_path:
        return "KEEP_AUTOMATIC_PRESENTATION", "Automatic", "Keep automatic presentation."
    if "/Sync/Automatic/" in rel_path:
        return "KEEP_AUTOMATIC_DOMAIN", "Automatic", "Keep automatic domain."
    if "/Sync/Manual/" in rel_path:
        return "KEEP_MANUAL", "Manual", "Keep manual boundary."
    if "/Sync/Shared/" in rel_path:
        return "KEEP_SHARED_PURE", "Shared", "Keep only if scanner proves pure."
    if "/Sync/Recovery/" in rel_path:
        return "KEEP_RECOVERY", "Recovery", "Keep recovery boundary."
    if "/Sync/Account/" in rel_path:
        return "KEEP_ACCOUNT", "Account", "Keep account boundary."
    if "/Sync/Outbox/" in rel_path:
        return "SPLIT_REQUIRED", "Outbox", "Classify outbox file-by-file; do not assume Shared purity."
    if name == "AutomaticPushServices.swift":
        return "DELETE_STUB", "Automatic", "Delete legacy automatic push aggregation stub or replace with domain files."
    if name == "CloudSyncOverviewState.swift":
        return "KEEP_AUTOMATIC_PRESENTATION", "Automatic", "Presentation state; keep only if no domain behavior."
    if name == "InventorySyncService.swift":
        return "EXCEPTION_REQUIRES_APPROVAL", "Sync", "Legacy/root sync service requires explicit exception or move/delete."
    if name in {"SyncAutomaticRuntime.swift", "AutomaticSyncReconnectScheduler.swift", "SyncOrchestrator.swift"}:
        return "MOVE_TO_AUTOMATIC", "Automatic", "Move behavior into Automatic boundary."
    if name == "SyncAutomaticRuntimeProviders.swift":
        return "DELETE_STUB", "Automatic", "Delete provider legacy or zero-behavior exception."
    if name == "SupabaseInventoryService.swift":
        return "SPLIT_REQUIRED", "Remote", "Split mega-service into remote adapters."
    if name.startswith("SupabaseAuth"):
        return "KEEP_ACCOUNT", "Account", "Account/auth boundary candidate."
    if name in {"SupabaseClientProvider.swift", "SupabaseConfig.swift"}:
        return "KEEP_REMOTE_TRANSPORT_ONLY", "Remote", "Keep only thin transport/config."
    if name.startswith("Supabase") and ("Manual" in name or "Preview" in name or "DryRun" in name or "Debug" in name):
        return "MOVE_TO_MANUAL", "Manual", "Manual/debug boundary."
    if name.startswith("Supabase") and ("Pull" in name or "Apply" in name or "Reconciliation" in name):
        return "MOVE_TO_RECOVERY", "Recovery", "Recovery/pull/apply boundary."
    if name.startswith("Supabase") or name.startswith("SyncEvent"):
        return "MOVE_TO_REMOTE", "Remote", "Remote adapter/DTO/protocol classification."
    if name.startswith("Sync"):
        return "SPLIT_REQUIRED", "Sync", "Root sync file requires file-by-file classification."
    return "UNCATEGORIZED", "Unknown", "No TASK-121 category rule matched."


def reference_count(symbol: str) -> int:
    if not symbol:
        return 0
    count = 0
    for candidate in swift_files("iOSMerchandiseControl", "iOSMerchandiseControlTests"):
        try:
            if symbol in candidate.read_text(encoding="utf-8", errors="replace"):
                count += 1
        except OSError:
            pass
    return count


def inventory_entries() -> list[dict[str, object]]:
    project_text = read("iOSMerchandiseControl.xcodeproj/project.pbxproj")
    entries: list[dict[str, object]] = []
    for candidate in relevant_sync_files():
        rel_path = rel(candidate)
        category, owner, action = categorize(rel_path)
        symbol = candidate.stem
        entries.append({
            "path": rel_path,
            "category": category,
            "owner": owner,
            "action": action,
            "current_folder": str(Path(rel_path).parent),
            "proposed_folder": owner,
            "reference_count": reference_count(symbol),
            "xcode_membership": "referenced" if candidate.name in project_text else "synchronized_or_unlisted",
            "risk": "high" if category in {"SPLIT_REQUIRED", "DELETE_STUB", "DELETE_LEGACY", "UNCATEGORIZED"} else "medium",
            "tests_needed": "architecture/build/regression",
            "exception_id": "",
        })
    return entries


def write_inventory_artifacts(entries: list[dict[str, object]]) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    (EVIDENCE_DIR / "sync-inventory.json").write_text(
        json.dumps({"schema_version": SCHEMA_VERSION, "task_id": TASK_ID, "entries": entries}, indent=2) + "\n",
        encoding="utf-8",
    )
    with (EVIDENCE_DIR / "sync-inventory.csv").open("w", encoding="utf-8", newline="") as handle:
        fields = ["path", "category", "owner", "action", "current_folder", "proposed_folder", "reference_count", "xcode_membership", "risk", "tests_needed", "exception_id"]
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for entry in entries:
            writer.writerow({field: entry.get(field, "") for field in fields})


def scan_task_docs() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    task_rel = "docs/TASKS/TASK-121-ios-sync-architecture-full-purification.md"
    readme_rel = "docs/TASKS/EVIDENCE/TASK-121/README.md"
    master_rel = "docs/MASTER-PLAN.md"
    task = read(task_rel)
    readme = read(readme_rel)
    master = read(master_rel)
    required_readme = ["docs/TASKS/EVIDENCE/TASK-121/agent-runs/", "schema `1.1`", ".md", ".json", ".log", "NEXT_ACTION", "redaction_summary", "NOT_RUN"]
    for rel_file in [task_rel, readme_rel, master_rel]:
        check(checks, f"exists:{rel_file}", "PASS" if path(rel_file).exists() else "FAIL", "Required TASK-121 document exists.", file=rel_file)
    missing = [item for item in required_readme if item not in readme]
    check(checks, "evidence_readme_aligned", "PASS" if not missing else "FAIL", "Evidence README contains TASK-121 schema/status/redaction contract.", file=readme_rel, evidence={"missing": missing})
    check(checks, "required_sentence", "PASS" if "Completion requires execution, review, and user acceptance." in task and "Completion requires execution, review, and user acceptance." in readme else "FAIL", "Required TASK-121 completion wording is present.")
    ca = {int(m.group(1)) for m in re.finditer(r"CA-121-(\d{2})", task)}
    missing_ca = [f"CA-121-{idx:02d}" for idx in range(1, 57) if idx not in ca]
    check(checks, "ca_121_01_56_present", "PASS" if not missing_ca else "FAIL", "CA-121-01...56 are materialized.", file=task_rel, evidence={"missing": missing_ca})
    check(checks, "master_points_task121", "PASS" if "Task attivo corrente:** **TASK-121" in master and task_rel in master else "FAIL", "MASTER-PLAN current task points to TASK-121.", file=master_rel)
    return report("task-docs", checks, "Fix TASK-121 docs/evidence alignment before execution.")


def scan_master_plan_consistency() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    master_rel = "docs/MASTER-PLAN.md"
    master = read(master_rel)
    objective_match = re.search(r"## Obiettivo attuale([\s\S]*?)(?:\n## |\Z)", master)
    objective = objective_match.group(1) if objective_match else ""
    current_matches = re.findall(r"Task attivo corrente:\*\* \*\*TASK-(\d+)|task corrente \*\*`TASK-(\d+)`", master)
    current_ids = sorted({a or b for a, b in current_matches})
    task120_done = bool(re.search(r"TASK-120\s+[—-]\s+DONE\b", objective))
    has_task121_phase = (
        "TASK-121 PLANNING" in objective
        or "TASK-121 FIX" in objective
        or "TASK-121 REVIEW" in objective
    )
    check(checks, "objective_is_task121", "PASS" if "TASK-121" in objective and has_task121_phase else "FAIL", "Current objective block is TASK-121.", file=master_rel)
    check(checks, "single_current_task121", "PASS" if current_ids == ["121"] else "FAIL", "Exactly one operative current task is TASK-121.", file=master_rel, evidence={"current_ids": current_ids})
    check(checks, "task120_superseded_not_done", "PASS" if "TASK-120 — ACTIVE / FIX — CHANGES_REQUIRED / SUPERSEDED_BY_TASK-121" in objective and not task120_done else "FAIL", "TASK-120 is superseded and not DONE.", file=master_rel)
    return report("master-plan-consistency", checks, "Keep only TASK-121 as current objective; historical ACTIVE headings are allowed only outside current task fields.")


def scan_harness_routing() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    payload, raw = load_help_json()
    check(checks, "help_json_parseable", "PASS" if payload else "MISCONFIGURED", "help-json parses.", evidence=raw[:500] if not payload else {"command_count": len(payload.get("commands", []))})
    patterns = command_patterns_from_help()
    missing = [" ".join(cmd) for cmd in task121_matrix_commands() if not command_is_discoverable(cmd, patterns)]
    check(checks, "task121_matrix_discoverable", "PASS" if not missing else "FAIL", "Every TASK-121 command is discoverable.", evidence={"missing": missing})
    route_text = read("tools/agent/mc-agent.sh")
    required = ["sync-inventory", "retry-ownership", "root-residue", "shared-purity", "TASK-121"]
    absent = [item for item in required if item not in route_text]
    check(checks, "task121_routes_present", "PASS" if not absent else "FAIL", "mc-agent.sh routes TASK-121 scanner names.", file="tools/agent/mc-agent.sh", evidence={"missing": absent})
    return report("harness-routing", checks, "Add TASK-121 routes/help-json entries before using scanners.")


def scan_harness_health() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    for candidate in sorted(path("tools/agent").rglob("*.sh")):
        code, out = run_cmd(["bash", "-n", str(candidate)])
        check(checks, f"bash_n:{rel(candidate)}", "PASS" if code == 0 else "FAIL", "Shell parses.", file=rel(candidate), evidence=out[-400:])
    for candidate in sorted(path("tools/agent/lib").rglob("*.py")):
        code, out = run_cmd(["python3", "-m", "py_compile", str(candidate)])
        check(checks, f"py_compile:{rel(candidate)}", "PASS" if code == 0 else "FAIL", "Python compiles.", file=rel(candidate), evidence=out[-400:])
    for candidate in sorted(path("tools/agent/mcp").rglob("*.mjs")):
        code, out = run_cmd(["node", "--check", str(candidate)])
        check(checks, f"node_check:{rel(candidate)}", "PASS" if code == 0 else "FAIL", "MCP JavaScript parses.", file=rel(candidate), evidence=out[-400:])
    return report("harness-health", checks, "Fix harness syntax before scanner execution.")


def scan_mcp_wrapper() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    server = read("tools/agent/mcp/server.mjs")
    required = ["mc_task121_scan_task_docs", "mc_task121_scan_sync_inventory", "mc_task121_scan_retry_ownership", "mc_task121_scan_shared_purity", "mc_task121_scan_root_residue"]
    missing = [name for name in required if name not in server]
    check(checks, "mcp_task121_allowlist_present", "PASS" if not missing else "FAIL", "MCP wrapper allowlists TASK-121 safe scanner commands.", file="tools/agent/mcp/server.mjs", evidence={"missing": missing})
    check(checks, "mcp_argv_not_shell", "PASS" if "shell: true" not in server and "exec(" not in server else "FAIL", "MCP wrapper uses argv spawn and no arbitrary shell.")
    check(checks, "mcp_no_allow_mutation", "PASS" if not re.search(r"process\.env\.MC_ALLOW_(LIVE|CLEANUP)\s*=", server) else "FAIL", "MCP wrapper does not set live/cleanup allow env.")
    return report("mcp-wrapper", checks, "Update MCP allowlist for TASK-121 safe commands.")


def scan_status_taxonomy() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    payload, raw = load_help_json()
    expected = {"0": "PASS", "1": "FAIL", "2": "BLOCKED_EXTERNAL", "3": "MISCONFIGURED", "4": "UNSAFE_OPERATION_REFUSED"}
    actual = payload.get("exit_codes", {}) if payload else {}
    check(checks, "canonical_exit_codes", "PASS" if actual == expected else "FAIL", "help-json exposes canonical exit-code taxonomy.", evidence={"actual": actual, "expected": expected})
    report_text = read("tools/agent/lib/report.sh")
    check(checks, "not_run_not_pass_rule_documented", "PASS" if "NOT_RUN" in report_text or "NOT_RUN" in read("docs/TASKS/EVIDENCE/TASK-121/README.md") else "FAIL", "NOT_RUN is documented as not PASS.")
    return report("status-taxonomy", checks, "Keep JSON statuses canonical.")


def scan_evidence_metadata() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    required = [
        AGENT_RUNS / "00-help-json.json",
        AGENT_RUNS / "00-commands-json.json",
        AGENT_RUNS / "00-discovery-summary.md",
    ]
    for candidate in required:
        check(checks, f"exists:{rel(candidate)}", "PASS" if candidate.exists() else "FAIL", "Discovery evidence file exists.", file=rel(candidate))
    bad_reports = []
    for candidate in sorted(AGENT_RUNS.glob("*.json")) if AGENT_RUNS.exists() else []:
        try:
            data = json.loads(candidate.read_text(encoding="utf-8", errors="replace"))
        except json.JSONDecodeError:
            bad_reports.append({"file": rel(candidate), "reason": "invalid json"})
            continue
        missing = [key for key in ["schema_version", "task_id", "status", "NEXT_ACTION"] if key not in data]
        status = str(data.get("status", ""))
        if status and status not in CANONICAL_STATUSES:
            missing.append("canonical_status")
        if missing and candidate.name not in {"00-help-json.json", "00-commands-json.json"}:
            bad_reports.append({"file": rel(candidate), "missing": missing})
    check(checks, "agent_run_json_metadata", "PASS" if not bad_reports else "FAIL", "Agent-run JSON reports include TASK-121 schema/status/NEXT_ACTION.", evidence=bad_reports[:40])
    return report("evidence-metadata", checks, "Fix report metadata before final certification.")


def scan_source_format() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    candidates: set[Path] = set()
    candidates.update(swift_files("iOSMerchandiseControl/Sync"))
    root = path("iOSMerchandiseControl")
    for pattern in ("Supabase*.swift", "*Sync*.swift"):
        candidates.update(root.glob(pattern))
    candidates.add(path("tools/agent/mc-agent.sh"))
    candidates.update(path("tools/agent/lib").glob("*.sh"))
    candidates.update(path("tools/agent/lib").glob("*.py"))
    candidates.add(path("tools/agent/mcp/server.mjs"))
    offenders: list[dict[str, object]] = []
    for candidate in sorted(c for c in candidates if c.exists()):
        lines = candidate.read_text(encoding="utf-8", errors="replace").splitlines()
        if not lines:
            continue
        long_1000 = [idx for idx, line in enumerate(lines, 1) if len(line) > 1000]
        long_300_ratio = sum(1 for line in lines if len(line) > 300) / max(len(lines), 1)
        if long_1000 or long_300_ratio > 0.05 or (len(lines) == 1 and len(lines[0]) > 300):
            offenders.append({"file": rel(candidate), "lines": len(lines), "long_1000": long_1000[:5], "long_300_ratio": round(long_300_ratio, 3)})
    check(checks, "no_minified_core_files", "PASS" if not offenders else "FAIL", "Sync/harness/MCP core files are readable.", evidence=offenders[:80])
    return report("source-format", checks, "Format one-line/minified core files before semantic Swift refactor.")


def scan_sync_inventory() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    entries = inventory_entries()
    write_inventory_artifacts(entries)
    uncategorized = [entry for entry in entries if entry["category"] == "UNCATEGORIZED"]
    outbox_pure = [entry for entry in entries if "/Sync/Outbox/" in str(entry["path"]) and entry["category"] == "KEEP_SHARED_PURE"]
    check(checks, "inventory_non_empty", "PASS" if entries else "FAIL", "Sync/root inventory has relevant files.", evidence={"count": len(entries)})
    check(checks, "no_uncategorized", "PASS" if not uncategorized else "FAIL", "No relevant file is UNCATEGORIZED.", evidence=uncategorized[:80])
    check(checks, "outbox_not_keep_shared_pure", "PASS" if not outbox_pure else "FAIL", "Sync/Outbox is not globally treated as KEEP_SHARED_PURE.", evidence=outbox_pure)
    return report("sync-inventory", checks, "Resolve UNCATEGORIZED files and review generated sync-inventory.csv/json.")


def scan_sync_architecture() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    retry_exists = path("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRetryPolicy.swift").exists()
    facade = read("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift")
    root_runtime = path("iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift")
    provider = path("iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift")
    runtime_text = read("iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift")
    provider_text = read("iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift")
    check(checks, "retry_policy_exists", "PASS" if retry_exists else "FAIL", "AutomaticSyncRetryPolicy exists.", file="iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRetryPolicy.swift")
    check(checks, "facade_not_typealias", "PASS" if "typealias AutomaticSyncRuntimeFacade = SyncAutomaticRuntime" not in facade else "FAIL", "Runtime facade is not a fake typealias.")
    check(checks, "root_runtime_no_behavior", "PASS" if not root_runtime.exists() or len(runtime_text.strip().splitlines()) <= 20 else "FAIL", "Root SyncAutomaticRuntime is deleted or zero-behavior shim.", file=rel(root_runtime))
    concrete_provider = bool(re.search(r"\b(class|struct|actor|protocol)\s+\w+", provider_text)) and len(provider_text.strip().splitlines()) > 20
    check(checks, "root_providers_no_behavior", "PASS" if not provider.exists() or not concrete_provider else "FAIL", "Root providers deleted or zero-behavior marker.", file=rel(provider))
    return report("sync-architecture", checks, "Move/delete root runtime/provider legacy and implement retry ownership.")


def scan_retry_ownership() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    retry_rel = "iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRetryPolicy.swift"
    engine_rel = "iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift"
    orchestrator_rel = "iOSMerchandiseControl/Sync/SyncOrchestrator.swift"
    retry = read(retry_rel)
    engine = read(engine_rel)
    orchestrator = read(orchestrator_rel)
    check(checks, "retry_policy_file_exists", "PASS" if path(retry_rel).exists() else "FAIL", "AutomaticSyncRetryPolicy.swift exists.", file=retry_rel)
    check(checks, "engine_uses_retry_policy", "PASS" if "AutomaticSyncRetryPolicy" in engine else "FAIL", "AutomaticSyncEngine uses retry policy.", file=engine_rel)
    check(checks, "retry_has_injectable_clock_or_sleeper", "PASS" if re.search(r"Clock|Sleeper|sleep", retry) else "FAIL", "Retry policy exposes injectable clock/sleeper for deterministic tests.", file=retry_rel)
    check(checks, "orchestrator_no_retry_after_busy", "PASS" if "retry_after_sync_busy" not in orchestrator else "FAIL", "SyncOrchestrator has no retry_after_sync_busy.", file=orchestrator_rel, evidence=line_hits(orchestrator_rel, "retry_after_sync_busy"))
    sleep_retry_hits = [hit for hit in line_hits(orchestrator_rel, r"Task\.sleep") if "retry" in hit["snippet"].lower() or "busy" in hit["snippet"].lower()]
    check(checks, "orchestrator_no_retry_sleep", "PASS" if not sleep_retry_hits else "FAIL", "SyncOrchestrator has no retry Task.sleep.", file=orchestrator_rel, evidence=sleep_retry_hits)
    return report("retry-ownership", checks, "Move busy/cancel/retry ownership fully into Automatic/Core.")


def scan_root_residue() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    root = path("iOSMerchandiseControl")
    residue = []
    for candidate in sorted(root.glob("*.swift")):
        if re.search(r"Supabase.*(Manual|Push|Pull|Preview)|.*Sync.*Service|InventorySyncService", candidate.name):
            category, owner, action = categorize(rel(candidate))
            if category in {"UNCATEGORIZED", "EXCEPTION_REQUIRES_APPROVAL", "SPLIT_REQUIRED", "MOVE_TO_MANUAL", "MOVE_TO_RECOVERY", "MOVE_TO_REMOTE"}:
                residue.append({"path": rel(candidate), "category": category, "owner": owner, "action": action})
    unclassified = [entry for entry in residue if entry["category"] == "UNCATEGORIZED"]
    check(checks, "root_sync_residue_classified", "PASS" if not unclassified else "FAIL", "Root sync/Supabase residues have a move/split/delete/exception decision.", evidence={"unclassified": unclassified[:80], "classified_residue_count": len(residue)})
    check(checks, "root_sync_residue_remaining_notes", "PASS_WITH_NOTES" if residue and not unclassified else "PASS", "Classified root residues remain and must be moved/split before final target certification.", evidence=residue[:80])
    return report("root-residue", checks, "Move/split classified root Supabase and sync residues before claiming final architecture target.")


def scan_shared_purity() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    hits: list[dict[str, object]] = []
    for candidate in swift_files("iOSMerchandiseControl/Sync/Shared"):
        text = candidate.read_text(encoding="utf-8", errors="replace")
        for idx, line in enumerate(text.splitlines(), 1):
            if re.search(r"@Model|ModelContext|HistoryEntry|ensureRemoteID|Supabase|ManualSync|SwiftUI|URLSession|await\s+", line):
                hits.append({"file": rel(candidate), "line": idx, "snippet": line.strip()[:180]})
    check(checks, "shared_value_only", "PASS" if not hits else "FAIL", "Sync/Shared contains only pure value/DTO/helper code.", evidence=hits[:80])
    return report("shared-purity", checks, "Move SwiftData/network/manual side effects out of Sync/Shared.")


def scan_manual_boundary() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    auto_hits: list[dict[str, object]] = []
    for candidate in swift_files("iOSMerchandiseControl/Sync/Automatic"):
        text = candidate.read_text(encoding="utf-8", errors="replace")
        if re.search(r"SupabaseManual|ManualPush|ManualSync", text):
            auto_hits.append({"file": rel(candidate)})
    root_manual = [rel(p) for p in path("iOSMerchandiseControl").glob("SupabaseManual*.swift")]
    check(checks, "automatic_no_manual_refs", "PASS" if not auto_hits else "FAIL", "Automatic path does not reference manual services/DTOs.", evidence=auto_hits)
    check(checks, "manual_not_root", "PASS" if not root_manual else "FAIL", "Manual files are not root-level.", evidence=root_manual)
    return report("manual-boundary", checks, "Isolate manual sync under Sync/Manual.")


def scan_dead_code() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    stale = [rel(p) for p in relevant_sync_files() if "Task087" in p.name or "Task088" in p.name]
    check(checks, "legacy_task_helpers_removed", "PASS" if not stale else "FAIL", "Legacy task smoke helpers are removed or test-only approved.", evidence=stale)
    return report("dead-code", checks, "Delete stale task-specific sync helpers or document test-only exceptions.")


def scan_xcode_membership() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    project = read("iOSMerchandiseControl.xcodeproj/project.pbxproj")
    missing = []
    for match in re.finditer(r"path = ([^;]+\.swift);", project):
        name = match.group(1).strip('"')
        if not list(REPO.glob(f"**/{name}")):
            missing.append(name)
    check(checks, "project_swift_refs_exist", "PASS" if not missing else "FAIL", "Xcode Swift references exist.", evidence={"missing": missing[:80]})
    return report("xcode-membership", checks, "Update Xcode membership after move/delete.")


def scan_duplicate_symbols() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    symbols: dict[str, list[str]] = {}
    ignored_nested_or_local = {
        "Call",
        "CodingKeys",
        "Coordinator",
        "ExpectedPoint",
        "Field",
        "Fixture",
        "InlineSuggestionsBox",
        "Kind",
        "Mode",
        "NamePickerSheet",
        "RemoteSnapshot",
        "Response",
        "Runtime",
        "ShareItem",
        "Stage",
        "State",
        "TestError",
        "ViewState",
    }
    for candidate in swift_files("iOSMerchandiseControl", "iOSMerchandiseControlTests"):
        text = candidate.read_text(encoding="utf-8", errors="replace")
        for line in text.splitlines():
            if line[:1].isspace():
                continue
            match = re.match(r"(?:public\s+|internal\s+|private\s+|fileprivate\s+)?(?:final\s+)?(?:class|struct|enum|actor|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)", line)
            if not match:
                continue
            symbol = match.group(1)
            if symbol in ignored_nested_or_local:
                continue
            symbols.setdefault(symbol, []).append(rel(candidate))
    dupes = {name: paths for name, paths in symbols.items() if len(set(paths)) > 1}
    check(checks, "no_duplicate_type_symbols", "PASS" if not dupes else "FAIL", "No duplicate type/protocol declarations.", evidence=dict(list(dupes.items())[:40]))
    return report("duplicate-symbols", checks, "Rename/delete duplicate declarations.")


def scan_scanner_self_tests() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    groups = ["sync-inventory", "sync-architecture", "retry-ownership", "manual-boundary", "root-residue", "shared-purity", "dead-code", "xcode-membership", "source-format", "evidence-metadata", "status-taxonomy", "mcp-wrapper"]
    base = path("tools/agent/fixtures/task121_scanners")
    for group in groups:
        group_dir = base / group
        red = group_dir / "red"
        green = group_dir / "green"
        manifest = group_dir / "README.md"
        ok = red.exists() and green.exists() and manifest.exists() and "expected" in manifest.read_text(encoding="utf-8", errors="replace").lower()
        check(checks, f"fixture:{group}", "PASS" if ok else "FAIL", "TASK-121 scanner fixture group has RED/GREEN and manifest.", file=rel(group_dir))
    return report("scanner-self-tests", checks, "Add RED/GREEN fixture groups under tools/agent/fixtures/task121_scanners.")


def scan_supabase_contract() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    table_hits = []
    for candidate in relevant_sync_files():
        text = candidate.read_text(encoding="utf-8", errors="replace")
        for table in ["inventory_products", "inventory_suppliers", "inventory_categories", "inventory_product_prices", "shared_sheet_sessions", "sync_events"]:
            if table in text:
                table_hits.append({"file": rel(candidate), "table": table})
    mutation_hits = []
    for candidate in relevant_sync_files():
        for idx, line in enumerate(candidate.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if re.search(r"\b(CREATE|ALTER|DROP|GRANT|REVOKE|CREATE POLICY|ALTER POLICY|DROP POLICY)\b", line, re.I):
                mutation_hits.append({"file": rel(candidate), "line": idx, "snippet": line.strip()[:180]})
    check(checks, "sync_tables_mapped", "PASS" if table_hits else "PASS_WITH_NOTES", "Static adapter table map collected.", evidence=table_hits[:120])
    check(checks, "no_schema_mutation_in_sources", "PASS" if not mutation_hits else "FAIL", "No schema/RLS/grant mutation tokens in sync sources.", evidence=mutation_hits[:80])
    return report("supabase-contract-sync-schema", checks, "Use read-only schema evidence before SupabaseInventoryService split.")


SCANS: dict[str, Callable[[], dict[str, object]]] = {
    "task-docs": scan_task_docs,
    "master-plan-consistency": scan_master_plan_consistency,
    "harness-routing": scan_harness_routing,
    "harness-health": scan_harness_health,
    "mcp-wrapper": scan_mcp_wrapper,
    "status-taxonomy": scan_status_taxonomy,
    "evidence-metadata": scan_evidence_metadata,
    "source-format": scan_source_format,
    "sync-inventory": scan_sync_inventory,
    "sync-architecture": scan_sync_architecture,
    "retry-ownership": scan_retry_ownership,
    "root-residue": scan_root_residue,
    "shared-purity": scan_shared_purity,
    "manual-boundary": scan_manual_boundary,
    "dead-code": scan_dead_code,
    "xcode-membership": scan_xcode_membership,
    "duplicate-symbols": scan_duplicate_symbols,
    "scanner-self-tests": scan_scanner_self_tests,
    "supabase-contract-sync-schema": scan_supabase_contract,
}


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in SCANS:
        payload = report(
            "unknown",
            [{"id": "scanner_argument", "status": "MISCONFIGURED", "reason": f"Expected one of {', '.join(sorted(SCANS))}.", "evidence": {"argv": argv[1:]}}],
            "Call task121_scans.py with a supported scan name.",
        )
        print(json.dumps(payload, indent=2))
        return exit_code(payload)
    payload = SCANS[argv[1]]()
    print(json.dumps(payload, indent=2))
    return exit_code(payload)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
