import XCTest
@testable import iOSMerchandiseControl

final class Task097RuntimeSmokeTests: XCTestCase {
    private let suffix = "R1778437271"
    private let priceTolerance = 0.005

    func testTask097RuntimeSandboxReadBackEvidence() async throws {
        // Read-only by design: TASK097 rows remain in Supabase as review evidence.
        guard ProcessInfo.processInfo.environment["TASK097_RUNTIME_SMOKE"] == "1" else {
            throw XCTSkip("Set TASK097_RUNTIME_SMOKE=1 to run the live TASK-097 Supabase read-back smoke.")
        }

        let config = try SupabaseConfig.load()
        let inventory = SupabaseInventoryService(
            clientProvider: SupabaseClientProvider(config: config)
        )

        let suppliers = try await fetchAllSuppliers(inventory)
        let categories = try await fetchAllCategories(inventory)
        let products = try await fetchAllProducts(inventory)

        let supplierName = "TASK097_SUPPLIER_RUNTIME_SANDBOX_\(suffix)"
        let categoryName = "TASK097_CATEGORY_RUNTIME_SANDBOX_\(suffix)"
        let barcodeA = "TASK097_BAR_A_20260510_\(suffix)"
        let barcodeB = "TASK097_BAR_B_20260510_\(suffix)"

        let supplier = try XCTUnwrap(
            suppliers.singleActiveRow { $0.name == supplierName },
            "Expected one active TASK-097 supplier for \(suffix)"
        )
        let category = try XCTUnwrap(
            categories.singleActiveRow { $0.name == categoryName },
            "Expected one active TASK-097 category for \(suffix)"
        )
        let productA = try XCTUnwrap(
            products.singleActiveRow { $0.barcode == barcodeA },
            "Expected one active TASK-097 Product A for \(suffix)"
        )
        let productB = try XCTUnwrap(
            products.singleActiveRow { $0.barcode == barcodeB },
            "Expected one active TASK-097 Product B for \(suffix)"
        )

        XCTAssertEqual(supplier.ownerUserID, category.ownerUserID)
        XCTAssertEqual(productA.ownerUserID, supplier.ownerUserID)
        XCTAssertEqual(productB.ownerUserID, supplier.ownerUserID)
        XCTAssertEqual(productA.supplierID, supplier.id)
        XCTAssertEqual(productA.categoryID, category.id)
        XCTAssertEqual(productB.supplierID, supplier.id)
        XCTAssertEqual(productB.categoryID, category.id)
        XCTAssertEqual(productA.productName, "TASK097_PRODUCT_A_PULL_BASELINE_\(suffix)")
        XCTAssertEqual(productB.productName, "TASK097_PRODUCT_B_LOCAL_PUSH_\(suffix)")
        XCTAssertPrice(productB.purchasePrice, equals: 35.55, label: "Product B catalog purchase")
        XCTAssertPrice(productB.retailPrice, equals: 70.70, label: "Product B catalog retail")

        let prices = try await fetchAllPrices(inventory, ownerUserID: supplier.ownerUserID, productIDs: [productA.id, productB.id])
        XCTAssertEqual(prices.count, 8)
        XCTAssertTrue(prices.allSatisfy { $0.ownerUserID == supplier.ownerUserID })

        assertPriceHistory(
            prices,
            productID: productA.id,
            type: "PURCHASE",
            expected: [
                ExpectedPrice(price: 11.11, effectiveAt: "2026-05-10 10:00:00"),
                ExpectedPrice(price: 12.34, effectiveAt: "2026-05-10 10:05:00")
            ]
        )
        assertPriceHistory(
            prices,
            productID: productA.id,
            type: "RETAIL",
            expected: [
                ExpectedPrice(price: 22.22, effectiveAt: "2026-05-10 10:10:00"),
                ExpectedPrice(price: 24.68, effectiveAt: "2026-05-10 10:15:00")
            ]
        )
        assertPriceHistory(
            prices,
            productID: productB.id,
            type: "PURCHASE",
            expected: [
                ExpectedPrice(price: 33.33, effectiveAt: "2026-05-10 10:20:00"),
                ExpectedPrice(price: 35.55, effectiveAt: "2026-05-10 10:30:00")
            ]
        )
        assertPriceHistory(
            prices,
            productID: productB.id,
            type: "RETAIL",
            expected: [
                ExpectedPrice(price: 66.66, effectiveAt: "2026-05-10 10:25:00"),
                ExpectedPrice(price: 70.70, effectiveAt: "2026-05-10 10:35:00")
            ]
        )
    }

