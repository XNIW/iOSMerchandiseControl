import Foundation
import SwiftData
import CryptoKit

/// Durable evidence for a manual HTTP request. These entries share the existing
/// outbox but are local-only, and deliberately have a different shape/domain
/// from a single-revision catalog seal. No credential or complete URLRequest is
/// stored. Until the complete batch has its exact ACK, every member is protected.
nonisolated enum ManualPendingAtomicRequestStore {
    static let domain = "local_manual_atomic_request"
    static let format = "manual_atomic_request_v1"
    private static let limit = LocalPendingChangeAccumulator.defaultMaxActiveChanges
    private static let maximumBodyBytes = 8 * 1024 * 1024
    private static let maximumRecordBytes = 12 * 1024 * 1024

    enum Failure: Error, Equatable, Sendable { case invalidRecord, staleBatch, alreadyDispatched }
    enum Phase: String, Codable, Sendable { case prepared, inFlight, responseConfirmed }

    struct Provenance: Codable, Equatable, Sendable {
        let ownerUserID: UUID
        let accountHash: String
        let shopID: UUID
        let storeIdentity: LocalStoreIdentity
        let deviceInstallID: String
        let deviceIdentityHash: String
        let originLeaseGeneration: UInt64

        init(_ scope: Task126VerifiedOwnerStoreScope) {
            ownerUserID = scope.ownerUserID; accountHash = scope.accountHash; shopID = scope.shopID
            storeIdentity = scope.storeIdentity; deviceInstallID = scope.deviceInstallID
            deviceIdentityHash = scope.deviceIdentityHash; originLeaseGeneration = scope.leaseGeneration
        }
        func matches(_ scope: Task126VerifiedOwnerStoreScope) -> Bool {
            ownerUserID == scope.ownerUserID && accountHash == scope.accountHash && shopID == scope.shopID
                && storeIdentity.hasSameProvenance(as: scope.storeIdentity)
                && deviceInstallID == scope.deviceInstallID && deviceIdentityHash == scope.deviceIdentityHash
        }
    }

    /// Exact already-serialized request bytes and a nonsecret semantic contract.
    /// The original order of array elements is retained in body; no re-encoding
    /// is permitted at dispatch. response-confirmed alone is not a business ACK.
    struct Request: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let requestID: UUID
        let batchID: UUID
        let originGenerationID: UUID
        let provenance: Provenance
        let members: [LocalPendingChangeCASToken]
        let requestMemberIDs: [String]
        let method: String
        let origin: String
        let pathAndQuery: String
        let headers: [String: String]
        let body: Data
        let bodySHA256: String
        var changeIDs: Set<String> { Set(members.map(\.changeID)) }
    }

    struct Transfer: Codable, Equatable, Sendable {
        let sourceGenerationID: UUID
        let destinationGenerationID: UUID
        let previousMappingSHA256: String
    }
    struct Receipt: Codable, Equatable, Sendable {
        let request: Request
        let requestSHA256: String
        let currentGenerationID: UUID
        let transfers: [Transfer]
        var protectedChangeIDs: Set<String> { request.changeIDs }
    }
    struct Witness: Sendable, Equatable {
        let requestID: UUID
        let batchID: UUID
        let requestSHA256: String
        let currentGenerationID: UUID
    }

    /// Intrinsic validation only: safe to call while the normal mutation fence
    /// is already held. A malformed entry throws; callers must fail closed.
    static func records(context: ModelContext) throws -> [(SyncEventOutboxEntry, Receipt)] {
        let requestedDomain = domain
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate { $0.domain == requestedDomain })
        descriptor.fetchLimit = limit + 1
        let entries = try context.fetch(descriptor)
        guard entries.count <= limit, Set(entries.map(\.id)).count == entries.count else { throw Failure.invalidRecord }
        let result = try entries.map { ($0, try validate($0)) }
        for group in Dictionary(grouping: result, by: { $0.1.request.batchID }).values {
            guard let first = group.first?.1.request,
                  group.allSatisfy({ $0.1.request.members == first.members
                    && $0.1.request.provenance == first.provenance
                    && $0.1.request.originGenerationID == first.originGenerationID
                    && $0.1.currentGenerationID == group.first?.1.currentGenerationID }) else { throw Failure.invalidRecord }
        }
        return result
    }

    static func records(context: ModelContext, scope: Task126VerifiedOwnerStoreScope) throws -> [(SyncEventOutboxEntry, Receipt)] {
        let values = try records(context: context)
        guard values.allSatisfy({ $0.1.request.provenance.matches(scope) }) else { throw Failure.invalidRecord }
        return values
    }
    static func protectedChangeIDs(context: ModelContext) throws -> Set<String> {
        Set(try records(context: context).flatMap { $0.1.protectedChangeIDs })
    }
    static func blockingChangeIDs(context: ModelContext, scope: Task126VerifiedOwnerStoreScope) throws -> Set<String> {
        Set(try records(context: context, scope: scope).flatMap { $0.1.protectedChangeIDs })
    }

    /// Caller holds the common mutation fence for the captured scope/generation.
    /// Uses the final SDK-serialized body. Saves preparation before returning.
    static func prepareExact(request wire: URLRequest, requestID: UUID, batchID: UUID,
                             members: [LocalPendingChangeCASToken], requestMemberIDs: Set<String>,
                             scope: Task126VerifiedOwnerStoreScope, generationID: UUID,
                             context: ModelContext) throws -> Witness {
        guard let url = wire.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https", let host = components.host, components.user == nil,
              components.password == nil, components.fragment == nil, components.port == nil,
              let body = wire.httpBody, wire.httpBodyStream == nil,
              !body.isEmpty, body.count <= maximumBodyBytes,
              let method = wire.httpMethod, ["POST", "PATCH"].contains(method) else { throw Failure.invalidRecord }
        let path = components.percentEncodedPath
        let query = components.percentEncodedQuery.map { "?" + $0 } ?? ""
        let allowedHeaders: Set<String> = ["content-type", "prefer", "content-profile"]
        var headers: [String: String] = [:]
        for (name, value) in wire.allHTTPHeaderFields ?? [:] where allowedHeaders.contains(name.lowercased()) {
            headers[name.lowercased()] = value
        }
        let request = Request(schemaVersion: 1, requestID: requestID, batchID: batchID,
            originGenerationID: generationID, provenance: Provenance(scope),
            members: members.sorted { $0.changeID < $1.changeID }, requestMemberIDs: requestMemberIDs.sorted(),
            method: method, origin: "https://" + host, pathAndQuery: path + query,
            headers: headers, body: body, bodySHA256: digest(body))
        try validateRequest(request)
        let existing = try records(context: context, scope: scope)
        guard existing.allSatisfy({ $0.1.request.requestID != requestID
            && ($0.1.request.batchID == batchID || $0.1.protectedChangeIDs.isDisjoint(with: request.changeIDs)) }) else {
            throw Failure.staleBatch
        }
        for (_, value) in existing where value.request.batchID == batchID {
            guard value.request.members == request.members, value.currentGenerationID == generationID,
                  value.request.provenance == request.provenance,
                  Set(value.request.requestMemberIDs).isDisjoint(with: requestMemberIDs) else { throw Failure.staleBatch }
        }
        try requireExactMembers(request, context: context)
        let receipt = Receipt(request: request, requestSHA256: digest(try encode(request)),
                              currentGenerationID: generationID, transfers: [])
        let now = Date()
        let value = try makeEntry(receipt, phase: .prepared, now: now)
        context.insert(value)
        try context.save()
        let persisted = try find(requestID: requestID, context: ModelContext(context.container))
        guard persisted.1 == receipt, persisted.0.lastErrorKindRaw == Phase.prepared.rawValue else { throw Failure.invalidRecord }
        return witness(receipt)
    }

    /// A dispatch is permitted exactly once. Unknown replay stays protected and
    /// requires reconciliation; this helper never rebuilds a request from rows.
    static func beginDispatch(witness: Witness, context: ModelContext,
                              scope: Task126VerifiedOwnerStoreScope) throws {
        let (entry, receipt) = try matching(witness, context: context, scope: scope)
        guard entry.lastErrorKindRaw == Phase.prepared.rawValue, entry.attemptCount == 0 else { throw Failure.alreadyDispatched }
        try requireExactMembers(receipt.request, context: context)
        entry.lastErrorKindRaw = Phase.inFlight.rawValue; entry.attemptCount = 1
        entry.lastAttemptAt = Date(); entry.updatedAt = entry.lastAttemptAt!
        try context.save()
        let persisted = try matching(witness, context: ModelContext(context.container), scope: scope)
        guard persisted.0.attemptCount == 1, persisted.0.lastErrorKindRaw == Phase.inFlight.rawValue else { throw Failure.invalidRecord }
    }

    /// Invoke only after parsing and validating the complete response set.
    /// A response received after local/scope drift cannot be confirmed here.
    static func confirmResponse(witness: Witness, context: ModelContext,
                                scope: Task126VerifiedOwnerStoreScope) throws {
        let (entry, receipt) = try matching(witness, context: context, scope: scope)
        guard entry.lastErrorKindRaw == Phase.inFlight.rawValue, entry.attemptCount == 1 else { throw Failure.invalidRecord }
        try requireExactMembers(receipt.request, context: context)
        entry.lastErrorKindRaw = Phase.responseConfirmed.rawValue; entry.updatedAt = Date()
        try context.save()
    }

    /// NO save: caller removes evidence and applies the exact original ACK in
    /// one transaction. On failure the fresh context is discarded/rolled back.
    static func removeConfirmedBatch(batchID: UUID, members: [LocalPendingChangeCASToken],
                                     context: ModelContext, scope: Task126VerifiedOwnerStoreScope,
                                     verifiedReadOnlyChangeIDs: Set<String> = []) throws {
        let values = try records(context: context, scope: scope).filter { $0.1.request.batchID == batchID }
        guard !values.isEmpty else { throw Failure.invalidRecord }
        let expected = members.sorted { $0.changeID < $1.changeID }
        let covered = Set(values.flatMap { $0.1.request.requestMemberIDs })
        guard covered.isDisjoint(with: verifiedReadOnlyChangeIDs),
              covered.union(verifiedReadOnlyChangeIDs) == Set(expected.map(\.changeID)) else { throw Failure.staleBatch }
        for (entry, receipt) in values {
            guard receipt.request.members == expected, entry.lastErrorKindRaw == Phase.responseConfirmed.rawValue else { throw Failure.staleBatch }
            try requireExactMembers(receipt.request, context: context)
        }
        values.forEach { context.delete($0.0) }
    }

    /// NO insertion/save: the existing recovery transfer owns its transaction.
    /// Origin, tokens, raw body, request SHA and phase are kept unchanged.
    static func copyForTransfer(_ entry: SyncEventOutboxEntry, scope: Task126VerifiedOwnerStoreScope,
                                sourceGenerationID: UUID, destinationGenerationID: UUID) throws -> SyncEventOutboxEntry {
        let receipt = try validate(entry)
        guard receipt.request.provenance.matches(scope), receipt.currentGenerationID == sourceGenerationID,
              sourceGenerationID != destinationGenerationID,
              !receipt.transfers.contains(where: { $0.sourceGenerationID == destinationGenerationID
                || $0.destinationGenerationID == destinationGenerationID }) else { throw Failure.invalidRecord }
        let link = Transfer(sourceGenerationID: sourceGenerationID, destinationGenerationID: destinationGenerationID,
                            previousMappingSHA256: try mappingHash(receipt))
        let copy = Receipt(request: receipt.request, requestSHA256: receipt.requestSHA256,
                           currentGenerationID: destinationGenerationID, transfers: receipt.transfers + [link])
        guard let phase = Phase(rawValue: entry.lastErrorKindRaw) else { throw Failure.invalidRecord }
        let result = try makeEntry(copy, phase: phase, now: entry.createdAt)
        result.attemptCount = entry.attemptCount; result.lastAttemptAt = entry.lastAttemptAt
        result.updatedAt = entry.updatedAt
        _ = try validate(result)
        return result
    }

    private static func requireExactMembers(_ request: Request, context: ModelContext) throws {
        let ids = request.members.map(\.changeID)
        var descriptor = FetchDescriptor<LocalPendingChange>(predicate: #Predicate { ids.contains($0.changeID) })
        descriptor.fetchLimit = ids.count + 1
        let rows = try context.fetch(descriptor)
        let retired = try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: context)
        guard rows.count == ids.count, Set(rows.map(\.changeID)).count == rows.count,
              request.members.allSatisfy({ token in !retired.contains(token.changeID)
                && rows.contains(where: { token.matches($0) }) }) else { throw Failure.staleBatch }
    }
    private static func matching(_ value: Witness, context: ModelContext,
                                 scope: Task126VerifiedOwnerStoreScope) throws -> (SyncEventOutboxEntry, Receipt) {
        let result = try find(requestID: value.requestID, context: context)
        guard witness(result.1) == value, result.1.request.provenance.matches(scope) else { throw Failure.staleBatch }
        return result
    }
    private static func find(requestID: UUID, context: ModelContext) throws -> (SyncEventOutboxEntry, Receipt) {
        let values = try records(context: context).filter { $0.1.request.requestID == requestID }
        guard values.count == 1, let value = values.first else { throw Failure.invalidRecord }
        return value
    }
    private static func witness(_ receipt: Receipt) -> Witness {
        Witness(requestID: receipt.request.requestID, batchID: receipt.request.batchID,
                requestSHA256: receipt.requestSHA256, currentGenerationID: receipt.currentGenerationID)
    }
    private static func makeEntry(_ receipt: Receipt, phase: Phase, now: Date) throws -> SyncEventOutboxEntry {
        let data = try encode(receipt)
        guard data.count <= maximumRecordBytes else { throw Failure.invalidRecord }
        let request = receipt.request, p = request.provenance
        let entry = SyncEventOutboxEntry(id: request.requestID.uuidString.lowercased(),
            ownerUserID: p.ownerUserID.uuidString.lowercased(), storeId: p.storeIdentity.storeId,
            localStoreId: p.storeIdentity.localStoreId, syncProtocolVersion: p.storeIdentity.syncProtocolVersion,
            schemaVersion: p.storeIdentity.schemaVersion, storeEpoch: p.storeIdentity.storeEpoch,
            clientEventID: request.requestID.uuidString.lowercased(), batchID: request.batchID.uuidString.lowercased(),
            domain: domain, eventType: request.method, changedCount: request.members.count,
            entityIDsShape: digest(data), metadataShape: format,
            entityIDsPayloadJSON: String(decoding: try encode(request.members.map(\.changeID)), as: UTF8.self),
            metadataPayloadJSON: String(decoding: data, as: UTF8.self), status: .localOnly,
            attemptCount: phase == .prepared ? 0 : 1, maxAttempts: 1, nextRetryAt: now,
            lastErrorKind: .none, createdAt: now, updatedAt: now, sourceDeviceID: p.deviceInstallID)
        entry.lastErrorKindRaw = phase.rawValue
        return entry
    }
    private static func validate(_ entry: SyncEventOutboxEntry) throws -> Receipt {
        guard entry.domain == domain, entry.metadataShape == format, entry.statusRaw == SyncEventOutboxStatus.localOnly.rawValue,
              let text = entry.metadataPayloadJSON, let data = text.data(using: .utf8), data.count <= maximumRecordBytes,
              digest(data) == entry.entityIDsShape, let phase = Phase(rawValue: entry.lastErrorKindRaw),
              entry.attemptCount == (phase == .prepared ? 0 : 1), entry.maxAttempts == 1,
              (phase == .prepared ? entry.lastAttemptAt == nil : entry.lastAttemptAt != nil) else { throw Failure.invalidRecord }
        let receipt = try JSONDecoder().decode(Receipt.self, from: data)
        guard try encode(receipt) == data else { throw Failure.invalidRecord }
        try validateRequest(receipt.request)
        let request = receipt.request, p = request.provenance
        guard receipt.requestSHA256 == digest(try encode(request)), entry.id == request.requestID.uuidString.lowercased(),
              entry.clientEventID == entry.id, entry.batchID == request.batchID.uuidString.lowercased(),
              entry.ownerUserID == p.ownerUserID.uuidString.lowercased(), entry.storeId == p.storeIdentity.storeId,
              entry.localStoreId == p.storeIdentity.localStoreId, entry.syncProtocolVersion == p.storeIdentity.syncProtocolVersion,
              entry.schemaVersion == p.storeIdentity.schemaVersion, entry.storeEpoch == p.storeIdentity.storeEpoch,
              entry.sourceDeviceID == p.deviceInstallID, entry.eventType == request.method,
              entry.changedCount == request.members.count,
              entry.entityIDsPayloadJSON == String(decoding: try encode(request.members.map(\.changeID)), as: UTF8.self),
              entry.lastErrorCode == nil, entry.lastErrorMessageSanitized == nil, entry.sentAt == nil else { throw Failure.invalidRecord }
        var prior = Receipt(request: request, requestSHA256: receipt.requestSHA256,
                            currentGenerationID: request.originGenerationID, transfers: [])
        var visited: Set<UUID> = [request.originGenerationID]
        guard receipt.transfers.count <= limit else { throw Failure.invalidRecord }
        for link in receipt.transfers {
            guard link.sourceGenerationID == prior.currentGenerationID,
                  visited.insert(link.destinationGenerationID).inserted,
                  link.previousMappingSHA256 == (try mappingHash(prior)) else { throw Failure.invalidRecord }
            prior = Receipt(request: request, requestSHA256: receipt.requestSHA256,
                currentGenerationID: link.destinationGenerationID, transfers: prior.transfers + [link])
        }
        guard prior.currentGenerationID == receipt.currentGenerationID else { throw Failure.invalidRecord }
        return receipt
    }
    private static func validateRequest(_ request: Request) throws {
        let p = request.provenance, owner = p.ownerUserID.uuidString.lowercased()
        guard request.schemaVersion == 1, !request.members.isEmpty, request.members.count <= limit,
              request.members == request.members.sorted(by: { $0.changeID < $1.changeID }),
              request.changeIDs.count == request.members.count, !request.requestMemberIDs.isEmpty,
              request.requestMemberIDs == Array(Set(request.requestMemberIDs)).sorted(),
              Set(request.requestMemberIDs).isSubset(of: request.changeIDs),
              !p.deviceInstallID.isEmpty, p.deviceIdentityHash == DeviceInstallIDStore.identityHash(for: p.deviceInstallID),
              p.accountHash == AccountBindingStore.redactedAccountHash(for: owner),
              !p.storeIdentity.needsLegacyRepair, request.bodySHA256 == digest(request.body),
              !request.body.isEmpty, request.body.count <= maximumBodyBytes,
              ["POST", "PATCH"].contains(request.method),
              let url = URLComponents(string: request.origin + request.pathAndQuery),
              url.scheme == "https", url.host != nil, url.user == nil, url.password == nil, url.fragment == nil, url.port == nil,
              request.origin == "https://" + (url.host ?? ""),
              ["/rest/v1/inventory_suppliers", "/rest/v1/inventory_categories", "/rest/v1/inventory_products", "/rest/v1/inventory_product_prices"].contains(url.path),
              (url.queryItems ?? []).allSatisfy({ ["select", "columns", "id", "owner_user_id", "shop_id", "on_conflict"].contains($0.name) }),
              Set(request.headers.keys).isSubset(of: ["content-type", "prefer", "content-profile"]),
              request.headers.values.allSatisfy({ !$0.contains("\n") && !$0.contains("\r") }) else { throw Failure.invalidRecord }
        let object = try JSONSerialization.jsonObject(with: request.body)
        let bodyRows: [[String: Any]]
        if let array = object as? [[String: Any]] { bodyRows = array }
        else if let single = object as? [String: Any] { bodyRows = [single] }
        else { throw Failure.invalidRecord }
        let fields: Set<String>
        switch url.path {
        case "/rest/v1/inventory_suppliers", "/rest/v1/inventory_categories":
            fields = ["owner_user_id", "shop_id", "name"]
        case "/rest/v1/inventory_products":
            fields = ["owner_user_id", "shop_id", "barcode", "item_number", "product_name", "second_product_name",
                      "purchase_price", "retail_price", "supplier_id", "category_id", "stock_quantity", "deleted_at"]
        case "/rest/v1/inventory_product_prices":
            fields = ["id", "owner_user_id", "shop_id", "product_id", "type", "price", "effective_at", "source", "note", "created_at"]
        default: throw Failure.invalidRecord
        }
        guard !bodyRows.isEmpty, bodyRows.count <= limit,
              bodyRows.allSatisfy({ !$0.isEmpty && Set($0.keys).isSubset(of: fields) }) else { throw Failure.invalidRecord }
        if request.method == "POST" {
            guard object is [[String: Any]], bodyRows.allSatisfy({ row in
                (row["owner_user_id"] as? String).flatMap(UUID.init(uuidString:)) == p.ownerUserID
                    && (row["shop_id"] as? String).flatMap(UUID.init(uuidString:)) == p.shopID
            }) else { throw Failure.invalidRecord }
        } else {
            guard bodyRows.count == 1, object is [String: Any] else { throw Failure.invalidRecord }
            for (key, expected) in [("owner_user_id", p.ownerUserID), ("shop_id", p.shopID)] {
                let values = (url.queryItems ?? []).filter { $0.name == key }.compactMap(\.value)
                guard values.count == 1, let value = values.first, value.hasPrefix("eq."),
                      UUID(uuidString: String(value.dropFirst(3))) == expected else { throw Failure.invalidRecord }
            }
        }
        guard request.members.allSatisfy({ token in
            UUID(uuidString: token.changeID) != nil && !token.idempotencyKey.isEmpty
                && token.ownerUserID == owner && token.ownerHash == p.accountHash
                && token.storeId == p.storeIdentity.storeId && token.localStoreId == p.storeIdentity.localStoreId
                && token.syncProtocolVersion == p.storeIdentity.syncProtocolVersion && token.schemaVersion == p.storeIdentity.schemaVersion
                && token.storeEpoch == p.storeIdentity.storeEpoch && token.statusRaw == LocalPendingChangeStatus.sent.rawValue
                && token.lastAttemptAt != nil && !token.logicalKey.isEmpty
                && LocalPendingChangeEntityKind(rawValue: token.entityKindRaw) != nil
                && LocalPendingChangeOperation(rawValue: token.operationRaw) != nil
        }) else { throw Failure.invalidRecord }
    }
    private static func mappingHash(_ receipt: Receipt) throws -> String { digest(try encode(receipt)) }
    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}

