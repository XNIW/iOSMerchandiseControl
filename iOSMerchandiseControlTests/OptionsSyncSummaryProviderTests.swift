import Combine
import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class OptionsSyncSummaryProviderTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testAcknowledgedIntentsAndLocalBodyProofsDoNotCountAsPendingCloudWork() throws {
        let context = try makeContext()
        let owner = UUID()
        let now = Date(timeIntervalSince1970: 1_000)
        for index in 0..<6 {
            context.insert(LocalPendingChange(
                ownerUserID: owner,
                entityKind: index < 2 ? .product : .productPrice,
                operation: index < 2 ? .create : .upsert,
                status: .acknowledged,
                origin: index < 2 ? .manualCatalogSave : .productPriceSave,
                logicalKey: "fixture-ack-\(index)",
                createdAt: now,
                updatedAt: now
            ))
        }
        for index in 0..<9 {
            let isProof = index >= 3
            let id = "fixture-event-\(index)"
            context.insert(SyncEventOutboxEntry(
                id: id,
                ownerUserID: owner.uuidString.lowercased(),
                clientEventID: id,
                domain: isProof ? LocalCatalogBodyProofStore.domain : "catalog",
                eventType: isProof ? "local_catalog_body_v1" : "updated",
                changedCount: 1,
                entityIDsShape: "fixture-entity-shape-\(index)",
                metadataShape: "fixture-metadata-shape-\(index)",
                entityIDsPayloadJSON: "{\"id\":\"\(id)\"}",
                metadataPayloadJSON: "{\"fixture\":\(index)}",
                status: isProof ? .localOnly : .sent,
                nextRetryAt: now,
                createdAt: now,
                updatedAt: now,
                sentAt: isProof ? nil : now
            ))
        }
        try context.save()
        let before = try outboxSnapshot(context)

        XCTAssertEqual(try OptionsPendingAttentionCounter.countAll(context: context), 0)

        context.insert(LocalPendingChange(
            ownerUserID: owner,
            entityKind: .product,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: "fixture-real-pending",
            changedFields: ["productName"],
            createdAt: now,
            updatedAt: now
        ))
        try context.save()
        XCTAssertEqual(try OptionsPendingAttentionCounter.countAll(context: context), 1)
        XCTAssertEqual(try outboxSnapshot(context), before, "Counting must retain every event and local proof unchanged.")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocalPendingChange>()), 7)
    }

    func testPendingAttentionStillIncludesBlockedAndDeadCloudEvents() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_000)
        let attentionStatuses: [SyncEventOutboxStatus] = [
            .pending, .sending, .failedRetryable, .blockedContract, .blockedAuth, .blockedSchema, .dead
        ]
        for status in attentionStatuses {
            context.insert(SyncEventOutboxEntry(
                ownerUserID: UUID().uuidString.lowercased(),
                domain: "catalog",
                eventType: "updated",
                changedCount: 1,
                entityIDsShape: "fixture",
                metadataShape: "fixture",
                status: status,
                nextRetryAt: now,
                createdAt: now,
                updatedAt: now
            ))
        }
        try context.save()

        XCTAssertEqual(try OptionsPendingAttentionCounter.countAll(context: context), attentionStatuses.count)
    }

    private func outboxSnapshot(_ context: ModelContext) throws -> [[String]] {
        try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
            .sorted { $0.id < $1.id }
            .map { entry in
                [entry.id, entry.clientEventID, entry.ownerUserID, entry.domain, entry.eventType,
                 entry.statusRaw, entry.entityIDsShape, entry.metadataShape,
                 entry.entityIDsPayloadJSON ?? "", entry.metadataPayloadJSON ?? "",
                 String(entry.attemptCount), String(entry.updatedAt.timeIntervalSince1970)]
            }
    }

    func testRefreshIsDebouncedAndCoalescesRepeatedAppearNotifications() async throws {
        let fixture = try await OptionsQualifiedSummaryFixture.make(testCase: self)
        let provider = OptionsSyncSummaryProvider(now: { Date(timeIntervalSince1970: 1_000) }, defaults: fixture.defaults)
        fixture.registerProviderTeardown(provider, testCase: self)
        refresh(provider, fixture: fixture, reason: "appear")
        XCTAssertTrue(provider.isLoading)
        refresh(provider, fixture: fixture, reason: "notification")
        XCTAssertEqual(provider.coalescedEvents, 1)
        try await waitForSummary(provider)
        XCTAssertFalse(provider.isLoading)
        XCTAssertFalse(provider.isStale)
        XCTAssertEqual(provider.localDatabaseSummary.products, 1)
        XCTAssertEqual(provider.refreshReason, "notification")
        XCTAssertNotNil(provider.lastRefreshedAt)
        XCTAssertTrue(provider.isBusinessSummaryCurrent(context: fixture.context, localOwnerUserID: fixture.owner))
    }

    func testCoalescedRefreshRunsAgainWithLatestLocalData() async throws {
        let fixture = try await OptionsQualifiedSummaryFixture.make(testCase: self)
        let provider = OptionsSyncSummaryProvider(now: { Date(timeIntervalSince1970: 1_100) }, defaults: fixture.defaults)
        fixture.registerProviderTeardown(provider, testCase: self)
        refresh(provider, fixture: fixture, reason: "appear")
        try fixture.insertLocalProduct(barcode: "TASK127_DURING_INFLIGHT")
        refresh(provider, fixture: fixture, reason: "pending-change")
        try await waitForSummary(provider, expectedProductCount: 2)
        XCTAssertEqual(provider.coalescedEvents, 1)
        XCTAssertEqual(provider.refreshReason, "pending-change")
    }

    func testRemoteDriftDoesNotBlockInitialLocalSummary() async throws {
        let fixture = try await OptionsQualifiedSummaryFixture.make(testCase: self)
        let provider = OptionsSyncSummaryProvider(now: { Date(timeIntervalSince1970: 2_000) }, defaults: fixture.defaults)
        fixture.registerProviderTeardown(provider, testCase: self)
        let remote = HeldOptionsCountFetcher()
        defer { remote.release(.success(.zero)) }
        refresh(provider, fixture: fixture, remote: remote, signedIn: true, reason: "appear")
        try await waitForSummary(provider)
        try await waitUntil("remote request entered") { remote.entered }
        XCTAssertEqual(provider.localDatabaseSummary.products, 1)
        XCTAssertNil(provider.syncCountDriftReport)
        XCTAssertTrue(provider.isCheckingRemoteCounts)
        remote.release(.success(.zero))
        try await waitUntil("drift report") { provider.syncCountDriftReport != nil }
        XCTAssertEqual(provider.syncCountDriftReport?.mismatches, [.products])
        XCTAssertFalse(provider.isCheckingRemoteCounts)
    }

    func testShopDiscoveryRefreshMovesFromUnavailableToConcreteMismatchWithoutDefaultFallback() async throws {
        let fixture = try await OptionsQualifiedSummaryFixture.make(testCase: self)
        let selection = SelectedShopStore(defaults: fixture.defaults)
        selection.clear(accountHash: fixture.accountHash)
        let provider = OptionsSyncSummaryProvider(defaults: fixture.defaults)
        fixture.registerProviderTeardown(provider, testCase: self)
        refresh(provider, fixture: fixture, signedIn: true, reason: "unresolved-shop")
        try await waitForDecision(provider, reason: .shopContextUnavailable)
        XCTAssertEqual(provider.businessReadCountForTesting, 0)
        let shopB = fixture.otherShop()
        XCTAssertTrue(selection.save(shopB, accountHash: fixture.accountHash))
        XCTAssertTrue(selection.markResolutionReady(accountHash: fixture.accountHash))
        refresh(provider, fixture: fixture, signedIn: true, reason: "shop-context-changed")
        XCTAssertNil(provider.accountSyncDecision)
        XCTAssertTrue(provider.isLoading || provider.isStale)
        try await waitForDecision(provider, reason: .shopMismatch)
        XCTAssertEqual(provider.refreshReason, "shop-context-changed")
        XCTAssertFalse(provider.isBusinessSummaryAvailable)
        XCTAssertEqual(provider.businessReadCountForTesting, 0)
        XCTAssertEqual(AccountBindingStore(defaults: fixture.defaults).currentBinding?.storeIdentity,
                       fixture.shop.localStoreIdentity)
        XCTAssertTrue(provider.isAccountDecisionCurrent(context: fixture.context,
            localOwnerUserID: fixture.owner, authSnapshot: fixture.auth))
        refresh(provider, fixture: fixture, reason: "signed-out")
        XCTAssertNil(provider.accountSyncDecision)
        try await waitUntil("signed-out refresh") { !provider.isLoading }
        XCTAssertNil(provider.accountSyncDecision)
        XCTAssertEqual(provider.businessReadCountForTesting, 0)
    }

    func testScopeInvalidatedBeforeTaskEntryPreventsRemoteDispatch() async throws {
        let fixture = try await OptionsQualifiedSummaryFixture.make(testCase: self)
        let provider = OptionsSyncSummaryProvider(defaults: fixture.defaults)
        fixture.registerProviderTeardown(provider, testCase: self)
        let remote = HeldOptionsCountFetcher()
        // If wrongly dispatched, this non-cooperative fetcher returns immediately.
        // The negative must fail at fetchCount, not hang waiting for a response.
        remote.release(.success(.zero))
        let selection = SelectedShopStore(defaults: fixture.defaults)
        let originalGeneration = Task126OwnerStoreGate.localBodyProofAdmissionGeneration()
        var invalidationCount = 0
        let subscription = provider.$isCheckingRemoteCounts
            .filter { $0 }
            .prefix(1)
            .sink { _ in
                // @Published sends synchronously after the outer admission guard,
                // before Task construction/first entry. Do not re-enter the provider.
                XCTAssertFalse(remote.entered)
                XCTAssertEqual(provider.outstandingRemoteCountCallbacksForTesting, 0)
                XCTAssertTrue(selection.save(fixture.otherShop(), accountHash: fixture.accountHash))
                invalidationCount += 1
            }
        defer { subscription.cancel(); remote.release(.success(.zero)) }

        refresh(provider, fixture: fixture, remote: remote, signedIn: true, reason: "A-before-dispatch")
        try await waitUntil("invalidated actual count task settled") {
            provider.settledRemoteCountCallbacksForTesting == 1
        }
        XCTAssertEqual(invalidationCount, 1)
        XCTAssertNotEqual(Task126OwnerStoreGate.localBodyProofAdmissionGeneration(), originalGeneration)
        XCTAssertEqual(remote.fetchCount, 0, "The actual Task must revalidate before calling a non-cooperative fetcher.")
        XCTAssertFalse(remote.entered)
        XCTAssertFalse(remote.returned)
        XCTAssertEqual(provider.outstandingRemoteCountCallbacksForTesting, 0)
        XCTAssertEqual(provider.businessReadCountForTesting, 3)
        XCTAssertFalse(provider.isBusinessSummaryCurrent(context: fixture.context, localOwnerUserID: fixture.owner))
        XCTAssertNil(provider.syncCountDriftReport)
        XCTAssertFalse(provider.syncCountDriftCheckFailed)
        XCTAssertNil(provider.lastSyncCountDriftCheckedAt)

        refresh(provider, fixture: fixture, remote: remote, signedIn: true, reason: "B-after-rejected-entry")
        try await waitForDecision(provider, reason: .shopMismatch)
        XCTAssertFalse(provider.isBusinessSummaryAvailable)
        XCTAssertFalse(provider.isCheckingRemoteCounts)
        XCTAssertEqual(provider.businessReadCountForTesting, 3)
        XCTAssertEqual(remote.fetchCount, 0)
        XCTAssertEqual(provider.settledRemoteCountCallbacksForTesting, 1)
        XCTAssertEqual(provider.outstandingRemoteCountCallbacksForTesting, 0)
        XCTAssertTrue(provider.isAccountDecisionCurrent(context: fixture.context,
            localOwnerUserID: fixture.owner, authSnapshot: fixture.auth))
    }

    func testHeldOldSuccessCannotPublishAcrossShopSwitchOrReturn() async throws {
        try await assertHeldOldCompletionAcrossNewRequest(fails: false)
    }

    func testHeldOldFailureCannotPublishAcrossShopSwitchOrReturn() async throws {
        try await assertHeldOldCompletionAcrossNewRequest(fails: true)
    }

    private func assertHeldOldCompletionAcrossNewRequest(fails: Bool) async throws {
        let fixture = try await OptionsQualifiedSummaryFixture.make(testCase: self)
        let provider = OptionsSyncSummaryProvider(defaults: fixture.defaults)
        fixture.registerProviderTeardown(provider, testCase: self)
        let old = HeldOptionsCountFetcher()
        let current = HeldOptionsCountFetcher()
        defer { old.release(.success(.zero)); current.release(.success(.zero)) }
        refresh(provider, fixture: fixture, remote: old, signedIn: true, reason: "A-old")
        try await waitUntil("old A count request") { old.entered }
        XCTAssertEqual(provider.businessReadCountForTesting, 3)
        let originalSummary = provider.localDatabaseSummary.products
        let selection = SelectedShopStore(defaults: fixture.defaults)
        XCTAssertTrue(selection.save(fixture.otherShop(), accountHash: fixture.accountHash))
        XCTAssertFalse(provider.isBusinessSummaryCurrent(context: fixture.context, localOwnerUserID: fixture.owner))
        refresh(provider, fixture: fixture, remote: current, signedIn: true, reason: "B")
        XCTAssertFalse(provider.isBusinessSummaryAvailable)
        try await waitForDecision(provider, reason: .shopMismatch)
        XCTAssertEqual(provider.localDatabaseSummary.products, originalSummary)
        XCTAssertEqual(provider.businessReadCountForTesting, 3)
        XCTAssertEqual(current.fetchCount, 0, "The administrative B branch must not dispatch count work.")
        try await fixture.restoreOriginalShop()
        XCTAssertFalse(provider.isBusinessSummaryCurrent(context: fixture.context, localOwnerUserID: fixture.owner))
        refresh(provider, fixture: fixture, remote: current, signedIn: true, reason: "A-current")
        try await waitUntil("current A count request") { current.entered }
        let readsBeforeOldCompletion = provider.businessReadCountForTesting
        XCTAssertEqual(readsBeforeOldCompletion, 6)
        XCTAssertTrue(provider.isCheckingRemoteCounts)
        old.release(fails ? .failure(HeldOptionsCountFetcher.Failure.synthetic) : .success(.zero))
        try await waitUntil("old completion fully settled") {
            old.returned && provider.settledRemoteCountCallbacksForTesting == 1
        }
        XCTAssertEqual(provider.businessReadCountForTesting, readsBeforeOldCompletion)
        XCTAssertTrue(provider.isCheckingRemoteCounts, "Old success/catch must not clean up the current request.")
        XCTAssertNil(provider.syncCountDriftReport)
        XCTAssertFalse(provider.syncCountDriftCheckFailed)
        XCTAssertNil(provider.lastSyncCountDriftCheckedAt)
        XCTAssertEqual(provider.refreshReason, "A-current")
        XCTAssertTrue(provider.isBusinessSummaryCurrent(context: fixture.context, localOwnerUserID: fixture.owner))
        current.release(.success(.zero))
        try await waitUntil("current drift published") { provider.syncCountDriftReport != nil }
        XCTAssertEqual(provider.businessReadCountForTesting, readsBeforeOldCompletion + 1)
        XCTAssertEqual(provider.syncCountDriftReport?.local.products, 1)
        XCTAssertEqual(provider.syncCountDriftReport?.remote.products, 0)
        XCTAssertEqual(provider.syncCountDriftReport?.mismatches, [.products])
        XCTAssertFalse(provider.isCheckingRemoteCounts)
        XCTAssertFalse(provider.syncCountDriftCheckFailed)
    }

    func testHeldOldCompletionCannotReadAfterScopeChangeWithoutRefresh() async throws {
        for fails in [false, true] {
            let fixture = try await OptionsQualifiedSummaryFixture.make(testCase: self)
            let provider = OptionsSyncSummaryProvider(defaults: fixture.defaults)
        fixture.registerProviderTeardown(provider, testCase: self)
            let old = HeldOptionsCountFetcher()
            defer { old.release(.success(.zero)) }
            refresh(provider, fixture: fixture, remote: old, signedIn: true, reason: "A-before-ABA")
            try await waitUntil("held A before ABA") { old.entered }
            let generation = Task126OwnerStoreGate.localBodyProofAdmissionGeneration()
            let reads = provider.businessReadCountForTesting
            XCTAssertTrue(SelectedShopStore(defaults: fixture.defaults).save(fixture.otherShop(), accountHash: fixture.accountHash))
            XCTAssertFalse(provider.isBusinessSummaryCurrent(context: fixture.context, localOwnerUserID: fixture.owner))
            try await fixture.restoreOriginalShop()
            XCTAssertNotEqual(Task126OwnerStoreGate.localBodyProofAdmissionGeneration(), generation)
            XCTAssertFalse(provider.isBusinessSummaryCurrent(context: fixture.context, localOwnerUserID: fixture.owner),
                           "The unchanged request ID cannot revive an old A snapshot after ABA.")
            old.release(fails ? .failure(HeldOptionsCountFetcher.Failure.synthetic) : .success(.zero))
            try await waitUntil("old ABA completion fully settled") {
                old.returned && provider.settledRemoteCountCallbacksForTesting == 1
            }
            XCTAssertEqual(provider.businessReadCountForTesting, reads)
            XCTAssertNil(provider.syncCountDriftReport)
            XCTAssertFalse(provider.syncCountDriftCheckFailed)
            XCTAssertNil(provider.lastSyncCountDriftCheckedAt)
            XCTAssertTrue(provider.isCheckingRemoteCounts, "A stale callback cannot clean up any provider state.")
            let current = HeldOptionsCountFetcher()
            defer { current.release(.success(.zero)) }
            refresh(provider, fixture: fixture, remote: current, signedIn: true, reason: "A-after-ABA")
            try await waitUntil("new A after ABA") { current.entered }
            current.release(.success(.zero))
            try await waitUntil("new ABA drift") { provider.syncCountDriftReport != nil }
            XCTAssertTrue(provider.isBusinessSummaryCurrent(context: fixture.context, localOwnerUserID: fixture.owner))
            XCTAssertEqual(provider.syncCountDriftReport?.local.products, 1)
            XCTAssertFalse(provider.isCheckingRemoteCounts)
        }
    }

    func testInvalidJournalSuppressesBusinessReadsAndShowsInterruptedDecision() async throws {
        let fixture = try await OptionsQualifiedSummaryFixture.make(testCase: self)
        // Deliberate corruption of this fixture's real durable journal, never a fabricated permission.
        try Data([0xde, 0xad, 0xbe, 0xef]).write(to: fixture.repository.recoveryJournalURL, options: [.atomic])
        fixture.defaults.removeObject(forKey: "sync.accountBinding.v1.pendingReplacement")
        XCTAssertTrue(AccountBindingStore(defaults: fixture.defaults).hasPendingReplacementJournal)
        XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal)
        XCTAssertFalse(Task126OwnerStoreGate.permitsSameScopeLocalAccess(
            modelContainer: fixture.controller.modelContainer, ownerUserID: fixture.owner, defaults: fixture.defaults))
        let provider = OptionsSyncSummaryProvider(defaults: fixture.defaults)
        fixture.registerProviderTeardown(provider, testCase: self)
        let remote = HeldOptionsCountFetcher()
        defer { remote.release(.success(.zero)) }
        refresh(provider, fixture: fixture, remote: remote, signedIn: true, reason: "corrupt-journal")
        try await waitForDecision(provider, reason: .replacementInterrupted)
        XCTAssertFalse(provider.isBusinessSummaryAvailable)
        XCTAssertEqual(provider.businessReadCountForTesting, 0)
        XCTAssertEqual(remote.fetchCount, 0)
        XCTAssertTrue(provider.isAccountDecisionCurrent(context: fixture.context,
            localOwnerUserID: fixture.owner, authSnapshot: fixture.auth))
    }

    func testMetadataOnlyMissingBindingAndUnqualifiedSameScopeStayUnavailable() async throws {
        let fixture = try await OptionsQualifiedSummaryFixture.make(testCase: self)
        let preview = try makeContext()
        preview.insert(Product(barcode: "UNQUALIFIED-MUST-NOT-BE-COUNTED"))
        try preview.save()
        let provider = OptionsSyncSummaryProvider(defaults: fixture.defaults)
        fixture.registerProviderTeardown(provider, testCase: self)
        provider.refreshAll(context: preview, authSnapshot: fixture.auth, localOwnerUserID: fixture.owner,
            remoteCountFetcher: nil, refreshReason: "unqualified-same-scope")
        try await waitForDecision(provider, reason: .localStateUnavailable)
        XCTAssertEqual(provider.businessReadCountForTesting, 0)
        XCTAssertFalse(provider.isBusinessSummaryAvailable)
        XCTAssertTrue(AccountBindingStore(defaults: fixture.defaults).saveBinding(
            accountHash: "bogus", storeIdentity: fixture.shop.localStoreIdentity))
        provider.refreshAll(context: preview, authSnapshot: fixture.auth, localOwnerUserID: fixture.owner,
            remoteCountFetcher: nil, refreshReason: "malformed-binding-owner")
        try await waitForDecision(provider, reason: .localStateUnavailable)
        XCTAssertEqual(provider.businessReadCountForTesting, 0)
        XCTAssertEqual(AccountBindingStore(defaults: fixture.defaults).currentBinding?.accountHash, "bogus")
        AccountBindingStore(defaults: fixture.defaults).clearBinding()
        provider.refreshAll(context: preview, authSnapshot: fixture.auth, localOwnerUserID: fixture.owner,
            remoteCountFetcher: nil, refreshReason: "missing-binding")
        try await waitForDecision(provider, reason: .localStateUnavailable)
        XCTAssertEqual(provider.businessReadCountForTesting, 0)
        XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).currentBinding)
        provider.refreshAll(context: preview, authSnapshot: fixture.auth, localOwnerUserID: nil,
            remoteCountFetcher: nil, refreshReason: "missing-local-owner")
        try await waitForDecision(provider, reason: .localStateUnavailable)
        XCTAssertEqual(provider.businessReadCountForTesting, 0)
        XCTAssertFalse(provider.isBusinessSummaryAvailable)
    }

    func testOfflineLocalOwnerKeepsQualifiedSummaryWithoutRemoteSession() async throws {
        let fixture = try await OptionsQualifiedSummaryFixture.make(testCase: self)
        let provider = OptionsSyncSummaryProvider(defaults: fixture.defaults)
        fixture.registerProviderTeardown(provider, testCase: self)
        let remote = HeldOptionsCountFetcher()
        defer { remote.release(.success(.zero)) }
        refresh(provider, fixture: fixture, remote: remote, reason: "offline-local-owner")
        try await waitForSummary(provider)
        XCTAssertTrue(provider.isBusinessSummaryCurrent(context: fixture.context, localOwnerUserID: fixture.owner))
        XCTAssertEqual(provider.localDatabaseSummary.products, 1)
        XCTAssertEqual(provider.businessReadCountForTesting, 3)
        XCTAssertEqual(remote.fetchCount, 0)
        XCTAssertNil(provider.accountSyncDecision)
        let otherOwner = UUID()
        provider.refreshAll(context: fixture.context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: true, userID: otherOwner),
            localOwnerUserID: fixture.owner, remoteCountFetcher: remote, refreshReason: "different-cloud-session")
        try await waitUntil("different cloud session refresh") { !provider.isLoading }
        XCTAssertTrue(provider.isBusinessSummaryCurrent(context: fixture.context, localOwnerUserID: fixture.owner))
        XCTAssertEqual(provider.localDatabaseSummary.products, 1)
        XCTAssertEqual(remote.fetchCount, 0, "Cloud owner B must never reconcile against local owner A.")
        XCTAssertNil(provider.syncCountDriftReport)
        XCTAssertFalse(provider.isCheckingRemoteCounts)
    }

    private func refresh(_ provider: OptionsSyncSummaryProvider, fixture: OptionsQualifiedSummaryFixture,
                         remote: (any OptionsSyncRemoteCountFetching)? = nil,
                         signedIn: Bool = false, reason: String) {
        provider.refreshAll(context: fixture.context,
            authSnapshot: signedIn ? fixture.auth : OptionsSyncAuthSnapshot(isSignedIn: false, userID: nil),
            localOwnerUserID: fixture.owner, remoteCountFetcher: remote, refreshReason: reason)
    }

    private func waitForSummary(_ provider: OptionsSyncSummaryProvider, expectedProductCount: Int? = nil) async throws {
        try await waitUntil("Options summary") {
            !provider.isLoading && !provider.isStale && provider.isBusinessSummaryAvailable
                && provider.lastRefreshedAt != nil
                && (expectedProductCount.map { provider.localDatabaseSummary.products == $0 } ?? true)
        }
    }

    private func waitForDecision(_ provider: OptionsSyncSummaryProvider, reason: OwnerStoreBindingReviewReason) async throws {
        try await waitUntil("account decision \(reason)") {
            if case .promptOwnerStoreReview(let actual)? = provider.accountSyncDecision?.action {
                return !provider.isLoading && actual == reason
            }
            return false
        }
    }

    private func waitUntil(_ description: String, predicate: () -> Bool) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for \(description).")
        throw OptionsSummaryFixtureError.timedOut
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }
}

