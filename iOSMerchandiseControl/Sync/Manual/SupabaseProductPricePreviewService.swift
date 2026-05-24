import Foundation
import SwiftData

protocol SupabaseProductPricePreviewFetching: Sendable {
    func fetchProductPricesPreviewPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow]
    func fetchProductPriceCount() async throws -> Int?
}

protocol SupabaseProductPriceKeysetFetching: SupabaseProductPricePreviewFetching {
    func fetchProductPricesPreviewPage(afterID: UUID?, limit: Int) async throws -> [RemoteInventoryProductPriceRow]
}

protocol SupabaseProductPriceDeletedProductFetching: Sendable {
    func fetchDeletedProductIDs(pageSize: Int) async throws -> Set<UUID>
}

extension SupabaseProductPricePreviewFetching {
    func fetchProductPriceCount() async throws -> Int? {
        nil
    }
}

nonisolated struct ProductPricePreviewOptions: Sendable, Equatable {
    static let defaultPageSize = 200
    static let defaultMaxRows = 1_000
    static let defaultMaxPages = 5
    static let defaultSampleLimit = 15
    static let maxSampleLimit = 20

    let pageSize: Int
    let maxRows: Int
    let maxPages: Int
    let sampleLimit: Int

    init(
        pageSize: Int = Self.defaultPageSize,
        maxRows: Int = Self.defaultMaxRows,
        maxPages: Int = Self.defaultMaxPages,
        sampleLimit: Int = Self.defaultSampleLimit
    ) {
        self.pageSize = max(1, min(pageSize, 1_000))
        self.maxRows = max(1, maxRows)
        self.maxPages = max(1, maxPages)
        self.sampleLimit = max(0, min(sampleLimit, Self.maxSampleLimit))
    }
}

nonisolated enum ProductPricePreviewStoppedReason: String, Sendable, Equatable {
    case pageEmpty
    case partialPage
    case maxRows
    case maxPages
    case error
    case cancelled
}

nonisolated struct ProductPricePreviewSampleRow: Identifiable, Sendable, Equatable {
    let id: UUID
    let remoteRowID: UUID
    let productID: UUID
    let abbreviatedProductID: String
    let normalizedType: String
    let price: Double
    let effectiveAtRaw: String
    let effectiveAtCanonical: String
    let productDisplayName: String?
    let isOrphan: Bool

    init(
        remoteRowID: UUID,
        productID: UUID,
        normalizedType: String,
        price: Double,
        effectiveAtRaw: String,
        effectiveAtCanonical: String,
        productDisplayName: String?,
        isOrphan: Bool
    ) {
        self.id = remoteRowID
        self.remoteRowID = remoteRowID
        self.productID = productID
        self.abbreviatedProductID = Self.abbreviatedUUID(productID)
        self.normalizedType = normalizedType
        self.price = price
        self.effectiveAtRaw = effectiveAtRaw
        self.effectiveAtCanonical = effectiveAtCanonical
        self.productDisplayName = productDisplayName
        self.isOrphan = isOrphan
    }

    private static func abbreviatedUUID(_ id: UUID) -> String {
        String(id.uuidString.prefix(8)) + "..."
    }
}

nonisolated struct ProductPricePreviewSummary: Sendable, Equatable {
    let totalFetched: Int
    let pagesFetched: Int
    let truncated: Bool
    let orphanCount: Int
    let invalidTypeCount: Int
    let invalidEffectiveAtCount: Int
    let stoppedReason: ProductPricePreviewStoppedReason
    let diagnosticDetail: String?
    let samples: [ProductPricePreviewSampleRow]
}

nonisolated enum ProductPricePreviewViewState: Sendable {
    case idle
    case loading
    case loaded(ProductPricePreviewSummary)
    case failed(SupabaseTransportClientError)
}

nonisolated struct ProductPricePreviewLocalProduct: Sendable, Equatable {
    let remoteID: UUID?
    let barcode: String
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
}

