#if DEBUG
import Foundation
import SwiftData

nonisolated struct SupabaseTask088RemoteSeed: Sendable {
    let ownerUserID: UUID
    let supplier: RemoteInventorySupplierRow
    let category: RemoteInventoryCategoryRow
    let product: RemoteInventoryProductRow
}

nonisolated enum SupabaseTask088ProductPriceSmokeError: Error, Sendable, Equatable {
    case remotePriceCollision(count: Int)
    case firstPlanUnexpected(String)
    case pushVerificationFailed(String)
    case identityNotLinked(expected: Int, actual: Int)
    case reloadIdentityMismatch(expected: Int, actual: Int)
    case secondPlanUnexpected(String)
    case duplicateRemoteLogicalKeys(count: Int)
    case localSaveFailed

    var safeMessage: String {
        switch self {
        case .remotePriceCollision(let count):
            return "TASK088 remote price collision count=\(count)"
        case .firstPlanUnexpected(let detail):
            return "TASK088 first plan unexpected: \(detail)"
        case .pushVerificationFailed(let detail):
            return "TASK088 push verification failed: \(detail)"
        case .identityNotLinked(let expected, let actual):
            return "TASK088 identity link mismatch expected=\(expected) actual=\(actual)"
        case .reloadIdentityMismatch(let expected, let actual):
            return "TASK088 reload identity mismatch expected=\(expected) actual=\(actual)"
        case .secondPlanUnexpected(let detail):
            return "TASK088 second plan unexpected: \(detail)"
        case .duplicateRemoteLogicalKeys(let count):
            return "TASK088 duplicate logical keys count=\(count)"
        case .localSaveFailed:
            return "TASK088 local save failed"
        }
    }
}

nonisolated struct SupabaseTask088ProductPriceSmokeResult: Sendable, Equatable {
    let ownerUserIDHash: String
    let firstReadyCandidates: Int
    let insertedCount: Int
    let linkedRemoteIDs: Int
    let reloadedLinkedRemoteIDs: Int
    let secondReadyCandidates: Int
    let remoteRowsBefore: Int
    let remoteRowsAfterFirstPush: Int
    let remoteRowsAfterSecondPush: Int
    let duplicateRemoteLogicalKeys: Int
    let androidExpectedLastPurchase: Double
    let androidExpectedPrevPurchase: Double
    let androidExpectedLastRetail: Double
    let androidExpectedPrevRetail: Double

    var privacySafeSummary: String {
        [
            "ownerHash=\(ownerUserIDHash)",
            "firstReady=\(firstReadyCandidates)",
            "inserted=\(insertedCount)",
            "linked=\(linkedRemoteIDs)",
            "reloadLinked=\(reloadedLinkedRemoteIDs)",
            "secondReady=\(secondReadyCandidates)",
            "remoteBefore=\(remoteRowsBefore)",
            "remoteAfterFirst=\(remoteRowsAfterFirstPush)",
            "remoteAfterSecond=\(remoteRowsAfterSecondPush)",
            "duplicateKeys=\(duplicateRemoteLogicalKeys)",
            "androidSummary=purchase:\(androidExpectedPrevPurchase)->\(androidExpectedLastPurchase),retail:\(androidExpectedPrevRetail)->\(androidExpectedLastRetail)"
        ].joined(separator: " ")
    }
}

@MainActor
struct SupabaseTask088ProductPriceSmokeService {
    private static let expectedPriceCount = 4
    private static let supplierName = "TASK088_SUPPLIER"
    private static let categoryName = "TASK088_CATEGORY"
    private static let productBarcode = "TASK088_BAR_PRICE"
    private static let productName = "TASK088_PRODUCT"

    private let inventoryService: SupabaseInventoryService

    init(inventoryService: SupabaseInventoryService) {
        self.inventoryService = inventoryService
    }

    func run() async throws -> SupabaseTask088ProductPriceSmokeResult {
        let seed = try await inventoryService.ensureTask088RemoteSeed()
        let remoteBefore = try await inventoryService.fetchTask088ProductPriceRows(
            ownerUserID: seed.ownerUserID,
            productID: seed.product.id
        )
        guard remoteBefore.isEmpty else {
            throw SupabaseTask088ProductPriceSmokeError.remotePriceCollision(count: remoteBefore.count)
        }

        let container = try makeContainer()
        let context = ModelContext(container)
        try seedLocalFixture(seed: seed, context: context)
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: seed.ownerUserID
        )

