import Foundation
import SwiftData

nonisolated struct SupabasePullApplyOptions: Sendable, Equatable {
    var applyStockQuantity: Bool

    init(applyStockQuantity: Bool = false) {
        self.applyStockQuantity = applyStockQuantity
    }
}

nonisolated enum SupabasePullApplyDisabledReason: String, Sendable, Equatable {
    case sessionMissing
    case partialPreview
    case sourceErrorsPresent
    case priceHistoryIncomplete
    case conflictsPresent
    case localDuplicateBarcode
    case missingApplicablePayload
    case missingRequiredField
    case invalidPrice
    case invalidStockQuantity
    case previewStale
    case noApplicableChanges
}

nonisolated enum SupabasePullApplyError: Error, Sendable, Equatable {
    case sessionMissing
    case partialPreview
    case sourceErrorsPresent
    case priceHistoryIncomplete
    case conflictsPresent
    case localDuplicateBarcode
    case missingApplicablePayload(barcode: String?)
    case missingRequiredField(barcode: String?, field: String)
    case invalidPrice(barcode: String?, field: SyncPreviewFieldKey)
    case invalidStockQuantity(barcode: String?)
    case previewStale
    case noApplicableChanges
    case localSnapshotFailed(message: String?)
    case saveFailed(message: String?)

    var disabledReason: SupabasePullApplyDisabledReason {
        switch self {
        case .sessionMissing:
            return .sessionMissing
        case .partialPreview:
            return .partialPreview
        case .sourceErrorsPresent:
            return .sourceErrorsPresent
        case .priceHistoryIncomplete:
            return .priceHistoryIncomplete
        case .conflictsPresent:
            return .conflictsPresent
        case .localDuplicateBarcode:
            return .localDuplicateBarcode
        case .missingApplicablePayload:
            return .missingApplicablePayload
        case .missingRequiredField:
            return .missingRequiredField
        case .invalidPrice:
            return .invalidPrice
        case .invalidStockQuantity:
            return .invalidStockQuantity
        case .previewStale:
            return .previewStale
        case .noApplicableChanges:
            return .noApplicableChanges
        case .localSnapshotFailed, .saveFailed:
            return .previewStale
        }
    }
}

nonisolated struct SupabasePullApplyResult: Sendable, Equatable {
    let inserted: Int
    let updated: Int
    let suppliersCreated: Int
    let categoriesCreated: Int
}

nonisolated struct SupabasePullApplyPlan: Sendable, Equatable {
    let generatedAt: Date
    let options: SupabasePullApplyOptions
    let expectedProductStates: [SupabasePullApplyExpectedProductState]
    let suppliersToCreate: [SupabasePullApplyLookup]
    let categoriesToCreate: [SupabasePullApplyLookup]
    let productInserts: [SupabasePullApplyProductInsert]
    let productUpdates: [SupabasePullApplyProductUpdate]

    var plannedInsertedCount: Int { productInserts.count }
    var plannedUpdatedCount: Int { productUpdates.count }
}

nonisolated struct SupabasePullApplyExpectedProductState: Sendable, Equatable {
    let barcode: String
    let fingerprint: SupabasePullApplyProductFingerprint?
}

nonisolated struct SupabasePullApplyLookup: Sendable, Equatable {
    let normalizedName: String
    let displayName: String
}

nonisolated struct SupabasePullApplyProductInsert: Sendable, Equatable {
    let barcode: String
    let payload: SyncPreviewProductApplyPayload
}

nonisolated struct SupabasePullApplyProductUpdate: Sendable, Equatable {
    let barcode: String
    let payload: SyncPreviewProductApplyPayload
    let expectedFingerprint: SupabasePullApplyProductFingerprint
}

