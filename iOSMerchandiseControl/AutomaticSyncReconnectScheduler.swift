import Foundation
import Network

nonisolated enum AutomaticSyncNetworkStatus: Equatable, Sendable {
    case satisfied
    case unsatisfied
}

@MainActor
final class AutomaticSyncReconnectScheduler: @unchecked Sendable {
    private let debounce: TimeInterval
    private let trigger: @MainActor @Sendable () -> Void

    private var isForeground = false
    private var lastStatus: AutomaticSyncNetworkStatus?
    private var pendingTask: Task<Void, Never>?

    init(
        debounce: TimeInterval = SupabaseManualSyncSemiAutomaticPolicy.defaultForegroundDebounce,
        trigger: @escaping @MainActor @Sendable () -> Void
    ) {
        self.debounce = max(0, debounce)
        self.trigger = trigger
    }

    func setForeground(_ isForeground: Bool) {
        self.isForeground = isForeground
        if !isForeground {
            cancelPendingIntent()
        }
    }

    func receive(_ status: AutomaticSyncNetworkStatus) {
        let previousStatus = lastStatus
        lastStatus = status

        switch status {
        case .satisfied:
            guard previousStatus == .unsatisfied,
                  isForeground else { return }
            scheduleReconnectIntent()
        case .unsatisfied:
            cancelPendingIntent()
        }
    }

    func cancel() {
        cancelPendingIntent()
    }

    private func scheduleReconnectIntent() {
        cancelPendingIntent()
        let delay = UInt64(debounce * 1_000_000_000)
        pendingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled,
                  self.isForeground else { return }
            self.pendingTask = nil
            self.trigger()
        }
    }

    private func cancelPendingIntent() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}

@MainActor
final class AutomaticSyncNetworkReachabilityObserver {
    private let scheduler: AutomaticSyncReconnectScheduler
    private var monitor: NWPathMonitor?
    private var queue: DispatchQueue?

    init(scheduler: AutomaticSyncReconnectScheduler) {
        self.scheduler = scheduler
    }

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "AutomaticSyncNetworkReachabilityObserver")
        let scheduler = scheduler
        monitor.pathUpdateHandler = { path in
            let status: AutomaticSyncNetworkStatus = path.status == .satisfied ? .satisfied : .unsatisfied
            Task { @MainActor [scheduler] in
                scheduler.receive(status)
            }
        }
        self.monitor = monitor
        self.queue = queue
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor?.cancel()
        monitor = nil
        queue = nil
        scheduler.cancel()
    }
}
