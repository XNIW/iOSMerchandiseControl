import CryptoKit
import Foundation
import SwiftData

nonisolated enum LocalPendingChangeEntityKind: String, CaseIterable, Sendable {
    case product
    case supplier
    case productCategory
    case productPrice
    case importBatch
    case historySession

    var isCatalogKind: Bool {
        switch self {
        case .product, .supplier, .productCategory, .importBatch:
            return true
        case .productPrice, .historySession:
            return false
        }
    }
}

nonisolated enum LocalPendingChangeOperation: String, CaseIterable, Sendable {
    case create
    case update
    case delete
    case upsert
}

nonisolated enum LocalPendingChangeStatus: String, CaseIterable, Sendable {
    case pending
    case superseded
    case blocked
    case staleBaseline
    case sent
    case acknowledged

    var isTerminal: Bool {
        self == .superseded || self == .acknowledged
    }
}

nonisolated enum LocalPendingChangeOrigin: String, CaseIterable, Sendable {
    case manualCatalogSave
    case confirmedImport
    case productPriceSave
    case historySessionSave
    case reconciliation
}

@Model
final class LocalPendingChange {
    var changeID: String
    var recordSchemaVersion: Int
    var ownerUserID: String?
    var ownerHash: String?
    var storeId: String?
    var localStoreId: String?
    var syncProtocolVersion: Int = Task126SyncPolicy.syncProtocolVersion
    var schemaVersion: Int = Task126SyncPolicy.localSchemaVersion
    var storeEpoch: Int = Task126SyncPolicy.defaultStoreEpoch
    var entityKindRaw: String
    var operationRaw: String
    var statusRaw: String
    var originRaw: String
    var logicalKey: String
    var changedFieldsRaw: String
    var baselineFingerprintHash: String?
    var intendedFingerprintHash: String?
    var baseRemoteUpdatedAt: Date?
    var baseVersion: Int?
    var baseEventId: String?
    var idempotencyKey: String = UUID().uuidString.lowercased()
    var entityRemoteIDRaw: String?
    var createdAt: Date
    var updatedAt: Date
    var lastAttemptAt: Date?
    var supersededByChangeID: String?

    init(
        changeID: UUID = UUID(),
        recordSchemaVersion: Int = 1,
        ownerUserID: UUID? = nil,
        ownerHash: String? = nil,
        storeId: String? = nil,
        localStoreId: String? = nil,
        syncProtocolVersion: Int = Task126SyncPolicy.syncProtocolVersion,
        schemaVersion: Int = Task126SyncPolicy.localSchemaVersion,
        storeEpoch: Int = Task126SyncPolicy.defaultStoreEpoch,
        baseRemoteUpdatedAt: Date? = nil,
        baseVersion: Int? = nil,
        baseEventId: String? = nil,
        idempotencyKey: String? = nil,
        entityKind: LocalPendingChangeEntityKind,
        operation: LocalPendingChangeOperation,
        status: LocalPendingChangeStatus = .pending,
        origin: LocalPendingChangeOrigin,
        logicalKey: String,
        changedFields: [String] = [],
        baselineFingerprintHash: String? = nil,
        intendedFingerprintHash: String? = nil,
        entityRemoteID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastAttemptAt: Date? = nil,
        supersededByChangeID: UUID? = nil
    ) {
        self.changeID = changeID.uuidString.lowercased()
        self.recordSchemaVersion = recordSchemaVersion
        let ownerRaw = ownerUserID?.uuidString.lowercased()
        let normalizedStoreId = Task126OwnerStoreScope.normalizedStoreId(storeId)
        self.ownerUserID = ownerRaw
        self.ownerHash = ownerHash ?? ownerRaw.map(AccountBindingStore.redactedAccountHash(for:))
        self.storeId = normalizedStoreId
        self.localStoreId = Task126OwnerStoreScope.normalizedLocalStoreId(
            localStoreId,
            storeId: normalizedStoreId
        )
        self.syncProtocolVersion = syncProtocolVersion
        self.schemaVersion = schemaVersion
        self.storeEpoch = storeEpoch
        self.entityKindRaw = entityKind.rawValue
        self.operationRaw = operation.rawValue
        self.statusRaw = status.rawValue
        self.originRaw = origin.rawValue
        self.logicalKey = logicalKey
        self.changedFieldsRaw = Self.encodeChangedFields(changedFields)
        self.baselineFingerprintHash = baselineFingerprintHash
        self.intendedFingerprintHash = intendedFingerprintHash
        self.baseRemoteUpdatedAt = baseRemoteUpdatedAt
        self.baseVersion = baseVersion
        self.baseEventId = baseEventId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeIdempotencyKey = idempotencyKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let safeIdempotencyKey, !safeIdempotencyKey.isEmpty {
            self.idempotencyKey = safeIdempotencyKey
        } else {
            self.idempotencyKey = changeID.uuidString.lowercased()
        }
        self.entityRemoteIDRaw = entityRemoteID?.uuidString.lowercased()
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastAttemptAt = lastAttemptAt
        self.supersededByChangeID = supersededByChangeID?.uuidString.lowercased()
    }

