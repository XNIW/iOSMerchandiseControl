#if DEBUG
import Foundation
import SwiftData
import Combine

typealias ProductPriceManualPushRemote = SupabaseProductPriceManualPushRemoteAccessing & SupabaseProductPricePushDryRunRemoteFetching

nonisolated enum ProductPriceManualPushStateKind: String, Sendable, Equatable {
    case idle
    case dryRunRunning
    case previewSafe
    case previewUnsafe
    case snapshotStale
    case overBatchLimit
    case pushReady
    case pushRunning
    case readBackRunning
    case verifiedSuccess
    case verificationUnknown
    case failedConflict
    case failedValidation
    case failedNetwork
    case cancelled
}

nonisolated enum ProductPriceManualPushDisabledReason: String, Sendable, Equatable {
    case serviceMissing
    case sessionMissing
    case unsafeDryRun
    case noCandidates
    case overBatchLimit
    case staleSnapshot
    case pushInProgress
    case validationFailed
}

nonisolated enum ProductPriceManualPushState: Sendable {
    case idle
    case dryRunRunning
    case previewSafe(plan: ProductPricePushDryRunPlan, snapshot: ProductPriceManualPushSnapshot)
    case previewUnsafe(plan: ProductPricePushDryRunPlan?, reason: ProductPriceManualPushDisabledReason)
    case snapshotStale(plan: ProductPricePushDryRunPlan?, reason: ProductPriceManualPushDisabledReason)
    case overBatchLimit(plan: ProductPricePushDryRunPlan, limit: Int, actual: Int)
    case pushReady(plan: ProductPricePushDryRunPlan, snapshot: ProductPriceManualPushSnapshot)
    case pushRunning(snapshot: ProductPriceManualPushSnapshot)
    case readBackRunning(snapshot: ProductPriceManualPushSnapshot)
    case verifiedSuccess(ProductPriceManualPushResult)
    case verificationUnknown(ProductPriceManualPushResult)
    case failedConflict(message: String?)
    case failedValidation(message: String?)
    case failedNetwork(message: String?)
    case cancelled

    var kind: ProductPriceManualPushStateKind {
        switch self {
        case .idle:
            return .idle
        case .dryRunRunning:
            return .dryRunRunning
        case .previewSafe:
            return .previewSafe
        case .previewUnsafe:
            return .previewUnsafe
        case .snapshotStale:
            return .snapshotStale
        case .overBatchLimit:
            return .overBatchLimit
        case .pushReady:
            return .pushReady
        case .pushRunning:
            return .pushRunning
        case .readBackRunning:
            return .readBackRunning
        case .verifiedSuccess:
            return .verifiedSuccess
        case .verificationUnknown:
            return .verificationUnknown
        case .failedConflict:
            return .failedConflict
        case .failedValidation:
            return .failedValidation
        case .failedNetwork:
            return .failedNetwork
        case .cancelled:
            return .cancelled
        }
    }

    var isBusy: Bool {
        switch self {
        case .dryRunRunning, .pushRunning, .readBackRunning:
            return true
        case .idle,
             .previewSafe,
             .previewUnsafe,
             .snapshotStale,
             .overBatchLimit,
             .pushReady,
             .verifiedSuccess,
             .verificationUnknown,
             .failedConflict,
             .failedValidation,
             .failedNetwork,
             .cancelled:
            return false
        }
    }

    var plan: ProductPricePushDryRunPlan? {
        switch self {
        case .previewSafe(let plan, _),
             .previewUnsafe(let plan?, _),
             .snapshotStale(let plan?, _),
             .overBatchLimit(let plan, _, _),
             .pushReady(let plan, _):
            return plan
        case .idle,
             .dryRunRunning,
             .previewUnsafe(nil, _),
             .snapshotStale(nil, _),
             .pushRunning,
             .readBackRunning,
             .verifiedSuccess,
             .verificationUnknown,
             .failedConflict,
             .failedValidation,
             .failedNetwork,
             .cancelled:
            return nil
        }
    }

    var snapshot: ProductPriceManualPushSnapshot? {
        switch self {
        case .previewSafe(_, let snapshot),
             .pushReady(_, let snapshot),
             .pushRunning(let snapshot),
             .readBackRunning(let snapshot):
            return snapshot
        case .idle,
             .dryRunRunning,
             .previewUnsafe,
             .snapshotStale,
             .overBatchLimit,
             .verifiedSuccess,
             .verificationUnknown,
             .failedConflict,
             .failedValidation,
             .failedNetwork,
             .cancelled:
            return nil
        }
    }
}

@MainActor
final class ProductPriceManualPushDebugViewModel: ObservableObject {
    @Published private(set) var state: ProductPriceManualPushState = .idle

    private let remote: (any ProductPriceManualPushRemote)?
    private let options: ProductPriceManualPushOptions
    private var task: Task<Void, Never>?
    private var requestID = 0

    init(
        remote: (any ProductPriceManualPushRemote)?,
        options: ProductPriceManualPushOptions = ProductPriceManualPushOptions()
    ) {
        self.remote = remote
        self.options = options
    }

    var canCalculatePreview: Bool {
        remote != nil && !state.isBusy
    }

    var canPush: Bool {
        switch state {
        case .previewSafe, .pushReady:
            return !state.isBusy
        case .idle,
             .dryRunRunning,
             .previewUnsafe,
             .snapshotStale,
             .overBatchLimit,
             .pushRunning,
             .readBackRunning,
             .verifiedSuccess,
             .verificationUnknown,
             .failedConflict,
             .failedValidation,
             .failedNetwork,
             .cancelled:
            return false
        }
    }

