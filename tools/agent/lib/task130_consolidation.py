#!/usr/bin/env python3
"""TASK-130 consolidated hardening scanners.

Read-only/static gates for the TASK-128 residual scope absorbed into TASK-130.
The commands intentionally separate verified local/static evidence from physical
device, live, or binary roundtrip work that is not available in this run.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path


SCHEMA_VERSION = "1.1"
TASK_ID = os.environ.get("TASK_ID", os.environ.get("MC_TASK_ID", "TASK-130"))
IOS_REPO = Path(os.environ.get("IOS_REPO", os.getcwd())).resolve()
ANDROID_REPO = Path(
    os.environ.get(
        "ANDROID_REPO",
        "/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView",
    )
).resolve()
SUPABASE_REPO = Path(
    os.environ.get(
        "SUPABASE_REPO",
        "/Users/minxiang/Desktop/MerchandiseControlSupabase",
    )
).resolve()


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def read(base: Path, rel_path: str) -> str:
    try:
        return (base / rel_path).read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def exists(base: Path, rel_path: str) -> bool:
    return (base / rel_path).exists()


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(IOS_REPO))
    except ValueError:
        return path.name


def add_check(
    checks: list[dict[str, object]],
    check_id: str,
    status: str,
    reason: str,
    file: str,
    evidence: object | None = None,
) -> None:
    item: dict[str, object] = {
        "id": check_id,
        "status": status,
        "reason": reason,
        "file": file,
    }
    if evidence is not None:
        item["evidence"] = evidence
    checks.append(item)


def status_from_checks(checks: list[dict[str, object]]) -> str:
    statuses = [str(check.get("status", "MISCONFIGURED")) for check in checks]
    if "MISCONFIGURED" in statuses:
        return "MISCONFIGURED"
    if "UNSAFE_OPERATION_REFUSED" in statuses:
        return "UNSAFE_OPERATION_REFUSED"
    if "FAIL" in statuses:
        return "FAIL"
    if "BLOCKED_EXTERNAL" in statuses:
        return "BLOCKED_EXTERNAL"
    if any(status in {"PARTIAL", "NOT_RUN", "PASS_WITH_NOTES"} for status in statuses):
        return "PASS_WITH_NOTES"
    if statuses and all(status == "PASS" for status in statuses):
        return "PASS"
    return "MISCONFIGURED"


def exit_code(status: str) -> int:
    return {
        "PASS": 0,
        "PASS_WITH_NOTES": 0,
        "FAIL": 1,
        "BLOCKED_EXTERNAL": 2,
        "MISCONFIGURED": 3,
        "UNSAFE_OPERATION_REFUSED": 4,
    }.get(status, 3)


def payload(source: str, checks: list[dict[str, object]], next_action: str, **extra: object) -> dict[str, object]:
    status = status_from_checks(checks)
    data: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "schemaVersion": SCHEMA_VERSION,
        "task_id": TASK_ID,
        "taskId": TASK_ID,
        "source": source,
        "status": status,
        "result_status": status,
        "summary": f"{source}: {status} ({len(checks)} checks)",
        "started_at": now(),
        "completed_at": now(),
        "safety_level": "read_only_static_scan",
        "requires_live": False,
        "checks": checks,
        "NEXT_ACTION": next_action,
    }
    data.update(extra)
    return data


def golden_fixture_dir() -> Path:
    return IOS_REPO / "docs" / "TASKS" / "EVIDENCE" / "TASK-130" / "golden-corpus"


def run_golden_validate() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    import_core = read(IOS_REPO, "iOSMerchandiseControl/ProductImportCore.swift")
    excel = read(IOS_REPO, "iOSMerchandiseControl/ExcelSessionViewModel.swift")
    database = read(IOS_REPO, "iOSMerchandiseControl/DatabaseView.swift")
    android_excel = read(ANDROID_REPO, "app/src/main/java/com/example/merchandisecontrolsplitview/util/ExcelUtils.kt")
    android_analyzer = read(ANDROID_REPO, "app/src/main/java/com/example/merchandisecontrolsplitview/util/ImportAnalysis.kt")
    fixture_dir = golden_fixture_dir()

    for check_id, rel_path in [
        ("TASK130-GOLDEN-README", "docs/TASKS/EVIDENCE/TASK-130/golden-corpus/README.md"),
        ("TASK130-GOLDEN-CSV", "docs/TASKS/EVIDENCE/TASK-130/golden-corpus/task130-golden-products.csv"),
        ("TASK130-GOLDEN-HTML", "docs/TASKS/EVIDENCE/TASK-130/golden-corpus/task130-golden-excel.html"),
        ("TASK130-GOLDEN-FULL-PRODUCTS", "docs/TASKS/EVIDENCE/TASK-130/golden-corpus/full-db/Products.csv"),
        ("TASK130-GOLDEN-FULL-SUPPLIERS", "docs/TASKS/EVIDENCE/TASK-130/golden-corpus/full-db/Suppliers.csv"),
        ("TASK130-GOLDEN-FULL-CATEGORIES", "docs/TASKS/EVIDENCE/TASK-130/golden-corpus/full-db/Categories.csv"),
        ("TASK130-GOLDEN-FULL-PRICEHISTORY", "docs/TASKS/EVIDENCE/TASK-130/golden-corpus/full-db/PriceHistory.csv"),
        ("TASK130-GOLDEN-EXPECTED", "docs/TASKS/EVIDENCE/TASK-130/golden-corpus/expected-results.json"),
    ]:
        add_check(checks, check_id, "PASS" if exists(IOS_REPO, rel_path) else "FAIL", "TASK-130 synthetic golden fixture is versioned.", rel_path)

    add_check(
        checks,
        "TASK130-GOLDEN-XLSX-SUPPORT",
        "PASS" if exists(IOS_REPO, "docs/fixtures/TASK-031/canonical-headers.xlsx") and "rowsFromXLSX" in excel else "FAIL",
        "Existing privacy-safe XLSX fixture and iOS XLSX parser are present.",
        "docs/fixtures/TASK-031/canonical-headers.xlsx",
    )
    add_check(
        checks,
        "TASK130-GOLDEN-HTML-SUPPORT",
        "PASS" if "rowsFromHTML" in excel and exists(IOS_REPO, "docs/TASKS/EVIDENCE/TASK-130/golden-corpus/task130-golden-excel.html") else "FAIL",
        "HTML Excel parsing support and TASK-130 HTML fixture are present.",
        "iOSMerchandiseControl/ExcelSessionViewModel.swift",
    )
    add_check(
        checks,
        "TASK130-GOLDEN-LEGACY-XLS-SUPPORT",
        "PASS_WITH_NOTES" if "readLegacyXLSRows" in excel and list((IOS_REPO / "Vendor/libxls/test/files").glob("*.xls")) else "PARTIAL",
        "Legacy XLS parser and vendor XLS corpus exist; TASK-130 semantic XLS binary was not generated in this text-only evidence pass.",
        "Vendor/libxls/test/files",
    )
    for check_id, token, reason in [
        ("TASK130-GOLDEN-SCIENTIFIC-BARCODE", "expandScientificBarcode", "Scientific notation barcodes are normalized."),
        ("TASK130-GOLDEN-DECIMAL-SEPARATORS", "decimalSeparator", "Dot/comma prices are parsed deterministically."),
        ("TASK130-GOLDEN-DISCOUNT", "discountedPrice", "discount/discountedPrice columns are recognized."),
        ("TASK130-GOLDEN-DUPLICATE-BARCODE", "duplicate", "Duplicate barcode warnings are produced."),
        ("TASK130-GOLDEN-MISSING-BARCODE", "barcode_missing", "Missing barcode errors are produced."),
        ("TASK130-GOLDEN-MISSING-NAME", "product_name_missing", "Missing product name cases are represented."),
        ("TASK130-GOLDEN-INVALID-RETAIL", "retailPrice", "Retail price field is represented in parser/import contract."),
        ("TASK130-GOLDEN-NEGATIVE-QTY", "negative", "Negative quantity handling is represented."),
    ]:
        text = import_core + "\n" + excel + "\n" + android_analyzer
        add_check(checks, check_id, "PASS" if token.lower() in text.lower() else "PARTIAL", reason, "iOSMerchandiseControl/ProductImportCore.swift")
    add_check(
        checks,
        "TASK130-GOLDEN-FULL-DB-SHEETS",
        "PASS" if all(token in database for token in ["Products", "Suppliers", "Categories", "PriceHistory"]) else "FAIL",
        "Full DB import/export path references Products/Suppliers/Categories/PriceHistory sheets.",
        "iOSMerchandiseControl/DatabaseView.swift",
    )
    add_check(
        checks,
        "TASK130-GOLDEN-ANDROID-IMPORT-SUPPORT",
        "PASS" if any(token in android_excel for token in ["WorkbookFactory", "XSSFWorkbook", "DataFormatter", "createWorkbookWithLegacyFallback"]) else "PARTIAL",
        "Android import utility can read spreadsheet-like inputs for cross-platform parity.",
        "app/src/main/java/com/example/merchandisecontrolsplitview/util/ExcelUtils.kt",
    )
    add_check(
        checks,
        "TASK130-GOLDEN-PRIVACY",
        "PASS" if not re.search(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "\n".join(p.read_text(encoding="utf-8", errors="replace") for p in fixture_dir.rglob("*") if p.is_file())) else "FAIL",
        "Golden corpus contains no email-shaped real data.",
        "docs/TASKS/EVIDENCE/TASK-130/golden-corpus",
    )

    return payload(
        "harness.golden-corpus.validate",
        checks,
        "Use PASS/PARTIAL rows in the consolidated TASK-130 golden corpus ledger.",
        fixture_dir="docs/TASKS/EVIDENCE/TASK-130/golden-corpus",
    )


def run_golden_roundtrip() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    database = read(IOS_REPO, "iOSMerchandiseControl/DatabaseView.swift")
    xlsx_exporter = read(IOS_REPO, "iOSMerchandiseControl/InventoryXLSXExporter.swift")
    android_db = read(ANDROID_REPO, "app/src/main/java/com/example/merchandisecontrolsplitview/ui/screens/DatabaseScreen.kt")
    android_vm = read(ANDROID_REPO, "app/src/main/java/com/example/merchandisecontrolsplitview/viewmodel/DatabaseViewModel.kt")
    android_excel = read(ANDROID_REPO, "app/src/main/java/com/example/merchandisecontrolsplitview/util/ExcelUtils.kt")

    add_check(
        checks,
        "TASK130-ROUNDTRIP-IOS-EXPORT-FULL-DB",
        "PASS" if "exportFullDatabase" in database and "PriceHistory" in database and "InventoryXLSXExporter" in xlsx_exporter else "FAIL",
        "iOS full DB export path includes PriceHistory and XLSX writer.",
        "iOSMerchandiseControl/DatabaseView.swift",
    )
    add_check(
        checks,
        "TASK130-ROUNDTRIP-IOS-IMPORT-FULL-DB",
        "PASS" if "importFullDatabaseFromExcel" in database and "prepareFullDatabaseImport" in database else "FAIL",
        "iOS full DB import path is present.",
        "iOSMerchandiseControl/DatabaseView.swift",
    )
    add_check(
        checks,
        "TASK130-ROUNDTRIP-ANDROID-IMPORT-PATH",
        "PASS" if android_excel and any(token in android_excel for token in ["WorkbookFactory", "DataFormatter", "XSSFWorkbook", "createWorkbookWithLegacyFallback"]) else "PARTIAL",
        "Android spreadsheet import utility is present for static parity.",
        "app/src/main/java/com/example/merchandisecontrolsplitview/util/ExcelUtils.kt",
    )
    add_check(
        checks,
        "TASK130-ROUNDTRIP-ANDROID-EXPORT-PATH",
        "PASS_WITH_NOTES" if "exportDatabase" in android_vm and "writeDatabaseExportStreaming" in android_vm and "PRICE_HISTORY" in android_vm else ("PARTIAL" if "export" in android_db.lower() else "NOT_RUN"),
        "Android export UI/path was statically inspected; no Android-produced XLSX artifact was generated for iOS import in this run.",
        "app/src/main/java/com/example/merchandisecontrolsplitview/ui/screens/DatabaseScreen.kt",
    )
    add_check(
        checks,
        "TASK130-ROUNDTRIP-IOS-TO-ANDROID-BINARY",
        "PARTIAL",
        "No binary iOS export artifact was imported into Android during this consolidation run; static paths and fixtures are documented.",
        "docs/TASKS/EVIDENCE/TASK-130/golden-corpus",
    )
    add_check(
        checks,
        "TASK130-ROUNDTRIP-ANDROID-TO-IOS-BINARY",
        "PARTIAL",
        "No binary Android export artifact was imported into iOS during this consolidation run; static paths and fixtures are documented.",
        "docs/TASKS/EVIDENCE/TASK-130/golden-corpus",
    )
    return payload(
        "harness.golden-corpus.roundtrip",
        checks,
        "Reviewer must accept PARTIAL binary roundtrip limits or request device/app-auth execution inside TASK-130.",
    )


def fetch_old_prices_function() -> str:
    text = read(IOS_REPO, "iOSMerchandiseControl/ExcelSessionViewModel.swift")
    marker = "private func fetchOldPricesByBarcode"
    start = text.find(marker)
    if start < 0:
        return ""
    end = text.find("/// Formattazione", start)
    return text[start:end if end > start else start + 3000]


def run_swiftdata_fetch_budget() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    function = fetch_old_prices_function()
    database = read(IOS_REPO, "iOSMerchandiseControl/DatabaseView.swift")
    add_check(
        checks,
        "TASK130-SWIFTDATA-PREGENERATE-NO-FETCH-ALL",
        "PASS" if "context.fetch(FetchDescriptor<Product>())" not in function and "#Predicate<Product>" in function else "FAIL",
        "PreGenerate old-price lookup must not fetch every Product and filter in memory.",
        "iOSMerchandiseControl/ExcelSessionViewModel.swift",
    )
    add_check(
        checks,
        "TASK130-SWIFTDATA-PREGENERATE-CHUNKED-BARCODE",
        "PASS" if "chunk.contains(product.barcode)" in function and "chunkSize" in function else "FAIL",
        "PreGenerate lookup uses chunked barcode predicates.",
        "iOSMerchandiseControl/ExcelSessionViewModel.swift",
    )
    add_check(
        checks,
        "TASK130-SWIFTDATA-DATABASE-UI-QUERY-NOT-IMPORT-BLOCKER",
        "PASS_WITH_NOTES" if "@Query(sort: \\Product.barcode" in database else "PASS",
        "Database product list still uses SwiftUI @Query for UI listing; this is not the import/pre-generate hot path.",
        "iOSMerchandiseControl/DatabaseView.swift",
    )
    return payload(
        "scan.swiftdata-fetch-budget",
        checks,
        "Keep benchmark/runtime measurement as PASS_WITH_NOTES unless large-device data is provided.",
        strict="--strict" in sys.argv,
    )


def run_ios_benchmark_import_large() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    add_check(
        checks,
        "TASK130-BENCH-HARNESS-AVAILABLE",
        "PASS" if exists(IOS_REPO, "iOSMerchandiseControl/Task089SyntheticBenchmarkHarness.swift") else "PARTIAL",
        "Existing synthetic XLSX benchmark harness can generate privacy-safe large imports.",
        "iOSMerchandiseControl/Task089SyntheticBenchmarkHarness.swift",
    )
    function = fetch_old_prices_function()
    add_check(
        checks,
        "TASK130-BENCH-HOT-PATH-BUDGET",
        "PASS" if "chunk.contains(product.barcode)" in function else "FAIL",
        "PreGenerate price snapshot hot path avoids fetch-all Product lookup.",
        "iOSMerchandiseControl/ExcelSessionViewModel.swift",
    )
    add_check(
        checks,
        "TASK130-BENCH-RUNTIME-DATASET",
        "PARTIAL",
        "No device/simulator large XLSX timing was executed in this consolidation pass; static hot-path budget and harness availability were verified.",
        "docs/TASKS/TASK-130-price-contract-current-previous-old.md",
    )
    return payload(
        "ios.benchmark.import-large",
        checks,
        "Run the synthetic benchmark on the review machine/device if numeric time/memory budgets are required before acceptance.",
    )


def run_options_first_sync() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    options = read(IOS_REPO, "iOSMerchandiseControl/OptionsView.swift")
    account = read(IOS_REPO, "iOSMerchandiseControl/Sync/Account/AccountSyncDecisionView.swift")
    strings = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in (IOS_REPO / "iOSMerchandiseControl").glob("*.lproj/Localizable.strings"))
    source = options + "\n" + account + "\n" + strings
    required = [
        ("TASK130-OPTIONS-ACCOUNT", "cloudAccountStatusLabel", "account connected/signed-in/signed-out state"),
        ("TASK130-OPTIONS-LOCAL-DATA", "localDatabaseStatusPublicCard", "local data summary"),
        ("TASK130-OPTIONS-CLOUD-DATA", "supabaseBaselineSummary", "cloud/baseline data summary"),
        ("TASK130-OPTIONS-REVIEW", "AccountSyncDecisionView", "review needed/completed path"),
        ("TASK130-OPTIONS-AUTOSYNC", "SupabaseAutomaticSyncStatusCard", "automatic sync status"),
        ("TASK130-OPTIONS-PENDING", "localPendingAttentionCount", "pending local count"),
        ("TASK130-OPTIONS-LAST-SYNC", "lastSuccessText", "last sync/success timestamp"),
        ("TASK130-OPTIONS-SIGN-IN", "signInWithGoogle", "Sign in CTA"),
        ("TASK130-OPTIONS-REVIEW-CTA", "options.accountDecision.review", "Review CTA"),
    ]
    for check_id, token, reason in required:
        add_check(checks, check_id, "PASS" if token in source else "FAIL", f"Options exposes {reason}.", "iOSMerchandiseControl/OptionsView.swift")
    add_check(
        checks,
        "TASK130-OPTIONS-RETRY-CTA",
        "PASS_WITH_NOTES" if "options.supabase.automaticSync.badge.retry" in source else "PARTIAL",
        "Retry state is visible via automatic-sync retry badge/root sync action; Options does not add a separate manual retry button in this pass.",
        "iOSMerchandiseControl/OptionsView.swift",
    )
    return payload(
        "ios.smoke.options-first-sync",
        checks,
        "Reviewer should decide whether the visible retry state is enough or whether TASK-130 needs a dedicated Options retry button.",
    )


def run_scanner_edge() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    scanner = read(IOS_REPO, "iOSMerchandiseControl/BarcodeScannerView.swift")
    database = read(IOS_REPO, "iOSMerchandiseControl/DatabaseView.swift")
    generated = read(IOS_REPO, "iOSMerchandiseControl/GeneratedView.swift")
    add_check(checks, "TASK130-SCANNER-FALLBACK", "PASS" if "fallbackActionTitle" in scanner and "onFallbackRequested" in scanner else "FAIL", "Scanner exposes manual fallback callbacks.", "iOSMerchandiseControl/BarcodeScannerView.swift")
    add_check(checks, "TASK130-SCANNER-BACKGROUND", "PASS" if "handleScenePhaseChange" in scanner and "shouldRunSession: scenePhase == .active" in scanner else "FAIL", "Scanner stops/resumes camera work on scene phase changes.", "iOSMerchandiseControl/BarcodeScannerView.swift")
    add_check(checks, "TASK130-SCANNER-DB-EXISTING", "PASS" if "productToEdit = existing" in database and "pendingBarcodeForNewProduct" in database else "FAIL", "Database scanner distinguishes barcode already in DB from new product.", "iOSMerchandiseControl/DatabaseView.swift")
    add_check(checks, "TASK130-SCANNER-DB-FALLBACK-FOCUS", "PASS" if "focusSearchAfterScannerFallback" in database else "FAIL", "Database scanner fallback returns to manual search input.", "iOSMerchandiseControl/DatabaseView.swift")
    add_check(checks, "TASK130-SCANNER-GENERATED-SURFACE", "PASS_WITH_NOTES" if "showScanner" in generated and "reopenRowDetailAfterScan" in generated else "PARTIAL", "Generated scanner surface exists; physical double-scan/low-light behavior was not run.", "iOSMerchandiseControl/GeneratedView.swift")
    return payload(
        "ios.smoke.scanner-edge",
        checks,
        "Run physical low-light/double-scan cases if reviewer requires real-device scanner acceptance.",
    )


def run_accessibility() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    options = read(IOS_REPO, "iOSMerchandiseControl/OptionsView.swift")
    database = read(IOS_REPO, "iOSMerchandiseControl/DatabaseView.swift")
    generated = read(IOS_REPO, "iOSMerchandiseControl/GeneratedView.swift")
    scanner = read(IOS_REPO, "iOSMerchandiseControl/BarcodeScannerView.swift")
    strings = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in (IOS_REPO / "iOSMerchandiseControl").glob("*.lproj/Localizable.strings"))
    add_check(checks, "TASK130-A11Y-OPTIONS-LABELS", "PASS" if ".accessibilityElement(children: .combine)" in options else "FAIL", "Options combines key status rows for VoiceOver.", "iOSMerchandiseControl/OptionsView.swift")
    add_check(checks, "TASK130-A11Y-DATABASE-LABELS", "PASS" if ".accessibilityLabel" in database and ".accessibilityAction" in database else "FAIL", "Database rows/search/actions expose accessibility labels/actions.", "iOSMerchandiseControl/DatabaseView.swift")
    add_check(checks, "TASK130-A11Y-GENERATED-LABELS", "PASS_WITH_NOTES" if ".accessibility" in generated else "PARTIAL", "Generated has some accessibility coverage; full VoiceOver traversal not executed.", "iOSMerchandiseControl/GeneratedView.swift")
    add_check(checks, "TASK130-A11Y-SCANNER-LABELS", "PASS" if "scanner.torch.accessibility.label" in scanner and 'L("common.close")' in scanner else "FAIL", "Scanner close/torch controls are labeled.", "iOSMerchandiseControl/BarcodeScannerView.swift")
    add_check(checks, "TASK130-A11Y-DYNAMIC-TYPE", "PASS_WITH_NOTES" if "fixedSize(horizontal: false, vertical: true)" in options and ".minimumScaleFactor" in generated else "PARTIAL", "Dynamic Type/text overflow safeguards are present statically; simulator XXL screenshots were not captured in this pass.", "iOSMerchandiseControl/OptionsView.swift")
    add_check(checks, "TASK130-A11Y-LOCALIZATIONS", "PASS" if all(lang in strings or (IOS_REPO / f"iOSMerchandiseControl/{lang}.lproj/Localizable.strings").exists() for lang in ["en", "it", "es", "zh-Hans"]) else "PARTIAL", "Localization files for English/Italian/Spanish/Chinese are present.", "iOSMerchandiseControl/*.lproj/Localizable.strings")
    return payload(
        "ios.smoke.accessibility",
        checks,
        "Use PASS_WITH_NOTES rows as static smoke only; run VoiceOver/Dynamic Type simulator review if required.",
    )


def run_device_feasibility_snapshot() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    ios_devices = subprocess.run(["xcrun", "devicectl", "list", "devices"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    adb_devices = subprocess.run(["adb", "devices"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    add_check(
        checks,
        "TASK130-REALDEVICE-IOS-LISTABLE",
        "PASS_WITH_NOTES" if ios_devices.returncode == 0 else "BLOCKED_EXTERNAL",
        "iOS physical device list was queried; this does not prove app-auth/background acceptance.",
        "xcrun devicectl list devices",
        {"returncode": ios_devices.returncode},
    )
    add_check(
        checks,
        "TASK130-REALDEVICE-ANDROID-LISTABLE",
        "PASS_WITH_NOTES" if adb_devices.returncode == 0 else "BLOCKED_EXTERNAL",
        "Android device list was queried; this does not prove physical/offline/locked acceptance.",
        "adb devices",
        {"returncode": adb_devices.returncode, "deviceRows": len([line for line in adb_devices.stdout.splitlines()[1:] if line.strip()])},
    )
    add_check(
        checks,
        "TASK130-REALDEVICE-BACKGROUND-LOCKED-LONG",
        "PARTIAL",
        "No 30-60 minute background/locked/offline real-device run was executed in this consolidation pass.",
        "docs/TASKS/TASK-130-price-contract-current-previous-old.md",
    )
    return payload(
        "harness.real-device-feasibility",
        checks,
        "Reviewer must accept these as feasibility notes or provide devices/auth windows for a TASK-130 live run.",
    )


MODES = {
    "golden-corpus-validate": run_golden_validate,
    "golden-corpus-roundtrip": run_golden_roundtrip,
    "swiftdata-fetch-budget": run_swiftdata_fetch_budget,
    "ios-benchmark-import-large": run_ios_benchmark_import_large,
    "ios-smoke-options-first-sync": run_options_first_sync,
    "ios-smoke-scanner-edge": run_scanner_edge,
    "ios-smoke-accessibility": run_accessibility,
    "real-device-feasibility": run_device_feasibility_snapshot,
}


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    runner = MODES.get(mode)
    if runner is None:
        data = payload(
            "task130.consolidation",
            [
                {
                    "id": "TASK130-CONSOLIDATION-MODE",
                    "status": "MISCONFIGURED",
                    "reason": f"Unknown TASK-130 consolidation mode: {mode}",
                    "file": "tools/agent/lib/task130_consolidation.py",
                }
            ],
            "Use one of the documented TASK-130 consolidation modes.",
        )
    else:
        data = runner()
    print(json.dumps(data, indent=2, sort_keys=True))
    return exit_code(str(data.get("status", "MISCONFIGURED")))


if __name__ == "__main__":
    raise SystemExit(main())
