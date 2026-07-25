import Foundation
import SwiftData

nonisolated struct CatalogIncrementalApplyResult {
    var targetedSuppliersFetched = 0
    var targetedCategoriesFetched = 0
    var targetedProductsFetched = 0
    var productsInserted = 0
    var productsUpdated = 0
    var productsTombstoned = 0
    var suppliersCreated = 0
    var suppliersUpdated = 0
    var categoriesCreated = 0
    var categoriesUpdated = 0
    var productsMissingRemoteTombstoned = 0
    var suppliersMissingRemoteTombstoned = 0
    var categoriesMissingRemoteTombstoned = 0
    var missingRemoteTargetCount = 0
    var remoteActiveProductIDs = Set<UUID>()
    var catalogFetchMs = 0
    var catalogApplyMs = 0
}

nonisolated struct CatalogIncrementalFetchResult: Sendable {
    var suppliers: [RemoteInventorySupplierRow] = []
    var categories: [RemoteInventoryCategoryRow] = []
    var products: [RemoteInventoryProductRow] = []
    var fetchMs = 0
}

nonisolated struct CatalogIncrementalMutationRows: Sendable {
    var suppliers: [RemoteInventorySupplierRow] = []
    var categories: [RemoteInventoryCategoryRow] = []
    var products: [RemoteInventoryProductRow] = []

    var remoteActiveProductIDs: Set<UUID> {
        Set(products.filter { $0.deletedAt == nil }.map(\.id))
    }
}

nonisolated func catalogIncrementalMutationRows(
    fetched: CatalogIncrementalFetchResult,
    eventIDs: SyncEventEntityIDSet
) throws -> CatalogIncrementalMutationRows {
    let products = fetched.products.filter { eventIDs.productIDs.contains($0.id) }
    let relatedSupplierIDs = Set(products.compactMap(\.supplierID))
    let relatedCategoryIDs = Set(products.compactMap(\.categoryID))
    let suppliers = fetched.suppliers.filter {
        eventIDs.supplierIDs.contains($0.id) || relatedSupplierIDs.contains($0.id)
    }
    let categories = fetched.categories.filter {
        eventIDs.categoryIDs.contains($0.id) || relatedCategoryIDs.contains($0.id)
    }
    guard eventIDs.supplierIDs.isSubset(of: Set(suppliers.map(\.id))),
          eventIDs.categoryIDs.isSubset(of: Set(categories.map(\.id))),
          eventIDs.productIDs.isSubset(of: Set(products.map(\.id))),
          relatedSupplierIDs.isSubset(of: Set(suppliers.map(\.id))),
          relatedCategoryIDs.isSubset(of: Set(categories.map(\.id))) else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    return CatalogIncrementalMutationRows(
        suppliers: suppliers,
        categories: categories,
        products: products
    )
}

nonisolated func applyTargetedCatalogMutationRows(
    _ rows: CatalogIncrementalMutationRows,
    protected: IncrementalApplyProtectedRemoteIDs,
    context: ModelContext,
    localIdentityIndex: inout IncrementalLocalCatalogIdentityIndex
) throws -> TargetedCatalogApplyResult {
    var result = TargetedCatalogApplyResult()
    var supplierCache: [UUID: Supplier] = [:]
    var categoryCache: [UUID: ProductCategory] = [:]

    for row in rows.suppliers where !protected.suppliers.contains(row.id) {
        let applied = try applyTargetedSupplier(
            row,
            context: context,
            localIdentityIndex: &localIdentityIndex
        )
        if let supplier = applied.supplier { supplierCache[row.id] = supplier }
        result.suppliersCreated += applied.created ? 1 : 0
        result.suppliersUpdated += applied.updated ? 1 : 0
    }
    for row in rows.categories where !protected.categories.contains(row.id) {
        let applied = try applyTargetedCategory(
            row,
            context: context,
            localIdentityIndex: &localIdentityIndex
        )
        if let category = applied.category { categoryCache[row.id] = category }
        result.categoriesCreated += applied.created ? 1 : 0
        result.categoriesUpdated += applied.updated ? 1 : 0
    }
    for row in rows.products {
        if protected.products.contains(row.id) {
            if try applyTargetedProductImageReference(row, context: context) {
                result.productsUpdated += 1
            }
            continue
        }
        let supplier = try row.supplierID.flatMap { remoteID -> Supplier? in
            if let cached = supplierCache[remoteID] { return cached }
            if let existing = try fetchSupplier(remoteID: remoteID, context: context) {
                supplierCache[remoteID] = existing
                return existing
            }
            return nil
        }
        let category = try row.categoryID.flatMap { remoteID -> ProductCategory? in
            if let cached = categoryCache[remoteID] { return cached }
            if let existing = try fetchCategory(remoteID: remoteID, context: context) {
                categoryCache[remoteID] = existing
                return existing
            }
            return nil
        }
        let applied = try applyTargetedProduct(
            row,
            supplier: supplier,
            category: category,
            context: context,
            localIdentityIndex: &localIdentityIndex
        )
        result.productsInserted += applied.inserted ? 1 : 0
        result.productsUpdated += applied.updated ? 1 : 0
        result.productsTombstoned += applied.tombstoned ? 1 : 0
    }
    return result
}

