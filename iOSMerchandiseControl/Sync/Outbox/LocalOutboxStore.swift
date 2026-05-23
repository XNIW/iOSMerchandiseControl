import Foundation
import SwiftData

@MainActor
struct LocalOutboxStore {
    private let backingStore: SyncEventOutboxLocalStore

    init(context: ModelContext) {
        self.backingStore = SyncEventOutboxLocalStore(context: context)
    }

    func fetchCounts(ownerUserID: UUID, now: Date = Date()) throws -> SyncEventOutboxCounts {
        try backingStore.fetchCounts(
            ownerUserID: ownerUserID.uuidString.lowercased(),
            now: now
        )
    }

    func fetchRetryable(
        ownerUserID: UUID,
        now: Date = Date(),
        limit: Int? = nil
    ) throws -> [SyncEventOutboxEntry] {
        try backingStore.fetchRetryable(
            ownerUserID: ownerUserID.uuidString.lowercased(),
            now: now,
            limit: limit
        )
    }
}
