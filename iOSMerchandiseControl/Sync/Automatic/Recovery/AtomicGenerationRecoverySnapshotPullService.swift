import CryptoKit
import Foundation
import SwiftData

private nonisolated final class AtomicRecoveryDefaultsBox: @unchecked Sendable {
    let value: UserDefaults

    init(_ value: UserDefaults) {
        self.value = value
    }
}

private nonisolated final class AtomicRecoveryStagingState: @unchecked Sendable {
    let baselineRunID = UUID()
    var supplierModelIDs: [UUID: PersistentIdentifier] = [:]
    var categoryModelIDs: [UUID: PersistentIdentifier] = [:]
    var productModelIDs: [UUID: PersistentIdentifier] = [:]
    var tombstonedProductIDs: Set<UUID> = []
    var expectedImageRelationships: [UUID: ImageRelationship] = [:]
    var supplierMaterializationProof = AtomicRecoveryProofAccumulator()
    var categoryMaterializationProof = AtomicRecoveryProofAccumulator()
    var productMaterializationProof = AtomicRecoveryProofAccumulator()
    var priceMaterializationProof = AtomicRecoveryProofAccumulator()
    var historyMaterializationProof = AtomicRecoveryProofAccumulator()
    var supplierBaselineProof = AtomicRecoveryProofAccumulator()
    var categoryBaselineProof = AtomicRecoveryProofAccumulator()
    var productBaselineProof = AtomicRecoveryProofAccumulator()

    nonisolated struct ImageRelationship: Equatable, Sendable {
        let versionID: UUID
        let isTombstone: Bool
    }
}

private nonisolated struct AtomicRecoveryProofReceipt: Equatable, Sendable {
    let count: Int
    let digest: String
}

private nonisolated struct AtomicRecoveryProofAccumulator: Sendable {
    private var hasher = SHA256()
    private var count = 0
    private var previousOrderingID: String?

    mutating func append(orderingID: UUID, proof: String) throws {
        let id = orderingID.uuidString.lowercased()
        guard previousOrderingID.map({ $0 < id }) ?? true,
              proof.count == 64,
              proof.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID
        }
        if count > 0 { hasher.update(data: Data("\n".utf8)) }
        hasher.update(data: Data(
            ShopSyncRecoveryCanonical.joined(id, proof).utf8
        ))
        count += 1
        previousOrderingID = id
    }

    mutating func finalize() -> AtomicRecoveryProofReceipt {
        AtomicRecoveryProofReceipt(
            count: count,
            digest: hasher.finalize().map { String(format: "%02x", $0) }.joined()
        )
    }
}

private nonisolated enum AtomicRecoveryMaterializationProof {
    static func hash(_ parts: [String?]) -> String {
        let canonical = parts.map { value -> String in
            guard let value else { return "-1:" }
            return "\(value.utf8.count):\(value)"
        }.joined(separator: "|")
        return ShopSyncRecoveryCanonical.sha256(canonical)
    }

    static func uuid(_ value: UUID?) -> String? {
        value?.uuidString.lowercased()
    }

    static func date(_ value: Date?) -> String? {
        value.map { String($0.timeIntervalSinceReferenceDate.bitPattern, radix: 16) }
    }

    static func number(_ value: Double?) -> String? {
        value.map { String($0.bitPattern, radix: 16) }
    }

    static func data(_ value: Data?) -> String? {
        value.map {
            SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()
        }
    }
}

