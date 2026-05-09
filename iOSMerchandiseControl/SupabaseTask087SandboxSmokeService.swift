#if DEBUG
import Foundation
import SwiftData

nonisolated enum SupabaseTask087SandboxSmokeError: Error, Sendable, Equatable {
    case missingRemoteSeed(String)
    case missingLocalProduct(String)
    case missingRemoteReference(String)
    case unsafeScope(String)
    case remoteIDConflict(String)
    case localSaveFailed(String)
    case syncEventRecorderMissing
    case remoteReadBackMismatch(String)

    var safeMessage: String {
        switch self {
        case .missingRemoteSeed(let key):
            return "TASK087 seed remoto mancante: \(key)"
        case .missingLocalProduct(let barcode):
            return "TASK087 prodotto locale mancante: \(barcode)"
        case .missingRemoteReference(let key):
            return "TASK087 riferimento remoto mancante: \(key)"
        case .unsafeScope(let key):
            return "TASK087 scope non valido: \(key)"
        case .remoteIDConflict(let key):
            return "TASK087 remote id non coerente: \(key)"
        case .localSaveFailed:
            return "TASK087 salvataggio locale non riuscito."
        case .syncEventRecorderMissing:
            return "TASK087 sync event recorder non configurato."
        case .remoteReadBackMismatch(let key):
            return "TASK087 read-back remoto non coerente: \(key)"
        }
    }
}

nonisolated struct SupabaseTask087SandboxSmokeResult: Sendable, Equatable {
    let ownerUserIDHash: String
    let suppliersApplied: Int
    let categoriesApplied: Int
    let productsInserted: Int
    let productsUpdated: Int
    let androidBarcodeProductName: String
    let iosBarcodeProductName: String
    let updatedRemoteProductID: UUID
    let syncEventRecorded: Bool

    var privacySafeSummary: String {
        [
            "ownerHash=\(ownerUserIDHash)",
            "suppliers=\(suppliersApplied)",
            "categories=\(categoriesApplied)",
            "inserted=\(productsInserted)",
            "updated=\(productsUpdated)",
            "syncEvent=\(syncEventRecorded ? "recorded" : "missing")"
        ].joined(separator: " ")
    }
}

@MainActor
struct SupabaseTask087SandboxSmokeService {
    static let androidBarcode = "TASK087_BAR_A"
    static let iosBarcode = "TASK087_BAR_I"
    static let androidToIOSProductName = "TASK087_ANDROID_TO_IOS_VERIFIED"
    static let iosToAndroidProductName = "TASK087_IOS_TO_ANDROID_VERIFIED"

    private let context: ModelContext
    private let inventoryService: SupabaseInventoryService
    private let syncEventRecorder: (any SyncEventRecording)?

    init(
        context: ModelContext,
        inventoryService: SupabaseInventoryService,
        syncEventRecorder: (any SyncEventRecording)?
    ) {
        self.context = context
        self.inventoryService = inventoryService
        self.syncEventRecorder = syncEventRecorder
    }

    func run() async throws -> SupabaseTask087SandboxSmokeResult {
        let ownerUserID = try await inventoryService.authenticatedTask087OwnerUserID()
        try await inventoryService.ensureTask087RemoteSeed()
        let snapshot = try await inventoryService.fetchTask087RemoteCatalogSnapshot()
        try validateRemoteSeed(snapshot)

        let applyResult = try apply(snapshot: snapshot)
        let androidProduct = try requireLocalProduct(barcode: Self.androidBarcode)
        guard androidProduct.productName == Self.androidToIOSProductName else {
            throw SupabaseTask087SandboxSmokeError.remoteReadBackMismatch(Self.androidBarcode)
        }

        let iosProduct = try requireLocalProduct(barcode: Self.iosBarcode)
        iosProduct.productName = Self.iosToAndroidProductName
        try saveContext()

        let updatedRemoteProduct = try await inventoryService.updateTask087ProductName(
            barcode: Self.iosBarcode,
            newProductName: Self.iosToAndroidProductName
        )
        guard updatedRemoteProduct.productName == Self.iosToAndroidProductName else {
            throw SupabaseTask087SandboxSmokeError.remoteReadBackMismatch(Self.iosBarcode)
        }

        applyRemoteProductMetadata(updatedRemoteProduct, to: iosProduct)
        try saveContext()
        try await recordCatalogSyncEvent(productID: updatedRemoteProduct.id)

        return SupabaseTask087SandboxSmokeResult(
            ownerUserIDHash: Self.shortHash(ownerUserID.uuidString),
            suppliersApplied: applyResult.suppliersApplied,
            categoriesApplied: applyResult.categoriesApplied,
            productsInserted: applyResult.productsInserted,
            productsUpdated: applyResult.productsUpdated,
            androidBarcodeProductName: androidProduct.productName ?? "",
            iosBarcodeProductName: iosProduct.productName ?? "",
            updatedRemoteProductID: updatedRemoteProduct.id,
            syncEventRecorded: true
        )
    }

