import Foundation
import SwiftData
import XCTest
@testable import iOSMerchandiseControl

final class ShopSyncRecoveryContractTests: XCTestCase {
    @MainActor
    func testSameScopeRecoveryPromotionRequiresExplicitDestructiveCoordinator() throws {
        let suiteName = "SameScopePromotion-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let userID = UUID(uuidString: "34343434-3434-4434-8434-343434343434")!
        let accountHash = AccountBindingStore.accountHash(for: userID)
        let identity = LocalStoreIdentity(rawValue: "shop:same-scope-explicit-promotion")
        let deviceInstallID = try DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID()
        let deviceHash = DeviceInstallIDStore.identityHash(for: deviceInstallID)
        let bindingStore = AccountBindingStore(defaults: defaults)
        XCTAssertTrue(bindingStore.saveBinding(accountHash: accountHash, storeIdentity: identity))
        XCTAssertTrue(bindingStore.beginSameScopeRecovery(
            accountHash: accountHash,
            storeIdentity: identity,
            reason: "legacy-import-cap",
            deviceIdentityHash: deviceHash
        ))

        XCTAssertFalse(bindingStore.beginReplacement(
            accountHash: accountHash,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash
        ))
        XCTAssertEqual(bindingStore.pendingRecoveryJournal?.mode, .sameScopeRecovery)

        let container = try SyncStoreSchema.makeInMemoryContainer()
        let result = try AccountStoreReplacementCoordinator(
            context: ModelContext(container),
            bindingStore: bindingStore
        ).discardLocalDataAndBind(userID: userID, storeIdentity: identity)

        XCTAssertEqual(result.deletedProducts, 0)
        let promoted = try XCTUnwrap(bindingStore.pendingRecoveryJournal)
        XCTAssertEqual(promoted.mode, .accountOrShopReplacement)
        XCTAssertEqual(promoted.phase, .prepared)
        XCTAssertEqual(promoted.deviceIdentityHash, deviceHash)
        XCTAssertNil(promoted.generationID)
        XCTAssertNil(promoted.watermark)
    }

    @MainActor
    func testCorruptJournalStaysUntouchedUntilExplicitDestructiveReplacement() throws {
        let suiteName = "CorruptRecoveryJournal-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let rawKey = "sync.accountBinding.v1.pendingReplacement"
        let corruptBytes = Data([0xde, 0xad, 0xbe, 0xef])
        defaults.set(corruptBytes, forKey: rawKey)
        let bindingStore = AccountBindingStore(defaults: defaults)
        let userID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let identity = LocalStoreIdentity(rawValue: "shop:corrupt-journal-target")

        XCTAssertTrue(bindingStore.hasPendingReplacementJournal)
        XCTAssertNil(bindingStore.pendingRecoveryJournal)
        XCTAssertFalse(bindingStore.beginReplacement(
            accountHash: AccountBindingStore.accountHash(for: userID),
            storeIdentity: identity
        ))
        XCTAssertEqual(defaults.data(forKey: rawKey), corruptBytes)

        let container = try SyncStoreSchema.makeInMemoryContainer()
        let result = try AccountStoreReplacementCoordinator(
            context: ModelContext(container),
            bindingStore: bindingStore
        ).discardLocalDataAndBind(userID: userID, storeIdentity: identity)

        XCTAssertEqual(result.deletedProducts, 0)
        XCTAssertEqual(result.deletedOutboxEntries, 0)
        let repaired = try XCTUnwrap(bindingStore.pendingRecoveryJournal)
        XCTAssertEqual(repaired.phase, .prepared)
        XCTAssertEqual(repaired.mode, .accountOrShopReplacement)
        XCTAssertEqual(repaired.replacement.accountHash, AccountBindingStore.accountHash(for: userID))
        XCTAssertEqual(repaired.replacement.storeIdentity, identity)
        XCTAssertNotEqual(defaults.data(forKey: rawKey), corruptBytes)
    }

    func testQuarantinedGenerationIsNotReusedAcrossScopeChange() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncStoreGenerationScope-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let repository = try SyncStoreGenerationRepository(baseDirectory: temporaryRoot)
        let first = try repository.prepareStaging(
            accountHash: String(repeating: "a", count: 64),
            shopID: UUID(uuidString: "00000000-0000-4000-8000-000000000140")!,
            storeIdentity: LocalStoreIdentity(rawValue: "shop:scope-a"),
            deviceIdentityHash: String(repeating: "1", count: 64)
        )
        repository.markStagingQuarantined(first)

        let second = try repository.prepareStaging(
            accountHash: String(repeating: "b", count: 64),
            shopID: UUID(uuidString: "00000000-0000-4000-8000-000000000141")!,
            storeIdentity: LocalStoreIdentity(rawValue: "shop:scope-b"),
            deviceIdentityHash: String(repeating: "2", count: 64)
        )

