import XCTest
@testable import iOSMerchandiseControl

final class SupabasePullPreviewDiffEngineTests: XCTestCase {
    private let ownerID = UUID()

    func testRemoteProductWithUnknownBarcodeIsNewProduct() {
        let preview = makePreview(
            remote: remoteSnapshot(products: [
                remoteProduct(barcode: " 12345 ", name: "Remote product")
            ]),
            local: localSnapshot()
        )

        XCTAssertEqual(preview.newProducts.count, 1)
        XCTAssertEqual(preview.newProducts.first?.barcode, "12345")
        XCTAssertTrue(preview.updateCandidates.isEmpty)
        XCTAssertTrue(preview.conflicts.isEmpty)
    }

    func testMatchedProductWithPriceOrNameDifferenceIsUpdateCandidate() {
        let preview = makePreview(
            remote: remoteSnapshot(products: [
                remoteProduct(
                    barcode: "12345",
                    name: "Remote product",
                    purchasePrice: 2.50
                )
            ]),
            local: localSnapshot(products: [
                localProduct(
                    barcode: "12345",
                    name: "Local product",
                    purchasePrice: 2.00
                )
            ])
        )

        XCTAssertEqual(preview.updateCandidates.count, 1)
        let fields = Set(preview.updateCandidates[0].fieldChanges.map(\.fieldKey))
        XCTAssertTrue(fields.contains(.productName))
        XCTAssertTrue(fields.contains(.purchasePrice))
    }

    func testDuplicateActiveRemoteBarcodeIsConflict() {
        let preview = makePreview(
            remote: remoteSnapshot(products: [
                remoteProduct(barcode: "12345", name: "First"),
                remoteProduct(barcode: " 12345 ", name: "Second")
            ]),
            local: localSnapshot()
        )

        XCTAssertTrue(preview.newProducts.isEmpty)
        XCTAssertEqual(preview.conflicts.count, 1)
        XCTAssertEqual(preview.conflicts.first?.kind, .remoteDuplicateBarcode)
    }

    func testRemoteEmptyBarcodeIsConflictAndNotNewProduct() {
        let preview = makePreview(
            remote: remoteSnapshot(products: [
                remoteProduct(barcode: "   ", name: "Remote product")
            ]),
            local: localSnapshot()
        )

        XCTAssertTrue(preview.newProducts.isEmpty)
        XCTAssertEqual(preview.conflicts.count, 1)
        XCTAssertEqual(preview.conflicts.first?.kind, .remoteEmptyBarcode)
        XCTAssertTrue(preview.warnings.contains { $0.code == .remoteEmptyBarcode })
    }

    func testNewProductWithMissingRemoteSupplierOrCategoryIsConflictAndNotNewProduct() {
        let supplierID = UUID()
        let categoryID = UUID()
        let preview = makePreview(
            remote: remoteSnapshot(products: [
                remoteProduct(
                    barcode: "12345",
                    name: "Remote product",
                    supplierID: supplierID,
                    categoryID: categoryID
                )
            ]),
            local: localSnapshot()
        )

        XCTAssertTrue(preview.newProducts.isEmpty)
        XCTAssertTrue(preview.updateCandidates.isEmpty)
        XCTAssertEqual(Set(preview.conflicts.map(\.kind)), [.missingRemoteSupplier, .missingRemoteCategory])
    }

    func testRemoteDeletedAtCreatesTombstoneOnly() {
        let preview = makePreview(
            remote: remoteSnapshot(products: [
                remoteProduct(
                    barcode: "12345",
                    name: "Remote product",
                    deletedAt: "2026-05-04T10:00:00Z"
                )
            ]),
            local: localSnapshot(products: [
                localProduct(barcode: "12345", name: "Local product")
            ])
        )

        XCTAssertEqual(preview.remoteTombstones.count, 1)
        XCTAssertTrue(preview.newProducts.isEmpty)
        XCTAssertTrue(preview.updateCandidates.isEmpty)
    }

