import Foundation
import SwiftData
import CryptoKit
import Security
#if canImport(Darwin)
import Darwin
#endif
// TASK145_COST39_BEGIN oslog-import
#if DEBUG
import OSLog
#endif
// TASK145_COST39_END oslog-import

/// Current business-body readback, independent of the immutable cloud checkpoint.
/// Only validated remote apply/ACK writes these sparse local-only receipts.
/// They are neither pending business intent nor sync-event RPC work.
nonisolated enum LocalCatalogBodyProofStore {
    static let domain = "local_catalog_body_proof"
    private static let format = "local_catalog_body_v1"
    private static let batchSize = 256

    private struct Body: Codable {
        let generationID: UUID
        let kind: String
        let remoteID: UUID
        let canonical: String
        let updatedAt: Date?
        let deletedAt: Date?
        let payloadVersion: Int?
    }

    static func record(_ row: RemoteInventorySupplierRow, context: ModelContext,
                       scope: Task126VerifiedOwnerStoreScope) throws {
        try record(kind: .supplier, id: row.id,
            canonical: ManualPushFingerprintNormalizer.supplier(remoteID: row.id, name: row.name).canonicalString,
            updatedAt: SupabaseRemoteDateParser.parse(row.updatedAt), deletedAt: SupabaseRemoteDateParser.parse(row.deletedAt),
            context: context, scope: scope)
    }

    static func record(_ row: RemoteInventoryCategoryRow, context: ModelContext,
                       scope: Task126VerifiedOwnerStoreScope) throws {
        try record(kind: .productCategory, id: row.id,
            canonical: ManualPushFingerprintNormalizer.category(remoteID: row.id, name: row.name).canonicalString,
            updatedAt: SupabaseRemoteDateParser.parse(row.updatedAt), deletedAt: SupabaseRemoteDateParser.parse(row.deletedAt),
            context: context, scope: scope)
    }

    static func record(_ row: RemoteInventoryProductRow, context: ModelContext,
                       scope: Task126VerifiedOwnerStoreScope) throws {
        try record(kind: .product, id: row.id,
            canonical: ManualPushFingerprintNormalizer.product(barcode: row.barcode, itemNumber: row.itemNumber,
                productName: row.productName, secondProductName: row.secondProductName,
                purchasePrice: row.purchasePrice, retailPrice: row.retailPrice, stockQuantity: row.stockQuantity,
                supplierRemoteID: row.supplierID, categoryRemoteID: row.categoryID).canonicalString,
            updatedAt: SupabaseRemoteDateParser.parse(row.updatedAt), deletedAt: SupabaseRemoteDateParser.parse(row.deletedAt),
            context: context, scope: scope)
    }

    static func record(_ row: RemoteInventoryProductPriceRow, context: ModelContext,
                       scope: Task126VerifiedOwnerStoreScope) throws {
        guard let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.effectiveAt),
              let createdAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.createdAt),
              let type = SupabasePullPreviewNormalizer.normalizedPriceType(row.type),
              let updatedAt = SupabaseRemoteDateParser.parse(row.updatedAt) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let amount = try row.priceCanonical.map { _ in try ShopSyncRecoveryRowContract.canonicalPrice(row).doubleValue } ?? row.price
        try record(kind: LocalPendingChangeEntityKind.productPrice.rawValue, id: row.id,
            canonical: priceBody(parent: row.productID, type: type, price: amount,
                effectiveAt: effectiveAt, createdAt: createdAt, sourceHash: ShopSyncRecoveryCanonical.sha256(row.source ?? ""),
                noteHash: ShopSyncRecoveryCanonical.sha256(row.note ?? "")),
            updatedAt: updatedAt, deletedAt: nil, context: context, scope: scope)
    }

    static func record(_ row: RemoteSharedSheetSessionRow, context: ModelContext,
                       scope: Task126VerifiedOwnerStoreScope) throws {
        try record(kind: LocalPendingChangeEntityKind.historySession.rawValue, id: row.remoteID,
            canonical: HistorySessionPayloadCodec.fingerprintHash(for: row),
            updatedAt: SupabaseRemoteDateParser.parse(row.updatedAt), deletedAt: SupabaseRemoteDateParser.parse(row.deletedAt),
            context: context, scope: scope, payloadVersion: row.payloadVersion)
    }

    private static func record(kind: SupabaseCatalogBaselineEntityType, id: UUID, canonical: String,
                               updatedAt: Date?, deletedAt: Date?, context: ModelContext,
                               scope: Task126VerifiedOwnerStoreScope, overlayGenerationID: UUID? = nil) throws {
        try record(kind: kind.rawValue, id: id, canonical: canonical, updatedAt: updatedAt,
            deletedAt: deletedAt, context: context, scope: scope, overlayGenerationID: overlayGenerationID)
    }

    private static func record(kind: String, id: UUID, canonical: String,
                               updatedAt: Date?, deletedAt: Date?, context: ModelContext,
                               scope: Task126VerifiedOwnerStoreScope, overlayGenerationID: UUID? = nil,
                               payloadVersion: Int? = nil) throws {
        let generationID: UUID
        if let overlayGenerationID { generationID = overlayGenerationID }
        else {
            guard let manifest = Task126OwnerStoreGate.activeManifestWithLeaseHeld(context.container) else { return }
            guard manifest.accountHash == scope.accountHash, manifest.shopID == scope.shopID,
                  manifest.storeIdentity == scope.storeIdentity, manifest.deviceIdentityHash == scope.deviceIdentityHash else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            generationID = manifest.generationID
        }
        guard updatedAt != nil else { throw SyncStoreGenerationError.activationReadBackFailed }
        let key = recordID(kind: kind, id: id)
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate { $0.id == key })
        descriptor.fetchLimit = 2
        let existing = try context.fetch(descriptor)
        guard existing.count <= 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
        if let old = existing.first { context.delete(old) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Body(generationID: generationID, kind: kind,
            remoteID: id, canonical: canonical, updatedAt: updatedAt, deletedAt: deletedAt, payloadVersion: payloadVersion))
        guard data.count <= ShopSyncRecoveryLimits.maximumGenerationManifestBytes,
              let json = String(data: data, encoding: .utf8) else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
        let now = Date()
        context.insert(SyncEventOutboxEntry(id: key,
            ownerUserID: scope.ownerUserID.uuidString.lowercased(), storeId: scope.storeIdentity.storeId,
            localStoreId: scope.storeIdentity.localStoreId, syncProtocolVersion: scope.storeIdentity.syncProtocolVersion,
            schemaVersion: scope.storeIdentity.schemaVersion, storeEpoch: scope.storeIdentity.storeEpoch,
            clientEventID: key, batchID: key, domain: domain, eventType: kind,
            changedCount: deletedAt == nil ? 1 : 0, entityIDsShape: ShopSyncRecoveryCanonical.sha256(json),
            metadataShape: format, metadataPayloadJSON: json, status: .localOnly, nextRetryAt: now,
            createdAt: now, updatedAt: now, sourceDeviceID: scope.deviceInstallID))
    }

    /// The owned overlay already proves the source intent and fences both
    /// stores. This receipt describes the preserved local projection only;
    /// it grants no remote ACK or convergence and does not alter pending keys.
    static func recordOverlayBody(_ row: Product, context: ModelContext,
                                  scope: Task126VerifiedOwnerStoreScope, generationID: UUID) throws {
        guard let id = row.remoteID else { return }
        try record(kind: .product, id: id,
            canonical: ManualPushFingerprintNormalizer.product(barcode: row.barcode, itemNumber: row.itemNumber,
                productName: row.productName, secondProductName: row.secondProductName,
                purchasePrice: row.purchasePrice, retailPrice: row.retailPrice, stockQuantity: row.stockQuantity,
                supplierRemoteID: row.supplier?.remoteID, categoryRemoteID: row.category?.remoteID).canonicalString,
            updatedAt: row.remoteUpdatedAt, deletedAt: row.remoteDeletedAt, context: context,
            scope: scope, overlayGenerationID: generationID)
    }

    static func recordOverlayBody(_ row: Supplier, context: ModelContext,
                                  scope: Task126VerifiedOwnerStoreScope, generationID: UUID) throws {
        guard let id = row.remoteID else { return }
        try record(kind: .supplier, id: id,
            canonical: ManualPushFingerprintNormalizer.supplier(remoteID: id, name: row.name).canonicalString,
            updatedAt: row.remoteUpdatedAt, deletedAt: row.remoteDeletedAt, context: context,
            scope: scope, overlayGenerationID: generationID)
    }

    static func recordOverlayBody(_ row: ProductCategory, context: ModelContext,
                                  scope: Task126VerifiedOwnerStoreScope, generationID: UUID) throws {
        guard let id = row.remoteID else { return }
        try record(kind: .productCategory, id: id,
            canonical: ManualPushFingerprintNormalizer.category(remoteID: id, name: row.name).canonicalString,
            updatedAt: row.remoteUpdatedAt, deletedAt: row.remoteDeletedAt, context: context,
            scope: scope, overlayGenerationID: generationID)
    }

    /// Verifies the already persisted projection of a previous owned transfer.
    /// The caller separately proves the exact original manual request/members
    /// and generation mapping. This grants neither an ACK nor a new request.
    static func matchesTransferredProductBody(_ row: Product, context: ModelContext,
                                             scope: Task126VerifiedOwnerStoreScope,
                                             generationID: UUID) throws -> Bool {
        guard let id = row.remoteID else { return false }
        let key = recordID(kind: SupabaseCatalogBaselineEntityType.product.rawValue, id: id)
        let proofDomain = domain
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate {
            $0.domain == proofDomain && $0.id == key
        })
        descriptor.fetchLimit = 2
        let entries = try context.fetch(descriptor)
        guard entries.count <= 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
        guard let entry = entries.first else { return false }
        let proof = try decode(entry, accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash, generationID: generationID)
        let canonical = ManualPushFingerprintNormalizer.product(barcode: row.barcode, itemNumber: row.itemNumber,
            productName: row.productName, secondProductName: row.secondProductName,
            purchasePrice: row.purchasePrice, retailPrice: row.retailPrice, stockQuantity: row.stockQuantity,
            supplierRemoteID: row.supplier?.remoteID, categoryRemoteID: row.category?.remoteID).canonicalString
        return proof.kind == SupabaseCatalogBaselineEntityType.product.rawValue && proof.remoteID == id
            && proof.updatedAt == row.remoteUpdatedAt && proof.deletedAt == row.remoteDeletedAt
            && proof.canonical == canonical
    }

    /// Called off Main under a before/after physical-file fence. Retained
    /// pending intent explains only its own exact current business body.
    static func validate(container: ModelContainer, manifest: SyncStoreGenerationManifest, storeURL: URL) throws {
// TASK145_COST39_BEGIN validate-start
#if DEBUG
        let costStartNS = DispatchTime.now().uptimeNanoseconds
        var costPhaseStartNS = costStartNS
        var costPhase = 0 // setup, products, suppliers, categories, ledger, prices, history
        var costNS = [UInt64](repeating: 0, count: 7)
        var costReturnedNormally = false
        func costEnter(_ next: Int) {
            let now = DispatchTime.now().uptimeNanoseconds
            costNS[costPhase] &+= now &- costPhaseStartNS
            costPhase = next
            costPhaseStartNS = now
        }
        defer {
            let ended = DispatchTime.now().uptimeNanoseconds
            costNS[costPhase] &+= ended &- costPhaseStartNS
            let elapsed = ended &- costStartNS
            Logger(subsystem: "com.niwcyber.iOSMerchandiseControl", category: "LocalBodyQualification").notice("populated-qualification-cost kind.validate start_ns.\(costStartNS, privacy: .public) elapsed_ns.\(elapsed, privacy: .public) returned.\(costReturnedNormally, privacy: .public) cancelled.\(Task.isCancelled, privacy: .public) last_phase.\(costPhase, privacy: .public) setup_ns.\(costNS[0], privacy: .public) products_ns.\(costNS[1], privacy: .public) suppliers_ns.\(costNS[2], privacy: .public) categories_ns.\(costNS[3], privacy: .public) ledger_ns.\(costNS[4], privacy: .public) prices_ns.\(costNS[5], privacy: .public) history_ns.\(costNS[6], privacy: .public)")
        }
#endif
// TASK145_COST39_END validate-start
        let context = ModelContext(container); context.autosaveEnabled = false
        let ownerHash = manifest.accountHash
        let resolutions = try LocalCatalogConflictResolutionStore.receipts(context: context)
        guard resolutions.allSatisfy({ $0.1.currentGenerationID == manifest.generationID }) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let resolved = Set(resolutions.flatMap { $0.1.resolvedChangeIDs })
        var pendingDescriptor = FetchDescriptor<LocalPendingChange>(predicate: #Predicate {
            $0.statusRaw != "superseded" && $0.statusRaw != "acknowledged"
        })
        pendingDescriptor.fetchLimit = LocalPendingChangeAccumulator.defaultMaxActiveChanges + resolved.count + 1
        let pending = try context.fetch(pendingDescriptor).filter { !resolved.contains($0.changeID) }
        guard pending.count <= LocalPendingChangeAccumulator.defaultMaxActiveChanges,
              pending.allSatisfy({ change in
                  guard let rawOwner = change.ownerUserID, let owner = UUID(uuidString: rawOwner) else { return false }
                  return AccountBindingStore.accountHash(for: owner) == ownerHash
                      && change.storeId == manifest.storeIdentity.storeId
                      && change.localStoreId == manifest.storeIdentity.localStoreId
                      && change.schemaVersion == manifest.storeIdentity.schemaVersion
                      && change.syncProtocolVersion == manifest.storeIdentity.syncProtocolVersion
                      && change.storeEpoch == manifest.storeIdentity.storeEpoch
              }) else { throw SyncStoreGenerationError.activationReadBackFailed }
        let grouped = Dictionary(grouping: pending, by: \.logicalKey)
        let runID = manifest.baselineRunID
        var run = FetchDescriptor<SupabaseCatalogBaselineRun>(predicate: #Predicate { $0.baselineRunID == runID })
        run.fetchLimit = 2
        let runs = try context.fetch(run)
        guard runs.count == 1, let baseline = runs.first, baseline.status == "valid",
              AccountBindingStore.accountHash(for: baseline.ownerUserUUID) == manifest.accountHash,
              baseline.fingerprintSchemaVersion == SupabaseCatalogFingerprintSchema.currentVersion else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
// TASK145_COST39_BEGIN validate-phase-1
#if DEBUG
        costEnter(1)
#endif
// TASK145_COST39_END validate-phase-1
        try scan(Product.self, kind: .product, context: context, manifest: manifest, pending: grouped,
            sort: [SortDescriptor(\Product.remoteID)]) { row in
                let key = LocalPendingChangeLogicalKey.product(remoteID: row.remoteID, barcode: row.barcode)
                let needsIntentHash = grouped[key]?.contains { $0.entityKindRaw == SupabaseCatalogBaselineEntityType.product.rawValue } ?? false
                return (row.remoteID, row.remoteUpdatedAt, row.remoteDeletedAt,
                 ManualPushFingerprintNormalizer.product(barcode: row.barcode, itemNumber: row.itemNumber,
                    productName: row.productName, secondProductName: row.secondProductName,
                    purchasePrice: row.purchasePrice, retailPrice: row.retailPrice, stockQuantity: row.stockQuantity,
                    supplierRemoteID: row.supplier?.remoteID, categoryRemoteID: row.category?.remoteID).canonicalString,
                 key,
                 needsIntentHash ? LocalPendingChangeLogicalKey.productFingerprintHash(row) : "")
            }
// TASK145_COST39_BEGIN validate-phase-2
#if DEBUG
        costEnter(2)
#endif
// TASK145_COST39_END validate-phase-2
        try scan(Supplier.self, kind: .supplier, context: context, manifest: manifest, pending: grouped,
            sort: [SortDescriptor(\Supplier.remoteID)]) { row in
                let key = LocalPendingChangeLogicalKey.supplier(remoteID: row.remoteID, name: row.name)
                let needsIntentHash = grouped[key]?.contains { $0.entityKindRaw == SupabaseCatalogBaselineEntityType.supplier.rawValue } ?? false
                return (row.remoteID, row.remoteUpdatedAt, row.remoteDeletedAt,
                 ManualPushFingerprintNormalizer.supplier(remoteID: row.remoteID, name: row.name).canonicalString,
                 key,
                 needsIntentHash ? LocalPendingChangeLogicalKey.supplierFingerprintHash(row) : "")
            }
// TASK145_COST39_BEGIN validate-phase-3
#if DEBUG
        costEnter(3)
#endif
// TASK145_COST39_END validate-phase-3
        try scan(ProductCategory.self, kind: .productCategory, context: context, manifest: manifest, pending: grouped,
            sort: [SortDescriptor(\ProductCategory.remoteID)]) { row in
                let key = LocalPendingChangeLogicalKey.category(remoteID: row.remoteID, name: row.name)
                let needsIntentHash = grouped[key]?.contains { $0.entityKindRaw == SupabaseCatalogBaselineEntityType.productCategory.rawValue } ?? false
                return (row.remoteID, row.remoteUpdatedAt, row.remoteDeletedAt,
                 ManualPushFingerprintNormalizer.category(remoteID: row.remoteID, name: row.name).canonicalString,
                 key,
                 needsIntentHash ? LocalPendingChangeLogicalKey.categoryFingerprintHash(row) : "")
            }
// TASK145_COST39_BEGIN validate-phase-4
#if DEBUG
        costEnter(4)
#endif
// TASK145_COST39_END validate-phase-4
        let ledger = try ShopSyncRecoveryLedger(generationStoreURL: storeURL, mode: .readExisting)
// TASK145_COST39_BEGIN validate-phase-5
#if DEBUG
        costEnter(5)
#endif
// TASK145_COST39_END validate-phase-5
        try validatePrices(context: context, manifest: manifest, pending: grouped, ledger: ledger)
// TASK145_COST39_BEGIN validate-phase-6
#if DEBUG
        costEnter(6)
#endif
// TASK145_COST39_END validate-phase-6
        try validateHistory(context: context, manifest: manifest, pending: grouped, ledger: ledger)
// TASK145_COST39_BEGIN validate-returned
#if DEBUG
        costReturnedNormally = true
#endif
// TASK145_COST39_END validate-returned
    }

    private static func priceBody(parent: UUID, type: String, price: Double, effectiveAt: Date,
                                  createdAt: Date, sourceHash: String, noteHash: String) -> String {
        ShopSyncRecoveryCanonical.joined(parent.uuidString.lowercased(), type, String(price.bitPattern),
            ProductPriceEffectiveAtCanonicalizer.canonicalString(from: effectiveAt),
            ProductPriceEffectiveAtCanonicalizer.canonicalString(from: createdAt), sourceHash, noteHash)
    }

    private struct PhysicalPriceParent {
        let remoteID: UUID?
        let deletedAt: Date?
    }

    /// Read the current physical relationships in one bounded page. The keys
    /// come from the price rows, never from a ledger or an expected remote ID.
    /// These values live only until this page is consumed inside the existing
    /// before/after physical-file fence; they grant no reusable authority.
    private static func physicalPriceParents(_ rows: [ProductPrice], context: ModelContext) throws
        -> [PersistentIdentifier: PhysicalPriceParent] {
        guard rows.count <= batchSize else { throw SyncStoreGenerationError.generationResourceBudgetExceeded }
        let ids = Array(Set(rows.compactMap { $0.product?.persistentModelID }))
        guard !ids.isEmpty else { return [:] }
        var descriptor = FetchDescriptor<Product>(predicate: #Predicate { ids.contains($0.persistentModelID) })
        descriptor.fetchLimit = ids.count + 1
        descriptor.propertiesToFetch = [\Product.remoteID, \Product.remoteDeletedAt]
        let parents = try context.fetch(descriptor)
        var values: [PersistentIdentifier: PhysicalPriceParent] = [:]
        for parent in parents {
            let id = parent.persistentModelID
            guard values[id] == nil, ids.contains(id) else { throw SyncStoreGenerationError.activationReadBackFailed }
            values[id] = PhysicalPriceParent(remoteID: parent.remoteID, deletedAt: parent.remoteDeletedAt)
        }
        guard values.count == ids.count else { throw SyncStoreGenerationError.activationReadBackFailed }
        return values
    }

    private static func priceBody(_ row: ProductPrice, parents: [PersistentIdentifier: PhysicalPriceParent]) throws -> String {
        guard let physicalID = row.product?.persistentModelID, let parent = parents[physicalID],
              let parentID = parent.remoteID, parent.deletedAt == nil,
              row.price.isFinite, row.price >= 0 else { throw SyncStoreGenerationError.activationReadBackFailed }
        return priceBody(parent: parentID, type: row.type.rawValue, price: row.price,
            effectiveAt: row.effectiveAt, createdAt: row.createdAt,
            sourceHash: ShopSyncRecoveryCanonical.sha256(row.source ?? ""),
            noteHash: ShopSyncRecoveryCanonical.sha256(row.note ?? ""))
    }

    private static func priceIntentMatches(_ row: ProductPrice, pending: [String: [LocalPendingChange]]) -> Bool {
        let key = LocalPendingChangeLogicalKey.productPrice(productRemoteID: row.product?.remoteID,
            productBarcode: row.product?.barcode ?? "", type: row.type, effectiveAt: row.effectiveAt)
        let fingerprint = LocalPendingChangeLogicalKey.productPriceFingerprintHash(row)
        return (pending[key] ?? []).contains {
            $0.entityKind == .productPrice && $0.intendedFingerprintHash == fingerprint
        }
    }

    /// A missing physical price is permitted only by a known, proven parent
    /// tombstone or its exact owned pending delete. A raw cascade is rejected.
    private static func inactiveParents(_ ids: [UUID], context: ModelContext,
                                        manifest: SyncStoreGenerationManifest,
                                        pending: [String: [LocalPendingChange]]) throws -> Set<UUID> {
        let bodies = try expectedBodies(kind: .product, ids: ids, context: context, manifest: manifest)
        let allPending: [LocalPendingChange] = pending.values.flatMap { $0 }
        let productDeletes: [LocalPendingChange] = allPending.filter { change in
            change.entityKind == .product && change.operation == .delete
        }
        let deleteIDs: [UUID] = productDeletes.compactMap { $0.entityRemoteID }
        let deletes: Set<UUID> = Set(deleteIDs)
        var inactive: Set<UUID> = []
        for id in ids {
            guard let proof = bodies[id] else { throw SyncStoreGenerationError.activationReadBackFailed }
            if proof.deletedAt != nil || deletes.contains(id) { inactive.insert(id) }
        }
        return inactive
    }

    private static func forEachBatch(ledger: ShopSyncRecoveryLedger, domain: ShopSyncRecoveryDomain,
                                    _ body: ([ShopSyncRecoveryLedgerRecord]) throws -> Void) throws {
        var batch: [ShopSyncRecoveryLedgerRecord] = []
        try ledger.forEachRecord(for: domain) { record in
            try Task.checkCancellation()
            batch.append(record)
            if batch.count == batchSize { try body(batch); batch.removeAll(keepingCapacity: true) }
        }
        if !batch.isEmpty { try body(batch) }
    }

    /// One ordered ledger pass and bounded physical/proof pages. No complete
    /// price/history array or per-row scope/parent query is retained.
    private final class BodyRowPager<Model: PersistentModel> {
        let context: ModelContext
        let manifest: SyncStoreGenerationManifest
        let kind: String
        let id: (Model) -> UUID?
        var descriptor: FetchDescriptor<Model>
        var rows: [Model] = []
        var prepareRows: (([Model]) throws -> Void)?
        var overrides: [UUID: Body] = [:]
        var offset = 0
        var index = 0
        var prior: String?
        var exhausted = false
        let maximum: Int

        init(context: ModelContext, manifest: SyncStoreGenerationManifest, kind: String,
             sort: [SortDescriptor<Model>], maximum: Int, id: @escaping (Model) -> UUID?) {
            self.context = context; self.manifest = manifest; self.kind = kind; self.maximum = maximum; self.id = id
            descriptor = FetchDescriptor<Model>(sortBy: sort); descriptor.fetchLimit = batchSize
        }

        func peek() throws -> Model? {
            if index == rows.count {
                if exhausted { return nil }
                descriptor.fetchOffset = offset
                rows = try context.fetch(descriptor); index = 0
                exhausted = rows.count < batchSize
                offset += rows.count
                guard offset <= maximum else { throw SyncStoreGenerationError.generationResourceBudgetExceeded }
                try prepareRows?(rows)
                overrides = try localOverrides(kind: kind, ids: rows.compactMap(id), context: context, manifest: manifest)
            }
            return rows.isEmpty ? nil : rows[index]
        }

        func advance() throws {
            guard let row = try peek() else { return }
            if let current = id(row)?.uuidString.lowercased() {
                if let prior, current <= prior { throw SyncStoreGenerationError.activationReadBackFailed }
                prior = current
            }
            index += 1
        }
    }

    private static func localOverrides(kind: String, ids: [UUID], context: ModelContext,
                                       manifest: SyncStoreGenerationManifest) throws -> [UUID: Body] {
        let keys = ids.map { recordID(kind: kind, id: $0) }; let proofDomain = domain
        let rows = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate {
            $0.domain == proofDomain && keys.contains($0.id)
        }))
        var result: [UUID: Body] = [:]
        for row in rows {
            let proof = try decode(row, manifest: manifest)
            guard proof.kind == kind, ids.contains(proof.remoteID), result[proof.remoteID] == nil else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            result[proof.remoteID] = proof
        }
        return result
    }

    private static func forEachOverrideBatch(kind: String, context: ModelContext,
                                            manifest: SyncStoreGenerationManifest,
                                            _ body: ([Body]) throws -> Void) throws {
        let proofDomain = domain
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate {
            $0.domain == proofDomain && $0.eventType == kind
        }, sortBy: [SortDescriptor(\SyncEventOutboxEntry.id, comparator: .lexical)])
        descriptor.fetchLimit = batchSize
        var offset = 0
        while true {
            try Task.checkCancellation(); descriptor.fetchOffset = offset
            let rows = try context.fetch(descriptor)
            if rows.isEmpty { break }
            try body(rows.map { try decode($0, manifest: manifest) })
            offset += rows.count
            guard offset <= ShopSyncRecoveryLimits.maximumRows(for: kind == "productPrice" ? .prices : .history) else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
            if rows.count < batchSize { break }
        }
    }

    private static func validatePrices(context: ModelContext, manifest: SyncStoreGenerationManifest,
                                       pending: [String: [LocalPendingChange]], ledger: ShopSyncRecoveryLedger) throws {
        let kind = LocalPendingChangeEntityKind.productPrice.rawValue
        let pager = BodyRowPager<ProductPrice>(context: context, manifest: manifest, kind: kind,
            sort: [SortDescriptor(\ProductPrice.remoteID)], maximum: ShopSyncRecoveryLimits.maximumRows(for: .prices),
            id: { $0.remoteID })
        pager.descriptor.relationshipKeyPathsForPrefetching = [\ProductPrice.product]
        var physicalParents: [PersistentIdentifier: PhysicalPriceParent] = [:]
        pager.prepareRows = { rows in
            physicalParents = try physicalPriceParents(rows, context: context)
        }
        func validateExtra(_ row: ProductPrice) throws {
            // A new locally created product has no remote ID until its own
            // catalog ACK. Its exact scoped price intent is still usable.
            if priceIntentMatches(row, pending: pending) {
                guard let parent = row.product, parent.remoteDeletedAt == nil, row.price.isFinite, row.price >= 0,
                      row.effectiveAt.timeIntervalSince1970.isFinite, row.createdAt.timeIntervalSince1970.isFinite else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                return
            }
            let body = try priceBody(row, parents: physicalParents)
            guard row.remoteID.flatMap({ pager.overrides[$0]?.canonical }) == body else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        // Pure successful parses only, bounded to this validation invocation.
        // Every row still validates its own contract and complete current body.
        var parsedDates: [Data: Date] = [:]
        func parsedDate(_ value: String) -> Date? {
            let bytes = Data(value.utf8)
            if let date = parsedDates[bytes] { return date }
            guard let date = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: value) else { return nil }
            if parsedDates.count < batchSize * 2 { parsedDates[bytes] = date }
            return date
        }
        try forEachBatch(ledger: ledger, domain: .prices) { batch in
            let parsed = try batch.map { record -> (UUID, UUID, String) in
                let parts = record.versionLine.components(separatedBy: ShopSyncRecoveryCanonical.separator)
                guard parts.count == 9, let id = UUID(uuidString: parts[0]), let parent = UUID(uuidString: parts[2]),
                      id.uuidString.lowercased() == record.orderingID, !record.isTombstone,
                      let amount = Decimal(string: parts[3], locale: Locale(identifier: "en_US_POSIX")),
                      let type = SupabasePullPreviewNormalizer.normalizedPriceType(parts[4]),
                      let effective = parsedDate(parts[5]),
                      let created = parts[6].utf8.elementsEqual(parts[5].utf8)
                        ? effective : parsedDate(parts[6]),
                      ShopSyncRecoveryCanonical.isRedactedKey(parts[7]), ShopSyncRecoveryCanonical.isRedactedKey(parts[8]) else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                let price = NSDecimalNumber(decimal: amount).doubleValue
                guard price.isFinite, price >= 0 else { throw SyncStoreGenerationError.activationReadBackFailed }
                return (id, parent, priceBody(parent: parent, type: type, price: price, effectiveAt: effective,
                    createdAt: created, sourceHash: parts[7], noteHash: parts[8]))
            }
            let inactive = try inactiveParents(Array(Set(parsed.map { $0.1 })), context: context,
                manifest: manifest, pending: pending)
            for (id, parent, expected) in parsed {
                while let row = try pager.peek(), row.remoteID == nil
                    || row.remoteID!.uuidString.lowercased() < id.uuidString.lowercased() {
                    try validateExtra(row); try pager.advance()
                }
                if let row = try pager.peek(), row.remoteID == id {
                    let actual = try priceBody(row, parents: physicalParents)
                    guard !inactive.contains(parent),
                          actual == (pager.overrides[id]?.canonical ?? expected) || priceIntentMatches(row, pending: pending) else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    try pager.advance()
                } else if !inactive.contains(parent) { throw SyncStoreGenerationError.activationReadBackFailed }
            }
        }
        while let row = try pager.peek() { try validateExtra(row); try pager.advance() }
        // Sparse ACK rows absent from original C must also exist physically;
        // otherwise an acknowledged price could be silently removed on disk.
        try forEachOverrideBatch(kind: kind, context: context, manifest: manifest) { proofs in
            let ids = proofs.map(\.remoteID)
            let optionalIDs = ids.map(Optional.some)
            let rows = try context.fetch(FetchDescriptor<ProductPrice>(predicate: #Predicate { row in
                optionalIDs.contains(row.remoteID)
            }))
            var current: [UUID: ProductPrice] = [:]
            for row in rows {
                guard let id = row.remoteID, current[id] == nil else { throw SyncStoreGenerationError.activationReadBackFailed }
                current[id] = row
            }
            let currentParents = try physicalPriceParents(rows, context: context)
            let parents = try proofs.map { proof -> UUID in
                guard let part = proof.canonical.components(separatedBy: ShopSyncRecoveryCanonical.separator).first,
                      let id = UUID(uuidString: part) else { throw SyncStoreGenerationError.activationReadBackFailed }
                return id
            }
            let inactive = try inactiveParents(Array(Set(parents)), context: context, manifest: manifest, pending: pending)
            for (index, proof) in proofs.enumerated() {
                if inactive.contains(parents[index]) {
                    guard current[proof.remoteID] == nil else { throw SyncStoreGenerationError.activationReadBackFailed }
                } else {
                    guard let row = current[proof.remoteID], try priceBody(row, parents: currentParents) == proof.canonical
                            || priceIntentMatches(row, pending: pending) else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                }
            }
        }
    }

    private static func historyFingerprint(_ row: HistoryEntry, payloadVersion: Int) throws -> String {
        guard payloadVersion > 0, !row.hasPersistedJSONDecodeFault,
              (row.dataJSON?.count ?? 0) <= ShopSyncRecoveryLimits.maximumHistoryDataBytes,
              (row.editableJSON?.count ?? 0) + (row.completeJSON?.count ?? 0) <= HistorySessionPayloadCodec.maxOverlayBytes else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let decoder = JSONDecoder()
        let data = try row.dataJSON.map { try decoder.decode([[String]].self, from: $0) } ?? []
        let editable = try row.editableJSON.map { try decoder.decode([[String]].self, from: $0) } ?? []
        let complete = try row.completeJSON.map { try decoder.decode([Bool].self, from: $0) } ?? []
        return HistorySessionPayloadCodec.fingerprintHash(for: HistorySessionLocalPayloadSnapshot(
            remoteID: row.remoteID ?? row.uid, localID: row.uid, payloadVersion: payloadVersion,
            displayName: row.title, timestamp: row.timestamp, supplier: row.supplier, category: row.category,
            isManualEntry: row.isManualEntry, data: data, editable: editable, complete: complete, deletedAt: row.remoteDeletedAt))
    }

    private static func historyIntentMatches(_ row: HistoryEntry, pending: [String: [LocalPendingChange]]) throws -> Bool {
        let key = LocalPendingChangeLogicalKey.historySession(remoteID: row.remoteID, uid: row.uid)
        let fingerprint = try historyFingerprint(row, payloadVersion: HistorySessionPayloadCodec.payloadVersion)
        return (pending[key] ?? []).contains {
            $0.entityKind == .historySession && $0.intendedFingerprintHash == fingerprint
        }
    }

    private static func validateHistory(context: ModelContext, manifest: SyncStoreGenerationManifest,
                                        pending: [String: [LocalPendingChange]], ledger: ShopSyncRecoveryLedger) throws {
        let kind = LocalPendingChangeEntityKind.historySession.rawValue
        let pager = BodyRowPager<HistoryEntry>(context: context, manifest: manifest, kind: kind,
            sort: [SortDescriptor(\HistoryEntry.remoteID), SortDescriptor(\HistoryEntry.uid)],
            maximum: ShopSyncRecoveryLimits.maximumRows(for: .history), id: { $0.remoteID ?? $0.uid })
        func validate(_ row: HistoryEntry, version: Int?, expectedUpdatedAt: Date? = nil) throws {
            guard UUID(uuidString: row.ownerUserID ?? "").map(AccountBindingStore.accountHash(for:)) == manifest.accountHash,
                  row.storeID == manifest.storeIdentity.storeId, row.shopID == manifest.shopID,
                  row.localChangeRevision >= row.lastSyncedLocalRevision, row.lastSyncedLocalRevision >= 0 else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            let id = row.remoteID ?? row.uid; let proof = pager.overrides[id]
            let ownedIntent = try historyIntentMatches(row, pending: pending)
            if ownedIntent { return }
            if row.remoteDeletedAt != nil {
                guard row.localChangeRevision == row.lastSyncedLocalRevision, let proof,
                      proof.deletedAt == row.remoteDeletedAt, proof.updatedAt == row.remoteUpdatedAt,
                      proof.canonical == row.remotePayloadFingerprint else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                return // A validated tombstone makes no claim about retained legacy payload fields.
            }
            guard row.localChangeRevision == row.lastSyncedLocalRevision, let fingerprint = row.remotePayloadFingerprint,
                  let payloadVersion = proof?.payloadVersion ?? version,
                  try historyFingerprint(row, payloadVersion: payloadVersion) == fingerprint,
                  proof.map({ $0.canonical == fingerprint && $0.updatedAt == row.remoteUpdatedAt && $0.deletedAt == row.remoteDeletedAt })
                    ?? (expectedUpdatedAt == row.remoteUpdatedAt) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        try forEachBatch(ledger: ledger, domain: .history) { batch in
            let batchIDs = try batch.map { record -> UUID in
                guard let id = UUID(uuidString: record.orderingID) else { throw SyncStoreGenerationError.activationReadBackFailed }
                return id
            }
            let missingOverrides = try localOverrides(kind: kind, ids: batchIDs, context: context, manifest: manifest)
            for record in batch {
                let parts = record.versionLine.components(separatedBy: ShopSyncRecoveryCanonical.separator)
                guard parts.count >= 5, let id = UUID(uuidString: parts[0]), let version = Int(parts[3]),
                      id.uuidString.lowercased() == record.orderingID else { throw SyncStoreGenerationError.activationReadBackFailed }
                while let row = try pager.peek(), (row.remoteID ?? row.uid).uuidString.lowercased() < id.uuidString.lowercased() {
                    try validate(row, version: nil); try pager.advance()
                }
                if let row = try pager.peek(), (row.remoteID ?? row.uid) == id {
                    try validate(row, version: version, expectedUpdatedAt: SupabaseRemoteDateParser.parse(parts[1]))
                    try pager.advance()
                } else {
                    let deleted = (pending[LocalPendingChangeLogicalKey.historySession(remoteID: id, uid: id)] ?? [])
                        .contains { $0.entityKind == .historySession && $0.operation == .delete }
                    guard record.isTombstone || missingOverrides[id]?.deletedAt != nil || deleted else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                }
            }
        }
        while let row = try pager.peek() { try validate(row, version: nil); try pager.advance() }
        try forEachOverrideBatch(kind: kind, context: context, manifest: manifest) { proofs in
            let ids = proofs.map(\.remoteID)
            let optionalIDs = ids.map(Optional.some)
            let rows = try context.fetch(FetchDescriptor<HistoryEntry>(predicate: #Predicate { row in
                optionalIDs.contains(row.remoteID)
            }))
            let existing = Set(rows.compactMap(\.remoteID))
            guard proofs.allSatisfy({ $0.deletedAt != nil || existing.contains($0.remoteID) }) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
    }

    private typealias Current = (UUID?, Date?, Date?, String, String, String)

    private static func scan<Model: PersistentModel>(
        _ type: Model.Type, kind: SupabaseCatalogBaselineEntityType, context: ModelContext,
        manifest: SyncStoreGenerationManifest, pending: [String: [LocalPendingChange]],
        sort: [SortDescriptor<Model>], body: (Model) -> Current
    ) throws {
// TASK145_COST39_BEGIN scan-start
#if DEBUG
        let costStartNS = DispatchTime.now().uptimeNanoseconds
        var costPhaseStartNS = costStartNS
        var costPhase = 0 // setup, fetch, current body, expected body, compare, count
        var costNS = [UInt64](repeating: 0, count: 6)
        var costBatches: UInt64 = 0
        var costRows: UInt64 = 0
        var costReturnedNormally = false
        func costEnter(_ next: Int) {
            let now = DispatchTime.now().uptimeNanoseconds
            costNS[costPhase] &+= now &- costPhaseStartNS
            costPhase = next
            costPhaseStartNS = now
        }
        defer {
            let ended = DispatchTime.now().uptimeNanoseconds
            costNS[costPhase] &+= ended &- costPhaseStartNS
            let elapsed = ended &- costStartNS
            Logger(subsystem: "com.niwcyber.iOSMerchandiseControl", category: "LocalBodyQualification").notice("populated-qualification-cost kind.scan entity.\(kind.rawValue, privacy: .public) start_ns.\(costStartNS, privacy: .public) elapsed_ns.\(elapsed, privacy: .public) returned.\(costReturnedNormally, privacy: .public) cancelled.\(Task.isCancelled, privacy: .public) last_phase.\(costPhase, privacy: .public) batches.\(costBatches, privacy: .public) rows.\(costRows, privacy: .public) setup_ns.\(costNS[0], privacy: .public) fetch_ns.\(costNS[1], privacy: .public) current_ns.\(costNS[2], privacy: .public) expected_ns.\(costNS[3], privacy: .public) compare_ns.\(costNS[4], privacy: .public) count_ns.\(costNS[5], privacy: .public)")
        }
#endif
// TASK145_COST39_END scan-start
        var descriptor = FetchDescriptor<Model>(sortBy: sort)
        descriptor.fetchLimit = batchSize
        var offset = 0; var prior: UUID?; var physicalActive = 0
        while true {
            try Task.checkCancellation()
            descriptor.fetchOffset = offset
// TASK145_COST39_BEGIN scan-fetch
#if DEBUG
            costEnter(1)
#endif
// TASK145_COST39_END scan-fetch
            let rows = try context.fetch(descriptor)
            if rows.isEmpty { break }
// TASK145_COST39_BEGIN scan-current
#if DEBUG
            costBatches &+= 1
            costRows &+= UInt64(rows.count)
            costEnter(2)
#endif
// TASK145_COST39_END scan-current
            let current = rows.map(body)
            let ids = current.compactMap { $0.0 }
// TASK145_COST39_BEGIN scan-expected
#if DEBUG
            costEnter(3)
#endif
// TASK145_COST39_END scan-expected
            let expected = try expectedBodies(kind: kind, ids: ids, context: context, manifest: manifest)
// TASK145_COST39_BEGIN scan-compare
#if DEBUG
            costEnter(4)
#endif
// TASK145_COST39_END scan-compare
            for item in current {
                let activePending = (pending[item.4] ?? []).filter { $0.entityKindRaw == kind.rawValue }
                let intentMatches = activePending.contains { $0.intendedFingerprintHash == item.5 }
                guard let id = item.0 else {
                    guard intentMatches, activePending.contains(where: { $0.operation == .create }) else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    continue
                }
                if let prior, prior.uuidString.lowercased() >= id.uuidString.lowercased() {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                prior = id
                if item.2 == nil { physicalActive += 1 }
                guard let proof = expected[id], proof.updatedAt == item.1, proof.deletedAt == item.2,
                      proof.canonical == item.3 || intentMatches else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
            }
            offset += rows.count
            guard offset <= ShopSyncRecoveryLimits.maximumRows(for: .products) else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
            if rows.count < batchSize { break }
        }
// TASK145_COST39_BEGIN scan-count
#if DEBUG
        costEnter(5)
#endif
// TASK145_COST39_END scan-count
        var expectedActive = try expectedActiveCount(kind: kind, context: context, manifest: manifest)
        let deletes = Set(pending.values.flatMap { $0 }.filter {
            $0.entityKindRaw == kind.rawValue && $0.operation == .delete
        }.compactMap(\.entityRemoteID))
        for batch in stride(from: 0, to: deletes.count, by: batchSize) {
            let ids = Array(deletes.sorted(by: { $0.uuidString < $1.uuidString }).dropFirst(batch).prefix(batchSize))
            expectedActive -= try expectedBodies(kind: kind, ids: ids, context: context, manifest: manifest)
                .values.filter { $0.deletedAt == nil }.count
        }
        guard expectedActive == physicalActive else { throw SyncStoreGenerationError.activationReadBackFailed }
// TASK145_COST39_BEGIN scan-returned
#if DEBUG
        costReturnedNormally = true
#endif
// TASK145_COST39_END scan-returned
    }

    private static func expectedActiveCount(kind: SupabaseCatalogBaselineEntityType, context: ModelContext,
                                           manifest: SyncStoreGenerationManifest) throws -> Int {
        let runID = manifest.baselineRunID; let kindRaw = kind.rawValue
        var count = try context.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRecord>(predicate: #Predicate {
            $0.baselineRunID == runID && $0.entityType == kindRaw && $0.remoteDeletedAt == nil
        }))
        let proofDomain = domain
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate {
            $0.domain == proofDomain && $0.eventType == kindRaw
        }, sortBy: [SortDescriptor(\SyncEventOutboxEntry.id, comparator: .lexical)])
        descriptor.fetchLimit = batchSize
        var offset = 0
        while true {
            descriptor.fetchOffset = offset
            let rows = try context.fetch(descriptor)
            if rows.isEmpty { break }
            let proofs = try rows.map { try decode($0, manifest: manifest) }
            let ids = proofs.map(\.remoteID)
            let base = try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRecord>(predicate: #Predicate {
                $0.baselineRunID == runID && $0.entityType == kindRaw && ids.contains($0.remoteID)
            }))
            var original: [UUID: Bool] = [:]
            for row in base {
                guard original[row.remoteID] == nil else { throw SyncStoreGenerationError.activationReadBackFailed }
                original[row.remoteID] = row.remoteDeletedAt == nil
            }
            for proof in proofs {
                count += (proof.deletedAt == nil ? 1 : 0) - (original[proof.remoteID] == true ? 1 : 0)
            }
            offset += rows.count
            guard offset <= ShopSyncRecoveryLimits.maximumRows(for: .products), count >= 0 else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
            if rows.count < batchSize { break }
        }
        return count
    }

    private static func expectedBodies(kind: SupabaseCatalogBaselineEntityType, ids: [UUID],
                                       context: ModelContext, manifest: SyncStoreGenerationManifest) throws -> [UUID: Body] {
        let runID = manifest.baselineRunID; let kindRaw = kind.rawValue
        let records = try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRecord>(predicate: #Predicate {
            $0.baselineRunID == runID && $0.entityType == kindRaw && ids.contains($0.remoteID)
        }))
        var result: [UUID: Body] = [:]
        // This memo contains only a pure UUID-to-hash conversion for this batch.
        // Every record still checks its own owner, schema, identity and body.
        var ownerHashes: [UUID: String] = [:]
        for record in records {
            let ownerHash: String
            if let computed = ownerHashes[record.ownerUserUUID] {
                ownerHash = computed
            } else {
                ownerHash = AccountBindingStore.accountHash(for: record.ownerUserUUID)
                ownerHashes[record.ownerUserUUID] = ownerHash
            }
            guard result[record.remoteID] == nil,
                  ownerHash == manifest.accountHash,
                  record.fingerprintSchemaVersion == SupabaseCatalogFingerprintSchema.currentVersion else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            result[record.remoteID] = Body(generationID: manifest.generationID, kind: kindRaw,
                remoteID: record.remoteID, canonical: record.fingerprintCanonical,
                updatedAt: record.remoteUpdatedAt, deletedAt: record.remoteDeletedAt, payloadVersion: nil)
        }
        let keys = ids.map { recordID(kind: kindRaw, id: $0) }; let proofDomain = domain
        let overrides = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate {
            $0.domain == proofDomain && keys.contains($0.id)
        }))
        for entry in overrides {
            let proof = try decode(entry, manifest: manifest)
            guard proof.kind == kindRaw, ids.contains(proof.remoteID) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            result[proof.remoteID] = proof
        }
        return result
    }

    private static func decode(_ entry: SyncEventOutboxEntry, manifest: SyncStoreGenerationManifest) throws -> Body {
        try decode(entry, accountHash: manifest.accountHash, storeIdentity: manifest.storeIdentity,
            deviceIdentityHash: manifest.deviceIdentityHash, generationID: manifest.generationID)
    }

    private static func decode(_ entry: SyncEventOutboxEntry, accountHash: String,
                               storeIdentity: LocalStoreIdentity, deviceIdentityHash: String,
                               generationID: UUID) throws -> Body {
        guard entry.status == .localOnly, entry.metadataShape == format,
              UUID(uuidString: entry.ownerUserID).map(AccountBindingStore.accountHash(for:)) == accountHash,
              entry.storeId == storeIdentity.storeId, entry.localStoreId == storeIdentity.localStoreId,
              entry.schemaVersion == storeIdentity.schemaVersion,
              entry.syncProtocolVersion == storeIdentity.syncProtocolVersion,
              entry.storeEpoch == storeIdentity.storeEpoch,
              entry.sourceDeviceID.map(DeviceInstallIDStore.identityHash(for:)) == deviceIdentityHash,
              let json = entry.metadataPayloadJSON, json.utf8.count <= ShopSyncRecoveryLimits.maximumGenerationManifestBytes,
              ShopSyncRecoveryCanonical.sha256(json) == entry.entityIDsShape,
              let data = json.data(using: .utf8) else { throw SyncStoreGenerationError.activationReadBackFailed }
        let proof = try JSONDecoder().decode(Body.self, from: data)
        guard proof.generationID == generationID,
              entry.id == recordID(kind: proof.kind, id: proof.remoteID), entry.clientEventID == entry.id,
              entry.batchID == entry.id, entry.eventType == proof.kind, proof.updatedAt != nil else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        return proof
    }

    private static func recordID(kind: String, id: UUID) -> String {
        "local-body:\(kind):\(id.uuidString.lowercased())"
    }
}

