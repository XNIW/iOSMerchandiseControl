import Foundation
import SwiftData

nonisolated struct SupabasePullPreviewService: Sendable {
    private let inventoryService: SupabaseInventoryService
    private let pageSize: Int
    private let maxCatalogRows: Int
    private let maxProductPriceRows: Int

    init(
        inventoryService: SupabaseInventoryService,
        pageSize: Int = 500,
        maxCatalogRows: Int = 10_000,
        maxProductPriceRows: Int = 2_000
    ) {
        self.inventoryService = inventoryService
        self.pageSize = max(1, min(pageSize, 1_000))
        self.maxCatalogRows = maxCatalogRows
        self.maxProductPriceRows = maxProductPriceRows
    }

    @MainActor
    func generatePreview(context: ModelContext) async -> SupabasePullPreviewViewState {
        let remoteOutcome: RemoteFetchOutcome
        do {
            remoteOutcome = try await fetchRemoteSnapshot()
        } catch let error as SupabaseInventoryServiceError {
            return .failed(.service(error))
        } catch {
            return .failed(.unknown(message: String(describing: error)))
        }

        let localSnapshot: LocalInventorySnapshot
        do {
            localSnapshot = try SwiftDataInventorySnapshotService(context: context).makeSnapshot()
        } catch {
            return .failed(.localSnapshot(message: String(describing: error)))
        }

        let preview = await Task.detached(priority: .userInitiated) {
            SupabasePullPreviewDiffEngine.makePreview(
                remote: remoteOutcome.snapshot,
                local: localSnapshot,
                outcome: remoteOutcome.partialCatalog ? .partial : .success
            )
        }.value

        if remoteOutcome.partialCatalog {
            return .partial(
                preview,
                warnings: preview.warnings,
                sourceErrors: preview.sourceErrors
            )
        }

        return .success(preview)
    }

    private func fetchRemoteSnapshot() async throws -> RemoteFetchOutcome {
        let products = try await fetchPaged(
            maxRows: maxCatalogRows
        ) { from, to in
            try await inventoryService.fetchProductsPage(from: from, to: to)
        }

        var sourceErrors: [SyncPreviewWarning] = []
        var partialCatalog = products.reachedCap

        if products.reachedCap {
            sourceErrors.append(
                SyncPreviewWarning(
                    code: .sourceError,
                    detail: "inventory_products",
                    relatedKey: "inventory_products"
                )
            )
        }

        async let suppliersFetch = fetchPaged(maxRows: maxCatalogRows) { from, to in
            try await inventoryService.fetchSuppliersPage(from: from, to: to)
        }
        async let categoriesFetch = fetchPaged(maxRows: maxCatalogRows) { from, to in
            try await inventoryService.fetchCategoriesPage(from: from, to: to)
        }
        async let productPricesFetch = fetchPaged(maxRows: maxProductPriceRows) { from, to in
            try await inventoryService.fetchProductPricesPage(from: from, to: to)
        }

        let suppliers: [RemoteInventorySupplierRow]
        do {
            let result = try await suppliersFetch
            suppliers = result.rows
            if result.reachedCap {
                partialCatalog = true
                sourceErrors.append(
                    SyncPreviewWarning(
                        code: .sourceError,
                        detail: "inventory_suppliers",
                        relatedKey: "inventory_suppliers"
                    )
                )
            }
        } catch {
            suppliers = []
            partialCatalog = true
            sourceErrors.append(sourceErrorWarning(for: "inventory_suppliers", error: error))
        }

        let categories: [RemoteInventoryCategoryRow]
        do {
            let result = try await categoriesFetch
            categories = result.rows
            if result.reachedCap {
                partialCatalog = true
                sourceErrors.append(
                    SyncPreviewWarning(
                        code: .sourceError,
                        detail: "inventory_categories",
                        relatedKey: "inventory_categories"
                    )
                )
            }
        } catch {
            categories = []
            partialCatalog = true
            sourceErrors.append(sourceErrorWarning(for: "inventory_categories", error: error))
        }

        let productPrices: [RemoteInventoryProductPriceRow]
        do {
            let result = try await productPricesFetch
            productPrices = result.rows
            if result.reachedCap {
                sourceErrors.append(
                    SyncPreviewWarning(
                        code: .priceHistoryIncomplete,
                        detail: "inventory_product_prices",
                        relatedKey: "inventory_product_prices"
                    )
                )
            }
        } catch {
            productPrices = []
            sourceErrors.append(sourceErrorWarning(for: "inventory_product_prices", error: error))
            sourceErrors.append(
                SyncPreviewWarning(
                    code: .priceHistoryIncomplete,
                    detail: "inventory_product_prices",
                    relatedKey: "inventory_product_prices"
                )
            )
        }

        return RemoteFetchOutcome(
            snapshot: RemoteInventorySnapshot(
                products: products.rows,
                suppliers: suppliers,
                categories: categories,
                productPrices: productPrices,
                sourceErrors: sourceErrors
            ),
            partialCatalog: partialCatalog
        )
    }

    private func fetchPaged<Row: Sendable>(
        maxRows: Int,
        fetchPage: (Int, Int) async throws -> [Row]
    ) async throws -> PagedFetchResult<Row> {
        var rows: [Row] = []
        var offset = 0
        let rowBudget = max(0, maxRows)

        guard rowBudget > 0 else {
            return PagedFetchResult(rows: [], reachedCap: true)
        }

        while rows.count < rowBudget {
            let remaining = rowBudget - rows.count
            let currentPageSize = min(pageSize, remaining)
            let page = try await fetchPage(offset, offset + currentPageSize - 1)
            rows.append(contentsOf: page)

            if page.count < currentPageSize {
                return PagedFetchResult(rows: rows, reachedCap: false)
            }

            offset += currentPageSize
        }

        return PagedFetchResult(rows: rows, reachedCap: true)
    }

    private func sourceErrorWarning(for table: String, error: Error) -> SyncPreviewWarning {
        let detail: String?
        if let serviceError = error as? SupabaseInventoryServiceError,
           let safeDetail = serviceError.safeDiagnosticDetail {
            detail = "\(table): \(safeDetail)"
        } else {
            detail = table
        }

        return SyncPreviewWarning(
            code: .sourceError,
            detail: detail,
            relatedKey: table
        )
    }

    private struct PagedFetchResult<Row: Sendable>: Sendable {
        let rows: [Row]
        let reachedCap: Bool
    }

    private struct RemoteFetchOutcome: Sendable {
        let snapshot: RemoteInventorySnapshot
        let partialCatalog: Bool
    }
}

