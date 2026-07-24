import CryptoKit
import Foundation
import Supabase

private nonisolated final class ShopSyncRecoveryDefaultsBox: @unchecked Sendable {
    let value: UserDefaults

    init(_ value: UserDefaults) {
        self.value = value
    }
}

nonisolated enum ShopSyncRecoveryDomain: String, Codable, CaseIterable, Sendable {
    case suppliers
    case categories
    case products
    case prices
    case history
    case images
}

/// Hard resource ceilings for a single recovery generation. A checkpoint is
/// rejected before any staging store is created when it exceeds these bounds;
/// the ledger enforces independent byte limits while it is written and read.
/// These are safety ceilings, not pagination targets.
nonisolated enum ShopSyncRecoveryLimits {
    // These ceilings intentionally fit a mobile recovery process. Exceeding
    // them is a durable, fail-closed recovery error; it must never fall back
    // to applying a partial snapshot in the active store.
    static let maximumTotalRows = 350_000
    static let maximumLedgerRecordBytes = 4 * 1_024
    static let maximumLedgerBytesPerDomain = 48 * 1_024 * 1_024
    static let maximumLedgerBytesTotal = 128 * 1_024 * 1_024
    static let maximumCheckpointResponseBytes = 512 * 1_024
    // V6 limits every recovery and targeted response to the same bounded
    // PostgREST envelope.  History is intentionally not granted a larger
    // exception: a single oversized history page must request recovery again,
    // not force an active generation to materialize partial data.
    static let maximumPageResponseBytes = 4 * 1_024 * 1_024
    static let maximumHistoryPageResponseBytes = maximumPageResponseBytes
    static let maximumResponseBytesPerDomain = 192 * 1_024 * 1_024
    static let maximumResponseBytesTotal = 384 * 1_024 * 1_024
    static let maximumHistoryDataBytes = 512 * 1_024
    static let maximumHistoryRowPayloadBytes = 512 * 1_024
    static let maximumGenerationDirectoryBytes = 768 * 1_024 * 1_024
    static let maximumRetainedGenerationBytes = 2 * maximumGenerationDirectoryBytes
    static let minimumAvailableCapacityForRecovery = 128 * 1_024 * 1_024
    static let maximumGenerationManifestBytes = 512 * 1_024
    static let verificationBatchSize = 256

    static func maximumPageRows(for domain: ShopSyncRecoveryDomain) -> Int {
        switch domain {
        case .suppliers, .categories:
            return 240
        case .products:
            return 60
        case .prices:
            return 120
        case .history:
            return 3
        case .images:
            return 240
        }
    }

    static func maximumTargetedRows(for domain: ShopSyncRecoveryDomain) -> Int {
        switch domain {
        case .suppliers, .categories, .products:
            return 60
        case .prices:
            return 120
        case .history:
            return 3
        case .images:
            return 240
        }
    }

    static func maximumRows(for domain: ShopSyncRecoveryDomain) -> Int {
        switch domain {
        case .suppliers, .categories:
            return 25_000
        case .history:
            return 10_000
        case .products, .images:
            return 100_000
        case .prices:
            return 150_000
        }
    }

    static func total(
        _ digest: ShopSyncRecoveryEntityDigest,
        domain: ShopSyncRecoveryDomain
    ) throws -> Int {
        let (total, overflow) = digest.activeCount.addingReportingOverflow(
            digest.tombstoneCount
        )
        guard !overflow,
              digest.activeCount >= 0,
              digest.tombstoneCount >= 0,
              total <= maximumRows(for: domain) else {
            throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
        }
        return total
    }
}