nonisolated struct SupabasePullApplyProductFingerprint: Sendable, Equatable {
    let barcode: String
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let stockQuantity: Double?
    let supplierLookupName: String?
    let categoryLookupName: String?

    init(snapshot: LocalProductSnapshot) {
        barcode = SupabasePullPreviewNormalizer.normalizedBarcode(snapshot.barcode) ?? snapshot.barcode
        itemNumber = SupabasePullPreviewNormalizer.semanticString(snapshot.itemNumber)
        productName = SupabasePullPreviewNormalizer.semanticString(snapshot.productName)
        secondProductName = SupabasePullPreviewNormalizer.semanticString(snapshot.secondProductName)
        purchasePrice = snapshot.purchasePrice
        retailPrice = snapshot.retailPrice
        stockQuantity = snapshot.stockQuantity
        supplierLookupName = SupabasePullPreviewNormalizer.normalizedLookupName(snapshot.supplierName)
        categoryLookupName = SupabasePullPreviewNormalizer.normalizedLookupName(snapshot.categoryName)
    }

    func matches(_ snapshot: LocalProductSnapshot) -> Bool {
        guard barcode == SupabasePullPreviewNormalizer.normalizedBarcode(snapshot.barcode) else {
            return false
        }

        return SupabasePullPreviewNormalizer.semanticString(snapshot.itemNumber) == itemNumber
            && SupabasePullPreviewNormalizer.semanticString(snapshot.productName) == productName
            && SupabasePullPreviewNormalizer.semanticString(snapshot.secondProductName) == secondProductName
            && SupabasePullPreviewNormalizer.doublesEqual(snapshot.purchasePrice, purchasePrice)
            && SupabasePullPreviewNormalizer.doublesEqual(snapshot.retailPrice, retailPrice)
            && SupabasePullPreviewNormalizer.doublesEqual(snapshot.stockQuantity, stockQuantity)
            && SupabasePullPreviewNormalizer.normalizedLookupName(snapshot.supplierName) == supplierLookupName
            && SupabasePullPreviewNormalizer.normalizedLookupName(snapshot.categoryName) == categoryLookupName
    }
}

@MainActor
struct SupabasePullApplyService {
    init() {}

    /// Not re-entrant on the same ModelContext; the DEBUG UI serializes calls with isApplyingLocalPreview.
    func prepareApplyPlan(
        preview: SyncPreview,
        context: ModelContext,
        options: SupabasePullApplyOptions = SupabasePullApplyOptions(),
        isAuthenticated: Bool
    ) throws -> SupabasePullApplyPlan {
        try validateGlobalGuards(preview: preview, isAuthenticated: isAuthenticated)

        let snapshot: LocalInventorySnapshot
        do {
            snapshot = try SwiftDataInventorySnapshotService(context: context).makeSnapshot()
        } catch {
            throw SupabasePullApplyError.localSnapshotFailed(message: String(describing: error))
        }

        if !snapshot.duplicateProductBarcodes.isEmpty {
            throw SupabasePullApplyError.localDuplicateBarcode
        }

        var inserts: [SupabasePullApplyProductInsert] = []
        var updates: [SupabasePullApplyProductUpdate] = []
        var expectedStates: [SupabasePullApplyExpectedProductState] = []

        for summary in preview.newProducts.sorted(by: productSort) {
            guard let payload = summary.applyPayload else {
                throw SupabasePullApplyError.missingApplicablePayload(barcode: summary.barcode)
            }

            try validateNumbers(payload: payload, options: options)

            guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(payload.barcode) else {
                throw SupabasePullApplyError.missingRequiredField(barcode: summary.barcode, field: "barcode")
            }

            guard snapshot.productsByBarcode[barcode] == nil else {
                throw SupabasePullApplyError.previewStale
            }

            let primaryName = SupabasePullPreviewNormalizer.semanticString(payload.productName)
            let secondaryName = SupabasePullPreviewNormalizer.semanticString(payload.secondProductName)
            guard primaryName != nil || secondaryName != nil else {
                throw SupabasePullApplyError.missingRequiredField(barcode: barcode, field: "productName")
            }

            inserts.append(SupabasePullApplyProductInsert(barcode: barcode, payload: payload))
            expectedStates.append(SupabasePullApplyExpectedProductState(barcode: barcode, fingerprint: nil))
        }

        for summary in preview.updateCandidates.sorted(by: productSort) {
            guard let payload = summary.applyPayload else {
                throw SupabasePullApplyError.missingApplicablePayload(barcode: summary.barcode)
            }

            try validateNumbers(payload: payload, options: options)

            guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(summary.barcode ?? payload.barcode) else {
                throw SupabasePullApplyError.missingRequiredField(barcode: summary.barcode, field: "barcode")
            }

            guard let localProduct = snapshot.productsByBarcode[barcode] else {
                throw SupabasePullApplyError.previewStale
            }

            guard hasApplicableUpdate(payload: payload, local: localProduct, options: options) else {
                continue
            }

            let fingerprint = SupabasePullApplyProductFingerprint(snapshot: localProduct)
            updates.append(
                SupabasePullApplyProductUpdate(
                    barcode: barcode,
                    payload: payload,
                    expectedFingerprint: fingerprint
                )
            )
            expectedStates.append(SupabasePullApplyExpectedProductState(barcode: barcode, fingerprint: fingerprint))
        }

        guard !inserts.isEmpty || !updates.isEmpty else {
            throw SupabasePullApplyError.noApplicableChanges
        }

        let suppliersToCreate = lookupsToCreate(
            from: inserts.map(\.payload) + updates.map(\.payload),
            existing: snapshot.suppliersByNormalizedName,
            value: \.supplierName
        )
        let categoriesToCreate = lookupsToCreate(
            from: inserts.map(\.payload) + updates.map(\.payload),
            existing: snapshot.categoriesByNormalizedName,
            value: \.categoryName
        )

        return SupabasePullApplyPlan(
            generatedAt: preview.generatedAt,
            options: options,
            expectedProductStates: expectedStates.sorted { $0.barcode < $1.barcode },
            suppliersToCreate: suppliersToCreate,
            categoriesToCreate: categoriesToCreate,
            productInserts: inserts.sorted { $0.barcode < $1.barcode },
            productUpdates: updates.sorted { $0.barcode < $1.barcode }
        )
    }

