import Foundation
import SwiftData

nonisolated struct ProductPriceApplySessionSnapshot: Sendable, Equatable {
    let userID: UUID
}

nonisolated struct ProductPriceApplySourceState: Sendable, Equatable {
    let partial: Bool
    let truncated: Bool
    let sourceError: String?

    init(partial: Bool = false, truncated: Bool = false, sourceError: String? = nil) {
        self.partial = partial
        self.truncated = truncated
        self.sourceError = SupabasePullPreviewNormalizer.semanticString(sourceError)
    }
}

nonisolated struct ProductPriceApplyLocalSnapshot: Sendable {
    let products: [ProductPriceApplyLocalProduct]
    let prices: [ProductPriceApplyLocalPrice]

    init(products: [ProductPriceApplyLocalProduct], prices: [ProductPriceApplyLocalPrice]) {
        self.products = products
        self.prices = prices
    }
}

nonisolated struct ProductPriceApplyLocalProduct: Sendable, Equatable {
    let remoteID: UUID?
    let barcode: String
    let productName: String?
    let purchasePrice: Double?
    let retailPrice: Double?

    init(
        remoteID: UUID?,
        barcode: String,
        productName: String? = nil,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil
    ) {
        self.remoteID = remoteID
        self.barcode = barcode
        self.productName = productName
        self.purchasePrice = purchasePrice
        self.retailPrice = retailPrice
    }
}

nonisolated struct ProductPriceApplyLocalPrice: Sendable, Equatable {
    let remoteID: UUID?
    let productRemoteID: UUID?
    let productBarcode: String
    let type: String
    let price: Double
    let effectiveAt: Date

    init(remoteID: UUID? = nil, productBarcode: String, productRemoteID: UUID? = nil, type: String, price: Double, effectiveAt: Date) {
        self.remoteID = remoteID
        self.productRemoteID = productRemoteID
        self.productBarcode = productBarcode
        self.type = type
        self.price = price
        self.effectiveAt = effectiveAt
    }
}

nonisolated enum ProductPriceApplyBlockReason: String, Sendable, Equatable, CaseIterable {
    case partial
    case truncated
    case sourceError
    case unmappedProducts
    case invalidRows
    case conflicts
    case sessionMismatch
    case noApplicableRows
}

nonisolated enum ProductPriceApplyIssueReason: String, Sendable, Equatable {
    case unmappedProduct
    case invalidType
    case invalidPrice
    case invalidEffectiveAt
    case mappingConflict
    case priceConflict
    case duplicateRemoteLogicalRow
    case sourceError
}

nonisolated struct ProductPriceApplyIssue: Identifiable, Sendable, Equatable {
    let id: UUID
    let reason: ProductPriceApplyIssueReason
    let detail: String

    init(id: UUID = UUID(), reason: ProductPriceApplyIssueReason, detail: String) {
        self.id = id
        self.reason = reason
        self.detail = detail
    }
}

nonisolated struct ProductPriceApplySummary: Sendable, Equatable {
    let remoteRead: Int
    let included: Int
    let remoteIdentityLinks: Int
    let skippedExisting: Int
    let unmapped: Int
    let invalid: Int
    let conflicts: Int
    let mappingConflicts: Int
    let partial: Bool
    let truncated: Bool
    let sourceError: String?

    init(
        remoteRead: Int,
        included: Int,
        remoteIdentityLinks: Int = 0,
        skippedExisting: Int,
        unmapped: Int,
        invalid: Int,
        conflicts: Int,
        mappingConflicts: Int,
        partial: Bool,
        truncated: Bool,
        sourceError: String?
    ) {
        self.remoteRead = remoteRead
        self.included = included
        self.remoteIdentityLinks = remoteIdentityLinks
        self.skippedExisting = skippedExisting
        self.unmapped = unmapped
        self.invalid = invalid
        self.conflicts = conflicts
        self.mappingConflicts = mappingConflicts
        self.partial = partial
        self.truncated = truncated
        self.sourceError = sourceError
    }
}

