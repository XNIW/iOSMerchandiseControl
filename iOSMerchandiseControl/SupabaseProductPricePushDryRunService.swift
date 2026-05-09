import Foundation
import SwiftData

protocol SupabaseProductPricePushDryRunRemoteFetching: Sendable {
    func fetchProductPricesForPushDryRunDedupePage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow]
}

extension SupabaseInventoryService: SupabaseProductPricePushDryRunRemoteFetching {}

nonisolated struct ProductPricePushDryRunSessionSnapshot: Sendable, Equatable {
    let userID: UUID?
    let lastLinkedUserID: UUID?
}

nonisolated enum ProductPricePushBaselineState: Sendable, Equatable {
    case available(ManualPushBaseline)
    case missing
    case accountMismatch
    case stale
    case partial
}

nonisolated struct ProductPricePushDryRunLocalSnapshot: Sendable {
    let products: [ProductPricePushDryRunLocalProduct]
    let prices: [ProductPricePushDryRunLocalPrice]
}

nonisolated struct ProductPricePushDryRunLocalProduct: Sendable, Equatable {
    let localID: String
    let remoteID: UUID?
    let barcode: String
    let productName: String?
}

nonisolated struct ProductPricePushDryRunLocalPrice: Sendable, Equatable {
    let localID: String
    let productLocalID: String
    let productRemoteID: UUID?
    let productBarcode: String
    let productDisplayName: String
    let type: String
    let price: Double
    let effectiveAt: Date
    let createdAt: Date
    let source: String?
    let note: String?
}

nonisolated struct ProductPricePushDryRunInput: Sendable {
    let generatedAt: Date
    let sessionSnapshot: ProductPricePushDryRunSessionSnapshot
    let baselineState: ProductPricePushBaselineState
    let localSnapshot: ProductPricePushDryRunLocalSnapshot

    init(
        generatedAt: Date = Date(),
        sessionSnapshot: ProductPricePushDryRunSessionSnapshot,
        baselineState: ProductPricePushBaselineState,
        localSnapshot: ProductPricePushDryRunLocalSnapshot
    ) {
        self.generatedAt = generatedAt
        self.sessionSnapshot = sessionSnapshot
        self.baselineState = baselineState
        self.localSnapshot = localSnapshot
    }
}

nonisolated struct ProductPricePushDryRunFetchOptions: Sendable, Equatable {
    static let defaultBatchSize = 100
    static let defaultPageSize = 500
    static let defaultMaxPagesPerBatch = 20
    static let defaultMaxRemoteRows = 50_000

    let batchSize: Int
    let pageSize: Int
    let maxPagesPerBatch: Int
    let maxRemoteRows: Int

    init(
        batchSize: Int = Self.defaultBatchSize,
        pageSize: Int = Self.defaultPageSize,
        maxPagesPerBatch: Int = Self.defaultMaxPagesPerBatch,
        maxRemoteRows: Int = Self.defaultMaxRemoteRows
    ) {
        self.batchSize = max(1, min(batchSize, 100))
        self.pageSize = max(1, min(pageSize, 1_000))
        self.maxPagesPerBatch = max(1, maxPagesPerBatch)
        self.maxRemoteRows = max(1, maxRemoteRows)
    }
}

nonisolated enum ProductPricePushRemoteDedupeReason: String, Sendable, Equatable {
    case notNeeded
    case complete
    case networkOrPermission
    case pageBudgetExceeded
    case rowBudgetExceeded
    case invalidRemoteRows
    case cancelled
}

nonisolated enum ProductPricePushRemoteDedupeStatus: Sendable, Equatable {
    case notNeeded
    case complete
    case unsafePartialRemoteDedupe(ProductPricePushRemoteDedupeReason)

    var isComplete: Bool {
        switch self {
        case .notNeeded, .complete:
            return true
        case .unsafePartialRemoteDedupe:
            return false
        }
    }
}

