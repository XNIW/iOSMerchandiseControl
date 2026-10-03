import Combine
import SwiftData
import Supabase
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class AtomicGenerationRecoverySnapshotPullServiceTests: XCTestCase {
    func testVerifiedDiskRecoveryAllowsTwoOrdinaryAutomaticCatalogUpdates() async throws {
        try await assertOrdinaryAutomaticContinuation(reopenBeforeSecondEvent: false)
    }

    func testVerifiedDiskRecoveryAllowsOrdinaryAutomaticUpdateAfterFreshOpen() async throws {
        try await assertOrdinaryAutomaticContinuation(reopenBeforeSecondEvent: true)
    }

    func testVerifiedDiskRecoveryAllowsNoEventsPollBeforeThirdOrdinaryAutomaticCatalogUpdate() async throws {
        try await assertOrdinaryAutomaticContinuation(
            reopenBeforeSecondEvent: false, includeNoEventsAndThirdDelta: true
        )
    }

    func testOrdinaryContinuationReceiptRejectsChangedAuthority() async throws {
        let mutations = ["lease", "owner", "shop", "device", "binding", "watermark", "generation",
                         "fenceMissing", "fenceTampered", "fenceDifferent", "finalization", "manifest", "journal"]
        for mutation in mutations {
            let proof = try await makeRealContinuationProof()
            let fixture = proof.fixture
            switch mutation {
            case "lease": Task126OwnerStoreGate.invalidateAutomaticScopeLease()
            case "owner": fixture.defaults.set(AccountBindingStore.accountHash(for: UUID()),
                                               forKey: "mobile.shopContext.activeAccountHash.v1")
            case "shop":
                let shop = SelectedShop(shopID: UUID(), code: "RI08-OTHER", name: "Other fixture shop",
                                        role: "owner", status: "active", selectable: true, canWrite: true)
                XCTAssertTrue(SelectedShopStore(defaults: fixture.defaults).save(shop, accountHash: proof.scope.accountHash))
            case "device": fixture.defaults.set(UUID().uuidString.lowercased(), forKey: "shop.device.install.id")
            case "binding": AccountBindingStore(defaults: fixture.defaults).clearBinding()
            case "watermark": WatermarkStore(defaults: fixture.defaults).save(42, for: proof.watermarkScope)
            case "generation":
                XCTAssertTrue(WatermarkStore(defaults: fixture.defaults).saveAuthoritativeRecoveryCheckpoint(
                    41, generationID: UUID(), for: proof.watermarkScope))
            case "fenceMissing": fixture.defaults.removeObject(forKey: proof.fenceDefaultsKey)
            case "fenceTampered": fixture.defaults.set(Data("invalid".utf8), forKey: proof.fenceDefaultsKey)
            case "fenceDifferent":
                let scope = proof.checkpoint.scope
                let other = ShopSyncRecoveryScope(kind: scope.kind, historyKind: scope.historyKind,
                    key: String(repeating: "a", count: 64), legacyOwnerKey: scope.legacyOwnerKey,
                    accountKey: scope.accountKey, deviceKey: scope.deviceKey)
                XCTAssertTrue(ShopSyncRecoveryFenceStore(defaults: fixture.defaults).saveAuthoritative(
                    scope: other, watermark: 41, accountHash: proof.scope.accountHash,
                    storeIdentity: proof.scope.storeIdentity, deviceIdentityHash: proof.scope.deviceIdentityHash))
            case "finalization": try FileManager.default.removeItem(at: fixture.recoveryFinalizationURL)
            case "manifest":
                try Data("invalid".utf8).write(to: fixture.temporaryRoot
                    .appendingPathComponent("generation-root/active-generation.json"))
            case "journal":
                XCTAssertTrue(AccountBindingStore(defaults: fixture.defaults).beginSameScopeRecovery(
                    accountHash: proof.scope.accountHash, storeIdentity: proof.scope.storeIdentity,
                    reason: "ri08-post-issuance", deviceIdentityHash: proof.scope.deviceIdentityHash))
            default: XCTFail("Unknown mutation")
            }
            proof.stateStore.recordRunResult(proof.result)
            XCTAssertEqual(proof.stateStore.state.phase, .recoveryRequired, mutation)
            XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt, mutation)
            XCTAssertFalse(proof.result.verifiedConvergence)
            if mutation == "journal" {
                XCTAssertTrue(AccountBindingStore(defaults: fixture.defaults).hasPendingReplacementJournal)
            }
        }
    }

    func testOrdinaryContinuationReceiptRejectsNewLocalWorkAndCountDrift() async throws {
        for mutation in ["pending", "blocked", "staleBaseline", "sent", "unknownPending", "cap", "foreignPending",
                         "outbox", "unknownOutbox", "dirtyHistory", "localCountDrift"] {
            let proof = try await makeRealContinuationProof()
            let context = ModelContext(proof.fixture.controller.modelContainer)
            context.autosaveEnabled = false
            if mutation == "outbox" || mutation == "unknownOutbox" {
                let entry = SyncEventOutboxEntry(ownerUserID: proof.fixture.ownerUserID.uuidString.lowercased(),
                    storeId: proof.scope.storeIdentity.storeId, domain: "inventory", eventType: "catalog-updated",
                    changedCount: 1, entityIDsShape: "object", metadataShape: "object", nextRetryAt: Date(),
                    createdAt: Date(), updatedAt: Date())
                if mutation == "unknownOutbox" { entry.statusRaw = "unknown" }
                context.insert(entry)
            } else if mutation == "dirtyHistory" {
                context.insert(HistoryEntry(id: "ri08-dirty.xlsx", ownerUserID: proof.fixture.ownerUserID.uuidString.lowercased(),
                                            storeID: proof.scope.storeIdentity.storeId, shopID: proof.fixture.shopID))
            } else if mutation == "localCountDrift" {
                let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first)
                context.delete(product)
            } else {
                let change = LocalPendingChange(ownerUserID: mutation == "foreignPending" ? UUID() : proof.fixture.ownerUserID,
                    storeId: proof.scope.storeIdentity.storeId,
                    entityKind: mutation == "cap" ? .importBatch : .product, operation: .update,
                    origin: .manualCatalogSave, logicalKey: mutation == "cap" ? "import:cap:ri08" : "ri08:product")
                if mutation == "unknownPending" { change.statusRaw = "unknown" }
                else if ["blocked", "staleBaseline", "sent"].contains(mutation) { change.statusRaw = mutation }
                context.insert(change)
            }
            try context.save()
            proof.stateStore.recordRunResult(proof.result)
            XCTAssertEqual(proof.stateStore.state.phase, .recoveryRequired, mutation)
            XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt, mutation)
        }
    }

    func testOrdinaryContinuationReceiptPreservesGenuineRecoveryAndCancelsOriginatingRun() async throws {
        for mutation in ["origin", "preserve", "runCancellation", "consumerTaskCancellation"] {
            let proof = try await makeRealContinuationProof(eventID: 42)
            XCTAssertEqual(try ordinaryStock(fixture: proof.fixture, productID: proof.productID), 1)
            XCTAssertEqual(ordinaryWatermark(fixture: proof.fixture), 42)
            if mutation == "origin" { proof.stateStore.updatePhase(.recoveryRequired) }
            if mutation == "runCancellation" { await proof.policy.requestCancellation() }
            if mutation == "consumerTaskCancellation" {
                let publication = Task { @MainActor in proof.stateStore.recordRunResult(proof.result) }
                publication.cancel()
                await publication.value
            } else {
                proof.stateStore.recordRunResult(proof.result, preserveRecoveryRequired: mutation == "preserve")
            }
            XCTAssertEqual(proof.stateStore.state.phase, .recoveryRequired, mutation)
            XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt, mutation)
        }
    }

    func testOrdinaryContinuationReceiptRevalidatesOnReadAfterPublication() async throws {
        for mutation in ["lease", "runCancellation", "pending"] {
            let proof = try await makeRealContinuationProof()
            proof.stateStore.recordRunResult(proof.result)
            XCTAssertEqual(proof.stateStore.state.phase, .idle)
            if mutation == "lease" { Task126OwnerStoreGate.invalidateAutomaticScopeLease() }
            else if mutation == "runCancellation" { await proof.policy.requestCancellation() }
            else {
                let context = ModelContext(proof.fixture.controller.modelContainer)
                context.insert(LocalPendingChange(ownerUserID: proof.fixture.ownerUserID,
                    storeId: proof.scope.storeIdentity.storeId, entityKind: .product, operation: .update,
                    origin: .manualCatalogSave, logicalKey: "ri08:post-publication"))
                try context.save()
            }
            XCTAssertEqual(proof.stateStore.state.phase, .recoveryRequired, mutation)
            XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt, mutation)
        }
    }

    func testOrdinaryContinuationPublisherAllowsObserverReadAndRejectsObserverInvalidation() async throws {
        for mutation in ["read", "invalidate", "genuineRecovery"] {
            let proof = try await makeRealContinuationProof(eventID: 42)
            var observations = 0
            let observation = proof.stateStore.objectWillChange.sink {
                observations += 1
                _ = proof.stateStore.state.phase
                if mutation == "invalidate" { Task126OwnerStoreGate.invalidateAutomaticScopeLease() }
                if mutation == "genuineRecovery", observations == 1 { proof.stateStore.updatePhase(.recoveryRequired) }
            }
            proof.stateStore.recordRunResult(proof.result)
            XCTAssertGreaterThan(observations, 0)
            XCTAssertEqual(proof.stateStore.state.phase, mutation == "read" ? .idle : .recoveryRequired)
            XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt)
            observation.cancel()
        }
    }

    func testStableNoEventsRequiresFreshCountsAndStableTail() async throws {
        for mutation in ["countDrift", "tailAppeared"] {
            let proof = try await makeRealContinuationProof(expectReceipt: false, configure: { remote, fixture, productID in
                if mutation == "countDrift" {
                    remote.reconciliationCountsOverride = .init(products: 2, suppliers: 0, categories: 0,
                                                                productPrices: 0, historySessions: 0)
                } else {
                    remote.eventToPublishAfterCounts = try self.ordinaryContinuationEvent(
                        fixture: fixture, productID: productID, id: 42)
                }
            })
            XCTAssertEqual(proof.result.status, .recoveryRequired, mutation)
            XCTAssertNil(proof.result.continuationReceipt, mutation)
            XCTAssertEqual(proof.remote.reconciliationFetchCallCount, 1)
            XCTAssertEqual(ordinaryWatermark(fixture: proof.fixture), 41)
            XCTAssertEqual(try ordinaryStock(fixture: proof.fixture, productID: proof.productID), 0)
            XCTAssertEqual(proof.remote.catalogFetchCallCount, 0)
            if mutation == "tailAppeared" {
                XCTAssertEqual(proof.remote.eventReads.last?.afterID, 41)
                XCTAssertEqual(proof.remote.eventReads.last?.returnedCount, 1)
            }
        }
    }

    func testStableNoEventsAlwaysRefreshesCountsWithoutTargetedCatalogLookup() async throws {
        let proof = try await makeRealContinuationProof()
        proof.stateStore.recordRunResult(proof.result)
        XCTAssertEqual(proof.stateStore.state.phase, .idle)
        XCTAssertEqual(proof.remote.reconciliationFetchCallCount, 1)
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: proof.fixture.ownerUserID,
                                                                  defaults: proof.fixture.defaults)
        let second = await Task126OwnerStoreGate.withAutomaticScope(scope) {
            await proof.engine.run(action: .drainEvents, source: .foregroundPoll, ownerUserID: proof.fixture.ownerUserID)
        }
        XCTAssertEqual(second.status, .noWork)
        XCTAssertNotNil(second.continuationReceipt)
        XCTAssertFalse(second.verifiedConvergence)
        proof.stateStore.recordRunResult(second)
        XCTAssertEqual(proof.remote.reconciliationFetchCallCount, 2)
        XCTAssertEqual(proof.remote.catalogFetchCallCount, 0)
        XCTAssertEqual(proof.stateStore.state.phase, .idle)
        XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt)
    }

    func testOrdinaryContinuationRejectsModifiedSummaryAndIncompatibleFinalAggregate() async throws {
        for mutation in ["summaryCursor", "summaryEvents", "summaryMutation", "missingReceipt", "trailingPush", "genericNoOp"] {
            let action: SyncAction = mutation == "trailingPush" ? .sequence([.drainEvents, .pushPending])
                : (mutation == "genericNoOp" ? .noOp : .drainEvents)
            let proof = try await makeRealContinuationProof(eventID: 42, action: action, expectReceipt: false,
                transform: { original in
                    var summary = original
                    if mutation == "summaryCursor" { summary.watermarkAfter += 1 }
                    if mutation == "summaryEvents" { summary.eventsProcessed += 1 }
                    if mutation == "summaryMutation" { summary.productsUpdated += 1 }
                    if mutation == "missingReceipt" { summary.continuationReceipt = nil }
                    return summary
                })
            XCTAssertNil(proof.result.continuationReceipt, mutation)
            XCTAssertFalse(proof.result.verifiedConvergence)
            proof.stateStore.recordRunResult(proof.result)
            XCTAssertEqual(proof.stateStore.state.phase, .recoveryRequired, mutation)
            XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt, mutation)
        }
    }

    func testOrdinaryContinuationSupportsCompatibleMultipleRealDrains() async throws {
        let proof = try await makeRealContinuationProof(eventID: 42, action: .sequence([.drainEvents, .lightReconcile]))
        XCTAssertEqual(proof.result.status, .success)
        XCTAssertNotNil(proof.result.continuationReceipt)
        XCTAssertEqual(ordinaryWatermark(fixture: proof.fixture), 42)
        proof.stateStore.recordRunResult(proof.result)
        XCTAssertEqual(proof.stateStore.state.phase, .idle)
        XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt)
        XCTAssertEqual(proof.remote.reconciliationFetchCallCount, 1)
    }

    func testOrdinaryContinuationCancellationAfterActualCommitNeverPublishesReceipt() async throws {
        let proof = try await makeRealContinuationProof(eventID: 42, expectReceipt: false,
            afterAtomicMutation: { throw CancellationError() })
        XCTAssertEqual(proof.result.status, .cancelled)
        XCTAssertNil(proof.result.continuationReceipt)
        XCTAssertEqual(try ordinaryStock(fixture: proof.fixture, productID: proof.productID), 1)
        XCTAssertEqual(ordinaryWatermark(fixture: proof.fixture), 41)
        XCTAssertTrue(proof.remote.fenceAdvances.isEmpty)
    }

    func testOrdinaryContinuationRejectsReplacementContainerAndOtherDefaults() async throws {
        let proof = try await makeRealContinuationProof(eventID: 42)
        let oldContainer = proof.fixture.controller.modelContainer
        let product = ordinaryContinuationProduct(fixture: proof.fixture, id: proof.productID, stock: 2)
        let checkpoint = try makeCatalogPriceCheckpoint(fixture: proof.fixture, maxEventID: 43,
            seed: "ri08-replaced", products: [product], prices: [])
        let transport = AtomicRecoveryTestTransport(ownerUserID: proof.fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint], productRows: [product])
        _ = try await makeService(fixture: proof.fixture, transport: transport).recoverFromRemoteSnapshot(
            ownerUserID: proof.fixture.ownerUserID)
        XCTAssertFalse(proof.fixture.controller.modelContainer === oldContainer)
        proof.stateStore.recordRunResult(proof.result)
        XCTAssertEqual(proof.stateStore.state.phase, .recoveryRequired)
        let otherFixture = try makeFixture()
        let otherState = SyncStateStore(defaults: otherFixture.defaults, keyPrefix: "ri08.other-context")
        otherState.updatePhase(.checking)
        otherState.recordRunResult(proof.result)
        XCTAssertEqual(otherState.state.phase, .recoveryRequired)
    }

    func testOrdinarySelfEventContinuesAfterRealLocalPushAndOutboxAcknowledgement() async throws {
        let proof = try await makeRealContinuationProof()
        proof.stateStore.recordRunResult(proof.result)
        proof.remote.prepareProductForPush(ordinaryContinuationProduct(fixture: proof.fixture, id: proof.productID, stock: 0))
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: proof.fixture.controller.modelContainer,
            ownerUserID: proof.fixture.ownerUserID, defaults: proof.fixture.defaults) { context in
            let id = proof.productID
            let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>(predicate: #Predicate { $0.remoteID == id })).first)
            product.stockQuantity = 1
            try LocalPendingChangeAccumulator(context: context, ownerUserID: proof.fixture.ownerUserID,
                storeIdentity: proof.scope.storeIdentity).recordProductChange(
                    product: product, operation: .update, origin: .manualCatalogSave, changedFields: ["stockQuantity"])
            try context.save()
        }
        proof.stateStore.updatePhase(.pushing)
        let pushed = try await CatalogPushService(modelContainer: proof.fixture.controller.modelContainer,
            remote: proof.remote, defaults: proof.fixture.defaults).pushPendingCatalog(ownerUserID: proof.fixture.ownerUserID)
        XCTAssertEqual(pushed.productUpdates, 1)
        XCTAssertEqual(proof.remote.catalogPushCallCount, 1)
        let beforeRegistration = ModelContext(proof.fixture.controller.modelContainer)
        XCTAssertEqual(try beforeRegistration.fetch(FetchDescriptor<LocalPendingChange>()).first?.status, .acknowledged)
        XCTAssertEqual(try beforeRegistration.fetch(FetchDescriptor<SyncEventOutboxEntry>()).first?.status, .pending)
        let registered = try await SyncActivityRegistrationService(modelContainer: proof.fixture.controller.modelContainer,
            recorder: proof.remote, defaults: proof.fixture.defaults).registerSyncActivities(ownerUserID: proof.fixture.ownerUserID)
        XCTAssertEqual(registered.summary.registered, 1)
        XCTAssertEqual(proof.remote.recordRequests.count, 1)
        let ack = try XCTUnwrap(proof.remote.acknowledgedSelfEvent)
        XCTAssertEqual(ack.eventType, "catalog_changed")
        XCTAssertEqual(ack.sourceDeviceKey, ShopSyncRecoveryCanonical.sha256(proof.fixture.deviceInstallID))
        let afterRegistration = ModelContext(proof.fixture.controller.modelContainer)
        XCTAssertEqual(try afterRegistration.fetch(FetchDescriptor<SyncEventOutboxEntry>()).first?.status, .sent)
        proof.stateStore.updatePhase(.pullingEvents)
        let selfResult = await Task126OwnerStoreGate.withAutomaticScope(proof.scope) {
            await proof.engine.run(action: .drainEvents, source: .foregroundPoll, ownerUserID: proof.fixture.ownerUserID)
        }
        XCTAssertEqual(selfResult.status, .success)
        XCTAssertNotNil(selfResult.continuationReceipt)
        XCTAssertFalse(selfResult.verifiedConvergence)
        XCTAssertEqual(ordinaryWatermark(fixture: proof.fixture), 42)
        XCTAssertEqual(proof.remote.catalogFetchCallCount, 0, "Self ACK must never targeted-fetch its already applied row")
        proof.stateStore.recordRunResult(selfResult)
        XCTAssertEqual(proof.stateStore.state.phase, .idle)
        proof.remote.replace(event: try ordinaryContinuationEvent(fixture: proof.fixture, productID: proof.productID, id: 43),
                             product: ordinaryContinuationProduct(fixture: proof.fixture, id: proof.productID, stock: 2))
        proof.stateStore.updatePhase(.pullingEvents)
        let remoteResult = await Task126OwnerStoreGate.withAutomaticScope(proof.scope) {
            await proof.engine.run(action: .drainEvents, source: .remoteSyncEvent, ownerUserID: proof.fixture.ownerUserID)
        }
        XCTAssertEqual(remoteResult.status, .success)
        XCTAssertNotNil(remoteResult.continuationReceipt)
        proof.stateStore.recordRunResult(remoteResult)
        XCTAssertEqual(proof.stateStore.state.phase, .idle)
        XCTAssertEqual(try ordinaryStock(fixture: proof.fixture, productID: proof.productID), 2)
        XCTAssertEqual(ordinaryWatermark(fixture: proof.fixture), 43)
        let countReadsBeforeEmpty = proof.remote.reconciliationFetchCallCount
        let empty = await Task126OwnerStoreGate.withAutomaticScope(proof.scope) {
            await proof.engine.run(action: .drainEvents, source: .foregroundPoll, ownerUserID: proof.fixture.ownerUserID)
        }
        XCTAssertEqual(empty.status, .noWork)
        XCTAssertNotNil(empty.continuationReceipt)
        proof.stateStore.recordRunResult(empty)
        XCTAssertEqual(proof.stateStore.state.phase, .idle)
        XCTAssertEqual(proof.remote.reconciliationFetchCallCount, countReadsBeforeEmpty + 1)
        XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt)
        XCTAssertFalse(empty.verifiedConvergence)
    }

    func testKnownNoTargetNotificationContinuesButUnknownWireTypeHasNoReceipt() async throws {
        for eventType in ["catalog_changed", "catalog_updated", "unknown_type"] {
            let proof = try await makeRealContinuationProof()
            proof.stateStore.recordRunResult(proof.result)
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(
                try ordinaryContinuationEvent(fixture: proof.fixture, productID: proof.productID, id: 42))) as? [String: Any])
            object["event_type"] = eventType
            object["changed_count"] = 0
            object["entity_ids"] = [String: Any]()
            let event = try JSONDecoder().decode(RemoteSyncEventRow.self, from: JSONSerialization.data(withJSONObject: object))
            proof.remote.replace(event: event, product: ordinaryContinuationProduct(fixture: proof.fixture, id: proof.productID, stock: 0))
            let result = await Task126OwnerStoreGate.withAutomaticScope(proof.scope) {
                await proof.engine.run(action: .drainEvents, source: .remoteSyncEvent, ownerUserID: proof.fixture.ownerUserID)
            }
            XCTAssertEqual(result.status, .success, eventType)
            XCTAssertEqual(ordinaryWatermark(fixture: proof.fixture), 42)
            XCTAssertEqual(proof.remote.catalogFetchCallCount, 0)
            XCTAssertFalse(result.verifiedConvergence)
            if eventType == "catalog_changed" { XCTAssertNotNil(result.continuationReceipt) }
            else { XCTAssertNil(result.continuationReceipt) }
            proof.stateStore.recordRunResult(result)
            XCTAssertEqual(proof.stateStore.state.phase, eventType == "catalog_changed" ? .idle : .recoveryRequired)
            XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt)
        }
    }

    func testOrdinaryReceiptRejectedWhenOriginRunCancelledAfterRealProvider() async throws {
        let proof = try await makeRealContinuationProof(eventID: 42, expectReceipt: false, cancelAfterProvider: true)
        XCTAssertEqual(proof.result.status, .cancelled)
        XCTAssertNil(proof.result.continuationReceipt)
        XCTAssertEqual(ordinaryWatermark(fixture: proof.fixture), 42)
        XCTAssertEqual(try ordinaryStock(fixture: proof.fixture, productID: proof.productID), 1)
    }

    func testOrdinaryContinuationRequiresRegisteredCurrentContainer() async throws {
        let proof = try await makeRealContinuationProof()
        let unregistered = try SyncStoreSchema.makeInMemoryContainer()
        let pull = SyncEventIncrementalPullService(modelContainer: unregistered, remote: proof.remote,
            defaults: proof.fixture.defaults, storeGenerationController: proof.fixture.controller)
        let engine = AutomaticSyncEngine(catalogPushProvider: nil, productPriceProvider: nil,
            historySessionProvider: nil, incrementalPullProvider: pull,
            activityRegistrationProvider: nil, defaults: proof.fixture.defaults)
        let result = await Task126OwnerStoreGate.withAutomaticScope(proof.scope) {
            await engine.run(action: .drainEvents, source: .foregroundPoll, ownerUserID: proof.fixture.ownerUserID)
        }
        XCTAssertEqual(result.status, .failed)
        XCTAssertNil(result.continuationReceipt)
        XCTAssertEqual(proof.remote.reconciliationFetchCallCount, 1, "Unregistered must fail before any second count read")
        XCTAssertEqual(ordinaryWatermark(fixture: proof.fixture), 41)
    }

    func testOrdinaryContinuationRequiresFinalizationAndAuthoritativeGenerationBeforeIssuance() async throws {
        for mutation in ["unfinalized", "missingGeneration"] {
            let proof = try await makeRealContinuationProof(expectReceipt: false, configure: { _, fixture, _ in
                if mutation == "unfinalized" { try FileManager.default.removeItem(at: fixture.recoveryFinalizationURL) }
                else {
                    let scope = WatermarkStore.Scope(ownerUserID: fixture.ownerUserID,
                        storeIdentity: LocalStoreIdentity(rawValue: fixture.shopID.uuidString.lowercased()))
                    fixture.defaults.removeObject(forKey: WatermarkStore(defaults: fixture.defaults).key(for: scope) + ".generation")
                }
            })
            XCTAssertNil(proof.result.continuationReceipt, mutation)
            XCTAssertFalse(proof.result.verifiedConvergence)
            proof.stateStore.recordRunResult(proof.result)
            XCTAssertEqual(proof.stateStore.state.phase, .recoveryRequired, mutation)
            XCTAssertEqual(proof.stateStore.state.lastVerifiedAt, proof.verifiedAt, mutation)
        }
    }

    func testFinalizedReopenRejectsAdvancedCursorWithoutMatchingFence() async throws {
        for mutation in ["missing", "corrupt", "foreignScope"] {
            let proof = try await makeRealContinuationProof(eventID: 42)
            let fixture = proof.fixture
            let manifest = try XCTUnwrap(fixture.controller.activeManifest)
            let watermarkStore = WatermarkStore(defaults: fixture.defaults)
            XCTAssertEqual(proof.result.status, .success)
            XCTAssertEqual(manifest.checkpoint.maxEventID, 41)
            XCTAssertTrue(watermarkStore.matchesRecoveryGeneration(
                manifest.generationID, watermark: 42, scope: proof.watermarkScope))
            XCTAssertEqual(ShopSyncRecoveryFenceStore(defaults: fixture.defaults).scopeKey(
                accountHash: proof.scope.accountHash, storeIdentity: proof.scope.storeIdentity,
                deviceIdentityHash: proof.scope.deviceIdentityHash, watermark: 42), proof.checkpoint.scope.key)
            if mutation == "missing" {
                fixture.defaults.removeObject(forKey: proof.fenceDefaultsKey)
            } else if mutation == "corrupt" {
                fixture.defaults.set(Data("invalid".utf8), forKey: proof.fenceDefaultsKey)
            } else {
                let original = proof.checkpoint.scope
                let foreign = ShopSyncRecoveryScope(kind: original.kind, historyKind: original.historyKind,
                    key: String(repeating: "a", count: 64), legacyOwnerKey: original.legacyOwnerKey,
                    accountKey: original.accountKey, deviceKey: original.deviceKey)
                XCTAssertNotEqual(foreign.key, original.key)
                XCTAssertTrue(ShopSyncRecoveryFenceStore(defaults: fixture.defaults).saveAuthoritative(
                    scope: foreign, watermark: 42, accountHash: proof.scope.accountHash,
                    storeIdentity: proof.scope.storeIdentity, deviceIdentityHash: proof.scope.deviceIdentityHash))
            }
            XCTAssertThrowsError(try reopenFixture(fixture), mutation) { error in
                XCTAssertEqual(error as? SyncStoreGenerationError, .defaultsConfigurationMismatch, mutation)
            }
            XCTAssertEqual(ordinaryWatermark(fixture: fixture), 42, mutation)
            XCTAssertTrue(watermarkStore.matchesRecoveryGeneration(
                manifest.generationID, watermark: 42, scope: proof.watermarkScope), mutation)
            XCTAssertNotEqual(ShopSyncRecoveryFenceStore(defaults: fixture.defaults).scopeKey(
                accountHash: proof.scope.accountHash, storeIdentity: proof.scope.storeIdentity,
                deviceIdentityHash: proof.scope.deviceIdentityHash, watermark: 42), proof.checkpoint.scope.key)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recoveryFinalizationURL.path))
            XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        }
    }

    func testFinalizedZeroContinuationRejectsMissingOrCorruptTypedGeneration() async throws {
        for mutation in ["missing", "corrupt"] {
            let setup = try await makeReopenedEmptyZeroRecovery()
            let fixture = setup.fixture
            let controller = fixture.controller
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: fixture.ownerUserID, defaults: fixture.defaults)
            let lease = try XCTUnwrap(controller.captureLease(for: controller.modelContainer))
            let watermarkScope = WatermarkStore.Scope(
                accountHash: scope.accountHash, storeIdentity: scope.storeIdentity)
            let fenceStore = ShopSyncRecoveryFenceStore(defaults: fixture.defaults)
            let qualifiedKey = try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope, defaults: fixture.defaults) {
                    try Task126OwnerStoreGate.validateRegisteredActiveContainerWithLeaseHeld(controller.modelContainer)
                    try controller.validateLease(lease)
                    guard try controller.isActiveRecoveryFinalized(scope: scope) else {
                        throw SyncStoreGenerationError.invalidManifest
                    }
                    return fenceStore.continuationScopeKey(accountHash: scope.accountHash,
                        storeIdentity: scope.storeIdentity, deviceIdentityHash: scope.deviceIdentityHash,
                        watermark: 0, generationID: setup.generationID)
                }
            XCTAssertEqual(qualifiedKey, setup.checkpoint.scope.key)
            XCTAssertNil(fenceStore.scopeKey(accountHash: scope.accountHash,
                storeIdentity: scope.storeIdentity, deviceIdentityHash: scope.deviceIdentityHash, watermark: 0))
            let recordKey = WatermarkStore(defaults: fixture.defaults).key(for: watermarkScope) + ".generation"
            if mutation == "missing" { fixture.defaults.removeObject(forKey: recordKey) }
            else { fixture.defaults.set(Data("invalid".utf8), forKey: recordKey) }
            let rejectedKey = try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope, defaults: fixture.defaults) {
                    try Task126OwnerStoreGate.validateRegisteredActiveContainerWithLeaseHeld(controller.modelContainer)
                    try controller.validateLease(lease)
                    guard try controller.isActiveRecoveryFinalized(scope: scope) else {
                        throw SyncStoreGenerationError.invalidManifest
                    }
                    return fenceStore.continuationScopeKey(accountHash: scope.accountHash,
                        storeIdentity: scope.storeIdentity, deviceIdentityHash: scope.deviceIdentityHash,
                        watermark: 0, generationID: setup.generationID)
                }
            XCTAssertNil(rejectedKey, mutation)
            let remote = RI08ZeroIncrementalRemote(ownerUserID: fixture.ownerUserID, shopID: fixture.shopID,
                authoritativeScope: setup.checkpoint.scope, defaults: RI08Defaults(fixture.defaults))
            let pull = SyncEventIncrementalPullService(modelContainer: controller.modelContainer,
                remote: remote, defaults: fixture.defaults, storeGenerationController: controller)
            let engine = AutomaticSyncEngine(catalogPushProvider: nil, productPriceProvider: nil,
                historySessionProvider: nil, incrementalPullProvider: pull, activityRegistrationProvider: nil,
                defaults: fixture.defaults,
                runAdmissionValidator: { try await MainActor.run { try controller.validateLease(lease) } })
            let stateStore = SyncStateStore(defaults: fixture.defaults, keyPrefix: "ri08.zero")
            stateStore.updatePhase(.pullingEvents)
            let result = await Task126OwnerStoreGate.withAutomaticScope(scope) {
                await engine.run(action: .drainEvents, source: .foregroundPoll, ownerUserID: fixture.ownerUserID)
            }
            XCTAssertGreaterThan(remote.eventReads.count, 0, mutation)
            XCTAssertEqual(result.status, .noWork, mutation)
            XCTAssertNil(result.continuationReceipt, mutation)
            XCTAssertFalse(result.verifiedConvergence)
            stateStore.recordRunResult(result)
            XCTAssertEqual(stateStore.state.phase, .recoveryRequired, mutation)
            XCTAssertEqual(stateStore.state.lastVerifiedAt, setup.verifiedAt, mutation)
            XCTAssertEqual(ordinaryWatermark(fixture: fixture), 0)
            XCTAssertTrue(try controller.isActiveRecoveryFinalized(scope: scope))
            XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        }
    }

    func testVerifiedEmptyZeroDiskRecoveryAllowsOrdinaryNoEventsAfterFreshOpen() async throws {
        try await assertOrdinaryZeroContinuation(includeFirstCanonicalDelta: false)
    }

    func testVerifiedEmptyZeroDiskRecoveryAllowsFirstCanonicalDeltaAndNoEventsAfterFreshOpen() async throws {
        try await assertOrdinaryZeroContinuation(includeFirstCanonicalDelta: true)
    }

    private func assertOrdinaryZeroContinuation(includeFirstCanonicalDelta: Bool) async throws {
        let setup = try await makeReopenedEmptyZeroRecovery()
        let fixture = setup.fixture
        let stateStore = SyncStateStore(defaults: fixture.defaults, keyPrefix: "ri08.zero")
        XCTAssertEqual(stateStore.state.phase, .idle)
        XCTAssertEqual(stateStore.state.lastVerifiedAt, setup.verifiedAt)
        let auth = try RI08SyntheticAuth(ownerUserID: fixture.ownerUserID)
        defer { auth.close() }
        XCTAssertTrue(auth.viewModel.isSignedIn)
        let remote = RI08ZeroIncrementalRemote(ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID, authoritativeScope: setup.checkpoint.scope,
            defaults: RI08Defaults(fixture.defaults))
        // This decoder reads only the synthetic fence actually written by recovery.
        // It isolates domain/state continuation from the production V6 scopeKey(0) guard.
        try remote.validateActualRecoveryFence()
        let lease = try XCTUnwrap(fixture.controller.captureLease(for: fixture.controller.modelContainer))
        let controller = fixture.controller
        let facade = AutomaticSyncRuntimeFacade(authViewModel: auth.viewModel,
            catalogPushProvider: nil, productPriceProvider: nil, historySessionProvider: nil,
            incrementalPullProvider: SyncEventIncrementalPullService(
                modelContainer: controller.modelContainer, remote: remote, defaults: fixture.defaults,
                storeGenerationController: controller),
            activityRegistrationProvider: nil, deviceAuthorization: remote, defaults: fixture.defaults,
            runAdmissionValidator: { try await MainActor.run { try controller.validateLease(lease) } })
        let runtime = RI08ObservedRealRuntime(facade: facade)
        let orchestrator = makeOrdinaryOrchestrator(fixture: fixture, auth: auth,
            runtime: runtime, stateStore: stateStore)
        defer { orchestrator.stop() }
        do {
            let productID = try XCTUnwrap(UUID(uuidString: "56565656-5656-4565-8565-565656565656"))
            if includeFirstCanonicalDelta {
                remote.replace(event: try ordinaryContinuationEvent(fixture: fixture, productID: productID, id: 1),
                    product: ordinaryContinuationProduct(fixture: fixture, id: productID, stock: 1))
                let completed = expectation(description: "First canonical event after reopened verified zero")
                runtime.expectedCompletions.append(completed)
                orchestrator.submitForegroundTrigger(source: .remoteSyncEvent, forceIncremental: true)
                await fulfillment(of: [completed], timeout: 5)
                let published = await awaitOrdinaryTerminalPublication(stateStore)
                try recordZeroActualStage("first-canonical-delta-1", fixture: fixture,
                    stateStore: stateStore, runtime: runtime, remote: remote)
                XCTAssertTrue(published, ordinaryObservedEvidence(stateStore, runtime: runtime))
                XCTAssertEqual(runtime.results.count, 1)
                let actual = try XCTUnwrap(runtime.results.last)
                XCTAssertEqual(actual.status, .success, ordinaryObservedEvidence(stateStore, runtime: runtime))
                XCTAssertTrue(actual.didWork)
                XCTAssertFalse(actual.verifiedConvergence)
                XCTAssertEqual(try ordinaryStock(fixture: fixture, productID: productID), 1)
                XCTAssertEqual(ordinaryWatermark(fixture: fixture), 1)
                XCTAssertEqual(remote.fenceAdvances.map(\.from), [0])
                XCTAssertEqual(remote.fenceAdvances.map(\.through), [1])
                XCTAssertEqual(stateStore.state.phase, .idle,
                    "A genuine finalized zero generation must admit the first canonical delta")
                XCTAssertEqual(stateStore.state.lastVerifiedAt, setup.verifiedAt)
                XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
            }
            let watermarkBefore = includeFirstCanonicalDelta ? Int64(1) : Int64(0)
            let runsBefore = runtime.results.count
            let countsBefore = remote.reconciliationFetchCallCount
            let targetedBefore = remote.catalogFetchCallCount
            let eventReadsBefore = remote.eventReads.count
            let completed = expectation(description: "Ordinary empty poll after actual zero recovery")
            runtime.expectedCompletions.append(completed)
            orchestrator.submitForegroundTrigger(source: .foregroundPoll, forceIncremental: true)
            await fulfillment(of: [completed], timeout: 2)
            let published = await awaitOrdinaryTerminalPublication(stateStore)
            try recordZeroActualStage(includeFirstCanonicalDelta ? "empty-after-first-1" : "initial-empty-0",
                fixture: fixture, stateStore: stateStore, runtime: runtime, remote: remote)
            XCTAssertTrue(published, ordinaryObservedEvidence(stateStore, runtime: runtime))
            XCTAssertEqual(runtime.results.count, runsBefore + 1,
                "The ordinary trigger must enter the real runtime without Retry or full recovery")
            let actual = try XCTUnwrap(runtime.results.dropFirst(runsBefore).first,
                "ZERO_ORDINARY_SUPPRESSED: " + ordinaryObservedEvidence(stateStore, runtime: runtime))
            XCTAssertEqual(actual.status, .noWork, ordinaryObservedEvidence(stateStore, runtime: runtime))
            XCTAssertFalse(actual.didWork)
            XCTAssertFalse(actual.verifiedConvergence)
            XCTAssertGreaterThan(remote.reconciliationFetchCallCount, countsBefore,
                "The stable-empty authority must use a fresh existing count request")
            XCTAssertGreaterThanOrEqual(remote.eventReads.count - eventReadsBefore, 2,
                "The real empty read must be followed by the bounded stability tail")
            XCTAssertEqual(remote.eventReads.last?.afterID, watermarkBefore)
            XCTAssertEqual(remote.eventReads.last?.returnedCount, 0)
            XCTAssertEqual(remote.catalogFetchCallCount, targetedBefore)
            if !includeFirstCanonicalDelta { XCTAssertEqual(targetedBefore, 0) }
            XCTAssertEqual(ordinaryWatermark(fixture: fixture), watermarkBefore)
            XCTAssertEqual(stateStore.state.phase, .idle)
            XCTAssertEqual(stateStore.state.lastVerifiedAt, setup.verifiedAt)
            XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
            XCTAssertEqual(AccountBindingStore(defaults: fixture.defaults).currentBinding, setup.binding)
            XCTAssertEqual(controller.activeManifest?.generationID, setup.generationID)
            XCTAssertTrue(runtime.results.allSatisfy { !$0.verifiedConvergence })
            XCTAssertFalse(runtime.actions.contains(where: { $0.containsFullRecovery }))
            XCTAssertFalse(runtime.sources.contains(.releaseCard))
            XCTAssertEqual(auth.networkBlocker.requestCount, 0)
            let context = ModelContext(controller.modelContainer)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), includeFirstCanonicalDelta ? 1 : 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocalPendingChange>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()), 0)
            orchestrator.stop()
            await runtime.cancelAndWait()
            await runtime.resumeAfterStoreReplacement()
        } catch {
            orchestrator.stop()
            await runtime.cancelAndWait()
            await runtime.resumeAfterStoreReplacement()
            throw error
        }
    }

    private func makeReopenedEmptyZeroRecovery() async throws -> (
        fixture: AtomicRecoveryFixture, checkpoint: ShopSyncRecoveryCheckpoint,
        generationID: UUID, binding: AccountBinding, verifiedAt: Date
    ) {
        var oldFixture: AtomicRecoveryFixture? = try makeFixture()
        let metadata: (defaults: UserDefaults, suiteName: String, root: URL,
            ownerUserID: UUID, shopID: UUID, deviceInstallID: String)
        let checkpoint: ShopSyncRecoveryCheckpoint
        let generationID: UUID
        let binding: AccountBinding
        let verifiedAt: Date
        do {
            let original = try XCTUnwrap(oldFixture)
            metadata = (original.defaults, original.suiteName, original.temporaryRoot,
                original.ownerUserID, original.shopID, original.deviceInstallID)
            checkpoint = makeCheckpoint(fixture: original, maxEventID: 0, seed: "ri08-empty-zero")
            let transport = AtomicRecoveryTestTransport(ownerUserID: original.ownerUserID,
                checkpoints: [checkpoint, checkpoint, checkpoint])
            let engine = AutomaticSyncEngine(catalogPushProvider: nil, productPriceProvider: nil,
                historySessionProvider: nil, incrementalPullProvider: nil,
                recoverySnapshotPullProvider: makeService(fixture: original, transport: transport),
                activityRegistrationProvider: nil, defaults: original.defaults)
            let actual = await engine.run(action: .bootstrap, source: .rootForeground,
                ownerUserID: original.ownerUserID)
            let recoveryEvidence: [String: Any] = [
                "stage": "real-empty-zero-recovery-before-continuation",
                "runtimeStatus": actual.status.rawValue, "runtimeErrorCode": actual.errorCode ?? "none",
                "verifiedConvergence": actual.verifiedConvergence,
                "canonicalCheckpointAMaxID": checkpoint.syncEvents.maxId,
                "checkpointTransportCalls": transport.counts().checkpoints,
                "domainPageTransportCalls": transport.counts().pages,
                "tailTransportCalls": transport.counts().tailPages,
                "firstRequestBaselineID": transport.checkpointCallsForTesting().first?.verifiedBaselineID ?? "none",
                "firstRequestScopeKeyAbsent": transport.checkpointCallsForTesting().first?.expectedBaselineScopeKey == nil,
                "activatedGeneration": original.controller.activeManifest != nil,
                "finalizationPresent": FileManager.default.fileExists(atPath: original.recoveryFinalizationURL.path),
                "pendingRecoveryJournal": AccountBindingStore(defaults: original.defaults).pendingRecoveryJournal != nil
            ]
            print("RI08_ZERO_RECOVERY_ACTUAL " + String(decoding: try JSONSerialization.data(
                withJSONObject: recoveryEvidence, options: [.sortedKeys]), as: UTF8.self))
            XCTAssertEqual(actual.status, .success,
                "The real empty0 recovery must activate before continuation; checkpointB0/key failure is a separate recovery RED")
            XCTAssertTrue(actual.verifiedConvergence,
                "Empty0 recovery must produce its actual full canonical proof")
            _ = try XCTUnwrap(actual.status == .success && actual.verifiedConvergence ? true : nil,
                "ZERO_RECOVERY_NOT_ACTIVATED_CONTINUATION_NOT_REACHED")
            generationID = try XCTUnwrap(original.controller.activeManifest?.generationID)
            binding = try XCTUnwrap(AccountBindingStore(defaults: original.defaults).currentBinding)
            let store = SyncStateStore(defaults: original.defaults, keyPrefix: "ri08.zero")
            store.recordRunResult(actual,
                now: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down)))
            verifiedAt = try XCTUnwrap(store.state.lastVerifiedAt)
            try assertZeroRecoveryAuthority(original, generationID: generationID, stage: "activated-zero")
            XCTAssertEqual(transport.counts().checkpoints, 2)
            XCTAssertEqual(transport.counts().pages, ShopSyncRecoveryDomain.allCases.count)
        }
        // No recovery engine, service, context, state store or old controller is retained.
        oldFixture = nil
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: metadata.root.appendingPathComponent("generation-root", isDirectory: true),
            legacyDefaultStoreURL: metadata.root.appendingPathComponent("legacy-default.store"),
            defaults: metadata.defaults)
        let controller = try SyncStoreGenerationController(repository: repository, defaults: metadata.defaults)
        let reopened = AtomicRecoveryFixture(controller: controller, defaults: metadata.defaults,
            suiteName: metadata.suiteName, temporaryRoot: metadata.root,
            recoveryJournalURL: repository.recoveryJournalURL,
            recoveryFinalizationURL: repository.recoveryFinalizationURL,
            ownerUserID: metadata.ownerUserID, shopID: metadata.shopID,
            deviceInstallID: metadata.deviceInstallID)
        XCTAssertEqual(controller.activeManifest?.generationID, generationID)
        XCTAssertEqual(AccountBindingStore(defaults: reopened.defaults).currentBinding, binding)
        try assertZeroRecoveryAuthority(reopened, generationID: generationID, stage: "reopened-zero")
        XCTAssertEqual(SyncStateStore(defaults: reopened.defaults, keyPrefix: "ri08.zero").state.lastVerifiedAt, verifiedAt)
        return (reopened, checkpoint, generationID, binding, verifiedAt)
    }

    private func assertZeroRecoveryAuthority(
        _ fixture: AtomicRecoveryFixture, generationID: UUID, stage: String
    ) throws {
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: fixture.ownerUserID,
            defaults: fixture.defaults)
        let manifest = try XCTUnwrap(fixture.controller.activeManifest, "ZERO_SETUP_MISSING_MANIFEST")
        let manifestWatermark = try XCTUnwrap(manifest.checkpoint.maxEventID, "ZERO_SETUP_MISSING_CHECKPOINT_CURSOR")
        let finalized = try fixture.controller.isActiveRecoveryFinalized(scope: scope)
        let typedZero = WatermarkStore(defaults: fixture.defaults).matchesRecoveryGeneration(
            generationID, watermark: 0, scope: .init(ownerUserID: fixture.ownerUserID, storeIdentity: scope.storeIdentity))
        let counts = try LocalDatabasePublicSummary.makeReconciliationAware(context: ModelContext(fixture.controller.modelContainer))
        let noJournal = AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal == nil
            && !FileManager.default.fileExists(atPath: fixture.recoveryJournalURL.path)
        let baseline = ModelContext(fixture.controller.modelContainer)
        let baselineCount = try baseline.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRun>())
        let actual: [String: Any] = ["stage": stage, "finalized": finalized, "typedZeroRecord": typedZero,
            "scalarWatermark": ordinaryWatermark(fixture: fixture), "manifestWatermark": manifestWatermark,
            "pendingRecoveryJournal": !noJournal, "products": counts.products, "suppliers": counts.suppliers,
            "categories": counts.categories, "productPrices": counts.productPrices,
            "historySessions": counts.historySessions, "baselineRuns": baselineCount]
        print("RI08_ZERO_SETUP " + String(decoding: try JSONSerialization.data(withJSONObject: actual,
            options: [.sortedKeys]), as: UTF8.self))
        XCTAssertEqual(manifest.generationID, generationID)
        XCTAssertEqual(manifest.checkpoint.maxEventID, 0)
        XCTAssertTrue(finalized)
        XCTAssertTrue(typedZero)
        XCTAssertEqual(ordinaryWatermark(fixture: fixture), 0)
        XCTAssertTrue(noJournal)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recoveryFinalizationURL.path))
        XCTAssertEqual(counts, .init(products: 0, suppliers: 0, categories: 0, productPrices: 0, historySessions: 0))
        XCTAssertGreaterThan(baselineCount, 0)
        _ = try XCTUnwrap(finalized && typedZero && noJournal && manifest.checkpoint.maxEventID == 0
            && counts == .init(products: 0, suppliers: 0, categories: 0, productPrices: 0, historySessions: 0)
            && baselineCount > 0 ? true : nil, "ZERO_SETUP_NOT_FUNCTIONAL_RED")
    }

    private func recordZeroActualStage(
        _ stage: String, fixture: AtomicRecoveryFixture, stateStore: SyncStateStore,
        runtime: RI08ObservedRealRuntime, remote: RI08ZeroIncrementalRemote
    ) throws {
        let counts = try LocalDatabasePublicSummary.makeReconciliationAware(context: ModelContext(fixture.controller.modelContainer))
        let actual: [String: Any] = ["stage": stage, "runtimeResultCount": runtime.results.count,
            "latestRuntimeStatus": runtime.results.last?.status.rawValue ?? "none",
            "latestRuntimeErrorCode": runtime.results.last?.errorCode ?? "none",
            "latestRuntimeVerifiedConvergence": runtime.results.last.map { $0.verifiedConvergence as Any } ?? NSNull(),
            "actualContinuationReceipt": runtime.results.last?.continuationReceipt != nil,
            "statePhase": String(describing: stateStore.state.phase), "products": counts.products,
            "watermark": ordinaryWatermark(fixture: fixture), "eventReads": remote.eventReads.count,
            "catalogTargetedFetchCalls": remote.catalogFetchCallCount,
            "freshReconciliationCalls": remote.reconciliationFetchCallCount,
            "pendingRecoveryJournal": AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal != nil,
            "lastVerifiedAt": stateStore.state.lastVerifiedAt.map { $0.timeIntervalSince1970 as Any } ?? NSNull()]
        print("RI08_ZERO_ACTUAL " + String(decoding: try JSONSerialization.data(withJSONObject: actual,
            options: [.sortedKeys]), as: UTF8.self))
    }

    private func makeRealContinuationProof(
        eventID: Int64? = nil, action: SyncAction = .drainEvents, expectReceipt: Bool = true,
        cancelAfterProvider: Bool = false,
        configure: ((RI08OrdinaryIncrementalRemote, AtomicRecoveryFixture, UUID) throws -> Void)? = nil,
        transform: ((SyncIncrementalPullSummary) -> SyncIncrementalPullSummary)? = nil,
        afterAtomicMutation: (@Sendable () async throws -> Void)? = nil
    ) async throws -> RI08RealContinuationProof {
        let fixture = try makeFixture()
        let productID = try XCTUnwrap(UUID(uuidString: "45454545-4545-4545-8545-454545454545"))
        let baseline = ordinaryContinuationProduct(fixture: fixture, id: productID, stock: 0)
        let checkpoint = try makeCatalogPriceCheckpoint(fixture: fixture, maxEventID: 41,
            seed: "ri08-real-receipt", products: [baseline], prices: [])
        let recoveryTransport = AtomicRecoveryTestTransport(ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint], productRows: [baseline])
        let recoveryEngine = AutomaticSyncEngine(catalogPushProvider: nil, productPriceProvider: nil,
            historySessionProvider: nil, incrementalPullProvider: nil,
            recoverySnapshotPullProvider: makeService(fixture: fixture, transport: recoveryTransport),
            activityRegistrationProvider: nil, defaults: fixture.defaults)
        let recovered = await recoveryEngine.run(action: .bootstrap, source: .rootForeground,
                                                 ownerUserID: fixture.ownerUserID)
        XCTAssertEqual(recovered.status, .success)
        XCTAssertTrue(recovered.verifiedConvergence)
        let stateStore = SyncStateStore(defaults: fixture.defaults, keyPrefix: "ri08.real-receipt")
        stateStore.recordRunResult(recovered)
        let verifiedAt = try XCTUnwrap(stateStore.state.lastVerifiedAt)
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: fixture.ownerUserID, defaults: fixture.defaults)
        let remote = RI08OrdinaryIncrementalRemote(ownerUserID: fixture.ownerUserID, shopID: fixture.shopID,
            authoritativeScope: checkpoint.scope, defaults: RI08Defaults(fixture.defaults))
        if let eventID {
            remote.replace(event: try ordinaryContinuationEvent(fixture: fixture, productID: productID, id: eventID),
                           product: ordinaryContinuationProduct(fixture: fixture, id: productID, stock: 1))
        }
        try configure?(remote, fixture, productID)
        let pull = SyncEventIncrementalPullService(modelContainer: fixture.controller.modelContainer,
            remote: remote, defaults: fixture.defaults, storeGenerationController: fixture.controller,
            domainApplyServiceFactory: { remote, defaults in
                SyncEventIncrementalDomainApplyService(eventFetcher: remote, remote: remote, defaults: defaults,
                                                       afterAtomicMutationForTesting: afterAtomicMutation)
            })
        let policy = AutomaticSyncCancellationPolicy()
        let provider: any SyncIncrementalPullProviding
        if transform != nil || cancelAfterProvider {
            provider = RI08TransformingRealPullProvider(pull: pull, transform: transform ?? { $0 },
                                                       cancelAfterProvider: cancelAfterProvider ? policy : nil)
        } else { provider = pull }
        let controller = fixture.controller
        let lease = try XCTUnwrap(controller.captureLease(for: controller.modelContainer))
        let engine = AutomaticSyncEngine(catalogPushProvider: nil, productPriceProvider: nil,
            historySessionProvider: nil, incrementalPullProvider: provider,
            activityRegistrationProvider: nil, defaults: fixture.defaults, cancellationPolicy: policy,
            runAdmissionValidator: { try await MainActor.run { try controller.validateLease(lease) } })
        stateStore.updatePhase(.pullingEvents)
        let result = await Task126OwnerStoreGate.withAutomaticScope(scope) {
            await engine.run(action: action, source: .foregroundPoll, ownerUserID: fixture.ownerUserID)
        }
        if expectReceipt {
            XCTAssertNotNil(result.continuationReceipt, "The control must mint actual domain + engine authority")
            XCTAssertFalse(result.verifiedConvergence)
        }
        return RI08RealContinuationProof(fixture: fixture, checkpoint: checkpoint, productID: productID,
            scope: scope, stateStore: stateStore, verifiedAt: verifiedAt, remote: remote, engine: engine,
            policy: policy, result: result)
    }

    private func assertOrdinaryAutomaticContinuation(
        reopenBeforeSecondEvent: Bool, includeNoEventsAndThirdDelta: Bool = false
    ) async throws {
        var fixture = try makeFixture()
        let productID = try XCTUnwrap(UUID(uuidString: "45454545-4545-4545-8545-454545454545"))
        let baselineProduct = ordinaryContinuationProduct(fixture: fixture, id: productID, stock: 0)
        let checkpoint = try makeCatalogPriceCheckpoint(
            fixture: fixture, maxEventID: 41, seed: "ri08-ordinary-baseline",
            products: [baselineProduct], prices: []
        )
        let recoveryTransport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint],
            productRows: [baselineProduct]
        )
        let recoveryEngine = AutomaticSyncEngine(
            catalogPushProvider: nil, productPriceProvider: nil,
            historySessionProvider: nil, incrementalPullProvider: nil,
            recoverySnapshotPullProvider: makeService(fixture: fixture, transport: recoveryTransport),
            activityRegistrationProvider: nil, defaults: fixture.defaults
        )
        let verifiedRecovery = await recoveryEngine.run(
            action: .bootstrap, source: .rootForeground, ownerUserID: fixture.ownerUserID
        )
        XCTAssertEqual(verifiedRecovery.status, .success)
        XCTAssertTrue(verifiedRecovery.verifiedConvergence)
        let generationID = try XCTUnwrap(fixture.controller.activeManifest?.generationID)
        let recoveredBinding = try XCTUnwrap(AccountBindingStore(defaults: fixture.defaults).currentBinding)
        XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.recoveryFinalizationURL.path))
        let statePrefix = "ri08.ordinary"
        var stateStore = SyncStateStore(defaults: fixture.defaults, keyPrefix: statePrefix)
        stateStore.recordRunResult(verifiedRecovery,
            now: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down)))
        let verifiedAt = try XCTUnwrap(stateStore.state.lastVerifiedAt)
        let recoveryCountsBeforeEvents = recoveryTransport.counts()
        let auth = try RI08SyntheticAuth(ownerUserID: fixture.ownerUserID)
        defer { auth.close() }
        XCTAssertTrue(auth.viewModel.isSignedIn)
        XCTAssertEqual(auth.viewModel.sessionInfo?.userID, fixture.ownerUserID)
        let remote = RI08OrdinaryIncrementalRemote(
            ownerUserID: fixture.ownerUserID, shopID: fixture.shopID,
            authoritativeScope: checkpoint.scope, defaults: RI08Defaults(fixture.defaults)
        )
        let firstEvent = try ordinaryContinuationEvent(fixture: fixture, productID: productID, id: 42)
        let firstFinished = expectation(description: "First ordinary real runtime finished")
        var runtime = makeOrdinaryRuntime(fixture: fixture, auth: auth, remote: remote)
        var orchestrator = makeOrdinaryOrchestrator(
            fixture: fixture, auth: auth, runtime: runtime, stateStore: stateStore
        )
        // This covers the currently assigned instance before any await or throwing assertion.
        defer { orchestrator.stop() }
        do {
            if includeNoEventsAndThirdDelta {
                let initialEmptyFinished = expectation(description: "Initial real empty poll after verified recovery")
                runtime.expectedCompletions.append(initialEmptyFinished)
                let catalogReadsBeforeInitialPoll = remote.catalogFetchCallCount
                XCTAssertEqual(catalogReadsBeforeInitialPoll, 0)
                orchestrator.submitForegroundTrigger(source: .foregroundPoll, forceIncremental: true)
                await fulfillment(of: [initialEmptyFinished], timeout: 2)
                let initialStatePublished = await awaitOrdinaryTerminalPublication(stateStore)
                try recordOrdinaryActualStage("initial-empty-41", fixture: fixture,
                    productID: productID, stateStore: stateStore, runtime: runtime, remote: remote)
                XCTAssertTrue(initialStatePublished, ordinaryObservedEvidence(stateStore, runtime: runtime))
                XCTAssertEqual(runtime.results.count, 1)
                let initialResult = try XCTUnwrap(runtime.results.first)
                XCTAssertEqual(initialResult.status, .noWork,
                    "Stage initial-empty-41: \(ordinaryObservedEvidence(stateStore, runtime: runtime))")
                XCTAssertFalse(initialResult.didWork)
                XCTAssertFalse(initialResult.verifiedConvergence)
                XCTAssertEqual(remote.catalogFetchCallCount, 0)
                XCTAssertEqual(remote.catalogFetchCallCount, catalogReadsBeforeInitialPoll)
                XCTAssertEqual(remote.eventReads.last?.afterID, 41)
                XCTAssertEqual(remote.eventReads.last?.returnedCount, 0)
                XCTAssertEqual(try ordinaryStock(fixture: fixture, productID: productID), 0)
                XCTAssertEqual(ordinaryWatermark(fixture: fixture), 41)
                XCTAssertEqual(stateStore.state.phase, .idle,
                    "Stage initial-empty-41: \(ordinaryObservedEvidence(stateStore, runtime: runtime))")
                XCTAssertEqual(stateStore.state.lastVerifiedAt, verifiedAt)
                XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
                XCTAssertTrue(remote.fenceAdvances.isEmpty)
                XCTAssertEqual(fixture.controller.activeManifest?.generationID, generationID)
                let initialScope = try Task126OwnerStoreGate.captureAutomaticScope(
                    ownerUserID: fixture.ownerUserID, defaults: fixture.defaults)
                XCTAssertEqual(ShopSyncRecoveryFenceStore(defaults: fixture.defaults).scopeKey(
                    accountHash: initialScope.accountHash, storeIdentity: initialScope.storeIdentity,
                    deviceIdentityHash: initialScope.deviceIdentityHash, watermark: 41
                ), checkpoint.scope.key)
            }
            remote.replace(event: firstEvent,
                product: ordinaryContinuationProduct(fixture: fixture, id: productID, stock: 1))
            runtime.expectedCompletions.append(firstFinished)
            let runsBeforeFirst = runtime.results.count
            orchestrator.submitForegroundTrigger(source: .remoteSyncEvent, forceIncremental: true)
            await fulfillment(of: [firstFinished], timeout: 5)
            let firstStatePublished = await awaitOrdinaryTerminalPublication(stateStore)
            XCTAssertTrue(firstStatePublished,
                "First result state publication timed out: \(ordinaryObservedEvidence(stateStore, runtime: runtime))")
            try recordOrdinaryActualStage("first-delta-42", fixture: fixture,
                productID: productID, stateStore: stateStore, runtime: runtime, remote: remote)
            XCTAssertEqual(runtime.results.count, runsBeforeFirst + 1)
            let firstResult = try XCTUnwrap(runtime.results.dropFirst(runsBeforeFirst).first)
            XCTAssertEqual(firstResult.status, .success,
                ordinaryObservedEvidence(stateStore, runtime: runtime))
            XCTAssertTrue(firstResult.didWork)
            XCTAssertFalse(firstResult.verifiedConvergence)
            XCTAssertEqual(try ordinaryStock(fixture: fixture, productID: productID), 1)
            XCTAssertEqual(ordinaryWatermark(fixture: fixture), 42)
            XCTAssertEqual(stateStore.state.lastVerifiedAt, verifiedAt)
            XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
            XCTAssertEqual(stateStore.state.phase, .idle,
                "A valid ordinary continuation must stay automatically admissible without claiming a new full proof")
            if reopenBeforeSecondEvent {
                orchestrator.stop()
                await runtime.cancelAndWait()
                await runtime.resumeAfterStoreReplacement()
                try recordOrdinaryReopenMetadata("before-fresh-open", fixture: fixture)
                fixture = try reopenFixture(fixture)
                try recordOrdinaryReopenMetadata("after-fresh-open", fixture: fixture)
                stateStore = SyncStateStore(defaults: fixture.defaults, keyPrefix: statePrefix)
                XCTAssertEqual(stateStore.state.lastVerifiedAt, verifiedAt)
                XCTAssertEqual(fixture.controller.activeManifest?.generationID, generationID)
                runtime = makeOrdinaryRuntime(fixture: fixture, auth: auth, remote: remote)
                orchestrator = makeOrdinaryOrchestrator(
                    fixture: fixture, auth: auth, runtime: runtime, stateStore: stateStore
                )
            }
            let secondFinished = expectation(description: "Second ordinary real runtime finished without Retry")
            runtime.expectedCompletions.append(secondFinished)
            let resultsBeforeSecond = runtime.results.count
            let secondEvent = try ordinaryContinuationEvent(fixture: fixture, productID: productID, id: 43)
            remote.replace(event: secondEvent,
                product: ordinaryContinuationProduct(fixture: fixture, id: productID, stock: 2))
            orchestrator.submitForegroundTrigger(source: .remoteSyncEvent, forceIncremental: true)
            await fulfillment(of: [secondFinished], timeout: 2)
            let secondStatePublished = await awaitOrdinaryTerminalPublication(stateStore)
            XCTAssertTrue(secondStatePublished,
                "Second result state publication timed out: \(ordinaryObservedEvidence(stateStore, runtime: runtime))")
            try recordOrdinaryActualStage("second-delta-43", fixture: fixture,
                productID: productID, stateStore: stateStore, runtime: runtime, remote: remote)
            XCTAssertEqual(runtime.results.count, resultsBeforeSecond + 1,
                "The second automatic trigger must reach the real incremental runtime")
            XCTAssertEqual(runtime.results.last?.status, .success,
                ordinaryObservedEvidence(stateStore, runtime: runtime))
            XCTAssertEqual(runtime.results.last?.didWork, true)
            XCTAssertEqual(try ordinaryStock(fixture: fixture, productID: productID), 2)
            XCTAssertEqual(ordinaryWatermark(fixture: fixture), 43)
            XCTAssertEqual(stateStore.state.phase, .idle)
            XCTAssertEqual(stateStore.state.lastVerifiedAt, verifiedAt)
            XCTAssertTrue(runtime.results.allSatisfy { !$0.verifiedConvergence })
            XCTAssertFalse(runtime.actions.contains(where: { $0.containsFullRecovery }))
            XCTAssertFalse(runtime.sources.contains(.releaseCard))
            XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
            XCTAssertEqual(AccountBindingStore(defaults: fixture.defaults).currentBinding, recoveredBinding)
            XCTAssertEqual(fixture.controller.activeManifest?.generationID, generationID)
            XCTAssertEqual(recoveryTransport.counts().checkpoints, recoveryCountsBeforeEvents.checkpoints)
            XCTAssertEqual(recoveryTransport.counts().pages, recoveryCountsBeforeEvents.pages)
            let context = ModelContext(fixture.controller.modelContainer)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocalPendingChange>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()), 0)
            let advances = remote.fenceAdvances
            XCTAssertEqual(advances.map(\.from), [41, 42])
            XCTAssertEqual(advances.map(\.through), [42, 43])
            if includeNoEventsAndThirdDelta {
                let noEventsFinished = expectation(description: "Actual empty-event poll finished")
                runtime.expectedCompletions.append(noEventsFinished)
                let runsBeforePoll = runtime.results.count
                let eventReadsBeforePoll = remote.eventReads.count
                let catalogReadsBeforePoll = remote.catalogFetchCallCount
                orchestrator.submitForegroundTrigger(source: .foregroundPoll, forceIncremental: true)
                await fulfillment(of: [noEventsFinished], timeout: 2)
                let noEventsStatePublished = await awaitOrdinaryTerminalPublication(stateStore)
                try recordOrdinaryActualStage("current-empty-43", fixture: fixture,
                    productID: productID, stateStore: stateStore, runtime: runtime, remote: remote)
                XCTAssertTrue(noEventsStatePublished, ordinaryObservedEvidence(stateStore, runtime: runtime))
                XCTAssertEqual(runtime.results.count, runsBeforePoll + 1,
                    "The poll must enter the real runtime and empty event fetch")
                XCTAssertEqual(runtime.results.last?.status, .noWork,
                    ordinaryObservedEvidence(stateStore, runtime: runtime))
                XCTAssertEqual(runtime.results.last?.didWork, false)
                XCTAssertEqual(runtime.results.last?.verifiedConvergence, false)
                XCTAssertEqual(remote.catalogFetchCallCount, catalogReadsBeforePoll)
                XCTAssertGreaterThan(remote.eventReads.count, eventReadsBeforePoll)
                XCTAssertEqual(remote.eventReads.last?.afterID, 43)
                XCTAssertEqual(remote.eventReads.last?.returnedCount, 0)
                XCTAssertEqual(try ordinaryStock(fixture: fixture, productID: productID), 2)
                XCTAssertEqual(ordinaryWatermark(fixture: fixture), 43)
                XCTAssertEqual(stateStore.state.phase, .idle,
                    "An authenticated current-fence empty poll must retain continuation admission")
                XCTAssertEqual(stateStore.state.lastVerifiedAt, verifiedAt)
                XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
                XCTAssertEqual(remote.fenceAdvances.map(\.through), [42, 43])
                let currentScope = try Task126OwnerStoreGate.captureAutomaticScope(
                    ownerUserID: fixture.ownerUserID, defaults: fixture.defaults)
                XCTAssertEqual(ShopSyncRecoveryFenceStore(defaults: fixture.defaults).scopeKey(
                    accountHash: currentScope.accountHash, storeIdentity: currentScope.storeIdentity,
                    deviceIdentityHash: currentScope.deviceIdentityHash, watermark: 43
                ), checkpoint.scope.key)

                let thirdFinished = expectation(description: "Third delta after actual empty-event poll finished")
                runtime.expectedCompletions.append(thirdFinished)
                let runsBeforeThird = runtime.results.count
                remote.replace(event: try ordinaryContinuationEvent(
                    fixture: fixture, productID: productID, id: 44
                ), product: ordinaryContinuationProduct(fixture: fixture, id: productID, stock: 3))
                orchestrator.submitForegroundTrigger(source: .remoteSyncEvent, forceIncremental: true)
                await fulfillment(of: [thirdFinished], timeout: 2)
                let thirdStatePublished = await awaitOrdinaryTerminalPublication(stateStore)
                try recordOrdinaryActualStage("third-delta-44", fixture: fixture,
                    productID: productID, stateStore: stateStore, runtime: runtime, remote: remote)
                XCTAssertTrue(thirdStatePublished, ordinaryObservedEvidence(stateStore, runtime: runtime))
                XCTAssertEqual(runtime.results.count, runsBeforeThird + 1)
                XCTAssertEqual(runtime.results.last?.status, .success,
                    ordinaryObservedEvidence(stateStore, runtime: runtime))
                XCTAssertEqual(runtime.results.last?.didWork, true)
                XCTAssertEqual(try ordinaryStock(fixture: fixture, productID: productID), 3)
                XCTAssertEqual(ordinaryWatermark(fixture: fixture), 44)
                XCTAssertEqual(stateStore.state.phase, .idle)
                XCTAssertEqual(stateStore.state.lastVerifiedAt, verifiedAt)
                XCTAssertTrue(runtime.results.allSatisfy { !$0.verifiedConvergence })
                XCTAssertFalse(runtime.actions.contains(where: { $0.containsFullRecovery }))
                XCTAssertFalse(runtime.sources.contains(.releaseCard))
                XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
                XCTAssertEqual(AccountBindingStore(defaults: fixture.defaults).currentBinding, recoveredBinding)
                XCTAssertEqual(fixture.controller.activeManifest?.generationID, generationID)
                XCTAssertEqual(recoveryTransport.counts().checkpoints, recoveryCountsBeforeEvents.checkpoints)
                XCTAssertEqual(recoveryTransport.counts().pages, recoveryCountsBeforeEvents.pages)
                XCTAssertEqual(remote.fenceAdvances.map(\.from), [41, 42, 43])
                XCTAssertEqual(remote.fenceAdvances.map(\.through), [42, 43, 44])
                let finalContext = ModelContext(fixture.controller.modelContainer)
                XCTAssertEqual(try finalContext.fetchCount(FetchDescriptor<LocalPendingChange>()), 0)
                XCTAssertEqual(try finalContext.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()), 0)
            }
            XCTAssertEqual(auth.networkBlocker.requestCount, 0, "Synthetic SDK auth must not use network")
            orchestrator.stop()
            await runtime.cancelAndWait()
            await runtime.resumeAfterStoreReplacement()
        } catch {
            orchestrator.stop()
            await runtime.cancelAndWait()
            await runtime.resumeAfterStoreReplacement()
            throw error
        }
    }

    private func awaitOrdinaryTerminalPublication(_ store: SyncStateStore) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while true {
            switch store.state.phase {
            case .idle, .recoveryRequired, .failed, .blocked:
                return true
            case .checking, .pushing, .pullingEvents, .reconciling:
                break
            }
            guard clock.now < deadline, !Task.isCancelled else { return false }
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch {
                return false
            }
        }
    }

    private func ordinaryObservedEvidence(
        _ store: SyncStateStore, runtime: RI08ObservedRealRuntime
    ) -> String {
        let result = runtime.results.last
        return "phase=\(store.state.phase); outcome=\(String(describing: store.state.lastOutcome)); "
            + "runtimeStatus=\(result?.status.rawValue ?? "none"); errorCode=\(result?.errorCode ?? "none")"
    }

    private func recordOrdinaryActualStage(
        _ stage: String, fixture: AtomicRecoveryFixture, productID: UUID,
        stateStore: SyncStateStore, runtime: RI08ObservedRealRuntime,
        remote: RI08OrdinaryIncrementalRemote
    ) throws {
        let result = runtime.results.last
        let actual: [String: Any] = [
            "stage": stage, "runtimeResultCount": runtime.results.count,
            "catalogTargetedFetchCalls": remote.catalogFetchCallCount,
            "latestRuntimeStatus": result?.status.rawValue ?? "none",
            "latestRuntimeErrorCode": result?.errorCode ?? "none",
            "latestRuntimeVerifiedConvergence": result.map { $0.verifiedConvergence as Any } ?? NSNull(),
            "statePhase": String(describing: stateStore.state.phase),
            "stock": try ordinaryStock(fixture: fixture, productID: productID).map { $0 as Any } ?? NSNull(),
            "watermark": ordinaryWatermark(fixture: fixture),
            "lastVerifiedAt": stateStore.state.lastVerifiedAt.map { $0.timeIntervalSince1970 as Any } ?? NSNull(),
            "pendingRecoveryJournal": AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal != nil
        ]
        let data = try JSONSerialization.data(withJSONObject: actual, options: [.sortedKeys])
        print("RI08_ACTUAL " + String(decoding: data, as: UTF8.self))
    }

    private func recordOrdinaryReopenMetadata(
        _ stage: String, fixture: AtomicRecoveryFixture
    ) throws {
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: fixture.ownerUserID, defaults: fixture.defaults)
        guard let manifest = fixture.controller.activeManifest else {
            throw SyncStoreGenerationError.invalidManifest
        }
        let finalizationData = try Data(contentsOf: fixture.recoveryFinalizationURL)
        guard finalizationData.count <= 4_096 else {
            throw SyncStoreGenerationError.invalidManifest
        }
        let finalization = try JSONDecoder().decode(
            SyncStoreRecoveryFinalization.self, from: finalizationData)
        let watermarkScope = WatermarkStore.Scope(
            accountHash: scope.accountHash, storeIdentity: scope.storeIdentity)
        let watermarkStore = WatermarkStore(defaults: fixture.defaults)
        let scalar = (fixture.defaults.object(forKey: watermarkStore.key(for: watermarkScope)) as? Int)
            .flatMap { $0 >= 0 ? Int64($0) : nil }
        let current = watermarkStore.watermark(for: watermarkScope)
        let typedMirrorMatches = watermarkStore.matchesRecoveryGeneration(
            manifest.generationID, watermark: current, scope: watermarkScope)
        let fence = ordinaryStoredFenceWatermark(fixture: fixture, scope: scope,
            expectedScopeKey: manifest.checkpoint.scope.key)
        let currentScopeKey = ShopSyncRecoveryFenceStore(defaults: fixture.defaults).scopeKey(
            accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash, watermark: current)
        let binding = AccountBindingStore(defaults: fixture.defaults).currentBinding
        let actual: [String: Any] = [
            "stage": stage,
            "scalarWatermark": scalar.map { $0 as Any } ?? NSNull(),
            "typedWatermark": typedMirrorMatches ? current as Any : NSNull(),
            "typedGenerationRecordPresent": fixture.defaults.object(
                forKey: watermarkStore.key(for: watermarkScope) + ".generation") != nil,
            "generationAndWatermarkMirrorMatch": typedMirrorMatches,
            "manifestRecoveryWatermark": manifest.checkpoint.maxEventID.map { $0 as Any } ?? NSNull(),
            "finalizationRecoveryWatermark": finalization.watermark,
            "finalizationExactlyMatchesManifest": finalization.exactlyMatches(manifest),
            "activeRecoveryFinalized": try fixture.controller.isActiveRecoveryFinalized(scope: scope),
            "fenceStoredWatermark": fence.map { $0 as Any } ?? NSNull(),
            "fenceRecordValidated": fence != nil,
            "fenceMatchesCurrentWatermark": fence.map { ($0 == current) as Any } ?? NSNull(),
            "currentScopeKeyPresent": currentScopeKey != nil,
            "currentScopeKeyMatchesManifest": currentScopeKey == manifest.checkpoint.scope.key,
            "generationMatchesFinalization": manifest.generationID == finalization.generationID,
            "accountMatches": manifest.accountHash == scope.accountHash
                && binding?.accountHash == scope.accountHash,
            "storeMatches": manifest.storeIdentity == scope.storeIdentity
                && binding?.storeIdentity == scope.storeIdentity,
            "shopMatches": manifest.shopID == scope.shopID,
            "deviceMatches": manifest.deviceIdentityHash == scope.deviceIdentityHash,
            "pendingRecoveryJournal": AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal != nil
        ]
        print("RI08_REOPEN_METADATA " + String(decoding: try JSONSerialization.data(
            withJSONObject: actual, options: [.sortedKeys]), as: UTF8.self))
    }

    private func ordinaryStoredFenceWatermark(
        fixture: AtomicRecoveryFixture, scope: Task126VerifiedOwnerStoreScope,
        expectedScopeKey: String
    ) -> Int64? {
        // Read the actual saved record. Its stored cursor may validly differ
        // from the current cursor; that difference is the observation.
        let key = "sync.recovery.fence.account.\(scope.accountHash).store.\(scope.storeIdentity.rawValue)"
        guard let data = fixture.defaults.data(forKey: key), data.count <= 2_048,
              let record = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              record["schema"] == "shop-sync-recovery-fence-v1",
              record["scopeKey"] == expectedScopeKey,
              ShopSyncRecoveryCanonical.isRedactedKey(expectedScopeKey),
              record["accountKey"] == scope.accountHash,
              record["deviceKey"] == scope.deviceIdentityHash,
              let rawWatermark = record["watermark"],
              let watermark = try? ShopSyncRecoveryCanonical.eventID(rawWatermark),
              record["checksum"] == ShopSyncRecoveryCanonical.sha256([
                "shop-sync-recovery-fence-v1", expectedScopeKey, scope.accountHash,
                scope.storeIdentity.rawValue, scope.deviceIdentityHash, rawWatermark
              ].joined(separator: "|")) else { return nil }
        return watermark
    }

    private func ordinaryContinuationProduct(
        fixture: AtomicRecoveryFixture, id: UUID, stock: Double
    ) -> RemoteInventoryProductRow {
        RemoteInventoryProductRow(
            id: id, ownerUserID: fixture.ownerUserID, shopID: fixture.shopID,
            barcode: "RI08-ORDINARY-PRODUCT", itemNumber: "ri08", productName: "Ordinary fixture",
            secondProductName: nil, purchasePrice: nil, retailPrice: nil,
            supplierID: nil, categoryID: nil, stockQuantity: stock,
            updatedAt: stock == 0 ? "2026-07-21T12:00:00.000000Z"
                : (stock == 1 ? "2026-07-21T12:01:00.000000Z"
                    : (stock == 2 ? "2026-07-21T12:02:00.000000Z" : "2026-07-21T12:03:00.000000Z")),
            deletedAt: nil
        )
    }

    private func ordinaryContinuationEvent(
        fixture: AtomicRecoveryFixture, productID: UUID, id: Int64
    ) throws -> RemoteSyncEventRow {
        let payload: [String: Any] = [
            "id": String(id), "owner_user_id": fixture.ownerUserID.uuidString,
            "store_id": NSNull(), "shop_id": fixture.shopID.uuidString,
            "domain": "catalog", "event_type": "catalog_changed", "source": "test",
            "source_device_id": "ri08-other-synthetic-device", "batch_id": NSNull(),
            "client_event_id": "RI08-ordinary-\(id)", "changed_count": 1,
            "entity_ids": ["product_ids": [productID.uuidString]],
            "requires_full_recovery": false,
            "created_at": id == 44 ? "2026-07-21T12:03:00Z" : "2026-07-21T12:02:00Z",
            "expires_at": NSNull(), "metadata": [:]
        ]
        return try JSONDecoder().decode(RemoteSyncEventRow.self,
            from: JSONSerialization.data(withJSONObject: payload))
    }

    private func ordinaryStock(fixture: AtomicRecoveryFixture, productID: UUID) throws -> Double? {
        let context = ModelContext(fixture.controller.modelContainer)
        let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>(
            predicate: #Predicate { $0.remoteID == productID }
        )).first)
        return product.stockQuantity
    }

    private func ordinaryWatermark(fixture: AtomicRecoveryFixture) -> Int64 {
        WatermarkStore(defaults: fixture.defaults).watermark(for: .init(
            ownerUserID: fixture.ownerUserID,
            storeIdentity: LocalStoreIdentity(rawValue: fixture.shopID.uuidString.lowercased())
        ))
    }

    private func makeOrdinaryRuntime(
        fixture: AtomicRecoveryFixture, auth: RI08SyntheticAuth, remote: RI08OrdinaryIncrementalRemote
    ) -> RI08ObservedRealRuntime {
        let lease = fixture.controller.captureLease(for: fixture.controller.modelContainer)
        let controller = fixture.controller
        let facade = AutomaticSyncRuntimeFacade(
            authViewModel: auth.viewModel, catalogPushProvider: nil,
            productPriceProvider: nil, historySessionProvider: nil,
            incrementalPullProvider: SyncEventIncrementalPullService(
                modelContainer: fixture.controller.modelContainer, remote: remote, defaults: fixture.defaults,
                storeGenerationController: fixture.controller
            ),
            activityRegistrationProvider: nil, deviceAuthorization: remote, defaults: fixture.defaults,
            runAdmissionValidator: {
                guard let lease else { throw SyncStoreGenerationError.staleGenerationLease }
                try await MainActor.run { try controller.validateLease(lease) }
            }
        )
        return RI08ObservedRealRuntime(facade: facade)
    }

    private func makeOrdinaryOrchestrator(
        fixture: AtomicRecoveryFixture, auth: RI08SyntheticAuth,
        runtime: RI08ObservedRealRuntime, stateStore: SyncStateStore
    ) -> SyncOrchestrator {
        SyncOrchestrator(
            automaticRuntime: runtime, authViewModel: auth.viewModel,
            activityCenter: ForegroundCloudWorkflowActivityCenter(), syncEventSignalWatcher: nil,
            stateStore: stateStore,
            decisionInputProvider: SyncDecisionInputProvider(
                modelContainer: fixture.controller.modelContainer, initialNetworkStatus: .satisfied,
                bindingStore: AccountBindingStore(defaults: fixture.defaults),
                selectedShopStore: SelectedShopStore(defaults: fixture.defaults)
            ),
            backgroundScheduler: SyncNoopBackgroundTaskScheduler()
        )
    }

    func testCanonicalNumericPrefixProductsRecoverAcrossPersistedVerificationBatch() async throws {
        let fixture = try makeFixture()
        let ids = try canonicalNumericPrefixIDs()
        XCTAssertEqual(ids.count, ShopSyncRecoveryLimits.verificationBatchSize + 1)
        let products = ids.enumerated().map { index, id in
            RemoteInventoryProductRow(
                id: id,
                ownerUserID: fixture.ownerUserID,
                shopID: fixture.shopID,
                barcode: "TASK144-ORDER-\(index)",
                itemNumber: "order-\(index)",
                productName: "Order fixture \(index)",
                secondProductName: nil,
                purchasePrice: nil,
                retailPrice: nil,
                supplierID: nil,
                categoryID: nil,
                stockQuantity: nil,
                updatedAt: "2026-07-21T12:00:00.000000Z",
                deletedAt: nil
            )
        }
        let checkpoint = try makeCatalogPriceCheckpoint(
            fixture: fixture,
            maxEventID: 41,
            seed: "canonical-numeric-prefix-order",
            products: products,
            prices: []
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint],
            productRows: products
        )

        let summary = try await makeService(fixture: fixture, transport: transport)
            .recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)

        XCTAssertTrue(summary.completedRecoveryJournal)
        let manifest = try XCTUnwrap(fixture.controller.activeManifest)
        XCTAssertEqual(manifest.localVerification.products, checkpoint.catalog.products)
        XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        XCTAssertEqual(transport.counts().pages, 16) // Eleven product pages and five empty domains.
        let reopened = try reopenFixture(fixture)
        let context = ModelContext(reopened.controller.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), ids.count)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRecord>()), ids.count)
    }

    // Backend capability control: exercise the real disk store and enumeration
    // with an explicit canonical comparator, independently of the service.
    func testDiskBaselineLexicalComparatorPreservesAllCatalogTypesAcrossBatches() async throws {
        let fixture = try makeFixture()
        let ids = try canonicalNumericPrefixIDs()
        let runID = try XCTUnwrap(UUID(uuidString: "34343434-3434-4434-8434-343434343434"))
        let context = ModelContext(fixture.controller.modelContainer)
        context.autosaveEnabled = false
        for entityType in SupabaseCatalogBaselineEntityType.allCases {
            for (index, id) in ids.enumerated() {
                context.insert(SupabaseCatalogBaselineRecord(
                    baselineRunID: runID,
                    ownerUserUUID: fixture.ownerUserID,
                    entityType: entityType,
                    remoteID: id,
                    fingerprintCanonical: "canonical-\(index)"
                ))
            }
        }
        try context.save()
        let reopened = try reopenFixture(fixture)
        let readContext = ModelContext(reopened.controller.modelContainer)
        readContext.autosaveEnabled = false
        let descriptor = FetchDescriptor<SupabaseCatalogBaselineRecord>(
            predicate: #Predicate { $0.baselineRunID == runID },
            sortBy: [SortDescriptor(\SupabaseCatalogBaselineRecord.recordKey, comparator: .lexical)]
        )
        var actual: [String: [UUID]] = [:]
        try readContext.enumerate(descriptor, batchSize: ShopSyncRecoveryLimits.verificationBatchSize) { record in
            actual[record.entityType, default: []].append(record.remoteID)
        }
        XCTAssertEqual(actual.count, 3)
        for entityType in SupabaseCatalogBaselineEntityType.allCases {
            XCTAssertEqual(actual[entityType.rawValue], ids, entityType.rawValue)
        }
    }

    private func canonicalNumericPrefixIDs() throws -> [UUID] {
        let prefixes = (0..<255).map { String(format: "%08d", $0) }
            + ["12000000", "1a000000"]
        let ids = try prefixes.map {
            try XCTUnwrap(UUID(uuidString: "\($0)-0000-4000-8000-000000000001"))
        }
        let strings = ids.map { $0.uuidString.lowercased() }
        for index in 1..<strings.count {
            XCTAssertLessThan(strings[index - 1], strings[index])
        }
        return ids
    }

    func testShortMarkerDenialAfterBPreservesRecoveryWithoutActivationOrRetry() async throws {
        try await assertShortMarkerDenial(expectedCode: "convergence_marker_resource_exceeded")
    }

    func testOtherMarkerDenialsAfterBRemainExplicitAndBounded() async throws {
        for (status, code) in [
            ("invalid_baseline", "convergence_marker_invalid_baseline"),
            ("integrity_blocked", "convergence_marker_integrity_blocked"),
            ("unknown-status-with-private-detail", "convergence_marker_status_unsupported")
        ] {
            try await assertShortMarkerDenial(expectedCode: code) { $0["status"] = status }
        }
    }

    func testShortMarkerValidatesBaselineScopeBeforeReportingDenial() async throws {
        try await assertShortMarkerDenial(expectedCode: "invalidCheckpoint") { payload in
            var scope = payload["scope"] as! [String: Any]
            scope["key"] = String(repeating: "0", count: 64)
            payload["scope"] = scope
        }
    }

    func testReadyMarkerStillRequiresCompleteSuccessPayload() async throws {
        try await assertShortMarkerDenial(expectedCode: nil) { $0["status"] = "ready" }
    }

    private func assertShortMarkerDenial(
        expectedCode: String?,
        mutation: ((inout [String: Any]) -> Void)? = nil
    ) async throws {
        let fixture = try makeFixture()
        let checkpoint = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "marker-denial")
        let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/MOBILE-PARITY/mobile-parity-recovery-marker-resource-exceeded.json")
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any])
        payload["shopId"] = fixture.shopID.uuidString.lowercased()
        payload["scope"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint.scope))
        mutation?(&payload)
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint],
            rawMarker: try JSONSerialization.data(withJSONObject: payload)
        )
        let bindingStore = AccountBindingStore(defaults: fixture.defaults)
        let beforeBinding = bindingStore.currentBinding
        let originalContainer = fixture.controller.modelContainer
        do {
            _ = try await makeService(fixture: fixture, transport: transport)
                .recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("A refused or incomplete marker must never publish the staged generation")
        } catch {
            if let expectedCode {
                XCTAssertEqual(String(describing: error), expectedCode)
            } else {
                XCTAssertTrue(error is DecodingError)
            }
        }
        XCTAssertEqual(transport.counts().checkpoints, 2)
        XCTAssertEqual(transport.counts().pages, ShopSyncRecoveryDomain.allCases.count)
        XCTAssertEqual(transport.markerBaselineIDsForTesting(), ["41"])
        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertTrue(fixture.controller.modelContainer === originalContainer)
        XCTAssertEqual(bindingStore.currentBinding, beforeBinding)
        XCTAssertNotNil(bindingStore.pendingRecoveryJournal)
        XCTAssertNil(bindingStore.pendingRecoveryJournal?.watermark)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.recoveryFinalizationURL.path))
    }

    func testShortResourceExceededCheckpointPreservesJournalAndStopsRecoveryAttempt() async throws {
        try await assertShortCheckpointDenial(
            fixtureName: "mobile-parity-recovery-short-resource-exceeded",
            expectedCode: "checkpoint_resource_exceeded"
        )
    }

    func testShortInvalidBaselineCheckpointPreservesJournalAndStopsRecoveryAttempt() async throws {
        try await assertShortCheckpointDenial(
            fixtureName: "mobile-parity-recovery-short-invalid-baseline",
            expectedCode: "checkpoint_invalid_baseline"
        )
    }

    func testCheckpointIntegrityAndUnknownDenialsUseSafeCodesWithoutSuccessFields() async throws {
        for (status, code) in [
            ("integrity_blocked", "checkpoint_integrity_blocked"),
            ("unknown-status-with-private-detail", "checkpoint_status_unsupported")
        ] {
            try await assertShortCheckpointDenial(
                fixtureName: "mobile-parity-recovery-short-resource-exceeded",
                expectedCode: code,
                mutation: { $0["status"] = status }
            )
        }
    }

    func testCheckpointDenialValidatesScopeBeforeReportingServerStatus() async throws {
        for field in ["shopId", "schemaVersion", "accountKey", "deviceKey", "key"] {
            try await assertShortCheckpointDenial(
                fixtureName: "mobile-parity-recovery-short-resource-exceeded",
                expectedCode: field == "accountKey" ? "authenticationChanged" : "invalidCheckpoint",
                mutation: { payload in
                    if field == "shopId" { payload[field] = UUID().uuidString }
                    else if field == "schemaVersion" { payload[field] = "unsupported" }
                    else {
                        var scope = payload["scope"] as! [String: Any]
                        scope[field] = field == "key" ? "invalid" : String(repeating: "0", count: 64)
                        payload["scope"] = scope
                    }
                }
            )
        }
    }

    func testReadyCheckpointStillRequiresCompleteSuccessPayload() async throws {
        try await assertShortCheckpointDenial(
            fixtureName: "mobile-parity-recovery-short-resource-exceeded",
            expectedCode: nil,
            mutation: { $0["status"] = "ready" }
        )
    }

    func testCheckpointWithoutStatusCannotDefaultToReadyOrDenial() async throws {
        try await assertShortCheckpointDenial(
            fixtureName: "mobile-parity-recovery-short-resource-exceeded",
            expectedCode: nil,
            mutation: { $0.removeValue(forKey: "status") }
        )
    }

    func testCheckpointDenialCannotCrossTheExpectedBaselineScopeFence() async throws {
        let fixture = try makeFixture()
        let checkpoint = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "scope-fence")
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint],
            rawCheckpoint: try JSONSerialization.data(withJSONObject: [
                "schemaVersion": checkpoint.schemaVersion,
                "status": "resource_exceeded",
                "shopId": fixture.shopID.uuidString,
                "scope": JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint.scope))
            ])
        )
        let remote = ShopSyncRecoveryRemoteAdapter(transport: transport, defaults: fixture.defaults)
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: fixture.ownerUserID, defaults: fixture.defaults
        )
        do {
            _ = try await remote.checkpoint(
                ownerUserID: fixture.ownerUserID, scope: scope,
                verifiedBaselineID: "1", expectedBaselineScopeKey: String(repeating: "0", count: 64)
            )
            XCTFail("A response from another baseline scope must not be accepted")
        } catch {
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .invalidCheckpoint)
        }
        XCTAssertEqual(transport.counts().checkpoints, 1)
        XCTAssertEqual(transport.counts().pages, 0)
    }

    private func assertShortCheckpointDenial(
        fixtureName: String,
        expectedCode: String?,
        mutation: ((inout [String: Any]) -> Void)? = nil
    ) async throws {
        let fixture = try makeFixture()
        let checkpoint = makeCheckpoint(fixture: fixture, maxEventID: 41, seed: "short-denial")
        let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/MOBILE-PARITY/\(fixtureName).json")
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any])
        // Preserve the deployed envelope, binding only the synthetic identity to
        // this test's fresh scope. No real account, device, or shop is involved.
        payload["shopId"] = fixture.shopID.uuidString.lowercased()
        payload["scope"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint.scope))
        mutation?(&payload)
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint],
            rawCheckpoint: try JSONSerialization.data(withJSONObject: payload)
        )
        let bindingStore = AccountBindingStore(defaults: fixture.defaults)
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: fixture.ownerUserID, defaults: fixture.defaults
        )
        XCTAssertTrue(bindingStore.beginSameScopeRecovery(
            accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            reason: "short-denial-test", deviceIdentityHash: scope.deviceIdentityHash
        ))
        let beforeJournal = bindingStore.pendingRecoveryJournal
        let beforeBinding = bindingStore.currentBinding
        let beforeJournalBytes = try Data(contentsOf: fixture.recoveryJournalURL)
        do {
            _ = try await makeService(fixture: fixture, transport: transport)
                .recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("A denied or incomplete checkpoint must never publish a generation")
        } catch {
            if let expectedCode {
                XCTAssertEqual(String(describing: error), expectedCode)
            } else {
                XCTAssertTrue(error is DecodingError, "Incomplete payload must remain a decoding failure")
            }
        }
        XCTAssertEqual(transport.counts().checkpoints, 1, "Stable denial must not retry this invocation")
        XCTAssertEqual(transport.counts().pages, 0)
        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertEqual(bindingStore.pendingRecoveryJournal, beforeJournal)
        XCTAssertEqual(bindingStore.currentBinding, beforeBinding)
        XCTAssertEqual(try Data(contentsOf: fixture.recoveryJournalURL), beforeJournalBytes)
    }

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
            let counts = transport.counts()
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
        let counts = transport.counts()
        XCTAssertEqual(counts.checkpoints, 2)
        XCTAssertEqual(counts.pages, ShopSyncRecoveryDomain.allCases.count)
        let checkpointCalls = transport.checkpointCallsForTesting()
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
        let resumeCalls = resumeTransport.counts()
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
        let counts = transport.counts()
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
        let markerBaselineIDs = transport.markerBaselineIDsForTesting()
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
        let counts = transport.counts()
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
        let counts = transport.counts()
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
        let counts = transport.counts()
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
        let counts = transport.counts()
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
        let counts = transport.counts()
        XCTAssertEqual(counts.checkpoints, 1)
        XCTAssertEqual(counts.pages, 3)
    }

    func testISOThreeMillisecondHistoryActivatesWithRawLedgerAndPersistedDate() async throws {
        let fixture = try makeFixture()
        let rawTimestamp = "2026-07-05T15:40:11.305Z"
        let row = AtomicRecoveryHistoryRowPayload(
            remoteID: UUID(),
            payloadVersion: 2,
            displayName: "ISO millisecond recovery fixture",
            timestamp: rawTimestamp,
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
        // The checkpoint helper hashes the exact wire string, independently
        // of the production timestamp validator and materialized Date.
        let checkpoint = makeCheckpoint(
            fixture: fixture, maxEventID: 41, seed: "iso-milliseconds", historyRow: row
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint],
            historyRows: [row]
        )
        let summary = try await makeService(fixture: fixture, transport: transport)
            .recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
        XCTAssertTrue(summary.completedRecoveryJournal)
        let manifest = try XCTUnwrap(fixture.controller.activeManifest)
        XCTAssertEqual(manifest.localVerification.history, checkpoint.history)
        let ledgerURL = fixture.temporaryRoot
            .appendingPathComponent("generation-root", isDirectory: true)
            .appendingPathComponent(manifest.relativeStorePath)
            .deletingLastPathComponent()
            .appendingPathComponent("recovery-ledger-v1/history.ndjson")
        let persistedRecord = try JSONDecoder().decode(
            ShopSyncRecoveryLedgerRecord.self, from: Data(contentsOf: ledgerURL)
        )
        XCTAssertEqual(
            persistedRecord.versionLine.components(separatedBy: ShopSyncRecoveryCanonical.separator)
                .dropFirst(4).first,
            rawTimestamp
        )
        let reopened = try reopenFixture(fixture)
        let context = ModelContext(reopened.controller.modelContainer)
        let stored = try XCTUnwrap(context.fetch(FetchDescriptor<HistoryEntry>()).first)
        XCTAssertEqual(stored.remoteID, row.remoteID)
        // Independently computed Unix UTC epoch for the fixture, including .305.
        XCTAssertEqual(stored.timestamp.timeIntervalSince1970, 1_783_266_011.305, accuracy: 0.000_001)
    }

    func testISOHistoryCannotActivateAgainstNormalizedSecondsCheckpoint() async throws {
        let fixture = try makeFixture()
        let originalContainer = fixture.controller.modelContainer
        let row = AtomicRecoveryHistoryRowPayload(
            remoteID: UUID(),
            payloadVersion: 2,
            displayName: "Wrong digest recovery fixture",
            timestamp: "2026-07-05T15:40:11.305Z",
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
        // A checkpoint for normalized seconds must not accept the ISO wire row.
        let checkpoint = makeCheckpoint(
            fixture: fixture, maxEventID: 41, seed: "wrong-history-digest", historyRow: row,
            historyTimestampOverride: "2026-07-05 15:40:11"
        )
        let transport = AtomicRecoveryTestTransport(
            ownerUserID: fixture.ownerUserID,
            checkpoints: [checkpoint, checkpoint, checkpoint],
            historyRows: [row]
        )
        do {
            _ = try await makeService(fixture: fixture, transport: transport)
                .recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            XCTFail("A different raw timestamp digest must prevent activation")
        } catch {
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .checkpointChanged)
        }
        XCTAssertNil(fixture.controller.activeManifest)
        XCTAssertTrue(fixture.controller.modelContainer === originalContainer)
        XCTAssertNotNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        XCTAssertEqual(
            try ModelContext(originalContainer).fetchCount(FetchDescriptor<HistoryEntry>()), 0
        )
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
        let counts = transport.counts()
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

        let counts = transport.counts()
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
        historyRow: AtomicRecoveryHistoryRowPayload? = nil,
        historyTimestampOverride: String? = nil
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
                    historyTimestampOverride ?? historyRow.timestamp,
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

@MainActor
private final class AtomicRecoveryTestTransport: ShopSyncRecoveryRPCTransporting {
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
    private let rawCheckpoint: Data?
    private let rawMarker: Data?
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
        markerMutation: (@Sendable () throws -> Void)? = nil,
        rawCheckpoint: Data? = nil,
        rawMarker: Data? = nil
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
        self.rawCheckpoint = rawCheckpoint
        self.rawMarker = rawMarker
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
        if let rawCheckpoint { return rawCheckpoint }
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
            // Preserve supplied wire order. Resolve the exact cursor position;
            // sorting/filtering by UUID here would conceal malformed input.
            let start: Int
            if let afterID = parameters.afterID {
                guard let index = productRows.firstIndex(where: {
                    $0.id.uuidString.lowercased() == afterID.lowercased()
                }) else { throw ShopSyncRecoveryContractError.invalidCursor }
                start = index + 1
            } else {
                start = 0
            }
            let end = min(start + parameters.limit, productRows.count)
            let rows = Array(productRows[start..<end])
            let hasMore = end < productRows.count
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
                rows: rows,
                nextAfterId: hasMore ? rows.last?.id.uuidString.lowercased() : nil,
                hasMore: hasMore
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
        if let rawMarker { return rawMarker }
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

// Only bounded server responses and in-memory SDK auth are synthetic.
// These helpers observe and forward the real application pipeline results.
@MainActor
private struct RI08RealContinuationProof {
    let fixture: AtomicRecoveryFixture
    let checkpoint: ShopSyncRecoveryCheckpoint
    let productID: UUID
    let scope: Task126VerifiedOwnerStoreScope
    let stateStore: SyncStateStore
    let verifiedAt: Date
    let remote: RI08OrdinaryIncrementalRemote
    let engine: AutomaticSyncEngine
    let policy: AutomaticSyncCancellationPolicy
    let result: SyncAutomaticRunResult
    var watermarkScope: WatermarkStore.Scope { .init(ownerUserID: fixture.ownerUserID, storeIdentity: scope.storeIdentity) }
    var fenceDefaultsKey: String { "sync.recovery.fence.account.\(scope.accountHash).store.\(scope.storeIdentity.rawValue)" }
}

@MainActor
private final class RI08TransformingRealPullProvider: SyncIncrementalPullProviding, @unchecked Sendable {
    private let pull: SyncEventIncrementalPullService
    private let transform: (SyncIncrementalPullSummary) -> SyncIncrementalPullSummary
    private let cancelAfterProvider: AutomaticSyncCancellationPolicy?
    init(pull: SyncEventIncrementalPullService, transform: @escaping (SyncIncrementalPullSummary) -> SyncIncrementalPullSummary,
         cancelAfterProvider: AutomaticSyncCancellationPolicy? = nil) {
        self.pull = pull
        self.transform = transform
        self.cancelAfterProvider = cancelAfterProvider
    }
    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary {
        let summary = try await pull.applyIncrementalRemoteChanges(ownerUserID: ownerUserID)
        await cancelAfterProvider?.requestCancellation()
        return transform(summary)
    }
    func applyIncrementalRemoteChanges(ownerUserID: UUID, forceLightReconcile: Bool) async throws -> SyncIncrementalPullSummary {
        let summary = try await pull.applyIncrementalRemoteChanges(ownerUserID: ownerUserID, forceLightReconcile: forceLightReconcile)
        await cancelAfterProvider?.requestCancellation()
        return transform(summary)
    }
}

private nonisolated final class RI08Defaults: @unchecked Sendable {
    let value: UserDefaults
    init(_ value: UserDefaults) { self.value = value }
}

private struct RI08FenceAdvance: Sendable {
    let from: Int64
    let through: Int64
}

private struct RI08EventRead: Sendable {
    let afterID: Int64
    let returnedCount: Int
}

@MainActor
private final class RI08OrdinaryIncrementalRemote: SyncAutomaticIncrementalRemote,
    ShopScopedIncrementalRPCAuthorizing, ShopScopedIncrementalFencePersisting,
    ShopDeviceAuthorizationChecking, SyncAutomaticCatalogRemoteWriting, SyncEventRecording, @unchecked Sendable {
    nonisolated let usesServerAuthorizedShopScope = true
    private let ownerUserID: UUID
    private let shopID: UUID
    private let authoritativeScope: ShopSyncRecoveryScope
    private let defaults: RI08Defaults
    private var event: RemoteSyncEventRow?
    private var product: RemoteInventoryProductRow?
    private(set) var fenceAdvances: [RI08FenceAdvance] = []
    private(set) var eventReads: [RI08EventRead] = []
    private(set) var catalogFetchCallCount = 0
    private(set) var reconciliationFetchCallCount = 0
    var reconciliationCountsOverride: SyncInventoryCountSnapshot?
    var eventToPublishAfterCounts: RemoteSyncEventRow?
    private(set) var catalogPushCallCount = 0
    private(set) var recordRequests: [SyncEventRecordRequest] = []
    private(set) var acknowledgedSelfEvent: RemoteSyncEventRow?

    init(ownerUserID: UUID, shopID: UUID, authoritativeScope: ShopSyncRecoveryScope, defaults: RI08Defaults) {
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.authoritativeScope = authoritativeScope
        self.defaults = defaults
    }

    func replace(event: RemoteSyncEventRow, product: RemoteInventoryProductRow) {
        self.event = event
        self.product = product
    }

    func prepareProductForPush(_ row: RemoteInventoryProductRow) { product = row }

    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .suppliers)
    }
    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .suppliers)
    }
    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .categories)
    }
    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .categories)
    }
    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
    }
    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        _ = try verifiedScope()
        guard let product, product.id == id, payload.stockQuantity == 1 else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
        catalogPushCallCount += 1
        let row = RemoteInventoryProductRow(id: id, ownerUserID: ownerUserID, shopID: shopID,
            barcode: payload.barcode ?? product.barcode, itemNumber: payload.itemNumber ?? product.itemNumber,
            productName: payload.productName ?? product.productName,
            secondProductName: product.secondProductName, purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice, supplierID: product.supplierID, categoryID: product.categoryID,
            stockQuantity: payload.stockQuantity, updatedAt: "2026-07-21T12:01:00.000000Z", deletedAt: nil)
        self.product = row
        return row
    }
    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult {
        _ = try verifiedScope()
        try SyncEventRecordValidator().validate(request)
        guard request.domain == "catalog", request.eventType == "catalog_changed", request.changedCount == 1,
              request.shopID == shopID, let sourceDeviceID = request.sourceDeviceID,
              sourceDeviceID == defaults.value.string(forKey: "shop.device.install.id") else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
        recordRequests.append(request)
        let payload: [String: Any] = [
            "id": "42", "owner_user_id": ownerUserID.uuidString, "shop_id": shopID.uuidString,
            "domain": request.domain, "event_type": request.eventType,
            "source": request.source ?? "ios", "source_device_key": ShopSyncRecoveryCanonical.sha256(sourceDeviceID),
            "client_event_key": ShopSyncRecoveryCanonical.sha256(request.clientEventID), "changed_count": request.changedCount,
            "entity_ids": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.entityIDs)),
            "metadata": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.metadata)),
            "requires_full_recovery": false, "created_at": "2026-07-21T12:01:00Z"
        ]
        let row = try JSONDecoder().decode(RemoteSyncEventRow.self, from: JSONSerialization.data(withJSONObject: payload))
        acknowledgedSelfEvent = row
        event = row
        return .recorded(row)
    }

    private func verifiedScope(requireTaskLocal: Bool = true) throws -> Task126VerifiedOwnerStoreScope {
        let scope = requireTaskLocal
            ? try Task126OwnerStoreGate.requireCurrentAutomaticScope(ownerUserID: ownerUserID, defaults: defaults.value)
            : try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerUserID, defaults: defaults.value)
        guard scope.shopID == shopID else { throw Task126OwnerStoreGateError.scopeChanged }
        try authoritativeScope.validate(expectedShopID: shopID,
            expectedDeviceIdentifier: scope.deviceInstallID, expectedOwnerUserID: ownerUserID)
        let watermark = WatermarkStore(defaults: defaults.value).watermark(for: .init(
            ownerUserID: ownerUserID, storeIdentity: scope.storeIdentity))
        guard ShopSyncRecoveryFenceStore(defaults: defaults.value).scopeKey(
            accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash, watermark: watermark
        ) == authoritativeScope.key else { throw ShopSyncRecoveryContractError.scopeFenceMissing }
        return scope
    }

    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow] {
        _ = try verifiedScope()
        guard ownerUserID == self.ownerUserID, afterID >= 41, limit > 0 else {
            throw ShopSyncRecoveryContractError.invalidCursor
        }
        let rows = event.map { $0.id > afterID ? [$0] : [] } ?? []
        eventReads.append(.init(afterID: afterID, returnedCount: rows.count))
        return rows
    }

    func fetchCatalogByIDs(supplierIDs: Set<UUID>, categoryIDs: Set<UUID>, productIDs: Set<UUID>) async throws -> (
        suppliers: [RemoteInventorySupplierRow], categories: [RemoteInventoryCategoryRow], products: [RemoteInventoryProductRow]
    ) {
        catalogFetchCallCount += 1
        _ = try verifiedScope()
        guard supplierIDs.isEmpty, categoryIDs.isEmpty, let product,
              product.ownerUserID == ownerUserID, product.shopID == shopID else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
        // The real catalog service performs this scoped related lookup even with no relations.
        if productIDs.isEmpty { return ([], [], []) }
        guard productIDs == Set([product.id]) else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
        return ([], [], [product])
    }

    func advanceDurableFence(ownerUserID: UUID, scope: Task126VerifiedOwnerStoreScope,
        from watermark: Int64, through newWatermark: Int64) async throws {
        let current = try verifiedScope()
        guard current == scope, ownerUserID == self.ownerUserID,
              event?.id == newWatermark, newWatermark == watermark + 1 else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        guard ShopSyncRecoveryFenceStore(defaults: defaults.value).saveAuthoritative(
            scope: authoritativeScope, watermark: newWatermark,
            accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash
        ) else { throw ShopSyncRecoveryContractError.scopeFenceMissing }
        fenceAdvances.append(.init(from: watermark, through: newWatermark))
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        reconciliationFetchCallCount += 1
        _ = try verifiedScope()
        if let eventToPublishAfterCounts { event = eventToPublishAfterCounts }
        return reconciliationCountsOverride ?? .init(products: 1, suppliers: 0, categories: 0, productPrices: 0, historySessions: 0)
    }
    func fetchProductPricesByIDs(ownerUserID: UUID, priceIDs: Set<UUID>) async throws -> [RemoteInventoryProductPriceRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .prices)
    }
    func upsertSharedSheetSessions(_ rows: [SharedSheetSessionUpsertRow], ownerUserID: UUID) async throws -> [RemoteSharedSheetSessionRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .history)
    }
    func fetchSharedSheetSessionsPage(ownerUserID: UUID, from: Int, to: Int) async throws -> [RemoteSharedSheetSessionRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .history)
    }
    func fetchSharedSheetSessionsByIDs(ownerUserID: UUID, sessionIDs: Set<UUID>) async throws -> [RemoteSharedSheetSessionRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .history)
    }
    func registerCurrentOwnerDevice(reason: String, force: Bool) async -> Bool { false }
    func registerHeartbeatAndCheck(reason: String) async -> ShopDeviceAuthorizationSnapshot { deviceSnapshot() }
    func currentOwnerDeviceStatus(reason: String, force: Bool) async -> ShopDeviceAuthorizationSnapshot { deviceSnapshot() }
    func ensureActiveForCloudWrite(reason: String) async throws -> ShopDeviceAuthorizationSnapshot {
        _ = try verifiedScope(requireTaskLocal: false)
        return deviceSnapshot()
    }
    private func deviceSnapshot() -> ShopDeviceAuthorizationSnapshot {
        .init(status: "active", code: "active", canWrite: true, serverTime: nil,
            lastSeenAt: nil, reasonCode: "ri08-synthetic", recommendedAction: "none", checkedAt: Date())
    }
}

