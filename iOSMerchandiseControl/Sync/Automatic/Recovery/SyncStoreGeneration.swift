import Combine
import Foundation
import SwiftData
#if canImport(Darwin)
import Darwin
#endif

nonisolated enum SyncStoreSchema {
    static var schema: Schema {
        Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            SyncEventOutboxEntry.self,
            LocalPendingChange.self
        ])
    }

    static func makeDefaultContainer() throws -> ModelContainer {
        let schema = schema
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema)]
        )
    }

    static var defaultStoreURL: URL {
        let schema = schema
        return ModelConfiguration(schema: schema).url
    }

    static func makeFileBackedContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = schema
        let configuration = ModelConfiguration(
            "sync-store-generation",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

nonisolated struct SyncStoreGenerationManifest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = "sync-store-generation-manifest-v2"

    let schemaVersion: String
    let generationID: UUID
    let relativeStorePath: String
    let accountHash: String
    let shopID: UUID
    let storeIdentity: LocalStoreIdentity
    let deviceIdentityHash: String
    let recoveryMode: AccountRecoveryJournalMode
    let checkpointBeforeDownload: ShopSyncRecoveryCheckpoint
    let checkpoint: ShopSyncRecoveryCheckpoint
    let localVerification: ShopSyncRecoveryLocalVerificationReceipt
    let baselineRunID: UUID
    let activatedAt: Date

    init(
        generationID: UUID,
        relativeStorePath: String,
        accountHash: String,
        shopID: UUID,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String,
        recoveryMode: AccountRecoveryJournalMode,
        checkpointBeforeDownload: ShopSyncRecoveryCheckpoint,
        checkpoint: ShopSyncRecoveryCheckpoint,
        localVerification: ShopSyncRecoveryLocalVerificationReceipt,
        baselineRunID: UUID,
        activatedAt: Date = Date()
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.generationID = generationID
        self.relativeStorePath = relativeStorePath
        self.accountHash = accountHash
        self.shopID = shopID
        self.storeIdentity = storeIdentity
        self.deviceIdentityHash = deviceIdentityHash
        self.recoveryMode = recoveryMode
        self.checkpointBeforeDownload = checkpointBeforeDownload
        self.checkpoint = checkpoint
        self.localVerification = localVerification
        self.baselineRunID = baselineRunID
        self.activatedAt = activatedAt
    }
}

nonisolated struct SyncStoreRecoveryFinalization: Codable, Equatable, Sendable {
    static let currentSchemaVersion = "sync-store-recovery-finalization-v1"

    let schemaVersion: String
    let generationID: UUID
    let accountHash: String
    let shopID: UUID
    let storeIdentity: LocalStoreIdentity
    let deviceIdentityHash: String
    let checkpointDigest: String
    let watermark: Int64
    let baselineRunID: UUID

    init(manifest: SyncStoreGenerationManifest) throws {
        guard let watermark = manifest.checkpoint.maxEventID else {
            throw SyncStoreGenerationError.invalidManifest
        }
        self.schemaVersion = Self.currentSchemaVersion
        self.generationID = manifest.generationID
        self.accountHash = manifest.accountHash
        self.shopID = manifest.shopID
        self.storeIdentity = manifest.storeIdentity
        self.deviceIdentityHash = manifest.deviceIdentityHash
        self.checkpointDigest = manifest.checkpoint.checkpointDigest
        self.watermark = watermark
        self.baselineRunID = manifest.baselineRunID
    }

    func exactlyMatches(_ manifest: SyncStoreGenerationManifest) -> Bool {
        schemaVersion == Self.currentSchemaVersion
            && generationID == manifest.generationID
            && accountHash == manifest.accountHash
            && shopID == manifest.shopID
            && storeIdentity == manifest.storeIdentity
            && deviceIdentityHash == manifest.deviceIdentityHash
            && checkpointDigest == manifest.checkpoint.checkpointDigest
            && watermark == manifest.checkpoint.maxEventID
            && baselineRunID == manifest.baselineRunID
    }
}

nonisolated struct SyncStoreGenerationHandle: @unchecked Sendable {
    let generationID: UUID
    let storeURL: URL
    let relativeStorePath: String
    let accountHash: String
    let shopID: UUID
    let storeIdentity: LocalStoreIdentity
    let deviceIdentityHash: String
    let container: ModelContainer
}

nonisolated struct SyncStoreGenerationMutationFence: Equatable, Sendable {
    nonisolated struct FileState: Equatable, Sendable {
        let relativePath: String
        let fileSize: Int
        let allocatedSize: Int
        let modificationTimeBits: UInt64
        let systemFileNumber: UInt64
    }

    let generationID: UUID
    let files: [FileState]
}

nonisolated struct SyncStoreActiveGeneration: @unchecked Sendable {
    let container: ModelContainer
    let manifest: SyncStoreGenerationManifest?

    var presentationID: String {
        manifest?.generationID.uuidString.lowercased() ?? "legacy-default-store"
    }
}

/// Immutable admission token captured together with the ModelContainer used
/// to build a sync runtime. It prevents a runtime created for generation G0
/// from entering the process-wide single flight after G1 has been activated.
nonisolated struct SyncStoreGenerationLease: Equatable, @unchecked Sendable {
    let presentationID: String
    let containerIdentity: ObjectIdentifier
}

nonisolated enum SyncStoreGenerationError: Error, Equatable, Sendable {
    case baseDirectoryUnavailable
    case invalidManifest
    case activeStoreMissing
    case stagingAlreadyOpen
    case stagingScopeChanged
    case stagingStoreMissing
    case activationReadBackFailed
    case cleanupRequiresRelaunch
    case unavailable
    case staleGenerationLease
    case generationResourceBudgetExceeded
    case insufficientRecoveryDiskCapacity
    case defaultsConfigurationMismatch
    case stagingChangedAfterVerification
}

/// Test-only observation points around the single durable publication
/// boundary. Production passes the no-op default; the isolated Simulator
/// crash harness blocks at one of these points so the host can deliver a real
/// SIGKILL and verify the generation selected on relaunch.
nonisolated enum SyncStoreActivationBoundary: Equatable, Sendable {
    case beforeManifestRename
    case afterManifestRename
}