nonisolated enum ProductPricePushDryRunLineReason: String, Sendable, Equatable {
    case candidate
    case alreadyPresentRemote
    case conflictSameKeyDifferentPrice
    case localDuplicateSameKey
    case localConflictSameKeyDifferentPrice
    case blockedNoRemoteID
    case excludedInvalidLocal
}

nonisolated struct ProductPricePushDryRunLogicalKey: Sendable, Hashable, Comparable {
    let ownerUserID: UUID
    let productID: UUID
    let type: String
    let effectiveAt: String

    var stableID: String {
        [
            ownerUserID.uuidString.lowercased(),
            productID.uuidString.lowercased(),
            type,
            effectiveAt
        ].joined(separator: "|")
    }

    static func < (lhs: ProductPricePushDryRunLogicalKey, rhs: ProductPricePushDryRunLogicalKey) -> Bool {
        lhs.stableID < rhs.stableID
    }
}

nonisolated struct ProductPricePushDryRunCandidatePayload: Sendable, Equatable {
    let ownerUserID: UUID
    let productID: UUID
    let remoteType: String
    let canonicalPrice: ProductPriceCanonicalAmount
    let effectiveAt: String
    let createdAt: String
    let source: String?
    let note: String?
}

nonisolated struct ProductPricePushDryRunLine: Identifiable, Sendable, Equatable {
    let id: String
    let reason: ProductPricePushDryRunLineReason
    let key: ProductPricePushDryRunLogicalKey?
    let productBarcode: String
    let productDisplayName: String
    let type: String
    let canonicalPrice: ProductPriceCanonicalAmount?
    let effectiveAtCanonical: String?
    let createdAtCanonical: String?
    let source: String?
    let note: String?
    let detail: String?
    let payload: ProductPricePushDryRunCandidatePayload?
}

nonisolated struct ProductPricePushDryRunSummary: Sendable, Equatable {
    let localPriceCount: Int
    let remoteRowsRead: Int
    let remotePagesRead: Int
    let readyCandidates: Int
    let alreadyPresentRemote: Int
    let conflictSameKeyDifferentPrice: Int
    let localDuplicateSameKey: Int
    let localConflictSameKeyDifferentPrice: Int
    let blockedNoRemoteID: Int
    let blockedNoAuth: Int
    let blockedAccountMismatch: Int
    let blockedBaselineMissing: Int
    let blockedBaselineStale: Int
    let blockedBaselinePartial: Int
    let excludedInvalidLocal: Int

    var blockedTotal: Int {
        blockedNoRemoteID
            + blockedNoAuth
            + blockedAccountMismatch
            + blockedBaselineMissing
            + blockedBaselineStale
            + blockedBaselinePartial
    }
}

nonisolated struct ProductPricePushDryRunPlan: Sendable, Equatable {
    let generatedAt: Date
    let sessionSnapshot: ProductPricePushDryRunSessionSnapshot
    let remoteDedupeStatus: ProductPricePushRemoteDedupeStatus
    let summary: ProductPricePushDryRunSummary
    let candidates: [ProductPricePushDryRunLine]
    let alreadyPresentRemote: [ProductPricePushDryRunLine]
    let conflictSameKeyDifferentPrice: [ProductPricePushDryRunLine]
    let localDuplicateSameKey: [ProductPricePushDryRunLine]
    let localConflictSameKeyDifferentPrice: [ProductPricePushDryRunLine]
    let blockedNoRemoteID: [ProductPricePushDryRunLine]
    let excludedInvalidLocal: [ProductPricePushDryRunLine]

    var isRemoteDedupeSafe: Bool {
        remoteDedupeStatus.isComplete
    }
}

nonisolated struct ProductPricePushDryRunLocalStage: Sendable, Equatable {
    let globalBlockSummary: ProductPricePushGlobalBlockSummary
    let representatives: [ProductPricePushDryRunLine]
    let localDuplicateSameKey: [ProductPricePushDryRunLine]
    let localConflictSameKeyDifferentPrice: [ProductPricePushDryRunLine]
    let blockedNoRemoteID: [ProductPricePushDryRunLine]
    let excludedInvalidLocal: [ProductPricePushDryRunLine]

    var productIDsForRemoteDedupe: [UUID] {
        let ids = Set(representatives.compactMap { $0.key?.productID })
        return ids.sorted { $0.uuidString < $1.uuidString }
    }

    var hasGlobalBlock: Bool {
        globalBlockSummary.hasGlobalBlock
    }
}

