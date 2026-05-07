import Foundation
import Supabase

protocol SupabaseSyncEventPreviewFetching: Sendable {
    func fetchLatestSyncEvents(limit: Int) async throws -> [RemoteSyncEventRow]
}

nonisolated struct SyncEventPreviewOptions: Sendable, Equatable {
    static let standardLimit = 50
    static let maximumLimit = 200

    let defaultLimit: Int
    let maximumLimit: Int

    init(
        defaultLimit: Int = Self.standardLimit,
        maximumLimit: Int = Self.maximumLimit
    ) {
        let safeMaximum = max(1, maximumLimit)
        self.maximumLimit = safeMaximum
        self.defaultLimit = max(1, min(defaultLimit, safeMaximum))
    }

    func effectiveLimit(_ requestedLimit: Int?) -> Int {
        max(1, min(requestedLimit ?? defaultLimit, maximumLimit))
    }
}

nonisolated struct SyncEventPreviewSummary: Sendable, Equatable {
    let requestedLimit: Int?
    let effectiveLimit: Int
    let events: [RemoteSyncEventRow]

    var isLimitClamped: Bool {
        guard let requestedLimit else {
            return false
        }
        return requestedLimit != effectiveLimit
    }
}

nonisolated struct SupabaseSyncEventPreviewService: Sendable {
    private let fetcher: any SupabaseSyncEventPreviewFetching
    let options: SyncEventPreviewOptions

    init(
        fetcher: any SupabaseSyncEventPreviewFetching,
        options: SyncEventPreviewOptions = SyncEventPreviewOptions()
    ) {
        self.fetcher = fetcher
        self.options = options
    }

    func loadLatestEvents(limit requestedLimit: Int? = nil) async throws -> SyncEventPreviewSummary {
        let effectiveLimit = options.effectiveLimit(requestedLimit)
        let events = try await fetcher.fetchLatestSyncEvents(limit: effectiveLimit)

        return SyncEventPreviewSummary(
            requestedLimit: requestedLimit,
            effectiveLimit: effectiveLimit,
            events: Array(events.prefix(effectiveLimit))
        )
    }
}

actor SupabaseSyncEventRemoteReader: SupabaseSyncEventPreviewFetching {
    nonisolated static let stablePageOrderColumns = ["created_at", "id"]

    private let clientProvider: SupabaseClientProvider

    init(clientProvider: SupabaseClientProvider) {
        self.clientProvider = clientProvider
    }

    func fetchLatestSyncEvents(limit: Int) async throws -> [RemoteSyncEventRow] {
        try await requireAuthenticatedSession()
        let effectiveLimit = max(1, min(limit, SyncEventPreviewOptions.maximumLimit))

        do {
            let rows: [RemoteSyncEventRow] = try await clientProvider.client
                .from("sync_events")
                .select("id,owner_user_id,store_id,domain,event_type,source,source_device_id,batch_id,client_event_id,changed_count,entity_ids,created_at,expires_at,metadata")
                .order("created_at", ascending: false)
                .order("id", ascending: false)
                .limit(effectiveLimit)
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