    func apply(plan: SupabasePullApplyPlan, context: ModelContext) throws -> SupabasePullApplyResult {
        guard !plan.productInserts.isEmpty || !plan.productUpdates.isEmpty else {
            throw SupabasePullApplyError.noApplicableChanges
        }

        try validateNotStale(plan: plan, context: context)

        var productsByBarcode = try fetchProductsByBarcode(context: context)
        var suppliersByName = try fetchSuppliersByNormalizedName(context: context)
        var categoriesByName = try fetchCategoriesByNormalizedName(context: context)

        var inserted = 0
        var updated = 0
        var suppliersCreated = 0
        var categoriesCreated = 0

        for supplier in plan.suppliersToCreate {
            _ = try resolveSupplier(
                named: supplier.displayName,
                context: context,
                cache: &suppliersByName,
                createdCount: &suppliersCreated
            )
        }

        for category in plan.categoriesToCreate {
            _ = try resolveCategory(
                named: category.displayName,
                context: context,
                cache: &categoriesByName,
                createdCount: &categoriesCreated
            )
        }

        for insert in plan.productInserts {
            guard productsByBarcode[insert.barcode] == nil else {
                throw SupabasePullApplyError.previewStale
            }

            let supplier = try resolveSupplier(
                named: insert.payload.supplierName,
                context: context,
                cache: &suppliersByName,
                createdCount: &suppliersCreated
            )
            let category = try resolveCategory(
                named: insert.payload.categoryName,
                context: context,
                cache: &categoriesByName,
                createdCount: &categoriesCreated
            )
            let product = Product(
                barcode: insert.barcode,
                itemNumber: SupabasePullPreviewNormalizer.semanticString(insert.payload.itemNumber),
                productName: SupabasePullPreviewNormalizer.semanticString(insert.payload.productName),
                secondProductName: SupabasePullPreviewNormalizer.semanticString(insert.payload.secondProductName),
                purchasePrice: insert.payload.purchasePrice,
                retailPrice: insert.payload.retailPrice,
                stockQuantity: plan.options.applyStockQuantity ? insert.payload.stockQuantity : nil,
                supplier: supplier,
                category: category
            )

            context.insert(product)
            productsByBarcode[insert.barcode] = product
            inserted += 1
        }

        for update in plan.productUpdates {
            guard let product = productsByBarcode[update.barcode] else {
                throw SupabasePullApplyError.previewStale
            }

            var didMutate = false
            try applyPayload(
                update.payload,
                to: product,
                options: plan.options,
                context: context,
                suppliersByName: &suppliersByName,
                categoriesByName: &categoriesByName,
                suppliersCreated: &suppliersCreated,
                categoriesCreated: &categoriesCreated,
                didMutate: &didMutate
            )

            if didMutate {
                updated += 1
            }
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw SupabasePullApplyError.saveFailed(message: String(describing: error))
        }

        return SupabasePullApplyResult(
            inserted: inserted,
            updated: updated,
            suppliersCreated: suppliersCreated,
            categoriesCreated: categoriesCreated
        )
    }

