import Foundation
import SwiftData
import Combine

@MainActor
final class SupabasePushPreflightViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case accountNotLinked
        case running
        case completedSafe(Summary)
        case completedNoWork(Summary)
        case completedBlocked(Summary)
        case failedLocalError
    }

    struct Summary: Equatable {
        struct CategoryGroup: Identifiable, Equatable {
            let category: ManualPushPreflightCategory
            let count: Int
            let severity: PushSeverity
            let examples: [String]
            let hiddenCount: Int

            var id: String { category.rawValue }
        }

        let generatedAt: Date
        let categoryCounts: [ManualPushPreflightCategory: Int]
        let totalCandidates: Int
        let totalBlockers: Int
        let totalWarnings: Int
        let totalFutureOnly: Int
        let groups: [CategoryGroup]
    }

    @Published private(set) var state: ViewState = .idle

    private let service: SupabaseManualPushPreflightService
    private let baselineReader: SupabaseCatalogBaselineReader
    private var runningTask: Task<Void, Never>?
    private let examplesLimit: Int

    init(
        service: SupabaseManualPushPreflightService = SupabaseManualPushPreflightService(),
        baselineReader: SupabaseCatalogBaselineReader = SupabaseCatalogBaselineReader(),
        examplesLimit: Int = 3
    ) {
        self.service = service
        self.baselineReader = baselineReader
        self.examplesLimit = max(1, examplesLimit)
    }

    deinit {
        runningTask?.cancel()
    }

    func cancel() {
        runningTask?.cancel()
        runningTask = nil
    }

    func runLocalCheck(
        context: ModelContext,
        isSignedIn: Bool,
        currentUserID: UUID?,
        lastLinkedUserID: UUID?
    ) {
        guard !isRunning else { return }
        guard isSignedIn, currentUserID != nil else {
            state = .accountNotLinked
            return
        }

        state = .running
        runningTask = Task { [weak self] in
            guard let self else { return }

            do {
                let service = self.service
                let examplesLimit = self.examplesLimit
                let input = try self.makeInput(
                    context: context,
                    currentUserID: currentUserID,
                    lastLinkedUserID: lastLinkedUserID
                )
                let preview = await Task.detached(priority: .userInitiated) {
                    service.makePreview(input: input)
                }.value
                if Task.isCancelled { return }
                self.state = Self.makeCompletedState(
                    preview: preview,
                    examplesLimit: examplesLimit
                )
            } catch {
                if Task.isCancelled { return }
                self.state = .failedLocalError
            }

            self.runningTask = nil
        }
    }

    var isRunning: Bool {
        if case .running = state {
            return true
        }
        return false
    }

    private func makeInput(
        context: ModelContext,
        currentUserID: UUID?,
        lastLinkedUserID: UUID?
    ) throws -> ManualPushPreflightInput {
        let productStates = try SwiftDataInventorySnapshotService(context: context)
            .makeManualPushPreflightProductStates()
        let baselineResult = try baselineReader.readManualPushBaseline(
            context: context,
            ownerUserUUID: try requireUserID(currentUserID)
        )
        let mappedBaseline = mapBaselineResult(
            baselineResult,
            currentUserID: currentUserID
        )

        return ManualPushPreflightInput(
            pullState: ManualPushPullState(isComplete: true, hasSourceErrors: false),
            accountState: mappedBaseline.accountState ?? ManualPushAccountState(
                currentUserID: currentUserID,
                lastLinkedUserID: lastLinkedUserID ?? currentUserID
            ),
            baseline: mappedBaseline.baseline,
            products: productStates
        )
    }

    private func requireUserID(_ currentUserID: UUID?) throws -> UUID {
        guard let currentUserID else {
            throw SupabasePushPreflightInputError.missingUserID
        }
        return currentUserID
    }

    private func mapBaselineResult(
        _ result: SupabaseCatalogBaselineReadResult,
        currentUserID: UUID?
    ) -> (baseline: ManualPushBaseline?, accountState: ManualPushAccountState?) {
        switch result {
        case .available(let snapshot):
            return (
                baseline: snapshot.baseline,
                accountState: ManualPushAccountState(currentUserID: currentUserID, lastLinkedUserID: snapshot.ownerUserUUID)
            )
        case .missing:
            return (baseline: nil, accountState: nil)
        case .accountMismatch:
            return (
                baseline: nil,
                accountState: ManualPushAccountState(currentUserID: currentUserID, lastLinkedUserID: UUID())
            )
        case .staleSchema:
            return (
                baseline: ManualPushBaseline(
                    productFingerprintsByRemoteID: [:],
                    invalidationReasons: [.fingerprintVersionChanged]
                ),
                accountState: nil
            )
        case .incomplete:
            return (
                baseline: ManualPushBaseline(
                    productFingerprintsByRemoteID: [:],
                    invalidationReasons: [.partialPull]
                ),
                accountState: nil
            )
        }
    }

    static func makeCompletedState(
        preview: ManualPushPreview,
        examplesLimit: Int
    ) -> ViewState {
        let summary = makeSummary(
            preview: preview,
            examplesLimit: max(1, examplesLimit)
        )
        if summary.totalBlockers > 0 {
            return .completedBlocked(summary)
        }
        if summary.totalCandidates == 0 {
            return .completedNoWork(summary)
        }
        return .completedSafe(summary)
    }

    static func makeSummary(
        preview: ManualPushPreview,
        examplesLimit: Int
    ) -> Summary {
        let limit = max(1, examplesLimit)
        var examplesByCategory: [ManualPushPreflightCategory: [String]] = [:]

        for candidate in preview.plan.candidates {
            examplesByCategory[candidate.category, default: []].append(candidate.localID)
        }
        for reason in preview.plan.blockedReasons {
            examplesByCategory[reason.category, default: []].append(reason.rawValue)
        }
        for warning in preview.plan.warnings {
            guard let category = warning.category else { continue }
            examplesByCategory[category, default: []].append(warning.rawValue)
        }

        let groups = preview.categoryCounts
            .sorted { lhs, rhs in
                if lhs.key.severity == rhs.key.severity {
                    return lhs.key.rawValue < rhs.key.rawValue
                }
                return severityRank(lhs.key.severity) < severityRank(rhs.key.severity)
            }
            .map { category, count in
                let allExamples = Array(Set(examplesByCategory[category, default: []])).sorted()
                let visible = Array(allExamples.prefix(limit))
                return Summary.CategoryGroup(
                    category: category,
                    count: count,
                    severity: category.severity,
                    examples: visible,
                    hiddenCount: max(0, allExamples.count - visible.count)
                )
            }

        return Summary(
            generatedAt: preview.generatedAt,
            categoryCounts: preview.categoryCounts,
            totalCandidates: preview.plan.candidates.filter {
                $0.action == .dryRunCreateCandidate || $0.action == .dryRunUpdateCandidate
            }.count,
            totalBlockers: preview.plan.blockedReasons.count,
            totalWarnings: preview.plan.warnings.filter { $0.severity == .warning }.count,
            totalFutureOnly: preview.plan.candidates.filter { $0.severity == .futureOnly }.count
                + preview.plan.warnings.filter { $0.severity == .futureOnly }.count,
            groups: groups
        )
    }

    private static func severityRank(_ severity: PushSeverity) -> Int {
        switch severity {
        case .blocker: return 0
        case .warning: return 1
        case .futureOnly: return 2
        case .info: return 3
        }
    }
}

private enum SupabasePushPreflightInputError: Error {
    case missingUserID
}
