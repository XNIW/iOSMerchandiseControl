import SwiftData
import XCTest
@testable import iOSMerchandiseControl

/// Actual manual adapter/service and real local mutation fence. The remote and
/// device authorization are controlled boundaries, not live cloud acceptance.
@MainActor
final class ManualPendingDispatchCASTests: XCTestCase {
    func testSaveCoalescedDuringDeviceAuthorizationPreventsAllBusinessHTTP() async throws {
        let fixture = try await makeFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertTrue(plan.isSendable)
        let original = try fixture.token()
        var later: LocalPendingChangeCASToken?
        fixture.authorization.duringExecute = { later = try fixture.save(name: "B after auth suspension") }
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(result.status, .blockedBeforeWrite)
        XCTAssertEqual(fixture.authorization.executeEntries, 1)
        XCTAssertEqual(fixture.remote.businessEntries, 0)
        XCTAssertEqual(later?.changeID, original.changeID, "The real unattempted writer coalesces the same ID")
        XCTAssertNotEqual(later, original)
        XCTAssertEqual(try fixture.token(), later)
        XCTAssertNil(try fixture.token().lastAttemptAt)
    }

    func testDurableAdoptReceiptDuringAuthorizationPreventsRetiredPlanDispatch() async throws {
        let fixture = try await makeFixture(creating: false)
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertTrue(plan.isSendable)
        let originalRemote = try XCTUnwrap(fixture.originalRemote)
        var retained: LocalPendingChangeCASToken?
        var decisionID: UUID?
        fixture.authorization.duringExecute = {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
                ownerUserID: fixture.owner, defaults: fixture.defaults) { context in
                let row = try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == fixture.changeID })
                row.status = .staleBaseline
                row.updatedAt = Date()
                try context.save()
            }
            let reader = ManualCASConflictReader(row: originalRemote)
            let service = CatalogConflictResolutionService(remote: reader, defaults: fixture.defaults)
            let review = try await service.prepare(modelContainer: fixture.container, ownerUserID: fixture.owner,
                remoteID: originalRemote.id, changeID: fixture.changeID)
            XCTAssertTrue(review.canResolve)
            retained = review.pending
            decisionID = review.id
            let outcome = try await service.resolve(review: review, choice: .adoptRemote, modelContainer: fixture.container)
            XCTAssertEqual(outcome, .adoptedRemote)
            XCTAssertEqual(reader.productFetches, 2)
            XCTAssertEqual(reader.emptyRelationFetches, 2)
        }
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(result.status, .blockedBeforeWrite)
        XCTAssertEqual(fixture.authorization.executeEntries, 1)
        XCTAssertEqual(fixture.remote.businessEntries, 0)
        let read = ModelContext(fixture.container)
        XCTAssertNotNil(try LocalCatalogConflictResolutionStore.receipt(decisionID: try XCTUnwrap(decisionID), context: read))
        XCTAssertTrue(try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: read).contains(fixture.changeID))
        XCTAssertEqual(try fixture.token(), retained, "Retirement retains the physical A token; no manual ACK rewrites it")
    }

    func testScopeRetiredDuringAuthorizationPreventsAllBusinessHTTP() async throws {
        let fixture = try await makeFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertTrue(plan.isSendable)
        let original = try fixture.token()
        fixture.authorization.duringExecute = { Task126OwnerStoreGate.invalidateAutomaticScopeLease() }
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(result.status, .blockedBeforeWrite)
        XCTAssertEqual(fixture.remote.businessEntries, 0)
        XCTAssertEqual(try fixture.token(), original)
    }

    func testUnchangedCreateUsesActualServiceLinksRemoteIDAndAcknowledgesOnlyOriginalToken() async throws {
        let fixture = try await makeFixture()
        let original = try fixture.token()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertTrue(plan.isSendable)
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertTrue([SupabaseManualPushTerminalStatus.completed, .completedBaselineRefreshFailed].contains(result.status))
        XCTAssertEqual(result.productCreates, 1)
        XCTAssertEqual(fixture.remote.businessEntries, 1)
        XCTAssertEqual(fixture.remote.readbackEntries, 1)
        XCTAssertEqual(fixture.remote.createdNames, ["A original"])
        let product = try fixture.product()
        XCTAssertEqual(product.remoteID, fixture.remote.createdID)
        let acknowledged = try fixture.token()
        XCTAssertEqual(acknowledged.changeID, original.changeID)
        XCTAssertEqual(acknowledged.intendedFingerprintHash, original.intendedFingerprintHash)
        XCTAssertEqual(acknowledged.logicalKey, original.logicalKey, "Linking the model must not reinterpret the pending revision")
        XCTAssertEqual(acknowledged.statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        XCTAssertNotNil(acknowledged.lastAttemptAt)
        let repeated = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(repeated.status, .blockedBeforeWrite)
        XCTAssertEqual(fixture.remote.businessEntries, 1, "Consumed plan cannot be dispatched twice")
    }

    func testPlanWithoutItsCapturedBatchCannotBypassAdmission() async throws {
        let fixture = try await makeFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        let uncaptured = SyncCatalogPushAdapter(context: ModelContext(fixture.container),
            manualPushService: SupabaseManualPushService(remote: fixture.remote), defaults: fixture.defaults)
        let original = try fixture.token()
        let result = await uncaptured.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(result.status, .blockedBeforeWrite)
        XCTAssertEqual(fixture.remote.businessEntries, 0)
        XCTAssertEqual(try fixture.token(), original)
    }

    func testSaveAfterDispatchCannotBeAcknowledgedByOriginalHTTPResponse() async throws {
        let fixture = try await makeFixture(creating: false)
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertTrue(plan.isSendable)
        var later: LocalPendingChangeCASToken?
        fixture.remote.beforeResponse = { later = try fixture.save(name: "B while A HTTP is pending") }
        _ = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        let laterToken = try XCTUnwrap(later)
        XCTAssertNotEqual(laterToken.changeID, fixture.changeID)
        let read = ModelContext(fixture.container)
        let current = try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == laterToken.changeID })
        XCTAssertTrue(laterToken.matches(current), "A's response cannot ACK or rewrite B")
        XCTAssertEqual(current.status, .pending)
        XCTAssertNil(current.lastAttemptAt)
        XCTAssertEqual(fixture.remote.businessEntries, 1)
        XCTAssertEqual(fixture.remote.updatedNames, ["A original"])
    }

    func testOneChangedRevisionRejectsEntireBatchWithoutPartialMarkSent() async throws {
        let fixture = try await makeFixture()
        let original = try fixture.token()
        var siblingID = ""
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults) { context in
            let product = Product(barcode: "MANUAL-CAS-SIBLING", productName: "Sibling A")
            context.insert(product)
            siblingID = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: fixture.owner,
                storeIdentity: fixture.scope.storeIdentity).recordProductChange(product: product, operation: .create,
                    origin: .manualCatalogSave, changedFields: ["barcode", "productName"])).changeID
            try context.save()
        }
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertEqual(plan.writeCandidates.count, 2)
        fixture.authorization.duringExecute = { _ = try fixture.save(name: "B coalesced") }
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(result.status, .blockedBeforeWrite)
        XCTAssertEqual(fixture.remote.businessEntries, 0)
        let read = ModelContext(fixture.container)
        let sibling = try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == siblingID })
        XCTAssertEqual(sibling.status, .pending)
        XCTAssertNil(sibling.lastAttemptAt)
        XCTAssertNotEqual(try fixture.token(), original)
    }

    /// Discriminator for the separate mutable-body gap. Entry/terminal CAS
    /// alone is insufficient: the product phase fetches after supplier await.
    func testInternalSupplierAwaitMustNotSendChangedProductUnderOriginalPlan() async throws {
        let fixture = try await makeFixture()
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults) { context in
            let supplier = Supplier(name: "MANUAL-CAS-SUPPLIER")
            context.insert(supplier)
            try LocalPendingChangeAccumulator(context: context, ownerUserID: fixture.owner,
                storeIdentity: fixture.scope.storeIdentity).recordSupplierChange(supplier: supplier,
                    operation: .create, origin: .manualCatalogSave, changedFields: ["name"])
            try context.save()
        }
        fixture.remote.allowSupplierCreate = true
        fixture.remote.beforeSupplierResponse = { _ = try fixture.save(name: "B during supplier HTTP") }
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertEqual(plan.writeCandidates.count, 2)
        _ = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(fixture.remote.supplierEntries, 1)
        XCTAssertFalse(fixture.remote.createdNames.contains("B during supplier HTTP"),
            "The original plan cannot dispatch B using A's admitted pending token")
        let read = ModelContext(fixture.container)
        let later = try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first {
            $0.changeID != fixture.changeID && $0.entityKind == .product && !$0.status.isTerminal
        })
        XCTAssertEqual(later.status, .pending)
        XCTAssertNil(later.lastAttemptAt)
    }

    func testUnknownBatchResponseDoesNotDispatchAnyHalfBatchOrRetry() async throws {
        let fixture = try await makeFixture()
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults) { context in
            let sibling = Product(barcode: "MANUAL-CAS-UNKNOWN-SIBLING", productName: "Sibling original")
            context.insert(sibling)
            try LocalPendingChangeAccumulator(context: context, ownerUserID: fixture.owner,
                storeIdentity: fixture.scope.storeIdentity).recordProductChange(product: sibling,
                    operation: .create, origin: .manualCatalogSave, changedFields: ["barcode", "productName"])
            try context.save()
        }
        let before = try ModelContext(fixture.container).fetch(FetchDescriptor<LocalPendingChange>()).map(LocalPendingChangeCASToken.init)
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertEqual(plan.writeCandidates.count, 2)
        fixture.remote.loseBatchResponse = true
        _ = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(fixture.remote.productBatchSizes, [2], "Unknown outcome preserves the whole request; no split replay")
        XCTAssertEqual(fixture.remote.businessEntries, 1)
        let after = try ModelContext(fixture.container).fetch(FetchDescriptor<LocalPendingChange>())
        XCTAssertEqual(Set(after.map(\.changeID)), Set(before.map(\.changeID)))
        for token in before {
            let row = try XCTUnwrap(after.first { $0.changeID == token.changeID })
            XCTAssertEqual(row.intendedFingerprintHash, token.intendedFingerprintHash)
            XCTAssertEqual(row.idempotencyKey, token.idempotencyKey)
            XCTAssertEqual(row.changedFieldsRaw, token.changedFieldsRaw)
            XCTAssertNotNil(row.lastAttemptAt)
            XCTAssertNotEqual(row.status, .acknowledged)
        }
        let retry = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertFalse(retry.isSendable)
        XCTAssertEqual(fixture.remote.productBatchSizes, [2])
    }

    func testScopedLookupLinkOnlyFillsFrozenProductDependencyAndExactTokensAcknowledge() async throws {
        let fixture = try await makeFixture()
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults) { context in
            let supplier = Supplier(name: "MANUAL-CAS-DEPENDENCY")
            context.insert(supplier)
            let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first { $0.barcode == fixture.barcode })
            product.supplier = supplier
            let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: fixture.owner,
                storeIdentity: fixture.scope.storeIdentity)
            try accumulator.recordSupplierChange(supplier: supplier, operation: .create, origin: .manualCatalogSave)
            try accumulator.recordProductChange(product: product, operation: .create,
                origin: .manualCatalogSave, changedFields: ["supplier"])
            try context.save()
        }
        fixture.remote.allowSupplierCreate = true
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertEqual(plan.writeCandidates.count, 2)
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(result.supplierCreates, 1)
        XCTAssertEqual(result.productCreates, 1)
        XCTAssertEqual(fixture.remote.businessEntries, 2)
        XCTAssertEqual(fixture.remote.createdNames, ["A original"])
        XCTAssertEqual(fixture.remote.createdSupplierIDs, [fixture.remote.createdSupplierID])
        let read = ModelContext(fixture.container)
        let rows = try read.fetch(FetchDescriptor<LocalPendingChange>())
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy { $0.status == .acknowledged })
        XCTAssertEqual(try fixture.product().supplier?.remoteID, fixture.remote.createdSupplierID)
        XCTAssertTrue(Task126OwnerStoreGate.hasCurrentLocalBodyProof(fixture.container))
    }

    func testScopeChangeAfterRemoteResponseDoesNotLinkOrAcknowledge() async throws {
        let fixture = try await makeFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        var admitted: LocalPendingChangeCASToken?
        fixture.remote.beforeResponse = {
            admitted = try fixture.token()
            Task126OwnerStoreGate.invalidateAutomaticScopeLease()
        }
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertNotEqual(result.status, .completed)
        XCTAssertEqual(fixture.remote.businessEntries, 1)
        XCTAssertNil(try fixture.product().remoteID)
        XCTAssertEqual(try fixture.token(), admitted)
        XCTAssertEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.sent.rawValue)
    }

    func testPriceParentChangedDuringAuthorizationRejectsWithoutAnyWrite() async throws {
        let fixture = try await makePriceFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertEqual(plan.summary.readyCandidates, 1)
        let original = try fixture.token()
        fixture.authorization.duringExecute = { _ = try fixture.saveParentPrice(37) }
        do {
            _ = try await fixture.provider.push(plan: plan, ownerUserID: fixture.owner)
            XCTFail("A newly active parent intent blocks the original price plan")
        } catch { XCTAssertTrue(error is LocalPendingManualDispatchError) }
        XCTAssertEqual(fixture.remote.insertEntries, 0)
        XCTAssertEqual(fixture.remote.productEntries, 0)
        XCTAssertEqual(try fixture.token(), original)
    }

    func testPriceExactBatchLinksAndAcknowledgesOnlyItsOwnChild() async throws {
        let fixture = try await makePriceFixture()
        let original = try fixture.token()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertEqual(plan.summary.readyCandidates, 1)
        let result = try await fixture.provider.push(plan: plan, ownerUserID: fixture.owner)
        XCTAssertTrue(result.isVerifiedSuccess)
        XCTAssertEqual(fixture.remote.insertEntries, 1)
        XCTAssertEqual(fixture.remote.productEntries, 0)
        let read = ModelContext(fixture.container)
        let price = try XCTUnwrap(read.fetch(FetchDescriptor<ProductPrice>()).first)
        XCTAssertEqual(price.remoteID, fixture.remote.payloads.first?.id)
        XCTAssertEqual(fixture.remote.payloads.first?.shopID, fixture.scope.shopID)
        XCTAssertEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        XCTAssertEqual(try fixture.token().intendedFingerprintHash, original.intendedFingerprintHash)
        XCTAssertEqual(try read.fetch(FetchDescriptor<LocalPendingChange>()).count, 1)
        XCTAssertTrue(Task126OwnerStoreGate.hasCurrentLocalBodyProof(fixture.container))
    }

    func testCatalogBProducedDuringPriceHTTPIsNeitherPatchedNorAcknowledged() async throws {
        let fixture = try await makePriceFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        var later: LocalPendingChangeCASToken?
        fixture.remote.beforeInsertResponse = { later = try fixture.saveParentPrice(37) }
        do {
            _ = try await fixture.provider.push(plan: plan, ownerUserID: fixture.owner)
            XCTFail("The price response cannot retire a catalog intent that appeared after planning")
        } catch { XCTAssertTrue(error is LocalPendingManualDispatchError) }
        XCTAssertEqual(fixture.remote.insertEntries, 1)
        XCTAssertEqual(fixture.remote.productEntries, 0)
        let read = ModelContext(fixture.container)
        let b = try XCTUnwrap(later)
        XCTAssertTrue(b.matches(try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == b.changeID })))
        XCTAssertEqual(b.statusRaw, LocalPendingChangeStatus.pending.rawValue)
        XCTAssertNil(b.lastAttemptAt)
        XCTAssertEqual(try read.fetch(FetchDescriptor<ProductPrice>()).count, 1)
        XCTAssertNotEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
    }

    func testPriceChildAcknowledgementPreservesDurablyRetiredCatalogA() async throws {
        let fixture = try await makePriceFixture()
        let a = try fixture.saveParentPrice(37)
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults) { context in
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == a.changeID })
            row.status = .staleBaseline
            row.updatedAt = Date()
            try context.save()
        }
        let reader = ManualCASConflictReader(row: .init(id: fixture.productID,
            ownerUserID: fixture.owner, shopID: fixture.scope.shopID, barcode: "MANUAL-PRICE-CAS",
            itemNumber: nil, productName: "Parent", secondProductName: nil, purchasePrice: nil,
            retailPrice: 20, supplierID: nil, categoryID: nil, stockQuantity: nil,
            updatedAt: "2026-10-23T20:00:00.123456Z", deletedAt: nil))
        let resolver = CatalogConflictResolutionService(remote: reader, defaults: fixture.defaults)
        let review = try await resolver.prepare(modelContainer: fixture.container, ownerUserID: fixture.owner,
            remoteID: fixture.productID, changeID: a.changeID)
        XCTAssertTrue(review.canResolve)
        _ = try await resolver.resolve(review: review, choice: .adoptRemote, modelContainer: fixture.container)
        XCTAssertEqual(reader.productFetches, 2)
        XCTAssertEqual(reader.emptyRelationFetches, 2)
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertEqual(plan.summary.readyCandidates, 1)
        let result = try await fixture.provider.push(plan: plan, ownerUserID: fixture.owner)
        XCTAssertTrue(result.isVerifiedSuccess)
        XCTAssertEqual(fixture.remote.productEntries, 0)
        let read = ModelContext(fixture.container)
        let retained = try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == a.changeID })
        XCTAssertTrue(review.pending.matches(retained))
        XCTAssertNotNil(try LocalCatalogConflictResolutionStore.receipt(decisionID: review.id, context: read))
        XCTAssertEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        XCTAssertEqual(try read.fetch(FetchDescriptor<ProductPrice>()).count, 1)
        XCTAssertNotNil(try read.fetch(FetchDescriptor<ProductPrice>()).first?.remoteID)
    }

    private func makePriceFixture(effectiveAt: Date = Date(timeIntervalSince1970: 1_792_800_000)) async throws -> PriceFixture {
        let productID = UUID()
        // The parent must be part of the actual recovery checkpoint and body
        // proof before the price intent exists. A later unrelated baseline run
        // cannot qualify a newly inserted parent against the active manifest.
        let local = try await makeQualifiedSyncStateFixture(includesAuth: true, products: { owner, shop in
            [RemoteInventoryProductRow(id: productID, ownerUserID: owner, shopID: shop,
                barcode: "MANUAL-PRICE-CAS", itemNumber: nil, productName: "Parent",
                secondProductName: nil, purchasePrice: nil, retailPrice: 20,
                supplierID: nil, categoryID: nil, stockQuantity: nil,
                updatedAt: "2026-10-23T20:00:00.123456Z", deletedAt: nil)]
        })
        let owner = try XCTUnwrap(local.authViewModel?.localMutationOwnerUserID)
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: local.defaults)
        var changeID = ""
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: local.controller.modelContainer,
            ownerUserID: owner, defaults: local.defaults) { context in
            let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first { $0.remoteID == productID })
            let price = ProductPrice(type: .retail, price: 20, effectiveAt: effectiveAt, createdAt: effectiveAt, product: product)
            context.insert(price)
            changeID = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: owner,
                storeIdentity: scope.storeIdentity).recordProductPriceChange(price: price, origin: .productPriceSave)).changeID
            try context.save()
        }
        let remote = ManualCASPriceRemote()
        let auth = ManualCASAuthorization()
        let adapter = SyncProductPriceAdapter(modelContainer: local.controller.modelContainer, remote: remote, defaults: local.defaults)
        return PriceFixture(defaults: local.defaults, controller: local.controller, owner: owner,
            scope: scope, productID: productID, changeID: changeID, remote: remote, authorization: auth,
            provider: DeviceGuardedManualProductPriceProvider(delegate: adapter, deviceAuthorization: auth))
    }

    @MainActor
    private struct PriceFixture {
        let defaults: UserDefaults
        let controller: SyncStoreGenerationController
        let owner: UUID
        let scope: Task126VerifiedOwnerStoreScope
        let productID: UUID
        let changeID: String
        let remote: ManualCASPriceRemote
        let authorization: ManualCASAuthorization
        let provider: DeviceGuardedManualProductPriceProvider
        var container: ModelContainer { controller.modelContainer }
        func token() throws -> LocalPendingChangeCASToken {
            LocalPendingChangeCASToken(try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == changeID }))
        }
        func saveParentPrice(_ value: Double) throws -> LocalPendingChangeCASToken {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container, ownerUserID: owner, defaults: defaults) { context in
                let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first { $0.remoteID == productID })
                let baseline = LocalPendingChangeLogicalKey.productFingerprintHash(product)
                product.retailPrice = value
                let row = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: owner,
                    storeIdentity: scope.storeIdentity).recordProductChange(product: product, operation: .update,
                        origin: .manualCatalogSave, changedFields: ["retailPrice"], baselineFingerprintHash: baseline))
                try context.save()
                return LocalPendingChangeCASToken(row)
            }
        }
    }

    func testRealGeneratedPriceRecorderUsesCurrentBodyFenceAndNeverAcknowledgesLaterB() async throws {
        let generated = ManualCASGeneratedPrices()
        let fixture = try await makeFixture(generatedPriceRemote: generated)
        generated.shopID = fixture.scope.shopID
        var later: LocalPendingChangeCASToken?
        generated.beforeReturn = { later = try fixture.save(name: "B after A ACK during telemetry read") }
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(result.productCreates, 1)
        XCTAssertEqual(generated.reads, 1)
        XCTAssertEqual(fixture.remote.businessEntries, 1)
        XCTAssertEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        let token = try XCTUnwrap(later)
        let read = ModelContext(fixture.container)
        XCTAssertTrue(token.matches(try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == token.changeID })))
        XCTAssertEqual(token.statusRaw, LocalPendingChangeStatus.pending.rawValue)
        XCTAssertNil(token.lastAttemptAt)
        XCTAssertTrue(Task126OwnerStoreGate.hasCurrentLocalBodyProof(fixture.container))
    }

    func testDuplicateCreateResponseCannotLinkOrAcknowledgeEitherOriginalMember() async throws {
        let fixture = try await makeFixture()
        try addSibling(fixture)
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertEqual(plan.writeCandidates.count, 2)
        fixture.remote.duplicateCreateResponse = true
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertFalse([SupabaseManualPushTerminalStatus.completed, .completedBaselineRefreshFailed].contains(result.status))
        XCTAssertEqual(fixture.remote.productBatchSizes, [2])
        let read = ModelContext(fixture.container)
        XCTAssertTrue(try read.fetch(FetchDescriptor<Product>()).allSatisfy { $0.remoteID == nil })
        let pending = try read.fetch(FetchDescriptor<LocalPendingChange>())
        XCTAssertEqual(pending.count, 2)
        XCTAssertTrue(pending.allSatisfy { $0.status == .sent })
        XCTAssertEqual(try ManualPendingAtomicRequestStore.protectedChangeIDs(context: read), Set(pending.map(\.changeID)))
    }

    func testActualManualUnknownSurvivesControllerReopenWithExactAtomicBytesAndNoResend() async throws {
        let fixture = try await makeFixture()
        try addSibling(fixture)
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        fixture.remote.loseBatchResponse = true
        _ = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(fixture.remote.productBatchSizes, [2])
        let original = try ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container))
        XCTAssertEqual(original.count, 1)
        let receipt = try XCTUnwrap(original.first?.1)
        XCTAssertEqual(receipt.request.body, fixture.remote.lastWireBody)
        XCTAssertEqual(receipt.request.members.count, 2)
        XCTAssertEqual(receipt.request.requestMemberIDs.count, 2)
        XCTAssertEqual(original.first?.0.lastErrorKindRaw, ManualPendingAtomicRequestStore.Phase.inFlight.rawValue)
        XCTAssertFalse(try XCTUnwrap(original.first?.0.metadataPayloadJSON).contains("never-persist-test-secret"))
        let manifest = try XCTUnwrap(fixture.controller.active.manifest)
        var base = try XCTUnwrap(fixture.container.configurations.first?.url)
        for _ in manifest.relativeStorePath.split(separator: "/") { base.deleteLastPathComponent() }
        let repository = try SyncStoreGenerationRepository(baseDirectory: base, defaults: fixture.defaults)
        let reopened = try SyncStoreGenerationController(repository: repository, defaults: fixture.defaults)
        let qualified = await reopened.awaitLocalBodyQualification()
        XCTAssertTrue(qualified)
        let read = ModelContext(reopened.modelContainer)
        let persisted = try ManualPendingAtomicRequestStore.records(context: read)
        XCTAssertEqual(persisted.first?.1, receipt)
        XCTAssertEqual(persisted.first?.0.metadataPayloadJSON, original.first?.0.metadataPayloadJSON)
        XCTAssertEqual(try ManualPendingAtomicRequestStore.protectedChangeIDs(context: read), receipt.request.changeIDs)
        let adapter = SyncCatalogPushAdapter(context: read,
            manualPushService: SupabaseManualPushService(remote: fixture.remote), defaults: fixture.defaults)
        let next = try await adapter.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertFalse(next.isSendable)
        _ = await adapter.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(fixture.remote.productBatchSizes, [2], "Unknown atomic batch is never rebuilt or split after reopen")
    }

    func testUnknownTransferKeepsOriginalRequestAndWholeMembership() async throws {
        let fixture = try await makeFixture()
        try addSibling(fixture)
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        fixture.remote.loseBatchResponse = true
        _ = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        let original = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container)).first)
        let target = try SyncStoreSchema.makeInMemoryContainer()
        let destination = UUID()
        let copy = try ManualPendingAtomicRequestStore.copyForTransfer(original.0, scope: fixture.scope,
            sourceGenerationID: original.1.currentGenerationID, destinationGenerationID: destination)
        let targetContext = ModelContext(target); targetContext.insert(copy); try targetContext.save()
        let receipt = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: ModelContext(target)).first?.1)
        XCTAssertEqual(receipt.request, original.1.request)
        XCTAssertEqual(receipt.requestSHA256, original.1.requestSHA256)
        XCTAssertEqual(receipt.currentGenerationID, destination)
        XCTAssertEqual(receipt.transfers.count, 1)
        XCTAssertEqual(try ManualPendingAtomicRequestStore.protectedChangeIDs(context: ModelContext(target)), original.1.request.changeIDs)
        XCTAssertThrowsError(try ManualPendingAtomicRequestStore.copyForTransfer(copy, scope: fixture.scope,
            sourceGenerationID: destination, destinationGenerationID: original.1.request.originGenerationID))
    }

    func testMalformedManualReceiptCannotBecomeUnprotected() async throws {
        let fixture = try await makeFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        fixture.remote.loseBatchResponse = true
        _ = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        let context = ModelContext(fixture.container)
        let record = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: context).first?.0)
        record.metadataPayloadJSON = "{}"; try context.save()
        XCTAssertThrowsError(try ManualPendingAtomicRequestStore.protectedChangeIDs(context: ModelContext(fixture.container)))
        XCTAssertThrowsError(try ManualPendingAtomicRequestStore.blockingChangeIDs(context: ModelContext(fixture.container), scope: fixture.scope))
    }

    func testIndependentDRemainsOutsideBaselineWhileOriginalAReceivesExactACK() async throws {
        let fixture = try await makeFixture(creating: false)
        let baselineIDs = Set(try ModelContext(fixture.container).fetch(FetchDescriptor<SupabaseCatalogBaselineRun>()).map(\.baselineRunID))
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        var later: LocalPendingChangeCASToken?
        fixture.remote.beforeResponse = {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
                ownerUserID: fixture.owner, defaults: fixture.defaults) { context in
                let product = Product(barcode: "MANUAL-INDEPENDENT-D", productName: "D unsent")
                context.insert(product)
                let change = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: fixture.owner,
                    storeIdentity: fixture.scope.storeIdentity).recordProductChange(product: product,
                        operation: .create, origin: .manualCatalogSave, changedFields: ["barcode", "productName"]))
                try context.save(); later = LocalPendingChangeCASToken(change)
            }
        }
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(result.status, .completedBaselineRefreshFailed)
        XCTAssertNil(result.baselineRunID)
        XCTAssertEqual(Set(try ModelContext(fixture.container).fetch(FetchDescriptor<SupabaseCatalogBaselineRun>()).map(\.baselineRunID)), baselineIDs)
        XCTAssertEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        let token = try XCTUnwrap(later)
        let read = ModelContext(fixture.container)
        XCTAssertTrue(token.matches(try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == token.changeID })))
        XCTAssertTrue(try ManualPendingAtomicRequestStore.records(context: read).isEmpty)
        XCTAssertEqual(fixture.remote.businessEntries, 1)
        XCTAssertTrue(Task126OwnerStoreGate.hasCurrentLocalBodyProof(fixture.container))
    }

    func testPriceIdentityAndExactACKHaveOneDurableCommitBoundary() async throws {
        let fixture = try await makePriceFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        let payload = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan, expectedShopID: fixture.scope.shopID)
        let original = LocalPendingManualDispatchSnapshot(scope: fixture.scope, tokens: [try fixture.token()])
        let store = LocalPendingAggregatedPushStateStore(context: ModelContext(fixture.container))
        let sent = try store.markSent(snapshot: original, ownerUserID: fixture.owner, defaults: fixture.defaults)
        // The exact response-link step is deliberately aborted before the one
        // final save. No remote ID or ACK can survive this local transaction.
        XCTAssertThrowsError(try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults, expectedAutomaticScope: fixture.scope) { context in
            let count = try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads(payload.payloads,
                context: context, saveChanges: false)
            XCTAssertEqual(count, 1)
            throw LocalPendingManualDispatchError.staleBatch
        })
        let read = ModelContext(fixture.container)
        XCTAssertNil(try XCTUnwrap(read.fetch(FetchDescriptor<ProductPrice>()).first).remoteID)
        XCTAssertEqual(try fixture.token(), sent.tokens.first)
        XCTAssertTrue(Task126OwnerStoreGate.hasCurrentLocalBodyProof(fixture.container))
        try store.finish(snapshot: sent, ownerUserID: fixture.owner, status: .acknowledged,
            defaults: fixture.defaults, verifiedPricePayloads: payload.payloads)
        XCTAssertEqual(try XCTUnwrap(ModelContext(fixture.container).fetch(FetchDescriptor<ProductPrice>()).first).remoteID,
            payload.payloads.first?.id)
        XCTAssertEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        XCTAssertTrue(Task126OwnerStoreGate.hasCurrentLocalBodyProof(fixture.container))
        XCTAssertEqual(fixture.remote.insertEntries, 0, "This test qualifies only the local atomic commit boundary")
    }

    func testReadBackFailureCannotMasqueradeAsBaselineOnlyFailureAndACK() async throws {
        let fixture = try await makeFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        fixture.remote.failReadBack = true
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(result.status, .partial)
        XCTAssertEqual(fixture.remote.businessEntries, 1)
        XCTAssertEqual(fixture.remote.readbackEntries, 1)
        XCTAssertEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.sent.rawValue)
        let records = try ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container))
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.0.lastErrorKindRaw, ManualPendingAtomicRequestStore.Phase.inFlight.rawValue)
        XCTAssertEqual(records.first?.1.protectedChangeIDs, [fixture.changeID])
    }

    func testPriceACKAndVerifiedRemoteBodyQualifyAfterControllerReopen() async throws {
        let fixture = try await makePriceFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        let result = try await fixture.provider.push(plan: plan, ownerUserID: fixture.owner)
        XCTAssertTrue(result.isVerifiedSuccess)
        XCTAssertEqual(fixture.remote.insertEntries, 1)
        XCTAssertEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        let manifest = try XCTUnwrap(fixture.controller.active.manifest)
        var base = try XCTUnwrap(fixture.container.configurations.first?.url)
        for _ in manifest.relativeStorePath.split(separator: "/") { base.deleteLastPathComponent() }
        let reopened = try SyncStoreGenerationController(
            repository: SyncStoreGenerationRepository(baseDirectory: base, defaults: fixture.defaults), defaults: fixture.defaults)
        let qualified = await reopened.awaitLocalBodyQualification()
        XCTAssertTrue(qualified)
        let context = ModelContext(reopened.modelContainer)
        XCTAssertTrue(try ManualPendingAtomicRequestStore.records(context: context).isEmpty)
        let price = try XCTUnwrap(context.fetch(FetchDescriptor<ProductPrice>()).first)
        XCTAssertEqual(price.remoteID, fixture.remote.payloads.first?.id)
        let pending = try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == fixture.changeID })
        XCTAssertEqual(pending.status, .acknowledged)
    }

    func testPriceFixtureBodyIsQualifiedBeforeAnyManualPriceDispatch() async throws {
        let fixture = try await makePriceFixture()
        let manifest = try XCTUnwrap(fixture.controller.active.manifest)
        let storeURL = try XCTUnwrap(fixture.container.configurations.first?.url)
        var validationError: String?
        do {
            try LocalCatalogBodyProofStore.validate(container: fixture.container,
                manifest: manifest, storeURL: storeURL)
        } catch {
            validationError = String(describing: error)
        }
        XCTAssertNil(validationError, "A price ACK test requires an already qualified parent fixture")
        XCTAssertEqual(fixture.remote.insertEntries, 0)
        XCTAssertNil(try fixture.token().lastAttemptAt)
        XCTAssertEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.pending.rawValue)
    }

    func testProductionSnapshotCaptureAdmitsBothInputOrders() async throws {
        for reversed in [false, true] {
            // The helper creates a fresh qualified fixture for each order.
            try await assertProductionSnapshotCaptureAdmitsInputOrder(reversed: reversed)
        }
    }

    func testDirectSnapshotWithReversedTokensRejectsWithoutHTTPOrIntentMutation() async throws {
        let fixture = try await makeFixture()
        try addSibling(fixture)
        let context = ModelContext(fixture.container)
        let rows = try context.fetch(FetchDescriptor<LocalPendingChange>()).sorted { $0.changeID < $1.changeID }
        XCTAssertEqual(rows.count, 2)
        let originals = rows.map(LocalPendingChangeCASToken.init)
        let reversed = Array(originals.reversed())
        XCTAssertNotEqual(reversed.map(\.changeID), originals.map(\.changeID),
            "The negative always supplies reversed ranks; it never depends on random UUID order")
        let raw = LocalPendingManualDispatchSnapshot(scope: fixture.scope, tokens: reversed)
        XCTAssertThrowsError(try LocalPendingAggregatedPushStateStore(context: context)
            .markSent(snapshot: raw, ownerUserID: fixture.owner, defaults: fixture.defaults)) { error in
            guard let failure = error as? LocalPendingManualDispatchError else {
                XCTFail("Expected the exact-batch guard, received \(String(reflecting: type(of: error)))")
                return
            }
            switch failure {
            case .staleBatch: break
            }
        }
        let read = ModelContext(fixture.container)
        XCTAssertEqual(try read.fetch(FetchDescriptor<LocalPendingChange>()).map(LocalPendingChangeCASToken.init)
            .sorted { $0.changeID < $1.changeID }, originals,
            "Rejected raw input cannot mark either revision sent or rewrite any intent field")
        XCTAssertTrue(try ManualPendingAtomicRequestStore.records(context: read).isEmpty)
        XCTAssertEqual(fixture.remote.businessEntries, 0)
    }

    private func assertProductionSnapshotCaptureAdmitsInputOrder(reversed: Bool) async throws {
        let fixture = try await makeFixture()
        try addSibling(fixture)
        let context = ModelContext(fixture.container)
        let rows = try context.fetch(FetchDescriptor<LocalPendingChange>()).sorted { $0.changeID < $1.changeID }
        XCTAssertEqual(rows.count, 2)
        let originals = rows.map(LocalPendingChangeCASToken.init)
        let input = reversed ? Array(rows.reversed()) : rows
        XCTAssertEqual(input.map(\.changeID), reversed ? Array(originals.map(\.changeID).reversed()) : originals.map(\.changeID))
        let snapshot = LocalPendingManualDispatchSnapshot.capture(changes: input,
            ownerUserID: fixture.owner, defaults: fixture.defaults)
        XCTAssertEqual(snapshot.scope, fixture.scope)
        XCTAssertEqual(snapshot.tokens, originals,
            "Production capture canonicalizes order without changing any original token value")
        let sent = try LocalPendingAggregatedPushStateStore(context: context)
            .markSent(snapshot: snapshot, ownerUserID: fixture.owner, defaults: fixture.defaults)
        XCTAssertEqual(sent.tokens.map(\.changeID), originals.map(\.changeID))
        for (original, admitted) in zip(originals, sent.tokens) {
            XCTAssertEqual(admitted.statusRaw, LocalPendingChangeStatus.sent.rawValue)
            XCTAssertNotNil(admitted.lastAttemptAt)
            XCTAssertEqual(admitted.logicalKey, original.logicalKey)
            XCTAssertEqual(admitted.idempotencyKey, original.idempotencyKey)
            XCTAssertEqual(admitted.changedFieldsRaw, original.changedFieldsRaw)
            XCTAssertEqual(admitted.intendedFingerprintHash, original.intendedFingerprintHash)
            XCTAssertEqual(admitted.baselineFingerprintHash, original.baselineFingerprintHash)
        }
        let read = ModelContext(fixture.container)
        XCTAssertEqual(try read.fetch(FetchDescriptor<LocalPendingChange>()).map(LocalPendingChangeCASToken.init)
            .sorted { $0.changeID < $1.changeID }, sent.tokens)
        XCTAssertTrue(try ManualPendingAtomicRequestStore.records(context: read).isEmpty)
        XCTAssertEqual(fixture.remote.businessEntries, 0, "Local admission is not a remote acknowledgement")
    }

    func testConfirmedPartialRequestCoverageCannotAcknowledgeUnsentBatchMember() async throws {
        let fixture = try await makeFixture()
        try addSibling(fixture)
        let originals = try ModelContext(fixture.container).fetch(FetchDescriptor<LocalPendingChange>())
        let snapshot = LocalPendingManualDispatchSnapshot.capture(changes: originals,
            ownerUserID: fixture.owner, defaults: fixture.defaults)
        let sent = try LocalPendingAggregatedPushStateStore(context: ModelContext(fixture.container))
            .markSent(snapshot: snapshot, ownerUserID: fixture.owner, defaults: fixture.defaults)
        let member = try XCTUnwrap(sent.tokens.first)
        let product = try XCTUnwrap(ModelContext(fixture.container).fetch(FetchDescriptor<Product>()).first {
            LocalPendingChangeLogicalKey.product(remoteID: $0.remoteID, barcode: $0.barcode) == member.logicalKey
        })
        let payload: [[String: String]] = [["owner_user_id": fixture.owner.uuidString.lowercased(),
            "shop_id": fixture.scope.shopID.uuidString.lowercased(), "barcode": product.barcode, "product_name": product.productName ?? ""]]
        var wire = URLRequest(url: URL(string: "https://manual-cas.invalid/rest/v1/inventory_products")!)
        wire.httpMethod = "POST"; wire.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let batchID = UUID()
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults, expectedAutomaticScope: fixture.scope) { context in
            let witness = try ManualPendingAtomicRequestStore.prepareExact(request: wire, requestID: UUID(), batchID: batchID,
                members: sent.tokens, requestMemberIDs: [member.changeID], scope: fixture.scope,
                generationID: try XCTUnwrap(fixture.controller.active.manifest?.generationID), context: context)
            try ManualPendingAtomicRequestStore.beginDispatch(witness: witness, context: context, scope: fixture.scope)
            try ManualPendingAtomicRequestStore.confirmResponse(witness: witness, context: context, scope: fixture.scope)
            XCTAssertThrowsError(try ManualPendingAtomicRequestStore.removeConfirmedBatch(batchID: batchID,
                members: sent.tokens, context: context, scope: fixture.scope))
        }
        let read = ModelContext(fixture.container)
        XCTAssertEqual(try ManualPendingAtomicRequestStore.protectedChangeIDs(context: read), Set(sent.tokens.map(\.changeID)))
        XCTAssertTrue(try read.fetch(FetchDescriptor<LocalPendingChange>()).allSatisfy { $0.status == .sent })
        XCTAssertEqual(fixture.remote.businessEntries, 0, "Controlled receipt test is not a remote ACK proof")
    }

    func testExactReadOnlyLinkAcknowledgesOnlyAfterScopedRowAndCompleteReadBack() async throws {
        let fixture = try await makeFixture(linkExisting: true)
        let original = try fixture.token()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        XCTAssertEqual(plan.writeCandidates.count, 1)
        XCTAssertEqual(plan.writeCandidates.first?.action, .dryRunLinkCandidate)
        let result = await fixture.provider.execute(plan: plan, ownerUserID: fixture.owner)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.productLinks, 1)
        XCTAssertEqual(fixture.remote.businessEntries, 0)
        XCTAssertEqual(fixture.remote.linkReadEntries, 1)
        XCTAssertEqual(fixture.remote.readbackEntries, 1)
        XCTAssertEqual(try fixture.product().remoteID, fixture.originalRemote?.id)
        let acknowledged = try fixture.token()
        XCTAssertEqual(acknowledged.changeID, original.changeID)
        XCTAssertEqual(acknowledged.idempotencyKey, original.idempotencyKey)
        XCTAssertEqual(acknowledged.statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        XCTAssertTrue(try ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container)).isEmpty)
    }

    func testActualPriceFactoryUppercaseWireIsSealedWithoutReencoding() async throws {
        let fixture = try await makePriceFixture()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan, expectedShopID: fixture.scope.shopID)
        XCTAssertEqual(snapshot.payloads.map(\.type), ["RETAIL"])
        var observed = false
        fixture.remote.beforeInsertResponse = {
            let records = try ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container))
            XCTAssertEqual(records.count, 1)
            let receipt = try XCTUnwrap(records.first?.1)
            let wire = try XCTUnwrap(fixture.remote.lastWireBody)
            XCTAssertEqual(receipt.request.body, wire)
            let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: wire) as? [[String: Any]])
            XCTAssertEqual(rows.first?["type"] as? String, "RETAIL")
            XCTAssertEqual(receipt.request.requestMemberIDs, [fixture.changeID])
            observed = true
        }
        let result = try await fixture.provider.push(plan: plan, ownerUserID: fixture.owner)
        XCTAssertTrue(observed)
        XCTAssertTrue(result.isVerifiedSuccess)
        XCTAssertEqual(fixture.remote.insertEntries, 1)
        XCTAssertEqual(try fixture.token().statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
    }

    func testActualPriceFactoryFractionalLocalDateKeepsOriginalTokenAndExactWire() async throws {
        let date = Date(timeIntervalSince1970: 1_792_800_000.375)
        let fixture = try await makePriceFixture(effectiveAt: date)
        let original = try fixture.token()
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        let payload = try XCTUnwrap(ProductPriceManualPushSnapshotFactory.makeSnapshot(
            from: plan, expectedShopID: fixture.scope.shopID).payloads.first)
        XCTAssertEqual(payload.effectiveAt, ProductPriceEffectiveAtCanonicalizer.canonicalString(from: date))
        XCTAssertNil(SupabaseRemoteDateParser.parse(payload.effectiveAt), "Manual wire dates use the established non-ISO canonical format")
        let rounded = try XCTUnwrap(ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: payload.effectiveAt))
        XCTAssertNotEqual(original.logicalKey, LocalPendingChangeLogicalKey.productPrice(
            productRemoteID: fixture.productID, productBarcode: "", type: .retail, effectiveAt: rounded))
        var observed = false
        fixture.remote.beforeInsertResponse = {
            let record = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container)).first?.1)
            XCTAssertEqual(record.request.body, fixture.remote.lastWireBody)
            XCTAssertEqual(record.request.requestMemberIDs, [original.changeID])
            XCTAssertEqual(record.request.members.first?.logicalKey, original.logicalKey)
            XCTAssertEqual(record.request.members.first?.intendedFingerprintHash, original.intendedFingerprintHash)
            observed = true
        }
        let result = try await fixture.provider.push(plan: plan, ownerUserID: fixture.owner)
        XCTAssertTrue(result.isVerifiedSuccess)
        XCTAssertTrue(observed)
        XCTAssertEqual(fixture.remote.insertEntries, 1)
        let acknowledged = try fixture.token()
        XCTAssertEqual(acknowledged.statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        XCTAssertEqual(acknowledged.logicalKey, original.logicalKey)
        XCTAssertEqual(acknowledged.intendedFingerprintHash, original.intendedFingerprintHash)
    }

    func testPriceWireAmountDriftCannotCreateDurableAttemptForOriginalToken() async throws {
        let fixture = try await makePriceFixture(effectiveAt: Date(timeIntervalSince1970: 1_792_800_000.375))
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        let payload = try XCTUnwrap(ProductPriceManualPushSnapshotFactory.makeSnapshot(
            from: plan, expectedShopID: fixture.scope.shopID).payloads.first)
        let original = LocalPendingManualDispatchSnapshot(scope: fixture.scope, tokens: [try fixture.token()])
        let sent = try LocalPendingAggregatedPushStateStore(context: ModelContext(fixture.container))
            .markSent(snapshot: original, ownerUserID: fixture.owner, defaults: fixture.defaults)
        let atomic = try ManualPendingAtomicBatchExecution(snapshot: sent, container: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults)
        let changed = ProductPriceManualPushPayload(id: payload.id, ownerUserID: payload.ownerUserID,
            shopID: payload.shopID, productID: payload.productID, type: payload.type,
            price: 21, priceCanonical: "21", effectiveAt: payload.effectiveAt,
            source: payload.source, note: payload.note, createdAt: payload.createdAt)
        XCTAssertThrowsError(try ManualPendingAtomicDispatchContext.$beforeDispatch.withValue({ try atomic.beforeDispatch($0) }) {
            try manualCASBeforeDispatch([changed], table: "inventory_product_prices", shop: fixture.scope.shopID)
        }) { XCTAssertTrue($0 is LocalPendingManualDispatchError) }
        XCTAssertEqual(try fixture.token(), sent.tokens.first)
        XCTAssertTrue(try ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container)).isEmpty)
        XCTAssertEqual(fixture.remote.insertEntries, 0)
    }

    func testTwoOriginalPriceFractionsWithSameWireFieldsAreAmbiguous() async throws {
        let fixture = try await makePriceFixture(effectiveAt: Date(timeIntervalSince1970: 1_792_800_000.125))
        let plan = try await fixture.provider.makePushPlan(ownerUserID: fixture.owner)
        let payloads = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan, expectedShopID: fixture.scope.shopID).payloads
        var second: LocalPendingChangeCASToken?
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults) { context in
            let parent = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first { $0.remoteID == fixture.productID })
            let date = Date(timeIntervalSince1970: 1_792_800_000.875)
            let price = ProductPrice(type: .retail, price: 20, effectiveAt: date, createdAt: date, product: parent)
            context.insert(price)
            let change = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: fixture.owner,
                storeIdentity: fixture.scope.storeIdentity).recordProductPriceChange(price: price, origin: .productPriceSave))
            try context.save()
            second = LocalPendingChangeCASToken(change)
        }
        let first = try fixture.token(), secondToken = try XCTUnwrap(second)
        XCTAssertNotEqual(first.logicalKey, secondToken.logicalKey)
        let localPrices = try ModelContext(fixture.container).fetch(FetchDescriptor<ProductPrice>())
        XCTAssertEqual(localPrices.count, 2)
        XCTAssertEqual(Set(localPrices.map { ProductPriceEffectiveAtCanonicalizer.canonicalString(from: $0.effectiveAt) }),
            [try XCTUnwrap(payloads.first?.effectiveAt)])
        XCTAssertEqual(Set(localPrices.map { ProductPriceEffectiveAtCanonicalizer.canonicalString(from: $0.createdAt) }),
            [try XCTUnwrap(payloads.first?.createdAt)])
        XCTAssertTrue(localPrices.allSatisfy { $0.price == payloads.first?.price && $0.type == .retail
            && $0.product?.remoteID == fixture.productID && $0.source == nil && $0.note == nil })
        // Exercise the final boundary independently as well: even two exact
        // admitted tokens must not be collapsed into one remote request member.
        let original = LocalPendingManualDispatchSnapshot(scope: fixture.scope,
            tokens: [first, secondToken].sorted { $0.changeID < $1.changeID })
        let sent = try LocalPendingAggregatedPushStateStore(context: ModelContext(fixture.container))
            .markSent(snapshot: original, ownerUserID: fixture.owner, defaults: fixture.defaults)
        let atomic = try ManualPendingAtomicBatchExecution(snapshot: sent, container: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults)
        XCTAssertThrowsError(try ManualPendingAtomicDispatchContext.$beforeDispatch.withValue({ try atomic.beforeDispatch($0) }) {
            try manualCASBeforeDispatch(payloads, table: "inventory_product_prices", shop: fixture.scope.shopID)
        }) { XCTAssertTrue($0 is LocalPendingManualDispatchError) }
        let read = ModelContext(fixture.container)
        XCTAssertEqual(try read.fetch(FetchDescriptor<LocalPendingChange>()).map(LocalPendingChangeCASToken.init)
            .sorted { $0.changeID < $1.changeID }, sent.tokens.sorted { $0.changeID < $1.changeID })
        XCTAssertTrue(try ManualPendingAtomicRequestStore.records(context: read).isEmpty)
        XCTAssertEqual(fixture.remote.insertEntries, 0)
    }

    private func addSibling(_ fixture: Fixture) throws {
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.owner, defaults: fixture.defaults) { context in
            let sibling = Product(barcode: "MANUAL-CAS-V3-SIBLING", productName: "Sibling original")
            context.insert(sibling)
            try LocalPendingChangeAccumulator(context: context, ownerUserID: fixture.owner,
                storeIdentity: fixture.scope.storeIdentity).recordProductChange(product: sibling,
                    operation: .create, origin: .manualCatalogSave, changedFields: ["barcode", "productName"])
            try context.save()
        }
    }

    private func makeFixture(creating: Bool = true, linkExisting: Bool = false,
        generatedPriceRemote: (any SupabaseProductPricePushDryRunRemoteFetching)? = nil) async throws -> Fixture {
        let local = try await makeQualifiedSyncStateFixture(includesAuth: true)
        let owner = try XCTUnwrap(local.authViewModel?.localMutationOwnerUserID)
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: local.defaults)
        let container = local.controller.modelContainer
        let barcode = "MANUAL-CAS-\(UUID().uuidString.lowercased())"
        var changeID = ""
        var originalRemote: RemoteInventoryProductRow!
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container,
            ownerUserID: owner, defaults: local.defaults) { context in
            let product: Product
            if creating {
                product = Product(barcode: barcode, productName: linkExisting ? "A original" : "Before A")
                context.insert(product)
                if linkExisting {
                    product.remoteID = UUID()
                    product.remoteUpdatedAt = SupabaseRemoteDateParser.parse("2026-10-23T20:00:00.123456Z")
                    try context.save()
                    _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(context: context, ownerUserUUID: owner)
                    originalRemote = Self.remoteRow(product, owner: owner, shop: scope.shopID)
                    product.remoteID = nil; product.remoteUpdatedAt = nil
                }
            } else {
                product = Product(barcode: barcode, remoteID: UUID(),
                    remoteUpdatedAt: SupabaseRemoteDateParser.parse("2026-10-23T20:00:00.123456Z"),
                    productName: "Before A")
                context.insert(product)
                try context.save()
                // Controlled established remote row, committed using the actual
                // baseline writer inside the qualified local store fence.
                _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(context: context, ownerUserUUID: owner)
                originalRemote = Self.remoteRow(product, owner: owner, shop: scope.shopID)
            }
            let base = creating ? nil : LocalPendingChangeLogicalKey.productFingerprintHash(product)
            product.productName = "A original"
            changeID = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: owner,
                storeIdentity: scope.storeIdentity).recordProductChange(product: product,
                    operation: creating ? .create : .update, origin: .manualCatalogSave,
                    changedFields: creating ? ["barcode", "productName"] : ["productName"],
                    baselineFingerprintHash: base)).changeID
            try context.save()
        }
        let remote = ManualCASRemote(owner: owner, shop: scope.shopID)
        if linkExisting { remote.existingLinkRow = originalRemote }
        let authorization = ManualCASAuthorization()
        let adapter = SyncCatalogPushAdapter(context: ModelContext(container),
            manualPushService: SupabaseManualPushService(remote: remote),
            generatedPriceRemote: generatedPriceRemote, defaults: local.defaults)
        let provider = DeviceGuardedManualCatalogPushProvider(delegate: adapter, deviceAuthorization: authorization)
        return Fixture(defaults: local.defaults, controller: local.controller, owner: owner, scope: scope,
            barcode: barcode, changeID: changeID, originalRemote: originalRemote,
            remote: remote, authorization: authorization, provider: provider)
    }

    private static func remoteRow(_ p: Product, owner: UUID, shop: UUID) -> RemoteInventoryProductRow {
        RemoteInventoryProductRow(id: p.remoteID!, ownerUserID: owner, shopID: shop,
            barcode: p.barcode, itemNumber: p.itemNumber, productName: p.productName,
            secondProductName: p.secondProductName, purchasePrice: p.purchasePrice, retailPrice: p.retailPrice,
            supplierID: p.supplier?.remoteID, categoryID: p.category?.remoteID, stockQuantity: p.stockQuantity,
            updatedAt: "2026-10-23T20:00:00.123456Z", deletedAt: nil)
    }

    @MainActor
    private struct Fixture {
        let defaults: UserDefaults
        let controller: SyncStoreGenerationController
        let owner: UUID
        let scope: Task126VerifiedOwnerStoreScope
        let barcode: String
        let changeID: String
        let originalRemote: RemoteInventoryProductRow?
        let remote: ManualCASRemote
        let authorization: ManualCASAuthorization
        let provider: DeviceGuardedManualCatalogPushProvider
        var container: ModelContainer { controller.modelContainer }
        func token() throws -> LocalPendingChangeCASToken {
            let context = ModelContext(container)
            return LocalPendingChangeCASToken(try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == changeID }))
        }
        func product() throws -> Product {
            try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Product>()).first { $0.barcode == barcode })
        }
        func save(name: String) throws -> LocalPendingChangeCASToken {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container,
                ownerUserID: owner, defaults: defaults) { context in
                let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first { $0.barcode == barcode })
                let baseline = LocalPendingChangeLogicalKey.productFingerprintHash(product)
                product.productName = name
                let row = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: owner,
                    storeIdentity: scope.storeIdentity).recordProductChange(product: product,
                        operation: product.remoteID == nil ? .create : .update, origin: .manualCatalogSave,
                        changedFields: ["productName"], baselineFingerprintHash: baseline))
                try context.save()
                return LocalPendingChangeCASToken(row)
            }
        }
    }
}