nonisolated struct ProductPricePushGlobalBlockSummary: Sendable, Equatable {
    let blockedNoAuth: Int
    let blockedAccountMismatch: Int
    let blockedBaselineMissing: Int
    let blockedBaselineStale: Int
    let blockedBaselinePartial: Int

    static let none = ProductPricePushGlobalBlockSummary(
        blockedNoAuth: 0,
        blockedAccountMismatch: 0,
        blockedBaselineMissing: 0,
        blockedBaselineStale: 0,
        blockedBaselinePartial: 0
    )

    var hasGlobalBlock: Bool {
        blockedNoAuth > 0
            || blockedAccountMismatch > 0
            || blockedBaselineMissing > 0
            || blockedBaselineStale > 0
            || blockedBaselinePartial > 0
    }
}

nonisolated struct SupabaseProductPricePushDryRunEngine: Sendable {
    func makeLocalStage(input: ProductPricePushDryRunInput) -> ProductPricePushDryRunLocalStage {
        let globalBlocks = makeGlobalBlocks(input: input)
        guard !globalBlocks.hasGlobalBlock,
              let ownerUserID = input.sessionSnapshot.userID else {
            return ProductPricePushDryRunLocalStage(
                globalBlockSummary: globalBlocks,
                representatives: [],
                localDuplicateSameKey: [],
                localConflictSameKeyDifferentPrice: [],
                blockedNoRemoteID: [],
                excludedInvalidLocal: []
            )
        }

        var validByKey: [ProductPricePushDryRunLogicalKey: [ProductPricePushDryRunLine]] = [:]
        var blockedNoRemoteID: [ProductPricePushDryRunLine] = []
        var excludedInvalidLocal: [ProductPricePushDryRunLine] = []

        for price in input.localSnapshot.prices {
            guard let productID = price.productRemoteID else {
                blockedNoRemoteID.append(blockedLine(price: price, reason: .blockedNoRemoteID, detail: "missing product remoteID"))
                continue
            }

            guard let type = SupabasePullPreviewNormalizer.normalizedPriceType(price.type),
                  let canonicalPrice = PriceCanonicalizer.canonicalAmount(from: price.price) else {
                excludedInvalidLocal.append(blockedLine(price: price, reason: .excludedInvalidLocal, detail: "invalid type or price"))
                continue
            }

            let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt)
            let createdAt = ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.createdAt)
            let key = ProductPricePushDryRunLogicalKey(
                ownerUserID: ownerUserID,
                productID: productID,
                type: type,
                effectiveAt: effectiveAt
            )
            let payload = ProductPricePushDryRunCandidatePayload(
                ownerUserID: ownerUserID,
                productID: productID,
                remoteType: remoteType(from: type),
                canonicalPrice: canonicalPrice,
                effectiveAt: effectiveAt,
                createdAt: createdAt,
                source: sanitized(price.source),
                note: sanitized(price.note)
            )
            validByKey[key, default: []].append(
                line(
                    price: price,
                    reason: .candidate,
                    key: key,
                    canonicalPrice: canonicalPrice,
                    effectiveAtCanonical: effectiveAt,
                    createdAtCanonical: createdAt,
                    payload: payload
                )
            )
        }

        var representatives: [ProductPricePushDryRunLine] = []
        var localDuplicateSameKey: [ProductPricePushDryRunLine] = []
        var localConflictSameKeyDifferentPrice: [ProductPricePushDryRunLine] = []

        for key in validByKey.keys.sorted() {
            let lines = sortLines(validByKey[key] ?? [])
            let priceValues = Set(lines.compactMap { $0.canonicalPrice })

            if lines.count > 1, priceValues.count > 1 {
                localConflictSameKeyDifferentPrice.append(
                    contentsOf: lines.map { rewrite($0, reason: .localConflictSameKeyDifferentPrice) }
                )
                continue
            }

            if lines.count > 1 {
                localDuplicateSameKey.append(
                    contentsOf: lines.map { rewrite($0, reason: .localDuplicateSameKey) }
                )
            }

            if let representative = lines.first {
                representatives.append(representative)
            }
        }

        return ProductPricePushDryRunLocalStage(
            globalBlockSummary: globalBlocks,
            representatives: sortLines(representatives),
            localDuplicateSameKey: sortLines(localDuplicateSameKey),
            localConflictSameKeyDifferentPrice: sortLines(localConflictSameKeyDifferentPrice),
            blockedNoRemoteID: sortLines(blockedNoRemoteID),
            excludedInvalidLocal: sortLines(excludedInvalidLocal)
        )
    }

    func makePlan(
        input: ProductPricePushDryRunInput,
        remoteRows: [RemoteInventoryProductPriceRow],
        remoteDedupeStatus: ProductPricePushRemoteDedupeStatus,
        remoteRowsRead: Int,
        remotePagesRead: Int
    ) -> ProductPricePushDryRunPlan {
        let localStage = makeLocalStage(input: input)
        return makePlan(
            input: input,
            localStage: localStage,
            remoteRows: remoteRows,
            remoteDedupeStatus: remoteDedupeStatus,
            remoteRowsRead: remoteRowsRead,
            remotePagesRead: remotePagesRead
        )
    }

    func makePlan(
        input: ProductPricePushDryRunInput,
        localStage: ProductPricePushDryRunLocalStage,
        remoteRows: [RemoteInventoryProductPriceRow],
        remoteDedupeStatus: ProductPricePushRemoteDedupeStatus,
        remoteRowsRead: Int,
        remotePagesRead: Int
    ) -> ProductPricePushDryRunPlan {
        let remoteLookup = makeRemoteLookup(
            ownerUserID: input.sessionSnapshot.userID,
            remoteRows: remoteRows
        )
        let effectiveRemoteStatus = remoteLookup.invalidRemoteRows
            ? .unsafePartialRemoteDedupe(.invalidRemoteRows)
            : remoteDedupeStatus

        var candidates: [ProductPricePushDryRunLine] = []
        var alreadyPresentRemote: [ProductPricePushDryRunLine] = []
        var conflictSameKeyDifferentPrice: [ProductPricePushDryRunLine] = []

        if effectiveRemoteStatus.isComplete {
            for line in localStage.representatives {
                guard let key = line.key,
                      let canonicalPrice = line.canonicalPrice else {
                    continue
                }

                if let remotePrices = remoteLookup.pricesByKey[key] {
                    if remotePrices.count == 1, remotePrices.contains(canonicalPrice) {
                        alreadyPresentRemote.append(rewrite(line, reason: .alreadyPresentRemote))
                    } else {
                        conflictSameKeyDifferentPrice.append(rewrite(line, reason: .conflictSameKeyDifferentPrice))
                    }
                } else {
                    candidates.append(line)
                }
            }
        }

        let sortedCandidates = sortLines(candidates)
        let sortedAlreadyPresent = sortLines(alreadyPresentRemote)
        let sortedRemoteConflicts = sortLines(conflictSameKeyDifferentPrice)
        let summary = ProductPricePushDryRunSummary(
            localPriceCount: input.localSnapshot.prices.count,
            remoteRowsRead: remoteRowsRead,
            remotePagesRead: remotePagesRead,
            readyCandidates: effectiveRemoteStatus.isComplete ? sortedCandidates.count : 0,
            alreadyPresentRemote: sortedAlreadyPresent.count,
            conflictSameKeyDifferentPrice: sortedRemoteConflicts.count,
            localDuplicateSameKey: localStage.localDuplicateSameKey.count,
            localConflictSameKeyDifferentPrice: localStage.localConflictSameKeyDifferentPrice.count,
            blockedNoRemoteID: localStage.blockedNoRemoteID.count,
            blockedNoAuth: localStage.globalBlockSummary.blockedNoAuth,
            blockedAccountMismatch: localStage.globalBlockSummary.blockedAccountMismatch,
            blockedBaselineMissing: localStage.globalBlockSummary.blockedBaselineMissing,
            blockedBaselineStale: localStage.globalBlockSummary.blockedBaselineStale,
            blockedBaselinePartial: localStage.globalBlockSummary.blockedBaselinePartial,
            excludedInvalidLocal: localStage.excludedInvalidLocal.count
        )

        return ProductPricePushDryRunPlan(
            generatedAt: input.generatedAt,
            sessionSnapshot: input.sessionSnapshot,
            remoteDedupeStatus: effectiveRemoteStatus,
            summary: summary,
            candidates: sortedCandidates,
            alreadyPresentRemote: sortedAlreadyPresent,
            conflictSameKeyDifferentPrice: sortedRemoteConflicts,
            localDuplicateSameKey: localStage.localDuplicateSameKey,
            localConflictSameKeyDifferentPrice: localStage.localConflictSameKeyDifferentPrice,
            blockedNoRemoteID: localStage.blockedNoRemoteID,
            excludedInvalidLocal: localStage.excludedInvalidLocal
        )
    }

    private func makeGlobalBlocks(input: ProductPricePushDryRunInput) -> ProductPricePushGlobalBlockSummary {
        if input.sessionSnapshot.userID == nil {
            return ProductPricePushGlobalBlockSummary(
                blockedNoAuth: 1,
                blockedAccountMismatch: 0,
                blockedBaselineMissing: 0,
                blockedBaselineStale: 0,
                blockedBaselinePartial: 0
            )
        }

        if input.sessionSnapshot.userID != input.sessionSnapshot.lastLinkedUserID {
            return ProductPricePushGlobalBlockSummary(
                blockedNoAuth: 0,
                blockedAccountMismatch: 1,
                blockedBaselineMissing: 0,
                blockedBaselineStale: 0,
                blockedBaselinePartial: 0
            )
        }

        switch input.baselineState {
        case .available(let baseline):
            guard baseline.isValid else {
                let hasPartial = baseline.invalidationReasons.contains(.partialPull)
                    || baseline.invalidationReasons.contains(.sourceErrors)
                return ProductPricePushGlobalBlockSummary(
                    blockedNoAuth: 0,
                    blockedAccountMismatch: 0,
                    blockedBaselineMissing: 0,
                    blockedBaselineStale: hasPartial ? 0 : 1,
                    blockedBaselinePartial: hasPartial ? 1 : 0
                )
            }
            return .none
        case .missing:
            return ProductPricePushGlobalBlockSummary(
                blockedNoAuth: 0,
                blockedAccountMismatch: 0,
                blockedBaselineMissing: 1,
                blockedBaselineStale: 0,
                blockedBaselinePartial: 0
            )
        case .accountMismatch:
            return ProductPricePushGlobalBlockSummary(
                blockedNoAuth: 0,
                blockedAccountMismatch: 1,
                blockedBaselineMissing: 0,
                blockedBaselineStale: 0,
                blockedBaselinePartial: 0
            )
        case .stale:
            return ProductPricePushGlobalBlockSummary(
                blockedNoAuth: 0,
                blockedAccountMismatch: 0,
                blockedBaselineMissing: 0,
                blockedBaselineStale: 1,
                blockedBaselinePartial: 0
            )
        case .partial:
            return ProductPricePushGlobalBlockSummary(
                blockedNoAuth: 0,
                blockedAccountMismatch: 0,
                blockedBaselineMissing: 0,
                blockedBaselineStale: 0,
                blockedBaselinePartial: 1
            )
        }
    }

    private func makeRemoteLookup(
        ownerUserID: UUID?,
        remoteRows: [RemoteInventoryProductPriceRow]
    ) -> (pricesByKey: [ProductPricePushDryRunLogicalKey: Set<ProductPriceCanonicalAmount>], invalidRemoteRows: Bool) {
        guard let ownerUserID else {
            return ([:], false)
        }

        var pricesByKey: [ProductPricePushDryRunLogicalKey: Set<ProductPriceCanonicalAmount>] = [:]
        var invalidRemoteRows = false

        for row in remoteRows {
            guard row.ownerUserID == ownerUserID else {
                invalidRemoteRows = true
                continue
            }

            guard let type = SupabasePullPreviewNormalizer.normalizedPriceType(row.type),
                  let canonicalPrice = PriceCanonicalizer.canonicalAmount(from: row.price),
                  let effectiveAtDate = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.effectiveAt) else {
                invalidRemoteRows = true
                continue
            }

            let key = ProductPricePushDryRunLogicalKey(
                ownerUserID: ownerUserID,
                productID: row.productID,
                type: type,
                effectiveAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(from: effectiveAtDate)
            )
            let existingPrices = pricesByKey[key] ?? []
            pricesByKey[key] = existingPrices.union([canonicalPrice])
        }

        return (pricesByKey, invalidRemoteRows)
    }

    private func blockedLine(
        price: ProductPricePushDryRunLocalPrice,
        reason: ProductPricePushDryRunLineReason,
        detail: String
    ) -> ProductPricePushDryRunLine {
        ProductPricePushDryRunLine(
            id: "\(reason.rawValue)|\(price.localID)",
            reason: reason,
            key: nil,
            productBarcode: price.productBarcode,
            productDisplayName: price.productDisplayName,
            type: price.type,
            canonicalPrice: PriceCanonicalizer.canonicalAmount(from: price.price),
            effectiveAtCanonical: ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt),
            createdAtCanonical: ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.createdAt),
            source: sanitized(price.source),
            note: sanitized(price.note),
            detail: detail,
            payload: nil
        )
    }

    private func line(
        price: ProductPricePushDryRunLocalPrice,
        reason: ProductPricePushDryRunLineReason,
        key: ProductPricePushDryRunLogicalKey,
        canonicalPrice: ProductPriceCanonicalAmount,
        effectiveAtCanonical: String,
        createdAtCanonical: String,
        payload: ProductPricePushDryRunCandidatePayload
    ) -> ProductPricePushDryRunLine {
        ProductPricePushDryRunLine(
            id: "\(reason.rawValue)|\(key.stableID)|\(price.localID)",
            reason: reason,
            key: key,
            productBarcode: price.productBarcode,
            productDisplayName: price.productDisplayName,
            type: key.type,
            canonicalPrice: canonicalPrice,
            effectiveAtCanonical: effectiveAtCanonical,
            createdAtCanonical: createdAtCanonical,
            source: payload.source,
            note: payload.note,
            detail: nil,
            payload: payload
        )
    }

    private func rewrite(
        _ line: ProductPricePushDryRunLine,
        reason: ProductPricePushDryRunLineReason
    ) -> ProductPricePushDryRunLine {
        ProductPricePushDryRunLine(
            id: "\(reason.rawValue)|\(line.key?.stableID ?? "no-key")|\(line.id)",
            reason: reason,
            key: line.key,
            productBarcode: line.productBarcode,
            productDisplayName: line.productDisplayName,
            type: line.type,
            canonicalPrice: line.canonicalPrice,
            effectiveAtCanonical: line.effectiveAtCanonical,
            createdAtCanonical: line.createdAtCanonical,
            source: line.source,
            note: line.note,
            detail: line.detail,
            payload: line.payload
        )
    }

    private func sortLines(_ lines: [ProductPricePushDryRunLine]) -> [ProductPricePushDryRunLine] {
        lines.sorted {
            (
                $0.productDisplayName,
                $0.productBarcode,
                $0.type,
                $0.effectiveAtCanonical ?? "",
                $0.createdAtCanonical ?? "",
                $0.id
            ) < (
                $1.productDisplayName,
                $1.productBarcode,
                $1.type,
                $1.effectiveAtCanonical ?? "",
                $1.createdAtCanonical ?? "",
                $1.id
            )
        }
    }

    private func sanitized(_ value: String?) -> String? {
        SupabasePullPreviewNormalizer.semanticString(value)
    }

    private func remoteType(from normalizedType: String) -> String {
        normalizedType.uppercased()
    }
}

