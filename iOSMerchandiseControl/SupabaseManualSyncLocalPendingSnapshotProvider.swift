import Foundation
import SwiftData

@MainActor
protocol SupabaseManualSyncLocalPendingSessionProviding: AnyObject {
    var manualSyncIsSignedIn: Bool { get }
    var manualSyncOwnerUserID: UUID? { get }
}

extension SupabaseAuthViewModel: SupabaseManualSyncLocalPendingSessionProviding {
    var manualSyncIsSignedIn: Bool { isSignedIn }
    var manualSyncOwnerUserID: UUID? { sessionInfo?.userID }
}

@MainActor
protocol SupabaseManualSyncCatalogPendingCounting: AnyObject {
    func pendingCatalogChangeCount(ownerUserID: UUID) async throws -> Int
}

@MainActor
protocol SupabaseManualSyncOutboxPendingCounting: AnyObject {
    func pendingQueuedCloudOperationCount(ownerUserID: UUID) async throws -> Int
}

@MainActor
protocol SupabaseManualSyncProductPricePendingCounting: AnyObject {
    func pendingProductPriceChangeCount(ownerUserID: UUID) async throws -> Int
}

@MainActor
final class SupabaseManualSyncLocalPendingSnapshotProvider: SupabaseManualSyncLocalPendingProviding {
    private let sessionProvider: any SupabaseManualSyncLocalPendingSessionProviding
    private let localPendingChangeCounter: (any SupabaseManualSyncLocalPendingChangeCounting)?
    private let catalogPendingCounter: any SupabaseManualSyncCatalogPendingCounting
    private let productPricePendingCounter: (any SupabaseManualSyncProductPricePendingCounting)?
    private let outboxPendingCounter: any SupabaseManualSyncOutboxPendingCounting

    init(
        sessionProvider: any SupabaseManualSyncLocalPendingSessionProviding,
        localPendingChangeCounter: (any SupabaseManualSyncLocalPendingChangeCounting)? = nil,
        catalogPendingCounter: any SupabaseManualSyncCatalogPendingCounting,
        productPricePendingCounter: (any SupabaseManualSyncProductPricePendingCounting)? = nil,
        outboxPendingCounter: any SupabaseManualSyncOutboxPendingCounting
    ) {
        self.sessionProvider = sessionProvider
        self.localPendingChangeCounter = localPendingChangeCounter
        self.catalogPendingCounter = catalogPendingCounter
        self.productPricePendingCounter = productPricePendingCounter
        self.outboxPendingCounter = outboxPendingCounter
    }

    func loadLocalPendingSnapshot() async throws -> SupabaseManualSyncPrivacyCounts {
        guard sessionProvider.manualSyncIsSignedIn,
              let ownerUserID = sessionProvider.manualSyncOwnerUserID else {
            return SupabaseManualSyncPrivacyCounts()
        }

        try Task.checkCancellation()
        let localSnapshot = try await localPendingChangeCounter?.pendingLocalChangeSnapshot(ownerUserID: ownerUserID)
        try Task.checkCancellation()
        let fallbackCatalogCount: Int
        if let localSnapshot, localSnapshot.pendingCatalogChangeCount > 0 {
            fallbackCatalogCount = 0
        } else {
            fallbackCatalogCount = try await catalogPendingCounter.pendingCatalogChangeCount(ownerUserID: ownerUserID)
        }
        try Task.checkCancellation()
        let priceCount: Int
        if let localSnapshot {
            priceCount = localSnapshot.pendingProductPriceChangeCount
        } else {
            priceCount = try await productPricePendingCounter?.pendingProductPriceChangeCount(ownerUserID: ownerUserID) ?? 0
        }
        try Task.checkCancellation()
        let outboxQueuedOperationCount = try await outboxPendingCounter.pendingQueuedCloudOperationCount(ownerUserID: ownerUserID)
        let historySessionQueuedOperationCount = localSnapshot?.pendingHistorySessionChangeCount ?? 0
        try Task.checkCancellation()

        return SupabaseManualSyncPrivacyCounts(
            pendingCatalogChangeCount: max(0, max(localSnapshot?.pendingCatalogChangeCount ?? 0, fallbackCatalogCount)),
            pendingPriceChangeCount: max(0, priceCount),
            pendingQueuedCloudOperationCount: max(0, outboxQueuedOperationCount + historySessionQueuedOperationCount)
        )
    }
}

