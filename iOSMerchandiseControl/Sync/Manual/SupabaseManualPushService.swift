import Foundation
import SwiftData
import Supabase

nonisolated enum SupabaseManualPushTerminalStatus: String, Sendable, Equatable {
    case completed
    case completedBaselineRefreshFailed
    case partial
    case failedBeforeWrite
    case blockedBeforeWrite
}

nonisolated struct SupabaseManualPushTouchedIDs: Sendable, Equatable {
    var suppliers: Set<UUID> = []
    var categories: Set<UUID> = []
    var products: Set<UUID> = []

    var isEmpty: Bool {
        suppliers.isEmpty && categories.isEmpty && products.isEmpty
    }

    var syncEventEntityIDs: SyncEventJSONValue {
        .object([
            "supplier_ids": .array(suppliers.sorted { $0.uuidString < $1.uuidString }.map { .string($0.uuidString.lowercased()) }),
            "category_ids": .array(categories.sorted { $0.uuidString < $1.uuidString }.map { .string($0.uuidString.lowercased()) }),
            "product_ids": .array(products.sorted { $0.uuidString < $1.uuidString }.map { .string($0.uuidString.lowercased()) })
        ])
    }
}

nonisolated struct SupabaseManualPushReadBackExpectation: Sendable, Equatable {
    var supplierFingerprintsByID: [UUID: ManualPushFingerprint] = [:]
    var categoryFingerprintsByID: [UUID: ManualPushFingerprint] = [:]
    var productFingerprintsByID: [UUID: ManualPushFingerprint] = [:]

    var touchedIDs: SupabaseManualPushTouchedIDs {
        SupabaseManualPushTouchedIDs(
            suppliers: Set(supplierFingerprintsByID.keys),
            categories: Set(categoryFingerprintsByID.keys),
            products: Set(productFingerprintsByID.keys)
        )
    }

    var isEmpty: Bool {
        supplierFingerprintsByID.isEmpty
            && categoryFingerprintsByID.isEmpty
            && productFingerprintsByID.isEmpty
    }
}

nonisolated struct SupabaseManualPushResult: Sendable, Equatable {
    let status: SupabaseManualPushTerminalStatus
    let supplierCreates: Int
    let supplierUpdates: Int
    let supplierLinks: Int
    let categoryCreates: Int
    let categoryUpdates: Int
    let categoryLinks: Int
    let productCreates: Int
    let productUpdates: Int
    let productLinks: Int
    var touchedIDs = SupabaseManualPushTouchedIDs()
    var tombstoneIDs = SupabaseManualPushTouchedIDs()
    let baselineRunID: UUID?
    let message: String?

    init(
        status: SupabaseManualPushTerminalStatus,
        supplierCreates: Int,
        supplierUpdates: Int,
        supplierLinks: Int,
        categoryCreates: Int,
        categoryUpdates: Int,
        categoryLinks: Int,
        productCreates: Int,
        productUpdates: Int,
        productLinks: Int,
        touchedIDs: SupabaseManualPushTouchedIDs = SupabaseManualPushTouchedIDs(),
        tombstoneIDs: SupabaseManualPushTouchedIDs = SupabaseManualPushTouchedIDs(),
        baselineRunID: UUID?,
        message: String?
    ) {
        self.status = status
        self.supplierCreates = supplierCreates
        self.supplierUpdates = supplierUpdates
        self.supplierLinks = supplierLinks
        self.categoryCreates = categoryCreates
        self.categoryUpdates = categoryUpdates
        self.categoryLinks = categoryLinks
        self.productCreates = productCreates
        self.productUpdates = productUpdates
        self.productLinks = productLinks
        self.touchedIDs = touchedIDs
        self.tombstoneIDs = tombstoneIDs
        self.baselineRunID = baselineRunID
        self.message = message
    }

    static func blocked(message: String? = nil) -> SupabaseManualPushResult {
        SupabaseManualPushResult(
            status: .blockedBeforeWrite,
            supplierCreates: 0,
            supplierUpdates: 0,
            supplierLinks: 0,
            categoryCreates: 0,
            categoryUpdates: 0,
            categoryLinks: 0,
            productCreates: 0,
            productUpdates: 0,
            productLinks: 0,
            touchedIDs: SupabaseManualPushTouchedIDs(),
            baselineRunID: nil,
            message: message
        )
    }
}

nonisolated struct SupabaseManualPushSupplierCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case name
    }
}

nonisolated struct SupabaseManualPushSupplierUpdatePayload: Encodable, Equatable, Sendable {
    let name: String
}

nonisolated struct SupabaseManualPushCategoryCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case name
    }
}

nonisolated struct SupabaseManualPushCategoryUpdatePayload: Encodable, Equatable, Sendable {
    let name: String
}

nonisolated struct SupabaseManualPushProductCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let barcode: String
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let supplierID: UUID?
    let categoryID: UUID?
    let stockQuantity: Double?

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case barcode
        case itemNumber = "item_number"
        case productName = "product_name"
        case secondProductName = "second_product_name"
        case purchasePrice = "purchase_price"
        case retailPrice = "retail_price"
        case supplierID = "supplier_id"
        case categoryID = "category_id"
        case stockQuantity = "stock_quantity"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ownerUserID, forKey: .ownerUserID)
        try container.encode(barcode, forKey: .barcode)
        try container.encodeIfPresent(itemNumber, forKey: .itemNumber)
        try container.encodeIfPresent(productName, forKey: .productName)
        try container.encodeIfPresent(secondProductName, forKey: .secondProductName)
        try container.encodeIfPresent(purchasePrice, forKey: .purchasePrice)
        try container.encodeIfPresent(retailPrice, forKey: .retailPrice)
        try container.encodeIfPresent(supplierID, forKey: .supplierID)
        try container.encodeIfPresent(categoryID, forKey: .categoryID)
        try container.encodeIfPresent(stockQuantity, forKey: .stockQuantity)
    }
}