    func testSupplierSourceErrorProducesPartialWithoutSupplierFieldConflict() {
        let supplierID = UUID()
        let preview = makePreview(
            remote: remoteSnapshot(
                products: [
                    remoteProduct(
                        barcode: "12345",
                        name: "Remote product",
                        supplierID: supplierID
                    )
                ],
                sourceErrors: [
                    SyncPreviewWarning(
                        code: .sourceError,
                        detail: "inventory_suppliers",
                        relatedKey: "inventory_suppliers"
                    )
                ]
            ),
            local: localSnapshot(products: [
                localProduct(
                    barcode: "12345",
                    name: "Remote product",
                    supplierName: "Local supplier"
                )
            ]),
            outcome: .partial
        )

        XCTAssertEqual(preview.outcome, .partial)
        XCTAssertEqual(preview.sourceErrors.count, 1)
        XCTAssertEqual(preview.unchangedProducts.count, 1)
        XCTAssertTrue(preview.conflicts.isEmpty)
        XCTAssertTrue(preview.updateCandidates.isEmpty)
    }

    func testProductPricesBudgetWarningDoesNotFailCatalogPreview() {
        let productID = UUID()
        let preview = makePreview(
            remote: remoteSnapshot(
                products: [
                    remoteProduct(id: productID, barcode: "12345", name: "Remote product")
                ],
                productPrices: [
                    remotePrice(productID: productID, type: "PURCHASE", price: 2.00, effectiveAt: "2026-05-04 00:00:00")
                ],
                sourceErrors: [
                    SyncPreviewWarning(
                        code: .priceHistoryIncomplete,
                        detail: "inventory_product_prices",
                        relatedKey: "inventory_product_prices"
                    )
                ]
            ),
            local: localSnapshot(products: [
                localProduct(barcode: "12345", name: "Remote product")
            ])
        )

        XCTAssertEqual(preview.outcome, .success)
        XCTAssertTrue(preview.sourceErrors.contains { $0.code == .priceHistoryIncomplete })
        XCTAssertEqual(preview.unchangedProducts.count, 1)
    }

    func testRemoteProductPriceDiffStaysInPreviewOnly() {
        let productID = UUID()
        let preview = makePreview(
            remote: remoteSnapshot(
                products: [
                    remoteProduct(id: productID, barcode: "12345", name: "Remote product")
                ],
                productPrices: [
                    remotePrice(productID: productID, type: "PURCHASE", price: 3.00, effectiveAt: "2026-05-04 00:00:00")
                ]
            ),
            local: localSnapshot(
                products: [
                    localProduct(barcode: "12345", name: "Remote product")
                ],
                prices: [
                    localPrice(barcode: "12345", type: "purchase", price: 2.50, effectiveAt: "2026-05-04 00:00:00")
                ]
            )
        )

        XCTAssertEqual(preview.unchangedProducts.count, 1)
        XCTAssertTrue(preview.updateCandidates.isEmpty)
        XCTAssertEqual(preview.priceHistoryDiffs.count, 1)
        XCTAssertEqual(preview.priceHistoryDiffs.first?.fieldKey, .priceHistory)
    }

    func testNormalizationForEmptyStringsLookupNamesAndDoubleTolerance() {
        let supplierID = UUID()
        let categoryID = UUID()
        let preview = makePreview(
            remote: remoteSnapshot(
                products: [
                    remoteProduct(
                        barcode: " 12345 ",
                        itemNumber: "",
                        name: "Remote product",
                        purchasePrice: 10.0004,
                        supplierID: supplierID,
                        categoryID: categoryID
                    )
                ],
                suppliers: [
                    remoteSupplier(id: supplierID, name: " Supplier ")
                ],
                categories: [
                    remoteCategory(id: categoryID, name: "Shelf")
                ]
            ),
            local: localSnapshot(products: [
                localProduct(
                    barcode: "12345",
                    itemNumber: nil,
                    name: "Remote product",
                    purchasePrice: 10.0,
                    supplierName: "supplier",
                    categoryName: " shelf "
                )
            ])
        )

        XCTAssertEqual(preview.unchangedProducts.count, 1)
        XCTAssertTrue(preview.updateCandidates.isEmpty)
        XCTAssertTrue(preview.conflicts.isEmpty)
    }

    private func makePreview(
        remote: RemoteInventorySnapshot,
        local: LocalInventorySnapshot,
        outcome: SyncPreviewOutcome = .success
    ) -> SyncPreview {
        SupabasePullPreviewDiffEngine.makePreview(
            remote: remote,
            local: local,
            outcome: outcome
        )
    }

    private func remoteSnapshot(
        products: [RemoteInventoryProductRow],
        suppliers: [RemoteInventorySupplierRow] = [],
        categories: [RemoteInventoryCategoryRow] = [],
        productPrices: [RemoteInventoryProductPriceRow] = [],
        sourceErrors: [SyncPreviewWarning] = []
    ) -> RemoteInventorySnapshot {
        RemoteInventorySnapshot(
            products: products,
            suppliers: suppliers,
            categories: categories,
            productPrices: productPrices,
            sourceErrors: sourceErrors
        )
    }