/// Owns the file-level generation protocol. It never unlinks a store opened in
/// the current process. Cleanup runs only after the active container has been
/// opened successfully, so a corrupt pointer cannot destroy the last usable
/// generation before recovery can inspect it.
nonisolated final class SyncStoreGenerationRepository: @unchecked Sendable {
    private static let maximumRetainedGenerationDirectories = 3
    private static let maximumCleanupDeletionsPerLaunch = 2
    private let fileManager: FileManager
    let baseDirectory: URL
    private let generationsDirectory: URL
    let manifestURL: URL
    let recoveryJournalURL: URL
    let recoveryFinalizationURL: URL
    private let legacyDefaultStoreURL: URL?
    let defaults: UserDefaults
    private let activationBoundaryProbe: @Sendable (SyncStoreActivationBoundary) -> Void
    private let activationDurabilityProbe: @Sendable () throws -> Void
    private let lock = NSLock()
    private var currentStaging: SyncStoreGenerationHandle?

    init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default,
        legacyDefaultStoreURL: URL? = nil,
        defaults: UserDefaults = .standard,
        activationBoundaryProbe: @escaping @Sendable (SyncStoreActivationBoundary) -> Void = { _ in },
        activationDurabilityProbe: @escaping @Sendable () throws -> Void = {}
    ) throws {
        self.fileManager = fileManager
        self.defaults = defaults
        self.activationBoundaryProbe = activationBoundaryProbe
        self.activationDurabilityProbe = activationDurabilityProbe
        self.legacyDefaultStoreURL = legacyDefaultStoreURL
            ?? (baseDirectory == nil ? SyncStoreSchema.defaultStoreURL : nil)
        if let baseDirectory {
            self.baseDirectory = baseDirectory.standardizedFileURL
        } else {
            guard let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw SyncStoreGenerationError.baseDirectoryUnavailable
            }
            self.baseDirectory = applicationSupport
                .appendingPathComponent("SyncStoreGenerations", isDirectory: true)
                .appendingPathComponent("v1", isDirectory: true)
                .standardizedFileURL
        }
        self.generationsDirectory = self.baseDirectory
            .appendingPathComponent("generations", isDirectory: true)
        self.manifestURL = self.baseDirectory
            .appendingPathComponent("active-generation.json", isDirectory: false)
        self.recoveryJournalURL = self.baseDirectory
            .appendingPathComponent("recovery-journal.json", isDirectory: false)
        self.recoveryFinalizationURL = self.baseDirectory
            .appendingPathComponent("recovery-finalization.json", isDirectory: false)

        try fileManager.createDirectory(
            at: generationsDirectory,
            withIntermediateDirectories: true
        )
        AccountBindingStore.configureDurableRecoveryJournal(
            at: recoveryJournalURL,
            for: defaults
        )
    }

    func loadActive() throws -> SyncStoreActiveGeneration {
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            let container: ModelContainer
            if let legacyDefaultStoreURL {
                container = try SyncStoreSchema.makeFileBackedContainer(at: legacyDefaultStoreURL)
            } else {
                container = try SyncStoreSchema.makeDefaultContainer()
            }
            let active = SyncStoreActiveGeneration(
                container: container,
                manifest: nil
            )
            cleanupAfterOpeningDefaultStore()
            return active
        }
        let manifest = try decodeAndValidateManifest()
        let storeURL = try resolvedStoreURL(for: manifest)
        guard fileManager.fileExists(atPath: storeURL.path) else {
            throw SyncStoreGenerationError.activeStoreMissing
        }
        let container = try SyncStoreSchema.makeFileBackedContainer(at: storeURL)
        let bindingStore = AccountBindingStore(defaults: defaults)
        let hasRawJournal = bindingStore.hasPendingReplacementJournal
        let journal = bindingStore.pendingRecoveryJournal
        let recoveryFinalization = try decodeRecoveryFinalizationIfPresent()
        let isRecoveryFinalized = recoveryFinalization?.exactlyMatches(manifest) == true
        let requiresActivationProof: Bool
        if isRecoveryFinalized {
            // The marker is written only after checkpoint C and fsynced before
            // the journal can be cleared. Later ordinary local mutations make
            // the original digest stale, so a finalized live generation needs
            // structural validation rather than immutable snapshot equality.
            requiresActivationProof = false
        } else if hasRawJournal, let journal {
            switch journal.phase {
            case .activated:
                guard Self.journal(journal, exactlyMatches: manifest) else {
                    throw SyncStoreGenerationError.invalidManifest
                }
                requiresActivationProof = true
            case .verified:
                if journal.generationID == manifest.generationID {
                    guard Self.journal(journal, exactlyMatches: manifest) else {
                        throw SyncStoreGenerationError.invalidManifest
                    }
                    requiresActivationProof = true
                } else {
                    // Activation of G2 may fail after the atomic rename and
                    // restore the prior G1 pointer while the durable journal
                    // still names verified G2. G1 remains the coherent old
                    // generation behind the privacy gate and must stay usable
                    // for a bounded retry.
                    requiresActivationProof = false
                }
            case .prepared, .staging:
                // A new recovery can legitimately be staging while the prior
                // committed generation remains the readable old generation.
                requiresActivationProof = false
            }
        } else {
            // A generation without a matching post-checkpoint-C marker must
            // retain an exact durable journal. Missing or undecodable proof is
            // never interpreted as completed recovery.
            throw SyncStoreGenerationError.invalidManifest
        }

        if requiresActivationProof {
            // The atomic coordinator completed the only full materialization
            // replay and reconstructed the persisted ledger receipt before B.
            // The verified journal, immutable manifest and fsynced generation
            // are the durable activation proof after a crash. Repeating up to
            // 350k SwiftData rows plus 128 MiB of ledger synchronously during
            // app launch would add no publication safety and can trip the
            // watchdog. Keep relaunch validation structural and bounded.
            _ = try ShopSyncRecoveryLedger(
                generationStoreURL: storeURL,
                fileManager: fileManager,
                mode: .readExisting
            )
        }
        try validateActiveGenerationResourceBudget(storeURL: storeURL)
        try validateLiveGenerationStore(container: container)
        if isRecoveryFinalized, let recoveryFinalization {
            try restoreFinalizedMetadata(
                manifest: manifest,
                finalization: recoveryFinalization
            )
        }
        let active = SyncStoreActiveGeneration(
            container: container,
            manifest: manifest
        )
        cleanupAfterOpeningActiveStore(activeGenerationID: manifest.generationID)
        cleanupLegacyDefaultStoreAfterOpeningGeneration()
        return active
    }

    private func restoreFinalizedMetadata(
        manifest: SyncStoreGenerationManifest,
        finalization: SyncStoreRecoveryFinalization
    ) throws {
        guard finalization.exactlyMatches(manifest),
              DeviceInstallIDStore.identityHash(
                for: try DeviceInstallIDStore(defaults: defaults)
                    .requireDeviceInstallID()
              ) == finalization.deviceIdentityHash,
              AccountBindingStore(defaults: defaults).restoreFinalizedGenerationMetadata(
                accountHash: finalization.accountHash,
                storeIdentity: finalization.storeIdentity,
                generationID: finalization.generationID,
                watermark: finalization.watermark,
                recoveryScope: manifest.checkpoint.scope,
                deviceIdentityHash: finalization.deviceIdentityHash,
                boundAt: manifest.activatedAt
              ) else {
            throw SyncStoreGenerationError.defaultsConfigurationMismatch
        }
    }

    func prepareStaging(
        accountHash: String,
        shopID: UUID,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String
    ) throws -> SyncStoreGenerationHandle {
        lock.lock()
        defer { lock.unlock() }

        if let currentStaging {
            if try decodeAndValidateManifestIfPresent()?.generationID
                == currentStaging.generationID {
                // A prior activation crossed the durable pointer boundary but
                // failed during metadata/read-back work. Never hand that store
                // out as mutable staging again.
                self.currentStaging = nil
            } else if currentStaging.accountHash == accountHash,
                      currentStaging.shopID == shopID,
                      currentStaging.storeIdentity == storeIdentity,
                      currentStaging.deviceIdentityHash == deviceIdentityHash {
                return currentStaging
            } else {
                // Quarantine belongs to the captured scope. Release its
                // in-process handle so another authorized scope can stage
                // independently, while bounded directory retention keeps
                // the still-open store on disk until a safe relaunch.
                markCurrentStagingQuarantinedLocked(currentStaging)
                self.currentStaging = nil
            }
        }

        // A generation that was active earlier in this process may still be
        // referenced by SwiftUI/SwiftData even after a successful swap, so it
        // must not be unlinked here. Keep disk growth bounded and require a
        // normal relaunch, where only the newly opened active generation can
        // be referenced, before creating additional staging stores.
        guard try retainedGenerationDirectoryCount()
            < Self.maximumRetainedGenerationDirectories else {
            throw SyncStoreGenerationError.cleanupRequiresRelaunch
        }
        let retainedBytes = try retainedGenerationAllocatedBytes()
        let (projectedBytes, projectedOverflow) = retainedBytes.addingReportingOverflow(
            ShopSyncRecoveryLimits.maximumGenerationDirectoryBytes
        )
        guard !projectedOverflow,
              projectedBytes <= ShopSyncRecoveryLimits.maximumRetainedGenerationBytes else {
            throw SyncStoreGenerationError.cleanupRequiresRelaunch
        }
        // Reserve enough headroom for the worst admitted staging generation,
        // not merely the final low-space stop. This prevents a recovery from
        // filling the volume halfway through a page stream.
        try validateAvailableRecoveryCapacity(
            requiredAdditionalBytes: ShopSyncRecoveryLimits.maximumGenerationDirectoryBytes
        )

        let generationID = UUID()
        let relativeStorePath = "generations/\(generationID.uuidString.lowercased())/store.store"
        let storeURL = baseDirectory.appendingPathComponent(relativeStorePath)
        try fileManager.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let handle = SyncStoreGenerationHandle(
            generationID: generationID,
            storeURL: storeURL,
            relativeStorePath: relativeStorePath,
            accountHash: accountHash,
            shopID: shopID,
            storeIdentity: storeIdentity,
            deviceIdentityHash: deviceIdentityHash,
            container: try SyncStoreSchema.makeFileBackedContainer(at: storeURL)
        )
        currentStaging = handle
        return handle
    }

    func activate(
        _ staging: SyncStoreGenerationHandle,
        mutationFence: SyncStoreGenerationMutationFence,
        checkpointBeforeDownload: ShopSyncRecoveryCheckpoint,
        checkpoint: ShopSyncRecoveryCheckpoint,
        localVerification: ShopSyncRecoveryLocalVerificationReceipt,
        baselineRunID: UUID,
        journal: AccountRecoveryJournalSnapshot,
        activatedAt: Date = Date()
    ) throws -> SyncStoreActiveGeneration {
        lock.lock()
        defer { lock.unlock() }

        guard let currentStaging,
              currentStaging.generationID == staging.generationID else {
            throw SyncStoreGenerationError.stagingAlreadyOpen
        }
        guard fileManager.fileExists(atPath: staging.storeURL.path) else {
            throw SyncStoreGenerationError.stagingStoreMissing
        }
        try validateResourceBudget(for: staging)
        guard Self.isVerifiedRecoveryPublication(
                checkpointBeforeDownload: checkpointBeforeDownload,
                checkpoint: checkpoint
              ),
              checkpoint.shopId == staging.shopID,
              checkpoint.integrity.totalViolationCount == 0,
              journal.replacement.accountHash == staging.accountHash,
              journal.replacement.storeIdentity == staging.storeIdentity,
              journal.deviceIdentityHash == staging.deviceIdentityHash,
              journal.generationID == staging.generationID,
              journal.phase == .verified,
              journal.checkpointDigest == checkpoint.checkpointDigest,
              journal.watermark == checkpoint.maxEventID,
              journal.baselineRunID == baselineRunID,
              localVerification.matches(checkpoint),
              mutationFence.generationID == staging.generationID else {
            throw SyncStoreGenerationError.stagingScopeChanged
        }
        guard mutationFence == (try mutationFenceForGeneration(staging)) else {
            throw SyncStoreGenerationError.stagingChangedAfterVerification
        }
        let manifest = SyncStoreGenerationManifest(
            generationID: staging.generationID,
            relativeStorePath: staging.relativeStorePath,
            accountHash: staging.accountHash,
            shopID: staging.shopID,
            storeIdentity: staging.storeIdentity,
            deviceIdentityHash: staging.deviceIdentityHash,
            recoveryMode: journal.mode,
            checkpointBeforeDownload: checkpointBeforeDownload,
            checkpoint: checkpoint,
            localVerification: localVerification,
            baselineRunID: baselineRunID,
            activatedAt: activatedAt
        )
        let encoded = try Self.encoder.encode(manifest)
        guard encoded.count <= ShopSyncRecoveryLimits.maximumGenerationManifestBytes else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
        let previousManifestData = fileManager.fileExists(atPath: manifestURL.path)
            ? try boundedData(
                at: manifestURL,
                maximumBytes: ShopSyncRecoveryLimits.maximumGenerationManifestBytes
              )
            : nil
        // Flush the complete SQLite family and its parent directory before
        // publishing the generation pointer. A crash before the pointer rename
        // leaves G-old selected; a crash after it leaves durable G-new bytes,
        // including a non-empty WAL when SwiftData has one open.
        try synchronizeGenerationForActivation(staging)
        activationBoundaryProbe(.beforeManifestRename)
        do {
            try encoded.write(to: manifestURL, options: [.atomic])
            activationBoundaryProbe(.afterManifestRename)
            try synchronizeFile(manifestURL)
            try synchronizeDirectory(baseDirectory)
            // Once the atomic pointer has named this generation, it may never
            // be returned by prepareStaging/resetStaging, even if a later
            // read-back or UserDefaults repair fails.
            try activationDurabilityProbe()
            let readBack = try decodeAndValidateManifest()
            guard readBack == manifest else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        } catch {
            // This generation crossed the publication boundary. Even when we
            // successfully restore G-old below, G-new must never be handed
            // back as mutable staging: its SQLite family and ledger may have
            // been observed as active before the post-rename probe failed.
            markCurrentStagingQuarantinedLocked(staging)
            self.currentStaging = nil
            // Restore the previously verified pointer (or the legacy-default
            // absence of a pointer) before surfacing the failed activation.
            if let previousManifestData {
                try previousManifestData.write(to: manifestURL, options: [.atomic])
                try synchronizeFile(manifestURL)
            } else if fileManager.fileExists(atPath: manifestURL.path) {
                try fileManager.removeItem(at: manifestURL)
            }
            try synchronizeDirectory(baseDirectory)
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        self.currentStaging = nil
        return SyncStoreActiveGeneration(container: staging.container, manifest: manifest)
    }

    func activeManifest() throws -> SyncStoreGenerationManifest? {
        guard fileManager.fileExists(atPath: manifestURL.path) else { return nil }
        return try decodeAndValidateManifest()
    }

    func markRecoveryFinalized(_ manifest: SyncStoreGenerationManifest) throws {
        lock.lock()
        defer { lock.unlock() }
        guard try decodeAndValidateManifest() == manifest else {
            throw SyncStoreGenerationError.invalidManifest
        }
        let finalization = try SyncStoreRecoveryFinalization(manifest: manifest)
        let encoded = try Self.encoder.encode(finalization)
        guard encoded.count <= ShopSyncRecoveryLimits.maximumGenerationManifestBytes else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
        try encoded.write(to: recoveryFinalizationURL, options: [.atomic])
        try synchronizeFile(recoveryFinalizationURL)
        try synchronizeDirectory(baseDirectory)
        guard try decodeRecoveryFinalizationIfPresent() == finalization else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
    }

    func isRecoveryFinalized(_ manifest: SyncStoreGenerationManifest) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard try decodeAndValidateManifest() == manifest else { return false }
        return try decodeRecoveryFinalizationIfPresent()?.exactlyMatches(manifest) == true
    }

    func markStagingQuarantined(_ staging: SyncStoreGenerationHandle) {
        lock.lock()
        defer { lock.unlock() }
        guard currentStaging?.generationID == staging.generationID else { return }
        guard (try? decodeAndValidateManifestIfPresent()?.generationID)
            != staging.generationID else {
            currentStaging = nil
            return
        }
        markCurrentStagingQuarantinedLocked(staging)
        // Do not reuse a partially downloaded generation. The container may
        // still be referenced in this process, so physical deletion remains a
        // bounded next-launch operation.
        currentStaging = nil
    }

    private func markCurrentStagingQuarantinedLocked(_ staging: SyncStoreGenerationHandle) {
        let marker = staging.storeURL.deletingLastPathComponent()
            .appendingPathComponent("quarantined", isDirectory: false)
        try? Data().write(to: marker, options: [.atomic])
    }

    func resetStaging(_ staging: SyncStoreGenerationHandle) throws {
        lock.lock()
        defer { lock.unlock() }
        guard currentStaging?.generationID == staging.generationID else {
            throw SyncStoreGenerationError.stagingAlreadyOpen
        }
        guard try decodeAndValidateManifestIfPresent()?.generationID
            != staging.generationID else {
            currentStaging = nil
            throw SyncStoreGenerationError.stagingAlreadyOpen
        }
        try deleteAll(ProductPrice.self, from: staging.container)
        try deleteAll(Product.self, from: staging.container)
        try deleteAll(HistoryEntry.self, from: staging.container)
        try deleteAll(LocalPendingChange.self, from: staging.container)
        try deleteAll(SyncEventOutboxEntry.self, from: staging.container)
        try deleteAll(SupabaseCatalogBaselineRecord.self, from: staging.container)
        try deleteAll(Supplier.self, from: staging.container)
        try deleteAll(ProductCategory.self, from: staging.container)
        try deleteAll(SupabaseCatalogBaselineRun.self, from: staging.container)
        try validateResourceBudget(for: staging)
    }

    func validateResourceBudget(for staging: SyncStoreGenerationHandle) throws {
        let generationDirectory = staging.storeURL.deletingLastPathComponent().standardizedFileURL
        guard generationDirectory.deletingLastPathComponent()
                == generationsDirectory.standardizedFileURL,
              try allocatedBytes(in: generationDirectory)
                <= ShopSyncRecoveryLimits.maximumGenerationDirectoryBytes else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
        try validateAvailableRecoveryCapacity()
    }

    func captureMutationFence(
        for staging: SyncStoreGenerationHandle
    ) throws -> SyncStoreGenerationMutationFence {
        lock.lock()
        defer { lock.unlock() }
        guard currentStaging?.generationID == staging.generationID else {
            throw SyncStoreGenerationError.stagingAlreadyOpen
        }
        try validateResourceBudget(for: staging)
        return try mutationFenceForGeneration(staging)
    }

    /// Proves that no file belonging to the staged generation changed across
    /// an asynchronous recovery boundary.  The active generation is never
    /// consulted here: a failed proof keeps it selected and causes the caller
    /// to discard this staging directory instead of publishing a partial one.
    func validateMutationFence(
        _ expected: SyncStoreGenerationMutationFence,
        for staging: SyncStoreGenerationHandle
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard currentStaging?.generationID == staging.generationID,
              expected.generationID == staging.generationID else {
            throw SyncStoreGenerationError.stagingAlreadyOpen
        }
        try validateResourceBudget(for: staging)
        guard expected == (try mutationFenceForGeneration(staging)) else {
            throw SyncStoreGenerationError.stagingChangedAfterVerification
        }
    }

    private func cleanupAfterOpeningActiveStore(activeGenerationID: UUID) {
        bestEffortCleanup(excluding: activeGenerationID)
    }

    private func cleanupAfterOpeningDefaultStore() {
        bestEffortCleanup(excluding: nil)
    }

    private func retainedGenerationDirectoryCount() throws -> Int {
        try generationDirectories().count
    }

    private func retainedGenerationAllocatedBytes() throws -> Int {
        var total = 0
        for directory in try generationDirectories() {
            let bytes = try allocatedBytes(in: directory)
            let (next, overflow) = total.addingReportingOverflow(bytes)
            guard !overflow,
                  next <= ShopSyncRecoveryLimits.maximumRetainedGenerationBytes else {
                throw SyncStoreGenerationError.cleanupRequiresRelaunch
            }
            total = next
        }
        return total
    }

    private func allocatedBytes(in directory: URL) throws -> Int {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .fileAllocatedSizeKey
            ],
            options: []
        ) else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
        var total = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey,
                    .fileAllocatedSizeKey
                ]
            )
            guard values.isSymbolicLink != true else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
            let bytes = max(values.fileSize ?? 0, values.fileAllocatedSize ?? 0)
            let (next, overflow) = total.addingReportingOverflow(bytes)
            guard bytes >= 0, !overflow else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
            total = next
        }
        return total
    }

    private func validateActiveGenerationResourceBudget(storeURL: URL) throws {
        let directory = storeURL.deletingLastPathComponent().standardizedFileURL
        guard directory.deletingLastPathComponent() == generationsDirectory.standardizedFileURL,
              try allocatedBytes(in: directory)
                <= ShopSyncRecoveryLimits.maximumGenerationDirectoryBytes else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
    }

    private func mutationFenceForGeneration(
        _ staging: SyncStoreGenerationHandle
    ) throws -> SyncStoreGenerationMutationFence {
        let directory = staging.storeURL.deletingLastPathComponent().standardizedFileURL
        guard directory.deletingLastPathComponent() == generationsDirectory.standardizedFileURL,
              let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey,
                    .fileAllocatedSizeKey,
                    .contentModificationDateKey
                ],
                options: []
              ) else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
        let prefix = directory.path + "/"
        var files: [SyncStoreGenerationMutationFence.FileState] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [
                .isRegularFileKey,
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .fileAllocatedSizeKey,
                .contentModificationDateKey
            ])
            guard values.isSymbolicLink != true else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true,
                  fileURL.standardizedFileURL.path.hasPrefix(prefix),
                  let fileSize = values.fileSize,
                  let modificationDate = values.contentModificationDate,
                  fileSize >= 0 else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            guard let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
            files.append(.init(
                relativePath: String(fileURL.standardizedFileURL.path.dropFirst(prefix.count)),
                fileSize: fileSize,
                allocatedSize: max(fileSize, values.fileAllocatedSize ?? 0),
                modificationTimeBits: modificationDate.timeIntervalSinceReferenceDate.bitPattern,
                systemFileNumber: inode
            ))
            guard files.count <= 32 else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
        }
        return SyncStoreGenerationMutationFence(
            generationID: staging.generationID,
            files: files.sorted { $0.relativePath < $1.relativePath }
        )
    }

    private func validateAvailableRecoveryCapacity(
        requiredAdditionalBytes: Int = 0
    ) throws {
        let values = try baseDirectory.resourceValues(
            forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ]
        )
        let available = values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map(Int64.init)
        guard let available else {
            throw SyncStoreGenerationError.insufficientRecoveryDiskCapacity
        }
        let (required, overflow) = Int64(
            ShopSyncRecoveryLimits.minimumAvailableCapacityForRecovery
        ).addingReportingOverflow(Int64(requiredAdditionalBytes))
        if overflow || available < required {
            throw SyncStoreGenerationError.insufficientRecoveryDiskCapacity
        }
    }

    private func synchronizeGenerationForActivation(
        _ staging: SyncStoreGenerationHandle
    ) throws {
        let storeCandidates = [
            staging.storeURL,
            URL(fileURLWithPath: staging.storeURL.path + "-wal"),
            URL(fileURLWithPath: staging.storeURL.path + "-shm")
        ]
        for candidate in storeCandidates where fileManager.fileExists(atPath: candidate.path) {
            try synchronizeFile(candidate)
        }
        let generationDirectory = staging.storeURL.deletingLastPathComponent()
        let ledgerDirectory = generationDirectory
            .appendingPathComponent("recovery-ledger-v1", isDirectory: true)
        if fileManager.fileExists(atPath: ledgerDirectory.path) {
            for domain in ShopSyncRecoveryDomain.allCases {
                let ledgerURL = ledgerDirectory
                    .appendingPathComponent("\(domain.rawValue).ndjson", isDirectory: false)
                if fileManager.fileExists(atPath: ledgerURL.path) {
                    try synchronizeFile(ledgerURL)
                }
            }
            try synchronizeDirectory(ledgerDirectory)
        }
        try synchronizeDirectory(generationDirectory)
        // Persist the generation directory entry itself before publishing the
        // manifest pointer from the sibling base directory. Without this parent
        // fsync, a power loss could retain the pointer but lose G-new's name.
        try synchronizeDirectory(generationsDirectory)
    }

    private func synchronizeFile(_ url: URL) throws {
        #if canImport(Darwin)
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        #else
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.synchronize()
        #endif
    }

    private func synchronizeDirectory(_ url: URL) throws {
        #if canImport(Darwin)
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        #endif
    }

    private func generationDirectories() throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: generationsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { directory in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func bestEffortCleanup(excluding activeGenerationID: UUID?) {
        // Cleanup must never make a verified active store unavailable. Each
        // launch performs a small, idempotent amount of work; a retained-count
        // guard in prepareStaging prevents unbounded growth if deletion keeps
        // failing or many legacy directories already exist.
        guard let directories = try? generationDirectories() else { return }
        var deletionAttempts = 0
        for directory in directories {
            guard deletionAttempts < Self.maximumCleanupDeletionsPerLaunch else { return }
            guard UUID(uuidString: directory.lastPathComponent) != activeGenerationID else { continue }
            deletionAttempts += 1
            try? fileManager.removeItem(at: directory)
        }
    }

    private func cleanupLegacyDefaultStoreAfterOpeningGeneration() {
        guard let legacyDefaultStoreURL else { return }
        // This runs only after a verified generation manifest and its SQLite
        // store have both opened successfully in a fresh process. The legacy
        // default store is therefore no longer an active fallback. Remove the
        // bounded SQLite family idempotently; never touch arbitrary siblings.
        let candidates = [
            legacyDefaultStoreURL,
            URL(fileURLWithPath: legacyDefaultStoreURL.path + "-shm"),
            URL(fileURLWithPath: legacyDefaultStoreURL.path + "-wal")
        ]
        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            try? fileManager.removeItem(at: candidate)
        }
    }

    private func decodeAndValidateManifest() throws -> SyncStoreGenerationManifest {
        do {
            let data = try boundedData(
                at: manifestURL,
                maximumBytes: ShopSyncRecoveryLimits.maximumGenerationManifestBytes
            )
            let manifest = try Self.decoder.decode(SyncStoreGenerationManifest.self, from: data)
            guard manifest.schemaVersion == SyncStoreGenerationManifest.currentSchemaVersion,
                  manifest.relativeStorePath == "generations/\(manifest.generationID.uuidString.lowercased())/store.store",
                  manifest.accountHash.count == 64,
                  manifest.deviceIdentityHash.count == 64,
                  Self.isVerifiedRecoveryPublication(
                    checkpointBeforeDownload: manifest.checkpointBeforeDownload,
                    checkpoint: manifest.checkpoint
                  ),
                  manifest.checkpoint.shopId == manifest.shopID,
                  manifest.checkpoint.maxEventID != nil,
                  manifest.localVerification.matches(manifest.checkpoint) else {
                throw SyncStoreGenerationError.invalidManifest
            }
            _ = try resolvedStoreURL(for: manifest)
            return manifest
        } catch let error as SyncStoreGenerationError {
            throw error
        } catch {
            throw SyncStoreGenerationError.invalidManifest
        }
    }

    /// A generation may be downloaded behind checkpoint A and then proven
    /// against checkpoint B after its fenced tail is validated.  Requiring
    /// A==B here made a real, fully verified snapshot look like no work under
    /// concurrent writes.  Publication remains fail-closed: scope/shop must
    /// stay exact, B may only advance monotonically, and the caller supplies
    /// a receipt that matches B before the manifest pointer is written.
    private static func isVerifiedRecoveryPublication(
        checkpointBeforeDownload: ShopSyncRecoveryCheckpoint,
        checkpoint: ShopSyncRecoveryCheckpoint
    ) -> Bool {
        guard checkpointBeforeDownload.schemaVersion == checkpoint.schemaVersion,
              checkpointBeforeDownload.status == "ready",
              checkpoint.status == "ready",
              checkpointBeforeDownload.shopId == checkpoint.shopId,
              checkpointBeforeDownload.scope == checkpoint.scope,
              let beforeID = checkpointBeforeDownload.maxEventID,
              let verifiedID = checkpoint.maxEventID,
              verifiedID >= beforeID,
              let beforeCatalog = try? ShopSyncRecoveryCanonical.eventID(
                checkpointBeforeDownload.syncEvents.domainMaxIds.catalog
              ),
              let verifiedCatalog = try? ShopSyncRecoveryCanonical.eventID(
                checkpoint.syncEvents.domainMaxIds.catalog
              ),
              let beforePrices = try? ShopSyncRecoveryCanonical.eventID(
                checkpointBeforeDownload.syncEvents.domainMaxIds.prices
              ),
              let verifiedPrices = try? ShopSyncRecoveryCanonical.eventID(
                checkpoint.syncEvents.domainMaxIds.prices
              ),
              let beforeHistory = try? ShopSyncRecoveryCanonical.eventID(
                checkpointBeforeDownload.syncEvents.domainMaxIds.history
              ),
              let verifiedHistory = try? ShopSyncRecoveryCanonical.eventID(
                checkpoint.syncEvents.domainMaxIds.history
              ),
              verifiedCatalog >= beforeCatalog,
              verifiedPrices >= beforePrices,
              verifiedHistory >= beforeHistory else {
            return false
        }
        return true
    }

    private func decodeAndValidateManifestIfPresent() throws -> SyncStoreGenerationManifest? {
        guard fileManager.fileExists(atPath: manifestURL.path) else { return nil }
        return try decodeAndValidateManifest()
    }

    private func decodeRecoveryFinalizationIfPresent() throws -> SyncStoreRecoveryFinalization? {
        guard fileManager.fileExists(atPath: recoveryFinalizationURL.path) else { return nil }
        do {
            let data = try boundedData(
                at: recoveryFinalizationURL,
                maximumBytes: ShopSyncRecoveryLimits.maximumGenerationManifestBytes
            )
            let finalization = try Self.decoder.decode(
                SyncStoreRecoveryFinalization.self,
                from: data
            )
            guard finalization.schemaVersion == SyncStoreRecoveryFinalization.currentSchemaVersion,
                  finalization.accountHash.count == 64,
                  finalization.deviceIdentityHash.count == 64,
                  finalization.checkpointDigest.count == 64,
                  finalization.watermark >= 0 else {
                throw SyncStoreGenerationError.invalidManifest
            }
            return finalization
        } catch let error as SyncStoreGenerationError {
            throw error
        } catch {
            throw SyncStoreGenerationError.invalidManifest
        }
    }

    private func boundedData(at url: URL, maximumBytes: Int) throws -> Data {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              size.int64Value >= 0,
              size.int64Value <= Int64(maximumBytes) else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= maximumBytes else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
        return data
    }

    private func resolvedStoreURL(for manifest: SyncStoreGenerationManifest) throws -> URL {
        let resolved = baseDirectory
            .appendingPathComponent(manifest.relativeStorePath)
            .standardizedFileURL
        let expectedParent = baseDirectory.standardizedFileURL.path + "/"
        guard resolved.path.hasPrefix(expectedParent),
              resolved.deletingLastPathComponent().lastPathComponent
                == manifest.generationID.uuidString.lowercased() else {
            throw SyncStoreGenerationError.invalidManifest
        }
        return resolved
    }

    /// A committed generation is intentionally mutable after its recovery
    /// journal is cleared. Relaunch therefore validates the pointer, schema and
    /// the ability to read every table, but never compares live counts/outbox
    /// against the historical activation checkpoint.
    private func validateLiveGenerationStore(container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            try probe(Product.self, context: context)
            try probe(Supplier.self, context: context)
            try probe(ProductCategory.self, context: context)
            try probe(ProductPrice.self, context: context)
            try probe(HistoryEntry.self, context: context)
            try probe(LocalPendingChange.self, context: context)
            try probe(SyncEventOutboxEntry.self, context: context)
            try probe(SupabaseCatalogBaselineRun.self, context: context)
            try probe(SupabaseCatalogBaselineRecord.self, context: context)
        } catch {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
    }

    private func probe<Model: PersistentModel>(
        _: Model.Type,
        context: ModelContext
    ) throws {
        var descriptor = FetchDescriptor<Model>()
        descriptor.fetchLimit = 1
        _ = try context.fetch(descriptor)
    }

    private static func journal(
        _ journal: AccountRecoveryJournalSnapshot,
        exactlyMatches manifest: SyncStoreGenerationManifest
    ) -> Bool {
        journal.replacement.accountHash == manifest.accountHash
            && journal.replacement.storeIdentity == manifest.storeIdentity
            && journal.deviceIdentityHash == manifest.deviceIdentityHash
            && journal.mode == manifest.recoveryMode
            && journal.generationID == manifest.generationID
            && journal.checkpointDigest == manifest.checkpoint.checkpointDigest
            && journal.watermark == manifest.checkpoint.maxEventID
            && journal.baselineRunID == manifest.baselineRunID
            && manifest.checkpoint.shopId == manifest.shopID
    }

    private func deleteAll<Model: PersistentModel>(
        _: Model.Type,
        from container: ModelContainer,
        batchSize: Int = 256
    ) throws {
        while true {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            var descriptor = FetchDescriptor<Model>()
            descriptor.fetchLimit = max(1, batchSize)
            let rows = try context.fetch(descriptor)
            guard !rows.isEmpty else { return }
            try context.transaction {
                for row in rows { context.delete(row) }
                try context.save()
            }
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()
}

@MainActor
final class SyncStoreGenerationController: ObservableObject, @unchecked Sendable {
    static let shared = SyncStoreGenerationController()

    @Published private(set) var active: SyncStoreActiveGeneration
    @Published private(set) var loadFailureCode: String?
    private let repository: SyncStoreGenerationRepository?
    private let defaults: UserDefaults
    private var presentationBoundaryObserver: ((String) -> Void)?

    var modelContainer: ModelContainer { active.container }
    var activeManifest: SyncStoreGenerationManifest? { active.manifest }
    var presentationID: String { active.presentationID }

    func setPresentationBoundaryObserver(_ observer: @escaping (String) -> Void) {
        presentationBoundaryObserver = observer
    }

    func captureLease(for container: ModelContainer) -> SyncStoreGenerationLease? {
        guard active.container === container else { return nil }
        return SyncStoreGenerationLease(
            presentationID: active.presentationID,
            containerIdentity: ObjectIdentifier(active.container)
        )
    }

    func validateLease(_ lease: SyncStoreGenerationLease) throws {
        guard lease.presentationID == active.presentationID,
              lease.containerIdentity == ObjectIdentifier(active.container) else {
            throw SyncStoreGenerationError.staleGenerationLease
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.defaults = defaults
        let repository = try? SyncStoreGenerationRepository(defaults: defaults)
        self.repository = repository
        do {
            guard let repository else { throw SyncStoreGenerationError.unavailable }
            let loaded = try repository.loadActive()
            self.active = loaded
            self.loadFailureCode = nil
            Task126OwnerStoreGate.registerActiveGenerationContainer(loaded.container)
        } catch {
            let fallback = SyncStoreActiveGeneration(
                container: try! SyncStoreSchema.makeInMemoryContainer(),
                manifest: nil
            )
            self.active = fallback
            self.loadFailureCode = "sync_store_generation_load_failed"
            Task126OwnerStoreGate.registerActiveGenerationContainer(fallback.container)
        }
    }

    init(
        repository: SyncStoreGenerationRepository,
        defaults: UserDefaults = .standard
    ) throws {
        guard repository.defaults === defaults else {
            throw SyncStoreGenerationError.defaultsConfigurationMismatch
        }
        self.defaults = defaults
        self.repository = repository
        let loaded = try repository.loadActive()
        self.active = loaded
        self.loadFailureCode = nil
        Task126OwnerStoreGate.registerActiveGenerationContainer(loaded.container)
    }

    static func ephemeral() -> SyncStoreGenerationController {
        SyncStoreGenerationController(
            ephemeralContainer: try! SyncStoreSchema.makeInMemoryContainer()
        )
    }

    private init(ephemeralContainer: ModelContainer) {
        self.defaults = .standard
        self.repository = nil
        self.active = SyncStoreActiveGeneration(container: ephemeralContainer, manifest: nil)
        self.loadFailureCode = nil
        Task126OwnerStoreGate.registerActiveGenerationContainer(ephemeralContainer)
    }

    func prepareStaging(
        accountHash: String,
        shopID: UUID,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String
    ) throws -> SyncStoreGenerationHandle {
        guard let repository else { throw SyncStoreGenerationError.unavailable }
        return try repository.prepareStaging(
            accountHash: accountHash,
            shopID: shopID,
            storeIdentity: storeIdentity,
            deviceIdentityHash: deviceIdentityHash
        )
    }

    func captureMutationFence(
        for staging: SyncStoreGenerationHandle
    ) throws -> SyncStoreGenerationMutationFence {
        guard let repository else { throw SyncStoreGenerationError.unavailable }
        return try repository.captureMutationFence(for: staging)
    }

    func validateMutationFence(
        _ expected: SyncStoreGenerationMutationFence,
        for staging: SyncStoreGenerationHandle
    ) throws {
        guard let repository else { throw SyncStoreGenerationError.unavailable }
        try repository.validateMutationFence(expected, for: staging)
    }

    func activate(
        _ staging: SyncStoreGenerationHandle,
        mutationFence: SyncStoreGenerationMutationFence,
        checkpointBeforeDownload: ShopSyncRecoveryCheckpoint,
        checkpoint: ShopSyncRecoveryCheckpoint,
        localVerification: ShopSyncRecoveryLocalVerificationReceipt,
        baselineRunID: UUID,
        journal: AccountRecoveryJournalSnapshot,
        scope: Task126VerifiedOwnerStoreScope,
        activatedAt: Date = Date()
    ) async throws -> SyncStoreGenerationManifest {
        guard let repository else { throw SyncStoreGenerationError.unavailable }
        try Task.checkCancellation()
        guard scope.accountHash == staging.accountHash,
              scope.shopID == staging.shopID,
              scope.storeIdentity == staging.storeIdentity,
              scope.deviceIdentityHash == staging.deviceIdentityHash,
              scope.pendingReplacement == journal.replacement else {
            throw SyncStoreGenerationError.stagingScopeChanged
        }
        let defaults = self.defaults
        let activeContainer = active.container
        // This is the single publication boundary. It intentionally runs
        // synchronously on MainActor: durable manifest rename, in-process
        // container switch, retired-container registration, journal/binding/
        // watermark publication and lease invalidation must all happen before
        // a queued user writer can enter the non-recursive gate.
        return try Task126OwnerStoreGate.withValidatedAutomaticScopeLeaseInvalidated(
            expectedGeneration: scope.leaseGeneration
        ) {
            try Task.checkCancellation()
            if journal.mode == .sameScopeRecovery {
                guard try SameScopeRecoveryActiveWorkInspector.snapshot(
                    container: activeContainer,
                    scope: scope
                ).isDrained else {
                    throw AtomicGenerationRecoveryError.pendingLocalWorkRequiresDrain
                }
            }
            let activated = try repository.activate(
                staging,
                mutationFence: mutationFence,
                checkpointBeforeDownload: checkpointBeforeDownload,
                checkpoint: checkpoint,
                localVerification: localVerification,
                baselineRunID: baselineRunID,
                journal: journal,
                activatedAt: activatedAt
            )
            guard let manifest = activated.manifest else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            Task126OwnerStoreGate.replaceActiveGenerationContainerWithLeaseHeld(
                old: activeContainer,
                new: activated.container
            )
            // Never roll back to the retired container after the durable
            // pointer rename. A metadata failure leaves the new generation
            // active and the durable recovery journal fail-closed for retry.
            presentationBoundaryObserver?(activated.presentationID)
            active = activated
            guard AccountBindingStore(defaults: defaults)
                .commitActivatedGenerationWithLeaseHeld(manifest) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            loadFailureCode = nil
            return manifest
        }
    }

    func quarantine(_ staging: SyncStoreGenerationHandle) {
        repository?.markStagingQuarantined(staging)
    }

    /// Publishes durable proof that checkpoint C matched the active manifest.
    /// This marker is fsynced before the recovery journal may be cleared.
    func markRecoveryFinalized(
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> SyncStoreGenerationManifest {
        guard let repository,
              let manifest = active.manifest,
              manifest.accountHash == scope.accountHash,
              manifest.shopID == scope.shopID,
              manifest.storeIdentity == scope.storeIdentity,
              manifest.deviceIdentityHash == scope.deviceIdentityHash else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
            scope,
            defaults: defaults
        ) {
            try Task.checkCancellation()
            try repository.markRecoveryFinalized(manifest)
        }
        return manifest
    }

    func isActiveRecoveryFinalized(
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> Bool {
        guard let repository,
              let manifest = active.manifest,
              manifest.accountHash == scope.accountHash,
              manifest.shopID == scope.shopID,
              manifest.storeIdentity == scope.storeIdentity,
              manifest.deviceIdentityHash == scope.deviceIdentityHash else {
            return false
        }
        return try repository.isRecoveryFinalized(manifest)
    }

    func resetStaging(_ staging: SyncStoreGenerationHandle) throws {
        guard let repository else { throw SyncStoreGenerationError.unavailable }
        try repository.resetStaging(staging)
    }

    func validateResourceBudget(_ staging: SyncStoreGenerationHandle) throws {
        guard let repository else { throw SyncStoreGenerationError.unavailable }
        try repository.validateResourceBudget(for: staging)
    }

    func restoreActivatedMetadataIfAuthorized(
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> SyncStoreGenerationManifest {
        guard let manifest = active.manifest,
              manifest.accountHash == scope.accountHash,
              manifest.shopID == scope.shopID,
              manifest.storeIdentity == scope.storeIdentity,
              manifest.deviceIdentityHash == scope.deviceIdentityHash,
              DeviceInstallIDStore.identityHash(
                for: try DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID()
              ) == scope.deviceIdentityHash,
              try Self.restoreActivatedMetadata(
                manifest,
                defaults: defaults,
                expectedLeaseGeneration: scope.leaseGeneration
              ) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        return manifest
    }

    private static func restoreActivatedMetadata(
        _ manifest: SyncStoreGenerationManifest,
        defaults: UserDefaults,
        expectedLeaseGeneration: UInt64
    ) throws -> Bool {
        let bindingStore = AccountBindingStore(defaults: defaults)
        return try bindingStore.commitActivatedGeneration(
            manifest,
            expectedLeaseGeneration: expectedLeaseGeneration
        )
    }
}

nonisolated struct SameScopeRecoveryActiveWorkSnapshot: Sendable, Equatable {
    let pendingLocalCount: Int
    let outboxCount: Int

    var isDrained: Bool {
        pendingLocalCount == 0 && outboxCount == 0
    }
}

nonisolated enum SameScopeRecoveryActiveWorkInspector {
    static func snapshot(
        container: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> SameScopeRecoveryActiveWorkSnapshot {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let expectedOwner = scope.ownerUserID.uuidString.lowercased()
        let expectedStore = scope.storeIdentity.storeId
        var activePending = 0

        for change in try context.fetch(FetchDescriptor<LocalPendingChange>()) {
            guard let status = LocalPendingChangeStatus(rawValue: change.statusRaw) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            guard !status.isTerminal else { continue }
            guard change.ownerUserID == expectedOwner,
                  Task126OwnerStoreScope.normalizedStoreId(change.storeId) == expectedStore else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            activePending += 1
        }

        let scopedSnapshot = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(
                ownerUserID: scope.ownerUserID,
                storeIdentity: scope.storeIdentity
            )
        if scopedSnapshot.pendingCatalogChangeCount > 0
            || scopedSnapshot.pendingProductPriceChangeCount > 0
            || scopedSnapshot.pendingHistorySessionChangeCount > 0
            || scopedSnapshot.blockedCount > 0
            || scopedSnapshot.staleBaselineCount > 0
            || scopedSnapshot.sentCount > 0
            || scopedSnapshot.isCapped {
            activePending = max(activePending, 1)
        }

        var activeOutbox = 0
        for entry in try context.fetch(FetchDescriptor<SyncEventOutboxEntry>()) {
            guard let status = SyncEventOutboxStatus(rawValue: entry.statusRaw) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            switch status {
            case .sent, .blockedContract, .blockedAuth, .blockedSchema, .dead, .localOnly:
                continue
            case .pending, .sending, .failedRetryable:
                guard entry.ownerUserID == expectedOwner,
                      Task126OwnerStoreScope.normalizedStoreId(entry.storeId) == expectedStore else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                activeOutbox += 1
            }
        }

        return SameScopeRecoveryActiveWorkSnapshot(
            pendingLocalCount: activePending,
            outboxCount: activeOutbox
        )
    }
}