// Synthetic controlled remote, NOT the actual V6 RPC wrapper. Read-only fence
// decoding includes legitimate0 to isolate the real domain/state continuation.
@MainActor
private final class RI08ZeroIncrementalRemote: SyncAutomaticIncrementalRemote,
    ShopScopedIncrementalRPCAuthorizing, ShopScopedIncrementalFencePersisting,
    ShopDeviceAuthorizationChecking, @unchecked Sendable {
    nonisolated let usesServerAuthorizedShopScope = true
    private let ownerUserID: UUID
    private let shopID: UUID
    private let authoritativeScope: ShopSyncRecoveryScope
    private let defaults: RI08Defaults
    private var event: RemoteSyncEventRow?
    private var product: RemoteInventoryProductRow?
    private(set) var eventReads: [RI08EventRead] = []
    private(set) var fenceAdvances: [RI08FenceAdvance] = []
    private(set) var catalogFetchCallCount = 0
    private(set) var reconciliationFetchCallCount = 0

    init(ownerUserID: UUID, shopID: UUID, authoritativeScope: ShopSyncRecoveryScope, defaults: RI08Defaults) {
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.authoritativeScope = authoritativeScope
        self.defaults = defaults
    }

    func replace(event: RemoteSyncEventRow, product: RemoteInventoryProductRow) {
        self.event = event
        self.product = product
    }

    func validateActualRecoveryFence(requireTaskLocal: Bool = false) throws {
        let scope = requireTaskLocal
            ? try Task126OwnerStoreGate.requireCurrentAutomaticScope(ownerUserID: ownerUserID, defaults: defaults.value)
            : try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerUserID, defaults: defaults.value)
        guard scope.shopID == shopID else { throw Task126OwnerStoreGateError.scopeChanged }
        try authoritativeScope.validate(expectedShopID: shopID,
            expectedDeviceIdentifier: scope.deviceInstallID, expectedOwnerUserID: ownerUserID)
        let watermark = WatermarkStore(defaults: defaults.value).watermark(for: .init(
            ownerUserID: ownerUserID, storeIdentity: scope.storeIdentity))
        let key = "sync.recovery.fence.account.\(scope.accountHash).store.\(scope.storeIdentity.rawValue)"
        guard let data = defaults.value.data(forKey: key), data.count <= 2_048,
              let record = try JSONSerialization.jsonObject(with: data) as? [String: String],
              record["schema"] == "shop-sync-recovery-fence-v1",
              record["scopeKey"] == authoritativeScope.key,
              record["accountKey"] == scope.accountHash,
              record["deviceKey"] == scope.deviceIdentityHash,
              record["watermark"] == String(watermark), watermark >= 0,
              record["checksum"] == ShopSyncRecoveryCanonical.sha256([
                "shop-sync-recovery-fence-v1", authoritativeScope.key, scope.accountHash,
                scope.storeIdentity.rawValue, scope.deviceIdentityHash, String(watermark)
              ].joined(separator: "|")) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
    }

    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow] {
        try validateActualRecoveryFence(requireTaskLocal: true)
        guard ownerUserID == self.ownerUserID, afterID >= 0, limit > 0 else {
            throw ShopSyncRecoveryContractError.invalidCursor
        }
        let rows = event.map { $0.id > afterID ? [$0] : [] } ?? []
        eventReads.append(.init(afterID: afterID, returnedCount: rows.count))
        return rows
    }

    func fetchCatalogByIDs(supplierIDs: Set<UUID>, categoryIDs: Set<UUID>, productIDs: Set<UUID>) async throws -> (
        suppliers: [RemoteInventorySupplierRow], categories: [RemoteInventoryCategoryRow], products: [RemoteInventoryProductRow]
    ) {
        catalogFetchCallCount += 1
        try validateActualRecoveryFence(requireTaskLocal: true)
        guard supplierIDs.isEmpty, categoryIDs.isEmpty else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
        if productIDs.isEmpty { return ([], [], []) }
        guard let product, product.ownerUserID == ownerUserID, product.shopID == shopID,
              productIDs == Set([product.id]) else {
            throw ShopSyncRecoveryContractError.invalidPage(domain: .products)
        }
        return ([], [], [product])
    }

    func advanceDurableFence(ownerUserID: UUID, scope: Task126VerifiedOwnerStoreScope,
        from watermark: Int64, through newWatermark: Int64) async throws {
        try validateActualRecoveryFence(requireTaskLocal: true)
        let current = try Task126OwnerStoreGate.requireCurrentAutomaticScope(ownerUserID: self.ownerUserID,
            defaults: defaults.value)
        guard current == scope, ownerUserID == self.ownerUserID,
              event?.id == newWatermark, newWatermark == watermark + 1 else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        // Normal production domain commit calls this remote fence callback.
        guard ShopSyncRecoveryFenceStore(defaults: defaults.value).saveAuthoritative(
            scope: authoritativeScope, watermark: newWatermark, accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity, deviceIdentityHash: scope.deviceIdentityHash) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        fenceAdvances.append(.init(from: watermark, through: newWatermark))
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        reconciliationFetchCallCount += 1
        try validateActualRecoveryFence(requireTaskLocal: true)
        return .init(products: product == nil ? 0 : 1, suppliers: 0, categories: 0,
            productPrices: 0, historySessions: 0)
    }
    func fetchProductPricesByIDs(ownerUserID: UUID, priceIDs: Set<UUID>) async throws -> [RemoteInventoryProductPriceRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .prices)
    }
    func upsertSharedSheetSessions(_ rows: [SharedSheetSessionUpsertRow], ownerUserID: UUID) async throws -> [RemoteSharedSheetSessionRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .history)
    }
    func fetchSharedSheetSessionsPage(ownerUserID: UUID, from: Int, to: Int) async throws -> [RemoteSharedSheetSessionRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .history)
    }
    func fetchSharedSheetSessionsByIDs(ownerUserID: UUID, sessionIDs: Set<UUID>) async throws -> [RemoteSharedSheetSessionRow] {
        throw ShopSyncRecoveryContractError.invalidPage(domain: .history)
    }
    func registerCurrentOwnerDevice(reason: String, force: Bool) async -> Bool { false }
    func registerHeartbeatAndCheck(reason: String) async -> ShopDeviceAuthorizationSnapshot { deviceSnapshot() }
    func currentOwnerDeviceStatus(reason: String, force: Bool) async -> ShopDeviceAuthorizationSnapshot { deviceSnapshot() }
    func ensureActiveForCloudWrite(reason: String) async throws -> ShopDeviceAuthorizationSnapshot {
        try validateActualRecoveryFence()
        return deviceSnapshot()
    }
    private func deviceSnapshot() -> ShopDeviceAuthorizationSnapshot {
        .init(status: "active", code: "active", canWrite: true, serverTime: nil,
            lastSeenAt: nil, reasonCode: "ri08-zero-synthetic", recommendedAction: "none", checkedAt: Date())
    }
}

