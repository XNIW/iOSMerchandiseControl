#!/usr/bin/env python3
"""TASK-120 scanners.

Read-only architecture and harness gates for iOS sync purification. The
scanners are intentionally conservative: they report concrete files, line
numbers, and a next action instead of attempting cleanup or remote work.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Callable, Iterable


TASK_ID = os.environ.get("TASK_ID", os.environ.get("MC_TASK_ID", "TASK-120"))
REPO = Path(os.environ.get("IOS_REPO", os.environ.get("MC_IOS_REPO", os.getcwd()))).resolve()
SCHEMA_VERSION = "1.1"
CANONICAL_STATUSES = {
    "PASS",
    "FAIL",
    "BLOCKED_EXTERNAL",
    "NOT_RUN",
    "PASS_WITH_NOTES",
    "MISCONFIGURED",
    "UNSAFE_OPERATION_REFUSED",
}
LEGACY_RESULT_MAP = {
    "pass": "PASS",
    "fail": "FAIL",
    "blocked": "BLOCKED_EXTERNAL",
    "misconfigured": "MISCONFIGURED",
    "refused": "UNSAFE_OPERATION_REFUSED",
    "pass_with_notes": "PASS_WITH_NOTES",
}


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO).as_posix()
    except ValueError:
        return path.as_posix()


def path(rel_path: str) -> Path:
    return REPO / rel_path


def read(rel_path: str) -> str:
    try:
        return path(rel_path).read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


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
    item: dict[str, object] = {
        "id": check_id,
        "status": status,
        "reason": reason,
    }
    if file is not None:
        item["file"] = file
    if evidence is not None:
        item["evidence"] = evidence
    if fix_hint is not None:
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
    status = str(payload.get("status", "MISCONFIGURED"))
    return {
        "PASS": 0,
        "PASS_WITH_NOTES": 0,
        "FAIL": 1,
        "BLOCKED_EXTERNAL": 2,
        "MISCONFIGURED": 3,
        "UNSAFE_OPERATION_REFUSED": 4,
    }.get(status, 3)


def swift_files(*roots: str) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        base = path(root)
        if base.is_file() and base.suffix == ".swift":
            files.append(base)
        elif base.is_dir():
            files.extend(sorted(base.rglob("*.swift")))
    return sorted(set(files))


def text_files_for_format() -> Iterable[Path]:
    roots = [
        path("iOSMerchandiseControl"),
        path("iOSMerchandiseControlTests"),
        path("tools/agent"),
    ]
    for root in roots:
        if not root.exists():
            continue
        for candidate in root.rglob("*"):
            if not candidate.is_file():
                continue
            rel_parts = candidate.resolve().relative_to(REPO).parts
            if any(part in {".git", "DerivedData", "node_modules", "agent-runs", "fixtures"} for part in rel_parts):
                continue
            if candidate.suffix in {".swift", ".sh", ".py"}:
                yield candidate


def all_repo_text_files() -> Iterable[Path]:
    excluded = {".git", "DerivedData", "node_modules", "agent-runs", ".build", "build"}
    for candidate in REPO.rglob("*"):
        if not candidate.is_file():
            continue
        if any(part in excluded for part in candidate.parts):
            continue
        if candidate.suffix.lower() in {".swift", ".md", ".py", ".sh", ".mjs", ".json", ".pbxproj"}:
            yield candidate


def run_cmd(args: list[str], cwd: Path | None = None) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd or REPO),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=60,
            check=False,
        )
        return proc.returncode, proc.stdout
    except Exception as exc:  # pragma: no cover - defensive scanner path
        return 99, str(exc)


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
            normalized = tuple(str(item) for item in argv if not str(item).startswith("TASK-"))
            patterns.add(normalized)
    return patterns


def command_is_discoverable(required: list[str], patterns: set[tuple[str, ...]]) -> bool:
    normalized = [item for item in required if not item.startswith("TASK-")]
    for pattern in patterns:
        if len(pattern) > len(normalized):
            continue
        if tuple(normalized[: len(pattern)]) == pattern:
            return True
    return False


def task120_test_matrix_commands() -> list[list[str]]:
    return [
        ["git", "head-consistency", "--task", "TASK-120"],
        ["preflight", "--require-head-consistency", "--task", "TASK-120"],
        ["config", "validate", "--task", "TASK-120"],
        ["help-json"],
        ["list", "commands-json"],
        ["scan", "task-docs", "--task", "TASK-120", "--strict"],
        ["scan", "harness-routing", "--task", "TASK-120", "--strict"],
        ["scan", "harness-health", "--task", "TASK-120", "--strict"],
        ["scan", "source-format", "--task", "TASK-120", "--strict"],
        ["scan", "duplicate-symbols", "--task", "TASK-120", "--strict"],
        ["scan", "automatic-legacy-monolith", "--task", "TASK-120", "--strict"],
        ["scan", "mainactor-boundary", "--task", "TASK-120", "--strict"],
        ["scan", "swiftdata-context-boundary", "--task", "TASK-120", "--strict"],
        ["scan", "manual-root-residue", "--task", "TASK-120", "--strict"],
        ["scan", "master-plan-consistency", "--task", "TASK-120", "--strict"],
        ["scan", "mcp-wrapper", "--task", "TASK-120", "--strict"],
        ["scan", "scanner-self-tests", "--task", "TASK-120", "--strict"],
        ["scan", "status-taxonomy", "--task", "TASK-120", "--strict"],
        ["scan", "evidence-metadata", "--task", "TASK-120", "--strict"],
        ["scan", "sync-architecture", "--task", "TASK-120", "--strict"],
        ["scan", "manual-boundary", "--task", "TASK-120", "--strict"],
        ["scan", "dead-code", "--task", "TASK-120", "--strict"],
        ["scan", "xcode-membership", "--task", "TASK-120", "--strict"],
        ["ios", "build", "debug", "--task", "TASK-120"],
        ["ios", "build", "release", "--task", "TASK-120"],
        ["ios", "test", "automatic-architecture", "--task", "TASK-120"],
        ["ios", "test", "automatic-domain", "--task", "TASK-120"],
        ["ios", "test", "sync", "--task", "TASK-120"],
        ["ios", "smoke", "options", "--task", "TASK-120"],
        ["supabase", "status-redacted", "--task", "TASK-120"],
        ["supabase", "contract", "sync-schema", "--task", "TASK-120", "--read-only"],
        ["scan", "sensitive", "--task", "TASK-120"],
        ["scan", "evidence", "--task", "TASK-120"],
        ["report", "validate-json", "--task", "TASK-120", "--path", "docs/TASKS/EVIDENCE/TASK-120/agent-runs"],
    ]


def scan_task_docs() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    task_rel = "docs/TASKS/TASK-120-ios-sync-final-architecture-purification.md"
    evidence_readme = "docs/TASKS/EVIDENCE/TASK-120/README.md"
    master_rel = "docs/MASTER-PLAN.md"
    task_text = read(task_rel)
    master = read(master_rel)

    check(checks, "task_doc_exists", "PASS" if path(task_rel).exists() else "FAIL", "TASK-120 task doc exists.", file=task_rel)
    check(
        checks,
        "evidence_readme_exists",
        "PASS" if path(evidence_readme).exists() else "FAIL",
        "TASK-120 evidence README exists.",
        file=evidence_readme,
    )
    check(
        checks,
        "master_mentions_task120_current",
        "PASS" if "TASK-120" in master and task_rel in master else "FAIL",
        "MASTER-PLAN points at the TASK-120 task file.",
        file=master_rel,
    )
    check(
        checks,
        "task119_review_pass_with_notes",
        "PASS" if "TASK-119" in master and "REVIEW_PASS_WITH_NOTES" in master else "FAIL",
        "TASK-119 remains REVIEW_PASS_WITH_NOTES in tracking.",
        file=master_rel,
    )
    check(
        checks,
        "task120_not_done",
        "PASS" if not re.search(r"\*\*Stato\*\*:\s*DONE\b", task_text) else "FAIL",
        "TASK-120 is not marked DONE in task metadata.",
        file=task_rel,
    )
    ca_ids = {int(match.group(1)) for match in re.finditer(r"CA-120-(\d{2})", task_text)}
    missing = [f"CA-120-{idx:02d}" for idx in range(1, 69) if idx not in ca_ids]
    check(
        checks,
        "ca_120_01_68_present",
        "PASS" if not missing else "FAIL",
        "CA-120-01...68 are materialized.",
        file=task_rel,
        evidence={"missing": missing},
    )
    matrix_missing = []
    for command in task120_test_matrix_commands():
        command_text = "./tools/agent/mc-agent.sh " + " ".join(command)
        if command_text not in task_text and " ".join(command) not in task_text:
            matrix_missing.append(" ".join(command))
    check(
        checks,
        "test_matrix_commands_present",
        "PASS" if not matrix_missing else "FAIL",
        "Task test matrix lists required commands.",
        file=task_rel,
        evidence={"missing": matrix_missing},
    )
    check(
        checks,
        "agent_runs_root_exists",
        "PASS" if path("docs/TASKS/EVIDENCE/TASK-120/agent-runs").exists() else "PASS_WITH_NOTES",
        "Evidence root is docs/TASKS/EVIDENCE/TASK-120/agent-runs.",
        file="docs/TASKS/EVIDENCE/TASK-120/agent-runs",
    )
    return report("task-docs", checks, "Continue with harness-routing only after task docs are coherent.")


def scan_harness_routing() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    payload, raw = load_help_json()
    check(
        checks,
        "help_json_parseable",
        "PASS" if payload is not None else "MISCONFIGURED",
        "mc-agent help-json is parseable.",
        evidence=raw[:800] if payload is None else {"command_count": len(payload.get("commands", []))},
    )
    patterns = command_patterns_from_help()
    missing = []
    for command in task120_test_matrix_commands():
        if not command_is_discoverable(command, patterns):
            missing.append(" ".join(command))
    check(
        checks,
        "task120_matrix_commands_discoverable",
        "PASS" if not missing else "FAIL",
        "Every TASK-120 test matrix command is discoverable via help-json/list commands-json.",
        evidence={"missing": missing},
        fix_hint="Add a safe mc-agent route and help-json entry before using an undocumented command.",
    )
    required_scans = [
        "task-docs",
        "harness-routing",
        "harness-health",
        "source-format",
        "duplicate-symbols",
        "automatic-legacy-monolith",
        "mainactor-boundary",
        "swiftdata-context-boundary",
        "manual-root-residue",
        "master-plan-consistency",
        "mcp-wrapper",
        "scanner-self-tests",
        "status-taxonomy",
        "evidence-metadata",
    ]
    route_text = read("tools/agent/mc-agent.sh")
    route_missing = [name for name in required_scans if name not in route_text]
    check(
        checks,
        "task120_scan_routes_present",
        "PASS" if not route_missing else "FAIL",
        "TASK-120 scanner names are routed by mc-agent.sh.",
        file="tools/agent/mc-agent.sh",
        evidence={"missing": route_missing},
    )
    return report("harness-routing", checks, "Fix missing routes before scanner self-tests or architecture scans.")


def scan_harness_health() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    shell_files = sorted(path("tools/agent").rglob("*.sh"))
    python_files = sorted(path("tools/agent/lib").rglob("*.py"))
    mjs_files = sorted(path("tools/agent/mcp").rglob("*.mjs"))
    for candidate in shell_files:
        code, out = run_cmd(["bash", "-n", str(candidate)])
        check(
            checks,
            f"bash_n:{rel(candidate)}",
            "PASS" if code == 0 else "FAIL",
            "Shell script parses with bash -n.",
            file=rel(candidate),
            evidence=out[-400:],
        )
    for candidate in python_files:
        code, out = run_cmd(["python3", "-m", "py_compile", str(candidate)])
        check(
            checks,
            f"py_compile:{rel(candidate)}",
            "PASS" if code == 0 else "FAIL",
            "Python scanner compiles.",
            file=rel(candidate),
            evidence=out[-400:],
        )
    for candidate in mjs_files:
        code, out = run_cmd(["node", "--check", str(candidate)])
        check(
            checks,
            f"node_check:{rel(candidate)}",
            "PASS" if code == 0 else "FAIL",
            "MCP JavaScript parses.",
            file=rel(candidate),
            evidence=out[-400:],
        )
    payload, raw = load_help_json()
    check(
        checks,
        "help_json_schema",
        "PASS" if payload and payload.get("schema_version") == SCHEMA_VERSION else "MISCONFIGURED",
        "help-json exposes schema 1.1.",
        evidence=raw[:600] if not payload else {"schema_version": payload.get("schema_version")},
    )
    return report("harness-health", checks, "Resolve parser/compile failures before trusting scanner output.")


def scan_source_format() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    for candidate in sorted(text_files_for_format()):
        rel_path = rel(candidate)
        lines = candidate.read_text(encoding="utf-8", errors="replace").splitlines()
        too_long = [
            {"line": idx, "length": len(line), "snippet": line[:160]}
            for idx, line in enumerate(lines, start=1)
            if len(line) > 1000
        ]
        over_300 = sum(1 for line in lines if len(line) > 300)
        ratio = (over_300 / len(lines)) if lines else 0
        packed_decls = []
        if candidate.suffix == ".swift":
            decl_rx = re.compile(r"\b(class|struct|actor|enum|protocol|func)\s+[A-Za-z_][A-Za-z0-9_]*")
            for idx, line in enumerate(lines, start=1):
                if len(decl_rx.findall(line)) > 1:
                    packed_decls.append({"line": idx, "snippet": line[:220]})
        minified_script = False
        if candidate.suffix in {".sh", ".py"} and lines:
            has_functions = any(re.search(r"\b(function|def)\b|[A-Za-z_][A-Za-z0-9_]*\(\)\s*\{", line) for line in lines)
            minified_script = len(lines) <= 2 and (lines[0].startswith("#!") or has_functions) and any(len(line) > 300 for line in lines)
        failures = {
            "lines_over_1000": too_long[:20],
            "over_300_ratio": ratio,
            "packed_declarations": packed_decls[:20],
            "minified_script": minified_script,
        }
        status = "FAIL" if too_long or ratio > 0.05 or packed_decls or minified_script else "PASS"
        check(
            checks,
            f"source_format:{rel_path}",
            status,
            "File respects TASK-120 line/readability thresholds." if status == "PASS" else "File violates TASK-120 source formatting thresholds.",
            file=rel_path,
            evidence=failures,
            fix_hint="Split long lines or packed declarations before architecture moves.",
        )
    return report("source-format", checks, "Fix source-format failures before Swift move/split/delete work.")


DECL_RX = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s*)*(?:(?:public|private|fileprivate|internal|open|final|nonisolated)\s+)*\b(class|struct|actor|enum|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)")


def top_level_symbols(root: str = "iOSMerchandiseControl") -> dict[str, list[dict[str, object]]]:
    symbols: dict[str, list[dict[str, object]]] = {}
    for candidate in swift_files(root):
        for idx, line in enumerate(candidate.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
            if line.startswith((" ", "\t")):
                continue
            match = DECL_RX.search(line)
            if not match:
                continue
            name = match.group(2)
            if name in {"CodingKeys"}:
                continue
            symbols.setdefault(name, []).append({"file": rel(candidate), "line": idx, "kind": match.group(1)})
    return symbols


def scan_duplicate_symbols() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    duplicates = {
        name: hits for name, hits in top_level_symbols().items()
        if len({hit["file"] for hit in hits}) > 1
    }
    check(
        checks,
        "duplicate_top_level_class_protocol_struct_symbols",
        "PASS" if not duplicates else "FAIL",
        "No duplicate top-level Swift declarations across app sources.",
        evidence=duplicates,
        fix_hint="Delete stale copies or rename/split ownership before build.",
    )
    return report("duplicate-symbols", checks, "Resolve duplicate declarations before Swift compilation.")


def scan_automatic_legacy_monolith() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    rel_file = "iOSMerchandiseControl/Sync/AutomaticPushServices.swift"
    text = read(rel_file)
    forbidden = r"\b(CatalogPushService|ProductPricePushService|HistorySessionPushService|SyncActivityRegistrationService)\b"
    hits = line_hits(rel_file, forbidden)
    decl_hits = line_hits(rel_file, r"^\s*(final\s+)?(class|struct|actor|protocol)\s+")
    line_count = len(text.splitlines()) if text else 0
    check(
        checks,
        "automatic_push_services_no_domain_concretes",
        "PASS" if not hits else "FAIL",
        "AutomaticPushServices.swift has no concrete domain services.",
        file=rel_file,
        evidence=hits,
    )
    check(
        checks,
        "automatic_push_services_stub_or_absent",
        "PASS" if not path(rel_file).exists() or (line_count <= 5 and not decl_hits) else "FAIL",
        "AutomaticPushServices.swift is absent or zero-behavior stub.",
        file=rel_file,
        evidence={"line_count": line_count, "declarations": decl_hits},
        fix_hint="Delete the stale monolith or leave only a reviewer-approved marker comment.",
    )
    return report("automatic-legacy-monolith", checks, "Keep the legacy monolith deleted/stubbed and rerun duplicate-symbols.")


def scan_mainactor_boundary() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    roots = [
        "iOSMerchandiseControl/Sync/Automatic/Core",
        "iOSMerchandiseControl/Sync/Automatic/Decision",
        "iOSMerchandiseControl/Sync/Automatic/Catalog",
        "iOSMerchandiseControl/Sync/Automatic/ProductPrice",
        "iOSMerchandiseControl/Sync/Automatic/History",
        "iOSMerchandiseControl/Sync/Automatic/Outbox",
        "iOSMerchandiseControl/Sync/Automatic/Pull",
    ]
    for candidate in swift_files(*roots):
        rel_path = rel(candidate)
        hits = line_hits(rel_path, r"@MainActor")
        check(
            checks,
            f"mainactor_boundary:{rel_path}",
            "PASS" if not hits else "FAIL",
            "Automatic core/domain file has no @MainActor marker.",
            file=rel_path,
            evidence=hits,
            fix_hint="Move UI/progress MainActor bridging to Presentation/facade, not domain/core services.",
        )
    return report("mainactor-boundary", checks, "Remove @MainActor from automatic core/domain before REVIEW.")


def scan_swiftdata_context_boundary() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    runtime = "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift"
    runtime_hits = line_hits(runtime, r"\bModelContext\b|context:\s*ModelContext|context\.container")
    check(
        checks,
        "runtime_facade_no_ui_modelcontext",
        "PASS" if not runtime_hits else "FAIL",
        "SyncAutomaticRuntime facade does not accept/pass UI ModelContext.",
        file=runtime,
        evidence=runtime_hits,
        fix_hint="Move concrete factory to a composition file that takes ModelContainer directly.",
    )
    for candidate in swift_files(
        "iOSMerchandiseControl/Sync/Automatic/Catalog",
        "iOSMerchandiseControl/Sync/Automatic/ProductPrice",
        "iOSMerchandiseControl/Sync/Automatic/History",
        "iOSMerchandiseControl/Sync/Automatic/Outbox",
        "iOSMerchandiseControl/Sync/Automatic/Pull",
    ):
        rel_path = rel(candidate)
        if rel_path.endswith("AutomaticSyncEventOutboxWriter.swift") or rel_path.endswith("Helpers.swift"):
            continue
        text = candidate.read_text(encoding="utf-8", errors="replace")
        if "ModelContext" not in text:
            continue
        has_fresh = "ModelContext(modelContainer)" in text
        ui_context_hits = line_hits(rel_path, r"context:\s*ModelContext")
        status = "PASS" if has_fresh and not rel_path.endswith("AutomaticPullBoundary.swift") else "FAIL"
        check(
            checks,
            f"automatic_fresh_context:{rel_path}",
            status,
            "Automatic SwiftData path creates fresh ModelContext from ModelContainer.",
            file=rel_path,
            evidence={"has_fresh_model_context": has_fresh, "context_parameters": ui_context_hits},
            fix_hint="Automatic/background work must own fresh contexts, not UI contexts.",
        )
    return report("swiftdata-context-boundary", checks, "Fix ModelContext boundary leaks before Swift moves continue.")


MANUAL_ROOT_PATTERN = re.compile(
    r"^(SupabaseManual.*|.*ManualPush.*|.*Manual.*(DTOs?|Models?|Factory|Adapter|ViewModel|Coordinator|Conversion).*)\.swift$"
)


def manual_root_files() -> list[str]:
    root = path("iOSMerchandiseControl")
    if not root.exists():
        return []
    return sorted(candidate.name for candidate in root.glob("*.swift") if MANUAL_ROOT_PATTERN.match(candidate.name))


def scan_manual_root_residue() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    residue = manual_root_files()
    check(
        checks,
        "manual_files_not_root_level",
        "PASS" if not residue else "FAIL",
        "Manual sync source files are physically isolated below Sync/Manual.",
        evidence={"root_level_manual_files": residue},
        fix_hint="Move SupabaseManual*/ManualPush/manual DTO/factory/view model files to iOSMerchandiseControl/Sync/Manual.",
    )
    boundary = path("iOSMerchandiseControl/Sync/Manual/ManualSyncBoundary.swift").exists()
    real_manual = [rel(candidate) for candidate in path("iOSMerchandiseControl/Sync/Manual").glob("*.swift")] if path("iOSMerchandiseControl/Sync/Manual").exists() else []
    check(
        checks,
        "manual_boundary_has_real_files",
        "PASS" if boundary and len(real_manual) > 1 else "FAIL",
        "Sync/Manual contains real manual implementation files, not only the marker boundary.",
        file="iOSMerchandiseControl/Sync/Manual",
        evidence={"files": real_manual[:80]},
    )
    return report("manual-root-residue", checks, "Move root-level manual residues or document reviewer-approved exceptions.")


def scan_master_plan_consistency() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    master_rel = "docs/MASTER-PLAN.md"
    master = read(master_rel)
    first_objective = master.split("\n## ", 2)[0] if master else ""
    objective_block_match = re.search(r"## Obiettivo attuale([\s\S]*?)(?:\n## |\Z)", master)
    objective_block = objective_block_match.group(1) if objective_block_match else first_objective
    current_task120 = "TASK-120" in objective_block
    task119_current = bool(re.search(r"\*\*TASK-119\s+--\s+ACTIVE\b", objective_block))
    task120_done = bool(re.search(r"TASK-120\s+[—-]{1,2}\s+DONE\b", objective_block))
    check(
        checks,
        "master_current_objective_task120",
        "PASS" if current_task120 else "FAIL",
        "MASTER current objective is TASK-120.",
        file=master_rel,
    )
    check(
        checks,
        "master_no_task119_active_conflict_in_current_objective",
        "PASS" if not task119_current else "FAIL",
        "MASTER current objective does not keep TASK-119 as a competing active current task.",
        file=master_rel,
        evidence={"task119_current_in_objective": task119_current},
    )
    check(
        checks,
        "master_task120_not_done",
        "PASS" if not task120_done else "FAIL",
        "MASTER does not mark TASK-120 DONE.",
        file=master_rel,
    )
    return report("master-plan-consistency", checks, "Update only current TASK-120 tracking; do not alter backlog/priorities.")


def scan_mcp_wrapper() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    server_rel = "tools/agent/mcp/server.mjs"
    server = read(server_rel)
    task120_tools = [
        "mc_task120_scan_task_docs",
        "mc_task120_scan_harness_routing",
        "mc_task120_scan_source_format",
        "mc_task120_scan_scanner_self_tests",
        "mc_task120_scan_sync_architecture",
    ]
    missing_tools = [name for name in task120_tools if name not in server]
    check(
        checks,
        "mcp_task120_allowlist_present",
        "PASS" if not missing_tools else "FAIL",
        "MCP wrapper allowlists safe TASK-120 scanner commands.",
        file=server_rel,
        evidence={"missing": missing_tools},
    )
    check(
        checks,
        "mcp_no_shell_string",
        "PASS" if "shell: true" not in server and "exec(" not in server else "FAIL",
        "MCP wrapper uses argv-based spawn, not arbitrary shell execution.",
        file=server_rel,
    )
    check(
        checks,
        "mcp_fixed_cwd",
        "PASS" if "cwd: MC_IOS_REPO" in server else "FAIL",
        "MCP wrapper fixes cwd to the iOS repo.",
        file=server_rel,
    )
    check(
        checks,
        "mcp_no_allow_mutation",
        "PASS" if not re.search(r"process\.env\.MC_ALLOW_(LIVE|CLEANUP)\s*=", server) else "FAIL",
        "MCP wrapper does not mutate MC_ALLOW_LIVE or MC_ALLOW_CLEANUP.",
        file=server_rel,
    )
    check(
        checks,
        "mcp_timeout_bound",
        "PASS" if "setTimeout" in server and "TIMEOUT_MS" in server else "FAIL",
        "MCP wrapper bounds command runtime with a timeout.",
        file=server_rel,
    )
    return report("mcp-wrapper", checks, "Harden MCP wrapper before exposing TASK-120 commands through MCP.")


def scan_status_taxonomy() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    payload, raw = load_help_json()
    if not payload:
        check(checks, "help_json_loaded", "MISCONFIGURED", "help-json could not be loaded.", evidence=raw[:600])
        return report("status-taxonomy", checks, "Fix help-json before taxonomy validation.")
    expected = {
        "0": "PASS",
        "1": "FAIL",
        "2": "BLOCKED_EXTERNAL",
        "3": "MISCONFIGURED",
        "4": "UNSAFE_OPERATION_REFUSED",
    }
    exit_codes = payload.get("exit_codes", {})
    check(
        checks,
        "exit_code_statuses_canonical",
        "PASS" if exit_codes == expected else "FAIL",
        "help-json exposes canonical TASK-120 status taxonomy.",
        evidence={"actual": exit_codes, "expected": expected},
        fix_hint="Use BLOCKED_EXTERNAL and UNSAFE_OPERATION_REFUSED in JSON; keep BLOCKED/REFUSED only as human aliases.",
    )
    report_map = read("tools/agent/lib/report.sh")
    check(
        checks,
        "report_map_uses_canonical_status",
        "PASS" if "BLOCKED_EXTERNAL" in report_map and "UNSAFE_OPERATION_REFUSED" in report_map else "FAIL",
        "mc-agent reports include canonical status values.",
        file="tools/agent/lib/report.sh",
    )
    return report("status-taxonomy", checks, "Fix taxonomy before final JSON validation.")


def canonical_status_from_report(payload: dict[str, object]) -> str | None:
    status = payload.get("status")
    if isinstance(status, str) and status in CANONICAL_STATUSES:
        return status
    result = payload.get("result")
    if isinstance(result, str):
        if result in CANONICAL_STATUSES:
            return result
        return LEGACY_RESULT_MAP.get(result)
    return None


def scan_evidence_metadata() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    runs = path("docs/TASKS/EVIDENCE/TASK-120/agent-runs")
    json_files = sorted(runs.glob("*.json")) if runs.exists() else []
    check(
        checks,
        "agent_runs_exists",
        "PASS" if runs.exists() else "FAIL",
        "TASK-120 agent-runs directory exists.",
        file=rel(runs),
    )
    if not json_files:
        check(
            checks,
            "agent_runs_has_json",
            "FAIL",
            "At least one TASK-120 JSON report exists.",
            file=rel(runs),
        )
    required = [
        "schema_version",
        "task_id",
        "command",
        "command_slug",
        "safety_level",
        "timestamp_start",
        "timestamp_end",
        "git_sha",
        "dirty_state",
        "exit_code",
        "artifact_paths",
        "redaction_summary",
        "NEXT_ACTION",
        "next_action_recommended",
    ]
    for candidate in json_files:
        try:
            payload = json.loads(candidate.read_text(encoding="utf-8"))
        except Exception as exc:
            check(checks, f"evidence_json_read:{candidate.name}", "FAIL", "JSON report is readable.", file=rel(candidate), evidence=str(exc))
            continue
        missing = [key for key in required if key not in payload]
        artifacts = payload.get("artifact_paths", {})
        artifact_missing = [key for key in ["markdown", "json", "log"] if not artifacts.get(key)]
        status = canonical_status_from_report(payload)
        bad = missing or artifact_missing or payload.get("schema_version") != SCHEMA_VERSION or payload.get("task_id") != TASK_ID or status not in CANONICAL_STATUSES
        check(
            checks,
            f"evidence_metadata:{candidate.name}",
            "PASS" if not bad else "FAIL",
            "JSON report has TASK-120 metadata, canonical status, artifacts and NEXT_ACTION.",
            file=rel(candidate),
            evidence={
                "missing": missing,
                "artifact_missing": artifact_missing,
                "schema_version": payload.get("schema_version"),
                "task_id": payload.get("task_id"),
                "canonical_status": status,
            },
        )
    outside = [
        rel(candidate)
        for candidate in path("docs/TASKS/EVIDENCE/TASK-120").glob("*.json")
    ]
    check(
        checks,
        "no_report_json_outside_agent_runs",
        "PASS" if not outside else "FAIL",
        "TASK-120 report JSON files live under agent-runs.",
        evidence={"outside_agent_runs": outside},
    )
    return report("evidence-metadata", checks, "Regenerate non-compliant reports with the hardened mc-agent wrapper.")


def scan_manual_boundary() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    residue = manual_root_files()
    check(
        checks,
        "manual_root_clean",
        "PASS" if not residue else "FAIL",
        "Manual sync files are not root-level.",
        evidence={"root_level_manual_files": residue},
    )
    automatic_roots = [
        "iOSMerchandiseControl/Sync/Automatic",
        "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift",
        "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
    ]
    forbidden = r"\bSupabaseManual[A-Za-z0-9_]*\b|\b[A-Za-z0-9_]*ManualPush[A-Za-z0-9_]*\b|\b[A-Za-z0-9_]*Compatibility[A-Za-z0-9_]*\b"
    hits = []
    for candidate in swift_files(*automatic_roots):
        rel_path = rel(candidate)
        for hit in line_hits(rel_path, forbidden):
            hits.append({"file": rel_path, **hit})
    check(
        checks,
        "automatic_no_manual_references",
        "PASS" if not hits else "FAIL",
        "Automatic runtime/domain does not reference manual-only symbols.",
        evidence=hits[:80],
    )
    return report("manual-boundary", checks, "Remove manual leakage from automatic paths.")


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
        "iOSMerchandiseControl/Sync/Recovery",
        "iOSMerchandiseControl/Sync/Account",
    ]
    for rel_dir in required_dirs:
        check(
            checks,
            f"dir:{rel_dir}",
            "PASS" if path(rel_dir).is_dir() else "FAIL",
            "Target architecture directory exists.",
            file=rel_dir,
        )
    root_residue = [
        rel_path for rel_path in [
            "iOSMerchandiseControl/Sync/SyncDecisionEngine.swift",
            "iOSMerchandiseControl/Sync/SyncDecisionInputProvider.swift",
            "iOSMerchandiseControl/Sync/SyncTrigger.swift",
            "iOSMerchandiseControl/Sync/SyncState.swift",
            "iOSMerchandiseControl/Sync/SyncStateStore.swift",
        ]
        if path(rel_path).exists()
    ]
    old_dirs = [rel_path for rel_path in ["iOSMerchandiseControl/Sync/Incremental", "iOSMerchandiseControl/Sync/Presentation"] if path(rel_path).exists()]
    check(
        checks,
        "root_domain_residue_absent",
        "PASS" if not root_residue and not old_dirs else "FAIL",
        "Decision/Pull/Presentation automatic files are physically under Automatic/*.",
        evidence={"root_files": root_residue, "old_dirs": old_dirs},
    )
    providers = "iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift"
    provider_text = read(providers)
    provider_decl_hits = line_hits(providers, r"^\s*(nonisolated\s+)?(class|struct|actor|enum|protocol)\s+")
    check(
        checks,
        "providers_monolith_removed",
        "PASS" if not path(providers).exists() or (len(provider_text.splitlines()) <= 5 and not provider_decl_hits) else "FAIL",
        "SyncAutomaticRuntimeProviders.swift is removed or transitional zero-behavior stub.",
        file=providers,
        evidence={"line_count": len(provider_text.splitlines()), "declarations": provider_decl_hits[:20]},
    )
    runtime = "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift"
    runtime_text = read(runtime)
    check(
        checks,
        "runtime_facade_no_factory_or_modelcontext",
        "PASS" if "SyncAutomaticRuntimeFactory" not in runtime_text and "ModelContext" not in runtime_text else "FAIL",
        "SyncAutomaticRuntime is facade/auth/state only; concrete factory moved out.",
        file=runtime,
    )
    factory = "iOSMerchandiseControl/Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift"
    check(
        checks,
        "composition_factory_dedicated",
        "PASS" if path(factory).exists() and "SyncAutomaticRuntimeFactory" in read(factory) else "FAIL",
        "Concrete automatic service creation lives in a dedicated composition factory.",
        file=factory,
    )
    history_auto = "iOSMerchandiseControl/Sync/Automatic/History/HistorySessionAutomaticPushService.swift"
    concrete_history_hits = line_hits(history_auto, r"\bHistorySessionSyncService\b")
    check(
        checks,
        "automatic_history_no_concrete_shared_service",
        "PASS" if not concrete_history_hits else "FAIL",
        "Automatic history push does not instantiate concrete mixed HistorySessionSyncService.",
        file=history_auto,
        evidence=concrete_history_hits,
    )
    automatic_service_hits = []
    for candidate in swift_files("iOSMerchandiseControl/Sync/Automatic"):
        rel_path = rel(candidate)
        if (
            rel_path.endswith("RemoteWriting.swift")
            or rel_path.endswith("Contracts.swift")
            or "/Presentation/" in rel_path
            or "/Composition/" in rel_path
        ):
            continue
        for hit in line_hits(rel_path, r"\bSupabaseInventoryService\b"):
            automatic_service_hits.append({"file": rel_path, **hit})
    check(
        checks,
        "automatic_domain_no_concrete_supabase_inventory_dependency",
        "PASS" if not automatic_service_hits else "FAIL",
        "Automatic domain depends on remote-writing protocols, not concrete SupabaseInventoryService.",
        evidence=automatic_service_hits[:80],
    )
    engine = read("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift")
    check(
        checks,
        "engine_owns_singleflight_cancel_retry",
        "PASS" if all(token in engine for token in ["AutomaticSyncSingleFlight", "AutomaticSyncCancellationPolicy", "AutomaticSyncRetryPolicy"]) else "FAIL",
        "AutomaticSyncEngine owns single-flight, cancellation and retry policy.",
        file="iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift",
    )
    retry_policy = "iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRetryPolicy.swift"
    retry_policy_text = read(retry_policy)
    check(
        checks,
        "retry_policy_is_dedicated_core_type",
        "PASS" if path(retry_policy).exists() and "AutomaticSyncRetryPolicy" in retry_policy_text else "FAIL",
        "Automatic retry policy lives in Automatic/Core instead of UI orchestration.",
        file=retry_policy,
    )
    orchestrator = "iOSMerchandiseControl/Sync/SyncOrchestrator.swift"
    orchestrator_retry_hits = []
    for pattern in [r"retry_after_sync_busy", r"Task\.sleep\(nanoseconds:\s*2_000_000_000\)"]:
        orchestrator_retry_hits.extend(line_hits(orchestrator, pattern))
    check(
        checks,
        "orchestrator_no_post_busy_retry_scheduler",
        "PASS" if not orchestrator_retry_hits else "FAIL",
        "SyncOrchestrator may submit/defer UI triggers, but post-busy retry scheduling is owned by AutomaticSyncEngine.",
        file=orchestrator,
        evidence=orchestrator_retry_hits[:40],
    )
    return report("sync-architecture", checks, "Resolve architecture FAIL rows before REVIEW.")


def scan_dead_code() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    project = read("iOSMerchandiseControl.xcodeproj/project.pbxproj")
    candidates = []
    for candidate in swift_files("iOSMerchandiseControl"):
        name = candidate.name
        if any(token in name for token in ["Compatibility", "Adapter", "AutomaticPushServices", "RuntimeProviders"]):
            refs = 0
            samples = []
            rx = re.compile(rf"\b{re.escape(candidate.stem)}\b")
            for text_file in all_repo_text_files():
                if text_file.resolve() == candidate.resolve():
                    continue
                text = text_file.read_text(encoding="utf-8", errors="replace")
                for idx, line in enumerate(text.splitlines(), start=1):
                    if rx.search(line):
                        refs += 1
                        if len(samples) < 10:
                            samples.append({"file": rel(text_file), "line": idx, "snippet": line.strip()[:180]})
            candidates.append({
                "file": rel(candidate),
                "symbol": candidate.stem,
                "reference_count_excluding_self": refs,
                "xcode_membership_detected": candidate.name in project,
                "samples": samples,
            })
    check(
        checks,
        "dead_code_inventory",
        "PASS",
        "Read-only stale/adapter candidate inventory collected; no deletion performed.",
        evidence={"candidates": candidates},
    )
    return report("dead-code", checks, "Use inventory plus xcode-membership/build evidence before deletion.")


def scan_xcode_membership() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    project_rel = "iOSMerchandiseControl.xcodeproj/project.pbxproj"
    project = read(project_rel)
    check(
        checks,
        "project_exists",
        "PASS" if path(project_rel).exists() else "MISCONFIGURED",
        "Xcode project exists.",
        file=project_rel,
    )
    check(
        checks,
        "filesystem_synchronized_groups",
        "PASS" if "PBXFileSystemSynchronizedRootGroup" in project else "FAIL",
        "Project uses file-system synchronized groups.",
        file=project_rel,
    )
    missing = []
    for ref in sorted(set(re.findall(r"[\w./-]+\.swift", project))):
        normalized = ref.strip('"')
        if normalized.startswith("../") or normalized.startswith("//") or "://" in normalized:
            continue
        if not any((REPO / prefix / normalized).exists() for prefix in ["", "iOSMerchandiseControl", "iOSMerchandiseControlTests"]):
            missing.append(normalized)
    check(
        checks,
        "explicit_swift_refs_exist",
        "PASS" if not missing else "FAIL",
        "Explicit Swift references in project.pbxproj exist.",
        file=project_rel,
        evidence={"missing_refs": missing[:80]},
    )
    return report("xcode-membership", checks, "Rerun after every move/delete.")


def scan_supabase_contract() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    source_hits = []
    sql_mutation_hits = []
    for candidate in swift_files("iOSMerchandiseControl/Sync/Automatic", "iOSMerchandiseControl/Sync/Manual"):
        rel_path = rel(candidate)
        text = candidate.read_text(encoding="utf-8", errors="replace")
        for table in ["inventory_products", "inventory_suppliers", "inventory_categories", "inventory_product_prices", "shared_sheet_sessions", "sync_events"]:
            if table in text:
                source_hits.append({"file": rel_path, "table": table})
        for idx, line in enumerate(text.splitlines(), start=1):
            if re.search(r"\b(CREATE|ALTER|DROP|GRANT|REVOKE|POLICY|RPC)\b", line, re.I):
                sql_mutation_hits.append({"file": rel_path, "line": idx, "snippet": line.strip()[:180]})
    check(
        checks,
        "known_sync_tables_referenced_static",
        "PASS" if source_hits else "PASS_WITH_NOTES",
        "Static contract references known sync tables/protocol surfaces without live DB query.",
        evidence={"sample": source_hits[:80]},
    )
    check(
        checks,
        "no_schema_mutation_tokens_in_sync_sources",
        "PASS" if not sql_mutation_hits else "FAIL",
        "TASK-120 sync sources do not contain migration/RLS/grant/RPC mutation tokens.",
        evidence=sql_mutation_hits[:80],
    )
    return report("supabase-contract-sync-schema", checks, "Use this static read-only gate unless live DB read-only approval is granted.")


SELF_TEST_SCANS = [
    "automatic-legacy-monolith",
    "manual-root-residue",
    "duplicate-symbols",
    "mainactor-boundary",
    "swiftdata-context-boundary",
    "source-format",
    "master-plan-consistency",
    "harness-routing",
    "status-taxonomy",
    "evidence-metadata",
    "mcp-wrapper",
    "sync-architecture",
]


def fixture_root_for(scan_name: str, color: str) -> Path:
    return path(f"tools/agent/fixtures/task120_scanners/{scan_name.replace('-', '_')}/{color}")


def scan_fixture_case(scan_name: str, fixture_root: Path) -> str:
    old_repo = globals()["REPO"]
    try:
        globals()["REPO"] = fixture_root.resolve()
        payload = SCANS[scan_name]()
        return str(payload.get("status", "MISCONFIGURED"))
    finally:
        globals()["REPO"] = old_repo


def scan_scanner_self_tests() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    for scan_name in SELF_TEST_SCANS:
        red_root = fixture_root_for(scan_name, "red")
        green_root = fixture_root_for(scan_name, "green")
        if not red_root.exists() or not green_root.exists():
            check(
                checks,
                f"fixture_exists:{scan_name}",
                "FAIL",
                "RED and GREEN fixture directories exist.",
                evidence={"red": rel(red_root), "green": rel(green_root)},
            )
            continue
        red_status = scan_fixture_case(scan_name, red_root)
        green_status = scan_fixture_case(scan_name, green_root)
        check(
            checks,
            f"red_green:{scan_name}",
            "PASS" if red_status in {"FAIL", "MISCONFIGURED"} and green_status in {"PASS", "PASS_WITH_NOTES"} else "FAIL",
            "Scanner fixture returns RED failure and GREEN pass.",
            evidence={"red_status": red_status, "green_status": green_status},
            file=f"tools/agent/fixtures/task120_scanners/{scan_name.replace('-', '_')}",
        )
    return report("scanner-self-tests", checks, "Fix scanner fixtures before trusting TASK-120 gates.")


SCANS: dict[str, Callable[[], dict[str, object]]] = {
    "task-docs": scan_task_docs,
    "harness-routing": scan_harness_routing,
    "harness-health": scan_harness_health,
    "source-format": scan_source_format,
    "duplicate-symbols": scan_duplicate_symbols,
    "automatic-legacy-monolith": scan_automatic_legacy_monolith,
    "mainactor-boundary": scan_mainactor_boundary,
    "swiftdata-context-boundary": scan_swiftdata_context_boundary,
    "manual-root-residue": scan_manual_root_residue,
    "master-plan-consistency": scan_master_plan_consistency,
    "mcp-wrapper": scan_mcp_wrapper,
    "scanner-self-tests": scan_scanner_self_tests,
    "status-taxonomy": scan_status_taxonomy,
    "evidence-metadata": scan_evidence_metadata,
    "sync-architecture": scan_sync_architecture,
    "manual-boundary": scan_manual_boundary,
    "dead-code": scan_dead_code,
    "xcode-membership": scan_xcode_membership,
    "supabase-contract-sync-schema": scan_supabase_contract,
}


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in SCANS:
        payload = report(
            "unknown",
            [{
                "id": "scanner_argument",
                "status": "MISCONFIGURED",
                "reason": f"Expected one of {', '.join(sorted(SCANS))}.",
                "evidence": {"argv": argv[1:]},
            }],
            "Call task120_scans.py with a supported scan name.",
        )
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 3
    payload = SCANS[argv[1]]()
    print(json.dumps(payload, indent=2, sort_keys=True))
    return exit_code(payload)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
