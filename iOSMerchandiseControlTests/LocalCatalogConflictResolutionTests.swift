import Foundation
import SwiftData
import XCTest
@testable import iOSMerchandiseControl

/// File-backed transaction tests. Scope/release and remote rows are controlled
/// fixtures; these tests do not claim an authenticated backend or process kill.
@MainActor
final class LocalCatalogConflictResolutionTests: XCTestCase {
    func testSealedNoOpAdoptionReopensThenNormalSaveContainsOnlyNewIntent() throws {
        let fixture = try Fixture(rejected: true)
        let review = try fixture.review(remoteName: "Saved A")
        let original = review.pending
        let beforeSeal = try fixture.sealBytes()
        XCTAssertEqual(try fixture.resolve(review, choice: .adoptRemote), .adoptedRemote)
        try fixture.reopen()
        XCTAssertEqual(try fixture.resolved(), [original.changeID])
        XCTAssertEqual(try fixture.changes().count, 1)
        XCTAssertEqual(try fixture.token(original.changeID), original, "A remains byte-equivalent, never ACKed")
        XCTAssertEqual(try fixture.sealBytes(), beforeSeal)
        XCTAssertEqual(try fixture.receipts().count, 1, "No-op business still writes a durable decision")
        XCTAssertEqual(try fixture.snapshot().pendingCatalogChangeCount, 0)

        let next = try fixture.normalSaveItem("Only B")
        XCTAssertNotEqual(next.changeID, original.changeID)
        XCTAssertNotEqual(next.idempotencyKey, original.idempotencyKey)
        XCTAssertEqual(next.changedFieldsRaw, "itemnumber")
        XCTAssertEqual(next.baselineFingerprintHash, review.remote.fingerprint)
        try fixture.reopen()
        XCTAssertEqual(try fixture.product().productName, "Saved A")
        XCTAssertEqual(try fixture.product().itemNumber, "Only B")
        XCTAssertEqual(try fixture.token(original.changeID), original)
        XCTAssertEqual(try fixture.sealBytes(), beforeSeal)
        XCTAssertEqual(try fixture.snapshot().pendingCatalogChangeCount, 1)
        XCTAssertEqual(try fixture.resolved(), [original.changeID])
    }

    func testAdoptionWithDifferentRemoteBodyDoesNotReuseRetiredFingerprintForSaveB() throws {
        let fixture = try Fixture(rejected: true)
        let review = try fixture.review(remoteName: "Remote replacement")
        XCTAssertNotEqual(review.pending.intendedFingerprintHash, review.remote.fingerprint)
        _ = try fixture.resolve(review, choice: .adoptRemote)
        try fixture.reopen()
        let next = try fixture.normalSaveItem("Disjoint B")
        XCTAssertEqual(next.baselineFingerprintHash, review.remote.fingerprint)
        XCTAssertNotEqual(next.baselineFingerprintHash, review.pending.intendedFingerprintHash)
        XCTAssertEqual(next.changedFieldsRaw, "itemnumber")
        XCTAssertEqual(try fixture.product().productName, "Remote replacement")
        XCTAssertEqual(try fixture.token(review.pending.changeID), review.pending)
    }

    func testUnknownSealedRequestAndClearedRejectionCannotBeRetiredByChoice() throws {
        let fixture = try Fixture(rejected: false)
        let review = try fixture.review(remoteName: "Remote replacement")
        let before = try fixture.sealBytes()
        XCTAssertThrowsError(try fixture.resolve(review, choice: .adoptRemote)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        XCTAssertEqual(try fixture.receipts().count, 0)
        XCTAssertEqual(try fixture.product().productName, "Saved A")
        XCTAssertEqual(try fixture.sealBytes(), before)
        XCTAssertEqual(try fixture.token(review.pending.changeID), review.pending)

        try fixture.recordRejection()
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.scope.ownerUserID) { context in
            try LocalPendingBusinessAttemptStore.clearRejectionBeforeDispatch(changeID: review.changeID, context: context)
        }
        try fixture.reopen()
        XCTAssertThrowsError(try fixture.resolve(review, choice: .adoptRemote)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        XCTAssertEqual(try fixture.receipts().count, 0)
        XCTAssertEqual(try fixture.sealBytes(), before)
    }

    func testNewerOrdinarySaveMakesOldReviewCASFailWithoutLosingEitherRevision() throws {
        let fixture = try Fixture(rejected: true)
        let review = try fixture.review(remoteName: "Remote replacement")
        let next = try fixture.normalSaveItem("Later B")
        let before = try fixture.sealBytes()
        XCTAssertThrowsError(try fixture.resolve(review, choice: .adoptRemote)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .localChanged)
        }
        try fixture.reopen()
        XCTAssertEqual(try fixture.product().itemNumber, "Later B")
        XCTAssertEqual(try fixture.product().productName, "Saved A")
        XCTAssertEqual(try fixture.token(review.changeID), review.pending)
        XCTAssertEqual(try fixture.token(next.changeID), next)
        XCTAssertEqual(try fixture.sealBytes(), before)
        XCTAssertTrue(try fixture.receipts().isEmpty)
    }