nonisolated enum ProductPricePushDryRunError: Error, Sendable, Equatable {
    case localSnapshotFailed(message: String?)
}

@MainActor
struct SupabaseProductPricePushDryRunService {
    private let fetcher: any SupabaseProductPricePushDryRunRemoteFetching
    private let fetchOptions: ProductPricePushDryRunFetchOptions
    private let engine: SupabaseProductPricePushDryRunEngine
    private let baselineReader: SupabaseCatalogBaselineReader

    init(
        fetcher: any SupabaseProductPricePushDryRunRemoteFetching,
        fetchOptions: ProductPricePushDryRunFetchOptions = ProductPricePushDryRunFetchOptions(),
        engine: SupabaseProductPricePushDryRunEngine = SupabaseProductPricePushDryRunEngine(),
        baselineReader: SupabaseCatalogBaselineReader = SupabaseCatalogBaselineReader()
    ) {
        self.fetcher = fetcher
        self.fetchOptions = fetchOptions
        self.engine = engine
        self.baselineReader = baselineReader
    }

    func loadDryRun(
        context: ModelContext,
        sessionSnapshot: ProductPricePushDryRunSessionSnapshot
    ) async throws -> ProductPricePushDryRunPlan {
        let baselineState = try readBaselineState(context: context, sessionSnapshot: sessionSnapshot)
        let localSnapshot: ProductPricePushDryRunLocalSnapshot
        do {
            localSnapshot = try makeLocalSnapshot(context: context)
        } catch {
            throw ProductPricePushDryRunError.localSnapshotFailed(message: String(describing: error))
        }

        let input = ProductPricePushDryRunInput(
            sessionSnapshot: sessionSnapshot,
            baselineState: baselineState,
            localSnapshot: localSnapshot
        )
        let localStage = engine.makeLocalStage(input: input)

        guard !localStage.hasGlobalBlock else {
            return engine.makePlan(
                input: input,
                localStage: localStage,
                remoteRows: [],
                remoteDedupeStatus: .notNeeded,
                remoteRowsRead: 0,
                remotePagesRead: 0
            )
        }

        let productIDs = localStage.productIDsForRemoteDedupe
        guard let ownerUserID = sessionSnapshot.userID, !productIDs.isEmpty else {
            return engine.makePlan(
                input: input,
                localStage: localStage,
                remoteRows: [],
                remoteDedupeStatus: .notNeeded,
                remoteRowsRead: 0,
                remotePagesRead: 0
            )
        }

        let fetchResult = await fetchRemoteRows(ownerUserID: ownerUserID, productIDs: productIDs)
        return engine.makePlan(
            input: input,
            localStage: localStage,
            remoteRows: fetchResult.rows,
            remoteDedupeStatus: fetchResult.status,
            remoteRowsRead: fetchResult.rows.count,
            remotePagesRead: fetchResult.pagesRead
        )
    }

