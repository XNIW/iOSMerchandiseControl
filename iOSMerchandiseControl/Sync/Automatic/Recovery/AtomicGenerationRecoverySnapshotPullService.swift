import CryptoKit
import Foundation
import SwiftData
#if canImport(Darwin)
import Darwin
#endif

private nonisolated final class AtomicRecoveryDefaultsBox: @unchecked Sendable {
    let value: UserDefaults

    init(_ value: UserDefaults) {
        self.value = value
    }
}

private nonisolated final class AtomicRecoveryStagingState: @unchecked Sendable {
    let baselineRunID: UUID
    var pageProgress: AtomicRecoveryPageProgress?
    init(baselineRunID: UUID = UUID()) { self.baselineRunID = baselineRunID }
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

private nonisolated struct AtomicRecoveryProofAccumulator: Codable, Sendable {
    private var digest = ShopSyncRecoveryCanonical.sha256("")
    private var count = 0
    private var previousOrderingID: String?

    mutating func append(orderingID: UUID, proof: String) throws {
        let id = orderingID.uuidString.lowercased()
        guard previousOrderingID.map({ $0 < id }) ?? true,
              proof.count == 64,
              proof.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID
        }
        // Private physical materialization proof, independent of the public
        // checkpoint digest. Its bounded value state can survive page commits.
        digest = ShopSyncRecoveryCanonical.sha256(digest + "\n" + ShopSyncRecoveryCanonical.joined(id, proof))
        count += 1
        previousOrderingID = id
    }

    mutating func finalize() -> AtomicRecoveryProofReceipt {
        AtomicRecoveryProofReceipt(
            count: count,
            digest: digest
        )
    }

    func validate() throws {
        guard count >= 0, count <= ShopSyncRecoveryLimits.maximumTotalRows,
              digest.count == 64, digest.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
              (count == 0 ? (previousOrderingID == nil && digest == ShopSyncRecoveryCanonical.sha256(""))
                : previousOrderingID.flatMap(UUID.init(uuidString:)) != nil) else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
    }
}

private nonisolated struct AtomicRecoveryProofState: Codable {
    let supplier: AtomicRecoveryProofAccumulator
    let category: AtomicRecoveryProofAccumulator
    let product: AtomicRecoveryProofAccumulator
    let price: AtomicRecoveryProofAccumulator
    let history: AtomicRecoveryProofAccumulator
    let supplierBaseline: AtomicRecoveryProofAccumulator
    let categoryBaseline: AtomicRecoveryProofAccumulator
    let productBaseline: AtomicRecoveryProofAccumulator

    init(_ state: AtomicRecoveryStagingState) {
        supplier = state.supplierMaterializationProof; category = state.categoryMaterializationProof
        product = state.productMaterializationProof; price = state.priceMaterializationProof
        history = state.historyMaterializationProof; supplierBaseline = state.supplierBaselineProof
        categoryBaseline = state.categoryBaselineProof; productBaseline = state.productBaselineProof
    }
    func restore(_ state: AtomicRecoveryStagingState) throws {
        for proof in [supplier, category, product, price, history, supplierBaseline, categoryBaseline, productBaseline] {
            try proof.validate()
        }
        state.supplierMaterializationProof = supplier; state.categoryMaterializationProof = category
        state.productMaterializationProof = product; state.priceMaterializationProof = price
        state.historyMaterializationProof = history; state.supplierBaselineProof = supplierBaseline
        state.categoryBaselineProof = categoryBaseline; state.productBaselineProof = productBaseline
    }
}

