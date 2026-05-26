import Foundation
import SwiftData

nonisolated struct SupabasePullApplyOptions: Sendable, Equatable {
    var applyStockQuantity: Bool
    var allowLookupOnlyApplyWhenProductConflicts: Bool
    var isCompleteRemoteSnapshot: Bool

    init(
        applyStockQuantity: Bool = false,
        allowLookupOnlyApplyWhenProductConflicts: Bool = true,
        isCompleteRemoteSnapshot: Bool = true
    ) {
        self.applyStockQuantity = applyStockQuantity
        self.allowLookupOnlyApplyWhenProductConflicts = allowLookupOnlyApplyWhenProductConflicts
        self.isCompleteRemoteSnapshot = isCompleteRemoteSnapshot
    }
}

nonisolated enum SupabasePullApplyDisabledReason: String, Sendable, Equatable {
    case sessionMissing
    case accountMismatch
    case partialPreview
    case sourceErrorsPresent
    case priceHistoryIncomplete
    case conflictsPresent
    case localDuplicateBarcode
    case missingApplicablePayload
    case missingRequiredField
    case invalidLocalData
    case invalidPrice
    case invalidStockQuantity
    case previewStale
    case noApplicableChanges
}

nonisolated enum SupabasePullApplyError: Error, Sendable, Equatable {
    case sessionMissing
    case accountMismatch
    case partialPreview
    case sourceErrorsPresent
    case priceHistoryIncomplete
    case conflictsPresent
    case localDuplicateBarcode
    case missingApplicablePayload(barcode: String?)
    case missingRequiredField(barcode: String?, field: String)
    case invalidLocalData
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
        case .accountMismatch:
            return .accountMismatch
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
        case .invalidLocalData:
            return .invalidLocalData
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
    let productTombstoned: Int
    let productPruned: Int

    init(
        inserted: Int,
        updated: Int,
        suppliersCreated: Int,
        categoriesCreated: Int,
        productTombstoned: Int = 0,
        productPruned: Int = 0
    ) {
        self.inserted = inserted
        self.updated = updated
        self.suppliersCreated = suppliersCreated
        self.categoriesCreated = categoriesCreated
        self.productTombstoned = productTombstoned
        self.productPruned = productPruned
    }
}

nonisolated struct SupabasePullApplyProgress: Sendable, Equatable {
    enum Stage: String, Sendable, Equatable {
        case suppliers
        case categories
        case products
        case saving
        case completed
    }

    let stage: Stage
    let current: Int
    let total: Int

    init(stage: Stage, current: Int, total: Int) {
        self.stage = stage
        self.current = max(0, current)
        self.total = max(0, total)
    }
}

nonisolated struct SupabasePullApplyPlan: Sendable, Equatable {
    let generatedAt: Date
    let options: SupabasePullApplyOptions
    let expectedProductStates: [SupabasePullApplyExpectedProductState]
    let suppliersToCreate: [SupabasePullApplyLookup]
    let categoriesToCreate: [SupabasePullApplyLookup]
    let productInserts: [SupabasePullApplyProductInsert]
    let productUpdates: [SupabasePullApplyProductUpdate]
    let productTombstones: [SupabasePullApplyProductTombstone]
    let productPrunes: [SupabasePullApplyProductPrune]
    let remoteSupplierIDs: Set<UUID>
    let remoteCategoryIDs: Set<UUID>
    let shouldPruneUnreferencedCleanLookups: Bool

    var plannedInsertedCount: Int { productInserts.count }
    var plannedUpdatedCount: Int { productUpdates.count }
    var plannedProductMutationCount: Int { productInserts.count + productUpdates.count + productTombstones.count + productPrunes.count }
}

nonisolated struct SupabasePullApplyExpectedProductState: Sendable, Equatable {
    let barcode: String
    let fingerprint: SupabasePullApplyProductFingerprint?
}

nonisolated struct SupabasePullApplyLookup: Sendable, Equatable {
    let normalizedName: String
    let displayName: String
    let remoteID: UUID?
    let remoteUpdatedAt: Date?
    let remoteDeletedAt: Date?

    init(
        normalizedName: String,
        displayName: String,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil
    ) {
        self.normalizedName = normalizedName
        self.displayName = displayName
        self.remoteID = remoteID
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteDeletedAt = remoteDeletedAt
    }
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

nonisolated struct SupabasePullApplyProductTombstone: Sendable, Equatable {
    let barcode: String
    let payload: SyncPreviewProductApplyPayload
    let expectedFingerprint: SupabasePullApplyProductFingerprint
}

nonisolated struct SupabasePullApplyProductPrune: Sendable, Equatable {
    let barcode: String
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
    let remoteID: UUID?
    let remoteUpdatedAt: Date?
    let remoteDeletedAt: Date?

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
        remoteID = snapshot.remoteID
        remoteUpdatedAt = snapshot.remoteUpdatedAt
        remoteDeletedAt = snapshot.remoteDeletedAt
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
            && snapshot.remoteID == remoteID
            && snapshot.remoteUpdatedAt == remoteUpdatedAt
            && snapshot.remoteDeletedAt == remoteDeletedAt
    }
}

nonisolated struct SupabasePullApplyAccountGuard: Sendable, Equatable {
    let currentUserID: UUID?
    let lastLinkedUserID: UUID?

    init(currentUserID: UUID?, lastLinkedUserID: UUID?) {
        self.currentUserID = currentUserID
        self.lastLinkedUserID = lastLinkedUserID
    }

    var hasMismatch: Bool {
        guard currentUserID != nil || lastLinkedUserID != nil else {
            return false
        }
        return currentUserID != lastLinkedUserID
    }
}

