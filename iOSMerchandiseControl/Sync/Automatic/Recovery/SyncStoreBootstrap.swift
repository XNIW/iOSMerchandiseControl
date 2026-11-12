import Combine
import Foundation
import SwiftUI
import SwiftData

/// Only load() can prepare a normal opening. No ModelContext crosses this boundary.
/// The container is transferred once to the MainActor controller, never opened a second time.
nonisolated final class SyncStoreOpenedGeneration: @unchecked Sendable {
    private let repository: SyncStoreGenerationRepository
    private let active: SyncStoreActiveGeneration
    private let defaults: UserDefaults
    let openedContainerIdentity: ObjectIdentifier
    // Initialized before transfer; only the MainActor claim method mutates this flag.
    private var claimed = false

    private init(repository: SyncStoreGenerationRepository, active: SyncStoreActiveGeneration, defaults: UserDefaults) {
        self.repository = repository; self.active = active; self.defaults = defaults
        openedContainerIdentity = ObjectIdentifier(active.container)
    }
    static func load(repository: SyncStoreGenerationRepository, defaults: UserDefaults) throws -> SyncStoreOpenedGeneration {
        guard repository.defaults === defaults else { throw SyncStoreGenerationError.defaultsConfigurationMismatch }
        let active = try repository.loadActive()
        return SyncStoreOpenedGeneration(repository: repository, active: active, defaults: defaults)
    }
    static func loadDefault() throws -> SyncStoreOpenedGeneration {
        let defaults = UserDefaults.standard
        return try load(repository: SyncStoreGenerationRepository(defaults: defaults), defaults: defaults)
    }
    static func loadDefaultAsync() async throws -> SyncStoreOpenedGeneration { try loadDefault() }
    @MainActor
    func claimForAdoption() throws -> (SyncStoreGenerationRepository, SyncStoreActiveGeneration, UserDefaults) {
        guard !claimed, repository.defaults === defaults else { throw SyncStoreGenerationError.defaultsConfigurationMismatch }
        // Pointer/scope changed while opening: reject before registration or qualification.
        guard try repository.activeManifest() == active.manifest else { throw SyncStoreGenerationError.staleGenerationLease }
        claimed = true
        return (repository, active, defaults)
    }
}

/// App-lifetime owner of the entire physical load/cleanup, not a transient SwiftUI task.
/// Physical opening is not authorization, domain readiness or a new cold-reuse proof.
@MainActor
final class SyncStoreBootstrap: ObservableObject {
    enum Phase: Equatable { case opening, opened, failed }
    static let shared = SyncStoreBootstrap()
    @Published private(set) var phase: Phase = .opening
    @Published private(set) var controller: SyncStoreGenerationController?
    @Published private(set) var failureCode: String?
    private let loader: @Sendable () async throws -> SyncStoreOpenedGeneration
    private var physicalFlight: Task<SyncStoreOpenedGeneration, Error>?
    private var completionTask: Task<Void, Never>?
    private var physicalAttempt: UUID?
    private var admittedAttempt: UUID?
    private var waiters: [UUID: CheckedContinuation<SyncStoreGenerationController, Error>] = [:]
    private var openedObserver: ((SyncStoreGenerationController) -> Void)?

    init(loader: @escaping @Sendable () async throws -> SyncStoreOpenedGeneration = SyncStoreOpenedGeneration.loadDefaultAsync) {
        self.loader = loader
    }
    /// Explicit controlled/hosted controllers retain their existing opening and failure behavior.
    init(opened controller: SyncStoreGenerationController) {
        self.loader = { throw SyncStoreGenerationError.unavailable }
        self.controller = controller; self.phase = .opened
    }
    var canRetry: Bool { phase == .failed && physicalFlight == nil }
    var hasPhysicalFlight: Bool { physicalFlight != nil }
    func observeOpened(_ observer: @escaping (SyncStoreGenerationController) -> Void) {
        openedObserver = observer
        if let controller { observer(controller) }
    }
    func startIfNeeded() {
        guard controller == nil, physicalFlight == nil, phase != .failed else { return }
        let attempt = UUID(); physicalAttempt = attempt; admittedAttempt = attempt
        phase = .opening; failureCode = nil
        let loader = loader
        let worker = Task.detached(priority: .userInitiated) { try await loader() }
        physicalFlight = worker
        completionTask = Task { [weak self] in
            let result = await worker.result
            self?.complete(result, attempt: attempt)
        }
    }
    func retry() {
        guard canRetry else { return }
        phase = .opening; startIfNeeded()
    }
    /// Revokes publication, not synchronous SQLite work. Retry stays unavailable until it finishes.
    /// Foreground disappearance or one background waiter's expiry must NOT call this method.
    func withdrawOpeningPublication() {
        guard physicalFlight != nil else { return }
        admittedAttempt = nil
        finishWaiters(.failure(CancellationError()))
    }
    // Internal observation is nil in production; tests can prove a waiter was registered before cancelling it.
    func waitUntilOpened(onWaiterRegistered: (() -> Void)? = nil) async throws -> SyncStoreGenerationController {
        try Task.checkCancellation()
        if let controller { return controller }
        if phase == .failed { throw SyncStoreGenerationError.unavailable }
        let waiter = UUID()
        let opened: SyncStoreGenerationController = try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                if let controller { continuation.resume(returning: controller); return }
                if phase == .failed { continuation.resume(throwing: SyncStoreGenerationError.unavailable); return }
                waiters[waiter] = continuation
                onWaiterRegistered?()
                startIfNeeded()
            }
        }, onCancel: { [weak self] in
            Task { @MainActor [weak self] in self?.cancelWaiter(waiter) }
        })
        try Task.checkCancellation()
        return opened
    }
    private func cancelWaiter(_ id: UUID) {
        waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }
    private func finishWaiters(_ result: Result<SyncStoreGenerationController, Error>) {
        let pending = Array(waiters.values); waiters.removeAll()
        for continuation in pending { continuation.resume(with: result) }
    }
    private func complete(_ result: Result<SyncStoreOpenedGeneration, Error>, attempt: UUID) {
        guard physicalAttempt == attempt else { return }
        // Completion is terminal before any retry is allowed. We never cancel a synchronous opener.
        physicalFlight = nil; completionTask = nil; physicalAttempt = nil
        guard admittedAttempt == attempt else {
            phase = .failed; failureCode = "sync_store_generation_load_failed"
            finishWaiters(.failure(CancellationError())); return
        }
        admittedAttempt = nil
        do {
            let adopted = try SyncStoreGenerationController(adopting: result.get())
            // Value presentation and boundary observer are installed before the business branch is visible.
            openedObserver?(adopted)
            controller = adopted; phase = .opened
            finishWaiters(.success(adopted))
        } catch {
            // No normal in-memory fallback and no business registration on failed physical opening.
            failureCode = "sync_store_generation_load_failed"; phase = .failed
            finishWaiters(.failure(error))
        }
    }
}

/// The actual root boundary: unopened/failed rendering cannot construct a business child.
struct SyncStoreBootstrapGate<Opened: View, Pending: View>: View {
    @ObservedObject var bootstrap: SyncStoreBootstrap
    let opened: (SyncStoreGenerationController) -> Opened
    let pending: () -> Pending
    var body: some View {
        if let controller = bootstrap.controller { opened(controller) }
        else { pending() }
    }
}
