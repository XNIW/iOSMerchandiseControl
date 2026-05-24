import Combine
import Foundation
import SwiftData

#if DEBUG
@MainActor
final class SyncEventOutboxDrainDebugViewModel: ObservableObject {
    typealias Clock = () -> Date
    typealias FetchCounts = @MainActor (_ ownerUserID: String, _ now: Date) async throws -> SyncEventOutboxCounts
    typealias DrainOnce = @MainActor (_ ownerUserID: String, _ limit: Int, _ fetchScanLimit: Int?) async throws -> SyncEventOutboxDrainOutcome

    enum ViewState: Equatable {
        case idle
        case loadingCounts
        case draining
        case result
        case error

        var isBusy: Bool {
            switch self {
            case .loadingCounts, .draining:
                return true
            case .idle, .result, .error:
                return false
            }
        }
    }

    enum AccessIssue: Equatable {
        case missingSession
        case invalidOwner
    }

    enum DrainMessage: Equatable {
        case noWork
        case drained(sent: Int)
        case partial(sent: Int, retryScheduled: Int, blocked: Int, dead: Int)
        case blocked
        case alreadyRunning
        case network
        case cancelled
        case invalidOwner
        case localSaveFailed
    }

    static let allowedLimits = [5, 10, 25]
    static let defaultLimit = 10

    @Published private(set) var state: ViewState = .idle
    @Published private(set) var counts: SyncEventOutboxCounts?
    @Published private(set) var lastCountsRefreshAt: Date?
    @Published private(set) var selectedLimit = SyncEventOutboxDrainDebugViewModel.defaultLimit
    @Published private(set) var isShowingDrainConfirmation = false
    @Published private(set) var lastDrainMessage: DrainMessage?
    @Published private(set) var didFailRefreshingCounts = false

    private let clock: Clock
    private let fetchCounts: FetchCounts
    private let drainOnce: DrainOnce?
    private var currentTask: Task<Void, Never>?
    private var requestID = 0
    private var currentOwnerUserID: String?
    private var didAutoRefreshCurrentOwner = false

    init(
        clock: @escaping Clock = Date.init,
        fetchCounts: @escaping FetchCounts,
        drainOnce: DrainOnce?
    ) {
        self.clock = clock
        self.fetchCounts = fetchCounts
        self.drainOnce = drainOnce
    }

    init(
        context: ModelContext,
        recorder: (any SyncEventRecording)?,
        clock: @escaping Clock = Date.init
    ) {
        let store = SyncEventOutboxLocalStore(context: context)
        let fetchCounts: FetchCounts = { ownerUserID, now in
            try store.fetchCounts(ownerUserID: ownerUserID, now: now)
        }
        let drainOnce: DrainOnce?
        if let recorder {
            drainOnce = { ownerUserID, limit, fetchScanLimit in
                let service = SyncEventOutboxDrainService(
                    context: context,
                    recorder: recorder,
                    clock: clock
                )
                return try await service.drainOnce(
                    ownerUserID: ownerUserID,
                    limit: limit,
                    fetchScanLimit: fetchScanLimit
                )
            }
        } else {
            drainOnce = nil
        }

        self.clock = clock
        self.fetchCounts = fetchCounts
        self.drainOnce = drainOnce
    }

    deinit {
        currentTask?.cancel()
    }

    var isBusy: Bool {
        state.isBusy
    }

    var retryableCount: Int {
        counts?.retryable ?? 0
    }

    var canDrain: Bool {
        retryableCount > 0 && !state.isBusy && drainOnce != nil
    }

    func selectLimit(_ limit: Int) {
        guard Self.allowedLimits.contains(limit) else { return }
        selectedLimit = limit
    }

    func accessIssue(isAuthenticated: Bool, ownerUserID: String?) -> AccessIssue? {
        guard isAuthenticated else { return .missingSession }
        guard normalizedOwner(ownerUserID) != nil else { return .invalidOwner }
        return nil
    }

    func updateSession(isAuthenticated: Bool, ownerUserID: String?) {
        let nextOwner = accessIssue(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID) == nil
            ? normalizedOwner(ownerUserID)
            : nil

        guard currentOwnerUserID != nextOwner else { return }

        cancelInFlight()
        currentOwnerUserID = nextOwner
        resetOwnerBoundState()
    }

    func refreshCountsIfNeeded(isAuthenticated: Bool, ownerUserID: String?) async {
        guard let owner = prepareOwner(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID) else {
            return
        }
        guard !didAutoRefreshCurrentOwner else { return }
        didAutoRefreshCurrentOwner = true
        await refreshCounts(for: owner)
    }

    func refreshCounts(isAuthenticated: Bool, ownerUserID: String?) async {
        guard let owner = prepareOwner(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID) else {
            return
        }
        await refreshCounts(for: owner)
    }

