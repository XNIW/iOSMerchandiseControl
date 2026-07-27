import CryptoKit
import Foundation
import SwiftData

final class CatalogPushService: SyncCatalogPushProviding {
    private let modelContainer: ModelContainer
    private let remote: (any SyncAutomaticCatalogRemoteWriting)?
    private let defaults: UserDefaults

    init(
        modelContainer: ModelContainer,
        remote: (any SyncAutomaticCatalogRemoteWriting)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
        self.defaults = defaults
    }

    func pushPendingCatalog(ownerUserID: UUID) async throws -> SyncCatalogPushResult {
        let modelContainer = self.modelContainer
        let remote = self.remote
        let defaults = self.defaults
        return try await Task.detached(priority: .utility) {
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: ownerUserID,
                defaults: defaults,
                allowsPendingSameScopeRecovery: true
            )
            let preparation = try Self.withFreshScopedContext(
                modelContainer: modelContainer,
                scope: scope,
                defaults: defaults
            ) { context -> (plan: SyncCatalogPushPlan, changeIDs: [String]) in
                _ = try CatalogTextPendingRepair.repair(
                    context: context,
                    ownerUserID: ownerUserID,
                    storeIdentity: scope.storeIdentity
                )
                let snapshot = try LocalPendingChangeSnapshotProvider(context: context)
                    .loadSnapshot(ownerUserID: ownerUserID, storeIdentity: scope.storeIdentity)
                var blockers: [String] = []
                if snapshot.blockedCount > 0 { blockers.append("blockedLocalChanges") }
                if snapshot.staleBaselineCount > 0 { blockers.append("staleBaselineLocalChanges") }
                if snapshot.sentCount > 0 { blockers.append("sentChangesWaitingForRetry") }
                if snapshot.isCapped { blockers.append("cappedPendingStore") }
                if remote == nil, snapshot.pendingCatalogChangeCount > 0 {
                    blockers.append("missingRemote")
                }
                let plan = SyncCatalogPushPlan(
                    ownerUserID: ownerUserID,
                    pendingChangeCount: snapshot.pendingCatalogChangeCount,
                    idempotencyKey: "catalog:\(ownerUserID.uuidString.lowercased()):\(scope.shopID.uuidString.lowercased()):\(snapshot.pendingCatalogChangeCount)",
                    blockers: SyncStringCollectionHelpers.uniquedSorted(blockers)
                )
                let changeIDs = try Self.pendingCatalogChanges(
                    context: context,
                    ownerUserID: ownerUserID,
                    scope: scope
                ).map(\.changeID)
                return (plan, changeIDs)
            }
            var result = SyncCatalogPushResult(plan: preparation.plan)
            guard preparation.plan.hasWork,
                  let remote else {
                return result
            }

            for changeID in preparation.changeIDs {
                guard let mutation = try Self.withFreshScopedContext(
                    modelContainer: modelContainer,
                    scope: scope,
                    defaults: defaults,
                    { context in
                        try Self.prepareMutation(
                            changeID: changeID,
                            context: context,
                            ownerUserID: ownerUserID,
                            scope: scope
                        )
                    }
                ) else { continue }

                switch mutation.action {
                case .acknowledgeLocalOnly:
                    try Self.withFreshScopedContext(
                        modelContainer: modelContainer,
                        scope: scope,
                        defaults: defaults
                    ) { context in
                        guard let change = try Self.fetchPendingChange(
                            changeID: mutation.pending.changeID,
                            context: context
                        ), mutation.pending.matches(change),
                              LocalPendingChangeScopeMatcher.matches(
                                change,
                                ownerUserID: ownerUserID,
                                accountHash: scope.accountHash,
                                storeIdentity: scope.storeIdentity
                              ) else { return }
                        change.status = .acknowledged
                        change.updatedAt = Date()
                        try context.save()
                    }
                case .remote(let call):
                    let readBack = try await Self.execute(
                        call,
                        remote: remote,
                        scope: scope,
                        defaults: defaults
                    )
                    let outcome = try Self.withFreshScopedContext(
                        modelContainer: modelContainer,
                        scope: scope,
                        defaults: defaults
                    ) { context in
                        try Self.applyReadBack(
                            readBack,
                            mutation: mutation,
                            context: context,
                            ownerUserID: ownerUserID,
                            plan: preparation.plan,
                            scope: scope
                        )
                    }
                    result.supplierCreates += outcome.result.supplierCreates
                    result.supplierUpdates += outcome.result.supplierUpdates
                    result.categoryCreates += outcome.result.categoryCreates
                    result.categoryUpdates += outcome.result.categoryUpdates
                    result.productCreates += outcome.result.productCreates
                    result.productUpdates += outcome.result.productUpdates
                }
            }

            _ = try? Self.withFreshScopedContext(
                modelContainer: modelContainer,
                scope: scope,
                defaults: defaults
            ) { context -> SupabaseCatalogBaselineCommitResult? in
                let finalSnapshot = try LocalPendingChangeSnapshotProvider(context: context)
                    .loadSnapshot(ownerUserID: ownerUserID, storeIdentity: scope.storeIdentity)
                guard finalSnapshot.pendingCatalogChangeCount == 0,
                      finalSnapshot.blockedCount == 0,
                      finalSnapshot.staleBaselineCount == 0,
                      finalSnapshot.sentCount == 0,
                      !finalSnapshot.isCapped else { return nil }
                return try SupabaseCatalogBaselineWriter().commitLatestBaseline(
                    context: context,
                    ownerUserUUID: ownerUserID,
                    validateBeforeSave: {}
                )
            }
            return result
        }.value
    }

    nonisolated private static func pendingCatalogChanges(
        context: ModelContext,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> [LocalPendingChange] {
        let owner = ownerUserID.uuidString.lowercased()
        let pending = LocalPendingChangeStatus.pending.rawValue
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner && change.statusRaw == pending
            },
            sortBy: [
                SortDescriptor(\.updatedAt, order: .forward),
                SortDescriptor(\.changeID, order: .forward)
            ]
        )
        return try context.fetch(descriptor).filter {
            $0.entityKind.isCatalogKind
                && LocalPendingChangeScopeMatcher.matches(
                    $0,
                    ownerUserID: ownerUserID,
                    accountHash: scope.accountHash,
                    storeIdentity: scope.storeIdentity
                )
        }
    }

    nonisolated private struct CatalogPushOutcome: Sendable {
        var result: SyncCatalogPushResult
        var supplierIDs: [UUID] = []
        var categoryIDs: [UUID] = []
        var productIDs: [UUID] = []
        var supplierTombstoneIDs: [UUID] = []
        var categoryTombstoneIDs: [UUID] = []
        var productTombstoneIDs: [UUID] = []
        var changeIDs: [String] = []
    }

    nonisolated private enum CatalogPushError: Error, Sendable, Equatable {
        case responseMismatch
        case invalidIdempotencyKey
        case nonCanonicalCatalogText(CatalogTextField)
    }

    nonisolated private enum CatalogEntityReference: Sendable {
        case supplier(PersistentIdentifier)
        case category(PersistentIdentifier)
        case product(PersistentIdentifier)
    }

    nonisolated private enum CatalogRemoteCall: Sendable {
        case createSupplier(SyncAutomaticSupplierCreatePayload)
        case updateSupplier(UUID, SyncAutomaticSupplierUpdatePayload)
        case createCategory(SyncAutomaticCategoryCreatePayload)
        case updateCategory(UUID, SyncAutomaticCategoryUpdatePayload)
        case createProduct(SyncAutomaticProductCreatePayload)
        case updateProduct(UUID, SyncAutomaticProductUpdatePayload)
    }

    nonisolated private enum CatalogMutationAction: Sendable {
        case acknowledgeLocalOnly
        case remote(CatalogRemoteCall)
    }

    nonisolated private enum CatalogReadBack: Sendable {
        case supplier(RemoteInventorySupplierRow)
        case category(RemoteInventoryCategoryRow)
        case product(RemoteInventoryProductRow)
    }

    nonisolated private struct PreparedCatalogMutation: Sendable {
        let pending: LocalPendingChangeCASToken
        let entity: CatalogEntityReference?
        let businessFingerprint: String?
        let action: CatalogMutationAction
        let isCreate: Bool
        let isTombstone: Bool
    }

    nonisolated private static func withFreshScopedContext<Result>(
        modelContainer: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults,
        _ body: (ModelContext) throws -> Result
    ) throws -> Result {
        try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
            scope,
            defaults: defaults
        ) {
            try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                modelContainer
            )
            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            return try body(context)
        }
    }

    nonisolated private static func fetchPendingChange(
        changeID: String,
        context: ModelContext
    ) throws -> LocalPendingChange? {
        var descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { $0.changeID == changeID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated private static func prepareMutation(
        changeID: String,
        context: ModelContext,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> PreparedCatalogMutation? {
        guard let change = try fetchPendingChange(changeID: changeID, context: context),
              change.status == .pending,
              LocalPendingChangeScopeMatcher.matches(
                change,
                ownerUserID: ownerUserID,
                accountHash: scope.accountHash,
                storeIdentity: scope.storeIdentity
              ) else { return nil }
        let token = LocalPendingChangeCASToken(change)

        switch change.entityKind {
        case .supplier:
            let supplier = try findSupplier(for: change, context: context)
            if change.operation == .delete {
                guard let remoteID = change.entityRemoteID
                        ?? remoteIDFromLogicalKey(change.logicalKey) else {
                    return change.logicalKey.hasPrefix("supplier:local:")
                        ? PreparedCatalogMutation(
                            pending: token,
                            entity: supplier.map { .supplier($0.persistentModelID) },
                            businessFingerprint: nil,
                            action: .acknowledgeLocalOnly,
                            isCreate: false,
                            isTombstone: true
                        )
                        : nil
                }
                return PreparedCatalogMutation(
                    pending: token,
                    entity: supplier.map { .supplier($0.persistentModelID) },
                    businessFingerprint: nil,
                    action: .remote(.updateSupplier(
                        remoteID,
                        SyncAutomaticSupplierUpdatePayload(deletedAt: timestamp(Date()))
                    )),
                    isCreate: false,
                    isTombstone: true
                )
            }
            guard let supplier else { return nil }
            try requireCanonical(supplier.name, field: .supplierName)
            let fingerprint = LocalPendingChangeLogicalKey.supplierFingerprintHash(supplier)
            if let remoteID = supplier.remoteID {
                return PreparedCatalogMutation(
                    pending: token,
                    entity: .supplier(supplier.persistentModelID),
                    businessFingerprint: fingerprint,
                    action: .remote(.updateSupplier(
                        remoteID,
                        SyncAutomaticSupplierUpdatePayload(name: supplier.name)
                    )),
                    isCreate: false,
                    isTombstone: false
                )
            }
            return PreparedCatalogMutation(
                pending: token,
                entity: .supplier(supplier.persistentModelID),
                businessFingerprint: fingerprint,
                action: .remote(.createSupplier(SyncAutomaticSupplierCreatePayload(
                    id: try deterministicCreateID(
                        token: token,
                        ownerUserID: ownerUserID,
                        shopID: scope.shopID,
                        entityKind: .supplier
                    ),
                    ownerUserID: ownerUserID,
                    shopID: scope.shopID,
                    name: supplier.name
                ))),
                isCreate: true,
                isTombstone: false
            )

        case .productCategory:
            let category = try findCategory(for: change, context: context)
            if change.operation == .delete {
                guard let remoteID = change.entityRemoteID
                        ?? remoteIDFromLogicalKey(change.logicalKey) else {
                    return change.logicalKey.hasPrefix("category:local:")
                        ? PreparedCatalogMutation(
                            pending: token,
                            entity: category.map { .category($0.persistentModelID) },
                            businessFingerprint: nil,
                            action: .acknowledgeLocalOnly,
                            isCreate: false,
                            isTombstone: true
                        )
                        : nil
                }
                return PreparedCatalogMutation(
                    pending: token,
                    entity: category.map { .category($0.persistentModelID) },
                    businessFingerprint: nil,
                    action: .remote(.updateCategory(
                        remoteID,
                        SyncAutomaticCategoryUpdatePayload(deletedAt: timestamp(Date()))
                    )),
                    isCreate: false,
                    isTombstone: true
                )
            }
            guard let category else { return nil }
            try requireCanonical(category.name, field: .categoryName)
            let fingerprint = LocalPendingChangeLogicalKey.categoryFingerprintHash(category)
            if let remoteID = category.remoteID {
                return PreparedCatalogMutation(
                    pending: token,
                    entity: .category(category.persistentModelID),
                    businessFingerprint: fingerprint,
                    action: .remote(.updateCategory(
                        remoteID,
                        SyncAutomaticCategoryUpdatePayload(name: category.name)
                    )),
                    isCreate: false,
                    isTombstone: false
                )
            }
            return PreparedCatalogMutation(
                pending: token,
                entity: .category(category.persistentModelID),
                businessFingerprint: fingerprint,
                action: .remote(.createCategory(SyncAutomaticCategoryCreatePayload(
                    id: try deterministicCreateID(
                        token: token,
                        ownerUserID: ownerUserID,
                        shopID: scope.shopID,
                        entityKind: .productCategory
                    ),
                    ownerUserID: ownerUserID,
                    shopID: scope.shopID,
                    name: category.name
                ))),
                isCreate: true,
                isTombstone: false
            )

        case .product:
            let product = try findProduct(for: change, context: context)
            if change.operation == .delete {
                guard let remoteID = change.entityRemoteID
                        ?? remoteIDFromLogicalKey(change.logicalKey) else {
                    return change.logicalKey.hasPrefix("product:local:")
                        ? PreparedCatalogMutation(
                            pending: token,
                            entity: product.map { .product($0.persistentModelID) },
                            businessFingerprint: nil,
                            action: .acknowledgeLocalOnly,
                            isCreate: false,
                            isTombstone: true
                        )
                        : nil
                }
                return PreparedCatalogMutation(
                    pending: token,
                    entity: product.map { .product($0.persistentModelID) },
                    businessFingerprint: nil,
                    action: .remote(.updateProduct(remoteID, makeProductTombstonePayload())),
                    isCreate: false,
                    isTombstone: true
                )
            }
            guard let product else { return nil }
            try requireCanonical(product)
            let fingerprint = LocalPendingChangeLogicalKey.productFingerprintHash(product)
            if let remoteID = product.remoteID {
                return PreparedCatalogMutation(
                    pending: token,
                    entity: .product(product.persistentModelID),
                    businessFingerprint: fingerprint,
                    action: .remote(.updateProduct(
                        remoteID,
                        makeProductUpdatePayload(product, changedFields: change.changedFields)
                    )),
                    isCreate: false,
                    isTombstone: false
                )
            }
            return PreparedCatalogMutation(
                pending: token,
                entity: .product(product.persistentModelID),
                businessFingerprint: fingerprint,
                action: .remote(.createProduct(makeProductCreatePayload(
                    product,
                    id: try deterministicCreateID(
                        token: token,
                        ownerUserID: ownerUserID,
                        shopID: scope.shopID,
                        entityKind: .product
                    ),
                    ownerUserID: ownerUserID,
                    shopID: scope.shopID
                ))),
                isCreate: true,
                isTombstone: false
            )

        case .productPrice, .historySession, .importBatch:
            return nil
        }
    }

    nonisolated private static func execute(
        _ call: CatalogRemoteCall,
        remote: any SyncAutomaticCatalogRemoteWriting,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults
    ) async throws -> CatalogReadBack {
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        let readBack: CatalogReadBack
        switch call {
        case .createSupplier(let payload):
            let rows = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                try await remote.createSuppliers([payload])
            }
            guard rows.count == 1, let row = rows.first, row.id == payload.id else {
                throw CatalogPushError.responseMismatch
            }
            readBack = .supplier(row)
        case .updateSupplier(let id, let payload):
            let row = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                try await remote.updateSupplier(id: id, payload: payload)
            }
            guard row.id == id else { throw CatalogPushError.responseMismatch }
            readBack = .supplier(row)
        case .createCategory(let payload):
            let rows = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                try await remote.createCategories([payload])
            }
            guard rows.count == 1, let row = rows.first, row.id == payload.id else {
                throw CatalogPushError.responseMismatch
            }
            readBack = .category(row)
        case .updateCategory(let id, let payload):
            let row = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                try await remote.updateCategory(id: id, payload: payload)
            }
            guard row.id == id else { throw CatalogPushError.responseMismatch }
            readBack = .category(row)
        case .createProduct(let payload):
            let rows = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                try await remote.createProducts([payload])
            }
            guard rows.count == 1, let row = rows.first, row.id == payload.id else {
                throw CatalogPushError.responseMismatch
            }
            readBack = .product(row)
        case .updateProduct(let id, let payload):
            let row = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                try await remote.updateProduct(id: id, payload: payload)
            }
            guard row.id == id else { throw CatalogPushError.responseMismatch }
            readBack = .product(row)
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        switch readBack {
        case .supplier(let row):
            try Task126OwnerStoreGate.validateRemoteIdentity(
                ownerUserID: row.ownerUserID,
                shopID: row.shopID,
                scope: scope
            )
        case .category(let row):
            try Task126OwnerStoreGate.validateRemoteIdentity(
                ownerUserID: row.ownerUserID,
                shopID: row.shopID,
                scope: scope
            )
        case .product(let row):
            try Task126OwnerStoreGate.validateRemoteIdentity(
                ownerUserID: row.ownerUserID,
                shopID: row.shopID,
                scope: scope
            )
        }
        guard readBackMatches(readBack, call: call) else {
            throw CatalogPushError.responseMismatch
        }
        return readBack
    }

    nonisolated private static func readBackMatches(
        _ readBack: CatalogReadBack,
        call: CatalogRemoteCall
    ) -> Bool {
        switch (readBack, call) {
        case (.supplier(let row), .createSupplier(let payload)):
            return row.id == payload.id
                && SupabaseRemoteDateParser.parse(row.updatedAt) != nil
                && row.name == payload.name
                && SupabaseRemoteDateParser.parse(row.deletedAt) == nil
        case (.supplier(let row), .updateSupplier(_, let payload)):
            return SupabaseRemoteDateParser.parse(row.updatedAt) != nil
                && (payload.name == nil || row.name == payload.name)
                && (payload.deletedAt == nil
                    || SupabaseRemoteDateParser.parse(row.deletedAt) != nil)
        case (.category(let row), .createCategory(let payload)):
            return row.id == payload.id
                && SupabaseRemoteDateParser.parse(row.updatedAt) != nil
                && row.name == payload.name
                && SupabaseRemoteDateParser.parse(row.deletedAt) == nil
        case (.category(let row), .updateCategory(_, let payload)):
            return SupabaseRemoteDateParser.parse(row.updatedAt) != nil
                && (payload.name == nil || row.name == payload.name)
                && (payload.deletedAt == nil
                    || SupabaseRemoteDateParser.parse(row.deletedAt) != nil)
        case (.product(let row), .createProduct(let payload)):
            return row.id == payload.id
                && SupabaseRemoteDateParser.parse(row.updatedAt) != nil
                && row.barcode == payload.barcode
                && row.itemNumber == payload.itemNumber
                && row.productName == payload.productName
                && row.secondProductName == payload.secondProductName
                && equal(row.purchasePrice, payload.purchasePrice)
                && equal(row.retailPrice, payload.retailPrice)
                && row.supplierID == payload.supplierID
                && row.categoryID == payload.categoryID
                && equal(row.stockQuantity, payload.stockQuantity)
                && SupabaseRemoteDateParser.parse(row.deletedAt) == nil
        case (.product(let row), .updateProduct(_, let payload)):
            return SupabaseRemoteDateParser.parse(row.updatedAt) != nil
                && (payload.barcode == nil || row.barcode == payload.barcode)
                && (payload.itemNumber == nil || row.itemNumber == payload.itemNumber)
                && (payload.productName == nil || row.productName == payload.productName)
                && (payload.secondProductName == nil
                    || row.secondProductName == payload.secondProductName)
                && (payload.purchasePrice == nil
                    || equal(row.purchasePrice, payload.purchasePrice))
                && (payload.retailPrice == nil
                    || equal(row.retailPrice, payload.retailPrice))
                && (payload.supplierID == nil || row.supplierID == payload.supplierID)
                && (payload.categoryID == nil || row.categoryID == payload.categoryID)
                && (payload.stockQuantity == nil
                    || equal(row.stockQuantity, payload.stockQuantity))
                && (payload.deletedAt == nil
                    || SupabaseRemoteDateParser.parse(row.deletedAt) != nil)
        default:
            return false
        }
    }

    nonisolated private static func equal(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (.some(let lhs), .some(let rhs)):
            return lhs.bitPattern == rhs.bitPattern
        default:
            return false
        }
    }

    nonisolated private static func applyReadBack(
        _ readBack: CatalogReadBack,
        mutation: PreparedCatalogMutation,
        context: ModelContext,
        ownerUserID: UUID,
        plan: SyncCatalogPushPlan,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> CatalogPushOutcome {
        guard let change = try fetchPendingChange(
            changeID: mutation.pending.changeID,
            context: context
        ), LocalPendingChangeScopeMatcher.matches(
            change,
            ownerUserID: ownerUserID,
            accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity
        ) else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        let tokenMatches = mutation.pending.matches(change)
        var metadataAccepted = false
        var currentBusinessFingerprint: String?
        var outcome = CatalogPushOutcome(result: SyncCatalogPushResult(plan: plan))
        outcome.changeIDs = [mutation.pending.eventFingerprint]

        switch (readBack, mutation.entity) {
        case (.supplier(let row), .supplier(let id)):
            let supplier = try? Task126OwnerStoreGate.requireLocalModel(
                Supplier.self,
                id: id,
                in: context
            )
            currentBusinessFingerprint = supplier.map(
                LocalPendingChangeLogicalKey.supplierFingerprintHash
            )
            if let supplier, tokenMatches || mutation.isCreate {
                metadataAccepted = try mergeRemoteMetadata(row, into: supplier)
            }
            outcome.result.supplierCreates = mutation.isCreate ? 1 : 0
            outcome.result.supplierUpdates = mutation.isCreate ? 0 : 1
            outcome.supplierIDs = [row.id]
            if mutation.isTombstone { outcome.supplierTombstoneIDs = [row.id] }
            if mutation.isCreate, !tokenMatches {
                linkConcurrentCreate(change, remoteID: row.id, kind: .supplier)
            }

        case (.category(let row), .category(let id)):
            let category = try? Task126OwnerStoreGate.requireLocalModel(
                ProductCategory.self,
                id: id,
                in: context
            )
            currentBusinessFingerprint = category.map(
                LocalPendingChangeLogicalKey.categoryFingerprintHash
            )
            if let category, tokenMatches || mutation.isCreate {
                metadataAccepted = try mergeRemoteMetadata(row, into: category)
            }
            outcome.result.categoryCreates = mutation.isCreate ? 1 : 0
            outcome.result.categoryUpdates = mutation.isCreate ? 0 : 1
            outcome.categoryIDs = [row.id]
            if mutation.isTombstone { outcome.categoryTombstoneIDs = [row.id] }
            if mutation.isCreate, !tokenMatches {
                linkConcurrentCreate(change, remoteID: row.id, kind: .productCategory)
            }

        case (.product(let row), .product(let id)):
            let product = try? Task126OwnerStoreGate.requireLocalModel(
                Product.self,
                id: id,
                in: context
            )
            currentBusinessFingerprint = product.map(
                LocalPendingChangeLogicalKey.productFingerprintHash
            )
            if let product, tokenMatches || mutation.isCreate {
                metadataAccepted = try mergeRemoteMetadata(row, into: product)
            }
            outcome.result.productCreates = mutation.isCreate ? 1 : 0
            outcome.result.productUpdates = mutation.isCreate ? 0 : 1
            outcome.productIDs = [row.id]
            if mutation.isTombstone { outcome.productTombstoneIDs = [row.id] }
            if mutation.isCreate, !tokenMatches {
                linkConcurrentCreate(change, remoteID: row.id, kind: .product)
            }

        case (.supplier(let row), nil):
            outcome.result.supplierUpdates = 1
            outcome.supplierIDs = [row.id]
            if mutation.isTombstone { outcome.supplierTombstoneIDs = [row.id] }
            metadataAccepted = tokenMatches && mutation.isTombstone
        case (.category(let row), nil):
            outcome.result.categoryUpdates = 1
            outcome.categoryIDs = [row.id]
            if mutation.isTombstone { outcome.categoryTombstoneIDs = [row.id] }
            metadataAccepted = tokenMatches && mutation.isTombstone
        case (.product(let row), nil):
            outcome.result.productUpdates = 1
            outcome.productIDs = [row.id]
            if mutation.isTombstone { outcome.productTombstoneIDs = [row.id] }
            metadataAccepted = tokenMatches && mutation.isTombstone
        default:
            throw CatalogPushError.responseMismatch
        }

        let businessMatches = mutation.isTombstone
            || currentBusinessFingerprint == mutation.businessFingerprint
        if tokenMatches, businessMatches, metadataAccepted {
            change.status = .acknowledged
            change.updatedAt = Date()
        }
        try enqueueCatalogSyncEventWithLeaseHeld(
            context: context,
            ownerUserID: ownerUserID,
            outcome: outcome,
            scope: scope
        )
        try context.save()
        return outcome
    }

    nonisolated private static func linkConcurrentCreate(
        _ change: LocalPendingChange,
        remoteID: UUID,
        kind: LocalPendingChangeEntityKind
    ) {
        change.entityRemoteID = remoteID
        change.logicalKey = LocalPendingChangeLogicalKey.remoteEntity(
            kind: kind,
            remoteID: remoteID
        )
        if change.status == .superseded {
            change.operation = .delete
            change.status = .pending
            change.changedFields = ["tombstone"]
        } else if change.operation == .create {
            change.operation = .update
            change.status = .pending
        }
        change.idempotencyKey = UUID().uuidString.lowercased()
        change.lastAttemptAt = nil
        change.updatedAt = Date()
    }

    nonisolated private static func mergeRemoteMetadata(
        _ row: RemoteInventorySupplierRow,
        into supplier: Supplier
    ) throws -> Bool {
        try mergeRemoteMetadata(
            remoteID: row.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(row.deletedAt),
            currentRemoteID: supplier.remoteID,
            currentUpdatedAt: supplier.remoteUpdatedAt,
            currentDeletedAt: supplier.remoteDeletedAt
        ) { id, updatedAt, deletedAt in
            supplier.remoteID = id
            supplier.remoteUpdatedAt = updatedAt
            supplier.remoteDeletedAt = deletedAt
        }
    }

    nonisolated private static func mergeRemoteMetadata(
        _ row: RemoteInventoryCategoryRow,
        into category: ProductCategory
    ) throws -> Bool {
        try mergeRemoteMetadata(
            remoteID: row.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(row.deletedAt),
            currentRemoteID: category.remoteID,
            currentUpdatedAt: category.remoteUpdatedAt,
            currentDeletedAt: category.remoteDeletedAt
        ) { id, updatedAt, deletedAt in
            category.remoteID = id
            category.remoteUpdatedAt = updatedAt
            category.remoteDeletedAt = deletedAt
        }
    }

    nonisolated private static func mergeRemoteMetadata(
        _ row: RemoteInventoryProductRow,
        into product: Product
    ) throws -> Bool {
        // Catalog push never owns primary-image metadata. A concurrent image
        // replace/remove therefore cannot be undone by a stale catalog row.
        try mergeRemoteMetadata(
            remoteID: row.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(row.deletedAt),
            currentRemoteID: product.remoteID,
            currentUpdatedAt: product.remoteUpdatedAt,
            currentDeletedAt: product.remoteDeletedAt
        ) { id, updatedAt, deletedAt in
            product.remoteID = id
            product.remoteUpdatedAt = updatedAt
            product.remoteDeletedAt = deletedAt
        }
    }

    nonisolated private static func mergeRemoteMetadata(
        remoteID: UUID,
        remoteUpdatedAt: Date?,
        remoteDeletedAt: Date?,
        currentRemoteID: UUID?,
        currentUpdatedAt: Date?,
        currentDeletedAt: Date?,
        apply: (UUID, Date?, Date?) -> Void
    ) throws -> Bool {
        if let currentRemoteID, currentRemoteID != remoteID {
            throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
        }
        if let currentUpdatedAt, let remoteUpdatedAt {
            if currentUpdatedAt > remoteUpdatedAt { return false }
            if currentUpdatedAt == remoteUpdatedAt,
               currentDeletedAt != remoteDeletedAt {
                return false
            }
        }
        apply(remoteID, remoteUpdatedAt ?? currentUpdatedAt, remoteDeletedAt)
        return true
    }

    nonisolated private static func enqueueCatalogSyncEventWithLeaseHeld(
        context: ModelContext,
        ownerUserID: UUID,
        outcome: CatalogPushOutcome,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        guard outcome.result.totalChanged > 0 else { return }
        let supplierTombstoneIDs = Set(outcome.supplierTombstoneIDs)
        let categoryTombstoneIDs = Set(outcome.categoryTombstoneIDs)
        let tombstoneIDs = Set(outcome.productTombstoneIDs)
        let nonTombstoneSupplierIDs = outcome.supplierIDs.filter { !supplierTombstoneIDs.contains($0) }
        let nonTombstoneCategoryIDs = outcome.categoryIDs.filter { !categoryTombstoneIDs.contains($0) }
        let nonTombstoneProductIDs = outcome.productIDs.filter { !tombstoneIDs.contains($0) }
        let eventType = nonTombstoneSupplierIDs.isEmpty &&
            nonTombstoneCategoryIDs.isEmpty &&
            nonTombstoneProductIDs.isEmpty &&
            (!outcome.supplierTombstoneIDs.isEmpty ||
                !outcome.categoryTombstoneIDs.isEmpty ||
                !outcome.productTombstoneIDs.isEmpty) ? "catalog_tombstone" : "catalog_changed"
        let entityIDs = try AutomaticSyncEventOutboxWriter.entityIDs([
            "supplier_ids": outcome.supplierIDs,
            "category_ids": outcome.categoryIDs,
            "product_ids": outcome.productIDs
        ])
        try AutomaticSyncEventOutboxWriter.enqueueWithValidatedScopeLeaseHeld(
            context: context,
            ownerUserID: ownerUserID,
            domain: "catalog",
            eventType: eventType,
            changedCount: outcome.result.totalChanged,
            entityIDs: entityIDs,
            metadata: .object([
                "source": .string("ios")
            ]),
            source: "ios_catalog_automatic_push",
            entityIDsShape: "supplier_ids:count=\(outcome.supplierIDs.count);category_ids:count=\(outcome.categoryIDs.count);product_ids:count=\(outcome.productIDs.count)",
            metadataShape: "source=ios_catalog_automatic_push;suppliers=\(outcome.result.supplierCreates + outcome.result.supplierUpdates);categories=\(outcome.result.categoryCreates + outcome.result.categoryUpdates);products=\(outcome.result.productCreates + outcome.result.productUpdates);supplierTombstones=\(outcome.supplierTombstoneIDs.count);categoryTombstones=\(outcome.categoryTombstoneIDs.count);productTombstones=\(outcome.productTombstoneIDs.count)",
            clientEventFingerprint: catalogEventFingerprint(
                eventType: eventType,
                outcome: outcome
            ),
            scope: scope
        )
    }

    nonisolated private static func catalogEventFingerprint(
        eventType: String,
        outcome: CatalogPushOutcome
    ) -> String {
        [
            outcome.result.plan?.idempotencyKey ?? "catalog:unknown",
            "event:\(eventType)",
            "changes:\(outcome.changeIDs.sorted().joined(separator: ","))",
            "suppliers:\(fingerprintIDs(outcome.supplierIDs))",
            "categories:\(fingerprintIDs(outcome.categoryIDs))",
            "products:\(fingerprintIDs(outcome.productIDs))",
            "supplierTombstones:\(fingerprintIDs(outcome.supplierTombstoneIDs))",
            "categoryTombstones:\(fingerprintIDs(outcome.categoryTombstoneIDs))",
            "productTombstones:\(fingerprintIDs(outcome.productTombstoneIDs))"
        ].joined(separator: "|")
    }

    nonisolated private static func fingerprintIDs(_ ids: [UUID]) -> String {
        ids.map { $0.uuidString.lowercased() }.sorted().joined(separator: ",")
    }

    nonisolated private static func findSupplier(for change: LocalPendingChange, context: ModelContext) throws -> Supplier? {
        if let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) {
            return try fetchSupplier(remoteID: remoteID, context: context)
        }
        return try context.fetch(FetchDescriptor<Supplier>()).first {
            pendingKeys(for: $0).contains(change.logicalKey)
        }
    }

    nonisolated private static func findCategory(for change: LocalPendingChange, context: ModelContext) throws -> ProductCategory? {
        if let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) {
            return try fetchCategory(remoteID: remoteID, context: context)
        }
        return try context.fetch(FetchDescriptor<ProductCategory>()).first {
            pendingKeys(for: $0).contains(change.logicalKey)
        }
    }

    nonisolated private static func findProduct(for change: LocalPendingChange, context: ModelContext) throws -> Product? {
        if let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) {
            return try fetchProduct(remoteID: remoteID, context: context)
        }
        return try context.fetch(FetchDescriptor<Product>()).first {
            pendingKeys(for: $0).contains(change.logicalKey)
        }
    }

    nonisolated private static func apply(_ row: RemoteInventorySupplierRow, to supplier: Supplier) {
        supplier.remoteID = row.id
        supplier.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        supplier.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    }

    nonisolated private static func apply(_ row: RemoteInventoryCategoryRow, to category: ProductCategory) {
        category.remoteID = row.id
        category.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        category.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    }

    nonisolated private static func apply(_ row: RemoteInventoryProductRow, to product: Product) {
        product.remoteID = row.id
        product.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        product.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    }

    nonisolated private static func makeProductCreatePayload(
        _ product: Product,
        id: UUID,
        ownerUserID: UUID,
        shopID: UUID?
    ) -> SyncAutomaticProductCreatePayload {
        SyncAutomaticProductCreatePayload(
            id: id,
            ownerUserID: ownerUserID,
            shopID: shopID,
            barcode: product.barcode,
            itemNumber: product.itemNumber,
            productName: product.productName,
            secondProductName: product.secondProductName,
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice,
            supplierID: product.supplier?.remoteID,
            categoryID: product.category?.remoteID,
            stockQuantity: product.stockQuantity
        )
    }

    nonisolated private static func requireCanonical(_ product: Product) throws {
        try requireCanonical(product.barcode, field: .barcode)
        try requireCanonicalOptional(
            product.itemNumber,
            field: .itemNumber,
            display: false
        )
        try requireCanonicalOptional(
            product.productName,
            field: .productName,
            display: true
        )
        try requireCanonicalOptional(
            product.secondProductName,
            field: .secondProductName,
            display: true
        )
    }

    nonisolated private static func requireCanonical(
        _ value: String,
        field: CatalogTextField
    ) throws {
        let normalized = try CatalogTextPolicy.validate(value, for: field).value
        guard scalarExactEqual(value, normalized) else {
            throw CatalogPushError.nonCanonicalCatalogText(field)
        }
    }

    nonisolated private static func requireCanonicalOptional(
        _ value: String?,
        field: CatalogTextField,
        display: Bool
    ) throws {
        guard let value else { return }
        let normalized = display
            ? try CatalogTextPersistenceBoundary.validatedOptionalDisplay(
                value,
                field: field
            )
            : try CatalogTextPersistenceBoundary.validatedOptionalStrict(
                value,
                field: field
            )
        guard let normalized, scalarExactEqual(value, normalized) else {
            throw CatalogPushError.nonCanonicalCatalogText(field)
        }
    }

    nonisolated private static func scalarExactEqual(
        _ lhs: String,
        _ rhs: String
    ) -> Bool {
        Array(lhs.unicodeScalars) == Array(rhs.unicodeScalars)
    }

    nonisolated private static func deterministicCreateID(
        token: LocalPendingChangeCASToken,
        ownerUserID: UUID,
        shopID: UUID,
        entityKind: LocalPendingChangeEntityKind
    ) throws -> UUID {
        let idempotencyKey = token.idempotencyKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !idempotencyKey.isEmpty else {
            throw CatalogPushError.invalidIdempotencyKey
        }
        let material = [
            "catalog-create-v1",
            ownerUserID.uuidString.lowercased(),
            shopID.uuidString.lowercased(),
            entityKind.rawValue,
            idempotencyKey
        ].joined(separator: "|")
        var bytes = Array(SHA256.hash(data: Data(material.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    nonisolated private static func makeProductTombstonePayload() -> SyncAutomaticProductUpdatePayload {
        SyncAutomaticProductUpdatePayload(
            barcode: nil,
            itemNumber: nil,
            productName: nil,
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            deletedAt: Self.timestamp(Date())
        )
    }

    nonisolated static func makeProductUpdatePayload(
        _ product: Product,
        changedFields: [String]
    ) -> SyncAutomaticProductUpdatePayload {
        let fields = Set(changedFields.map(normalizedProductChangedField))
        return SyncAutomaticProductUpdatePayload(
            barcode: fields.contains("barcode") ? product.barcode : nil,
            itemNumber: fields.contains("itemnumber") ? product.itemNumber : nil,
            productName: fields.contains("productname") ? product.productName : nil,
            secondProductName: fields.contains("secondproductname") ? product.secondProductName : nil,
            purchasePrice: fields.contains("purchaseprice") ? product.purchasePrice : nil,
            retailPrice: fields.contains("retailprice") ? product.retailPrice : nil,
            supplierID: fields.contains("supplier") ? product.supplier?.remoteID : nil,
            categoryID: fields.contains("category") ? product.category?.remoteID : nil,
            stockQuantity: fields.contains("stockquantity") ? product.stockQuantity : nil,
            deletedAt: fields.contains("tombstone") ? product.remoteDeletedAt.map(timestamp) : nil
        )
    }

    nonisolated private static func normalizedProductChangedField(_ field: String) -> String {
        switch field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "suppliername":
            return "supplier"
        case "categoryname":
            return "category"
        default:
            return field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    nonisolated private static func pendingKeys(for supplier: Supplier) -> Set<String> {
        Set([
            LocalPendingChangeLogicalKey.supplier(remoteID: supplier.remoteID, name: supplier.name),
            LocalPendingChangeLogicalKey.supplier(remoteID: nil, name: supplier.name)
        ])
    }

    nonisolated private static func isStoreCompatible(
        _ change: LocalPendingChange,
        storeIdentity: LocalStoreIdentity?
    ) -> Bool {
        guard let storeIdentity else { return true }
        return Task126OwnerStoreScope.normalizedStoreId(change.storeId) == storeIdentity.storeId
    }

    nonisolated private static func pendingKeys(for category: ProductCategory) -> Set<String> {
        Set([
            LocalPendingChangeLogicalKey.category(remoteID: category.remoteID, name: category.name),
            LocalPendingChangeLogicalKey.category(remoteID: nil, name: category.name)
        ])
    }

    nonisolated private static func pendingKeys(for product: Product) -> Set<String> {
        Set([
            LocalPendingChangeLogicalKey.product(remoteID: product.remoteID, barcode: product.barcode),
            LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: product.barcode)
        ])
    }

    nonisolated private static func acknowledge(changeIDs: [String], changes: [LocalPendingChange]) {
        let ids = Set(changeIDs)
        let timestamp = Date()
        for change in changes where ids.contains(change.changeID) {
            change.status = .acknowledged
            change.updatedAt = timestamp
        }
    }

    nonisolated private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