nonisolated enum ManualPendingAtomicDispatchContext {
    @TaskLocal static var beforeDispatch: (@MainActor @Sendable (URLRequest) throws -> Void)?
}

/// One invocation owns the immutable batch and its exact wire preparations.
/// It is not a queue: after process death only the local-only receipts remain,
/// and all consumers must reconcile rather than reconstructing these writes.
@MainActor
final class ManualPendingAtomicBatchExecution {
    let batchID = UUID()
    private let snapshot: LocalPendingManualDispatchSnapshot
    private let container: ModelContainer
    private let owner: UUID
    private let defaults: UserDefaults
    private let generationID: UUID
    private var witnesses: [ManualPendingAtomicRequestStore.Witness] = []
    private(set) var verifiedPriceRows: [RemoteInventoryProductPriceRow] = []

    func captureVerifiedPriceRows(_ rows: [RemoteInventoryProductPriceRow]) throws {
        guard let scope = snapshot.scope, !rows.isEmpty, Set(rows.map(\.id)).count == rows.count,
              rows.allSatisfy({ $0.ownerUserID == owner && $0.shopID == scope.shopID
                && SupabaseRemoteDateParser.parse($0.updatedAt) != nil }) else { throw LocalPendingManualDispatchError.staleBatch }
        verifiedPriceRows = rows
    }