nonisolated enum SupabasePullPreviewDiffEngine {
    static func makePreview(
        remote: RemoteInventorySnapshot,
        local: LocalInventorySnapshot,
        outcome: SyncPreviewOutcome
    ) -> SyncPreview {
        var conflicts: [SyncPreviewConflict] = []
        var warnings: [SyncPreviewWarning] = []
        var newProducts: [SyncPreviewProductSummary] = []
        var updateCandidates: [SyncPreviewProductSummary] = []
        var unchangedProducts: [SyncPreviewProductSummary] = []
        var tombstones: [SyncPreviewProductSummary] = []
        var supplierDiffs: [SyncPreviewFieldChange] = []
        var categoryDiffs: [SyncPreviewFieldChange] = []
        var priceHistoryDiffs: [SyncPreviewFieldChange] = []

        for duplicate in local.duplicateProductBarcodes {
            conflicts.append(
                SyncPreviewConflict(
                    kind: .localDuplicateBarcode,
                    barcodeOrKey: duplicate,
                    detail: duplicate
                )
            )
        }

        for duplicate in local.duplicateSupplierNames {
            warnings.append(
                SyncPreviewWarning(
                    code: .localDuplicateName,
                    detail: duplicate,
                    relatedKey: "supplier"
                )
            )
        }

        for duplicate in local.duplicateCategoryNames {
            warnings.append(
                SyncPreviewWarning(
                    code: .localDuplicateName,
                    detail: duplicate,
                    relatedKey: "category"
                )
            )
        }

        for duplicate in duplicateRemoteSupplierNames(remote) {
            warnings.append(
                SyncPreviewWarning(
                    code: .remoteDuplicateName,
                    detail: duplicate,
                    relatedKey: "supplier"
                )
            )
        }

        for duplicate in duplicateRemoteCategoryNames(remote) {
            warnings.append(
                SyncPreviewWarning(
                    code: .remoteDuplicateName,
                    detail: duplicate,
                    relatedKey: "category"
                )
            )
        }

        for product in remote.tombstonedProducts {
            tombstones.append(
                productSummary(
                    product,
                    classification: .remoteTombstone,
                    detail: product.deletedAt
                )
            )
        }

        let duplicateRemoteBarcodes = Set(remote.duplicateBarcodeGroups.keys)
        for (barcode, products) in remote.duplicateBarcodeGroups {
            conflicts.append(
                SyncPreviewConflict(
                    kind: .remoteDuplicateBarcode,
                    barcodeOrKey: barcode,
                    detail: barcode,
                    relatedRemoteIDs: products.map(\.id),
                    hintKey: "options.supabase.preview.conflict.hint.review"
                )
            )
        }

        let supplierFetchFailed = remote.hasSourceError(for: "inventory_suppliers")
        let categoryFetchFailed = remote.hasSourceError(for: "inventory_categories")

        for product in remote.activeProducts {
            guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(product.barcode) else {
                conflicts.append(
                    SyncPreviewConflict(
                        kind: .remoteEmptyBarcode,
                        barcodeOrKey: nil,
                        detail: product.id.uuidString,
                        relatedRemoteIDs: [product.id],
                        hintKey: "options.supabase.preview.conflict.hint.review"
                    )
                )
                warnings.append(
                    SyncPreviewWarning(
                        code: .remoteEmptyBarcode,
                        detail: product.id.uuidString
                    )
                )
                continue
            }

            if duplicateRemoteBarcodes.contains(barcode) {
                continue
            }

            guard let localProduct = local.productsByBarcode[barcode] else {
                newProducts.append(productSummary(product, classification: .newProduct))
                continue
            }

            var productConflicts: [SyncPreviewConflict] = []
            if product.supplierID != nil,
               remote.supplierName(for: product) == nil,
               !supplierFetchFailed {
                productConflicts.append(
                    SyncPreviewConflict(
                        kind: .missingRemoteSupplier,
                        barcodeOrKey: barcode,
                        detail: product.supplierID?.uuidString,
                        relatedRemoteIDs: [product.id],
                        hintKey: "options.supabase.preview.conflict.hint.review"
                    )
                )
            }

            if product.categoryID != nil,
               remote.categoryName(for: product) == nil,
               !categoryFetchFailed {
                productConflicts.append(
                    SyncPreviewConflict(
                        kind: .missingRemoteCategory,
                        barcodeOrKey: barcode,
                        detail: product.categoryID?.uuidString,
                        relatedRemoteIDs: [product.id],
                        hintKey: "options.supabase.preview.conflict.hint.review"
                    )
                )
            }

            if !productConflicts.isEmpty {
                conflicts.append(contentsOf: productConflicts)
                continue
            }

            var changes = productFieldChanges(
                remoteProduct: product,
                localProduct: localProduct,
                remote: remote,
                compareSupplier: !supplierFetchFailed,
                compareCategory: !categoryFetchFailed
            )

            let productSupplierDiffs = changes.filter { $0.fieldKey == .supplierName }
            let productCategoryDiffs = changes.filter { $0.fieldKey == .categoryName }
            supplierDiffs.append(contentsOf: productSupplierDiffs)
            categoryDiffs.append(contentsOf: productCategoryDiffs)

            if changes.isEmpty {
                unchangedProducts.append(productSummary(product, classification: .unchanged))
            } else {
                changes.sort { ($0.fieldKey.rawValue, $0.remoteDisplay ?? "") < ($1.fieldKey.rawValue, $1.remoteDisplay ?? "") }
                updateCandidates.append(
                    productSummary(
                        product,
                        classification: .updateCandidate,
                        fieldChanges: changes
                    )
                )
            }
        }

        let priceResult = priceHistoryDiffsAndWarnings(remote: remote, local: local)
        priceHistoryDiffs.append(contentsOf: priceResult.diffs)
        warnings.append(contentsOf: priceResult.warnings)

        let metrics = makeMetrics(
            remote: remote,
            local: local,
            newProducts: newProducts.count,
            updateCandidates: updateCandidates.count,
            conflicts: conflicts.count,
            tombstones: tombstones.count,
            warnings: warnings.count + remote.sourceErrors.count,
            unchanged: unchangedProducts.count
        )

        return SyncPreview(
            generatedAt: Date(),
            outcome: outcome,
            remoteCounts: remote.counts,
            localCounts: local.counts,
            newProducts: newProducts.sorted { $0.sortKey < $1.sortKey },
            updateCandidates: updateCandidates.sorted { $0.sortKey < $1.sortKey },
            conflicts: conflicts.sorted { ($0.barcodeOrKey ?? $0.detail ?? "") < ($1.barcodeOrKey ?? $1.detail ?? "") },
            unchangedProducts: unchangedProducts.sorted { $0.sortKey < $1.sortKey },
            remoteTombstones: tombstones.sorted { $0.sortKey < $1.sortKey },
            supplierDiffs: supplierDiffs.sorted { ($0.barcodeOrKey ?? "") < ($1.barcodeOrKey ?? "") },
            categoryDiffs: categoryDiffs.sorted { ($0.barcodeOrKey ?? "") < ($1.barcodeOrKey ?? "") },
            priceHistoryDiffs: priceHistoryDiffs.sorted { ($0.barcodeOrKey ?? "") < ($1.barcodeOrKey ?? "") },
            warnings: warnings.sorted { ($0.barcodeOrKey ?? $0.detail ?? "") < ($1.barcodeOrKey ?? $1.detail ?? "") },
            metrics: metrics,
            sourceErrors: remote.sourceErrors
        )
    }

    private static func productFieldChanges(
        remoteProduct: RemoteInventoryProductRow,
        localProduct: LocalProductSnapshot,
        remote: RemoteInventorySnapshot,
        compareSupplier: Bool,
        compareCategory: Bool
    ) -> [SyncPreviewFieldChange] {
        let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(remoteProduct.barcode)
        var changes: [SyncPreviewFieldChange] = []

        appendStringChange(
            to: &changes,
            fieldKey: .itemNumber,
            barcode: barcode,
            remoteValue: remoteProduct.itemNumber,
            localValue: localProduct.itemNumber
        )
        appendStringChange(
            to: &changes,
            fieldKey: .productName,
            barcode: barcode,
            remoteValue: remoteProduct.productName,
            localValue: localProduct.productName
        )
        appendStringChange(
            to: &changes,
            fieldKey: .secondProductName,
            barcode: barcode,
            remoteValue: remoteProduct.secondProductName,
            localValue: localProduct.secondProductName
        )
        appendDoubleChange(
            to: &changes,
            fieldKey: .purchasePrice,
            barcode: barcode,
            remoteValue: remoteProduct.purchasePrice,
            localValue: localProduct.purchasePrice
        )
        appendDoubleChange(
            to: &changes,
            fieldKey: .retailPrice,
            barcode: barcode,
            remoteValue: remoteProduct.retailPrice,
            localValue: localProduct.retailPrice
        )
        appendDoubleChange(
            to: &changes,
            fieldKey: .stockQuantity,
            barcode: barcode,
            remoteValue: remoteProduct.stockQuantity,
            localValue: localProduct.stockQuantity
        )

        if compareSupplier {
            appendLookupNameChange(
                to: &changes,
                fieldKey: .supplierName,
                barcode: barcode,
                remoteValue: remote.supplierName(for: remoteProduct),
                localValue: localProduct.supplierName
            )
        }

        if compareCategory {
            appendLookupNameChange(
                to: &changes,
                fieldKey: .categoryName,
                barcode: barcode,
                remoteValue: remote.categoryName(for: remoteProduct),
                localValue: localProduct.categoryName
            )
        }

        return changes
    }

    private static func duplicateRemoteSupplierNames(_ remote: RemoteInventorySnapshot) -> [String] {
        duplicateRemoteNames(
            remote.suppliersByID.values
                .filter { SupabasePullPreviewNormalizer.semanticString($0.deletedAt) == nil }
                .map(\.name)
        )
    }

    private static func duplicateRemoteCategoryNames(_ remote: RemoteInventorySnapshot) -> [String] {
        duplicateRemoteNames(
            remote.categoriesByID.values
                .filter { SupabasePullPreviewNormalizer.semanticString($0.deletedAt) == nil }
                .map(\.name)
        )
    }

    private static func duplicateRemoteNames(_ names: [String]) -> [String] {
        var counts: [String: Int] = [:]
        for name in names {
            guard let key = SupabasePullPreviewNormalizer.normalizedLookupName(name) else {
                continue
            }
            counts[key, default: 0] += 1
        }
        return counts
            .filter { $0.value > 1 }
            .map(\.key)
            .sorted()
    }

    private static func appendStringChange(
        to changes: inout [SyncPreviewFieldChange],
        fieldKey: SyncPreviewFieldKey,
        barcode: String?,
        remoteValue: String?,
        localValue: String?
    ) {
        guard !SupabasePullPreviewNormalizer.stringsEqual(remoteValue, localValue) else { return }
        changes.append(
            SyncPreviewFieldChange(
                fieldKey: fieldKey,
                barcodeOrKey: barcode,
                remoteDisplay: SupabasePullPreviewNormalizer.semanticString(remoteValue),
                localDisplay: SupabasePullPreviewNormalizer.semanticString(localValue)
            )
        )
    }

    private static func appendLookupNameChange(
        to changes: inout [SyncPreviewFieldChange],
        fieldKey: SyncPreviewFieldKey,
        barcode: String?,
        remoteValue: String?,
        localValue: String?
    ) {
        guard !SupabasePullPreviewNormalizer.lookupNamesEqual(remoteValue, localValue) else { return }
        changes.append(
            SyncPreviewFieldChange(
                fieldKey: fieldKey,
                barcodeOrKey: barcode,
                remoteDisplay: SupabasePullPreviewNormalizer.semanticString(remoteValue),
                localDisplay: SupabasePullPreviewNormalizer.semanticString(localValue)
            )
        )
    }

    private static func appendDoubleChange(
        to changes: inout [SyncPreviewFieldChange],
        fieldKey: SyncPreviewFieldKey,
        barcode: String?,
        remoteValue: Double?,
        localValue: Double?
    ) {
        guard !SupabasePullPreviewNormalizer.doublesEqual(remoteValue, localValue) else { return }
        changes.append(
            SyncPreviewFieldChange(
                fieldKey: fieldKey,
                barcodeOrKey: barcode,
                remoteDisplay: SupabasePullPreviewNormalizer.decimalDisplay(remoteValue),
                localDisplay: SupabasePullPreviewNormalizer.decimalDisplay(localValue)
            )
        )
    }

    private static func priceHistoryDiffsAndWarnings(
        remote: RemoteInventorySnapshot,
        local: LocalInventorySnapshot
    ) -> (diffs: [SyncPreviewFieldChange], warnings: [SyncPreviewWarning]) {
        var diffs: [SyncPreviewFieldChange] = []
        var warnings: [SyncPreviewWarning] = []
        let productsByID = Dictionary(uniqueKeysWithValues: remote.products.map { ($0.id, $0) })

        for price in remote.productPrices {
            guard let remoteProduct = productsByID[price.productID],
                  let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(remoteProduct.barcode) else {
                warnings.append(
                    SyncPreviewWarning(
                        code: .priceHistoryUnmatchedProduct,
                        detail: price.productID.uuidString,
                        relatedKey: "inventory_product_prices"
                    )
                )
                continue
            }

            guard let type = SupabasePullPreviewNormalizer.normalizedPriceType(price.type) else {
                warnings.append(
                    SyncPreviewWarning(
                        code: .priceHistoryInvalidType,
                        barcodeOrKey: barcode,
                        detail: price.type,
                        relatedKey: "inventory_product_prices"
                    )
                )
                continue
            }

            guard let effectiveAt = SupabasePullPreviewNormalizer.normalizedEffectiveAt(price.effectiveAt) else {
                warnings.append(
                    SyncPreviewWarning(
                        code: .priceHistoryInvalidEffectiveAt,
                        barcodeOrKey: barcode,
                        relatedKey: "inventory_product_prices"
                    )
                )
                continue
            }

            let key = PriceHistoryLogicalKey(
                barcode: barcode,
                type: type,
                effectiveAt: effectiveAt
            )

            if let localPrice = local.priceHistoryByLogicalKey[key] {
                guard !SupabasePullPreviewNormalizer.doublesEqual(price.price, localPrice.price) else {
                    continue
                }
                diffs.append(
                    SyncPreviewFieldChange(
                        fieldKey: .priceHistory,
                        barcodeOrKey: "\(barcode) / \(type) / \(effectiveAt)",
                        remoteDisplay: SupabasePullPreviewNormalizer.decimalDisplay(price.price),
                        localDisplay: SupabasePullPreviewNormalizer.decimalDisplay(localPrice.price)
                    )
                )
            } else {
                diffs.append(
                    SyncPreviewFieldChange(
                        fieldKey: .priceHistory,
                        barcodeOrKey: "\(barcode) / \(type) / \(effectiveAt)",
                        remoteDisplay: SupabasePullPreviewNormalizer.decimalDisplay(price.price),
                        localDisplay: nil
                    )
                )
            }
        }

        return (diffs, warnings)
    }

    private static func productSummary(
        _ product: RemoteInventoryProductRow,
        classification: SyncPreviewClassification,
        detail: String? = nil,
        fieldChanges: [SyncPreviewFieldChange] = []
    ) -> SyncPreviewProductSummary {
        SyncPreviewProductSummary(
            classification: classification,
            remoteID: product.id,
            barcode: SupabasePullPreviewNormalizer.semanticString(product.barcode),
            productName: SupabasePullPreviewNormalizer.semanticString(product.productName),
            detail: detail,
            fieldChanges: fieldChanges
        )
    }

    private static func makeMetrics(
        remote: RemoteInventorySnapshot,
        local: LocalInventorySnapshot,
        newProducts: Int,
        updateCandidates: Int,
        conflicts: Int,
        tombstones: Int,
        warnings: Int,
        unchanged: Int
    ) -> [SyncPreviewMetric] {
        [
            SyncPreviewMetric(id: "remoteProducts", labelKey: "options.supabase.preview.metric.remoteProducts", value: "\(remote.counts.products)"),
            SyncPreviewMetric(id: "localProducts", labelKey: "options.supabase.preview.metric.localProducts", value: "\(local.counts.products)"),
            SyncPreviewMetric(id: "newProducts", labelKey: "options.supabase.preview.metric.newProducts", value: "\(newProducts)"),
            SyncPreviewMetric(id: "updateCandidates", labelKey: "options.supabase.preview.metric.updateCandidates", value: "\(updateCandidates)"),
            SyncPreviewMetric(id: "conflicts", labelKey: "options.supabase.preview.metric.conflicts", value: "\(conflicts)"),
            SyncPreviewMetric(id: "tombstones", labelKey: "options.supabase.preview.metric.tombstones", value: "\(tombstones)"),
            SyncPreviewMetric(id: "warnings", labelKey: "options.supabase.preview.metric.warnings", value: "\(warnings)"),
            SyncPreviewMetric(id: "unchanged", labelKey: "options.supabase.preview.metric.unchanged", value: "\(unchanged)")
        ]
    }
}

private extension RemoteInventorySnapshot {
    nonisolated func supplierName(for product: RemoteInventoryProductRow) -> String? {
        product.supplierID.flatMap { suppliersByID[$0]?.name }
    }

    nonisolated func categoryName(for product: RemoteInventoryProductRow) -> String? {
        product.categoryID.flatMap { categoriesByID[$0]?.name }
    }
}