/// Full recovery implementation used by production automatic sync. Remote
/// pages are persisted in a separate SwiftData generation and a redacted
/// ledger. The active generation is never mutated; the only publication point
/// is the atomic manifest rename performed by `SyncStoreGenerationRepository`.
actor AtomicGenerationRecoverySnapshotPullService: SyncRecoverySnapshotPullProviding {
    nonisolated let publicationMode = SyncRecoverySnapshotPublicationMode.atomicGeneration

    private let storeGenerationController: SyncStoreGenerationController
    private let recoveryRemote: ShopSyncRecoveryRemoteAdapter
    private let defaultsBox: AtomicRecoveryDefaultsBox
    private let pageLimit: Int
    private let maximumAttempts: Int

    init(
        storeGenerationController: SyncStoreGenerationController,
        recoveryRemote: ShopSyncRecoveryRemoteAdapter,
        defaults: UserDefaults = .standard,
        pageLimit: Int = 250,
        maximumAttempts: Int = 2
    ) {
        self.storeGenerationController = storeGenerationController
        self.recoveryRemote = recoveryRemote
        self.defaultsBox = AtomicRecoveryDefaultsBox(defaults)
        self.pageLimit = max(1, min(pageLimit, 250))
        self.maximumAttempts = max(1, min(maximumAttempts, 2))
    }

    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary {
        // One budget covers checkpoint A, every page, bounded retry, B and C.
        // Reset only for a new top-level invocation so a changing checkpoint
        // cannot multiply the allowed network/memory footprint.
        await recoveryRemote.resetResourceBudget()
        var scope = try ensureRecoveryJournal(ownerUserID: ownerUserID)
        if let resumed = try await completeActivatedGenerationIfPossible(
            ownerUserID: ownerUserID,
            scope: scope
        ) {
            return resumed
        }
        // Metadata repair in the resume path invalidates the process-wide
        // owner/shop lease. Never carry the pre-repair token into a new
        // staging attempt.
        scope = try captureRecoveryScope(ownerUserID: ownerUserID)
        try validateJournal(scope: scope)
        try await requireDrainedActiveStoreForSameScopeRecovery(scope: scope)

        var lastCheckpointError: Error?
        for attempt in 1...maximumAttempts {
            var staging: SyncStoreGenerationHandle?
            var ledger: ShopSyncRecoveryLedger?
            var manifestActivated = false
            do {
                scope = try captureRecoveryScope(ownerUserID: ownerUserID)
                try validateJournal(scope: scope)
                let checkpointA = try await recoveryRemote.checkpoint(
                    ownerUserID: ownerUserID,
                    scope: scope
                )
                try revalidate(scope, ownerUserID: ownerUserID)

                let prepared = try await storeGenerationController.prepareStaging(
                    accountHash: scope.accountHash,
                    shopID: scope.shopID,
                    storeIdentity: scope.storeIdentity,
                    deviceIdentityHash: scope.deviceIdentityHash
                )
                staging = prepared
                let bindingStore = AccountBindingStore(defaults: defaultsBox.value)
                guard bindingStore.recordPendingRecoveryStaging(
                    accountHash: scope.accountHash,
                    storeIdentity: scope.storeIdentity,
                    deviceIdentityHash: scope.deviceIdentityHash,
                    generationID: prepared.generationID,
                    scope: scope
                ) else {
                    throw AtomicGenerationRecoveryError.journalTransitionRejected
                }
                scope = try captureRecoveryScope(ownerUserID: ownerUserID)
                try await storeGenerationController.resetStaging(prepared)
                let persistedLedger = try ShopSyncRecoveryLedger(
                    generationStoreURL: prepared.storeURL
                )
                ledger = persistedLedger
                let state = AtomicRecoveryStagingState()
                try createBaselineRun(
                    state: state,
                    container: prepared.container,
                    ownerUserID: ownerUserID,
                    scope: scope
                )

                try await stageSuppliers(
                    checkpoint: checkpointA,
                    ownerUserID: ownerUserID,
                    scope: scope,
                    staging: prepared,
                    ledger: persistedLedger,
                    state: state
                )
                try await stageCategories(
                    checkpoint: checkpointA,
                    ownerUserID: ownerUserID,
                    scope: scope,
                    staging: prepared,
                    ledger: persistedLedger,
                    state: state
                )
                try await stageProducts(
                    checkpoint: checkpointA,
                    ownerUserID: ownerUserID,
                    scope: scope,
                    staging: prepared,
                    ledger: persistedLedger,
                    state: state
                )
                state.supplierModelIDs.removeAll(keepingCapacity: false)
                state.categoryModelIDs.removeAll(keepingCapacity: false)
                try await stagePrices(
                    checkpoint: checkpointA,
                    ownerUserID: ownerUserID,
                    scope: scope,
                    staging: prepared,
                    ledger: persistedLedger,
                    state: state
                )
                state.productModelIDs.removeAll(keepingCapacity: false)
                try await stageHistory(
                    checkpoint: checkpointA,
                    ownerUserID: ownerUserID,
                    scope: scope,
                    staging: prepared,
                    ledger: persistedLedger,
                    state: state
                )
                try await stageImages(
                    checkpoint: checkpointA,
                    ownerUserID: ownerUserID,
                    scope: scope,
                    staging: prepared,
                    ledger: persistedLedger,
                    state: state
                )
                // Product recovery deliberately strips the primary image
                // pointer from a product tombstone, while the image domain
                // retains a tombstone metadata row for the former primary
                // version. Keep the bounded tombstone identity set until
                // image rows have consumed that explicit tombstone semantic.
                state.tombstonedProductIDs.removeAll(keepingCapacity: false)
                try persistedLedger.closeWrites()
                let receipt = try persistedLedger.receipt(
                    relationshipViolationCount: 0,
                    pendingLocalCount: 0,
                    outboxCount: 0
                )
                // V6 recovery pages are deliberately live keyset reads.  A is
                // an admission/fence checkpoint, not a frozen row snapshot:
                // the staged receipt is compared only with B after every
                // domain has drained.  Requiring it to match A turns a valid
                // live page stream into a permanent false recovery failure.
                // Freeze the physical staged bytes before the next remote
                // boundary.  Checkpoint B and the event-tail proof must not
                // be allowed to hide a concurrent staging mutation by merely
                // recapturing a later fence.
                let stagingFenceBeforeCheckpointB = try await storeGenerationController
                    .captureMutationFence(for: prepared)
                try revalidate(scope, ownerUserID: ownerUserID)
                let checkpointB = try await recoveryRemote.checkpoint(
                    ownerUserID: ownerUserID,
                    scope: scope,
                    verifiedBaselineID: checkpointA.syncEvents.maxId,
                    expectedBaselineScopeKey: checkpointA.scope.key
                )
                guard Self.isMonotonicRecoveryFence(checkpointB, from: checkpointA),
                      receipt.matches(checkpointB) else {
                    throw ShopSyncRecoveryContractError.checkpointChanged
                }
                try await recoveryRemote.verifyTail(
                    ownerUserID: ownerUserID,
                    scope: scope,
                    from: checkpointA,
                    through: checkpointB
                )
                try revalidate(scope, ownerUserID: ownerUserID)
                try await storeGenerationController.validateMutationFence(
                    stagingFenceBeforeCheckpointB,
                    for: prepared
                )
                // Baseline metadata is published into the staging generation
                // only after B and its complete tail have proven the live
                // receipt.  It must therefore carry B's counts, never A's.
                try finishBaselineRun(
                    state: state,
                    checkpoint: checkpointB,
                    container: prepared.container,
                    scope: scope
                )
                try verifyPersistedStore(
                    state: state,
                    checkpoint: checkpointB,
                    container: prepared.container,
                    ownerUserID: ownerUserID
                )
                // Capture the physical generation fence after the final local
                // metadata write.  Marker is an async boundary; activation
                // compares this fence before publishing the pointer.
                let mutationFence = try await storeGenerationController
                    .captureMutationFence(for: prepared)
                try revalidate(scope, ownerUserID: ownerUserID)
                _ = try await recoveryRemote.marker(
                    ownerUserID: ownerUserID,
                    scope: scope,
                    baselineCheckpoint: checkpointB,
                    localVerification: receipt
                )
                try revalidate(scope, ownerUserID: ownerUserID)
                guard bindingStore.recordPendingRecoveryVerified(
                    accountHash: scope.accountHash,
                    storeIdentity: scope.storeIdentity,
                    deviceIdentityHash: scope.deviceIdentityHash,
                    generationID: prepared.generationID,
                    checkpointDigest: checkpointB.checkpointDigest,
                    watermark: checkpointB.maxEventID!,
                    baselineRunID: state.baselineRunID,
                    scope: scope
                ) else {
                    throw AtomicGenerationRecoveryError.journalTransitionRejected
                }
                scope = try captureRecoveryScope(ownerUserID: ownerUserID)
                guard let journal = bindingStore.pendingRecoveryJournal else {
                    throw AtomicGenerationRecoveryError.journalTransitionRejected
                }
                _ = try await storeGenerationController.activate(
                    prepared,
                    mutationFence: mutationFence,
                    checkpointBeforeDownload: checkpointA,
                    checkpoint: checkpointB,
                    localVerification: receipt,
                    baselineRunID: state.baselineRunID,
                    journal: journal,
                    scope: scope
                )
                manifestActivated = true

                scope = try captureRecoveryScope(ownerUserID: ownerUserID)
                try revalidate(scope, ownerUserID: ownerUserID)
                _ = try await storeGenerationController.markRecoveryFinalized(scope: scope)
                guard try bindingStore.completePendingReplacementRecovery(
                    accountHash: scope.accountHash,
                    storeIdentity: scope.storeIdentity,
                    expectedLeaseGeneration: scope.leaseGeneration
                ) else {
                    throw AtomicGenerationRecoveryError.journalCompletionRejected
                }

                return makeSummary(
                    checkpoint: checkpointB,
                    generationID: prepared.generationID
                )
            } catch is CancellationError {
                if let ledger { try? ledger.closeWrites() }
                await quarantineIfUnpublished(staging, manifestActivated: manifestActivated)
                throw CancellationError()
            } catch ShopSyncRecoveryContractError.checkpointChanged {
                if let ledger { try? ledger.closeWrites() }
                await quarantineIfUnpublished(staging, manifestActivated: manifestActivated)
                // The convergence marker is obtained before the pointer is
                // published.  A checkpoint failure after publication can no
                // longer be retried by treating a changed cloud as complete:
                // keep the durable journal and let the next bounded recovery
                // stage a fresh generation.
                if manifestActivated {
                    throw ShopSyncRecoveryContractError.checkpointChanged
                }
                lastCheckpointError = ShopSyncRecoveryContractError.checkpointChanged
                guard attempt < maximumAttempts else { break }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
            } catch {
                if let ledger { try? ledger.closeWrites() }
                await quarantineIfUnpublished(staging, manifestActivated: manifestActivated)
                throw error
            }
        }
        throw lastCheckpointError ?? ShopSyncRecoveryContractError.checkpointChanged
    }

    private func quarantineIfUnpublished(
        _ staging: SyncStoreGenerationHandle?,
        manifestActivated: Bool
    ) async {
        guard let staging, !manifestActivated else { return }
        // `activate` publishes the manifest and in-process container before it
        // repairs UserDefaults metadata. If that repair fails, the call throws
        // even though the generation is already durable and active. Never
        // quarantine that generation; the pending journal makes the next run
        // resume the idempotent metadata/checkpoint-C completion path.
        let isDurablyActive = await storeGenerationController.activeManifest?.generationID
            == staging.generationID
        guard !isDurablyActive else { return }
        await storeGenerationController.quarantine(staging)
    }

    private func ensureRecoveryJournal(
        ownerUserID: UUID
    ) throws -> Task126VerifiedOwnerStoreScope {
        let bindingStore = AccountBindingStore(defaults: defaultsBox.value)
        if bindingStore.hasPendingReplacementJournal {
            let scope = try captureRecoveryScope(ownerUserID: ownerUserID)
            try validateJournal(scope: scope)
            return scope
        }
        let current = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaultsBox.value
        )
        guard bindingStore.beginSameScopeRecovery(
            accountHash: current.accountHash,
            storeIdentity: current.storeIdentity,
            reason: "automatic_full_recovery",
            deviceIdentityHash: current.deviceIdentityHash
        ) else {
            throw AtomicGenerationRecoveryError.journalTransitionRejected
        }
        return try captureRecoveryScope(ownerUserID: ownerUserID)
    }

    private func completeActivatedGenerationIfPossible(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) async throws -> SyncRecoverySnapshotPullSummary? {
        let bindingStore = AccountBindingStore(defaults: defaultsBox.value)
        guard let journal = bindingStore.pendingRecoveryJournal,
              let manifest = await storeGenerationController.activeManifest,
              journal.generationID == manifest.generationID,
              journal.checkpointDigest == manifest.checkpoint.checkpointDigest,
              journal.watermark == manifest.checkpoint.maxEventID,
              journal.baselineRunID == manifest.baselineRunID,
              journal.phase == .verified || journal.phase == .activated else {
            return nil
        }
        let isAlreadyFinalized = try await storeGenerationController
            .isActiveRecoveryFinalized(scope: scope)
        _ = try await storeGenerationController.restoreActivatedMetadataIfAuthorized(scope: scope)
        let refreshedScope = try captureRecoveryScope(ownerUserID: ownerUserID)
        if isAlreadyFinalized {
            guard try bindingStore.completePendingReplacementRecovery(
                accountHash: refreshedScope.accountHash,
                storeIdentity: refreshedScope.storeIdentity,
                expectedLeaseGeneration: refreshedScope.leaseGeneration
            ) else {
                throw AtomicGenerationRecoveryError.journalCompletionRejected
            }
            return makeSummary(
                checkpoint: manifest.checkpoint,
                generationID: manifest.generationID
            )
        }
        _ = try await recoveryRemote.marker(
            ownerUserID: ownerUserID,
            scope: refreshedScope,
            baselineCheckpoint: manifest.checkpoint,
            localVerification: manifest.localVerification
        )
        try revalidate(refreshedScope, ownerUserID: ownerUserID)
        _ = try await storeGenerationController.markRecoveryFinalized(scope: refreshedScope)
        guard try bindingStore.completePendingReplacementRecovery(
            accountHash: refreshedScope.accountHash,
            storeIdentity: refreshedScope.storeIdentity,
            expectedLeaseGeneration: refreshedScope.leaseGeneration
        ) else {
            throw AtomicGenerationRecoveryError.journalCompletionRejected
        }
        return makeSummary(checkpoint: manifest.checkpoint, generationID: manifest.generationID)
    }

    private nonisolated static func isMonotonicAdvance(
        _ candidate: ShopSyncRecoveryCheckpoint,
        from previous: ShopSyncRecoveryCheckpoint
    ) -> Bool {
        guard candidate.schemaVersion == previous.schemaVersion,
              candidate.shopId == previous.shopId,
              candidate.scope == previous.scope,
              let candidateEventID = candidate.maxEventID,
              let previousEventID = previous.maxEventID else { return false }
        return candidateEventID > previousEventID
    }

    private nonisolated static func isMonotonicRecoveryFence(
        _ candidate: ShopSyncRecoveryCheckpoint,
        from previous: ShopSyncRecoveryCheckpoint
    ) -> Bool {
        guard candidate.schemaVersion == previous.schemaVersion,
              candidate.status == "ready",
              candidate.shopId == previous.shopId,
              candidate.scope == previous.scope,
              let candidateEventID = candidate.maxEventID,
              let previousEventID = previous.maxEventID,
              candidateEventID >= previousEventID,
              let candidateCatalog = try? ShopSyncRecoveryCanonical.eventID(
                candidate.syncEvents.domainMaxIds.catalog
              ),
              let previousCatalog = try? ShopSyncRecoveryCanonical.eventID(
                previous.syncEvents.domainMaxIds.catalog
              ),
              let candidatePrices = try? ShopSyncRecoveryCanonical.eventID(
                candidate.syncEvents.domainMaxIds.prices
              ),
              let previousPrices = try? ShopSyncRecoveryCanonical.eventID(
                previous.syncEvents.domainMaxIds.prices
              ),
              let candidateHistory = try? ShopSyncRecoveryCanonical.eventID(
                candidate.syncEvents.domainMaxIds.history
              ),
              let previousHistory = try? ShopSyncRecoveryCanonical.eventID(
                previous.syncEvents.domainMaxIds.history
              ),
              candidateCatalog >= previousCatalog,
              candidatePrices >= previousPrices,
              candidateHistory >= previousHistory else {
            return false
        }
        return true
    }

    private func requireDrainedActiveStoreForSameScopeRecovery(
        scope: Task126VerifiedOwnerStoreScope
    ) async throws {
        let bindingStore = AccountBindingStore(defaults: defaultsBox.value)
        guard bindingStore.pendingRecoveryJournal?.mode == .sameScopeRecovery else {
            return
        }
        let activeContainer = await storeGenerationController.modelContainer
        let defaults = defaultsBox.value
        try await Task.detached(priority: .utility) {
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                guard try SameScopeRecoveryActiveWorkInspector.snapshot(
                    container: activeContainer,
                    scope: scope
                ).isDrained else {
                    throw AtomicGenerationRecoveryError.pendingLocalWorkRequiresDrain
                }
            }
        }.value
    }

    private func stageSuppliers(
        checkpoint: ShopSyncRecoveryCheckpoint,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        staging: SyncStoreGenerationHandle,
        ledger: ShopSyncRecoveryLedger,
        state: AtomicRecoveryStagingState
    ) async throws {
        try await streamPages(
            RemoteInventorySupplierRow.self,
            domain: .suppliers,
            staging: staging,
            ownerUserID: ownerUserID,
            scope: scope,
            checkpoint: checkpoint,
            orderingID: \.id,
            ledger: ledger,
            makeRecord: ShopSyncRecoveryRowContract.supplier
        ) { rows in
            try self.persistSuppliers(
                rows,
                state: state,
                container: staging.container,
                ownerUserID: ownerUserID,
                scope: scope
            )
        }
    }

    private func stageCategories(
        checkpoint: ShopSyncRecoveryCheckpoint,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        staging: SyncStoreGenerationHandle,
        ledger: ShopSyncRecoveryLedger,
        state: AtomicRecoveryStagingState
    ) async throws {
        try await streamPages(
            RemoteInventoryCategoryRow.self,
            domain: .categories,
            staging: staging,
            ownerUserID: ownerUserID,
            scope: scope,
            checkpoint: checkpoint,
            orderingID: \.id,
            ledger: ledger,
            makeRecord: ShopSyncRecoveryRowContract.category
        ) { rows in
            try self.persistCategories(
                rows,
                state: state,
                container: staging.container,
                ownerUserID: ownerUserID,
                scope: scope
            )
        }
    }

    private func stageProducts(
        checkpoint: ShopSyncRecoveryCheckpoint,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        staging: SyncStoreGenerationHandle,
        ledger: ShopSyncRecoveryLedger,
        state: AtomicRecoveryStagingState
    ) async throws {
        try await streamPages(
            RemoteInventoryProductRow.self,
            domain: .products,
            staging: staging,
            ownerUserID: ownerUserID,
            scope: scope,
            checkpoint: checkpoint,
            orderingID: \.id,
            ledger: ledger,
            makeRecord: ShopSyncRecoveryRowContract.product
        ) { rows in
            try self.persistProducts(
                rows,
                state: state,
                container: staging.container,
                ownerUserID: ownerUserID,
                scope: scope
            )
        }
    }

    private func stagePrices(
        checkpoint: ShopSyncRecoveryCheckpoint,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        staging: SyncStoreGenerationHandle,
        ledger: ShopSyncRecoveryLedger,
        state: AtomicRecoveryStagingState
    ) async throws {
        try await streamPages(
            RemoteInventoryProductPriceRow.self,
            domain: .prices,
            staging: staging,
            ownerUserID: ownerUserID,
            scope: scope,
            checkpoint: checkpoint,
            orderingID: \.id,
            ledger: ledger,
            makeRecord: ShopSyncRecoveryRowContract.price
        ) { rows in
            try self.persistPrices(rows, state: state, container: staging.container, scope: scope)
        }
    }

    private func stageHistory(
        checkpoint: ShopSyncRecoveryCheckpoint,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        staging: SyncStoreGenerationHandle,
        ledger: ShopSyncRecoveryLedger,
        state: AtomicRecoveryStagingState
    ) async throws {
        try await streamPages(
            RemoteSharedSheetSessionRow.self,
            domain: .history,
            staging: staging,
            ownerUserID: ownerUserID,
            scope: scope,
            checkpoint: checkpoint,
            orderingID: \.remoteID,
            ledger: ledger,
            makeRecord: ShopSyncRecoveryRowContract.history
        ) { rows in
            try self.persistHistory(rows, state: state, container: staging.container, scope: scope)
        }
    }

    private func stageImages(
        checkpoint: ShopSyncRecoveryCheckpoint,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        staging: SyncStoreGenerationHandle,
        ledger: ShopSyncRecoveryLedger,
        state: AtomicRecoveryStagingState
    ) async throws {
        try await streamPages(
            ShopSyncRecoveryImageRow.self,
            domain: .images,
            staging: staging,
            ownerUserID: ownerUserID,
            scope: scope,
            checkpoint: checkpoint,
            orderingID: \.productID,
            ledger: ledger,
            makeRecord: ShopSyncRecoveryRowContract.image
        ) { rows in
            for row in rows {
                if let expected = state.expectedImageRelationships.removeValue(
                    forKey: row.productID
                ) {
                    guard expected == .init(
                        versionID: row.versionID,
                        isTombstone: row.productDeletedAt != nil
                    ) else {
                        throw ShopSyncRecoveryContractError.relationViolation
                    }
                    continue
                }

                // `sync_product_recovery_row_v1` intentionally strips
                // primary_image_version_id from product tombstones. The image
                // checkpoint remains authoritative for an existing ready
                // version and represents it as an image-domain tombstone.
                // It is safe only for a product tombstone that was seen in
                // this same scoped snapshot; it must never become an active
                // product/image association or permit an unknown image row.
                guard row.productDeletedAt != nil,
                      state.tombstonedProductIDs.contains(row.productID) else {
                    throw ShopSyncRecoveryContractError.relationViolation
                }
            }
        }
        guard state.expectedImageRelationships.isEmpty else {
            throw ShopSyncRecoveryContractError.relationViolation
        }
    }

    private func streamPages<Row: Decodable & Sendable>(
        _ rowType: Row.Type,
        domain: ShopSyncRecoveryDomain,
        staging: SyncStoreGenerationHandle,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        checkpoint: ShopSyncRecoveryCheckpoint,
        orderingID: KeyPath<Row, UUID>,
        ledger: ShopSyncRecoveryLedger,
        makeRecord: (Row, ShopSyncRecoveryCheckpoint) throws -> ShopSyncRecoveryLedgerRecord,
        consume: ([Row]) throws -> Void
    ) async throws {
        var afterID: String?
        var previousID: String?
        var processed = 0
        var pages = 0
        var effectivePageLimit: Int?
        while true {
            pages += 1
            try Task.checkCancellation()
            try revalidate(scope, ownerUserID: ownerUserID)
            let page = try await recoveryRemote.page(
                rowType,
                domain: domain,
                afterID: afterID,
                limit: pageLimit,
                ownerUserID: ownerUserID,
                scope: scope,
                checkpoint: checkpoint
            )
            try revalidate(scope, ownerUserID: ownerUserID)
            if let effectivePageLimit {
                guard page.pageLimit == effectivePageLimit else {
                    throw ShopSyncRecoveryContractError.invalidPage(domain: domain)
                }
            } else {
                effectivePageLimit = page.pageLimit
            }
            // The V6 server intentionally serves live keyset pages while
            // enforcing A's monotonic event/domain fences.  Use only the
            // documented hard resource ceiling here; B plus the persisted
            // receipt is the sole count/digest publication proof.
            let maximumRows = ShopSyncRecoveryLimits.maximumRows(for: domain)
            let maximumPages = ((maximumRows - 1) / page.pageLimit) + 1
            guard pages <= maximumPages else {
                throw ShopSyncRecoveryContractError.pageBudgetExceeded(domain: domain)
            }

            var pageLastID: String?
            for row in page.rows {
                let id = row[keyPath: orderingID].uuidString.lowercased()
                guard previousID.map({ $0 < id }) ?? true else {
                    throw ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID
                }
                let record = try makeRecord(row, checkpoint)
                guard record.orderingID == id else {
                    throw ShopSyncRecoveryContractError.invalidPage(domain: domain)
                }
                try ledger.append(record, domain: domain)
                previousID = id
                pageLastID = id
                processed += 1
                guard processed <= maximumRows else {
                    throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
                }
            }
            try consume(page.rows)
            try await storeGenerationController.validateResourceBudget(staging)

            if page.hasMore {
                // A non-terminal backend page is contractually full. Reject a
                // one-row/hasMore stream immediately instead of permitting an
                // attacker to consume the row budget as hundreds of thousands
                // of RPCs and SQLite saves.
                guard page.rows.count == page.pageLimit,
                      let pageLastID,
                      page.nextAfterId?.lowercased() == pageLastID else {
                    throw ShopSyncRecoveryContractError.invalidPage(domain: domain)
                }
                afterID = pageLastID
            } else {
                guard page.nextAfterId == nil else {
                    throw ShopSyncRecoveryContractError.countMismatch(domain: domain)
                }
                return
            }
        }
    }

    private func createBaselineRun(
        state: AtomicRecoveryStagingState,
        container: ModelContainer,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        context.insert(SupabaseCatalogBaselineRun(
            baselineRunID: state.baselineRunID,
            ownerUserUUID: ownerUserID,
            status: .building
        ))
        try save(context, scope: scope)
    }

    private func persistSuppliers(
        _ rows: [RemoteInventorySupplierRow],
        state: AtomicRecoveryStagingState,
        container: ModelContainer,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var inserted: [(UUID, Supplier)] = []
        for row in rows {
            let updatedAt = try requiredDate(row.updatedAt)
            let deletedAt = try optionalDate(row.deletedAt)
            if deletedAt == nil {
                let supplier = Supplier(
                    name: row.name,
                    remoteID: row.id,
                    remoteUpdatedAt: updatedAt
                )
                context.insert(supplier)
                inserted.append((row.id, supplier))
                try state.supplierMaterializationProof.append(
                    orderingID: row.id,
                    proof: AtomicRecoveryMaterializationProof.hash([
                    AtomicRecoveryMaterializationProof.uuid(row.id),
                    row.name,
                    AtomicRecoveryMaterializationProof.date(updatedAt),
                    nil
                    ])
                )
            }
            let fingerprint = ManualPushFingerprintNormalizer.supplier(
                remoteID: row.id,
                name: row.name
            ).canonicalString
            let lookupName = SupabasePullPreviewNormalizer.normalizedLookupName(row.name)
            try state.supplierBaselineProof.append(
                orderingID: row.id,
                proof: baselineMaterializationProof(
                    baselineRunID: state.baselineRunID,
                    ownerUserID: ownerUserID,
                    entityType: .supplier,
                    remoteID: row.id,
                    remoteUpdatedAt: updatedAt,
                    remoteDeletedAt: deletedAt,
                    localModelID: nil,
                    fingerprintCanonical: fingerprint,
                    barcodeCanonical: nil,
                    lookupNameCanonical: lookupName
                )
            )
            context.insert(SupabaseCatalogBaselineRecord(
                baselineRunID: state.baselineRunID,
                ownerUserUUID: ownerUserID,
                entityType: .supplier,
                remoteID: row.id,
                remoteUpdatedAt: updatedAt,
                remoteDeletedAt: deletedAt,
                fingerprintCanonical: fingerprint,
                barcodeCanonical: nil,
                lookupNameCanonical: lookupName
            ))
        }
        try save(context, scope: scope)
        for (id, model) in inserted { state.supplierModelIDs[id] = model.persistentModelID }
    }

    private func persistCategories(
        _ rows: [RemoteInventoryCategoryRow],
        state: AtomicRecoveryStagingState,
        container: ModelContainer,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var inserted: [(UUID, ProductCategory)] = []
        for row in rows {
            let updatedAt = try requiredDate(row.updatedAt)
            let deletedAt = try optionalDate(row.deletedAt)
            if deletedAt == nil {
                let category = ProductCategory(
                    name: row.name,
                    remoteID: row.id,
                    remoteUpdatedAt: updatedAt
                )
                context.insert(category)
                inserted.append((row.id, category))
                try state.categoryMaterializationProof.append(
                    orderingID: row.id,
                    proof: AtomicRecoveryMaterializationProof.hash([
                    AtomicRecoveryMaterializationProof.uuid(row.id),
                    row.name,
                    AtomicRecoveryMaterializationProof.date(updatedAt),
                    nil
                    ])
                )
            }
            let fingerprint = ManualPushFingerprintNormalizer.category(
                remoteID: row.id,
                name: row.name
            ).canonicalString
            let lookupName = SupabasePullPreviewNormalizer.normalizedLookupName(row.name)
            try state.categoryBaselineProof.append(
                orderingID: row.id,
                proof: baselineMaterializationProof(
                    baselineRunID: state.baselineRunID,
                    ownerUserID: ownerUserID,
                    entityType: .productCategory,
                    remoteID: row.id,
                    remoteUpdatedAt: updatedAt,
                    remoteDeletedAt: deletedAt,
                    localModelID: nil,
                    fingerprintCanonical: fingerprint,
                    barcodeCanonical: nil,
                    lookupNameCanonical: lookupName
                )
            )
            context.insert(SupabaseCatalogBaselineRecord(
                baselineRunID: state.baselineRunID,
                ownerUserUUID: ownerUserID,
                entityType: .productCategory,
                remoteID: row.id,
                remoteUpdatedAt: updatedAt,
                remoteDeletedAt: deletedAt,
                fingerprintCanonical: fingerprint,
                barcodeCanonical: nil,
                lookupNameCanonical: lookupName
            ))
        }
        try save(context, scope: scope)
        for (id, model) in inserted { state.categoryModelIDs[id] = model.persistentModelID }
    }

    private func persistProducts(
        _ rows: [RemoteInventoryProductRow],
        state: AtomicRecoveryStagingState,
        container: ModelContainer,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var inserted: [(UUID, Product)] = []
        for row in rows {
            let updatedAt = try requiredDate(row.updatedAt)
            let deletedAt = try optionalDate(row.deletedAt)
            guard deletedAt == nil || (
                row.supplierID == nil
                    && row.categoryID == nil
                    && row.primaryImageVersionID == nil
                    && row.primaryImageUpdatedAt == nil
            ) else {
                throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
            }
            let primaryUpdatedAt = try optionalDate(row.primaryImageUpdatedAt)
            if let primaryImageVersionID = row.primaryImageVersionID {
                guard state.expectedImageRelationships[row.id] == nil else {
                    throw ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID
                }
                state.expectedImageRelationships[row.id] = .init(
                    versionID: primaryImageVersionID,
                    isTombstone: false
                )
            }
            if deletedAt == nil {
                guard row.supplierID.map({ state.supplierModelIDs[$0] != nil }) ?? true,
                      row.categoryID.map({ state.categoryModelIDs[$0] != nil }) ?? true else {
                    throw ShopSyncRecoveryContractError.relationViolation
                }
                let supplier = try row.supplierID.map {
                    try model(Supplier.self, remoteID: $0, ids: state.supplierModelIDs, context: context)
                }
                let category = try row.categoryID.map {
                    try model(ProductCategory.self, remoteID: $0, ids: state.categoryModelIDs, context: context)
                }
                let product = Product(
                    barcode: row.barcode,
                    remoteID: row.id,
                    remoteUpdatedAt: updatedAt,
                    primaryImageVersionID: row.primaryImageVersionID,
                    primaryImageUpdatedAt: primaryUpdatedAt,
                    itemNumber: row.itemNumber,
                    productName: row.productName,
                    secondProductName: row.secondProductName,
                    purchasePrice: row.purchasePrice,
                    retailPrice: row.retailPrice,
                    stockQuantity: row.stockQuantity,
                    supplier: supplier,
                    category: category
                )
                context.insert(product)
                inserted.append((row.id, product))
                try state.productMaterializationProof.append(
                    orderingID: row.id,
                    proof: productMaterializationProof(
                        remoteID: row.id,
                        remoteUpdatedAt: updatedAt,
                        remoteDeletedAt: nil,
                        primaryImageVersionID: row.primaryImageVersionID,
                        primaryImageUpdatedAt: primaryUpdatedAt,
                        barcode: row.barcode,
                        itemNumber: row.itemNumber,
                        productName: row.productName,
                        secondProductName: row.secondProductName,
                        purchasePrice: row.purchasePrice,
                        retailPrice: row.retailPrice,
                        stockQuantity: row.stockQuantity,
                        supplierID: row.supplierID,
                        categoryID: row.categoryID
                    )
                )
            } else {
                state.tombstonedProductIDs.insert(row.id)
            }
            let fingerprint = ManualPushFingerprintNormalizer.product(
                barcode: row.barcode,
                itemNumber: row.itemNumber,
                productName: row.productName,
                secondProductName: row.secondProductName,
                purchasePrice: row.purchasePrice,
                retailPrice: row.retailPrice,
                stockQuantity: row.stockQuantity,
                supplierRemoteID: row.supplierID,
                categoryRemoteID: row.categoryID
            ).canonicalString
            let barcode = ManualPushFingerprintNormalizer.semanticString(row.barcode)
            try state.productBaselineProof.append(
                orderingID: row.id,
                proof: baselineMaterializationProof(
                    baselineRunID: state.baselineRunID,
                    ownerUserID: ownerUserID,
                    entityType: .product,
                    remoteID: row.id,
                    remoteUpdatedAt: updatedAt,
                    remoteDeletedAt: deletedAt,
                    localModelID: nil,
                    fingerprintCanonical: fingerprint,
                    barcodeCanonical: barcode,
                    lookupNameCanonical: nil
                )
            )
            context.insert(SupabaseCatalogBaselineRecord(
                baselineRunID: state.baselineRunID,
                ownerUserUUID: ownerUserID,
                entityType: .product,
                remoteID: row.id,
                remoteUpdatedAt: updatedAt,
                remoteDeletedAt: deletedAt,
                fingerprintCanonical: fingerprint,
                barcodeCanonical: barcode,
                lookupNameCanonical: nil
            ))
        }
        try save(context, scope: scope)
        for (id, model) in inserted { state.productModelIDs[id] = model.persistentModelID }
    }

    private func persistPrices(
        _ rows: [RemoteInventoryProductPriceRow],
        state: AtomicRecoveryStagingState,
        container: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        for row in rows {
            guard let normalizedType = SupabasePullPreviewNormalizer.normalizedPriceType(row.type),
                  let type = PriceType(rawValue: normalizedType),
                  let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.effectiveAt),
                  let createdAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.createdAt) else {
                throw ShopSyncRecoveryContractError.relationViolation
            }
            // The exact decimal supplied by the recovery RPC is also the
            // amount committed to the checkpoint ledger.  Do not recreate it
            // from JSON's binary Double here: a value such as 12.340 can have
            // a different textual representation after a floating-point
            // round-trip even though its server digest was valid.
            let amount = try ShopSyncRecoveryRowContract.canonicalPrice(row)
            guard state.productModelIDs[row.productID] != nil else {
                // The backend's append-only price domain includes prices whose
                // product parent is already tombstoned. The complete price row
                // was appended to the generation ledger before this callback,
                // so it still participates in count/digest convergence. It is
                // intentionally not materialized into SwiftData, where the
                // required active Product relationship cannot be represented.
                guard state.tombstonedProductIDs.contains(row.productID) else {
                    throw ShopSyncRecoveryContractError.relationViolation
                }
                continue
            }
            let product = try model(
                Product.self,
                remoteID: row.productID,
                ids: state.productModelIDs,
                context: context
            )
            context.insert(ProductPrice(
                remoteID: row.id,
                type: type,
                price: amount.doubleValue,
                effectiveAt: effectiveAt,
                source: row.source,
                note: row.note,
                createdAt: createdAt,
                product: product
            ))
            try state.priceMaterializationProof.append(
                orderingID: row.id,
                proof: priceMaterializationProof(
                    remoteID: row.id,
                    type: type,
                    price: amount.doubleValue,
                    effectiveAt: effectiveAt,
                    source: row.source,
                    note: row.note,
                    createdAt: createdAt,
                    productID: row.productID
                )
            )
        }
        try save(context, scope: scope)
    }

    private func persistHistory(
        _ rows: [RemoteSharedSheetSessionRow],
        state: AtomicRecoveryStagingState,
        container: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        for row in rows {
            let fullRowJSON = try JSONEncoder().encode(row)
            let dataJSON = try JSONEncoder().encode(row.data)
            let overlayJSON = try row.sessionOverlay.map { try JSONEncoder().encode($0) }
            guard dataJSON.count <= ShopSyncRecoveryLimits.maximumHistoryDataBytes,
                  overlayJSON.map({ $0.count <= HistorySessionPayloadCodec.maxOverlayBytes }) ?? true,
                  fullRowJSON.count <= ShopSyncRecoveryLimits.maximumHistoryRowPayloadBytes else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .history)
            }
            // Tombstones are represented by the persisted recovery ledger and
            // intentionally have no visible SwiftData row. Legacy payload
            // fields must not make an otherwise valid deletion unrecoverable.
            guard row.deletedAt == nil else { continue }
            guard row.payloadVersion > 0 else {
                throw ShopSyncRecoveryContractError.relationViolation
            }
            let complete = row.sessionOverlay?.complete ?? []
            let initialSummary = HistoryImportedGridSupport.initialSummary(forGrid: row.data)
            let summary = HistoryEntryRuntimeSummary.compute(from: row.data, complete: complete)
            let timestamp = try HistorySessionPayloadCodec.parseTimestampStrict(row.timestamp)
            let editable = row.sessionOverlay?.editable ?? []
            let editableJSON = try JSONEncoder().encode(editable)
            let completeJSON = try JSONEncoder().encode(complete)
            let remoteUpdatedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.updatedAt)
            let remoteFingerprint = HistorySessionPayloadCodec.fingerprintHash(for: row)
            let entry = HistoryEntry(
                id: row.remoteID.uuidString.lowercased(),
                timestamp: timestamp,
                isManualEntry: row.isManualEntry,
                data: row.data,
                originalDataJSON: dataJSON,
                editable: editable,
                complete: complete,
                supplier: row.supplier,
                category: row.category,
                totalItems: summary.totalItems,
                orderTotal: initialSummary.orderTotal,
                paymentTotal: summary.paymentTotal,
                missingItems: summary.missingItems,
                syncStatus: .syncedSuccessfully,
                uid: row.remoteID,
                remoteID: row.remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                remotePayloadFingerprint: remoteFingerprint,
                lastSyncedLocalRevision: 0,
                ownerUserID: scope.ownerUserID.uuidString.lowercased(),
                storeID: scope.storeIdentity.storeId,
                shopID: scope.shopID
            )
            entry.title = row.displayName
            context.insert(entry)
            try state.historyMaterializationProof.append(
                orderingID: row.remoteID,
                proof: historyMaterializationProof(
                    id: row.remoteID.uuidString.lowercased(),
                    timestamp: timestamp,
                    isManualEntry: row.isManualEntry,
                    dataJSON: dataJSON,
                    originalDataJSON: dataJSON,
                    editableJSON: editableJSON,
                    completeJSON: completeJSON,
                    hasPersistedJSONDecodeFault: false,
                    title: row.displayName,
                    supplier: row.supplier,
                    category: row.category,
                    totalItems: summary.totalItems,
                    orderTotal: initialSummary.orderTotal,
                    paymentTotal: summary.paymentTotal,
                    missingItems: summary.missingItems,
                    syncStatus: .syncedSuccessfully,
                    wasExported: false,
                    uid: row.remoteID,
                    remoteID: row.remoteID,
                    remoteUpdatedAt: remoteUpdatedAt,
                    remoteDeletedAt: nil,
                    remotePayloadFingerprint: remoteFingerprint,
                    localChangeRevision: 0,
                    lastSyncedLocalRevision: 0,
                    ownerUserID: scope.ownerUserID.uuidString.lowercased(),
                    storeID: scope.storeIdentity.storeId,
                    shopID: scope.shopID
                )
            )
        }
        try save(context, scope: scope)
    }

    private func finishBaselineRun(
        state: AtomicRecoveryStagingState,
        checkpoint: ShopSyncRecoveryCheckpoint,
        container: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let runID = state.baselineRunID
        let rows = try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRun>(
            predicate: #Predicate { $0.baselineRunID == runID }
        ))
        guard rows.count == 1, let run = rows.first else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        run.productCount = try total(checkpoint.catalog.products, domain: .products)
        run.supplierCount = try total(checkpoint.catalog.suppliers, domain: .suppliers)
        run.categoryCount = try total(checkpoint.catalog.categories, domain: .categories)
        run.tombstoneCount = checkpoint.catalog.products.tombstoneCount
            + checkpoint.catalog.suppliers.tombstoneCount
            + checkpoint.catalog.categories.tombstoneCount
        run.status = SupabaseCatalogBaselineStatus.valid.rawValue
        run.appliedAt = Date()
        run.updatedAt = run.appliedAt ?? Date()
        try save(context, scope: scope)
    }

    private func baselineMaterializationProof(
        baselineRunID: UUID,
        ownerUserID: UUID,
        fingerprintSchemaVersion: Int = SupabaseCatalogFingerprintSchema.currentVersion,
        entityType: SupabaseCatalogBaselineEntityType,
        remoteID: UUID,
        remoteUpdatedAt: Date?,
        remoteDeletedAt: Date?,
        localModelID: String?,
        fingerprintCanonical: String,
        source: SupabaseCatalogBaselineSource = .fullPullApply,
        barcodeCanonical: String?,
        lookupNameCanonical: String?
    ) -> String {
        AtomicRecoveryMaterializationProof.hash([
            AtomicRecoveryMaterializationProof.uuid(baselineRunID),
            AtomicRecoveryMaterializationProof.uuid(ownerUserID),
            String(fingerprintSchemaVersion),
            entityType.rawValue,
            AtomicRecoveryMaterializationProof.uuid(remoteID),
            AtomicRecoveryMaterializationProof.date(remoteUpdatedAt),
            AtomicRecoveryMaterializationProof.date(remoteDeletedAt),
            localModelID,
            fingerprintCanonical,
            source.rawValue,
            barcodeCanonical,
            lookupNameCanonical
        ])
    }

    private func productMaterializationProof(
        remoteID: UUID?,
        remoteUpdatedAt: Date?,
        remoteDeletedAt: Date?,
        primaryImageVersionID: UUID?,
        primaryImageUpdatedAt: Date?,
        barcode: String,
        itemNumber: String?,
        productName: String?,
        secondProductName: String?,
        purchasePrice: Double?,
        retailPrice: Double?,
        stockQuantity: Double?,
        supplierID: UUID?,
        categoryID: UUID?
    ) -> String {
        AtomicRecoveryMaterializationProof.hash([
            AtomicRecoveryMaterializationProof.uuid(remoteID),
            AtomicRecoveryMaterializationProof.date(remoteUpdatedAt),
            AtomicRecoveryMaterializationProof.date(remoteDeletedAt),
            AtomicRecoveryMaterializationProof.uuid(primaryImageVersionID),
            AtomicRecoveryMaterializationProof.date(primaryImageUpdatedAt),
            barcode,
            itemNumber,
            productName,
            secondProductName,
            AtomicRecoveryMaterializationProof.number(purchasePrice),
            AtomicRecoveryMaterializationProof.number(retailPrice),
            AtomicRecoveryMaterializationProof.number(stockQuantity),
            AtomicRecoveryMaterializationProof.uuid(supplierID),
            AtomicRecoveryMaterializationProof.uuid(categoryID)
        ])
    }

    private func priceMaterializationProof(
        remoteID: UUID?,
        type: PriceType,
        price: Double,
        effectiveAt: Date,
        source: String?,
        note: String?,
        createdAt: Date,
        productID: UUID?
    ) -> String {
        AtomicRecoveryMaterializationProof.hash([
            AtomicRecoveryMaterializationProof.uuid(remoteID),
            type.rawValue,
            AtomicRecoveryMaterializationProof.number(price),
            AtomicRecoveryMaterializationProof.date(effectiveAt),
            source,
            note,
            AtomicRecoveryMaterializationProof.date(createdAt),
            AtomicRecoveryMaterializationProof.uuid(productID)
        ])
    }

    private func historyMaterializationProof(
        id: String,
        timestamp: Date,
        isManualEntry: Bool,
        dataJSON: Data?,
        originalDataJSON: Data?,
        editableJSON: Data?,
        completeJSON: Data?,
        hasPersistedJSONDecodeFault: Bool,
        title: String,
        supplier: String,
        category: String,
        totalItems: Int,
        orderTotal: Double,
        paymentTotal: Double,
        missingItems: Int,
        syncStatus: HistorySyncStatus,
        wasExported: Bool,
        uid: UUID,
        remoteID: UUID?,
        remoteUpdatedAt: Date?,
        remoteDeletedAt: Date?,
        remotePayloadFingerprint: String?,
        localChangeRevision: Int,
        lastSyncedLocalRevision: Int,
        ownerUserID: String?,
        storeID: String?,
        shopID: UUID?
    ) -> String {
        AtomicRecoveryMaterializationProof.hash([
            id,
            AtomicRecoveryMaterializationProof.date(timestamp),
            isManualEntry ? "1" : "0",
            AtomicRecoveryMaterializationProof.data(dataJSON),
            AtomicRecoveryMaterializationProof.data(originalDataJSON),
            AtomicRecoveryMaterializationProof.data(editableJSON),
            AtomicRecoveryMaterializationProof.data(completeJSON),
            hasPersistedJSONDecodeFault ? "1" : "0",
            title,
            supplier,
            category,
            String(totalItems),
            AtomicRecoveryMaterializationProof.number(orderTotal),
            AtomicRecoveryMaterializationProof.number(paymentTotal),
            String(missingItems),
            String(syncStatus.rawValue),
            wasExported ? "1" : "0",
            AtomicRecoveryMaterializationProof.uuid(uid),
            AtomicRecoveryMaterializationProof.uuid(remoteID),
            AtomicRecoveryMaterializationProof.date(remoteUpdatedAt),
            AtomicRecoveryMaterializationProof.date(remoteDeletedAt),
            remotePayloadFingerprint,
            String(localChangeRevision),
            String(lastSyncedLocalRevision),
            ownerUserID,
            storeID,
            AtomicRecoveryMaterializationProof.uuid(shopID)
        ])
    }

    private func verifyPersistedStore(
        state: AtomicRecoveryStagingState,
        checkpoint: ShopSyncRecoveryCheckpoint,
        container: ModelContainer,
        ownerUserID: UUID
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let expectedSupplierProof = state.supplierMaterializationProof.finalize()
        var actualSupplierProof = AtomicRecoveryProofAccumulator()
        let supplierCount = try forEachPersistedBatch(
            Supplier.self,
            container: container,
            sortBy: [SortDescriptor(\Supplier.remoteID)]
        ) { supplier in
            guard let id = supplier.remoteID else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            try actualSupplierProof.append(
                orderingID: id,
                proof: AtomicRecoveryMaterializationProof.hash([
                    AtomicRecoveryMaterializationProof.uuid(id),
                    supplier.name,
                    AtomicRecoveryMaterializationProof.date(supplier.remoteUpdatedAt),
                    AtomicRecoveryMaterializationProof.date(supplier.remoteDeletedAt)
                ])
            )
        }
        let expectedCategoryProof = state.categoryMaterializationProof.finalize()
        var actualCategoryProof = AtomicRecoveryProofAccumulator()
        let categoryCount = try forEachPersistedBatch(
            ProductCategory.self,
            container: container,
            sortBy: [SortDescriptor(\ProductCategory.remoteID)]
        ) { category in
            guard let id = category.remoteID else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            try actualCategoryProof.append(
                orderingID: id,
                proof: AtomicRecoveryMaterializationProof.hash([
                    AtomicRecoveryMaterializationProof.uuid(id),
                    category.name,
                    AtomicRecoveryMaterializationProof.date(category.remoteUpdatedAt),
                    AtomicRecoveryMaterializationProof.date(category.remoteDeletedAt)
                ])
            )
        }
        let expectedProductProof = state.productMaterializationProof.finalize()
        var actualProductProof = AtomicRecoveryProofAccumulator()
        let productCount = try forEachPersistedBatch(
            Product.self,
            container: container,
            sortBy: [SortDescriptor(\Product.remoteID)]
        ) { product in
            guard let id = product.remoteID,
                  product.remoteDeletedAt == nil else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            try actualProductProof.append(
                orderingID: id,
                proof: productMaterializationProof(
                    remoteID: id,
                    remoteUpdatedAt: product.remoteUpdatedAt,
                    remoteDeletedAt: product.remoteDeletedAt,
                    primaryImageVersionID: product.primaryImageVersionID,
                    primaryImageUpdatedAt: product.primaryImageUpdatedAt,
                    barcode: product.barcode,
                    itemNumber: product.itemNumber,
                    productName: product.productName,
                    secondProductName: product.secondProductName,
                    purchasePrice: product.purchasePrice,
                    retailPrice: product.retailPrice,
                    stockQuantity: product.stockQuantity,
                    supplierID: product.supplier?.remoteID,
                    categoryID: product.category?.remoteID
                )
            )
        }
        let expectedPriceProof = state.priceMaterializationProof.finalize()
        var actualPriceProof = AtomicRecoveryProofAccumulator()
        let priceCount = try forEachPersistedBatch(
            ProductPrice.self,
            container: container,
            sortBy: [SortDescriptor(\ProductPrice.remoteID)]
        ) { price in
            guard let id = price.remoteID,
                  let productID = price.product?.remoteID else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            try actualPriceProof.append(
                orderingID: id,
                proof: priceMaterializationProof(
                    remoteID: id,
                    type: price.type,
                    price: price.price,
                    effectiveAt: price.effectiveAt,
                    source: price.source,
                    note: price.note,
                    createdAt: price.createdAt,
                    productID: productID
                )
            )
        }
        let expectedHistoryProof = state.historyMaterializationProof.finalize()
        var actualHistoryProof = AtomicRecoveryProofAccumulator()
        let historyCount = try forEachPersistedBatch(
            HistoryEntry.self,
            container: container,
            sortBy: [SortDescriptor(\HistoryEntry.remoteID)]
        ) { entry in
            guard let id = entry.remoteID else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            try actualHistoryProof.append(
                orderingID: id,
                proof: historyMaterializationProof(
                    id: entry.id,
                    timestamp: entry.timestamp,
                    isManualEntry: entry.isManualEntry,
                    dataJSON: entry.dataJSON,
                    originalDataJSON: entry.originalDataJSON,
                    editableJSON: entry.editableJSON,
                    completeJSON: entry.completeJSON,
                    hasPersistedJSONDecodeFault: entry.hasPersistedJSONDecodeFault,
                    title: entry.title,
                    supplier: entry.supplier,
                    category: entry.category,
                    totalItems: entry.totalItems,
                    orderTotal: entry.orderTotal,
                    paymentTotal: entry.paymentTotal,
                    missingItems: entry.missingItems,
                    syncStatus: entry.syncStatus,
                    wasExported: entry.wasExported,
                    uid: entry.uid,
                    remoteID: entry.remoteID,
                    remoteUpdatedAt: entry.remoteUpdatedAt,
                    remoteDeletedAt: entry.remoteDeletedAt,
                    remotePayloadFingerprint: entry.remotePayloadFingerprint,
                    localChangeRevision: entry.localChangeRevision,
                    lastSyncedLocalRevision: entry.lastSyncedLocalRevision,
                    ownerUserID: entry.ownerUserID,
                    storeID: entry.storeID,
                    shopID: entry.shopID
                )
            )
        }
        guard supplierCount == expectedSupplierProof.count,
              actualSupplierProof.finalize() == expectedSupplierProof,
              categoryCount == expectedCategoryProof.count,
              actualCategoryProof.finalize() == expectedCategoryProof,
              productCount == expectedProductProof.count,
              actualProductProof.finalize() == expectedProductProof,
              priceCount == expectedPriceProof.count,
              actualPriceProof.finalize() == expectedPriceProof,
              historyCount == expectedHistoryProof.count,
              actualHistoryProof.finalize() == expectedHistoryProof,
              try context.fetchCount(FetchDescriptor<LocalPendingChange>()) == 0,
              try context.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()) == 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        guard state.expectedImageRelationships.isEmpty else {
            throw ShopSyncRecoveryContractError.relationViolation
        }
        let runID = state.baselineRunID
        let baselines = try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRun>(
            predicate: #Predicate { $0.baselineRunID == runID }
        ))
        let expectedSupplierBaseline = state.supplierBaselineProof.finalize()
        let expectedCategoryBaseline = state.categoryBaselineProof.finalize()
        let expectedProductBaseline = state.productBaselineProof.finalize()
        var actualSupplierBaseline = AtomicRecoveryProofAccumulator()
        var actualCategoryBaseline = AtomicRecoveryProofAccumulator()
        var actualProductBaseline = AtomicRecoveryProofAccumulator()
        let baselineRecordCount = try forEachPersistedBatch(
            SupabaseCatalogBaselineRecord.self,
            container: container,
            predicate: #Predicate { $0.baselineRunID == runID },
            sortBy: [SortDescriptor(\SupabaseCatalogBaselineRecord.recordKey)]
        ) { record in
            guard let entityType = SupabaseCatalogBaselineEntityType(rawValue: record.entityType) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            guard record.recordKey == SupabaseCatalogBaselineRecord.makeRecordKey(
                baselineRunID: runID,
                entityType: entityType,
                remoteID: record.remoteID
            ) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            let proof = baselineMaterializationProof(
                baselineRunID: record.baselineRunID,
                ownerUserID: record.ownerUserUUID,
                fingerprintSchemaVersion: record.fingerprintSchemaVersion,
                entityType: entityType,
                remoteID: record.remoteID,
                remoteUpdatedAt: record.remoteUpdatedAt,
                remoteDeletedAt: record.remoteDeletedAt,
                localModelID: record.localModelID,
                fingerprintCanonical: record.fingerprintCanonical,
                source: SupabaseCatalogBaselineSource(rawValue: record.source) ?? .fullPullApply,
                barcodeCanonical: record.barcodeCanonical,
                lookupNameCanonical: record.lookupNameCanonical
            )
            guard record.source == SupabaseCatalogBaselineSource.fullPullApply.rawValue else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            switch entityType {
            case .supplier:
                try actualSupplierBaseline.append(orderingID: record.remoteID, proof: proof)
            case .productCategory:
                try actualCategoryBaseline.append(orderingID: record.remoteID, proof: proof)
            case .product:
                try actualProductBaseline.append(orderingID: record.remoteID, proof: proof)
            }
        }
        let expectedBaselineCount = expectedSupplierBaseline.count
            + expectedCategoryBaseline.count
            + expectedProductBaseline.count
        guard baselines.count == 1,
              let baseline = baselines.first,
              baseline.ownerUserUUID == ownerUserID,
              baseline.runKey == SupabaseCatalogBaselineRun.makeRunKey(
                ownerUserUUID: ownerUserID,
                baselineRunID: runID
              ),
              baseline.fingerprintSchemaVersion == SupabaseCatalogFingerprintSchema.currentVersion,
              baseline.source == SupabaseCatalogBaselineSource.fullPullApply.rawValue,
              baseline.status == SupabaseCatalogBaselineStatus.valid.rawValue,
              baseline.appliedAt != nil,
              baselineRecordCount == expectedBaselineCount,
              actualSupplierBaseline.finalize() == expectedSupplierBaseline,
              actualCategoryBaseline.finalize() == expectedCategoryBaseline,
              actualProductBaseline.finalize() == expectedProductBaseline,
              baselineRecordCount == (try total(checkpoint.catalog.suppliers, domain: .suppliers))
                + (try total(checkpoint.catalog.categories, domain: .categories))
                + (try total(checkpoint.catalog.products, domain: .products)) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
    }

    private func forEachPersistedBatch<Model: PersistentModel>(
        _ type: Model.Type,
        container: ModelContainer,
        predicate: Predicate<Model>? = nil,
        sortBy: [SortDescriptor<Model>] = [],
        _ body: (Model) throws -> Void
    ) throws -> Int {
        var total = 0
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let descriptor = FetchDescriptor<Model>(predicate: predicate, sortBy: sortBy)
        try context.enumerate(
            descriptor,
            batchSize: ShopSyncRecoveryLimits.verificationBatchSize
        ) { row in
            try body(row)
            let (next, overflow) = total.addingReportingOverflow(1)
            guard !overflow, next <= ShopSyncRecoveryLimits.maximumTotalRows else {
                throw ShopSyncRecoveryContractError.totalResourceBudgetExceeded
            }
            total = next
        }
        return total
    }

    private func save(
        _ context: ModelContext,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
            scope,
            defaults: defaultsBox.value
        ) {
            try context.save()
        }
    }

    private func model<Model: PersistentModel>(
        _ type: Model.Type,
        remoteID: UUID,
        ids: [UUID: PersistentIdentifier],
        context: ModelContext
    ) throws -> Model {
        guard let persistentID = ids[remoteID],
              let model = context.model(for: persistentID) as? Model else {
            throw ShopSyncRecoveryContractError.relationViolation
        }
        return model
    }

    private func requiredDate(_ value: String) throws -> Date {
        _ = try ShopSyncRecoveryCanonical.requireUTC6(value)
        guard let date = SupabaseRemoteDateParser.parse(value) else {
            throw ShopSyncRecoveryContractError.nonCanonicalTimestamp
        }
        return date
    }

    private func optionalDate(_ value: String?) throws -> Date? {
        guard let value else { return nil }
        return try requiredDate(value)
    }

    private func captureRecoveryScope(
        ownerUserID: UUID
    ) throws -> Task126VerifiedOwnerStoreScope {
        try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaultsBox.value,
            allowsPendingReplacement: true
        )
    }

    private func validateJournal(scope: Task126VerifiedOwnerStoreScope) throws {
        let store = AccountBindingStore(defaults: defaultsBox.value)
        guard let journal = store.pendingRecoveryJournal,
              journal.replacement.accountHash == scope.accountHash,
              journal.replacement.storeIdentity == scope.storeIdentity,
              journal.deviceIdentityHash == scope.deviceIdentityHash else {
            throw AtomicGenerationRecoveryError.journalTransitionRejected
        }
    }

    private func revalidate(
        _ scope: Task126VerifiedOwnerStoreScope,
        ownerUserID: UUID
    ) throws {
        guard scope.ownerUserID == ownerUserID else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(
            scope,
            defaults: defaultsBox.value
        )
    }

    private func total(
        _ digest: ShopSyncRecoveryEntityDigest,
        domain: ShopSyncRecoveryDomain
    ) throws -> Int {
        try ShopSyncRecoveryLimits.total(digest, domain: domain)
    }

    private func makeSummary(
        checkpoint: ShopSyncRecoveryCheckpoint,
        generationID: UUID
    ) -> SyncRecoverySnapshotPullSummary {
        var history = HistorySessionPullResult()
        history.insertedCount = checkpoint.history.activeCount
        history.prunedMissingRemoteCount = checkpoint.history.tombstoneCount
        return SyncRecoverySnapshotPullSummary(
            catalog: SupabasePullApplyResult(
                inserted: checkpoint.catalog.products.activeCount,
                updated: 0,
                suppliersCreated: checkpoint.catalog.suppliers.activeCount,
                categoriesCreated: checkpoint.catalog.categories.activeCount,
                productTombstoned: checkpoint.catalog.products.tombstoneCount
            ),
            history: history,
            productPrices: ProductPriceApplyResult(
                inserted: checkpoint.prices.activeCount,
                skippedExisting: 0,
                totalConsidered: checkpoint.prices.activeCount
            ),
            watermarkAfter: checkpoint.maxEventID ?? 0,
            activatedGenerationID: generationID,
            completedRecoveryJournal: true
        )
    }
}

nonisolated enum AtomicGenerationRecoveryError: Error, Sendable, Equatable {
    case journalTransitionRejected
    case journalCompletionRejected
    case pendingLocalWorkRequiresDrain
}
