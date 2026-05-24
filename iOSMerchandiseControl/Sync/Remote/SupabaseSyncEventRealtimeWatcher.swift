import Foundation
import Supabase

@MainActor
final class SupabaseSyncEventSignalWatcher {
    private let clientProvider: SupabaseClientProvider
    private var ownerUserID: UUID?
    private var channel: RealtimeChannelV2?
    private var subscriptionTask: Task<Void, Never>?
    private var signalTask: Task<Void, Never>?

    init(clientProvider: SupabaseClientProvider) {
        self.clientProvider = clientProvider
    }

    func start(ownerUserID: UUID, onSignal: @escaping @MainActor @Sendable () -> Void) {
        guard self.ownerUserID != ownerUserID else { return }
        stop()

        let channel = clientProvider.client.channel("sync-events-v1-\(ownerUserID.uuidString.lowercased())")
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "sync_events",
            filter: .eq("owner_user_id", value: ownerUserID)
        )

        self.ownerUserID = ownerUserID
        self.channel = channel
        subscriptionTask = Task { [weak self] in
            do {
                try await channel.subscribeWithError()
                guard !Task.isCancelled else { return }
                for await _ in insertions {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self?.scheduleSignal(after: 500_000_000, onSignal: onSignal)
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                debugPrint("[SyncEventsRealtime] subscribe_failed owner=\(ownerUserID.uuidString.prefix(8))-redacted error=\(error)")
            }
        }
    }

    func stop() {
        ownerUserID = nil
        signalTask?.cancel()
        signalTask = nil
        subscriptionTask?.cancel()
        subscriptionTask = nil
        guard let channel else { return }
        self.channel = nil
        Task {
            await channel.unsubscribe()
        }
    }

    private func scheduleSignal(
        after delayNanoseconds: UInt64,
        onSignal: @escaping @MainActor @Sendable () -> Void
    ) {
        signalTask?.cancel()
        signalTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            onSignal()
        }
    }
}