    init(snapshot: LocalPendingManualDispatchSnapshot, container: ModelContainer,
         ownerUserID: UUID, defaults: UserDefaults) throws {
        self.snapshot = snapshot; self.container = container; owner = ownerUserID; self.defaults = defaults
        generationID = try snapshot.withFence(modelContainer: container, ownerUserID: ownerUserID, defaults: defaults) { context in
            _ = try snapshot.exactRowsWithFenceHeld(context: context, ownerUserID: ownerUserID, defaults: defaults)
            guard let manifest = Task126OwnerStoreGate.activeManifestWithLeaseHeld(container),
                  try ManualPendingAtomicRequestStore.protectedChangeIDs(context: context)
                    .isDisjoint(with: Set(snapshot.tokens.map(\.changeID))) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            return manifest.generationID
        }
    }

    /// Executed by the provider on MainActor after normal SDK authentication,
    /// immediately before the same URLSession dispatches these exact bytes.
    func beforeDispatch(_ request: URLRequest) throws {
        try snapshot.withFence(modelContainer: container, ownerUserID: owner, defaults: defaults) { context in
            guard let scope = snapshot.scope,
                  Task126OwnerStoreGate.activeManifestWithLeaseHeld(container)?.generationID == generationID else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            let rows = try snapshot.exactRowsWithFenceHeld(context: context, ownerUserID: owner, defaults: defaults)
            try LocalPendingAggregatedPushStateStore.validatePriceParents(rows: rows, context: context, scope: scope)
            guard ["POST", "PATCH"].contains(request.httpMethod ?? "") else { return }
            let ids = try requestMembers(request, context: context)
            let witness = try ManualPendingAtomicRequestStore.prepareExact(request: request, requestID: UUID(),
                batchID: batchID, members: snapshot.tokens, requestMemberIDs: ids,
                scope: scope, generationID: generationID, context: context)
            try ManualPendingAtomicRequestStore.beginDispatch(witness: witness, context: context, scope: scope)
            witnesses.append(witness)
        }
    }