    var entityKind: LocalPendingChangeEntityKind {
        get { LocalPendingChangeEntityKind(rawValue: entityKindRaw) ?? .product }
        set { entityKindRaw = newValue.rawValue }
    }

    var operation: LocalPendingChangeOperation {
        get { LocalPendingChangeOperation(rawValue: operationRaw) ?? .update }
        set { operationRaw = newValue.rawValue }
    }

    var status: LocalPendingChangeStatus {
        get { LocalPendingChangeStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var origin: LocalPendingChangeOrigin {
        get { LocalPendingChangeOrigin(rawValue: originRaw) ?? .manualCatalogSave }
        set { originRaw = newValue.rawValue }
    }

    var changedFields: [String] {
        get { Self.decodeChangedFields(changedFieldsRaw) }
        set { changedFieldsRaw = Self.encodeChangedFields(newValue) }
    }

    var entityRemoteID: UUID? {
        get {
            guard let entityRemoteIDRaw else { return nil }
            return UUID(uuidString: entityRemoteIDRaw)
        }
        set {
            entityRemoteIDRaw = newValue?.uuidString.lowercased()
        }
    }

    var ownerStoreScope: Task126OwnerStoreScope {
        Task126OwnerStoreScope(
            ownerHash: ownerHash ?? ownerUserID.map(AccountBindingStore.redactedAccountHash(for:)) ?? "anonymous",
            storeId: storeId,
            localStoreId: localStoreId,
            syncProtocolVersion: syncProtocolVersion,
            schemaVersion: schemaVersion,
            storeEpoch: storeEpoch
        )
    }

    static func encodeChangedFields(_ fields: [String]) -> String {
        fields
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
            .uniquedSorted()
            .joined(separator: ",")
    }

    static func decodeChangedFields(_ rawValue: String) -> [String] {
        rawValue
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }
}

nonisolated struct LocalPendingChangeSnapshot: Equatable, Sendable {
    var pendingCatalogChangeCount: Int
    var pendingProductPriceChangeCount: Int
    var pendingHistorySessionChangeCount: Int
    var blockedCount: Int
    var staleBaselineCount: Int
    var sentCount: Int
    var supersededRetainedCount: Int
    var isCapped: Bool

    init(
        pendingCatalogChangeCount: Int = 0,
        pendingProductPriceChangeCount: Int = 0,
        pendingHistorySessionChangeCount: Int = 0,
        blockedCount: Int = 0,
        staleBaselineCount: Int = 0,
        sentCount: Int = 0,
        supersededRetainedCount: Int = 0,
        isCapped: Bool = false
    ) {
        self.pendingCatalogChangeCount = pendingCatalogChangeCount
        self.pendingProductPriceChangeCount = pendingProductPriceChangeCount
        self.pendingHistorySessionChangeCount = pendingHistorySessionChangeCount
        self.blockedCount = blockedCount
        self.staleBaselineCount = staleBaselineCount
        self.sentCount = sentCount
        self.supersededRetainedCount = supersededRetainedCount
        self.isCapped = isCapped
    }

    static let empty = LocalPendingChangeSnapshot(
        pendingCatalogChangeCount: 0,
        pendingProductPriceChangeCount: 0,
        pendingHistorySessionChangeCount: 0,
        blockedCount: 0,
        staleBaselineCount: 0,
        sentCount: 0,
        supersededRetainedCount: 0,
        isCapped: false
    )
}

nonisolated struct LocalPendingChangeImportBatchResult: Equatable, Sendable {
    var recordedCount: Int
    var cappedCount: Int
}

nonisolated struct LocalPendingChangeReconciliationRecord: Sendable {
    let entityKind: LocalPendingChangeEntityKind
    let remoteID: UUID
    let remoteDeletedAt: Date?
    let fingerprintCanonical: String

    init(
        entityKind: LocalPendingChangeEntityKind,
        remoteID: UUID,
        remoteDeletedAt: Date? = nil,
        fingerprintCanonical: String
    ) {
        self.entityKind = entityKind
        self.remoteID = remoteID
        self.remoteDeletedAt = remoteDeletedAt
        self.fingerprintCanonical = fingerprintCanonical
    }
}

nonisolated final class LocalPendingChangeAccumulator {
    static let defaultMaxActiveChanges = 1_000
    static let defaultTerminalRetentionLimit = 200

    private let context: ModelContext
    private let ownerUserID: UUID?
    private let storeIdentity: LocalStoreIdentity
    private let now: () -> Date
    private let maxActiveChanges: Int
    private var cachedActiveCount: Int?

    init(
        context: ModelContext,
        ownerUserID: UUID? = nil,
        storeIdentity: LocalStoreIdentity = .anonymous,
        now: @escaping () -> Date = Date.init,
        maxActiveChanges: Int = defaultMaxActiveChanges
    ) {
        self.context = context
        self.ownerUserID = ownerUserID
        self.storeIdentity = storeIdentity
        self.now = now
        self.maxActiveChanges = max(1, maxActiveChanges)
    }

    @discardableResult
    func recordProductChange(
        product: Product,
        operation: LocalPendingChangeOperation,
        origin: LocalPendingChangeOrigin,
        changedFields: [String],
        baselineFingerprintHash: String? = nil,
        intendedFingerprintHash: String? = nil
    ) throws -> LocalPendingChange? {
        let key = LocalPendingChangeLogicalKey.product(
            remoteID: product.remoteID,
            barcode: product.barcode
        )
        let intendedHash = intendedFingerprintHash ?? LocalPendingChangeLogicalKey.productFingerprintHash(product)
        return try recordChange(
            entityKind: .product,
            operation: operation,
            origin: origin,
            logicalKey: key,
            changedFields: changedFields,
            baselineFingerprintHash: baselineFingerprintHash,
            intendedFingerprintHash: intendedHash,
            entityRemoteID: product.remoteID
        )
    }

    @discardableResult
    func recordSupplierChange(
        supplier: Supplier,
        operation: LocalPendingChangeOperation,
        origin: LocalPendingChangeOrigin,
        changedFields: [String] = ["name"],
        baselineFingerprintHash: String? = nil,
        intendedFingerprintHash: String? = nil
    ) throws -> LocalPendingChange? {
        let key = LocalPendingChangeLogicalKey.supplier(
            remoteID: supplier.remoteID,
            name: supplier.name
        )
        let intendedHash = intendedFingerprintHash ?? LocalPendingChangeLogicalKey.supplierFingerprintHash(supplier)
        return try recordChange(
            entityKind: .supplier,
            operation: operation,
            origin: origin,
            logicalKey: key,
            changedFields: changedFields,
            baselineFingerprintHash: baselineFingerprintHash,
            intendedFingerprintHash: intendedHash,
            entityRemoteID: supplier.remoteID
        )
    }

    @discardableResult
    func recordCategoryChange(
        category: ProductCategory,
        operation: LocalPendingChangeOperation,
        origin: LocalPendingChangeOrigin,
        changedFields: [String] = ["name"],
        baselineFingerprintHash: String? = nil,
        intendedFingerprintHash: String? = nil
    ) throws -> LocalPendingChange? {
        let key = LocalPendingChangeLogicalKey.category(
            remoteID: category.remoteID,
            name: category.name
        )
        let intendedHash = intendedFingerprintHash ?? LocalPendingChangeLogicalKey.categoryFingerprintHash(category)
        return try recordChange(
            entityKind: .productCategory,
            operation: operation,
            origin: origin,
            logicalKey: key,
            changedFields: changedFields,
            baselineFingerprintHash: baselineFingerprintHash,
            intendedFingerprintHash: intendedHash,
            entityRemoteID: category.remoteID
        )
    }

    @discardableResult
    func recordProductPriceChange(
        price: ProductPrice,
        origin: LocalPendingChangeOrigin
    ) throws -> LocalPendingChange? {
        guard let product = price.product else { return nil }
        let key = LocalPendingChangeLogicalKey.productPrice(
            productRemoteID: product.remoteID,
            productBarcode: product.barcode,
            type: price.type,
            effectiveAt: price.effectiveAt
        )
        return try recordChange(
            entityKind: .productPrice,
            operation: .upsert,
            origin: origin,
            logicalKey: key,
            changedFields: ["price", "effectiveAt", "type"],
            baselineFingerprintHash: nil,
            intendedFingerprintHash: LocalPendingChangeLogicalKey.productPriceFingerprintHash(price),
            entityRemoteID: price.remoteID
        )
    }

    @discardableResult
    func recordHistorySessionChange(
        entry: HistoryEntry,
        operation: LocalPendingChangeOperation,
        origin: LocalPendingChangeOrigin = .historySessionSave,
        changedFields: [String]
    ) throws -> LocalPendingChange? {
        let remoteID = entry.ensureHistorySessionRemoteID()
        let key = LocalPendingChangeLogicalKey.historySession(
            remoteID: remoteID,
            uid: entry.uid
        )
        return try recordChange(
            entityKind: .historySession,
            operation: operation,
            origin: origin,
            logicalKey: key,
            changedFields: changedFields,
            baselineFingerprintHash: nil,
            intendedFingerprintHash: HistorySessionPayloadCodec.fingerprintHash(
                for: HistorySessionPayloadSnapshotFactory.snapshot(for: entry, ensureRemoteID: false)
            ),
            entityRemoteID: remoteID
        )
    }

    func acknowledgeHistorySessionChange(entry: HistoryEntry) throws {
        let key = LocalPendingChangeLogicalKey.historySession(
            remoteID: entry.remoteID,
            uid: entry.uid
        )
        let timestamp = now()
        for change in try fetchChanges(entityKind: .historySession, logicalKey: key)
            where !change.status.isTerminal {
            change.status = .acknowledged
            change.updatedAt = timestamp
        }
    }

    @discardableResult
    func recordImportBatch(
        logicalKeys: [String],
        maxLogicalKeys: Int
    ) throws -> LocalPendingChangeImportBatchResult {
        var recordedCount = 0
        let cappedKeys = logicalKeys.prefix(max(0, maxLogicalKeys))
        for logicalKey in cappedKeys {
            if try recordChange(
                entityKind: .importBatch,
                operation: .upsert,
                origin: .confirmedImport,
                logicalKey: "import:\(LocalPendingChangeLogicalKey.privacyHash(logicalKey))",
                changedFields: ["confirmedImport"]
            ) != nil {
                recordedCount += 1
            }
        }

        let cappedCount = max(0, logicalKeys.count - cappedKeys.count)
        if cappedCount > 0 {
            _ = try recordImportCapMarker(cappedCount: cappedCount)
        }
        return LocalPendingChangeImportBatchResult(
            recordedCount: recordedCount,
            cappedCount: cappedCount
        )
    }

    func markStatus(
        change: LocalPendingChange,
        status: LocalPendingChangeStatus
    ) {
        change.status = status
        change.updatedAt = now()
    }

    func cleanupTerminalChanges(
        retainAtMost limit: Int = defaultTerminalRetentionLimit
    ) throws {
        let descriptor = FetchDescriptor<LocalPendingChange>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let terminal = try context.fetch(descriptor).filter {
            $0.status.isTerminal && isOwnerCompatible($0)
        }
        for change in terminal.dropFirst(max(0, limit)) {
            context.delete(change)
        }
    }

    func reconcileAfterBaselineRefresh(
        records: [LocalPendingChangeReconciliationRecord]
    ) throws {
        let recordsByKey = Dictionary(
            uniqueKeysWithValues: records.map { record in
                (
                    LocalPendingChangeLogicalKey.remoteEntity(
                        kind: record.entityKind,
                        remoteID: record.remoteID
                    ),
                    record
                )
            }
        )
        let changes = try fetchActiveChanges()
        let timestamp = now()

        for change in changes {
            guard let record = recordsByKey[change.logicalKey] else {
                continue
            }

            if record.remoteDeletedAt != nil {
                change.status = .blocked
                change.updatedAt = timestamp
                continue
            }

            let remoteHash = LocalPendingChangeLogicalKey.privacyHash(record.fingerprintCanonical)
            if let intendedHash = change.intendedFingerprintHash,
               intendedHash == remoteHash {
                change.status = .superseded
                change.updatedAt = timestamp
                continue
            }

            if let baselineHash = change.baselineFingerprintHash,
               baselineHash != remoteHash {
                change.status = .staleBaseline
                change.updatedAt = timestamp
            }
        }
    }

    private func recordChange(
        entityKind: LocalPendingChangeEntityKind,
        operation: LocalPendingChangeOperation,
        origin: LocalPendingChangeOrigin,
        logicalKey: String,
        changedFields: [String],
        status: LocalPendingChangeStatus = .pending,
        baselineFingerprintHash: String? = nil,
        intendedFingerprintHash: String? = nil,
        entityRemoteID: UUID? = nil,
        enforceCap: Bool = true
    ) throws -> LocalPendingChange? {
        guard operation != .update || !changedFields.isEmpty else {
            return nil
        }

        let timestamp = now()
        let existing = try fetchChanges(entityKind: entityKind, logicalKey: logicalKey)
            .filter { !$0.status.isTerminal }
            .sorted { $0.updatedAt > $1.updatedAt }

        if let current = existing.first {
            coalesce(
                current,
                operation: operation,
                origin: origin,
                changedFields: changedFields,
                baselineFingerprintHash: baselineFingerprintHash,
                intendedFingerprintHash: intendedFingerprintHash,
                entityRemoteID: entityRemoteID,
                timestamp: timestamp
            )
            for superseded in existing.dropFirst() {
                superseded.status = .superseded
                superseded.supersededByChangeID = current.changeID
                superseded.updatedAt = timestamp
            }
            notifyActiveChangeIfNeeded(current)
            return current.status.isTerminal ? nil : current
        }

        if enforceCap {
            guard try canInsertNewActiveChange(origin: origin, timestamp: timestamp) else {
                return nil
            }
        }

        let change = LocalPendingChange(
            ownerUserID: ownerUserID,
            storeId: storeIdentity.storeId,
            localStoreId: storeIdentity.localStoreId,
            syncProtocolVersion: storeIdentity.syncProtocolVersion,
            schemaVersion: storeIdentity.schemaVersion,
            storeEpoch: storeIdentity.storeEpoch,
            entityKind: entityKind,
            operation: operation,
            status: status,
            origin: origin,
            logicalKey: logicalKey,
            changedFields: changedFields,
            baselineFingerprintHash: baselineFingerprintHash,
            intendedFingerprintHash: intendedFingerprintHash,
            entityRemoteID: entityRemoteID,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        context.insert(change)
        cachedActiveCount = (cachedActiveCount ?? 0) + 1
        notifyActiveChangeIfNeeded(change)
        return change
    }

    private func notifyActiveChangeIfNeeded(_ change: LocalPendingChange) {
        guard !change.status.isTerminal else { return }
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .localPendingChangesDidChange,
                object: nil
            )
        }
    }

    private func coalesce(
        _ change: LocalPendingChange,
        operation: LocalPendingChangeOperation,
        origin: LocalPendingChangeOrigin,
        changedFields: [String],
        baselineFingerprintHash: String?,
        intendedFingerprintHash: String?,
        entityRemoteID: UUID?,
        timestamp: Date
    ) {
        let coalesced = PendingChangeCoalescer.coalesce(
            current: PendingChangeCoalescer.State(
                operation: change.operation,
                status: change.status,
                changedFields: change.changedFields,
                entityRemoteID: change.entityRemoteID
            ),
            incoming: operation,
            changedFields: changedFields,
            incomingEntityRemoteID: entityRemoteID
        )
        change.operation = coalesced.operation
        change.status = coalesced.status
        change.changedFields = coalesced.changedFields
        change.entityRemoteID = coalesced.entityRemoteID

        change.origin = origin
        change.baselineFingerprintHash = baselineFingerprintHash ?? change.baselineFingerprintHash
        change.intendedFingerprintHash = intendedFingerprintHash ?? change.intendedFingerprintHash
        change.updatedAt = timestamp
    }

    private func canInsertNewActiveChange(
        origin: LocalPendingChangeOrigin,
        timestamp: Date
    ) throws -> Bool {
        let count: Int
        if let cachedActiveCount {
            count = cachedActiveCount
        } else {
            let fetched = try fetchActiveChanges()
            cachedActiveCount = fetched.count
            count = fetched.count
        }
        guard count < maxActiveChanges else {
            _ = try recordImportCapMarker(cappedCount: 1, timestamp: timestamp)
            return false
        }
        return true
    }

    private func recordImportCapMarker(
        cappedCount: Int,
        timestamp: Date? = nil
    ) throws -> LocalPendingChange? {
        let key = "import:cap:\(ownerUserID?.uuidString.lowercased() ?? "unknown")"
        return try recordChange(
            entityKind: .importBatch,
            operation: .upsert,
            origin: .confirmedImport,
            logicalKey: key,
            changedFields: ["capped", "count"],
            status: .blocked,
            baselineFingerprintHash: nil,
            intendedFingerprintHash: LocalPendingChangeLogicalKey.privacyHash("capped:\(cappedCount):\(timestamp ?? now())"),
            entityRemoteID: nil,
            enforceCap: false
        )
    }

    private func fetchChanges(
        entityKind: LocalPendingChangeEntityKind,
        logicalKey: String
    ) throws -> [LocalPendingChange] {
        let rawKind = entityKind.rawValue
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.entityKindRaw == rawKind && change.logicalKey == logicalKey
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).filter(isOwnerCompatible)
    }

