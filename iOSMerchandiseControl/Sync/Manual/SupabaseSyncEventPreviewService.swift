#if DEBUG
import Foundation

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
        let safeMaximum = max(1, min(maximumLimit, Self.maximumLimit))
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

#endif