@MainActor
private final class RI08ObservedRealRuntime: SyncAutomaticRuntimeProviding {
    private let facade: AutomaticSyncRuntimeFacade
    private(set) var results: [SyncAutomaticRunResult] = []
    private(set) var actions: [SyncAction] = []
    private(set) var sources: [SyncAutomaticTriggerSource] = []
    var expectedCompletions: [XCTestExpectation] = []
    init(facade: AutomaticSyncRuntimeFacade) { self.facade = facade }
    var isRunning: Bool { facade.isRunning }
    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        actions.append(action)
        sources.append(source)
        let result = await facade.run(action: action, source: source)
        results.append(result)
        if expectedCompletions.indices.contains(results.count - 1) {
            expectedCompletions[results.count - 1].fulfill()
        }
        return result
    }
    func cancel() { facade.cancel() }
    func cancelAndWait() async { await facade.cancelAndWait() }
    func resumeAfterStoreReplacement() async { await facade.resumeAfterStoreReplacement() }
}

@MainActor
private final class RI08SyntheticAuth {
    let viewModel: SupabaseAuthViewModel
    let networkBlocker = RI08NetworkCounter()
    private let host: String
    private let session: URLSession
    init(ownerUserID: UUID) throws {
        host = "ri08-\(UUID().uuidString.lowercased()).example.invalid"
        let storage = RI08MemoryAuthStorage()
        let user = User(id: ownerUserID, appMetadata: [:], userMetadata: [:], aud: "authenticated",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000), updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let syntheticSession = Session(accessToken: "ri08-synthetic-access", tokenType: "bearer",
            expiresIn: 3600, expiresAt: Date().timeIntervalSince1970 + 3600,
            refreshToken: "ri08-synthetic-refresh", user: user)
        try storage.store(key: "sb-\(host.split(separator: ".")[0])-auth-token",
            value: JSONEncoder().encode(syntheticSession))
        RI08NetworkBlocker.register(host: host, counter: networkBlocker)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RI08NetworkBlocker.self]
        session = URLSession(configuration: configuration)
        let provider = SupabaseClientProvider(
            config: .init(projectURL: URL(string: "https://\(host)")!,
                publishableKey: "ri08-synthetic-publishable", productImageAPIBaseURL: nil),
            authStorage: storage, session: session, autoRefreshToken: false,
            authRegistry: SupabaseAuthClientRegistry())
        viewModel = SupabaseAuthViewModel(authService: SupabaseAuthService(provider: provider))
    }
    func close() {
        session.invalidateAndCancel()
        RI08NetworkBlocker.unregister(host: host)
    }
}

private nonisolated final class RI08MemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}
private nonisolated final class RI08NetworkCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var requestCount: Int { lock.withLock { count } }
    func record() { lock.withLock { count += 1 } }
}
private nonisolated final class RI08NetworkRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var counters: [String: RI08NetworkCounter] = [:]
    func register(host: String, counter: RI08NetworkCounter) { lock.withLock { counters[host] = counter } }
    func unregister(host: String) { _ = lock.withLock { counters.removeValue(forKey: host) } }
    func record(host: String) { lock.withLock { counters[host] }?.record() }
}
private nonisolated final class RI08NetworkBlocker: URLProtocol, @unchecked Sendable {
    private static let registry = RI08NetworkRegistry()
    static func register(host: String, counter: RI08NetworkCounter) { registry.register(host: host, counter: counter) }
    static func unregister(host: String) { registry.unregister(host: host) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.registry.record(host: request.url?.host ?? "")
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
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