    private func fetchActiveChanges() throws -> [LocalPendingChange] {
        let descriptor = FetchDescriptor<LocalPendingChange>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).filter {
            !$0.status.isTerminal && isOwnerCompatible($0)
        }
    }

    private func isOwnerCompatible(_ change: LocalPendingChange) -> Bool {
        guard let ownerUserID = ownerUserID?.uuidString.lowercased() else {
            return change.ownerUserID == nil
        }
        guard change.ownerUserID == ownerUserID else {
            return false
        }
        let changeStore = Task126OwnerStoreScope.normalizedStoreId(change.storeId)
        return changeStore == storeIdentity.storeId || change.storeId == nil
    }
}

nonisolated final class LocalPendingChangeSnapshotProvider {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadSnapshot(ownerUserID: UUID?) throws -> LocalPendingChangeSnapshot {
        guard let ownerUserID else {
            return .empty
        }

        let owner = ownerUserID.uuidString.lowercased()
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let changes = try context.fetch(descriptor)

        var snapshot = LocalPendingChangeSnapshot.empty
        for change in changes {
            if change.entityKind == .importBatch,
               change.logicalKey.hasPrefix("import:cap:") {
                snapshot.isCapped = true
            }
            switch change.status {
            case .pending:
                if change.entityKind.isCatalogKind {
                    snapshot.pendingCatalogChangeCount += 1
                } else if change.entityKind == .productPrice {
                    snapshot.pendingProductPriceChangeCount += 1
                } else if change.entityKind == .historySession {
                    snapshot.pendingHistorySessionChangeCount += 1
                }
            case .blocked:
                snapshot.blockedCount += 1
                if change.entityKind.isCatalogKind {
                    snapshot.pendingCatalogChangeCount += 1
                } else if change.entityKind == .productPrice {
                    snapshot.pendingProductPriceChangeCount += 1
                } else if change.entityKind == .historySession {
                    snapshot.pendingHistorySessionChangeCount += 1
                }
            case .staleBaseline:
                snapshot.staleBaselineCount += 1
                if change.entityKind.isCatalogKind {
                    snapshot.pendingCatalogChangeCount += 1
                } else if change.entityKind == .productPrice {
                    snapshot.pendingProductPriceChangeCount += 1
                } else if change.entityKind == .historySession {
                    snapshot.pendingHistorySessionChangeCount += 1
                }
            case .sent:
                snapshot.sentCount += 1
                if change.entityKind.isCatalogKind {
                    snapshot.pendingCatalogChangeCount += 1
                } else if change.entityKind == .productPrice {
                    snapshot.pendingProductPriceChangeCount += 1
                } else if change.entityKind == .historySession {
                    snapshot.pendingHistorySessionChangeCount += 1
                }
            case .superseded:
                snapshot.supersededRetainedCount += 1
            case .acknowledged:
                continue
            }
        }
        snapshot.pendingHistorySessionChangeCount = max(
            snapshot.pendingHistorySessionChangeCount,
            try dirtyHistorySessionCount()
        )
        return snapshot
    }

    private func dirtyHistorySessionCount() throws -> Int {
        let descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try context.fetch(descriptor).filter(\.isHistorySessionDirtyForCloud).count
    }
}