private nonisolated struct AtomicRecoveryPageProgress: Codable {
    static let fileName = "recovery-page-progress-v1.json"
    static let preparedFileName = "recovery-page-prepared-v1.json"
    struct Domain: Codable {
        var afterID: String?
        var processed = 0
        var pages = 0
        var complete = false
        var ledgerBytes = 0
        var effectiveLimit: Int?
        var lastPageSHA256: String?
    }
    let schemaVersion: String
    let generationID: UUID
    let accountHash: String
    let shopID: UUID
    let storeIdentity: LocalStoreIdentity
    let deviceIdentityHash: String
    let checkpointA: ShopSyncRecoveryCheckpoint
    let pageLimit: Int
    let baselineRunID: UUID
    var domains: [String: Domain]
    var proofs: AtomicRecoveryProofState

    init(staging: SyncStoreGenerationHandle, checkpoint: ShopSyncRecoveryCheckpoint,
         pageLimit: Int, state: AtomicRecoveryStagingState) {
        schemaVersion = "recovery-page-progress-v1"
        generationID = staging.generationID; accountHash = staging.accountHash; shopID = staging.shopID
        storeIdentity = staging.storeIdentity; deviceIdentityHash = staging.deviceIdentityHash
        checkpointA = checkpoint; self.pageLimit = pageLimit; baselineRunID = state.baselineRunID
        domains = [:]; proofs = AtomicRecoveryProofState(state)
    }
    static func read(staging: SyncStoreGenerationHandle) throws -> Self? {
        let url = staging.storeURL.deletingLastPathComponent().appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(Self.self, from: boundedRead(url, limit: ShopSyncRecoveryLimits.maximumGenerationManifestBytes))
    }
    func validate(staging: SyncStoreGenerationHandle, scope: Task126VerifiedOwnerStoreScope, pageLimit: Int) throws {
        guard schemaVersion == "recovery-page-progress-v1", generationID == staging.generationID,
              accountHash == scope.accountHash, shopID == scope.shopID, storeIdentity == scope.storeIdentity,
              deviceIdentityHash == scope.deviceIdentityHash, self.pageLimit == pageLimit,
              checkpointA.scope.accountKey == scope.accountHash,
              checkpointA.scope.deviceKey == scope.deviceIdentityHash,
              checkpointA.shopId == scope.shopID, checkpointA.status == "ready",
              domains.count <= ShopSyncRecoveryDomain.allCases.count else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
        var unfinishedSeen = false
        for domain in ShopSyncRecoveryDomain.allCases {
            if let cursor = domains[domain.rawValue] {
                guard !unfinishedSeen else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
                if !cursor.complete { unfinishedSeen = true }
            } else { unfinishedSeen = true }
        }
        var total = 0
        for (key, cursor) in domains {
            guard let domain = ShopSyncRecoveryDomain(rawValue: key), cursor.processed >= 0,
                  cursor.processed <= ShopSyncRecoveryLimits.maximumRows(for: domain), cursor.pages >= 0,
                  cursor.pages <= ShopSyncRecoveryLimits.maximumRows(for: domain) + 1,
                  cursor.ledgerBytes >= 0, cursor.ledgerBytes <= ShopSyncRecoveryLimits.maximumLedgerBytesPerDomain,
                  cursor.afterID == nil || cursor.afterID.flatMap(UUID.init(uuidString:)) != nil,
                  cursor.pages == 0 || cursor.effectiveLimit == min(pageLimit, ShopSyncRecoveryLimits.maximumPageRows(for: domain)),
                  cursor.complete || cursor.processed == 0 || cursor.afterID != nil,
                  cursor.processed == 0 || cursor.ledgerBytes > 0,
                  cursor.pages == 0 || cursor.lastPageSHA256?.count == 64 else {
                throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
            }
            total += cursor.ledgerBytes
        }
        guard total <= ShopSyncRecoveryLimits.maximumLedgerBytesTotal else { throw ShopSyncRecoveryContractError.totalResourceBudgetExceeded }
    }
    func save(staging: SyncStoreGenerationHandle) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try Self.write(try encoder.encode(self), to: staging.storeURL.deletingLastPathComponent().appendingPathComponent(Self.fileName),
                       limit: ShopSyncRecoveryLimits.maximumGenerationManifestBytes)
    }
    static func boundedRead(_ url: URL, limit: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let bytes = values.fileSize, bytes >= 0, bytes <= limit else { throw SyncStoreGenerationError.generationResourceBudgetExceeded }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw SyncStoreGenerationError.generationResourceBudgetExceeded }
        return data
    }
    static func write(_ data: Data, to url: URL, limit: Int) throws {
        guard data.count <= limit else { throw SyncStoreGenerationError.generationResourceBudgetExceeded }
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try boundedRead(url, limit: limit)
        }
        try data.write(to: url, options: .atomic)
        let file = try FileHandle(forWritingTo: url); defer { try? file.close() }; try file.synchronize()
    }
}

