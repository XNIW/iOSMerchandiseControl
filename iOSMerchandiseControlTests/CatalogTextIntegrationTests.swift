import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class CatalogTextIntegrationTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testQuotedCSVMultilineReachesPreviewAsCanonicalTextWithWarning() throws {
        let csv = """
        barcode;productName;retailPrice;supplier;category
        TASK140_CSV_1;"Prodotto
        \tDemo";12,50;" Fornitore\u{00A0}Uno ";"Categoria
        Uno"
        """
        let rows = try CatalogCSVParser.parse(csv)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1][1], "Prodotto\n\tDemo")

        let analysis = ProductImportCore.analyzeImport(
            header: rows[0],
            dataRows: [rows[1]],
            existingProductsByBarcode: [:]
        )

        XCTAssertTrue(analysis.errors.isEmpty)
        let draft = try XCTUnwrap(analysis.newProducts.first)
        XCTAssertEqual(draft.productName, "Prodotto Demo")
        XCTAssertEqual(draft.supplierName, "Fornitore Uno")
        XCTAssertEqual(draft.categoryName, "Categoria Uno")
        XCTAssertEqual(analysis.normalizationWarnings.count, 1)
        XCTAssertEqual(analysis.normalizationWarnings[0].affectedFieldCount, 3)
    }

    func testCSVParserPreservesEscapedQuoteAndRejectsUnclosedQuote() throws {
        let rows = try CatalogCSVParser.parse(
            "barcode;productName\r\nTASK140_CSV_2;\"Nome \"\"QA\"\"\"\r\n"
        )
        XCTAssertEqual(rows, [
            ["barcode", "productName"],
            ["TASK140_CSV_2", "Nome \"QA\""]
        ])
        XCTAssertThrowsError(
            try CatalogCSVParser.parse("barcode;productName\nX;\"not closed")
        ) { error in
            XCTAssertEqual(error as? CatalogCSVParserError, .unclosedQuote)
        }
    }

    func testImportRejectsProhibitedTextWithoutExposingRawInvisibleValue() throws {
        let analysis = ProductImportCore.analyzeImport(
            header: ["barcode", "productName", "retailPrice"],
            dataRows: [["TASK140_BAD_1", "Bad\u{200B}Name", "10"]],
            existingProductsByBarcode: [:]
        )

        XCTAssertTrue(analysis.newProducts.isEmpty)
        let error = try XCTUnwrap(analysis.errors.first)
        XCTAssertTrue(error.blocksApply)
        XCTAssertTrue(
            error.reasonKeys.contains(
                CatalogTextRejectionReason.prohibitedZeroWidth.localizationKey
            )
        )
        XCTAssertEqual(
            error.rowContent[AndroidImportKey.productName],
            "[catalog-text:prohibited_zero_width]"
        )
        XCTAssertFalse(error.rowContent.values.joined().contains("\u{200B}"))
    }

    func testStrictBarcodeCollisionAfterTrimBlocksApply() throws {
        let analysis = ProductImportCore.analyzeImport(
            header: ["barcode", "productName", "retailPrice"],
            dataRows: [
                [" TASK140_COLLISION ", "Primo", "10"],
                ["TASK140_COLLISION", "Secondo", "11"]
            ],
            existingProductsByBarcode: [:]
        )

        XCTAssertTrue(analysis.newProducts.isEmpty)
        XCTAssertTrue(analysis.errors.contains {
            $0.blocksApply
                && $0.reasonKeys.contains(
                    CatalogTextRejectionReason
                        .identityCollisionAfterTrim.localizationKey
                )
        })
    }

    func testFinalPersistenceBoundaryCanonicalizesBeforePendingFingerprint() throws {
        let context = try makeContext()
        let supplier = Supplier(name: " Fornitore\nUno ")
        let category = ProductCategory(name: " Categoria\tUno ")
        let product = Product(
            barcode: " TASK140_OUTBOX ",
            itemNumber: " ITEM-1 ",
            productName: " Caffe\u{0301}\nDemo ",
            secondProductName: " Secondo\tNome ",
            supplier: supplier,
            category: category
        )
        context.insert(supplier)
        context.insert(category)
        context.insert(product)

        let accumulator = LocalPendingChangeAccumulator(context: context)
        try accumulator.recordProductChange(
            product: product,
            operation: .create,
            origin: .manualCatalogSave,
            changedFields: ["barcode", "productName", "supplier", "category"]
        )
        try accumulator.recordSupplierChange(
            supplier: supplier,
            operation: .create,
            origin: .manualCatalogSave
        )
        try accumulator.recordCategoryChange(
            category: category,
            operation: .create,
            origin: .manualCatalogSave
        )
        try context.save()

        XCTAssertEqual(product.barcode, "TASK140_OUTBOX")
        XCTAssertEqual(product.itemNumber, "ITEM-1")
        XCTAssertEqual(product.productName, "Caffé Demo")
        XCTAssertEqual(product.secondProductName, "Secondo Nome")
        XCTAssertEqual(supplier.name, "Fornitore Uno")
        XCTAssertEqual(category.name, "Categoria Uno")

        let pending = try XCTUnwrap(
            context.fetch(FetchDescriptor<LocalPendingChange>()).first {
                $0.entityKind == .product
            }
        )
        XCTAssertEqual(
            pending.intendedFingerprintHash,
            LocalPendingChangeLogicalKey.productFingerprintHash(product)
        )
    }

    func testTextOnlyImportUpdateDoesNotCreatePriceHistory() throws {
        let context = try makeContext()
        let product = Product(
            barcode: "TASK140_TEXT_ONLY",
            productName: "Nome vecchio",
            purchasePrice: 5,
            retailPrice: 10
        )
        context.insert(product)
        let resolver = try ProductImportNamedEntityResolver(context: context)
        let old = ProductDraft(
            barcode: product.barcode,
            productName: product.productName,
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice
        )
        let new = ProductDraft(
            barcode: product.barcode,
            productName: " Nome\nnuovo ",
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice
        )
        let update = ProductUpdateDraft(
            barcode: product.barcode,
            old: old,
            new: new,
            changedFields: [.productName]
        )

        let created = try ProductImportCore.applyUpdate(
            update,
            to: product,
            in: context,
            resolver: resolver,
            recordPriceHistory: true
        )
        try context.save()

        XCTAssertEqual(product.productName, "Nome nuovo")
        XCTAssertTrue(created.isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ProductPrice>()).isEmpty)
    }

    func testExistingDirtyPendingRepairKeepsSameOutboxAndCanonicalFingerprint() throws {
        let context = try makeContext()
        let owner = UUID()
        let product = Product(
            barcode: " TASK140_DIRTY ",
            itemNumber: " ITEM-DIRTY ",
            productName: " Nome\nDirty "
        )
        context.insert(product)
        let changeID = UUID()
        let idempotencyKey = UUID().uuidString.lowercased()
        let change = LocalPendingChange(
            changeID: changeID,
            ownerUserID: owner,
            storeId: LocalStoreIdentity.anonymous.storeId,
            localStoreId: LocalStoreIdentity.anonymous.localStoreId,
            idempotencyKey: idempotencyKey,
            entityKind: .product,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: LocalPendingChangeLogicalKey.product(
                remoteID: nil,
                barcode: product.barcode
            ),
            changedFields: ["productName"],
            intendedFingerprintHash:
                LocalPendingChangeLogicalKey.productFingerprintHash(product)
        )
        context.insert(change)
        try context.save()

        let result = try CatalogTextPendingRepair.repair(
            context: context,
            ownerUserID: owner,
            storeIdentity: .anonymous
        )

        XCTAssertEqual(result.repairedProducts, 1)
        XCTAssertEqual(product.barcode, "TASK140_DIRTY")
        XCTAssertEqual(product.itemNumber, "ITEM-DIRTY")
        XCTAssertEqual(product.productName, "Nome Dirty")
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].changeID, changeID.uuidString.lowercased())
        XCTAssertEqual(changes[0].idempotencyKey, idempotencyKey)
        XCTAssertEqual(changes[0].status, .pending)
        XCTAssertTrue(changes[0].changedFields.contains("barcode"))
        XCTAssertTrue(changes[0].changedFields.contains("itemnumber"))
        XCTAssertEqual(
            changes[0].intendedFingerprintHash,
            LocalPendingChangeLogicalKey.productFingerprintHash(product)
        )
    }

    func testCanonicalPersistenceBoundaryLeavesSavedModelsCleanAndScalarExact() throws {
        let context = try makeContext()
        let supplier = Supplier(name: "Fornitore Caf\u{00E9}")
        let category = ProductCategory(name: "Categoria Caf\u{00E9}")
        let product = Product(
            barcode: "TASK146-CLEAN-e\u{0301}",
            itemNumber: "ITEM-e\u{0301}",
            productName: "Caf\u{00E9}",
            secondProductName: "Secondo Caf\u{00E9}",
            supplier: supplier,
            category: category
        )
        let nilProduct = Product(barcode: "TASK146-CLEAN-NILS")
        context.insert(supplier)
        context.insert(category)
        context.insert(product)
        context.insert(nilProduct)
        try context.save()
        let supplierScalars = Array(supplier.name.unicodeScalars)
        let categoryScalars = Array(category.name.unicodeScalars)
        let barcodeScalars = Array(product.barcode.unicodeScalars)
        let itemNumberScalars = product.itemNumber.map { Array($0.unicodeScalars) }
        let productNameScalars = product.productName.map { Array($0.unicodeScalars) }
        let secondNameScalars = product.secondProductName.map { Array($0.unicodeScalars) }
        XCTAssertFalse(context.hasChanges)

        try CatalogTextPersistenceBoundary.canonicalize(supplier)
        XCTAssertFalse(context.hasChanges)
        try CatalogTextPersistenceBoundary.canonicalize(category)
        XCTAssertFalse(context.hasChanges)
        try CatalogTextPersistenceBoundary.canonicalize(product)
        XCTAssertFalse(context.hasChanges)
        try CatalogTextPersistenceBoundary.canonicalize(nilProduct)
        XCTAssertFalse(context.hasChanges)

        XCTAssertEqual(Array(supplier.name.unicodeScalars), supplierScalars)
        XCTAssertEqual(Array(category.name.unicodeScalars), categoryScalars)
        XCTAssertEqual(Array(product.barcode.unicodeScalars), barcodeScalars)
        XCTAssertEqual(product.itemNumber.map { Array($0.unicodeScalars) }, itemNumberScalars)
        XCTAssertEqual(product.productName.map { Array($0.unicodeScalars) }, productNameScalars)
        XCTAssertEqual(product.secondProductName.map { Array($0.unicodeScalars) }, secondNameScalars)
        XCTAssertNil(nilProduct.itemNumber)
        XCTAssertNil(nilProduct.productName)
        XCTAssertNil(nilProduct.secondProductName)
        XCTAssertTrue(product.supplier === supplier)
        XCTAssertTrue(product.category === category)
    }

    func testPendingNFDDisplayRepairPersistsScalarsAndSecondPassLeavesContextClean() throws {
        let context = try makeContext()
        let owner = UUID()
        let barcode = "TASK146-NFD-ONLY"
        let nfd = "Cafe\u{0301}"
        let nfc = "Caf\u{00E9}"
        let product = Product(barcode: barcode, productName: nfd)
        let changeID = UUID()
        let idempotencyKey = UUID().uuidString.lowercased()
        let change = LocalPendingChange(
            changeID: changeID,
            ownerUserID: owner,
            storeId: LocalStoreIdentity.anonymous.storeId,
            localStoreId: LocalStoreIdentity.anonymous.localStoreId,
            idempotencyKey: idempotencyKey,
            entityKind: .product,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: barcode),
            changedFields: ["productName"],
            intendedFingerprintHash: LocalPendingChangeLogicalKey.productFingerprintHash(product)
        )
        context.insert(product)
        context.insert(change)
        try context.save()
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(nfd, nfc)
        XCTAssertNotEqual(Array(nfd.unicodeScalars), Array(nfc.unicodeScalars))
        XCTAssertEqual(Array(try XCTUnwrap(product.productName).unicodeScalars), Array(nfd.unicodeScalars))

        let first = try CatalogTextPendingRepair.repair(
            context: context, ownerUserID: owner, storeIdentity: .anonymous
        )
        XCTAssertEqual(first.repairedProducts, 1)
        XCTAssertEqual(first.repairedCount, 1)
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(change.changeID, changeID.uuidString.lowercased())
        XCTAssertEqual(change.idempotencyKey, idempotencyKey)
        XCTAssertEqual(change.status, .pending)
        XCTAssertEqual(change.intendedFingerprintHash, LocalPendingChangeLogicalKey.productFingerprintHash(product))
        let afterFirst = LocalPendingChangeCASToken(change)
        let createdAt = change.createdAt

        let persistedContext = ModelContext(context.container)
        let persistedProducts = try persistedContext.fetch(FetchDescriptor<Product>())
        XCTAssertEqual(persistedProducts.count, 1)
        let persistedProduct = try XCTUnwrap(persistedProducts.first)
        XCTAssertEqual(persistedProduct.barcode, barcode)
        XCTAssertEqual(Array(try XCTUnwrap(persistedProduct.productName).unicodeScalars), Array(nfc.unicodeScalars))
        let persistedChanges = try persistedContext.fetch(FetchDescriptor<LocalPendingChange>())
        XCTAssertEqual(persistedChanges.count, 1)
        XCTAssertEqual(LocalPendingChangeCASToken(try XCTUnwrap(persistedChanges.first)), afterFirst)

        let second = try CatalogTextPendingRepair.repair(
            context: context, ownerUserID: owner, storeIdentity: .anonymous
        )
        XCTAssertEqual(second.repairedCount, 0)
        XCTAssertFalse(context.hasChanges)
        let finalChanges = try context.fetch(FetchDescriptor<LocalPendingChange>())
        XCTAssertEqual(finalChanges.count, 1)
        let finalChange = try XCTUnwrap(finalChanges.first)
        XCTAssertEqual(LocalPendingChangeCASToken(finalChange), afterFirst)
        XCTAssertEqual(finalChange.createdAt, createdAt)
        XCTAssertEqual(Array(try XCTUnwrap(product.productName).unicodeScalars), Array(nfc.unicodeScalars))
    }

    func testPendingRepairPreflightRejectsAtomicallyBeforeAnyMutation() throws {
        let context = try makeContext()
        let owner = UUID()
        let first = Product(
            barcode: " TASK140_ATOMIC_1 ",
            productName: " Primo\nNome "
        )
        let invalid = Product(
            barcode: "TASK140_ATOMIC_2",
            productName: "Bad\u{200B}Name"
        )
        context.insert(first)
        context.insert(invalid)

        let firstChange = LocalPendingChange(
            ownerUserID: owner,
            storeId: LocalStoreIdentity.anonymous.storeId,
            localStoreId: LocalStoreIdentity.anonymous.localStoreId,
            entityKind: .product,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: LocalPendingChangeLogicalKey.product(
                remoteID: nil,
                barcode: first.barcode
            ),
            changedFields: ["productName"],
            intendedFingerprintHash:
                LocalPendingChangeLogicalKey.productFingerprintHash(first),
            createdAt: Date(timeIntervalSinceReferenceDate: 1),
            updatedAt: Date(timeIntervalSinceReferenceDate: 1)
        )
        let invalidChange = LocalPendingChange(
            ownerUserID: owner,
            storeId: LocalStoreIdentity.anonymous.storeId,
            localStoreId: LocalStoreIdentity.anonymous.localStoreId,
            entityKind: .product,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: LocalPendingChangeLogicalKey.product(
                remoteID: nil,
                barcode: invalid.barcode
            ),
            changedFields: ["productName"],
            intendedFingerprintHash:
                LocalPendingChangeLogicalKey.productFingerprintHash(invalid),
            createdAt: Date(timeIntervalSinceReferenceDate: 2),
            updatedAt: Date(timeIntervalSinceReferenceDate: 2)
        )
        context.insert(firstChange)
        context.insert(invalidChange)
        try context.save()

        XCTAssertThrowsError(
            try CatalogTextPendingRepair.repair(
                context: context,
                ownerUserID: owner,
                storeIdentity: .anonymous
            )
        ) { error in
            XCTAssertEqual(
                (error as? CatalogTextValidationError)?.reason,
                .prohibitedZeroWidth
            )
        }
        XCTAssertEqual(first.barcode, " TASK140_ATOMIC_1 ")
        XCTAssertEqual(first.productName, " Primo\nNome ")
        XCTAssertEqual(firstChange.changedFields, ["productname"])
    }

    func testPendingRepairFiltersOwnerStoreScopeBeforeApplyingLimit() throws {
        let context = try makeContext()
        let owner = UUID()
        let activeIdentity = LocalStoreIdentity.anonymous
        let foreignIdentity = LocalStoreIdentity(rawValue: "foreign-store")
        let activeProduct = Product(
            barcode: " TASK140_SCOPED ",
            productName: " Active\nProduct "
        )
        let foreignProducts = [
            Product(barcode: " TASK140_FOREIGN_1 "),
            Product(barcode: " TASK140_FOREIGN_2 ")
        ]
        context.insert(activeProduct)
        foreignProducts.forEach(context.insert)

        context.insert(
            LocalPendingChange(
                ownerUserID: owner,
                storeId: activeIdentity.storeId,
                localStoreId: activeIdentity.localStoreId,
                entityKind: .product,
                operation: .update,
                origin: .manualCatalogSave,
                logicalKey: LocalPendingChangeLogicalKey.product(
                    remoteID: nil,
                    barcode: activeProduct.barcode
                )
            )
        )
        for product in foreignProducts {
            context.insert(
                LocalPendingChange(
                    ownerUserID: owner,
                    storeId: foreignIdentity.storeId,
                    localStoreId: foreignIdentity.localStoreId,
                    entityKind: .product,
                    operation: .update,
                    origin: .manualCatalogSave,
                    logicalKey: LocalPendingChangeLogicalKey.product(
                        remoteID: nil,
                        barcode: product.barcode
                    )
                )
            )
        }
        try context.save()

        let result = try CatalogTextPendingRepair.repair(
            context: context,
            ownerUserID: owner,
            storeIdentity: activeIdentity,
            limit: 1
        )

        XCTAssertEqual(result.repairedProducts, 1)
        XCTAssertEqual(activeProduct.barcode, "TASK140_SCOPED")
        XCTAssertEqual(activeProduct.productName, "Active Product")
        XCTAssertEqual(foreignProducts[0].barcode, " TASK140_FOREIGN_1 ")
        XCTAssertEqual(foreignProducts[1].barcode, " TASK140_FOREIGN_2 ")
    }

    func testPendingRepairIndexesTargetsAcrossReasonableCatalogScale() throws {
        let context = try makeContext()
        let owner = UUID()
        for index in 0..<1_500 {
            context.insert(
                Product(
                    barcode: String(format: "TASK140_SCALE_%04d", index),
                    productName: "Unrelated \(index)"
                )
            )
        }

        var targets: [Product] = []
        for index in 0..<20 {
            let product = Product(
                barcode: String(format: " TASK140_TARGET_%02d ", index),
                productName: " Target\n\(index) "
            )
            targets.append(product)
            context.insert(product)
            context.insert(
                LocalPendingChange(
                    ownerUserID: owner,
                    storeId: LocalStoreIdentity.anonymous.storeId,
                    localStoreId: LocalStoreIdentity.anonymous.localStoreId,
                    entityKind: .product,
                    operation: .update,
                    origin: .manualCatalogSave,
                    logicalKey: LocalPendingChangeLogicalKey.product(
                        remoteID: nil,
                        barcode: product.barcode
                    ),
                    changedFields: ["productName"]
                )
            )
        }
        try context.save()

        let result = try CatalogTextPendingRepair.repair(
            context: context,
            ownerUserID: owner,
            storeIdentity: .anonymous,
            limit: targets.count
        )

        XCTAssertEqual(result.repairedProducts, targets.count)
        XCTAssertTrue(targets.allSatisfy {
            !$0.barcode.hasPrefix(" ") && !$0.barcode.hasSuffix(" ")
        })
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<LocalPendingChange>()).count,
            targets.count
        )
    }

    func testFullCatalogExportPreflightRejectsUnreferencedNamedEntities() throws {
        let product = Product(barcode: "TASK140_EXPORT_VALID")
        let invalidSupplier = Supplier(name: "Bad\u{200B}Supplier")
        let validCategory = ProductCategory(name: "Valid Category")

        XCTAssertThrowsError(
            try CatalogTextPersistenceBoundary.validateFullCatalogExport(
                products: [product],
                suppliers: [invalidSupplier],
                categories: [validCategory]
            )
        ) { error in
            XCTAssertEqual(
                error as? CatalogTextValidationError,
                CatalogTextValidationError(
                    field: .supplierName,
                    reason: .prohibitedZeroWidth
                )
            )
        }

        invalidSupplier.name = "Valid Supplier"
        let invalidCategory = ProductCategory(name: "Bad\u{200B}Category")
        XCTAssertThrowsError(
            try CatalogTextPersistenceBoundary.validateFullCatalogExport(
                products: [product],
                suppliers: [invalidSupplier],
                categories: [invalidCategory]
            )
        ) { error in
            XCTAssertEqual(
                error as? CatalogTextValidationError,
                CatalogTextValidationError(
                    field: .categoryName,
                    reason: .prohibitedZeroWidth
                )
            )
        }
    }

    func testInboundCatalogApplyCanonicalizesWithoutCreatingLocalPendingChange() throws {
        let context = try makeContext()
        let owner = UUID()
        let supplierResult = try applyTargetedSupplier(
            RemoteInventorySupplierRow(
                id: UUID(),
                ownerUserID: owner,
                name: " Fornitore\nInbound ",
                updatedAt: "2026-07-27T00:00:00Z",
                deletedAt: nil
            ),
            context: context
        )
        let supplier = try XCTUnwrap(supplierResult.supplier)
        XCTAssertEqual(supplier.name, "Fornitore Inbound")

        let productResult = try applyTargetedProduct(
            RemoteInventoryProductRow(
                id: UUID(),
                ownerUserID: owner,
                barcode: "TASK140_INBOUND",
                itemNumber: " ITEM-IN ",
                productName: " Prodotto\nInbound ",
                secondProductName: "Secondo\tNome",
                purchasePrice: 4,
                retailPrice: 8,
                supplierID: supplier.remoteID,
                categoryID: nil,
                stockQuantity: 2,
                updatedAt: "2026-07-27T00:00:00Z",
                deletedAt: nil
            ),
            supplier: supplier,
            category: nil,
            context: context
        )

        XCTAssertTrue(productResult.inserted)
        let product = try XCTUnwrap(
            context.fetch(FetchDescriptor<Product>()).first
        )
        XCTAssertEqual(product.itemNumber, "ITEM-IN")
        XCTAssertEqual(product.productName, "Prodotto Inbound")
        XCTAssertEqual(product.secondProductName, "Secondo Nome")
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<LocalPendingChange>()).isEmpty
        )
    }

    func testInboundRejectsStrictIdentityWithControl() throws {
        let context = try makeContext()
        let row = RemoteInventoryProductRow(
            id: UUID(),
            ownerUserID: UUID(),
            barcode: "TASK140\nBAD",
            itemNumber: nil,
            productName: "Prodotto",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-07-27T00:00:00Z",
            deletedAt: nil
        )

        XCTAssertThrowsError(
            try applyTargetedProduct(
                row,
                supplier: nil,
                category: nil,
                context: context
            )
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<Product>()).isEmpty)
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<LocalPendingChange>()).isEmpty
        )
    }

    func testAllSupportedLocalizationsContainCatalogTextMessages() throws {
        let keys = [
            "catalog.text.error.prohibited_control",
            "catalog.text.error.prohibited_zero_width",
            "catalog.text.error.too_long",
            "catalog.text.import.normalized_warning",
            "catalog.text.import.apply_blocked",
            "catalog.text.csv.unclosed_quote"
        ]
        for language in ["en", "it", "es", "zh-Hans"] {
            let path = try XCTUnwrap(
                Bundle.main.path(forResource: language, ofType: "lproj"),
                language
            )
            let bundle = try XCTUnwrap(Bundle(path: path), language)
            for key in keys {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: key, value: key, table: nil),
                    key,
                    "\(language): \(key)"
                )
            }
        }
    }

    private func makeContext() throws -> ModelContext {
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
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }
}
