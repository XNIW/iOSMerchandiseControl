#!/usr/bin/env python3
"""TASK-130 price contract scanners.

Static/read-only gates for the current/last/previous/old price contract across
iOS, Android, and local Supabase migrations.
"""

from __future__ import annotations

import datetime as dt
import json
import os
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


def migration_text() -> str:
    migrations = SUPABASE_REPO / "supabase" / "migrations"
    if not migrations.exists():
        migrations = SUPABASE_REPO / "migrations"
    if not migrations.exists():
        return ""
    return "\n".join(
        path.read_text(encoding="utf-8", errors="replace")
        for path in sorted(migrations.glob("*.sql"))
    )


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
    if "PASS_WITH_NOTES" in statuses:
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


def price_matrix() -> list[dict[str, object]]:
    return [
        {
            "concept": "current purchase price",
            "ios": "Product.purchasePrice",
            "android": "Product.purchasePrice / ProductWithDetails.currentPurchasePrice",
            "supabase": "inventory_products.purchase_price",
            "truth": "Product current field",
            "rule": "Do not derive current from ProductPrice history.",
            "import_export": "Products sheet current purchase field",
            "sync": "inventory_products.purchase_price",
            "status": "PASS",
        },
        {
            "concept": "current retail price",
            "ios": "Product.retailPrice",
            "android": "Product.retailPrice / ProductWithDetails.currentRetailPrice",
            "supabase": "inventory_products.retail_price",
            "truth": "Product current field",
            "rule": "Do not derive current from ProductPrice history.",
            "import_export": "Products sheet current retail field",
            "sync": "inventory_products.retail_price",
            "status": "PASS",
        },
        {
            "concept": "last purchase ProductPrice",
            "ios": "ProductPriceContract.lastPrice(..., .purchase)",
            "android": "ProductPriceSummary.lastPurchase",
            "supabase": "inventory_product_prices price/type/effective_at",
            "truth": "Latest purchase ProductPrice by effectiveAt",
            "rule": "Sort by effectiveAt descending, tie-break locally where available.",
            "import_export": "PriceHistory sheet or import-generated current event",
            "sync": "inventory_product_prices type=purchase/PURCHASE",
            "status": "PASS",
        },
        {
            "concept": "previous purchase ProductPrice",
            "ios": "ProductPriceContract.previousPrice(..., .purchase)",
            "android": "ProductPriceSummary.prevPurchase",
            "supabase": "inventory_product_prices price/type/effective_at",
            "truth": "Penultimate purchase ProductPrice by effectiveAt",
            "rule": "Second event after sorting history descending.",
            "import_export": "oldPurchasePrice maps to previous/import snapshot, not current",
            "sync": "history row remains append-only",
            "status": "PASS",
        },
        {
            "concept": "last retail ProductPrice",
            "ios": "ProductPriceContract.lastPrice(..., .retail)",
            "android": "ProductPriceSummary.lastRetail",
            "supabase": "inventory_product_prices price/type/effective_at",
            "truth": "Latest retail ProductPrice by effectiveAt",
            "rule": "Sort by effectiveAt descending, tie-break locally where available.",
            "import_export": "PriceHistory sheet or import-generated current event",
            "sync": "inventory_product_prices type=retail/RETAIL",
            "status": "PASS",
        },
        {
            "concept": "previous retail ProductPrice",
            "ios": "ProductPriceContract.previousPrice(..., .retail)",
            "android": "ProductPriceSummary.prevRetail",
            "supabase": "inventory_product_prices price/type/effective_at",
            "truth": "Penultimate retail ProductPrice by effectiveAt",
            "rule": "Second event after sorting history descending.",
            "import_export": "oldRetailPrice maps to previous/import snapshot, not current",
            "sync": "history row remains append-only",
            "status": "PASS",
        },
        {
            "concept": "oldPurchasePrice import/grid",
            "ios": "ProductDraft.oldPurchasePrice / generated grid oldPurchasePrice",
            "android": "Product.oldPurchasePrice / generated grid oldPurchasePrice",
            "supabase": "No inventory_products old purchase column",
            "truth": "Import or PreGenerate snapshot only",
            "rule": "Never use as remote current source of truth.",
            "import_export": "Can create IMPORT_PREV history or export previous snapshot",
            "sync": "Not a primary remote Product column",
            "status": "PASS",
        },
        {
            "concept": "oldRetailPrice import/grid",
            "ios": "ProductDraft.oldRetailPrice / generated grid oldRetailPrice",
            "android": "Product.oldRetailPrice / generated grid oldRetailPrice",
            "supabase": "No inventory_products old retail column",
            "truth": "Import or PreGenerate snapshot only",
            "rule": "Never use as remote current source of truth.",
            "import_export": "Can create IMPORT_PREV history or export previous snapshot",
            "sync": "Not a primary remote Product column",
            "status": "PASS",
        },
        {
            "concept": "PreGenerate old price snapshot",
            "ios": "ExcelSessionViewModel.fetchOldPricesByBarcode uses Product current fields",
            "android": "ExcelViewModel current-price snapshot",
            "supabase": "N/A local generated grid",
            "truth": "Current DB Product price at generation time",
            "rule": "Snapshot remains grid/input state, not remote current.",
            "import_export": "Generated old columns",
            "sync": "No direct remote write from old columns",
            "status": "PASS",
        },
        {
            "concept": "ProductPrice effectiveAt/effective_at",
            "ios": "ProductPrice.effectiveAt",
            "android": "ProductPrice.effectiveAt",
            "supabase": "inventory_product_prices.effective_at",
            "truth": "History ordering key",
            "rule": "Latest/previous are computed per type/effectiveAt.",
            "import_export": "PriceHistory timestamp",
            "sync": "effective_at remote column",
            "status": "PASS",
        },
        {
            "concept": "source/origin import/manual/sync",
            "ios": "ProductPrice.source",
            "android": "ProductPrice.source",
            "supabase": "inventory_product_prices.source",
            "truth": "Audit metadata only",
            "rule": "Source does not override current/previous ordering rules.",
            "import_export": "IMPORT_EXCEL/IMPORT_PREV or IMPORT/IMPORT_PREV",
            "sync": "manual/import/sync origin metadata",
            "status": "PASS",
        },
    ]


