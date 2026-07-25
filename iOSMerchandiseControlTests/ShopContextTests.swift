import XCTest
@testable import iOSMerchandiseControl

final class ShopContextTests: XCTestCase {
    func testZeroLinkedShopsKeepsLegacyCleanPresentation() {
        let persisted = selectedShop(id: UUID(), name: "Old shop")

        let resolution = ShopContextResolver.resolve(
            accountHash: "account-a",
            linkedShops: [],
            persistedSelection: persisted,
            now: Date(timeIntervalSince1970: 10)
        )
        let presentation = InventoryHomeShopContextPresentation.make(context: resolution.context)

        XCTAssertNil(resolution.context.selectedShop)
        XCTAssertNil(resolution.selectedShopToPersist)
        XCTAssertFalse(resolution.context.syncAllowed)
        XCTAssertNil(presentation.shopName)
        XCTAssertFalse(presentation.showsSwitcher)
        XCTAssertNil(presentation.activeShopID)
    }

    func testOneLinkedShopAutoSelectsAndShowsNameWithoutSwitcher() {
        let shop = linkedShop(id: UUID(), name: "Centro")

        let resolution = ShopContextResolver.resolve(
            accountHash: "account-a",
            linkedShops: [shop],
            persistedSelection: nil,
            now: Date(timeIntervalSince1970: 20)
        )
        let presentation = InventoryHomeShopContextPresentation.make(context: resolution.context)

        XCTAssertEqual(resolution.context.selectedShop?.shopID, shop.shopID)
        XCTAssertEqual(resolution.selectedShopToPersist?.shopID, shop.shopID)
        XCTAssertEqual(presentation.shopName, "Centro")
        XCTAssertFalse(presentation.showsSwitcher)
        XCTAssertEqual(presentation.activeShopID, shop.shopID)
    }

    func testMobileLinkedShopRPCDecoderReadsJsonbWrapperContract() throws {
        let shopID = UUID()
        let payload = """
        {
          "ok": true,
          "code": "success",
          "shops": [
            {
              "shop_id": "\(shopID.uuidString)",
              "shop_code": "TASK068E",
              "shop_name": "TASK068E REHEARSAL",
              "role_key": "shop_owner",
              "membership_status": "active",
              "shop_status": "active",
              "can_select": true,
              "can_write": true
            }
          ]
        }
        """.data(using: .utf8)!

        let shops = try MobileLinkedShopRPCDecoder.decode(payload)

        XCTAssertEqual(shops.count, 1)
        XCTAssertEqual(shops.first?.shopID, shopID)
        XCTAssertEqual(shops.first?.name, "TASK068E REHEARSAL")
        XCTAssertTrue(shops.first?.isValidSelection == true)
    }

    func testMobileLinkedShopRPCDecoderKeepsLegacyArrayCompatibility() throws {
        let shopID = UUID()
        let payload = """
        [
          {
            "shop_id": "\(shopID.uuidString)",
            "shop_name": "Legacy Array Shop",
            "shop_status": "active",
            "can_select": true,
            "can_write": true
          }
        ]
        """.data(using: .utf8)!

        let shops = try MobileLinkedShopRPCDecoder.decode(payload)

        XCTAssertEqual(shops.count, 1)
        XCTAssertEqual(shops.first?.shopID, shopID)
        XCTAssertEqual(shops.first?.name, "Legacy Array Shop")
    }

