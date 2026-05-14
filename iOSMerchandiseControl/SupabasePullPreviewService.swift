import Foundation
import SwiftData

protocol SupabaseInventoryFetching: Sendable {
    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow]
    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow]
    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow]
    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow]
}

extension SupabaseInventoryService: SupabaseInventoryFetching {}

nonisolated struct SupabasePullPreviewService: Sendable {
    private let inventoryService: any SupabaseInventoryFetching
    private let pageSize: Int
    private let catalogRowBudget: Int?
    private let productPricePreviewSampleLimit: Int?

    init(
        inventoryService: any SupabaseInventoryFetching,
        pageSize: Int = 500,
        catalogRowBudget: Int? = nil,
        productPricePreviewSampleLimit: Int? = 1_000
    ) {
        self.inventoryService = inventoryService
        self.pageSize = max(1, min(pageSize, 1_000))
        self.catalogRowBudget = catalogRowBudget.map { max(0, $0) }
        self.productPricePreviewSampleLimit = productPricePreviewSampleLimit.map { max(0, $0) }
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
        var sourceErrors: [SyncPreviewWarning] = []
        var previewWarnings: [SyncPreviewWarning] = []
        var partialCatalog = false

        let products: [RemoteInventoryProductRow]
        do {
            let result = try await fetchPaged(rowBudget: catalogRowBudget) { from, to in
                try await inventoryService.fetchProductsPage(from: from, to: to)
            }
            products = result.rows
            if result.isPartial {
                partialCatalog = true
                sourceErrors.append(partialBudgetWarning(for: "inventory_products"))
            }
        } catch {
            products = []
            partialCatalog = true
            sourceErrors.append(sourceErrorWarning(for: "inventory_products", error: error))
        }

        async let suppliersFetch = fetchPaged(rowBudget: catalogRowBudget) { from, to in
            try await inventoryService.fetchSuppliersPage(from: from, to: to)
        }
        async let categoriesFetch = fetchPaged(rowBudget: catalogRowBudget) { from, to in
            try await inventoryService.fetchCategoriesPage(from: from, to: to)
        }
        async let productPricesFetch = fetchPaged(rowBudget: productPricePreviewSampleLimit) { from, to in
            try await inventoryService.fetchProductPricesPage(from: from, to: to)
        }

        let suppliers: [RemoteInventorySupplierRow]
        do {
            let result = try await suppliersFetch
            suppliers = result.rows
            if result.isPartial {
                partialCatalog = true
                sourceErrors.append(partialBudgetWarning(for: "inventory_suppliers"))
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
            if result.isPartial {
                partialCatalog = true
                sourceErrors.append(partialBudgetWarning(for: "inventory_categories"))
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
            if result.isPartial {
                previewWarnings.append(
                    SyncPreviewWarning(
                        code: .priceHistoryPagedApplyRequired,
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
                products: products,
                suppliers: suppliers,
                categories: categories,
                productPrices: productPrices,
                sourceErrors: sourceErrors,
                previewWarnings: previewWarnings
            ),
            partialCatalog: partialCatalog
        )
    }

    private func fetchPaged<Row: Sendable>(
        rowBudget: Int?,
        fetchPage: (Int, Int) async throws -> [Row]
    ) async throws -> SupabasePagedFetchResult<Row> {
        try await SupabasePullPreviewPager.fetchAll(
            pageSize: pageSize,
            rowBudget: rowBudget,
            fetchPage: fetchPage
        )
    }

    private func partialBudgetWarning(for table: String) -> SyncPreviewWarning {
#if DEBUG
        debugPrint("[Task108PullPreview] row_budget table=\(table)")
#endif

        return SyncPreviewWarning(
            code: .sourceError,
            detail: table,
            relatedKey: table
        )
    }

    private struct RemoteFetchOutcome: Sendable {
        let snapshot: RemoteInventorySnapshot
        let partialCatalog: Bool
    }
}

nonisolated struct SupabasePagedFetchResult<Row: Sendable>: Sendable {
    let rows: [Row]
    let isPartial: Bool
}

nonisolated enum SupabasePullPreviewPager {
    static func fetchAll<Row: Sendable>(
        pageSize: Int,
        rowBudget: Int?,
        fetchPage: (Int, Int) async throws -> [Row]
    ) async throws -> SupabasePagedFetchResult<Row> {
        var rows: [Row] = []
        var offset = 0
        let clampedPageSize = max(1, min(pageSize, 1_000))

        if let rowBudget, rowBudget <= 0 {
            return SupabasePagedFetchResult(rows: [], isPartial: true)
        }

        while rowBudget.map({ rows.count < $0 }) ?? true {
            let remainingBudget = rowBudget.map { max(0, $0 - rows.count) } ?? clampedPageSize
            let currentPageSize = min(clampedPageSize, remainingBudget)
            guard currentPageSize > 0 else {
                return SupabasePagedFetchResult(rows: rows, isPartial: true)
            }

            let page = try await fetchPage(offset, offset + currentPageSize - 1)
            rows.append(contentsOf: page)

            if page.count < currentPageSize {
                return SupabasePagedFetchResult(rows: rows, isPartial: false)
            }

            offset += currentPageSize
        }

        return SupabasePagedFetchResult(rows: rows, isPartial: true)
    }
}

nonisolated enum SupabaseRemoteDateParser {
    static func parse(_ value: String?) -> Date? {
        guard let value = SupabasePullPreviewNormalizer.semanticString(value) else {
            return nil
        }

        if let date = fractionalFormatter.date(from: value) {
            return date
        }
        if let date = standardFormatter.date(from: value) {
            return date
        }

        return nil
    }

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension SupabasePullPreviewService {
    nonisolated private func sourceErrorWarning(for table: String, error: Error) -> SyncPreviewWarning {
        let detail: String?
        if let serviceError = error as? SupabaseInventoryServiceError,
           let safeDetail = serviceError.safeDiagnosticDetail {
            detail = "\(table): \(safeDetail)"
        } else {
            detail = table
        }

#if DEBUG
        debugPrint("[Task108PullPreview] source_error table=\(table) detail=\(detail ?? "redacted")")
#endif

        return SyncPreviewWarning(
            code: .sourceError,
            detail: detail,
            relatedKey: table
        )
    }
}

nonisolated enum SupabasePullPreviewDiffEngine {
    static func makePreview(
        remote: RemoteInventorySnapshot,
        local: LocalInventorySnapshot,
        outcome: SyncPreviewOutcome
    ) -> SyncPreview {
        var conflicts: [SyncPreviewConflict] = []
        var warnings: [SyncPreviewWarning] = remote.previewWarnings
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

        appendDuplicateRemoteIDConflicts(
            local.duplicateProductRemoteIDs,
            entityKey: "product",
            to: &conflicts
        )
        appendDuplicateRemoteIDConflicts(
            local.duplicateSupplierRemoteIDs,
            entityKey: "supplier",
            to: &conflicts
        )
        appendDuplicateRemoteIDConflicts(
            local.duplicateCategoryRemoteIDs,
            entityKey: "category",
            to: &conflicts
        )

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
                    remote: remote,
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

            if let productWithRemoteID = local.productsByRemoteID[product.id],
               SupabasePullPreviewNormalizer.normalizedBarcode(productWithRemoteID.barcode) != barcode {
                conflicts.append(
                    SyncPreviewConflict(
                        kind: .remoteIDConflict,
                        barcodeOrKey: barcode,
                        detail: product.id.uuidString,
                        relatedRemoteIDs: [product.id],
                        hintKey: "options.supabase.preview.conflict.hint.review"
                    )
                )
                continue
            }

            let productConflicts = unresolvedLookupConflicts(
                product: product,
                barcode: barcode,
                remote: remote,
                local: local,
                supplierFetchFailed: supplierFetchFailed,
                categoryFetchFailed: categoryFetchFailed
            )
            if !productConflicts.isEmpty {
                conflicts.append(contentsOf: productConflicts)
                continue
            }

            guard let localProduct = local.productsByBarcode[barcode] else {
                newProducts.append(productSummary(product, remote: remote, classification: .newProduct))
                continue
            }

            if let localRemoteID = localProduct.remoteID,
               localRemoteID != product.id {
                conflicts.append(
                    SyncPreviewConflict(
                        kind: .remoteIDConflict,
                        barcodeOrKey: barcode,
                        detail: product.id.uuidString,
                        relatedRemoteIDs: [localRemoteID, product.id],
                        hintKey: "options.supabase.preview.conflict.hint.review"
                    )
                )
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

            let metadataNeedsUpdate = productRemoteMetadataNeedsUpdate(
                remoteProduct: product,
                localProduct: localProduct
            )

            if changes.isEmpty && !metadataNeedsUpdate {
                unchangedProducts.append(productSummary(product, remote: remote, classification: .unchanged))
            } else if changes.isEmpty && localProduct.remoteID == nil {
                updateCandidates.append(productSummary(product, remote: remote, classification: .linkOnly))
            } else {
                changes.sort { ($0.fieldKey.rawValue, $0.remoteDisplay ?? "") < ($1.fieldKey.rawValue, $1.remoteDisplay ?? "") }
                updateCandidates.append(
                    productSummary(
                        product,
                        remote: remote,
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

    private static func productRemoteMetadataNeedsUpdate(
        remoteProduct: RemoteInventoryProductRow,
        localProduct: LocalProductSnapshot
    ) -> Bool {
        localProduct.remoteID != remoteProduct.id
            || localProduct.remoteUpdatedAt != SupabaseRemoteDateParser.parse(remoteProduct.updatedAt)
            || localProduct.remoteDeletedAt != SupabaseRemoteDateParser.parse(remoteProduct.deletedAt)
    }

    private static func unresolvedLookupConflicts(
        product: RemoteInventoryProductRow,
        barcode: String,
        remote: RemoteInventorySnapshot,
        local: LocalInventorySnapshot,
        supplierFetchFailed: Bool,
        categoryFetchFailed: Bool
    ) -> [SyncPreviewConflict] {
        var conflicts: [SyncPreviewConflict] = []

        if let supplierID = product.supplierID,
           remote.supplierName(for: product) == nil,
           !supplierFetchFailed {
            conflicts.append(
                SyncPreviewConflict(
                    kind: .missingRemoteReference,
                    barcodeOrKey: barcode,
                    detail: supplierID.uuidString,
                    relatedRemoteIDs: [product.id],
                    hintKey: "options.supabase.preview.conflict.hint.review"
                )
            )
        }

        if let supplierID = product.supplierID,
           let remoteSupplier = remote.suppliersByID[supplierID],
           let supplierConflict = lookupRemoteIDConflict(
                entityKey: "supplier",
                remoteID: supplierID,
                remoteName: remoteSupplier.name,
                localRemoteIDByNormalizedName: local.supplierRemoteIDByNormalizedName,
                localByRemoteID: local.suppliersByRemoteID,
                barcode: barcode,
                productRemoteID: product.id
           ) {
            conflicts.append(supplierConflict)
        }

        if let categoryID = product.categoryID,
           remote.categoryName(for: product) == nil,
           !categoryFetchFailed {
            conflicts.append(
                SyncPreviewConflict(
                    kind: .missingRemoteReference,
                    barcodeOrKey: barcode,
                    detail: categoryID.uuidString,
                    relatedRemoteIDs: [product.id],
                    hintKey: "options.supabase.preview.conflict.hint.review"
                )
            )
        }

        if let categoryID = product.categoryID,
           let remoteCategory = remote.categoriesByID[categoryID],
           let categoryConflict = lookupRemoteIDConflict(
                entityKey: "category",
                remoteID: categoryID,
                remoteName: remoteCategory.name,
                localRemoteIDByNormalizedName: local.categoryRemoteIDByNormalizedName,
                localByRemoteID: local.categoriesByRemoteID,
                barcode: barcode,
                productRemoteID: product.id
           ) {
            conflicts.append(categoryConflict)
        }

        return conflicts
    }

    private static func lookupRemoteIDConflict(
        entityKey: String,
        remoteID: UUID,
        remoteName: String,
        localRemoteIDByNormalizedName: [String: UUID],
        localByRemoteID: [UUID: LocalLookupSnapshot],
        barcode: String,
        productRemoteID: UUID
    ) -> SyncPreviewConflict? {
        let normalizedRemoteName = SupabasePullPreviewNormalizer.normalizedLookupName(remoteName)

        if let normalizedRemoteName,
           let localRemoteID = localRemoteIDByNormalizedName[normalizedRemoteName],
           localRemoteID != remoteID {
            return SyncPreviewConflict(
                kind: .remoteIDConflict,
                barcodeOrKey: barcode,
                detail: "\(entityKey):\(remoteID.uuidString)",
                relatedRemoteIDs: [productRemoteID, localRemoteID, remoteID],
                hintKey: "options.supabase.preview.conflict.hint.review"
            )
        }

        if let localLookup = localByRemoteID[remoteID],
           !SupabasePullPreviewNormalizer.lookupNamesEqual(localLookup.name, remoteName) {
            return SyncPreviewConflict(
                kind: .remoteIDConflict,
                barcodeOrKey: barcode,
                detail: "\(entityKey):\(remoteID.uuidString)",
                relatedRemoteIDs: [productRemoteID, remoteID],
                hintKey: "options.supabase.preview.conflict.hint.review"
            )
        }

        return nil
    }

    private static func appendDuplicateRemoteIDConflicts(
        _ remoteIDs: [UUID],
        entityKey: String,
        to conflicts: inout [SyncPreviewConflict]
    ) {
        for remoteID in remoteIDs {
            conflicts.append(
                SyncPreviewConflict(
                    kind: .remoteIDConflict,
                    barcodeOrKey: entityKey,
                    detail: remoteID.uuidString,
                    relatedRemoteIDs: [remoteID],
                    hintKey: "options.supabase.preview.conflict.hint.review"
                )
            )
        }
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
        remote: RemoteInventorySnapshot,
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
            fieldChanges: fieldChanges,
            applyPayload: SyncPreviewProductApplyPayload(
                remoteID: product.id,
                remoteUpdatedAt: SupabaseRemoteDateParser.parse(product.updatedAt),
                remoteDeletedAt: SupabaseRemoteDateParser.parse(product.deletedAt),
                barcode: SupabasePullPreviewNormalizer.semanticString(product.barcode),
                itemNumber: product.itemNumber,
                productName: product.productName,
                secondProductName: product.secondProductName,
                purchasePrice: product.purchasePrice,
                retailPrice: product.retailPrice,
                stockQuantity: product.stockQuantity,
                supplierName: remote.supplierName(for: product),
                supplierRemoteID: product.supplierID,
                supplierRemoteUpdatedAt: product.supplierID
                    .flatMap { remote.suppliersByID[$0]?.updatedAt }
                    .flatMap(SupabaseRemoteDateParser.parse),
                supplierRemoteDeletedAt: product.supplierID
                    .flatMap { remote.suppliersByID[$0]?.deletedAt }
                    .flatMap(SupabaseRemoteDateParser.parse),
                categoryName: remote.categoryName(for: product),
                categoryRemoteID: product.categoryID,
                categoryRemoteUpdatedAt: product.categoryID
                    .flatMap { remote.categoriesByID[$0]?.updatedAt }
                    .flatMap(SupabaseRemoteDateParser.parse),
                categoryRemoteDeletedAt: product.categoryID
                    .flatMap { remote.categoriesByID[$0]?.deletedAt }
                    .flatMap(SupabaseRemoteDateParser.parse)
            )
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
            SyncPreviewMetric(id: "remoteSuppliers", labelKey: "options.supabase.preview.metric.remoteSuppliers", value: "\(remote.counts.suppliers)"),
            SyncPreviewMetric(id: "remoteCategories", labelKey: "options.supabase.preview.metric.remoteCategories", value: "\(remote.counts.categories)"),
            SyncPreviewMetric(id: "localProducts", labelKey: "options.supabase.preview.metric.localProducts", value: "\(local.counts.products)"),
            SyncPreviewMetric(id: "linkedProducts", labelKey: "options.supabase.preview.metric.linkedProducts", value: "\(local.counts.linkedProducts)"),
            SyncPreviewMetric(id: "linkedSuppliers", labelKey: "options.supabase.preview.metric.linkedSuppliers", value: "\(local.counts.linkedSuppliers)"),
            SyncPreviewMetric(id: "linkedCategories", labelKey: "options.supabase.preview.metric.linkedCategories", value: "\(local.counts.linkedCategories)"),
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