    private func validateGlobalGuards(preview: SyncPreview, isAuthenticated: Bool) throws {
        guard isAuthenticated else {
            throw SupabasePullApplyError.sessionMissing
        }

        guard preview.outcome == .success else {
            throw SupabasePullApplyError.partialPreview
        }

        if containsPriceHistoryIncomplete(preview) {
            throw SupabasePullApplyError.priceHistoryIncomplete
        }

        if !preview.sourceErrors.isEmpty {
            throw SupabasePullApplyError.sourceErrorsPresent
        }

        if preview.conflicts.contains(where: { $0.kind == .localDuplicateBarcode }) {
            throw SupabasePullApplyError.localDuplicateBarcode
        }

        if !preview.conflicts.isEmpty {
            throw SupabasePullApplyError.conflictsPresent
        }
    }

    private func containsPriceHistoryIncomplete(_ preview: SyncPreview) -> Bool {
        (preview.warnings + preview.sourceErrors).contains { $0.code == .priceHistoryIncomplete }
    }

    private func validateNumbers(
        payload: SyncPreviewProductApplyPayload,
        options: SupabasePullApplyOptions
    ) throws {
        try validatePrice(payload.purchasePrice, barcode: payload.barcode, field: .purchasePrice)
        try validatePrice(payload.retailPrice, barcode: payload.barcode, field: .retailPrice)

        if options.applyStockQuantity,
           let stockQuantity = payload.stockQuantity,
           !isValidFiniteNonNegative(stockQuantity) {
            throw SupabasePullApplyError.invalidStockQuantity(barcode: payload.barcode)
        }
    }

    private func validatePrice(
        _ value: Double?,
        barcode: String?,
        field: SyncPreviewFieldKey
    ) throws {
        guard let value else { return }
        guard isValidFiniteNonNegative(value) else {
            throw SupabasePullApplyError.invalidPrice(barcode: barcode, field: field)
        }
    }

    private func isValidFiniteNonNegative(_ value: Double) -> Bool {
        value.isFinite && !value.isNaN && value >= 0
    }

    private func hasApplicableUpdate(
        payload: SyncPreviewProductApplyPayload,
        local: LocalProductSnapshot,
        options: SupabasePullApplyOptions
    ) -> Bool {
        if let itemNumber = SupabasePullPreviewNormalizer.semanticString(payload.itemNumber),
           !SupabasePullPreviewNormalizer.stringsEqual(itemNumber, local.itemNumber) {
            return true
        }
        if let productName = SupabasePullPreviewNormalizer.semanticString(payload.productName),
           !SupabasePullPreviewNormalizer.stringsEqual(productName, local.productName) {
            return true
        }
        if let secondProductName = SupabasePullPreviewNormalizer.semanticString(payload.secondProductName),
           !SupabasePullPreviewNormalizer.stringsEqual(secondProductName, local.secondProductName) {
            return true
        }
        if let purchasePrice = payload.purchasePrice,
           !SupabasePullPreviewNormalizer.doublesEqual(purchasePrice, local.purchasePrice) {
            return true
        }
        if let retailPrice = payload.retailPrice,
           !SupabasePullPreviewNormalizer.doublesEqual(retailPrice, local.retailPrice) {
            return true
        }
        if options.applyStockQuantity,
           let stockQuantity = payload.stockQuantity,
           !SupabasePullPreviewNormalizer.doublesEqual(stockQuantity, local.stockQuantity) {
            return true
        }
        if let supplierName = SupabasePullPreviewNormalizer.semanticString(payload.supplierName),
           !SupabasePullPreviewNormalizer.lookupNamesEqual(supplierName, local.supplierName) {
            return true
        }
        if let categoryName = SupabasePullPreviewNormalizer.semanticString(payload.categoryName),
           !SupabasePullPreviewNormalizer.lookupNamesEqual(categoryName, local.categoryName) {
            return true
        }

        return false
    }