def run_scan_price_contract() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    models = read(IOS_REPO, "iOSMerchandiseControl/Models.swift")
    database = read(IOS_REPO, "iOSMerchandiseControl/DatabaseView.swift")
    history_view = read(IOS_REPO, "iOSMerchandiseControl/ProductPriceHistoryView.swift")
    import_core = read(IOS_REPO, "iOSMerchandiseControl/ProductImportCore.swift")
    pregenerate = read(IOS_REPO, "iOSMerchandiseControl/ExcelSessionViewModel.swift")
    ios_tests = read(IOS_REPO, "iOSMerchandiseControlTests/Task130PriceContractTests.swift")
    android_details = read(
        ANDROID_REPO,
        "app/src/main/java/com/example/merchandisecontrolsplitview/data/ProductWithDetails.kt",
    )
    android_summary = read(
        ANDROID_REPO,
        "app/src/main/java/com/example/merchandisecontrolsplitview/data/ProductPriceSummary.kt",
    )
    android_repo = read(
        ANDROID_REPO,
        "app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt",
    )
    android_tests = read(
        ANDROID_REPO,
        "app/src/test/java/com/example/merchandisecontrolsplitview/data/Task130PriceContractTest.kt",
    )
    migrations = migration_text()

    add_check(
        checks,
        "TASK130-IOS-CONTRACT-HELPER",
        "PASS" if "enum ProductPriceContract" in models else "FAIL",
        "iOS has a single helper for current/last/previous price semantics.",
        "iOSMerchandiseControl/Models.swift",
    )
    add_check(
        checks,
        "TASK130-IOS-CURRENT-PRODUCT-FIELD",
        "PASS"
        if "currentPrice(for product: Product" in models
        and "return product.purchasePrice" in models
        and "return product.retailPrice" in models
        else "FAIL",
        "iOS current price resolves from Product current fields.",
        "iOSMerchandiseControl/Models.swift",
    )
    add_check(
        checks,
        "TASK130-IOS-EXPORT-CURRENT",
        "PASS"
        if "ProductPriceContract.currentPrice" in database and "history.dropFirst().first?.price" in database
        else "FAIL",
        "iOS DB export uses Product current field and previous history row.",
        "iOSMerchandiseControl/DatabaseView.swift",
    )
    add_check(
        checks,
        "TASK130-IOS-HISTORY-UI-CURRENT",
        "PASS" if "ProductPriceContract.currentPrice" in history_view else "FAIL",
        "iOS price history UI displays current from Product field.",
        "iOSMerchandiseControl/ProductPriceHistoryView.swift",
    )
    add_check(
        checks,
        "TASK130-IOS-IMPORT-OLD-PREVIOUS",
        "PASS" if "IMPORT_PREV" in import_core and "oldPurchasePrice" in import_core else "FAIL",
        "iOS import old fields are previous/import snapshots.",
        "iOSMerchandiseControl/ProductImportCore.swift",
    )
    add_check(
        checks,
        "TASK130-IOS-PREGENERATE-SNAPSHOT",
        "PASS"
        if "map[product.barcode] = (product.purchasePrice, product.retailPrice)" in pregenerate
        else "FAIL",
        "iOS PreGenerate old prices snapshot Product current fields.",
        "iOSMerchandiseControl/ExcelSessionViewModel.swift",
    )
    add_check(
        checks,
        "TASK130-IOS-TESTS",
        "PASS"
        if "Task130PriceContractTests" in ios_tests
        and "testImportOldFieldsBecomePreviousHistoryNotCurrent" in ios_tests
        else "FAIL",
        "iOS targeted price-contract tests are present.",
        "iOSMerchandiseControlTests/Task130PriceContractTests.swift",
    )
    add_check(
        checks,
        "TASK130-ANDROID-CURRENT-PRODUCT-FIELD",
        "PASS"
        if "get() = product.purchasePrice" in android_details
        and "get() = product.retailPrice" in android_details
        and "lastPurchase ?: product.purchasePrice" not in android_details
        and "lastRetail ?: product.retailPrice" not in android_details
        else "FAIL",
        "Android current price resolves from Product current fields, not summary fallback.",
        "app/src/main/java/com/example/merchandisecontrolsplitview/data/ProductWithDetails.kt",
    )
    add_check(
        checks,
        "TASK130-ANDROID-LAST-PREVIOUS",
        "PASS" if "lastPurchase" in android_summary and "prevPurchase" in android_summary else "FAIL",
        "Android ProductPriceSummary exposes last/previous history by type/effectiveAt.",
        "app/src/main/java/com/example/merchandisecontrolsplitview/data/ProductPriceSummary.kt",
    )
    add_check(
        checks,
        "TASK130-ANDROID-IMPORT-OLD-PREVIOUS",
        "PASS"
        if 'record("PURCHASE", product.oldPurchasePrice' in android_repo
        and 'record("RETAIL", product.oldRetailPrice' in android_repo
        else "FAIL",
        "Android import old fields create previous history rows.",
        "app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt",
    )
    add_check(
        checks,
        "TASK130-ANDROID-TESTS",
        "PASS"
        if "Task130PriceContractTest" in android_tests
        and "history-only remote row does not override current product field" in android_tests
        else "FAIL",
        "Android targeted price-contract tests are present.",
        "app/src/test/java/com/example/merchandisecontrolsplitview/data/Task130PriceContractTest.kt",
    )
    add_check(
        checks,
        "TASK130-SUPABASE-PRODUCT-CURRENT",
        "PASS"
        if "inventory_products" in migrations
        and "purchase_price" in migrations
        and "retail_price" in migrations
        else "FAIL",
        "Supabase inventory_products has current purchase/retail columns.",
        "supabase/migrations/*.sql",
    )
    add_check(
        checks,
        "TASK130-SUPABASE-PRICE-HISTORY",
        "PASS"
        if "inventory_product_prices" in migrations
        and "effective_at" in migrations
        and "source" in migrations
        and "type" in migrations
        else "FAIL",
        "Supabase inventory_product_prices has price/type/effective_at/source columns.",
        "supabase/migrations/*.sql",
    )

    status = status_from_checks(checks)
    return {
        "schema_version": SCHEMA_VERSION,
        "schemaVersion": SCHEMA_VERSION,
        "task_id": TASK_ID,
        "taskId": TASK_ID,
        "source": "scan.price-contract",
        "scan": "price-contract",
        "status": status,
        "result_status": status,
        "summary": f"price-contract: {status} ({len(checks)} checks)",
        "started_at": now(),
        "completed_at": now(),
        "safety_level": "read_only_static_scan",
        "strict": "--strict" in sys.argv,
        "checks": checks,
        "price_contract_matrix": price_matrix(),
        "NEXT_ACTION": "Run targeted iOS/Android price-contract tests and Supabase price-schema contract.",
    }


