import SwiftData

@MainActor
struct SupabaseManualSyncAggregatedPushOutboxProducer {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func produce(_ outcome: SyncEventOutboxProducerOutcome) -> SyncEventOutboxProducerResult {
        let produceOutboxOutcome = SyncEventOutboxEnqueueService(context: context).enqueue
        return produceOutboxOutcome(outcome)
    }
}