nonisolated struct SupabasePullApplyService: Sendable {
    init() {}

    /// Not re-entrant on the same ModelContext; the DEBUG UI serializes calls with isApplyingLocalPreview.
    func prepareApplyPlan(
        preview: SyncPreview,
        context: ModelContext,
        options: SupabasePullApplyOptions = SupabasePullApplyOptions(),
        isAuthenticated: Bool,
        accountGuard: SupabasePullApplyAccountGuard? = nil
    ) throws -> SupabasePullApplyPlan {
        try validateGlobalGuards(
            preview: preview,
            isAuthenticated: isAuthenticated,
            accountGuard: accountGuard,
            options: options
        )

        let snapshot: LocalInventorySnapshot
        do {
            snapshot = try SwiftDataInventorySnapshotService(context: context).makeSnapshot()
        } catch {
            throw SupabasePullApplyError.localSnapshotFailed(message: String(describing: error))
        }

        if !snapshot.duplicateProductBarcodes.isEmpty {
            throw SupabasePullApplyError.localDuplicateBarcode
        }
        try validateLocalInvariants(snapshot)
        let pendingProductChanges = try pendingProductChanges(
            context: context,
            ownerUserID: accountGuard?.currentUserID
        )

        var inserts: [SupabasePullApplyProductInsert] = []
        var updates: [SupabasePullApplyProductUpdate] = []
        var tombstones: [SupabasePullApplyProductTombstone] = []
        var expectedStates: [SupabasePullApplyExpectedProductState] = []

        let shouldSkipProductMutationsDueToConflicts =
            options.allowLookupOnlyApplyWhenProductConflicts && !preview.conflicts.isEmpty

        if !shouldSkipProductMutationsDueToConflicts {
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

                if let localRemoteID = localProduct.remoteID,
                   localRemoteID != payload.remoteID {
                    throw SupabasePullApplyError.previewStale
                }

                if hasPendingLocalProductChange(
                    payload: payload,
                    barcode: barcode,
                    pendingChanges: pendingProductChanges
                ) {
                    continue
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

            for summary in preview.remoteTombstones.sorted(by: productSort) {
                guard let payload = summary.applyPayload else {
                    throw SupabasePullApplyError.missingApplicablePayload(barcode: summary.barcode)
                }

                guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(summary.barcode ?? payload.barcode) else {
                    throw SupabasePullApplyError.missingRequiredField(barcode: summary.barcode, field: "barcode")
                }

                guard let localProduct = snapshot.productsByBarcode[barcode] else {
                    continue
                }

                if let localRemoteID = localProduct.remoteID,
                   localRemoteID != payload.remoteID {
                    throw SupabasePullApplyError.previewStale
                }

                if hasPendingLocalProductChange(
                    payload: payload,
                    barcode: barcode,
                    pendingChanges: pendingProductChanges
                ) {
                    continue
                }

                guard localProduct.remoteDeletedAt != (payload.remoteDeletedAt ?? localProduct.remoteDeletedAt)
                        || localProduct.remoteUpdatedAt != payload.remoteUpdatedAt
                        || localProduct.remoteID != payload.remoteID else {
                    continue
                }

                let fingerprint = SupabasePullApplyProductFingerprint(snapshot: localProduct)
                tombstones.append(
                    SupabasePullApplyProductTombstone(
                        barcode: barcode,
                        payload: payload,
                        expectedFingerprint: fingerprint
                    )
                )
                expectedStates.append(SupabasePullApplyExpectedProductState(barcode: barcode, fingerprint: fingerprint))
            }
        }

        let productPrunes = shouldSkipProductMutationsDueToConflicts || !options.isCompleteRemoteSnapshot
            ? []
            : cleanProductPrunes(
                preview: preview,
                snapshot: snapshot,
                pendingChanges: pendingProductChanges
            )
        expectedStates.append(
            contentsOf: productPrunes.map {
                SupabasePullApplyExpectedProductState(barcode: $0.barcode, fingerprint: $0.expectedFingerprint)
            }
        )

        let applicablePayloads = inserts.map(\.payload) + updates.map(\.payload)
        let suppliersToCreate = lookupsToCreate(
            lookupsToCreate(
                from: applicablePayloads,
                existing: snapshot.suppliersByNormalizedName,
                existingRemoteIDs: Set(snapshot.suppliersByRemoteID.keys),
                value: \.supplierName,
                remoteID: \.supplierRemoteID,
                remoteUpdatedAt: \.supplierRemoteUpdatedAt,
                remoteDeletedAt: \.supplierRemoteDeletedAt
            ) + lookupsToCreate(
                from: preview.remoteSupplierLookups,
                existing: snapshot.suppliersByNormalizedName,
                existingRemoteIDs: Set(snapshot.suppliersByRemoteID.keys)
            )
        )
        let categoriesToCreate = lookupsToCreate(
            lookupsToCreate(
                from: applicablePayloads,
                existing: snapshot.categoriesByNormalizedName,
                existingRemoteIDs: Set(snapshot.categoriesByRemoteID.keys),
                value: \.categoryName,
                remoteID: \.categoryRemoteID,
                remoteUpdatedAt: \.categoryRemoteUpdatedAt,
                remoteDeletedAt: \.categoryRemoteDeletedAt
            ) + lookupsToCreate(
                from: preview.remoteCategoryLookups,
                existing: snapshot.categoriesByNormalizedName,
                existingRemoteIDs: Set(snapshot.categoriesByRemoteID.keys)
            )
        )

        let hasPrunableCleanLookups = options.isCompleteRemoteSnapshot
            ? try hasPrunableUnreferencedCleanLookups(
                context: context,
                remoteSupplierIDs: preview.remoteSupplierIDs,
                remoteCategoryIDs: preview.remoteCategoryIDs
            )
            : false
        let shouldPruneUnreferencedCleanLookups =
            options.isCompleteRemoteSnapshot
                && inserts.isEmpty
                && updates.isEmpty
                && tombstones.isEmpty
                && (hasPrunableCleanLookups || !productPrunes.isEmpty)

        guard !inserts.isEmpty ||
            !updates.isEmpty ||
            !tombstones.isEmpty ||
            !productPrunes.isEmpty ||
            !suppliersToCreate.isEmpty ||
            !categoriesToCreate.isEmpty ||
            shouldPruneUnreferencedCleanLookups else {
            if shouldSkipProductMutationsDueToConflicts {
                throw SupabasePullApplyError.conflictsPresent
            }
            throw SupabasePullApplyError.noApplicableChanges
        }

        return SupabasePullApplyPlan(
            generatedAt: preview.generatedAt,
            options: options,
            expectedProductStates: expectedStates.sorted { $0.barcode < $1.barcode },
            suppliersToCreate: suppliersToCreate,
            categoriesToCreate: categoriesToCreate,
            productInserts: inserts.sorted { $0.barcode < $1.barcode },
            productUpdates: updates.sorted { $0.barcode < $1.barcode },
            productTombstones: tombstones.sorted { $0.barcode < $1.barcode },
            productPrunes: productPrunes.sorted { $0.barcode < $1.barcode },
            remoteSupplierIDs: preview.remoteSupplierIDs,
            remoteCategoryIDs: preview.remoteCategoryIDs,
            shouldPruneUnreferencedCleanLookups: shouldPruneUnreferencedCleanLookups
        )
    }

    func apply(plan: SupabasePullApplyPlan, context: ModelContext) throws -> SupabasePullApplyResult {
        guard !plan.productInserts.isEmpty ||
            !plan.productUpdates.isEmpty ||
            !plan.productTombstones.isEmpty ||
            !plan.productPrunes.isEmpty ||
            !plan.suppliersToCreate.isEmpty ||
            !plan.categoriesToCreate.isEmpty ||
            plan.shouldPruneUnreferencedCleanLookups else {
            throw SupabasePullApplyError.noApplicableChanges
        }

        try validateNotStale(plan: plan, context: context)

        var productsByBarcode = try fetchProductsByBarcode(context: context)
        var suppliersByName = try fetchSuppliersByNormalizedName(context: context)
        var categoriesByName = try fetchCategoriesByNormalizedName(context: context)

        var inserted = 0
        var updated = 0
        var productTombstoned = 0
        var productPruned = 0
        var suppliersCreated = 0
        var categoriesCreated = 0

        for supplier in plan.suppliersToCreate {
            _ = try resolveSupplier(
                named: supplier.displayName,
                remoteID: supplier.remoteID,
                remoteUpdatedAt: supplier.remoteUpdatedAt,
                remoteDeletedAt: supplier.remoteDeletedAt,
                context: context,
                cache: &suppliersByName,
                createdCount: &suppliersCreated
            )
        }

        for category in plan.categoriesToCreate {
            _ = try resolveCategory(
                named: category.displayName,
                remoteID: category.remoteID,
                remoteUpdatedAt: category.remoteUpdatedAt,
                remoteDeletedAt: category.remoteDeletedAt,
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
                remoteID: insert.payload.supplierRemoteID,
                remoteUpdatedAt: insert.payload.supplierRemoteUpdatedAt,
                remoteDeletedAt: insert.payload.supplierRemoteDeletedAt,
                context: context,
                cache: &suppliersByName,
                createdCount: &suppliersCreated
            )
            let category = try resolveCategory(
                named: insert.payload.categoryName,
                remoteID: insert.payload.categoryRemoteID,
                remoteUpdatedAt: insert.payload.categoryRemoteUpdatedAt,
                remoteDeletedAt: insert.payload.categoryRemoteDeletedAt,
                context: context,
                cache: &categoriesByName,
                createdCount: &categoriesCreated
            )
            let product = Product(
                barcode: insert.barcode,
                remoteID: insert.payload.remoteID,
                remoteUpdatedAt: insert.payload.remoteUpdatedAt,
                remoteDeletedAt: insert.payload.remoteDeletedAt,
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

        for tombstone in plan.productTombstones {
            guard let product = productsByBarcode[tombstone.barcode] else {
                throw SupabasePullApplyError.previewStale
            }

            if applyProductTombstone(tombstone.payload, to: product) {
                productTombstoned += 1
            }
        }

        for prune in plan.productPrunes {
            guard let product = productsByBarcode[prune.barcode] else {
                throw SupabasePullApplyError.previewStale
            }
            context.delete(product)
            productsByBarcode.removeValue(forKey: prune.barcode)
            productPruned += 1
        }

        if plan.shouldPruneUnreferencedCleanLookups {
            _ = try pruneUnreferencedCleanLookups(
                context: context,
                suppliersByName: &suppliersByName,
                categoriesByName: &categoriesByName,
                remoteSupplierIDs: plan.remoteSupplierIDs,
                remoteCategoryIDs: plan.remoteCategoryIDs
            )
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
            categoriesCreated: categoriesCreated,
            productTombstoned: productTombstoned,
            productPruned: productPruned
        )
    }

    func replaceLocalCatalogWithRemoteSnapshot(
        preview: SyncPreview,
        context: ModelContext,
        options: SupabasePullApplyOptions = SupabasePullApplyOptions(
            allowLookupOnlyApplyWhenProductConflicts: false
        ),
        isAuthenticated: Bool,
        accountGuard: SupabasePullApplyAccountGuard? = nil,
        onProgress: @escaping @MainActor @Sendable (SupabasePullApplyProgress) -> Void = { _ in }
    ) async throws -> SupabasePullApplyResult {
        let replacementOptions = SupabasePullApplyOptions(
            applyStockQuantity: options.applyStockQuantity,
            allowLookupOnlyApplyWhenProductConflicts: false,
            isCompleteRemoteSnapshot: true
        )
        try validateGlobalGuards(
            preview: preview,
            isAuthenticated: isAuthenticated,
            accountGuard: accountGuard,
            options: replacementOptions
        )
        let replacementPreview = try makeCatalogReplacementPreview(from: preview)
        try validateCatalogReplacementPayloads(replacementPreview, options: replacementOptions)
        try validateNoActiveLocalPendingChanges(context: context)

        let deletedCounts = try deleteLocalCatalogAndPricesForReplacement(context: context)
        do {
            let plan = try prepareApplyPlan(
                preview: replacementPreview,
                context: context,
                options: replacementOptions,
                isAuthenticated: isAuthenticated,
                accountGuard: accountGuard
            )
            let applied = try await applyBatched(
                plan: plan,
                context: context,
                onProgress: onProgress
            )
            return SupabasePullApplyResult(
                inserted: applied.inserted,
                updated: applied.updated,
                suppliersCreated: applied.suppliersCreated,
                categoriesCreated: applied.categoriesCreated,
                productTombstoned: applied.productTombstoned,
                productPruned: deletedCounts.products
            )
        } catch let error as SupabasePullApplyError where error == .noApplicableChanges {
            return SupabasePullApplyResult(
                inserted: 0,
                updated: 0,
                suppliersCreated: 0,
                categoriesCreated: 0,
                productPruned: deletedCounts.products
            )
        }
    }

    private func cleanProductPrunes(
        preview: SyncPreview,
        snapshot: LocalInventorySnapshot,
        pendingChanges: SupabasePullApplyPendingProductChanges
    ) -> [SupabasePullApplyProductPrune] {
        guard !preview.remoteProductIDs.isEmpty else {
            return []
        }

        return snapshot.productsByBarcode.compactMap { barcode, localProduct in
            guard let remoteID = localProduct.remoteID,
                  !preview.remoteProductIDs.contains(remoteID),
                  localProduct.remoteDeletedAt == nil,
                  !hasPendingLocalProductChange(
                    remoteID: remoteID,
                    barcode: barcode,
                    pendingChanges: pendingChanges
                  ) else {
                return nil
            }

            return SupabasePullApplyProductPrune(
                barcode: barcode,
                expectedFingerprint: SupabasePullApplyProductFingerprint(snapshot: localProduct)
            )
        }
    }

    private func makeCatalogReplacementPreview(from preview: SyncPreview) throws -> SyncPreview {
        let activeRemoteProducts = preview.newProducts + preview.updateCandidates + preview.unchangedProducts
        let replacementProducts = activeRemoteProducts.map { summary in
            SyncPreviewProductSummary(
                id: summary.id,
                classification: .newProduct,
                remoteID: summary.remoteID,
                barcode: summary.barcode,
                productName: summary.productName,
                detail: summary.detail,
                fieldChanges: summary.fieldChanges,
                applyPayload: summary.applyPayload
            )
        }
        return SyncPreview(
            generatedAt: preview.generatedAt,
            outcome: preview.outcome,
            remoteCounts: preview.remoteCounts,
            localCounts: preview.localCounts,
            newProducts: replacementProducts,
            updateCandidates: [],
            remoteSupplierLookups: preview.remoteSupplierLookups,
            remoteCategoryLookups: preview.remoteCategoryLookups,
            conflicts: preview.conflicts,
            unchangedProducts: [],
            remoteTombstones: [],
            supplierDiffs: [],
            categoryDiffs: [],
            priceHistoryDiffs: preview.priceHistoryDiffs,
            warnings: preview.warnings,
            metrics: preview.metrics,
            sourceErrors: preview.sourceErrors,
            remoteProductIDs: Set(replacementProducts.compactMap(\.remoteID)),
            remoteSupplierIDs: preview.remoteSupplierIDs,
            remoteCategoryIDs: preview.remoteCategoryIDs
        )
    }

    private func validateCatalogReplacementPayloads(
        _ preview: SyncPreview,
        options: SupabasePullApplyOptions
    ) throws {
        var barcodes = Set<String>()
        for summary in preview.newProducts {
            guard let payload = summary.applyPayload else {
                throw SupabasePullApplyError.missingApplicablePayload(barcode: summary.barcode)
            }
            try validateNumbers(payload: payload, options: options)
            guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(payload.barcode) else {
                throw SupabasePullApplyError.missingRequiredField(barcode: summary.barcode, field: "barcode")
            }
            guard barcodes.insert(barcode).inserted else {
                throw SupabasePullApplyError.conflictsPresent
            }
            let primaryName = SupabasePullPreviewNormalizer.semanticString(payload.productName)
            let secondaryName = SupabasePullPreviewNormalizer.semanticString(payload.secondProductName)
            guard primaryName != nil || secondaryName != nil else {
                throw SupabasePullApplyError.missingRequiredField(barcode: barcode, field: "productName")
            }
        }
    }

    private func validateNoActiveLocalPendingChanges(context: ModelContext) throws {
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        guard !changes.contains(where: { !$0.status.isTerminal }) else {
            throw SupabasePullApplyError.invalidLocalData
        }
    }

    private func deleteLocalCatalogAndPricesForReplacement(
        context: ModelContext
    ) throws -> (products: Int, productPrices: Int, suppliers: Int, categories: Int) {
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
        let products = try context.fetch(FetchDescriptor<Product>())
        let suppliers = try context.fetch(FetchDescriptor<Supplier>())
        let categories = try context.fetch(FetchDescriptor<ProductCategory>())

        for price in prices {
            context.delete(price)
        }
        for product in products {
            context.delete(product)
        }
        for supplier in suppliers {
            context.delete(supplier)
        }
        for category in categories {
            context.delete(category)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw SupabasePullApplyError.saveFailed(message: String(describing: error))
        }

        return (
            products: products.count,
            productPrices: prices.count,
            suppliers: suppliers.count,
            categories: categories.count
        )
    }

    private func pendingProductChanges(
        context: ModelContext,
        ownerUserID: UUID?
    ) throws -> SupabasePullApplyPendingProductChanges {
        guard let ownerUserID else {
            return .empty
        }
        let owner = ownerUserID.uuidString.lowercased()
        let productKind = LocalPendingChangeEntityKind.product.rawValue
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner && change.entityKindRaw == productKind
            }
        )
        let activeChanges = try context.fetch(descriptor).filter { !$0.status.isTerminal }
        return SupabasePullApplyPendingProductChanges(
            logicalKeys: Set(activeChanges.map(\.logicalKey)),
            remoteIDs: Set(activeChanges.compactMap(\.entityRemoteID))
        )
    }

    private func hasPendingLocalProductChange(
        payload: SyncPreviewProductApplyPayload,
        barcode: String,
        pendingChanges: SupabasePullApplyPendingProductChanges
    ) -> Bool {
        guard !pendingChanges.isEmpty else {
            return false
        }

        let remoteID = payload.remoteID
        if pendingChanges.remoteIDs.contains(remoteID) {
            return true
        }
        let remoteKey = LocalPendingChangeLogicalKey.remoteEntity(kind: .product, remoteID: remoteID)
        if pendingChanges.logicalKeys.contains(remoteKey) {
            return true
        }

        let localKey = LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: barcode)
        return pendingChanges.logicalKeys.contains(localKey)
    }

    private func hasPendingLocalProductChange(
        remoteID: UUID,
        barcode: String,
        pendingChanges: SupabasePullApplyPendingProductChanges
    ) -> Bool {
        guard !pendingChanges.isEmpty else {
            return false
        }
        if pendingChanges.remoteIDs.contains(remoteID) {
            return true
        }
        let remoteKey = LocalPendingChangeLogicalKey.remoteEntity(kind: .product, remoteID: remoteID)
        if pendingChanges.logicalKeys.contains(remoteKey) {
            return true
        }
        let localKey = LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: barcode)
        return pendingChanges.logicalKeys.contains(localKey)
    }

    func applyBatched(
        plan: SupabasePullApplyPlan,
        context: ModelContext,
        onProgress: @escaping @MainActor @Sendable (SupabasePullApplyProgress) -> Void = { _ in }
    ) async throws -> SupabasePullApplyResult {
        guard !plan.productInserts.isEmpty ||
            !plan.productUpdates.isEmpty ||
            !plan.productTombstones.isEmpty ||
            !plan.productPrunes.isEmpty ||
            !plan.suppliersToCreate.isEmpty ||
            !plan.categoriesToCreate.isEmpty ||
            plan.shouldPruneUnreferencedCleanLookups else {
            throw SupabasePullApplyError.noApplicableChanges
        }

        try Task.checkCancellation()
        try validateNotStale(plan: plan, context: context)

        var productsByBarcode = try fetchProductsByBarcode(context: context)
        var suppliersByName = try fetchSuppliersByNormalizedName(context: context)
        var categoriesByName = try fetchCategoriesByNormalizedName(context: context)

        var inserted = 0
        var updated = 0
        var productTombstoned = 0
        var productPruned = 0
        var suppliersCreated = 0
        var categoriesCreated = 0
        var mutationsSinceSave = 0
        let batchSize = 500

        func saveBatchIfNeeded(force: Bool = false) async throws {
            guard mutationsSinceSave > 0, force || mutationsSinceSave >= batchSize else { return }
            await publishProgress(
                SupabasePullApplyProgress(stage: .saving, current: inserted + updated + productTombstoned + productPruned, total: plan.plannedProductMutationCount),
                onProgress: onProgress
            )
            do {
                try context.save()
                mutationsSinceSave = 0
            } catch {
                context.rollback()
                throw SupabasePullApplyError.saveFailed(message: String(describing: error))
            }
        }

        await publishProgress(SupabasePullApplyProgress(stage: .suppliers, current: 0, total: plan.suppliersToCreate.count), onProgress: onProgress)
        for (index, supplier) in plan.suppliersToCreate.enumerated() {
            try Task.checkCancellation()
            let before = suppliersCreated
            _ = try resolveSupplier(
                named: supplier.displayName,
                remoteID: supplier.remoteID,
                remoteUpdatedAt: supplier.remoteUpdatedAt,
                remoteDeletedAt: supplier.remoteDeletedAt,
                context: context,
                cache: &suppliersByName,
                createdCount: &suppliersCreated
            )
            if suppliersCreated > before {
                mutationsSinceSave += 1
            }
            await publishProgress(SupabasePullApplyProgress(stage: .suppliers, current: index + 1, total: plan.suppliersToCreate.count), onProgress: onProgress)
            try await saveBatchIfNeeded()
            if (index + 1).isMultiple(of: batchSize) {
                await Task.yield()
            }
        }

        await publishProgress(SupabasePullApplyProgress(stage: .categories, current: 0, total: plan.categoriesToCreate.count), onProgress: onProgress)
        for (index, category) in plan.categoriesToCreate.enumerated() {
            try Task.checkCancellation()
            let before = categoriesCreated
            _ = try resolveCategory(
                named: category.displayName,
                remoteID: category.remoteID,
                remoteUpdatedAt: category.remoteUpdatedAt,
                remoteDeletedAt: category.remoteDeletedAt,
                context: context,
                cache: &categoriesByName,
                createdCount: &categoriesCreated
            )
            if categoriesCreated > before {
                mutationsSinceSave += 1
            }
            await publishProgress(SupabasePullApplyProgress(stage: .categories, current: index + 1, total: plan.categoriesToCreate.count), onProgress: onProgress)
            try await saveBatchIfNeeded()
            if (index + 1).isMultiple(of: batchSize) {
                await Task.yield()
            }
        }

        let productTotal = plan.plannedProductMutationCount
        var processedProducts = 0
        await publishProgress(SupabasePullApplyProgress(stage: .products, current: 0, total: productTotal), onProgress: onProgress)
        for insert in plan.productInserts {
            try Task.checkCancellation()
            guard productsByBarcode[insert.barcode] == nil else {
                throw SupabasePullApplyError.previewStale
            }

            let supplier = try resolveSupplier(
                named: insert.payload.supplierName,
                remoteID: insert.payload.supplierRemoteID,
                remoteUpdatedAt: insert.payload.supplierRemoteUpdatedAt,
                remoteDeletedAt: insert.payload.supplierRemoteDeletedAt,
                context: context,
                cache: &suppliersByName,
                createdCount: &suppliersCreated
            )
            let category = try resolveCategory(
                named: insert.payload.categoryName,
                remoteID: insert.payload.categoryRemoteID,
                remoteUpdatedAt: insert.payload.categoryRemoteUpdatedAt,
                remoteDeletedAt: insert.payload.categoryRemoteDeletedAt,
                context: context,
                cache: &categoriesByName,
                createdCount: &categoriesCreated
            )
            let product = Product(
                barcode: insert.barcode,
                remoteID: insert.payload.remoteID,
                remoteUpdatedAt: insert.payload.remoteUpdatedAt,
                remoteDeletedAt: insert.payload.remoteDeletedAt,
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
            processedProducts += 1
            mutationsSinceSave += 1
            await publishProgress(SupabasePullApplyProgress(stage: .products, current: processedProducts, total: productTotal), onProgress: onProgress)
            try await saveBatchIfNeeded()
            if processedProducts.isMultiple(of: batchSize) {
                await Task.yield()
            }
        }

        for update in plan.productUpdates {
            try Task.checkCancellation()
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
                mutationsSinceSave += 1
            }
            processedProducts += 1
            await publishProgress(SupabasePullApplyProgress(stage: .products, current: processedProducts, total: productTotal), onProgress: onProgress)
            try await saveBatchIfNeeded()
            if processedProducts.isMultiple(of: batchSize) {
                await Task.yield()
            }
        }

        for tombstone in plan.productTombstones {
            try Task.checkCancellation()
            guard let product = productsByBarcode[tombstone.barcode] else {
                throw SupabasePullApplyError.previewStale
            }

            if applyProductTombstone(tombstone.payload, to: product) {
                productTombstoned += 1
                mutationsSinceSave += 1
            }
            processedProducts += 1
            await publishProgress(SupabasePullApplyProgress(stage: .products, current: processedProducts, total: productTotal), onProgress: onProgress)
            try await saveBatchIfNeeded()
            if processedProducts.isMultiple(of: batchSize) {
                await Task.yield()
            }
        }

        for prune in plan.productPrunes {
            try Task.checkCancellation()
            guard let product = productsByBarcode[prune.barcode] else {
                throw SupabasePullApplyError.previewStale
            }
            context.delete(product)
            productsByBarcode.removeValue(forKey: prune.barcode)
            productPruned += 1
            processedProducts += 1
            mutationsSinceSave += 1
            await publishProgress(SupabasePullApplyProgress(stage: .products, current: processedProducts, total: productTotal), onProgress: onProgress)
            try await saveBatchIfNeeded()
            if processedProducts.isMultiple(of: batchSize) {
                await Task.yield()
            }
        }

        if plan.shouldPruneUnreferencedCleanLookups {
            let pruned = try pruneUnreferencedCleanLookups(
                context: context,
                suppliersByName: &suppliersByName,
                categoriesByName: &categoriesByName,
                remoteSupplierIDs: plan.remoteSupplierIDs,
                remoteCategoryIDs: plan.remoteCategoryIDs
            )
            mutationsSinceSave += pruned
            try await saveBatchIfNeeded()
        }

        try await saveBatchIfNeeded(force: true)
        await publishProgress(SupabasePullApplyProgress(stage: .completed, current: productTotal, total: productTotal), onProgress: onProgress)

        return SupabasePullApplyResult(
            inserted: inserted,
            updated: updated,
            suppliersCreated: suppliersCreated,
            categoriesCreated: categoriesCreated,
            productTombstoned: productTombstoned,
            productPruned: productPruned
        )
    }

    private func validateGlobalGuards(
        preview: SyncPreview,
        isAuthenticated: Bool,
        accountGuard: SupabasePullApplyAccountGuard?,
        options: SupabasePullApplyOptions
    ) throws {
        guard isAuthenticated else {
            throw SupabasePullApplyError.sessionMissing
        }

        if accountGuard?.hasMismatch == true {
            throw SupabasePullApplyError.accountMismatch
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

        if !preview.conflicts.isEmpty && !options.allowLookupOnlyApplyWhenProductConflicts {
            throw SupabasePullApplyError.conflictsPresent
        }
    }

    private func containsPriceHistoryIncomplete(_ preview: SyncPreview) -> Bool {
        (preview.warnings + preview.sourceErrors).contains { $0.code == .priceHistoryIncomplete }
    }

    private func validateLocalInvariants(_ snapshot: LocalInventorySnapshot) throws {
        guard snapshot.invalidProductBarcodes == 0,
              snapshot.invalidSupplierNames == 0,
              snapshot.invalidCategoryNames == 0,
              snapshot.duplicateProductRemoteIDs.isEmpty,
              snapshot.duplicateSupplierRemoteIDs.isEmpty,
              snapshot.duplicateCategoryRemoteIDs.isEmpty,
              snapshot.duplicateSupplierNames.isEmpty,
              snapshot.duplicateCategoryNames.isEmpty else {
            throw SupabasePullApplyError.invalidLocalData
        }
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
        if local.remoteID != payload.remoteID
            || local.remoteUpdatedAt != payload.remoteUpdatedAt
            || local.remoteDeletedAt != payload.remoteDeletedAt {
            return true
        }
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
        try validateLocalInvariants(snapshot)

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

        if SupabasePullPreviewNormalizer.semanticString(payload.supplierName) != nil {
            let supplier = try resolveSupplier(
                named: payload.supplierName,
                remoteID: payload.supplierRemoteID,
                remoteUpdatedAt: payload.supplierRemoteUpdatedAt,
                remoteDeletedAt: payload.supplierRemoteDeletedAt,
                context: context,
                cache: &suppliersByName,
                createdCount: &suppliersCreated
            )
            if !SupabasePullPreviewNormalizer.lookupNamesEqual(supplier?.name, product.supplier?.name) {
                product.supplier = supplier
                didMutate = true
            }
        }

        if SupabasePullPreviewNormalizer.semanticString(payload.categoryName) != nil {
            let category = try resolveCategory(
                named: payload.categoryName,
                remoteID: payload.categoryRemoteID,
                remoteUpdatedAt: payload.categoryRemoteUpdatedAt,
                remoteDeletedAt: payload.categoryRemoteDeletedAt,
                context: context,
                cache: &categoriesByName,
                createdCount: &categoriesCreated
            )
            if !SupabasePullPreviewNormalizer.lookupNamesEqual(category?.name, product.category?.name) {
                product.category = category
                didMutate = true
            }
        }

        if product.remoteID != payload.remoteID {
            product.remoteID = payload.remoteID
            didMutate = true
        }
        if product.remoteUpdatedAt != payload.remoteUpdatedAt {
            product.remoteUpdatedAt = payload.remoteUpdatedAt
            didMutate = true
        }
        if product.remoteDeletedAt != payload.remoteDeletedAt {
            product.remoteDeletedAt = payload.remoteDeletedAt
            didMutate = true
        }
    }

    private func applyProductTombstone(
        _ payload: SyncPreviewProductApplyPayload,
        to product: Product
    ) -> Bool {
        var didMutate = false
        if product.remoteID != payload.remoteID {
            product.remoteID = payload.remoteID
            didMutate = true
        }
        if product.remoteUpdatedAt != payload.remoteUpdatedAt {
            product.remoteUpdatedAt = payload.remoteUpdatedAt
            didMutate = true
        }
        if product.remoteDeletedAt != payload.remoteDeletedAt {
            product.remoteDeletedAt = payload.remoteDeletedAt
            didMutate = true
        }
        return didMutate
    }

    private func resolveSupplier(
        named name: String?,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil,
        context: ModelContext,
        cache: inout [String: Supplier],
        createdCount: inout Int
    ) throws -> Supplier? {
        guard let displayName = SupabasePullPreviewNormalizer.semanticString(name),
              let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(displayName) else {
            return nil
        }

        if let remoteID,
           let existing = cache.values.first(where: { $0.remoteID == remoteID }) {
            try applyRemoteMetadata(
                remoteID: remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                remoteDeletedAt: remoteDeletedAt,
                to: existing
            )
            return existing
        }

        if let existing = cache[normalizedName] {
            try applyRemoteMetadata(
                remoteID: remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                remoteDeletedAt: remoteDeletedAt,
                to: existing
            )
            return existing
        }

        cache = try fetchSuppliersByNormalizedName(context: context)
        if let remoteID,
           let existing = cache.values.first(where: { $0.remoteID == remoteID }) {
            try applyRemoteMetadata(
                remoteID: remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                remoteDeletedAt: remoteDeletedAt,
                to: existing
            )
            return existing
        }

        if let existing = cache[normalizedName] {
            try applyRemoteMetadata(
                remoteID: remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                remoteDeletedAt: remoteDeletedAt,
                to: existing
            )
            return existing
        }

        let supplier = Supplier(
            name: displayName,
            remoteID: remoteID,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeletedAt: remoteDeletedAt
        )
        context.insert(supplier)
        cache[normalizedName] = supplier
        createdCount += 1
        return supplier
    }

    private func resolveCategory(
        named name: String?,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil,
        context: ModelContext,
        cache: inout [String: ProductCategory],
        createdCount: inout Int
    ) throws -> ProductCategory? {
        guard let displayName = SupabasePullPreviewNormalizer.semanticString(name),
              let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(displayName) else {
            return nil
        }

        if let remoteID,
           let existing = cache.values.first(where: { $0.remoteID == remoteID }) {
            try applyRemoteMetadata(
                remoteID: remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                remoteDeletedAt: remoteDeletedAt,
                to: existing
            )
            return existing
        }

        if let existing = cache[normalizedName] {
            try applyRemoteMetadata(
                remoteID: remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                remoteDeletedAt: remoteDeletedAt,
                to: existing
            )
            return existing
        }

        cache = try fetchCategoriesByNormalizedName(context: context)
        if let remoteID,
           let existing = cache.values.first(where: { $0.remoteID == remoteID }) {
            try applyRemoteMetadata(
                remoteID: remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                remoteDeletedAt: remoteDeletedAt,
                to: existing
            )
            return existing
        }

        if let existing = cache[normalizedName] {
            try applyRemoteMetadata(
                remoteID: remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                remoteDeletedAt: remoteDeletedAt,
                to: existing
            )
            return existing
        }

        let category = ProductCategory(
            name: displayName,
            remoteID: remoteID,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeletedAt: remoteDeletedAt
        )
        context.insert(category)
        cache[normalizedName] = category
        createdCount += 1
        return category
    }

    private func applyRemoteMetadata(
        remoteID: UUID?,
        remoteUpdatedAt: Date?,
        remoteDeletedAt: Date?,
        to supplier: Supplier
    ) throws {
        if let remoteID {
            if let existingRemoteID = supplier.remoteID, existingRemoteID != remoteID {
                throw SupabasePullApplyError.previewStale
            }
            supplier.remoteID = remoteID
        }
        supplier.remoteUpdatedAt = remoteUpdatedAt ?? supplier.remoteUpdatedAt
        supplier.remoteDeletedAt = remoteDeletedAt
    }

    private func applyRemoteMetadata(
        remoteID: UUID?,
        remoteUpdatedAt: Date?,
        remoteDeletedAt: Date?,
        to category: ProductCategory
    ) throws {
        if let remoteID {
            if let existingRemoteID = category.remoteID, existingRemoteID != remoteID {
                throw SupabasePullApplyError.previewStale
            }
            category.remoteID = remoteID
        }
        category.remoteUpdatedAt = remoteUpdatedAt ?? category.remoteUpdatedAt
        category.remoteDeletedAt = remoteDeletedAt
    }

    private func pruneUnreferencedCleanLookups(
        context: ModelContext,
        suppliersByName: inout [String: Supplier],
        categoriesByName: inout [String: ProductCategory],
        remoteSupplierIDs: Set<UUID>,
        remoteCategoryIDs: Set<UUID>
    ) throws -> Int {
        let products = try context.fetch(FetchDescriptor<Product>())
        let activeProducts = products.filter { $0.remoteDeletedAt == nil }
        let referencedSupplierNames = Set(
            activeProducts.compactMap { SupabasePullPreviewNormalizer.normalizedLookupName($0.supplier?.name) }
        )
        let referencedCategoryNames = Set(
            activeProducts.compactMap { SupabasePullPreviewNormalizer.normalizedLookupName($0.category?.name) }
        )
        let activeLookupPendingKeys = try fetchActiveLookupPendingKeys(context: context)

        var supplierPrunes: [(supplier: Supplier, normalizedName: String)] = []
        var categoryPrunes: [(category: ProductCategory, normalizedName: String)] = []
        let suppliers = try context.fetch(FetchDescriptor<Supplier>(sortBy: [SortDescriptor(\Supplier.name)]))
        for supplier in suppliers {
            let existsInRemoteSnapshot = supplier.remoteID.map { remoteSupplierIDs.contains($0) } ?? false
            guard !existsInRemoteSnapshot,
                  supplier.remoteDeletedAt == nil,
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(supplier.name),
                  !referencedSupplierNames.contains(normalizedName),
                  !activeLookupPendingKeys.contains(
                    LocalPendingChangeLogicalKey.supplier(remoteID: supplier.remoteID, name: supplier.name)
                ) else {
                continue
            }
            supplierPrunes.append((supplier, normalizedName))
        }

        let categories = try context.fetch(FetchDescriptor<ProductCategory>(sortBy: [SortDescriptor(\ProductCategory.name)]))
        for category in categories {
            let existsInRemoteSnapshot = category.remoteID.map { remoteCategoryIDs.contains($0) } ?? false
            guard !existsInRemoteSnapshot,
                  category.remoteDeletedAt == nil,
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(category.name),
                  !referencedCategoryNames.contains(normalizedName),
                  !activeLookupPendingKeys.contains(
                    LocalPendingChangeLogicalKey.category(remoteID: category.remoteID, name: category.name)
                ) else {
                continue
            }
            categoryPrunes.append((category, normalizedName))
        }

        var detachedRelationships = false
        for (supplier, _) in supplierPrunes {
            detachedRelationships = detachSupplier(supplier, from: products) || detachedRelationships
        }
        for (category, _) in categoryPrunes {
            detachedRelationships = detachCategory(category, from: products) || detachedRelationships
        }

        if detachedRelationships {
            do {
                try context.save()
            } catch {
                context.rollback()
                throw SupabasePullApplyError.saveFailed(message: String(describing: error))
            }
        }

        var pruned = 0
        for (supplier, normalizedName) in supplierPrunes {
            context.delete(supplier)
            suppliersByName.removeValue(forKey: normalizedName)
            pruned += 1
        }
        for (category, normalizedName) in categoryPrunes {
            context.delete(category)
            categoriesByName.removeValue(forKey: normalizedName)
            pruned += 1
        }

        return pruned
    }

    @discardableResult
    private func detachSupplier(_ supplier: Supplier, from products: [Product]) -> Bool {
        var detached = false
        for product in products where product.supplier === supplier {
            product.supplier = nil
            detached = true
        }
        return detached
    }

    @discardableResult
    private func detachCategory(_ category: ProductCategory, from products: [Product]) -> Bool {
        var detached = false
        for product in products where product.category === category {
            product.category = nil
            detached = true
        }
        return detached
    }

    private func hasPrunableUnreferencedCleanLookups(
        context: ModelContext,
        remoteSupplierIDs: Set<UUID>,
        remoteCategoryIDs: Set<UUID>
    ) throws -> Bool {
        let products = try context.fetch(FetchDescriptor<Product>())
            .filter { $0.remoteDeletedAt == nil }
        let referencedSupplierNames = Set(
            products.compactMap { SupabasePullPreviewNormalizer.normalizedLookupName($0.supplier?.name) }
        )
        let referencedCategoryNames = Set(
            products.compactMap { SupabasePullPreviewNormalizer.normalizedLookupName($0.category?.name) }
        )
        let activeLookupPendingKeys = try fetchActiveLookupPendingKeys(context: context)

        let suppliers = try context.fetch(FetchDescriptor<Supplier>())
        if suppliers.contains(where: { supplier in
            let existsInRemoteSnapshot = supplier.remoteID.map { remoteSupplierIDs.contains($0) } ?? false
            guard !existsInRemoteSnapshot,
                  supplier.remoteDeletedAt == nil,
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(supplier.name),
                  !referencedSupplierNames.contains(normalizedName) else {
                return false
            }
            return !activeLookupPendingKeys.contains(
                LocalPendingChangeLogicalKey.supplier(remoteID: supplier.remoteID, name: supplier.name)
            )
        }) {
            return true
        }

        let categories = try context.fetch(FetchDescriptor<ProductCategory>())
        return categories.contains { category in
            let existsInRemoteSnapshot = category.remoteID.map { remoteCategoryIDs.contains($0) } ?? false
            guard !existsInRemoteSnapshot,
                  category.remoteDeletedAt == nil,
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(category.name),
                  !referencedCategoryNames.contains(normalizedName) else {
                return false
            }
            return !activeLookupPendingKeys.contains(
                LocalPendingChangeLogicalKey.category(remoteID: category.remoteID, name: category.name)
            )
        }
    }

    private func fetchActiveLookupPendingKeys(context: ModelContext) throws -> Set<String> {
        let descriptor = FetchDescriptor<LocalPendingChange>()
        let lookupKinds: Set<String> = [
            LocalPendingChangeEntityKind.supplier.rawValue,
            LocalPendingChangeEntityKind.productCategory.rawValue
        ]
        return Set(
            try context.fetch(descriptor)
                .filter { lookupKinds.contains($0.entityKindRaw) && !$0.status.isTerminal }
                .map(\.logicalKey)
        )
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
        existingRemoteIDs: Set<UUID>,
        value: KeyPath<SyncPreviewProductApplyPayload, String?>,
        remoteID: KeyPath<SyncPreviewProductApplyPayload, UUID?>,
        remoteUpdatedAt: KeyPath<SyncPreviewProductApplyPayload, Date?>,
        remoteDeletedAt: KeyPath<SyncPreviewProductApplyPayload, Date?>
    ) -> [SupabasePullApplyLookup] {
        var pending: [String: SupabasePullApplyLookup] = [:]

        for payload in payloads {
            guard let displayName = SupabasePullPreviewNormalizer.semanticString(payload[keyPath: value]),
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(displayName),
                  payload[keyPath: remoteID].map({ !existingRemoteIDs.contains($0) }) ?? true,
                  existing[normalizedName] == nil,
                  pending[normalizedName] == nil else {
                continue
            }

            pending[normalizedName] = SupabasePullApplyLookup(
                normalizedName: normalizedName,
                displayName: displayName,
                remoteID: payload[keyPath: remoteID],
                remoteUpdatedAt: payload[keyPath: remoteUpdatedAt],
                remoteDeletedAt: payload[keyPath: remoteDeletedAt]
            )
        }

        return pending
            .map(\.value)
            .sorted { $0.normalizedName < $1.normalizedName }
    }

    private func lookupsToCreate(
        from lookups: [SyncPreviewLookupSummary],
        existing: [String: String],
        existingRemoteIDs: Set<UUID>
    ) -> [SupabasePullApplyLookup] {
        var pending: [String: SupabasePullApplyLookup] = [:]

        for lookup in lookups {
            guard lookup.remoteDeletedAt == nil,
                  !existingRemoteIDs.contains(lookup.remoteID),
                  let displayName = SupabasePullPreviewNormalizer.semanticString(lookup.displayName),
                  let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(displayName),
                  existing[normalizedName] == nil,
                  pending[normalizedName] == nil else {
                continue
            }

            pending[normalizedName] = SupabasePullApplyLookup(
                normalizedName: normalizedName,
                displayName: displayName,
                remoteID: lookup.remoteID,
                remoteUpdatedAt: lookup.remoteUpdatedAt,
                remoteDeletedAt: nil
            )
        }

        return pending
            .map(\.value)
            .sorted { $0.normalizedName < $1.normalizedName }
    }

    private func lookupsToCreate(_ lookups: [SupabasePullApplyLookup]) -> [SupabasePullApplyLookup] {
        var pending: [String: SupabasePullApplyLookup] = [:]
        for lookup in lookups where pending[lookup.normalizedName] == nil {
            pending[lookup.normalizedName] = lookup
        }
        return pending
            .map(\.value)
            .sorted { $0.normalizedName < $1.normalizedName }
    }

    private func productSort(
        lhs: SyncPreviewProductSummary,
        rhs: SyncPreviewProductSummary
    ) -> Bool {
        lhs.sortKey < rhs.sortKey
    }

    private func publishProgress(
        _ progress: SupabasePullApplyProgress,
        onProgress: @escaping @MainActor @Sendable (SupabasePullApplyProgress) -> Void
    ) async {
        await MainActor.run {
            onProgress(progress)
        }
    }
}

nonisolated struct SupabasePullApplyPendingProductChanges {
    let logicalKeys: Set<String>
    let remoteIDs: Set<UUID>

    var isEmpty: Bool {
        logicalKeys.isEmpty && remoteIDs.isEmpty
    }

    static let empty = SupabasePullApplyPendingProductChanges(logicalKeys: [], remoteIDs: [])
}
