import Foundation
import SwiftData

/// Values cross the review/network boundary; SwiftData objects never do.
nonisolated struct CatalogConflictProductValues: Codable, Equatable, Sendable {
    var barcode: String
    var itemNumber: String?
    var productName: String?
    var secondProductName: String?
    var purchasePrice: Double?
    var retailPrice: Double?
    var stockQuantity: Double?
    var supplierID: UUID?
    var categoryID: UUID?
    var supplierName: String?
    var categoryName: String?

    init(product: Product) {
        barcode = product.barcode; itemNumber = product.itemNumber
        productName = product.productName; secondProductName = product.secondProductName
        purchasePrice = product.purchasePrice; retailPrice = product.retailPrice
        stockQuantity = product.stockQuantity
        supplierID = product.supplier?.remoteID; categoryID = product.category?.remoteID
        supplierName = product.supplier?.name; categoryName = product.category?.name
    }

    init(row: RemoteInventoryProductRow, suppliers: [RemoteInventorySupplierRow] = [],
         categories: [RemoteInventoryCategoryRow] = []) {
        barcode = row.barcode; itemNumber = row.itemNumber
        productName = row.productName; secondProductName = row.secondProductName
        purchasePrice = row.purchasePrice; retailPrice = row.retailPrice; stockQuantity = row.stockQuantity
        supplierID = row.supplierID; categoryID = row.categoryID
        supplierName = suppliers.first { $0.id == row.supplierID }?.name
        categoryName = categories.first { $0.id == row.categoryID }?.name
    }

    static let fields = ["barcode", "itemNumber", "productName", "secondProductName", "purchasePrice",
                         "retailPrice", "stockQuantity", "supplierID", "categoryID"]

    static func canonicalField(_ raw: String) -> String? {
        if ["supplier", "suppliername"].contains(raw.lowercased()) { return "supplierID" }
        if ["category", "categoryname"].contains(raw.lowercased()) { return "categoryID" }
        return fields.first { $0.lowercased() == raw.lowercased() }
    }

    var fingerprint: String {
        LocalPendingChangeLogicalKey.privacyHash(ManualPushFingerprintNormalizer.product(
            barcode: barcode, itemNumber: itemNumber, productName: productName,
            secondProductName: secondProductName, purchasePrice: purchasePrice, retailPrice: retailPrice,
            stockQuantity: stockQuantity, supplierRemoteID: supplierID, categoryRemoteID: categoryID).canonicalString)
    }

    func overlay(_ selected: CatalogConflictProductValues, fields: [String]) throws -> Self {
        guard Set(fields).count == fields.count, fields.allSatisfy(Self.fields.contains) else {
            throw CatalogConflictResolutionError.invalidDecision
        }
        var value = self
        for field in fields {
            switch field {
            case "barcode": value.barcode = selected.barcode
            case "itemNumber": value.itemNumber = selected.itemNumber
            case "productName": value.productName = selected.productName
            case "secondProductName": value.secondProductName = selected.secondProductName
            case "purchasePrice": value.purchasePrice = selected.purchasePrice
            case "retailPrice": value.retailPrice = selected.retailPrice
            case "stockQuantity": value.stockQuantity = selected.stockQuantity
            case "supplierID": value.supplierID = selected.supplierID; value.supplierName = selected.supplierName
            case "categoryID": value.categoryID = selected.categoryID; value.categoryName = selected.categoryName
            default: throw CatalogConflictResolutionError.invalidDecision
            }
        }
        guard !value.barcode.isEmpty,
              [value.purchasePrice, value.retailPrice, value.stockQuantity].compactMap({ $0 }).allSatisfy(\.isFinite) else {
            throw CatalogConflictResolutionError.invalidDecision
        }
        return value
    }

    func differingFields(from other: Self) -> [String] {
        Self.fields.filter { field in
            switch field {
            case "barcode": barcode != other.barcode
            case "itemNumber": itemNumber != other.itemNumber
            case "productName": productName != other.productName
            case "secondProductName": secondProductName != other.secondProductName
            case "purchasePrice": purchasePrice != other.purchasePrice
            case "retailPrice": retailPrice != other.retailPrice
            case "stockQuantity": stockQuantity != other.stockQuantity
            case "supplierID": supplierID != other.supplierID
            case "categoryID": categoryID != other.categoryID
            default: false
            }
        }
    }

    var updatePayload: SyncAutomaticProductUpdatePayload {
        SyncAutomaticProductUpdatePayload(barcode: barcode, itemNumber: itemNumber, productName: productName,
            secondProductName: secondProductName, purchasePrice: purchasePrice, retailPrice: retailPrice,
            supplierID: supplierID, categoryID: categoryID, stockQuantity: stockQuantity, deletedAt: nil)
    }
}

nonisolated enum PersistedCatalogConflictChoice: Codable, Equatable, Sendable {
    case adoptRemote
    case adoptRemoteTombstone
    case selectedFields(values: CatalogConflictProductValues, fields: [String])
}

nonisolated enum PersistedCatalogConflictOutcome: Codable, Equatable, Sendable {
    case adoptedRemote
    case adoptedRemoteTombstone
    case successorPending(changeID: String)
}

nonisolated enum CatalogConflictResolutionError: Error, Equatable, Sendable {
    case invalidReceipt, invalidDecision, remoteUnavailable, remoteChanged, localChanged
    case ownerBusy, reconciliationRequired, destructiveDependencies, relationshipUnavailable
    case noConflict, generationChanged
}

nonisolated struct CatalogConflictRemoteSnapshot: Codable, Sendable {
    let product: RemoteInventoryProductRow
    let suppliers: [RemoteInventorySupplierRow]
    let categories: [RemoteInventoryCategoryRow]
    let observedAt: Date
    let scopeLeaseGeneration: UInt64

    var values: CatalogConflictProductValues {
        CatalogConflictProductValues(row: product, suppliers: suppliers, categories: categories)
    }

    /// Time of observation is not a remote version. The wire timestamps are
    /// kept byte-for-byte in `product` and become the later CAS predicates.
    var versionFingerprint: String {
        (try? LocalCatalogConflictResolutionStore.encode(RemoteBody(product: product,
            suppliers: suppliers, categories: categories))).map(ShopSyncRecoveryCanonical.sha256) ?? ""
    }

    private struct RemoteBody: Encodable {
        let product: RemoteInventoryProductRow
        let suppliers: [RemoteInventorySupplierRow]
        let categories: [RemoteInventoryCategoryRow]
    }
}