    /// A complete service read-back is required before this method is called.
    /// A crash during confirmation remains protected until the single ACK save.
    func confirmVerifiedResponses(requiresWrite: Bool, verifiedReadOnlyChangeIDs: Set<String> = []) throws {
        guard !requiresWrite || !witnesses.isEmpty else { throw LocalPendingManualDispatchError.staleBatch }
        try snapshot.withFence(modelContainer: container, ownerUserID: owner, defaults: defaults) { context in
            guard let scope = snapshot.scope,
                  Task126OwnerStoreGate.activeManifestWithLeaseHeld(container)?.generationID == generationID else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            _ = try snapshot.exactRowsWithFenceHeld(context: context, ownerUserID: owner, defaults: defaults,
                                                   requiresOriginalSet: false)
            let records = try ManualPendingAtomicRequestStore.records(context: context, scope: scope)
                .filter { $0.1.request.batchID == batchID }
            let covered = Set(records.flatMap { $0.1.request.requestMemberIDs })
            guard covered.isDisjoint(with: verifiedReadOnlyChangeIDs),
                  covered.union(verifiedReadOnlyChangeIDs) == Set(snapshot.tokens.map(\.changeID)) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            for witness in witnesses {
                try ManualPendingAtomicRequestStore.confirmResponse(witness: witness, context: context, scope: scope)
            }
        }
    }

