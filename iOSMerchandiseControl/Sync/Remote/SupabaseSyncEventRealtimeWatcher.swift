import Foundation

/// Foreground signal source for the sanitized shop-scoped event RPC.
///
/// `public.sync_events` can contain historical raw metadata and therefore no
/// longer grants client SELECT. A Postgres Changes subscription would either
/// fail after that security boundary or reintroduce the leakage. This bounded
/// timer never reads event rows itself: it only asks the orchestrator to poll
/// `shop_sync_event_page_v1`, where RLS, shop/device authorization and metadata
/// redaction are enforced server-side.
@MainActor
final class SupabaseSyncEventSignalWatcher {
    private static let pollNanoseconds: UInt64 = 2_000_000_000

    private var ownerUserID: UUID?
    private var selectedShopID: UUID?
    private var pollingTask: Task<Void, Never>?

    init(clientProvider _: SupabaseClientProvider) {}

    func start(
        ownerUserID: UUID,
        selectedShopID: UUID,
        onSignal: @escaping @MainActor @Sendable () -> Void
    ) {
        guard self.ownerUserID != ownerUserID || self.selectedShopID != selectedShopID else { return }
        stop()
        self.ownerUserID = ownerUserID
        self.selectedShopID = selectedShopID
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: Self.pollNanoseconds)
                } catch {
                    return
                }
                guard !Task.isCancelled,
                      self?.ownerUserID == ownerUserID,
                      self?.selectedShopID == selectedShopID else {
                    return
                }
                onSignal()
            }
        }
    }

    func stop() {
        ownerUserID = nil
        selectedShopID = nil
        pollingTask?.cancel()
        pollingTask = nil
    }
}