/// An authenticated memo of a REAL complete body validation, never an authority
/// token. Only unchanged complete post-open content and physical identity can
/// reuse its work. Persisted SHM timestamps may differ; live stability may not.
/// Every unavailable key, unsupported layout or changed byte falls back to the
/// original validator. Ordinary writers never update or reseal this memo.
nonisolated enum LocalCatalogPhysicalProofStore {
    // Bump whenever the complete validator's contract/encoding changes.
    static let version = "local-catalog-complete-physical-proof-v2"
    private static let keyService = "com.niwcyber.local-catalog-physical-proof.v1"
    private static let maximumCapsuleBytes = 128 * 1_024

    struct File: Codable, Equatable, Sendable {
        let state: SyncStoreGenerationMutationFence.FileState
        let sha256: String
        let deviceID: Int64
        let changeTimeSeconds: Int64
        let changeTimeNanoseconds: Int64
    }
    struct Snapshot: Codable, Equatable, Sendable {
        let version: String
        let keyAccount: String
        let generationID: UUID
        let contextSHA256: String
        let files: [File]

        /// Used ONLY after the saved capsule's MAC and latest binding pass.
        /// SQLite may retouch its SHM on process open without changing a byte.
        /// Keep the full stored/live snapshots: their synthesized == still
        /// checks both timestamps during read, recapture and publication.
        func hasSameAuthenticatedContent(as other: Snapshot) -> Bool {
            guard version == other.version, keyAccount == other.keyAccount,
                  generationID == other.generationID, contextSHA256 == other.contextSHA256,
                  files.count == other.files.count else { return false }
            for (saved, current) in zip(files, other.files) {
                guard Self.persistedComparisonValue(saved) == Self.persistedComparisonValue(current) else {
                    return false
                }
            }
            return true
        }

        private static func persistedComparisonValue(_ file: File) -> File {
            guard file.state.relativePath == "store.store-shm" else { return file }
            let state = SyncStoreGenerationMutationFence.FileState(
                relativePath: file.state.relativePath, fileSize: file.state.fileSize,
                allocatedSize: file.state.allocatedSize, modificationTimeBits: 0,
                systemFileNumber: file.state.systemFileNumber)
            return File(state: state, sha256: file.sha256, deviceID: file.deviceID,
                changeTimeSeconds: 0, changeTimeNanoseconds: 0)
        }
    }
    private struct Capsule: Codable {
        let payload: Data
        let authenticationCode: Data
    }
    enum Failure: Error { case unavailable }

    static func hash(_ data: Data) -> String {
        let digits = Array("0123456789abcdef".utf8)
        var bytes: [UInt8] = []; bytes.reserveCapacity(64)
        for byte in SHA256.hash(data: data) {
            bytes.append(digits[Int(byte >> 4)]); bytes.append(digits[Int(byte & 15)])
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    static func keyAccount(baseDirectory: URL, deviceIdentityHash: String) -> String {
        // A relocated/restored sandbox has no authority to reuse another path's
        // proof. Fixture roots also get separate keys, without touching Auth keys.
        hash(Data((baseDirectory.standardizedFileURL.path + "\u{0}" + deviceIdentityHash).utf8))
    }

    struct ReuseToken: Sendable {
        let keyAccount: String
        let protectedRecordSHA256: String
        let capsuleSHA256: String
        let contextSHA256: String
        let generationID: UUID
    }
    private struct SignedPayload: Codable {
        let sealID: UUID
        let snapshot: Snapshot
    }
    private struct ProtectedRecord: Codable {
        let format: String
        let key: Data
        var latestCapsuleSHA256: String?
        var latestContextSHA256: String?
        var latestGenerationID: UUID?
    }
    private static let keyLock = NSRecursiveLock()
    private static let protectedRecordFormat = "local-body-physical-proof-protected-key-v1"

    static func matches(_ snapshot: Snapshot, capsuleURL: URL) -> Bool {
        reuseToken(snapshot, capsuleURL: capsuleURL) != nil
    }

    static func reuseToken(_ snapshot: Snapshot, capsuleURL: URL) -> ReuseToken? {
#if DEBUG
        enum ReuseFrontier: String {
            case capsuleRead, capsuleDecode, payloadBound, authenticationLength, protectedKey
            case latestCapsule, latestContext, latestGeneration, authentication, payloadDecode
            case snapshotVersion, snapshotEquality, protectedRecordDigest, complete
        }
        var reuseFrontier = ReuseFrontier.capsuleRead
        var contextSame = -1, identitySame = -1, membershipSame = -1
        var metadataChangedKinds = -1, digestChangedKinds = -1
        defer {
            // Same closed kind bits as eligibility: main=1/WAL=2/SHM=4/ledger=8/other=16.
            // -1 means not compared. No paths, identities, hashes, tags or key data.
            Logger(subsystem: "com.niwcyber.iOSMerchandiseControl", category: "LocalBodyQualification").notice("populated-qualification-physical kind.reuse-token frontier.\(reuseFrontier.rawValue, privacy: .public) context_same.\(contextSame, privacy: .public) identity_same.\(identitySame, privacy: .public) membership_same.\(membershipSame, privacy: .public) metadata_changed_kinds.\(metadataChangedKinds, privacy: .public) digest_changed_kinds.\(digestChangedKinds, privacy: .public)")
        }
#endif
        keyLock.lock(); defer { keyLock.unlock() }
        do {
            let data = try readData(capsuleURL, maximumBytes: maximumCapsuleBytes)
#if DEBUG
            reuseFrontier = .capsuleDecode
#endif
            let capsule = try JSONDecoder().decode(Capsule.self, from: data)
#if DEBUG
            reuseFrontier = .payloadBound
#endif
            guard capsule.payload.count <= maximumCapsuleBytes else { return nil }
#if DEBUG
            reuseFrontier = .authenticationLength
#endif
            guard capsule.authenticationCode.count == 32 else { return nil }
#if DEBUG
            reuseFrontier = .protectedKey
#endif
            guard let record = try key(account: snapshot.keyAccount, create: false) else { return nil }
#if DEBUG
            reuseFrontier = .latestCapsule
#endif
            guard record.latestCapsuleSHA256 == hash(data) else { return nil }
#if DEBUG
            reuseFrontier = .latestContext
#endif
            guard record.latestContextSHA256 == snapshot.contextSHA256 else { return nil }
#if DEBUG
            reuseFrontier = .latestGeneration
#endif
            guard record.latestGenerationID == snapshot.generationID else { return nil }
#if DEBUG
            reuseFrontier = .authentication
#endif
            guard HMAC<SHA256>.isValidAuthenticationCode(capsule.authenticationCode,
                    authenticating: capsule.payload, using: SymmetricKey(data: record.key)) else { return nil }
#if DEBUG
            reuseFrontier = .payloadDecode
#endif
            let saved = try JSONDecoder().decode(SignedPayload.self, from: capsule.payload)
#if DEBUG
            reuseFrontier = .snapshotVersion
#endif
            guard saved.snapshot.version == version else { return nil }
#if DEBUG
            reuseFrontier = .snapshotEquality
#endif
            guard saved.snapshot.hasSameAuthenticatedContent(as: snapshot) else {
#if DEBUG
                let earlier = saved.snapshot, later = snapshot
                contextSame = earlier.contextSHA256 == later.contextSHA256 ? 1 : 0
                identitySame = earlier.version == later.version && earlier.keyAccount == later.keyAccount
                    && earlier.generationID == later.generationID ? 1 : 0
                membershipSame = earlier.files.map { $0.state.relativePath }
                    == later.files.map { $0.state.relativePath } ? 1 : 0
                if membershipSame == 1 {
                    metadataChangedKinds = 0; digestChangedKinds = 0
                    for pair in zip(earlier.files, later.files) {
                        let path = pair.0.state.relativePath
                        let kind: Int
                        if path.hasSuffix("-wal") { kind = 2 }
                        else if path.hasSuffix("-shm") { kind = 4 }
                        else if path.hasPrefix("recovery-ledger-v1/") { kind = 8 }
                        else if path == "store.store" { kind = 1 }
                        else { kind = 16 }
                        if pair.0.state != pair.1.state || pair.0.deviceID != pair.1.deviceID
                            || pair.0.changeTimeSeconds != pair.1.changeTimeSeconds
                            || pair.0.changeTimeNanoseconds != pair.1.changeTimeNanoseconds {
                            metadataChangedKinds |= kind
                        }
                        if pair.0.sha256 != pair.1.sha256 { digestChangedKinds |= kind }
                    }
                }
#endif
                return nil
            }
#if DEBUG
            reuseFrontier = .protectedRecordDigest
#endif
            let token = ReuseToken(keyAccount: snapshot.keyAccount,
                protectedRecordSHA256: try protectedRecordDigest(record), capsuleSHA256: hash(data),
                contextSHA256: snapshot.contextSHA256, generationID: snapshot.generationID)
#if DEBUG
            reuseFrontier = .complete
#endif
            return token
        } catch { return nil }
    }

    /// Serializes this installation's capsule/key operations through the ORIGINAL
    /// lease publication. A latest-binding change cannot race the admission.
    /// No await, DB read or authorization is performed by this lock itself.
    static func withLatestBinding(_ token: ReuseToken?, publication: () -> Bool) -> Bool {
        keyLock.lock(); defer { keyLock.unlock() }
        guard let token else { return publication() } // REAL full-validation path.
        do {
            guard let current = try key(account: token.keyAccount, create: false),
                  try protectedRecordDigest(current) == token.protectedRecordSHA256,
                  current.latestCapsuleSHA256 == token.capsuleSHA256,
                  current.latestContextSHA256 == token.contextSHA256,
                  current.latestGenerationID == token.generationID else { return false }
            return publication()
        } catch { return false }
    }

    static func seal(_ snapshot: Snapshot, capsuleURL: URL) throws {
// TASK145_PHYSICAL_FRONTIER_BEGIN seal-internal
#if DEBUG
        var sealFrontier = "key", sealCompleted = false
        defer {
            Logger(subsystem: "com.niwcyber.iOSMerchandiseControl", category: "LocalBodyQualification").notice("populated-qualification-physical kind.seal-internal frontier.\(sealFrontier, privacy: .public) completed.\(sealCompleted, privacy: .public)")
        }
#endif
// TASK145_PHYSICAL_FRONTIER_END seal-internal
        keyLock.lock(); defer { keyLock.unlock() }
        guard snapshot.version == version, var record = try key(account: snapshot.keyAccount, create: true) else {
            throw Failure.unavailable
        }
// TASK145_PHYSICAL_FRONTIER_BEGIN encode
#if DEBUG
        sealFrontier = "encode"
#endif
// TASK145_PHYSICAL_FRONTIER_END encode
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        // Even two full validations of identical bytes produce different latest
        // bindings. An old authentic capsule is not the currently trusted seal.
        let payload = try encoder.encode(SignedPayload(sealID: UUID(), snapshot: snapshot))
        let capsule = Capsule(payload: payload,
            authenticationCode: Data(HMAC<SHA256>.authenticationCode(for: payload, using: SymmetricKey(data: record.key))))
        let encoded = try encoder.encode(capsule)
        guard encoded.count <= maximumCapsuleBytes else { throw Failure.unavailable }
        // Crash order: durable capsule FIRST, external trusted latest SECOND.
        // Interrupted/missing/mismatched pairs are misses, never startup repairs.
// TASK145_PHYSICAL_FRONTIER_BEGIN write
#if DEBUG
        sealFrontier = "write"
#endif
// TASK145_PHYSICAL_FRONTIER_END write
        try encoded.write(to: capsuleURL, options: [.atomic])
// TASK145_PHYSICAL_FRONTIER_BEGIN fsync-file
#if DEBUG
        sealFrontier = "fsync-file"
#endif
// TASK145_PHYSICAL_FRONTIER_END fsync-file
        try synchronize(capsuleURL)
// TASK145_PHYSICAL_FRONTIER_BEGIN fsync-directory
#if DEBUG
        sealFrontier = "fsync-directory"
#endif
// TASK145_PHYSICAL_FRONTIER_END fsync-directory
        try synchronize(capsuleURL.deletingLastPathComponent())
        record.latestCapsuleSHA256 = hash(encoded)
        record.latestContextSHA256 = snapshot.contextSHA256
        record.latestGenerationID = snapshot.generationID
// TASK145_PHYSICAL_FRONTIER_BEGIN latest-encode
#if DEBUG
        sealFrontier = "latest-encode"
#endif
// TASK145_PHYSICAL_FRONTIER_END latest-encode
        let update: [String: Any] = [kSecValueData as String: try encoder.encode(record)]
// TASK145_PHYSICAL_FRONTIER_BEGIN latest-update
#if DEBUG
        sealFrontier = "latest-update"
#endif
// TASK145_PHYSICAL_FRONTIER_END latest-update
        guard SecItemUpdate(keyQuery(account: snapshot.keyAccount) as CFDictionary,
                            update as CFDictionary) == errSecSuccess else { throw Failure.unavailable }
// TASK145_PHYSICAL_FRONTIER_BEGIN seal-internal-success
#if DEBUG
        sealFrontier = "success"; sealCompleted = true
#endif
// TASK145_PHYSICAL_FRONTIER_END seal-internal-success
    }

    private static func protectedRecordDigest(_ record: ProtectedRecord) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return hash(try encoder.encode(record))
    }

    static func fileDigest(_ url: URL, expected: SyncStoreGenerationMutationFence.FileState) throws -> File {
        var hasher = SHA256()
        let metadata = try read(url, maximumBytes: expected.fileSize, expected: expected) { hasher.update(data: $0) }
        let digits = Array("0123456789abcdef".utf8)
        var bytes: [UInt8] = []; bytes.reserveCapacity(64)
        for byte in hasher.finalize() {
            bytes.append(digits[Int(byte >> 4)]); bytes.append(digits[Int(byte & 15)])
        }
        return File(state: expected, sha256: String(decoding: bytes, as: UTF8.self),
            deviceID: metadata.deviceID, changeTimeSeconds: metadata.seconds, changeTimeNanoseconds: metadata.nanoseconds)
    }

    static func readData(_ url: URL, maximumBytes: Int) throws -> Data {
        var data = Data()
        _ = try read(url, maximumBytes: maximumBytes, expected: nil) { data.append($0) }
        return data
    }

    private static func read(_ url: URL, maximumBytes: Int,
                             expected: SyncStoreGenerationMutationFence.FileState?, consume: (Data) -> Void)
        throws -> (deviceID: Int64, seconds: Int64, nanoseconds: Int64) {
        #if canImport(Darwin)
// TASK145_CAPTURE_FRONTIER_BEGIN read-start
#if DEBUG
        enum ReadFrontier: String {
            case byteLimit, open, fdStatBefore, pathStatBefore, regularFile, singleLink
            case pathMatchBefore, sizeBound, expectedSize, expectedInode
            case readChunk, cancellation, readBound, readCount
            case fdStatAfter, pathStatAfter, fdStable, pathStable, complete
        }
        enum ReadKind: String { case manifest, journal, finalization, capsule, main, wal, shm, ledger, other }
        let readKind: ReadKind
        let name = url.lastPathComponent
        if name == "active-generation.json" { readKind = .manifest }
        else if name == "recovery-journal.json" { readKind = .journal }
        else if name == "recovery-finalization.json" { readKind = .finalization }
        else if name == "local-body-physical-proof-v1.json" { readKind = .capsule }
        else if name == "store.store" { readKind = .main }
        else if name.hasSuffix("-wal") { readKind = .wal }
        else if name.hasSuffix("-shm") { readKind = .shm }
        else if expected?.relativePath.hasPrefix("recovery-ledger-v1/") == true { readKind = .ledger }
        else { readKind = .other }
        var readFrontier = ReadFrontier.byteLimit
        var readCompleted = false
        defer {
            if !readCompleted {
                Logger(subsystem: "com.niwcyber.iOSMerchandiseControl", category: "LocalBodyQualification").notice("populated-qualification-physical kind.read-failure frontier.\(readFrontier.rawValue, privacy: .public) file_kind.\(readKind.rawValue, privacy: .public)")
            }
        }
#endif
// TASK145_CAPTURE_FRONTIER_END read-start
        guard maximumBytes >= 0 else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-open
#if DEBUG
        readFrontier = .open
#endif
// TASK145_CAPTURE_FRONTIER_END read-open
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw Failure.unavailable }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var before = stat(); var pathBefore = stat()
// TASK145_CAPTURE_FRONTIER_BEGIN read-fdStatBefore
#if DEBUG
        readFrontier = .fdStatBefore
#endif
// TASK145_CAPTURE_FRONTIER_END read-fdStatBefore
        guard Darwin.fstat(fd, &before) == 0 else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-pathStatBefore
#if DEBUG
        readFrontier = .pathStatBefore
#endif
// TASK145_CAPTURE_FRONTIER_END read-pathStatBefore
        guard Darwin.lstat(url.path, &pathBefore) == 0 else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-regularFile
#if DEBUG
        readFrontier = .regularFile
#endif
// TASK145_CAPTURE_FRONTIER_END read-regularFile
        guard before.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-singleLink
#if DEBUG
        readFrontier = .singleLink
#endif
// TASK145_CAPTURE_FRONTIER_END read-singleLink
        guard before.st_nlink == 1 else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-pathMatchBefore
#if DEBUG
        readFrontier = .pathMatchBefore
#endif
// TASK145_CAPTURE_FRONTIER_END read-pathMatchBefore
        guard same(before, pathBefore) else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-sizeBound
#if DEBUG
        readFrontier = .sizeBound
#endif
// TASK145_CAPTURE_FRONTIER_END read-sizeBound
        guard before.st_size >= 0, before.st_size <= Int64(maximumBytes) else { throw Failure.unavailable }
        if let expected {
// TASK145_CAPTURE_FRONTIER_BEGIN read-expectedSize
#if DEBUG
        readFrontier = .expectedSize
#endif
// TASK145_CAPTURE_FRONTIER_END read-expectedSize
            guard before.st_size == Int64(expected.fileSize) else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-expectedInode
#if DEBUG
        readFrontier = .expectedInode
#endif
// TASK145_CAPTURE_FRONTIER_END read-expectedInode
            guard before.st_ino == expected.systemFileNumber else { throw Failure.unavailable }
        }
        var count = 0
// TASK145_CAPTURE_FRONTIER_BEGIN read-readChunk
#if DEBUG
        readFrontier = .readChunk
#endif
// TASK145_CAPTURE_FRONTIER_END read-readChunk
        while let chunk = try handle.read(upToCount: min(256 * 1_024, maximumBytes - count + 1)), !chunk.isEmpty {
// TASK145_CAPTURE_FRONTIER_BEGIN read-cancellation
#if DEBUG
        readFrontier = .cancellation
#endif
// TASK145_CAPTURE_FRONTIER_END read-cancellation
            try Task.checkCancellation()
            let (next, overflow) = count.addingReportingOverflow(chunk.count)
// TASK145_CAPTURE_FRONTIER_BEGIN read-readBound
#if DEBUG
        readFrontier = .readBound
#endif
// TASK145_CAPTURE_FRONTIER_END read-readBound
            guard !overflow, next <= maximumBytes else { throw Failure.unavailable }
            count = next; consume(chunk)
// TASK145_CAPTURE_FRONTIER_BEGIN read-readChunk
#if DEBUG
        readFrontier = .readChunk
#endif
// TASK145_CAPTURE_FRONTIER_END read-readChunk
        }
        var after = stat(); var pathAfter = stat()
// TASK145_CAPTURE_FRONTIER_BEGIN read-readCount
#if DEBUG
        readFrontier = .readCount
#endif
// TASK145_CAPTURE_FRONTIER_END read-readCount
        guard Int64(count) == before.st_size else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-fdStatAfter
#if DEBUG
        readFrontier = .fdStatAfter
#endif
// TASK145_CAPTURE_FRONTIER_END read-fdStatAfter
        guard Darwin.fstat(fd, &after) == 0 else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-pathStatAfter
#if DEBUG
        readFrontier = .pathStatAfter
#endif
// TASK145_CAPTURE_FRONTIER_END read-pathStatAfter
        guard Darwin.lstat(url.path, &pathAfter) == 0 else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-fdStable
#if DEBUG
        readFrontier = .fdStable
#endif
// TASK145_CAPTURE_FRONTIER_END read-fdStable
        guard same(before, after) else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-pathStable
#if DEBUG
        readFrontier = .pathStable
#endif
// TASK145_CAPTURE_FRONTIER_END read-pathStable
        guard same(before, pathAfter) else { throw Failure.unavailable }
// TASK145_CAPTURE_FRONTIER_BEGIN read-complete
#if DEBUG
        readFrontier = .complete
        readCompleted = true
#endif
// TASK145_CAPTURE_FRONTIER_END read-complete
        return (Int64(before.st_dev), Int64(before.st_ctimespec.tv_sec), Int64(before.st_ctimespec.tv_nsec))
        #else
        throw Failure.unavailable
        #endif
    }

    #if canImport(Darwin)
    private static func same(_ a: stat, _ b: stat) -> Bool {
        a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_mode == b.st_mode
            && a.st_nlink == b.st_nlink && a.st_size == b.st_size
            && a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec
            && a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec
    }
    #endif

    private static func synchronize(_ url: URL) throws {
        #if canImport(Darwin)
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw Failure.unavailable }
        defer { _ = Darwin.close(fd) }
        guard Darwin.fsync(fd) == 0 else { throw Failure.unavailable }
        #else
        throw Failure.unavailable
        #endif
    }

    private static func keyQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keyService, kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }

    /// Call only while keyLock is held. Never rewrites a latest binding on read.
    private static func key(account: String, create: Bool) throws -> ProtectedRecord? {
        var query = keyQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data, data.count <= 2 * 1_024 else { throw Failure.unavailable }
            let record = try JSONDecoder().decode(ProtectedRecord.self, from: data)
            let absent = record.latestCapsuleSHA256 == nil && record.latestContextSHA256 == nil && record.latestGenerationID == nil
            let complete = record.latestCapsuleSHA256?.count == 64 && record.latestContextSHA256?.count == 64 && record.latestGenerationID != nil
            guard record.format == protectedRecordFormat, record.key.count == 32,
                  absent || complete else { throw Failure.unavailable }
            return record
        }
        guard status == errSecItemNotFound else { throw Failure.unavailable }
        guard create else { return nil }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw Failure.unavailable
        }
        let record = ProtectedRecord(format: protectedRecordFormat, key: Data(bytes),
            latestCapsuleSHA256: nil, latestContextSHA256: nil, latestGenerationID: nil)
        var item = keyQuery(account: account)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        item[kSecValueData as String] = try JSONEncoder().encode(record)
        let added = SecItemAdd(item as CFDictionary, nil)
        if added == errSecDuplicateItem { return try key(account: account, create: false) }
        guard added == errSecSuccess else { throw Failure.unavailable }
        return record
    }

    #if DEBUG
    static func removeOwnedKeyForTesting(account: String) {
        keyLock.lock(); defer { keyLock.unlock() }
        _ = SecItemDelete(keyQuery(account: account) as CFDictionary)
    }
    #endif
}