    func testTombstoneWithPriceChildPreservesProductChildLedgerAndAttention() throws {
        let fixture = try Fixture(rejected: true)
        let childID = try fixture.addPriceChild()
        let review = try fixture.review(remoteName: "Remote deleted", deletedAt: "2026-10-23T20:11:00.654321Z")
        let seal = try fixture.sealBytes()
        XCTAssertThrowsError(try fixture.resolve(review, choice: .adoptRemoteTombstone)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .destructiveDependencies)
        }
        try fixture.reopen()
        XCTAssertEqual(try fixture.products().count, 1)
        XCTAssertEqual(try fixture.prices().count, 1)
        XCTAssertEqual(try fixture.changes().filter { $0.entityKind == .productPrice }.map(\.changeID), [childID])
        XCTAssertEqual(try fixture.sealBytes(), seal)
        XCTAssertEqual(try fixture.token(review.changeID), review.pending)
        XCTAssertTrue(try fixture.receipts().isEmpty)
        XCTAssertEqual(try fixture.snapshot().pendingCatalogChangeCount, 1)
        XCTAssertEqual(try fixture.snapshot().pendingProductPriceChangeCount, 1)
    }

    func testTombstoneWithoutDependenciesRetainsOriginalSealAndResolutionAcrossReopen() throws {
        let fixture = try Fixture(rejected: true)
        let review = try fixture.review(remoteName: "Remote deleted", deletedAt: "2026-10-23T20:11:00.654321Z")
        let before = try fixture.sealBytes()
        XCTAssertEqual(try fixture.resolve(review, choice: .adoptRemoteTombstone), .adoptedRemoteTombstone)
        try fixture.reopen()
        XCTAssertTrue(try fixture.products().isEmpty)
        XCTAssertTrue(try fixture.prices().isEmpty)
        XCTAssertEqual(try fixture.sealBytes(), before)
        XCTAssertEqual(try fixture.token(review.changeID), review.pending)
        XCTAssertEqual(try fixture.resolved(), [review.changeID])
        XCTAssertEqual(try fixture.receipts().first?.decision.remote.product.deletedAt, "2026-10-23T20:11:00.654321Z")
    }

    func testRepeatedSelectedPriceDecisionCreatesOneSuccessorAndOneNewPrice() throws {
        let fixture = try Fixture(rejected: true)
        let review = try fixture.review(remoteName: "Remote replacement")
        var selected = review.desired
        selected.purchasePrice = 37
        let choice = PersistedCatalogConflictChoice.selectedFields(values: selected, fields: ["purchasePrice"])
        let outcome = try fixture.resolve(review, choice: choice)
        guard case .successorPending(let successorID) = outcome else { return XCTFail("Expected a distinct successor") }
        XCTAssertEqual(try fixture.resolve(review, choice: choice), outcome)
        try fixture.reopen()
        XCTAssertEqual(try fixture.resolve(review, choice: choice), outcome)
        XCTAssertEqual(try fixture.receipts().count, 1)
        XCTAssertEqual(try fixture.prices().count, 1)
        XCTAssertEqual(try fixture.prices().first?.price, 37)
        XCTAssertEqual(try fixture.product().productName, "Remote replacement", "Unselected local name A must not return")
        let successor = try fixture.token(successorID)
        XCTAssertEqual(successor.changedFieldsRaw, "purchaseprice")
        XCTAssertEqual(successor.baselineFingerprintHash, review.remote.fingerprint)
        XCTAssertNotEqual(successor.idempotencyKey, review.pending.idempotencyKey)
        XCTAssertEqual(try fixture.snapshot().pendingCatalogChangeCount, 1)
        XCTAssertEqual(try fixture.snapshot().pendingProductPriceChangeCount, 1)
        XCTAssertEqual(try fixture.token(review.changeID), review.pending)
    }

    func testRemoteDriftAndMalformedReceiptFailClosedWithoutOverwritingEvidence() throws {
        let fixture = try Fixture(rejected: true)
        let review = try fixture.review(remoteName: "Compared remote")
        let drift = try fixture.review(remoteName: "New remote").snapshot
        XCTAssertThrowsError(try fixture.resolve(review, choice: .adoptRemote, remote: drift)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .localChanged)
        }
        XCTAssertTrue(try fixture.receipts().isEmpty)
        XCTAssertEqual(try fixture.product().productName, "Saved A")
        _ = try fixture.resolve(review, choice: .adoptRemote)
        let context = ModelContext(fixture.container)
        let entries = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        let receipt = try XCTUnwrap(entries.first { $0.domain == LocalCatalogConflictResolutionStore.domain })
        receipt.metadataPayloadJSON = "{\"schemaVersion\":999}"
        try context.save()
        try fixture.reopen()
        XCTAssertThrowsError(try fixture.resolved())
        XCTAssertThrowsError(try fixture.snapshot())
        XCTAssertEqual(try fixture.token(review.changeID), review.pending)
        let retained = try ModelContext(fixture.container).fetch(FetchDescriptor<SyncEventOutboxEntry>())
        XCTAssertEqual(retained.first { $0.domain == LocalCatalogConflictResolutionStore.domain }?.metadataPayloadJSON,
                       "{\"schemaVersion\":999}")
    }

    func testReceiptSealAndLineageTransferWithoutOverlayingRetiredDesired() throws {
        let fixture = try Fixture(rejected: true)
        let review = try fixture.review(remoteName: "Adopted R")
        let originalSeal = try fixture.sealBytes()
        _ = try fixture.resolve(review, choice: .adoptRemote)
        let sourceReceipt = try XCTUnwrap(fixture.receipts().first)
        let firstGeneration = UUID()
        let first = try fixture.makeStaging(name: "Newer remote C", item: "C item")
        try SameScopeRecoveryLocalWorkTransfer.apply(from: fixture.container, to: first.container,
            scope: fixture.scope, sourceGenerationID: fixture.generationID, stagingGenerationID: firstGeneration)
        let reopened = try Fixture.makeContainer(url: first.url)
        let firstContext = ModelContext(reopened)
        let product = try XCTUnwrap(firstContext.fetch(FetchDescriptor<Product>()).first)
        XCTAssertEqual(product.productName, "Newer remote C")
        XCTAssertEqual(product.itemNumber, "C item")
        XCTAssertEqual(try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: firstContext), [review.changeID])
        let transferred = try XCTUnwrap(LocalCatalogConflictResolutionStore.receipts(context: firstContext).first?.1)
        XCTAssertEqual(transferred.decision.original, review.pending)
        XCTAssertEqual(transferred.decision.originGenerationID, fixture.generationID)
        XCTAssertEqual(transferred.currentGenerationID, firstGeneration)
        XCTAssertEqual(transferred.transfers.count, 1)
        XCTAssertEqual(try LocalPendingBusinessAttemptStore.entry(changeID: review.changeID,
            context: firstContext)?.metadataPayloadJSON, originalSeal)
        XCTAssertEqual(try fixture.receipts().first?.transfers, sourceReceipt.transfers,
                       "Staging transfer must not edit the source receipt")

        let secondGeneration = UUID()
        let second = try fixture.makeStaging(name: "Newer remote D", item: "D item")
        try SameScopeRecoveryLocalWorkTransfer.apply(from: reopened, to: second.container,
            scope: fixture.scope, sourceGenerationID: firstGeneration, stagingGenerationID: secondGeneration)
        let secondContext = ModelContext(try Fixture.makeContainer(url: second.url))
        let again = try XCTUnwrap(LocalCatalogConflictResolutionStore.receipts(context: secondContext).first?.1)
        XCTAssertEqual(again.decision.originGenerationID, fixture.generationID)
        XCTAssertEqual(again.currentGenerationID, secondGeneration)
        XCTAssertEqual(again.transfers.count, 2)
        XCTAssertEqual(try secondContext.fetch(FetchDescriptor<Product>()).first?.productName, "Newer remote D")
        XCTAssertEqual(try LocalPendingBusinessAttemptStore.entry(changeID: review.changeID,
            context: secondContext)?.metadataPayloadJSON, originalSeal)
    }

    func testAdoptionPreservesPriceIntentAndEffectiveParentBlockTracksOnlyResidualCatalog() throws {
        let fixture = try Fixture(rejected: true)
        let childID = try fixture.addPriceChild()
        let childBefore = try fixture.token(childID)
        let review = try fixture.review(remoteName: "Adopted parent R")
        XCTAssertEqual(try fixture.blockedParents(), [fixture.remoteID])
        _ = try fixture.resolve(review, choice: .adoptRemote)
        try fixture.reopen()
        XCTAssertTrue(try fixture.blockedParents().isEmpty,
                      "Retired A cannot permanently block the independently saved price")
        XCTAssertEqual(try fixture.token(childID), childBefore)
        XCTAssertEqual(try fixture.prices().count, 1)
        XCTAssertEqual(try fixture.snapshot().pendingProductPriceChangeCount, 1)
        XCTAssertEqual(try fixture.product().remoteID, fixture.remoteID)
        XCTAssertNil(try fixture.product().remoteDeletedAt)
        let next = try fixture.normalSaveItem("Residual B")
        XCTAssertEqual(try fixture.blockedParents(), [fixture.remoteID], "An active B still blocks its incompatible child")
        XCTAssertEqual(try fixture.token(childID), childBefore)
        XCTAssertEqual(try fixture.token(next.changeID), next)

        let unknown = try Fixture(rejected: false)
        _ = try unknown.addPriceChild()
        XCTAssertEqual(try unknown.blockedParents(), [unknown.remoteID], "An unknown sealed parent remains protected")
    }

    func testKeepingAlreadySavedPricePreservesOriginalChildWithoutCompensatingDuplicate() throws {
        let fixture = try Fixture(rejected: true, localPurchasePrice: 37,
            originalFields: ["productName", "purchasePrice"])
        let childID = try fixture.addPriceChild(price: 37)
        let childBefore = try fixture.token(childID)
        let review = try fixture.review(remoteName: "Remote replacement")
        XCTAssertEqual(review.desired.purchasePrice, 37)
        XCTAssertEqual(review.remote.purchasePrice, 10)
        let choice = PersistedCatalogConflictChoice.selectedFields(values: review.desired, fields: ["purchasePrice"])
        guard case .successorPending = try fixture.resolve(review, choice: choice) else {
            return XCTFail("Expected a catalog successor for the selected price")
        }
        try fixture.reopen()
        XCTAssertEqual(try fixture.prices().count, 1, "The existing append-only price is not recreated by review")
        XCTAssertEqual(try fixture.prices().first?.price, 37)
        XCTAssertEqual(try fixture.token(childID), childBefore)
        XCTAssertEqual(try fixture.snapshot().pendingProductPriceChangeCount, 1)
        XCTAssertEqual(try fixture.product().purchasePrice, 37)
        XCTAssertEqual(try fixture.product().productName, "Remote replacement")
    }

    func testNeverDispatchedRequiresClearJournalAndMatchingOwnerWitnessBeforeAnyCommit() throws {
        let fixture = try Fixture(rejected: false, sealed: false)
        let review = try fixture.review(remoteName: "Remote replacement")
        XCTAssertNil(review.pending.lastAttemptAt)
        XCTAssertNil(review.originalSealSHA256)
        XCTAssertThrowsError(try fixture.resolve(review, choice: .adoptRemote, writerJournalIsClear: false)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        let wrongOwner = LocalCatalogConflictResolutionStore.OwnerReleaseProof(invocationID: UUID(), processEpoch: UUID(),
            scopeLeaseGeneration: fixture.scope.leaseGeneration, generationID: UUID(),
            writerJournalSHA256: ShopSyncRecoveryCanonical.sha256("no-recovery-journal"))
        XCTAssertThrowsError(try fixture.resolve(review, choice: .adoptRemote, ownerRelease: wrongOwner)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        let wrongJournal = LocalCatalogConflictResolutionStore.OwnerReleaseProof(invocationID: UUID(), processEpoch: UUID(),
            scopeLeaseGeneration: fixture.scope.leaseGeneration, generationID: fixture.generationID,
            writerJournalSHA256: ShopSyncRecoveryCanonical.sha256("inconsistent-journal"))
        XCTAssertThrowsError(try fixture.resolve(review, choice: .adoptRemote, ownerRelease: wrongJournal))
        XCTAssertTrue(try fixture.receipts().isEmpty)
        XCTAssertEqual(try fixture.product().productName, "Saved A")
        XCTAssertEqual(try fixture.token(review.changeID), review.pending)
        XCTAssertEqual(try fixture.resolve(review, choice: .adoptRemote), .adoptedRemote)
        try fixture.reopen()
        XCTAssertEqual(try fixture.resolved(), [review.changeID])
        XCTAssertEqual(try fixture.token(review.changeID), review.pending)
        XCTAssertEqual(try fixture.snapshot().pendingCatalogChangeCount, 0)
    }

    func testLostFirstOutcomeThenReplayRejectionCannotBecomeNoCommitProof() throws {
        let fixture = try Fixture(rejected: false)
        let review = try fixture.review(remoteName: "Saved A")
        let before = try fixture.sealBytes()
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.scope.ownerUserID) { context in
            let first = try LocalPendingBusinessAttemptStore.beginCatalogDispatch(pending: review.pending,
                context: context, scope: fixture.scope)
            XCTAssertEqual(first.ordinal, 1)
            XCTAssertFalse(first.hadPriorUnknown)
            try LocalPendingBusinessAttemptStore.recordUnconfirmed(pending: review.pending,
                context: context, scope: fixture.scope)
        }
        try fixture.reopen()
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container,
            ownerUserID: fixture.scope.ownerUserID) { context in
            let replay = try LocalPendingBusinessAttemptStore.beginCatalogDispatch(pending: review.pending,
                context: context, scope: fixture.scope)
            XCTAssertEqual(replay.ordinal, 2)
            XCTAssertTrue(replay.hadPriorUnknown)
            XCTAssertFalse(try LocalPendingBusinessAttemptStore.recordRejectedWithoutCommit(.init(sqlstate: "23505"),
                pending: review.pending, dispatch: replay, context: context, scope: fixture.scope))
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first)
            XCTAssertNil(try LocalPendingBusinessAttemptStore.rejectionProof(change: row,
                context: context, scope: fixture.scope))
        }
        try fixture.reopen()
        XCTAssertThrowsError(try fixture.resolve(review, choice: .adoptRemote)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        XCTAssertEqual(try fixture.sealBytes(), before)
        XCTAssertEqual(try fixture.token(review.changeID), review.pending)
        XCTAssertTrue(try fixture.receipts().isEmpty)
        XCTAssertEqual(try fixture.product().productName, "Saved A")
    }

    func testFreshReviewNamesEveryRevisionAndRetiresOnlyProvenLineage() throws {
        for selectLaterItem in [false, true] {
            let fixture = try Fixture(rejected: true)
            let old = try fixture.review(remoteName: "Remote replacement")
            let originalSeal = try fixture.sealBytes()
            let later = try fixture.normalSaveItem("Later B")
            XCTAssertThrowsError(try fixture.resolve(old, choice: .adoptRemote))
            let fresh = try fixture.reviewLatest(later, predecessor: old)
            XCTAssertEqual(Set(fresh.originalChangedFields), ["productName", "itemNumber"])
            let choice: PersistedCatalogConflictChoice = selectLaterItem
                ? .selectedFields(values: fresh.desired, fields: ["itemNumber"]) : .adoptRemote
            let outcome = try fixture.resolve(fresh, choice: choice)
            try fixture.reopen()
            XCTAssertEqual(try fixture.resolved(), [old.changeID, later.changeID])
            XCTAssertEqual(try fixture.token(old.changeID), old.pending)
            XCTAssertEqual(try fixture.token(later.changeID), later, "Retirement does not forge an ACK for B")
            XCTAssertEqual(try fixture.sealBytes(), originalSeal)
            XCTAssertEqual(try fixture.product().productName, "Remote replacement")
            let receipt = try XCTUnwrap(fixture.receipts().first)
            XCTAssertEqual(receipt.decision.original, later)
            XCTAssertEqual(receipt.decision.predecessors.map(\.pending), [old.pending])
            if selectLaterItem {
                guard case .successorPending(let successorID) = outcome else { return XCTFail("Expected C") }
                let successor = try fixture.token(successorID)
                XCTAssertEqual(successor.changedFieldsRaw, "itemnumber")
                XCTAssertEqual(successor.baselineFingerprintHash, fresh.remote.fingerprint)
                XCTAssertNotEqual(successor.idempotencyKey, later.idempotencyKey)
                XCTAssertEqual(try fixture.product().itemNumber, "Later B")
                XCTAssertEqual(try fixture.snapshot().pendingCatalogChangeCount, 1)
            } else {
                XCTAssertEqual(outcome, .adoptedRemote)
                XCTAssertEqual(try fixture.product().itemNumber, "Remote item")
                XCTAssertEqual(try fixture.snapshot().pendingCatalogChangeCount, 0)
            }
        }
        let unknown = try Fixture(rejected: false)
        let old = try unknown.review(remoteName: "Remote replacement")
        let originalSeal = try unknown.sealBytes()
        let later = try unknown.normalSaveItem("Later B")
        let fresh = try unknown.reviewLatest(later, predecessor: old)
        XCTAssertThrowsError(try unknown.resolve(fresh, choice: .adoptRemote)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        try unknown.reopen()
        XCTAssertTrue(try unknown.receipts().isEmpty)
        XCTAssertTrue(try unknown.resolved().isEmpty)
        XCTAssertEqual(try unknown.token(old.changeID), old.pending)
        XCTAssertEqual(try unknown.token(later.changeID), later)
        XCTAssertEqual(try unknown.sealBytes(), originalSeal)
        XCTAssertEqual(try unknown.product().itemNumber, "Later B")
    }

    func testManualPriceOnlyPlanIgnoresIndependentCatalogSuccessorButProtectsItsOwnParent() async throws {
        for independent in [true, false] {
            let fixture = try Fixture(rejected: true)
            let review = try fixture.review(remoteName: "Remote replacement")
            let originalSeal = try fixture.sealBytes()
            guard case .successorPending(let successorID) = try fixture.resolve(review,
                choice: .selectedFields(values: review.desired, fields: ["productName"])) else {
                return XCTFail("Expected a conditional catalog successor")
            }
            let successor = try fixture.token(successorID)
            let child = try fixture.addManualPrice(independent: independent)
            let childBefore = try fixture.token(child.changeID)
            let fetcher = ManualPriceFetcher()
            let priceOnly = try await LocalPendingAggregatedPushPlanner(context: ModelContext(fixture.container),
                priceRemoteFetcher: fetcher, includesCatalog: false, includesProductPrice: true)
                .makePlan(ownerUserID: fixture.scope.ownerUserID)
            XCTAssertFalse(priceOnly.blockers.contains(.unsafeCatalogPlan), "An unselected catalog revision is not a global price-only blocker")
            if independent {
                XCTAssertTrue(priceOnly.blockers.isEmpty)
                XCTAssertEqual(priceOnly.counts.selectedProductPriceChanges, 1)
                XCTAssertEqual(priceOnly.productPriceBatch?.plan.summary.readyCandidates, 1)
                XCTAssertEqual(fetcher.productIDs, [child.remoteID])
            } else {
                XCTAssertTrue(priceOnly.blockers.contains(.unsafeProductPricePlan))
                XCTAssertNil(priceOnly.productPriceBatch)
                XCTAssertTrue(fetcher.productIDs.isEmpty, "Dependent child is stopped before remote dedupe")
            }
            let catalog = try await LocalPendingAggregatedPushPlanner(context: ModelContext(fixture.container),
                includesCatalog: true, includesProductPrice: false).makePlan(ownerUserID: fixture.scope.ownerUserID)
            XCTAssertTrue(catalog.blockers.contains(.unsafeCatalogPlan), "Manual PATCH cannot replace the successor's conditional contract")
            XCTAssertNil(catalog.catalogBatch)
            XCTAssertEqual(try fixture.token(review.changeID), review.pending)
            XCTAssertEqual(try fixture.sealBytes(), originalSeal)
            XCTAssertEqual(try fixture.token(successorID), successor)
            XCTAssertEqual(try fixture.token(child.changeID), childBefore)
            XCTAssertEqual(try fixture.receipts().count, 1)
        }
    }

    func testManualAggregateDispatchAndRetryCannotAuthorizeRetiringOneUnsealedMember() throws {
        let fixture = try Fixture(rejected: false, sealed: false)
        let context = ModelContext(fixture.container)
        let original = try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first {
            $0.changeID == fixture.originalID
        })
        original.status = .pending
        let sibling = Product(barcode: "R23-MANUAL-BATCH-SIBLING", remoteID: UUID(),
            itemNumber: "Independent item", productName: "Independent saved intent")
        context.insert(sibling)
        let accumulator = LocalPendingChangeAccumulator(context: context,
            ownerUserID: fixture.scope.ownerUserID, storeIdentity: fixture.scope.storeIdentity)
        let other = try XCTUnwrap(accumulator.recordProductChange(product: sibling, operation: .update,
            origin: .manualCatalogSave, changedFields: ["productName"], baselineFingerprintHash: "manual-base"))
        try context.save()
        let ids = [original.changeID, other.changeID]
        let sentAt = Date(timeIntervalSince1970: 1_792_781_123)
        try LocalPendingAggregatedPushStateStore(context: context, now: { sentAt }).markSent(
            changeIDs: ids, ownerUserID: fixture.scope.ownerUserID, planFingerprint: "manual-aggregate-plan")
        try fixture.reopen()
        let sentTokens = try ids.map { try fixture.token($0) }
        XCTAssertTrue(sentTokens.allSatisfy { $0.lastAttemptAt == sentAt })
        XCTAssertTrue(sentTokens.allSatisfy { $0.statusRaw == LocalPendingChangeStatus.sent.rawValue })
        let sentReview = try fixture.review(remoteName: "Remote replacement")
        XCTAssertThrowsError(try fixture.resolve(sentReview, choice: .adoptRemote)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        XCTAssertTrue(try fixture.receipts().isEmpty)
        XCTAssertEqual(try ids.map { try fixture.token($0) }, sentTokens)

        // A transport failure may restore scheduling eligibility, but it does
        // not establish no-commit for either member of the original batch.
        try LocalPendingAggregatedPushStateStore(context: ModelContext(fixture.container)).markRetryable(
            changeIDs: ids, ownerUserID: fixture.scope.ownerUserID)
        try fixture.reopen()
        let retryTokens = try ids.map { try fixture.token($0) }
        XCTAssertTrue(retryTokens.allSatisfy { $0.lastAttemptAt == sentAt })
        XCTAssertTrue(retryTokens.allSatisfy { $0.statusRaw == LocalPendingChangeStatus.pending.rawValue })
        let retryReview = try fixture.review(remoteName: "Remote replacement")
        XCTAssertThrowsError(try fixture.resolve(retryReview, choice: .adoptRemote)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        XCTAssertEqual(try ids.map { try fixture.token($0) }, retryTokens)
        let retained = try ModelContext(fixture.container).fetch(FetchDescriptor<Product>())
        XCTAssertEqual(retained.first { $0.remoteID == fixture.remoteID }?.productName, "Saved A")
        XCTAssertEqual(retained.first { $0.remoteID == sibling.remoteID }?.productName, "Independent saved intent")
        XCTAssertTrue(try fixture.receipts().isEmpty)
        XCTAssertTrue(try fixture.resolved().isEmpty)
    }

    private final class ManualPriceFetcher: SupabaseProductPricePushDryRunRemoteFetching {
        private(set) var productIDs: [UUID] = []
        func fetchProductPricesForPushDryRunDedupePage(ownerUserID: UUID, productIDs: [UUID],
            from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
            self.productIDs.append(contentsOf: productIDs)
            return []
        }
    }

    func testManualAtomicUnknownReopenProtectsWholeBatchAndLaterSaveGetsNewRevision() throws {
        let fixture = try Fixture(rejected: false, sealed: false, initialStatus: .pending)
        let child = try fixture.addPriceChild(price: 37)
        let sealed = try fixture.sealManualBatch(changeIDs: [fixture.originalID, child])
        let tokens = try [fixture.token(fixture.originalID), fixture.token(child)]
        try fixture.reopen()
        let read = ModelContext(fixture.container)
        XCTAssertEqual(try ManualPendingAtomicRequestStore.protectedChangeIDs(context: read), Set(tokens.map(\.changeID)))
        let receipt = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: read).first?.1)
        XCTAssertEqual(receipt.request.body, sealed.body)
        XCTAssertEqual(receipt.request.members, tokens.sorted { $0.changeID < $1.changeID })
        XCTAssertFalse(try SameScopeRecoveryActiveWorkInspector.isContinuationDrained(container: fixture.container))
        let review = try fixture.review(remoteName: "Remote R")
        XCTAssertThrowsError(try fixture.resolve(review, choice: .adoptRemote)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        let next = try fixture.normalSaveItem("Only B after uncertain aggregate")
        XCTAssertFalse(tokens.map(\.changeID).contains(next.changeID))
        try fixture.reopen()
        XCTAssertEqual(try fixture.token(fixture.originalID), tokens[0])
        XCTAssertEqual(try fixture.token(child), tokens[1])
        XCTAssertTrue(try fixture.receipts().isEmpty)
        XCTAssertEqual(try ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container)).first?.1.request, receipt.request)
    }

    func testManualAtomicUnknownSurvivesTwoTransfersWithoutSplittingOrChangingRequestBytes() throws {
        let fixture = try Fixture(rejected: false, sealed: false, initialStatus: .pending)
        let child = try fixture.addPriceChild(price: 37)
        _ = try fixture.sealManualBatch(changeIDs: [fixture.originalID, child])
        let original = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container)).first?.1)
        let generationB = UUID(), generationC = UUID()
        let b = try fixture.makeStaging(name: "New remote B", item: "B")
        try SameScopeRecoveryLocalWorkTransfer.apply(from: fixture.container, to: b.container, scope: fixture.scope,
            sourceGenerationID: fixture.generationID, stagingGenerationID: generationB)
        let reopenedB = try Fixture.makeContainer(url: b.url)
        let bContext = ModelContext(reopenedB)
        let productB = try XCTUnwrap(bContext.fetch(FetchDescriptor<Product>()).first)
        XCTAssertEqual(productB.productName, "Saved A")
        XCTAssertEqual(productB.itemNumber, "B")
        XCTAssertTrue(try LocalCatalogBodyProofStore.matchesTransferredProductBody(productB,
            context: bContext, scope: fixture.scope, generationID: generationB))
        XCTAssertNotEqual(LocalPendingChangeLogicalKey.productFingerprintHash(productB),
            original.request.members.first { $0.entityKindRaw == "product" }?.intendedFingerprintHash)
        let bReceipt = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: bContext).first?.1)
        XCTAssertEqual(bReceipt.request, original.request)
        XCTAssertEqual(bReceipt.transfers.count, 1)
        let c = try fixture.makeStaging(name: "New remote C", item: "C")
        try SameScopeRecoveryLocalWorkTransfer.apply(from: reopenedB, to: c.container, scope: fixture.scope,
            sourceGenerationID: generationB, stagingGenerationID: generationC)
        let reopenedC = try Fixture.makeContainer(url: c.url)
        let context = ModelContext(reopenedC)
        let productC = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first)
        XCTAssertEqual(productC.productName, "Saved A")
        XCTAssertEqual(productC.itemNumber, "C")
        XCTAssertTrue(try LocalCatalogBodyProofStore.matchesTransferredProductBody(productC,
            context: context, scope: fixture.scope, generationID: generationC))
        let transferred = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: context, scope: fixture.scope).first?.1)
        XCTAssertEqual(transferred.request, original.request)
        XCTAssertEqual(transferred.requestSHA256, original.requestSHA256)
        XCTAssertEqual(transferred.request.originGenerationID, fixture.generationID)
        XCTAssertEqual(transferred.currentGenerationID, generationC)
        XCTAssertEqual(transferred.transfers.count, 2)
        XCTAssertEqual(try ManualPendingAtomicRequestStore.blockingChangeIDs(context: context, scope: fixture.scope), original.request.changeIDs)
        XCTAssertFalse(try SameScopeRecoveryActiveWorkInspector.isContinuationDrained(container: reopenedC))
        let rows = try context.fetch(FetchDescriptor<LocalPendingChange>())
        XCTAssertTrue(original.request.members.allSatisfy { token in rows.contains { token.matches($0) } })
        XCTAssertEqual(try ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container)).first?.1, original)
        XCTAssertTrue(try LocalCatalogConflictResolutionStore.receipts(context: context).isEmpty)
    }

    func testManualAtomicSecondTransferRejectsTamperedOrUnqualifiedProjectionWithoutChangingOriginalRequest() throws {
        for corruption in ["body", "missingProof", "foreignGeneration", "malformedProof"] {
            let fixture = try Fixture(rejected: false, sealed: false, initialStatus: .pending)
            _ = try fixture.sealManualBatch(changeIDs: [fixture.originalID])
            let original = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container)).first?.1)
            let generationB = UUID()
            let b = try fixture.makeStaging(name: "Remote B", item: "B")
            try SameScopeRecoveryLocalWorkTransfer.apply(from: fixture.container, to: b.container,
                scope: fixture.scope, sourceGenerationID: fixture.generationID, stagingGenerationID: generationB)
            let context = ModelContext(try Fixture.makeContainer(url: b.url))
            let proof = try XCTUnwrap(context.fetch(FetchDescriptor<SyncEventOutboxEntry>()).first {
                $0.domain == LocalCatalogBodyProofStore.domain
            })
            let manualBefore = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: context).first?.0.metadataPayloadJSON)
            switch corruption {
            case "body":
                try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first).productName = "Arbitrary change after B"
            case "missingProof": context.delete(proof)
            case "foreignGeneration":
                var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(proof.metadataPayloadJSON).utf8)) as? [String: Any])
                object["generationID"] = UUID().uuidString
                let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
                let json = String(decoding: data, as: UTF8.self)
                proof.metadataPayloadJSON = json
                proof.entityIDsShape = ShopSyncRecoveryCanonical.sha256(json)
            default: proof.metadataPayloadJSON = "{invalid}"
            }
            try context.save()
            let reopenedB = try Fixture.makeContainer(url: b.url)
            let c = try fixture.makeStaging(name: "Remote C", item: "C")
            XCTAssertThrowsError(try SameScopeRecoveryLocalWorkTransfer.apply(from: reopenedB, to: c.container,
                scope: fixture.scope, sourceGenerationID: generationB, stagingGenerationID: UUID())) {
                XCTAssertEqual($0 as? SyncStoreGenerationError, .activationReadBackFailed, corruption)
            }
            let cRead = ModelContext(try Fixture.makeContainer(url: c.url))
            XCTAssertTrue(try cRead.fetch(FetchDescriptor<LocalPendingChange>()).isEmpty, corruption)
            XCTAssertTrue(try ManualPendingAtomicRequestStore.records(context: cRead).isEmpty, corruption)
            XCTAssertEqual(try cRead.fetch(FetchDescriptor<Product>()).first?.productName, "Remote C", corruption)
            let bRead = ModelContext(reopenedB)
            let retained = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: bRead).first)
            XCTAssertEqual(retained.0.metadataPayloadJSON, manualBefore, corruption)
            XCTAssertEqual(retained.1.request, original.request, corruption)
            let rows = try bRead.fetch(FetchDescriptor<LocalPendingChange>())
            XCTAssertTrue(original.request.members.allSatisfy { token in rows.contains { token.matches($0) } }, corruption)
        }
    }

    func testManualAtomicLookupMembersKeepExactTokensAcrossRemoteDriftAndTwoTransfers() throws {
        let fixture = try Fixture(rejected: false, sealed: false, initialStatus: .pending)
        let supplierID = UUID(), categoryID = UUID()
        let lookupChanges = try Task126OwnerStoreGate.withLocalMutationFence(
            modelContainer: fixture.container, ownerUserID: fixture.scope.ownerUserID) { context in
            let supplier = Supplier(name: "Supplier before A", remoteID: supplierID)
            let category = ProductCategory(name: "Category before A", remoteID: categoryID)
            context.insert(supplier); context.insert(category)
            let supplierBase = LocalPendingChangeLogicalKey.supplierFingerprintHash(supplier)
            let categoryBase = LocalPendingChangeLogicalKey.categoryFingerprintHash(category)
            supplier.name = "Supplier saved A"; category.name = "Category saved A"
            let accumulator = LocalPendingChangeAccumulator(context: context,
                ownerUserID: fixture.scope.ownerUserID, storeIdentity: fixture.scope.storeIdentity)
            let supplierChange = try XCTUnwrap(accumulator.recordSupplierChange(supplier: supplier,
                operation: .update, origin: .manualCatalogSave, baselineFingerprintHash: supplierBase))
            let categoryChange = try XCTUnwrap(accumulator.recordCategoryChange(category: category,
                operation: .update, origin: .manualCatalogSave, baselineFingerprintHash: categoryBase))
            try context.save()
            return [supplierChange.changeID, categoryChange.changeID]
        }
        _ = try fixture.sealManualBatch(changeIDs: [fixture.originalID] + lookupChanges)
        let original = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container)).first?.1)
        XCTAssertEqual(original.request.members.count, 3)
        XCTAssertTrue(original.request.members.allSatisfy { $0.statusRaw == "sent" })
        var current = fixture.container
        var currentGeneration = fixture.generationID
        for index in 1...2 {
            let next = try fixture.makeStaging(name: "Remote product drift \(index)", item: "Remote \(index)")
            let stageContext = ModelContext(next.container)
            stageContext.insert(Supplier(name: "Remote supplier drift \(index)", remoteID: supplierID,
                remoteUpdatedAt: Date(timeIntervalSince1970: 1_792_781_000 + Double(index))))
            stageContext.insert(ProductCategory(name: "Remote category drift \(index)", remoteID: categoryID,
                remoteUpdatedAt: Date(timeIntervalSince1970: 1_792_781_000 + Double(index))))
            try stageContext.save()
            let nextGeneration = UUID()
            try SameScopeRecoveryLocalWorkTransfer.apply(from: current, to: next.container, scope: fixture.scope,
                sourceGenerationID: currentGeneration, stagingGenerationID: nextGeneration)
            current = try Fixture.makeContainer(url: next.url)
            currentGeneration = nextGeneration
            let context = ModelContext(current)
            let tokens = try context.fetch(FetchDescriptor<LocalPendingChange>())
            XCTAssertTrue(original.request.members.allSatisfy { token in tokens.contains { token.matches($0) } })
            let transferred = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: context, scope: fixture.scope).first?.1)
            XCTAssertEqual(transferred.request, original.request)
            XCTAssertEqual(transferred.requestSHA256, original.requestSHA256)
            XCTAssertEqual(transferred.currentGenerationID, currentGeneration)
            XCTAssertEqual(transferred.transfers.count, index)
            XCTAssertEqual(try ManualPendingAtomicRequestStore.blockingChangeIDs(context: context, scope: fixture.scope), original.request.changeIDs)
            XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).first { $0.remoteID == supplierID }?.name, "Supplier saved A")
            XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).first { $0.remoteID == categoryID }?.name, "Category saved A")
            XCTAssertFalse(try SameScopeRecoveryActiveWorkInspector.isContinuationDrained(container: current))
        }
        XCTAssertEqual(try ManualPendingAtomicRequestStore.records(context: ModelContext(fixture.container)).first?.1, original)
    }

    func testManualAtomicUnknownCannotBeSupersededByPriceDeleteOrBaselineReconciliation() throws {
        let fixture = try Fixture(rejected: false, sealed: false, initialStatus: .pending)
        let child = try fixture.addPriceChild(price: 37)
        _ = try fixture.sealManualBatch(changeIDs: [fixture.originalID, child])
        let original = try fixture.token(fixture.originalID), price = try fixture.token(child)
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: fixture.container, ownerUserID: fixture.scope.ownerUserID) { context in
            let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first)
            let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: fixture.scope.ownerUserID,
                storeIdentity: fixture.scope.storeIdentity)
            XCTAssertThrowsError(try accumulator.supersedeProductPriceChanges(for: product)) {
                XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
            }
            try accumulator.reconcileAfterBaselineRefresh(records: [.init(entityKind: .product,
                remoteID: fixture.remoteID, fingerprintCanonical: "different readback")])
            try accumulator.cleanupTerminalChanges(retainAtMost: 0)
            try context.save()
        }
        try fixture.reopen()
        XCTAssertEqual(try fixture.token(fixture.originalID), original)
        XCTAssertEqual(try fixture.token(child), price)
        XCTAssertEqual(try fixture.prices().count, 1)
    }

    func testMalformedManualAtomicReceiptFailsClosedAndNeverMeansDrained() throws {
        let fixture = try Fixture(rejected: false, sealed: false, initialStatus: .pending)
        _ = try fixture.sealManualBatch(changeIDs: [fixture.originalID])
        let before = try fixture.token(fixture.originalID)
        let context = ModelContext(fixture.container)
        let entry = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: context).first?.0)
        entry.metadataPayloadJSON = "{\"invalid\":true}"
        try context.save()
        try fixture.reopen()
        XCTAssertThrowsError(try ManualPendingAtomicRequestStore.blockingChangeIDs(context: ModelContext(fixture.container), scope: fixture.scope))
        XCTAssertThrowsError(try SameScopeRecoveryActiveWorkInspector.isContinuationDrained(container: fixture.container))
        XCTAssertThrowsError(try fixture.normalSaveItem("Must not coalesce against an unreadable seal"))
        try fixture.reopen()
        XCTAssertEqual(try fixture.token(fixture.originalID), before)
        XCTAssertEqual(try fixture.product().itemNumber, "Remote item")
        XCTAssertEqual(try ModelContext(fixture.container).fetch(FetchDescriptor<SyncEventOutboxEntry>()).first {
            $0.domain == ManualPendingAtomicRequestStore.domain
        }?.metadataPayloadJSON, "{\"invalid\":true}")
    }

    @MainActor
    private final class Fixture {
        let directory: URL
        let storeURL: URL
        var container: ModelContainer
        let scope: Task126VerifiedOwnerStoreScope
        let generationID = UUID()
        let remoteID = UUID()
        private(set) var originalID = ""

        private struct AtomicCatalogBody: Codable {
            let id: UUID
            let owner: UUID
            let shop: UUID
            let values: CatalogConflictProductValues
            let fields: [String]
        }

        init(rejected: Bool, sealed: Bool = true, localPurchasePrice: Double = 10,
             originalFields: [String] = ["productName"], initialStatus: LocalPendingChangeStatus = .staleBaseline) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("task145-resolution-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            storeURL = directory.appendingPathComponent("catalog.store")
            container = try Self.makeContainer(url: storeURL)
            let owner = UUID(), shop = UUID(), device = "unit-conflict-device"
            scope = Task126VerifiedOwnerStoreScope(ownerUserID: owner,
                accountHash: AccountBindingStore.accountHash(for: owner), shopID: shop,
                storeIdentity: LocalStoreIdentity(rawValue: shop.uuidString.lowercased()),
                deviceInstallID: device, deviceIdentityHash: DeviceInstallIDStore.identityHash(for: device),
                pendingReplacement: nil, leaseGeneration: 0)
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container, ownerUserID: owner) { context in
                let product = Product(barcode: "R23-DURABLE-CONFLICT", remoteID: remoteID,
                    remoteUpdatedAt: SupabaseRemoteDateParser.parse("2026-10-23T20:00:00.123456Z"),
                    itemNumber: "Remote item", productName: "Before A", purchasePrice: 10, retailPrice: 20)
                context.insert(product)
                let base = LocalPendingChangeLogicalKey.productFingerprintHash(product)
                product.productName = "Saved A"
                product.purchasePrice = localPurchasePrice
                let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: owner, storeIdentity: scope.storeIdentity)
                let change = try XCTUnwrap(accumulator.recordProductChange(product: product, operation: .update,
                    origin: .manualCatalogSave, changedFields: originalFields, baselineFingerprintHash: base))
                originalID = change.changeID
                if sealed {
                    change.lastAttemptAt = Date(timeIntervalSince1970: 1_792_781_000)
                    let body = AtomicCatalogBody(id: remoteID, owner: owner, shop: shop,
                        values: CatalogConflictProductValues(product: product), fields: originalFields)
                    try LocalPendingBusinessAttemptStore.seal(body, pending: LocalPendingChangeCASToken(change),
                        kind: "catalog", context: context, scope: scope, priorCatalogAttemptIsKnownAbsent: true)
                } else {
                    change.status = initialStatus
                    try context.save()
                }
            }
            if rejected { try recordRejection() }
        }

        func sealManualBatch(changeIDs: [String]) throws -> (body: Data, witness: ManualPendingAtomicRequestStore.Witness) {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container, ownerUserID: scope.ownerUserID) { context in
                try LocalPendingAggregatedPushStateStore(context: context, now: { Date(timeIntervalSince1970: 1_792_781_111) })
                    .markSent(changeIDs: changeIDs, ownerUserID: scope.ownerUserID, planFingerprint: "manual-storage-boundary")
                let rows = try context.fetch(FetchDescriptor<LocalPendingChange>()).filter { changeIDs.contains($0.changeID) }
                XCTAssertEqual(rows.count, changeIDs.count)
                let tokens = rows.map(LocalPendingChangeCASToken.init)
                let url = "https://example.invalid/rest/v1/inventory_products?id=eq.\(remoteID.uuidString.lowercased())&owner_user_id=eq.\(scope.ownerUserID.uuidString.lowercased())&shop_id=eq.\(scope.shopID.uuidString.lowercased())"
                var request = URLRequest(url: URL(string: url)!)
                request.httpMethod = "PATCH"
                request.httpBody = Data("{\"product_name\":\"Saved A\"}".utf8)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let witness = try ManualPendingAtomicRequestStore.prepareExact(request: request, requestID: UUID(), batchID: UUID(),
                    members: tokens, requestMemberIDs: [originalID], scope: scope, generationID: generationID, context: context)
                try ManualPendingAtomicRequestStore.beginDispatch(witness: witness, context: context, scope: scope)
                return (request.httpBody!, witness)
            }
        }

        func reopen() throws { container = try Self.makeContainer(url: storeURL) }

        func review(remoteName: String, deletedAt: String? = nil) throws -> PersistedCatalogConflictReview {
            let context = ModelContext(container)
            let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first { $0.remoteID == remoteID })
            let pending = try token(originalID)
            let row = RemoteInventoryProductRow(id: remoteID, ownerUserID: scope.ownerUserID, shopID: scope.shopID,
                barcode: product.barcode, itemNumber: "Remote item", productName: remoteName, secondProductName: nil,
                purchasePrice: 10, retailPrice: 20, supplierID: nil, categoryID: nil, stockQuantity: nil,
                updatedAt: "2026-10-23T20:10:00.123456Z", deletedAt: deletedAt)
            let remote = CatalogConflictRemoteSnapshot(product: row, suppliers: [], categories: [],
                observedAt: Date(), scopeLeaseGeneration: scope.leaseGeneration)
            let seal = try LocalPendingBusinessAttemptStore.entry(changeID: originalID, context: context)
            return PersistedCatalogConflictReview(id: UUID(), changeID: originalID,
                originalChangedFields: pending.changedFieldsRaw.split(separator: ",").compactMap { CatalogConflictProductValues.canonicalField(String($0)) },
                desired: CatalogConflictProductValues(product: product), remote: remote.values,
                remoteUpdatedAt: row.updatedAt, remoteDeletedAt: row.deletedAt, canResolve: true, blockedReason: nil,
                pending: pending, scope: scope, generationID: generationID, snapshot: remote, originalSealSHA256: seal?.entityIDsShape)
        }

        func reviewLatest(_ pending: LocalPendingChangeCASToken,
                          predecessor: PersistedCatalogConflictReview) throws -> PersistedCatalogConflictReview {
            let snapshot = predecessor.snapshot
            return PersistedCatalogConflictReview(id: UUID(), changeID: pending.changeID,
                originalChangedFields: ["productName", "itemNumber"],
                desired: CatalogConflictProductValues(product: try product()), remote: snapshot.values,
                remoteUpdatedAt: snapshot.product.updatedAt, remoteDeletedAt: snapshot.product.deletedAt,
                canResolve: true, blockedReason: nil, pending: pending, scope: scope, generationID: generationID,
                snapshot: snapshot, originalSealSHA256: nil,
                predecessors: [.init(pending: predecessor.pending, sealSHA256: predecessor.originalSealSHA256)])
        }

        func resolve(_ review: PersistedCatalogConflictReview, choice: PersistedCatalogConflictChoice,
                     remote: CatalogConflictRemoteSnapshot? = nil,
                     writerJournalIsClear: Bool = true,
                     ownerRelease: LocalCatalogConflictResolutionStore.OwnerReleaseProof? = nil) throws -> PersistedCatalogConflictOutcome {
            let proof = ownerRelease ?? LocalCatalogConflictResolutionStore.OwnerReleaseProof(invocationID: UUID(), processEpoch: UUID(),
                scopeLeaseGeneration: scope.leaseGeneration, generationID: generationID,
                writerJournalSHA256: ShopSyncRecoveryCanonical.sha256("no-recovery-journal"))
            return try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container,
                ownerUserID: scope.ownerUserID) { context in
                try LocalPendingChangeAccumulator.resolvePersistedCatalogConflict(context: context, review: review,
                    choice: choice, remote: remote ?? review.snapshot, ownerRelease: proof, writerJournalIsClear: writerJournalIsClear)
            }
        }

        func recordRejection() throws {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container,
                ownerUserID: scope.ownerUserID) { context in
                let change = try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == originalID })
                let pending = LocalPendingChangeCASToken(change)
                let dispatch = try LocalPendingBusinessAttemptStore.beginCatalogDispatch(pending: pending,
                    context: context, scope: scope)
                XCTAssertTrue(try LocalPendingBusinessAttemptStore.recordRejectedWithoutCommit(.init(sqlstate: "23505"),
                    pending: pending, dispatch: dispatch, context: context, scope: scope))
            }
        }

        func normalSaveItem(_ value: String) throws -> LocalPendingChangeCASToken {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container,
                ownerUserID: scope.ownerUserID) { context in
                let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first)
                let base = LocalPendingChangeLogicalKey.productFingerprintHash(product)
                product.itemNumber = value
                let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: scope.ownerUserID,
                    storeIdentity: scope.storeIdentity)
                let recorded = try accumulator.recordProductChange(product: product, operation: .update,
                    origin: .manualCatalogSave, changedFields: ["itemNumber"], baselineFingerprintHash: base)
                let change = try XCTUnwrap(recorded)
                try context.save()
                return LocalPendingChangeCASToken(change)
            }
        }

        func addPriceChild(price value: Double = 10) throws -> String {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container,
                ownerUserID: scope.ownerUserID) { context in
                let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first)
                let price = ProductPrice(type: .purchase, price: value,
                    effectiveAt: Date(timeIntervalSince1970: 1_792_781_000), source: "manual", product: product)
                context.insert(price)
                let change = try XCTUnwrap(LocalPendingChangeAccumulator(context: context,
                    ownerUserID: scope.ownerUserID, storeIdentity: scope.storeIdentity)
                    .recordProductPriceChange(price: price, origin: .productPriceSave))
                try context.save()
                return change.changeID
            }
        }

        func addManualPrice(independent: Bool) throws -> (changeID: String, remoteID: UUID) {
            try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container, ownerUserID: scope.ownerUserID) { context in
                let product: Product
                if independent {
                    product = Product(barcode: "R23-INDEPENDENT-PRICE", remoteID: UUID(), productName: "Independent", purchasePrice: 10)
                    context.insert(product)
                    try context.save()
                } else { product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first) }
                _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(context: context, ownerUserUUID: scope.ownerUserID)
                let price = ProductPrice(type: .purchase, price: 12, effectiveAt: Date(timeIntervalSince1970: 1_792_781_000), product: product)
                context.insert(price)
                let change = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: scope.ownerUserID,
                    storeIdentity: scope.storeIdentity).recordProductPriceChange(price: price, origin: .productPriceSave))
                try context.save()
                return (change.changeID, try XCTUnwrap(product.remoteID))
            }
        }

        func products() throws -> [Product] { try ModelContext(container).fetch(FetchDescriptor<Product>()) }
        func product() throws -> Product { try XCTUnwrap(products().first) }
        func prices() throws -> [ProductPrice] { try ModelContext(container).fetch(FetchDescriptor<ProductPrice>()) }
        func changes() throws -> [LocalPendingChange] { try ModelContext(container).fetch(FetchDescriptor<LocalPendingChange>()) }
        func token(_ id: String) throws -> LocalPendingChangeCASToken {
            LocalPendingChangeCASToken(try XCTUnwrap(changes().first { $0.changeID == id }))
        }
        func sealBytes() throws -> String {
            try XCTUnwrap(LocalPendingBusinessAttemptStore.entry(changeID: originalID,
                context: ModelContext(container))?.metadataPayloadJSON)
        }
        func resolved() throws -> Set<String> {
            try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: ModelContext(container))
        }
        func receipts() throws -> [LocalCatalogConflictResolutionStore.Receipt] {
            try LocalCatalogConflictResolutionStore.receipts(context: ModelContext(container)).map(\.1)
        }
        func snapshot() throws -> LocalPendingChangeSnapshot {
            try LocalPendingChangeSnapshotProvider(context: ModelContext(container)).loadSnapshot(
                ownerUserID: scope.ownerUserID, storeIdentity: scope.storeIdentity)
        }
        func blockedParents() throws -> Set<UUID> {
            try LocalCatalogConflictResolutionStore.blockedParentProductIDs(context: ModelContext(container), scope: scope)
        }
        func makeStaging(name: String, item: String) throws -> (container: ModelContainer, url: URL) {
            let url = directory.appendingPathComponent("staging-\(UUID().uuidString).store")
            let staging = try Self.makeContainer(url: url)
            let context = ModelContext(staging)
            context.insert(Product(barcode: "R23-DURABLE-CONFLICT", remoteID: remoteID,
                remoteUpdatedAt: SupabaseRemoteDateParser.parse("2026-10-23T20:30:00.999999Z"),
                itemNumber: item, productName: name, purchasePrice: 10, retailPrice: 20))
            try context.save()
            return (staging, url)
        }
        static func makeContainer(url: URL) throws -> ModelContainer {
            let schema = Schema([Product.self, Supplier.self, ProductCategory.self, HistoryEntry.self,
                ProductPrice.self, SupabaseCatalogBaselineRun.self, SupabaseCatalogBaselineRecord.self,
                SyncEventOutboxEntry.self, LocalPendingChange.self])
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        }
    }
}