nonisolated struct ShopSyncRecoveryScope: Codable, Equatable, Sendable {
    let kind: String
    let historyKind: String
    let key: String
    let legacyOwnerKey: String?
    let accountKey: String
    let deviceKey: String

    var isSupported: Bool {
        Self.isSupportedCatalogKind(kind) && Self.isSupportedHistoryKind(historyKind)
    }

    init(
        kind: String,
        historyKind: String = "shop_scoped",
        key: String,
        legacyOwnerKey: String?,
        accountKey: String,
        deviceKey: String
    ) {
        self.kind = kind
        self.historyKind = historyKind
        self.key = key
        self.legacyOwnerKey = legacyOwnerKey
        self.accountKey = accountKey
        self.deviceKey = deviceKey
    }

    func validate(
        expectedShopID: UUID,
        expectedDeviceIdentifier: String,
        expectedOwnerUserID: UUID? = nil
    ) throws {
        _ = expectedShopID // Bound by the enclosing RPC envelope; scope.key is opaque.
        let expectedDeviceKey = ShopSyncRecoveryCanonical.sha256(
            expectedDeviceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard isSupported,
              Self.isRedactedKey(key),
              Self.isRedactedKey(accountKey),
              Self.isRedactedKey(deviceKey),
              deviceKey == expectedDeviceKey,
              legacyOwnerKey.map(Self.isRedactedKey) ?? true else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
        // The key is server-issued and intentionally opaque.  Its input
        // includes policy branches that the client must not reconstruct.  It
        // is still bound to the authenticated identity and device before any
        // page request is accepted.
        if let expectedOwnerUserID {
            guard accountKey == ShopSyncRecoveryCanonical.sha256(
                expectedOwnerUserID.uuidString.lowercased()
            ) else {
                throw ShopSyncRecoveryContractError.authenticationChanged
            }
        }
        let needsLegacyOwner = kind != "shop_scoped"
            || historyKind == "authorized_shop_plus_legacy"
        guard needsLegacyOwner == (legacyOwnerKey != nil) else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
    }

    private static func isSupportedCatalogKind(_ value: String) -> Bool {
        value == "shop_scoped"
            || value == "legacy_owner_bridge"
            || value == "authorized_shop_plus_legacy"
    }

    private static func isSupportedHistoryKind(_ value: String) -> Bool {
        value == "shop_scoped" || value == "authorized_shop_plus_legacy"
    }

    private static func isRedactedKey(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

nonisolated struct ShopSyncRecoveryEntityDigest: Codable, Equatable, Sendable {
    let activeCount: Int
    let tombstoneCount: Int
    let idSetDigest: String
    let versionDigest: String
    let identityDigest: String?

    init(
        activeCount: Int,
        tombstoneCount: Int,
        idSetDigest: String,
        versionDigest: String,
        identityDigest: String? = nil
    ) {
        self.activeCount = activeCount
        self.tombstoneCount = tombstoneCount
        self.idSetDigest = idSetDigest
        self.versionDigest = versionDigest
        self.identityDigest = identityDigest
    }
}

nonisolated struct ShopSyncRecoveryCatalogDigest: Codable, Equatable, Sendable {
    let suppliers: ShopSyncRecoveryEntityDigest
    let categories: ShopSyncRecoveryEntityDigest
    let products: ShopSyncRecoveryEntityDigest
    let digest: String
}

nonisolated struct ShopSyncRecoveryIntegrity: Codable, Equatable, Sendable {
    let productCategoryViolationCount: Int
    let productSupplierViolationCount: Int
    let priceProductViolationCount: Int
    let primaryImageViolationCount: Int
    let historyIdViolationCount: Int
    let totalViolationCount: Int
}

nonisolated struct ShopSyncRecoveryEventCheckpoint: Codable, Equatable, Sendable {
    let maxId: String
    let verifiedBaselineId: String
    let requiresFullRecovery: Bool
    let domainMaxIds: ShopSyncRecoveryDomainEventMaxIDs

    init(
        maxId: String,
        verifiedBaselineId: String = "0",
        requiresFullRecovery: Bool = true,
        domainMaxIds: ShopSyncRecoveryDomainEventMaxIDs = .zero
    ) {
        self.maxId = maxId
        self.verifiedBaselineId = verifiedBaselineId
        self.requiresFullRecovery = requiresFullRecovery
        self.domainMaxIds = domainMaxIds
    }

    var parsedMaxID: Int64? {
        try? ShopSyncRecoveryCanonical.eventID(maxId)
    }

    func domainMaxID(for domain: ShopSyncRecoveryDomain) -> String {
        switch domain {
        case .suppliers, .categories, .products, .images:
            return domainMaxIds.catalog
        case .prices:
            return domainMaxIds.prices
        case .history:
            return domainMaxIds.history
        }
    }

    func validate() throws {
        let maxID = try ShopSyncRecoveryCanonical.eventID(maxId)
        let baselineID = try ShopSyncRecoveryCanonical.eventID(verifiedBaselineId)
        guard baselineID <= maxID,
              try ShopSyncRecoveryCanonical.eventID(domainMaxIds.catalog) <= maxID,
              try ShopSyncRecoveryCanonical.eventID(domainMaxIds.prices) <= maxID,
              try ShopSyncRecoveryCanonical.eventID(domainMaxIds.history) <= maxID else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
    }
}

nonisolated struct ShopSyncRecoveryDomainEventMaxIDs: Codable, Equatable, Sendable {
    static let zero = ShopSyncRecoveryDomainEventMaxIDs(
        catalog: "0",
        prices: "0",
        history: "0"
    )

    let catalog: String
    let prices: String
    let history: String
}

nonisolated struct ShopSyncRecoveryCheckpoint: Codable, Equatable, Sendable {
    let schemaVersion: String
    let status: String
    let shopId: UUID
    let scope: ShopSyncRecoveryScope
    let syncEvents: ShopSyncRecoveryEventCheckpoint
    let catalog: ShopSyncRecoveryCatalogDigest
    let prices: ShopSyncRecoveryEntityDigest
    let history: ShopSyncRecoveryEntityDigest
    let images: ShopSyncRecoveryEntityDigest
    let integrity: ShopSyncRecoveryIntegrity
    let checkpointDigest: String

    init(
        schemaVersion: String,
        status: String = "ready",
        shopId: UUID,
        scope: ShopSyncRecoveryScope,
        syncEvents: ShopSyncRecoveryEventCheckpoint,
        catalog: ShopSyncRecoveryCatalogDigest,
        prices: ShopSyncRecoveryEntityDigest,
        history: ShopSyncRecoveryEntityDigest,
        images: ShopSyncRecoveryEntityDigest,
        integrity: ShopSyncRecoveryIntegrity,
        checkpointDigest: String
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.shopId = shopId
        self.scope = scope
        self.syncEvents = syncEvents
        self.catalog = catalog
        self.prices = prices
        self.history = history
        self.images = images
        self.integrity = integrity
        self.checkpointDigest = checkpointDigest
    }

    var maxEventID: Int64? {
        syncEvents.parsedMaxID
    }

    func validate(
        expectedShopID: UUID,
        expectedDeviceIdentifier: String,
        expectedOwnerUserID: UUID? = nil
    ) throws {
        guard schemaVersion == "shop-sync-recovery-checkpoint-v1",
              status == "ready",
              shopId == expectedShopID,
              let maxEventID,
              maxEventID >= 0,
              String(maxEventID) == syncEvents.maxId,
              integrity.totalViolationCount == 0,
              integrity.productCategoryViolationCount == 0,
              integrity.productSupplierViolationCount == 0,
              integrity.priceProductViolationCount == 0,
              integrity.primaryImageViolationCount == 0,
              integrity.historyIdViolationCount == 0,
              Self.isDigest(checkpointDigest),
              Self.isDigest(catalog.digest),
              Self.isDigest(scope.deviceKey),
              Self.isDigest(scope.key),
              scope.legacyOwnerKey.map(Self.isDigest) ?? true else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
        try scope.validate(
            expectedShopID: expectedShopID,
            expectedDeviceIdentifier: expectedDeviceIdentifier,
            expectedOwnerUserID: expectedOwnerUserID
        )
        try syncEvents.validate()

        let domainDigests: [(ShopSyncRecoveryDomain, ShopSyncRecoveryEntityDigest)] = [
            (.suppliers, catalog.suppliers),
            (.categories, catalog.categories),
            (.products, catalog.products),
            (.prices, prices),
            (.history, history),
            (.images, images)
        ]
        var totalRows = 0
        for (domain, digest) in domainDigests {
            guard digest.activeCount >= 0,
                  digest.tombstoneCount >= 0,
                  Self.isDigest(digest.idSetDigest),
                  Self.isDigest(digest.versionDigest),
                  digest.identityDigest.map(Self.isDigest) ?? true else {
                throw ShopSyncRecoveryContractError.invalidCheckpoint
            }
            let domainRows = try ShopSyncRecoveryLimits.total(digest, domain: domain)
            let (newTotal, overflow) = totalRows.addingReportingOverflow(domainRows)
            guard !overflow, newTotal <= ShopSyncRecoveryLimits.maximumTotalRows else {
                throw ShopSyncRecoveryContractError.totalResourceBudgetExceeded
            }
            totalRows = newTotal
        }
        guard catalog.products.identityDigest != nil else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
    }

    static func isDigest(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

nonisolated struct ShopSyncRecoveryLocalVerificationReceipt: Codable, Equatable, Sendable {
    let suppliers: ShopSyncRecoveryEntityDigest
    let categories: ShopSyncRecoveryEntityDigest
    let products: ShopSyncRecoveryEntityDigest
    let prices: ShopSyncRecoveryEntityDigest
    let history: ShopSyncRecoveryEntityDigest
    let images: ShopSyncRecoveryEntityDigest
    let catalogDigest: String
    let relationshipViolationCount: Int
    let pendingLocalCount: Int
    let outboxCount: Int

    func matches(_ checkpoint: ShopSyncRecoveryCheckpoint) -> Bool {
        suppliers == checkpoint.catalog.suppliers
            && categories == checkpoint.catalog.categories
            && products == checkpoint.catalog.products
            && prices == checkpoint.prices
            && history == checkpoint.history
            && images == checkpoint.images
            && catalogDigest == checkpoint.catalog.digest
            && relationshipViolationCount == 0
            && pendingLocalCount == 0
            && outboxCount == 0
    }
}

nonisolated struct ShopSyncRecoveryPage<Row: Decodable & Sendable>: Decodable, Sendable {
    let schemaVersion: String
    let shopId: UUID
    let scope: ShopSyncRecoveryScope
    let domain: ShopSyncRecoveryDomain
    let snapshotEventMaxId: String
    let currentScopeEventMaxId: String
    let baselineDomainEventMaxId: String
    let pageDomainEventMaxId: String
    let domainScope: String
    let pageLimit: Int
    let rows: [Row]
    let nextAfterId: String?
    let hasMore: Bool
}

nonisolated struct ShopSyncRecoveryImageVariant: Codable, Equatable, Sendable {
    let sha256: String?
    let bytes: Int?
    let width: Int?
    let height: Int?
    let mime: String?
}

nonisolated struct ShopSyncRecoveryImageRow: Codable, Equatable, Sendable {
    let productID: UUID
    let ownerUserID: UUID
    let shopID: UUID?
    let productDeletedAt: String?
    let versionID: UUID
    let status: String
    let finalizedAt: String?
    let main: ShopSyncRecoveryImageVariant
    let thumb: ShopSyncRecoveryImageVariant

    enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case productDeletedAt = "product_deleted_at"
        case versionID = "version_id"
        case status
        case finalizedAt = "finalized_at"
        case main
        case thumb
    }
}

nonisolated protocol ShopSyncAuthorizedRow: Decodable, Sendable {
    nonisolated var authorizedOwnerUserID: UUID { get }
    nonisolated var authorizedShopID: UUID? { get }
}

extension RemoteInventorySupplierRow: ShopSyncAuthorizedRow {
    nonisolated var authorizedOwnerUserID: UUID { ownerUserID }
    nonisolated var authorizedShopID: UUID? { shopID }
}

extension RemoteInventoryCategoryRow: ShopSyncAuthorizedRow {
    nonisolated var authorizedOwnerUserID: UUID { ownerUserID }
    nonisolated var authorizedShopID: UUID? { shopID }
}

extension RemoteInventoryProductRow: ShopSyncAuthorizedRow {
    nonisolated var authorizedOwnerUserID: UUID { ownerUserID }
    nonisolated var authorizedShopID: UUID? { shopID }
}

extension RemoteInventoryProductPriceRow: ShopSyncAuthorizedRow {
    nonisolated var authorizedOwnerUserID: UUID { ownerUserID }
    nonisolated var authorizedShopID: UUID? { shopID }
}

extension RemoteSharedSheetSessionRow: ShopSyncAuthorizedRow {
    nonisolated var authorizedOwnerUserID: UUID { ownerUserID }
    nonisolated var authorizedShopID: UUID? { shopID }
}

extension ShopSyncRecoveryImageRow: ShopSyncAuthorizedRow {
    nonisolated var authorizedOwnerUserID: UUID { ownerUserID }
    nonisolated var authorizedShopID: UUID? { shopID }
}

nonisolated struct ShopSyncRecoveryCheckpointParameters: Encodable, Sendable {
    let shopID: UUID
    let deviceIdentifier: String
    let verifiedBaselineID: String
    let expectedBaselineScopeKey: String?

    init(
        shopID: UUID,
        deviceIdentifier: String,
        verifiedBaselineID: String = "0",
        expectedBaselineScopeKey: String? = nil
    ) {
        self.shopID = shopID
        self.deviceIdentifier = deviceIdentifier
        self.verifiedBaselineID = verifiedBaselineID
        self.expectedBaselineScopeKey = expectedBaselineScopeKey
    }

    enum CodingKeys: String, CodingKey {
        case shopID = "p_shop_id"
        case deviceIdentifier = "p_device_identifier"
        case verifiedBaselineID = "p_verified_baseline_id"
        case expectedBaselineScopeKey = "p_expected_baseline_scope_key"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shopID, forKey: .shopID)
        try container.encode(deviceIdentifier, forKey: .deviceIdentifier)
        try container.encode(verifiedBaselineID, forKey: .verifiedBaselineID)
        if let expectedBaselineScopeKey {
            try container.encode(expectedBaselineScopeKey, forKey: .expectedBaselineScopeKey)
        } else {
            try container.encodeNil(forKey: .expectedBaselineScopeKey)
        }
    }
}

nonisolated struct ShopSyncRecoveryPageParameters: Encodable, Sendable {
    let shopID: UUID
    let deviceIdentifier: String
    let domain: String
    let afterID: String?
    let limit: Int
    let expectedScopeKey: String
    let expectedEventMaxID: String
    let expectedDomainEventMaxID: String

    enum CodingKeys: String, CodingKey {
        case shopID = "p_shop_id"
        case deviceIdentifier = "p_device_identifier"
        case domain = "p_domain"
        case afterID = "p_after_id"
        case limit = "p_limit"
        case expectedScopeKey = "p_expected_scope_key"
        case expectedEventMaxID = "p_expected_event_max_id"
        case expectedDomainEventMaxID = "p_expected_domain_event_max_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shopID, forKey: .shopID)
        try container.encode(deviceIdentifier, forKey: .deviceIdentifier)
        try container.encode(domain, forKey: .domain)
        if let afterID {
            try container.encode(afterID, forKey: .afterID)
        } else {
            try container.encodeNil(forKey: .afterID)
        }
        try container.encode(limit, forKey: .limit)
        try container.encode(expectedScopeKey, forKey: .expectedScopeKey)
        try container.encode(expectedEventMaxID, forKey: .expectedEventMaxID)
        try container.encode(expectedDomainEventMaxID, forKey: .expectedDomainEventMaxID)
    }
}

nonisolated struct ShopSyncConvergenceMarkerParameters: Encodable, Sendable {
    let shopID: UUID
    let deviceIdentifier: String
    let verifiedBaselineID: String
    let expectedBaselineScopeKey: String

    enum CodingKeys: String, CodingKey {
        case shopID = "p_shop_id"
        case deviceIdentifier = "p_device_identifier"
        case verifiedBaselineID = "p_verified_baseline_id"
        case expectedBaselineScopeKey = "p_expected_baseline_scope_key"
    }
}

nonisolated struct ShopSyncRecoveryMarkerIntegrity: Codable, Equatable, Sendable {
    let totalViolationCount: Int
}

nonisolated struct ShopSyncRecoveryConvergenceMarker: Codable, Equatable, Sendable {
    let schemaVersion: String
    let status: String
    let shopId: UUID
    let scope: ShopSyncRecoveryScope
    let syncEvents: ShopSyncRecoveryEventCheckpoint
    let catalog: ShopSyncRecoveryCatalogDigest
    let prices: ShopSyncRecoveryEntityDigest
    let history: ShopSyncRecoveryEntityDigest
    let images: ShopSyncRecoveryEntityDigest
    let integrity: ShopSyncRecoveryMarkerIntegrity
    let checkpointDigest: String
    let serverNoWorkEligible: Bool
    let markerDigest: String

    func validates(
        localVerification: ShopSyncRecoveryLocalVerificationReceipt,
        expectedShopID: UUID,
        expectedDeviceIdentifier: String,
        expectedOwnerUserID: UUID,
        expectedScope: ShopSyncRecoveryScope,
        expectedBaselineID: String
    ) throws {
        guard schemaVersion == "shop-sync-convergence-marker-v1",
              status == "ready",
              shopId == expectedShopID,
              scope == expectedScope,
              serverNoWorkEligible,
              integrity.totalViolationCount == 0,
              ShopSyncRecoveryCheckpoint.isDigest(checkpointDigest),
              ShopSyncRecoveryCheckpoint.isDigest(markerDigest),
              syncEvents.maxId == expectedBaselineID,
              syncEvents.verifiedBaselineId == expectedBaselineID,
              syncEvents.requiresFullRecovery == false,
              localVerification.suppliers == catalog.suppliers,
              localVerification.categories == catalog.categories,
              localVerification.products == catalog.products,
              localVerification.prices == prices,
              localVerification.history == history,
              localVerification.images == images,
              localVerification.catalogDigest == catalog.digest,
              localVerification.relationshipViolationCount == 0,
              localVerification.pendingLocalCount == 0,
              localVerification.outboxCount == 0 else {
            throw ShopSyncRecoveryContractError.markerNotVerified
        }
        try syncEvents.validate()
        try scope.validate(
            expectedShopID: expectedShopID,
            expectedDeviceIdentifier: expectedDeviceIdentifier,
            expectedOwnerUserID: expectedOwnerUserID
        )
    }
}

protocol ShopSyncRecoveryRPCTransporting: Sendable {
    func authenticatedUserID() async throws -> UUID
    func checkpoint(_ parameters: ShopSyncRecoveryCheckpointParameters) async throws -> Data
    func page(_ parameters: ShopSyncRecoveryPageParameters) async throws -> Data
    func marker(_ parameters: ShopSyncConvergenceMarkerParameters) async throws -> Data
    func eventPage(_ parameters: ShopSyncEventPageParameters) async throws -> Data
}

extension ShopSyncRecoveryRPCTransporting {
    func marker(_ parameters: ShopSyncConvergenceMarkerParameters) async throws -> Data {
        throw ShopSyncRecoveryContractError.markerNotVerified
    }

    func eventPage(_ parameters: ShopSyncEventPageParameters) async throws -> Data {
        throw ShopSyncRecoveryContractError.fullRecoveryRequired
    }
}

struct SupabaseShopSyncRecoveryRPCTransport: ShopSyncRecoveryRPCTransporting {
    let remote: SupabaseTransportClient

    func authenticatedUserID() async throws -> UUID {
        try await remote.authenticatedUserID()
    }

    func checkpoint(_ parameters: ShopSyncRecoveryCheckpointParameters) async throws -> Data {
        try await execute(
            "shop_sync_recovery_checkpoint_v1",
            parameters: parameters,
            maximumResponseBytes: ShopSyncRecoveryLimits.maximumCheckpointResponseBytes
        )
    }

    func page(_ parameters: ShopSyncRecoveryPageParameters) async throws -> Data {
        try await execute(
            "shop_sync_recovery_page_v1",
            parameters: parameters,
            maximumResponseBytes: ShopSyncRecoveryLimits.maximumPageResponseBytes
        )
    }

    func marker(_ parameters: ShopSyncConvergenceMarkerParameters) async throws -> Data {
        try await execute(
            "shop_sync_convergence_marker_v1",
            parameters: parameters,
            maximumResponseBytes: ShopSyncRecoveryLimits.maximumCheckpointResponseBytes
        )
    }

    func eventPage(_ parameters: ShopSyncEventPageParameters) async throws -> Data {
        try await execute(
            "shop_sync_event_page_v1",
            parameters: parameters,
            maximumResponseBytes: ShopSyncRecoveryLimits.maximumPageResponseBytes
        )
    }

    private func execute<Parameters: Encodable & Sendable>(
        _ function: String,
        parameters: Parameters,
        maximumResponseBytes: Int
    ) async throws -> Data {
        do {
            return try await remote.boundedRPC(
                function,
                parameters: parameters,
                maximumResponseBytes: maximumResponseBytes
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
    }
}

actor ShopSyncRecoveryRemoteAdapter {
    private let transport: any ShopSyncRecoveryRPCTransporting
    private let defaultsBox: ShopSyncRecoveryDefaultsBox
    private let decoder = JSONDecoder()
    private var responseBytesByDomain: [ShopSyncRecoveryDomain: Int] = [:]
    private var totalResponseBytes = 0

    init(
        transport: any ShopSyncRecoveryRPCTransporting,
        defaults: UserDefaults = .standard
    ) {
        self.transport = transport
        self.defaultsBox = ShopSyncRecoveryDefaultsBox(defaults)
    }

    func resetResourceBudget() {
        responseBytesByDomain.removeAll(keepingCapacity: true)
        totalResponseBytes = 0
    }

    func checkpoint(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        verifiedBaselineID: String = "0",
        expectedBaselineScopeKey: String? = nil
    ) async throws -> ShopSyncRecoveryCheckpoint {
        let parsedBaseline = try ShopSyncRecoveryCanonical.eventID(verifiedBaselineID)
        guard (parsedBaseline == 0 && expectedBaselineScopeKey == nil)
            || (parsedBaseline > 0 && expectedBaselineScopeKey.map(ShopSyncRecoveryCanonical.isRedactedKey) == true) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        try validateLocalScope(ownerUserID: ownerUserID, scope: scope)
        let authenticated = try await transport.authenticatedUserID()
        guard authenticated == ownerUserID else {
            throw ShopSyncRecoveryContractError.authenticationChanged
        }
        let data = try await transport.checkpoint(
            ShopSyncRecoveryCheckpointParameters(
                shopID: scope.shopID,
                deviceIdentifier: scope.deviceInstallID,
                verifiedBaselineID: verifiedBaselineID,
                expectedBaselineScopeKey: expectedBaselineScopeKey
            )
        )
        guard data.count <= ShopSyncRecoveryLimits.maximumCheckpointResponseBytes else {
            throw ShopSyncRecoveryContractError.totalResourceBudgetExceeded
        }
        try recordResponseBytes(data.count, domain: nil)
        guard try await transport.authenticatedUserID() == ownerUserID else {
            throw ShopSyncRecoveryContractError.authenticationChanged
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(
            scope,
            defaults: defaultsBox.value
        )
        let checkpoint = try decoder.decode(ShopSyncRecoveryCheckpoint.self, from: data)
        try checkpoint.validate(
            expectedShopID: scope.shopID,
            expectedDeviceIdentifier: scope.deviceInstallID,
            expectedOwnerUserID: ownerUserID
        )
        guard checkpoint.syncEvents.verifiedBaselineId == verifiedBaselineID else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
        return checkpoint
    }

    func page<Row: Decodable & Sendable>(
        _ rowType: Row.Type,
        domain: ShopSyncRecoveryDomain,
        afterID: String?,
        limit: Int,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        checkpoint: ShopSyncRecoveryCheckpoint
    ) async throws -> ShopSyncRecoveryPage<Row> {
        try validateLocalScope(ownerUserID: ownerUserID, scope: scope)
        let clampedLimit = max(
            1,
            min(limit, ShopSyncRecoveryLimits.maximumPageRows(for: domain))
        )
        let authenticated = try await transport.authenticatedUserID()
        guard authenticated == ownerUserID else {
            throw ShopSyncRecoveryContractError.authenticationChanged
        }
        let data = try await transport.page(
            ShopSyncRecoveryPageParameters(
                shopID: scope.shopID,
                deviceIdentifier: scope.deviceInstallID,
                domain: domain.rawValue,
                afterID: afterID,
                limit: clampedLimit,
                expectedScopeKey: checkpoint.scope.key,
                expectedEventMaxID: checkpoint.syncEvents.maxId,
                expectedDomainEventMaxID: checkpoint.syncEvents.domainMaxID(for: domain)
            )
        )
        let maximumPageBytes = domain == .history
            ? ShopSyncRecoveryLimits.maximumHistoryPageResponseBytes
            : ShopSyncRecoveryLimits.maximumPageResponseBytes
        guard data.count <= maximumPageBytes else {
            throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
        }
        try recordResponseBytes(data.count, domain: domain)
        guard try await transport.authenticatedUserID() == ownerUserID else {
            throw ShopSyncRecoveryContractError.authenticationChanged
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(
            scope,
            defaults: defaultsBox.value
        )
        let page = try decoder.decode(ShopSyncRecoveryPage<Row>.self, from: data)
        let baselineDomainMaxID = checkpoint.syncEvents.domainMaxID(for: domain)
        let pageDomainMaxID = try ShopSyncRecoveryCanonical.eventID(page.pageDomainEventMaxId)
        let expectedDomainMaxID = try ShopSyncRecoveryCanonical.eventID(baselineDomainMaxID)
        guard page.schemaVersion == "shop-sync-recovery-page-v1",
              page.shopId == scope.shopID,
              page.scope == checkpoint.scope,
              page.domain == domain,
              page.snapshotEventMaxId == checkpoint.syncEvents.maxId,
              page.baselineDomainEventMaxId == baselineDomainMaxID,
              pageDomainMaxID >= expectedDomainMaxID,
              page.domainScope == (domain == .history
                  ? checkpoint.scope.historyKind
                  : checkpoint.scope.kind),
              page.pageLimit == clampedLimit,
              page.rows.count <= page.pageLimit,
              page.hasMore == (page.nextAfterId != nil),
              page.nextAfterId == nil || UUID(uuidString: page.nextAfterId!) != nil else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: domain)
        }
        return page
    }

    func marker(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        baselineCheckpoint: ShopSyncRecoveryCheckpoint,
        localVerification: ShopSyncRecoveryLocalVerificationReceipt
    ) async throws -> ShopSyncRecoveryConvergenceMarker {
        guard let baselineID = baselineCheckpoint.maxEventID else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
        try validateLocalScope(ownerUserID: ownerUserID, scope: scope)
        guard try await transport.authenticatedUserID() == ownerUserID else {
            throw ShopSyncRecoveryContractError.authenticationChanged
        }
        let data = try await transport.marker(
            ShopSyncConvergenceMarkerParameters(
                shopID: scope.shopID,
                deviceIdentifier: scope.deviceInstallID,
                verifiedBaselineID: String(baselineID),
                expectedBaselineScopeKey: baselineCheckpoint.scope.key
            )
        )
        guard data.count <= ShopSyncRecoveryLimits.maximumCheckpointResponseBytes else {
            throw ShopSyncRecoveryContractError.totalResourceBudgetExceeded
        }
        try recordResponseBytes(data.count, domain: nil)
        guard try await transport.authenticatedUserID() == ownerUserID else {
            throw ShopSyncRecoveryContractError.authenticationChanged
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaultsBox.value)
        let marker = try decoder.decode(ShopSyncRecoveryConvergenceMarker.self, from: data)
        try marker.validates(
            localVerification: localVerification,
            expectedShopID: scope.shopID,
            expectedDeviceIdentifier: scope.deviceInstallID,
            expectedOwnerUserID: ownerUserID,
            expectedScope: baselineCheckpoint.scope,
            expectedBaselineID: String(baselineID)
        )
        return marker
    }

    /// Reads the bounded event tail between A and B.  A full snapshot already
    /// materializes the row state; this tail proves that no malformed or
    /// legacy event was silently crossed while the live keyset pages were
    /// being staged.  It never advances a cursor or mutates the active store.
    func verifyTail(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        from checkpointA: ShopSyncRecoveryCheckpoint,
        through checkpointB: ShopSyncRecoveryCheckpoint
    ) async throws {
        guard checkpointA.shopId == checkpointB.shopId,
              checkpointA.scope == checkpointB.scope,
              let fromID = checkpointA.maxEventID,
              let throughID = checkpointB.maxEventID,
              throughID >= fromID else {
            throw ShopSyncRecoveryContractError.checkpointChanged
        }
        guard throughID > fromID else { return }
        var cursor = fromID
        var pages = 0
        while true {
            pages += 1
            guard pages <= 512 else {
                throw ShopSyncRecoveryContractError.pageBudgetExceeded(domain: .products)
            }
            try validateLocalScope(ownerUserID: ownerUserID, scope: scope)
            guard try await transport.authenticatedUserID() == ownerUserID else {
                throw ShopSyncRecoveryContractError.authenticationChanged
            }
            let data = try await transport.eventPage(
                ShopSyncEventPageParameters(
                    shopID: scope.shopID,
                    deviceIdentifier: scope.deviceInstallID,
                    afterID: String(cursor),
                    limit: 150,
                    expectedScopeKey: checkpointB.scope.key,
                    expectedEventMaxID: String(throughID)
                )
            )
            guard data.count <= ShopSyncRecoveryLimits.maximumPageResponseBytes else {
                throw ShopSyncRecoveryContractError.totalResourceBudgetExceeded
            }
            try recordResponseBytes(data.count, domain: nil)
            guard try await transport.authenticatedUserID() == ownerUserID else {
                throw ShopSyncRecoveryContractError.authenticationChanged
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaultsBox.value)
            let page = try decoder.decode(ShopSyncEventPageEnvelope.self, from: data)
            let scopeMaxID = try ShopSyncRecoveryCanonical.eventID(page.scopeEventMaxId)
            let asOfID = try ShopSyncRecoveryCanonical.eventID(page.asOfEventMaxId)
            guard page.schemaVersion == "shop-sync-event-page-v1",
                  page.shopId == scope.shopID,
                  page.scope == checkpointB.scope,
                  page.pageLimit == 150,
                  page.rows.count <= 150,
                  page.asOfEventMaxId == String(throughID),
                  scopeMaxID >= throughID,
                  asOfID == throughID,
                  page.asOfDomainEventMaxIds == checkpointB.syncEvents.domainMaxIds,
                  page.hasMore == (page.nextAfterId != nil) else {
                throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
            }
            for event in page.rows {
                guard event.id > cursor,
                      event.id <= throughID,
                      event.requiresFullRecovery == false,
                      Self.hasCompleteTailEntityIDs(event) else {
                    throw ShopSyncRecoveryContractError.fullRecoveryRequired
                }
                let domain: ShopSyncRecoveryDomain
                switch event.domain {
                case "catalog", "prices":
                    domain = .products
                case "history":
                    domain = .history
                default:
                    throw ShopSyncRecoveryContractError.fullRecoveryRequired
                }
                try ShopSyncRecoveryRowContract.validateScope(
                    ownerUserID: event.ownerUserID,
                    shopID: event.shopID,
                    domain: domain,
                    selectedShopID: scope.shopID,
                    recoveryScope: checkpointB.scope
                )
                cursor = event.id
            }
            if page.hasMore {
                guard let next = page.nextAfterId,
                      try ShopSyncRecoveryCanonical.eventID(next) == cursor,
                      !page.rows.isEmpty else {
                    throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
                }
                continue
            }
            guard cursor == throughID else {
                throw ShopSyncRecoveryContractError.checkpointChanged
            }
            return
        }
    }

    /// A tail may cross an event only when the exact same completeness rules
    /// used by incremental apply accept it.  Presence of `entity_ids` alone
    /// is not evidence: `{}`, duplicate IDs, wrong-domain keys and count
    /// mismatches are all legacy/full-recovery blockers.  Zero-change
    /// compatibility events remain valid with an omitted payload.
    private nonisolated static func hasCompleteTailEntityIDs(
        _ event: RemoteSyncEventRow
    ) -> Bool {
        let ids = SyncEventEntityIDSet(json: event.entityIDs)
        switch event.domain {
        case "catalog":
            return ids.isCompleteCatalog(changedCount: event.changedCount)
        case "prices":
            return ids.isCompletePrices(changedCount: event.changedCount)
        case "history":
            return ids.isCompleteHistory(changedCount: event.changedCount)
        default:
            return false
        }
    }

    private func recordResponseBytes(
        _ bytes: Int,
        domain: ShopSyncRecoveryDomain?
    ) throws {
        let (nextTotal, totalOverflow) = totalResponseBytes.addingReportingOverflow(bytes)
        guard bytes >= 0,
              !totalOverflow,
              nextTotal <= ShopSyncRecoveryLimits.maximumResponseBytesTotal else {
            throw ShopSyncRecoveryContractError.totalResourceBudgetExceeded
        }
        if let domain {
            let current = responseBytesByDomain[domain, default: 0]
            let (nextDomain, domainOverflow) = current.addingReportingOverflow(bytes)
            guard !domainOverflow,
                  nextDomain <= ShopSyncRecoveryLimits.maximumResponseBytesPerDomain else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
            }
            responseBytesByDomain[domain] = nextDomain
        }
        totalResponseBytes = nextTotal
    }

    private func validateLocalScope(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        guard scope.ownerUserID == ownerUserID,
              scope.deviceIdentityHash == DeviceInstallIDStore.identityHash(
                for: scope.deviceInstallID
              ) else {
            throw ShopSyncRecoveryContractError.authenticationChanged
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(
            scope,
            defaults: defaultsBox.value
        )
    }
}

nonisolated enum ShopSyncRecoveryCanonical {
    static let separator = "\u{001f}"
    static let null = "-"
    /// The server folds every ordered checkpoint line into this initial SHA-256
    /// state. Keep the literal aligned with `sync_checkpoint_chain_digest_v1`
    /// rather than relying on a stream/newline digest implementation.
    static let checkpointChainInitialDigest =
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Exact `app_private.sync_checkpoint_chain_step_v1` contract.  The
    /// separator and UTF-8 byte count make the concatenation unambiguous; it
    /// is deliberately *not* a SHA of newline-delimited lines.
    static func checkpointChainStep(state: String, value: String) -> String {
        sha256(
            state + separator + String(value.utf8.count) + ":" + value
        )
    }

    static func checkpointChainDigest(_ values: [String]) -> String {
        values.reduce(checkpointChainInitialDigest) { state, value in
            checkpointChainStep(state: state, value: value)
        }
    }

    static func eventID(_ value: String) throws -> Int64 {
        guard value.utf8.count <= 19,
              !value.isEmpty,
              value == "0" || (value.first != "0" && value.allSatisfy(\.isNumber)),
              let parsed = Int64(value),
              parsed >= 0,
              String(parsed) == value else {
            throw ShopSyncRecoveryContractError.invalidCursor
        }
        return parsed
    }

    static func isRedactedKey(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    static func uuid(_ value: UUID?) -> String {
        value?.uuidString.lowercased() ?? null
    }

    static func joined(_ values: String...) -> String {
        values.joined(separator: separator)
    }

    /// Recovery RPC rows are required to expose digest-relevant timestamps in
    /// this exact UTC-six-microsecond form. Refusing to reinterpret a timestamp
    /// through `Date` prevents precision loss from changing a checkpoint.
    static func requireUTC6(_ value: String?) throws -> String {
        guard let value else { return null }
        let expression = try NSRegularExpression(
            pattern: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}Z$"#
        )
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard expression.firstMatch(in: value, range: range) != nil else {
            throw ShopSyncRecoveryContractError.nonCanonicalTimestamp
        }
        return value
    }

    /// Price effective/created timestamps and history business timestamps use
    /// the legacy database canonical form, not an ISO/RFC3339 variant.
    static func requireLegacyTimestamp(_ value: String?) throws -> String {
        guard let value,
              let date = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: value),
              ProductPriceEffectiveAtCanonicalizer.canonicalString(from: date) == value else {
            throw ShopSyncRecoveryContractError.nonCanonicalTimestamp
        }
        return value
    }
}

nonisolated struct ShopSyncRecoveryLedgerRecord: Codable, Equatable, Sendable {
    let orderingID: String
    let idLine: String
    let versionLine: String
    let identityLine: String?
    let isTombstone: Bool
}

nonisolated enum ShopSyncRecoveryRowContract {
    static func validateScope(
        ownerUserID: UUID,
        shopID: UUID?,
        domain: ShopSyncRecoveryDomain,
        checkpoint: ShopSyncRecoveryCheckpoint
    ) throws {
        try validateScope(
            ownerUserID: ownerUserID,
            shopID: shopID,
            domain: domain,
            selectedShopID: checkpoint.shopId,
            recoveryScope: checkpoint.scope
        )
    }

    static func validateScope(
        ownerUserID: UUID,
        shopID: UUID?,
        domain: ShopSyncRecoveryDomain,
        selectedShopID: UUID,
        recoveryScope: ShopSyncRecoveryScope
    ) throws {
        let domainScope = domain == .history
            ? recoveryScope.historyKind
            : recoveryScope.kind
        let isAuthorizedLegacyRow = shopID == nil
            && recoveryScope.legacyOwnerKey
                == ShopSyncRecoveryCanonical.sha256(ownerUserID.uuidString.lowercased())
        switch domainScope {
        case "shop_scoped":
            guard shopID == selectedShopID else {
                throw ShopSyncRecoveryContractError.rowOutsideScope(domain: domain)
            }
        case "legacy_owner_bridge":
            guard isAuthorizedLegacyRow else {
                throw ShopSyncRecoveryContractError.rowOutsideScope(domain: domain)
            }
        case "authorized_shop_plus_legacy":
            guard shopID == selectedShopID || isAuthorizedLegacyRow else {
                throw ShopSyncRecoveryContractError.rowOutsideScope(domain: domain)
            }
        default:
            throw ShopSyncRecoveryContractError.rowOutsideScope(domain: domain)
        }
    }

    static func supplier(
        _ row: RemoteInventorySupplierRow,
        checkpoint: ShopSyncRecoveryCheckpoint
    ) throws -> ShopSyncRecoveryLedgerRecord {
        try validateScope(
            ownerUserID: row.ownerUserID,
            shopID: row.shopID,
            domain: .suppliers,
            checkpoint: checkpoint
        )
        let id = row.id.uuidString.lowercased()
        return ShopSyncRecoveryLedgerRecord(
            orderingID: id,
            idLine: id,
            versionLine: ShopSyncRecoveryCanonical.joined(
                id,
                try ShopSyncRecoveryCanonical.requireUTC6(row.updatedAt),
                try ShopSyncRecoveryCanonical.requireUTC6(row.deletedAt)
            ),
            identityLine: nil,
            isTombstone: row.deletedAt != nil
        )
    }

    static func category(
        _ row: RemoteInventoryCategoryRow,
        checkpoint: ShopSyncRecoveryCheckpoint
    ) throws -> ShopSyncRecoveryLedgerRecord {
        try validateScope(
            ownerUserID: row.ownerUserID,
            shopID: row.shopID,
            domain: .categories,
            checkpoint: checkpoint
        )
        let id = row.id.uuidString.lowercased()
        return ShopSyncRecoveryLedgerRecord(
            orderingID: id,
            idLine: id,
            versionLine: ShopSyncRecoveryCanonical.joined(
                id,
                try ShopSyncRecoveryCanonical.requireUTC6(row.updatedAt),
                try ShopSyncRecoveryCanonical.requireUTC6(row.deletedAt)
            ),
            identityLine: nil,
            isTombstone: row.deletedAt != nil
        )
    }

    static func product(
        _ row: RemoteInventoryProductRow,
        checkpoint: ShopSyncRecoveryCheckpoint
    ) throws -> ShopSyncRecoveryLedgerRecord {
        try validateScope(
            ownerUserID: row.ownerUserID,
            shopID: row.shopID,
            domain: .products,
            checkpoint: checkpoint
        )
        let id = row.id.uuidString.lowercased()
        let isTombstone = row.deletedAt != nil
        // `sync_product_recovery_row_v1` strips every live relation from a
        // product tombstone. Treat their reappearance as a malformed recovery
        // payload rather than silently normalizing a potentially cross-scope
        // UUID into the same digest sentinel.
        guard !isTombstone || (
            row.categoryID == nil
                && row.supplierID == nil
                && row.primaryImageVersionID == nil
                && row.primaryImageUpdatedAt == nil
        ) else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
        return ShopSyncRecoveryLedgerRecord(
            orderingID: id,
            idLine: id,
            versionLine: ShopSyncRecoveryCanonical.joined(
                id,
                try ShopSyncRecoveryCanonical.requireUTC6(row.updatedAt),
                try ShopSyncRecoveryCanonical.requireUTC6(row.deletedAt),
                isTombstone
                    ? ShopSyncRecoveryCanonical.null
                    : ShopSyncRecoveryCanonical.uuid(row.categoryID),
                isTombstone
                    ? ShopSyncRecoveryCanonical.null
                    : ShopSyncRecoveryCanonical.uuid(row.supplierID),
                isTombstone
                    ? ShopSyncRecoveryCanonical.null
                    : ShopSyncRecoveryCanonical.uuid(row.primaryImageVersionID),
                isTombstone
                    ? ShopSyncRecoveryCanonical.null
                    : try ShopSyncRecoveryCanonical.requireUTC6(row.primaryImageUpdatedAt)
            ),
            identityLine: ShopSyncRecoveryCanonical.joined(
                id,
                ShopSyncRecoveryCanonical.sha256(row.barcode),
                ShopSyncRecoveryCanonical.sha256(row.itemNumber ?? "")
            ),
            isTombstone: isTombstone
        )
    }

    static func price(
        _ row: RemoteInventoryProductPriceRow,
        checkpoint: ShopSyncRecoveryCheckpoint
    ) throws -> ShopSyncRecoveryLedgerRecord {
        try validateScope(
            ownerUserID: row.ownerUserID,
            shopID: row.shopID,
            domain: .prices,
            checkpoint: checkpoint
        )
        let id = row.id.uuidString.lowercased()
        guard let updatedAt = row.updatedAt else {
            throw ShopSyncRecoveryContractError.nonCanonicalTimestamp
        }
        // The inventory table stores its enum-like values as uppercase
        // `PURCHASE`/`RETAIL`, and the backend checkpoint intentionally hashes
        // that raw value. Validate the supported semantic type without
        // normalizing the value used below in `versionLine`.
        guard SupabasePullPreviewNormalizer.normalizedPriceType(row.type) != nil else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .prices)
        }
        let canonicalPrice = try canonicalPrice(row)
        return ShopSyncRecoveryLedgerRecord(
            orderingID: id,
            idLine: id,
            versionLine: ShopSyncRecoveryCanonical.joined(
                id,
                try ShopSyncRecoveryCanonical.requireUTC6(updatedAt),
                row.productID.uuidString.lowercased(),
                canonicalPrice.value,
                row.type,
                try ShopSyncRecoveryCanonical.requireLegacyTimestamp(row.effectiveAt),
                try ShopSyncRecoveryCanonical.requireLegacyTimestamp(row.createdAt),
                ShopSyncRecoveryCanonical.sha256(row.source ?? ""),
                ShopSyncRecoveryCanonical.sha256(row.note ?? "")
            ),
            identityLine: nil,
            isTombstone: false
        )
    }

    static func history(
        _ row: RemoteSharedSheetSessionRow,
        checkpoint: ShopSyncRecoveryCheckpoint
    ) throws -> ShopSyncRecoveryLedgerRecord {
        try validateScope(
            ownerUserID: row.ownerUserID,
            shopID: row.shopID,
            domain: .history,
            checkpoint: checkpoint
        )
        let id = row.remoteID.uuidString.lowercased()
        guard let updatedAt = row.updatedAt else {
            throw ShopSyncRecoveryContractError.nonCanonicalTimestamp
        }
        let suffix: [String]
        if row.deletedAt != nil {
            guard row.dataCheckpointDigest == ShopSyncRecoveryCanonical.null,
                  row.overlayCheckpointDigest == ShopSyncRecoveryCanonical.null else {
                throw ShopSyncRecoveryContractError.invalidPage(domain: .history)
            }
            suffix = [ShopSyncRecoveryCanonical.null]
        } else {
            guard let dataDigest = row.dataCheckpointDigest,
                  let overlayDigest = row.overlayCheckpointDigest,
                  ShopSyncRecoveryCanonical.isRedactedKey(dataDigest),
                  ShopSyncRecoveryCanonical.isRedactedKey(overlayDigest) else {
                throw ShopSyncRecoveryContractError.invalidPage(domain: .history)
            }
            suffix = [
                try ShopSyncRecoveryCanonical.requireLegacyTimestamp(row.timestamp),
                ShopSyncRecoveryCanonical.sha256(row.supplier),
                ShopSyncRecoveryCanonical.sha256(row.category),
                row.isManualEntry ? "true" : "false",
                ShopSyncRecoveryCanonical.sha256(row.displayName),
                dataDigest,
                overlayDigest
            ]
        }
        return ShopSyncRecoveryLedgerRecord(
            orderingID: id,
            idLine: id,
            versionLine: (
                [
                    id,
                    try ShopSyncRecoveryCanonical.requireUTC6(updatedAt),
                    try ShopSyncRecoveryCanonical.requireUTC6(row.deletedAt),
                    String(row.payloadVersion)
                ] + suffix
            ).joined(separator: ShopSyncRecoveryCanonical.separator),
            identityLine: nil,
            isTombstone: row.deletedAt != nil
        )
    }

    /// Use the decimal supplied by the recovery RPC as the authoritative
    /// materialization input. A binary JSON `Double` cannot safely recreate
    /// PostgreSQL's `trim_scale(round(price::numeric, 3))` digest field.
    static func canonicalPrice(
        _ row: RemoteInventoryProductPriceRow
    ) throws -> ProductPriceCanonicalAmount {
        guard let value = row.priceCanonical,
              isServerCanonicalPrice(value),
              let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .prices)
        }
        let number = NSDecimalNumber(decimal: decimal)
        guard number != NSDecimalNumber.notANumber,
              number.doubleValue.isFinite else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .prices)
        }
        return ProductPriceCanonicalAmount(value: value, doubleValue: number.doubleValue)
    }

    private static func isServerCanonicalPrice(_ value: String) -> Bool {
        let pieces = value.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 1 || pieces.count == 2,
              let integer = pieces.first,
              !integer.isEmpty,
              integer.utf8.allSatisfy({ (48...57).contains($0) }),
              integer.count <= 12,
              !(integer.count > 1 && integer.first == "0") else {
            return false
        }
        guard pieces.count == 1 else {
            guard let fraction = pieces.last,
                  (1...3).contains(fraction.count),
                  fraction.utf8.allSatisfy({ (48...57).contains($0) }),
                  fraction.last != "0" else {
                return false
            }
            return true
        }
        return true
    }

    static func image(
        _ row: ShopSyncRecoveryImageRow,
        checkpoint: ShopSyncRecoveryCheckpoint
    ) throws -> ShopSyncRecoveryLedgerRecord {
        try validateScope(
            ownerUserID: row.ownerUserID,
            shopID: row.shopID,
            domain: .images,
            checkpoint: checkpoint
        )
        guard row.status == "ready",
              let finalizedAt = row.finalizedAt,
              try validImageVariant(row.main, maximumBytes: 1_048_576, maximumDimension: 1_600),
              try validImageVariant(row.thumb, maximumBytes: 92_160, maximumDimension: 384) else {
            throw ShopSyncRecoveryContractError.invalidImageMetadata
        }
        let productID = row.productID.uuidString.lowercased()
        let versionID = row.versionID.uuidString.lowercased()
        return ShopSyncRecoveryLedgerRecord(
            orderingID: productID,
            // Image recovery is keyed and paged by product. The backend
            // id-set digest therefore uses product_id; version_id remains in
            // the version line so replacing an image still changes the
            // strong digest without changing entity identity.
            idLine: productID,
            versionLine: ShopSyncRecoveryCanonical.joined(
                productID,
                versionID,
                row.status,
                // The recovery RPC keeps a ready primary image row for a
                // tombstoned product. `product_deleted_at` is therefore part
                // of the server's image version digest and must precede the
                // image finalization timestamp exactly as it does there.
                try ShopSyncRecoveryCanonical.requireUTC6(row.productDeletedAt),
                try ShopSyncRecoveryCanonical.requireUTC6(finalizedAt),
                row.main.sha256!,
                String(row.main.bytes!),
                String(row.main.width!),
                String(row.main.height!),
                row.main.mime!,
                row.thumb.sha256!,
                String(row.thumb.bytes!),
                String(row.thumb.width!),
                String(row.thumb.height!),
                row.thumb.mime!
            ),
            identityLine: nil,
            isTombstone: row.productDeletedAt != nil
        )
    }

    private static func validImageVariant(
        _ variant: ShopSyncRecoveryImageVariant,
        maximumBytes: Int,
        maximumDimension: Int
    ) throws -> Bool {
        guard let sha256 = variant.sha256,
              sha256.count == 64,
              sha256.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
              let bytes = variant.bytes,
              (1...maximumBytes).contains(bytes),
              let width = variant.width,
              (1...maximumDimension).contains(width),
              let height = variant.height,
              (1...maximumDimension).contains(height),
              variant.mime == "image/jpeg" else {
            return false
        }
        return true
    }
}