    private struct ApplyResult: Equatable {
        var suppliersApplied = 0
        var categoriesApplied = 0
        var productsInserted = 0
        var productsUpdated = 0
    }

    private func validateRemoteSeed(_ snapshot: SupabaseTask087RemoteCatalogSnapshot) throws {
        guard snapshot.suppliers.contains(where: { $0.name == "TASK087_SUP" || $0.name == "TASK087_SUPPLIER" }) else {
            throw SupabaseTask087SandboxSmokeError.missingRemoteSeed("TASK087_SUP")
        }
        guard snapshot.categories.contains(where: { $0.name == "TASK087_CAT" || $0.name == "TASK087_CATEGORY" }) else {
            throw SupabaseTask087SandboxSmokeError.missingRemoteSeed("TASK087_CAT")
        }
        guard snapshot.products.contains(where: { $0.barcode == Self.androidBarcode }) else {
            throw SupabaseTask087SandboxSmokeError.missingRemoteSeed(Self.androidBarcode)
        }
        guard snapshot.products.contains(where: { $0.barcode == Self.iosBarcode }) else {
            throw SupabaseTask087SandboxSmokeError.missingRemoteSeed(Self.iosBarcode)
        }
    }

    private func apply(snapshot: SupabaseTask087RemoteCatalogSnapshot) throws -> ApplyResult {
        let suppliersByID = Dictionary(uniqueKeysWithValues: snapshot.suppliers.map { ($0.id, $0) })
        let categoriesByID = Dictionary(uniqueKeysWithValues: snapshot.categories.map { ($0.id, $0) })
        var suppliersApplied = 0
        var categoriesApplied = 0
        var productsInserted = 0
        var productsUpdated = 0

        for row in snapshot.suppliers where row.deletedAt == nil {
            if try upsertSupplier(row) {
                suppliersApplied += 1
            }
        }
        for row in snapshot.categories where row.deletedAt == nil {
            if try upsertCategory(row) {
                categoriesApplied += 1
            }
        }
        for row in snapshot.products where row.deletedAt == nil {
            guard row.barcode.hasPrefix(SupabaseInventoryService.task087Prefix) else {
                throw SupabaseTask087SandboxSmokeError.unsafeScope(row.barcode)
            }
            let supplier = try row.supplierID.map { supplierID in
                guard let row = suppliersByID[supplierID] else {
                    throw SupabaseTask087SandboxSmokeError.missingRemoteReference("supplier")
                }
                _ = try upsertSupplier(row)
                return try requireSupplier(name: row.name)
            }
            let category = try row.categoryID.map { categoryID in
                guard let row = categoriesByID[categoryID] else {
                    throw SupabaseTask087SandboxSmokeError.missingRemoteReference("category")
                }
                _ = try upsertCategory(row)
                return try requireCategory(name: row.name)
            }
            let didInsert = try upsertProduct(row, supplier: supplier, category: category)
            if didInsert {
                productsInserted += 1
            } else {
                productsUpdated += 1
            }
        }

        try saveContext()
        return ApplyResult(
            suppliersApplied: suppliersApplied,
            categoriesApplied: categoriesApplied,
            productsInserted: productsInserted,
            productsUpdated: productsUpdated
        )
    }

    @discardableResult
    private func upsertSupplier(_ row: RemoteInventorySupplierRow) throws -> Bool {
        guard row.name.hasPrefix(SupabaseInventoryService.task087Prefix) else {
            throw SupabaseTask087SandboxSmokeError.unsafeScope(row.name)
        }
        if let supplier = try fetchSupplier(name: row.name) {
            guard supplier.remoteID == nil || supplier.remoteID == row.id else {
                throw SupabaseTask087SandboxSmokeError.remoteIDConflict(row.name)
            }
            supplier.remoteID = row.id
            supplier.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
            supplier.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
            return false
        }
        context.insert(Supplier(
            name: row.name,
            remoteID: row.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(row.deletedAt)
        ))
        return true
    }