@MainActor
protocol SupabaseManualSyncBaselineReading: AnyObject {
    func readManualPushBaseline(ownerUserID: UUID) throws -> SupabaseCatalogBaselineReadResult
}

@MainActor
private final class SupabaseManualSyncSwiftDataBaselineReader: SupabaseManualSyncBaselineReading {
    private let context: ModelContext
    private let reader: SupabaseCatalogBaselineReader

    init(
        context: ModelContext,
        reader: SupabaseCatalogBaselineReader = SupabaseCatalogBaselineReader()
    ) {
        self.context = context
        self.reader = reader
    }

    func readManualPushBaseline(ownerUserID: UUID) throws -> SupabaseCatalogBaselineReadResult {
        try reader.readManualPushBaseline(context: context, ownerUserUUID: ownerUserID)
    }
}

nonisolated struct SupabaseManualSyncCatalogSnapshot: Equatable, Sendable {
    let suppliers: [ManualPushLookupState]
    let categories: [ManualPushLookupState]
    let products: [ManualPushProductState]
    let exceededLimit: Bool
}

@MainActor
protocol SupabaseManualSyncCatalogSnapshotLoading: AnyObject {
    func loadCatalogSnapshot(maxRowsPerEntity: Int) throws -> SupabaseManualSyncCatalogSnapshot
}

@MainActor
final class SupabaseManualSyncCatalogPendingAdapter: SupabaseManualSyncCatalogPendingCounting {
    nonisolated static let defaultMaxRowsPerEntity = 1_000
    nonisolated static let hardMaxRowsPerEntity = 1_000

    private let baselineReader: any SupabaseManualSyncBaselineReading
    private let snapshotLoader: any SupabaseManualSyncCatalogSnapshotLoading
    private let preflightService: SupabaseManualPushPreflightService
    private let maxRowsPerEntity: Int

    convenience init(context: ModelContext) {
        self.init(
            baselineReader: SupabaseManualSyncSwiftDataBaselineReader(context: context),
            snapshotLoader: SupabaseManualSyncSwiftDataCatalogSnapshotLoader(context: context)
        )
    }

    init(
        baselineReader: any SupabaseManualSyncBaselineReading,
        snapshotLoader: any SupabaseManualSyncCatalogSnapshotLoading,
        preflightService: SupabaseManualPushPreflightService = SupabaseManualPushPreflightService(),
        maxRowsPerEntity: Int = defaultMaxRowsPerEntity
    ) {
        self.baselineReader = baselineReader
        self.snapshotLoader = snapshotLoader
        self.preflightService = preflightService
        self.maxRowsPerEntity = min(
            max(0, maxRowsPerEntity),
            Self.hardMaxRowsPerEntity
        )
    }

    func pendingCatalogChangeCount(ownerUserID: UUID) async throws -> Int {
        try Task.checkCancellation()
        let baselineResult = try baselineReader.readManualPushBaseline(ownerUserID: ownerUserID)
        guard case .available(let baselineSnapshot) = baselineResult else {
            return 0
        }
        guard baselineSnapshot.ownerUserUUID == ownerUserID else {
            return 0
        }

        try Task.checkCancellation()
        let snapshot = try snapshotLoader.loadCatalogSnapshot(maxRowsPerEntity: maxRowsPerEntity)
        if snapshot.exceededLimit {
            return 1
        }

        try Task.checkCancellation()
        let plan = preflightService.makePlan(input: ManualPushPreflightInput(
            baselineRunID: baselineSnapshot.runID,
            pullState: ManualPushPullState(isComplete: true),
            accountState: ManualPushAccountState(
                currentUserID: ownerUserID,
                lastLinkedUserID: baselineSnapshot.ownerUserUUID
            ),
            baseline: baselineSnapshot.baseline,
            suppliers: snapshot.suppliers,
            categories: snapshot.categories,
            products: snapshot.products
        ))

        return Self.pendingCatalogCount(from: plan)
    }

    private static func pendingCatalogCount(from plan: ManualPushPlan) -> Int {
        let catalogWriteOrLinkCandidates = plan.writeCandidates.filter {
            $0.entityKind == .supplier || $0.entityKind == .productCategory || $0.entityKind == .product
        }.count
        return catalogWriteOrLinkCandidates + plan.blockedReasons.count
    }
}