@MainActor
protocol SupabaseManualSyncLocalPendingChangeCounting: AnyObject {
    func pendingLocalChangeSnapshot(ownerUserID: UUID) async throws -> LocalPendingChangeSnapshot
}

@MainActor
final class LocalPendingChangePendingAdapter:
    SupabaseManualSyncCatalogPendingCounting,
    SupabaseManualSyncProductPricePendingCounting,
    SupabaseManualSyncLocalPendingChangeCounting
{
    private let provider: LocalPendingChangeSnapshotProvider

    init(context: ModelContext) {
        self.provider = LocalPendingChangeSnapshotProvider(context: context)
    }

    func pendingLocalChangeSnapshot(ownerUserID: UUID) async throws -> LocalPendingChangeSnapshot {
        try Task.checkCancellation()
        return try provider.loadSnapshot(ownerUserID: ownerUserID)
    }

    func pendingCatalogChangeCount(ownerUserID: UUID) async throws -> Int {
        let snapshot = try await pendingLocalChangeSnapshot(ownerUserID: ownerUserID)
        return snapshot.pendingCatalogChangeCount
    }

    func pendingProductPriceChangeCount(ownerUserID: UUID) async throws -> Int {
        let snapshot = try await pendingLocalChangeSnapshot(ownerUserID: ownerUserID)
        return snapshot.pendingProductPriceChangeCount
    }
}

