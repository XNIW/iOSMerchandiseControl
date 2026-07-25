import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class RecoveryRemoteSupabaseAdapterScopeTests: XCTestCase {
    func testAutomaticRecoveryRejectsForeignRowsFromEveryFetchBeforeReturningThem() async throws {
        let ownerUserID = UUID(uuidString: "13900000-0000-4000-8000-000000000001")!
        let shopID = UUID(uuidString: "13900000-0000-4000-8000-000000000002")!
        let fixture = try makeAutomaticScopeFixture(ownerUserID: ownerUserID, shopID: shopID)
        defer { fixture.cleanup() }

        let foreignOwnerUserID = UUID(uuidString: "13900000-0000-4000-8000-000000000003")!
        let foreignShopID = UUID(uuidString: "13900000-0000-4000-8000-000000000004")!
        let remote = RecoveryRemoteScopeFake(
            products: [makeProduct(ownerUserID: foreignOwnerUserID, shopID: shopID)],
            suppliers: [makeSupplier(ownerUserID: ownerUserID, shopID: foreignShopID)],
            categories: [makeCategory(ownerUserID: foreignOwnerUserID, shopID: shopID)],
            productPrices: [makeProductPrice(ownerUserID: ownerUserID, shopID: foreignShopID)]
        )
        let adapter = RecoveryRemoteSupabaseAdapter(catalog: remote, productPrice: remote)
        let lookupID = UUID(uuidString: "13900000-0000-4000-8000-000000000005")!

        await Task126OwnerStoreGate.withAutomaticScope(fixture.scope) {
            let products = await assertScopeChanged {
                try await adapter.fetchProductsPage(from: 0, to: 99)
            }
            let suppliers = await assertScopeChanged {
                try await adapter.fetchSuppliersPage(from: 0, to: 99)
            }
            let categories = await assertScopeChanged {
                try await adapter.fetchCategoriesPage(from: 0, to: 99)
            }
            let productPrices = await assertScopeChanged {
                try await adapter.fetchProductPricesPage(from: 0, to: 99)
            }
            let suppliersByID = await assertScopeChanged {
                try await adapter.fetchSuppliersByIDs([lookupID])
            }
            let categoriesByID = await assertScopeChanged {
                try await adapter.fetchCategoriesByIDs([lookupID])
            }

            XCTAssertNil(products)
            XCTAssertNil(suppliers)
            XCTAssertNil(categories)
            XCTAssertNil(productPrices)
            XCTAssertNil(suppliersByID)
            XCTAssertNil(categoriesByID)
        }

        XCTAssertEqual(
            remote.fetchCounts(),
            RecoveryRemoteScopeFetchCounts(
                products: 1,
                suppliers: 1,
                categories: 1,
                productPrices: 1,
                suppliersByID: 1,
                categoriesByID: 1
            )
        )
    }

    func testManualFetchWithoutAutomaticScopeReturnsRowsUnchanged() async throws {
        let ownerUserID = UUID(uuidString: "13900000-0000-4000-8000-000000000011")!
        let shopID = UUID(uuidString: "13900000-0000-4000-8000-000000000012")!
        let products = [makeProduct(ownerUserID: ownerUserID, shopID: shopID)]
        let suppliers = [makeSupplier(ownerUserID: ownerUserID, shopID: shopID)]
        let categories = [makeCategory(ownerUserID: ownerUserID, shopID: shopID)]
        let productPrices = [makeProductPrice(ownerUserID: ownerUserID, shopID: shopID)]
        let remote = RecoveryRemoteScopeFake(
            products: products,
            suppliers: suppliers,
            categories: categories,
            productPrices: productPrices
        )
        let adapter = RecoveryRemoteSupabaseAdapter(catalog: remote, productPrice: remote)

        let fetchedProducts = try await adapter.fetchProductsPage(from: 0, to: 99)
        let fetchedSuppliers = try await adapter.fetchSuppliersPage(from: 0, to: 99)
        let fetchedCategories = try await adapter.fetchCategoriesPage(from: 0, to: 99)
        let fetchedProductPrices = try await adapter.fetchProductPricesPage(from: 0, to: 99)
        let fetchedSuppliersByID = try await adapter.fetchSuppliersByIDs([suppliers[0].id])
        let fetchedCategoriesByID = try await adapter.fetchCategoriesByIDs([categories[0].id])

        XCTAssertEqual(fetchedProducts.map(\.id), products.map(\.id))
        XCTAssertEqual(fetchedSuppliers.map(\.id), suppliers.map(\.id))
        XCTAssertEqual(fetchedCategories.map(\.id), categories.map(\.id))
        XCTAssertEqual(fetchedProductPrices.map(\.id), productPrices.map(\.id))
        XCTAssertEqual(fetchedSuppliersByID.map(\.id), suppliers.map(\.id))
        XCTAssertEqual(fetchedCategoriesByID.map(\.id), categories.map(\.id))
    }

    func testDeletedProductValidationRejectsForeignRowBeforeIDExtraction() async throws {
        let ownerUserID = UUID(uuidString: "13900000-0000-4000-8000-000000000021")!
        let shopID = UUID(uuidString: "13900000-0000-4000-8000-000000000022")!
        let fixture = try makeAutomaticScopeFixture(ownerUserID: ownerUserID, shopID: shopID)
        defer { fixture.cleanup() }
        let foreignProduct = makeProduct(
            ownerUserID: ownerUserID,
            shopID: UUID(uuidString: "13900000-0000-4000-8000-000000000023")!,
            deletedAt: "2026-07-21T12:00:00Z"
        )
        var extractedIDs = Set<UUID>()

        await Task126OwnerStoreGate.withAutomaticScope(fixture.scope) {
            do {
                let rows = try Task126AutomaticRemoteRowValidator.validate(
                    [foreignProduct],
                    ownerUserID: \.ownerUserID,
                    shopID: \.shopID
                )
                extractedIDs.formUnion(
                    rows
                        .filter { SupabasePullPreviewNormalizer.semanticString($0.deletedAt) != nil }
                        .map(\.id)
                )
                XCTFail("Expected the foreign-shop row to be rejected before ID extraction.")
            } catch {
                XCTAssertEqual(error as? Task126OwnerStoreGateError, .scopeChanged)
            }
        }

        XCTAssertTrue(extractedIDs.isEmpty)
    }

    private func assertScopeChanged<Value>(
        _ operation: () async throws -> Value,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> Value? {
        do {
            let value = try await operation()
            XCTFail("Expected automatic owner/shop validation to reject the fetched rows.", file: file, line: line)
            return value
        } catch {
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .scopeChanged, file: file, line: line)
            return nil
        }
    }

    private func makeAutomaticScopeFixture(
        ownerUserID: UUID,
        shopID: UUID
    ) throws -> RecoveryRemoteAutomaticScopeFixture {
        let suiteName = "RecoveryRemoteSupabaseAdapterScopeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let shop = SelectedShop(
            shopID: shopID,
            code: "TASK139",
            name: "TASK-139 scope fixture",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedShopStore = SelectedShopStore(defaults: defaults)
        selectedShopStore.noteActiveAccount(accountHash)
        XCTAssertTrue(selectedShopStore.save(shop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaults
        )
        return RecoveryRemoteAutomaticScopeFixture(
            suiteName: suiteName,
            defaults: defaults,
            scope: scope
        )
    }

    private func makeProduct(
        ownerUserID: UUID,
        shopID: UUID,
        deletedAt: String? = nil
    ) -> RemoteInventoryProductRow {
        RemoteInventoryProductRow(
            id: UUID(),
            ownerUserID: ownerUserID,
            shopID: shopID,
            barcode: UUID().uuidString,
            itemNumber: nil,
            productName: "Scope product",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: deletedAt
        )
    }

    private func makeSupplier(ownerUserID: UUID, shopID: UUID) -> RemoteInventorySupplierRow {
        RemoteInventorySupplierRow(
            id: UUID(),
            ownerUserID: ownerUserID,
            shopID: shopID,
            name: "Scope supplier",
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: nil
        )
    }

    private func makeCategory(ownerUserID: UUID, shopID: UUID) -> RemoteInventoryCategoryRow {
        RemoteInventoryCategoryRow(
            id: UUID(),
            ownerUserID: ownerUserID,
            shopID: shopID,
            name: "Scope category",
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: nil
        )
    }

    private func makeProductPrice(ownerUserID: UUID, shopID: UUID) -> RemoteInventoryProductPriceRow {
        RemoteInventoryProductPriceRow(
            id: UUID(),
            ownerUserID: ownerUserID,
            shopID: shopID,
            productID: UUID(),
            type: "purchase",
            price: 1,
            effectiveAt: "2026-07-21T12:00:00Z",
            source: "TASK139",
            note: nil,
            createdAt: "2026-07-21T12:00:00Z"
        )
    }
}

private struct RecoveryRemoteAutomaticScopeFixture {
    let suiteName: String
    let defaults: UserDefaults
    let scope: Task126VerifiedOwnerStoreScope

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private struct RecoveryRemoteScopeFetchCounts: Sendable, Equatable {
    var products = 0
    var suppliers = 0
    var categories = 0
    var productPrices = 0
    var suppliersByID = 0
    var categoriesByID = 0
}

@MainActor
private final class RecoveryRemoteScopeFake:
    RecoveryCatalogRemoteFetching,
    RecoveryProductPriceRemoteFetching {
    private let products: [RemoteInventoryProductRow]
    private let suppliers: [RemoteInventorySupplierRow]
    private let categories: [RemoteInventoryCategoryRow]
    private let productPrices: [RemoteInventoryProductPriceRow]
    private var counts = RecoveryRemoteScopeFetchCounts()

    init(
        products: [RemoteInventoryProductRow],
        suppliers: [RemoteInventorySupplierRow],
        categories: [RemoteInventoryCategoryRow],
        productPrices: [RemoteInventoryProductPriceRow]
    ) {
        self.products = products
        self.suppliers = suppliers
        self.categories = categories
        self.productPrices = productPrices
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        counts.products += 1
        return products
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        counts.suppliers += 1
        return suppliers
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        counts.categories += 1
        return categories
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        counts.productPrices += 1
        return productPrices
    }

    func fetchSuppliersByIDs(_ ids: Set<UUID>) async throws -> [RemoteInventorySupplierRow] {
        counts.suppliersByID += 1
        return suppliers
    }

    func fetchCategoriesByIDs(_ ids: Set<UUID>) async throws -> [RemoteInventoryCategoryRow] {
        counts.categoriesByID += 1
        return categories
    }

    func fetchCounts() -> RecoveryRemoteScopeFetchCounts {
        counts
    }
}