@MainActor
private final class ManualCASAuthorization: ShopDeviceAuthorizationChecking {
    var duringExecute: (@MainActor () async throws -> Void)?
    private(set) var executeEntries = 0
    private var snapshot: ShopDeviceAuthorizationSnapshot {
        .init(status: "active", code: "active", canWrite: true, serverTime: nil, lastSeenAt: nil,
            reasonCode: "active", recommendedAction: "", checkedAt: Date())
    }
    func registerCurrentOwnerDevice(reason: String, force: Bool) async -> Bool { true }
    func registerHeartbeatAndCheck(reason: String) async -> ShopDeviceAuthorizationSnapshot { snapshot }
    func currentOwnerDeviceStatus(reason: String, force: Bool) async -> ShopDeviceAuthorizationSnapshot { snapshot }
    func ensureActiveForCloudWrite(reason: String) async throws -> ShopDeviceAuthorizationSnapshot {
        if reason == "manual_catalog_execute" || reason == "manual_price_push" {
            executeEntries += 1
            await Task.yield()
            try await duringExecute?()
        }
        return snapshot
    }
}

@MainActor
private final class ManualCASConflictReader: SyncAutomaticCatalogIncrementalReading {
    let row: RemoteInventoryProductRow
    private(set) var productFetches = 0
    private(set) var emptyRelationFetches = 0
    init(row: RemoteInventoryProductRow) { self.row = row }
    func fetchCatalogByIDs(supplierIDs: Set<UUID>, categoryIDs: Set<UUID>, productIDs: Set<UUID>) async throws
        -> (suppliers: [RemoteInventorySupplierRow], categories: [RemoteInventoryCategoryRow], products: [RemoteInventoryProductRow]) {
        guard supplierIDs.isEmpty, categoryIDs.isEmpty else {
            throw CatalogConflictResolutionError.remoteUnavailable
        }
        // The actual incremental service always performs the relation fetch,
        // including an empty request for a product with no relations.
        if productIDs.isEmpty {
            emptyRelationFetches += 1
            return ([], [], [])
        }
        guard productIDs == [row.id] else { throw CatalogConflictResolutionError.remoteUnavailable }
        productFetches += 1
        return ([], [], [row])
    }
}