    private func readBaselineState(
        context: ModelContext,
        sessionSnapshot: ProductPricePushDryRunSessionSnapshot
    ) throws -> ProductPricePushBaselineState {
        guard let userID = sessionSnapshot.userID else {
            return .missing
        }

        switch try baselineReader.readManualPushBaseline(context: context, ownerUserUUID: userID) {
        case .available(let snapshot):
            return .available(snapshot.baseline)
        case .missing:
            return .missing
        case .accountMismatch:
            return .accountMismatch
        case .staleSchema:
            return .stale
        case .incomplete:
            return .partial
        }
    }

    private func fetchRemoteRows(
        ownerUserID: UUID,
        productIDs: [UUID]
    ) async -> (rows: [RemoteInventoryProductPriceRow], status: ProductPricePushRemoteDedupeStatus, pagesRead: Int) {
        var rows: [RemoteInventoryProductPriceRow] = []
        var pagesRead = 0

        for batchStart in stride(from: 0, to: productIDs.count, by: fetchOptions.batchSize) {
            let batchEnd = min(batchStart + fetchOptions.batchSize, productIDs.count)
            let batch = Array(productIDs[batchStart..<batchEnd])
            var pageIndex = 0
            var offset = 0
            var didCompleteBatch = false

            while pageIndex < fetchOptions.maxPagesPerBatch {
                if rows.count >= fetchOptions.maxRemoteRows {
                    return (rows, .unsafePartialRemoteDedupe(.rowBudgetExceeded), pagesRead)
                }

                let remainingRows = fetchOptions.maxRemoteRows - rows.count
                let currentPageSize = min(fetchOptions.pageSize, remainingRows)

                do {
                    try Task.checkCancellation()
                    let page = try await fetcher.fetchProductPricesForPushDryRunDedupePage(
                        ownerUserID: ownerUserID,
                        productIDs: batch,
                        from: offset,
                        to: offset + currentPageSize - 1
                    )
                    try Task.checkCancellation()

                    pagesRead += 1
                    pageIndex += 1

                    if page.count > currentPageSize {
                        return (rows, .unsafePartialRemoteDedupe(.rowBudgetExceeded), pagesRead)
                    }

                    rows.append(contentsOf: page)

                    if page.count < currentPageSize {
                        didCompleteBatch = true
                        break
                    }

                    offset += currentPageSize
                } catch is CancellationError {
                    return (rows, .unsafePartialRemoteDedupe(.cancelled), pagesRead)
                } catch {
                    return (rows, .unsafePartialRemoteDedupe(.networkOrPermission), pagesRead)
                }
            }

            if !didCompleteBatch {
                return (rows, .unsafePartialRemoteDedupe(.pageBudgetExceeded), pagesRead)
            }
        }

        return (rows, .complete, pagesRead)
    }

