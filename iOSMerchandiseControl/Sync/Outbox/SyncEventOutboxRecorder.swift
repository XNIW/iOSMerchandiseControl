import Foundation
import SwiftData

@MainActor
struct SyncEventOutboxRecorder {
    private let enqueueService: SyncEventOutboxEnqueueService

    init(context: ModelContext) {
        self.enqueueService = SyncEventOutboxEnqueueService(context: context)
    }

    func record(_ outcome: SyncEventOutboxProducerOutcome) -> SyncEventOutboxProducerResult {
        enqueueService.enqueue(outcome)
    }
}