private nonisolated struct AtomicRecoveryPreparedPageHeader: Decodable {
    let domain: ShopSyncRecoveryDomain
}

private nonisolated struct AtomicRecoveryPreparedPage<Row: Codable>: Codable {
    let domain: ShopSyncRecoveryDomain
    let afterID: String?
    let rows: [Row]
    let pageLimit: Int
    let nextAfterID: String?
    let hasMore: Bool
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
    private let progressReporter: SyncRecoveryProgressReporter?
    private let pageCommitProbe: @Sendable (ShopSyncRecoveryDomain) throws -> Void

    init(
        storeGenerationController: SyncStoreGenerationController,
        recoveryRemote: ShopSyncRecoveryRemoteAdapter,
        defaults: UserDefaults = .standard,
        pageLimit: Int = 250,
        maximumAttempts: Int = 2,
        progressReporter: SyncRecoveryProgressReporter? = nil,
        pageCommitProbe: @escaping @Sendable (ShopSyncRecoveryDomain) throws -> Void = { _ in }
    ) {
        self.storeGenerationController = storeGenerationController
        self.recoveryRemote = recoveryRemote
        self.defaultsBox = AtomicRecoveryDefaultsBox(defaults)
        self.pageLimit = max(1, min(pageLimit, 250))
        self.maximumAttempts = max(1, min(maximumAttempts, 2))
        self.progressReporter = progressReporter
        self.pageCommitProbe = pageCommitProbe
    }

    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary {
        // One budget covers checkpoint A, every page, bounded retry, B and C.
        // Reset only for a new top-level invocation so a changing checkpoint
        // cannot multiply the allowed network/memory footprint.
        await recoveryRemote.resetResourceBudget()
        var scope = try await ensureRecoveryJournal(ownerUserID: ownerUserID)
        try await reportProgress(.preparing, scope: scope)
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
            var activatedManifest: SyncStoreGenerationManifest?
            var activatedJournal: AccountRecoveryJournalSnapshot?
            do {
                scope = try captureRecoveryScope(ownerUserID: ownerUserID)
                try validateJournal(scope: scope)
                try await reportProgress(.checkpoint, scope: scope)
                let freshAdmission = try await recoveryRemote.checkpoint(
                    ownerUserID: ownerUserID,
                    scope: scope
                )
                try revalidate(scope, ownerUserID: ownerUserID)
                let resumeID = AccountBindingStore(defaults: defaultsBox.value).pendingRecoveryJournal?.generationID
                let prepared = try await storeGenerationController.prepareStaging(
                    accountHash: scope.accountHash,
                    shopID: scope.shopID,
                    storeIdentity: scope.storeIdentity,
                    deviceIdentityHash: scope.deviceIdentityHash,
                    resumeGenerationID: resumeID
                )
                staging = prepared
                let bindingStore = AccountBindingStore(defaults: defaultsBox.value)
                guard await recordStagingJournal(scope: scope, generationID: prepared.generationID) else {
                    throw AtomicGenerationRecoveryError.journalTransitionRejected
                }
                scope = try captureRecoveryScope(ownerUserID: ownerUserID)
                let progress = try AtomicRecoveryPageProgress.read(staging: prepared)
                let checkpointA: ShopSyncRecoveryCheckpoint
                let state: AtomicRecoveryStagingState
                let persistedLedger: ShopSyncRecoveryLedger
                if let progress {
                    try progress.validate(staging: prepared, scope: scope, pageLimit: pageLimit)
                    guard Self.isMonotonicRecoveryFence(freshAdmission, from: progress.checkpointA) else {
                        throw ShopSyncRecoveryContractError.checkpointChanged
                    }
                    checkpointA = progress.checkpointA
                    state = AtomicRecoveryStagingState(baselineRunID: progress.baselineRunID)
                    state.pageProgress = progress
                    try progress.proofs.restore(state)
                    let offsets = Dictionary(uniqueKeysWithValues: progress.domains.compactMap { key, value in
                        ShopSyncRecoveryDomain(rawValue: key).map { ($0, value.ledgerBytes) }
                    })
                    persistedLedger = try ShopSyncRecoveryLedger(generationStoreURL: prepared.storeURL,
                        mode: .resumeAccepted(byteOffsets: offsets))
                    try restoreAcceptedRelationships(state: state, staging: prepared, ledger: persistedLedger)
                } else {
                    checkpointA = freshAdmission
                    try await storeGenerationController.resetStaging(prepared)
                    state = AtomicRecoveryStagingState()
                    persistedLedger = try ShopSyncRecoveryLedger(generationStoreURL: prepared.storeURL)
                    try createBaselineRun(state: state, container: prepared.container, ownerUserID: ownerUserID, scope: scope)
                    state.pageProgress = AtomicRecoveryPageProgress(staging: prepared, checkpoint: checkpointA,
                                                                  pageLimit: pageLimit, state: state)
                    try state.pageProgress!.save(staging: prepared)
                }
                ledger = persistedLedger

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
                try await reportProgress(.verifying, scope: scope)
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
                    expectedBaselineScopeKey: checkpointA.syncEvents.maxId == "0" ? nil : checkpointA.scope.key
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
                guard await recordVerifiedJournal(scope: scope, generationID: prepared.generationID,
                    checkpointDigest: checkpointB.checkpointDigest, watermark: checkpointB.maxEventID!,
                    baselineRunID: state.baselineRunID) else {
                    throw AtomicGenerationRecoveryError.journalTransitionRejected
                }
                scope = try captureRecoveryScope(ownerUserID: ownerUserID)
                guard let journal = bindingStore.pendingRecoveryJournal else {
                    throw AtomicGenerationRecoveryError.journalTransitionRejected
                }
                try await reportProgress(.activating, scope: scope)
                let publishedManifest = try await storeGenerationController.activate(
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
                activatedManifest = publishedManifest
                activatedJournal = journal

                scope = try captureRecoveryScope(ownerUserID: ownerUserID)
                try revalidate(scope, ownerUserID: ownerUserID)
                try await reportProgress(.finalizing, scope: scope)
                _ = try await storeGenerationController.markRecoveryFinalized(scope: scope)
                guard try await completeRecoveryJournal(scope: scope) else {
                    throw AtomicGenerationRecoveryError.journalCompletionRejected
                }

                return try await makeSummary(
                    checkpoint: checkpointB,
                    generationID: prepared.generationID
                )
            } catch is CancellationError {
                if let ledger { try? ledger.closeWrites() }
                // Accepted pages belong only to this scoped staging generation.
                // Their durable cursor can be reused after cancellation/reopen.
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
            } catch let error as Task126OwnerStoreGateError where error == .scopeChanged && manifestActivated {
                if let ledger { try? ledger.closeWrites() }
                guard let activatedManifest, let activatedJournal,
                      let completed = try await completePublishedSameScopeGenerationAfterLeaseRefresh(
                        originalScope: scope, manifest: activatedManifest, journal: activatedJournal
                      ) else { throw error }
                return completed
            } catch {
                if let ledger { try? ledger.closeWrites() }
                if !Self.isResumableTransportFailure(error) {
                    await quarantineIfUnpublished(staging, manifestActivated: manifestActivated)
                }
                throw error
            }
        }
        throw lastCheckpointError ?? ShopSyncRecoveryContractError.checkpointChanged
    }

    /// A generation remount can refresh the same resolved shop and invalidate
    /// the old lease after durable publication. Only the original published
    /// generation/journal may resume, under newly captured exact authority.
    /// The existing completion path reacquires its marker and durable proof;
    /// no obsolete response or pre-publication scope is accepted here.
    private func completePublishedSameScopeGenerationAfterLeaseRefresh(
        originalScope: Task126VerifiedOwnerStoreScope,
        manifest: SyncStoreGenerationManifest,
        journal: AccountRecoveryJournalSnapshot
    ) async throws -> SyncRecoverySnapshotPullSummary? {
        for admissionAttempt in 1...maximumAttempts {
            try Task.checkCancellation()
            guard journal.mode == .sameScopeRecovery,
                  journal.generationID == manifest.generationID,
                  journal.checkpointDigest == manifest.checkpoint.checkpointDigest,
                  journal.watermark == manifest.checkpoint.maxEventID,
                  journal.baselineRunID == manifest.baselineRunID else { return nil }
            do {
                let current = try captureRecoveryScope(ownerUserID: originalScope.ownerUserID)
                guard current.ownerUserID == originalScope.ownerUserID,
                      current.accountHash == originalScope.accountHash,
                      current.shopID == originalScope.shopID,
                      current.storeIdentity == originalScope.storeIdentity,
                      current.deviceInstallID == originalScope.deviceInstallID,
                      current.deviceIdentityHash == originalScope.deviceIdentityHash,
                      current.pendingReplacement == originalScope.pendingReplacement,
                      !SelectedShopStore(defaults: defaultsBox.value).hasConfirmedDeviceDenial(
                        accountHash: current.accountHash, shopID: current.shopID,
                        deviceIdentityHash: current.deviceIdentityHash),
                      await storeGenerationController.activeManifest == manifest,
                      let persistedJournal = AccountBindingStore(defaults: defaultsBox.value).pendingRecoveryJournal,
                      persistedJournal.mode == journal.mode,
                      persistedJournal.phase == .activated,
                      persistedJournal.replacement == journal.replacement,
                      persistedJournal.deviceIdentityHash == journal.deviceIdentityHash,
                      persistedJournal.generationID == journal.generationID,
                      persistedJournal.checkpointDigest == journal.checkpointDigest,
                      persistedJournal.watermark == journal.watermark,
                      persistedJournal.baselineRunID == journal.baselineRunID else { return nil }
                try revalidate(current, ownerUserID: originalScope.ownerUserID)
                return try await completeActivatedGenerationIfPossible(
                        ownerUserID: originalScope.ownerUserID, scope: current
                    )
            } catch let error as Task126OwnerStoreGateError where error == .scopeChanged {
                // Each lifecycle refresh requires a fresh complete admission and
                // marker. Never carry a stale response into journal completion.
                guard admissionAttempt < maximumAttempts else { throw error }
            }
        }
        return nil
    }

    private func reportProgress(
        _ stage: SyncRecoveryProgress.Stage,
        scope: Task126VerifiedOwnerStoreScope,
        domain: ShopSyncRecoveryDomain? = nil,
        pages: Int = 0,
        persistedRows: Int = 0
    ) async throws {
        guard let progressReporter else { return }
        await progressReporter(SyncRecoveryProgressEvent(
            invocationID: SyncRecoveryProgressContext.invocationID,
            scope: scope,
            progress: SyncRecoveryProgress(
                stage: stage, domain: domain, pages: pages, persistedRows: persistedRows
            )
        ))
        // Presentation is an async boundary. Never carry authorization across
        // it into a write or publication without the existing scope fence.
        try revalidate(scope, ownerUserID: scope.ownerUserID)
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

    // UserDefaults synchronously calls SwiftUI's AppStorage observer. Taking
    // the scope lease on a worker while that callback waits for SwiftUI's
    // update lock deadlocks a root render waiting for the same scope lease.
    // Only these small journal/metadata transitions move to MainActor; page
    // materialization, full proofs and filesystem mutation fences stay off it.
    private func ensureRecoveryJournal(
        ownerUserID: UUID
    ) async throws -> Task126VerifiedOwnerStoreScope {
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
        guard await beginRecoveryJournal(scope: current) else {
            throw AtomicGenerationRecoveryError.journalTransitionRejected
        }
        return try captureRecoveryScope(ownerUserID: ownerUserID)
    }

    @MainActor
    private func beginRecoveryJournal(scope: Task126VerifiedOwnerStoreScope) -> Bool {
        AccountBindingStore(defaults: defaultsBox.value).beginSameScopeRecovery(
            accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            reason: "automatic_full_recovery", deviceIdentityHash: scope.deviceIdentityHash)
    }

    @MainActor
    private func recordStagingJournal(scope: Task126VerifiedOwnerStoreScope, generationID: UUID) -> Bool {
        AccountBindingStore(defaults: defaultsBox.value).recordPendingRecoveryStaging(
            accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash, generationID: generationID, scope: scope)
    }

    @MainActor
    private func recordVerifiedJournal(scope: Task126VerifiedOwnerStoreScope, generationID: UUID,
        checkpointDigest: String, watermark: Int64, baselineRunID: UUID) -> Bool {
        AccountBindingStore(defaults: defaultsBox.value).recordPendingRecoveryVerified(
            accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash, generationID: generationID,
            checkpointDigest: checkpointDigest, watermark: watermark,
            baselineRunID: baselineRunID, scope: scope)
    }

    @MainActor
    private func completeRecoveryJournal(scope: Task126VerifiedOwnerStoreScope) throws -> Bool {
        try AccountBindingStore(defaults: defaultsBox.value).completePendingReplacementRecovery(
            accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            expectedLeaseGeneration: scope.leaseGeneration)
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
        try await reportProgress(.finalizing, scope: refreshedScope)
        if isAlreadyFinalized {
            guard try await completeRecoveryJournal(scope: refreshedScope) else {
                throw AtomicGenerationRecoveryError.journalCompletionRejected
            }
            return try await makeSummary(
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
        guard try await completeRecoveryJournal(scope: refreshedScope) else {
            throw AtomicGenerationRecoveryError.journalCompletionRejected
        }
        return try await makeSummary(checkpoint: manifest.checkpoint, generationID: manifest.generationID)
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
                _ = try SameScopeRecoveryActiveWorkInspector.snapshot(
                    container: activeContainer,
                    scope: scope
                )
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
            state: state,
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
            state: state,
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
            state: state,
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
            state: state,
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
            state: state,
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
            state: state,
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

    private func streamPages<Row: Codable & Sendable>(
        _ rowType: Row.Type,
        domain: ShopSyncRecoveryDomain,
        staging: SyncStoreGenerationHandle,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        checkpoint: ShopSyncRecoveryCheckpoint,
        orderingID: KeyPath<Row, UUID>,
        ledger: ShopSyncRecoveryLedger,
        state: AtomicRecoveryStagingState,
        makeRecord: (Row, ShopSyncRecoveryCheckpoint) throws -> ShopSyncRecoveryLedgerRecord,
        consume: ([Row]) throws -> Void
    ) async throws {
        guard var progress = state.pageProgress else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
        var cursor = progress.domains[domain.rawValue] ?? .init()
        let cacheURL = staging.storeURL.deletingLastPathComponent()
            .appendingPathComponent(AtomicRecoveryPageProgress.preparedFileName)
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            let data = try AtomicRecoveryPageProgress.boundedRead(cacheURL, limit: ShopSyncRecoveryLimits.maximumPageResponseBytes)
            let header = try JSONDecoder().decode(AtomicRecoveryPreparedPageHeader.self, from: data)
            if header.domain == domain, let lastHash = cursor.lastPageSHA256,
               ShopSyncRecoveryCanonical.sha256(String(decoding: data, as: UTF8.self)) == lastHash {
                try FileManager.default.removeItem(at: cacheURL)
            }
        }
        if cursor.complete { return }
        try await reportProgress(.downloading, scope: scope, domain: domain,
                                 pages: cursor.pages, persistedRows: cursor.processed)
        while true {
            try Task.checkCancellation()
            try revalidate(scope, ownerUserID: ownerUserID)
            let page: AtomicRecoveryPreparedPage<Row>
            var replayPrepared = false
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                let data = try AtomicRecoveryPageProgress.boundedRead(cacheURL,
                    limit: ShopSyncRecoveryLimits.maximumPageResponseBytes)
                page = try JSONDecoder().decode(AtomicRecoveryPreparedPage<Row>.self, from: data)
                guard page.domain == domain else { throw ShopSyncRecoveryContractError.invalidPage(domain: domain) }
                guard page.afterID == cursor.afterID else { throw ShopSyncRecoveryContractError.invalidPage(domain: domain) }
                replayPrepared = true
            } else {
                let remotePage = try await recoveryRemote.page(rowType, domain: domain,
                    afterID: cursor.afterID, limit: pageLimit, ownerUserID: ownerUserID,
                    scope: scope, checkpoint: checkpoint)
                try revalidate(scope, ownerUserID: ownerUserID)
                page = AtomicRecoveryPreparedPage(domain: domain, afterID: cursor.afterID,
                    rows: remotePage.rows, pageLimit: remotePage.pageLimit,
                    nextAfterID: remotePage.nextAfterId, hasMore: remotePage.hasMore)
            }
            guard page.pageLimit == min(pageLimit, ShopSyncRecoveryLimits.maximumPageRows(for: domain)),
                  cursor.effectiveLimit == nil || cursor.effectiveLimit == page.pageLimit,
                  page.rows.count <= page.pageLimit, page.hasMore == (page.nextAfterID != nil) else {
                throw ShopSyncRecoveryContractError.invalidPage(domain: domain)
            }
            let pages = cursor.pages + 1
            let maximumRows = ShopSyncRecoveryLimits.maximumRows(for: domain)
            guard pages <= ((maximumRows - 1) / page.pageLimit) + 1 else {
                throw ShopSyncRecoveryContractError.pageBudgetExceeded(domain: domain)
            }
            var previousID = cursor.afterID
            var records: [ShopSyncRecoveryLedgerRecord] = []
            records.reserveCapacity(page.rows.count)
            for row in page.rows {
                let id = row[keyPath: orderingID].uuidString.lowercased()
                guard previousID.map({ $0 < id }) ?? true else { throw ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID }
                let record = try makeRecord(row, checkpoint)
                guard record.orderingID == id else { throw ShopSyncRecoveryContractError.invalidPage(domain: domain) }
                records.append(record); previousID = id
            }
            guard cursor.processed + records.count <= maximumRows else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: domain)
            }
            if page.hasMore {
                guard page.rows.count == page.pageLimit, let last = records.last?.orderingID,
                      page.nextAfterID?.lowercased() == last else { throw ShopSyncRecoveryContractError.invalidPage(domain: domain) }
            } else if page.nextAfterID != nil { throw ShopSyncRecoveryContractError.invalidPage(domain: domain) }
            if replayPrepared {
                try removeUnacceptedMaterialization(domain: domain, ids: Set(records.compactMap { UUID(uuidString: $0.orderingID) }),
                                                    state: state, staging: staging, scope: scope)
            } else {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                try AtomicRecoveryPageProgress.write(try encoder.encode(page), to: cacheURL,
                    limit: ShopSyncRecoveryLimits.maximumPageResponseBytes)
            }
            // The one bounded raw page counts against the unchanged staging
            // directory budget, including the duplicate before commit.
            try await storeGenerationController.validateResourceBudget(staging)
            for record in records { try ledger.append(record, domain: domain) }
            try consume(page.rows)
            try pageCommitProbe(domain)
            try ledger.closeWrites()
            cursor.pages = pages; cursor.processed += records.count; cursor.complete = !page.hasMore
            cursor.effectiveLimit = page.pageLimit
            let preparedData = try AtomicRecoveryPageProgress.boundedRead(cacheURL, limit: ShopSyncRecoveryLimits.maximumPageResponseBytes)
            cursor.lastPageSHA256 = ShopSyncRecoveryCanonical.sha256(String(decoding: preparedData, as: UTF8.self))
            cursor.afterID = page.hasMore ? records.last?.orderingID : nil
            cursor.ledgerBytes = try ledger.acceptedByteOffsets()[domain, default: 0]
            progress.domains[domain.rawValue] = cursor
            progress.proofs = AtomicRecoveryProofState(state)
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(scope, defaults: defaultsBox.value) {
                try progress.save(staging: staging)
            }
            state.pageProgress = progress
            try FileManager.default.removeItem(at: cacheURL)
            try await storeGenerationController.validateResourceBudget(staging)
            try await reportProgress(.downloading, scope: scope, domain: domain,
                                     pages: cursor.pages, persistedRows: cursor.processed)
            if cursor.complete { return }
        }
    }

    private nonisolated static func isResumableTransportFailure(_ error: Error) -> Bool {
        if error is URLError { return true }
        if case SupabaseTransportClientError.networkError = error { return true }
        return false
    }

    private func restoreAcceptedRelationships(
        state: AtomicRecoveryStagingState, staging: SyncStoreGenerationHandle, ledger: ShopSyncRecoveryLedger
    ) throws {
        guard let progress = state.pageProgress else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
        // One bounded traversal on reopen. Never derive the expected body proof
        // from these rows: the saved proof still drives the final full readback.
        _ = try forEachPersistedBatch(Supplier.self, container: staging.container) { row in
            guard let id = row.remoteID, state.supplierModelIDs.updateValue(row.persistentModelID, forKey: id) == nil else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        _ = try forEachPersistedBatch(ProductCategory.self, container: staging.container) { row in
            guard let id = row.remoteID, state.categoryModelIDs.updateValue(row.persistentModelID, forKey: id) == nil else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        _ = try forEachPersistedBatch(Product.self, container: staging.container) { row in
            guard let id = row.remoteID, state.productModelIDs.updateValue(row.persistentModelID, forKey: id) == nil else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            if let version = row.primaryImageVersionID {
                state.expectedImageRelationships[id] = .init(versionID: version, isTombstone: row.remoteDeletedAt != nil)
            }
        }
        for domain in ShopSyncRecoveryDomain.allCases {
            var rows = 0
            try ledger.forEachRecord(for: domain) { record in
                rows += 1
                guard let id = UUID(uuidString: record.orderingID) else {
                    throw ShopSyncRecoveryContractError.persistedLedgerInvalid(domain: domain)
                }
                if domain == .products, record.isTombstone { state.tombstonedProductIDs.insert(id) }
                if domain == .images { state.expectedImageRelationships.removeValue(forKey: id) }
            }
            guard rows == (progress.domains[domain.rawValue]?.processed ?? 0) else {
                throw ShopSyncRecoveryContractError.persistedLedgerInvalid(domain: domain)
            }
        }
    }

    private func removeUnacceptedMaterialization(
        domain: ShopSyncRecoveryDomain, ids: Set<UUID>, state: AtomicRecoveryStagingState,
        staging: SyncStoreGenerationHandle, scope: Task126VerifiedOwnerStoreScope
    ) throws {
        let context = ModelContext(staging.container); context.autosaveEnabled = false
        switch domain {
        case .suppliers:
            try removePreparedModels(Supplier.self, context: context) { $0.remoteID.map(ids.contains) ?? false }
            for id in ids { state.supplierModelIDs.removeValue(forKey: id) }
        case .categories:
            try removePreparedModels(ProductCategory.self, context: context) { $0.remoteID.map(ids.contains) ?? false }
            for id in ids { state.categoryModelIDs.removeValue(forKey: id) }
        case .products:
            try removePreparedModels(Product.self, context: context) { $0.remoteID.map(ids.contains) ?? false }
            for id in ids {
                state.productModelIDs.removeValue(forKey: id)
                state.tombstonedProductIDs.remove(id); state.expectedImageRelationships.removeValue(forKey: id)
            }
        case .prices:
            try removePreparedModels(ProductPrice.self, context: context) { $0.remoteID.map(ids.contains) ?? false }
        case .history:
            try removePreparedModels(HistoryEntry.self, context: context) { $0.remoteID.map(ids.contains) ?? false }
        case .images: break // Image verification owns no business model row.
        }
        if domain == .suppliers || domain == .categories || domain == .products {
            let type: SupabaseCatalogBaselineEntityType = domain == .suppliers ? .supplier : (domain == .categories ? .productCategory : .product)
            try removePreparedModels(SupabaseCatalogBaselineRecord.self, context: context) {
                $0.baselineRunID == state.baselineRunID && $0.entityType == type.rawValue && ids.contains($0.remoteID)
            }
        }
        try save(context, scope: scope)
    }

    private func removePreparedModels<Model: PersistentModel>(
        _ type: Model.Type, context: ModelContext, matching: (Model) -> Bool
    ) throws {
        var selected: [Model] = []
        try context.enumerate(FetchDescriptor<Model>(), batchSize: ShopSyncRecoveryLimits.verificationBatchSize) { row in
            if matching(row) {
                guard selected.count < pageLimit else { throw SyncStoreGenerationError.activationReadBackFailed }
                selected.append(row)
            }
        }
        for row in selected { context.delete(row) }
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
            sortBy: [SortDescriptor(\SupabaseCatalogBaselineRecord.recordKey, comparator: .lexical)]
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
    ) async throws -> SyncRecoverySnapshotPullSummary {
        let container = await storeGenerationController.modelContainer
        let hasPendingLocalWork = try await Task.detached(priority: .utility) {
            try !SameScopeRecoveryActiveWorkInspector.isContinuationDrained(container: container)
        }.value
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
            completedRecoveryJournal: true,
            hasPendingLocalWork: hasPendingLocalWork
        )
    }
}

nonisolated enum AtomicGenerationRecoveryError: Error, Sendable, Equatable {
    case journalTransitionRejected
    case journalCompletionRejected
    case pendingLocalWorkRequiresDrain
}
