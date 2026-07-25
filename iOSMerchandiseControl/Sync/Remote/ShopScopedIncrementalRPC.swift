import Foundation
import Supabase

/// `UserDefaults` is thread-safe but is not annotated Sendable by Foundation.
/// The client only uses it for durable, redacted recovery-fence reads; the box
/// keeps that SDK annotation from leaking into the RPC value type.
private nonisolated final class ShopScopedIncrementalDefaultsBox: @unchecked Sendable {
    let value: UserDefaults

    init(_ value: UserDefaults) {
        self.value = value
    }
}

nonisolated protocol ShopScopedIncrementalRPCAuthorizing: Sendable {
    var usesServerAuthorizedShopScope: Bool { get }
}

nonisolated struct ShopSyncEventPageParameters: Encodable, Sendable {
    let shopID: UUID
    let deviceIdentifier: String
    let afterID: String
    let limit: Int
    let expectedScopeKey: String
    let expectedEventMaxID: String

    enum CodingKeys: String, CodingKey {
        case shopID = "p_shop_id"
        case deviceIdentifier = "p_device_identifier"
        case afterID = "p_after_id"
        case limit = "p_limit"
        case expectedScopeKey = "p_expected_scope_key"
        case expectedEventMaxID = "p_expected_event_max_id"
    }
}

nonisolated struct ShopSyncRowsByIDsParameters: Encodable, Sendable {
    let shopID: UUID
    let deviceIdentifier: String
    let domain: String
    let entityIDs: [String]
    let expectedScopeKey: String
    let expectedEventMaxID: String
    let expectedDomainEventMaxID: String

    enum CodingKeys: String, CodingKey {
        case shopID = "p_shop_id"
        case deviceIdentifier = "p_device_identifier"
        case domain = "p_domain"
        case entityIDs = "p_entity_ids"
        case expectedScopeKey = "p_expected_scope_key"
        case expectedEventMaxID = "p_expected_event_max_id"
        case expectedDomainEventMaxID = "p_expected_domain_event_max_id"
    }
}

