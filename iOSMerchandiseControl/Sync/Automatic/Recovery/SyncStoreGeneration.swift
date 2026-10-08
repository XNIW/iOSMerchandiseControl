import Combine
import Foundation
import OSLog
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

nonisolated struct SyncStoreActiveMutationFence: Equatable, Sendable {
    let presentationID: String
    let files: [SyncStoreGenerationMutationFence.FileState]
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
    case beforeLocalWorkTransfer
    case afterLocalWorkPreparation
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
        deviceIdentityHash: String,
        resumeGenerationID: UUID? = nil
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
                      currentStaging.deviceIdentityHash == deviceIdentityHash,
                      resumeGenerationID == nil || resumeGenerationID == currentStaging.generationID {
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

        if let generationID = resumeGenerationID,
           try decodeAndValidateManifestIfPresent()?.generationID != generationID,
           fileManager.fileExists(atPath: generationsDirectory.appendingPathComponent(generationID.uuidString.lowercased())
             .appendingPathComponent("recovery-page-progress-v1.json").path),
           !fileManager.fileExists(atPath: generationsDirectory.appendingPathComponent(generationID.uuidString.lowercased())
             .appendingPathComponent("quarantined").path) {
            let relative = "generations/\(generationID.uuidString.lowercased())/store.store"
            let url = baseDirectory.appendingPathComponent(relative)
            let directory = url.deletingLastPathComponent()
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let fileValues = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            let progress = directory.appendingPathComponent("recovery-page-progress-v1.json")
            guard values.isDirectory == true, values.isSymbolicLink != true,
                  fileValues.isRegularFile == true, fileValues.isSymbolicLink != true,
                  !fileManager.fileExists(atPath: directory.appendingPathComponent("quarantined").path),
                  fileManager.fileExists(atPath: progress.path) else { throw SyncStoreGenerationError.invalidManifest }
            let handle = SyncStoreGenerationHandle(generationID: generationID, storeURL: url,
                relativeStorePath: relative, accountHash: accountHash, shopID: shopID,
                storeIdentity: storeIdentity, deviceIdentityHash: deviceIdentityHash,
                container: try SyncStoreSchema.makeFileBackedContainer(at: url))
            try validateResourceBudget(for: handle)
            currentStaging = handle
            return handle
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

    func observeLocalWorkBoundary(_ boundary: SyncStoreActivationBoundary) {
        activationBoundaryProbe(boundary)
    }

    func storeURLForLocalBodyReadback(_ manifest: SyncStoreGenerationManifest) throws -> URL {
        lock.lock(); defer { lock.unlock() }
        guard try decodeAndValidateManifestIfPresent() == manifest else { throw ShopSyncRecoveryContractError.checkpointChanged }
        return try resolvedStoreURL(for: manifest)
    }

    func captureActiveMutationFence(
        for active: SyncStoreActiveGeneration
    ) throws -> SyncStoreActiveMutationFence {
        lock.lock()
        defer { lock.unlock() }
        let currentManifest = try decodeAndValidateManifestIfPresent()
        guard currentManifest == active.manifest else {
            throw ShopSyncRecoveryContractError.checkpointChanged
        }
        let files: [SyncStoreGenerationMutationFence.FileState]
        if let manifest = active.manifest {
            let handle = SyncStoreGenerationHandle(
                generationID: manifest.generationID,
                storeURL: try resolvedStoreURL(for: manifest),
                relativeStorePath: manifest.relativeStorePath,
                accountHash: manifest.accountHash,
                shopID: manifest.shopID,
                storeIdentity: manifest.storeIdentity,
                deviceIdentityHash: manifest.deviceIdentityHash,
                container: active.container
            )
            files = try mutationFenceForGeneration(handle).files
        } else {
            // The legacy source has no generation directory. Limit the
            // fence to its own SQLite family, never unrelated app files.
            let storeURL = legacyDefaultStoreURL ?? SyncStoreSchema.defaultStoreURL
            files = try ["", "-wal", "-shm"].compactMap { suffix in
                let fileURL = URL(fileURLWithPath: storeURL.path + suffix)
                guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
                return try mutationFileState(fileURL, relativePath: fileURL.lastPathComponent)
            }.sorted { $0.relativePath < $1.relativePath }
            guard !files.isEmpty else { throw SyncStoreGenerationError.activeStoreMissing }
        }
        return SyncStoreActiveMutationFence(presentationID: active.presentationID, files: files)
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
            _ = modificationDate
            files.append(try mutationFileState(fileURL,
                relativePath: String(fileURL.standardizedFileURL.path.dropFirst(prefix.count))))
            guard files.count <= 32 else {
                throw SyncStoreGenerationError.generationResourceBudgetExceeded
            }
        }
        return SyncStoreGenerationMutationFence(
            generationID: staging.generationID,
            files: files.sorted { $0.relativePath < $1.relativePath }
        )
    }

    private func mutationFileState(
        _ fileURL: URL, relativePath: String
    ) throws -> SyncStoreGenerationMutationFence.FileState {
        let values = try fileURL.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
            .fileAllocatedSizeKey, .contentModificationDateKey
        ])
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        guard values.isSymbolicLink != true, values.isRegularFile == true,
              let size = values.fileSize, size >= 0,
              let modified = values.contentModificationDate,
              let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
        return .init(relativePath: relativePath, fileSize: size,
            allocatedSize: max(size, values.fileAllocatedSize ?? 0),
            modificationTimeBits: modified.timeIntervalSinceReferenceDate.bitPattern,
            systemFileNumber: inode)
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
        let bindingStore = AccountBindingStore(defaults: defaults)
        let journal = bindingStore.pendingRecoveryJournal
        let resumableGeneration: UUID? = {
            guard let journal, journal.phase == .staging || journal.phase == .verified,
                  let generation = journal.generationID,
                  journal.replacement.accountHash == bindingStore.currentBinding?.accountHash,
                  journal.replacement.storeIdentity == bindingStore.currentBinding?.storeIdentity,
                  let shop = SelectedShopStore(defaults: defaults).selectedShop(accountHash: journal.replacement.accountHash),
                  shop.localStoreIdentity == journal.replacement.storeIdentity,
                  let device = try? DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID(),
                  DeviceInstallIDStore.identityHash(for: device) == journal.deviceIdentityHash else { return nil }
            let directory = generationsDirectory.appendingPathComponent(generation.uuidString.lowercased())
            guard fileManager.fileExists(atPath: directory.appendingPathComponent("recovery-page-progress-v1.json").path),
                  !fileManager.fileExists(atPath: directory.appendingPathComponent("quarantined").path) else { return nil }
            return generation
        }()
        var deletionAttempts = 0
        for directory in directories {
            guard deletionAttempts < Self.maximumCleanupDeletionsPerLaunch else { return }
            let generation = UUID(uuidString: directory.lastPathComponent)
            guard generation != activeGenerationID, generation != resumableGeneration else { continue }
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

private nonisolated struct LocalBodyQualificationReadbackFailure: Error, Sendable {
    let stage: String // Only fixed literals assigned by the existing worker.
    let underlying: any Error
}

@MainActor
final class SyncStoreGenerationController: ObservableObject, @unchecked Sendable {
    static let shared = SyncStoreGenerationController()
    private static let qualificationLogger = Logger(
        subsystem: "com.niwcyber.iOSMerchandiseControl", category: "LocalBodyQualification"
    )

    private static func qualificationErrorReason(_ error: any Error) -> String {
        if error is CancellationError { return "cancelled" }
        if let failure = error as? SyncStoreGenerationError {
            switch failure {
            case .activationReadBackFailed: return "activation-readback-failed"
            case .invalidManifest: return "invalid-manifest"
            case .activeStoreMissing: return "active-store-missing"
            case .generationResourceBudgetExceeded: return "resource-budget"
            default: return "unknown"
            }
        }
        if let failure = error as? ShopSyncRecoveryContractError {
            switch failure {
            case .checkpointChanged: return "checkpoint-changed"
            case .persistedLedgerInvalid: return "persisted-ledger-invalid"
            case .resourceBudgetExceeded, .totalResourceBudgetExceeded: return "resource-budget"
            default: return "unknown"
            }
        }
        return "unknown"
    }

    @Published private(set) var active: SyncStoreActiveGeneration
    @Published private(set) var loadFailureCode: String?
    @Published private(set) var localBodyQualificationRevision = 0
    private let repository: SyncStoreGenerationRepository?
    private let defaults: UserDefaults
    private var presentationBoundaryObserver: ((String) -> Void)?
    private var localBodyQualificationTask: Task<Bool, Never>?
    private var manifestQualificationID: UUID?
    private var manifestQualificationRequested = false
    private var manifestQualificationOwner: UUID?
    #if DEBUG
    private var rootQualificationObservationTicket: UInt64 = 0
    // Tests hold the real detached readback before its existing publication guards.
    var localBodyQualificationBeforePublicationForTesting: (@MainActor () async -> Void)?
    #endif
    private struct EmptyRootProof {
        let scope: Task126VerifiedOwnerStoreScope
        let container: ModelContainer
        let fence: SyncStoreActiveMutationFence
    }
    private var emptyRootProof: EmptyRootProof?
    private var emptyPublicationSuccessorBudget = 0

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
            Task126OwnerStoreGate.registerActiveGenerationContainer(loaded.container, manifest: loaded.manifest)
            startLocalBodyQualification()
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
        Task126OwnerStoreGate.registerActiveGenerationContainer(loaded.container, manifest: loaded.manifest)
        startLocalBodyQualification()
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

    /// A genuine shop-context event may arrive before the current readback
    /// finishes. Coalesce it into one successor instead of cancelling/restarting
    /// a scan on every render, or losing readiness while the root stays hidden.
    func requestLocalBodyQualificationAfterShopContextChange(ownerUserID: UUID) {
        guard active.manifest != nil,
              !Task126OwnerStoreGate.hasCurrentLocalBodyProof(active.container) else { return }
        manifestQualificationOwner = ownerUserID
        if manifestQualificationID != nil {
            manifestQualificationRequested = true
        } else {
            startLocalBodyQualification(ownerUserID: ownerUserID)
        }
    }

    private func finishManifestQualification(_ identity: UUID, published: Bool, cancelled: Bool) {
        guard manifestQualificationID == identity else { return }
        manifestQualificationID = nil
        localBodyQualificationRevision &+= 1
        let retry = manifestQualificationRequested && !published && !cancelled
        let owner = manifestQualificationOwner
        manifestQualificationRequested = false
        if retry, let owner {
            startLocalBodyQualification(ownerUserID: owner)
        }
    }

    /// A publication and a later physical invalidation can coalesce into one
    /// hidden render. Only an actual fresh invalidation consumes this request.
    func requestEmptyRootQualificationAfterPublication(ownerUserID: UUID) {
        guard emptyPublicationSuccessorBudget > 0, localBodyQualificationRevision > 0,
              active.manifest == nil, let repository, let proof = emptyRootProof,
              proof.scope.ownerUserID == ownerUserID, active.container === proof.container,
              permitsEmptyQualificationReadback(scope: proof.scope, captured: active),
              let currentFence = try? repository.captureActiveMutationFence(for: active),
              currentFence != proof.fence else { return }
        // A successor does not reset the budget of its initiating lifecycle
        // request. Duplicate notifications cannot create an unbounded chain.
        emptyPublicationSuccessorBudget -= 1
        startEmptyRootQualification(ownerUserID: ownerUserID, repository: repository)
    }

    /// Full current catalog readback is deliberately outside MainActor. The
    /// result cannot authorize another scope, changed file or newer generation.
    func startLocalBodyQualification(ownerUserID: UUID? = nil) {
        guard let repository else {
            #if DEBUG
            Task144RootObservation.record("body-start", "branch.repository-absent", callsite: "SyncStoreGeneration.startLocalBodyQualification")
            #endif
            return
        }
        guard let manifest = active.manifest else {
            emptyPublicationSuccessorBudget = 1
            #if DEBUG
            Task144RootObservation.record("body-start", "branch.empty-root-dispatch", callsite: "SyncStoreGeneration.startLocalBodyQualification")
            #endif
            startEmptyRootQualification(ownerUserID: ownerUserID, repository: repository)
            return
        }
        emptyRootProof = nil
        guard !Task126OwnerStoreGate.hasCurrentLocalBodyProof(active.container) else {
            #if DEBUG
            Task144RootObservation.record("body-start", "branch.manifest-body-already-proven", callsite: "SyncStoreGeneration.startLocalBodyQualification")
            #endif
            return
        }
        #if DEBUG
        Task144RootObservation.record("body-start", "branch.manifest-body-qualification", callsite: "SyncStoreGeneration.startLocalBodyQualification")
        #endif
        localBodyQualificationTask?.cancel()
        let captured = active
        let container = captured.container
        Task126OwnerStoreGate.configureLocalBodyFence(container: container, proven: false,
            provider: { [weak container] in
                guard let container else { return nil }
                return try? repository.captureActiveMutationFence(for: .init(container: container, manifest: manifest))
            })
        let bindingStore = AccountBindingStore(defaults: defaults)
        let expectedBinding = bindingStore.currentBinding
        let expectedJournal = bindingStore.pendingRecoveryJournal
        let expectedPendingJournal = bindingStore.hasPendingReplacementJournal
        let expectedShop = SelectedShopStore(defaults: defaults).selectedShop(accountHash: manifest.accountHash)
        let device = try? DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID()
        let identity = UUID()
        manifestQualificationID = identity
        manifestQualificationRequested = false
        manifestQualificationOwner = ownerUserID
        #if DEBUG
        if Task144RootObservation.enabled { rootQualificationObservationTicket &+= 1 }
        #endif
        localBodyQualificationTask = Task { [weak self] in
            var published = false
            var firstFailureStage = "none"
            var firstFailureReason = "none"
            var firstPublicationFailure = "none"
            var authorityClosureEntered = false
            var authorityClosurePassed = false
            func noteFailure(_ stage: String, _ reason: String) {
                if firstFailureStage == "none" { firstFailureStage = stage; firstFailureReason = reason }
            }
            func observeAuthority(_ value: Bool, _ reason: String) -> Bool {
                if !value && firstPublicationFailure == "none" { firstPublicationFailure = reason }
                return value
            }
            func observeOptional<T>(_ value: T?, _ reason: String) -> T? {
                _ = observeAuthority(value != nil, reason)
                return value
            }
            defer {
                let ownerPresent = ownerUserID != nil
                let ownerMatches = ownerUserID.map(AccountBindingStore.accountHash(for:)) == manifest.accountHash
                let bindingMatches = expectedBinding?.accountHash == manifest.accountHash
                    && expectedBinding?.storeIdentity == manifest.storeIdentity
                let shopMatches = expectedShop?.shopID == manifest.shopID
                    && expectedShop?.localStoreIdentity == manifest.storeIdentity
                let currentTask = self?.manifestQualificationID == identity
                let currentContainer = self?.active.container === container
                let currentManifest = self?.active.manifest == manifest
                SyncStoreGenerationController.qualificationLogger.notice("populated-qualification published.\(published, privacy: .public) cancelled.\(Task.isCancelled, privacy: .public) first-stage.\(firstFailureStage, privacy: .public) first-reason.\(firstFailureReason, privacy: .public) first-publication.\(firstPublicationFailure, privacy: .public) authority-entered.\(authorityClosureEntered, privacy: .public) authority-passed.\(authorityClosurePassed, privacy: .public) owner-argument-present.\(ownerPresent, privacy: .public) owner-argument-matches.\(ownerMatches, privacy: .public) captured-binding-matches.\(bindingMatches, privacy: .public) captured-shop-matches.\(shopMatches, privacy: .public) captured-pending-journal.\(expectedPendingJournal, privacy: .public) captured-journal-present.\(expectedJournal != nil, privacy: .public) task-current.\(currentTask, privacy: .public) container-current.\(currentContainer, privacy: .public) manifest-current.\(currentManifest, privacy: .public) sdk-owner.NOT_OBSERVED")
                self?.finishManifestQualification(identity, published: published, cancelled: Task.isCancelled)
            }
            for _ in 0..<2 {
                guard !Task.isCancelled else { noteFailure("capture-before", "cancelled"); return false }
                let work = Task.detached(priority: .utility) {
                    var stage = "capture-before"
                    do {
                        try Task.checkCancellation()
                        let before = try repository.captureActiveMutationFence(for: captured)
                        stage = "body-validation"
                        try LocalCatalogBodyProofStore.validate(container: container, manifest: manifest,
                            storeURL: repository.storeURLForLocalBodyReadback(manifest))
                        stage = "capture-after"
                        let after = try repository.captureActiveMutationFence(for: captured)
                        guard before == after else { throw ShopSyncRecoveryContractError.checkpointChanged }
                        return after
                    } catch {
                        throw LocalBodyQualificationReadbackFailure(stage: stage, underlying: error)
                    }
                }
                do {
                    let fence = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
                    #if DEBUG
                    await self?.localBodyQualificationBeforePublicationForTesting?()
                    #endif
                    guard let self,
                          observeAuthority(!Task.isCancelled, "cancelled"),
                          observeAuthority(self.manifestQualificationID == identity, "qualification-replaced") else {
                        noteFailure("publication", firstPublicationFailure == "none" ? "controller-absent" : firstPublicationFailure)
                        return false
                    }
                    // The validated archive has stable provenance. Renewed
                    // selectedAt/name and writer leases are not its identity.
                    // Re-read authorization and publish under the same lease
                    // lock, so an old async writer gains no renewed authority.
                    authorityClosureEntered = false
                    authorityClosurePassed = false
                    published = Task126OwnerStoreGate.acceptLocalBodyProof(container: container, fence: fence) {
                        authorityClosureEntered = true
                        let selectedStore = SelectedShopStore(defaults: self.defaults)
                        let currentBinding = AccountBindingStore(defaults: self.defaults)
                        let currentJournal = currentBinding.pendingRecoveryJournal
                        guard observeAuthority(!Task.isCancelled, "cancelled"),
                              observeAuthority(self.active.container === container, "active-container-changed"),
                              observeAuthority(self.active.manifest == manifest, "active-manifest-changed"),
                              observeAuthority(self.defaults.string(forKey: "mobile.shopContext.activeAccountHash.v1") == manifest.accountHash, "active-account-mismatch"),
                              observeAuthority(ownerUserID.map(AccountBindingStore.accountHash(for:)).map({ $0 == manifest.accountHash }) ?? true, "owner-argument-mismatch"),
                              observeAuthority(currentBinding.currentBinding == expectedBinding, "binding-changed"),
                              observeAuthority(currentBinding.hasPendingReplacementJournal == expectedPendingJournal, "journal-presence-changed"),
                              // Journal progress describes staging, not this active archive.
                              // Its exact replacement binding (including boundAt), mode
                              // and device must remain the same recovery authority.
                              observeAuthority(currentJournal?.replacement == expectedJournal?.replacement, "journal-replacement-changed"),
                              observeAuthority(currentJournal?.mode == expectedJournal?.mode, "journal-mode-changed"),
                              observeAuthority(currentJournal?.deviceIdentityHash == expectedJournal?.deviceIdentityHash, "journal-device-changed"),
                              observeAuthority(expectedBinding?.accountHash == manifest.accountHash, "captured-binding-account-mismatch"),
                              observeAuthority(expectedBinding?.storeIdentity == manifest.storeIdentity, "captured-binding-store-mismatch"),
                              observeAuthority(selectedStore.isResolutionReady(accountHash: manifest.accountHash), "resolution-unready"),
                              let currentShop = observeOptional(selectedStore.selectedShop(accountHash: manifest.accountHash), "selected-shop-absent"),
                              observeAuthority(ownerUserID != nil || currentShop == expectedShop, "ownerless-selection-changed"),
                              observeAuthority(currentShop.shopID == expectedShop?.shopID, "selected-shop-changed"),
                              observeAuthority(currentShop.shopID == manifest.shopID, "selected-shop-manifest-mismatch"),
                              observeAuthority(currentShop.localStoreIdentity == manifest.storeIdentity, "selected-store-manifest-mismatch"),
                              observeAuthority(currentShop.role == expectedShop?.role, "selected-role-changed"),
                              observeAuthority(currentShop.status == expectedShop?.status, "selected-status-changed"),
                              observeAuthority(currentShop.canWrite == expectedShop?.canWrite, "selected-can-write-changed"),
                              observeAuthority(LinkedShop(shopID: currentShop.shopID, code: currentShop.code, name: currentShop.name,
                                role: currentShop.role, status: currentShop.status,
                                selectable: currentShop.selectable, canWrite: currentShop.canWrite).isValidSelection, "selected-shop-invalid"),
                              observeAuthority((try? DeviceInstallIDStore(defaults: self.defaults).requireDeviceInstallID()) == device, "device-changed"),
                              observeAuthority(device.map(DeviceInstallIDStore.identityHash(for:)) == manifest.deviceIdentityHash, "device-manifest-mismatch"),
                              observeAuthority((ownerUserID == nil || !selectedStore.hasConfirmedDeviceDenial(accountHash: manifest.accountHash,
                                shopID: manifest.shopID, deviceIdentityHash: manifest.deviceIdentityHash)), "confirmed-device-denial") else { return false }
                        if expectedPendingJournal {
                            guard let journal = observeOptional(currentJournal, "journal-absent"),
                                  observeAuthority(journal.mode == .sameScopeRecovery, "journal-not-same-scope"),
                                  observeAuthority(journal.replacement.accountHash == manifest.accountHash, "journal-account-mismatch"),
                                  observeAuthority(journal.replacement.storeIdentity == manifest.storeIdentity, "journal-store-mismatch"),
                                  observeAuthority(journal.deviceIdentityHash == manifest.deviceIdentityHash, "journal-device-manifest-mismatch") else { return false }
                        }
                        authorityClosurePassed = true
                        return true
                    }
                    if published { return true }
                    noteFailure("publication", authorityClosurePassed
                        ? "registered-container-or-current-physical-fence"
                        : firstPublicationFailure)
                } catch {
                    let failure = error as? LocalBodyQualificationReadbackFailure
                    let underlying = failure?.underlying ?? error
                    noteFailure(failure?.stage ?? "publication", Self.qualificationErrorReason(underlying))
                    // Preserve the original two-attempt checkpointChanged behavior exactly.
                    if underlying as? ShopSyncRecoveryContractError == .checkpointChanged { continue }
                    return false
                }
            }
            return false
        }
    }

    /// Presentation-only admission for a physically empty first bootstrap.
    /// It grants neither local mutation authority nor cloud readiness.
    func permitsScopedEmptyRoot(ownerUserID: UUID?) -> Bool {
        #if DEBUG
        if Task144RootObservation.enabled { return observeScopedEmptyRoot(ownerUserID: ownerUserID) }
        #endif
        guard let ownerUserID, let proof = emptyRootProof, let repository,
              loadFailureCode == nil, active.manifest == nil, active.container === proof.container,
              proof.scope.ownerUserID == ownerUserID,
              let current = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerUserID,
                defaults: defaults, allowsPendingReplacement: true),
              current.ownerUserID == proof.scope.ownerUserID,
              current.accountHash == proof.scope.accountHash,
              current.shopID == proof.scope.shopID,
              current.storeIdentity == proof.scope.storeIdentity,
              current.deviceInstallID == proof.scope.deviceInstallID,
              current.deviceIdentityHash == proof.scope.deviceIdentityHash,
              current.pendingReplacement == proof.scope.pendingReplacement,
              !SelectedShopStore(defaults: defaults).hasConfirmedDeviceDenial(accountHash: proof.scope.accountHash,
                shopID: proof.scope.shopID, deviceIdentityHash: proof.scope.deviceIdentityHash),
              (try? repository.captureActiveMutationFence(for: active)) == proof.fence,
              (try? Task126OwnerStoreGate.revalidateAutomaticScope(current, defaults: defaults)) != nil else { return false }
        // The physically empty presentation proof survives ordinary same-shop
        // refresh; an old writer still needs its original full lease unchanged.
        return true
    }

    private func permitsEmptyQualificationReadback(scope: Task126VerifiedOwnerStoreScope,
        captured: SyncStoreActiveGeneration) -> Bool {
        guard !Task.isCancelled, loadFailureCode == nil,
              active.container === captured.container, active.manifest == nil,
              AccountBindingStore(defaults: defaults).hasPendingReplacementJournal,
              let current = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: scope.ownerUserID,
                defaults: defaults, allowsPendingReplacement: true),
              current.ownerUserID == scope.ownerUserID,
              current.accountHash == scope.accountHash,
              current.shopID == scope.shopID,
              current.storeIdentity == scope.storeIdentity,
              current.deviceInstallID == scope.deviceInstallID,
              current.deviceIdentityHash == scope.deviceIdentityHash,
              current.pendingReplacement == scope.pendingReplacement,
              !SelectedShopStore(defaults: defaults).hasConfirmedDeviceDenial(accountHash: scope.accountHash,
                shopID: scope.shopID, deviceIdentityHash: scope.deviceIdentityHash),
              (try? Task126OwnerStoreGate.revalidateAutomaticScope(current, defaults: defaults)) != nil else { return false }
        return true
    }

    #if DEBUG
    private func observeScopedEmptyRoot(ownerUserID: UUID?) -> Bool {
        let observation = Task144RootObservation.Evaluation("empty-admission", callsite: "SyncStoreGeneration.permitsScopedEmptyRoot")
        var result = false
        defer { observation.finish(result) }
        guard let owner = observation.optional(ownerUserID, "owner"),
              let proof = observation.optional(emptyRootProof, "proof"),
              let repository = observation.optional(repository, "repository"),
              observation.check(loadFailureCode == nil, "load"),
              observation.check(active.manifest == nil, "manifest"),
              observation.check(active.container === proof.container, "container"),
              observation.check(proof.scope.ownerUserID == owner, "proof-owner"),
              let current = observation.attempt("capture-current", {
                  try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                      defaults: defaults, allowsPendingReplacement: true)
              }) else { return false }
        guard observation.check(current.ownerUserID == proof.scope.ownerUserID, "owner-equal"),
              observation.check(current.accountHash == proof.scope.accountHash, "account-equal"),
              observation.check(current.shopID == proof.scope.shopID, "shop-equal"),
              observation.check(current.storeIdentity == proof.scope.storeIdentity, "full-store-equal"),
              observation.check(current.deviceInstallID == proof.scope.deviceInstallID, "install-equal"),
              observation.check(current.deviceIdentityHash == proof.scope.deviceIdentityHash, "device-equal"),
              observation.check(current.pendingReplacement == proof.scope.pendingReplacement, "full-pending-equal"),
              observation.check(!SelectedShopStore(defaults: defaults).hasConfirmedDeviceDenial(
                  accountHash: proof.scope.accountHash, shopID: proof.scope.shopID,
                  deviceIdentityHash: proof.scope.deviceIdentityHash), "not-denied"),
              let fence = observation.attempt("physical-fence-read", {
                  try repository.captureActiveMutationFence(for: active)
              }),
              observation.check(fence == proof.fence, "physical-fence-equal"),
              observation.attempt("current-revalidate", {
                  try Task126OwnerStoreGate.revalidateAutomaticScope(current, defaults: defaults)
              }) != nil else { return false }
        result = true
        return true
    }

    private func observeEmptyPublicationAllowed(scope: Task126VerifiedOwnerStoreScope,
        captured: SyncStoreActiveGeneration, fence: SyncStoreActiveMutationFence,
        repository: SyncStoreGenerationRepository, ticket: UInt64) throws -> Task126VerifiedOwnerStoreScope? {
        let observation = Task144RootObservation.Evaluation("empty-publication", callsite: "SyncStoreGeneration.startEmptyRootQualification.after-await")
        var result = false
        observation.note("ticket-current", rootQualificationObservationTicket == ticket)
        defer { observation.finish(result) }
        guard observation.check(!Task.isCancelled, "not-cancelled"),
              observation.check(active.container === captured.container, "container"),
              observation.check(active.manifest == nil, "manifest"),
              let current = observation.attempt("capture-current", {
                  try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: scope.ownerUserID,
                      defaults: defaults, allowsPendingReplacement: true)
              }),
              observation.check(current.ownerUserID == scope.ownerUserID, "owner-equal"),
              observation.check(current.accountHash == scope.accountHash, "account-equal"),
              observation.check(current.shopID == scope.shopID, "shop-equal"),
              observation.check(current.storeIdentity == scope.storeIdentity, "full-store-equal"),
              observation.check(current.deviceInstallID == scope.deviceInstallID, "install-equal"),
              observation.check(current.deviceIdentityHash == scope.deviceIdentityHash, "device-equal"),
              observation.check(current.pendingReplacement == scope.pendingReplacement, "full-pending-equal"),
              observation.check(!SelectedShopStore(defaults: defaults).hasConfirmedDeviceDenial(
                  accountHash: scope.accountHash, shopID: scope.shopID,
                  deviceIdentityHash: scope.deviceIdentityHash), "not-denied") else { return nil }
        let currentFence = try observation.required("physical-fence-read", {
            try repository.captureActiveMutationFence(for: captured)
        })
        guard observation.check(currentFence == fence, "physical-fence-equal") else {
            throw ShopSyncRecoveryContractError.checkpointChanged
        }
        guard observation.attempt("current-revalidate", {
            try Task126OwnerStoreGate.revalidateAutomaticScope(current, defaults: defaults)
        }) != nil else { return nil }
        result = true
        return current
    }
    private func observeStartEmptyRootQualification(ownerUserID: UUID?, repository: SyncStoreGenerationRepository) {
        let observation = Task144RootObservation.Evaluation("empty-start", callsite: "SyncStoreGeneration.startEmptyRootQualification")
        var accepted = false
        var branch = "initial-guard-denied"
        defer { observation.finish(accepted, branch: branch) }
        guard observation.check(loadFailureCode == nil, "load"),
              let ownerUserID = observation.optional(ownerUserID, "owner"),
              observation.check(AccountBindingStore(defaults: defaults).hasPendingReplacementJournal, "pending-journal") else {
            emptyRootProof = nil
            return
        }
        let scope: Task126VerifiedOwnerStoreScope
        do {
            scope = try observation.required("capture-current", {
                try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerUserID,
                    defaults: defaults, allowsPendingReplacement: true)
            })
        } catch Task126OwnerStoreGateError.shopContextUnavailable {
            // Retain only a same-owner candidate during unresolved shop context.
            // Admission still requires a fresh current scope and physical fence.
            branch = "shop-context-unavailable-candidate-guard"
            guard let proof = observation.optional(emptyRootProof, "candidate-proof"),
                  observation.check(proof.scope.ownerUserID == ownerUserID, "candidate-owner"),
                  observation.check(!SelectedShopStore(defaults: defaults).hasConfirmedDeviceDenial(accountHash: proof.scope.accountHash,
                    shopID: proof.scope.shopID, deviceIdentityHash: proof.scope.deviceIdentityHash), "candidate-not-denied") else {
                emptyRootProof = nil
                return
            }
            branch = "shop-context-unavailable-candidate-retained"
            // Candidate retention is not presentation admission.
            return
        } catch {
            branch = Task144RootObservation.errorCategory(error)
            emptyRootProof = nil
            return
        }
        branch = "confirmed-device-denial"
        guard observation.check(!SelectedShopStore(defaults: defaults).hasConfirmedDeviceDenial(accountHash: scope.accountHash,
                shopID: scope.shopID, deviceIdentityHash: scope.deviceIdentityHash), "not-denied") else {
            emptyRootProof = nil
            return
        }
        if permitsScopedEmptyRoot(ownerUserID: ownerUserID) {
            accepted = true; branch = "existing-empty-proof-admitted"
            return
        }
        localBodyQualificationTask?.cancel()
        emptyRootProof = nil
        let captured = active
        rootQualificationObservationTicket &+= 1
        let ticket = rootQualificationObservationTicket
        let revisionAtStart = localBodyQualificationRevision
        branch = "empty-task-assigned-after-existing-cancel-statement"
        localBodyQualificationTask = Task { [weak self] in
            var completion = "NOT_COMPLETED"
            defer {
                Task144RootObservation.record("empty-task-completion",
                    "ticket.\(ticket);result.\(completion);controller-present.\(self != nil);ticket-current.\(self.map { $0.rootQualificationObservationTicket == ticket } ?? false);revision-changed.\(self.map { $0.localBodyQualificationRevision != revisionAtStart } ?? false)",
                    callsite: "SyncStoreGeneration.startEmptyRootQualification")
            }
            for _ in 0..<2 {
                guard self?.permitsEmptyQualificationReadback(scope: scope, captured: captured) == true else { return false }
                let work = Task.detached(priority: .utility) {
                    var stage = "check-cancellation"
                    do {
                    try Task.checkCancellation()
                    stage = "physical-fence-before"
                    let before = try repository.captureActiveMutationFence(for: captured)
                    stage = "existing-nine-empty-fetches"
                    let context = ModelContext(captured.container); context.autosaveEnabled = false
                    func requireEmpty<Model: PersistentModel>(_ type: Model.Type) throws {
                        try Task.checkCancellation()
                        var descriptor = FetchDescriptor<Model>(); descriptor.fetchLimit = 1
                        guard try context.fetch(descriptor).isEmpty else { throw SyncStoreGenerationError.activationReadBackFailed }
                    }
                    try requireEmpty(Product.self); try requireEmpty(Supplier.self); try requireEmpty(ProductCategory.self)
                    try requireEmpty(ProductPrice.self); try requireEmpty(HistoryEntry.self)
                    try requireEmpty(LocalPendingChange.self); try requireEmpty(SyncEventOutboxEntry.self)
                    try requireEmpty(SupabaseCatalogBaselineRun.self); try requireEmpty(SupabaseCatalogBaselineRecord.self)
                    stage = "physical-fence-after"
                    let after = try repository.captureActiveMutationFence(for: captured)
                    stage = "physical-fence-equality"
                    guard before == after else { throw ShopSyncRecoveryContractError.checkpointChanged }
                    return after
                    } catch {
                        Task144RootObservation.record("empty-worker-error", "ticket.\(ticket);stage.\(stage);error.\(Task144RootObservation.errorCategory(error))",
                            callsite: "SyncStoreGeneration.startEmptyRootQualification.worker")
                        throw error
                    }
                }
                do {
                    let fence = try await withTaskCancellationHandler { try await work.value } onCancel: {
                        Task144RootObservation.record("empty-worker-cancel", "ticket.\(ticket);existing-cancel-handler.entered",
                            callsite: "SyncStoreGeneration.startEmptyRootQualification.on-cancel")
                        work.cancel()
                    }
                    await self?.localBodyQualificationBeforePublicationForTesting?()
                    guard let self else {
                        completion = "self-absent"
                        return false
                    }
                    guard let current = try self.observeEmptyPublicationAllowed(scope: scope, captured: captured,
                        fence: fence, repository: repository, ticket: ticket) else {
                        completion = "after-await-guard-denied"
                        return false
                    }
                    self.emptyRootProof = EmptyRootProof(scope: current, container: captured.container, fence: fence)
                    self.localBodyQualificationRevision &+= 1
                    completion = "published"
                    return true
                } catch {
                    completion = Task144RootObservation.errorCategory(error)
                    if error as? ShopSyncRecoveryContractError == .checkpointChanged { continue }
                    return false
                }
            }
            return false
        }
        accepted = true
    }

    #endif

    private func startEmptyRootQualification(ownerUserID: UUID?, repository: SyncStoreGenerationRepository) {
        #if DEBUG
        if Task144RootObservation.enabled {
            observeStartEmptyRootQualification(ownerUserID: ownerUserID, repository: repository)
            return
        }
        #endif
        guard loadFailureCode == nil, let ownerUserID,
              AccountBindingStore(defaults: defaults).hasPendingReplacementJournal else {
            emptyRootProof = nil
            return
        }
        let scope: Task126VerifiedOwnerStoreScope
        do {
            scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerUserID,
                defaults: defaults, allowsPendingReplacement: true)
        } catch Task126OwnerStoreGateError.shopContextUnavailable {
            // Retain only a same-owner candidate during unresolved shop context.
            // Admission still requires a fresh current scope and physical fence.
            guard let proof = emptyRootProof, proof.scope.ownerUserID == ownerUserID,
                  !SelectedShopStore(defaults: defaults).hasConfirmedDeviceDenial(accountHash: proof.scope.accountHash,
                    shopID: proof.scope.shopID, deviceIdentityHash: proof.scope.deviceIdentityHash) else {
                emptyRootProof = nil
                return
            }
            return
        } catch {
            emptyRootProof = nil
            return
        }
        guard !SelectedShopStore(defaults: defaults).hasConfirmedDeviceDenial(accountHash: scope.accountHash,
                shopID: scope.shopID, deviceIdentityHash: scope.deviceIdentityHash) else {
            emptyRootProof = nil
            return
        }
        if permitsScopedEmptyRoot(ownerUserID: ownerUserID) { return }
        localBodyQualificationTask?.cancel()
        emptyRootProof = nil
        let captured = active
        localBodyQualificationTask = Task { [weak self] in
            // Retry only a changed physical readback, with the same captured
            // scope and every current publication guard evaluated afresh.
            for _ in 0..<2 {
                guard self?.permitsEmptyQualificationReadback(scope: scope, captured: captured) == true else { return false }
                let work = Task.detached(priority: .utility) {
                    try Task.checkCancellation()
                    let before = try repository.captureActiveMutationFence(for: captured)
                    let context = ModelContext(captured.container); context.autosaveEnabled = false
                    func requireEmpty<Model: PersistentModel>(_ type: Model.Type) throws {
                        try Task.checkCancellation()
                        var descriptor = FetchDescriptor<Model>(); descriptor.fetchLimit = 1
                        guard try context.fetch(descriptor).isEmpty else { throw SyncStoreGenerationError.activationReadBackFailed }
                    }
                    try requireEmpty(Product.self); try requireEmpty(Supplier.self); try requireEmpty(ProductCategory.self)
                    try requireEmpty(ProductPrice.self); try requireEmpty(HistoryEntry.self)
                    try requireEmpty(LocalPendingChange.self); try requireEmpty(SyncEventOutboxEntry.self)
                    try requireEmpty(SupabaseCatalogBaselineRun.self); try requireEmpty(SupabaseCatalogBaselineRecord.self)
                    let after = try repository.captureActiveMutationFence(for: captured)
                    guard before == after else { throw ShopSyncRecoveryContractError.checkpointChanged }
                    return after
                }
                do {
                    let fence = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
                    #if DEBUG
                    await self?.localBodyQualificationBeforePublicationForTesting?()
                    #endif
                    guard let self, !Task.isCancelled, self.active.container === captured.container,
                          self.active.manifest == nil,
                          let current = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: scope.ownerUserID,
                            defaults: self.defaults, allowsPendingReplacement: true),
                          current.ownerUserID == scope.ownerUserID,
                          current.accountHash == scope.accountHash,
                          current.shopID == scope.shopID,
                          current.storeIdentity == scope.storeIdentity,
                          current.deviceInstallID == scope.deviceInstallID,
                          current.deviceIdentityHash == scope.deviceIdentityHash,
                          current.pendingReplacement == scope.pendingReplacement,
                          !SelectedShopStore(defaults: self.defaults).hasConfirmedDeviceDenial(accountHash: scope.accountHash,
                            shopID: scope.shopID, deviceIdentityHash: scope.deviceIdentityHash) else { return false }
                    guard try repository.captureActiveMutationFence(for: captured) == fence else {
                        throw ShopSyncRecoveryContractError.checkpointChanged
                    }
                    guard (try? Task126OwnerStoreGate.revalidateAutomaticScope(current, defaults: self.defaults)) != nil else { return false }
                    self.emptyRootProof = EmptyRootProof(scope: current, container: captured.container, fence: fence)
                    self.localBodyQualificationRevision &+= 1
                    return true
                } catch {
                    if error as? ShopSyncRecoveryContractError == .checkpointChanged { continue }
                    return false
                }
            }
            return false
        }
    }

    func awaitLocalBodyQualification() async -> Bool {
        if let localBodyQualificationTask { return await localBodyQualificationTask.value }
        return active.manifest == nil || Task126OwnerStoreGate.hasCurrentLocalBodyProof(active.container)
    }

    func prepareStaging(
        accountHash: String,
        shopID: UUID,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String,
        resumeGenerationID: UUID? = nil
    ) throws -> SyncStoreGenerationHandle {
        guard let repository else { throw SyncStoreGenerationError.unavailable }
        return try repository.prepareStaging(
            accountHash: accountHash,
            shopID: shopID,
            storeIdentity: storeIdentity,
            deviceIdentityHash: deviceIdentityHash,
            resumeGenerationID: resumeGenerationID
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
        let capturedActive = active
        let activeContainer = capturedActive.container
        var publicationFence = mutationFence
        var sourceFence: SyncStoreActiveMutationFence?
        if journal.mode == .sameScopeRecovery {
            // C is immutable and verified before the only owned overlay.
            // Source scans and staging writes run off the UI thread without
            // holding the Save/ACK lease. A source write forces bounded retry.
            let preparation = Task.detached(priority: .utility) {
                try Task.checkCancellation()
                try repository.validateMutationFence(mutationFence, for: staging)
                let before = try repository.captureActiveMutationFence(for: capturedActive)
                repository.observeLocalWorkBoundary(.beforeLocalWorkTransfer)
                try SameScopeRecoveryLocalWorkTransfer.apply(
                    from: activeContainer, to: staging.container, scope: scope, stagingGenerationID: staging.generationID
                )
                let after = try repository.captureActiveMutationFence(for: capturedActive)
                guard before == after else { throw ShopSyncRecoveryContractError.checkpointChanged }
                try Task.checkCancellation()
                return (after, try repository.captureMutationFence(for: staging))
            }
            let prepared = try await withTaskCancellationHandler {
                try await preparation.value
            } onCancel: {
                preparation.cancel()
            }
            sourceFence = prepared.0
            publicationFence = prepared.1
            repository.observeLocalWorkBoundary(.afterLocalWorkPreparation)
        }
        // This is the single publication boundary. It intentionally runs
        // synchronously on MainActor: durable manifest rename, in-process
        // container switch, retired-container registration, journal/binding/
        // watermark publication and lease invalidation must all happen before
        // a queued user writer can enter the non-recursive gate.
        return try Task126OwnerStoreGate.withValidatedAutomaticScopeLeaseInvalidated(
            expectedGeneration: scope.leaseGeneration
        ) {
            try Task.checkCancellation()
            guard active.container === activeContainer,
                  active.presentationID == capturedActive.presentationID else {
                throw ShopSyncRecoveryContractError.checkpointChanged
            }
            if let sourceFence,
               try repository.captureActiveMutationFence(for: capturedActive) != sourceFence {
                throw ShopSyncRecoveryContractError.checkpointChanged
            }
            let activated = try repository.activate(
                staging,
                mutationFence: publicationFence,
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
                new: activated.container,
                manifest: manifest
            )
            Task126OwnerStoreGate.configureLocalBodyFenceWithLeaseHeld(container: activated.container, proven: true,
                provider: { [weak container = activated.container] in
                    guard let container else { return nil }
                    return try? repository.captureActiveMutationFence(for: .init(container: container, manifest: manifest))
                })
            #if DEBUG
            if Task144RootObservation.enabled {
                rootQualificationObservationTicket &+= 1
                Task144RootObservation.record("empty-task-invalidation", "branch.activation-cancel", callsite: "SyncStoreGeneration.activate")
            }
            #endif
            manifestQualificationID = nil
            manifestQualificationRequested = false
            manifestQualificationOwner = nil
            emptyPublicationSuccessorBudget = 0
            localBodyQualificationTask?.cancel()
            localBodyQualificationTask = nil
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
    /// Bounded materialization for synchronous continuation admission/readback.
    /// Unknown or foreign active work is deliberately rejected as well. SQL
    /// may still scan retained rows; this does not claim constant query cost.
    static func isContinuationDrained(container: ModelContainer) throws -> Bool {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var pending = FetchDescriptor<LocalPendingChange>(predicate: #Predicate {
            $0.statusRaw != "superseded" && $0.statusRaw != "acknowledged"
        })
        pending.fetchLimit = 1
        guard try context.fetch(pending).isEmpty else { return false }
        let terminalOutboxStatuses: [String] = [
            "sent", "blockedContract", "blockedAuth", "blockedSchema", "dead", "localOnly"
        ]
        var outbox = FetchDescriptor<SyncEventOutboxEntry>(
            predicate: #Predicate<SyncEventOutboxEntry> { entry in
                !terminalOutboxStatuses.contains(entry.statusRaw)
            }
        )
        outbox.fetchLimit = 1
        guard try context.fetch(outbox).isEmpty else { return false }
        var history = FetchDescriptor<HistoryEntry>(predicate: #Predicate {
            $0.remotePayloadFingerprint == nil || $0.localChangeRevision > $0.lastSyncedLocalRevision
        })
        history.fetchLimit = 1
        return try context.fetch(history).isEmpty
    }

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
        let localOnly = "localOnly"
        for entry in try context.fetch(FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate {
            $0.statusRaw != localOnly
        })) {
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