    @discardableResult
    private func upsertCategory(_ row: RemoteInventoryCategoryRow) throws -> Bool {
        guard row.name.hasPrefix(SupabaseInventoryService.task087Prefix) else {
            throw SupabaseTask087SandboxSmokeError.unsafeScope(row.name)
        }
        if let category = try fetchCategory(name: row.name) {
            guard category.remoteID == nil || category.remoteID == row.id else {
                throw SupabaseTask087SandboxSmokeError.remoteIDConflict(row.name)
            }
            category.remoteID = row.id
            category.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
            category.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
            return false
        }
        context.insert(ProductCategory(
            name: row.name,
            remoteID: row.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(row.deletedAt)
        ))
        return true
    }

    @discardableResult
    private func upsertProduct(
        _ row: RemoteInventoryProductRow,
        supplier: Supplier?,
        category: ProductCategory?
    ) throws -> Bool {
        guard row.barcode == Self.androidBarcode || row.barcode == Self.iosBarcode else {
            throw SupabaseTask087SandboxSmokeError.unsafeScope(row.barcode)
        }

        if let product = try fetchProduct(barcode: row.barcode) {
            guard product.remoteID == nil || product.remoteID == row.id else {
                throw SupabaseTask087SandboxSmokeError.remoteIDConflict(row.barcode)
            }
            applyRemoteProduct(row, to: product, supplier: supplier, category: category)
            return false
        }

        context.insert(Product(
            barcode: row.barcode,
            remoteID: row.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(row.deletedAt),
            itemNumber: row.itemNumber,
            productName: row.productName,
            secondProductName: row.secondProductName,
            purchasePrice: row.purchasePrice,
            retailPrice: row.retailPrice,
            stockQuantity: row.stockQuantity,
            supplier: supplier,
            category: category
        ))
        return true
    }

    private func applyRemoteProduct(
        _ row: RemoteInventoryProductRow,
        to product: Product,
        supplier: Supplier?,
        category: ProductCategory?
    ) {
        product.remoteID = row.id
        product.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        product.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
        product.itemNumber = row.itemNumber
        product.productName = row.productName
        product.secondProductName = row.secondProductName
        product.purchasePrice = row.purchasePrice
        product.retailPrice = row.retailPrice
        product.stockQuantity = row.stockQuantity
        product.supplier = supplier
        product.category = category
    }

    private func applyRemoteProductMetadata(_ row: RemoteInventoryProductRow, to product: Product) {
        product.remoteID = row.id
        product.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        product.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
        product.productName = row.productName
    }

    private func recordCatalogSyncEvent(productID: UUID) async throws {
        guard let syncEventRecorder else {
            throw SupabaseTask087SandboxSmokeError.syncEventRecorderMissing
        }
        let request = SyncEventRecordRequest(
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDs: .object([
                "product_ids": .array([.string(productID.uuidString)])
            ]),
            metadata: .object([
                "scope": .string("TASK087"),
                "source": .string("ios_sandbox_smoke")
            ]),
            source: "ios_task087_sandbox_smoke",
            sourceDeviceID: "ios-task087-sandbox",
            batchID: UUID(),
            clientEventID: "task087-ios-\(UUID().uuidString)"
        )
        _ = try await syncEventRecorder.record(request)
    }

    private func requireLocalProduct(barcode: String) throws -> Product {
        guard let product = try fetchProduct(barcode: barcode) else {
            throw SupabaseTask087SandboxSmokeError.missingLocalProduct(barcode)
        }
        return product
    }

    private func requireSupplier(name: String) throws -> Supplier {
        guard let supplier = try fetchSupplier(name: name) else {
            throw SupabaseTask087SandboxSmokeError.missingRemoteReference(name)
        }
        return supplier
    }

    private func requireCategory(name: String) throws -> ProductCategory {
        guard let category = try fetchCategory(name: name) else {
            throw SupabaseTask087SandboxSmokeError.missingRemoteReference(name)
        }
        return category
    }

    private func fetchSupplier(name: String) throws -> Supplier? {
        var descriptor = FetchDescriptor<Supplier>(
            predicate: #Predicate { $0.name == name }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchCategory(name: String) throws -> ProductCategory? {
        var descriptor = FetchDescriptor<ProductCategory>(
            predicate: #Predicate { $0.name == name }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchProduct(barcode: String) throws -> Product? {
        var descriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func saveContext() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw SupabaseTask087SandboxSmokeError.localSaveFailed(String(describing: error))
        }
    }

    private static func shortHash(_ value: String) -> String {
        String(value.utf8.reduce(UInt32(2166136261)) { hash, byte in
            (hash ^ UInt32(byte)) &* 16777619
        }, radix: 16)
    }
}
#endif