nonisolated struct ShopSyncEventPageEnvelope: Decodable, Sendable {
    let schemaVersion: String
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

/// Pure V6 cursor/fence validation shared by the RPC client and focused
/// regressions.  The server already promises this relationship, but a client
/// must not apply an event or continuation cursor outside the frozen as-of
/// fence when a proxy, schema drift or malformed response violates it.
nonisolated enum ShopSyncEventPageCursorContract {
    static func validate(
        rows: [RemoteSyncEventRow],
        afterID: Int64,
        asOfEventMaxID: Int64,
        nextAfterID: Int64?,
        hasMore: Bool
    ) throws {
        guard afterID >= 0, afterID <= asOfEventMaxID else {
            throw ShopSyncRecoveryContractError.invalidCursor
        }
        var previousID = afterID
        for event in rows {
            guard event.id > previousID, event.id <= asOfEventMaxID else {
                throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
            }
            previousID = event.id
        }
        if hasMore {
            guard let nextAfterID,
                  nextAfterID == rows.last?.id,
                  nextAfterID <= asOfEventMaxID else {
                throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
            }
        } else if nextAfterID != nil {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
    }
}

nonisolated struct ShopSyncRowsByIDsEnvelope<Row: ShopSyncAuthorizedRow>: Decodable, Sendable {
    let schemaVersion: String
    let shopId: UUID
    let scope: ShopSyncRecoveryScope
    let domain: ShopSyncRecoveryDomain
    let asOfEventMaxId: String
    let currentScopeEventMaxId: String
    let minimumDomainEventMaxId: String
    let materializedDomainEventMaxId: String
    let domainScope: String
    let requestedCount: Int
    let rows: [Row]
    let missingIds: [UUID]
}

/// Durable, redacted binding between an authoritative recovery generation and
/// the opaque server scope key required by V6 incremental reads.  It is not a
/// sync state machine: it only prevents a nonzero local watermark from being
/// reused without the exact account/shop/device scope that produced it.
nonisolated struct ShopSyncRecoveryFenceStore {
    private struct Record: Codable, Equatable {
        static let schema = "shop-sync-recovery-fence-v1"

        let schema: String
        let scopeKey: String
        let accountKey: String
        let deviceKey: String
        let watermark: String
        let checksum: String
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func scopeKey(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String,
        watermark: Int64
    ) -> String? {
        guard watermark > 0,
              let record = validatedRecord(
                accountHash: accountHash,
                storeIdentity: storeIdentity,
                deviceIdentityHash: deviceIdentityHash
              ),
              record.watermark == String(watermark) else {
            return nil
        }
        return record.scopeKey
    }

    @discardableResult
    func saveAuthoritative(
        scope: ShopSyncRecoveryScope,
        watermark: Int64,
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String
    ) -> Bool {
        guard watermark >= 0,
              scope.accountKey == accountHash,
              scope.deviceKey == deviceIdentityHash,
              ShopSyncRecoveryCanonical.isRedactedKey(scope.key),
              ShopSyncRecoveryCanonical.isRedactedKey(scope.accountKey),
              ShopSyncRecoveryCanonical.isRedactedKey(scope.deviceKey) else {
            return false
        }
        let record = Record(
            schema: Record.schema,
            scopeKey: scope.key,
            accountKey: scope.accountKey,
            deviceKey: scope.deviceKey,
            watermark: String(watermark),
            checksum: checksum(
                scopeKey: scope.key,
                accountHash: accountHash,
                storeIdentity: storeIdentity,
                deviceIdentityHash: deviceIdentityHash,
                watermark: String(watermark)
            )
        )
        guard let data = try? JSONEncoder().encode(record), data.count <= 2_048 else {
            return false
        }
        defaults.set(data, forKey: key(accountHash: accountHash, storeIdentity: storeIdentity))
        return validatedRecord(
            accountHash: accountHash,
            storeIdentity: storeIdentity,
            deviceIdentityHash: deviceIdentityHash
        ) == record
    }

    private func validatedRecord(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String
    ) -> Record? {
        guard let data = defaults.data(forKey: key(accountHash: accountHash, storeIdentity: storeIdentity)),
              data.count <= 2_048,
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.schema == Record.schema,
              record.accountKey == accountHash,
              record.deviceKey == deviceIdentityHash,
              ShopSyncRecoveryCanonical.isRedactedKey(record.scopeKey),
              (try? ShopSyncRecoveryCanonical.eventID(record.watermark)) != nil,
              record.checksum == checksum(
                scopeKey: record.scopeKey,
                accountHash: accountHash,
                storeIdentity: storeIdentity,
                deviceIdentityHash: deviceIdentityHash,
                watermark: record.watermark
              ) else {
            return nil
        }
        return record
    }

    private func key(accountHash: String, storeIdentity: LocalStoreIdentity) -> String {
        "sync.recovery.fence.account.\(accountHash).store.\(storeIdentity.rawValue)"
    }

    private func checksum(
        scopeKey: String,
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String,
        watermark: String
    ) -> String {
        ShopSyncRecoveryCanonical.sha256([
            Record.schema,
            scopeKey,
            accountHash,
            storeIdentity.rawValue,
            deviceIdentityHash,
            watermark
        ].joined(separator: "|"))
    }
}

private actor ShopSyncIncrementalFenceCache {
    struct Fence: Sendable {
        let scope: ShopSyncRecoveryScope
        let eventMaxID: String
        let domainMaxIDs: ShopSyncRecoveryDomainEventMaxIDs
        let baselineWatermark: Int64
    }

    private var values: [String: Fence] = [:]

    func value(for key: String, baselineWatermark: Int64) -> Fence? {
        guard let value = values[key], value.baselineWatermark == baselineWatermark else {
            values.removeValue(forKey: key)
            return nil
        }
        return value
    }

    func save(_ value: Fence, for key: String) {
        values[key] = value
    }
}

nonisolated struct ShopScopedIncrementalRPCClient: Sendable {
    private static let maximumEventPageResponseBytes = 4 * 1_024 * 1_024
    private static let maximumRowsByIDResponseBytes = 4 * 1_024 * 1_024
    let remote: SupabaseTransportClient
    private let defaultsBox: ShopScopedIncrementalDefaultsBox
    private let fenceCache: ShopSyncIncrementalFenceCache

    init(
        remote: SupabaseTransportClient,
        defaults: UserDefaults = .standard
    ) {
        self.remote = remote
        self.defaultsBox = ShopScopedIncrementalDefaultsBox(defaults)
        self.fenceCache = ShopSyncIncrementalFenceCache()
    }

    func events(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        afterID: Int64,
        limit: Int
    ) async throws -> [RemoteSyncEventRow] {
        try validateLocal(ownerUserID: ownerUserID, scope: scope)
        guard afterID >= 0 else {
            throw ShopSyncRecoveryContractError.invalidCursor
        }
        let fence = try await fence(
            ownerUserID: ownerUserID,
            scope: scope,
            afterID: afterID
        )
        let effectiveLimit = max(1, min(limit, 150))
        let data = try await execute(
            "shop_sync_event_page_v1",
            parameters: ShopSyncEventPageParameters(
                shopID: scope.shopID,
                deviceIdentifier: scope.deviceInstallID,
                afterID: String(afterID),
                limit: effectiveLimit,
                expectedScopeKey: fence.scope.key,
                expectedEventMaxID: fence.eventMaxID
            ),
            ownerUserID: ownerUserID,
            scope: scope
        )
        guard data.count <= Self.maximumEventPageResponseBytes else {
            throw ShopSyncRecoveryContractError.totalResourceBudgetExceeded
        }
        let envelope = try JSONDecoder().decode(ShopSyncEventPageEnvelope.self, from: data)
        try envelope.scope.validate(
            expectedShopID: scope.shopID,
            expectedDeviceIdentifier: scope.deviceInstallID,
            expectedOwnerUserID: ownerUserID
        )
        let scopeMaxID = try ShopSyncRecoveryCanonical.eventID(envelope.scopeEventMaxId)
        let asOfEventMaxID = try ShopSyncRecoveryCanonical.eventID(envelope.asOfEventMaxId)
        let nextAfterID = try envelope.nextAfterId.map(ShopSyncRecoveryCanonical.eventID)
        guard envelope.schemaVersion == "shop-sync-event-page-v1",
              envelope.shopId == scope.shopID,
              envelope.scope == fence.scope,
              envelope.asOfEventMaxId == fence.eventMaxID,
              envelope.asOfDomainEventMaxIds == fence.domainMaxIDs,
              scopeMaxID >= asOfEventMaxID,
              envelope.pageLimit == effectiveLimit,
              envelope.rows.count <= effectiveLimit,
              envelope.hasMore == (envelope.nextAfterId != nil) else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
        try ShopSyncEventPageCursorContract.validate(
            rows: envelope.rows,
            afterID: afterID,
            asOfEventMaxID: asOfEventMaxID,
            nextAfterID: nextAfterID,
            hasMore: envelope.hasMore
        )
        for event in envelope.rows {
            try validateEvent(event, shopID: scope.shopID, recoveryScope: envelope.scope)
        }
        return envelope.rows
    }

    func advanceDurableFence(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        from watermark: Int64,
        through newWatermark: Int64
    ) async throws {
        guard watermark >= 0, newWatermark > watermark else {
            throw ShopSyncRecoveryContractError.invalidCursor
        }
        try validateLocal(ownerUserID: ownerUserID, scope: scope)
        let cacheKey = [
            scope.accountHash,
            scope.storeIdentity.rawValue,
            scope.deviceIdentityHash
        ].joined(separator: "|")
        guard let captured = await fenceCache.value(
            for: cacheKey,
            baselineWatermark: watermark
        ) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        // The actor await above is an identity boundary even though it is
        // local-only.  Never write a fence for a stale account/shop/device
        // lease, and bind the cached opaque scope back to that exact lease.
        try validateLocal(ownerUserID: ownerUserID, scope: scope)
        try captured.scope.validate(
            expectedShopID: scope.shopID,
            expectedDeviceIdentifier: scope.deviceInstallID,
            expectedOwnerUserID: ownerUserID
        )
        guard ShopSyncRecoveryFenceStore(defaults: defaultsBox.value).saveAuthoritative(
            scope: captured.scope,
            watermark: newWatermark,
            accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash
        ) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        await fenceCache.save(
            ShopSyncIncrementalFenceCache.Fence(
                scope: captured.scope,
                eventMaxID: captured.eventMaxID,
                domainMaxIDs: captured.domainMaxIDs,
                baselineWatermark: newWatermark
            ),
            for: cacheKey
        )
    }

    func rows<Row: ShopSyncAuthorizedRow>(
        _ rowType: Row.Type,
        domain: ShopSyncRecoveryDomain,
        ids: Set<UUID>,
        id: KeyPath<Row, UUID>,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) async throws -> [Row] {
        guard !ids.isEmpty else { return [] }
        guard ids.count <= ShopSyncRecoveryLimits.maximumTargetedRows(for: domain) else {
            throw ShopSyncRecoveryContractError.pageBudgetExceeded(domain: domain)
        }
        try validateLocal(ownerUserID: ownerUserID, scope: scope)
        let fence = try await fence(ownerUserID: ownerUserID, scope: scope)
        let orderedIDs = ids.map { $0.uuidString.lowercased() }.sorted()
        let data = try await execute(
            "shop_sync_rows_by_ids_v1",
            parameters: ShopSyncRowsByIDsParameters(
                shopID: scope.shopID,
                deviceIdentifier: scope.deviceInstallID,
                domain: domain.rawValue,
                entityIDs: orderedIDs,
                expectedScopeKey: fence.scope.key,
                expectedEventMaxID: fence.eventMaxID,
                expectedDomainEventMaxID: shopSyncDomainMaxID(
                    fence.domainMaxIDs,
                    domain: domain
                )
            ),
            ownerUserID: ownerUserID,
            scope: scope
        )
        guard data.count <= Self.maximumRowsByIDResponseBytes else {
            throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
        }
        let envelope = try JSONDecoder().decode(
            ShopSyncRowsByIDsEnvelope<Row>.self,
            from: data
        )
        try envelope.scope.validate(
            expectedShopID: scope.shopID,
            expectedDeviceIdentifier: scope.deviceInstallID,
            expectedOwnerUserID: ownerUserID
        )
        let currentScopeMaxID = try ShopSyncRecoveryCanonical.eventID(envelope.currentScopeEventMaxId)
        let materializedDomainMaxID = try ShopSyncRecoveryCanonical.eventID(
            envelope.materializedDomainEventMaxId
        )
        let expectedEventMaxID = try ShopSyncRecoveryCanonical.eventID(fence.eventMaxID)
        let expectedDomainFence = shopSyncDomainMaxID(fence.domainMaxIDs, domain: domain)
        let expectedDomainMaxID = try ShopSyncRecoveryCanonical.eventID(expectedDomainFence)
        let returnedIDs = envelope.rows.map { $0[keyPath: id] }
        let returnedSet = Set(returnedIDs)
        let missingSet = Set(envelope.missingIds)
        guard envelope.schemaVersion == "shop-sync-rows-by-ids-v1",
              envelope.shopId == scope.shopID,
              envelope.scope == fence.scope,
              envelope.domain == domain,
              envelope.asOfEventMaxId == fence.eventMaxID,
              envelope.minimumDomainEventMaxId == expectedDomainFence,
              currentScopeMaxID >= expectedEventMaxID,
              materializedDomainMaxID >= expectedDomainMaxID,
              envelope.domainScope == (domain == .history
                  ? fence.scope.historyKind
                  : fence.scope.kind),
              envelope.requestedCount == ids.count,
              returnedIDs.count == returnedSet.count,
              returnedSet.isSubset(of: ids),
              missingSet.isSubset(of: ids),
              returnedSet.isDisjoint(with: missingSet),
              returnedSet.union(missingSet) == ids else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: domain)
        }
        for row in envelope.rows {
            try ShopSyncRecoveryRowContract.validateScope(
                ownerUserID: row.authorizedOwnerUserID,
                shopID: row.authorizedShopID,
                domain: domain,
                selectedShopID: scope.shopID,
                recoveryScope: envelope.scope
            )
        }
        return envelope.rows
    }

    private func fence(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        afterID: Int64? = nil
    ) async throws -> ShopSyncIncrementalFenceCache.Fence {
        let watermarkScope = WatermarkStore.Scope(
            ownerUserID: ownerUserID,
            storeIdentity: scope.storeIdentity
        )
        let baselineWatermark = WatermarkStore(defaults: defaultsBox.value)
            .watermark(for: watermarkScope)
        let cacheKey = [
            scope.accountHash,
            scope.storeIdentity.rawValue,
            scope.deviceIdentityHash
        ].joined(separator: "|")
        if let cached = await fenceCache.value(
            for: cacheKey,
            baselineWatermark: baselineWatermark
        ) {
            if let afterID {
                let maximum = try ShopSyncRecoveryCanonical.eventID(cached.eventMaxID)
                if afterID < maximum {
                    return cached
                }
            } else {
                return cached
            }
        }
        let expectedScopeKey: String?
        if baselineWatermark == 0 {
            expectedScopeKey = nil
        } else {
            expectedScopeKey = ShopSyncRecoveryFenceStore(defaults: defaultsBox.value).scopeKey(
                accountHash: scope.accountHash,
                storeIdentity: scope.storeIdentity,
                deviceIdentityHash: scope.deviceIdentityHash,
                watermark: baselineWatermark
            )
            guard expectedScopeKey != nil else {
                throw ShopSyncRecoveryContractError.scopeFenceMissing
            }
        }
        let checkpoint = try await ShopSyncRecoveryRemoteAdapter(
            transport: SupabaseShopSyncRecoveryRPCTransport(remote: remote),
            defaults: defaultsBox.value
        ).checkpoint(
            ownerUserID: ownerUserID,
            scope: scope,
            verifiedBaselineID: String(baselineWatermark),
            expectedBaselineScopeKey: expectedScopeKey
        )
        guard checkpoint.syncEvents.requiresFullRecovery == false else {
            throw ShopSyncRecoveryContractError.fullRecoveryRequired
        }
        let captured = ShopSyncIncrementalFenceCache.Fence(
            scope: checkpoint.scope,
            eventMaxID: checkpoint.syncEvents.maxId,
            domainMaxIDs: checkpoint.syncEvents.domainMaxIds,
            baselineWatermark: baselineWatermark
        )
        await fenceCache.save(captured, for: cacheKey)
        return captured
    }

    private func execute<Parameters: Encodable & Sendable>(
        _ function: String,
        parameters: Parameters,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) async throws -> Data {
        guard try await remote.authenticatedUserID() == ownerUserID else {
            throw ShopSyncRecoveryContractError.authenticationChanged
        }
        let data: Data
        do {
            data = try await remote.boundedRPC(
                function,
                parameters: parameters,
                maximumResponseBytes: ShopSyncRecoveryLimits.maximumPageResponseBytes
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DecodingError {
            throw await remote.mapDecodingError(error)
        } catch let error as PostgrestError {
            throw await remote.mapPostgrestError(error)
        } catch let error as URLError {
            throw await remote.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
        guard try await remote.authenticatedUserID() == ownerUserID else {
            throw ShopSyncRecoveryContractError.authenticationChanged
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaultsBox.value)
        return data
    }

    private func validateLocal(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        guard scope.ownerUserID == ownerUserID else {
            throw ShopSyncRecoveryContractError.authenticationChanged
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaultsBox.value)
    }

    private func validateEvent(
        _ event: RemoteSyncEventRow,
        shopID: UUID,
        recoveryScope: ShopSyncRecoveryScope
    ) throws {
        guard event.sourceDeviceID == nil,
              event.clientEventID == nil,
              event.sourceDeviceKey.map(Self.isRedactedKey) ?? true,
              event.clientEventKey.map(Self.isRedactedKey) ?? true else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
        let domainScope = event.domain == "history"
            ? recoveryScope.historyKind
            : recoveryScope.kind
        let isAuthorizedLegacyEvent = event.shopID == nil
            && recoveryScope.legacyOwnerKey
                == ShopSyncRecoveryCanonical.sha256(event.ownerUserID.uuidString.lowercased())
        switch domainScope {
        case "shop_scoped":
            guard event.shopID == shopID else {
                throw ShopSyncRecoveryContractError.rowOutsideScope(domain: .products)
            }
        case "legacy_owner_bridge":
            guard isAuthorizedLegacyEvent else {
                throw ShopSyncRecoveryContractError.rowOutsideScope(domain: .products)
            }
        case "authorized_shop_plus_legacy":
            guard event.shopID == shopID || isAuthorizedLegacyEvent else {
                throw ShopSyncRecoveryContractError.rowOutsideScope(domain: .products)
            }
        default:
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
    }

    private nonisolated static func isRedactedKey(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

private nonisolated func shopSyncDomainMaxID(
    _ maximums: ShopSyncRecoveryDomainEventMaxIDs,
    domain: ShopSyncRecoveryDomain
) -> String {
    switch domain {
    case .suppliers, .categories, .products, .images:
        return maximums.catalog
    case .prices:
        return maximums.prices
    case .history:
        return maximums.history
    }
}

nonisolated func validateIncrementalReadIdentity(
    ownerUserID: UUID,
    shopID: UUID?,
    scope: Task126VerifiedOwnerStoreScope,
    remote: Any
) throws {
    if let authorized = remote as? any ShopScopedIncrementalRPCAuthorizing,
       authorized.usesServerAuthorizedShopScope {
        // Exact scope, RLS and legacy-owner mapping were already checked by the
        // security-definer RPC envelope and revalidated after the await.
        guard shopID == scope.shopID || shopID == nil else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        return
    }
    try Task126OwnerStoreGate.validateRemoteIdentity(
        ownerUserID: ownerUserID,
        shopID: shopID,
        scope: scope
    )
}