nonisolated enum LocalPendingChangeLogicalKey {
    static func product(remoteID: UUID?, barcode: String) -> String {
        if let remoteID {
            return remoteEntity(kind: .product, remoteID: remoteID)
        }
        return "product:local:\(privacyHash(normalize(barcode)))"
    }

    static func supplier(remoteID: UUID?, name: String) -> String {
        if let remoteID {
            return remoteEntity(kind: .supplier, remoteID: remoteID)
        }
        return "supplier:local:\(privacyHash(normalize(name)))"
    }

    static func category(remoteID: UUID?, name: String) -> String {
        if let remoteID {
            return remoteEntity(kind: .productCategory, remoteID: remoteID)
        }
        return "category:local:\(privacyHash(normalize(name)))"
    }

    static func productPrice(
        productRemoteID: UUID?,
        productBarcode: String,
        type: PriceType,
        effectiveAt: Date
    ) -> String {
        let productPart: String
        if let productRemoteID {
            productPart = "remote:\(productRemoteID.uuidString.lowercased())"
        } else {
            productPart = "local:\(privacyHash(normalize(productBarcode)))"
        }
        let effectiveAtKey = effectiveAtMicrosecondKey(effectiveAt)
        return "price:\(privacyHash("\(productPart)|\(type.rawValue)|\(effectiveAtKey)"))"
    }

    static func historySession(remoteID: UUID?, uid: UUID) -> String {
        if let remoteID {
            return remoteEntity(kind: .historySession, remoteID: remoteID)
        }
        return "history:local:\(privacyHash(uid.uuidString.lowercased()))"
    }

    static func remoteEntity(
        kind: LocalPendingChangeEntityKind,
        remoteID: UUID
    ) -> String {
        "\(kind.rawValue):remote:\(remoteID.uuidString.lowercased())"
    }

    static func productFingerprintHash(_ product: Product) -> String {
        privacyHash(
            ManualPushFingerprintNormalizer.product(
                barcode: product.barcode,
                itemNumber: product.itemNumber,
                productName: product.productName,
                secondProductName: product.secondProductName,
                purchasePrice: product.purchasePrice,
                retailPrice: product.retailPrice,
                stockQuantity: product.stockQuantity,
                supplierRemoteID: product.supplier?.remoteID,
                categoryRemoteID: product.category?.remoteID
            ).canonicalString
        )
    }

    static func productFingerprintHash(_ draft: ProductDraft) -> String {
        privacyHash(
            ManualPushFingerprintNormalizer.product(
                barcode: draft.barcode,
                itemNumber: draft.itemNumber,
                productName: draft.productName,
                secondProductName: draft.secondProductName,
                purchasePrice: draft.purchasePrice,
                retailPrice: draft.retailPrice,
                stockQuantity: draft.stockQuantity,
                supplierRemoteID: nil,
                categoryRemoteID: nil
            ).canonicalString
        )
    }

    static func supplierFingerprintHash(_ supplier: Supplier) -> String {
        privacyHash(
            ManualPushFingerprintNormalizer.supplier(name: supplier.name).canonicalString
        )
    }

    static func categoryFingerprintHash(_ category: ProductCategory) -> String {
        privacyHash(
            ManualPushFingerprintNormalizer.category(name: category.name).canonicalString
        )
    }

    static func productPriceFingerprintHash(_ price: ProductPrice) -> String {
        privacyHash(
            [
                price.product?.remoteID?.uuidString.lowercased() ?? privacyHash(normalize(price.product?.barcode ?? "")),
                price.type.rawValue,
                effectiveAtMicrosecondKey(price.effectiveAt),
                String(price.price)
            ].joined(separator: "|")
        )
    }

    static func privacyHash(_ rawValue: String) -> String {
        let digest = SHA256.hash(data: Data(rawValue.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func effectiveAtMicrosecondKey(_ date: Date) -> String {
        String(Int64((date.timeIntervalSince1970 * 1_000_000).rounded()))
    }
}

private extension Array where Element == String {
    func uniquedSorted() -> [String] {
        Array(Set(self)).sorted()
    }
}
