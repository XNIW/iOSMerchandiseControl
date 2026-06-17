import Foundation
import SwiftData

nonisolated struct SyncRecoverySnapshotPullSummary: Sendable, Equatable {
    var catalog: SupabasePullApplyResult
    var history: HistorySessionPullResult
    var productPrices: ProductPriceApplyResult
    var watermarkAfter: Int64

    var didWork: Bool {
        catalog.inserted > 0 ||
            catalog.updated > 0 ||
            catalog.suppliersCreated > 0 ||
            catalog.categoriesCreated > 0 ||
            catalog.productTombstoned > 0 ||
            catalog.productPruned > 0 ||
            history.insertedCount > 0 ||
            history.updatedCount > 0 ||
            history.prunedMissingRemoteCount > 0 ||
            productPrices.inserted > 0 ||
            productPrices.remoteIdentityLinked > 0 ||
            productPrices.prunedLocal > 0 ||
            watermarkAfter > 0
    }
}

protocol SyncRecoverySnapshotPullProviding: Sendable {
    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary
}

actor AutomaticRecoverySnapshotPullService: SyncRecoverySnapshotPullProviding {
    private let modelContainer: ModelContainer
    private let previewService: SupabasePullPreviewService
    private let catalogApplyService: SupabasePullApplyService
    private let productPriceApplyService: SupabaseProductPriceApplyService
    private let historyRemote: any HistorySessionRemoteSyncing
    private let syncEventFetcher: any SupabaseSyncEventIncrementalFetching

    init(
        modelContainer: ModelContainer,
        previewService: SupabasePullPreviewService,
        catalogApplyService: SupabasePullApplyService = SupabasePullApplyService(),
        productPriceApplyService: SupabaseProductPriceApplyService,
        historyRemote: any HistorySessionRemoteSyncing,
        syncEventFetcher: any SupabaseSyncEventIncrementalFetching
    ) {
        self.modelContainer = modelContainer
        self.previewService = previewService
        self.catalogApplyService = catalogApplyService
        self.productPriceApplyService = productPriceApplyService
        self.historyRemote = historyRemote
        self.syncEventFetcher = syncEventFetcher
    }

    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary {
        let context = ModelContext(modelContainer)
        let preview = try await makeCompletePreview()
        let catalogResult = try await catalogApplyService.replaceLocalCatalogWithRemoteSnapshot(
            preview: preview,
            context: context,
            isAuthenticated: true,
            accountGuard: SupabasePullApplyAccountGuard(
                currentUserID: ownerUserID,
                lastLinkedUserID: ownerUserID
            )
        )
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerUserID
        )

        let historyResult = try await HistorySessionSyncService(remote: historyRemote).pullHistorySessionsFromCloud(
            ownerUserID: ownerUserID,
            context: context
        )

        let priceSession = ProductPriceApplySessionSnapshot(userID: ownerUserID)
        let pricePlan = try await productPriceApplyService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: priceSession
        )
        let priceResult = try await productPriceApplyService.applyPagedFullPull(
            plan: pricePlan,
            context: context,
            currentSessionSnapshot: priceSession
        )

        let watermark = try await latestSyncEventWatermark(ownerUserID: ownerUserID)
        SyncEventIncrementalDomainApplyService.markWatermarkAfterFullRecovery(
            ownerUserID: ownerUserID,
            watermark: watermark
        )

        return SyncRecoverySnapshotPullSummary(
            catalog: catalogResult,
            history: historyResult,
            productPrices: priceResult,
            watermarkAfter: watermark
        )
    }

    private func makeCompletePreview() async throws -> SyncPreview {
        let state = await previewService.generatePreview(modelContainer: modelContainer)
        switch state {
        case .success(let preview):
            return preview
        case .partial(_, let warnings, let sourceErrors):
            throw AutomaticRecoverySnapshotPullError.partialPreview(
                warnings: warnings.count,
                sourceErrors: sourceErrors.count
            )
        case .failed(let error):
            throw AutomaticRecoverySnapshotPullError.previewFailed(
                error.safeDiagnosticDetail ?? "preview_failed"
            )
        case .idle, .loading:
            throw AutomaticRecoverySnapshotPullError.previewNotTerminal
        }
    }

    private func latestSyncEventWatermark(ownerUserID: UUID) async throws -> Int64 {
        var watermark: Int64 = 0
        while true {
            let events = try await syncEventFetcher.fetchSyncEventsAfter(
                ownerUserID: ownerUserID,
                afterID: watermark,
                limit: SupabaseSyncEventIncrementalLimits.maximumLimit
            )
            guard !events.isEmpty else { return watermark }
            watermark = max(watermark, events.map(\.id).max() ?? watermark)
            guard events.count == SupabaseSyncEventIncrementalLimits.maximumLimit else {
                return watermark
            }
            try Task.checkCancellation()
            await Task.yield()
        }
    }
}

nonisolated enum AutomaticRecoverySnapshotPullError: Error, Sendable, Equatable {
    case partialPreview(warnings: Int, sourceErrors: Int)
    case previewFailed(String)
    case previewNotTerminal
    case providerMissing
}