nonisolated struct SupabaseManualPushProductUpdatePayload: Encodable, Equatable, Sendable {
    let barcode: String?
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let supplierID: UUID?
    let categoryID: UUID?
    let stockQuantity: Double?
    let deletedAt: String?

    init(
        barcode: String?,
        itemNumber: String?,
        productName: String?,
        secondProductName: String?,
        purchasePrice: Double?,
        retailPrice: Double?,
        supplierID: UUID?,
        categoryID: UUID?,
        stockQuantity: Double?,
        deletedAt: String? = nil
    ) {
        self.barcode = barcode
        self.itemNumber = itemNumber
        self.productName = productName
        self.secondProductName = secondProductName
        self.purchasePrice = purchasePrice
        self.retailPrice = retailPrice
        self.supplierID = supplierID
        self.categoryID = categoryID
        self.stockQuantity = stockQuantity
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case barcode
        case itemNumber = "item_number"
        case productName = "product_name"
        case secondProductName = "second_product_name"
        case purchasePrice = "purchase_price"
        case retailPrice = "retail_price"
        case supplierID = "supplier_id"
        case categoryID = "category_id"
        case stockQuantity = "stock_quantity"
        case deletedAt = "deleted_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(barcode, forKey: .barcode)
        try container.encodeIfPresent(itemNumber, forKey: .itemNumber)
        try container.encodeIfPresent(productName, forKey: .productName)
        try container.encodeIfPresent(secondProductName, forKey: .secondProductName)
        try container.encodeIfPresent(purchasePrice, forKey: .purchasePrice)
        try container.encodeIfPresent(retailPrice, forKey: .retailPrice)
        try container.encodeIfPresent(supplierID, forKey: .supplierID)
        try container.encodeIfPresent(categoryID, forKey: .categoryID)
        try container.encodeIfPresent(stockQuantity, forKey: .stockQuantity)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
}

protocol SupabaseManualPushRemoteGateway {
    func createSuppliers(_ payloads: [SupabaseManualPushSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow]
    func updateSupplier(id: UUID, payload: SupabaseManualPushSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow
    func verifySupplier(id: UUID, normalizedName: String) async throws -> RemoteInventorySupplierRow

    func createCategories(_ payloads: [SupabaseManualPushCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow]
    func updateCategory(id: UUID, payload: SupabaseManualPushCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow
    func verifyCategory(id: UUID, normalizedName: String) async throws -> RemoteInventoryCategoryRow

    func createProducts(_ payloads: [SupabaseManualPushProductCreatePayload]) async throws -> [RemoteInventoryProductRow]
    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow
    func verifyProduct(id: UUID, normalizedBarcode: String) async throws -> RemoteInventoryProductRow

    func verifyReadBack(expectation: SupabaseManualPushReadBackExpectation) async throws
}

nonisolated enum ManualPendingCatalogDispatchContext {
    @TaskLocal static var beforeDispatch: (@MainActor @Sendable () throws -> Void)?
}

private nonisolated struct ManualCatalogDefaults: @unchecked Sendable { let value: UserDefaults }

private nonisolated protocol ManualCatalogScopedRow: Decodable, Sendable {
    var id: UUID { get }
    var ownerUserID: UUID { get }
    var shopID: UUID? { get }
}
extension RemoteInventorySupplierRow: ManualCatalogScopedRow {}
extension RemoteInventoryCategoryRow: ManualCatalogScopedRow {}
extension RemoteInventoryProductRow: ManualCatalogScopedRow {}

private nonisolated struct ManualCatalogShopPayload<Value: Encodable>: Encodable {
    let value: Value
    let shopID: UUID
    private enum CodingKeys: String, CodingKey { case shopID = "shop_id" }
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shopID, forKey: .shopID)
    }
}

actor SupabaseManualPushRemoteClient: SupabaseManualPushRemoteGateway {
    private enum Table {
        static let suppliers = "inventory_suppliers"
        static let categories = "inventory_categories"
        static let products = "inventory_products"
        static let supplierColumns = "id,owner_user_id,shop_id,name,updated_at,deleted_at"
        static let categoryColumns = "id,owner_user_id,shop_id,name,updated_at,deleted_at"
        static let productColumns = "id,owner_user_id,shop_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at,primary_image_version_id,primary_image_updated_at"
    }

    private let clientProvider: SupabaseClientProvider
    private let defaults: ManualCatalogDefaults
    private nonisolated struct Admission: Sendable {
        let owner: UUID
        let auth: SupabaseAuthClientSnapshot
        let scope: Task126VerifiedOwnerStoreScope?
    }

    init(clientProvider: SupabaseClientProvider, defaults: UserDefaults = .standard) {
        self.clientProvider = clientProvider
        self.defaults = ManualCatalogDefaults(value: defaults)
    }

    func createSuppliers(_ payloads: [SupabaseManualPushSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        let admission = try await requireAuthenticatedSession()
        try validateCreatePayloadOwners(payloads.map(\.ownerUserID), ownerUserID: admission.owner)
        if let scope = admission.scope {
            return try await insert(payloads.map { ManualCatalogShopPayload(value: $0, shopID: scope.shopID) },
                table: Table.suppliers, columns: Table.supplierColumns, admission: admission)
        }
        return try await insert(payloads, table: Table.suppliers, columns: Table.supplierColumns, admission: admission)
    }

    func updateSupplier(id: UUID, payload: SupabaseManualPushSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        try await update(payload, table: Table.suppliers, columns: Table.supplierColumns, id: id)
    }

    func verifySupplier(id: UUID, normalizedName: String) async throws -> RemoteInventorySupplierRow {
        let row: RemoteInventorySupplierRow = try await fetchByID(table: Table.suppliers, columns: Table.supplierColumns, id: id)
        guard SupabasePullPreviewNormalizer.normalizedLookupName(row.name) == normalizedName else {
            throw SupabaseTransportClientError.schemaDrift(message: "Supplier natural key mismatch.")
        }
        return row
    }

    func createCategories(_ payloads: [SupabaseManualPushCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        let admission = try await requireAuthenticatedSession()
        try validateCreatePayloadOwners(payloads.map(\.ownerUserID), ownerUserID: admission.owner)
        if let scope = admission.scope {
            return try await insert(payloads.map { ManualCatalogShopPayload(value: $0, shopID: scope.shopID) },
                table: Table.categories, columns: Table.categoryColumns, admission: admission)
        }
        return try await insert(payloads, table: Table.categories, columns: Table.categoryColumns, admission: admission)
    }

    func updateCategory(id: UUID, payload: SupabaseManualPushCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        try await update(payload, table: Table.categories, columns: Table.categoryColumns, id: id)
    }

    func verifyCategory(id: UUID, normalizedName: String) async throws -> RemoteInventoryCategoryRow {
        let row: RemoteInventoryCategoryRow = try await fetchByID(table: Table.categories, columns: Table.categoryColumns, id: id)
        guard SupabasePullPreviewNormalizer.normalizedLookupName(row.name) == normalizedName else {
            throw SupabaseTransportClientError.schemaDrift(message: "Category natural key mismatch.")
        }
        return row
    }

    func createProducts(_ payloads: [SupabaseManualPushProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        let admission = try await requireAuthenticatedSession()
        try validateCreatePayloadOwners(payloads.map(\.ownerUserID), ownerUserID: admission.owner)
        if let scope = admission.scope {
            return try await insert(payloads.map { ManualCatalogShopPayload(value: $0, shopID: scope.shopID) },
                table: Table.products, columns: Table.productColumns, admission: admission)
        }
        return try await insert(payloads, table: Table.products, columns: Table.productColumns, admission: admission)
    }

    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        try await update(payload, table: Table.products, columns: Table.productColumns, id: id)
    }

    func verifyProduct(id: UUID, normalizedBarcode: String) async throws -> RemoteInventoryProductRow {
        let row: RemoteInventoryProductRow = try await fetchByID(table: Table.products, columns: Table.productColumns, id: id)
        guard ManualPushFingerprintNormalizer.semanticString(row.barcode) == normalizedBarcode else {
            throw SupabaseTransportClientError.schemaDrift(message: "Product natural key mismatch.")
        }
        return row
    }

    func verifyReadBack(expectation: SupabaseManualPushReadBackExpectation) async throws {
        let touchedIDs = expectation.touchedIDs
        if !touchedIDs.suppliers.isEmpty {
            let rows: [RemoteInventorySupplierRow] = try await fetchByIDs(
                table: Table.suppliers,
                columns: Table.supplierColumns,
                ids: touchedIDs.suppliers
            )
            guard Set(rows.map(\.id)) == touchedIDs.suppliers else {
                throw SupabaseTransportClientError.schemaDrift(message: "Supplier read-back mismatch.")
            }
            for row in rows {
                guard expectation.supplierFingerprintsByID[row.id] == remoteFingerprint(row) else {
                    throw SupabaseTransportClientError.schemaDrift(message: "Supplier read-back fingerprint mismatch.")
                }
            }
        }
        if !touchedIDs.categories.isEmpty {
            let rows: [RemoteInventoryCategoryRow] = try await fetchByIDs(
                table: Table.categories,
                columns: Table.categoryColumns,
                ids: touchedIDs.categories
            )
            guard Set(rows.map(\.id)) == touchedIDs.categories else {
                throw SupabaseTransportClientError.schemaDrift(message: "Category read-back mismatch.")
            }
            for row in rows {
                guard expectation.categoryFingerprintsByID[row.id] == remoteFingerprint(row) else {
                    throw SupabaseTransportClientError.schemaDrift(message: "Category read-back fingerprint mismatch.")
                }
            }
        }
        if !touchedIDs.products.isEmpty {
            let rows: [RemoteInventoryProductRow] = try await fetchByIDs(
                table: Table.products,
                columns: Table.productColumns,
                ids: touchedIDs.products
            )
            guard Set(rows.map(\.id)) == touchedIDs.products else {
                throw SupabaseTransportClientError.schemaDrift(message: "Product read-back mismatch.")
            }
            for row in rows {
                guard expectation.productFingerprintsByID[row.id] == remoteFingerprint(row) else {
                    throw SupabaseTransportClientError.schemaDrift(message: "Product read-back fingerprint mismatch.")
                }
            }
        }
    }

    private func remoteFingerprint(_ row: RemoteInventorySupplierRow) -> ManualPushFingerprint {
        ManualPushFingerprintNormalizer.supplier(remoteID: row.id, name: row.name)
    }

    private func remoteFingerprint(_ row: RemoteInventoryCategoryRow) -> ManualPushFingerprint {
        ManualPushFingerprintNormalizer.category(remoteID: row.id, name: row.name)
    }

    private func remoteFingerprint(_ row: RemoteInventoryProductRow) -> ManualPushFingerprint {
        ManualPushFingerprintNormalizer.product(
            barcode: row.barcode,
            itemNumber: row.itemNumber,
            productName: row.productName,
            secondProductName: row.secondProductName,
            purchasePrice: row.purchasePrice,
            retailPrice: row.retailPrice,
            stockQuantity: row.stockQuantity,
            supplierRemoteID: row.supplierID,
            categoryRemoteID: row.categoryID
        )
    }

    private func guardedClient(_ admission: Admission) -> PostgrestClient {
        var configuration = admission.auth.client.schema("public").configuration
        guard let scope = admission.scope else { return PostgrestClient(configuration: configuration) }
        let provider = clientProvider, capturedDefaults = defaults
        configuration.retryEnabled = false
        configuration.fetch = { wire in
            try await provider.performManualRequest(wire, snapshot: admission.auth, scope: scope,
                validateScope: {
                    try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: capturedDefaults.value)
                }, beforeDispatch: { finalWire in
                    try ManualPendingCatalogDispatchContext.beforeDispatch?()
                    try ManualPendingAtomicDispatchContext.beforeDispatch?(finalWire)
                })
        }
        return PostgrestClient(configuration: configuration)
    }

    private func insert<Row: ManualCatalogScopedRow>(
        _ payloads: some Encodable, table: String, columns: String, admission: Admission
    ) async throws -> [Row] {
        do {
            try await validate(admission, beforeHTTP: true)
            let rows: [Row] = try await guardedClient(admission).from(table).insert(payloads)
                .select(columns).execute().value
            try await validate(admission)
            try validateRows(rows, admission: admission)
            return rows
        } catch { throw mapRemoteError(error) }
    }

    private func validateCreatePayloadOwners(_ payloadOwnerIDs: [UUID], ownerUserID: UUID) throws {
        guard payloadOwnerIDs.allSatisfy({ $0 == ownerUserID }) else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "Owner mismatch."
            )
        }
    }

    private func update<Row: ManualCatalogScopedRow>(
        _ payload: some Encodable, table: String, columns: String, id: UUID
    ) async throws -> Row {
        let admission = try await requireAuthenticatedSession()
        do {
            var request = try guardedClient(admission).from(table).update(payload)
                .eq("id", value: id.uuidString).eq("owner_user_id", value: admission.owner.uuidString)
            if let scope = admission.scope { request = request.eq("shop_id", value: scope.shopID.uuidString) }
            try await validate(admission, beforeHTTP: true)
            let row: Row = try await request.select(columns).single().execute().value
            try await validate(admission)
            try validateRows([row], admission: admission)
            guard admission.scope == nil || row.id == id else { throw LocalPendingManualDispatchError.staleBatch }
            return row
        } catch { throw mapRemoteError(error) }
    }

    private func fetchByID<Row: ManualCatalogScopedRow>(table: String, columns: String, id: UUID) async throws -> Row {
        let admission = try await requireAuthenticatedSession()
        do {
            var request = guardedClient(admission).from(table).select(columns)
                .eq("id", value: id.uuidString).eq("owner_user_id", value: admission.owner.uuidString)
            if let scope = admission.scope { request = request.eq("shop_id", value: scope.shopID.uuidString) }
            try await validate(admission, beforeHTTP: true)
            let row: Row = try await request.limit(1).single().execute().value
            try await validate(admission)
            try validateRows([row], admission: admission)
            guard admission.scope == nil || row.id == id else { throw LocalPendingManualDispatchError.staleBatch }
            return row
        } catch { throw mapRemoteError(error) }
    }

    private func fetchByIDs<Row: ManualCatalogScopedRow>(table: String, columns: String, ids: Set<UUID>) async throws -> [Row] {
        let admission = try await requireAuthenticatedSession()
        do {
            var request = guardedClient(admission).from(table).select(columns)
                .eq("owner_user_id", value: admission.owner.uuidString)
                .in("id", values: ids.sorted { $0.uuidString < $1.uuidString }.map(\.uuidString))
            if let scope = admission.scope { request = request.eq("shop_id", value: scope.shopID.uuidString) }
            try await validate(admission, beforeHTTP: true)
            let rows: [Row] = try await request.execute().value
            try await validate(admission)
            try validateRows(rows, admission: admission)
            return rows
        } catch { throw mapRemoteError(error) }
    }

    private func requireAuthenticatedSession() async throws -> Admission {
        let scope = Task126OwnerStoreGate.currentAutomaticScope
        if let scope { try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults.value) }
        let snapshot = await clientProvider.authSnapshot
        do {
            let session = try await snapshot.client.auth.session
            let admission = Admission(owner: session.user.id, auth: snapshot, scope: scope)
            try await validate(admission)
            return admission
        } catch {
            if scope != nil {
                await clientProvider.recordSessionReadFailure(error, generation: snapshot.generation)
                throw error
            }
            throw SupabaseTransportClientError.sessionMissing
        }
    }

    private func validate(_ admission: Admission, beforeHTTP: Bool = false) async throws {
        let provider = clientProvider, capturedDefaults = defaults
        try await MainActor.run {
            // One synchronous main-actor admission after auth awaits. No other
            // async hop separates the batch check from auth/scope validation.
            if beforeHTTP { try ManualPendingCatalogDispatchContext.beforeDispatch?() }
            guard provider.acceptsAuthGeneration(admission.auth.generation) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            if let scope = admission.scope {
                try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: capturedDefaults.value)
                guard admission.owner == scope.ownerUserID else { throw LocalPendingManualDispatchError.staleBatch }
            }
        }
    }

    private func validateRows<Row: ManualCatalogScopedRow>(_ rows: [Row], admission: Admission) throws {
        guard let scope = admission.scope else { return }
        guard rows.allSatisfy({ $0.ownerUserID == scope.ownerUserID && $0.shopID == scope.shopID }) else {
            throw LocalPendingManualDispatchError.staleBatch
        }
    }

    private func mapRemoteError(_ error: Error) -> Error {
        if let error = error as? PostgrestError {
            let normalized = [error.code, error.message, error.detail, error.hint]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            if normalized.contains("permission denied")
                || normalized.contains("row-level security")
                || normalized.contains("rls")
                || normalized.contains("unauthorized")
                || normalized.contains("authenticated")
                || error.code == "42501" {
                return SupabaseTransportClientError.permissionDeniedOrRLS(
                    statusCode: nil,
                    code: error.code,
                    message: error.message
                )
            }
            if error.code == "42P01" || error.code == "42703" || error.code == "PGRST204" {
                return SupabaseTransportClientError.schemaDrift(message: error.message)
            }
            return SupabaseTransportClientError.unknown(message: error.message)
        }
        if let error = error as? DecodingError {
            return SupabaseTransportClientError.decodingError(message: String(describing: error))
        }
        if let error = error as? URLError {
            return SupabaseTransportClientError.networkError(statusCode: nil, message: error.localizedDescription)
        }
        return error
    }
}

