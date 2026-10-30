#if DEBUG
import Foundation

/// Bounded remote/observation state of the existing isolated root fixture.
/// Local data, journal, intents and ACKs are always written by production code.
@MainActor
final class Task145SavedRecoveryControl {
    static let savedName = "R23 saved before recovery activation"
    /// Values read from one fresh local context before ACK. No SwiftData ID or
    /// predicted cloud ID crosses the generation/process boundary.
    struct LocalPriceWitness: Codable, Equatable {
        let ownerUserID: UUID
        let shopID: UUID
        let accountHash: String
        let storeRawValue: String
        let defaultStoreID: String
        let localStoreID: String
        let schemaVersion: Int
        let syncProtocolVersion: Int
        let storeEpoch: Int
        let deviceInstallID: String
        let deviceIdentityHash: String
        let productID: UUID
        let productBarcode: String
        let type: String
        let localPriceBits: UInt64
        let localEffectiveAt: Date
        let localCreatedAt: Date
        let price: Double
        let amountCanonical: String
        let effectiveAt: String
        let source: String?
        let note: String?
        let createdAt: String
        let logicalKey: String
        let intendedFingerprintHash: String
        let originalToken: LocalPendingChangeCASToken

        func matchesScope(_ scope: Task126VerifiedOwnerStoreScope) -> Bool {
            ownerUserID == scope.ownerUserID && shopID == scope.shopID
                && accountHash == scope.accountHash
                && storeRawValue == scope.storeIdentity.rawValue
                && defaultStoreID == scope.storeIdentity.defaultStoreId
                && localStoreID == scope.storeIdentity.localStoreId
                && schemaVersion == scope.storeIdentity.schemaVersion
                && syncProtocolVersion == scope.storeIdentity.syncProtocolVersion
                && storeEpoch == scope.storeIdentity.storeEpoch
                && deviceInstallID == scope.deviceInstallID
                && deviceIdentityHash == scope.deviceIdentityHash
        }
        func matchesPayload(_ payload: SyncAutomaticProductPricePayload) -> Bool {
            ownerUserID == payload.ownerUserID && shopID == payload.shopID
                && productID == payload.productID && type == payload.type
                && price.bitPattern == payload.price.bitPattern
                && amountCanonical == PriceCanonicalizer.canonicalAmount(from: payload.price)?.value
                && effectiveAt == payload.effectiveAt && source == payload.source
                && note == payload.note && createdAt == payload.createdAt
        }
    }
    struct State: Codable {
        let schema: Int
        let runID: UUID
        var product: RemoteInventoryProductRow
        var originalGeneration: UUID?
        var terminalGeneration: UUID?
        var journalBytes: Data?
        var savedTokens: [LocalPendingChangeCASToken] = []
        var savedLocalPriceWitness: LocalPriceWitness?
        var savedPriceID: UUID?
        var catalogIngressCount = 0
        var priceIngressCount = 0
        var eventIngressCount = 0
        var catalogPayloads: [Data] = []
        var prices: [RemoteInventoryProductPriceRow] = []
        var pricePayloads: [Data] = []
        var events: [RemoteSyncEventRow] = []
        var eventClientIDs: [String: RemoteSyncEventRow] = [:]
        var processIDs: [Int32] = []
    }
    /// Decode only the actual recorded outbound bytes, never construct an ID.
    private struct ObservedPricePayload: Decodable {
        let id: UUID
        let ownerUserID: UUID
        let shopID: UUID?
        let productID: UUID
        let type: String
        let price: Double
        let effectiveAt: String
        let source: String?
        let note: String?
        let createdAt: String
        enum CodingKeys: String, CodingKey {
            case id, type, price, source, note
            case ownerUserID = "owner_user_id", shopID = "shop_id", productID = "product_id"
            case effectiveAt = "effective_at", createdAt = "created_at"
        }
    }
    let reopening: Bool
    let url: URL
    var state: State
    var qualifiedReopen: Data?
    var capturePrice: ((SyncAutomaticProductPricePayload, Task126VerifiedOwnerStoreScope) throws -> LocalPriceWitness)?
    init(url: URL, runID: UUID, initial: RemoteInventoryProductRow, reopening: Bool) throws {
        self.url = url; self.reopening = reopening
        if reopening {
            let data = try Data(contentsOf: url)
            guard data.count <= 262_144 else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = try JSONDecoder().decode(State.self, from: data)
            guard state.schema == 2, state.runID == runID, state.product.id == initial.id,
                  state.product.ownerUserID == initial.ownerUserID, state.product.shopID == initial.shopID,
                  state.originalGeneration != nil, hasOriginalPriceWitness(),
                  state.processIDs.count < 3, !state.processIDs.contains(ProcessInfo.processInfo.processIdentifier),
                  state.journalBytes != nil else { throw SyncStoreGenerationError.activationReadBackFailed }
            if state.terminalGeneration == nil {
                guard state.savedPriceID == nil, state.catalogPayloads.isEmpty,
                      state.pricePayloads.isEmpty, state.prices.isEmpty, state.events.isEmpty,
                      state.catalogIngressCount == 0, state.priceIngressCount == 0,
                      state.eventIngressCount == 0 else { throw SyncStoreGenerationError.activationReadBackFailed }
            } else {
                guard try observedPriceIsJoined() else { throw SyncStoreGenerationError.activationReadBackFailed }
            }
        } else {
            guard !FileManager.default.fileExists(atPath: url.path) else { throw SyncStoreGenerationError.activationReadBackFailed }
            state = State(schema: 2, runID: runID, product: initial)
        }
        state.processIDs.append(ProcessInfo.processInfo.processIdentifier)
        try persist()
    }
    func bytes() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }
    func persist() throws {
        let data = try bytes()
        guard state.schema == 2, data.count <= 262_144,
              state.catalogIngressCount <= 8, state.priceIngressCount <= 8,
              state.eventIngressCount <= 8, state.catalogPayloads.count <= 1,
              state.pricePayloads.count <= 1, state.prices.count <= 1,
              state.events.count <= 2, state.eventClientIDs.count <= 2 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        if !state.savedTokens.isEmpty {
            guard hasOriginalPriceWitness() else { throw SyncStoreGenerationError.activationReadBackFailed }
        }
        if state.savedPriceID != nil {
            guard try observedPriceIsJoined() else { throw SyncStoreGenerationError.activationReadBackFailed }
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    func hasOriginalPriceWitness() -> Bool {
        let tokens = state.savedTokens.filter { $0.entityKindRaw == "productPrice" }
        guard state.savedTokens.count == 2, Set(state.savedTokens.map(\.changeID)).count == 2,
              Set(state.savedTokens.map(\.entityKindRaw)) == ["product", "productPrice"],
              tokens.count == 1, let token = tokens.first, let witness = state.savedLocalPriceWitness else { return false }
        return token == witness.originalToken && token.statusRaw == LocalPendingChangeStatus.pending.rawValue
            && token.entityRemoteIDRaw == nil && token.logicalKey == witness.logicalKey
            && token.intendedFingerprintHash == witness.intendedFingerprintHash
            && witness.productID == state.product.id && witness.productBarcode == state.product.barcode
            && witness.ownerUserID == state.product.ownerUserID && witness.shopID == state.product.shopID
    }
    /// The immutable request and returned row must still describe the witness.
    /// This observation does not set a local model ID or acknowledge an intent.
    func observedPriceIsJoined() throws -> Bool {
        guard hasOriginalPriceWitness(), let witness = state.savedLocalPriceWitness,
              let id = state.savedPriceID, state.pricePayloads.count == 1, state.prices.count == 1,
              let row = state.prices.first else { return false }
        let payloads = try JSONDecoder().decode([ObservedPricePayload].self, from: state.pricePayloads[0])
        guard payloads.count == 1, let payload = payloads.first else { return false }
        return payload.id == id && row.id == id
            && payload.ownerUserID == witness.ownerUserID && row.ownerUserID == payload.ownerUserID
            && payload.shopID == witness.shopID && row.shopID == payload.shopID
            && payload.productID == witness.productID && row.productID == payload.productID
            && payload.type == witness.type && row.type == payload.type
            && payload.price.bitPattern == witness.price.bitPattern && row.price.bitPattern == payload.price.bitPattern
            && PriceCanonicalizer.canonicalAmount(from: payload.price)?.value == witness.amountCanonical
            && payload.effectiveAt == witness.effectiveAt && row.effectiveAt == payload.effectiveAt
            && payload.source == witness.source && row.source == payload.source
            && payload.note == witness.note && row.note == payload.note
            && payload.createdAt == witness.createdAt && row.createdAt == payload.createdAt
            && row.updatedAt.flatMap(SupabaseRemoteDateParser.parse) != nil
    }
    /// Production price ACK changes only its linked ID, status and updatedAt.
    /// Every other original token field remains required for this exact intent.
    func acknowledgedPriceTokenMatches(_ current: LocalPendingChangeCASToken) -> Bool {
        guard let original = state.savedLocalPriceWitness?.originalToken,
              let id = state.savedPriceID else { return false }
        return current.statusRaw == LocalPendingChangeStatus.acknowledged.rawValue
            && current.entityRemoteIDRaw == id.uuidString.lowercased()
            && current.changeID == original.changeID && current.recordSchemaVersion == original.recordSchemaVersion
            && current.ownerUserID == original.ownerUserID && current.ownerHash == original.ownerHash
            && current.storeId == original.storeId && current.localStoreId == original.localStoreId
            && current.syncProtocolVersion == original.syncProtocolVersion && current.schemaVersion == original.schemaVersion
            && current.storeEpoch == original.storeEpoch && current.entityKindRaw == original.entityKindRaw
            && current.operationRaw == original.operationRaw && current.originRaw == original.originRaw
            && current.logicalKey == original.logicalKey && current.changedFieldsRaw == original.changedFieldsRaw
            && current.baselineFingerprintHash == original.baselineFingerprintHash
            && current.intendedFingerprintHash == original.intendedFingerprintHash
            && current.baseRemoteUpdatedAt == original.baseRemoteUpdatedAt && current.baseVersion == original.baseVersion
            && current.baseEventId == original.baseEventId && current.idempotencyKey == original.idempotencyKey
            && current.lastAttemptAt == original.lastAttemptAt && current.supersededByChangeID == original.supersededByChangeID
    }
    /// Read-only shape of the original durable journal. This does not create or
    /// update recovery state; the byte-exact file remains owned by production.
    private struct OriginalStagingJournal: Decodable {
        let replacement: AccountBinding
        let wipeCommitted: Bool
        let modeRaw: String
        let phaseRaw: String
        let deviceIdentityHash: String
        let generationID: UUID
        let checkpointDigest: String?
        let watermark: Int64?
        let baselineRunID: UUID?
    }
    /// The original price push runs before bootstrap retires this journal.
    /// Match only the saved staging context; absence is not a fallback admission.
    func matchesOriginalStagingRecoveryContext(
        scope: Task126VerifiedOwnerStoreScope, activeManifest: SyncStoreGenerationManifest?,
        binding: AccountBinding?, pendingReplacement: AccountBinding?,
        pendingWipeCommitted: Bool, journal: AccountRecoveryJournalSnapshot?, journalBytes: Data?
    ) -> Bool {
        guard reopening, state.processIDs.count == 2, state.terminalGeneration == nil,
              state.savedPriceID == nil, hasOriginalPriceWitness(),
              let witness = state.savedLocalPriceWitness, witness.matchesScope(scope),
              let sourceGeneration = state.originalGeneration,
              let savedJournalBytes = state.journalBytes, !savedJournalBytes.isEmpty,
              let original = try? JSONDecoder().decode(OriginalStagingJournal.self, from: savedJournalBytes),
              original.modeRaw == AccountRecoveryJournalMode.sameScopeRecovery.rawValue,
              original.phaseRaw == AccountRecoveryJournalPhase.staging.rawValue, !original.wipeCommitted,
              let journalBytes, journalBytes == savedJournalBytes,
              let activeManifest, activeManifest.generationID == sourceGeneration,
              activeManifest.accountHash == scope.accountHash, activeManifest.shopID == scope.shopID,
              activeManifest.deviceIdentityHash == scope.deviceIdentityHash,
              activeManifest.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
              let binding, binding.accountHash == scope.accountHash,
              binding.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
              let pendingReplacement, let capturedReplacement = scope.pendingReplacement,
              capturedReplacement == pendingReplacement,
              capturedReplacement.storeIdentity.hasSameProvenance(as: pendingReplacement.storeIdentity),
              let journal, journal.mode == .sameScopeRecovery, journal.phase == .staging,
              journal.replacement == original.replacement,
              journal.replacement.storeIdentity.hasSameProvenance(as: original.replacement.storeIdentity),
              journal.deviceIdentityHash == original.deviceIdentityHash,
              journal.generationID == original.generationID,
              journal.checkpointDigest == original.checkpointDigest,
              journal.watermark == original.watermark, journal.baselineRunID == original.baselineRunID,
              journal.deviceIdentityHash == scope.deviceIdentityHash,
              journal.replacement == pendingReplacement,
              journal.replacement.accountHash == scope.accountHash,
              journal.replacement.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
              pendingReplacement.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
              let targetGeneration = journal.generationID, targetGeneration != sourceGeneration,
              !pendingWipeCommitted else { return false }
        return true
    }
    private struct EventPage: Encodable {
        let schemaVersion = "shop-sync-event-page-v1"
        let shopId: UUID
        let scope: ShopSyncRecoveryScope
        let scopeEventMaxId: String
        let asOfEventMaxId: String
        let asOfDomainEventMaxIds: ShopSyncRecoveryDomainEventMaxIDs
        let pageLimit: Int
        let rows: [RemoteSyncEventRow]
        let nextAfterId: String?
        let hasMore: Bool
    }
    /// Read only the events already recorded by the ordinary controlled server.
    /// This never creates an event, admits an ACK, or repairs an event payload.
    func eventPage(_ parameters: ShopSyncEventPageParameters,
                   checkpoint: ShopSyncRecoveryCheckpoint) throws -> Data {
        guard hasOriginalPriceWitness(), let witness = state.savedLocalPriceWitness,
              parameters.shopID == state.product.shopID, parameters.shopID == checkpoint.shopId,
              parameters.deviceIdentifier == witness.deviceInstallID,
              checkpoint.scope.accountKey == witness.accountHash,
              checkpoint.scope.deviceKey == witness.deviceIdentityHash,
              parameters.expectedScopeKey == checkpoint.scope.key else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        let after = try ShopSyncRecoveryCanonical.eventID(parameters.afterID)
        let through = try ShopSyncRecoveryCanonical.eventID(parameters.expectedEventMaxID)
        let current = try ShopSyncRecoveryCanonical.eventID(checkpoint.syncEvents.maxId)
        guard parameters.limit == 150, after >= 41, after <= through, through <= current,
              through == 41 || state.events.contains(where: { $0.id == through }) else {
            throw ShopSyncRecoveryContractError.invalidCursor
        }
        // currentSnapshot uses its event max for all three T10 domain fences.
        // An earlier as-of must use that same construction, not the later max.
        let currentDomains = ShopSyncRecoveryDomainEventMaxIDs(catalog: String(current),
            prices: String(current), history: String(current))
        guard state.events.count <= 2, current == (state.events.last?.id ?? 41),
              checkpoint.syncEvents.domainMaxIds == currentDomains else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
        var previous: Int64 = 41
        for event in state.events {
            guard event.id > previous, event.id <= current else {
                throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
            }
            previous = event.id
        }
        let bounded = state.events.filter { $0.id > after && $0.id <= through }
        let rows = Array(bounded.prefix(parameters.limit))
        let hasMore = bounded.count > rows.count
        let next = hasMore ? rows.last?.id : nil
        try ShopSyncEventPageCursorContract.validate(rows: rows, afterID: after,
            asOfEventMaxID: through, nextAfterID: next, hasMore: hasMore)
        return try JSONEncoder().encode(EventPage(shopId: checkpoint.shopId, scope: checkpoint.scope,
            scopeEventMaxId: String(current), asOfEventMaxId: String(through),
            asOfDomainEventMaxIds: .init(catalog: String(through), prices: String(through), history: String(through)),
            pageLimit: parameters.limit, rows: rows, nextAfterId: next.map(String.init), hasMore: hasMore))
    }
    func noteIngress(_ kind: String) throws {
        switch kind {
        case "catalog": state.catalogIngressCount += 1
        case "price": state.priceIngressCount += 1
        case "event": state.eventIngressCount += 1
        default: throw SyncStoreGenerationError.activationReadBackFailed
        }
        // Count and persist entry before remote scope/payload validation.
        try persist()
    }
    func recordCatalog(id: UUID, payload: SyncAutomaticProductUpdatePayload,
                       scope: Task126VerifiedOwnerStoreScope) throws {
        guard reopening, state.processIDs.count == 2, state.catalogPayloads.isEmpty, state.catalogIngressCount == 1,
              id == state.product.id, scope.ownerUserID == state.product.ownerUserID,
              scope.shopID == state.product.shopID, payload.productName == Self.savedName,
              payload.purchasePrice == 37, payload.itemNumber == nil,
              state.savedTokens.contains(where: { $0.entityKindRaw == "product" }) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        state.catalogPayloads = [try JSONEncoder().encode(payload)]
        try persist()
    }
    func insertPrices(_ payloads: [SyncAutomaticProductPricePayload],
                      scope: Task126VerifiedOwnerStoreScope) throws -> [RemoteInventoryProductPriceRow] {
        guard reopening, state.processIDs.count == 2, state.pricePayloads.isEmpty, state.priceIngressCount == 1,
              state.savedPriceID == nil, hasOriginalPriceWitness(), let witness = state.savedLocalPriceWitness,
              let capturePrice, payloads.count == 1, let payload = payloads.first,
              witness.matchesScope(scope), witness.matchesPayload(payload), payload.price == 37,
              try capturePrice(payload, scope) == witness else { throw SyncStoreGenerationError.activationReadBackFailed }
        // Only an actual, fully joined automatic request supplies this ID.
        // The fixture never writes ProductPrice.remoteID or LocalPendingChange.
        state.savedPriceID = payload.id
        state.pricePayloads = [try JSONEncoder().encode(payloads)]
        let row = RemoteInventoryProductPriceRow(id: payload.id, ownerUserID: payload.ownerUserID,
            shopID: payload.shopID, productID: payload.productID, type: payload.type, price: payload.price,
            priceCanonical: witness.amountCanonical,
            effectiveAt: payload.effectiveAt, source: payload.source, note: payload.note,
            createdAt: payload.createdAt, updatedAt: "2026-10-23T20:25:00.123456Z")
        state.prices = [row]
        try persist()
        return [row]
    }
}
#endif