    private func localSnapshot(
        products: [LocalProductSnapshot] = [],
        prices: [LocalPriceSnapshot] = []
    ) -> LocalInventorySnapshot {
        let productsByBarcode = Dictionary(
            uniqueKeysWithValues: products.compactMap { product in
                SupabasePullPreviewNormalizer.normalizedBarcode(product.barcode).map { ($0, product) }
            }
        )
        let pricesByKey: [PriceHistoryLogicalKey: LocalPriceSnapshot] = Dictionary(
            uniqueKeysWithValues: prices.compactMap { price in
                guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(price.barcode),
                      let type = SupabasePullPreviewNormalizer.normalizedPriceType(price.type),
                      let effectiveAt = SupabasePullPreviewNormalizer.normalizedEffectiveAt(price.effectiveAt) else {
                    return nil
                }
                return (
                    PriceHistoryLogicalKey(
                        barcode: barcode,
                        type: type,
                        effectiveAt: effectiveAt
                    ),
                    price
                )
            }
        )

        return LocalInventorySnapshot(
            productsByBarcode: productsByBarcode,
            suppliersByNormalizedName: [:],
            categoriesByNormalizedName: [:],
            priceHistoryByLogicalKey: pricesByKey,
            counts: LocalInventorySnapshotCounts(
                products: products.count,
                suppliers: 0,
                categories: 0,
                productPrices: prices.count
            ),
            duplicateProductBarcodes: [],
            duplicateSupplierNames: [],
            duplicateCategoryNames: []
        )
    }

    private func remoteProduct(
        id: UUID = UUID(),
        barcode: String,
        itemNumber: String? = nil,
        name: String?,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil,
        stockQuantity: Double? = nil,
        supplierID: UUID? = nil,
        categoryID: UUID? = nil,
        deletedAt: String? = nil
    ) -> RemoteInventoryProductRow {
        RemoteInventoryProductRow(
            id: id,
            ownerUserID: ownerID,
            barcode: barcode,
            itemNumber: itemNumber,
            productName: name,
            secondProductName: nil,
            purchasePrice: purchasePrice,
            retailPrice: retailPrice,
            supplierID: supplierID,
            categoryID: categoryID,
            stockQuantity: stockQuantity,
            updatedAt: "2026-05-04T00:00:00Z",
            deletedAt: deletedAt
        )
    }

    private func remoteSupplier(id: UUID, name: String) -> RemoteInventorySupplierRow {
        RemoteInventorySupplierRow(
            id: id,
            ownerUserID: ownerID,
            name: name,
            updatedAt: "2026-05-04T00:00:00Z",
            deletedAt: nil
        )
    }

    private func remoteCategory(id: UUID, name: String) -> RemoteInventoryCategoryRow {
        RemoteInventoryCategoryRow(
            id: id,
            ownerUserID: ownerID,
            name: name,
            updatedAt: "2026-05-04T00:00:00Z",
            deletedAt: nil
        )
    }

    private func remotePrice(
        id: UUID = UUID(),
        productID: UUID,
        type: String,
        price: Double,
        effectiveAt: String
    ) -> RemoteInventoryProductPriceRow {
        RemoteInventoryProductPriceRow(
            id: id,
            ownerUserID: ownerID,
            productID: productID,
            type: type,
            price: price,
            effectiveAt: effectiveAt,
            source: nil,
            note: nil,
            createdAt: effectiveAt
        )
    }

    private func localProduct(
        barcode: String,
        itemNumber: String? = nil,
        name: String?,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil,
        stockQuantity: Double? = nil,
        supplierName: String? = nil,
        categoryName: String? = nil
    ) -> LocalProductSnapshot {
        LocalProductSnapshot(
            barcode: barcode,
            itemNumber: itemNumber,
            productName: name,
            secondProductName: nil,
            purchasePrice: purchasePrice,
            retailPrice: retailPrice,
            stockQuantity: stockQuantity,
            supplierName: supplierName,
            categoryName: categoryName
        )
    }

    private func localPrice(
        barcode: String,
        type: String,
        price: Double,
        effectiveAt: String
    ) -> LocalPriceSnapshot {
        LocalPriceSnapshot(
            barcode: barcode,
            type: type,
            price: price,
            effectiveAt: effectiveAt,
            source: nil,
            note: nil,
            createdAt: effectiveAt
        )
    }
}