def run_supabase_price_schema() -> dict[str, object]:
    checks: list[dict[str, object]] = []
    migrations = migration_text()
    add_check(
        checks,
        "TASK130-SB-READONLY-MIGRATIONS-FOUND",
        "PASS" if migrations else "BLOCKED_EXTERNAL",
        "Local Supabase migrations were read without applying SQL.",
        "supabase/migrations/*.sql",
    )
    for check_id, table, columns in [
        (
            "TASK130-SB-INVENTORY-PRODUCTS-CURRENT",
            "inventory_products",
            ["purchase_price", "retail_price"],
        ),
        (
            "TASK130-SB-INVENTORY-PRODUCT-PRICES-HISTORY",
            "inventory_product_prices",
            ["price", "type", "effective_at", "source", "created_at"],
        ),
    ]:
        missing = [column for column in columns if column not in migrations]
        add_check(
            checks,
            check_id,
            "PASS" if table in migrations and not missing else "FAIL",
            f"{table} contains required TASK-130 price contract columns.",
            "supabase/migrations/*.sql",
            {"missing": missing},
        )
    status = status_from_checks(checks)
    return {
        "schema_version": SCHEMA_VERSION,
        "schemaVersion": SCHEMA_VERSION,
        "task_id": TASK_ID,
        "taskId": TASK_ID,
        "source": "supabase.contract.price-schema",
        "scan": "supabase-price-schema",
        "status": status,
        "result_status": status,
        "summary": f"supabase price-schema: {status} ({len(checks)} checks)",
        "started_at": now(),
        "completed_at": now(),
        "safety_level": "read_only_static_scan",
        "requires_live": False,
        "checks": checks,
        "NEXT_ACTION": "Use this read-only schema contract in TASK-130 evidence.",
    }


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "scan-price-contract"
    if mode == "scan-price-contract":
        payload = run_scan_price_contract()
    elif mode == "supabase-price-schema":
        payload = run_supabase_price_schema()
    else:
        payload = {
            "schema_version": SCHEMA_VERSION,
            "task_id": TASK_ID,
            "source": "task130.price-contract",
            "status": "MISCONFIGURED",
            "result_status": "MISCONFIGURED",
            "summary": f"Unknown TASK-130 scanner mode: {mode}",
            "started_at": now(),
            "completed_at": now(),
            "checks": [],
            "NEXT_ACTION": "Use scan-price-contract or supabase-price-schema.",
        }
    print(json.dumps(payload, indent=2, sort_keys=True))
    return exit_code(str(payload.get("status", "MISCONFIGURED")))


if __name__ == "__main__":
    raise SystemExit(main())