        let firstPlan = try await makePushPlan(context: context, ownerUserID: seed.ownerUserID)
        guard firstPlan.summary.localPriceCount == Self.expectedPriceCount,
              firstPlan.summary.readyCandidates == Self.expectedPriceCount,
              firstPlan.summary.blockedTotal == 0,
              firstPlan.summary.conflictSameKeyDifferentPrice == 0,
              firstPlan.summary.localConflictSameKeyDifferentPrice == 0 else {
            throw SupabaseTask088ProductPriceSmokeError.firstPlanUnexpected(summary(firstPlan))
        }

        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: firstPlan)
        let pushResult = try await SupabaseProductPriceManualPushService(remote: inventoryService).push(snapshot: snapshot)
        guard pushResult.insertedCount == Self.expectedPriceCount,
              pushResult.isVerifiedSuccess else {
            throw SupabaseTask088ProductPriceSmokeError.pushVerificationFailed(verificationSummary(pushResult))
        }

        let linked = try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads(
            snapshot.payloads,
            context: context
        )
        guard linked == Self.expectedPriceCount else {
            throw SupabaseTask088ProductPriceSmokeError.identityNotLinked(
                expected: Self.expectedPriceCount,
                actual: linked
            )
        }

        let afterFirst = try await inventoryService.fetchTask088ProductPriceRows(
            ownerUserID: seed.ownerUserID,
            productID: seed.product.id
        )
        let duplicateAfterFirst = duplicateLogicalKeyCount(afterFirst)
        guard afterFirst.count == Self.expectedPriceCount,
              duplicateAfterFirst == 0 else {
            throw SupabaseTask088ProductPriceSmokeError.duplicateRemoteLogicalKeys(count: duplicateAfterFirst)
        }

        let reloadContext = ModelContext(container)
        let reloadedLinked = try countReloadedLinkedPrices(context: reloadContext)
        guard reloadedLinked == Self.expectedPriceCount else {
            throw SupabaseTask088ProductPriceSmokeError.reloadIdentityMismatch(
                expected: Self.expectedPriceCount,
                actual: reloadedLinked
            )
        }

        let secondPlan = try await makePushPlan(context: reloadContext, ownerUserID: seed.ownerUserID)
        guard secondPlan.summary.localPriceCount == Self.expectedPriceCount,
              secondPlan.summary.readyCandidates == 0,
              secondPlan.summary.blockedTotal == 0 else {
            throw SupabaseTask088ProductPriceSmokeError.secondPlanUnexpected(summary(secondPlan))
        }

        let afterSecond = try await inventoryService.fetchTask088ProductPriceRows(
            ownerUserID: seed.ownerUserID,
            productID: seed.product.id
        )
        let duplicateAfterSecond = duplicateLogicalKeyCount(afterSecond)
        guard afterSecond.count == afterFirst.count,
              duplicateAfterSecond == 0 else {
            throw SupabaseTask088ProductPriceSmokeError.duplicateRemoteLogicalKeys(count: duplicateAfterSecond)
        }

        return SupabaseTask088ProductPriceSmokeResult(
            ownerUserIDHash: shortHash(seed.ownerUserID.uuidString),
            firstReadyCandidates: firstPlan.summary.readyCandidates,
            insertedCount: pushResult.insertedCount,
            linkedRemoteIDs: linked,
            reloadedLinkedRemoteIDs: reloadedLinked,
            secondReadyCandidates: secondPlan.summary.readyCandidates,
            remoteRowsBefore: remoteBefore.count,
            remoteRowsAfterFirstPush: afterFirst.count,
            remoteRowsAfterSecondPush: afterSecond.count,
            duplicateRemoteLogicalKeys: duplicateAfterSecond,
            androidExpectedLastPurchase: Self.priceSpecs.filter { $0.type == .purchase }.last?.price ?? 0,
            androidExpectedPrevPurchase: Self.priceSpecs.filter { $0.type == .purchase }.first?.price ?? 0,
            androidExpectedLastRetail: Self.priceSpecs.filter { $0.type == .retail }.last?.price ?? 0,
            androidExpectedPrevRetail: Self.priceSpecs.filter { $0.type == .retail }.first?.price ?? 0
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func seedLocalFixture(seed: SupabaseTask088RemoteSeed, context: ModelContext) throws {
        let supplier = Supplier(
            name: Self.supplierName,
            remoteID: seed.supplier.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(seed.supplier.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(seed.supplier.deletedAt)
        )
        let category = ProductCategory(
            name: Self.categoryName,
            remoteID: seed.category.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(seed.category.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(seed.category.deletedAt)
        )
        let product = Product(
            barcode: Self.productBarcode,
            remoteID: seed.product.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(seed.product.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(seed.product.deletedAt),
            productName: Self.productName,
            purchasePrice: 122.20,
            retailPrice: 244.40,
            stockQuantity: 0,
            supplier: supplier,
            category: category
        )

        context.insert(supplier)
        context.insert(category)
        context.insert(product)
        for spec in Self.priceSpecs {
            context.insert(ProductPrice(
                type: spec.type,
                price: spec.price,
                effectiveAt: spec.effectiveAt,
                source: "TASK088_\(spec.type.rawValue.uppercased())",
                note: spec.note,
                createdAt: spec.effectiveAt,
                product: product
            ))
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw SupabaseTask088ProductPriceSmokeError.localSaveFailed
        }
    }

    private func makePushPlan(context: ModelContext, ownerUserID: UUID) async throws -> ProductPricePushDryRunPlan {
        try await SupabaseProductPricePushDryRunService(fetcher: inventoryService).loadDryRun(
            context: context,
            sessionSnapshot: ProductPricePushDryRunSessionSnapshot(
                userID: ownerUserID,
                lastLinkedUserID: ownerUserID
            )
        )
    }

    private func countReloadedLinkedPrices(context: ModelContext) throws -> Int {
        let prices = try context.fetch(
            FetchDescriptor<ProductPrice>(
                sortBy: [
                    SortDescriptor(\ProductPrice.effectiveAt),
                    SortDescriptor(\ProductPrice.createdAt)
                ]
            )
        )
        return prices.filter { price in
            price.product?.barcode == Self.productBarcode && price.remoteID != nil
        }.count
    }

    private func duplicateLogicalKeyCount(_ rows: [RemoteInventoryProductPriceRow]) -> Int {
        var seen = Set<String>()
        var duplicates = 0
        for row in rows {
            let key = [
                row.productID.uuidString.lowercased(),
                row.type.uppercased(),
                row.effectiveAt
            ].joined(separator: "|")
            if !seen.insert(key).inserted {
                duplicates += 1
            }
        }
        return duplicates
    }

    private func summary(_ plan: ProductPricePushDryRunPlan) -> String {
        [
            "local=\(plan.summary.localPriceCount)",
            "ready=\(plan.summary.readyCandidates)",
            "blocked=\(plan.summary.blockedTotal)",
            "remoteConflict=\(plan.summary.conflictSameKeyDifferentPrice)",
            "localConflict=\(plan.summary.localConflictSameKeyDifferentPrice)",
            "dedupeSafe=\(plan.isRemoteDedupeSafe)"
        ].joined(separator: " ")
    }

    private func verificationSummary(_ result: ProductPriceManualPushResult) -> String {
        switch result.verification {
        case .exactMatch(let verifiedCount):
            return "exact=\(verifiedCount)"
        case .missingRows(let rows):
            return "missing=\(rows.count)"
        case .mismatchedRows(let rows):
            return "mismatch=\(rows.count)"
        case .unknown:
            return "unknown"
        }
    }

    private static let priceSpecs: [PriceSpec] = [
        PriceSpec(type: .purchase, price: 111.10, effectiveAt: fixedDate("2026-01-10 10:00:00"), note: "TASK088_PURCHASE_PREV"),
        PriceSpec(type: .purchase, price: 122.20, effectiveAt: fixedDate("2026-01-20 10:00:00"), note: "TASK088_PURCHASE_LAST"),
        PriceSpec(type: .retail, price: 211.10, effectiveAt: fixedDate("2026-01-10 10:00:00"), note: "TASK088_RETAIL_PREV"),
        PriceSpec(type: .retail, price: 244.40, effectiveAt: fixedDate("2026-01-20 10:00:00"), note: "TASK088_RETAIL_LAST")
    ]

    private struct PriceSpec {
        let type: PriceType
        let price: Double
        let effectiveAt: Date
        let note: String
    }

    private static func fixedDate(_ value: String) -> Date {
        guard let date = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: value) else {
            preconditionFailure("Invalid TASK088 fixture date")
        }
        return date
    }

    private func shortHash(_ value: String) -> String {
        String(value.utf8.reduce(UInt32(2166136261)) { hash, byte in
            (hash ^ UInt32(byte)) &* 16777619
        }, radix: 16)
    }
}
#endif