    private func makeLocalSnapshot(context: ModelContext) throws -> ProductPricePushDryRunLocalSnapshot {
        let products = try context.fetch(
            FetchDescriptor<Product>(
                sortBy: [SortDescriptor(\Product.barcode)]
            )
        )
        let prices = try context.fetch(
            FetchDescriptor<ProductPrice>(
                sortBy: [
                    SortDescriptor(\ProductPrice.effectiveAt),
                    SortDescriptor(\ProductPrice.createdAt)
                ]
            )
        )

        let localProducts = products.enumerated().map { index, product in
            ProductPricePushDryRunLocalProduct(
                localID: "product-\(index)-\(product.barcode)",
                remoteID: product.remoteID,
                barcode: product.barcode,
                productName: product.productName
            )
        }

        let localPrices = prices.enumerated().compactMap { index, price -> ProductPricePushDryRunLocalPrice? in
            guard let product = price.product else {
                return nil
            }

            return ProductPricePushDryRunLocalPrice(
                localID: "price-\(index)-\(product.barcode)-\(price.type.rawValue)",
                productLocalID: product.barcode,
                productRemoteID: product.remoteID,
                productBarcode: product.barcode,
                productDisplayName: displayName(for: product),
                type: price.type.rawValue,
                price: price.price,
                effectiveAt: price.effectiveAt,
                createdAt: price.createdAt,
                source: price.source,
                note: price.note
            )
        }

        return ProductPricePushDryRunLocalSnapshot(products: localProducts, prices: localPrices)
    }

    private func displayName(for product: Product) -> String {
        let raw = SupabasePullPreviewNormalizer.semanticString(product.productName)
            ?? SupabasePullPreviewNormalizer.semanticString(product.secondProductName)
            ?? SupabasePullPreviewNormalizer.semanticString(product.itemNumber)
            ?? SupabasePullPreviewNormalizer.semanticString(product.barcode)
            ?? product.remoteID?.uuidString
            ?? "local product"

        return ProductPricePreviewLocalLookupBuilder.truncated(raw, maxLength: 32)
    }
}