@MainActor
private final class ManualCASRemote: SupabaseManualPushRemoteGateway {
    let owner: UUID
    let shop: UUID
    let createdID = UUID()
    let createdSupplierID = UUID()
    var loseBatchResponse = false
    var duplicateCreateResponse = false
    var failReadBack = false
    var existingLinkRow: RemoteInventoryProductRow?
    private(set) var linkReadEntries = 0
    private(set) var lastWireBody: Data?
    private(set) var productBatchSizes: [Int] = []
    private(set) var createdSupplierIDs: [UUID?] = []
    var beforeResponse: (@MainActor () async throws -> Void)?
    var allowSupplierCreate = false
    var beforeSupplierResponse: (@MainActor () async throws -> Void)?
    private(set) var supplierEntries = 0
    private(set) var businessEntries = 0
    private(set) var readbackEntries = 0
    private(set) var createdNames: [String?] = []
    private(set) var updatedNames: [String?] = []
    private var rows: [UUID: RemoteInventoryProductRow] = [:]
    private var suppliers: [UUID: RemoteInventorySupplierRow] = [:]
    init(owner: UUID, shop: UUID) { self.owner = owner; self.shop = shop }
    func createProducts(_ payloads: [SupabaseManualPushProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        lastWireBody = try manualCASBeforeDispatch(payloads, table: "inventory_products", shop: shop)
        businessEntries += 1
        productBatchSizes.append(payloads.count)
        if loseBatchResponse { throw URLError(.networkConnectionLost) }
        guard payloads.count == 1 || duplicateCreateResponse else { throw LocalPendingManualDispatchError.staleBatch }
        let p = payloads[0]
        createdNames.append(p.productName)
        createdSupplierIDs.append(p.supplierID)
        let row = RemoteInventoryProductRow(id: createdID, ownerUserID: p.ownerUserID, shopID: shop,
            barcode: p.barcode, itemNumber: p.itemNumber, productName: p.productName, secondProductName: p.secondProductName,
            purchasePrice: p.purchasePrice, retailPrice: p.retailPrice, supplierID: p.supplierID,
            categoryID: p.categoryID, stockQuantity: p.stockQuantity, updatedAt: "2026-10-23T21:00:00.123456Z", deletedAt: nil)
        rows[row.id] = row
        try await beforeResponse?()
        return duplicateCreateResponse ? Array(repeating: row, count: payloads.count) : [row]
    }
    func updateProduct(id: UUID, payload p: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        lastWireBody = try manualCASBeforeDispatch(p, table: "inventory_products", shop: shop, id: id)
        businessEntries += 1
        updatedNames.append(p.productName)
        let row = RemoteInventoryProductRow(id: id, ownerUserID: owner, shopID: shop,
            barcode: p.barcode ?? "", itemNumber: p.itemNumber, productName: p.productName, secondProductName: p.secondProductName,
            purchasePrice: p.purchasePrice, retailPrice: p.retailPrice, supplierID: p.supplierID,
            categoryID: p.categoryID, stockQuantity: p.stockQuantity, updatedAt: "2026-10-23T21:00:00.123456Z", deletedAt: p.deletedAt)
        rows[row.id] = row
        try await beforeResponse?()
        return row
    }
    func verifyReadBack(expectation: SupabaseManualPushReadBackExpectation) async throws {
        readbackEntries += 1
        if failReadBack { throw URLError(.networkConnectionLost) }
        XCTAssertEqual(Set(suppliers.keys), Set(expectation.supplierFingerprintsByID.keys))
        XCTAssertTrue(expectation.categoryFingerprintsByID.isEmpty)
        XCTAssertEqual(Set(rows.keys), Set(expectation.productFingerprintsByID.keys))
        for (id, expected) in expectation.productFingerprintsByID {
            let row = try XCTUnwrap(rows[id])
            XCTAssertEqual(expected, ManualPushFingerprintNormalizer.product(barcode: row.barcode,
                itemNumber: row.itemNumber, productName: row.productName, secondProductName: row.secondProductName,
                purchasePrice: row.purchasePrice, retailPrice: row.retailPrice, stockQuantity: row.stockQuantity,
                supplierRemoteID: row.supplierID, categoryRemoteID: row.categoryID))
        }
    }
    func createSuppliers(_ payloads: [SupabaseManualPushSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        _ = try manualCASBeforeDispatch(payloads, table: "inventory_suppliers", shop: shop)
        businessEntries += 1
        supplierEntries += 1
        guard allowSupplierCreate, payloads.count == 1 else { throw LocalPendingManualDispatchError.staleBatch }
        let p = payloads[0]
        let row = RemoteInventorySupplierRow(id: createdSupplierID, ownerUserID: p.ownerUserID, shopID: shop, name: p.name,
            updatedAt: "2026-10-23T21:00:00.123456Z", deletedAt: nil)
        suppliers[row.id] = row
        try await beforeSupplierResponse?()
        return [row]
    }
    func updateSupplier(id: UUID, payload: SupabaseManualPushSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        businessEntries += 1; throw LocalPendingManualDispatchError.staleBatch
    }
    func verifySupplier(id: UUID, normalizedName: String) async throws -> RemoteInventorySupplierRow { throw LocalPendingManualDispatchError.staleBatch }
    func createCategories(_ payloads: [SupabaseManualPushCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        businessEntries += 1; throw LocalPendingManualDispatchError.staleBatch
    }
    func updateCategory(id: UUID, payload: SupabaseManualPushCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        businessEntries += 1; throw LocalPendingManualDispatchError.staleBatch
    }
    func verifyCategory(id: UUID, normalizedName: String) async throws -> RemoteInventoryCategoryRow { throw LocalPendingManualDispatchError.staleBatch }
    func verifyProduct(id: UUID, normalizedBarcode: String) async throws -> RemoteInventoryProductRow {
        var wire = URLRequest(url: URL(string: "https://manual-cas.invalid/rest/v1/inventory_products")!)
        wire.httpMethod = "GET"
        try ManualPendingAtomicDispatchContext.beforeDispatch?(wire)
        linkReadEntries += 1
        guard let row = existingLinkRow, row.id == id, row.barcode == normalizedBarcode else {
            throw LocalPendingManualDispatchError.staleBatch
        }
        rows[row.id] = row
        return row
    }
}

@MainActor
private final class ManualCASPriceRemote: SupabaseProductPriceKeysetFetching, SupabaseProductPriceDeletedProductFetching,
    SupabaseProductPriceManualPushRemoteAccessing, SupabaseProductPricePushDryRunRemoteFetching {
    var beforeInsertResponse: (@MainActor () async throws -> Void)?
    private(set) var insertEntries = 0
    private(set) var lastWireBody: Data?
    private(set) var productEntries = 0
    private(set) var payloads: [ProductPriceManualPushPayload] = []
    private var rows: [RemoteInventoryProductPriceRow] = []
    func fetchProductPricesPreviewPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] { [] }
    func fetchProductPricesPreviewPage(afterID: UUID?, limit: Int) async throws -> [RemoteInventoryProductPriceRow] { [] }
    func fetchDeletedProductIDs(pageSize: Int) async throws -> Set<UUID> { [] }
    func fetchProductPricesForPushDryRunDedupePage(ownerUserID: UUID, productIDs: [UUID], from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] { [] }
    func insertProductPriceManualPushPayloads(_ payloads: [ProductPriceManualPushPayload]) async throws -> [RemoteInventoryProductPriceRow] {
        lastWireBody = try manualCASBeforeDispatch(payloads, table: "inventory_product_prices", shop: try XCTUnwrap(payloads.first?.shopID))
        insertEntries += 1
        self.payloads = payloads
        rows = payloads.map { .init(id: $0.id, ownerUserID: $0.ownerUserID, shopID: $0.shopID,
            productID: $0.productID, type: $0.type, price: $0.price, priceCanonical: $0.priceCanonical,
            effectiveAt: $0.effectiveAt, source: $0.source, note: $0.note, createdAt: $0.createdAt,
            updatedAt: "2026-10-23T21:00:00.123456Z") }
        try await beforeInsertResponse?()
        return rows
    }
    func fetchProductPricesForManualPushVerificationPage(ownerUserID: UUID, productIDs: [UUID], from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] { rows }
    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        productEntries += 1
        throw LocalPendingManualDispatchError.staleBatch
    }
}

@MainActor
private final class ManualCASGeneratedPrices: SupabaseProductPricePushDryRunRemoteFetching {
    var shopID: UUID?
    var beforeReturn: (@MainActor () throws -> Void)?
    private(set) var reads = 0
    func fetchProductPricesForPushDryRunDedupePage(ownerUserID: UUID, productIDs: [UUID], from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        reads += 1
        try beforeReturn?()
        return productIDs.map { .init(id: UUID(), ownerUserID: ownerUserID, shopID: shopID,
            productID: $0, type: "RETAIL", price: 20, priceCanonical: "20",
            effectiveAt: "2026-10-23T21:00:00.000000Z", source: nil, note: nil,
            createdAt: "2026-10-23T21:00:00.000000Z") }
    }
}

/// Controlled wire boundary for actual adapter/service tests. This uses test
/// encoding, not the SDK: separate SDK tests establish the actual wire seam.
@MainActor
@discardableResult
private func manualCASBeforeDispatch(_ payload: some Encodable, table: String, shop: UUID,
                                     id: UUID? = nil) throws -> Data {
    let encoded = try JSONEncoder().encode(payload)
    var object = try JSONSerialization.jsonObject(with: encoded)
    if id == nil, var rows = object as? [[String: Any]] {
        for index in rows.indices { rows[index]["shop_id"] = shop.uuidString.lowercased() }
        object = rows
    }
    let body = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    var components = URLComponents(string: "https://manual-cas.invalid/rest/v1/" + table)!
    if let id {
        components.queryItems = [URLQueryItem(name: "id", value: "eq." + id.uuidString.lowercased()),
            URLQueryItem(name: "shop_id", value: "eq." + shop.uuidString.lowercased()),
            URLQueryItem(name: "owner_user_id", value: "eq." + (Task126OwnerStoreGate.currentAutomaticScope?.ownerUserID.uuidString.lowercased() ?? ""))]
    }
    var wire = URLRequest(url: components.url!)
    wire.httpMethod = id == nil ? "POST" : "PATCH"; wire.httpBody = body
    wire.setValue("application/json", forHTTPHeaderField: "Content-Type")
    wire.setValue("return=representation", forHTTPHeaderField: "Prefer")
    wire.setValue("never-persist-test-secret", forHTTPHeaderField: "Authorization")
    try ManualPendingAtomicDispatchContext.beforeDispatch?(wire)
    return body
}