@MainActor
private final class SupabaseManualSyncSwiftDataCatalogSnapshotLoader: SupabaseManualSyncCatalogSnapshotLoading {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadCatalogSnapshot(maxRowsPerEntity: Int) throws -> SupabaseManualSyncCatalogSnapshot {
        let limit = min(
            max(0, maxRowsPerEntity),
            SupabaseManualSyncCatalogPendingAdapter.hardMaxRowsPerEntity
        )

        let supplierFetch = try fetchSuppliers(limit: limit)
        try Task.checkCancellation()
        let categoryFetch = try fetchCategories(limit: limit)
        try Task.checkCancellation()
        let productFetch = try fetchProducts(limit: limit)
        try Task.checkCancellation()

        return SupabaseManualSyncCatalogSnapshot(
            suppliers: supplierFetch.values.map { supplier in
                ManualPushLookupState(
                    entityKind: .supplier,
                    localID: supplier.name,
                    remoteID: supplier.remoteID,
                    remoteUpdatedAt: supplier.remoteUpdatedAt,
                    remoteDeletedAt: supplier.remoteDeletedAt,
                    name: supplier.name
                )
            },
            categories: categoryFetch.values.map { category in
                ManualPushLookupState(
                    entityKind: .productCategory,
                    localID: category.name,
                    remoteID: category.remoteID,
                    remoteUpdatedAt: category.remoteUpdatedAt,
                    remoteDeletedAt: category.remoteDeletedAt,
                    name: category.name
                )
            },
            products: productFetch.values.map { product in
                ManualPushProductState(
                    localID: product.barcode,
                    remoteID: product.remoteID,
                    remoteUpdatedAt: product.remoteUpdatedAt,
                    remoteDeletedAt: product.remoteDeletedAt,
                    barcode: product.barcode,
                    itemNumber: product.itemNumber,
                    productName: product.productName,
                    secondProductName: product.secondProductName,
                    purchasePrice: product.purchasePrice,
                    retailPrice: product.retailPrice,
                    stockQuantity: product.stockQuantity,
                    hasSupplierReference: product.supplier != nil,
                    supplierLocalID: product.supplier?.name,
                    supplierName: product.supplier?.name,
                    supplierRemoteID: product.supplier?.remoteID,
                    hasCategoryReference: product.category != nil,
                    categoryLocalID: product.category?.name,
                    categoryName: product.category?.name,
                    categoryRemoteID: product.category?.remoteID,
                    hasLocalPriceChanges: false
                )
            },
            exceededLimit: supplierFetch.exceededLimit || categoryFetch.exceededLimit || productFetch.exceededLimit
        )
    }

    private func fetchSuppliers(limit: Int) throws -> (values: [Supplier], exceededLimit: Bool) {
        var descriptor = FetchDescriptor<Supplier>(
            sortBy: [SortDescriptor(\Supplier.name, order: .forward)]
        )
        descriptor.fetchLimit = limit + 1
        let values = try context.fetch(descriptor)
        return (Array(values.prefix(limit)), values.count > limit)
    }

    private func fetchCategories(limit: Int) throws -> (values: [ProductCategory], exceededLimit: Bool) {
        var descriptor = FetchDescriptor<ProductCategory>(
            sortBy: [SortDescriptor(\ProductCategory.name, order: .forward)]
        )
        descriptor.fetchLimit = limit + 1
        let values = try context.fetch(descriptor)
        return (Array(values.prefix(limit)), values.count > limit)
    }

    private func fetchProducts(limit: Int) throws -> (values: [Product], exceededLimit: Bool) {
        var descriptor = FetchDescriptor<Product>(
            sortBy: [SortDescriptor(\Product.barcode, order: .forward)]
        )
        descriptor.fetchLimit = limit + 1
        let values = try context.fetch(descriptor)
        return (Array(values.prefix(limit)), values.count > limit)
    }
}

@MainActor
final class SupabaseManualSyncOutboxPendingAdapter: SupabaseManualSyncOutboxPendingCounting {
    private let context: ModelContext
    private let now: () -> Date

    init(
        context: ModelContext,
        now: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.now = now
    }

    func pendingQueuedCloudOperationCount(ownerUserID: UUID) async throws -> Int {
        try Task.checkCancellation()
        let counts = try SyncEventOutboxLocalStore(context: context).fetchCounts(
            ownerUserID: ownerUserID.uuidString.lowercased(),
            now: now()
        )
        return counts.pending + counts.failedRetryable + counts.blocked
    }
}
