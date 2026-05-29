import Foundation
import SwiftData

enum CatalogGeneratedProductPriceSyncEventRecorderError: Error, Equatable {
    case incompleteReadBack(expectedAtLeast: Int, actual: Int)
}

@MainActor
struct CatalogGeneratedProductPriceSyncEventRecorder {
    private let context: ModelContext
    private let remote: any SupabaseProductPricePushDryRunRemoteFetching
    private let maxAttempts: Int
    private let retryDelayNanoseconds: UInt64

    init(
        context: ModelContext,
        remote: any SupabaseProductPricePushDryRunRemoteFetching,
        maxAttempts: Int = 4,
        retryDelayNanoseconds: UInt64 = 250_000_000
    ) {
        self.context = context
        self.remote = remote
        self.maxAttempts = max(1, maxAttempts)
        self.retryDelayNanoseconds = retryDelayNanoseconds
    }

    func recordIfNeeded(
        catalogResult: SupabaseManualPushResult,
        ownerUserID: UUID,
        planFingerprint: String
    ) async throws -> SyncEventOutboxProducerResult {
        let productIDs = catalogResult.touchedIDs.products
        guard !productIDs.isEmpty else {
            return SyncEventOutboxProducerResult(kind: .skippedNoOp)
        }

        var rows: [RemoteInventoryProductPriceRow] = []

        for attempt in 1...maxAttempts {
            rows = try await fetchRows(ownerUserID: ownerUserID, productIDs: productIDs)
            if rows.isEmpty == false {
                break
            }
            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }
        }

        guard rows.isEmpty == false else {
            return SyncEventOutboxProducerResult(kind: .skippedNoOp)
        }

        return SyncEventOutboxEnqueueService(context: context).enqueue(
            .catalogGeneratedProductPrices(
                priceIDs: rows.map(\.id),
                productIDs: Array(productIDs),
                ownerUserID: ownerUserID,
                currentOwnerUserID: ownerUserID,
                planFingerprint: planFingerprint
            )
        )
    }

    private func fetchRows(
        ownerUserID: UUID,
        productIDs: Set<UUID>
    ) async throws -> [RemoteInventoryProductPriceRow] {
        let rows = try await remote.fetchProductPricesForPushDryRunDedupePage(
            ownerUserID: ownerUserID,
            productIDs: Array(productIDs),
            from: 0,
            to: 999
        )
        return Array(Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values)
            .sorted { lhs, rhs in
                if lhs.productID != rhs.productID {
                    return lhs.productID.uuidString < rhs.productID.uuidString
                }
                if lhs.type != rhs.type {
                    return lhs.type < rhs.type
                }
                if lhs.effectiveAt != rhs.effectiveAt {
                    return lhs.effectiveAt < rhs.effectiveAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }
}