@MainActor
private final class HeldOptionsCountFetcher: OptionsSyncRemoteCountFetching {
    enum Failure: Error { case synthetic }
    private var continuation: CheckedContinuation<SyncInventoryCountSnapshot, any Error>?
    private var result: Result<SyncInventoryCountSnapshot, any Error>?
    private(set) var fetchCount = 0
    private(set) var entered = false
    private(set) var returned = false

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        fetchCount += 1
        entered = true
        defer { returned = true }
        // Deliberately ignores Task cancellation. Every caller owns a deferred release.
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func release(_ result: Result<SyncInventoryCountSnapshot, any Error>) {
        guard self.result == nil else { return }
        self.result = result
        let held = continuation
        continuation = nil
        held?.resume(with: result)
    }
}

private enum OptionsSummaryFixtureError: Error { case timedOut; case qualificationFailed }

/// Shared only by the Options unit tests. Uses persisted rows, baseline and
/// ledger, then the controller's production readback; no permission override.
@MainActor
private final class OptionsSummaryFixtureCleanupState {
    let defaults: UserDefaults
    var pendingProviderDrains = 0

    init(defaults: UserDefaults) { self.defaults = defaults }
}

@MainActor
struct OptionsQualifiedSummaryFixture {
    let defaults: UserDefaults
    let repository: SyncStoreGenerationRepository
    let controller: SyncStoreGenerationController
    let owner: UUID
    let shop: SelectedShop
    let context: ModelContext
    private let cleanupState: OptionsSummaryFixtureCleanupState
    var accountHash: String { AccountBindingStore.accountHash(for: owner) }
    var auth: OptionsSyncAuthSnapshot { OptionsSyncAuthSnapshot(isSignedIn: true, userID: owner) }