    func calculatePreview(context: ModelContext, sessionSnapshot: ProductPricePushDryRunSessionSnapshot) {
        guard !state.isBusy else { return }
        guard let remote else {
            state = .previewUnsafe(plan: nil, reason: .serviceMissing)
            return
        }
        guard sessionSnapshot.userID != nil else {
            state = .previewUnsafe(plan: nil, reason: .sessionMissing)
            return
        }

        startTask()
        let requestID = requestID
        state = .dryRunRunning

        task = Task { @MainActor in
            do {
                let service = SupabaseProductPricePushDryRunService(fetcher: remote)
                let plan = try await service.loadDryRun(context: context, sessionSnapshot: sessionSnapshot)
                guard self.requestID == requestID else { return }
                self.state = self.state(for: plan)
                self.task = nil
            } catch is CancellationError {
                guard self.requestID == requestID else { return }
                self.state = .cancelled
                self.task = nil
            } catch {
                guard self.requestID == requestID else { return }
                self.state = .failedValidation(message: String(describing: error))
                self.task = nil
            }
        }
    }

    func confirmPush() {
        guard !state.isBusy else { return }
        guard let remote else {
            state = .failedValidation(message: ProductPriceManualPushDisabledReason.serviceMissing.rawValue)
            return
        }
        guard let snapshot = state.snapshot else {
            state = .snapshotStale(plan: state.plan, reason: .staleSnapshot)
            return
        }

        startTask()
        let requestID = requestID
        state = .pushRunning(snapshot: snapshot)

        task = Task { @MainActor in
            let service = SupabaseProductPriceManualPushService(remote: remote, options: options)
            do {
                let insertedCount = try await service.insert(snapshot: snapshot)
                guard self.requestID == requestID else { return }
                self.state = .readBackRunning(snapshot: snapshot)
                let verification = try await service.verify(snapshot: snapshot)
                guard self.requestID == requestID else { return }

                let result = ProductPriceManualPushResult(
                    insertedCount: insertedCount,
                    verification: verification,
                    fingerprint: snapshot.fingerprint
                )
                self.state = self.terminalState(for: result)
                self.task = nil
            } catch is CancellationError {
                guard self.requestID == requestID else { return }
                self.state = .cancelled
                self.task = nil
            } catch let error as ProductPriceManualPushError {
                guard self.requestID == requestID else { return }
                self.state = self.terminalState(for: error)
                self.task = nil
            } catch {
                guard self.requestID == requestID else { return }
                self.state = .failedNetwork(message: String(describing: error))
                self.task = nil
            }
        }
    }

    func invalidateSnapshot(reason: ProductPriceManualPushDisabledReason = .staleSnapshot) {
        switch state {
        case .previewSafe(let plan, _), .pushReady(let plan, _):
            state = .snapshotStale(plan: plan, reason: reason)
        case .idle,
             .dryRunRunning,
             .previewUnsafe,
             .snapshotStale,
             .overBatchLimit,
             .pushRunning,
             .readBackRunning,
             .verifiedSuccess,
             .verificationUnknown,
             .failedConflict,
             .failedValidation,
             .failedNetwork,
             .cancelled:
            break
        }
    }

    func cancel() {
        guard state.isBusy else {
            task?.cancel()
            task = nil
            return
        }
        requestID += 1
        task?.cancel()
        task = nil
        state = .cancelled
    }

    func reset() {
        requestID += 1
        task?.cancel()
        task = nil
        state = .idle
    }

    private func startTask() {
        requestID += 1
        task?.cancel()
        task = nil
    }

    private func state(for plan: ProductPricePushDryRunPlan) -> ProductPriceManualPushState {
        do {
            let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan, options: options)
            return .previewSafe(plan: plan, snapshot: snapshot)
        } catch ProductPriceManualPushError.overBatchLimit(let limit, let actual) {
            return .overBatchLimit(plan: plan, limit: limit, actual: actual)
        } catch ProductPriceManualPushError.noCandidates {
            return .previewUnsafe(plan: plan, reason: .noCandidates)
        } catch ProductPriceManualPushError.unsafeDryRun {
            return .previewUnsafe(plan: plan, reason: .unsafeDryRun)
        } catch {
            return .previewUnsafe(plan: plan, reason: .validationFailed)
        }
    }

    private func terminalState(for result: ProductPriceManualPushResult) -> ProductPriceManualPushState {
        switch result.verification {
        case .exactMatch:
            return .verifiedSuccess(result)
        case .unknown:
            return .verificationUnknown(result)
        case .missingRows, .mismatchedRows:
            return .failedValidation(message: "read-back exact-match failed")
        }
    }

    private func terminalState(for error: ProductPriceManualPushError) -> ProductPriceManualPushState {
        switch error {
        case .uniqueConflict(let message):
            return .failedConflict(message: message)
        case .network(let message):
            return .failedNetwork(message: message)
        case .cancelled:
            return .cancelled
        case .unsafeDryRun:
            return .failedValidation(message: ProductPriceManualPushDisabledReason.unsafeDryRun.rawValue)
        case .noCandidates:
            return .failedValidation(message: ProductPriceManualPushDisabledReason.noCandidates.rawValue)
        case .overBatchLimit(let limit, let actual):
            return .failedValidation(message: "\(actual) > \(limit)")
        case .staleSnapshot:
            return .snapshotStale(plan: state.plan, reason: .staleSnapshot)
        case .invalidPayload:
            return .failedValidation(message: ProductPriceManualPushDisabledReason.validationFailed.rawValue)
        }
    }
}
#endif
