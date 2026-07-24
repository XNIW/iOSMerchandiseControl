import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class AtomicGenerationRecoverySnapshotPullServiceTests: XCTestCase {
    func testEmptySnapshotPublishesOneGenerationAndCompletesJournal() async throws {
        let fixture = try makeFixture()
        let checkpoint = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "stable")
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint]
        )
        let service = makeService(fixture: fixture, transport: transport)
        do {
            _ = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: fixture.ownerUserID,
                defaults: fixture.defaults
            )
        } catch {
            XCTFail("Fixture scope precondition failed: \(error)")
            return
        }

        let summary: SyncRecoverySnapshotPullSummary
        do {
            summary = try await service.recoverFromRemoteSnapshot(
                ownerUserID: fixture.ownerUserID
            )
        } catch {
            let counts = await transport.counts()
            let accountHash = AccountBindingStore.accountHash(for: fixture.ownerUserID)
            let activeMatches = fixture.defaults.string(
                forKey: "mobile.shopContext.activeAccountHash.v1"
            ) == accountHash
            let journalPresent = AccountBindingStore(
                defaults: fixture.defaults
            ).pendingRecoveryJournal != nil
            XCTFail(
                "Unexpected recovery error \(error); checkpoints=\(counts.checkpoints), "
                    + "pages=\(counts.pages), activeMatches=\(activeMatches), "
                    + "journalPresent=\(journalPresent)"
            )
            return
        }

        XCTAssertEqual(summary.watermarkAfter, 41)
        XCTAssertTrue(summary.completedRecoveryJournal)
        XCTAssertEqual(summary.activatedGenerationID, fixture.controller.activeManifest?.generationID)
        XCTAssertNotNil(fixture.controller.activeManifest)
        XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.recoveryJournalURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recoveryFinalizationURL.path))
        let counts = await transport.counts()
        XCTAssertEqual(counts.checkpoints, 2)
        XCTAssertEqual(counts.pages, ShopSyncRecoveryDomain.allCases.count)
        let checkpointCalls = await transport.checkpointCallsForTesting()
        XCTAssertEqual(checkpointCalls.count, 2)
        XCTAssertEqual(checkpointCalls[0].verifiedBaselineID, "0")
        XCTAssertNil(checkpointCalls[0].expectedBaselineScopeKey)
        XCTAssertEqual(checkpointCalls[1].verifiedBaselineID, checkpoint.syncEvents.maxId)
        XCTAssertEqual(checkpointCalls[1].expectedBaselineScopeKey, checkpoint.scope.key)
    }

    func testFinalizedMarkerResumesAfterCrashWithoutRemoteEqualityCheck() async throws {
        let fixture = try makeFixture()
        let stable = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "stable")
        let firstTransport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [stable, stable, stable]
        )
        _ = try await makeService(
            fixture: fixture,
            transport: firstTransport
        ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)

        let manifest = try XCTUnwrap(fixture.controller.activeManifest)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: fixture.recoveryFinalizationURL.path
        ))
        let bindingStore = AccountBindingStore(defaults: fixture.defaults)
        let accountHash = AccountBindingStore.accountHash(for: fixture.ownerUserID)
        let deviceIdentityHash = AccountBindingStore.redactedAccountHash(
            for: fixture.deviceInstallID
        )
        XCTAssertTrue(bindingStore.beginSameScopeRecovery(
            accountHash: accountHash,
            storeIdentity: manifest.storeIdentity,
            reason: "fixture_crash_after_finalization_marker",
            deviceIdentityHash: deviceIdentityHash
        ))
        var scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: fixture.ownerUserID,
            defaults: fixture.defaults,
            allowsPendingSameScopeRecovery: true
        )
        XCTAssertTrue(bindingStore.recordPendingRecoveryStaging(
            accountHash: accountHash,
            storeIdentity: manifest.storeIdentity,
            deviceIdentityHash: deviceIdentityHash,
            generationID: manifest.generationID,
            scope: scope
        ))
        scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: fixture.ownerUserID,
            defaults: fixture.defaults,
            allowsPendingSameScopeRecovery: true
        )
        XCTAssertTrue(bindingStore.recordPendingRecoveryVerified(
            accountHash: accountHash,
            storeIdentity: manifest.storeIdentity,
            deviceIdentityHash: deviceIdentityHash,
            generationID: manifest.generationID,
            checkpointDigest: manifest.checkpoint.checkpointDigest,
            watermark: try XCTUnwrap(manifest.checkpoint.maxEventID),
            baselineRunID: manifest.baselineRunID,
            scope: scope
        ))
        XCTAssertNotNil(bindingStore.pendingRecoveryJournal)

        // The cloud cursor is monotonic and has advanced. A crash after the
        // fsynced finalization marker must complete locally without asking the
        // backend to recreate an impossible old checkpoint.
        let advanced = makeCheckpoint(fixture: fixture, maxEventID: 42, seed: "advanced")
        let resumeTransport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [advanced]
        )
        let resumed = try await makeService(
            fixture: fixture,
            transport: resumeTransport
        ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)

        XCTAssertEqual(resumed.activatedGenerationID, manifest.generationID)
        XCTAssertEqual(resumed.watermarkAfter, 41)
        XCTAssertTrue(resumed.completedRecoveryJournal)
        XCTAssertNil(bindingStore.pendingRecoveryJournal)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.recoveryJournalURL.path))
        let resumeCalls = await resumeTransport.counts()
        XCTAssertEqual(resumeCalls.checkpoints, 0)
        XCTAssertEqual(resumeCalls.pages, 0)
    }

    func testCheckpointBWithDivergentSnapshotRetriesTwiceWithoutPublishingOrClearingRecovery() async throws {
        let fixture = try makeFixture()
        let checkpointA = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "a")
        let checkpointB = makeDivergentCheckpoint(
            fixture: fixture,
            maxEventID: 42,
            seed: "b"
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpointA, checkpointB, checkpointA, checkpointB]
        )
        let service = makeService(fixture: fixture, transport: transport)

        do {
            _ = try await service.recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("A divergent B snapshot must not publish a generation")
        } catch {
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .checkpointChanged)
        }

        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        let counts = await transport.counts()
        XCTAssertEqual(counts.checkpoints, 4)
        XCTAssertEqual(counts.pages, ShopSyncRecoveryDomain.allCases.count * 2)
    }

    func testLivePagesMaterializingDivergentCheckpointBPublishOnlyAfterBProof() async throws {
        let fixture = try makeFixture()
        let product = RemoteInventoryProductRow(
            id: UUID(),
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            barcode: "TASK139-LIVE-B",
            itemNumber: nil,
            productName: "Live B fixture",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: 1,
            updatedAt: "2026-07-23T00:00:00.000000Z",
            deletedAt: nil
        )
        let checkpointA = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "live-a")
        let checkpointB = try makeCatalogPriceCheckpoint(
            fixture: fixture,
            maxEventID: 42,
            seed: "live-b",
            products: [product],
            prices: []
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpointA, checkpointB],
            productRows: [product]
        )

        let summary = try await makeService(
            fixture: fixture,
            transport: transport,
            maximumAttempts: 1
        ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)

        XCTAssertEqual(summary.watermarkAfter, 42)
        XCTAssertTrue(summary.completedRecoveryJournal)
        let manifest = try XCTUnwrap(fixture.controller.activeManifest)
        XCTAssertEqual(manifest.checkpointBeforeDownload.checkpointDigest, checkpointA.checkpointDigest)
        XCTAssertEqual(manifest.checkpoint.checkpointDigest, checkpointB.checkpointDigest)
        XCTAssertEqual(manifest.localVerification.products, checkpointB.catalog.products)
        let context = ModelContext(fixture.controller.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 1)
        let baseline = try XCTUnwrap(context.fetch(FetchDescriptor<SupabaseCatalogBaselineRun>()).first)
        XCTAssertEqual(baseline.productCount, 1)
        XCTAssertEqual(baseline.status, SupabaseCatalogBaselineStatus.valid.rawValue)
        XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
    }

    func testProductTombstoneWithImageTombstonePublishesAsImageDomainTombstone() async throws {
        let fixture = try makeFixture()
        let productID = UUID()
        let deletedAt = "2026-07-23T00:00:00.000000Z"
        let product = RemoteInventoryProductRow(
            id: productID,
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            barcode: "TASK139-TOMBSTONE-IMAGE",
            itemNumber: nil,
            productName: nil,
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: deletedAt,
            deletedAt: deletedAt,
            // Canonical recovery product rows deliberately clear this pointer
            // when deleted_at is non-null. The matching image row below is an
            // image-domain tombstone, not a live product association.
            primaryImageVersionID: nil,
            primaryImageUpdatedAt: nil
        )
        let image = makeImageTombstone(
            fixture: fixture,
            productID: productID,
            deletedAt: deletedAt
        )
        let checkpointA = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "image-tombstone-a")
        let checkpointB = try makeCatalogPriceCheckpoint(
            fixture: fixture,
            maxEventID: 42,
            seed: "image-tombstone-b",
            products: [product],
            prices: [],
            images: [image]
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpointA, checkpointB],
            productRows: [product],
            imageRows: [image]
        )

        let summary = try await makeService(
            fixture: fixture,
            transport: transport,
            maximumAttempts: 1
        ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)

        XCTAssertEqual(summary.watermarkAfter, 42)
        XCTAssertTrue(summary.completedRecoveryJournal)
        let manifest = try XCTUnwrap(fixture.controller.activeManifest)
        XCTAssertEqual(manifest.localVerification.products, checkpointB.catalog.products)
        XCTAssertEqual(manifest.localVerification.images, checkpointB.images)
        let context = ModelContext(fixture.controller.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 0)
        let baseline = try XCTUnwrap(context.fetch(FetchDescriptor<SupabaseCatalogBaselineRun>()).first)
        XCTAssertEqual(baseline.productCount, 1)
        XCTAssertEqual(baseline.tombstoneCount, 1)
        let markerBaselineIDs = await transport.markerBaselineIDsForTesting()
        XCTAssertEqual(markerBaselineIDs, ["42"])
        XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
    }

    func testImageTombstoneWithoutSameSnapshotProductTombstoneNeverActivates() async throws {
        let fixture = try makeFixture()
        let image = makeImageTombstone(
            fixture: fixture,
            productID: UUID(),
            deletedAt: "2026-07-23T00:00:00.000000Z"
        )
        let checkpoint = try makeCatalogPriceCheckpoint(
            fixture: fixture,
            maxEventID: 41,
            seed: "orphan-image-tombstone",
            products: [],
            prices: [],
            images: [image]
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint],
            imageRows: [image]
        )

        do {
            _ = try await makeService(
                fixture: fixture,
                transport: transport,
                maximumAttempts: 1
            ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("An image tombstone without its scoped product tombstone must not activate")
        } catch {
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .relationViolation)
        }

        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
    }

    func testStagingMutationDuringCheckpointBIsNeverPublished() async throws {
        let fixture = try makeFixture()
        let checkpoint = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "stable")
        let generationRoot = fixture.temporaryRoot
            .appendingPathComponent("generation-root", isDirectory: true)
            .appendingPathComponent("generations", isDirectory: true)
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint, checkpoint],
            checkpointMutation: { call in
                guard call.isMultiple(of: 2) else { return }
                let generations = try FileManager.default.contentsOfDirectory(
                    at: generationRoot,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                let candidates = generations.filter {
                    !FileManager.default.fileExists(
                        atPath: $0.appendingPathComponent("quarantined").path
                    )
                }
                guard candidates.count == 1, let candidate = candidates.first else {
                    throw SyncStoreGenerationError.stagingStoreMissing
                }
                let marker = candidate
                    .appendingPathComponent("recovery-ledger-v1", isDirectory: true)
                    .appendingPathComponent("mutation-after-fence-\(call)", isDirectory: false)
                try Data([UInt8(call)]).write(to: marker, options: [.atomic])
            }
        )

        do {
            _ = try await makeService(
                fixture: fixture,
                transport: transport
            ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("A generation changed after strong verification must not publish")
        } catch {
            XCTAssertEqual(
                error as? SyncStoreGenerationError,
                .stagingChangedAfterVerification
            )
        }

        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        let counts = await transport.counts()
        // A local single-writer invariant violation is deterministic, not a
        // transient A/B drift. Fail immediately instead of retrying the same
        // unsafe generation loop.
        XCTAssertEqual(counts.checkpoints, 2)
        XCTAssertEqual(counts.pages, ShopSyncRecoveryDomain.allCases.count)
    }

    func testMonotonicCheckpointBAdvancePublishesOnlyAfterSafeTailAndMarker() async throws {
        let fixture = try makeFixture()
        let stable = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "stable")
        let advanced = makeCheckpoint(fixture: fixture, maxEventID: 42, seed: "advanced")
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [stable, advanced]
        )

        let summary = try await makeService(
            fixture: fixture,
            transport: transport,
            maximumAttempts: 1
        ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)

        XCTAssertEqual(summary.watermarkAfter, 42)
        XCTAssertTrue(summary.completedRecoveryJournal)
        let manifest = try XCTUnwrap(fixture.controller.activeManifest)
        XCTAssertEqual(manifest.checkpointBeforeDownload.maxEventID, 41)
        XCTAssertEqual(manifest.checkpoint.maxEventID, 42)
        XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recoveryFinalizationURL.path))
        let counts = await transport.counts()
        XCTAssertEqual(counts.checkpoints, 2)
        XCTAssertEqual(counts.pages, ShopSyncRecoveryDomain.allCases.count)
        XCTAssertEqual(counts.tailPages, 1)
    }

    func testIncompleteTailEntityIDsRetainJournalAndNeverActivate() async throws {
        let fixture = try makeFixture()
        let checkpointA = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "tail-a")
        let checkpointB = makeCheckpoint(fixture: fixture, maxEventID: 42, seed: "tail-b")
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpointA, checkpointB],
            tailBehavior: .incompleteEntityIDs
        )

        do {
            _ = try await makeService(
                fixture: fixture,
                transport: transport,
                maximumAttempts: 1
            ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("A tail event with an empty entity_ids object must require recovery")
        } catch {
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .fullRecoveryRequired)
        }

        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        let counts = await transport.counts()
        XCTAssertEqual(counts.checkpoints, 2)
        XCTAssertEqual(counts.tailPages, 1)
    }

    func testMarkerFailureKeepsRecoveryJournalAndNeverActivatesGeneration() async throws {
        let fixture = try makeFixture()
        let checkpoint = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "marker-failure")
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint],
            markerFailure: .markerNotVerified
        )

        do {
            _ = try await makeService(
                fixture: fixture,
                transport: transport,
                maximumAttempts: 1
            ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("A missing convergence marker must not publish a generation")
        } catch {
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .markerNotVerified)
        }

        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recoveryJournalURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.recoveryFinalizationURL.path))
        let counts = await transport.counts()
        XCTAssertEqual(counts.checkpoints, 2)
        XCTAssertEqual(counts.pages, ShopSyncRecoveryDomain.allCases.count)
        XCTAssertEqual(counts.tailPages, 0)
    }

    func testLeaseInvalidatedDuringMarkerPreservesJournalAndNeverActivatesGeneration() async throws {
        let fixture = try makeFixture()
        let checkpoint = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "stale-marker-lease")
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint],
            markerMutation: {
                AccountBindingStore(defaults: fixture.defaults).clearBinding()
            }
        )

        do {
            _ = try await makeService(
                fixture: fixture,
                transport: transport,
                maximumAttempts: 1
            ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("A stale owner/shop lease must not activate a generation")
        } catch {
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .bindingMismatch)
        }

        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recoveryJournalURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.recoveryFinalizationURL.path))
    }

    func testCancellationDuringPagesPreservesOldStoreAndDurableRecoveryJournal() async throws {
        let fixture = try makeFixture()
        let checkpoint = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "stable")
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint],
            cancellationDomain: .products
        )
        let service = makeService(fixture: fixture, transport: transport)

        do {
            _ = try await service.recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("Cancellation must not publish staging")
        } catch is CancellationError {
            // Expected.
        }

        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recoveryJournalURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.recoveryFinalizationURL.path))
        let context = ModelContext(fixture.controller.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 0)
        let counts = await transport.counts()
        XCTAssertEqual(counts.checkpoints, 1)
        XCTAssertEqual(counts.pages, 3)
    }

    func testMalformedActiveHistoryTimestampFailsBeforeActivation() async throws {
        let fixture = try makeFixture()
        let row = AtomicRecoveryHistoryRowPayload(
            remoteID: UUID(),
            payloadVersion: 2,
            displayName: "Malformed timestamp fixture",
            timestamp: "not-a-timestamp",
            supplier: "",
            category: "",
            isManualEntry: false,
            data: [["item"]],
            sessionOverlay: nil,
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            dataCheckpointDigest: String(repeating: "a", count: 64),
            overlayCheckpointDigest: String(repeating: "b", count: 64),
            updatedAt: "2026-07-21T12:00:00.000000Z",
            deletedAt: nil
        )
        let checkpoint = makeCheckpoint(
            fixture: fixture,
            maxEventID: 41,
            seed: "invalid-history",
            historyRow: row
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint],
            historyRows: [row]
        )
        let service = makeService(fixture: fixture, transport: transport)

        do {
            _ = try await service.recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("Malformed active history timestamps must fail closed")
        } catch {
            XCTAssertEqual(
                error as? ShopSyncRecoveryContractError,
                .nonCanonicalTimestamp
            )
        }

        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        let counts = await transport.counts()
        XCTAssertEqual(counts.checkpoints, 1)
        XCTAssertEqual(counts.pages, 5)
    }

    func testLegacyHistoryTombstoneDoesNotRequireMaterializablePayload() async throws {
        let fixture = try makeFixture()
        let row = AtomicRecoveryHistoryRowPayload(
            remoteID: UUID(),
            payloadVersion: 0,
            displayName: "Legacy tombstone",
            timestamp: "not-materialized",
            supplier: "",
            category: "",
            isManualEntry: false,
            data: [],
            sessionOverlay: nil,
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            dataCheckpointDigest: "-",
            overlayCheckpointDigest: "-",
            updatedAt: "2026-07-21T12:00:00.000000Z",
            deletedAt: "2026-07-21T12:01:00.000000Z"
        )
        let checkpoint = makeCheckpoint(
            fixture: fixture,
            maxEventID: 41,
            seed: "legacy-tombstone",
            historyRow: row
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint],
            historyRows: [row]
        )
        let service = makeService(fixture: fixture, transport: transport)

        let summary = try await service.recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)

        XCTAssertTrue(summary.completedRecoveryJournal)
        XCTAssertNotNil(fixture.controller.activeManifest)
        let context = ModelContext(fixture.controller.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 0)
    }

    func testPriceForTombstonedProductRemainsInVerifiedLedgerWithoutVisibleOrphan() async throws {
        let fixture = try makeFixture()
        let productID = UUID()
        let product = RemoteInventoryProductRow(
            id: productID,
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            barcode: "TASK139-DELETED",
            itemNumber: nil,
            productName: "Deleted fixture",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-07-21T12:00:00.000000Z",
            deletedAt: "2026-07-21T12:01:00.000000Z"
        )
        let price = RemoteInventoryProductPriceRow(
            id: UUID(),
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            productID: productID,
            type: "RETAIL",
            price: 12.34,
            priceCanonical: "12.34",
            effectiveAt: "2026-07-21 12:00:00",
            source: "fixture",
            note: nil,
            createdAt: "2026-07-21 12:00:00",
            updatedAt: "2026-07-21T12:02:00.000000Z"
        )
        let checkpoint = try makeCatalogPriceCheckpoint(
            fixture: fixture,
            maxEventID: 41,
            seed: "tombstoned-product-price",
            products: [product],
            prices: [price]
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint],
            productRows: [product],
            priceRows: [price]
        )

        let summary = try await makeService(
            fixture: fixture,
            transport: transport
        ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)

        XCTAssertTrue(summary.completedRecoveryJournal)
        let manifest = try XCTUnwrap(fixture.controller.activeManifest)
        XCTAssertEqual(manifest.localVerification.products, checkpoint.catalog.products)
        XCTAssertEqual(manifest.localVerification.prices, checkpoint.prices)
        let context = ModelContext(fixture.controller.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductPrice>()), 0)
    }

    func testPriceForUnknownProductFailsClosedBeforeActivation() async throws {
        let fixture = try makeFixture()
        let price = RemoteInventoryProductPriceRow(
            id: UUID(),
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            productID: UUID(),
            type: "RETAIL",
            price: 12.34,
            priceCanonical: "12.34",
            effectiveAt: "2026-07-21 12:00:00",
            source: "fixture",
            note: nil,
            createdAt: "2026-07-21 12:00:00",
            updatedAt: "2026-07-21T12:02:00.000000Z"
        )
        let checkpoint = try makeCatalogPriceCheckpoint(
            fixture: fixture,
            maxEventID: 41,
            seed: "unknown-product-price",
            products: [],
            prices: [price]
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint],
            priceRows: [price]
        )

        do {
            _ = try await makeService(
                fixture: fixture,
                transport: transport
            ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("A price with no active or tombstoned product must not publish")
        } catch {
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .relationViolation)
        }

        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        let context = ModelContext(fixture.controller.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductPrice>()), 0)
    }

    func testUppercaseRPCPriceUsesCanonicalDecimalForVerifiedMaterialization() async throws {
        let fixture = try makeFixture()
        let productID = UUID()
        let product = RemoteInventoryProductRow(
            id: productID,
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            barcode: "TASK139-CANONICAL-PRICE",
            itemNumber: "price-139",
            productName: "Canonical price fixture",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-07-21T12:00:00.000000Z",
            deletedAt: nil
        )
        let price = RemoteInventoryProductPriceRow(
            id: UUID(),
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            productID: productID,
            type: "RETAIL",
            price: 12.34,
            priceCanonical: "12.34",
            effectiveAt: "2026-07-21 12:00:00",
            source: "fixture",
            note: "canonical",
            createdAt: "2026-07-21 12:00:00",
            updatedAt: "2026-07-21T12:02:00.000000Z"
        )
        let checkpoint = try makeCatalogPriceCheckpoint(
            fixture: fixture,
            maxEventID: 41,
            seed: "canonical-active-price",
            products: [product],
            prices: [price]
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint],
            productRows: [product],
            priceRows: [price]
        )

        let summary = try await makeService(
            fixture: fixture,
            transport: transport
        ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)

        XCTAssertTrue(summary.completedRecoveryJournal)
        let manifest = try XCTUnwrap(fixture.controller.activeManifest)
        XCTAssertEqual(manifest.localVerification.prices, checkpoint.prices)
        let context = ModelContext(fixture.controller.modelContainer)
        let stored = try XCTUnwrap(context.fetch(FetchDescriptor<ProductPrice>()).first)
        XCTAssertEqual(stored.type, .retail)
        XCTAssertEqual(stored.price, 12.34, accuracy: 0.000_001)
    }

    func testHistoryFullRowBudgetAcceptsExactLimitAndRejectsNextByte() async throws {
        let exactFixture = try makeFixture()
        let exactRow = try makeHistoryRow(
            fixture: exactFixture,
            encodedBytes: ShopSyncRecoveryLimits.maximumHistoryRowPayloadBytes
        )
        let exactCheckpoint = makeCheckpoint(
            fixture: exactFixture,
            maxEventID: 41,
            seed: "history-exact-budget",
            historyRow: exactRow
        )
        let exactTransport = AtomicRecoveryTestTransport(
            ownerUserID: exactFixture.ownerUserID,
            checkpoints: [exactCheckpoint, exactCheckpoint, exactCheckpoint],
            historyRows: [exactRow]
        )

        let exactSummary = try await makeService(
            fixture: exactFixture,
            transport: exactTransport
        ).recoverFromRemoteSnapshot(ownerUserID: exactFixture.ownerUserID)
        XCTAssertTrue(exactSummary.completedRecoveryJournal)
        XCTAssertNotNil(exactFixture.controller.activeManifest)

        let oversizedFixture = try makeFixture()
        let oversizedRow = try makeHistoryRow(
            fixture: oversizedFixture,
            encodedBytes: ShopSyncRecoveryLimits.maximumHistoryRowPayloadBytes + 1
        )
        let oversizedCheckpoint = makeCheckpoint(
            fixture: oversizedFixture,
            maxEventID: 42,
            seed: "history-oversized-budget",
            historyRow: oversizedRow
        )
        let oversizedTransport = AtomicRecoveryTestTransport(
            ownerUserID: oversizedFixture.ownerUserID,
            checkpoints: [oversizedCheckpoint],
            historyRows: [oversizedRow]
        )

        do {
            _ = try await makeService(
                fixture: oversizedFixture,
                transport: oversizedTransport
            ).recoverFromRemoteSnapshot(ownerUserID: oversizedFixture.ownerUserID)
            XCTFail("A history row one byte beyond the full-row budget must fail closed")
        } catch {
            XCTAssertEqual(
                error as? ShopSyncRecoveryContractError,
                .resourceBudgetExceeded(domain: .history)
            )
        }
        XCTAssertNil(oversizedFixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(
            defaults: oversizedFixture.defaults
        ).pendingRecoveryJournal)
    }

    func testBackendCannotShrinkPageLimitIntoUnboundedRecoveryCalls() async throws {
        let fixture = try makeFixture()
        let checkpoint = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "small-page")
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint],
            forcedPageLimit: 1
        )

        do {
            _ = try await makeService(
                fixture: fixture,
                transport: transport
            ).recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("A backend page must echo the requested bounded page limit")
        } catch {
            XCTAssertEqual(
                error as? ShopSyncRecoveryContractError,
                .invalidPage(domain: .suppliers)
            )
        }

        let counts = await transport.counts()
        XCTAssertEqual(counts.pages, 1)
        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
    }

    private func makeService(
        fixture: AtomicRecoveryFixture,
        transport: AtomicRecoveryTestTransport,
        maximumAttempts: Int = 2
    ) -> AtomicGenerationRecoverySnapshotPullService {
        AtomicGenerationRecoverySnapshotPullService(
            storeGenerationController: fixture.controller,
            recoveryRemote: ShopSyncRecoveryRemoteAdapter(
                transport: transport,
                defaults: fixture.defaults
            ),
            defaults: fixture.defaults,
            pageLimit: 25,
            maximumAttempts: maximumAttempts
        )
    }

    private func makeFixture() throws -> AtomicRecoveryFixture {
        let suiteName = "AtomicGenerationRecoverySnapshotPullServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AtomicGenerationRecovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)

        let ownerUserID = UUID()
        let shopID = UUID()
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let selectedShop = SelectedShop(
            shopID: shopID,
            code: "TASK139",
            name: "Atomic recovery fixture",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedShopStore = SelectedShopStore(defaults: defaults)
        selectedShopStore.noteActiveAccount(accountHash)
        XCTAssertTrue(selectedShopStore.save(selectedShop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: selectedShop.localStoreIdentity
        ))
        XCTAssertEqual(
            defaults.string(forKey: "mobile.shopContext.activeAccountHash.v1"),
            accountHash
        )
        let deviceInstallID = DeviceInstallIDStore(defaults: defaults).deviceInstallID
        let legacyStoreURL = temporaryRoot.appendingPathComponent("legacy-default.store")
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: temporaryRoot.appendingPathComponent("generation-root"),
            legacyDefaultStoreURL: legacyStoreURL,
            defaults: defaults
        )
        let controller = try SyncStoreGenerationController(
            repository: repository,
            defaults: defaults
        )
        XCTAssertEqual(
            defaults.string(forKey: "mobile.shopContext.activeAccountHash.v1"),
            accountHash
        )
        addTeardownBlock { [defaults, suiteName, temporaryRoot] in
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        return AtomicRecoveryFixture(
            controller: controller,
            defaults: defaults,
            suiteName: suiteName,
            temporaryRoot: temporaryRoot,
            recoveryJournalURL: repository.recoveryJournalURL,
            recoveryFinalizationURL: repository.recoveryFinalizationURL,
            ownerUserID: ownerUserID,
            shopID: shopID,
            deviceInstallID: deviceInstallID
        )
    }

    private func reopenFixture(_ fixture: AtomicRecoveryFixture) throws -> AtomicRecoveryFixture {
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: fixture.temporaryRoot
                .appendingPathComponent("generation-root", isDirectory: true),
            legacyDefaultStoreURL: fixture.temporaryRoot
                .appendingPathComponent("legacy-default.store", isDirectory: false),
            defaults: fixture.defaults
        )
        let controller = try SyncStoreGenerationController(
            repository: repository,
            defaults: fixture.defaults
        )
        return AtomicRecoveryFixture(
            controller: controller,
            defaults: fixture.defaults,
            suiteName: fixture.suiteName,
            temporaryRoot: fixture.temporaryRoot,
            recoveryJournalURL: repository.recoveryJournalURL,
            recoveryFinalizationURL: repository.recoveryFinalizationURL,
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            deviceInstallID: fixture.deviceInstallID
        )
    }

    private func makeCheckpoint(
        fixture: AtomicRecoveryFixture,
        maxEventID: Int64,
        seed: String,
        historyRow: AtomicRecoveryHistoryRowPayload? = nil
    ) -> ShopSyncRecoveryCheckpoint {
        let emptyHash = ShopSyncRecoveryCanonical.checkpointChainInitialDigest
        let empty = ShopSyncRecoveryEntityDigest(
            activeCount: 0,
            tombstoneCount: 0,
            idSetDigest: emptyHash,
            versionDigest: emptyHash
        )
        let products = ShopSyncRecoveryEntityDigest(
            activeCount: 0,
            tombstoneCount: 0,
            idSetDigest: emptyHash,
            versionDigest: emptyHash,
            identityDigest: emptyHash
        )
        let deviceKey = ShopSyncRecoveryCanonical.sha256(fixture.deviceInstallID)
        let scope = ShopSyncRecoveryScope(
            kind: "shop_scoped",
            key: ShopSyncRecoveryCanonical.sha256(
                fixture.shopID.uuidString.lowercased() + ":shop_scoped:-:" + deviceKey
            ),
            legacyOwnerKey: nil,
            accountKey: AccountBindingStore.accountHash(for: fixture.ownerUserID),
            deviceKey: deviceKey
        )
        let history: ShopSyncRecoveryEntityDigest
        if let historyRow {
            let id = historyRow.remoteID.uuidString.lowercased()
            let suffix: [String]
            if historyRow.deletedAt != nil {
                suffix = [ShopSyncRecoveryCanonical.null]
            } else {
                suffix = [
                    historyRow.timestamp,
                    ShopSyncRecoveryCanonical.sha256(historyRow.supplier),
                    ShopSyncRecoveryCanonical.sha256(historyRow.category),
                    historyRow.isManualEntry ? "true" : "false",
                    ShopSyncRecoveryCanonical.sha256(historyRow.displayName),
                    historyRow.dataCheckpointDigest ?? ShopSyncRecoveryCanonical.null,
                    historyRow.overlayCheckpointDigest ?? ShopSyncRecoveryCanonical.null
                ]
            }
            let versionLine = (
                [
                    id,
                    historyRow.updatedAt ?? ShopSyncRecoveryCanonical.null,
                    historyRow.deletedAt ?? ShopSyncRecoveryCanonical.null,
                    String(historyRow.payloadVersion)
                ] + suffix
            ).joined(separator: ShopSyncRecoveryCanonical.separator)
            history = ShopSyncRecoveryEntityDigest(
                activeCount: historyRow.deletedAt == nil ? 1 : 0,
                tombstoneCount: historyRow.deletedAt == nil ? 0 : 1,
                idSetDigest: ShopSyncRecoveryCanonical.checkpointChainDigest([id]),
                versionDigest: ShopSyncRecoveryCanonical.checkpointChainDigest([versionLine])
            )
        } else {
            history = empty
        }
        return ShopSyncRecoveryCheckpoint(
            schemaVersion: "shop-sync-recovery-checkpoint-v1",
            shopId: fixture.shopID,
            scope: scope,
            syncEvents: ShopSyncRecoveryEventCheckpoint(
                maxId: String(maxEventID),
                verifiedBaselineId: "0",
                requiresFullRecovery: true,
                domainMaxIds: ShopSyncRecoveryDomainEventMaxIDs(
                    catalog: String(maxEventID),
                    prices: String(maxEventID),
                    history: String(maxEventID)
                )
            ),
            catalog: ShopSyncRecoveryCatalogDigest(
                suppliers: empty,
                categories: empty,
                products: products,
                digest: ShopSyncRecoveryCanonical.sha256(
                    emptyHash + "\n" + emptyHash + "\n" + emptyHash
                )
            ),
            prices: empty,
            history: history,
            images: empty,
            integrity: ShopSyncRecoveryIntegrity(
                productCategoryViolationCount: 0,
                productSupplierViolationCount: 0,
                priceProductViolationCount: 0,
                primaryImageViolationCount: 0,
                historyIdViolationCount: 0,
                totalViolationCount: 0
            ),
            checkpointDigest: ShopSyncRecoveryCanonical.sha256(seed)
        )
    }

    private func makeCatalogPriceCheckpoint(
        fixture: AtomicRecoveryFixture,
        maxEventID: Int64,
        seed: String,
        products: [RemoteInventoryProductRow],
        prices: [RemoteInventoryProductPriceRow],
        images: [ShopSyncRecoveryImageRow] = []
    ) throws -> ShopSyncRecoveryCheckpoint {
        let base = makeCheckpoint(
            fixture: fixture,
            maxEventID: maxEventID,
            seed: seed
        )
        var productAccumulator = ShopSyncRecoveryDigestAccumulator(hasIdentity: true)
        for row in products.sorted(by: {
            $0.id.uuidString.lowercased() < $1.id.uuidString.lowercased()
        }) {
            let record = try ShopSyncRecoveryRowContract.product(row, checkpoint: base)
            try productAccumulator.append(
                orderingID: record.orderingID,
                idLine: record.idLine,
                versionLine: record.versionLine,
                identityLine: record.identityLine,
                isTombstone: record.isTombstone
            )
        }
        let productDigest = productAccumulator.finalize()
        var priceAccumulator = ShopSyncRecoveryDigestAccumulator()
        for row in prices.sorted(by: {
            $0.id.uuidString.lowercased() < $1.id.uuidString.lowercased()
        }) {
            let record = try ShopSyncRecoveryRowContract.price(row, checkpoint: base)
            try priceAccumulator.append(
                orderingID: record.orderingID,
                idLine: record.idLine,
                versionLine: record.versionLine,
                identityLine: record.identityLine,
                isTombstone: record.isTombstone
            )
        }
        let priceDigest = priceAccumulator.finalize()
        var imageAccumulator = ShopSyncRecoveryDigestAccumulator()
        for row in images.sorted(by: {
            $0.productID.uuidString.lowercased() < $1.productID.uuidString.lowercased()
        }) {
            let record = try ShopSyncRecoveryRowContract.image(row, checkpoint: base)
            try imageAccumulator.append(
                orderingID: record.orderingID,
                idLine: record.idLine,
                versionLine: record.versionLine,
                identityLine: record.identityLine,
                isTombstone: record.isTombstone
            )
        }
        let imageDigest = imageAccumulator.finalize()
        return ShopSyncRecoveryCheckpoint(
            schemaVersion: base.schemaVersion,
            shopId: base.shopId,
            scope: base.scope,
            syncEvents: base.syncEvents,
            catalog: ShopSyncRecoveryCatalogDigest(
                suppliers: base.catalog.suppliers,
                categories: base.catalog.categories,
                products: productDigest,
                digest: ShopSyncRecoveryCanonical.sha256(
                    base.catalog.suppliers.versionDigest + "\n"
                        + base.catalog.categories.versionDigest + "\n"
                        + productDigest.versionDigest
                )
            ),
            prices: priceDigest,
            history: base.history,
            images: imageDigest,
            integrity: base.integrity,
            checkpointDigest: ShopSyncRecoveryCanonical.sha256(seed)
        )
    }

    private func makeImageTombstone(
        fixture: AtomicRecoveryFixture,
        productID: UUID,
        deletedAt: String
    ) -> ShopSyncRecoveryImageRow {
        ShopSyncRecoveryImageRow(
            productID: productID,
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            productDeletedAt: deletedAt,
            versionID: UUID(),
            status: "ready",
            finalizedAt: "2026-07-23T00:00:00.000000Z",
            main: .init(
                sha256: String(repeating: "a", count: 64),
                bytes: 1_024,
                width: 1_600,
                height: 1_600,
                mime: "image/jpeg"
            ),
            thumb: .init(
                sha256: String(repeating: "b", count: 64),
                bytes: 512,
                width: 384,
                height: 384,
                mime: "image/jpeg"
            )
        )
    }

    private func makeDivergentCheckpoint(
        fixture: AtomicRecoveryFixture,
        maxEventID: Int64,
        seed: String
    ) -> ShopSyncRecoveryCheckpoint {
        let base = makeCheckpoint(
            fixture: fixture,
            maxEventID: maxEventID,
            seed: seed
        )
        let suppliers = ShopSyncRecoveryEntityDigest(
            activeCount: 1,
            tombstoneCount: 0,
            idSetDigest: ShopSyncRecoveryCanonical.sha256("divergent-supplier-id:\(seed)"),
            versionDigest: ShopSyncRecoveryCanonical.sha256("divergent-supplier-version:\(seed)")
        )
        return ShopSyncRecoveryCheckpoint(
            schemaVersion: base.schemaVersion,
            status: base.status,
            shopId: base.shopId,
            scope: base.scope,
            syncEvents: base.syncEvents,
            catalog: ShopSyncRecoveryCatalogDigest(
                suppliers: suppliers,
                categories: base.catalog.categories,
                products: base.catalog.products,
                digest: ShopSyncRecoveryCanonical.sha256(
                    suppliers.versionDigest + "\n"
                        + base.catalog.categories.versionDigest + "\n"
                        + base.catalog.products.versionDigest
                )
            ),
            prices: base.prices,
            history: base.history,
            images: base.images,
            integrity: base.integrity,
            checkpointDigest: ShopSyncRecoveryCanonical.sha256("divergent-checkpoint:\(seed)")
        )
    }

    private func makeHistoryRow(
        fixture: AtomicRecoveryFixture,
        encodedBytes: Int
    ) throws -> AtomicRecoveryHistoryRowPayload {
        let remoteID = UUID()
        let timestamp = "2026-07-21 12:00:00"
        let updatedAt = "2026-07-21T12:00:00.000000Z"
        let dataCheckpointDigest = String(repeating: "a", count: 64)
        let overlayCheckpointDigest = String(repeating: "b", count: 64)
        func row(displayName: String) -> RemoteSharedSheetSessionRow {
            RemoteSharedSheetSessionRow(
                remoteID: remoteID,
                payloadVersion: 2,
                displayName: displayName,
                timestamp: timestamp,
                supplier: "",
                category: "",
                isManualEntry: false,
                data: [],
                sessionOverlay: nil,
                ownerUserID: fixture.ownerUserID,
                shopID: fixture.shopID,
                dataCheckpointDigest: dataCheckpointDigest,
                overlayCheckpointDigest: overlayCheckpointDigest,
                updatedAt: updatedAt,
                deletedAt: nil
            )
        }
        let baseBytes = try JSONEncoder().encode(row(displayName: "")).count
        let fillerCount = encodedBytes - baseBytes
        guard fillerCount >= 0 else {
            throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .history)
        }
        let displayName = String(repeating: "x", count: fillerCount)
        XCTAssertEqual(try JSONEncoder().encode(row(displayName: displayName)).count, encodedBytes)
        return AtomicRecoveryHistoryRowPayload(
            remoteID: remoteID,
            payloadVersion: 2,
            displayName: displayName,
            timestamp: timestamp,
            supplier: "",
            category: "",
            isManualEntry: false,
            data: [],
            sessionOverlay: nil,
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            dataCheckpointDigest: dataCheckpointDigest,
            overlayCheckpointDigest: overlayCheckpointDigest,
            updatedAt: updatedAt,
            deletedAt: nil
        )
    }
}

