import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class CatalogGeneratedProductPriceSyncEventRecorderTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    private let ownerID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let productID = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!

    func testCatalogCurrentPriceColumnsWithoutRemotePriceRowsDoNotBlockVerifiedCatalogPush() async throws {
        let context = try makeContext()
        context.insert(Product(
            barcode: "TASK131-CATALOG-CURRENT-PRICE",
            remoteID: productID,
            productName: "Catalog current price only",
            purchasePrice: 10,
            retailPrice: 12
        ))
        try context.save()

        let result = try await CatalogGeneratedProductPriceSyncEventRecorder(
            context: context,
            remote: MockGeneratedPriceRemote(rows: [])
        ).recordIfNeeded(
            catalogResult: catalogResult(products: [productID]),
            ownerUserID: ownerID,
            planFingerprint: "catalog-current-price-only"
        )

        XCTAssertEqual(result.kind, .skippedNoOp)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SyncEventOutboxEntry>()).isEmpty)
    }

    func testRemoteGeneratedPriceRowsStillEnqueuePricesEvent() async throws {
        let context = try makeContext()
        context.insert(Product(
            barcode: "TASK131-CATALOG-GENERATED-PRICE",
            remoteID: productID,
            productName: "Catalog generated price",
            purchasePrice: 10,
            retailPrice: 12
        ))
        try context.save()

        let priceID = UUID(uuidString: "00000000-0000-4000-8000-000000000501")!
        let result = try await CatalogGeneratedProductPriceSyncEventRecorder(
            context: context,
            remote: MockGeneratedPriceRemote(rows: [
                RemoteInventoryProductPriceRow(
                    id: priceID,
                    ownerUserID: ownerID,
                    productID: productID,
                    type: "PURCHASE",
                    price: 10,
                    effectiveAt: "2026-05-12 13:00:00",
                    source: "TASK131",
                    note: nil,
                    createdAt: "2026-05-12 13:00:00"
                )
            ])
        ).recordIfNeeded(
            catalogResult: catalogResult(products: [productID]),
            ownerUserID: ownerID,
            planFingerprint: "catalog-generated-price"
        )

        XCTAssertEqual(result.kind, .enqueued)
        let entry = try XCTUnwrap(context.fetch(FetchDescriptor<SyncEventOutboxEntry>()).first)
        XCTAssertEqual(entry.domain, "prices")
        XCTAssertEqual(entry.eventType, "prices_changed")
        XCTAssertEqual(entry.changedCount, 1)
        XCTAssertEqual(entry.entityIDsShape, "price_rows:count=1;products:count=1")
        XCTAssertEqual(try entry.makeRecordRequestForReplay().source, "ios_catalog_generated_prices")
    }

    private func catalogResult(products: Set<UUID>) -> SupabaseManualPushResult {
        SupabaseManualPushResult(
            status: .completed,
            supplierCreates: 0,
            supplierUpdates: 0,
            supplierLinks: 0,
            categoryCreates: 0,
            categoryUpdates: 0,
            categoryLinks: 0,
            productCreates: products.count,
            productUpdates: 0,
            productLinks: 0,
            touchedIDs: SupabaseManualPushTouchedIDs(products: products),
            baselineRunID: nil,
            message: nil
        )
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Supplier.self,
            ProductCategory.self,
            Product.self,
            ProductPrice.self,
            SyncEventOutboxEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }
}

private actor MockGeneratedPriceRemote: SupabaseProductPricePushDryRunRemoteFetching {
    private let rows: [RemoteInventoryProductPriceRow]

    init(rows: [RemoteInventoryProductPriceRow]) {
        self.rows = rows
    }

    func fetchProductPricesForPushDryRunDedupePage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        let allowed = Set(productIDs)
        return rows.filter { $0.ownerUserID == ownerUserID && allowed.contains($0.productID) }
    }
}