    static func make(testCase: XCTestCase, productCount: Int = 1) async throws -> Self {
        let suite = "OptionsQualifiedSummary.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let cleanupState = OptionsSummaryFixtureCleanupState(defaults: defaults)
        testCase.addTeardownBlock {
            await MainActor.run {
                // A failed/cancelled drain retains the isolated store for diagnosis.
                guard cleanupState.pendingProviderDrains == 0 else { return }
                cleanupState.defaults.removePersistentDomain(forName: suite)
                try? FileManager.default.removeItem(at: root)
            }
        }
        let owner = UUID()
        let account = AccountBindingStore.accountHash(for: owner)
        let shop = SelectedShop(shopID: UUID(), code: "OPTIONS_A", name: "Options fixture A",
            role: "owner", status: "active", selectable: true, canWrite: true)
        let selection = SelectedShopStore(defaults: defaults)
        selection.noteActiveAccount(account)
        XCTAssertTrue(selection.save(shop, accountHash: account))
        XCTAssertTrue(selection.markResolutionReady(accountHash: account))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: account, storeIdentity: shop.localStoreIdentity))
        let device = try DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID()
        let deviceHash = DeviceInstallIDStore.identityHash(for: device)
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: root.appendingPathComponent("generation-root"),
            legacyDefaultStoreURL: root.appendingPathComponent("legacy.store"), defaults: defaults)
        let binding = AccountBindingStore(defaults: defaults)
        XCTAssertEqual(binding.durableRecoveryJournalURLForTesting, repository.recoveryJournalURL)
        XCTAssertTrue(binding.beginSameScopeRecovery(accountHash: account, storeIdentity: shop.localStoreIdentity,
            reason: "options-unit-body", deviceIdentityHash: deviceHash))
        let staging = try repository.prepareStaging(accountHash: account, shopID: shop.shopID,
            storeIdentity: shop.localStoreIdentity, deviceIdentityHash: deviceHash)
        let empty = ShopSyncRecoveryEntityDigest(activeCount: 0, tombstoneCount: 0,
            idSetDigest: ShopSyncRecoveryCanonical.checkpointChainInitialDigest,
            versionDigest: ShopSyncRecoveryCanonical.checkpointChainInitialDigest)
        let emptyProducts = ShopSyncRecoveryEntityDigest(activeCount: 0, tombstoneCount: 0,
            idSetDigest: empty.idSetDigest, versionDigest: empty.versionDigest, identityDigest: empty.idSetDigest)
        let scope = ShopSyncRecoveryScope(kind: "shop_scoped",
            key: ShopSyncRecoveryCanonical.sha256(shop.shopID.uuidString.lowercased() + ":shop_scoped:-:" + deviceHash),
            legacyOwnerKey: nil, accountKey: account, deviceKey: deviceHash)
        func checkpoint(products: ShopSyncRecoveryEntityDigest) -> ShopSyncRecoveryCheckpoint {
            ShopSyncRecoveryCheckpoint(schemaVersion: "shop-sync-recovery-checkpoint-v1", shopId: shop.shopID,
                scope: scope, syncEvents: ShopSyncRecoveryEventCheckpoint(maxId: "41", verifiedBaselineId: "0",
                    requiresFullRecovery: true,
                    domainMaxIds: .init(catalog: "41", prices: "41", history: "41")),
                catalog: .init(suppliers: empty, categories: empty, products: products,
                    digest: ShopSyncRecoveryCanonical.sha256(empty.versionDigest + "\n" + empty.versionDigest + "\n" + products.versionDigest)),
                prices: empty, history: empty, images: empty,
                integrity: .init(productCategoryViolationCount: 0, productSupplierViolationCount: 0,
                    priceProductViolationCount: 0, primaryImageViolationCount: 0, historyIdViolationCount: 0, totalViolationCount: 0),
                checkpointDigest: ShopSyncRecoveryCanonical.sha256("options-fixture-\(owner.uuidString)-\(productCount)"))
        }
        let base = checkpoint(products: emptyProducts)
        let rows = (0..<productCount).map { index in
            RemoteInventoryProductRow(id: UUID(), ownerUserID: owner, shopID: shop.shopID,
                barcode: "OPTIONS_\(index)", itemNumber: nil, productName: "Options body \(index)",
                secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil,
                stockQuantity: nil, updatedAt: "2026-07-21T12:00:00.000000Z", deletedAt: nil)
        }.sorted { $0.id.uuidString.lowercased() < $1.id.uuidString.lowercased() }
        var digest = ShopSyncRecoveryDigestAccumulator(hasIdentity: true)
        let ledger = try ShopSyncRecoveryLedger(generationStoreURL: staging.storeURL)
        let baselineID = UUID()
        let stagingContext = ModelContext(staging.container)
        stagingContext.autosaveEnabled = false
        for row in rows {
            let record = try ShopSyncRecoveryRowContract.product(row, checkpoint: base)
            try digest.append(orderingID: record.orderingID, idLine: record.idLine,
                versionLine: record.versionLine, identityLine: record.identityLine, isTombstone: record.isTombstone)
            try ledger.append(record, domain: .products)
            let updatedAt = try XCTUnwrap(SupabaseRemoteDateParser.parse(row.updatedAt))
            stagingContext.insert(Product(barcode: row.barcode, remoteID: row.id,
                remoteUpdatedAt: updatedAt, itemNumber: row.itemNumber, productName: row.productName))
            let canonical = ManualPushFingerprintNormalizer.product(barcode: row.barcode,
                itemNumber: row.itemNumber, productName: row.productName, secondProductName: row.secondProductName,
                purchasePrice: row.purchasePrice, retailPrice: row.retailPrice, stockQuantity: row.stockQuantity,
                supplierRemoteID: row.supplierID, categoryRemoteID: row.categoryID).canonicalString
            stagingContext.insert(SupabaseCatalogBaselineRecord(baselineRunID: baselineID, ownerUserUUID: owner,
                entityType: .product, remoteID: row.id, remoteUpdatedAt: updatedAt,
                fingerprintCanonical: canonical, barcodeCanonical: ManualPushFingerprintNormalizer.semanticString(row.barcode)))
        }
        stagingContext.insert(SupabaseCatalogBaselineRun(baselineRunID: baselineID, ownerUserUUID: owner,
            status: .valid, appliedAt: Date(timeIntervalSince1970: 1_000), productCount: productCount,
            supplierCount: 0, categoryCount: 0, tombstoneCount: 0))
        try stagingContext.save()
        try ledger.closeWrites()
        let verifiedCheckpoint = checkpoint(products: digest.finalize())
        let receipt = try ledger.receipt(relationshipViolationCount: 0, pendingLocalCount: 0, outboxCount: 0)
        XCTAssertTrue(receipt.matches(verifiedCheckpoint))
        XCTAssertTrue(binding.recordPendingRecoveryStaging(accountHash: account, storeIdentity: shop.localStoreIdentity,
            deviceIdentityHash: deviceHash, generationID: staging.generationID))
        XCTAssertTrue(binding.recordPendingRecoveryVerified(accountHash: account, storeIdentity: shop.localStoreIdentity,
            deviceIdentityHash: deviceHash, generationID: staging.generationID,
            checkpointDigest: verifiedCheckpoint.checkpointDigest,
            watermark: try XCTUnwrap(verifiedCheckpoint.maxEventID), baselineRunID: baselineID))
        let journal = try XCTUnwrap(binding.pendingRecoveryJournal)
        let activated = try repository.activate(staging, mutationFence: repository.captureMutationFence(for: staging),
            checkpointBeforeDownload: verifiedCheckpoint, checkpoint: verifiedCheckpoint,
            localVerification: receipt, baselineRunID: baselineID, journal: journal)
        let manifest = try XCTUnwrap(activated.manifest)
        XCTAssertEqual(manifest.generationID, staging.generationID)
        // Archive construction only: validate the actual body before the same
        // durable finalization API used by repository contract fixtures.
        try LocalCatalogBodyProofStore.validate(container: activated.container, manifest: manifest,
                                               storeURL: staging.storeURL)
        try repository.markRecoveryFinalized(manifest)
        binding.clearPendingReplacement()
        XCTAssertFalse(binding.hasPendingReplacementJournal)
        let controller = try SyncStoreGenerationController(repository: repository, defaults: defaults)
        let qualified = await controller.awaitLocalBodyQualification()
        XCTAssertTrue(qualified, "The actual persisted catalog readback must qualify before provider tests start.")
        guard qualified else { throw OptionsSummaryFixtureError.qualificationFailed }
        let context = ModelContext(controller.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), productCount)
        let allowed = Task126OwnerStoreGate.permitsSameScopeLocalAccess(
            modelContainer: controller.modelContainer, ownerUserID: owner, defaults: defaults)
        XCTAssertTrue(allowed)
        guard allowed else { throw OptionsSummaryFixtureError.qualificationFailed }
        return Self(defaults: defaults, repository: repository, controller: controller,
                    owner: owner, shop: shop, context: context, cleanupState: cleanupState)
    }

    func registerProviderTeardown(_ provider: OptionsSyncSummaryProvider, testCase: XCTestCase) {
        cleanupState.pendingProviderDrains += 1
        testCase.addTeardownBlock {
            await MainActor.run {
                provider.refreshAll(context: self.context,
                    authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: false, userID: nil),
                    localOwnerUserID: nil, remoteCountFetcher: nil, refreshReason: "fixture-teardown")
            }
            for _ in 0..<200 {
                if await MainActor.run(body: {
                    guard !provider.isLoading,
                          provider.outstandingRemoteCountCallbacksForTesting == 0 else { return false }
                    self.cleanupState.pendingProviderDrains -= 1
                    return true
                }) { return }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTFail("Options provider did not drain before fixture teardown.")
        }
    }

    func otherShop() -> SelectedShop {
        SelectedShop(shopID: UUID(), code: "OPTIONS_B", name: "Options fixture B",
            role: "owner", status: "active", selectable: true, canWrite: true)
    }

    func restoreOriginalShop() async throws {
        XCTAssertTrue(SelectedShopStore(defaults: defaults).save(shop, accountHash: accountHash))
        controller.startLocalBodyQualification(ownerUserID: owner)
        let qualified = await controller.awaitLocalBodyQualification()
        XCTAssertTrue(qualified)
        guard qualified else { throw OptionsSummaryFixtureError.qualificationFailed }
        XCTAssertTrue(Task126OwnerStoreGate.permitsSameScopeLocalAccess(
            modelContainer: controller.modelContainer, ownerUserID: owner, defaults: defaults))
    }

    func insertLocalProduct(barcode: String) throws {
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: controller.modelContainer,
            ownerUserID: owner, defaults: defaults) { context in
            context.insert(Product(barcode: barcode))
            try context.save()
        }
    }
}