private struct AtomicRecoveryFixture {
    let controller: SyncStoreGenerationController
    let defaults: UserDefaults
    let suiteName: String
    let temporaryRoot: URL
    let recoveryJournalURL: URL
    let recoveryFinalizationURL: URL
    let ownerUserID: UUID
    let shopID: UUID
    let deviceInstallID: String
}

private nonisolated enum AtomicRecoveryTailBehavior: Sendable {
    case safe
    case missingEntityIDs
    case incompleteEntityIDs
}

private nonisolated struct AtomicRecoveryCheckpointCall: Sendable {
    let verifiedBaselineID: String
    let expectedBaselineScopeKey: String?
}

private actor AtomicRecoveryTestTransport: ShopSyncRecoveryRPCTransporting {
    private let ownerUserID: UUID
    private let checkpoints: [ShopSyncRecoveryCheckpoint]
    private let cancellationDomain: ShopSyncRecoveryDomain?
    private let historyRows: [AtomicRecoveryHistoryRowPayload]
    private let productRows: [RemoteInventoryProductRow]
    private let priceRows: [RemoteInventoryProductPriceRow]
    private let imageRows: [ShopSyncRecoveryImageRow]
    private let forcedPageLimit: Int?
    private let checkpointMutation: (@Sendable (Int) throws -> Void)?
    private let tailBehavior: AtomicRecoveryTailBehavior
    private let markerFailure: ShopSyncRecoveryContractError?
    private let markerMutation: (@Sendable () throws -> Void)?
    private var checkpointIndex = 0
    private var checkpointCalls = 0
    private var pageCalls = 0
    private var tailPages = 0
    private var markerBaselineIDs: [String] = []
    private var checkpointCallParameters: [AtomicRecoveryCheckpointCall] = []
    private var latestCheckpoint: ShopSyncRecoveryCheckpoint?
    private let encoder = JSONEncoder()

    init(
        ownerUserID: UUID,
        checkpoints: [ShopSyncRecoveryCheckpoint],
        cancellationDomain: ShopSyncRecoveryDomain? = nil,
        historyRows: [AtomicRecoveryHistoryRowPayload] = [],
        productRows: [RemoteInventoryProductRow] = [],
        priceRows: [RemoteInventoryProductPriceRow] = [],
        imageRows: [ShopSyncRecoveryImageRow] = [],
        forcedPageLimit: Int? = nil,
        checkpointMutation: (@Sendable (Int) throws -> Void)? = nil,
        tailBehavior: AtomicRecoveryTailBehavior = .safe,
        markerFailure: ShopSyncRecoveryContractError? = nil,
        markerMutation: (@Sendable () throws -> Void)? = nil
    ) {
        self.ownerUserID = ownerUserID
        self.checkpoints = checkpoints
        self.cancellationDomain = cancellationDomain
        self.historyRows = historyRows
        self.productRows = productRows
        self.priceRows = priceRows
        self.imageRows = imageRows
        self.forcedPageLimit = forcedPageLimit
        self.checkpointMutation = checkpointMutation
        self.tailBehavior = tailBehavior
        self.markerFailure = markerFailure
        self.markerMutation = markerMutation
    }

    func authenticatedUserID() async throws -> UUID {
        ownerUserID
    }

    func checkpoint(_ parameters: ShopSyncRecoveryCheckpointParameters) async throws -> Data {
        guard !checkpoints.isEmpty else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
        checkpointCalls += 1
        checkpointCallParameters.append(AtomicRecoveryCheckpointCall(
            verifiedBaselineID: parameters.verifiedBaselineID,
            expectedBaselineScopeKey: parameters.expectedBaselineScopeKey
        ))
        try checkpointMutation?(checkpointCalls)
        let index = min(checkpointIndex, checkpoints.count - 1)
        checkpointIndex += 1
        let fixtureCheckpoint = checkpoints[index]
        let checkpoint = ShopSyncRecoveryCheckpoint(
            schemaVersion: fixtureCheckpoint.schemaVersion,
            status: fixtureCheckpoint.status,
            shopId: fixtureCheckpoint.shopId,
            scope: fixtureCheckpoint.scope,
            syncEvents: ShopSyncRecoveryEventCheckpoint(
                maxId: fixtureCheckpoint.syncEvents.maxId,
                verifiedBaselineId: parameters.verifiedBaselineID,
                requiresFullRecovery: fixtureCheckpoint.syncEvents.requiresFullRecovery,
                domainMaxIds: fixtureCheckpoint.syncEvents.domainMaxIds
            ),
            catalog: fixtureCheckpoint.catalog,
            prices: fixtureCheckpoint.prices,
            history: fixtureCheckpoint.history,
            images: fixtureCheckpoint.images,
            integrity: fixtureCheckpoint.integrity,
            checkpointDigest: fixtureCheckpoint.checkpointDigest
        )
        latestCheckpoint = checkpoint
        return try encoder.encode(checkpoint)
    }

    func page(_ parameters: ShopSyncRecoveryPageParameters) async throws -> Data {
        pageCalls += 1
        guard let domain = ShopSyncRecoveryDomain(rawValue: parameters.domain),
              let checkpoint = latestCheckpoint ?? checkpoints.first else {
            throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
        if domain == cancellationDomain { throw CancellationError() }
        if domain == .products, !productRows.isEmpty {
            return try encoder.encode(AtomicRecoveryRowsPage(
                schemaVersion: "shop-sync-recovery-page-v1",
                shopId: parameters.shopID,
                scope: checkpoint.scope,
                domain: domain,
                snapshotEventMaxId: parameters.expectedEventMaxID,
                currentScopeEventMaxId: parameters.expectedEventMaxID,
                baselineDomainEventMaxId: parameters.expectedDomainEventMaxID,
                pageDomainEventMaxId: parameters.expectedDomainEventMaxID,
                domainScope: domain == .history ? checkpoint.scope.historyKind : checkpoint.scope.kind,
                pageLimit: forcedPageLimit ?? parameters.limit,
                rows: productRows,
                nextAfterId: nil,
                hasMore: false
            ))
        }
        if domain == .prices, !priceRows.isEmpty {
            return try encoder.encode(AtomicRecoveryRowsPage(
                schemaVersion: "shop-sync-recovery-page-v1",
                shopId: parameters.shopID,
                scope: checkpoint.scope,
                domain: domain,
                snapshotEventMaxId: parameters.expectedEventMaxID,
                currentScopeEventMaxId: parameters.expectedEventMaxID,
                baselineDomainEventMaxId: parameters.expectedDomainEventMaxID,
                pageDomainEventMaxId: parameters.expectedDomainEventMaxID,
                domainScope: domain == .history ? checkpoint.scope.historyKind : checkpoint.scope.kind,
                pageLimit: forcedPageLimit ?? parameters.limit,
                rows: priceRows,
                nextAfterId: nil,
                hasMore: false
            ))
        }
        if domain == .history, !historyRows.isEmpty {
            return try encoder.encode(AtomicRecoveryHistoryPage(
                schemaVersion: "shop-sync-recovery-page-v1",
                shopId: parameters.shopID,
                scope: checkpoint.scope,
                domain: domain,
                snapshotEventMaxId: parameters.expectedEventMaxID,
                currentScopeEventMaxId: parameters.expectedEventMaxID,
                baselineDomainEventMaxId: parameters.expectedDomainEventMaxID,
                pageDomainEventMaxId: parameters.expectedDomainEventMaxID,
                domainScope: domain == .history ? checkpoint.scope.historyKind : checkpoint.scope.kind,
                pageLimit: forcedPageLimit ?? parameters.limit,
                rows: historyRows,
                nextAfterId: nil,
                hasMore: false
            ))
        }
        if domain == .images, !imageRows.isEmpty {
            return try encoder.encode(AtomicRecoveryRowsPage(
                schemaVersion: "shop-sync-recovery-page-v1",
                shopId: parameters.shopID,
                scope: checkpoint.scope,
                domain: domain,
                snapshotEventMaxId: parameters.expectedEventMaxID,
                currentScopeEventMaxId: parameters.expectedEventMaxID,
                baselineDomainEventMaxId: parameters.expectedDomainEventMaxID,
                pageDomainEventMaxId: parameters.expectedDomainEventMaxID,
                domainScope: domain == .history ? checkpoint.scope.historyKind : checkpoint.scope.kind,
                pageLimit: forcedPageLimit ?? parameters.limit,
                rows: imageRows,
                nextAfterId: nil,
                hasMore: false
            ))
        }
        return try encoder.encode(AtomicRecoveryEmptyPage(
            schemaVersion: "shop-sync-recovery-page-v1",
            shopId: parameters.shopID,
            scope: checkpoint.scope,
            domain: domain,
            snapshotEventMaxId: parameters.expectedEventMaxID,
            currentScopeEventMaxId: parameters.expectedEventMaxID,
            baselineDomainEventMaxId: parameters.expectedDomainEventMaxID,
            pageDomainEventMaxId: parameters.expectedDomainEventMaxID,
            domainScope: domain == .history ? checkpoint.scope.historyKind : checkpoint.scope.kind,
            pageLimit: forcedPageLimit ?? parameters.limit,
            rows: [],
            nextAfterId: nil,
            hasMore: false
        ))
    }

    func marker(_ parameters: ShopSyncConvergenceMarkerParameters) async throws -> Data {
        try markerMutation?()
        if let markerFailure { throw markerFailure }
        markerBaselineIDs.append(parameters.verifiedBaselineID)
        guard let checkpoint = latestCheckpoint ?? checkpoints.first,
              checkpoint.shopId == parameters.shopID,
              checkpoint.scope.key == parameters.expectedBaselineScopeKey,
              checkpoint.syncEvents.maxId == parameters.verifiedBaselineID else {
            throw ShopSyncRecoveryContractError.markerNotVerified
        }
        let marker = ShopSyncRecoveryConvergenceMarker(
            schemaVersion: "shop-sync-convergence-marker-v1",
            status: "ready",
            shopId: checkpoint.shopId,
            scope: checkpoint.scope,
            syncEvents: ShopSyncRecoveryEventCheckpoint(
                maxId: parameters.verifiedBaselineID,
                verifiedBaselineId: parameters.verifiedBaselineID,
                requiresFullRecovery: false,
                domainMaxIds: checkpoint.syncEvents.domainMaxIds
            ),
            catalog: checkpoint.catalog,
            prices: checkpoint.prices,
            history: checkpoint.history,
            images: checkpoint.images,
            integrity: ShopSyncRecoveryMarkerIntegrity(totalViolationCount: 0),
            checkpointDigest: checkpoint.checkpointDigest,
            serverNoWorkEligible: true,
            markerDigest: ShopSyncRecoveryCanonical.sha256(
                "fixture-marker:\(parameters.verifiedBaselineID)"
            )
        )
        return try encoder.encode(marker)
    }

    func eventPage(_ parameters: ShopSyncEventPageParameters) async throws -> Data {
        tailPages += 1
        guard let checkpoint = latestCheckpoint ?? checkpoints.first,
              checkpoint.shopId == parameters.shopID,
              checkpoint.scope.key == parameters.expectedScopeKey,
              checkpoint.syncEvents.maxId == parameters.expectedEventMaxID,
              let after = try? ShopSyncRecoveryCanonical.eventID(parameters.afterID),
              let through = try? ShopSyncRecoveryCanonical.eventID(parameters.expectedEventMaxID),
              after < through else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
        let end = min(through, after + Int64(parameters.limit))
        let isUnsafe = tailBehavior != .safe
        let entityIDs: SyncEventJSONValue? = tailBehavior == .incompleteEntityIDs
            ? .object([:])
            : nil
        let rows = (after + 1...end).map { eventID in
            AtomicRecoveryEventRow(
                id: String(eventID),
                ownerUserID: ownerUserID,
                shopID: parameters.shopID,
                domain: "catalog",
                eventType: "fixture",
                changedCount: isUnsafe ? 1 : 0,
                entityIDs: entityIDs,
                requiresFullRecovery: false,
                createdAt: "2026-07-23T00:00:00.000000Z"
            )
        }
        let hasMore = end < through
        return try encoder.encode(AtomicRecoveryEventPage(
            schemaVersion: "shop-sync-event-page-v1",
            shopId: parameters.shopID,
            scope: checkpoint.scope,
            scopeEventMaxId: parameters.expectedEventMaxID,
            asOfEventMaxId: parameters.expectedEventMaxID,
            asOfDomainEventMaxIds: checkpoint.syncEvents.domainMaxIds,
            pageLimit: parameters.limit,
            rows: rows,
            nextAfterId: hasMore ? String(end) : nil,
            hasMore: hasMore
        ))
    }

    func counts() -> (checkpoints: Int, pages: Int, tailPages: Int) {
        (checkpointCalls, pageCalls, tailPages)
    }

    func markerBaselineIDsForTesting() -> [String] {
        markerBaselineIDs
    }

    func checkpointCallsForTesting() -> [AtomicRecoveryCheckpointCall] {
        checkpointCallParameters
    }
}

private struct AtomicRecoveryEventPage: Encodable {
    let schemaVersion: String
    let shopId: UUID
    let scope: ShopSyncRecoveryScope
    let scopeEventMaxId: String
    let asOfEventMaxId: String
    let asOfDomainEventMaxIds: ShopSyncRecoveryDomainEventMaxIDs
    let pageLimit: Int
    let rows: [AtomicRecoveryEventRow]
    let nextAfterId: String?
    let hasMore: Bool
}

private struct AtomicRecoveryEventRow: Encodable {
    let id: String
    let ownerUserID: UUID
    let shopID: UUID
    let domain: String
    let eventType: String
    let changedCount: Int
    let entityIDs: SyncEventJSONValue?
    let requiresFullRecovery: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case domain
        case eventType = "event_type"
        case changedCount = "changed_count"
        case entityIDs = "entity_ids"
        case requiresFullRecovery = "requires_full_recovery"
        case createdAt = "created_at"
    }
}

