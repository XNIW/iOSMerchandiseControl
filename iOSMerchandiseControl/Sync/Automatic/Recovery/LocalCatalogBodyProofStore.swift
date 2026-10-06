import Foundation
import SwiftData

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

    /// Called off Main under a before/after physical-file fence. Retained
    /// pending intent explains only its own exact current business body.
    static func validate(container: ModelContainer, manifest: SyncStoreGenerationManifest, storeURL: URL) throws {
        let context = ModelContext(container); context.autosaveEnabled = false
        let ownerHash = manifest.accountHash
        var pendingDescriptor = FetchDescriptor<LocalPendingChange>(predicate: #Predicate {
            $0.statusRaw != "superseded" && $0.statusRaw != "acknowledged"
        })
        pendingDescriptor.fetchLimit = LocalPendingChangeAccumulator.defaultMaxActiveChanges + 1
        let pending = try context.fetch(pendingDescriptor)
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
        try scan(Product.self, kind: .product, context: context, manifest: manifest, pending: grouped,
            sort: [SortDescriptor(\Product.remoteID)]) { row in
                (row.remoteID, row.remoteUpdatedAt, row.remoteDeletedAt,
                 ManualPushFingerprintNormalizer.product(barcode: row.barcode, itemNumber: row.itemNumber,
                    productName: row.productName, secondProductName: row.secondProductName,
                    purchasePrice: row.purchasePrice, retailPrice: row.retailPrice, stockQuantity: row.stockQuantity,
                    supplierRemoteID: row.supplier?.remoteID, categoryRemoteID: row.category?.remoteID).canonicalString,
                 LocalPendingChangeLogicalKey.product(remoteID: row.remoteID, barcode: row.barcode),
                 LocalPendingChangeLogicalKey.productFingerprintHash(row))
            }
        try scan(Supplier.self, kind: .supplier, context: context, manifest: manifest, pending: grouped,
            sort: [SortDescriptor(\Supplier.remoteID)]) { row in
                (row.remoteID, row.remoteUpdatedAt, row.remoteDeletedAt,
                 ManualPushFingerprintNormalizer.supplier(remoteID: row.remoteID, name: row.name).canonicalString,
                 LocalPendingChangeLogicalKey.supplier(remoteID: row.remoteID, name: row.name),
                 LocalPendingChangeLogicalKey.supplierFingerprintHash(row))
            }
        try scan(ProductCategory.self, kind: .productCategory, context: context, manifest: manifest, pending: grouped,
            sort: [SortDescriptor(\ProductCategory.remoteID)]) { row in
                (row.remoteID, row.remoteUpdatedAt, row.remoteDeletedAt,
                 ManualPushFingerprintNormalizer.category(remoteID: row.remoteID, name: row.name).canonicalString,
                 LocalPendingChangeLogicalKey.category(remoteID: row.remoteID, name: row.name),
                 LocalPendingChangeLogicalKey.categoryFingerprintHash(row))
            }
        let ledger = try ShopSyncRecoveryLedger(generationStoreURL: storeURL, mode: .readExisting)
        try validatePrices(context: context, manifest: manifest, pending: grouped, ledger: ledger)
        try validateHistory(context: context, manifest: manifest, pending: grouped, ledger: ledger)
    }

    private static func priceBody(parent: UUID, type: String, price: Double, effectiveAt: Date,
                                  createdAt: Date, sourceHash: String, noteHash: String) -> String {
        ShopSyncRecoveryCanonical.joined(parent.uuidString.lowercased(), type, String(price.bitPattern),
            ProductPriceEffectiveAtCanonicalizer.canonicalString(from: effectiveAt),
            ProductPriceEffectiveAtCanonicalizer.canonicalString(from: createdAt), sourceHash, noteHash)
    }

    private static func priceBody(_ row: ProductPrice) throws -> String {
        guard let parent = row.product, let parentID = parent.remoteID, parent.remoteDeletedAt == nil,
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
        let deletes = Set(pending.values.flatMap { $0 }.filter {
            $0.entityKind == .product && $0.operation == .delete
        }.compactMap(\.entityRemoteID))
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
            let body = try priceBody(row)
            guard row.remoteID.flatMap({ pager.overrides[$0]?.canonical }) == body else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        try forEachBatch(ledger: ledger, domain: .prices) { batch in
            let parsed = try batch.map { record -> (UUID, UUID, String) in
                let parts = record.versionLine.components(separatedBy: ShopSyncRecoveryCanonical.separator)
                guard parts.count == 9, let id = UUID(uuidString: parts[0]), let parent = UUID(uuidString: parts[2]),
                      id.uuidString.lowercased() == record.orderingID, !record.isTombstone,
                      let amount = Decimal(string: parts[3], locale: Locale(identifier: "en_US_POSIX")),
                      let type = SupabasePullPreviewNormalizer.normalizedPriceType(parts[4]),
                      let effective = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: parts[5]),
                      let created = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: parts[6]),
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
                    let actual = try priceBody(row)
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
                    guard let row = current[proof.remoteID], try priceBody(row) == proof.canonical
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
        var descriptor = FetchDescriptor<Model>(sortBy: sort)
        descriptor.fetchLimit = batchSize
        var offset = 0; var prior: UUID?; var physicalActive = 0
        while true {
            try Task.checkCancellation()
            descriptor.fetchOffset = offset
            let rows = try context.fetch(descriptor)
            if rows.isEmpty { break }
            let current = rows.map(body)
            let ids = current.compactMap { $0.0 }
            let expected = try expectedBodies(kind: kind, ids: ids, context: context, manifest: manifest)
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
        for record in records {
            guard result[record.remoteID] == nil,
                  AccountBindingStore.accountHash(for: record.ownerUserUUID) == manifest.accountHash,
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
        guard entry.status == .localOnly, entry.metadataShape == format,
              UUID(uuidString: entry.ownerUserID).map(AccountBindingStore.accountHash(for:)) == manifest.accountHash,
              entry.storeId == manifest.storeIdentity.storeId, entry.localStoreId == manifest.storeIdentity.localStoreId,
              entry.schemaVersion == manifest.storeIdentity.schemaVersion,
              entry.syncProtocolVersion == manifest.storeIdentity.syncProtocolVersion,
              entry.storeEpoch == manifest.storeIdentity.storeEpoch,
              entry.sourceDeviceID.map(DeviceInstallIDStore.identityHash(for:)) == manifest.deviceIdentityHash,
              let json = entry.metadataPayloadJSON, json.utf8.count <= ShopSyncRecoveryLimits.maximumGenerationManifestBytes,
              ShopSyncRecoveryCanonical.sha256(json) == entry.entityIDsShape,
              let data = json.data(using: .utf8) else { throw SyncStoreGenerationError.activationReadBackFailed }
        let proof = try JSONDecoder().decode(Body.self, from: data)
        guard proof.generationID == manifest.generationID,
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