nonisolated struct ProductPriceApplyLine: Identifiable, Sendable, Equatable {
    let id: UUID
    let remoteRowID: UUID
    let productID: UUID
    let productBarcode: String
    let type: String
    let canonicalPrice: ProductPriceCanonicalAmount
    let effectiveAt: Date
    let effectiveAtCanonical: String
    let createdAt: Date?

    init(
        remoteRowID: UUID,
        productID: UUID,
        productBarcode: String,
        type: String,
        canonicalPrice: ProductPriceCanonicalAmount,
        effectiveAt: Date,
        effectiveAtCanonical: String,
        createdAt: Date?
    ) {
        self.id = remoteRowID
        self.remoteRowID = remoteRowID
        self.productID = productID
        self.productBarcode = productBarcode
        self.type = type
        self.canonicalPrice = canonicalPrice
        self.effectiveAt = effectiveAt
        self.effectiveAtCanonical = effectiveAtCanonical
        self.createdAt = createdAt
    }
}

nonisolated struct ProductPriceApplyIdentityLink: Identifiable, Sendable, Equatable {
    let id: UUID
    let remoteRowID: UUID
    let productID: UUID
    let productBarcode: String
    let type: String
    let canonicalPrice: ProductPriceCanonicalAmount
    let effectiveAtCanonical: String

    init(
        remoteRowID: UUID,
        productID: UUID,
        productBarcode: String,
        type: String,
        canonicalPrice: ProductPriceCanonicalAmount,
        effectiveAtCanonical: String
    ) {
        self.id = remoteRowID
        self.remoteRowID = remoteRowID
        self.productID = productID
        self.productBarcode = productBarcode
        self.type = type
        self.canonicalPrice = canonicalPrice
        self.effectiveAtCanonical = effectiveAtCanonical
    }
}

nonisolated struct ProductPriceApplyPlan: Sendable {
    let generatedAt: Date
    let sessionSnapshot: ProductPriceApplySessionSnapshot
    let sourceState: ProductPriceApplySourceState
    let summary: ProductPriceApplySummary
    let blockReasons: [ProductPriceApplyBlockReason]
    let linesToInsert: [ProductPriceApplyLine]
    let remoteIdentityLinks: [ProductPriceApplyIdentityLink]
    let issues: [ProductPriceApplyIssue]
    let remoteRows: [RemoteInventoryProductPriceRow]

    init(
        generatedAt: Date,
        sessionSnapshot: ProductPriceApplySessionSnapshot,
        sourceState: ProductPriceApplySourceState,
        summary: ProductPriceApplySummary,
        blockReasons: [ProductPriceApplyBlockReason],
        linesToInsert: [ProductPriceApplyLine],
        remoteIdentityLinks: [ProductPriceApplyIdentityLink] = [],
        issues: [ProductPriceApplyIssue],
        remoteRows: [RemoteInventoryProductPriceRow]
    ) {
        self.generatedAt = generatedAt
        self.sessionSnapshot = sessionSnapshot
        self.sourceState = sourceState
        self.summary = summary
        self.blockReasons = blockReasons
        self.linesToInsert = linesToInsert
        self.remoteIdentityLinks = remoteIdentityLinks
        self.issues = issues
        self.remoteRows = remoteRows
    }

    var isApplyAllowed: Bool {
        blockReasons.isEmpty && (!linesToInsert.isEmpty || !remoteIdentityLinks.isEmpty)
    }

    var hasHardBlocks: Bool {
        blockReasons.contains { $0 != .noApplicableRows }
    }
}

nonisolated struct ProductPriceApplyResult: Sendable, Equatable {
    let inserted: Int
    let remoteIdentityLinked: Int
    let skippedExisting: Int
    let totalConsidered: Int

    init(inserted: Int, remoteIdentityLinked: Int = 0, skippedExisting: Int, totalConsidered: Int) {
        self.inserted = inserted
        self.remoteIdentityLinked = remoteIdentityLinked
        self.skippedExisting = skippedExisting
        self.totalConsidered = totalConsidered
    }
}

nonisolated enum ProductPriceApplyError: Error, Sendable, Equatable {
    case fetcherMissing
    case sessionMismatch
    case policyBlocked([ProductPriceApplyBlockReason])
    case localSnapshotFailed(message: String?)
    case saveFailed(message: String?)
    case verificationFailed
}

