#!/usr/bin/env python3
"""TASK-124 architecture scanner suite.

Read-only gates for the final iOS sync architecture purification. The suite is
purposefully static: it validates boundaries, stale project references, known
legacy residues, and scanner fixture behavior before runtime refactors.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path


TASK_ID = os.environ.get("TASK_ID", os.environ.get("MC_TASK_ID", "TASK-124"))
REPO = Path(os.environ.get("IOS_REPO", os.environ.get("MC_IOS_REPO", os.getcwd()))).resolve()
SCHEMA_VERSION = "1.1"
APP_ROOT = "iOSMerchandiseControl"
SYNC_ROOT = f"{APP_ROOT}/Sync"

REQUIRED_SCANS = [
    "no-root-supabase-legacy",
    "no-automatic-manual-dependency",
    "transport-thin-only",
    "remote-adapter-single-domain",
    "no-full-pull-normal-path",
    "no-hidden-manual-sync",
    "no-stale-pbxproj-reference",
    "no-mainactor-heavy-sync",
    "no-service-role-client",
    "no-rls-bypass",
    "source-format",
    "dead-code-residue",
]

ROOT_LEGACY_FILES = {
    "SupabaseInventoryService.swift",
    "InventorySyncService.swift",
    "SupabaseManualSyncCompatibilityAdapter.swift",
}

DOMAIN_TABLES = {
    "catalog": {"inventory_products", "catalog"},
    "product_price": {"product_prices", "product_price"},
    "history": {"history_sessions", "history_generated_sheets", "inventory_history"},
    "sync_events": {"sync_events"},
    "options": {"option_", "user_option_counts", "counts"},
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


def read(candidate: Path | str) -> str:
    p = candidate if isinstance(candidate, Path) else path(candidate)
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def run_cmd(args: list[str]) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            args,
            cwd=str(REPO),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=60,
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


def app_swift_files() -> list[Path]:
    return swift_files(APP_ROOT)


def line_hits(candidate: Path, pattern: str, flags: int = 0) -> list[dict[str, object]]:
    rx = re.compile(pattern, flags)
    hits = []
    for idx, line in enumerate(read(candidate).splitlines(), start=1):
        if rx.search(line):
            hits.append({"line": idx, "snippet": line.strip()[:220]})
    return hits


def add(
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
    return "PASS" if statuses else "MISCONFIGURED"


def exit_code_for_status(status: str) -> int:
    return {
        "PASS": 0,
        "PASS_WITH_NOTES": 0,
        "FAIL": 1,
        "BLOCKED_EXTERNAL": 2,
        "MISCONFIGURED": 3,
        "UNSAFE_OPERATION_REFUSED": 4,
    }.get(status, 3)


def git_head(ref: str) -> str | None:
    code, out = run_cmd(["git", "rev-parse", ref])
    return out.strip() if code == 0 else None


def report(scan: str, checks: list[dict[str, object]], next_action: str) -> dict[str, object]:
    code, out = run_cmd(["git", "ls-remote", "origin", "refs/heads/main"])
    github_head = out.split()[0] if code == 0 and out.split() else None
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
        "completed_at": started,
        "safety_level": "read_only_static_scan",
        "repository": str(REPO),
        "canonicalHead": github_head,
        "localHead": git_head("HEAD"),
        "originHead": git_head("origin/main"),
        "githubHead": github_head,
        "checks": checks,
        "NEXT_ACTION": next_action,
        "nextAction": next_action,
    }


def write_evidence(name: str, data: dict[str, object], markdown: str) -> None:
    evidence_dir = REPO / f"docs/TASKS/EVIDENCE/{TASK_ID}"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    (evidence_dir / f"{name}.json").write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (evidence_dir / f"{name}.md").write_text(markdown, encoding="utf-8")


def scan_no_root_supabase_legacy() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    root = path(APP_ROOT)
    found = [candidate.name for candidate in root.glob("*.swift") if candidate.name in ROOT_LEGACY_FILES]
    add(
        checks,
        "root-legacy-files",
        "FAIL" if found else "PASS",
        "Root app legacy Supabase/sync service files must not exist.",
        evidence={"found": found, "expected_absent": sorted(ROOT_LEGACY_FILES)},
        fix_hint="Delete, move, or rename root legacy files after call-site proof.",
    )
    return report("no-root-supabase-legacy", checks, "Keep root app free of legacy Supabase mega-services.")


def automatic_files() -> list[Path]:
    roots = [
        f"{SYNC_ROOT}/Automatic",
        f"{SYNC_ROOT}/SyncOrchestrator.swift",
        f"{APP_ROOT}/ContentView.swift",
        f"{APP_ROOT}/OptionsView.swift",
        f"{APP_ROOT}/iOSMerchandiseControlApp.swift",
    ]
    return swift_files(*roots)


def scan_no_automatic_manual_dependency() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    hits = []
    for candidate in automatic_files():
        for hit in line_hits(candidate, r"(SupabaseManualSync|ManualSync|Sync/Manual)"):
            hits.append({"file": rel(candidate), **hit})
    add(
        checks,
        "automatic-manual-symbols",
        "FAIL" if hits else "PASS",
        "Normal automatic path must not import or call manual sync symbols.",
        evidence=hits,
        fix_hint="Route explicit user/recovery flows outside Automatic/ContentView normal runtime path.",
    )
    return report("no-automatic-manual-dependency", checks, "Remove manual dependencies from automatic path.")


def scan_transport_thin_only() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    rel_path = f"{SYNC_ROOT}/Remote/SupabaseTransportClient.swift"
    candidate = path(rel_path)
    text = read(candidate)
    forbidden = []
    for pattern in [r"\.from\s*\(", r"\.rpc\s*\(", r"inventory_products|product_prices|history_sessions|sync_events", r"ModelContext"]:
        forbidden.extend(line_hits(candidate, pattern))
    loc = len(text.splitlines())
    add(checks, "transport-exists", "PASS" if candidate.exists() else "FAIL", "SupabaseTransportClient.swift must exist.", file=rel_path)
    add(
        checks,
        "transport-has-no-domain-query",
        "FAIL" if forbidden else "PASS",
        "Transport client must not own table/query/domain behavior.",
        file=rel_path,
        evidence={"loc": loc, "forbidden_hits": forbidden},
        fix_hint="Move query/table behavior into query executor or domain adapters.",
    )
    return report("transport-thin-only", checks, "Keep SupabaseTransportClient transport-only.")


def domain_hits_for(candidate: Path) -> set[str]:
    text = read(candidate)
    hits: set[str] = set()
    for domain, tokens in DOMAIN_TABLES.items():
        if any(token in text for token in tokens):
            hits.add(domain)
    return hits


def scan_remote_adapter_single_domain() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    adapter_dir = path(f"{SYNC_ROOT}/Remote")
    adapters = sorted(adapter_dir.glob("*RemoteSupabaseAdapter.swift")) if adapter_dir.is_dir() else []
    mixed = []
    for candidate in adapters:
        domains = domain_hits_for(candidate)
        text = read(candidate)
        role_tokens = [token for token in ["ManualPush", "DryRun", "Preview", "OptionsSyncRemoteCountFetching"] if token in text]
        allowed_catalog_preview = candidate.name == "CatalogRemoteSupabaseAdapter.swift" and domains <= {"catalog"} and role_tokens == ["Preview"]
        allowed_split_adapter = candidate.name in {
            "ProductPricePreviewRemoteSupabaseAdapter.swift",
            "ProductPriceManualPushRemoteSupabaseAdapter.swift",
            "ProductPriceReleaseRemoteSupabaseAdapter.swift",
        }
        allowed_incremental_facade = candidate.name == "SyncEventRemoteSupabaseAdapter.swift" and "OptionsSyncRemoteCountFetching" not in text
        if (len(domains) > 1 or role_tokens) and not (allowed_catalog_preview or allowed_split_adapter or allowed_incremental_facade):
            mixed.append({"file": rel(candidate), "domains": sorted(domains), "role_tokens": role_tokens})
    add(
        checks,
        "remote-adapter-domain-count",
        "FAIL" if mixed else "PASS",
        "Remote adapters must be single-domain or have an explicit split/keep rationale with call-site evidence.",
        evidence=mixed,
        fix_hint="Split preview/manual/options responsibilities out of automatic domain adapters.",
    )
    return report("remote-adapter-single-domain", checks, "Split mixed remote adapter responsibilities or add motivated keep evidence.")


def scan_no_full_pull_normal_path() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    hits = []
    forbidden = r"\b(InventorySyncService|FullRecoveryService|BootstrapPullService|performFullPull|fullPull|manualFullPull)\b"
    for candidate in automatic_files():
        for hit in line_hits(candidate, forbidden):
            if "blocked_full_pull_requires_explicit_context" in hit["snippet"]:
                continue
            hits.append({"file": rel(candidate), **hit})
    add(checks, "automatic-full-pull", "FAIL" if hits else "PASS", "Normal automatic path must not perform full pull for local writes.", evidence=hits)
    return report("no-full-pull-normal-path", checks, "Keep full pull behind explicit recovery/bootstrap context.")


def scan_no_hidden_manual_sync() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    hits = []
    for candidate in automatic_files():
        for hit in line_hits(candidate, r"\b(SupabaseManualSyncCoordinator|runManualSync|manualSyncCoordinator|manual push)\b", re.IGNORECASE):
            hits.append({"file": rel(candidate), **hit})
    add(checks, "hidden-manual-sync", "FAIL" if hits else "PASS", "Automatic gates must not hide manual sync calls.", evidence=hits)
    return report("no-hidden-manual-sync", checks, "Remove hidden manual sync from automatic tests/runtime.")


def pbxproj_files() -> list[Path]:
    return sorted(path(".").glob("*.xcodeproj/project.pbxproj"))


def scan_no_stale_pbxproj_reference() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    stale = []
    fixture_refs = []
    referenced = set()
    for pbx in pbxproj_files():
        text = read(pbx)
        for match in re.finditer(r"([A-Za-z0-9_+.-]+\.swift)", text):
            name = match.group(1)
            referenced.add(name)
            start = max(0, match.start() - 80)
            end = min(len(text), match.end() + 80)
            context = text[start:end]
            if "repositoryURL" in context or "XCRemoteSwiftPackageReference" in context:
                continue
            if "fixture" in name.lower():
                fixture_refs.append({"project": rel(pbx), "file": name})
            if not any(candidate.name == name for candidate in path(APP_ROOT).rglob(name)):
                stale.append({"project": rel(pbx), "file": name})
    data = {"referencedSwiftFileCount": len(referenced), "stale": stale, "fixtureRefs": fixture_refs}
    markdown = "# TASK-124 pbxproj target membership\n\n```json\n" + json.dumps(data, indent=2, sort_keys=True) + "\n```\n"
    write_evidence("pbxproj-target-membership", data, markdown)
    add(checks, "pbxproj-stale-swift", "FAIL" if stale else "PASS", "pbxproj must not reference missing Swift files.", evidence=stale)
    add(checks, "pbxproj-fixtures", "FAIL" if fixture_refs else "PASS", "Test-only fixtures must not be target-membered in app pbxproj.", evidence=fixture_refs)
    return report("no-stale-pbxproj-reference", checks, "Clean stale pbxproj references.")


def scan_no_mainactor_heavy_sync() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    hits = []
    heavy = r"\.(from|insert|upsert|update|delete)\s*\(|ModelContext|URLSession"
    mutative_roots = [
        f"{SYNC_ROOT}/Automatic",
        f"{SYNC_ROOT}/SyncOrchestrator.swift",
    ]
    for candidate in swift_files(*mutative_roots):
        if "/Presentation/" in rel(candidate) or "/Composition/" in rel(candidate):
            continue
        text = read(candidate)
        if "@MainActor" not in text:
            continue
        heavy_hits = line_hits(candidate, heavy)
        if heavy_hits and candidate.name not in {"AutomaticSyncRuntimeFactory.swift"}:
            hits.append({"file": rel(candidate), "hits": heavy_hits[:10]})
    add(checks, "mainactor-heavy-sync", "FAIL" if hits else "PASS", "Mutative/network sync work must not be MainActor-heavy.", evidence=hits)
    return report("no-mainactor-heavy-sync", checks, "Move heavy sync work off MainActor or prove construction-only.")


def scan_no_service_role_client() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    hits = []
    for candidate in app_swift_files():
        if candidate.name == "SupabaseConfig.swift":
            continue
        for hit in line_hits(candidate, r"service_role", re.IGNORECASE):
            hits.append({"file": rel(candidate), **hit})
    add(checks, "service-role-client", "FAIL" if hits else "PASS", "Client app source must not contain service_role usage.", evidence=hits)
    return report("no-service-role-client", checks, "Keep privileged keys out of client runtime.")


def scan_no_rls_bypass() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    hits = []
    for candidate in app_swift_files():
        if candidate.name == "SupabaseConfig.swift":
            continue
        for hit in line_hits(candidate, r"\b(bypassRLS|supabaseAdmin|adminClient|service_role)\b", re.IGNORECASE):
            hits.append({"file": rel(candidate), **hit})
    add(checks, "rls-bypass-symbols", "FAIL" if hits else "PASS", "Client runtime must not use RLS bypass/admin client symbols.", evidence=hits)
    return report("no-rls-bypass", checks, "Keep app client under normal RLS.")


def scan_source_format() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    long_lines = []
    tabs = []
    for candidate in app_swift_files() + [
        f for f in swift_files("tools/agent/lib") if "fixtures" not in f.parts
    ]:
        for idx, line in enumerate(read(candidate).splitlines(), start=1):
            if len(line) > 500:
                long_lines.append({"file": rel(candidate), "line": idx, "length": len(line)})
            if "\t" in line and candidate.suffix == ".swift":
                tabs.append({"file": rel(candidate), "line": idx})
    add(checks, "long-lines", "FAIL" if long_lines else "PASS", "Source lines must stay reviewable.", evidence=long_lines[:30])
    add(checks, "swift-tabs", "FAIL" if tabs else "PASS", "Swift source should not add tab indentation.", evidence=tabs[:30])
    return report("source-format", checks, "Fix formatting residue.")


def scan_dead_code_residue() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    inventory = build_file_inventory()
    candidates = []
    for item in inventory["files"]:
        rel_path = str(item["path"])
        name = Path(rel_path).name
        text = read(rel_path)
        if Path(rel_path).parent.as_posix() == APP_ROOT and name in ROOT_LEGACY_FILES:
            candidates.append({**item, "classification": "DELETE", "reason": "root legacy service name"})
        elif "CompatibilityAdapter" in name:
            candidates.append({**item, "classification": "DELETE_OR_RENAME", "reason": "compatibility wrapper residue"})
        elif name == "SyncAutomaticRuntime.swift" and int(item.get("loc", 0)) <= 5:
            candidates.append({**item, "classification": "DELETE_OR_MERGE", "reason": "near-empty compatibility file"})
        elif "ManualSyncAggregatedPushOutboxProducer" in name:
            candidates.append({**item, "classification": "SPLIT_OR_DELETE", "reason": "manual/outbox adapter residue requires call-site proof"})
        elif "TODO TASK-124" in text:
            candidates.append({**item, "classification": "BLOCKED", "reason": "explicit TASK-124 TODO"})
    markdown = render_inventory_markdown(inventory, candidates)
    write_evidence("file-inventory", {"inventory": inventory, "candidates": candidates}, markdown)
    add(
        checks,
        "dead-code-candidates",
        "FAIL" if candidates else "PASS",
        "Known compatibility, near-empty, or root legacy residues must be eliminated or classified.",
        evidence=candidates,
        fix_hint="Remove or document with call-site proof in TASK-124 evidence.",
    )
    return report("dead-code-residue", checks, "Delete, merge, rename, or evidence-classify residue.")


def build_file_inventory() -> dict[str, object]:
    roots = [
        f"{SYNC_ROOT}",
        f"{APP_ROOT}/ContentView.swift",
        f"{APP_ROOT}/OptionsView.swift",
        f"{APP_ROOT}/iOSMerchandiseControlApp.swift",
    ]
    files = []
    for candidate in swift_files(*roots):
        text = read(candidate)
        files.append(
            {
                "path": rel(candidate),
                "loc": len(text.splitlines()),
                "conformances": sorted(re.findall(r":\s*([A-Za-z0-9_, &]+)\s*\{", text)[:8]),
                "callsManual": bool(re.search(r"ManualSync|SupabaseManualSync", text)),
                "callsRecovery": bool(re.search(r"Recovery|InventorySyncService|FullRecovery", text)),
                "remoteDomains": sorted(domain_hits_for(candidate)),
            }
        )
    return {"generatedAt": now(), "fileCount": len(files), "files": files}


def render_inventory_markdown(inventory: dict[str, object], candidates: list[dict[str, object]]) -> str:
    lines = [
        "# TASK-124 file inventory",
        "",
        f"- Generated: {inventory['generatedAt']}",
        f"- Swift files inventoried: {inventory['fileCount']}",
        "",
        "## Candidate Matrix",
        "",
        "| File | LOC | Classification | Reason |",
        "| --- | ---: | --- | --- |",
    ]
    if candidates:
        for item in candidates:
            lines.append(f"| `{item['path']}` | {item['loc']} | {item['classification']} | {item['reason']} |")
    else:
        lines.append("| none | 0 | KEEP | No static residue candidate found by scanner. |")
    lines.extend(["", "## Inventory", "", "| File | LOC | Manual | Recovery | Remote domains |", "| --- | ---: | --- | --- | --- |"])
    for item in inventory["files"]:
        lines.append(
            f"| `{item['path']}` | {item['loc']} | {item['callsManual']} | {item['callsRecovery']} | {', '.join(item['remoteDomains']) or '-'} |"
        )
    return "\n".join(lines) + "\n"


def scan_harness_routing() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    agent = read("tools/agent/mc-agent.sh") + "\n" + read("tools/agent/lib/common.sh")
    missing = [scan for scan in REQUIRED_SCANS if scan not in agent]
    add(checks, "task124-scan-routing", "FAIL" if missing else "PASS", "All TASK-124 scanners must be discoverable through mc-agent.", evidence={"missing": missing})
    data = {"requiredScans": REQUIRED_SCANS, "missing": missing, "agentVersion": os.environ.get("MC_AGENT_VERSION", "")}
    markdown = "# TASK-124 harness routing\n\n```json\n" + json.dumps(data, indent=2, sort_keys=True) + "\n```\n"
    write_evidence("harness-routing", data, markdown)
    return report("harness-routing", checks, "Expose missing TASK-124 scanner commands.")


def scan_automation_discovery() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    data = {
        "helpJsonCommand": "MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh help-json",
        "commandsJsonCommand": "MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh list commands-json",
        "agentVersion": os.environ.get("MC_AGENT_VERSION", ""),
        "task124Scans": REQUIRED_SCANS,
    }
    add(checks, "automation-discovery-captured", "PASS", "Canonical discovery commands are represented in machine-readable evidence.", evidence=data)
    markdown = "# TASK-124 automation discovery\n\n```json\n" + json.dumps(data, indent=2, sort_keys=True) + "\n```\n"
    write_evidence("automation-discovery", data, markdown)
    return report("automation-discovery", checks, "Use discovered canonical commands before fallback.")


def scan_scanner_self_tests() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    base = path("tools/agent/fixtures/task124_scanners")
    if not base.is_dir():
        add(checks, "fixture-root", "FAIL", "TASK-124 fixture root is missing.", file=rel(base))
        return report("scanner-self-tests", checks, "Add RED/GREEN fixtures.")
    for scan in REQUIRED_SCANS:
        red = base / scan / "red"
        green = base / scan / "green"
        add(checks, f"{scan}-red-fixture", "PASS" if red.is_dir() else "FAIL", "RED fixture directory exists.", file=rel(red))
        add(checks, f"{scan}-green-fixture", "PASS" if green.is_dir() else "FAIL", "GREEN fixture directory exists.", file=rel(green))
        red_status = fixture_status(scan, red)
        green_status = fixture_status(scan, green)
        add(checks, f"{scan}-red-detects", "PASS" if red_status == "FAIL" else "FAIL", "RED fixture must fail the scanner.", evidence={"observedStatus": red_status})
        add(checks, f"{scan}-green-passes", "PASS" if green_status == "PASS" else "FAIL", "GREEN fixture must pass the scanner.", evidence={"observedStatus": green_status})
    return report("scanner-self-tests", checks, "Fix fixture or scanner behavior before trusting TASK-124 gates.")


def fixture_status(scan: str, fixture_root: Path) -> str:
    if not fixture_root.is_dir():
        return "MISCONFIGURED"
    old_repo = globals()["REPO"]
    try:
        globals()["REPO"] = fixture_root.resolve()
        result = SCANNERS[scan]()
        return str(result["status"])
    finally:
        globals()["REPO"] = old_repo


SCANNERS = {
    "automation-discovery": scan_automation_discovery,
    "harness-routing": scan_harness_routing,
    "scanner-self-tests": scan_scanner_self_tests,
    "no-root-supabase-legacy": scan_no_root_supabase_legacy,
    "no-automatic-manual-dependency": scan_no_automatic_manual_dependency,
    "transport-thin-only": scan_transport_thin_only,
    "remote-adapter-single-domain": scan_remote_adapter_single_domain,
    "no-full-pull-normal-path": scan_no_full_pull_normal_path,
    "no-hidden-manual-sync": scan_no_hidden_manual_sync,
    "no-stale-pbxproj-reference": scan_no_stale_pbxproj_reference,
    "no-mainactor-heavy-sync": scan_no_mainactor_heavy_sync,
    "no-service-role-client": scan_no_service_role_client,
    "no-rls-bypass": scan_no_rls_bypass,
    "source-format": scan_source_format,
    "dead-code-residue": scan_dead_code_residue,
}


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in SCANNERS:
        valid = ", ".join(sorted(SCANNERS))
        print(json.dumps(report("unknown", [{"id": "scan-name", "status": "MISCONFIGURED", "reason": f"Unknown TASK-124 scan. Valid: {valid}"}], "Use a valid TASK-124 scan name."), indent=2))
        return 3
    result = SCANNERS[argv[1]]()
    print(json.dumps(result, indent=2, sort_keys=True))
    return exit_code_for_status(str(result.get("status", "MISCONFIGURED")))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
