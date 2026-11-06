import Foundation
import Network

nonisolated enum AutomaticSyncNetworkStatus: Equatable, Sendable {
    case unknown
    case satisfied
    case unsatisfied
}

nonisolated enum AutomaticSyncPolicy {
    static let defaultForegroundDebounce: TimeInterval = 2
}

@MainActor
final class AutomaticSyncReconnectScheduler: @unchecked Sendable {
    private let debounce: TimeInterval
    private let trigger: @MainActor @Sendable () -> Void

    private var isForeground = false
    private var lastStatus: AutomaticSyncNetworkStatus?
    private var pendingTask: Task<Void, Never>?

    init(
        debounce: TimeInterval = AutomaticSyncPolicy.defaultForegroundDebounce,
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
        case .unknown:
            cancelPendingIntent()
        case .satisfied:
            guard previousStatus != .satisfied,
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
    private static var sharedMonitor: NWPathMonitor?
    private static let monitorQueue = DispatchQueue(label: "AutomaticSyncNetworkReachabilityObserver")
    private static var monitorID: UUID?
    private static var lastStatus: AutomaticSyncNetworkStatus?
    private static var observers: [UUID: @MainActor (AutomaticSyncNetworkStatus) -> Void] = [:]

    private let scheduler: AutomaticSyncReconnectScheduler?
    private let statusHandler: @MainActor @Sendable (AutomaticSyncNetworkStatus) -> Void
    private let id = UUID()

    init(
        scheduler: AutomaticSyncReconnectScheduler? = nil,
        statusHandler: @escaping @MainActor @Sendable (AutomaticSyncNetworkStatus) -> Void = { _ in }
    ) {
        self.scheduler = scheduler
        self.statusHandler = statusHandler
    }

    func start() {
        guard Self.observers[id] == nil else { return }
        Self.observers[id] = { [weak self] status in
            guard let self else { return }
            statusHandler(status)
            scheduler?.receive(status)
        }
        if let status = Self.lastStatus { Self.observers[id]?(status) }
        guard Self.sharedMonitor == nil else { return }
        let monitor = NWPathMonitor()
        let monitorID = UUID()
        monitor.pathUpdateHandler = { path in
            let status: AutomaticSyncNetworkStatus = path.status == .satisfied ? .satisfied : .unsatisfied
            Task { @MainActor in
                guard AutomaticSyncNetworkReachabilityObserver.monitorID == monitorID else { return }
                AutomaticSyncNetworkReachabilityObserver.lastStatus = status
                let listeners = Array(AutomaticSyncNetworkReachabilityObserver.observers.keys)
                for id in listeners {
                    AutomaticSyncNetworkReachabilityObserver.observers[id]?(status)
                }
            }
        }
        Self.sharedMonitor = monitor
        Self.monitorID = monitorID
        monitor.start(queue: Self.monitorQueue)
    }

    func cancel() {
        Self.observers.removeValue(forKey: id)
        if Self.observers.isEmpty {
            Self.sharedMonitor?.cancel()
            Self.sharedMonitor = nil
            Self.monitorID = nil
            Self.lastStatus = nil
        }
        scheduler?.cancel()
    }

    isolated deinit { cancel() }
}
