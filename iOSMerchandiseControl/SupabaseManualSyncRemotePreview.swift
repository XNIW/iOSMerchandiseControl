import Foundation
import SwiftData

@MainActor
protocol SupabaseManualSyncRemotePreviewProviding: AnyObject {
    func loadRemotePreviewSummary() async -> SupabaseManualSyncRemotePreviewSummary
}

@MainActor
protocol SupabaseManualSyncRemotePreviewStaging: AnyObject {
    var stagedPreviewForLocalApply: SyncPreview? { get }
    func clearStagedPreviewForLocalApply()
}

nonisolated enum SupabaseManualSyncRemotePreviewMessageKey: String, Sendable, Equatable {
    case cloudCheckCompleteNoAction
    case cloudDataNeedsReview
    case cloudCheckIncomplete
    case cloudCheckFailedRetry
    case cloudCheckFailedPermission
    case cloudCheckFailedTechnical
    case cloudCheckCancelled
}

nonisolated enum SupabaseManualSyncRemotePreviewFailureCategory: String, Sendable, Equatable {
    case network
    case permission
    case schemaOrDecode
    case localSnapshot
    case unknown
}

nonisolated struct SupabaseManualSyncRemotePreviewAggregateCounts: Sendable, Equatable {
    var remoteProductCount: Int = 0
    var remoteSupplierCount: Int = 0
    var remoteCategoryCount: Int = 0
    var remoteProductPriceCount: Int = 0
    var newProductCount: Int = 0
    var updateCandidateCount: Int = 0
    var conflictCount: Int = 0
    var tombstoneCount: Int = 0
    var warningCount: Int = 0
    var sourceErrorCount: Int = 0
    var supplierDiffCount: Int = 0
    var categoryDiffCount: Int = 0
    var priceHistorySignalCount: Int = 0

    var reviewSignalCount: Int {
        newProductCount
            + updateCandidateCount
            + conflictCount
            + tombstoneCount
            + warningCount
            + sourceErrorCount
            + supplierDiffCount
            + categoryDiffCount
            + priceHistorySignalCount
    }
}

nonisolated struct SupabaseManualSyncRemotePreviewSummary: Sendable, Equatable {
    var hasRemoteSignals: Bool
    var isComplete: Bool
    var isPartial: Bool
    var wasCancelled: Bool
    var safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts
    var recommendedUserMessageKey: SupabaseManualSyncRemotePreviewMessageKey
    var failureCategory: SupabaseManualSyncRemotePreviewFailureCategory?
}