nonisolated struct ProductPriceApplyFetchOptions: Sendable, Equatable {
    let pageSize: Int
    let maxRows: Int
    let maxPages: Int

    init(pageSize: Int = 500, maxRows: Int = 50_000, maxPages: Int = 100) {
        self.pageSize = max(1, min(pageSize, 1_000))
        self.maxRows = max(1, maxRows)
        self.maxPages = max(1, maxPages)
    }
}

nonisolated struct ProductPriceCanonicalAmount: Sendable, Hashable {
    let value: String
    let doubleValue: Double
}

nonisolated enum PriceCanonicalizer {
    static let scale: Int = 3

    static func canonicalAmount(from value: Double) -> ProductPriceCanonicalAmount? {
        guard value.isFinite, !value.isNaN, value >= 0 else {
            return nil
        }

        var decimal = Decimal(value)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &decimal, scale, .plain)

        guard rounded >= Decimal(0) else {
            return nil
        }

        let number = NSDecimalNumber(decimal: rounded)
        guard number != NSDecimalNumber.notANumber else {
            return nil
        }

        return ProductPriceCanonicalAmount(
            value: number.stringValue,
            doubleValue: number.doubleValue
        )
    }
}

nonisolated enum ProductPriceEffectiveAtCanonicalizer {
    static func canonicalDate(from value: String?) -> Date? {
        guard let value = SupabasePullPreviewNormalizer.semanticString(value) else {
            return nil
        }

        if let date = dateFormatter().date(from: value) {
            return date
        }

        if let date = fractionalISO8601Formatter().date(from: value) {
            return date
        }

        return standardISO8601Formatter().date(from: value)
    }

    static func canonicalString(from date: Date) -> String {
        dateFormatter().string(from: date)
    }

    private static func dateFormatter() -> DateFormatter {
        let key = "ProductPriceEffectiveAtCanonicalizer.dateFormatter"
        if let formatter = Thread.current.threadDictionary[key] as? DateFormatter {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.isLenient = false
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    private static func fractionalISO8601Formatter() -> ISO8601DateFormatter {
        let key = "ProductPriceEffectiveAtCanonicalizer.fractionalISO8601Formatter"
        if let formatter = Thread.current.threadDictionary[key] as? ISO8601DateFormatter {
            return formatter
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    private static func standardISO8601Formatter() -> ISO8601DateFormatter {
        let key = "ProductPriceEffectiveAtCanonicalizer.standardISO8601Formatter"
        if let formatter = Thread.current.threadDictionary[key] as? ISO8601DateFormatter {
            return formatter
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }
}

@MainActor
struct SupabaseProductPriceApplyService {
    private static let localSource = "SUPABASE_PULL"
    nonisolated fileprivate static let issueLimit = 8

    private let fetcher: (any SupabaseProductPricePreviewFetching)?
    private let fetchOptions: ProductPriceApplyFetchOptions

    init(
        fetcher: (any SupabaseProductPricePreviewFetching)? = nil,
        fetchOptions: ProductPriceApplyFetchOptions = ProductPriceApplyFetchOptions()
    ) {
        self.fetcher = fetcher
        self.fetchOptions = fetchOptions
    }

    func loadDryRun(
        context: ModelContext,
        sessionSnapshot: ProductPriceApplySessionSnapshot
    ) async throws -> ProductPriceApplyPlan {
        guard let fetcher else {
            throw ProductPriceApplyError.fetcherMissing
        }

        let fetchResult = await fetchRemoteRows(fetcher: fetcher)
        return try prepareApplyPlan(
            remoteRows: fetchResult.rows,
            context: context,
            sourceState: fetchResult.sourceState,
            sessionSnapshot: sessionSnapshot
        )
    }

    func prepareApplyPlan(
        remoteRows: [RemoteInventoryProductPriceRow],
        context: ModelContext,
        sourceState: ProductPriceApplySourceState = ProductPriceApplySourceState(),
        sessionSnapshot: ProductPriceApplySessionSnapshot
    ) throws -> ProductPriceApplyPlan {
        let snapshot: ProductPriceApplyLocalSnapshot
        do {
            snapshot = try makeLocalSnapshot(context: context)
        } catch {
            throw ProductPriceApplyError.localSnapshotFailed(message: String(describing: error))
        }

        return prepareApplyPlan(
            remoteRows: remoteRows,
            localSnapshot: snapshot,
            sourceState: sourceState,
            sessionSnapshot: sessionSnapshot
        )
    }

    func prepareApplyPlan(
        remoteRows: [RemoteInventoryProductPriceRow],
        localSnapshot: ProductPriceApplyLocalSnapshot,
        sourceState: ProductPriceApplySourceState = ProductPriceApplySourceState(),
        sessionSnapshot: ProductPriceApplySessionSnapshot
    ) -> ProductPriceApplyPlan {
        var builder = ProductPriceApplyPlanBuilder(
            remoteRows: remoteRows,
            localSnapshot: localSnapshot,
            sourceState: sourceState,
            sessionSnapshot: sessionSnapshot
        )
        return builder.build()
    }

    func apply(
        plan: ProductPriceApplyPlan,
        context: ModelContext,
        currentSessionSnapshot: ProductPriceApplySessionSnapshot
    ) throws -> ProductPriceApplyResult {
        guard plan.sessionSnapshot == currentSessionSnapshot else {
            throw ProductPriceApplyError.sessionMismatch
        }

        guard plan.isApplyAllowed else {
            throw ProductPriceApplyError.policyBlocked(plan.blockReasons)
        }

        let productsByRemoteID = try fetchUniqueProductsByRemoteID(context: context)
        var currentPricesByKey = try fetchCurrentPricesByKey(context: context)
        var inserted = 0
        var remoteIdentityLinked = 0
        var skippedExisting = 0

        for link in plan.remoteIdentityLinks {
            let key = ProductPriceApplyLogicalKey(
                productID: link.productID,
                type: link.type,
                effectiveAt: link.effectiveAtCanonical
            )
            guard let existingPrices = currentPricesByKey[key] else {
                throw ProductPriceApplyError.verificationFailed
            }
            let matchingPrices = existingPrices.filter {
                PriceCanonicalizer.canonicalAmount(from: $0.price) == link.canonicalPrice
            }
            guard matchingPrices.count == 1,
                  let existing = matchingPrices.first else {
                throw ProductPriceApplyError.policyBlocked([.conflicts])
            }
            if let existingRemoteID = existing.remoteID {
                guard existingRemoteID == link.remoteRowID else {
                    throw ProductPriceApplyError.policyBlocked([.conflicts])
                }
                skippedExisting += 1
                continue
            }

            existing.remoteID = link.remoteRowID
            remoteIdentityLinked += 1
            skippedExisting += 1
        }

        for line in plan.linesToInsert {
            guard let product = productsByRemoteID[line.productID] else {
                throw ProductPriceApplyError.policyBlocked([.unmappedProducts])
            }
            let key = ProductPriceApplyLogicalKey(
                productID: line.productID,
                type: line.type,
                effectiveAt: line.effectiveAtCanonical
            )

            if let existingPrices = currentPricesByKey[key] {
                guard existingPrices.count == 1 else {
                    throw ProductPriceApplyError.policyBlocked([.conflicts])
                }
                let existingAmounts = Set(existingPrices.compactMap { PriceCanonicalizer.canonicalAmount(from: $0.price) })
                guard existingAmounts.count == 1, existingAmounts.contains(line.canonicalPrice) else {
                    throw ProductPriceApplyError.policyBlocked([.conflicts])
                }
                let existingRemoteIDs = Set(existingPrices.compactMap(\.remoteID))
                guard existingRemoteIDs.allSatisfy({ $0 == line.remoteRowID }) else {
                    throw ProductPriceApplyError.policyBlocked([.conflicts])
                }
                if existingPrices.count == 1,
                   let existing = existingPrices.first,
                   existing.remoteID == nil {
                    existing.remoteID = line.remoteRowID
                    remoteIdentityLinked += 1
                }
                skippedExisting += 1
                continue
            }

            let newPrice = ProductPrice(
                remoteID: line.remoteRowID,
                type: priceType(from: line.type),
                price: line.canonicalPrice.doubleValue,
                effectiveAt: line.effectiveAt,
                source: Self.localSource,
                note: nil,
                createdAt: line.createdAt ?? Date(),
                product: product
            )
            context.insert(newPrice)
            currentPricesByKey[key, default: []].append(newPrice)
            inserted += 1
        }

        if inserted > 0 || remoteIdentityLinked > 0 {
            do {
                try context.save()
            } catch {
                context.rollback()
                throw ProductPriceApplyError.saveFailed(message: String(describing: error))
            }
        }

        let verificationPlan = try prepareApplyPlan(
            remoteRows: plan.remoteRows,
            context: context,
            sourceState: ProductPriceApplySourceState(),
            sessionSnapshot: currentSessionSnapshot
        )
        let verificationHardBlocks = verificationPlan.blockReasons.filter { $0 != .noApplicableRows }
        guard verificationHardBlocks.isEmpty,
              verificationPlan.linesToInsert.isEmpty,
              verificationPlan.remoteIdentityLinks.isEmpty else {
            throw ProductPriceApplyError.verificationFailed
        }

        return ProductPriceApplyResult(
            inserted: inserted,
            remoteIdentityLinked: remoteIdentityLinked,
            skippedExisting: skippedExisting,
            totalConsidered: verificationPlan.summary.remoteRead
        )
    }

    private func fetchRemoteRows(
        fetcher: any SupabaseProductPricePreviewFetching
    ) async -> (rows: [RemoteInventoryProductPriceRow], sourceState: ProductPriceApplySourceState) {
        var rows: [RemoteInventoryProductPriceRow] = []
        var seenRemoteIDs = Set<UUID>()
        var offset = 0
        var pagesFetched = 0

        while rows.count < fetchOptions.maxRows && pagesFetched < fetchOptions.maxPages {
            let remainingRows = fetchOptions.maxRows - rows.count
            let currentPageSize = min(fetchOptions.pageSize, remainingRows)

            do {
                try Task.checkCancellation()
                let page = try await fetcher.fetchProductPricesPreviewPage(
                    from: offset,
                    to: offset + currentPageSize - 1
                )
                try Task.checkCancellation()

                pagesFetched += 1

                if page.count > currentPageSize {
                    return (
                        rows,
                        ProductPriceApplySourceState(
                            partial: true,
                            sourceError: "inventory_product_prices range returned too many rows"
                        )
                    )
                }

                for row in page {
                    guard seenRemoteIDs.insert(row.id).inserted else {
                        return (
                            rows,
                            ProductPriceApplySourceState(
                                partial: true,
                                sourceError: "inventory_product_prices duplicate remote id"
                            )
                        )
                    }
                    rows.append(row)
                }

                if page.count < currentPageSize {
                    return (rows, ProductPriceApplySourceState())
                }

                offset += currentPageSize
            } catch is CancellationError {
                return (
                    rows,
                    ProductPriceApplySourceState(partial: true, sourceError: "cancelled")
                )
            } catch {
                return (
                    rows,
                    ProductPriceApplySourceState(
                        partial: true,
                        sourceError: safeDiagnosticDetail(for: error)
                    )
                )
            }
        }

        return (rows, ProductPriceApplySourceState(truncated: true))
    }

    private func makeLocalSnapshot(context: ModelContext) throws -> ProductPriceApplyLocalSnapshot {
        let products = try context.fetch(
            FetchDescriptor<Product>(
                sortBy: [SortDescriptor(\Product.barcode)]
            )
        )
        let prices = try context.fetch(
            FetchDescriptor<ProductPrice>(
                sortBy: [SortDescriptor(\ProductPrice.effectiveAt)]
            )
        )

        let localProducts = products.map {
            ProductPriceApplyLocalProduct(
                remoteID: $0.remoteID,
                barcode: $0.barcode,
                productName: $0.productName,
                purchasePrice: $0.purchasePrice,
                retailPrice: $0.retailPrice
            )
        }

        let localPrices = prices.compactMap { price -> ProductPriceApplyLocalPrice? in
            guard let product = price.product else {
                return nil
            }
            return ProductPriceApplyLocalPrice(
                remoteID: price.remoteID,
                productBarcode: product.barcode,
                productRemoteID: product.remoteID,
                type: price.type.rawValue,
                price: price.price,
                effectiveAt: price.effectiveAt
            )
        }

        return ProductPriceApplyLocalSnapshot(products: localProducts, prices: localPrices)
    }

    private func fetchUniqueProductsByRemoteID(context: ModelContext) throws -> [UUID: Product] {
        let products = try context.fetch(
            FetchDescriptor<Product>(
                sortBy: [SortDescriptor(\Product.barcode)]
            )
        )

        var result: [UUID: Product] = [:]
        var counts: [UUID: Int] = [:]
        for product in products {
            guard let remoteID = product.remoteID else {
                continue
            }
            counts[remoteID, default: 0] += 1
            if result[remoteID] == nil {
                result[remoteID] = product
            }
        }

        guard counts.values.allSatisfy({ $0 == 1 }) else {
            throw ProductPriceApplyError.policyBlocked([.conflicts])
        }

        return result
    }

    private func fetchCurrentPricesByKey(context: ModelContext) throws -> [ProductPriceApplyLogicalKey: [ProductPrice]] {
        let prices = try context.fetch(
            FetchDescriptor<ProductPrice>(
                sortBy: [SortDescriptor(\ProductPrice.effectiveAt)]
            )
        )
        var result: [ProductPriceApplyLogicalKey: [ProductPrice]] = [:]

        for price in prices {
            guard let product = price.product,
                  let productID = product.remoteID,
                  PriceCanonicalizer.canonicalAmount(from: price.price) != nil else {
                continue
            }

            let key = ProductPriceApplyLogicalKey(
                productID: productID,
                type: price.type.rawValue,
                effectiveAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt)
            )
            result[key, default: []].append(price)
        }

        return result
    }

    private func priceType(from normalizedType: String) -> PriceType {
        normalizedType == PriceType.retail.rawValue ? .retail : .purchase
    }

    private func safeDiagnosticDetail(for error: Error) -> String? {
        if let serviceError = error as? SupabaseInventoryServiceError {
            return serviceError.safeDiagnosticDetail ?? "inventory_product_prices"
        }
        return SupabaseInventoryServiceError.sanitizedDiagnosticDetail(String(describing: error))
            ?? "inventory_product_prices"
    }
}

nonisolated private struct ProductPriceApplyLogicalKey: Hashable {
    let productID: UUID
    let type: String
    let effectiveAt: String
}

nonisolated private struct ProductPriceApplyLocalPriceInfo: Sendable, Equatable {
    let canonicalPrice: ProductPriceCanonicalAmount
    let remoteID: UUID?
}

nonisolated private struct ProductPriceApplyPlanBuilder {
    private let remoteRows: [RemoteInventoryProductPriceRow]
    private let localSnapshot: ProductPriceApplyLocalSnapshot
    private let sourceState: ProductPriceApplySourceState
    private let sessionSnapshot: ProductPriceApplySessionSnapshot

    private var linesToInsert: [ProductPriceApplyLine] = []
    private var remoteIdentityLinks: [ProductPriceApplyIdentityLink] = []
    private var issues: [ProductPriceApplyIssue] = []
    private var skippedExisting = 0
    private var unmapped = 0
    private var invalid = 0
    private var conflicts = 0
    private var mappingConflicts = 0
    private var accessOrSyncError: String?

    init(
        remoteRows: [RemoteInventoryProductPriceRow],
        localSnapshot: ProductPriceApplyLocalSnapshot,
        sourceState: ProductPriceApplySourceState,
        sessionSnapshot: ProductPriceApplySessionSnapshot
    ) {
        self.remoteRows = remoteRows
        self.localSnapshot = localSnapshot
        self.sourceState = sourceState
        self.sessionSnapshot = sessionSnapshot
    }

    mutating func build() -> ProductPriceApplyPlan {
        let productLookup = makeProductLookup()
        let localPricesByKey = makeLocalPriceLookup(productLookup: productLookup)
        var remotePricesByKey: [ProductPriceApplyLogicalKey: ProductPriceCanonicalAmount] = [:]

        for row in remoteRows {
            guard row.ownerUserID == sessionSnapshot.userID else {
                accessOrSyncError = accessOrSyncError ?? "owner mismatch"
                appendInvalid(.sourceError, detail: "owner mismatch")
                continue
            }

            guard let type = SupabasePullPreviewNormalizer.normalizedPriceType(row.type) else {
                appendInvalid(.invalidType, detail: row.type)
                continue
            }

            guard let canonicalPrice = PriceCanonicalizer.canonicalAmount(from: row.price) else {
                appendInvalid(.invalidPrice, detail: row.id.uuidString)
                continue
            }

            guard let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.effectiveAt) else {
                appendInvalid(.invalidEffectiveAt, detail: row.effectiveAt)
                continue
            }

            let effectiveAtCanonical = ProductPriceEffectiveAtCanonicalizer.canonicalString(from: effectiveAt)

            if productLookup.duplicateRemoteIDs.contains(row.productID) {
                mappingConflicts += 1
                conflicts += 1
                appendIssue(.mappingConflict, detail: row.productID.uuidString)
                continue
            }

            guard let product = productLookup.productsByRemoteID[row.productID] else {
                unmapped += 1
                appendIssue(.unmappedProduct, detail: row.productID.uuidString)
                continue
            }

            let key = ProductPriceApplyLogicalKey(
                productID: row.productID,
                type: type,
                effectiveAt: effectiveAtCanonical
            )

            if let existingPrices = localPricesByKey[key] {
                guard existingPrices.count == 1 else {
                    conflicts += 1
                    appendIssue(.priceConflict, detail: "\(product.barcode) / \(type) / \(effectiveAtCanonical)")
                    continue
                }
                let existingAmounts = Set(existingPrices.map(\.canonicalPrice))
                guard existingAmounts.count == 1, existingAmounts.contains(canonicalPrice) else {
                    conflicts += 1
                    appendIssue(.priceConflict, detail: "\(product.barcode) / \(type) / \(effectiveAtCanonical)")
                    continue
                }
                let existingRemoteIDs = Set(existingPrices.compactMap(\.remoteID))
                if existingRemoteIDs.contains(where: { $0 != row.id }) {
                    conflicts += 1
                    appendIssue(.priceConflict, detail: "\(product.barcode) / \(type) / \(effectiveAtCanonical)")
                    continue
                }
                if existingPrices.count == 1, existingPrices[0].remoteID == nil {
                    if remoteIdentityLinks.contains(where: {
                        $0.productID == row.productID
                            && $0.type == type
                            && $0.effectiveAtCanonical == effectiveAtCanonical
                    }) {
                        conflicts += 1
                        appendIssue(.duplicateRemoteLogicalRow, detail: "\(product.barcode) / \(type) / \(effectiveAtCanonical)")
                        continue
                    }
                    remoteIdentityLinks.append(
                        ProductPriceApplyIdentityLink(
                            remoteRowID: row.id,
                            productID: row.productID,
                            productBarcode: product.barcode,
                            type: type,
                            canonicalPrice: canonicalPrice,
                            effectiveAtCanonical: effectiveAtCanonical
                        )
                    )
                }
                skippedExisting += 1
                continue
            }

            if remotePricesByKey[key] != nil {
                conflicts += 1
                appendIssue(.duplicateRemoteLogicalRow, detail: "\(product.barcode) / \(type) / \(effectiveAtCanonical)")
                continue
            }

            remotePricesByKey[key] = canonicalPrice
            linesToInsert.append(
                ProductPriceApplyLine(
                    remoteRowID: row.id,
                    productID: row.productID,
                    productBarcode: product.barcode,
                    type: type,
                    canonicalPrice: canonicalPrice,
                    effectiveAt: effectiveAt,
                    effectiveAtCanonical: effectiveAtCanonical,
                    createdAt: ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.createdAt)
                )
            )
        }

        let summary = ProductPriceApplySummary(
            remoteRead: remoteRows.count,
            included: linesToInsert.count,
            remoteIdentityLinks: remoteIdentityLinks.count,
            skippedExisting: skippedExisting,
            unmapped: unmapped,
            invalid: invalid,
            conflicts: conflicts,
            mappingConflicts: mappingConflicts,
            partial: sourceState.partial,
            truncated: sourceState.truncated,
            sourceError: sourceState.sourceError ?? accessOrSyncError
        )

        return ProductPriceApplyPlan(
            generatedAt: Date(),
            sessionSnapshot: sessionSnapshot,
            sourceState: sourceState,
            summary: summary,
            blockReasons: makeBlockReasons(summary: summary),
            linesToInsert: linesToInsert.sorted {
                ($0.productBarcode, $0.type, $0.effectiveAtCanonical, $0.remoteRowID.uuidString)
                    < ($1.productBarcode, $1.type, $1.effectiveAtCanonical, $1.remoteRowID.uuidString)
            },
            remoteIdentityLinks: remoteIdentityLinks.sorted {
                ($0.productBarcode, $0.type, $0.effectiveAtCanonical, $0.remoteRowID.uuidString)
                    < ($1.productBarcode, $1.type, $1.effectiveAtCanonical, $1.remoteRowID.uuidString)
            },
            issues: issues,
            remoteRows: remoteRows
        )
    }

    private func makeProductLookup() -> (productsByRemoteID: [UUID: ProductPriceApplyLocalProduct], duplicateRemoteIDs: Set<UUID>) {
        var counts: [UUID: Int] = [:]
        var productsByRemoteID: [UUID: ProductPriceApplyLocalProduct] = [:]

        for product in localSnapshot.products {
            guard let remoteID = product.remoteID else {
                continue
            }
            counts[remoteID, default: 0] += 1
            if productsByRemoteID[remoteID] == nil {
                productsByRemoteID[remoteID] = product
            }
        }

        let duplicates = Set(counts.filter { $0.value > 1 }.map(\.key))
        return (productsByRemoteID, duplicates)
    }

    private func makeLocalPriceLookup(
        productLookup: (productsByRemoteID: [UUID: ProductPriceApplyLocalProduct], duplicateRemoteIDs: Set<UUID>)
    ) -> [ProductPriceApplyLogicalKey: [ProductPriceApplyLocalPriceInfo]] {
        var result: [ProductPriceApplyLogicalKey: [ProductPriceApplyLocalPriceInfo]] = [:]
        let remoteIDByBarcode = Dictionary(
            productLookup.productsByRemoteID.map { ($0.value.barcode, $0.key) },
            uniquingKeysWith: { first, _ in first }
        )

        for price in localSnapshot.prices {
            guard let type = SupabasePullPreviewNormalizer.normalizedPriceType(price.type),
                  let productID = price.productRemoteID ?? remoteIDByBarcode[price.productBarcode],
                  let canonicalPrice = PriceCanonicalizer.canonicalAmount(from: price.price) else {
                continue
            }

            let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt)
            let key = ProductPriceApplyLogicalKey(
                productID: productID,
                type: type,
                effectiveAt: effectiveAt
            )
            result[key, default: []].append(
                ProductPriceApplyLocalPriceInfo(canonicalPrice: canonicalPrice, remoteID: price.remoteID)
            )
        }

        return result
    }

    private mutating func appendInvalid(_ reason: ProductPriceApplyIssueReason, detail: String) {
        invalid += 1
        appendIssue(reason, detail: detail)
    }

    private mutating func appendIssue(_ reason: ProductPriceApplyIssueReason, detail: String) {
        guard issues.count < SupabaseProductPriceApplyService.issueLimit else {
            return
        }
        issues.append(ProductPriceApplyIssue(reason: reason, detail: detail))
    }

    private func makeBlockReasons(summary: ProductPriceApplySummary) -> [ProductPriceApplyBlockReason] {
        var reasons: [ProductPriceApplyBlockReason] = []

        if summary.partial {
            reasons.append(.partial)
        }
        if summary.truncated {
            reasons.append(.truncated)
        }
        if summary.sourceError != nil {
            reasons.append(.sourceError)
        }
        if summary.unmapped > 0 {
            reasons.append(.unmappedProducts)
        }
        if summary.invalid > 0 {
            reasons.append(.invalidRows)
        }
        if summary.conflicts > 0 {
            reasons.append(.conflicts)
        }
        if summary.included == 0 && summary.remoteIdentityLinks == 0 {
            reasons.append(.noApplicableRows)
        }

        return reasons
    }
}