private struct AtomicRecoveryRowsPage<Row: Encodable>: Encodable {
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

private struct AtomicRecoveryEmptyPage: Encodable {
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
    let rows: [String]
    let nextAfterId: String?
    let hasMore: Bool
}

private struct AtomicRecoveryHistoryPage: Encodable {
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
    let rows: [AtomicRecoveryHistoryRowPayload]
    let nextAfterId: String?
    let hasMore: Bool
}

private struct AtomicRecoveryHistoryRowPayload: Encodable {
    let remoteID: UUID
    let payloadVersion: Int
    let displayName: String
    let timestamp: String
    let supplier: String
    let category: String
    let isManualEntry: Bool
    let data: [[String]]
    let sessionOverlay: HistorySessionOverlayPayload?
    let ownerUserID: UUID
    let shopID: UUID?
    let dataCheckpointDigest: String?
    let overlayCheckpointDigest: String?
    let updatedAt: String?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case remoteID = "remote_id"
        case payloadVersion = "payload_version"
        case displayName = "display_name"
        case timestamp
        case supplier
        case category
        case isManualEntry = "is_manual_entry"
        case data
        case sessionOverlay = "session_overlay"
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case dataCheckpointDigest = "data_checkpoint_digest"
        case overlayCheckpointDigest = "overlay_checkpoint_digest"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}
