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
    let baselineRunID: UUID?
    let message: String?

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

actor SupabaseManualPushRemoteClient: SupabaseManualPushRemoteGateway {
    private enum Table {
        static let suppliers = "inventory_suppliers"
        static let categories = "inventory_categories"
        static let products = "inventory_products"
        static let supplierColumns = "id,owner_user_id,name,updated_at,deleted_at"
        static let categoryColumns = "id,owner_user_id,name,updated_at,deleted_at"
        static let productColumns = "id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at"
    }

    private let clientProvider: SupabaseClientProvider

    init(clientProvider: SupabaseClientProvider) {
        self.clientProvider = clientProvider
    }

    func createSuppliers(_ payloads: [SupabaseManualPushSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        try await insert(payloads, table: Table.suppliers, columns: Table.supplierColumns)
    }

    func updateSupplier(id: UUID, payload: SupabaseManualPushSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        try await update(payload, table: Table.suppliers, columns: Table.supplierColumns, id: id)
    }

    func verifySupplier(id: UUID, normalizedName: String) async throws -> RemoteInventorySupplierRow {
        let row: RemoteInventorySupplierRow = try await fetchByID(table: Table.suppliers, columns: Table.supplierColumns, id: id)
        guard SupabasePullPreviewNormalizer.normalizedLookupName(row.name) == normalizedName else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "Supplier natural key mismatch.")
        }
        return row
    }

    func createCategories(_ payloads: [SupabaseManualPushCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        try await insert(payloads, table: Table.categories, columns: Table.categoryColumns)
    }

    func updateCategory(id: UUID, payload: SupabaseManualPushCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        try await update(payload, table: Table.categories, columns: Table.categoryColumns, id: id)
    }

    func verifyCategory(id: UUID, normalizedName: String) async throws -> RemoteInventoryCategoryRow {
        let row: RemoteInventoryCategoryRow = try await fetchByID(table: Table.categories, columns: Table.categoryColumns, id: id)
        guard SupabasePullPreviewNormalizer.normalizedLookupName(row.name) == normalizedName else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "Category natural key mismatch.")
        }
        return row
    }

    func createProducts(_ payloads: [SupabaseManualPushProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        try await insert(payloads, table: Table.products, columns: Table.productColumns)
    }

    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        try await update(payload, table: Table.products, columns: Table.productColumns, id: id)
    }

    func verifyProduct(id: UUID, normalizedBarcode: String) async throws -> RemoteInventoryProductRow {
        let row: RemoteInventoryProductRow = try await fetchByID(table: Table.products, columns: Table.productColumns, id: id)
        guard ManualPushFingerprintNormalizer.semanticString(row.barcode) == normalizedBarcode else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "Product natural key mismatch.")
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
                throw SupabaseInventoryServiceError.schemaDrift(message: "Supplier read-back mismatch.")
            }
            for row in rows {
                guard expectation.supplierFingerprintsByID[row.id] == remoteFingerprint(row) else {
                    throw SupabaseInventoryServiceError.schemaDrift(message: "Supplier read-back fingerprint mismatch.")
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
                throw SupabaseInventoryServiceError.schemaDrift(message: "Category read-back mismatch.")
            }
            for row in rows {
                guard expectation.categoryFingerprintsByID[row.id] == remoteFingerprint(row) else {
                    throw SupabaseInventoryServiceError.schemaDrift(message: "Category read-back fingerprint mismatch.")
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
                throw SupabaseInventoryServiceError.schemaDrift(message: "Product read-back mismatch.")
            }
            for row in rows {
                guard expectation.productFingerprintsByID[row.id] == remoteFingerprint(row) else {
                    throw SupabaseInventoryServiceError.schemaDrift(message: "Product read-back fingerprint mismatch.")
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

    private func insert<Row: Decodable & Sendable>(
        _ payloads: some Encodable,
        table: String,
        columns: String
    ) async throws -> [Row] {
        try await requireAuthenticatedSession()
        do {
            return try await clientProvider.client
                .from(table)
                .insert(payloads)
                .select(columns)
                .execute()
                .value
        } catch {
            throw mapRemoteError(error)
        }
    }

    private func update<Row: Decodable & Sendable>(
        _ payload: some Encodable,
        table: String,
        columns: String,
        id: UUID
    ) async throws -> Row {
        try await requireAuthenticatedSession()
        do {
            return try await clientProvider.client
                .from(table)
                .update(payload)
                .eq("id", value: id.uuidString)
                .select(columns)
                .single()
                .execute()
                .value
        } catch {
            throw mapRemoteError(error)
        }
    }

    private func fetchByID<Row: Decodable & Sendable>(
        table: String,
        columns: String,
        id: UUID
    ) async throws -> Row {
        try await requireAuthenticatedSession()
        do {
            return try await clientProvider.client
                .from(table)
                .select(columns)
                .eq("id", value: id.uuidString)
                .limit(1)
                .single()
                .execute()
                .value
        } catch {
            throw mapRemoteError(error)
        }
    }

    private func fetchByIDs<Row: Decodable & Sendable>(
        table: String,
        columns: String,
        ids: Set<UUID>
    ) async throws -> [Row] {
        try await requireAuthenticatedSession()
        do {
            return try await clientProvider.client
                .from(table)
                .select(columns)
                .in("id", values: ids.sorted { $0.uuidString < $1.uuidString }.map(\.uuidString))
                .execute()
                .value
        } catch {
            throw mapRemoteError(error)
        }
    }

    private func requireAuthenticatedSession() async throws {
        do {
            _ = try await clientProvider.client.auth.session
        } catch {
            throw SupabaseInventoryServiceError.sessionMissing
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
                return SupabaseInventoryServiceError.permissionDeniedOrRLS(
                    statusCode: nil,
                    code: error.code,
                    message: error.message
                )
            }
            if error.code == "42P01" || error.code == "42703" || error.code == "PGRST204" {
                return SupabaseInventoryServiceError.schemaDrift(message: error.message)
            }
            return SupabaseInventoryServiceError.unknown(message: error.message)
        }
        if let error = error as? DecodingError {
            return SupabaseInventoryServiceError.decodingError(message: String(describing: error))
        }
        if let error = error as? URLError {
            return SupabaseInventoryServiceError.networkError(statusCode: nil, message: error.localizedDescription)
        }
        return error
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
        ownerUserID: UUID
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
        var didConfirmAnyRemoteWrite = false
        var didConfirmAnyRemoteOrLink = false

        do {
            try await pushSuppliers(
                plan: plan,
                context: context,
                ownerUserID: ownerUserID,
                counters: &counters,
                touchedIDs: &touchedIDs,
                didConfirmAnyRemoteWrite: &didConfirmAnyRemoteWrite,
                didConfirmAnyRemoteOrLink: &didConfirmAnyRemoteOrLink
            )
            try await pushCategories(
                plan: plan,
                context: context,
                ownerUserID: ownerUserID,
                counters: &counters,
                touchedIDs: &touchedIDs,
                didConfirmAnyRemoteWrite: &didConfirmAnyRemoteWrite,
                didConfirmAnyRemoteOrLink: &didConfirmAnyRemoteOrLink
            )
            try await pushProducts(
                plan: plan,
                context: context,
                ownerUserID: ownerUserID,
                counters: &counters,
                touchedIDs: &touchedIDs,
                didConfirmAnyRemoteWrite: &didConfirmAnyRemoteWrite,
                didConfirmAnyRemoteOrLink: &didConfirmAnyRemoteOrLink
            )
        } catch {
            return makeResult(
                status: didConfirmAnyRemoteWrite || didConfirmAnyRemoteOrLink ? .partial : .failedBeforeWrite,
                counters: counters,
                baselineRunID: nil,
                message: sanitized(error)
            )
        }

        guard !touchedIDs.isEmpty else {
            return makeResult(status: .completed, counters: counters, baselineRunID: nil, message: nil)
        }

        do {
            let expectation = try makeReadBackExpectation(context: context, touchedIDs: touchedIDs)
            try await remote.verifyReadBack(expectation: expectation)
            let baseline = try baselineWriter.commitLatestBaseline(
                context: context,
                ownerUserUUID: ownerUserID
            )
            return makeResult(
                status: .completed,
                counters: counters,
                baselineRunID: baseline.baselineRunID,
                message: nil
            )
        } catch {
            return makeResult(
                status: didConfirmAnyRemoteWrite ? .completedBaselineRefreshFailed : .failedBeforeWrite,
                counters: counters,
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
            throw SupabaseInventoryServiceError.schemaDrift(message: "Scoped TASK045 plan is blocked before remote write.")
        }

        let suppliersByName = try fetchSuppliersByName(context: context)
        let categoriesByName = try fetchCategoriesByName(context: context)
        let productsByBarcode = try fetchProductsByBarcode(context: context)

        for candidate in plan.writeCandidates {
            switch candidate.entityKind {
            case .supplier:
                guard let supplier = suppliersByName[candidate.localID],
                      ManualPushTask045Scope.contains(supplier) else {
                    throw SupabaseInventoryServiceError.schemaDrift(message: "Scoped TASK045 supplier payload contains an outside-scope record.")
                }
            case .productCategory:
                guard let category = categoriesByName[candidate.localID],
                      ManualPushTask045Scope.contains(category) else {
                    throw SupabaseInventoryServiceError.schemaDrift(message: "Scoped TASK045 category payload contains an outside-scope record.")
                }
            case .product:
                guard let product = productsByBarcode[candidate.localID],
                      ManualPushTask045Scope.contains(product),
                      scopedProductDependenciesAreRemoteSafe(product) else {
                    throw SupabaseInventoryServiceError.schemaDrift(message: "Scoped TASK045 product payload contains an outside-scope record or dependency.")
                }
            case .productPrice:
                throw SupabaseInventoryServiceError.schemaDrift(message: "Scoped TASK045 payload cannot contain ProductPrice.")
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
        counters: inout Counters,
        touchedIDs: inout SupabaseManualPushTouchedIDs,
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
        let createRows = try await createSupplierRows(createSuppliers, ownerUserID: ownerUserID)
        if !createSuppliers.isEmpty {
            didConfirmAnyRemoteWrite = true
        }
        guard createRows.count == createSuppliers.count else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "Supplier create response count mismatch.")
        }
        for row in createRows {
            guard let supplier = suppliersByName[row.name] else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "Supplier create response did not match a local record.")
            }
            apply(row: row, to: supplier)
            try save(context)
            counters.supplierCreates += 1
            touchedIDs.suppliers.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunLinkCandidate {
            guard let supplier = suppliersByName[candidate.localID],
                  let remoteID = candidate.remoteID,
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(supplier.name) else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "Missing supplier link target.")
            }
            let row = try await remote.verifySupplier(id: remoteID, normalizedName: normalizedName)
            apply(row: row, to: supplier)
            try save(context)
            counters.supplierLinks += 1
            touchedIDs.suppliers.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunUpdateCandidate {
            guard let supplier = suppliersByName[candidate.localID],
                  let remoteID = supplier.remoteID else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "Missing supplier update target.")
            }
            let row = try await remote.updateSupplier(
                id: remoteID,
                payload: SupabaseManualPushSupplierUpdatePayload(name: supplier.name)
            )
            didConfirmAnyRemoteWrite = true
            apply(row: row, to: supplier)
            try save(context)
            counters.supplierUpdates += 1
            touchedIDs.suppliers.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }
    }

    private func pushCategories(
        plan: ManualPushPlan,
        context: ModelContext,
        ownerUserID: UUID,
        counters: inout Counters,
        touchedIDs: inout SupabaseManualPushTouchedIDs,
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
        let createRows = try await createCategoryRows(createCategories, ownerUserID: ownerUserID)
        if !createCategories.isEmpty {
            didConfirmAnyRemoteWrite = true
        }
        guard createRows.count == createCategories.count else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "Category create response count mismatch.")
        }
        for row in createRows {
            guard let category = categoriesByName[row.name] else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "Category create response did not match a local record.")
            }
            apply(row: row, to: category)
            try save(context)
            counters.categoryCreates += 1
            touchedIDs.categories.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunLinkCandidate {
            guard let category = categoriesByName[candidate.localID],
                  let remoteID = candidate.remoteID,
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(category.name) else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "Missing category link target.")
            }
            let row = try await remote.verifyCategory(id: remoteID, normalizedName: normalizedName)
            apply(row: row, to: category)
            try save(context)
            counters.categoryLinks += 1
            touchedIDs.categories.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunUpdateCandidate {
            guard let category = categoriesByName[candidate.localID],
                  let remoteID = category.remoteID else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "Missing category update target.")
            }
            let row = try await remote.updateCategory(
                id: remoteID,
                payload: SupabaseManualPushCategoryUpdatePayload(name: category.name)
            )
            didConfirmAnyRemoteWrite = true
            apply(row: row, to: category)
            try save(context)
            counters.categoryUpdates += 1
            touchedIDs.categories.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }
    }

    private func pushProducts(
        plan: ManualPushPlan,
        context: ModelContext,
        ownerUserID: UUID,
        counters: inout Counters,
        touchedIDs: inout SupabaseManualPushTouchedIDs,
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
                    throw SupabaseInventoryServiceError.schemaDrift(message: "Missing product create target.")
                }
                return product
            }
        let createRows = try await createProductRows(createProducts, ownerUserID: ownerUserID)
        if !createProducts.isEmpty {
            didConfirmAnyRemoteWrite = true
        }
        guard createRows.count == createProducts.count else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "Product create response count mismatch.")
        }
        for row in createRows {
            guard let product = productsByBarcode[row.barcode] else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "Product create response did not match a local record.")
            }
            apply(row: row, to: product)
            try save(context)
            counters.productCreates += 1
            touchedIDs.products.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunLinkCandidate {
            guard let product = productsByBarcode[candidate.localID],
                  let remoteID = candidate.remoteID,
                  let normalizedBarcode = ManualPushFingerprintNormalizer.semanticString(product.barcode) else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "Missing product link target.")
            }
            let row = try await remote.verifyProduct(id: remoteID, normalizedBarcode: normalizedBarcode)
            apply(row: row, to: product)
            try save(context)
            counters.productLinks += 1
            touchedIDs.products.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }

        for candidate in candidates where candidate.action == .dryRunUpdateCandidate {
            guard let product = productsByBarcode[candidate.localID],
                  let remoteID = product.remoteID else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "Missing product update target.")
            }
            let row = try await remote.updateProduct(
                id: remoteID,
                payload: makeProductUpdatePayload(product)
            )
            didConfirmAnyRemoteWrite = true
            apply(row: row, to: product)
            try save(context)
            counters.productUpdates += 1
            touchedIDs.products.insert(row.id)
            didConfirmAnyRemoteOrLink = true
        }
    }

    private func createSupplierRows(_ suppliers: [Supplier], ownerUserID: UUID) async throws -> [RemoteInventorySupplierRow] {
        try await createBatched(suppliers) { batch in
            try await remote.createSuppliers(batch.map {
                SupabaseManualPushSupplierCreatePayload(ownerUserID: ownerUserID, name: $0.name)
            })
        }
    }

    private func createCategoryRows(_ categories: [ProductCategory], ownerUserID: UUID) async throws -> [RemoteInventoryCategoryRow] {
        try await createBatched(categories) { batch in
            try await remote.createCategories(batch.map {
                SupabaseManualPushCategoryCreatePayload(ownerUserID: ownerUserID, name: $0.name)
            })
        }
    }

    private func createProductRows(_ products: [Product], ownerUserID: UUID) async throws -> [RemoteInventoryProductRow] {
        try await createBatched(products) { batch in
            try await remote.createProducts(batch.map {
                makeProductCreatePayload($0, ownerUserID: ownerUserID)
            })
        }
    }

    private func createBatched<Item, Row>(
        _ items: [Item],
        send: ([Item]) async throws -> [Row]
    ) async throws -> [Row] {
        guard !items.isEmpty else { return [] }
        var rows: [Row] = []
        var start = 0
        while start < items.count {
            let end = min(start + maxBatchSize, items.count)
            let batch = Array(items[start..<end])
            rows += try await createBatchWithFallback(batch, send: send)
            start = end
        }
        return rows
    }

    private func createBatchWithFallback<Item, Row>(
        _ batch: [Item],
        send: ([Item]) async throws -> [Row]
    ) async throws -> [Row] {
        do {
            return try await send(batch)
        } catch {
            guard batch.count > 1 else { throw error }
            let midpoint = batch.count / 2
            let left = try await createBatchWithFallback(Array(batch[..<midpoint]), send: send)
            let right = try await createBatchWithFallback(Array(batch[midpoint...]), send: send)
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
            throw SupabaseInventoryServiceError.schemaDrift(message: "Local read-back expectation mismatch.")
        }
        return expectation
    }

    private func makeResult(
        status: SupabaseManualPushTerminalStatus,
        counters: Counters,
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
            baselineRunID: baselineRunID,
            message: message
        )
    }

    private func sanitized(_ error: Error) -> String? {
        if let serviceError = error as? SupabaseInventoryServiceError {
            return serviceError.safeDiagnosticDetail ?? String(describing: serviceError)
        }
        let detail = String(describing: error)
        return SupabaseInventoryServiceError.sanitizedDiagnosticDetail(detail) ?? "Unknown error"
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
}