    func requestDrainConfirmation(isAuthenticated: Bool, ownerUserID: String?) {
        guard prepareOwner(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID) != nil else {
            return
        }
        guard canDrain else { return }
        isShowingDrainConfirmation = true
    }

    func dismissDrainConfirmation() {
        isShowingDrainConfirmation = false
    }

    func confirmDrain(isAuthenticated: Bool, ownerUserID: String?) async {
        guard let owner = prepareOwner(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID) else {
            return
        }
        guard isShowingDrainConfirmation else { return }
        guard canDrain else { return }
        guard let drainOnce else { return }

        requestID += 1
        let activeRequestID = requestID
        let limit = Self.allowedLimits.contains(selectedLimit) ? selectedLimit : Self.defaultLimit
        isShowingDrainConfirmation = false
        lastDrainMessage = nil
        didFailRefreshingCounts = false
        state = .draining

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let outcome = try await drainOnce(owner, limit, nil)
                try Task.checkCancellation()
                guard activeRequestID == requestID else { return }
                lastDrainMessage = Self.message(for: outcome)
                state = .result
                await refreshCountsAfterDrain(ownerUserID: owner, requestID: activeRequestID)
            } catch is CancellationError {
                guard activeRequestID == requestID else { return }
                lastDrainMessage = .cancelled
                state = .result
            } catch let error as SyncEventOutboxDrainError {
                guard activeRequestID == requestID else { return }
                lastDrainMessage = Self.message(for: error)
                state = .error
            } catch {
                guard activeRequestID == requestID else { return }
                lastDrainMessage = .network
                state = .error
            }

            if activeRequestID == requestID {
                currentTask = nil
            }
        }

        currentTask = task
        await task.value
    }

    func cancelInFlight() {
        requestID += 1
        currentTask?.cancel()
        currentTask = nil
        isShowingDrainConfirmation = false
        if state.isBusy {
            state = .idle
        }
    }

    func reset() {
        cancelInFlight()
        currentOwnerUserID = nil
        resetOwnerBoundState()
    }

    private func refreshCounts(for ownerUserID: String) async {
        guard !state.isBusy else { return }

        requestID += 1
        let activeRequestID = requestID
        didFailRefreshingCounts = false
        state = .loadingCounts

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let now = clock()
                let loadedCounts = try await fetchCounts(ownerUserID, now)
                try Task.checkCancellation()
                guard activeRequestID == requestID else { return }
                counts = loadedCounts
                lastCountsRefreshAt = clock()
                didFailRefreshingCounts = false
                state = .idle
            } catch is CancellationError {
                guard activeRequestID == requestID else { return }
                state = .idle
            } catch {
                guard activeRequestID == requestID else { return }
                didFailRefreshingCounts = true
                state = .error
            }

            if activeRequestID == requestID {
                currentTask = nil
            }
        }

        currentTask = task
        await task.value
    }

    private func refreshCountsAfterDrain(ownerUserID: String, requestID activeRequestID: Int) async {
        do {
            let loadedCounts = try await fetchCounts(ownerUserID, clock())
            try Task.checkCancellation()
            guard activeRequestID == requestID else { return }
            counts = loadedCounts
            lastCountsRefreshAt = clock()
            didFailRefreshingCounts = false
        } catch {
            guard activeRequestID == requestID else { return }
            didFailRefreshingCounts = true
        }
    }

    private func prepareOwner(isAuthenticated: Bool, ownerUserID: String?) -> String? {
        updateSession(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID)
        guard isAuthenticated else { return nil }
        return normalizedOwner(ownerUserID)
    }

    private func resetOwnerBoundState() {
        counts = nil
        lastCountsRefreshAt = nil
        lastDrainMessage = nil
        didFailRefreshingCounts = false
        didAutoRefreshCurrentOwner = false
        isShowingDrainConfirmation = false
        state = .idle
    }

    private static func message(for outcome: SyncEventOutboxDrainOutcome) -> DrainMessage {
        switch outcome.status {
        case .noWork:
            return .noWork
        case .alreadyRunning:
            return .alreadyRunning
        case .drained:
            return .drained(sent: outcome.sent)
        case .partiallyDrained:
            return .partial(
                sent: outcome.sent,
                retryScheduled: outcome.retryScheduled,
                blocked: outcome.blocked,
                dead: outcome.dead
            )
        case .blockedPayloadReplay, .blocked:
            return .blocked
        case .networkFailed:
            return .network
        }
    }

    private static func message(for error: SyncEventOutboxDrainError) -> DrainMessage {
        switch error {
        case .invalidOwnerUserID:
            return .invalidOwner
        case .localSaveFailed:
            return .localSaveFailed
        }
    }

    private func normalizedOwner(_ ownerUserID: String?) -> String? {
        guard let ownerUserID else { return nil }
        let trimmed = ownerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uuid = UUID(uuidString: trimmed) else { return nil }
        return uuid.uuidString.lowercased()
    }
}
#endif
