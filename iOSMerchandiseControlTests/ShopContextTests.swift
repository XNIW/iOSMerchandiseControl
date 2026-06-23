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
        let alpha = linkedShop(id: UUID(), name: "Alpha")
        let beta = linkedShop(id: UUID(), name: "Beta")
        let contextStore = ShopContextStore(
            fetcher: StaticLinkedShopFetcher(shops: [alpha, beta]),
            selectedStore: selectedStore,
            accountBindingStore: AccountBindingStore(defaults: defaults),
            now: { Date(timeIntervalSince1970: 30) }
        )

        await contextStore.refresh(ownerUserID: ownerUserID)
        contextStore.selectShop(beta.shopID)

        let presentation = InventoryHomeShopContextPresentation.make(context: contextStore.context)
        XCTAssertEqual(contextStore.context.selectedShop?.shopID, beta.shopID)
        XCTAssertEqual(presentation.shopName, "Beta")
        XCTAssertTrue(presentation.showsSwitcher)
        XCTAssertEqual(presentation.activeShopID, beta.shopID)
        XCTAssertEqual(selectedStore.selectedShopID(ownerUserID: ownerUserID), beta.shopID)
        XCTAssertEqual(selectedStore.localStoreIdentity(ownerUserID: ownerUserID).storeId, beta.shopID.uuidString.lowercased())
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
        let contextStore = ShopContextStore(
            fetcher: ThrowingLinkedShopFetcher(),
            selectedStore: selectedStore,
            accountBindingStore: accountBindingStore,
            now: { Date(timeIntervalSince1970: 35) }
        )

        await contextStore.refresh(ownerUserID: ownerUserID)

        XCTAssertFalse(contextStore.context.syncAllowed)
        XCTAssertNil(contextStore.context.selectedShop)
        XCTAssertNil(accountBindingStore.currentBinding)
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
