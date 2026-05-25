import Foundation
import Supabase

nonisolated enum SupabaseTransportClientError: Error, Sendable {
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

nonisolated enum SupabaseTransportDiagnosticResult: Sendable {
    case catalogProbeSucceeded(rowCount: Int)
}

actor SupabaseTransportClient {
    nonisolated static let stablePageOrderColumn = "id"
    nonisolated static let productPriceStablePageOrderColumns = ["id"]
    nonisolated static let productColumns = "id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at"
    nonisolated static let productPriceColumns = "id,owner_user_id,product_id,type,price,effective_at,source,note,created_at"
    nonisolated static let sharedSheetSessionColumns = "remote_id,payload_version,display_name,timestamp,supplier,category,is_manual_entry,data,session_overlay,owner_user_id,updated_at,deleted_at"

    private let clientProvider: SupabaseClientProvider

    init(clientProvider: SupabaseClientProvider) {
        self.clientProvider = clientProvider
    }

    func client() -> SupabaseClient {
        clientProvider.client
    }

    @discardableResult
    func authenticatedUserID() async throws -> UUID {
        do {
            let session = try await clientProvider.client.auth.session
            return session.user.id
        } catch {
            throw SupabaseTransportClientError.sessionMissing
        }
    }

    func testConnection() async throws -> SupabaseTransportDiagnosticResult {
        let ownerUserID = try await authenticatedUserID()
        let response = try await clientProvider.client
            .from("inventory_products")
            .select("id", head: true, count: .exact)
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .limit(1)
            .execute()
        return .catalogProbeSucceeded(rowCount: response.count ?? 0)
    }

    func mapPostgrestError(_ error: PostgrestError) -> SupabaseTransportClientError {
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

    func mapDecodingError(_ error: DecodingError) -> SupabaseTransportClientError {
        switch error {
        case .keyNotFound(let key, _):
            return .schemaDrift(message: "Missing key \(key.stringValue).")
        case .typeMismatch, .valueNotFound, .dataCorrupted:
            return .decodingError(message: String(describing: error))
        @unknown default:
            return .decodingError(message: String(describing: error))
        }
    }

    func networkError(_ error: URLError) -> SupabaseTransportClientError {
        .networkError(statusCode: nil, message: error.localizedDescription)
    }
}