nonisolated struct ShopSyncRecoveryDigestAccumulator {
    private var idDigest = ShopSyncRecoveryCanonical.checkpointChainInitialDigest
    private var versionDigest = ShopSyncRecoveryCanonical.checkpointChainInitialDigest
    private var identityDigest = ShopSyncRecoveryCanonical.checkpointChainInitialDigest
    private var hasIdentity: Bool
    private var rowCount = 0
    private var activeCount = 0
    private var tombstoneCount = 0
    private var previousOrderingID: String?

    init(hasIdentity: Bool = false) {
        self.hasIdentity = hasIdentity
    }

    mutating func append(
        orderingID: String,
        idLine: String,
        versionLine: String,
        identityLine: String? = nil,
        isTombstone: Bool
    ) throws {
        let orderingID = orderingID.lowercased()
        guard UUID(uuidString: orderingID) != nil,
              previousOrderingID.map({ $0 < orderingID }) ?? true,
              hasIdentity == (identityLine != nil) else {
            throw ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID
        }
        idDigest = ShopSyncRecoveryCanonical.checkpointChainStep(
            state: idDigest,
            value: idLine
        )
        versionDigest = ShopSyncRecoveryCanonical.checkpointChainStep(
            state: versionDigest,
            value: versionLine
        )
        if let identityLine {
            identityDigest = ShopSyncRecoveryCanonical.checkpointChainStep(
                state: identityDigest,
                value: identityLine
            )
        }
        rowCount += 1
        if isTombstone { tombstoneCount += 1 } else { activeCount += 1 }
        previousOrderingID = orderingID
    }

    mutating func finalize() -> ShopSyncRecoveryEntityDigest {
        ShopSyncRecoveryEntityDigest(
            activeCount: activeCount,
            tombstoneCount: tombstoneCount,
            idSetDigest: idDigest,
            versionDigest: versionDigest,
            identityDigest: hasIdentity ? identityDigest : nil
        )
    }
}

nonisolated enum ShopSyncRecoveryContractError: Error, Equatable, Sendable {
    case authenticationChanged
    case invalidCheckpoint
    case invalidPage(domain: ShopSyncRecoveryDomain)
    case nonCanonicalTimestamp
    case nonMonotonicOrDuplicateID
    case rowOutsideScope(domain: ShopSyncRecoveryDomain)
    case digestMismatch(domain: ShopSyncRecoveryDomain)
    case countMismatch(domain: ShopSyncRecoveryDomain)
    case checkpointChanged
    case invalidCursor
    case scopeFenceMissing
    case markerNotVerified
    case fullRecoveryRequired
    case relationViolation
    case pageBudgetExceeded(domain: ShopSyncRecoveryDomain)
    case invalidImageMetadata
    case persistedLedgerInvalid(domain: ShopSyncRecoveryDomain)
    case resourceBudgetExceeded(domain: ShopSyncRecoveryDomain)
    case totalResourceBudgetExceeded
}