nonisolated struct PersistedCatalogConflictReview: Identifiable, Sendable {
    let id: UUID
    let changeID: String
    let originalChangedFields: [String]
    let desired: CatalogConflictProductValues
    let remote: CatalogConflictProductValues
    let remoteUpdatedAt: String
    let remoteDeletedAt: String?
    let canResolve: Bool
    let blockedReason: String?
    let pending: LocalPendingChangeCASToken
    let scope: Task126VerifiedOwnerStoreScope
    let generationID: UUID
    let snapshot: CatalogConflictRemoteSnapshot
    let originalSealSHA256: String?
    var predecessors: [CatalogConflictCapturedRevision] = []
}

nonisolated struct CatalogConflictCapturedRevision: Codable, Equatable, Sendable {
    let pending: LocalPendingChangeCASToken
    let sealSHA256: String?
}

/// The outbox owns local decisions, not a second queue or an ACK watermark.
/// Every consumer uses this resolver; a malformed receipt throws before a
/// revision can be considered clean or dispatched again.
nonisolated enum LocalCatalogConflictResolutionStore {
    static let domain = "local_catalog_conflict_resolution"
    static let format = "local_catalog_conflict_resolution_v1"
    static let maximumBytes = HistorySessionPushService.maximumHistoryRequestBytes

    struct OwnerReleaseProof: Codable, Equatable, Sendable {
        let invocationID: UUID
        let processEpoch: UUID
        let scopeLeaseGeneration: UInt64
        let generationID: UUID
        let writerJournalSHA256: String
    }

    enum Disposition: Codable, Equatable, Sendable {
        case neverDispatched(OwnerReleaseProof)
        case rejectedWithoutCommit(LocalPendingBusinessAttemptStore.RejectedWithoutCommitProof)
    }

    struct RetiredRevision: Codable, Sendable {
        let pending: LocalPendingChangeCASToken
        let sealJSON: String?
        let sealSHA256: String?
        let disposition: Disposition
    }

    struct Decision: Codable, Sendable {
        let schemaVersion: Int
        let decisionID: UUID
        let original: LocalPendingChangeCASToken
        let predecessors: [RetiredRevision]
        let expectedLatest: LocalPendingChangeCASToken
        let originalSealJSON: String?
        let originalSealSHA256: String?
        let desired: CatalogConflictProductValues
        let remote: CatalogConflictRemoteSnapshot
        let choice: PersistedCatalogConflictChoice
        let disposition: Disposition
        let originGenerationID: UUID
        let outcome: PersistedCatalogConflictOutcome
        let successor: LocalPendingChangeCASToken?
        let committedAt: Date
    }

    struct Transfer: Codable, Equatable, Sendable {
        let fromGenerationID: UUID
        let toGenerationID: UUID
        let previousReceiptSHA256: String
        let remoteID: UUID
    }

    struct Receipt: Codable, Sendable {
        let schemaVersion: Int
        let decision: Decision
        var transfers: [Transfer]
        var currentGenerationID: UUID { transfers.last?.toGenerationID ?? decision.originGenerationID }
        var resolvedChangeIDs: Set<String> {
            Set([decision.original.changeID] + decision.predecessors.map(\.pending.changeID))
        }
    }

    private struct SealHeader: Decodable {
        let schemaVersion: Int
        let pending: LocalPendingChangeCASToken
    }

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    static func receipts(context: ModelContext) throws -> [(SyncEventOutboxEntry, Receipt)] {
        let name = domain
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate { $0.domain == name })
        descriptor.fetchLimit = LocalPendingChangeAccumulator.defaultMaxActiveChanges + 1
        let entries = try context.fetch(descriptor)
        guard entries.count <= LocalPendingChangeAccumulator.defaultMaxActiveChanges else {
            throw CatalogConflictResolutionError.invalidReceipt
        }
        var revisions = Set<String>()
        return try entries.map { entry in
            let receipt = try validate(entry, context: context)
            guard revisions.isDisjoint(with: receipt.resolvedChangeIDs) else {
                throw CatalogConflictResolutionError.invalidReceipt
            }
            revisions.formUnion(receipt.resolvedChangeIDs)
            return (entry, receipt)
        }
    }

    static func resolvedChangeIDs(context: ModelContext) throws -> Set<String> {
        Set(try receipts(context: context).flatMap { $0.1.resolvedChangeIDs })
    }

    static func receipt(decisionID: UUID, context: ModelContext) throws -> Receipt? {
        try receipts(context: context).first { $0.1.decision.decisionID == decisionID }?.1
    }

    static func successorDecision(changeID: String, context: ModelContext) throws -> Decision? {
        let matches = try receipts(context: context).map(\.1.decision).filter { $0.successor?.changeID == changeID }
        guard matches.count <= 1 else { throw CatalogConflictResolutionError.invalidReceipt }
        return matches.first
    }

    static func blockedParentProductIDs(context: ModelContext, scope: Task126VerifiedOwnerStoreScope) throws -> Set<UUID> {
        let resolved = try resolvedChangeIDs(context: context)
        return Set(try context.fetch(FetchDescriptor<LocalPendingChange>()).filter {
            $0.entityKind == .product && !$0.status.isTerminal && !resolved.contains($0.changeID)
                && LocalPendingChangeScopeMatcher.matches($0, ownerUserID: scope.ownerUserID,
                    accountHash: scope.accountHash, storeIdentity: scope.storeIdentity)
        }.compactMap(\.entityRemoteID))
    }

    static func transfer(_ original: SyncEventOutboxEntry, to copy: SyncEventOutboxEntry,
        source: ModelContext, destination: ModelContext, stagingGenerationID: UUID) throws {
        var receipt = try validate(original, context: source)
        let remoteID = receipt.decision.remote.product.id
        var mapping = FetchDescriptor<Product>(predicate: #Predicate { $0.remoteID == remoteID }); mapping.fetchLimit = 2
        // Absence in a qualified later remote generation may be a newer
        // tombstone. It cannot revive the earlier locally retired revision.
        guard try destination.fetch(mapping).count <= 1,
              receipt.currentGenerationID != stagingGenerationID else { throw CatalogConflictResolutionError.invalidReceipt }
        receipt.transfers.append(Transfer(fromGenerationID: receipt.currentGenerationID,
            toGenerationID: stagingGenerationID, previousReceiptSHA256: original.entityIDsShape, remoteID: remoteID))
        let json = try encode(receipt)
        guard json.utf8.count <= maximumBytes else { throw CatalogConflictResolutionError.invalidReceipt }
        copy.metadataPayloadJSON = json
        copy.entityIDsShape = ShopSyncRecoveryCanonical.sha256(json)
    }

    static func attentionProductChangeIDs(context: ModelContext, ownerUserID: UUID,
        storeIdentity: LocalStoreIdentity) throws -> [String] {
        let resolved = try resolvedChangeIDs(context: context)
        let manualRequests = try ManualPendingAtomicRequestStore.protectedChangeIDs(context: context)
        return try context.fetch(FetchDescriptor<LocalPendingChange>()).filter { change in
            guard change.entityKind == .product, !change.status.isTerminal,
                  !resolved.contains(change.changeID),
                  LocalPendingChangeScopeMatcher.matches(change, ownerUserID: ownerUserID,
                    accountHash: AccountBindingStore.accountHash(for: ownerUserID), storeIdentity: storeIdentity) else { return false }
            if change.status == .blocked || change.status == .staleBaseline || manualRequests.contains(change.changeID) { return true }
            guard let seal = try LocalPendingBusinessAttemptStore.entry(changeID: change.changeID, context: context) else {
                return change.lastAttemptAt != nil
            }
            return ["catalog_atomic_rejection_v1", "catalog_outcome_unconfirmed_v1"].contains(seal.lastErrorKindRaw)
        }.map(\.changeID)
    }

    static func validate(_ entry: SyncEventOutboxEntry, context: ModelContext) throws -> Receipt {
        guard entry.domain == domain, entry.statusRaw == SyncEventOutboxStatus.localOnly.rawValue,
              entry.metadataShape == format, entry.eventType == "resolution", entry.changedCount == 1,
              let json = entry.metadataPayloadJSON, json.utf8.count <= maximumBytes,
              ShopSyncRecoveryCanonical.sha256(json) == entry.entityIDsShape,
              let data = json.data(using: .utf8) else { throw CatalogConflictResolutionError.invalidReceipt }
        let receipt = try JSONDecoder().decode(Receipt.self, from: data)
        let decision = receipt.decision
        let original = decision.original
        let manualRequests = try ManualPendingAtomicRequestStore.protectedChangeIDs(context: context)
        guard manualRequests.isDisjoint(with: [original.changeID] + decision.predecessors.map { $0.pending.changeID }) else {
            throw CatalogConflictResolutionError.invalidReceipt
        }
        guard try encode(receipt) == json, receipt.schemaVersion == 1, decision.schemaVersion == 1,
              entry.id == decision.decisionID.uuidString.lowercased(), entry.clientEventID == entry.id,
              entry.batchID == original.changeID, decision.expectedLatest == original,
              UUID(uuidString: original.changeID) != nil, !original.idempotencyKey.isEmpty,
              original.recordSchemaVersion == 1,
              original.ownerHash == AccountBindingStore.redactedAccountHash(for: entry.ownerUserID),
              entry.sourceDeviceID?.isEmpty == false,
              entry.ownerUserID == original.ownerUserID, entry.storeId == original.storeId,
              entry.localStoreId == original.localStoreId, entry.schemaVersion == original.schemaVersion,
              entry.syncProtocolVersion == original.syncProtocolVersion, entry.storeEpoch == original.storeEpoch,
              original.entityKindRaw == LocalPendingChangeEntityKind.product.rawValue,
              decision.remote.product.id.uuidString.lowercased() == original.entityRemoteIDRaw,
              decision.remote.product.ownerUserID.uuidString.lowercased() == entry.ownerUserID,
              decision.remote.product.shopID?.uuidString.lowercased() == entry.storeId,
              SupabaseRemoteDateParser.parse(decision.remote.product.updatedAt) != nil,
              !decision.remote.versionFingerprint.isEmpty else { throw CatalogConflictResolutionError.invalidReceipt }
        let id = original.changeID
        var query = FetchDescriptor<LocalPendingChange>(predicate: #Predicate { $0.changeID == id }); query.fetchLimit = 2
        let changes = try context.fetch(query)
        guard changes.count == 1, let change = changes.first, original.matches(change) else {
            throw CatalogConflictResolutionError.invalidReceipt
        }
        let seal = try LocalPendingBusinessAttemptStore.entry(changeID: id, context: context)
        switch decision.disposition {
        case .neverDispatched(let owner):
            guard seal == nil, original.lastAttemptAt == nil,
                  decision.originalSealJSON == nil, decision.originalSealSHA256 == nil,
                  owner.generationID == decision.originGenerationID,
                  owner.scopeLeaseGeneration == decision.remote.scopeLeaseGeneration,
                  owner.writerJournalSHA256 == ShopSyncRecoveryCanonical.sha256("no-recovery-journal") else {
                throw CatalogConflictResolutionError.invalidReceipt
            }
        case .rejectedWithoutCommit(let proof):
            guard let seal, seal.statusRaw == "localOnly", seal.eventType == "catalog",
                  seal.metadataPayloadJSON == decision.originalSealJSON,
                  seal.entityIDsShape == decision.originalSealSHA256,
                  let body = decision.originalSealJSON, ShopSyncRecoveryCanonical.sha256(body) == seal.entityIDsShape,
                  proof.schemaVersion == 1, ["23503", "23505"].contains(proof.sqlstate),
                  proof.dispatchJournalVersion == 2, proof.dispatchOrdinal == 1, !proof.hadPriorUnknown,
                  seal.attemptCount == proof.dispatchOrdinal,
                  proof.pending == original, proof.sealSHA256 == seal.entityIDsShape,
                  proof.changeID == original.changeID, proof.idempotencyKey == original.idempotencyKey,
                  seal.ownerUserID == entry.ownerUserID, seal.storeId == entry.storeId,
                  seal.localStoreId == entry.localStoreId, seal.storeEpoch == entry.storeEpoch,
                  seal.schemaVersion == entry.schemaVersion, seal.syncProtocolVersion == entry.syncProtocolVersion,
                  seal.sourceDeviceID == entry.sourceDeviceID else {
                throw CatalogConflictResolutionError.invalidReceipt
            }
            let header = try JSONDecoder().decode(SealHeader.self, from: Data(body.utf8))
            guard header.schemaVersion == 1, header.pending == original else { throw CatalogConflictResolutionError.invalidReceipt }
        }
        var precedingIDs = Set([original.changeID])
        for predecessor in decision.predecessors {
            let token = predecessor.pending
            guard precedingIDs.insert(token.changeID).inserted,
                  token.ownerUserID == original.ownerUserID, token.ownerHash == original.ownerHash,
                  token.storeId == original.storeId, token.localStoreId == original.localStoreId,
                  token.syncProtocolVersion == original.syncProtocolVersion,
                  token.schemaVersion == original.schemaVersion, token.storeEpoch == original.storeEpoch,
                  token.logicalKey == original.logicalKey, token.entityKindRaw == original.entityKindRaw,
                  token.entityRemoteIDRaw == original.entityRemoteIDRaw,
                  token.recordSchemaVersion == 1, UUID(uuidString: token.changeID) != nil,
                  !token.idempotencyKey.isEmpty else { throw CatalogConflictResolutionError.invalidReceipt }
            let predecessorID = token.changeID
            var query = FetchDescriptor<LocalPendingChange>(predicate: #Predicate { $0.changeID == predecessorID }); query.fetchLimit = 2
            let rows = try context.fetch(query)
            guard rows.count == 1, let row = rows.first, token.matches(row) else { throw CatalogConflictResolutionError.invalidReceipt }
            let priorSeal = try LocalPendingBusinessAttemptStore.entry(changeID: token.changeID, context: context)
            switch predecessor.disposition {
            case .neverDispatched(let owner):
                guard priorSeal == nil, token.lastAttemptAt == nil, predecessor.sealJSON == nil,
                      predecessor.sealSHA256 == nil, owner.generationID == decision.originGenerationID,
                      owner.scopeLeaseGeneration == decision.remote.scopeLeaseGeneration,
                      owner.writerJournalSHA256 == ShopSyncRecoveryCanonical.sha256("no-recovery-journal") else {
                    throw CatalogConflictResolutionError.invalidReceipt
                }
            case .rejectedWithoutCommit(let proof):
                guard let priorSeal, priorSeal.statusRaw == "localOnly", priorSeal.eventType == "catalog",
                      priorSeal.metadataPayloadJSON == predecessor.sealJSON,
                      priorSeal.entityIDsShape == predecessor.sealSHA256,
                      let body = predecessor.sealJSON, ShopSyncRecoveryCanonical.sha256(body) == priorSeal.entityIDsShape,
                      proof.schemaVersion == 1, ["23503", "23505"].contains(proof.sqlstate), proof.pending == token,
                      proof.dispatchJournalVersion == 2, proof.dispatchOrdinal == 1, !proof.hadPriorUnknown,
                      priorSeal.attemptCount == proof.dispatchOrdinal,
                      proof.sealSHA256 == priorSeal.entityIDsShape, proof.changeID == token.changeID,
                      proof.idempotencyKey == token.idempotencyKey,
                      priorSeal.ownerUserID == entry.ownerUserID, priorSeal.storeId == entry.storeId,
                      priorSeal.localStoreId == entry.localStoreId, priorSeal.storeEpoch == entry.storeEpoch,
                      priorSeal.schemaVersion == entry.schemaVersion, priorSeal.syncProtocolVersion == entry.syncProtocolVersion,
                      priorSeal.sourceDeviceID == entry.sourceDeviceID else { throw CatalogConflictResolutionError.invalidReceipt }
                let header = try JSONDecoder().decode(SealHeader.self, from: Data(body.utf8))
                guard header.schemaVersion == 1, header.pending == token else { throw CatalogConflictResolutionError.invalidReceipt }
            }
        }
        switch decision.outcome {
        case .adoptedRemote:
            guard decision.remote.product.deletedAt == nil, decision.successor == nil else { throw CatalogConflictResolutionError.invalidReceipt }
            switch decision.choice {
            case .adoptRemote: break
            case .selectedFields(let values, let fields):
                guard try decision.remote.values.overlay(values, fields: fields).differingFields(from: decision.remote.values).isEmpty else {
                    throw CatalogConflictResolutionError.invalidReceipt
                }
            case .adoptRemoteTombstone: throw CatalogConflictResolutionError.invalidReceipt
            }
        case .adoptedRemoteTombstone:
            guard let deleted = decision.remote.product.deletedAt, SupabaseRemoteDateParser.parse(deleted) != nil,
                  decision.successor == nil, decision.choice == .adoptRemoteTombstone else { throw CatalogConflictResolutionError.invalidReceipt }
        case .successorPending(let successorID):
            guard decision.remote.product.deletedAt == nil, let successor = decision.successor,
                  successor.changeID == successorID, successor.changeID != original.changeID,
                  successor.idempotencyKey != original.idempotencyKey,
                  successor.baselineFingerprintHash == decision.remote.values.fingerprint,
                  successor.entityRemoteIDRaw == original.entityRemoteIDRaw,
                  successor.ownerUserID == original.ownerUserID, successor.storeId == original.storeId,
                  successor.localStoreId == original.localStoreId else { throw CatalogConflictResolutionError.invalidReceipt }
            guard case .selectedFields(let selected, let fields) = decision.choice else { throw CatalogConflictResolutionError.invalidReceipt }
            let desired = try decision.remote.values.overlay(selected, fields: fields)
            let differences = desired.differingFields(from: decision.remote.values)
            guard !differences.isEmpty, LocalPendingChange.encodeChangedFields(differences) == successor.changedFieldsRaw,
                  desired.fingerprint == successor.intendedFingerprintHash,
                  successor.schemaVersion == original.schemaVersion, successor.storeEpoch == original.storeEpoch,
                  successor.syncProtocolVersion == original.syncProtocolVersion else { throw CatalogConflictResolutionError.invalidReceipt }
        }
        var previous = Receipt(schemaVersion: receipt.schemaVersion, decision: decision, transfers: [])
        var seen = Set([decision.originGenerationID])
        for transfer in receipt.transfers {
            guard transfer.fromGenerationID == previous.currentGenerationID,
                  seen.insert(transfer.toGenerationID).inserted,
                  transfer.remoteID == decision.remote.product.id,
                  transfer.previousReceiptSHA256 == ShopSyncRecoveryCanonical.sha256(try encode(previous)) else {
                throw CatalogConflictResolutionError.invalidReceipt
            }
            previous.transfers.append(transfer)
        }
        return receipt
    }

    static func insert(_ decision: Decision, context: ModelContext, scope: Task126VerifiedOwnerStoreScope) throws {
        let receipt = Receipt(schemaVersion: 1, decision: decision, transfers: [])
        let json = try encode(receipt)
        guard json.utf8.count <= maximumBytes else { throw CatalogConflictResolutionError.invalidReceipt }
        let id = decision.decisionID.uuidString.lowercased()
        let entry = SyncEventOutboxEntry(id: id, ownerUserID: scope.ownerUserID.uuidString.lowercased(),
            storeId: scope.storeIdentity.storeId, localStoreId: scope.storeIdentity.localStoreId,
            syncProtocolVersion: scope.storeIdentity.syncProtocolVersion, schemaVersion: scope.storeIdentity.schemaVersion,
            storeEpoch: scope.storeIdentity.storeEpoch, clientEventID: id, batchID: decision.original.changeID,
            domain: domain, eventType: "resolution", changedCount: 1,
            entityIDsShape: ShopSyncRecoveryCanonical.sha256(json), metadataShape: format,
            metadataPayloadJSON: json, status: .localOnly, nextRetryAt: decision.committedAt,
            createdAt: decision.committedAt, updatedAt: decision.committedAt, sourceDeviceID: scope.deviceInstallID)
        context.insert(entry)
        _ = try validate(entry, context: context)
    }
}

@MainActor
final class CatalogConflictResolutionService {
    private let remote: any SyncAutomaticCatalogIncrementalReading
    private let defaults: UserDefaults
    private static let processEpoch = UUID()

    init(remote: any SyncAutomaticCatalogIncrementalReading, defaults: UserDefaults = .standard) {
        self.remote = remote; self.defaults = defaults
    }

    // Keep reference-only teardown nonisolated on older concurrency runtimes.
    nonisolated deinit {}

    func prepare(modelContainer: ModelContainer, ownerUserID: UUID, remoteID: UUID,
                 changeID: String? = nil) async throws -> PersistedCatalogConflictReview {
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerUserID,
            defaults: defaults, allowsPendingSameScopeRecovery: true)
        let initial = try captureLocal(modelContainer: modelContainer, scope: scope, remoteID: remoteID, changeID: changeID)
        let snapshot = try await fetch(remoteID: remoteID, scope: scope)
        let current = try captureLocal(modelContainer: modelContainer, scope: scope, remoteID: remoteID,
                                      changeID: initial.pending.changeID)
        guard initial.pending == current.pending, initial.values == current.values,
              initial.generationID == current.generationID, initial.sealHash == current.sealHash,
              initial.predecessors == current.predecessors else {
            throw CatalogConflictResolutionError.localChanged
        }
        return PersistedCatalogConflictReview(id: UUID(), changeID: current.pending.changeID,
            originalChangedFields: Array(Set(([current.pending] + current.predecessors.map(\.pending))
                .flatMap { $0.changedFieldsRaw.split(separator: ",") }
                .compactMap { CatalogConflictProductValues.canonicalField(String($0)) })).sorted(),
            desired: current.values, remote: snapshot.values, remoteUpdatedAt: snapshot.product.updatedAt,
            remoteDeletedAt: snapshot.product.deletedAt, canResolve: current.canResolve,
            blockedReason: current.canResolve ? nil : "reconciliation-required", pending: current.pending,
            scope: scope, generationID: current.generationID, snapshot: snapshot, originalSealSHA256: current.sealHash,
            predecessors: current.predecessors)
    }

    func resolve(review: PersistedCatalogConflictReview, choice: PersistedCatalogConflictChoice,
                 modelContainer: ModelContainer) async throws -> PersistedCatalogConflictOutcome {
        try Task126OwnerStoreGate.revalidateAutomaticScope(review.scope, defaults: defaults)
        // Idempotent readback precedes a fresh network call: the same decision
        // remains durable even when the remote changes after it was committed.
        if let existing = try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(review.scope, defaults: defaults, operation: {
            try LocalCatalogConflictResolutionStore.receipt(decisionID: review.id, context: ModelContext(modelContainer))
        }) {
            guard existing.decision.original == review.pending, existing.decision.choice == choice else {
                throw CatalogConflictResolutionError.invalidDecision
            }
            return existing.decision.outcome
        }
        let currentRemote = try await fetch(remoteID: review.snapshot.product.id, scope: review.scope)
        guard currentRemote.versionFingerprint == review.snapshot.versionFingerprint else {
            throw CatalogConflictResolutionError.remoteChanged
        }
        // The shared automatic writer is released before acquiring this short
        // local fence. The network read above never holds the business lock.
        guard await AutomaticSyncSingleFlight.processShared.begin() else { throw CatalogConflictResolutionError.ownerBusy }
        do {
            let result = try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: modelContainer,
                ownerUserID: review.scope.ownerUserID, defaults: defaults,
                expectedAutomaticScope: review.scope) { context in
                guard Task126OwnerStoreGate.activeManifestWithLeaseHeld(modelContainer)?.generationID == review.generationID else {
                    throw CatalogConflictResolutionError.generationChanged
                }
                let binding = AccountBindingStore(defaults: defaults)
                // A never-dispatched proof is not inferred from a missing ACK.
                // This path requires an idle writer, no recovery journal, and
                // absent preparation under the very fence used to seal calls.
                let witness = LocalCatalogConflictResolutionStore.OwnerReleaseProof(invocationID: UUID(),
                    processEpoch: Self.processEpoch, scopeLeaseGeneration: review.scope.leaseGeneration,
                    generationID: review.generationID,
                    writerJournalSHA256: ShopSyncRecoveryCanonical.sha256(binding.hasPendingReplacementJournal ? "recovery-present" : "no-recovery-journal"))
                return try LocalPendingChangeAccumulator.resolvePersistedCatalogConflict(context: context,
                    review: review, choice: choice, remote: currentRemote, ownerRelease: witness,
                    writerJournalIsClear: !binding.hasPendingReplacementJournal)
            }
            let persisted = try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(review.scope, defaults: defaults) {
                try LocalCatalogConflictResolutionStore.receipt(decisionID: review.id, context: ModelContext(modelContainer))
            }
            guard persisted?.decision.outcome == result else { throw CatalogConflictResolutionError.invalidReceipt }
            await AutomaticSyncSingleFlight.processShared.finish()
            NotificationCenter.default.post(name: Notification.Name("localPendingChangesDidChange"), object: nil)
            return result
        } catch {
            await AutomaticSyncSingleFlight.processShared.finish()
            throw error
        }
    }

    private struct CapturedLocal {
        let pending: LocalPendingChangeCASToken
        let values: CatalogConflictProductValues
        let generationID: UUID
        let sealHash: String?
        let canResolve: Bool
        let predecessors: [CatalogConflictCapturedRevision]
    }

    private func captureLocal(modelContainer: ModelContainer, scope: Task126VerifiedOwnerStoreScope,
        remoteID: UUID, changeID: String?) throws -> CapturedLocal {
        try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(scope, defaults: defaults) {
            try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(modelContainer)
            guard let generationID = Task126OwnerStoreGate.activeManifestWithLeaseHeld(modelContainer)?.generationID else {
                throw CatalogConflictResolutionError.generationChanged
            }
            let context = ModelContext(modelContainer)
            let resolved = try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: context)
            let candidates = try context.fetch(FetchDescriptor<LocalPendingChange>()).filter {
                $0.entityKind == .product && $0.entityRemoteID == remoteID && !$0.status.isTerminal
                    && !resolved.contains($0.changeID)
                    && LocalPendingChangeScopeMatcher.matches($0, ownerUserID: scope.ownerUserID,
                        accountHash: scope.accountHash, storeIdentity: scope.storeIdentity)
            }.sorted { ($0.createdAt, $0.changeID) < ($1.createdAt, $1.changeID) }
            guard let change = candidates.last,
                  changeID == nil || candidates.contains(where: { $0.changeID == changeID }) else {
                throw CatalogConflictResolutionError.localChanged
            }
            let manualRequests = try ManualPendingAtomicRequestStore.blockingChangeIDs(context: context, scope: scope)
            let manualBlocksLineage = !manualRequests.isDisjoint(with: candidates.map(\.changeID))
            let seal = try LocalPendingBusinessAttemptStore.entry(changeID: change.changeID, context: context)
            let proof = try LocalPendingBusinessAttemptStore.rejectionProof(change: change, context: context, scope: scope)
            let predecessors = try candidates.dropLast().map { prior in
                CatalogConflictCapturedRevision(pending: LocalPendingChangeCASToken(prior),
                    sealSHA256: try LocalPendingBusinessAttemptStore.entry(changeID: prior.changeID, context: context)?.entityIDsShape)
            }
            guard change.status == .blocked || change.status == .staleBaseline || seal != nil || manualBlocksLineage
                    || predecessors.contains(where: { $0.sealSHA256 != nil }) else {
                throw CatalogConflictResolutionError.noConflict
            }
            let priorDispositionsKnown = try candidates.dropLast().allSatisfy { prior in
                try LocalPendingBusinessAttemptStore.rejectionProof(change: prior, context: context, scope: scope) != nil
                    || (prior.lastAttemptAt == nil
                        && LocalPendingBusinessAttemptStore.entry(changeID: prior.changeID, context: context) == nil)
            }
            let product = try Self.product(remoteID: remoteID, context: context)
            guard product.remoteDeletedAt == nil else { throw CatalogConflictResolutionError.remoteUnavailable }
            return CapturedLocal(pending: LocalPendingChangeCASToken(change), values: CatalogConflictProductValues(product: product),
                generationID: generationID, sealHash: seal?.entityIDsShape,
                canResolve: !manualBlocksLineage && priorDispositionsKnown && (proof != nil || (seal == nil && change.lastAttemptAt == nil)),
                predecessors: predecessors)
        }
    }

    private func fetch(remoteID: UUID, scope: Task126VerifiedOwnerStoreScope) async throws -> CatalogConflictRemoteSnapshot {
        var ids = SyncEventEntityIDSet()
        ids.productIDs = [remoteID]
        let fetched = try await CatalogIncrementalApplyService(remote: remote, scope: scope, defaults: defaults).fetch(eventIDs: ids)
        let qualified = try catalogIncrementalMutationRows(fetched: fetched, eventIDs: ids)
        guard qualified.products.count == 1, let row = qualified.products.first, row.id == remoteID,
              row.ownerUserID == scope.ownerUserID, row.shopID == scope.shopID,
              SupabaseRemoteDateParser.parse(row.updatedAt) != nil,
              row.deletedAt == nil || SupabaseRemoteDateParser.parse(row.deletedAt) != nil,
              Set(qualified.suppliers.map(\.id)).count == qualified.suppliers.count,
              Set(qualified.categories.map(\.id)).count == qualified.categories.count,
              qualified.suppliers.allSatisfy({ $0.deletedAt == nil }),
              qualified.categories.allSatisfy({ $0.deletedAt == nil }) else {
            throw CatalogConflictResolutionError.remoteUnavailable
        }
        return CatalogConflictRemoteSnapshot(product: row,
            suppliers: qualified.suppliers.sorted { $0.id.uuidString < $1.id.uuidString },
            categories: qualified.categories.sorted { $0.id.uuidString < $1.id.uuidString },
            observedAt: Date(), scopeLeaseGeneration: scope.leaseGeneration)
    }

    nonisolated static func product(remoteID: UUID, context: ModelContext) throws -> Product {
        var descriptor = FetchDescriptor<Product>(predicate: #Predicate { $0.remoteID == remoteID }); descriptor.fetchLimit = 2
        let rows = try context.fetch(descriptor)
        guard rows.count == 1, let row = rows.first else { throw CatalogConflictResolutionError.localChanged }
        return row
    }
}