nonisolated enum ProductPricePreviewLocalLookupBuilder {
    static func makeLookup(context: ModelContext) throws -> [UUID: String] {
        let products = try context.fetch(
            FetchDescriptor<Product>(
                sortBy: [SortDescriptor(\Product.barcode)]
            )
        )
        return makeLookup(
            products.map {
                ProductPricePreviewLocalProduct(
                    remoteID: $0.remoteID,
                    barcode: $0.barcode,
                    itemNumber: $0.itemNumber,
                    productName: $0.productName,
                    secondProductName: $0.secondProductName
                )
            }
        )
    }

    static func makeLookup(_ products: [ProductPricePreviewLocalProduct]) -> [UUID: String] {
        var lookup: [UUID: String] = [:]

        for product in products {
            guard let remoteID = product.remoteID, lookup[remoteID] == nil else {
                continue
            }

            lookup[remoteID] = displayName(for: product, fallbackID: remoteID)
        }

        return lookup
    }

    private static func displayName(for product: ProductPricePreviewLocalProduct, fallbackID: UUID) -> String {
        let raw = SupabasePullPreviewNormalizer.semanticString(product.productName)
            ?? SupabasePullPreviewNormalizer.semanticString(product.secondProductName)
            ?? SupabasePullPreviewNormalizer.semanticString(product.itemNumber)
            ?? SupabasePullPreviewNormalizer.semanticString(product.barcode)
            ?? fallbackID.uuidString

        return truncated(raw, maxLength: 32)
    }

    static func truncated(_ value: String, maxLength: Int) -> String {
        guard maxLength > 3, value.count > maxLength else {
            return value
        }

        return String(value.prefix(maxLength - 3)) + "..."
    }
}

nonisolated struct SupabaseProductPricePreviewService: Sendable {
    private let fetcher: any SupabaseProductPricePreviewFetching
    let options: ProductPricePreviewOptions

    init(
        fetcher: any SupabaseProductPricePreviewFetching,
        options: ProductPricePreviewOptions = ProductPricePreviewOptions()
    ) {
        self.fetcher = fetcher
        self.options = options
    }

    func loadPreview(productLookup: [UUID: String]) async throws -> ProductPricePreviewSummary {
        var accumulator = ProductPricePreviewAccumulator(options: options)
        var offset = 0

        do {
            while accumulator.totalFetched < options.maxRows && accumulator.pagesFetched < options.maxPages {
                try Task.checkCancellation()

                let remainingRows = options.maxRows - accumulator.totalFetched
                let currentPageSize = min(options.pageSize, remainingRows)
                let page = try await fetcher.fetchProductPricesPreviewPage(
                    from: offset,
                    to: offset + currentPageSize - 1
                )

                try Task.checkCancellation()

                accumulator.pagesFetched += 1
                accumulator.consume(page: Array(page.prefix(currentPageSize)), productLookup: productLookup)

                if page.isEmpty {
                    return accumulator.summary(stoppedReason: .pageEmpty)
                }

                if page.count < currentPageSize {
                    return accumulator.summary(stoppedReason: .partialPage)
                }

                if accumulator.totalFetched >= options.maxRows {
                    return accumulator.summary(stoppedReason: .maxRows)
                }

                if accumulator.pagesFetched >= options.maxPages {
                    return accumulator.summary(stoppedReason: .maxPages)
                }

                offset += currentPageSize
            }

            let reason: ProductPricePreviewStoppedReason = accumulator.totalFetched >= options.maxRows
                ? .maxRows
                : .maxPages
            return accumulator.summary(stoppedReason: reason)
        } catch is CancellationError {
            return accumulator.summary(stoppedReason: .cancelled)
        } catch {
            guard accumulator.totalFetched > 0 || accumulator.pagesFetched > 0 else {
                throw Self.previewError(from: error)
            }

            return accumulator.summary(
                stoppedReason: .error,
                diagnosticDetail: Self.safeDiagnosticDetail(for: error)
            )
        }
    }

    private static func previewError(from error: Error) -> SupabaseTransportClientError {
        if let serviceError = error as? SupabaseTransportClientError {
            return serviceError
        }
        return .unknown(message: String(describing: error))
    }

    private static func safeDiagnosticDetail(for error: Error) -> String? {
        if let serviceError = error as? SupabaseTransportClientError {
            return serviceError.safeDiagnosticDetail
        }
        return SupabaseTransportClientError.sanitizedDiagnosticDetail(String(describing: error))
    }
}