    private func requestMembers(_ wire: URLRequest, context: ModelContext) throws -> Set<String> {
        guard let url = wire.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let data = wire.httpBody else { throw LocalPendingManualDispatchError.staleBatch }
        let table = url.lastPathComponent
        let kind: LocalPendingChangeEntityKind
        switch table {
        case "inventory_suppliers": kind = .supplier
        case "inventory_categories": kind = .productCategory
        case "inventory_products": kind = .product
        case "inventory_product_prices": kind = .productPrice
        default: throw LocalPendingManualDispatchError.staleBatch
        }
        let object = try JSONSerialization.jsonObject(with: data)
        let rows: [[String: Any]]
        if let array = object as? [[String: Any]] { rows = array }
        else if let single = object as? [String: Any] { rows = [single] }
        else { throw LocalPendingManualDispatchError.staleBatch }
        guard !rows.isEmpty else { throw LocalPendingManualDispatchError.staleBatch }
        // Manual price wire dates are canonical seconds; pending keys retain
        // the original local microseconds. Never reconstruct a pending key by
        // parsing a lossy wire timestamp. Match only the exact original rows
        // under this fence, while leaving the request bytes unchanged.
        if kind == .productPrice, wire.httpMethod == "POST" {
            return try priceRequestMembers(rows, context: context)
        }
        var keys: [String] = []
        if wire.httpMethod == "PATCH" {
            guard rows.count == 1,
                  let raw = components.queryItems?.first(where: { $0.name == "id" })?.value,
                  raw.hasPrefix("eq."), let id = UUID(uuidString: String(raw.dropFirst(3))) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            keys = [LocalPendingChangeLogicalKey.remoteEntity(kind: kind, remoteID: id)]
        } else {
            for row in rows {
                switch kind {
                case .supplier:
                    guard let name = row["name"] as? String else { throw LocalPendingManualDispatchError.staleBatch }
                    keys.append(LocalPendingChangeLogicalKey.supplier(remoteID: nil, name: name))
                case .productCategory:
                    guard let name = row["name"] as? String else { throw LocalPendingManualDispatchError.staleBatch }
                    keys.append(LocalPendingChangeLogicalKey.category(remoteID: nil, name: name))
                case .product:
                    guard let barcode = row["barcode"] as? String else { throw LocalPendingManualDispatchError.staleBatch }
                    keys.append(LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: barcode))
                default: throw LocalPendingManualDispatchError.staleBatch
                }
            }
        }
        let tokens = snapshot.tokens.filter { $0.entityKindRaw == kind.rawValue && keys.contains($0.logicalKey) }
        guard Set(keys).count == keys.count, tokens.count == keys.count,
              Set(tokens.map(\.logicalKey)) == Set(keys) else { throw LocalPendingManualDispatchError.staleBatch }
        return Set(tokens.map(\.changeID))
    }

    private func priceRequestMembers(_ bodyRows: [[String: Any]], context: ModelContext) throws -> Set<String> {
        let tokens = snapshot.tokens.filter { $0.entityKindRaw == LocalPendingChangeEntityKind.productPrice.rawValue }
        var descriptor = FetchDescriptor<ProductPrice>(predicate: #Predicate { $0.remoteID == nil })
        descriptor.fetchLimit = LocalPendingAggregatedPushPlanner.defaultHardCap + 1
        let prices = try context.fetch(descriptor)
        guard prices.count <= LocalPendingAggregatedPushPlanner.defaultHardCap else {
            throw LocalPendingManualDispatchError.staleBatch
        }
        var members = Set<String>()
        for body in bodyRows {
            guard let product = body["product_id"] as? String, let productID = UUID(uuidString: product),
                  let rawType = body["type"] as? String,
                  let type = ["PURCHASE": PriceType.purchase, "RETAIL": PriceType.retail][rawType],
                  let effectiveAt = body["effective_at"] as? String,
                  let amount = body["price"] as? Double,
                  let canonicalAmount = PriceCanonicalizer.canonicalAmount(from: amount),
                  amount == canonicalAmount.doubleValue,
                  let createdAt = body["created_at"] as? String else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            var matches: [(ProductPrice, LocalPendingChangeCASToken)] = []
            for price in prices {
                guard let parent = price.product, parent.remoteID == productID, price.type == type,
                      ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt) == effectiveAt else { continue }
                let originalKeys = Set([parent.remoteID, nil].map {
                    LocalPendingChangeLogicalKey.productPrice(productRemoteID: $0, productBarcode: parent.barcode,
                        type: price.type, effectiveAt: price.effectiveAt)
                })
                for token in tokens where originalKeys.contains(token.logicalKey) {
                    matches.append((price, token))
                }
            }
            // Do not use amount to disambiguate two local revisions that
            // collapse to the same remote logical key at canonical seconds.
            guard matches.count == 1, let (price, token) = matches.first,
                  PriceCanonicalizer.canonicalAmount(from: price.price) == canonicalAmount,
                  ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.createdAt) == createdAt,
                  (body["source"] as? String) == SupabasePullPreviewNormalizer.semanticString(price.source),
                  (body["note"] as? String) == SupabasePullPreviewNormalizer.semanticString(price.note),
                  members.insert(token.changeID).inserted else {
                throw LocalPendingManualDispatchError.staleBatch
            }
        }
        return members
    }
}