extension LocalPendingChangeAccumulator {
    /// Caller owns both the process writer and the ordinary local mutation
    /// fence. The projection, successor and local non-ACK receipt share a save.
    nonisolated static func resolvePersistedCatalogConflict(context: ModelContext,
        review: PersistedCatalogConflictReview, choice: PersistedCatalogConflictChoice,
        remote: CatalogConflictRemoteSnapshot, ownerRelease: LocalCatalogConflictResolutionStore.OwnerReleaseProof,
        writerJournalIsClear: Bool) throws -> PersistedCatalogConflictOutcome {
        if let receipt = try LocalCatalogConflictResolutionStore.receipt(decisionID: review.id, context: context) {
            guard receipt.decision.original == review.pending, receipt.decision.choice == choice else {
                throw CatalogConflictResolutionError.invalidDecision
            }
            return receipt.decision.outcome
        }
        let resolved = try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: context)
        let active = try context.fetch(FetchDescriptor<LocalPendingChange>()).filter {
            !$0.status.isTerminal && !resolved.contains($0.changeID)
        }
        let lineage = active.filter { $0.entityKind == .product && $0.logicalKey == review.pending.logicalKey }
        let expected = review.predecessors.map(\.pending) + [review.pending]
        guard try ManualPendingAtomicRequestStore.blockingChangeIDs(context: context, scope: review.scope)
            .isDisjoint(with: expected.map(\.changeID)) else { throw CatalogConflictResolutionError.reconciliationRequired }
        guard lineage.count == expected.count, Set(lineage.map(\.changeID)) == Set(expected.map(\.changeID)),
              let original = lineage.first(where: { $0.changeID == review.pending.changeID }), review.pending.matches(original),
              expected.allSatisfy({ token in lineage.contains { token.matches($0) } }),
              lineage.sorted(by: { ($0.createdAt, $0.changeID) < ($1.createdAt, $1.changeID) }).last?.changeID == original.changeID,
              LocalPendingChangeScopeMatcher.matches(original, ownerUserID: review.scope.ownerUserID,
                accountHash: review.scope.accountHash, storeIdentity: review.scope.storeIdentity),
              remote.versionFingerprint == review.snapshot.versionFingerprint else { throw CatalogConflictResolutionError.localChanged }
        let product = try CatalogConflictResolutionService.product(remoteID: remote.product.id, context: context)
        guard CatalogConflictProductValues(product: product) == review.desired,
              product.remoteDeletedAt == nil else { throw CatalogConflictResolutionError.localChanged }
        let seal = try LocalPendingBusinessAttemptStore.entry(changeID: original.changeID, context: context)
        guard seal?.entityIDsShape == review.originalSealSHA256 else { throw CatalogConflictResolutionError.localChanged }
        func qualifyDisposition(_ change: LocalPendingChange) throws -> LocalCatalogConflictResolutionStore.Disposition {
            if let proof = try LocalPendingBusinessAttemptStore.rejectionProof(change: change, context: context, scope: review.scope) {
                return .rejectedWithoutCommit(proof)
            }
            guard try LocalPendingBusinessAttemptStore.entry(changeID: change.changeID, context: context) == nil,
                  change.lastAttemptAt == nil, writerJournalIsClear,
                  ownerRelease.generationID == review.generationID,
                  ownerRelease.scopeLeaseGeneration == review.scope.leaseGeneration,
                  ownerRelease.writerJournalSHA256 == ShopSyncRecoveryCanonical.sha256("no-recovery-journal") else {
                throw CatalogConflictResolutionError.reconciliationRequired
            }
            return .neverDispatched(ownerRelease)
        }
        let disposition = try qualifyDisposition(original)
        let predecessors = try review.predecessors.map { captured -> LocalCatalogConflictResolutionStore.RetiredRevision in
            guard let change = lineage.first(where: { $0.changeID == captured.pending.changeID }) else {
                throw CatalogConflictResolutionError.localChanged
            }
            let priorSeal = try LocalPendingBusinessAttemptStore.entry(changeID: change.changeID, context: context)
            guard priorSeal?.entityIDsShape == captured.sealSHA256 else { throw CatalogConflictResolutionError.localChanged }
            return LocalCatalogConflictResolutionStore.RetiredRevision(pending: captured.pending,
                sealJSON: priorSeal?.metadataPayloadJSON, sealSHA256: priorSeal?.entityIDsShape,
                disposition: try qualifyDisposition(change))
        }
        var desired = remote.values
        var fields: [String] = []
        switch choice {
        case .adoptRemote:
            guard remote.product.deletedAt == nil else { throw CatalogConflictResolutionError.invalidDecision }
        case .adoptRemoteTombstone:
            guard let deleted = remote.product.deletedAt, SupabaseRemoteDateParser.parse(deleted) != nil else {
                throw CatalogConflictResolutionError.invalidDecision
            }
            // Product.priceHistory has a cascade. Retaining only the catalog
            // intent cannot justify discarding any append-only child.
            guard product.priceHistory.isEmpty else { throw CatalogConflictResolutionError.destructiveDependencies }
        case .selectedFields(let selected, let chosen):
            guard remote.product.deletedAt == nil else { throw CatalogConflictResolutionError.invalidDecision }
            desired = try remote.values.overlay(selected, fields: chosen)
            fields = desired.differingFields(from: remote.values)
        }
        let now = Date()
        var successor: LocalPendingChange?
        let outcome: PersistedCatalogConflictOutcome
        if case .adoptRemoteTombstone = choice {
            // Existing deletion projection only, after proving the cascade is
            // empty. The original revision and its seal remain in the outbox.
            context.delete(product)
            outcome = .adoptedRemoteTombstone
        } else {
            try applyConflictProjection(desired, remote: remote, to: product, context: context)
            if !fields.isEmpty {
                guard active.count < defaultMaxActiveChanges else {
                    throw LocalPendingChangeAccumulatorError.activeChangeLimitExceeded(limit: defaultMaxActiveChanges)
                }
                let change = LocalPendingChange(ownerUserID: review.scope.ownerUserID,
                    storeId: review.scope.storeIdentity.storeId, localStoreId: review.scope.storeIdentity.localStoreId,
                    syncProtocolVersion: review.scope.storeIdentity.syncProtocolVersion,
                    schemaVersion: review.scope.storeIdentity.schemaVersion, storeEpoch: review.scope.storeIdentity.storeEpoch,
                    baseRemoteUpdatedAt: SupabaseRemoteDateParser.parse(remote.product.updatedAt),
                    entityKind: .product, operation: .update, origin: .reconciliation,
                    logicalKey: original.logicalKey, changedFields: fields,
                    baselineFingerprintHash: remote.values.fingerprint, intendedFingerprintHash: desired.fingerprint,
                    entityRemoteID: remote.product.id, createdAt: now, updatedAt: now)
                context.insert(change); successor = change
                outcome = .successorPending(changeID: change.changeID)
                let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: review.scope.ownerUserID,
                    storeIdentity: review.scope.storeIdentity, emitsNotifications: false)
                for (field, type, value, previous) in [
                    ("purchasePrice", PriceType.purchase, desired.purchasePrice, review.desired.purchasePrice),
                    ("retailPrice", PriceType.retail, desired.retailPrice, review.desired.retailPrice)
                ] where fields.contains(field) && value != previous {
                    if let value {
                        let price = ProductPrice(type: type, price: value, effectiveAt: now,
                            source: "manual", note: nil, createdAt: now, product: product)
                        context.insert(price)
                        _ = try accumulator.recordProductPriceChange(price: price, origin: .productPriceSave)
                    }
                }
            } else { outcome = .adoptedRemote }
        }
        let decision = LocalCatalogConflictResolutionStore.Decision(schemaVersion: 1, decisionID: review.id,
            original: review.pending, predecessors: predecessors, expectedLatest: review.pending, originalSealJSON: seal?.metadataPayloadJSON,
            originalSealSHA256: seal?.entityIDsShape, desired: review.desired, remote: remote, choice: choice,
            disposition: disposition, originGenerationID: review.generationID, outcome: outcome,
            successor: successor.map(LocalPendingChangeCASToken.init), committedAt: now)
        // This is the qualified remote readback, not an overlay assertion.
        // It lets the normal reopen body verifier distinguish adopted R from
        // the older immutable recovery checkpoint without reviving A.
        try LocalCatalogBodyProofStore.record(remote.product, context: context, scope: review.scope)
        try LocalCatalogConflictResolutionStore.insert(decision, context: context, scope: review.scope)
        try context.save()
        return outcome
    }

    nonisolated private static func applyConflictProjection(_ values: CatalogConflictProductValues,
        remote: CatalogConflictRemoteSnapshot, to product: Product, context: ModelContext) throws {
        let barcode = values.barcode
        var duplicate = FetchDescriptor<Product>(predicate: #Predicate { $0.barcode == barcode }); duplicate.fetchLimit = 2
        guard try context.fetch(duplicate).allSatisfy({ $0.persistentModelID == product.persistentModelID }) else {
            throw CatalogConflictResolutionError.localChanged
        }
        var supplier: Supplier?
        if let id = values.supplierID {
            var query = FetchDescriptor<Supplier>(predicate: #Predicate { $0.remoteID == id }); query.fetchLimit = 2
            let rows = try context.fetch(query)
            guard rows.count == 1, rows[0].remoteDeletedAt == nil else { throw CatalogConflictResolutionError.relationshipUnavailable }
            supplier = rows[0]
        }
        var category: ProductCategory?
        if let id = values.categoryID {
            var query = FetchDescriptor<ProductCategory>(predicate: #Predicate { $0.remoteID == id }); query.fetchLimit = 2
            let rows = try context.fetch(query)
            guard rows.count == 1, rows[0].remoteDeletedAt == nil else { throw CatalogConflictResolutionError.relationshipUnavailable }
            category = rows[0]
        }
        product.barcode = values.barcode; product.itemNumber = values.itemNumber
        product.productName = values.productName; product.secondProductName = values.secondProductName
        product.purchasePrice = values.purchasePrice; product.retailPrice = values.retailPrice
        product.stockQuantity = values.stockQuantity; product.supplier = supplier; product.category = category
        product.remoteUpdatedAt = SupabaseRemoteDateParser.parse(remote.product.updatedAt)
        product.remoteDeletedAt = nil
        product.primaryImageVersionID = remote.product.primaryImageVersionID
        product.primaryImageUpdatedAt = SupabaseRemoteDateParser.parse(remote.product.primaryImageUpdatedAt)
        try CatalogTextPersistenceBoundary.canonicalize(product)
        guard CatalogConflictProductValues(product: product).fingerprint == values.fingerprint else {
            throw CatalogConflictResolutionError.invalidDecision
        }
    }
}