nonisolated func applyTargetedCatalogMutationRows(
    _ rows: CatalogIncrementalMutationRows,
    protected: IncrementalApplyProtectedRemoteIDs,
    context: ModelContext
) throws -> TargetedCatalogApplyResult {
    var localIdentityIndex = try IncrementalLocalCatalogIdentityIndex(
        context: context,
        includeSuppliers: !rows.suppliers.isEmpty,
        includeCategories: !rows.categories.isEmpty,
        includeProducts: !rows.products.isEmpty
            || !rows.suppliers.isEmpty
            || !rows.categories.isEmpty
    )
    return try applyTargetedCatalogMutationRows(
        rows,
        protected: protected,
        context: context,
        localIdentityIndex: &localIdentityIndex
    )
}

nonisolated struct CatalogIncrementalApplyService {
    private let remote: any SyncAutomaticCatalogIncrementalReading
    private let scope: Task126VerifiedOwnerStoreScope
    private let defaults: UserDefaults

    init(
        remote: any SyncAutomaticCatalogIncrementalReading,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults = .standard
    ) {
        self.remote = remote
        self.scope = scope
        self.defaults = defaults
    }

    func fetch(
        eventIDs: SyncEventEntityIDSet
    ) async throws -> CatalogIncrementalFetchResult {
        guard eventIDs.hasCatalogWork else { return CatalogIncrementalFetchResult() }
        let catalogFetchStarted = mcNowMillis()
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        let firstFetch = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            try await remote.fetchCatalogByIDs(
                supplierIDs: eventIDs.supplierIDs,
                categoryIDs: eventIDs.categoryIDs,
                productIDs: eventIDs.productIDs
            )
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        try validateRemoteRows(firstFetch)
        let relatedSupplierIDs = Set(firstFetch.products.compactMap(\.supplierID))
            .subtracting(Set(firstFetch.suppliers.map(\.id)))
        let relatedCategoryIDs = Set(firstFetch.products.compactMap(\.categoryID))
            .subtracting(Set(firstFetch.categories.map(\.id)))
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        let relatedFetch = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            try await remote.fetchCatalogByIDs(
                supplierIDs: relatedSupplierIDs,
                categoryIDs: relatedCategoryIDs,
                productIDs: []
            )
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        try validateRemoteRows(relatedFetch)
        let suppliers = mergeRows(firstFetch.suppliers, relatedFetch.suppliers)
        let categories = mergeRows(firstFetch.categories, relatedFetch.categories)
        return CatalogIncrementalFetchResult(
            suppliers: suppliers,
            categories: categories,
            products: firstFetch.products,
            fetchMs: mcNowMillis() - catalogFetchStarted
        )
    }

    func apply(
        fetched: CatalogIncrementalFetchResult,
        eventIDs: SyncEventEntityIDSet,
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool
    ) async throws -> CatalogIncrementalApplyResult {
        let rows = try catalogIncrementalMutationRows(fetched: fetched, eventIDs: eventIDs)

        let catalogApplyStarted = mcNowMillis()
        let result = try await applyTargetedCatalogRows(
            rows: rows,
            ownerUserID: ownerUserID,
            modelContainer: modelContainer,
            scope: scope,
            defaults: defaults
        )
        let catalogApplyMs = mcNowMillis() - catalogApplyStarted
        return CatalogIncrementalApplyResult(
            targetedSuppliersFetched: rows.suppliers.count,
            targetedCategoriesFetched: rows.categories.count,
            targetedProductsFetched: rows.products.count,
            productsInserted: result.productsInserted,
            productsUpdated: result.productsUpdated,
            productsTombstoned: result.productsTombstoned,
            suppliersCreated: result.suppliersCreated,
            suppliersUpdated: result.suppliersUpdated,
            categoriesCreated: result.categoriesCreated,
            categoriesUpdated: result.categoriesUpdated,
            productsMissingRemoteTombstoned: 0,
            suppliersMissingRemoteTombstoned: 0,
            categoriesMissingRemoteTombstoned: 0,
            missingRemoteTargetCount: 0,
            remoteActiveProductIDs: rows.remoteActiveProductIDs,
            catalogFetchMs: fetched.fetchMs,
            catalogApplyMs: catalogApplyMs
        )
    }

    private func applyTargetedCatalogRows(
        rows: CatalogIncrementalMutationRows,
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults
    ) async throws -> TargetedCatalogApplyResult {
        try await Task.detached(priority: .userInitiated) {
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                    modelContainer
                )
                let context = ModelContext(modelContainer)
                context.autosaveEnabled = false
                let protected = try pendingRemoteIDs(
                    context: context,
                    ownerUserID: ownerUserID,
                    storeIdentity: scope.storeIdentity
                )
                let result = try applyTargetedCatalogMutationRows(
                    rows,
                    protected: protected,
                    context: context
                )
                if result.totalMutations > 0 {
                    try context.save()
                }
                return result
            }
        }.value
    }

    private func tombstoneMissingRemoteCatalog(
        supplierIDs: Set<UUID>,
        categoryIDs: Set<UUID>,
        productIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults
    ) async throws -> (suppliers: Int, categories: Int, products: Int) {
        guard !supplierIDs.isEmpty || !categoryIDs.isEmpty || !productIDs.isEmpty else {
            return (0, 0, 0)
        }
        return try await Task.detached(priority: .utility) {
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                    modelContainer
                )
                let context = ModelContext(modelContainer)
                context.autosaveEnabled = false
                let protected = try pendingRemoteIDs(
                    context: context,
                    ownerUserID: ownerUserID,
                    storeIdentity: scope.storeIdentity
                )
                let now = Date()
                var suppliers = 0
                var categories = 0
                var products = 0

                for remoteID in supplierIDs where !protected.suppliers.contains(remoteID) {
                    guard let supplier = try fetchSupplier(remoteID: remoteID, context: context),
                          supplier.remoteDeletedAt == nil else { continue }
                    supplier.remoteDeletedAt = now
                    try detachSupplier(remoteID: remoteID, context: context)
                    suppliers += 1
                }
                for remoteID in categoryIDs where !protected.categories.contains(remoteID) {
                    guard let category = try fetchCategory(remoteID: remoteID, context: context),
                          category.remoteDeletedAt == nil else { continue }
                    category.remoteDeletedAt = now
                    try detachCategory(remoteID: remoteID, context: context)
                    categories += 1
                }
                for remoteID in productIDs where !protected.products.contains(remoteID) {
                    guard let product = try fetchProduct(remoteID: remoteID, context: context),
                          product.remoteDeletedAt == nil else { continue }
                    product.remoteDeletedAt = now
                    product.supplier = nil
                    product.category = nil
                    products += 1
                }
                if suppliers + categories + products > 0 {
                    try context.save()
                }
                return (suppliers, categories, products)
            }
        }.value
    }

    private func mergeRows<Row: Identifiable>(_ lhs: [Row], _ rhs: [Row]) -> [Row] where Row.ID == UUID {
        // Preserve duplicate IDs so the ordered event preflight can fail
        // closed with diagnostics. Dictionary(uniqueKeysWithValues:) traps
        // before that safety boundary on a malformed/non-RPC response.
        lhs + rhs
    }

    private func validateRemoteRows(
        _ rows: (
            suppliers: [RemoteInventorySupplierRow],
            categories: [RemoteInventoryCategoryRow],
            products: [RemoteInventoryProductRow]
        )
    ) throws {
        for row in rows.suppliers {
            try validateIncrementalReadIdentity(ownerUserID: row.ownerUserID, shopID: row.shopID, scope: scope, remote: remote)
        }
        for row in rows.categories {
            try validateIncrementalReadIdentity(ownerUserID: row.ownerUserID, shopID: row.shopID, scope: scope, remote: remote)
        }
        for row in rows.products {
            try validateIncrementalReadIdentity(ownerUserID: row.ownerUserID, shopID: row.shopID, scope: scope, remote: remote)
        }
    }
}