nonisolated private struct ProductPricePreviewDedupeKey: Hashable {
    let productID: UUID
    let normalizedType: String
    let effectiveAtRaw: String
}

nonisolated private struct ProductPricePreviewAccumulator {
    private let options: ProductPricePreviewOptions
    private var rowsByKey: [ProductPricePreviewDedupeKey: ProductPricePreviewSampleRow] = [:]

    var totalFetched = 0
    var pagesFetched = 0
    var orphanCount = 0
    var invalidTypeCount = 0
    var invalidEffectiveAtCount = 0

    init(options: ProductPricePreviewOptions) {
        self.options = options
    }

    mutating func consume(page: [RemoteInventoryProductPriceRow], productLookup: [UUID: String]) {
        for row in page {
            totalFetched += 1

            guard let normalizedType = SupabasePullPreviewNormalizer.normalizedPriceType(row.type) else {
                invalidTypeCount += 1
                continue
            }

            guard let effectiveAtRaw = SupabasePullPreviewNormalizer.semanticString(row.effectiveAt),
                  let effectiveAtCanonical = Self.canonicalProductPriceTimestamp(effectiveAtRaw) else {
                invalidEffectiveAtCount += 1
                continue
            }

            let key = ProductPricePreviewDedupeKey(
                productID: row.productID,
                normalizedType: normalizedType,
                effectiveAtRaw: effectiveAtRaw
            )
            guard rowsByKey[key] == nil else {
                continue
            }

            let productDisplayName = productLookup[row.productID]
            let isOrphan = productDisplayName == nil
            if isOrphan {
                orphanCount += 1
            }

            rowsByKey[key] = ProductPricePreviewSampleRow(
                remoteRowID: row.id,
                productID: row.productID,
                normalizedType: normalizedType,
                price: row.price,
                effectiveAtRaw: effectiveAtRaw,
                effectiveAtCanonical: effectiveAtCanonical,
                productDisplayName: productDisplayName,
                isOrphan: isOrphan
            )
        }
    }

    func summary(
        stoppedReason: ProductPricePreviewStoppedReason,
        diagnosticDetail: String? = nil
    ) -> ProductPricePreviewSummary {
        let sortedRows = rowsByKey.values.sorted { lhs, rhs in
            if lhs.effectiveAtCanonical != rhs.effectiveAtCanonical {
                return lhs.effectiveAtCanonical > rhs.effectiveAtCanonical
            }
            return lhs.remoteRowID.uuidString < rhs.remoteRowID.uuidString
        }

        return ProductPricePreviewSummary(
            totalFetched: totalFetched,
            pagesFetched: pagesFetched,
            truncated: stoppedReason == .maxRows || stoppedReason == .maxPages,
            orphanCount: orphanCount,
            invalidTypeCount: invalidTypeCount,
            invalidEffectiveAtCount: invalidEffectiveAtCount,
            stoppedReason: stoppedReason,
            diagnosticDetail: diagnosticDetail,
            samples: Array(sortedRows.prefix(options.sampleLimit))
        )
    }

    private static func canonicalProductPriceTimestamp(_ value: String) -> String? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.isLenient = false

        guard let date = formatter.date(from: value) else {
            return nil
        }

        return formatter.string(from: date)
    }
}
