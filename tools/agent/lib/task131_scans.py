#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import pathlib
import re
import subprocess
import sys
from datetime import datetime, timezone
from typing import Any


TASK_ID = os.environ.get("TASK_ID", "TASK-131")
IOS_REPO = pathlib.Path(os.environ.get("IOS_REPO", ".")).resolve()
ANDROID_REPO = pathlib.Path(os.environ.get("ANDROID_REPO", "")).resolve()
SUPABASE_REPO = pathlib.Path(os.environ.get("SUPABASE_REPO", "")).resolve()
SCAN = sys.argv[1] if len(sys.argv) > 1 else ""

TASK_DOC = IOS_REPO / "docs/TASKS/TASK-131-physical-device-sync-policy-ui-ux-acceptance.md"
MASTER_PLAN = IOS_REPO / "docs/MASTER-PLAN.md"
EVIDENCE_DIR = IOS_REPO / "docs/TASKS/EVIDENCE/TASK-131"
AGENT_RUNS = EVIDENCE_DIR / "agent-runs"


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def rel(path: pathlib.Path) -> str:
    try:
        return str(path.resolve().relative_to(IOS_REPO))
    except Exception:
        return str(path)


def read(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def latest_reports_matching(command_regex: str, accepted: set[str] | None = None) -> list[str]:
    if accepted is None:
        accepted = {"PASS"}
    if not AGENT_RUNS.is_dir():
        return []
    out: list[str] = []
    pattern = re.compile(command_regex)
    for path in sorted(AGENT_RUNS.glob("*.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        command = str(payload.get("command", ""))
        result = str(payload.get("result") or payload.get("status") or "")
        if pattern.search(command) and result in accepted:
            out.append(rel(path))
    return out


def latest_report_payload(command_regex: str, accepted: set[str] | None = None) -> tuple[str, dict[str, Any]] | None:
    reports = latest_reports_matching(command_regex, accepted)
    if not reports:
        return None
    path = IOS_REPO / reports[-1]
    try:
        return reports[-1], json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def check(checks: list[dict[str, Any]], check_id: str, ok: bool, reason: str, evidence: Any = None, fail_status: str = "FAIL") -> None:
    checks.append({
        "id": check_id,
        "status": "PASS" if ok else fail_status,
        "reason": reason,
        "evidence": evidence,
    })


def status_and_code(checks: list[dict[str, Any]]) -> tuple[str, int]:
    statuses = {str(item.get("status")) for item in checks}
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
        "NEXT_ACTION": "Use this TASK-131 scanner as evidence." if status == "PASS" else next_action,
    }


def command_patterns() -> set[str]:
    raw = subprocess.run(
        ["bash", str(IOS_REPO / "tools/agent/mc-agent.sh"), "help-json"],
        cwd=str(IOS_REPO),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    ).stdout
    try:
        payload = json.loads(raw)
    except Exception:
        return set()
    return {" ".join(item.get("argv", [])) for item in payload.get("commands", [])}


def redact_sample(sample: str) -> str:
    script = f'''
set -euo pipefail
source "{IOS_REPO}/tools/agent/lib/redact.sh"
mc_redact_text "$TASK131_SAMPLE"
'''
    result = subprocess.run(
        ["bash", "-lc", script],
        cwd=str(IOS_REPO),
        env={**os.environ, "TASK131_SAMPLE": sample},
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return result.stdout


def scan_task131_redaction() -> tuple[int, dict[str, Any]]:
    checks: list[dict[str, Any]] = []
    red_samples = {
        "email": "operator@example.com",
        "jwt": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature",
        "bearer": "Authorization: Bearer abcdefghijklmnopqrstuvwxyz.12345",
        "service_role": "service_role=sb_secret_abcdefghijklmnopqrstuvwxyz",
        "anon_key": "anon_key=eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.signature",
        "project_ref_url": "https://abcdefghijklmnopqrst.supabase.co/rest/v1",
        "project_ref": "project_ref: abcdefghijklmnopqrst",
        "home_path": "/Users/privateperson/Desktop/iOSMerchandiseControl/log.txt",
        "android_serial": "adb -s R58N123ABCDE logcat",
        "ios_udid": "UDID: 00008030-001C195E0E91802E",
        "ios_xcode_id": "{ platform:iOS, arch:arm64e, id:00008130-001644523A2A001C, name:iPhone di Private }",
        "ios_watch_name": '{"name":"Apple\\u00a0Watch di Private"}',
        "oauth_callback": "com.example.app://callback?access_token=sensitive-token&refresh_token=refresh-token",
        "xcode_log": "deviceIdentifier=00008030-001C195E0E91802E xcodebuild",
        "screenshot_manifest": "screenshot=/Users/privateperson/Desktop/evidence/device.png",
    }
    forbidden = [
        "operator@example.com",
        "sb_secret_abcdefghijklmnopqrstuvwxyz",
        "abcdefghijklmnopqrst.supabase.co",
        "/Users/privateperson",
        "R58N123ABCDE",
        "00008030-001C195E0E91802E",
        "00008130-001644523A2A001C",
        "iPhone di Private",
        "Apple\\u00a0Watch di Private",
        "sensitive-token",
        "refresh-token",
    ]
    for sample_id, sample in red_samples.items():
        redacted = redact_sample(sample)
        ok = all(value not in redacted for value in forbidden)
        check(checks, f"redact-{sample_id}", ok, f"Redaction must remove {sample_id} sample.", redacted[:240])
    green = "TASK131_SYNTHETIC_PRODUCT TASK131_SYNTHETIC_STORE barcode TASK131_FAKE_001"
    green_redacted = redact_sample(green)
    check(checks, "green-fixture-preserved", green in green_redacted, "Synthetic TASK131 fixture labels should remain readable.", green_redacted)
    return report("task131-redaction", checks, "Fix common redaction patterns and rerun task131-redaction.")


REQUIRED_COLUMNS = [
    "caseId",
    "scenario",
    "requiredEvidenceTier",
    "platforms",
    "command",
    "prefix",
    "expectedUserUX",
    "expectedDataInvariant",
    "result",
    "reportJson",
    "reportMd",
    "cleanupRequired",
    "residueResult",
    "notes",
]


def scan_task131_matrix_completeness() -> tuple[int, dict[str, Any]]:
    text = read(TASK_DOC)
    checks: list[dict[str, Any]] = []
    header_ok = "| " + " | ".join(REQUIRED_COLUMNS) + " |" in text
    check(checks, "matrix-header-columns", header_ok, "C126 matrix must expose all TASK-131 tracking columns.", REQUIRED_COLUMNS)
    missing = [f"C126-{i:02d}" for i in range(61) if f"| C126-{i:02d} |" not in text]
    check(checks, "c126-00-through-60-present", not missing, "All C126-00..C126-60 rows must be present.", missing)
    p0_subset = [
        "auth/session", "Local dirty", "Remote dirty", "campi diversi", "Same-field",
        "Delete-vs-edit", "ProductPrice", "Offline", "Kill/restart", "Options",
        "No-op sync", "cross-owner", "Cleanup/residue",
    ]
    missing_terms = [term for term in p0_subset if term.lower() not in text.lower()]
    check(checks, "p0-subset-described", not missing_terms, "P0 physical-live mandatory subset must be described.", missing_terms)
    blocked_phrase = "BLOCKED_EXTERNAL_IOS_PHYSICAL_DEVICE_NOT_AVAILABLE"
    check(checks, "ios-physical-blocker-taxonomy", blocked_phrase in text, "Hybrid Execution must explicitly classify missing iPhone physical cases.", blocked_phrase)
    return report("task131-matrix-completeness", checks, "Complete TASK-131 C126 matrix and hybrid physical blocker taxonomy.")


def scan_task131_final_gates() -> tuple[int, dict[str, Any]]:
    checks: list[dict[str, Any]] = []
    text = read(TASK_DOC)
    master = read(MASTER_PLAN)
    commands = command_patterns()
    required_commands = [
        "physical devices list --task TASK-131",
        "ios physical sync-policy-ui --task TASK-131 --prefix TASK131_IOS_",
        "ios simulator sync-policy-ui --task TASK-131 --prefix TASK131_IOS_SIM_",
        "android physical sync-policy-ui --task TASK-131 --prefix TASK131_ANDROID_PHYS_",
        "physical sync-policy-matrix --task TASK-131 --prefix TASK131_POLICY_",
        "physical conflict-review-matrix --task TASK-131 --prefix TASK131_CONFLICT_",
        "physical account-switch-matrix --task TASK-131 --prefix TASK131_ACCOUNT_",
        "physical offline-background-matrix --task TASK-131 --prefix TASK131_OFFLINE_",
        "physical accessibility-smoke --task TASK-131",
        "scan task131-matrix-completeness --task TASK-131 --strict",
        "scan task131-redaction --task TASK-131 --strict",
        "scan task131-final-gates --task TASK-131 --strict",
    ]
    missing_commands = [cmd for cmd in required_commands if cmd not in commands]
    check(checks, "full-physical-command-discovery", not missing_commands, "TASK-131 full-physical commands must be discoverable in help-json/list commands-json.", missing_commands)
    state = (
        ("ACTIVE / EXECUTION" in text or "ACTIVE / FIX" in text or "ACTIVE / BLOCKED" in text or "ACTIVE / REVIEW" in text)
        and "FULL_PHYSICAL_IOS_ANDROID_SCOPE" in text
    )
    check(checks, "task-state-full-physical-execution-fix-blocked-or-review", state, "Task doc must reflect approved full physical Execution/Fix/Blocked/Review scope.")
    master_state = (
        ("TASK-131 — ACTIVE / EXECUTION" in master or "TASK-131 — ACTIVE / FIX" in master or "TASK-131 — ACTIVE / BLOCKED" in master or "TASK-131 — ACTIVE / REVIEW" in master)
        and "FULL_PHYSICAL_IOS_ANDROID_SCOPE" in master
    )
    check(checks, "master-plan-state-full-physical-current", master_state, "Master Plan must reflect current TASK-131 full physical scope and status.")
    check(checks, "evidence-readme-present", (EVIDENCE_DIR / "README.md").is_file(), "Evidence README must exist.", rel(EVIDENCE_DIR / "README.md"))
    redaction_reports = latest_reports_matching(r"^scan task131-redaction --task TASK-131", {"PASS"})
    matrix_reports = latest_reports_matching(r"^scan task131-matrix-completeness --task TASK-131", {"PASS"})
    check(checks, "redaction-scan-pass", bool(redaction_reports), "task131-redaction must have a PASS report.", redaction_reports[-1:] if redaction_reports else [])
    check(checks, "matrix-completeness-pass", bool(matrix_reports), "task131-matrix-completeness must have a PASS report.", matrix_reports[-1:] if matrix_reports else [])
    required_report_patterns = {
        "ios-physical-sync-policy-ui-pass": (r"^ios physical sync-policy-ui --task TASK-131", {"PASS"}),
        "ios-simulator-sync-policy-ui-pass": (r"^ios simulator sync-policy-ui --task TASK-131", {"PASS"}),
        "android-physical-sync-policy-ui-pass": (r"^android physical sync-policy-ui --task TASK-131", {"PASS"}),
        "physical-sync-policy-matrix-pass": (r"^physical sync-policy-matrix --task TASK-131", {"PASS"}),
        "physical-offline-background-matrix-pass": (r"^physical offline-background-matrix --task TASK-131", {"PASS"}),
        "cleanup-execute-pass": (r"^supabase cleanup --task TASK-131 --prefix TASK131_ --execute", {"PASS"}),
        "residue-check-pass": (r"^supabase residue-check --task TASK-131 --prefix TASK131_", {"PASS"}),
    }
    for check_id, (pattern, accepted) in required_report_patterns.items():
        reports = latest_reports_matching(pattern, accepted)
        check(checks, check_id, bool(reports), f"{check_id} requires a latest accepted TASK-131 report.", reports[-1:] if reports else [])
    conflict = latest_report_payload(r"^physical conflict-review-matrix --task TASK-131", {"PASS", "BLOCKED_EXTERNAL"})
    conflict_ok = False
    conflict_evidence: Any = None
    if conflict:
        conflict_evidence = conflict[0]
        rec = conflict[1].get("reconciliation", {})
        conflict_ok = (
            conflict[1].get("result") == "PASS"
            or any(step.get("blocker") == "OPERATOR_CONFLICT_REVIEW_CHECKLIST_NOT_PROVIDED" for step in rec.get("steps", []))
        )
    check(checks, "physical-conflict-review-pass-or-operator-blocked", conflict_ok, "Conflict/Review must PASS or be explicitly blocked only by missing operator tap checklist.", conflict_evidence)

    account = latest_report_payload(r"^physical account-switch-matrix --task TASK-131", {"PASS", "BLOCKED_EXTERNAL"})
    account_ok = False
    account_evidence: Any = None
    if account:
        account_evidence = account[0]
        rec = account[1].get("reconciliation", {})
        account_ok = account[1].get("result") == "PASS" or rec.get("blocker") == "BLOCKED_EXTERNAL_SECOND_ACCOUNT"
    check(checks, "physical-account-switch-pass-or-second-account-blocked", account_ok, "Account switch must PASS or be explicitly blocked by unavailable second synthetic account.", account_evidence)

    accessibility = latest_report_payload(r"^physical accessibility-smoke --task TASK-131", {"PASS", "BLOCKED_EXTERNAL"})
    accessibility_ok = False
    accessibility_evidence: Any = None
    if accessibility:
        accessibility_evidence = accessibility[0]
        rec = accessibility[1].get("reconciliation", {})
        accessibility_ok = (
            accessibility[1].get("result") == "PASS"
            or any(step.get("blocker") == "OPERATOR_ACCESSIBILITY_CHECKLIST_NOT_PROVIDED" for step in rec.get("steps", []))
        )
    check(checks, "physical-accessibility-pass-or-operator-blocked", accessibility_ok, "Accessibility must PASS or be explicitly blocked by missing operator-assisted VoiceOver/TalkBack checklist.", accessibility_evidence)

    return report("task131-final-gates", checks, "Complete missing full-physical reports/state or document external blockers before moving TASK-131 to REVIEW.", {
        "requiredCommands": required_commands,
    })


SCAN_FUNCS = {
    "task131-redaction": scan_task131_redaction,
    "task131-matrix-completeness": scan_task131_matrix_completeness,
    "task131-final-gates": scan_task131_final_gates,
}


def main() -> int:
    func = SCAN_FUNCS.get(SCAN)
    if not func:
        payload = {
            "schemaVersion": "1.1",
            "taskId": TASK_ID,
            "source": "scan.task131",
            "status": "MISCONFIGURED",
            "result": "MISCONFIGURED",
            "checks": [{"id": "known-scan", "status": "MISCONFIGURED", "reason": f"Unknown TASK-131 scan: {SCAN}"}],
            "NEXT_ACTION": "Use task131-matrix-completeness, task131-redaction, or task131-final-gates.",
        }
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 3
    code, payload = func()
    print(json.dumps(payload, indent=2, sort_keys=True))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