/// Invocation-local values for the guarded aggregate path. Business values are
/// captured once; only verified metadata links are added after remote replies.
@MainActor
final class ManualPendingCatalogExecution {
    private struct Lookup {
        let id: PersistentIdentifier
        let name: String
        let remoteID: UUID?
    }
    private struct Item {
        let id: PersistentIdentifier
        let remoteID: UUID?
        let values: CatalogConflictProductValues
        let supplierID: PersistentIdentifier?
        let categoryID: PersistentIdentifier?
    }
    private let snapshot: LocalPendingManualDispatchSnapshot
    private let container: ModelContainer
    private let owner: UUID
    private let defaults: UserDefaults
    private let suppliers: [String: Lookup]
    private let categories: [String: Lookup]
    private let products: [String: Item]
    private let tombstoneTimestamp: String
    private let readOnlyMemberIDsByTarget: [String: Set<String>]
    private(set) var verifiedReadOnlyChangeIDs: Set<String> = []
    private var supplierLinks: [PersistentIdentifier: UUID] = [:]
    private var categoryLinks: [PersistentIdentifier: UUID] = [:]
    private var productLinks: [PersistentIdentifier: UUID] = [:]

    init(snapshot: LocalPendingManualDispatchSnapshot, plan: ManualPushPlan,
         container: ModelContainer, ownerUserID: UUID, defaults: UserDefaults) throws {
        self.snapshot = snapshot; self.container = container; self.owner = ownerUserID; self.defaults = defaults
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        tombstoneTimestamp = formatter.string(from: plan.generatedAt)
        let captured = try snapshot.withFence(modelContainer: container, ownerUserID: ownerUserID, defaults: defaults) { context in
            _ = try snapshot.exactRowsWithFenceHeld(context: context, ownerUserID: ownerUserID, defaults: defaults)
            var suppliers: [String: Lookup] = [:], categories: [String: Lookup] = [:], products: [String: Item] = [:]
            for candidate in plan.writeCandidates {
                switch candidate.entityKind {
                case .supplier:
                    let name = candidate.localID
                    let matches = try context.fetch(FetchDescriptor<Supplier>(predicate: #Predicate { $0.name == name }))
                    guard matches.count == 1, let row = matches.first,
                          candidate.fingerprint == ManualPushFingerprintNormalizer.supplier(remoteID: row.remoteID, name: row.name) else {
                        throw LocalPendingManualDispatchError.staleBatch
                    }
                    suppliers[name] = Lookup(id: row.persistentModelID, name: row.name, remoteID: row.remoteID)
                case .productCategory:
                    let name = candidate.localID
                    let matches = try context.fetch(FetchDescriptor<ProductCategory>(predicate: #Predicate { $0.name == name }))
                    guard matches.count == 1, let row = matches.first,
                          candidate.fingerprint == ManualPushFingerprintNormalizer.category(remoteID: row.remoteID, name: row.name) else {
                        throw LocalPendingManualDispatchError.staleBatch
                    }
                    categories[name] = Lookup(id: row.persistentModelID, name: row.name, remoteID: row.remoteID)
                case .product:
                    if candidate.action == .dryRunTombstoneCandidate { continue }
                    let barcode = candidate.localID
                    let matches = try context.fetch(FetchDescriptor<Product>(predicate: #Predicate { $0.barcode == barcode }))
                    guard matches.count == 1, let row = matches.first, row.remoteDeletedAt == nil else {
                        throw LocalPendingManualDispatchError.staleBatch
                    }
                    let values = CatalogConflictProductValues(product: row)
                    guard candidate.fingerprint.map({ LocalPendingChangeLogicalKey.privacyHash($0.canonicalString) }) == values.fingerprint else {
                        throw LocalPendingManualDispatchError.staleBatch
                    }
                    products[barcode] = Item(id: row.persistentModelID, remoteID: row.remoteID, values: values,
                        supplierID: row.supplier?.persistentModelID, categoryID: row.category?.persistentModelID)
                case .productPrice: throw LocalPendingManualDispatchError.staleBatch
                }
            }
            return (suppliers, categories, products)
        }
        suppliers = captured.0; categories = captured.1; products = captured.2
        var readOnly: [String: Set<String>] = [:]
        for candidate in plan.writeCandidates where candidate.action == .dryRunLinkCandidate {
            let kind: LocalPendingChangeEntityKind, key: String
            switch candidate.entityKind {
            case .supplier:
                kind = .supplier
                key = LocalPendingChangeLogicalKey.supplier(remoteID: captured.0[candidate.localID]?.remoteID, name: candidate.localID)
            case .productCategory:
                kind = .productCategory
                key = LocalPendingChangeLogicalKey.category(remoteID: captured.1[candidate.localID]?.remoteID, name: candidate.localID)
            case .product:
                kind = .product
                key = LocalPendingChangeLogicalKey.product(remoteID: captured.2[candidate.localID]?.remoteID, barcode: candidate.localID)
            case .productPrice: throw LocalPendingManualDispatchError.staleBatch
            }
            let tokens = snapshot.tokens.filter { $0.entityKindRaw == kind.rawValue && $0.logicalKey == key }
            guard tokens.count == 1 else { throw LocalPendingManualDispatchError.staleBatch }
            readOnly[kind.rawValue + ":" + candidate.localID] = Set(tokens.map(\.changeID))
        }
        readOnlyMemberIDsByTarget = readOnly
    }

    private func expected(_ item: Item) -> CatalogConflictProductValues {
        var value = item.values
        if let id = item.supplierID, let linked = supplierLinks[id] { value.supplierID = linked }
        if let id = item.categoryID, let linked = categoryLinks[id] { value.categoryID = linked }
        return value
    }

    private func withCurrent<Result>(_ body: (ModelContext) throws -> Result) throws -> Result {
        try snapshot.withFence(modelContainer: container, ownerUserID: owner, defaults: defaults) { context in
            _ = try snapshot.exactRowsWithFenceHeld(context: context, ownerUserID: owner, defaults: defaults)
            for value in suppliers.values {
                let row = try Task126OwnerStoreGate.requireLocalModel(Supplier.self, id: value.id, in: context)
                guard row.name == value.name, row.remoteDeletedAt == nil,
                      row.remoteID == (supplierLinks[value.id] ?? value.remoteID) else { throw LocalPendingManualDispatchError.staleBatch }
            }
            for value in categories.values {
                let row = try Task126OwnerStoreGate.requireLocalModel(ProductCategory.self, id: value.id, in: context)
                guard row.name == value.name, row.remoteDeletedAt == nil,
                      row.remoteID == (categoryLinks[value.id] ?? value.remoteID) else { throw LocalPendingManualDispatchError.staleBatch }
            }
            for item in products.values {
                let row = try Task126OwnerStoreGate.requireLocalModel(Product.self, id: item.id, in: context)
                guard CatalogConflictProductValues(product: row) == expected(item), row.remoteDeletedAt == nil,
                      row.supplier?.persistentModelID == item.supplierID, row.category?.persistentModelID == item.categoryID,
                      row.remoteID == (productLinks[item.id] ?? item.remoteID) else { throw LocalPendingManualDispatchError.staleBatch }
            }
            return try body(context)
        }
    }

    func beforeRequest() throws { try withCurrent { _ in } }
    func supplierName(_ localID: String) throws -> String {
        guard let value = suppliers[localID] else { throw LocalPendingManualDispatchError.staleBatch }
        return value.name
    }
    func categoryName(_ localID: String) throws -> String {
        guard let value = categories[localID] else { throw LocalPendingManualDispatchError.staleBatch }
        return value.name
    }
    func createProduct(_ localID: String) throws -> SupabaseManualPushProductCreatePayload {
        guard let item = products[localID] else { throw LocalPendingManualDispatchError.staleBatch }
        let v = expected(item)
        return .init(ownerUserID: owner, barcode: v.barcode,
            itemNumber: SupabasePullPreviewNormalizer.semanticString(v.itemNumber),
            productName: SupabasePullPreviewNormalizer.semanticString(v.productName),
            secondProductName: SupabasePullPreviewNormalizer.semanticString(v.secondProductName),
            purchasePrice: v.purchasePrice, retailPrice: v.retailPrice,
            supplierID: v.supplierID, categoryID: v.categoryID, stockQuantity: v.stockQuantity)
    }
    func updateProduct(_ localID: String) throws -> SupabaseManualPushProductUpdatePayload {
        let value = try createProduct(localID)
        return .init(barcode: value.barcode, itemNumber: value.itemNumber, productName: value.productName,
            secondProductName: value.secondProductName, purchasePrice: value.purchasePrice, retailPrice: value.retailPrice,
            supplierID: value.supplierID, categoryID: value.categoryID, stockQuantity: value.stockQuantity)
    }

    func apply(_ row: RemoteInventorySupplierRow, localID: String) throws {
        guard let target = suppliers[localID], let scope = snapshot.scope,
              row.ownerUserID == owner, row.shopID == scope.shopID, row.deletedAt == nil,
              SupabaseRemoteDateParser.parse(row.updatedAt) != nil,
              ManualPushFingerprintNormalizer.supplier(remoteID: row.id, name: row.name) == ManualPushFingerprintNormalizer.supplier(remoteID: row.id, name: target.name),
              target.remoteID == nil || row.id == target.remoteID else { throw LocalPendingManualDispatchError.staleBatch }
        try withCurrent { context in
            let value = try Task126OwnerStoreGate.requireLocalModel(Supplier.self, id: target.id, in: context)
            let id = row.id
            guard try context.fetch(FetchDescriptor<Supplier>(predicate: #Predicate { $0.remoteID == id }))
                .allSatisfy({ $0.persistentModelID == target.id }) else { throw LocalPendingManualDispatchError.staleBatch }
            value.remoteID = row.id; value.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
            value.remoteDeletedAt = nil
            try LocalCatalogBodyProofStore.record(row, context: context, scope: scope)
            try context.save()
        }
        supplierLinks[target.id] = row.id
        verifiedReadOnlyChangeIDs.formUnion(readOnlyMemberIDsByTarget[LocalPendingChangeEntityKind.supplier.rawValue + ":" + localID] ?? [])
    }
    func apply(_ row: RemoteInventoryCategoryRow, localID: String) throws {
        guard let target = categories[localID], let scope = snapshot.scope,
              row.ownerUserID == owner, row.shopID == scope.shopID, row.deletedAt == nil,
              SupabaseRemoteDateParser.parse(row.updatedAt) != nil,
              ManualPushFingerprintNormalizer.category(remoteID: row.id, name: row.name) == ManualPushFingerprintNormalizer.category(remoteID: row.id, name: target.name),
              target.remoteID == nil || row.id == target.remoteID else { throw LocalPendingManualDispatchError.staleBatch }
        try withCurrent { context in
            let value = try Task126OwnerStoreGate.requireLocalModel(ProductCategory.self, id: target.id, in: context)
            let id = row.id
            guard try context.fetch(FetchDescriptor<ProductCategory>(predicate: #Predicate { $0.remoteID == id }))
                .allSatisfy({ $0.persistentModelID == target.id }) else { throw LocalPendingManualDispatchError.staleBatch }
            value.remoteID = row.id; value.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
            value.remoteDeletedAt = nil
            try LocalCatalogBodyProofStore.record(row, context: context, scope: scope)
            try context.save()
        }
        categoryLinks[target.id] = row.id
        verifiedReadOnlyChangeIDs.formUnion(readOnlyMemberIDsByTarget[LocalPendingChangeEntityKind.productCategory.rawValue + ":" + localID] ?? [])
    }
    func apply(_ row: RemoteInventoryProductRow, localID: String) throws {
        guard let target = products[localID], let scope = snapshot.scope,
              row.ownerUserID == owner, row.shopID == scope.shopID, row.deletedAt == nil,
              SupabaseRemoteDateParser.parse(row.updatedAt) != nil,
              CatalogConflictProductValues(row: row).fingerprint == expected(target).fingerprint,
              target.remoteID == nil || row.id == target.remoteID else { throw LocalPendingManualDispatchError.staleBatch }
        try withCurrent { context in
            let value = try Task126OwnerStoreGate.requireLocalModel(Product.self, id: target.id, in: context)
            let id = row.id
            guard try context.fetch(FetchDescriptor<Product>(predicate: #Predicate { $0.remoteID == id }))
                .allSatisfy({ $0.persistentModelID == target.id }) else { throw LocalPendingManualDispatchError.staleBatch }
            value.remoteID = row.id; value.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
            value.remoteDeletedAt = nil; value.primaryImageVersionID = row.primaryImageVersionID
            value.primaryImageUpdatedAt = SupabaseRemoteDateParser.parse(row.primaryImageUpdatedAt)
            try LocalCatalogBodyProofStore.record(row, context: context, scope: scope)
            try context.save()
        }
        productLinks[target.id] = row.id
        verifiedReadOnlyChangeIDs.formUnion(readOnlyMemberIDsByTarget[LocalPendingChangeEntityKind.product.rawValue + ":" + localID] ?? [])
    }
    func tombstonePayload() -> SupabaseManualPushProductUpdatePayload {
        .init(barcode: nil, itemNumber: nil, productName: nil, secondProductName: nil,
            purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil,
            stockQuantity: nil, deletedAt: tombstoneTimestamp)
    }
    func validateTombstone(_ row: RemoteInventoryProductRow, remoteID: UUID) throws {
        guard let scope = snapshot.scope, row.id == remoteID, row.ownerUserID == owner,
              row.shopID == scope.shopID, let deletedAt = row.deletedAt.flatMap(SupabaseRemoteDateParser.parse),
              deletedAt == SupabaseRemoteDateParser.parse(tombstoneTimestamp) else {
            throw LocalPendingManualDispatchError.staleBatch
        }
        try withCurrent { context in
            try LocalCatalogBodyProofStore.record(row, context: context, scope: scope)
            try context.save()
        }
    }
    func readBackExpectation(touchedIDs: SupabaseManualPushTouchedIDs) throws -> SupabaseManualPushReadBackExpectation {
        try withCurrent { _ in
            var value = SupabaseManualPushReadBackExpectation()
            for target in suppliers.values {
                if let id = supplierLinks[target.id] ?? target.remoteID, touchedIDs.suppliers.contains(id) {
                    value.supplierFingerprintsByID[id] = ManualPushFingerprintNormalizer.supplier(remoteID: id, name: target.name)
                }
            }
            for target in categories.values {
                if let id = categoryLinks[target.id] ?? target.remoteID, touchedIDs.categories.contains(id) {
                    value.categoryFingerprintsByID[id] = ManualPushFingerprintNormalizer.category(remoteID: id, name: target.name)
                }
            }
            for target in products.values {
                if let id = productLinks[target.id] ?? target.remoteID, touchedIDs.products.contains(id) {
                    let p = expected(target)
                    value.productFingerprintsByID[id] = ManualPushFingerprintNormalizer.product(barcode: p.barcode,
                        itemNumber: p.itemNumber, productName: p.productName, secondProductName: p.secondProductName,
                        purchasePrice: p.purchasePrice, retailPrice: p.retailPrice, stockQuantity: p.stockQuantity,
                        supplierRemoteID: p.supplierID, categoryRemoteID: p.categoryID)
                }
            }
            guard value.touchedIDs == touchedIDs else { throw LocalPendingManualDispatchError.staleBatch }
            return value
        }
    }
    func commitBaseline(writer: SupabaseCatalogBaselineWriter) throws -> SupabaseCatalogBaselineCommitResult {
        try withCurrent { context in
            // A global baseline must not absorb an independent unsent D.
            // Preserve the previous baseline while the confirmed original batch
            // may still receive its own exact ACK.
            let retired = try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: context)
            let ownerString = owner.uuidString.lowercased()
            var descriptor = FetchDescriptor<LocalPendingChange>(predicate: #Predicate {
                $0.ownerUserID == ownerString && $0.statusRaw != "acknowledged" && $0.statusRaw != "superseded"
            })
            descriptor.fetchLimit = LocalPendingAggregatedPushPlanner.defaultHardCap + 1
            let active = try context.fetch(descriptor)
            guard active.count <= LocalPendingAggregatedPushPlanner.defaultHardCap,
                  active.filter({ $0.entityKind.isCatalogKind && !retired.contains($0.changeID) })
                    .allSatisfy({ row in snapshot.tokens.contains { $0.changeID == row.changeID } }) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            // The explicit expected-scope fence is already held. The baseline
            // writer's optional implicit TaskLocal lease must not lock it twice.
            return try Task126OwnerStoreGate.$currentAutomaticScope.withValue(nil) {
                try writer.commitLatestBaseline(context: context, ownerUserUUID: owner)
            }
        }
    }
}

@MainActor
final class SupabaseManualPushService {
    private let remote: SupabaseManualPushRemoteGateway
    private let baselineWriter: SupabaseCatalogBaselineWriter
    private let maxBatchSize: Int

    init(
        remote: SupabaseManualPushRemoteGateway,
        baselineWriter: SupabaseCatalogBaselineWriter? = nil,
        maxBatchSize: Int = 50
    ) {
        self.remote = remote
        self.baselineWriter = baselineWriter ?? SupabaseCatalogBaselineWriter()
        self.maxBatchSize = max(1, maxBatchSize)
    }

    convenience init(clientProvider: SupabaseClientProvider) {
        self.init(remote: SupabaseManualPushRemoteClient(clientProvider: clientProvider))
    }

    func execute(
        plan: ManualPushPlan,
        context: ModelContext,
        ownerUserID: UUID,
        pendingExecution: ManualPendingCatalogExecution? = nil
    ) async -> SupabaseManualPushResult {
        guard plan.ownerUserID == ownerUserID,
              plan.isSendable,
              !plan.hasBlockers else {
            return .blocked(message: "Plan is not safe to send.")
        }

        do {
            try validateScopedPlanIfNeeded(plan: plan, context: context)
        } catch {
            return .blocked(message: sanitized(error))
        }

        var counters = Counters()
        var touchedIDs = SupabaseManualPushTouchedIDs()
        var tombstoneIDs = SupabaseManualPushTouchedIDs()
        var readBackIDs = SupabaseManualPushTouchedIDs()
        var didConfirmAnyRemoteWrite = false
        var didConfirmAnyRemoteOrLink = false

        do {
            try await pushSuppliers(
                plan: plan,
                context: context,
                ownerUserID: ownerUserID,
                pendingExecution: pendingExecution,
                counters: &counters,
                touchedIDs: &touchedIDs,
                readBackIDs: &readBackIDs,
                didConfirmAnyRemoteWrite: &didConfirmAnyRemoteWrite,
                didConfirmAnyRemoteOrLink: &didConfirmAnyRemoteOrLink
            )
            try await pushCategories(
                plan: plan,
                context: context,
                ownerUserID: ownerUserID,
                pendingExecution: pendingExecution,
                counters: &counters,
                touchedIDs: &touchedIDs,
                readBackIDs: &readBackIDs,
                didConfirmAnyRemoteWrite: &didConfirmAnyRemoteWrite,
                didConfirmAnyRemoteOrLink: &didConfirmAnyRemoteOrLink
            )
            try await pushProducts(
                plan: plan,
                context: context,
                ownerUserID: ownerUserID,
                pendingExecution: pendingExecution,
                counters: &counters,
                touchedIDs: &touchedIDs,
                tombstoneIDs: &tombstoneIDs,
                readBackIDs: &readBackIDs,
                didConfirmAnyRemoteWrite: &didConfirmAnyRemoteWrite,
                didConfirmAnyRemoteOrLink: &didConfirmAnyRemoteOrLink
            )
        } catch {
            return makeResult(
                status: didConfirmAnyRemoteWrite || didConfirmAnyRemoteOrLink ? .partial : .failedBeforeWrite,
                counters: counters,
                touchedIDs: touchedIDs,
                tombstoneIDs: tombstoneIDs,
                baselineRunID: nil,
                message: sanitized(error)
            )
        }

        guard !touchedIDs.isEmpty else {
            return makeResult(
                status: .completed,
                counters: counters,
                touchedIDs: touchedIDs,
                tombstoneIDs: tombstoneIDs,
                baselineRunID: nil,
                message: nil
            )
        }

        if let pendingExecution, !readBackIDs.isEmpty {
            do {
                let expectation = try pendingExecution.readBackExpectation(touchedIDs: readBackIDs)
                try await remote.verifyReadBack(expectation: expectation)
            } catch {
                return makeResult(status: didConfirmAnyRemoteWrite ? .partial : .failedBeforeWrite,
                    counters: counters, touchedIDs: touchedIDs, tombstoneIDs: tombstoneIDs,
                    baselineRunID: nil, message: sanitized(error))
            }
        }
        do {
            if pendingExecution == nil, !readBackIDs.isEmpty {
                let expectation = try pendingExecution?.readBackExpectation(touchedIDs: readBackIDs)
                    ?? makeReadBackExpectation(context: context, touchedIDs: readBackIDs)
                try await remote.verifyReadBack(expectation: expectation)
            }
            let baseline = try pendingExecution?.commitBaseline(writer: baselineWriter)
                ?? baselineWriter.commitLatestBaseline(context: context, ownerUserUUID: ownerUserID)
            return makeResult(
                status: .completed,
                counters: counters,
                touchedIDs: touchedIDs,
                tombstoneIDs: tombstoneIDs,
                baselineRunID: baseline.baselineRunID,
                message: nil
            )
        } catch {
            return makeResult(
                status: didConfirmAnyRemoteWrite ? .completedBaselineRefreshFailed : .failedBeforeWrite,
                counters: counters,
                touchedIDs: touchedIDs,
                tombstoneIDs: tombstoneIDs,
                baselineRunID: nil,
                message: sanitized(error)
            )
        }
    }

    private func validateScopedPlanIfNeeded(
        plan: ManualPushPlan,
        context: ModelContext
    ) throws {
        guard plan.scope.isScopedTask045 else {
            return
        }
        guard !plan.scopeSummary.hasScopedBlocker else {
            throw SupabaseTransportClientError.schemaDrift(message: "Scoped TASK045 plan is blocked before remote write.")
        }

        let suppliersByName = try fetchSuppliersByName(context: context)
        let categoriesByName = try fetchCategoriesByName(context: context)
        let productsByBarcode = try fetchProductsByBarcode(context: context)

        for candidate in plan.writeCandidates {
            switch candidate.entityKind {
            case .supplier:
                guard let supplier = suppliersByName[candidate.localID],
                      ManualPushTask045Scope.contains(supplier) else {
                    throw SupabaseTransportClientError.schemaDrift(message: "Scoped TASK045 supplier payload contains an outside-scope record.")
                }
            case .productCategory:
                guard let category = categoriesByName[candidate.localID],
                      ManualPushTask045Scope.contains(category) else {
                    throw SupabaseTransportClientError.schemaDrift(message: "Scoped TASK045 category payload contains an outside-scope record.")
                }
            case .product:
                guard let product = productsByBarcode[candidate.localID],
                      ManualPushTask045Scope.contains(product),
                      scopedProductDependenciesAreRemoteSafe(product) else {
                    throw SupabaseTransportClientError.schemaDrift(message: "Scoped TASK045 product payload contains an outside-scope record or dependency.")
                }
            case .productPrice:
                throw SupabaseTransportClientError.schemaDrift(message: "Scoped TASK045 payload cannot contain ProductPrice.")
            }
        }
    }

    private func scopedProductDependenciesAreRemoteSafe(_ product: Product) -> Bool {
        if let supplier = product.supplier,
           !ManualPushTask045Scope.contains(supplier),
           supplier.remoteID == nil {
            return false
        }
        if let category = product.category,
           !ManualPushTask045Scope.contains(category),
           category.remoteID == nil {
            return false
        }
        return true
    }

    private func pushSuppliers(
        plan: ManualPushPlan,
        context: ModelContext,
        ownerUserID: UUID,
        pendingExecution: ManualPendingCatalogExecution?,
        counters: inout Counters,
        touchedIDs: inout SupabaseManualPushTouchedIDs,
        readBackIDs: inout SupabaseManualPushTouchedIDs,
        didConfirmAnyRemoteWrite: inout Bool,
        didConfirmAnyRemoteOrLink: inout Bool
    ) async throws {
        let candidates = plan.writeCandidates
            .filter { $0.entityKind == .supplier }
            .sorted { $0.localID < $1.localID }
        let suppliersByName = try fetchSuppliersByName(context: context)

        let createSuppliers = candidates
            .filter { $0.action == .dryRunCreateCandidate }
            .compactMap { suppliersByName[$0.localID] }
        let createRows = try await createSupplierRows(createSuppliers, ownerUserID: ownerUserID, pendingExecution: pendingExecution)
        if !createSuppliers.isEmpty {
            didConfirmAnyRemoteWrite = true
        }
        guard createRows.count == createSuppliers.count else {
            throw SupabaseTransportClientError.schemaDrift(message: "Supplier create response count mismatch.")
        }
        if pendingExecution != nil {
            let requested = createSuppliers.map(\.name)
            guard Set(requested).count == requested.count,
                  Set(createRows.map(\.id)).count == createRows.count,
                  Set(createRows.map(\.name)).count == createRows.count,
                  Set(createRows.map(\.name)) == Set(requested) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
        }
        for row in createRows {
            guard let supplier = suppliersByName[row.name] else {
                throw SupabaseTransportClientError.schemaDrift(message: "Supplier create response did not match a local record.")
            }
            if let pendingExecution {
                try pendingExecution.apply(row, localID: supplier.name)
            } else {
                apply(row: row, to: supplier)
                try save(context)
            }
            counters.supplierCreates += 1
            touchedIDs.suppliers.insert(row.id)
            readBackIDs.suppliers.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunLinkCandidate {
            guard let supplier = suppliersByName[candidate.localID],
                  let remoteID = candidate.remoteID,
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(supplier.name) else {
                throw SupabaseTransportClientError.schemaDrift(message: "Missing supplier link target.")
            }
            try pendingExecution?.beforeRequest()
            let row = try await remote.verifySupplier(id: remoteID, normalizedName: normalizedName)
            if pendingExecution != nil, row.id != remoteID { throw LocalPendingManualDispatchError.staleBatch }
            if let pendingExecution {
                try pendingExecution.apply(row, localID: supplier.name)
            } else {
                apply(row: row, to: supplier)
                try save(context)
            }
            counters.supplierLinks += 1
            touchedIDs.suppliers.insert(row.id)
            readBackIDs.suppliers.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunUpdateCandidate {
            guard let supplier = suppliersByName[candidate.localID],
                  let remoteID = supplier.remoteID else {
                throw SupabaseTransportClientError.schemaDrift(message: "Missing supplier update target.")
            }
            try pendingExecution?.beforeRequest()
            let row = try await remote.updateSupplier(
                id: remoteID,
                payload: SupabaseManualPushSupplierUpdatePayload(name: try pendingExecution?.supplierName(candidate.localID) ?? supplier.name)
            )
            didConfirmAnyRemoteWrite = true
            if let pendingExecution {
                try pendingExecution.apply(row, localID: supplier.name)
            } else {
                apply(row: row, to: supplier)
                try save(context)
            }
            counters.supplierUpdates += 1
            touchedIDs.suppliers.insert(row.id)
            readBackIDs.suppliers.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }
    }

    private func pushCategories(
        plan: ManualPushPlan,
        context: ModelContext,
        ownerUserID: UUID,
        pendingExecution: ManualPendingCatalogExecution?,
        counters: inout Counters,
        touchedIDs: inout SupabaseManualPushTouchedIDs,
        readBackIDs: inout SupabaseManualPushTouchedIDs,
        didConfirmAnyRemoteWrite: inout Bool,
        didConfirmAnyRemoteOrLink: inout Bool
    ) async throws {
        let candidates = plan.writeCandidates
            .filter { $0.entityKind == .productCategory }
            .sorted { $0.localID < $1.localID }
        let categoriesByName = try fetchCategoriesByName(context: context)

        let createCategories = candidates
            .filter { $0.action == .dryRunCreateCandidate }
            .compactMap { categoriesByName[$0.localID] }
        let createRows = try await createCategoryRows(createCategories, ownerUserID: ownerUserID, pendingExecution: pendingExecution)
        if !createCategories.isEmpty {
            didConfirmAnyRemoteWrite = true
        }
        guard createRows.count == createCategories.count else {
            throw SupabaseTransportClientError.schemaDrift(message: "Category create response count mismatch.")
        }
        if pendingExecution != nil {
            let requested = createCategories.map(\.name)
            guard Set(requested).count == requested.count,
                  Set(createRows.map(\.id)).count == createRows.count,
                  Set(createRows.map(\.name)).count == createRows.count,
                  Set(createRows.map(\.name)) == Set(requested) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
        }
        for row in createRows {
            guard let category = categoriesByName[row.name] else {
                throw SupabaseTransportClientError.schemaDrift(message: "Category create response did not match a local record.")
            }
            if let pendingExecution {
                try pendingExecution.apply(row, localID: category.name)
            } else {
                apply(row: row, to: category)
                try save(context)
            }
            counters.categoryCreates += 1
            touchedIDs.categories.insert(row.id)
            readBackIDs.categories.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunLinkCandidate {
            guard let category = categoriesByName[candidate.localID],
                  let remoteID = candidate.remoteID,
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(category.name) else {
                throw SupabaseTransportClientError.schemaDrift(message: "Missing category link target.")
            }
            try pendingExecution?.beforeRequest()
            let row = try await remote.verifyCategory(id: remoteID, normalizedName: normalizedName)
            if pendingExecution != nil, row.id != remoteID { throw LocalPendingManualDispatchError.staleBatch }
            if let pendingExecution {
                try pendingExecution.apply(row, localID: category.name)
            } else {
                apply(row: row, to: category)
                try save(context)
            }
            counters.categoryLinks += 1
            touchedIDs.categories.insert(row.id)
            readBackIDs.categories.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunUpdateCandidate {
            guard let category = categoriesByName[candidate.localID],
                  let remoteID = category.remoteID else {
                throw SupabaseTransportClientError.schemaDrift(message: "Missing category update target.")
            }
            try pendingExecution?.beforeRequest()
            let row = try await remote.updateCategory(
                id: remoteID,
                payload: SupabaseManualPushCategoryUpdatePayload(name: try pendingExecution?.categoryName(candidate.localID) ?? category.name)
            )
            didConfirmAnyRemoteWrite = true
            if let pendingExecution {
                try pendingExecution.apply(row, localID: category.name)
            } else {
                apply(row: row, to: category)
                try save(context)
            }
            counters.categoryUpdates += 1
            touchedIDs.categories.insert(row.id)
            readBackIDs.categories.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }
    }

    private func pushProducts(
        plan: ManualPushPlan,
        context: ModelContext,
        ownerUserID: UUID,
        pendingExecution: ManualPendingCatalogExecution?,
        counters: inout Counters,
        touchedIDs: inout SupabaseManualPushTouchedIDs,
        tombstoneIDs: inout SupabaseManualPushTouchedIDs,
        readBackIDs: inout SupabaseManualPushTouchedIDs,
        didConfirmAnyRemoteWrite: inout Bool,
        didConfirmAnyRemoteOrLink: inout Bool
    ) async throws {
        let candidates = plan.writeCandidates
            .filter { $0.entityKind == .product }
            .sorted { $0.localID < $1.localID }
        let productsByBarcode = try fetchProductsByBarcode(context: context)

        let createProducts = try candidates
            .filter { $0.action == .dryRunCreateCandidate }
            .map { candidate -> Product in
                guard let product = productsByBarcode[candidate.localID] else {
                    throw SupabaseTransportClientError.schemaDrift(message: "Missing product create target.")
                }
                return product
            }
        let createRows = try await createProductRows(createProducts, ownerUserID: ownerUserID, pendingExecution: pendingExecution)
        if !createProducts.isEmpty {
            didConfirmAnyRemoteWrite = true
        }
        guard createRows.count == createProducts.count else {
            throw SupabaseTransportClientError.schemaDrift(message: "Product create response count mismatch.")
        }
        if pendingExecution != nil {
            let requested = createProducts.map(\.barcode)
            guard Set(requested).count == requested.count,
                  Set(createRows.map(\.id)).count == createRows.count,
                  Set(createRows.map(\.barcode)).count == createRows.count,
                  Set(createRows.map(\.barcode)) == Set(requested) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
        }
        for row in createRows {
            guard let product = productsByBarcode[row.barcode] else {
                throw SupabaseTransportClientError.schemaDrift(message: "Product create response did not match a local record.")
            }
            if let pendingExecution {
                try pendingExecution.apply(row, localID: product.barcode)
            } else {
                apply(row: row, to: product)
                try save(context)
            }
            counters.productCreates += 1
            touchedIDs.products.insert(row.id)
            readBackIDs.products.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunLinkCandidate {
            guard let product = productsByBarcode[candidate.localID],
                  let remoteID = candidate.remoteID,
                  let normalizedBarcode = ManualPushFingerprintNormalizer.semanticString(product.barcode) else {
                throw SupabaseTransportClientError.schemaDrift(message: "Missing product link target.")
            }
            try pendingExecution?.beforeRequest()
            let row = try await remote.verifyProduct(id: remoteID, normalizedBarcode: normalizedBarcode)
            if pendingExecution != nil, row.id != remoteID { throw LocalPendingManualDispatchError.staleBatch }
            if let pendingExecution {
                try pendingExecution.apply(row, localID: product.barcode)
            } else {
                apply(row: row, to: product)
                try save(context)
            }
            counters.productLinks += 1
            touchedIDs.products.insert(row.id)
            readBackIDs.products.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunTombstoneCandidate {
            guard let remoteID = candidate.remoteID else {
                throw SupabaseTransportClientError.schemaDrift(message: "Missing product tombstone target.")
            }
            try pendingExecution?.beforeRequest()
            let row = try await remote.updateProduct(
                id: remoteID,
                payload: pendingExecution?.tombstonePayload() ?? makeProductTombstonePayload()
            )
            try pendingExecution?.validateTombstone(row, remoteID: remoteID)
            guard SupabasePullPreviewNormalizer.semanticString(row.deletedAt) != nil else {
                throw SupabaseTransportClientError.schemaDrift(message: "Product tombstone response did not include deleted_at.")
            }
            didConfirmAnyRemoteWrite = true
            counters.productUpdates += 1
            touchedIDs.products.insert(remoteID)
            tombstoneIDs.products.insert(remoteID)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunUpdateCandidate {
            guard let product = productsByBarcode[candidate.localID],
                  let remoteID = product.remoteID else {
                throw SupabaseTransportClientError.schemaDrift(message: "Missing product update target.")
            }
            try pendingExecution?.beforeRequest()
            let row = try await remote.updateProduct(
                id: remoteID,
                payload: try pendingExecution?.updateProduct(candidate.localID) ?? makeProductUpdatePayload(product)
            )
            didConfirmAnyRemoteWrite = true
            if let pendingExecution {
                try pendingExecution.apply(row, localID: product.barcode)
            } else {
                apply(row: row, to: product)
                try save(context)
            }
            counters.productUpdates += 1
            touchedIDs.products.insert(row.id)
            readBackIDs.products.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }
    }

    private func createSupplierRows(_ suppliers: [Supplier], ownerUserID: UUID,
                                    pendingExecution: ManualPendingCatalogExecution?) async throws -> [RemoteInventorySupplierRow] {
        let payloads = try suppliers.map {
            SupabaseManualPushSupplierCreatePayload(ownerUserID: ownerUserID,
                name: try pendingExecution?.supplierName($0.name) ?? $0.name)
        }
        return try await createBatched(payloads, allowsFallback: pendingExecution == nil) { batch in
            try pendingExecution?.beforeRequest()
            return try await remote.createSuppliers(batch)
        }
    }

    private func createCategoryRows(_ categories: [ProductCategory], ownerUserID: UUID,
                                    pendingExecution: ManualPendingCatalogExecution?) async throws -> [RemoteInventoryCategoryRow] {
        let payloads = try categories.map {
            SupabaseManualPushCategoryCreatePayload(ownerUserID: ownerUserID,
                name: try pendingExecution?.categoryName($0.name) ?? $0.name)
        }
        return try await createBatched(payloads, allowsFallback: pendingExecution == nil) { batch in
            try pendingExecution?.beforeRequest()
            return try await remote.createCategories(batch)
        }
    }

    private func createProductRows(_ products: [Product], ownerUserID: UUID,
                                   pendingExecution: ManualPendingCatalogExecution?) async throws -> [RemoteInventoryProductRow] {
        let payloads = try products.map {
            try pendingExecution?.createProduct($0.barcode) ?? makeProductCreatePayload($0, ownerUserID: ownerUserID)
        }
        return try await createBatched(payloads, allowsFallback: pendingExecution == nil) { batch in
            try pendingExecution?.beforeRequest()
            return try await remote.createProducts(batch)
        }
    }

    private func createBatched<Item, Row>(
        _ items: [Item],
        allowsFallback: Bool,
        send: ([Item]) async throws -> [Row]
    ) async throws -> [Row] {
        guard !items.isEmpty else { return [] }
        var rows: [Row] = []
        var start = 0
        while start < items.count {
            let end = min(start + maxBatchSize, items.count)
            let batch = Array(items[start..<end])
            rows += try await createBatchWithFallback(batch, allowsFallback: allowsFallback, send: send)
            start = end
        }
        return rows
    }

    private func createBatchWithFallback<Item, Row>(
        _ batch: [Item],
        allowsFallback: Bool,
        send: ([Item]) async throws -> [Row]
    ) async throws -> [Row] {
        do {
            return try await send(batch)
        } catch {
            guard allowsFallback, batch.count > 1 else { throw error }
            let midpoint = batch.count / 2
            let left = try await createBatchWithFallback(Array(batch[..<midpoint]), allowsFallback: allowsFallback, send: send)
            let right = try await createBatchWithFallback(Array(batch[midpoint...]), allowsFallback: allowsFallback, send: send)
            return left + right
        }
    }

    private func makeProductCreatePayload(_ product: Product, ownerUserID: UUID) -> SupabaseManualPushProductCreatePayload {
        SupabaseManualPushProductCreatePayload(
            ownerUserID: ownerUserID,
            barcode: product.barcode,
            itemNumber: SupabasePullPreviewNormalizer.semanticString(product.itemNumber),
            productName: SupabasePullPreviewNormalizer.semanticString(product.productName),
            secondProductName: SupabasePullPreviewNormalizer.semanticString(product.secondProductName),
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice,
            supplierID: product.supplier?.remoteID,
            categoryID: product.category?.remoteID,
            stockQuantity: product.stockQuantity
        )
    }

    private func makeProductTombstonePayload(now: Date = Date()) -> SupabaseManualPushProductUpdatePayload {
        SupabaseManualPushProductUpdatePayload(
            barcode: nil,
            itemNumber: nil,
            productName: nil,
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            deletedAt: Self.tombstoneFormatter.string(from: now)
        )
    }

    private func makeProductUpdatePayload(_ product: Product) -> SupabaseManualPushProductUpdatePayload {
        SupabaseManualPushProductUpdatePayload(
            barcode: ManualPushFingerprintNormalizer.semanticString(product.barcode),
            itemNumber: SupabasePullPreviewNormalizer.semanticString(product.itemNumber),
            productName: SupabasePullPreviewNormalizer.semanticString(product.productName),
            secondProductName: SupabasePullPreviewNormalizer.semanticString(product.secondProductName),
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice,
            supplierID: product.supplier?.remoteID,
            categoryID: product.category?.remoteID,
            stockQuantity: product.stockQuantity
        )
    }

    private func apply(row: RemoteInventorySupplierRow, to supplier: Supplier) {
        supplier.remoteID = row.id
        supplier.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        supplier.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    }

    private func apply(row: RemoteInventoryCategoryRow, to category: ProductCategory) {
        category.remoteID = row.id
        category.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        category.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    }

    private func apply(row: RemoteInventoryProductRow, to product: Product) {
        product.remoteID = row.id
        product.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        product.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
        product.primaryImageVersionID = row.primaryImageVersionID
        product.primaryImageUpdatedAt = SupabaseRemoteDateParser.parse(row.primaryImageUpdatedAt)
    }

    private func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func fetchSuppliersByName(context: ModelContext) throws -> [String: Supplier] {
        let suppliers = try context.fetch(FetchDescriptor<Supplier>(sortBy: [SortDescriptor(\Supplier.name)]))
        return Dictionary(uniqueKeysWithValues: suppliers.map { ($0.name, $0) })
    }

    private func fetchCategoriesByName(context: ModelContext) throws -> [String: ProductCategory] {
        let categories = try context.fetch(FetchDescriptor<ProductCategory>(sortBy: [SortDescriptor(\ProductCategory.name)]))
        return Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0) })
    }

    private func fetchProductsByBarcode(context: ModelContext) throws -> [String: Product] {
        let products = try context.fetch(FetchDescriptor<Product>(sortBy: [SortDescriptor(\Product.barcode)]))
        return Dictionary(uniqueKeysWithValues: products.map { ($0.barcode, $0) })
    }

    private func makeReadBackExpectation(
        context: ModelContext,
        touchedIDs: SupabaseManualPushTouchedIDs
    ) throws -> SupabaseManualPushReadBackExpectation {
        var expectation = SupabaseManualPushReadBackExpectation()

        let suppliers = try context.fetch(FetchDescriptor<Supplier>(sortBy: [SortDescriptor(\Supplier.name)]))
        for supplier in suppliers {
            guard let remoteID = supplier.remoteID, touchedIDs.suppliers.contains(remoteID) else {
                continue
            }
            expectation.supplierFingerprintsByID[remoteID] = ManualPushFingerprintNormalizer.supplier(
                remoteID: remoteID,
                name: supplier.name
            )
        }

        let categories = try context.fetch(FetchDescriptor<ProductCategory>(sortBy: [SortDescriptor(\ProductCategory.name)]))
        for category in categories {
            guard let remoteID = category.remoteID, touchedIDs.categories.contains(remoteID) else {
                continue
            }
            expectation.categoryFingerprintsByID[remoteID] = ManualPushFingerprintNormalizer.category(
                remoteID: remoteID,
                name: category.name
            )
        }

        let products = try context.fetch(FetchDescriptor<Product>(sortBy: [SortDescriptor(\Product.barcode)]))
        for product in products {
            guard let remoteID = product.remoteID, touchedIDs.products.contains(remoteID) else {
                continue
            }
            expectation.productFingerprintsByID[remoteID] = ManualPushFingerprintNormalizer.product(
                barcode: product.barcode,
                itemNumber: product.itemNumber,
                productName: product.productName,
                secondProductName: product.secondProductName,
                purchasePrice: product.purchasePrice,
                retailPrice: product.retailPrice,
                stockQuantity: product.stockQuantity,
                supplierRemoteID: product.supplier?.remoteID,
                categoryRemoteID: product.category?.remoteID
            )
        }

        guard expectation.touchedIDs == touchedIDs else {
            throw SupabaseTransportClientError.schemaDrift(message: "Local read-back expectation mismatch.")
        }
        return expectation
    }

    private func makeResult(
        status: SupabaseManualPushTerminalStatus,
        counters: Counters,
        touchedIDs: SupabaseManualPushTouchedIDs,
        tombstoneIDs: SupabaseManualPushTouchedIDs,
        baselineRunID: UUID?,
        message: String?
    ) -> SupabaseManualPushResult {
        SupabaseManualPushResult(
            status: status,
            supplierCreates: counters.supplierCreates,
            supplierUpdates: counters.supplierUpdates,
            supplierLinks: counters.supplierLinks,
            categoryCreates: counters.categoryCreates,
            categoryUpdates: counters.categoryUpdates,
            categoryLinks: counters.categoryLinks,
            productCreates: counters.productCreates,
            productUpdates: counters.productUpdates,
            productLinks: counters.productLinks,
            touchedIDs: touchedIDs,
            tombstoneIDs: tombstoneIDs,
            baselineRunID: baselineRunID,
            message: message
        )
    }

    private func sanitized(_ error: Error) -> String? {
        if let serviceError = error as? SupabaseTransportClientError {
            return serviceError.safeDiagnosticDetail ?? String(describing: serviceError)
        }
        let detail = String(describing: error)
        return SupabaseTransportClientError.sanitizedDiagnosticDetail(detail) ?? "Unknown error"
    }

    private struct Counters {
        var supplierCreates = 0
        var supplierUpdates = 0
        var supplierLinks = 0
        var categoryCreates = 0
        var categoryUpdates = 0
        var categoryLinks = 0
        var productCreates = 0
        var productUpdates = 0
        var productLinks = 0
    }

    private static let tombstoneFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
