import Foundation
import SwiftData

@MainActor
struct LocalOutboxStore {
    private let backingStore: SyncEventOutboxLocalStore

    /// Compatibility facade over the existing sync-event outbox table.
    /// Owner binding is enforced on every read; local mutation coalescing remains owned by
    /// `LocalPendingChangeAccumulator` + `PendingChangeCoalescer` until the legacy manual
    /// push adapters are fully retired.
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
