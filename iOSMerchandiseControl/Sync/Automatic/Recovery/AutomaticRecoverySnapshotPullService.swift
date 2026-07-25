import Foundation
import SwiftData

nonisolated struct SyncRecoverySnapshotPullSummary: Sendable, Equatable {
    var catalog: SupabasePullApplyResult
    var history: HistorySessionPullResult
    var productPrices: ProductPriceApplyResult
    var watermarkAfter: Int64
    var activatedGenerationID: UUID?
    var completedRecoveryJournal: Bool

    init(
        catalog: SupabasePullApplyResult,
        history: HistorySessionPullResult,
        productPrices: ProductPriceApplyResult,
        watermarkAfter: Int64,
        activatedGenerationID: UUID? = nil,
        completedRecoveryJournal: Bool = false
    ) {
        self.catalog = catalog
        self.history = history
        self.productPrices = productPrices
        self.watermarkAfter = watermarkAfter
        self.activatedGenerationID = activatedGenerationID
        self.completedRecoveryJournal = completedRecoveryJournal
    }

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

nonisolated enum SyncRecoverySnapshotPublicationMode: Sendable, Equatable {
    case activeStoreLegacy
    case atomicGeneration
}

protocol SyncRecoverySnapshotPullProviding: Sendable {
    nonisolated var publicationMode: SyncRecoverySnapshotPublicationMode { get }
    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary
}

extension SyncRecoverySnapshotPullProviding {
    nonisolated var publicationMode: SyncRecoverySnapshotPublicationMode {
        .activeStoreLegacy
    }
}

private nonisolated final class AutomaticRecoveryUserDefaultsBox: @unchecked Sendable {
    let value: UserDefaults

    init(_ value: UserDefaults) {
        self.value = value
    }
}

actor AutomaticRecoverySnapshotPullService: SyncRecoverySnapshotPullProviding {
    private let modelContainer: ModelContainer
    private let previewService: SupabasePullPreviewService
    private let catalogApplyService: SupabasePullApplyService
    private let productPriceApplyService: SupabaseProductPriceApplyService
    private let historyRemote: any HistorySessionRemoteSyncing
    private let syncEventFetcher: any SupabaseSyncEventIncrementalFetching
    private let maximumWatermarkScanPages: Int
    private nonisolated let defaultsBox: AutomaticRecoveryUserDefaultsBox

    init(
        modelContainer: ModelContainer,
        previewService: SupabasePullPreviewService,
        catalogApplyService: SupabasePullApplyService = SupabasePullApplyService(),
        productPriceApplyService: SupabaseProductPriceApplyService,
        historyRemote: any HistorySessionRemoteSyncing,
        syncEventFetcher: any SupabaseSyncEventIncrementalFetching,
        defaults: UserDefaults = .standard,
        maximumWatermarkScanPages: Int = 512
    ) {
        self.modelContainer = modelContainer
        self.previewService = previewService
        self.catalogApplyService = catalogApplyService
        self.productPriceApplyService = productPriceApplyService
        self.historyRemote = historyRemote
        self.syncEventFetcher = syncEventFetcher
        self.maximumWatermarkScanPages = max(1, maximumWatermarkScanPages)
        self.defaultsBox = AutomaticRecoveryUserDefaultsBox(defaults)
    }

    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary {
        let recoveryScope = try Task126OwnerStoreGate.requireCurrentAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaultsBox.value
        )
        let context = ModelContext(modelContainer)
        let boundaryWatermark = try await latestSyncEventWatermark(
            ownerUserID: ownerUserID,
            recoveryScope: recoveryScope
        )
        try verifyRecoveryScope(recoveryScope, ownerUserID: ownerUserID)

        let preview = try await makeCompletePreview()
        try verifyRecoveryScope(recoveryScope, ownerUserID: ownerUserID)
        try validateAuthoritativePreviewWarnings(preview)
        let catalogResult = try await catalogApplyService.replaceLocalCatalogWithRemoteSnapshot(
            preview: preview,
            context: context,
            options: SupabasePullApplyOptions(allowLookupOnlyApplyWhenProductConflicts: false),
            isAuthenticated: true,
            accountGuard: SupabasePullApplyAccountGuard(
                currentUserID: ownerUserID,
                lastLinkedUserID: ownerUserID
            )
        )
        try verifyRecoveryScope(recoveryScope, ownerUserID: ownerUserID)
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerUserID,
            validateBeforeSave: { [defaultsBox] in
                try Task126OwnerStoreGate.revalidateAutomaticScope(
                    recoveryScope,
                    defaults: defaultsBox.value
                )
            }
        )

        try verifyRecoveryScope(recoveryScope, ownerUserID: ownerUserID)
        let historyResult = try await HistorySessionSyncService(remote: historyRemote).pullHistorySessionsFromCloud(
            ownerUserID: ownerUserID,
            context: context,
            automaticScope: recoveryScope,
            automaticScopeValidator: { [defaultsBox] expectedScope in
                try Task126OwnerStoreGate.revalidateAutomaticScope(
                    expectedScope,
                    defaults: defaultsBox.value
                )
            }
        )
        try verifyRecoveryScope(recoveryScope, ownerUserID: ownerUserID)

        let priceSession = ProductPriceApplySessionSnapshot(userID: ownerUserID)
        try verifyRecoveryScope(recoveryScope, ownerUserID: ownerUserID)
        let pricePlan = try await productPriceApplyService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: priceSession
        )
        try verifyRecoveryScope(recoveryScope, ownerUserID: ownerUserID)
        let priceResult = try await productPriceApplyService.applyPagedFullPull(
            plan: pricePlan,
            context: context,
            currentSessionSnapshot: priceSession
        )
        try verifyRecoveryScope(recoveryScope, ownerUserID: ownerUserID)

        return SyncRecoverySnapshotPullSummary(
            catalog: catalogResult,
            history: historyResult,
            productPrices: priceResult,
            watermarkAfter: boundaryWatermark
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

    private func validateAuthoritativePreviewWarnings(_ preview: SyncPreview) throws {
        let duplicateRemoteLookupNameCount = preview.warnings.reduce(into: 0) { count, warning in
            if warning.code == .remoteDuplicateName {
                count += 1
            }
        }
        guard duplicateRemoteLookupNameCount == 0 else {
            throw AutomaticRecoverySnapshotPullError.remoteDuplicateLookupNames(
                count: duplicateRemoteLookupNameCount
            )
        }
    }

    private func latestSyncEventWatermark(
        ownerUserID: UUID,
        recoveryScope: Task126VerifiedOwnerStoreScope
    ) async throws -> Int64 {
        var watermark: Int64 = 0
        var fetchedPageCount = 0
        while fetchedPageCount < maximumWatermarkScanPages {
            try verifyRecoveryScope(recoveryScope, ownerUserID: ownerUserID)
            let events = try await syncEventFetcher.fetchSyncEventsAfter(
                ownerUserID: ownerUserID,
                afterID: watermark,
                limit: SupabaseSyncEventIncrementalLimits.maximumLimit
            )
            fetchedPageCount += 1
            try verifyRecoveryScope(recoveryScope, ownerUserID: ownerUserID)
            for event in events {
                try Task126OwnerStoreGate.validateRemoteIdentity(
                    ownerUserID: event.ownerUserID,
                    shopID: event.shopID,
                    scope: recoveryScope
                )
            }
            guard !events.isEmpty else { return watermark }
            watermark = max(watermark, events.map(\.id).max() ?? watermark)
            guard events.count == SupabaseSyncEventIncrementalLimits.maximumLimit else {
                return watermark
            }
            guard fetchedPageCount < maximumWatermarkScanPages else {
                throw AutomaticRecoverySnapshotPullError.watermarkScanLimitExceeded(
                    maximumPages: maximumWatermarkScanPages,
                    pageSize: SupabaseSyncEventIncrementalLimits.maximumLimit
                )
            }
            try Task.checkCancellation()
            await Task.yield()
        }
        throw AutomaticRecoverySnapshotPullError.watermarkScanLimitExceeded(
            maximumPages: maximumWatermarkScanPages,
            pageSize: SupabaseSyncEventIncrementalLimits.maximumLimit
        )
    }

    private func verifyRecoveryScope(
        _ expected: Task126VerifiedOwnerStoreScope,
        ownerUserID: UUID
    ) throws {
        guard expected.ownerUserID == ownerUserID else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(expected, defaults: defaultsBox.value)
    }
}

nonisolated enum AutomaticRecoverySnapshotPullError: Error, Sendable, Equatable {
    case partialPreview(warnings: Int, sourceErrors: Int)
    case previewFailed(String)
    case previewNotTerminal
    case remoteDuplicateLookupNames(count: Int)
    case watermarkScanLimitExceeded(maximumPages: Int, pageSize: Int)
    case providerMissing
}