nonisolated enum SupabaseManualSyncRemotePreviewOutcomeMapper {
    static func summary(from viewState: SupabasePullPreviewViewState) -> SupabaseManualSyncRemotePreviewSummary {
        switch viewState {
        case .success(let preview):
            return summary(from: preview, isComplete: true)
        case .partial(let preview, _, _):
            return summary(from: preview, isComplete: false)
        case .failed(let error):
            return failedSummary(for: error)
        case .idle, .loading:
            return failureSummary(category: .unknown)
        }
    }

    static func cancelledSummary() -> SupabaseManualSyncRemotePreviewSummary {
        SupabaseManualSyncRemotePreviewSummary(
            hasRemoteSignals: false,
            isComplete: false,
            isPartial: false,
            wasCancelled: true,
            safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(),
            recommendedUserMessageKey: .cloudCheckCancelled,
            failureCategory: nil
        )
    }

    static func phaseOutcome(for summary: SupabaseManualSyncRemotePreviewSummary) -> SupabaseManualSyncPhaseOutcome {
        if summary.wasCancelled {
            return .cancelled
        }

        if let failureCategory = summary.failureCategory {
            switch failureCategory {
            case .network:
                return .failedRetryable
            case .permission:
                return .blocked
            case .schemaOrDecode, .localSnapshot, .unknown:
                return .failedNonRetryable
            }
        }

        if summary.isPartial {
            return .partial
        }

        return summary.isComplete ? .completed : .failedNonRetryable
    }

    static func finalUserState(for summary: SupabaseManualSyncRemotePreviewSummary) -> SupabaseManualSyncFinalUserState {
        if summary.wasCancelled {
            return .cancelled
        }

        if let failureCategory = summary.failureCategory {
            switch failureCategory {
            case .network:
                return .connectivityIssue
            case .permission, .schemaOrDecode, .localSnapshot, .unknown:
                return .technicalReviewNeeded
            }
        }

        if summary.isPartial {
            return .technicalReviewNeeded
        }

        if summary.hasRemoteSignals {
            return .technicalReviewNeeded
        }

        return .completedSuccessfully
    }

    private static func summary(
        from preview: SyncPreview,
        isComplete: Bool
    ) -> SupabaseManualSyncRemotePreviewSummary {
        let counts = SupabaseManualSyncRemotePreviewAggregateCounts(
            remoteProductCount: preview.remoteCounts.products,
            remoteSupplierCount: preview.remoteCounts.suppliers,
            remoteCategoryCount: preview.remoteCounts.categories,
            remoteProductPriceCount: preview.remoteCounts.productPrices,
            newProductCount: preview.newProducts.count,
            updateCandidateCount: preview.updateCandidates.count,
            conflictCount: preview.conflicts.count,
            tombstoneCount: preview.remoteTombstones.count,
            warningCount: preview.warnings.count,
            sourceErrorCount: preview.sourceErrors.count,
            supplierDiffCount: preview.supplierDiffs.count,
            categoryDiffCount: preview.categoryDiffs.count,
            priceHistorySignalCount: preview.priceHistoryDiffs.count
        )
        let partial = !isComplete || preview.outcome == .partial
        let hasSignals = counts.reviewSignalCount > 0

        return SupabaseManualSyncRemotePreviewSummary(
            hasRemoteSignals: hasSignals,
            isComplete: !partial,
            isPartial: partial,
            wasCancelled: false,
            safeAggregateCounts: counts,
            recommendedUserMessageKey: partial
                ? .cloudCheckIncomplete
                : (hasSignals ? .cloudDataNeedsReview : .cloudCheckCompleteNoAction),
            failureCategory: nil
        )
    }

    private static func failedSummary(for error: SupabasePullPreviewError) -> SupabaseManualSyncRemotePreviewSummary {
        switch error {
        case .service(let serviceError):
            return failureSummary(category: failureCategory(for: serviceError))
        case .localSnapshot:
            return failureSummary(category: .localSnapshot)
        case .unknown:
            return failureSummary(category: .unknown)
        }
    }

    private static func failureCategory(
        for error: SupabaseInventoryServiceError
    ) -> SupabaseManualSyncRemotePreviewFailureCategory {
        switch error {
        case .networkError:
            return .network
        case .permissionDeniedOrRLS, .sessionMissing, .configMissing, .invalidConfig:
            return .permission
        case .schemaDrift, .decodingError:
            return .schemaOrDecode
        case .unknown:
            return .unknown
        }
    }

    private static func failureSummary(
        category: SupabaseManualSyncRemotePreviewFailureCategory
    ) -> SupabaseManualSyncRemotePreviewSummary {
        let key: SupabaseManualSyncRemotePreviewMessageKey
        switch category {
        case .network:
            key = .cloudCheckFailedRetry
        case .permission:
            key = .cloudCheckFailedPermission
        case .schemaOrDecode, .localSnapshot, .unknown:
            key = .cloudCheckFailedTechnical
        }

        return SupabaseManualSyncRemotePreviewSummary(
            hasRemoteSignals: false,
            isComplete: false,
            isPartial: false,
            wasCancelled: false,
            safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(),
            recommendedUserMessageKey: key,
            failureCategory: category
        )
    }
}

@MainActor
final class SupabaseManualSyncPullPreviewAdapter: SupabaseManualSyncRemotePreviewProviding, SupabaseManualSyncRemotePreviewStaging {
    private let service: SupabasePullPreviewService
    private let context: ModelContext
    private(set) var stagedPreviewForLocalApply: SyncPreview?

    init(
        service: SupabasePullPreviewService,
        context: ModelContext
    ) {
        self.service = service
        self.context = context
    }

    func loadRemotePreviewSummary() async -> SupabaseManualSyncRemotePreviewSummary {
        clearStagedPreviewForLocalApply()

        do {
            try Task.checkCancellation()
            let viewState = await service.generatePreview(context: context)
            try Task.checkCancellation()
            stagePreviewIfComplete(viewState)
            return SupabaseManualSyncRemotePreviewOutcomeMapper.summary(from: viewState)
        } catch is CancellationError {
            clearStagedPreviewForLocalApply()
            return SupabaseManualSyncRemotePreviewOutcomeMapper.cancelledSummary()
        } catch {
            clearStagedPreviewForLocalApply()
            return SupabaseManualSyncRemotePreviewSummary(
                hasRemoteSignals: false,
                isComplete: false,
                isPartial: false,
                wasCancelled: false,
                safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(),
                recommendedUserMessageKey: .cloudCheckFailedTechnical,
                failureCategory: .unknown
            )
        }
    }

    func clearStagedPreviewForLocalApply() {
        stagedPreviewForLocalApply = nil
    }

    private func stagePreviewIfComplete(_ viewState: SupabasePullPreviewViewState) {
        guard case .success(let preview) = viewState else { return }
        stagedPreviewForLocalApply = preview
    }
}