    private func validateNotStale(plan: SupabasePullApplyPlan, context: ModelContext) throws {
        let snapshot: LocalInventorySnapshot
        do {
            snapshot = try SwiftDataInventorySnapshotService(context: context).makeSnapshot()
        } catch {
            throw SupabasePullApplyError.localSnapshotFailed(message: String(describing: error))
        }

        if !snapshot.duplicateProductBarcodes.isEmpty {
            throw SupabasePullApplyError.localDuplicateBarcode
        }

        for expected in plan.expectedProductStates {
            let current = snapshot.productsByBarcode[expected.barcode]
            switch (expected.fingerprint, current) {
            case (.none, .none):
                continue
            case let (.some(fingerprint), .some(product)) where fingerprint.matches(product):
                continue
            default:
                throw SupabasePullApplyError.previewStale
            }
        }
    }

    private func applyPayload(
        _ payload: SyncPreviewProductApplyPayload,
        to product: Product,
        options: SupabasePullApplyOptions,
        context: ModelContext,
        suppliersByName: inout [String: Supplier],
        categoriesByName: inout [String: ProductCategory],
        suppliersCreated: inout Int,
        categoriesCreated: inout Int,
        didMutate: inout Bool
    ) throws {
        if let itemNumber = SupabasePullPreviewNormalizer.semanticString(payload.itemNumber),
           !SupabasePullPreviewNormalizer.stringsEqual(itemNumber, product.itemNumber) {
            product.itemNumber = itemNumber
            didMutate = true
        }

        if let productName = SupabasePullPreviewNormalizer.semanticString(payload.productName),
           !SupabasePullPreviewNormalizer.stringsEqual(productName, product.productName) {
            product.productName = productName
            didMutate = true
        }

        if let secondProductName = SupabasePullPreviewNormalizer.semanticString(payload.secondProductName),
           !SupabasePullPreviewNormalizer.stringsEqual(secondProductName, product.secondProductName) {
            product.secondProductName = secondProductName
            didMutate = true
        }

        if let purchasePrice = payload.purchasePrice,
           !SupabasePullPreviewNormalizer.doublesEqual(purchasePrice, product.purchasePrice) {
            product.purchasePrice = purchasePrice
            didMutate = true
        }

        if let retailPrice = payload.retailPrice,
           !SupabasePullPreviewNormalizer.doublesEqual(retailPrice, product.retailPrice) {
            product.retailPrice = retailPrice
            didMutate = true
        }

        if options.applyStockQuantity,
           let stockQuantity = payload.stockQuantity,
           !SupabasePullPreviewNormalizer.doublesEqual(stockQuantity, product.stockQuantity) {
            product.stockQuantity = stockQuantity
            didMutate = true
        }

        if SupabasePullPreviewNormalizer.semanticString(payload.supplierName) != nil,
           !SupabasePullPreviewNormalizer.lookupNamesEqual(payload.supplierName, product.supplier?.name) {
            product.supplier = try resolveSupplier(
                named: payload.supplierName,
                context: context,
                cache: &suppliersByName,
                createdCount: &suppliersCreated
            )
            didMutate = true
        }

        if SupabasePullPreviewNormalizer.semanticString(payload.categoryName) != nil,
           !SupabasePullPreviewNormalizer.lookupNamesEqual(payload.categoryName, product.category?.name) {
            product.category = try resolveCategory(
                named: payload.categoryName,
                context: context,
                cache: &categoriesByName,
                createdCount: &categoriesCreated
            )
            didMutate = true
        }
    }