        XCTAssertNotEqual(first.generationID, second.generationID)
        XCTAssertNotEqual(first.storeURL, second.storeURL)
    }

    func testGenerationRetentionIsBoundedUntilSafeRelaunchCleanup() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncStoreGenerationBound-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let repository = try SyncStoreGenerationRepository(baseDirectory: temporaryRoot)

        for index in 0..<3 {
            let staging = try repository.prepareStaging(
                accountHash: String(repeating: String(index), count: 64),
                shopID: UUID(),
                storeIdentity: LocalStoreIdentity(rawValue: "shop:retained-\(index)"),
                deviceIdentityHash: String(repeating: "f", count: 64)
            )
            repository.markStagingQuarantined(staging)
        }

        XCTAssertThrowsError(try repository.prepareStaging(
            accountHash: String(repeating: "a", count: 64),
            shopID: UUID(),
            storeIdentity: LocalStoreIdentity(rawValue: "shop:blocked-until-relaunch"),
            deviceIdentityHash: String(repeating: "e", count: 64)
        )) { error in
            XCTAssertEqual(error as? SyncStoreGenerationError, .cleanupRequiresRelaunch)
        }
    }

    func testFailedPostRenameDurabilityProbeRestoresPointerAndForbidsStagingReuse() throws {
        enum InjectedFailure: Error { case afterManifestWrite }

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncStoreGenerationRollback-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let boundaryRecorder = SyncStoreActivationBoundaryRecorder()
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: temporaryRoot,
            activationBoundaryProbe: { boundaryRecorder.append($0) },
            activationDurabilityProbe: { throw InjectedFailure.afterManifestWrite }
        )
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let shop = UUID(uuidString: "00000000-0000-4000-8000-000000000140")!
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let deviceHash = String(repeating: "d", count: 64)
        let identity = LocalStoreIdentity(rawValue: shop.uuidString.lowercased())
        let staging = try repository.prepareStaging(
            accountHash: accountHash,
            shopID: shop,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash
        )
        let checkpoint = try makeCheckpoint(owner: owner, shop: shop)
        let receipt = ShopSyncRecoveryLocalVerificationReceipt(
            suppliers: checkpoint.catalog.suppliers,
            categories: checkpoint.catalog.categories,
            products: checkpoint.catalog.products,
            prices: checkpoint.prices,
            history: checkpoint.history,
            images: checkpoint.images,
            catalogDigest: checkpoint.catalog.digest,
            relationshipViolationCount: 0,
            pendingLocalCount: 0,
            outboxCount: 0
        )
        let baselineID = UUID()
        let context = ModelContext(staging.container)
        context.insert(SupabaseCatalogBaselineRun(
            baselineRunID: baselineID,
            ownerUserUUID: owner,
            status: .valid,
            appliedAt: Date(),
            productCount: 0,
            supplierCount: 0,
            categoryCount: 0,
            tombstoneCount: 0
        ))
        try context.save()
        let ledger = try ShopSyncRecoveryLedger(generationStoreURL: staging.storeURL)
        try ledger.closeWrites()
        let journal = AccountRecoveryJournalSnapshot(
            replacement: AccountBinding(
                accountHash: accountHash,
                storeIdentity: identity,
                boundAt: Date()
            ),
            mode: .sameScopeRecovery,
            phase: .verified,
            deviceIdentityHash: deviceHash,
            generationID: staging.generationID,
            checkpointDigest: checkpoint.checkpointDigest,
            watermark: checkpoint.maxEventID,
            baselineRunID: baselineID
        )

        let mutationFence = try repository.captureMutationFence(for: staging)
        XCTAssertThrowsError(try repository.activate(
            staging,
            mutationFence: mutationFence,
            checkpointBeforeDownload: checkpoint,
            checkpoint: checkpoint,
            localVerification: receipt,
            baselineRunID: baselineID,
            journal: journal
        )) { error in
            XCTAssertEqual(error as? SyncStoreGenerationError, .activationReadBackFailed)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.manifestURL.path))
        XCTAssertEqual(
            boundaryRecorder.snapshot(),
            [.beforeManifestRename, .afterManifestRename]
        )
        XCTAssertThrowsError(try repository.resetStaging(staging)) { error in
            XCTAssertEqual(error as? SyncStoreGenerationError, .stagingAlreadyOpen)
        }

        let retry = try repository.prepareStaging(
            accountHash: accountHash,
            shopID: shop,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash
        )
        XCTAssertNotEqual(retry.generationID, staging.generationID)
    }

    func testVerifiedGenerationReopensBeforeBoundedLegacyStoreCleanup() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncStoreGenerationRelaunch-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let defaultsSuite = "SyncStoreGenerationRelaunch-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let legacyStoreURL = temporaryRoot.appendingPathComponent("legacy-default.store")
        let legacySidecars = [
            legacyStoreURL,
            URL(fileURLWithPath: legacyStoreURL.path + "-shm"),
            URL(fileURLWithPath: legacyStoreURL.path + "-wal")
        ]
        for url in legacySidecars {
            XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: Data("legacy".utf8)))
        }
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: temporaryRoot.appendingPathComponent("generation-root"),
            legacyDefaultStoreURL: legacyStoreURL,
            defaults: defaults
        )
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let shop = UUID(uuidString: "00000000-0000-4000-8000-000000000140")!
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let deviceInstallID = try DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID()
        let deviceHash = DeviceInstallIDStore.identityHash(for: deviceInstallID)
        let identity = LocalStoreIdentity(rawValue: shop.uuidString.lowercased())
        let bindingStore = AccountBindingStore(defaults: defaults)
        XCTAssertTrue(bindingStore.saveBinding(
            accountHash: accountHash,
            storeIdentity: identity
        ))
        XCTAssertTrue(bindingStore.beginSameScopeRecovery(
            accountHash: accountHash,
            storeIdentity: identity,
            reason: "unit-activation-proof",
            deviceIdentityHash: deviceHash
        ))
        XCTAssertTrue(FileManager.default.fileExists(atPath: repository.recoveryJournalURL.path))
        let preparedJournal = try XCTUnwrap(bindingStore.pendingRecoveryJournal)
        XCTAssertEqual(preparedJournal.phase, .prepared)
        XCTAssertEqual(preparedJournal.replacement.accountHash, accountHash)
        XCTAssertEqual(preparedJournal.replacement.storeIdentity, identity)
        XCTAssertEqual(preparedJournal.deviceIdentityHash, deviceHash)
        defaults.removeObject(forKey: "sync.accountBinding.v1.pendingReplacement")
        let diskOnlyRelaunchStore = AccountBindingStore(defaults: defaults)
        XCTAssertEqual(diskOnlyRelaunchStore.pendingRecoveryJournal, preparedJournal)
        let staging = try repository.prepareStaging(
            accountHash: accountHash,
            shopID: shop,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash
        )
        let checkpoint = try makeCheckpoint(
            owner: owner,
            shop: shop,
            deviceInstallID: deviceInstallID
        )
        let receipt = ShopSyncRecoveryLocalVerificationReceipt(
            suppliers: checkpoint.catalog.suppliers,
            categories: checkpoint.catalog.categories,
            products: checkpoint.catalog.products,
            prices: checkpoint.prices,
            history: checkpoint.history,
            images: checkpoint.images,
            catalogDigest: checkpoint.catalog.digest,
            relationshipViolationCount: 0,
            pendingLocalCount: 0,
            outboxCount: 0
        )
        let baselineID = UUID()
        let context = ModelContext(staging.container)
        context.insert(SupabaseCatalogBaselineRun(
            baselineRunID: baselineID,
            ownerUserUUID: owner,
            status: .valid,
            appliedAt: Date(),
            productCount: 0,
            supplierCount: 0,
            categoryCount: 0,
            tombstoneCount: 0
        ))
        try context.save()
        let ledger = try ShopSyncRecoveryLedger(generationStoreURL: staging.storeURL)
        try ledger.closeWrites()
        let journal = AccountRecoveryJournalSnapshot(
            replacement: AccountBinding(
                accountHash: accountHash,
                storeIdentity: identity,
                boundAt: Date()
            ),
            mode: .sameScopeRecovery,
            phase: .verified,
            deviceIdentityHash: deviceHash,
            generationID: staging.generationID,
            checkpointDigest: checkpoint.checkpointDigest,
            watermark: checkpoint.maxEventID,
            baselineRunID: baselineID
        )
        XCTAssertTrue(bindingStore.recordPendingRecoveryStaging(
            accountHash: accountHash,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash,
            generationID: staging.generationID
        ))
        XCTAssertTrue(bindingStore.recordPendingRecoveryVerified(
            accountHash: accountHash,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash,
            generationID: staging.generationID,
            checkpointDigest: checkpoint.checkpointDigest,
            watermark: try XCTUnwrap(checkpoint.maxEventID),
            baselineRunID: baselineID
        ))
        let mutationFence = try repository.captureMutationFence(for: staging)
        let activated = try repository.activate(
            staging,
            mutationFence: mutationFence,
            checkpointBeforeDownload: checkpoint,
            checkpoint: checkpoint,
            localVerification: receipt,
            baselineRunID: baselineID,
            journal: journal
        )
        XCTAssertEqual(activated.manifest?.generationID, staging.generationID)
        XCTAssertTrue(legacySidecars.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })

        let durableJournalData = try Data(contentsOf: repository.recoveryJournalURL)
        try FileManager.default.removeItem(at: repository.recoveryJournalURL)
        defaults.removeObject(forKey: "sync.accountBinding.v1.pendingReplacement")
        let missingJournalRepository = try SyncStoreGenerationRepository(
            baseDirectory: temporaryRoot.appendingPathComponent("generation-root"),
            legacyDefaultStoreURL: legacyStoreURL,
            defaults: defaults
        )
        XCTAssertThrowsError(try missingJournalRepository.loadActive()) { error in
            XCTAssertEqual(error as? SyncStoreGenerationError, .invalidManifest)
        }
        try durableJournalData.write(to: repository.recoveryJournalURL, options: [.atomic])

        try repository.markRecoveryFinalized(try XCTUnwrap(activated.manifest))
        bindingStore.clearPendingReplacement()

        // Once activation metadata is complete, this is a normal mutable live
        // generation. Snapshot counts and pending/outbox are not replayed on
        // relaunch, and all new rows remain intact.
        context.insert(Product(barcode: "TASK139-LIVE-MUTATION"))
        context.insert(LocalPendingChange(
            ownerUserID: owner,
            storeId: identity.storeId,
            localStoreId: identity.localStoreId,
            entityKind: .product,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: "product:TASK139-LIVE-MUTATION"
        ))
        context.insert(SyncEventOutboxEntry(
            ownerUserID: owner.uuidString.lowercased(),
            storeId: identity.storeId,
            localStoreId: identity.localStoreId,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "products:count=1",
            metadataShape: "source=unit",
            nextRetryAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        ))
        try context.save()
        let relaunchedRepository = try SyncStoreGenerationRepository(
            baseDirectory: temporaryRoot.appendingPathComponent("generation-root"),
            legacyDefaultStoreURL: legacyStoreURL,
            defaults: defaults
        )
        let reopened = try relaunchedRepository.loadActive()

        XCTAssertEqual(reopened.manifest?.generationID, staging.generationID)
        let reopenedContext = ModelContext(reopened.container)
        XCTAssertEqual(try reopenedContext.fetchCount(FetchDescriptor<Product>()), 1)
        XCTAssertEqual(try reopenedContext.fetchCount(FetchDescriptor<LocalPendingChange>()), 1)
        XCTAssertEqual(try reopenedContext.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()), 1)
        XCTAssertTrue(legacySidecars.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testDurableJournalCorruptionAndOversizeStayFailClosed() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncStoreDurableJournalCorrupt-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let suiteName = "SyncStoreDurableJournalCorrupt-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: temporaryRoot,
            defaults: defaults
        )
        let store = AccountBindingStore(defaults: defaults)

        try Data([0xde, 0xad, 0xbe, 0xef]).write(
            to: repository.recoveryJournalURL,
            options: [.atomic]
        )
        XCTAssertTrue(store.hasPendingReplacementJournal)
        XCTAssertNil(store.pendingRecoveryJournal)

        try Data(repeating: 0x41, count: 512 * 1_024 + 1).write(
            to: repository.recoveryJournalURL,
            options: [.atomic]
        )
        XCTAssertTrue(store.hasPendingReplacementJournal)
        XCTAssertNil(store.pendingRecoveryJournal)
    }

    func testStandardDefaultsCannotBeRedirectedByTemporaryRepositoryRegistration() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncStoreStandardRegistry-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: temporaryRoot,
            defaults: .standard
        )
        let standardStore = AccountBindingStore(defaults: .standard)

        XCTAssertNotEqual(
            standardStore.durableRecoveryJournalURLForTesting,
            repository.recoveryJournalURL
        )
        XCTAssertEqual(
            standardStore.durableRecoveryJournalURLForTesting?.lastPathComponent,
            "recovery-journal.json"
        )
    }

    @MainActor
    func testControllerRejectsMismatchedDefaultsOwnership() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncStoreDefaultsInvariant-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let firstSuite = "SyncStoreDefaultsInvariant-A-\(UUID().uuidString)"
        let secondSuite = "SyncStoreDefaultsInvariant-B-\(UUID().uuidString)"
        let first = try XCTUnwrap(UserDefaults(suiteName: firstSuite))
        let second = try XCTUnwrap(UserDefaults(suiteName: secondSuite))
        defer {
            first.removePersistentDomain(forName: firstSuite)
            second.removePersistentDomain(forName: secondSuite)
        }
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: temporaryRoot,
            defaults: first
        )

        XCTAssertThrowsError(try SyncStoreGenerationController(
            repository: repository,
            defaults: second
        )) { error in
            XCTAssertEqual(error as? SyncStoreGenerationError, .defaultsConfigurationMismatch)
        }
    }

    func testShopScopedGoldenVectorAndExplicitNullCursor() throws {
        let shopID = UUID(uuidString: "00000000-0000-4000-8000-000000000140")!
        let scope = ShopSyncRecoveryScope(
            kind: "shop_scoped",
            key: "12ba5e60a6bf564660cb3acbc6a2cb58"
                + "a03162efcfd5c5ed151fd16b74fd81ba",
            legacyOwnerKey: nil,
            accountKey: ShopSyncRecoveryCanonical.sha256("golden-account-139"),
            deviceKey: "257e184cfeb7888e6eb749b3ca4b2d64"
                + "4ef4f278bde892714196a3980ded96e6"
        )

        XCTAssertNoThrow(try scope.validate(
            expectedShopID: shopID,
            expectedDeviceIdentifier: "device-139"
        ))
        let data = try JSONEncoder().encode(ShopSyncRecoveryPageParameters(
            shopID: shopID,
            deviceIdentifier: "device-139",
            domain: "products",
            afterID: nil,
            limit: 60,
            expectedScopeKey: scope.key,
            expectedEventMaxID: "140",
            expectedDomainEventMaxID: "140"
        ))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertTrue(object.keys.contains("p_after_id"))
        XCTAssertTrue(object["p_after_id"] is NSNull)
    }

    func testV6RecoveryFenceAdvancesOnlyAtExactDurableWatermarkAcrossRelaunch() throws {
        let suiteName = "ShopSyncRecoveryFenceAdvance-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let owner = UUID(uuidString: "34343434-3434-4434-8434-343434343439")!
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let deviceInstallID = try DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID()
        let deviceHash = DeviceInstallIDStore.identityHash(for: deviceInstallID)
        let identity = LocalStoreIdentity(rawValue: "shop:v6-fence-advance")
        let scopeKey = ShopSyncRecoveryCanonical.sha256("v6-fence-scope")
        let scope = ShopSyncRecoveryScope(
            kind: "shop_scoped",
            key: scopeKey,
            legacyOwnerKey: nil,
            accountKey: accountHash,
            deviceKey: deviceHash
        )
        let initial = ShopSyncRecoveryFenceStore(defaults: defaults)
        XCTAssertTrue(initial.saveAuthoritative(
            scope: scope,
            watermark: 101,
            accountHash: accountHash,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash
        ))
        XCTAssertEqual(initial.scopeKey(
            accountHash: accountHash,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash,
            watermark: 101
        ), scopeKey)
        XCTAssertNil(initial.scopeKey(
            accountHash: accountHash,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash,
            watermark: 102
        ))

        // A fresh instance models relaunch. The next V6 request can use only
        // the new exact fence; retaining the old cursor would fail closed.
        let relaunched = ShopSyncRecoveryFenceStore(defaults: defaults)
        XCTAssertTrue(relaunched.saveAuthoritative(
            scope: scope,
            watermark: 102,
            accountHash: accountHash,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash
        ))
        XCTAssertNil(relaunched.scopeKey(
            accountHash: accountHash,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash,
            watermark: 101
        ))
        XCTAssertEqual(relaunched.scopeKey(
            accountHash: accountHash,
            storeIdentity: identity,
            deviceIdentityHash: deviceHash,
            watermark: 102
        ), scopeKey)
    }

    func testPersistedLedgerRebuildsIndependentImageIDAndVersionOrdering() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShopSyncRecoveryContractTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let ledger = try ShopSyncRecoveryLedger(
            generationStoreURL: temporaryRoot.appendingPathComponent("store.store")
        )
        let productA = "10000000-0000-4000-8000-000000000001"
        let productB = "20000000-0000-4000-8000-000000000002"
        try ledger.append(
            ShopSyncRecoveryLedgerRecord(
                orderingID: productA,
                idLine: productA,
                versionLine: "product-a-version-line",
                identityLine: nil,
                isTombstone: false
            ),
            domain: .images
        )
        try ledger.append(
            ShopSyncRecoveryLedgerRecord(
                orderingID: productB,
                idLine: productB,
                versionLine: "product-b-version-line",
                identityLine: nil,
                isTombstone: true
            ),
            domain: .images
        )
        try ledger.closeWrites()

        let receipt = try ledger.receipt(
            relationshipViolationCount: 0,
            pendingLocalCount: 0,
            outboxCount: 0
        )
        XCTAssertEqual(receipt.images.activeCount, 1)
        XCTAssertEqual(receipt.images.tombstoneCount, 1)
        XCTAssertEqual(
            receipt.images.idSetDigest,
            ShopSyncRecoveryCanonical.checkpointChainDigest([productA, productB])
        )
        XCTAssertEqual(
            receipt.images.versionDigest,
            ShopSyncRecoveryCanonical.checkpointChainDigest([
                "product-a-version-line",
                "product-b-version-line"
            ])
        )
    }

    func testCheckpointChainMatchesBackendGoldenVectorWithUTF8ByteCounts() {
        XCTAssertEqual(
            ShopSyncRecoveryCanonical.checkpointChainDigest(["plain", "caffè", "猫"]),
            "bba5d5ab281d4262b5560aa9d5469794434ef6c79ea2a313f0d715fcab774896"
        )
        XCTAssertNotEqual(
            ShopSyncRecoveryCanonical.checkpointChainDigest(["plain", "caffè", "猫"]),
            ShopSyncRecoveryCanonical.sha256("plain\ncaffè\n猫")
        )
    }

    func testProductContractIncludesItemNumberAndRejectsTombstoneRelations() throws {
        let owner = UUID(uuidString: "33333333-3434-4434-8434-343434343434")!
        let shop = UUID(uuidString: "00000000-0000-4000-8000-000000000140")!
        let checkpoint = try makeCheckpoint(owner: owner, shop: shop)
        let productID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
        let categoryID = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
        let row = RemoteInventoryProductRow(
            id: productID,
            ownerUserID: owner,
            shopID: shop,
            barcode: "barcode-139",
            itemNumber: "item-139",
            productName: "Tombstone",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-07-21T12:00:00.000000Z",
            deletedAt: "2026-07-22T12:00:00.000000Z",
            primaryImageVersionID: nil,
            primaryImageUpdatedAt: nil
        )

        let record = try ShopSyncRecoveryRowContract.product(row, checkpoint: checkpoint)
        let id = productID.uuidString.lowercased()
        XCTAssertEqual(
            record.identityLine,
            ShopSyncRecoveryCanonical.joined(
                id,
                ShopSyncRecoveryCanonical.sha256("barcode-139"),
                ShopSyncRecoveryCanonical.sha256("item-139")
            )
        )
        XCTAssertEqual(
            record.versionLine,
            ShopSyncRecoveryCanonical.joined(
                id,
                "2026-07-21T12:00:00.000000Z",
                "2026-07-22T12:00:00.000000Z",
                "-", "-", "-", "-"
            )
        )
        XCTAssertTrue(record.isTombstone)

        let unexpectedRelation = RemoteInventoryProductRow(
            id: productID,
            ownerUserID: owner,
            shopID: shop,
            barcode: "barcode-139",
            itemNumber: "item-139",
            productName: "Tombstone",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: categoryID,
            stockQuantity: nil,
            updatedAt: "2026-07-21T12:00:00.000000Z",
            deletedAt: "2026-07-22T12:00:00.000000Z",
            primaryImageVersionID: nil,
            primaryImageUpdatedAt: nil
        )
        XCTAssertThrowsError(
            try ShopSyncRecoveryRowContract.product(
                unexpectedRelation,
                checkpoint: checkpoint
            )
        ) { error in
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .invalidPage(domain: .products))
        }
    }

    func testPriceContractUsesRPCDecimalAndRejectsMissingCanonicalField() throws {
        let owner = UUID(uuidString: "33333333-3434-4434-8434-343434343434")!
        let shop = UUID(uuidString: "00000000-0000-4000-8000-000000000140")!
        let checkpoint = try makeCheckpoint(owner: owner, shop: shop)
        let priceID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
        let productID = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
        let valid = RemoteInventoryProductPriceRow(
            id: priceID,
            ownerUserID: owner,
            shopID: shop,
            productID: productID,
            type: "RETAIL",
            price: 12.34,
            priceCanonical: "12.34",
            effectiveAt: "2026-07-21 12:00:00",
            source: "source",
            note: "note",
            createdAt: "2026-07-21 12:00:01",
            updatedAt: "2026-07-21T12:00:02.000000Z"
        )
        let record = try ShopSyncRecoveryRowContract.price(valid, checkpoint: checkpoint)
        XCTAssertEqual(
            record.versionLine,
            ShopSyncRecoveryCanonical.joined(
                priceID.uuidString.lowercased(),
                "2026-07-21T12:00:02.000000Z",
                productID.uuidString.lowercased(),
                "12.34",
                "RETAIL",
                "2026-07-21 12:00:00",
                "2026-07-21 12:00:01",
                ShopSyncRecoveryCanonical.sha256("source"),
                ShopSyncRecoveryCanonical.sha256("note")
            )
        )

        let missingCanonical = RemoteInventoryProductPriceRow(
            id: priceID,
            ownerUserID: owner,
            shopID: shop,
            productID: productID,
            type: "RETAIL",
            price: 12.34,
            effectiveAt: "2026-07-21 12:00:00",
            source: "source",
            note: "note",
            createdAt: "2026-07-21 12:00:01",
            updatedAt: "2026-07-21T12:00:02.000000Z"
        )
        XCTAssertThrowsError(
            try ShopSyncRecoveryRowContract.price(missingCanonical, checkpoint: checkpoint)
        ) { error in
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .invalidPage(domain: .prices))
        }
    }

    func testHistoryContractRequiresServerPayloadDigests() throws {
        let owner = UUID(uuidString: "33333333-3434-4434-8434-343434343434")!
        let shop = UUID(uuidString: "00000000-0000-4000-8000-000000000140")!
        let checkpoint = try makeCheckpoint(owner: owner, shop: shop)
        let remoteID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
        let dataDigest = String(repeating: "a", count: 64)
        let overlayDigest = String(repeating: "b", count: 64)
        let valid = RemoteSharedSheetSessionRow(
            remoteID: remoteID,
            payloadVersion: 2,
            displayName: "Sessione",
            timestamp: "2026-07-21 12:00:00",
            supplier: "Fornitore",
            category: "Categoria",
            isManualEntry: true,
            data: [["riga"]],
            sessionOverlay: nil,
            ownerUserID: owner,
            shopID: shop,
            dataCheckpointDigest: dataDigest,
            overlayCheckpointDigest: overlayDigest,
            updatedAt: "2026-07-21T12:00:01.000000Z",
            deletedAt: nil
        )
        let record = try ShopSyncRecoveryRowContract.history(valid, checkpoint: checkpoint)
        XCTAssertEqual(
            record.versionLine,
            ShopSyncRecoveryCanonical.joined(
                remoteID.uuidString.lowercased(),
                "2026-07-21T12:00:01.000000Z",
                "-",
                "2",
                "2026-07-21 12:00:00",
                ShopSyncRecoveryCanonical.sha256("Fornitore"),
                ShopSyncRecoveryCanonical.sha256("Categoria"),
                "true",
                ShopSyncRecoveryCanonical.sha256("Sessione"),
                dataDigest,
                overlayDigest
            )
        )

        let missingDigest = RemoteSharedSheetSessionRow(
            remoteID: remoteID,
            payloadVersion: 2,
            displayName: "Sessione",
            timestamp: "2026-07-21 12:00:00",
            supplier: "Fornitore",
            category: "Categoria",
            isManualEntry: true,
            data: [["riga"]],
            sessionOverlay: nil,
            ownerUserID: owner,
            shopID: shop,
            dataCheckpointDigest: nil,
            overlayCheckpointDigest: overlayDigest,
            updatedAt: "2026-07-21T12:00:01.000000Z",
            deletedAt: nil
        )
        XCTAssertThrowsError(
            try ShopSyncRecoveryRowContract.history(missingDigest, checkpoint: checkpoint)
        ) { error in
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .invalidPage(domain: .history))
        }
    }

    func testPersistedLedgerStreamsRecordsAcrossReadChunks() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShopSyncRecoveryLedgerChunks-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let storeURL = temporaryRoot.appendingPathComponent("store.store")
        let ledger = try ShopSyncRecoveryLedger(generationStoreURL: storeURL)

        let rowCount = 600
        for index in 0..<rowCount {
            let id = String(format: "00000000-0000-4000-8000-%012d", index)
            try ledger.append(
                ShopSyncRecoveryLedgerRecord(
                    orderingID: id,
                    idLine: id,
                    versionLine: "\(id)\u{001f}2026-07-21T12:00:00.000000Z\u{001f}-",
                    identityLine: nil,
                    isTombstone: false
                ),
                domain: .suppliers
            )
        }
        try ledger.closeWrites()

        let receipt = try ShopSyncRecoveryLedger(
            generationStoreURL: storeURL,
            mode: .readExisting
        ).receipt(
            relationshipViolationCount: 0,
            pendingLocalCount: 0,
            outboxCount: 0
        )

        XCTAssertEqual(receipt.suppliers.activeCount, rowCount)
        XCTAssertEqual(receipt.suppliers.tombstoneCount, 0)
    }

    func testPersistedLedgerRejectsMissingNewlineAndOversizedRecordPrecisely() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShopSyncRecoveryLedgerMalformed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let storeURL = temporaryRoot.appendingPathComponent("store.store")
        let ledger = try ShopSyncRecoveryLedger(generationStoreURL: storeURL)
        let id = "00000000-0000-4000-8000-000000000001"
        try ledger.append(
            ShopSyncRecoveryLedgerRecord(
                orderingID: id,
                idLine: id,
                versionLine: id,
                identityLine: nil,
                isTombstone: false
            ),
            domain: .suppliers
        )
        try ledger.closeWrites()
        let ledgerURL = temporaryRoot
            .appendingPathComponent("recovery-ledger-v1", isDirectory: true)
            .appendingPathComponent("suppliers.ndjson")
        var unterminated = try Data(contentsOf: ledgerURL)
        XCTAssertEqual(unterminated.removeLast(), 0x0A)
        try unterminated.write(to: ledgerURL, options: [.atomic])

        let malformed = try ShopSyncRecoveryLedger(
            generationStoreURL: storeURL,
            mode: .readExisting
        )
        XCTAssertThrowsError(try malformed.receipt(
            relationshipViolationCount: 0,
            pendingLocalCount: 0,
            outboxCount: 0
        )) { error in
            XCTAssertEqual(
                error as? ShopSyncRecoveryContractError,
                .persistedLedgerInvalid(domain: .suppliers)
            )
        }

        try Data(
            repeating: 0x61,
            count: ShopSyncRecoveryLimits.maximumLedgerRecordBytes + 1
        ).write(to: ledgerURL, options: [.atomic])
        let oversized = try ShopSyncRecoveryLedger(
            generationStoreURL: storeURL,
            mode: .readExisting
        )
        XCTAssertThrowsError(try oversized.receipt(
            relationshipViolationCount: 0,
            pendingLocalCount: 0,
            outboxCount: 0
        )) { error in
            XCTAssertEqual(
                error as? ShopSyncRecoveryContractError,
                .resourceBudgetExceeded(domain: .suppliers)
            )
        }
    }

    func testGenerationManifestAndDirectoryBudgetsFailClosed() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncStoreGenerationBudgets-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let repository = try SyncStoreGenerationRepository(baseDirectory: temporaryRoot)

        try Data(
            repeating: 0x7b,
            count: ShopSyncRecoveryLimits.maximumGenerationManifestBytes + 1
        ).write(to: repository.manifestURL, options: [.atomic])
        XCTAssertThrowsError(try repository.loadActive()) { error in
            XCTAssertEqual(
                error as? SyncStoreGenerationError,
                .generationResourceBudgetExceeded
            )
        }
        try FileManager.default.removeItem(at: repository.manifestURL)

        let staging = try repository.prepareStaging(
            accountHash: String(repeating: "a", count: 64),
            shopID: UUID(),
            storeIdentity: LocalStoreIdentity(rawValue: "shop:disk-budget"),
            deviceIdentityHash: String(repeating: "d", count: 64)
        )
        let oversizedURL = staging.storeURL.deletingLastPathComponent()
            .appendingPathComponent("oversized.fixture")
        XCTAssertTrue(FileManager.default.createFile(atPath: oversizedURL.path, contents: nil))
        let handle = try FileHandle(forWritingTo: oversizedURL)
        try handle.truncate(
            atOffset: UInt64(ShopSyncRecoveryLimits.maximumGenerationDirectoryBytes + 1)
        )
        try handle.close()

        XCTAssertThrowsError(try repository.validateResourceBudget(for: staging)) { error in
            XCTAssertEqual(
                error as? SyncStoreGenerationError,
                .generationResourceBudgetExceeded
            )
        }
    }

    func testRetainedGenerationByteBudgetRequiresRelaunchBeforeThirdStore() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncStoreGenerationRetainedBytes-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let repository = try SyncStoreGenerationRepository(baseDirectory: temporaryRoot)
        let retainedBytes = 400 * 1_024 * 1_024

        for index in 0..<2 {
            let staging = try repository.prepareStaging(
                accountHash: String(repeating: String(index), count: 64),
                shopID: UUID(),
                storeIdentity: LocalStoreIdentity(rawValue: "shop:retained-bytes-\(index)"),
                deviceIdentityHash: String(repeating: "d", count: 64)
            )
            let sparse = staging.storeURL.deletingLastPathComponent()
                .appendingPathComponent("retained.fixture")
            XCTAssertTrue(FileManager.default.createFile(atPath: sparse.path, contents: nil))
            let handle = try FileHandle(forWritingTo: sparse)
            try handle.truncate(atOffset: UInt64(retainedBytes))
            try handle.close()
            repository.markStagingQuarantined(staging)
        }

        XCTAssertThrowsError(try repository.prepareStaging(
            accountHash: String(repeating: "a", count: 64),
            shopID: UUID(),
            storeIdentity: LocalStoreIdentity(rawValue: "shop:retained-bytes-blocked"),
            deviceIdentityHash: String(repeating: "e", count: 64)
        )) { error in
            XCTAssertEqual(error as? SyncStoreGenerationError, .cleanupRequiresRelaunch)
        }
    }

    func testImageMetadataContractRejectsOversizeAndNonJPEGVariants() throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let shop = UUID(uuidString: "00000000-0000-4000-8000-000000000140")!
        let checkpoint = try makeCheckpoint(owner: owner, shop: shop)
        let valid = ShopSyncRecoveryImageRow(
            productID: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
            ownerUserID: owner,
            shopID: shop,
            productDeletedAt: nil,
            versionID: UUID(uuidString: "20000000-0000-4000-8000-000000000002")!,
            status: "ready",
            finalizedAt: "2026-07-21T12:00:00.000000Z",
            main: .init(
                sha256: String(repeating: "a", count: 64),
                bytes: 1_048_576,
                width: 1_600,
                height: 1_600,
                mime: "image/jpeg"
            ),
            thumb: .init(
                sha256: String(repeating: "b", count: 64),
                bytes: 92_160,
                width: 384,
                height: 384,
                mime: "image/jpeg"
            )
        )
        XCTAssertNoThrow(try ShopSyncRecoveryRowContract.image(valid, checkpoint: checkpoint))

        let invalid = ShopSyncRecoveryImageRow(
            productID: valid.productID,
            ownerUserID: owner,
            shopID: shop,
            productDeletedAt: nil,
            versionID: valid.versionID,
            status: "ready",
            finalizedAt: valid.finalizedAt,
            main: .init(
                sha256: String(repeating: "a", count: 64),
                bytes: 1_048_577,
                width: 1_600,
                height: 1_600,
                mime: "image/png"
            ),
            thumb: valid.thumb
        )
        XCTAssertThrowsError(
            try ShopSyncRecoveryRowContract.image(invalid, checkpoint: checkpoint)
        ) { error in
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .invalidImageMetadata)
        }
    }

    func testImageVersionDigestIncludesProductTombstoneTimestamp() throws {
        let owner = UUID(uuidString: "33333333-3434-4434-8434-343434343434")!
        let shop = UUID(uuidString: "00000000-0000-4000-8000-000000000140")!
        let checkpoint = try makeCheckpoint(owner: owner, shop: shop)
        let productID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
        let versionID = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
        let finalizedAt = "2026-07-21T12:00:00.000000Z"
        let deletedAt = "2026-07-22T13:14:15.000000Z"
        let main = ShopSyncRecoveryImageVariant(
            sha256: String(repeating: "a", count: 64),
            bytes: 1_000,
            width: 100,
            height: 100,
            mime: "image/jpeg"
        )
        let thumb = ShopSyncRecoveryImageVariant(
            sha256: String(repeating: "b", count: 64),
            bytes: 500,
            width: 50,
            height: 50,
            mime: "image/jpeg"
        )
        let active = ShopSyncRecoveryImageRow(
            productID: productID,
            ownerUserID: owner,
            shopID: shop,
            productDeletedAt: nil,
            versionID: versionID,
            status: "ready",
            finalizedAt: finalizedAt,
            main: main,
            thumb: thumb
        )
        let tombstoned = ShopSyncRecoveryImageRow(
            productID: productID,
            ownerUserID: owner,
            shopID: shop,
            productDeletedAt: deletedAt,
            versionID: versionID,
            status: "ready",
            finalizedAt: finalizedAt,
            main: main,
            thumb: thumb
        )

        let activeRecord = try ShopSyncRecoveryRowContract.image(active, checkpoint: checkpoint)
        let tombstonedRecord = try ShopSyncRecoveryRowContract.image(tombstoned, checkpoint: checkpoint)
        XCTAssertEqual(
            activeRecord.versionLine,
            ShopSyncRecoveryCanonical.joined(
                productID.uuidString.lowercased(),
                versionID.uuidString.lowercased(),
                "ready",
                "-",
                finalizedAt,
                main.sha256!,
                String(main.bytes!),
                String(main.width!),
                String(main.height!),
                main.mime!,
                thumb.sha256!,
                String(thumb.bytes!),
                String(thumb.width!),
                String(thumb.height!),
                thumb.mime!
            )
        )
        XCTAssertEqual(
            tombstonedRecord.versionLine,
            ShopSyncRecoveryCanonical.joined(
                productID.uuidString.lowercased(),
                versionID.uuidString.lowercased(),
                "ready",
                deletedAt,
                finalizedAt,
                main.sha256!,
                String(main.bytes!),
                String(main.width!),
                String(main.height!),
                main.mime!,
                thumb.sha256!,
                String(thumb.bytes!),
                String(thumb.width!),
                String(thumb.height!),
                thumb.mime!
            )
        )
        XCTAssertNotEqual(activeRecord.versionLine, tombstonedRecord.versionLine)
        XCTAssertFalse(activeRecord.isTombstone)
        XCTAssertTrue(tombstonedRecord.isTombstone)
    }

    private func makeCheckpoint(
        owner: UUID,
        shop: UUID,
        deviceInstallID: String = "device-139"
    ) throws -> ShopSyncRecoveryCheckpoint {
        let empty = ShopSyncRecoveryEntityDigest(
            activeCount: 0,
            tombstoneCount: 0,
            idSetDigest: ShopSyncRecoveryCanonical.sha256(""),
            versionDigest: ShopSyncRecoveryCanonical.sha256("")
        )
        let products = ShopSyncRecoveryEntityDigest(
            activeCount: 0,
            tombstoneCount: 0,
            idSetDigest: empty.idSetDigest,
            versionDigest: empty.versionDigest,
            identityDigest: empty.idSetDigest
        )
        let deviceKey = ShopSyncRecoveryCanonical.sha256(deviceInstallID)
        let scope = ShopSyncRecoveryScope(
            kind: "shop_scoped",
            key: ShopSyncRecoveryCanonical.sha256(
                shop.uuidString.lowercased() + ":shop_scoped:-:" + deviceKey
            ),
            legacyOwnerKey: nil,
            accountKey: AccountBindingStore.accountHash(for: owner),
            deviceKey: deviceKey
        )
        return ShopSyncRecoveryCheckpoint(
            schemaVersion: "shop-sync-recovery-checkpoint-v1",
            shopId: shop,
            scope: scope,
            syncEvents: ShopSyncRecoveryEventCheckpoint(maxId: "0"),
            catalog: ShopSyncRecoveryCatalogDigest(
                suppliers: empty,
                categories: empty,
                products: products,
                digest: ShopSyncRecoveryCanonical.sha256(
                    empty.versionDigest + "\n" + empty.versionDigest + "\n" + products.versionDigest
                )
            ),
            prices: empty,
            history: empty,
            images: empty,
            integrity: ShopSyncRecoveryIntegrity(
                productCategoryViolationCount: 0,
                productSupplierViolationCount: 0,
                priceProductViolationCount: 0,
                primaryImageViolationCount: 0,
                historyIdViolationCount: 0,
                totalViolationCount: 0
            ),
            checkpointDigest: ShopSyncRecoveryCanonical.sha256(owner.uuidString)
        )
    }
}

private nonisolated final class SyncStoreActivationBoundaryRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [SyncStoreActivationBoundary] = []

    func append(_ value: SyncStoreActivationBoundary) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [SyncStoreActivationBoundary] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}