    private func fetchAllSuppliers(_ inventory: SupabaseInventoryService) async throws -> [RemoteInventorySupplierRow] {
        var rows: [RemoteInventorySupplierRow] = []
        for page in 0..<25 {
            let pageRows = try await inventory.fetchSuppliersPage(from: page * 1_000, to: page * 1_000 + 999)
            rows.append(contentsOf: pageRows)
            if pageRows.count < 1_000 { break }
        }
        return rows
    }

    private func fetchAllCategories(_ inventory: SupabaseInventoryService) async throws -> [RemoteInventoryCategoryRow] {
        var rows: [RemoteInventoryCategoryRow] = []
        for page in 0..<25 {
            let pageRows = try await inventory.fetchCategoriesPage(from: page * 1_000, to: page * 1_000 + 999)
            rows.append(contentsOf: pageRows)
            if pageRows.count < 1_000 { break }
        }
        return rows
    }

    private func fetchAllProducts(_ inventory: SupabaseInventoryService) async throws -> [RemoteInventoryProductRow] {
        var rows: [RemoteInventoryProductRow] = []
        for page in 0..<25 {
            let pageRows = try await inventory.fetchProductsPage(from: page * 1_000, to: page * 1_000 + 999)
            rows.append(contentsOf: pageRows)
            if pageRows.count < 1_000 { break }
        }
        return rows
    }

    private func fetchAllPrices(
        _ inventory: SupabaseInventoryService,
        ownerUserID: UUID,
        productIDs: [UUID]
    ) async throws -> [RemoteInventoryProductPriceRow] {
        var rows: [RemoteInventoryProductPriceRow] = []
        for page in 0..<5 {
            let pageRows = try await inventory.fetchProductPricesForManualPushVerificationPage(
                ownerUserID: ownerUserID,
                productIDs: productIDs,
                from: page * 1_000,
                to: page * 1_000 + 999
            )
            rows.append(contentsOf: pageRows)
            if pageRows.count < 1_000 { break }
        }
        return rows
    }

    private func assertPriceHistory(
        _ prices: [RemoteInventoryProductPriceRow],
        productID: UUID,
        type: String,
        expected: [ExpectedPrice],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let rows = prices
            .filter { $0.productID == productID && $0.type.uppercased() == type }
            .sorted { canonicalEffectiveAt($0.effectiveAt) < canonicalEffectiveAt($1.effectiveAt) }

        XCTAssertEqual(rows.count, expected.count, file: file, line: line)
        XCTAssertEqual(Set(rows.map { canonicalEffectiveAt($0.effectiveAt) }).count, rows.count, file: file, line: line)

        for (row, expected) in zip(rows, expected) {
            XCTAssertPrice(row.price, equals: expected.price, label: "\(type) \(expected.effectiveAt)", file: file, line: line)
            XCTAssertEqual(canonicalEffectiveAt(row.effectiveAt), expected.effectiveAt, file: file, line: line)
        }
    }

    private func XCTAssertPrice(
        _ actual: Double?,
        equals expected: Double,
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("\(label) missing", file: file, line: line)
            return
        }
        XCTAssertLessThanOrEqual(abs(actual - expected), priceTolerance, label, file: file, line: line)
    }

    private func canonicalEffectiveAt(_ value: String) -> String {
        String(value.replacingOccurrences(of: "T", with: " ").prefix(19))
    }

    private struct ExpectedPrice {
        let price: Double
        let effectiveAt: String
    }
}

private extension Array where Element == RemoteInventorySupplierRow {
    func singleActiveRow(where predicate: (RemoteInventorySupplierRow) -> Bool) -> RemoteInventorySupplierRow? {
        let matches = filter { $0.deletedAt == nil && predicate($0) }
        return matches.count == 1 ? matches[0] : nil
    }
}

private extension Array where Element == RemoteInventoryCategoryRow {
    func singleActiveRow(where predicate: (RemoteInventoryCategoryRow) -> Bool) -> RemoteInventoryCategoryRow? {
        let matches = filter { $0.deletedAt == nil && predicate($0) }
        return matches.count == 1 ? matches[0] : nil
    }
}

private extension Array where Element == RemoteInventoryProductRow {
    func singleActiveRow(where predicate: (RemoteInventoryProductRow) -> Bool) -> RemoteInventoryProductRow? {
        let matches = filter { $0.deletedAt == nil && predicate($0) }
        return matches.count == 1 ? matches[0] : nil
    }
}