    func testMobileLinkedShopRPCDecoderTreatsOkFalseAsBlockingError() throws {
        let payload = """
        {
          "ok": false,
          "code": "unauthorized",
          "shops": []
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try MobileLinkedShopRPCDecoder.decode(payload)) { error in
            XCTAssertEqual(error as? MobileLinkedShopRPCDecoder.DecodeError, .rpcFailed(code: "unauthorized"))
        }
    }

    @MainActor
    func testMultipleLinkedShopsSwitchesSelectedShopAndSyncStoreScopeTogether() async {
        let ownerUserID = UUID()
        let defaults = makeDefaults()
        let selectedStore = SelectedShopStore(defaults: defaults)
        let bindingStore = AccountBindingStore(defaults: defaults)
        let originalBinding = LocalStoreIdentity(rawValue: "existing-owner-store")
        XCTAssertTrue(bindingStore.saveBinding(
            accountHash: AccountBindingStore.accountHash(for: ownerUserID),
            storeIdentity: originalBinding
        ))
        let alpha = linkedShop(id: UUID(), name: "Alpha")
        let beta = linkedShop(id: UUID(), name: "Beta")
        let contextStore = ShopContextStore(
            fetcher: StaticLinkedShopFetcher(shops: [alpha, beta]),
            selectedStore: selectedStore,
            accountBindingStore: bindingStore,
            now: { Date(timeIntervalSince1970: 30) }
        )

        await contextStore.refresh(ownerUserID: ownerUserID)
        XCTAssertNil(contextStore.context.selectedShop)
        XCTAssertFalse(contextStore.context.syncAllowed)
        XCTAssertFalse(selectedStore.isResolutionReady(
            accountHash: AccountBindingStore.accountHash(for: ownerUserID)
        ))
        contextStore.selectShop(beta.shopID)

        let presentation = InventoryHomeShopContextPresentation.make(context: contextStore.context)
        XCTAssertEqual(contextStore.context.selectedShop?.shopID, beta.shopID)
        XCTAssertEqual(presentation.shopName, "Beta")
        XCTAssertTrue(presentation.showsSwitcher)
        XCTAssertEqual(presentation.activeShopID, beta.shopID)
        XCTAssertEqual(selectedStore.selectedShopID(ownerUserID: ownerUserID), beta.shopID)
        XCTAssertEqual(selectedStore.localStoreIdentity(ownerUserID: ownerUserID).storeId, beta.shopID.uuidString.lowercased())
        XCTAssertTrue(selectedStore.isResolutionReady(
            accountHash: AccountBindingStore.accountHash(for: ownerUserID)
        ))
        XCTAssertEqual(bindingStore.currentBinding?.storeIdentity, originalBinding)
    }

    func testSelectedShopPersistenceIsAccountScoped() {
        let defaults = makeDefaults()
        let store = SelectedShopStore(defaults: defaults)
        let accountA = AccountBindingStore.accountHash(for: UUID())
        let accountB = AccountBindingStore.accountHash(for: UUID())
        let shopA = selectedShop(id: UUID(), name: "Account A Shop")
        let shopB = selectedShop(id: UUID(), name: "Account B Shop")

        store.save(shopA, accountHash: accountA)
        store.save(shopB, accountHash: accountB)

        XCTAssertEqual(store.selectedShop(accountHash: accountA)?.shopID, shopA.shopID)
        XCTAssertEqual(store.selectedShop(accountHash: accountB)?.shopID, shopB.shopID)
    }

    @MainActor
    func testLinkedShopFetchErrorBlocksSyncWithoutSavingAnonymousBinding() async {
        let ownerUserID = UUID()
        let defaults = makeDefaults()
        let selectedStore = SelectedShopStore(defaults: defaults)
        let accountBindingStore = AccountBindingStore(defaults: defaults)
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        XCTAssertTrue(selectedStore.markResolutionReady(accountHash: accountHash))
        let contextStore = ShopContextStore(
            fetcher: ThrowingLinkedShopFetcher(),
            selectedStore: selectedStore,
            accountBindingStore: accountBindingStore,
            now: { Date(timeIntervalSince1970: 35) }
        )

        await contextStore.refresh(ownerUserID: ownerUserID)

        XCTAssertFalse(contextStore.context.syncAllowed)
        XCTAssertNil(contextStore.context.selectedShop)
        XCTAssertFalse(selectedStore.isResolutionReady(accountHash: accountHash))
        XCTAssertNil(accountBindingStore.currentBinding)
    }

    @MainActor
    func testLinkedShopFetchErrorNeverClearsExistingOwnerBinding() async {
        let ownerUserID = UUID()
        let defaults = makeDefaults()
        let accountBindingStore = AccountBindingStore(defaults: defaults)
        let originalAccountHash = AccountBindingStore.accountHash(for: UUID())
        let originalStore = LocalStoreIdentity(rawValue: "original-shop")
        XCTAssertTrue(accountBindingStore.saveBinding(
            accountHash: originalAccountHash,
            storeIdentity: originalStore
        ))
        let contextStore = ShopContextStore(
            fetcher: ThrowingLinkedShopFetcher(),
            selectedStore: SelectedShopStore(defaults: defaults),
            accountBindingStore: accountBindingStore
        )

        await contextStore.refresh(ownerUserID: ownerUserID)

        XCTAssertFalse(contextStore.context.syncAllowed)
        XCTAssertEqual(accountBindingStore.currentBinding?.accountHash, originalAccountHash)
        XCTAssertEqual(accountBindingStore.currentBinding?.storeIdentity, originalStore)
    }

    @MainActor
    func testColdOfflineRestoresPersistedShopOnlyForVerifiedOwnerBinding() async {
        let ownerUserID = UUID()
        let defaults = makeDefaults()
        let selectedStore = SelectedShopStore(defaults: defaults)
        let bindingStore = AccountBindingStore(defaults: defaults)
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let persisted = selectedShop(id: UUID(), name: "Offline shop")
        XCTAssertTrue(selectedStore.save(persisted, accountHash: accountHash))
        XCTAssertTrue(bindingStore.saveBinding(
            accountHash: accountHash,
            storeIdentity: persisted.localStoreIdentity
        ))
        let contextStore = ShopContextStore(
            fetcher: ThrowingLinkedShopFetcher(),
            selectedStore: selectedStore,
            accountBindingStore: bindingStore
        )

        await contextStore.refresh(ownerUserID: ownerUserID)

        XCTAssertEqual(contextStore.context.accountHash, accountHash)
        XCTAssertEqual(contextStore.context.selectedShop, persisted)
        XCTAssertFalse(contextStore.context.syncAllowed)
        XCTAssertFalse(selectedStore.isResolutionReady(accountHash: accountHash))
    }

    @MainActor
    func testColdOfflineRejectsPersistedShopDuringReplacementJournal() async {
        let ownerUserID = UUID()
        let defaults = makeDefaults()
        let selectedStore = SelectedShopStore(defaults: defaults)
        let bindingStore = AccountBindingStore(defaults: defaults)
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let persisted = selectedShop(id: UUID(), name: "Pending replacement")
        XCTAssertTrue(selectedStore.save(persisted, accountHash: accountHash))
        XCTAssertTrue(bindingStore.saveBinding(
            accountHash: accountHash,
            storeIdentity: persisted.localStoreIdentity
        ))
        XCTAssertTrue(bindingStore.beginReplacement(
            accountHash: accountHash,
            storeIdentity: persisted.localStoreIdentity
        ))
        let contextStore = ShopContextStore(
            fetcher: ThrowingLinkedShopFetcher(),
            selectedStore: selectedStore,
            accountBindingStore: bindingStore
        )

        await contextStore.refresh(ownerUserID: ownerUserID)

        XCTAssertNil(contextStore.context.selectedShop)
        XCTAssertFalse(contextStore.context.syncAllowed)
    }

    @MainActor
    func testColdOfflineRejectsPersistedShopDuringUndecodableReplacementJournal() async {
        let ownerUserID = UUID()
        let defaults = makeDefaults()
        let selectedStore = SelectedShopStore(defaults: defaults)
        let bindingStore = AccountBindingStore(defaults: defaults)
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let persisted = selectedShop(id: UUID(), name: "Corrupt replacement")
        XCTAssertTrue(selectedStore.save(persisted, accountHash: accountHash))
        XCTAssertTrue(bindingStore.saveBinding(
            accountHash: accountHash,
            storeIdentity: persisted.localStoreIdentity
        ))
        defaults.set(Data([0xFF, 0x00]), forKey: "sync.accountBinding.v1.pendingReplacement")
        XCTAssertNil(bindingStore.pendingReplacement)
        XCTAssertTrue(bindingStore.hasPendingReplacementJournal)
        let contextStore = ShopContextStore(
            fetcher: ThrowingLinkedShopFetcher(),
            selectedStore: selectedStore,
            accountBindingStore: bindingStore
        )

        await contextStore.refresh(ownerUserID: ownerUserID)

        XCTAssertNil(contextStore.context.selectedShop)
        XCTAssertFalse(contextStore.context.syncAllowed)
    }

    @MainActor
    func testLateShopRefreshFromPreviousAccountCannotOverwriteCurrentAccount() async throws {
        let ownerA = UUID()
        let ownerB = UUID()
        let shopA = linkedShop(id: UUID(), name: "Shop A")
        let shopB = linkedShop(id: UUID(), name: "Shop B")
        let defaults = makeDefaults()
        let fetcher = DeferredLinkedShopFetcher()
        let contextStore = ShopContextStore(
            fetcher: fetcher,
            selectedStore: SelectedShopStore(defaults: defaults),
            accountBindingStore: AccountBindingStore(defaults: defaults)
        )

        let refreshA = Task { await contextStore.refresh(ownerUserID: ownerA) }
        try await fetcher.waitForCallCount(1)
        let refreshB = Task { await contextStore.refresh(ownerUserID: ownerB) }
        try await fetcher.waitForCallCount(2)
        await fetcher.resume(call: 1, shops: [shopB])
        await refreshB.value
        await fetcher.resume(call: 0, shops: [shopA])
        await refreshA.value

        XCTAssertEqual(
            contextStore.context.accountHash,
            AccountBindingStore.accountHash(for: ownerB)
        )
        XCTAssertEqual(contextStore.context.selectedShop?.shopID, shopB.shopID)
        XCTAssertNotEqual(contextStore.context.selectedShop?.shopID, shopA.shopID)
    }

    @MainActor
    func testLateSameAccountRefreshCannotOverwriteNewerManualSelection() async throws {
        let ownerUserID = UUID()
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let shopA = linkedShop(id: UUID(), name: "Shop A")
        let shopB = linkedShop(id: UUID(), name: "Shop B")
        let defaults = makeDefaults()
        let selectedStore = SelectedShopStore(defaults: defaults)
        XCTAssertTrue(selectedStore.save(
            SelectedShop(linkedShop: shopA, selectedAt: Date(timeIntervalSince1970: 1)),
            accountHash: accountHash
        ))
        let fetcher = DeferredLinkedShopFetcher()
        let contextStore = ShopContextStore(
            fetcher: fetcher,
            selectedStore: selectedStore,
            accountBindingStore: AccountBindingStore(defaults: defaults)
        )

        let initialRefresh = Task { await contextStore.refresh(ownerUserID: ownerUserID) }
        try await fetcher.waitForCallCount(1)
        await fetcher.resume(call: 0, shops: [shopA, shopB])
        await initialRefresh.value

        let staleRefresh = Task { await contextStore.refresh(ownerUserID: ownerUserID) }
        try await fetcher.waitForCallCount(2)
        contextStore.selectShop(shopB.shopID, ownerUserID: ownerUserID)
        await fetcher.resume(call: 1, shops: [shopA, shopB])
        await staleRefresh.value

        XCTAssertEqual(contextStore.context.selectedShop?.shopID, shopB.shopID)
        XCTAssertEqual(selectedStore.selectedShop(accountHash: accountHash)?.shopID, shopB.shopID)
    }

    @MainActor
    func testRevokedPersistedShopFallsBackToOnlyRemainingValidShop() async {
        let ownerUserID = UUID()
        let defaults = makeDefaults()
        let selectedStore = SelectedShopStore(defaults: defaults)
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let revokedID = UUID()
        let valid = linkedShop(id: UUID(), name: "Valid")
        selectedStore.save(selectedShop(id: revokedID, name: "Revoked"), accountHash: accountHash)

        let contextStore = ShopContextStore(
            fetcher: StaticLinkedShopFetcher(shops: [
                linkedShop(id: revokedID, name: "Revoked", status: "revoked", selectable: false),
                valid
            ]),
            selectedStore: selectedStore,
            accountBindingStore: AccountBindingStore(defaults: defaults),
            now: { Date(timeIntervalSince1970: 40) }
        )

        await contextStore.refresh(ownerUserID: ownerUserID)
        let presentation = InventoryHomeShopContextPresentation.make(context: contextStore.context)

        XCTAssertEqual(contextStore.context.selectedShop?.shopID, valid.shopID)
        XCTAssertEqual(selectedStore.selectedShopID(ownerUserID: ownerUserID), valid.shopID)
        XCTAssertEqual(presentation.shopName, "Valid")
        XCTAssertFalse(presentation.showsSwitcher)
    }

    @MainActor
    func testRevokedOnlyShopClearsSelectionAndReturnsLegacyPresentation() async {
        let ownerUserID = UUID()
        let defaults = makeDefaults()
        let selectedStore = SelectedShopStore(defaults: defaults)
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let revokedID = UUID()
        selectedStore.save(selectedShop(id: revokedID, name: "Revoked"), accountHash: accountHash)

        let contextStore = ShopContextStore(
            fetcher: StaticLinkedShopFetcher(shops: [
                linkedShop(id: revokedID, name: "Revoked", status: "suspended", selectable: false)
            ]),
            selectedStore: selectedStore,
            accountBindingStore: AccountBindingStore(defaults: defaults),
            now: { Date(timeIntervalSince1970: 50) }
        )

        await contextStore.refresh(ownerUserID: ownerUserID)
        let presentation = InventoryHomeShopContextPresentation.make(context: contextStore.context)

        XCTAssertNil(contextStore.context.selectedShop)
        XCTAssertNil(selectedStore.selectedShopID(ownerUserID: ownerUserID))
        XCTAssertFalse(contextStore.context.syncAllowed)
        XCTAssertFalse(selectedStore.isResolutionReady(accountHash: accountHash))
        XCTAssertNil(presentation.shopName)
        XCTAssertFalse(presentation.showsSwitcher)
    }

    private func linkedShop(
        id: UUID,
        name: String,
        role: String = "owner",
        status: String = "active",
        selectable: Bool = true,
        canWrite: Bool = true
    ) -> LinkedShop {
        LinkedShop(
            shopID: id,
            code: nil,
            name: name,
            role: role,
            status: status,
            selectable: selectable,
            canWrite: canWrite
        )
    }

    private func selectedShop(id: UUID, name: String) -> SelectedShop {
        SelectedShop(
            shopID: id,
            code: nil,
            name: name,
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true,
            selectedAt: Date(timeIntervalSince1970: 1)
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ShopContextTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct StaticLinkedShopFetcher: LinkedShopFetching {
    let shops: [LinkedShop]

    func fetchLinkedShops() async throws -> [LinkedShop] {
        shops
    }
}

private struct ThrowingLinkedShopFetcher: LinkedShopFetching {
    func fetchLinkedShops() async throws -> [LinkedShop] {
        throw MobileLinkedShopRPCDecoder.DecodeError.rpcFailed(code: "unavailable")
    }
}

private actor DeferredLinkedShopFetcher: LinkedShopFetching {
    private var continuations: [CheckedContinuation<[LinkedShop], Error>?] = []

    func fetchLinkedShops() async throws -> [LinkedShop] {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForCallCount(_ expected: Int) async throws {
        for _ in 0..<200 {
            if continuations.count >= expected { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw DeferredLinkedShopFetcherError.timedOut
    }

    func resume(call index: Int, shops: [LinkedShop]) {
        guard continuations.indices.contains(index),
              let continuation = continuations[index] else { return }
        continuations[index] = nil
        continuation.resume(returning: shops)
    }
}

private enum DeferredLinkedShopFetcherError: Error {
    case timedOut
}
