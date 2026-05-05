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

        if text.count > 240 {
            return String(text.prefix(240)) + "..."
        }

        return text
    }
}

nonisolated enum SupabaseInventoryDiagnosticResult: Sendable {
    case catalogProbeSucceeded(rowCount: Int)
}

actor SupabaseInventoryService {
    private let clientProvider: SupabaseClientProvider

    init(clientProvider: SupabaseClientProvider) {
        self.clientProvider = clientProvider
    }

    func testConnection() async throws -> SupabaseInventoryDiagnosticResult {
        try await requireAuthenticatedSession()
        let products = try await fetchProducts(limit: 1)
        return .catalogProbeSucceeded(rowCount: products.count)
    }

    func fetchProducts(limit: Int = 100) async throws -> [RemoteInventoryProductRow] {
        try await fetchRows(
            table: "inventory_products",
            columns: "id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at",
            limit: limit
        )
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

    private func fetchRows<Row: Decodable & Sendable>(
        table: String,
        columns: String,
        limit: Int
    ) async throws -> [Row] {
        try await requireAuthenticatedSession()
        let client = clientProvider.client
        let clampedLimit = max(1, min(limit, 1_000))

        do {
            let rows: [Row] = try await client
                .from(table)
                .select(columns)
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
        try await requireAuthenticatedSession()
        let client = clientProvider.client
        let start = max(0, from)
        let end = max(start, min(to, start + 999))

        do {
            let rows: [Row] = try await client
                .from(table)
                .select(columns)
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

    private func requireAuthenticatedSession() async throws {
        do {
            _ = try await clientProvider.client.auth.session
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
