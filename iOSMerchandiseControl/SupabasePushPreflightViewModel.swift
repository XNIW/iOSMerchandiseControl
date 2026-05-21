#if DEBUG
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
        case completedScopedSafe(Summary)
        case completedScopedBlocked(Summary)
        case completedNoWork(Summary)
        case completedBlocked(Summary)
        case completed(ExecutionSummary)
        case completedBaselineRefreshFailed(ExecutionSummary)
        case partial(ExecutionSummary)
        case failedBeforeWrite(ExecutionSummary)
        case blockedBeforeWrite(ExecutionSummary)
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
        let scopeSummary: ManualPushScopeSummary
        let totalCandidates: Int
        let supplierCreates: Int
        let supplierUpdates: Int
        let supplierLinks: Int
        let categoryCreates: Int
        let categoryUpdates: Int
        let categoryLinks: Int
        let productCreates: Int
        let productUpdates: Int
        let productLinks: Int
        let totalBlockers: Int
        let totalWarnings: Int
        let totalFutureOnly: Int
        let groups: [CategoryGroup]
    }

    struct ExecutionSummary: Equatable {
        let result: SupabaseManualPushResult
        let planFingerprint: String
    }

    @Published private(set) var state: ViewState = .idle
    @Published private(set) var lastPreview: ManualPushPreview?

    private let service: SupabaseManualPushPreflightService
    private let baselineReader: SupabaseCatalogBaselineReader
    private let manualPushService: SupabaseManualPushService?
    private var runningTask: Task<Void, Never>?
    private var frozenConfirmationPlan: ManualPushPlan?
    private let examplesLimit: Int

    init(
        service: SupabaseManualPushPreflightService = SupabaseManualPushPreflightService(),
        baselineReader: SupabaseCatalogBaselineReader = SupabaseCatalogBaselineReader(),
        manualPushService: SupabaseManualPushService? = nil,
        examplesLimit: Int = 3
    ) {
        self.service = service
        self.baselineReader = baselineReader
        self.manualPushService = manualPushService
        self.examplesLimit = max(1, examplesLimit)
    }

    deinit {
        runningTask?.cancel()
    }

    func cancel() {
        runningTask?.cancel()
        runningTask = nil
        frozenConfirmationPlan = nil
        if case .running = state {
            state = .idle
        }
    }

    func runLocalCheck(
        context: ModelContext,
        isSignedIn: Bool,
        currentUserID: UUID?,
        lastLinkedUserID: UUID?,
        scope: ManualPushPreflightScope = .global
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
                    lastLinkedUserID: lastLinkedUserID,
                    scope: scope
                )
                let preview = await Task.detached(priority: .userInitiated) {
                    service.makePreview(input: input)
                }.value
                if Task.isCancelled { return }
                self.lastPreview = preview
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

    func freezeCurrentPlanForConfirmation() -> ManualPushPlan? {
        guard !isRunning,
              let plan = lastPreview?.plan,
              plan.isSendable,
              !plan.hasBlockers,
              !plan.scopeSummary.hasScopedBlocker else {
            frozenConfirmationPlan = nil
            return nil
        }
        frozenConfirmationPlan = plan
        return plan
    }

    func clearFrozenConfirmationPlan() {
        frozenConfirmationPlan = nil
    }

    func runConfirmedPush(
        context: ModelContext,
        isSignedIn: Bool,
        currentUserID: UUID?,
        lastLinkedUserID: UUID?
    ) {
        guard !isRunning else { return }
        guard isSignedIn, let currentUserID else {
            state = .blockedBeforeWrite(
                ExecutionSummary(result: .blocked(message: "Account not linked."), planFingerprint: "")
            )
            frozenConfirmationPlan = nil
            return
        }
        guard let manualPushService else {
            state = .failedBeforeWrite(
                ExecutionSummary(result: .blocked(message: "Supabase push service unavailable."), planFingerprint: "")
            )
            frozenConfirmationPlan = nil
            return
        }
        guard let frozenPlan = frozenConfirmationPlan else {
            state = .blockedBeforeWrite(
                ExecutionSummary(result: .blocked(message: "Missing confirmed preflight plan."), planFingerprint: "")
            )
            return
        }

        state = .running
        runningTask = Task { [weak self] in
            guard let self else { return }
            let frozenFingerprint = frozenPlan.planFingerprint

            do {
                let preflightService = self.service
                let input = try self.makeInput(
                    context: context,
                    currentUserID: currentUserID,
                    lastLinkedUserID: lastLinkedUserID,
                    scope: frozenPlan.scope
                )
                let currentPlan = await Task.detached(priority: .userInitiated) {
                    preflightService.makePlan(input: input)
                }.value

                guard currentPlan.planFingerprint == frozenFingerprint else {
                    self.state = .blockedBeforeWrite(
                        ExecutionSummary(
                            result: .blocked(message: "Preflight plan changed before confirmation."),
                            planFingerprint: frozenFingerprint
                        )
                    )
                    self.frozenConfirmationPlan = nil
                    self.runningTask = nil
                    return
                }

                let result = await manualPushService.execute(
                    plan: frozenPlan,
                    context: context,
                    ownerUserID: currentUserID
                )
                if Task.isCancelled { return }
                self.state = Self.makeExecutionState(
                    result: result,
                    planFingerprint: frozenFingerprint
                )
                self.frozenConfirmationPlan = nil
            } catch {
                if Task.isCancelled { return }
                self.state = .failedBeforeWrite(
                    ExecutionSummary(
                        result: .blocked(message: String(describing: error)),
                        planFingerprint: frozenFingerprint
                    )
                )
                self.frozenConfirmationPlan = nil
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
        lastLinkedUserID: UUID?,
        scope: ManualPushPreflightScope = .global
    ) throws -> ManualPushPreflightInput {
        let snapshotService = SwiftDataInventorySnapshotService(context: context)
        let supplierStates = try snapshotService.makeManualPushPreflightSupplierStates()
        let categoryStates = try snapshotService.makeManualPushPreflightCategoryStates()
        let productStates = try snapshotService.makeManualPushPreflightProductStates()
        let baselineResult = try baselineReader.readManualPushBaseline(
            context: context,
            ownerUserUUID: try requireUserID(currentUserID)
        )
        let mappedBaseline = mapBaselineResult(
            baselineResult,
            currentUserID: currentUserID
        )

        return ManualPushPreflightInput(
            baselineRunID: mappedBaseline.runID,
            scope: scope,
            pullState: ManualPushPullState(isComplete: true, hasSourceErrors: false),
            accountState: mappedBaseline.accountState ?? ManualPushAccountState(
                currentUserID: currentUserID,
                lastLinkedUserID: lastLinkedUserID ?? currentUserID
            ),
            baseline: mappedBaseline.baseline,
            suppliers: supplierStates,
            categories: categoryStates,
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
    ) -> (runID: UUID?, baseline: ManualPushBaseline?, accountState: ManualPushAccountState?) {
        switch result {
        case .available(let snapshot):
            return (
                runID: snapshot.runID,
                baseline: snapshot.baseline,
                accountState: ManualPushAccountState(currentUserID: currentUserID, lastLinkedUserID: snapshot.ownerUserUUID)
            )
        case .missing:
            return (runID: nil, baseline: nil, accountState: nil)
        case .accountMismatch:
            return (
                runID: nil,
                baseline: nil,
                accountState: ManualPushAccountState(currentUserID: currentUserID, lastLinkedUserID: UUID())
            )
        case .staleSchema:
            return (
                runID: nil,
                baseline: ManualPushBaseline(
                    productFingerprintsByRemoteID: [:],
                    invalidationReasons: [.fingerprintVersionChanged]
                ),
                accountState: nil
            )
        case .incomplete:
            return (
                runID: nil,
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
            if summary.scopeSummary.mode.isScopedTask045 {
                return .completedScopedBlocked(summary)
            }
            return .completedBlocked(summary)
        }
        if summary.scopeSummary.mode.isScopedTask045 {
            return .completedScopedSafe(summary)
        }
        if summary.totalCandidates == 0 {
            return .completedNoWork(summary)
        }
        return .completedSafe(summary)
    }

    static func makeExecutionState(
        result: SupabaseManualPushResult,
        planFingerprint: String
    ) -> ViewState {
        let summary = ExecutionSummary(result: result, planFingerprint: planFingerprint)
        switch result.status {
        case .completed:
            return .completed(summary)
        case .completedBaselineRefreshFailed:
            return .completedBaselineRefreshFailed(summary)
        case .partial:
            return .partial(summary)
        case .failedBeforeWrite:
            return .failedBeforeWrite(summary)
        case .blockedBeforeWrite:
            return .blockedBeforeWrite(summary)
        }
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
            scopeSummary: preview.plan.scopeSummary,
            totalCandidates: preview.plan.writeCandidates.count,
            supplierCreates: preview.plan.count(entityKind: .supplier, action: .dryRunCreateCandidate),
            supplierUpdates: preview.plan.count(entityKind: .supplier, action: .dryRunUpdateCandidate),
            supplierLinks: preview.plan.count(entityKind: .supplier, action: .dryRunLinkCandidate),
            categoryCreates: preview.plan.count(entityKind: .productCategory, action: .dryRunCreateCandidate),
            categoryUpdates: preview.plan.count(entityKind: .productCategory, action: .dryRunUpdateCandidate),
            categoryLinks: preview.plan.count(entityKind: .productCategory, action: .dryRunLinkCandidate),
            productCreates: preview.plan.count(entityKind: .product, action: .dryRunCreateCandidate),
            productUpdates: preview.plan.count(entityKind: .product, action: .dryRunUpdateCandidate),
            productLinks: preview.plan.count(entityKind: .product, action: .dryRunLinkCandidate),
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
#endif
