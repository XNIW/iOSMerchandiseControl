import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class ProductImageSyncContractTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testRemoteProductDTOReadsOnlyVersionReferenceAndTimestamp() throws {
        let productID = UUID()
        let ownerID = UUID()
        let shopID = UUID()
        let versionID = UUID()
        let payload = """
        {
          "id":"\(productID.uuidString)",
          "owner_user_id":"\(ownerID.uuidString)",
          "shop_id":"\(shopID.uuidString)",
          "barcode":"TASK137-DTO",
          "item_number":null,
          "product_name":"DTO product",
          "second_product_name":null,
          "purchase_price":null,
          "retail_price":12.5,
          "supplier_id":null,
          "category_id":null,
          "stock_quantity":3,
          "updated_at":"2026-07-17T10:00:00Z",
          "deleted_at":null,
          "primary_image_version_id":"\(versionID.uuidString)",
          "primary_image_updated_at":"2026-07-17T10:00:01Z"
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(RemoteInventoryProductRow.self, from: payload)

        XCTAssertEqual(row.primaryImageVersionID, versionID)
        XCTAssertEqual(row.primaryImageUpdatedAt, "2026-07-17T10:00:01Z")
        XCTAssertFalse(String(data: payload, encoding: .utf8)!.contains("signed"))
        XCTAssertFalse(String(data: payload, encoding: .utf8)!.contains("object_path"))
    }

    func testTargetedApplyPersistsImageReferenceAndRemoval() throws {
        let context = ModelContext(try makeContainer())
        let productID = UUID()
        let firstVersion = UUID()
        let product = Product(
            barcode: "TASK137-APPLY",
            remoteID: productID,
            productName: "Local product"
        )
        context.insert(product)
        try context.save()

        _ = try applyTargetedProduct(
            remoteRow(
                id: productID,
                barcode: product.barcode,
                productName: "Remote product",
                versionID: firstVersion,
                imageUpdatedAt: "2026-07-17T11:00:01Z"
            ),
            supplier: nil,
            category: nil,
            context: context
        )
        try context.save()

        XCTAssertEqual(product.primaryImageVersionID, firstVersion)
        XCTAssertEqual(product.productName, "Remote product")
        XCTAssertNotNil(product.primaryImageUpdatedAt)

        _ = try applyTargetedProduct(
            remoteRow(
                id: productID,
                barcode: product.barcode,
                productName: "Remote product",
                versionID: nil,
                imageUpdatedAt: "2026-07-17T11:05:01Z"
            ),
            supplier: nil,
            category: nil,
            context: context
        )
        try context.save()

        XCTAssertNil(product.primaryImageVersionID)
        XCTAssertEqual(
            product.primaryImageUpdatedAt,
            SupabaseRemoteDateParser.parse("2026-07-17T11:05:01Z")
        )
    }

    func testProtectedDirtyProductStillAcceptsRemoteImageReferenceOnly() throws {
        let context = ModelContext(try makeContainer())
        let productID = UUID()
        let oldVersion = UUID()
        let newVersion = UUID()
        let oldRemoteUpdatedAt = SupabaseRemoteDateParser.parse("2026-07-17T12:00:00Z")
        let product = Product(
            barcode: "TASK137-DIRTY",
            remoteID: productID,
            remoteUpdatedAt: oldRemoteUpdatedAt,
            primaryImageVersionID: oldVersion,
            productName: "Unsynced local edit"
        )
        context.insert(product)
        try context.save()

        let changed = try applyTargetedProductImageReference(
            remoteRow(
                id: productID,
                barcode: product.barcode,
                productName: "Remote business value",
                versionID: newVersion,
                imageUpdatedAt: "2026-07-17T12:01:00Z"
            ),
            context: context
        )
        try context.save()

        XCTAssertTrue(changed)
        XCTAssertEqual(product.primaryImageVersionID, newVersion)
        XCTAssertEqual(product.productName, "Unsynced local edit")
        XCTAssertEqual(product.remoteUpdatedAt, oldRemoteUpdatedAt)
    }

    func testRecoveryFingerprintTreatsImageOnlyChangeAsStale() {
        let productID = UUID()
        let oldVersion = UUID()
        let newVersion = UUID()
        let original = LocalProductSnapshot(
            barcode: "TASK137-FINGERPRINT",
            remoteID: productID,
            primaryImageVersionID: oldVersion,
            primaryImageUpdatedAt: Date(timeIntervalSince1970: 100)
        )
        let fingerprint = SupabasePullApplyProductFingerprint(snapshot: original)
        let changed = LocalProductSnapshot(
            barcode: original.barcode,
            remoteID: productID,
            primaryImageVersionID: newVersion,
            primaryImageUpdatedAt: Date(timeIntervalSince1970: 101)
        )

        XCTAssertFalse(fingerprint.matches(changed))
        XCTAssertTrue(fingerprint.matches(original))
    }

    func testNormalCatalogWritePayloadNeverContainsImageOrURLFields() throws {
        let payload = SupabaseManualPushProductUpdatePayload(
            barcode: "TASK137-WRITE",
            itemNumber: nil,
            productName: "Business edit",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: 10,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any]
        )

        XCTAssertNil(object["primary_image_version_id"])
        XCTAssertNil(object["primary_image_updated_at"])
        XCTAssertNil(object["signed_url"])
        XCTAssertNil(object["object_path"])
    }

    private func remoteRow(
        id: UUID,
        barcode: String,
        productName: String,
        versionID: UUID?,
        imageUpdatedAt: String?
    ) -> RemoteInventoryProductRow {
        RemoteInventoryProductRow(
            id: id,
            ownerUserID: UUID(),
            shopID: UUID(),
            barcode: barcode,
            itemNumber: nil,
            productName: productName,
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-07-17T12:02:00Z",
            deletedAt: nil,
            primaryImageVersionID: versionID,
            primaryImageUpdatedAt: imageUpdatedAt
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            SyncEventOutboxEntry.self,
            LocalPendingChange.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return container
    }
}
