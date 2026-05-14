import Foundation
import Supabase

nonisolated enum SupabaseInventoryServiceError: Error, Sendable {
    case configMissing
    case invalidConfig
    case sessionMissing
    case networkError(statusCode: Int?, message: String?)
    case permissionDeniedOrRLS(statusCode: Int?, code: String?, message: String?)
    case decodingError(message: String?)
    case schemaDrift(message: String?)
    case unknown(message: String?)

    var safeDiagnosticDetail: String? {
        switch self {
        case .configMissing, .invalidConfig, .sessionMissing:
            return nil
        case .networkError(let statusCode, let message):
            return Self.detail(statusCode: statusCode, code: nil, message: message)
        case .permissionDeniedOrRLS(let statusCode, let code, let message):
            return Self.detail(statusCode: statusCode, code: code, message: message)
        case .decodingError(let message), .schemaDrift(let message), .unknown(let message):
            return Self.sanitized(message)
        }
    }

    static func sanitizedDiagnosticDetail(_ message: String?) -> String? {
        sanitized(message)
    }

    private static func detail(statusCode: Int?, code: String?, message: String?) -> String? {
        let parts = [
            statusCode.map { "HTTP \($0)" },
            code.map { "code \($0)" },
            sanitized(message)
        ].compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    private static func sanitized(_ message: String?) -> String? {
        guard let text = message?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        let lowercased = text.lowercased()
        if lowercased.contains("authorization")
            || lowercased.contains("bearer ")
            || lowercased.contains("apikey")
            || lowercased.contains("jwt") {
            return nil
        }

        return SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(text, maxLength: 240)
    }
}

nonisolated enum SupabaseInventoryDiagnosticResult: Sendable {
    case catalogProbeSucceeded(rowCount: Int)
}

#if DEBUG
nonisolated struct SupabaseTask045RemoteCollisionSummary: Sendable, Equatable {
    let supplierCount: Int
    let categoryCount: Int
    let productCount: Int

    var totalCount: Int {
        supplierCount + categoryCount + productCount
    }

    var isClear: Bool {
        totalCount == 0
    }
}

nonisolated struct SupabaseTask087RemoteCatalogSnapshot: Sendable {
    let ownerUserID: UUID
    let suppliers: [RemoteInventorySupplierRow]
    let categories: [RemoteInventoryCategoryRow]
    let products: [RemoteInventoryProductRow]
}
#endif

actor SupabaseInventoryService {
    nonisolated static let stablePageOrderColumn = "id"
    nonisolated static let productPriceStablePageOrderColumns = ["product_id", "type", "effective_at", "id"]
    nonisolated static let sharedSheetSessionColumns = "remote_id,payload_version,display_name,timestamp,supplier,category,is_manual_entry,data,session_overlay,owner_user_id,updated_at"

    private let clientProvider: SupabaseClientProvider
#if DEBUG
    private static let task045Prefix = "TASK045_"
    private static let task045UpperBound = "TASK045`"
    nonisolated static let task087Prefix = "TASK087_"
    private static let task087UpperBound = "TASK087`"
    private static let task087SupplierNames = ["TASK087_SUP", "TASK087_SUPPLIER"]
    private static let task087CategoryNames = ["TASK087_CAT", "TASK087_CATEGORY"]
    private static let task087ProductBarcodes = ["TASK087_BAR_A", "TASK087_BAR_I"]
    nonisolated static let task088Prefix = "TASK088_"
    private static let task088UpperBound = "TASK088`"
    private static let task088SupplierName = "TASK088_SUPPLIER"
    private static let task088CategoryName = "TASK088_CATEGORY"
    private static let task088ProductBarcode = "TASK088_BAR_PRICE"
    private static let task088ProductName = "TASK088_PRODUCT"
#endif

    init(clientProvider: SupabaseClientProvider) {
        self.clientProvider = clientProvider
    }

    func testConnection() async throws -> SupabaseInventoryDiagnosticResult {
        try await requireAuthenticatedSession()
        let products = try await fetchProducts(limit: 1)
        return .catalogProbeSucceeded(rowCount: products.count)
    }

#if DEBUG
    func authenticatedTask087OwnerUserID() async throws -> UUID {
        try await requireAuthenticatedSession()
    }

    func fetchTask087RemoteCatalogSnapshot() async throws -> SupabaseTask087RemoteCatalogSnapshot {
        let ownerUserID = try await requireAuthenticatedSession()
        let suppliers = try await fetchTask087Suppliers(ownerUserID: ownerUserID)
        let categories = try await fetchTask087Categories(ownerUserID: ownerUserID)
        let products = try await fetchTask087Products(ownerUserID: ownerUserID)

        guard suppliers.allSatisfy({ $0.ownerUserID == ownerUserID && $0.name.hasPrefix(Self.task087Prefix) }),
              categories.allSatisfy({ $0.ownerUserID == ownerUserID && $0.name.hasPrefix(Self.task087Prefix) }),
              products.allSatisfy({
                  $0.ownerUserID == ownerUserID
                      && $0.barcode.hasPrefix(Self.task087Prefix)
                      && Self.task087ProductBarcodes.contains($0.barcode)
              }) else {
            throw SupabaseInventoryServiceError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "TASK087 owner or prefix mismatch"
            )
        }

        return SupabaseTask087RemoteCatalogSnapshot(
            ownerUserID: ownerUserID,
            suppliers: suppliers,
            categories: categories,
            products: products
        )
    }

    func ensureTask087RemoteSeed() async throws {
        let ownerUserID = try await requireAuthenticatedSession()

        let existingSuppliers = try await fetchTask087Suppliers(ownerUserID: ownerUserID)
        guard existingSuppliers.allSatisfy({
            $0.ownerUserID == ownerUserID
                && Self.task087SupplierNames.contains($0.name)
                && $0.deletedAt == nil
        }) else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "TASK087 supplier collision.")
        }
        let supplier: RemoteInventorySupplierRow
        if let existingSupplier = existingSuppliers.first {
            supplier = existingSupplier
        } else {
            supplier = try await createTask087Supplier(ownerUserID: ownerUserID)
        }

        let existingCategories = try await fetchTask087Categories(ownerUserID: ownerUserID)
        guard existingCategories.allSatisfy({
            $0.ownerUserID == ownerUserID
                && Self.task087CategoryNames.contains($0.name)
                && $0.deletedAt == nil
        }) else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "TASK087 category collision.")
        }
        let category: RemoteInventoryCategoryRow
        if let existingCategory = existingCategories.first {
            category = existingCategory
        } else {
            category = try await createTask087Category(ownerUserID: ownerUserID)
        }

        let existingProducts = try await fetchTask087ProductsByPrefix(ownerUserID: ownerUserID)
        guard existingProducts.allSatisfy({
            $0.ownerUserID == ownerUserID
                && Self.task087ProductBarcodes.contains($0.barcode)
                && $0.deletedAt == nil
        }) else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "TASK087 product collision.")
        }

        var productsByBarcode: [String: RemoteInventoryProductRow] = [:]
        for product in existingProducts {
            guard productsByBarcode[product.barcode] == nil else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "TASK087 duplicate product collision.")
            }
            productsByBarcode[product.barcode] = product
        }
        let missingPayloads = [
            ("TASK087_BAR_A", "TASK087_PRD_A"),
            ("TASK087_BAR_I", "TASK087_PRD_I")
        ].compactMap { barcode, productName -> SupabaseManualPushProductCreatePayload? in
            guard productsByBarcode[barcode] == nil else { return nil }
            return SupabaseManualPushProductCreatePayload(
                ownerUserID: ownerUserID,
                barcode: barcode,
                itemNumber: nil,
                productName: productName,
                secondProductName: nil,
                purchasePrice: nil,
                retailPrice: nil,
                supplierID: supplier.id,
                categoryID: category.id,
                stockQuantity: 0
            )
        }

        guard !missingPayloads.isEmpty else { return }
        let createdProducts = try await createTask087Products(missingPayloads)
        let expectedBarcodes = Set(missingPayloads.map(\.barcode))
        guard Set(createdProducts.map(\.barcode)) == expectedBarcodes,
              createdProducts.allSatisfy({ $0.ownerUserID == ownerUserID }) else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "TASK087 product seed read-back mismatch.")
        }
    }

    func updateTask087ProductName(
        barcode: String,
        newProductName: String
    ) async throws -> RemoteInventoryProductRow {
        let ownerUserID = try await requireAuthenticatedSession()
        guard barcode.hasPrefix(Self.task087Prefix),
              Self.task087ProductBarcodes.contains(barcode),
              newProductName.hasPrefix(Self.task087Prefix) else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "TASK087 scoped update rejected.")
        }

        let product = try await fetchTask087Product(ownerUserID: ownerUserID, barcode: barcode)
        guard product.ownerUserID == ownerUserID,
              product.barcode == barcode else {
            throw SupabaseInventoryServiceError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "TASK087 owner or barcode mismatch"
            )
        }

        let payload = SupabaseManualPushProductUpdatePayload(
            barcode: nil,
            itemNumber: nil,
            productName: newProductName,
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil
        )

        do {
            let updated: RemoteInventoryProductRow = try await clientProvider.client
                .from("inventory_products")
                .update(payload)
                .eq("id", value: product.id.uuidString)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
                .single()
                .execute()
                .value
            guard updated.ownerUserID == ownerUserID,
                  updated.barcode == barcode,
                  updated.productName == newProductName else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "TASK087 product read-back mismatch.")
            }
            return updated
        } catch let error as SupabaseInventoryServiceError {
            throw error
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    func ensureTask088RemoteSeed() async throws -> SupabaseTask088RemoteSeed {
        let ownerUserID = try await requireAuthenticatedSession()

        let existingSuppliers = try await fetchTask088SuppliersByPrefix(ownerUserID: ownerUserID)
        guard existingSuppliers.allSatisfy({
            $0.ownerUserID == ownerUserID
                && $0.name == Self.task088SupplierName
                && $0.deletedAt == nil
        }), existingSuppliers.count <= 1 else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "TASK088 supplier collision.")
        }
        let supplier: RemoteInventorySupplierRow
        if let existingSupplier = existingSuppliers.first {
            supplier = existingSupplier
        } else {
            supplier = try await createTask088Supplier(ownerUserID: ownerUserID)
        }

        let existingCategories = try await fetchTask088CategoriesByPrefix(ownerUserID: ownerUserID)
        guard existingCategories.allSatisfy({
            $0.ownerUserID == ownerUserID
                && $0.name == Self.task088CategoryName
                && $0.deletedAt == nil
        }), existingCategories.count <= 1 else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "TASK088 category collision.")
        }
        let category: RemoteInventoryCategoryRow
        if let existingCategory = existingCategories.first {
            category = existingCategory
        } else {
            category = try await createTask088Category(ownerUserID: ownerUserID)
        }

        let existingProducts = try await fetchTask088ProductsByPrefix(ownerUserID: ownerUserID)
        guard existingProducts.allSatisfy({
            $0.ownerUserID == ownerUserID
                && $0.barcode == Self.task088ProductBarcode
                && $0.deletedAt == nil
        }), existingProducts.count <= 1 else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "TASK088 product collision.")
        }
        let product: RemoteInventoryProductRow
        if let existingProduct = existingProducts.first {
            product = existingProduct
        } else {
            product = try await createTask088Product(
                ownerUserID: ownerUserID,
                supplierID: supplier.id,
                categoryID: category.id
            )
        }

        guard product.ownerUserID == ownerUserID,
              product.barcode == Self.task088ProductBarcode,
              product.deletedAt == nil else {
            throw SupabaseInventoryServiceError.schemaDrift(message: "TASK088 product seed read-back mismatch.")
        }

        return SupabaseTask088RemoteSeed(
            ownerUserID: ownerUserID,
            supplier: supplier,
            category: category,
            product: product
        )
    }

    func fetchTask088ProductPriceRows(
        ownerUserID: UUID,
        productID: UUID
    ) async throws -> [RemoteInventoryProductPriceRow] {
        let authenticatedUserID = try await requireAuthenticatedSession()
        guard authenticatedUserID == ownerUserID else {
            throw SupabaseInventoryServiceError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "TASK088 owner mismatch"
            )
        }

        do {
            return try await clientProvider.client
                .from("inventory_product_prices")
                .select("id,owner_user_id,product_id,type,price,effective_at,source,note,created_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .eq("product_id", value: productID.uuidString)
                .order("type", ascending: true)
                .order("effective_at", ascending: true)
                .order("id", ascending: true)
                .limit(20)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    func fetchTask045RemoteCollisionSummary(limit: Int = 50) async throws -> SupabaseTask045RemoteCollisionSummary {
        let ownerUserID = try await requireAuthenticatedSession()
        let clampedLimit = max(1, min(limit, 50))
        let suppliers = try await fetchTask045Suppliers(ownerUserID: ownerUserID, limit: clampedLimit)
        let categories = try await fetchTask045Categories(ownerUserID: ownerUserID, limit: clampedLimit)
        let products = try await fetchTask045Products(ownerUserID: ownerUserID, limit: clampedLimit)

        return SupabaseTask045RemoteCollisionSummary(
            supplierCount: suppliers.count,
            categoryCount: categories.count,
            productCount: products.count
        )
    }
#endif

    func fetchProducts(limit: Int = 100) async throws -> [RemoteInventoryProductRow] {
        try await fetchRows(
            table: "inventory_products",
            columns: "id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at",
            limit: limit
        )
    }

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        guard !rows.isEmpty else { return [] }
        let authenticatedUserID = try await requireAuthenticatedSession()
        guard authenticatedUserID == ownerUserID,
              rows.allSatisfy({ $0.ownerUserID == ownerUserID }) else {
            throw SupabaseInventoryServiceError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "History/session owner mismatch"
            )
        }

        do {
            let readBack: [RemoteSharedSheetSessionRow] = try await clientProvider.client
                .from("shared_sheet_sessions")
                .upsert(rows, onConflict: "remote_id")
                .select(Self.sharedSheetSessionColumns)
                .execute()
                .value
            guard readBack.count == rows.count,
                  readBack.allSatisfy({ $0.ownerUserID == ownerUserID }) else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "History/session read-back mismatch.")
            }
            return readBack
        } catch let error as SupabaseInventoryServiceError {
            throw error
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from start: Int,
        to end: Int
    ) async throws -> [RemoteSharedSheetSessionRow] {
        let authenticatedUserID = try await requireAuthenticatedSession()
        guard authenticatedUserID == ownerUserID else {
            throw SupabaseInventoryServiceError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "History/session owner mismatch"
            )
        }

        do {
            return try await clientProvider.client
                .from("shared_sheet_sessions")
                .select(Self.sharedSheetSessionColumns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .order("remote_id", ascending: true)
                .range(from: max(0, start), to: max(start, end))
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        try await fetchRowsPage(
            table: "inventory_products",
            columns: "id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at",
            from: from,
            to: to
        )
    }

    func fetchSuppliers(limit: Int = 100) async throws -> [RemoteInventorySupplierRow] {
        try await fetchRows(
            table: "inventory_suppliers",
            columns: "id,owner_user_id,name,updated_at,deleted_at",
            limit: limit
        )
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        try await fetchRowsPage(
            table: "inventory_suppliers",
            columns: "id,owner_user_id,name,updated_at,deleted_at",
            from: from,
            to: to
        )
    }

    func fetchCategories(limit: Int = 100) async throws -> [RemoteInventoryCategoryRow] {
        try await fetchRows(
            table: "inventory_categories",
            columns: "id,owner_user_id,name,updated_at,deleted_at",
            limit: limit
        )
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        try await fetchRowsPage(
            table: "inventory_categories",
            columns: "id,owner_user_id,name,updated_at,deleted_at",
            from: from,
            to: to
        )
    }

    func fetchProductPrices(limit: Int = 100) async throws -> [RemoteInventoryProductPriceRow] {
        try await fetchRows(
            table: "inventory_product_prices",
            columns: "id,owner_user_id,product_id,type,price,effective_at,source,note,created_at",
            limit: limit
        )
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        try await fetchRowsPage(
            table: "inventory_product_prices",
            columns: "id,owner_user_id,product_id,type,price,effective_at,source,note,created_at",
            from: from,
            to: to
        )
    }

    func fetchProductPricesPreviewPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        let ownerUserID = try await requireAuthenticatedSession()
        let client = clientProvider.client
        let start = max(0, from)
        let end = max(start, min(to, start + 999))

        do {
            let rows: [RemoteInventoryProductPriceRow] = try await client
                .from("inventory_product_prices")
                .select("id,owner_user_id,product_id,type,price,effective_at,created_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .order("product_id", ascending: true)
                .order("type", ascending: true)
                .order("effective_at", ascending: true)
                .order("id", ascending: true)
                .range(from: start, to: end)
                .execute()
                .value
            return rows
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    func fetchProductPriceCount() async throws -> Int? {
        let ownerUserID = try await requireAuthenticatedSession()
        let client = clientProvider.client

        do {
            let response = try await client
                .from("inventory_product_prices")
                .select("id", head: true, count: .exact)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .execute()
            return response.count
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    func fetchProductPricesForPushDryRunDedupePage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        let authenticatedUserID = try await requireAuthenticatedSession()
        guard ownerUserID == authenticatedUserID else {
            throw SupabaseInventoryServiceError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "owner mismatch"
            )
        }
        let client = clientProvider.client
        let start = max(0, from)
        let end = max(start, min(to, start + 999))
        let sortedProductIDs = productIDs
            .sorted { $0.uuidString < $1.uuidString }
            .map(\.uuidString)

        guard !sortedProductIDs.isEmpty else {
            return []
        }

        do {
            let rows: [RemoteInventoryProductPriceRow] = try await client
                .from("inventory_product_prices")
                .select("id,owner_user_id,product_id,type,price,effective_at,created_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .in("product_id", values: sortedProductIDs)
                .order("product_id", ascending: true)
                .order("type", ascending: true)
                .order("effective_at", ascending: true)
                .order("id", ascending: true)
                .range(from: start, to: end)
                .execute()
                .value
            return rows
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    func insertProductPriceManualPushPayloads(_ payloads: [ProductPriceManualPushPayload]) async throws -> [RemoteInventoryProductPriceRow] {
        let authenticatedUserID = try await requireAuthenticatedSession()
        guard !payloads.isEmpty else {
            return []
        }
        guard payloads.allSatisfy({ $0.ownerUserID == authenticatedUserID }) else {
            throw ProductPriceManualPushError.invalidPayload
        }

        do {
            let rows: [RemoteInventoryProductPriceRow] = try await clientProvider.client
                .from("inventory_product_prices")
                .insert(payloads)
                .select("id,owner_user_id,product_id,type,price,effective_at,source,note,created_at")
                .execute()
                .value
            return rows
        } catch let error as PostgrestError {
            throw mapProductPriceManualPushPostgrestError(error)
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    func fetchProductPricesForManualPushVerificationPage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        let authenticatedUserID = try await requireAuthenticatedSession()
        guard ownerUserID == authenticatedUserID else {
            throw ProductPriceManualPushError.invalidPayload
        }
        let client = clientProvider.client
        let start = max(0, from)
        let end = max(start, min(to, start + 999))
        let sortedProductIDs = productIDs
            .sorted { $0.uuidString < $1.uuidString }
            .map(\.uuidString)

        guard !sortedProductIDs.isEmpty else {
            return []
        }

        do {
            let rows: [RemoteInventoryProductPriceRow] = try await client
                .from("inventory_product_prices")
                .select("id,owner_user_id,product_id,type,price,effective_at,source,note,created_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .in("product_id", values: sortedProductIDs)
                .order("product_id", ascending: true)
                .order("type", ascending: true)
                .order("effective_at", ascending: true)
                .order("id", ascending: true)
                .range(from: start, to: end)
                .execute()
                .value
            return rows
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchRows<Row: Decodable & Sendable>(
        table: String,
        columns: String,
        limit: Int
    ) async throws -> [Row] {
        let ownerUserID = try await requireAuthenticatedSession()
        let client = clientProvider.client
        let clampedLimit = max(1, min(limit, 1_000))

        do {
            let rows: [Row] = try await client
                .from(table)
                .select(columns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .order(Self.stablePageOrderColumn, ascending: true)
                .limit(clampedLimit)
                .execute()
                .value
            return rows
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchRowsPage<Row: Decodable & Sendable>(
        table: String,
        columns: String,
        from: Int,
        to: Int
    ) async throws -> [Row] {
        let ownerUserID = try await requireAuthenticatedSession()
        let client = clientProvider.client
        let start = max(0, from)
        let end = max(start, min(to, start + 999))

        do {
            let rows: [Row] = try await client
                .from(table)
                .select(columns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .order(Self.stablePageOrderColumn, ascending: true)
                .range(from: start, to: end)
                .execute()
                .value
            return rows
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

#if DEBUG
    private func fetchTask087Suppliers(ownerUserID: UUID) async throws -> [RemoteInventorySupplierRow] {
        do {
            return try await clientProvider.client
                .from("inventory_suppliers")
                .select("id,owner_user_id,name,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .in("name", values: Self.task087SupplierNames)
                .order(Self.stablePageOrderColumn, ascending: true)
                .limit(20)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func createTask087Supplier(ownerUserID: UUID) async throws -> RemoteInventorySupplierRow {
        do {
            let rows: [RemoteInventorySupplierRow] = try await clientProvider.client
                .from("inventory_suppliers")
                .insert([SupabaseManualPushSupplierCreatePayload(ownerUserID: ownerUserID, name: "TASK087_SUP")])
                .select("id,owner_user_id,name,updated_at,deleted_at")
                .execute()
                .value
            guard rows.count == 1, let row = rows.first,
                  row.ownerUserID == ownerUserID,
                  row.name == "TASK087_SUP",
                  row.deletedAt == nil else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "TASK087 supplier seed read-back mismatch.")
            }
            return row
        } catch let error as SupabaseInventoryServiceError {
            throw error
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchTask087Categories(ownerUserID: UUID) async throws -> [RemoteInventoryCategoryRow] {
        do {
            return try await clientProvider.client
                .from("inventory_categories")
                .select("id,owner_user_id,name,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .in("name", values: Self.task087CategoryNames)
                .order(Self.stablePageOrderColumn, ascending: true)
                .limit(20)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func createTask087Category(ownerUserID: UUID) async throws -> RemoteInventoryCategoryRow {
        do {
            let rows: [RemoteInventoryCategoryRow] = try await clientProvider.client
                .from("inventory_categories")
                .insert([SupabaseManualPushCategoryCreatePayload(ownerUserID: ownerUserID, name: "TASK087_CAT")])
                .select("id,owner_user_id,name,updated_at,deleted_at")
                .execute()
                .value
            guard rows.count == 1, let row = rows.first,
                  row.ownerUserID == ownerUserID,
                  row.name == "TASK087_CAT",
                  row.deletedAt == nil else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "TASK087 category seed read-back mismatch.")
            }
            return row
        } catch let error as SupabaseInventoryServiceError {
            throw error
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchTask087Products(ownerUserID: UUID) async throws -> [RemoteInventoryProductRow] {
        do {
            return try await clientProvider.client
                .from("inventory_products")
                .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .in("barcode", values: Self.task087ProductBarcodes)
                .order("barcode", ascending: true)
                .limit(20)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func createTask087Products(
        _ payloads: [SupabaseManualPushProductCreatePayload]
    ) async throws -> [RemoteInventoryProductRow] {
        do {
            return try await clientProvider.client
                .from("inventory_products")
                .insert(payloads)
                .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchTask087ProductsByPrefix(ownerUserID: UUID) async throws -> [RemoteInventoryProductRow] {
        do {
            return try await clientProvider.client
                .from("inventory_products")
                .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .gte("barcode", value: Self.task087Prefix)
                .lt("barcode", value: Self.task087UpperBound)
                .order("barcode", ascending: true)
                .limit(20)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchTask087Product(
        ownerUserID: UUID,
        barcode: String
    ) async throws -> RemoteInventoryProductRow {
        do {
            return try await clientProvider.client
                .from("inventory_products")
                .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .eq("barcode", value: barcode)
                .limit(1)
                .single()
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchTask088SuppliersByPrefix(ownerUserID: UUID) async throws -> [RemoteInventorySupplierRow] {
        do {
            return try await clientProvider.client
                .from("inventory_suppliers")
                .select("id,owner_user_id,name,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .gte("name", value: Self.task088Prefix)
                .lt("name", value: Self.task088UpperBound)
                .order(Self.stablePageOrderColumn, ascending: true)
                .limit(20)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func createTask088Supplier(ownerUserID: UUID) async throws -> RemoteInventorySupplierRow {
        do {
            let rows: [RemoteInventorySupplierRow] = try await clientProvider.client
                .from("inventory_suppliers")
                .insert([SupabaseManualPushSupplierCreatePayload(ownerUserID: ownerUserID, name: Self.task088SupplierName)])
                .select("id,owner_user_id,name,updated_at,deleted_at")
                .execute()
                .value
            guard rows.count == 1, let row = rows.first,
                  row.ownerUserID == ownerUserID,
                  row.name == Self.task088SupplierName,
                  row.deletedAt == nil else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "TASK088 supplier seed read-back mismatch.")
            }
            return row
        } catch let error as SupabaseInventoryServiceError {
            throw error
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchTask088CategoriesByPrefix(ownerUserID: UUID) async throws -> [RemoteInventoryCategoryRow] {
        do {
            return try await clientProvider.client
                .from("inventory_categories")
                .select("id,owner_user_id,name,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .gte("name", value: Self.task088Prefix)
                .lt("name", value: Self.task088UpperBound)
                .order(Self.stablePageOrderColumn, ascending: true)
                .limit(20)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func createTask088Category(ownerUserID: UUID) async throws -> RemoteInventoryCategoryRow {
        do {
            let rows: [RemoteInventoryCategoryRow] = try await clientProvider.client
                .from("inventory_categories")
                .insert([SupabaseManualPushCategoryCreatePayload(ownerUserID: ownerUserID, name: Self.task088CategoryName)])
                .select("id,owner_user_id,name,updated_at,deleted_at")
                .execute()
                .value
            guard rows.count == 1, let row = rows.first,
                  row.ownerUserID == ownerUserID,
                  row.name == Self.task088CategoryName,
                  row.deletedAt == nil else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "TASK088 category seed read-back mismatch.")
            }
            return row
        } catch let error as SupabaseInventoryServiceError {
            throw error
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchTask088ProductsByPrefix(ownerUserID: UUID) async throws -> [RemoteInventoryProductRow] {
        do {
            return try await clientProvider.client
                .from("inventory_products")
                .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .gte("barcode", value: Self.task088Prefix)
                .lt("barcode", value: Self.task088UpperBound)
                .order("barcode", ascending: true)
                .limit(20)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func createTask088Product(
        ownerUserID: UUID,
        supplierID: UUID,
        categoryID: UUID
    ) async throws -> RemoteInventoryProductRow {
        let payload = SupabaseManualPushProductCreatePayload(
            ownerUserID: ownerUserID,
            barcode: Self.task088ProductBarcode,
            itemNumber: nil,
            productName: Self.task088ProductName,
            secondProductName: nil,
            purchasePrice: 122.20,
            retailPrice: 244.40,
            supplierID: supplierID,
            categoryID: categoryID,
            stockQuantity: 0
        )

        do {
            let rows: [RemoteInventoryProductRow] = try await clientProvider.client
                .from("inventory_products")
                .insert([payload])
                .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
                .execute()
                .value
            guard rows.count == 1, let row = rows.first,
                  row.ownerUserID == ownerUserID,
                  row.barcode == Self.task088ProductBarcode,
                  row.productName == Self.task088ProductName,
                  row.deletedAt == nil else {
                throw SupabaseInventoryServiceError.schemaDrift(message: "TASK088 product seed read-back mismatch.")
            }
            return row
        } catch let error as SupabaseInventoryServiceError {
            throw error
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchTask045Suppliers(ownerUserID: UUID, limit: Int) async throws -> [RemoteInventorySupplierRow] {
        do {
            return try await clientProvider.client
                .from("inventory_suppliers")
                .select("id,owner_user_id,name,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .gte("name", value: Self.task045Prefix)
                .lt("name", value: Self.task045UpperBound)
                .order(Self.stablePageOrderColumn, ascending: true)
                .limit(limit)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchTask045Categories(ownerUserID: UUID, limit: Int) async throws -> [RemoteInventoryCategoryRow] {
        do {
            return try await clientProvider.client
                .from("inventory_categories")
                .select("id,owner_user_id,name,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .gte("name", value: Self.task045Prefix)
                .lt("name", value: Self.task045UpperBound)
                .order(Self.stablePageOrderColumn, ascending: true)
                .limit(limit)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }

    private func fetchTask045Products(ownerUserID: UUID, limit: Int) async throws -> [RemoteInventoryProductRow] {
        let barcodeMatches = try await fetchTask045Products(ownerUserID: ownerUserID, column: "barcode", limit: limit)
        let nameMatches = try await fetchTask045Products(ownerUserID: ownerUserID, column: "product_name", limit: limit)
        var seenIDs = Set<UUID>()

        return (barcodeMatches + nameMatches).filter { row in
            seenIDs.insert(row.id).inserted
        }
    }

    private func fetchTask045Products(ownerUserID: UUID, column: String, limit: Int) async throws -> [RemoteInventoryProductRow] {
        do {
            return try await clientProvider.client
                .from("inventory_products")
                .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .gte(column, value: Self.task045Prefix)
                .lt(column, value: Self.task045UpperBound)
                .order(Self.stablePageOrderColumn, ascending: true)
                .limit(limit)
                .execute()
                .value
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch let error as PostgrestError {
            throw mapPostgrestError(error)
        } catch let error as URLError {
            throw SupabaseInventoryServiceError.networkError(
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw SupabaseInventoryServiceError.unknown(message: String(describing: error))
        }
    }
#endif

    @discardableResult
    private func requireAuthenticatedSession() async throws -> UUID {
        do {
            let session = try await clientProvider.client.auth.session
            return session.user.id
        } catch {
            throw SupabaseInventoryServiceError.sessionMissing
        }
    }

    private func mapPostgrestError(_ error: PostgrestError) -> SupabaseInventoryServiceError {
        let code = error.code
        let message = error.message
        let normalized = [code, message, error.detail, error.hint]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if normalized.contains("permission denied")
            || normalized.contains("row-level security")
            || normalized.contains("rls")
            || normalized.contains("unauthorized")
            || normalized.contains("authenticated")
            || code == "42501" {
            return .permissionDeniedOrRLS(statusCode: nil, code: code, message: message)
        }

        if code == "42P01" || code == "42703" || code == "PGRST204" {
            return .schemaDrift(message: message)
        }

        return .unknown(message: message)
    }

    private func mapProductPriceManualPushPostgrestError(_ error: PostgrestError) -> Error {
        let code = error.code
        let message = error.message
        let normalized = [code, message, error.detail, error.hint]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if code == "23505"
            || normalized.contains("duplicate key")
            || normalized.contains("unique constraint") {
            return ProductPriceManualPushError.uniqueConflict(
                message: SupabaseInventoryServiceError.sanitizedDiagnosticDetail(message)
            )
        }

        if normalized.contains("permission denied")
            || normalized.contains("row-level security")
            || normalized.contains("rls")
            || normalized.contains("unauthorized")
            || normalized.contains("authenticated")
            || code == "42501" {
            return SupabaseInventoryServiceError.permissionDeniedOrRLS(statusCode: nil, code: code, message: message)
        }

        if code == "42P01" || code == "42703" || code == "PGRST204" {
            return SupabaseInventoryServiceError.schemaDrift(message: message)
        }

        return SupabaseInventoryServiceError.unknown(message: message)
    }

    private func mapDecodingError(_ error: DecodingError) -> SupabaseInventoryServiceError {
        switch error {
        case .keyNotFound(let key, _):
            return .schemaDrift(message: "Missing key \(key.stringValue).")
        case .typeMismatch, .valueNotFound, .dataCorrupted:
            return .decodingError(message: String(describing: error))
        @unknown default:
            return .decodingError(message: String(describing: error))
        }
    }
}

extension SupabaseInventoryService: HistorySessionRemoteSyncing {}