    private func resolveSupplier(
        named name: String?,
        context: ModelContext,
        cache: inout [String: Supplier],
        createdCount: inout Int
    ) throws -> Supplier? {
        guard let displayName = SupabasePullPreviewNormalizer.semanticString(name),
              let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(displayName) else {
            return nil
        }

        if let existing = cache[normalizedName] {
            return existing
        }

        cache = try fetchSuppliersByNormalizedName(context: context)
        if let existing = cache[normalizedName] {
            return existing
        }

        let supplier = Supplier(name: displayName)
        context.insert(supplier)
        cache[normalizedName] = supplier
        createdCount += 1
        return supplier
    }

    private func resolveCategory(
        named name: String?,
        context: ModelContext,
        cache: inout [String: ProductCategory],
        createdCount: inout Int
    ) throws -> ProductCategory? {
        guard let displayName = SupabasePullPreviewNormalizer.semanticString(name),
              let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(displayName) else {
            return nil
        }

        if let existing = cache[normalizedName] {
            return existing
        }

        cache = try fetchCategoriesByNormalizedName(context: context)
        if let existing = cache[normalizedName] {
            return existing
        }

        let category = ProductCategory(name: displayName)
        context.insert(category)
        cache[normalizedName] = category
        createdCount += 1
        return category
    }

    private func fetchProductsByBarcode(context: ModelContext) throws -> [String: Product] {
        let products = try context.fetch(
            FetchDescriptor<Product>(
                sortBy: [SortDescriptor(\Product.barcode)]
            )
        )

        var result: [String: Product] = [:]
        for product in products {
            guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(product.barcode),
                  result[barcode] == nil else {
                continue
            }
            result[barcode] = product
        }
        return result
    }

    private func fetchSuppliersByNormalizedName(context: ModelContext) throws -> [String: Supplier] {
        let suppliers = try context.fetch(
            FetchDescriptor<Supplier>(
                sortBy: [SortDescriptor(\Supplier.name)]
            )
        )

        var result: [String: Supplier] = [:]
        for supplier in suppliers {
            guard let name = SupabasePullPreviewNormalizer.normalizedLookupName(supplier.name),
                  result[name] == nil else {
                continue
            }
            result[name] = supplier
        }
        return result
    }

    private func fetchCategoriesByNormalizedName(context: ModelContext) throws -> [String: ProductCategory] {
        let categories = try context.fetch(
            FetchDescriptor<ProductCategory>(
                sortBy: [SortDescriptor(\ProductCategory.name)]
            )
        )

        var result: [String: ProductCategory] = [:]
        for category in categories {
            guard let name = SupabasePullPreviewNormalizer.normalizedLookupName(category.name),
                  result[name] == nil else {
                continue
            }
            result[name] = category
        }
        return result
    }

    private func lookupsToCreate(
        from payloads: [SyncPreviewProductApplyPayload],
        existing: [String: String],
        value: KeyPath<SyncPreviewProductApplyPayload, String?>
    ) -> [SupabasePullApplyLookup] {
        var pending: [String: String] = [:]

        for payload in payloads {
            guard let displayName = SupabasePullPreviewNormalizer.semanticString(payload[keyPath: value]),
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(displayName),
                  existing[normalizedName] == nil,
                  pending[normalizedName] == nil else {
                continue
            }

            pending[normalizedName] = displayName
        }

        return pending
            .map { SupabasePullApplyLookup(normalizedName: $0.key, displayName: $0.value) }
            .sorted { $0.normalizedName < $1.normalizedName }
    }

    private func productSort(
        lhs: SyncPreviewProductSummary,
        rhs: SyncPreviewProductSummary
    ) -> Bool {
        lhs.sortKey < rhs.sortKey
    }
}
