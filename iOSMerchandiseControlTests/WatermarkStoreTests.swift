import XCTest
@testable import iOSMerchandiseControl

final class WatermarkStoreTests: XCTestCase {
    func testWatermarkIsAccountAndStoreBound() {
        let suiteName = "WatermarkStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = WatermarkStore(defaults: defaults)
        let accountA = WatermarkStore.Scope(accountHash: "account-a", storeIdentity: LocalStoreIdentity(rawValue: "store-a"))
        let accountB = WatermarkStore.Scope(accountHash: "account-b", storeIdentity: LocalStoreIdentity(rawValue: "store-a"))
        let storeB = WatermarkStore.Scope(accountHash: "account-a", storeIdentity: LocalStoreIdentity(rawValue: "store-b"))

        store.save(42, for: accountA)

        XCTAssertEqual(store.watermark(for: accountA), 42)
        XCTAssertEqual(store.watermark(for: accountB), 0)
        XCTAssertEqual(store.watermark(for: storeB), 0)
        XCTAssertEqual(
            defaults.integer(forKey: WatermarkStore.watermarkKey(accountHash: "account-a", storeIdentity: LocalStoreIdentity(rawValue: "store-a"))),
            42
        )
    }

    func testWatermarkDoesNotMoveBackwards() {
        let suiteName = "WatermarkStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = WatermarkStore(defaults: defaults)
        let scope = WatermarkStore.Scope(accountHash: "account-a", storeIdentity: LocalStoreIdentity(rawValue: "store-a"))

        store.save(100, for: scope)
        store.save(90, for: scope)

        XCTAssertEqual(store.watermark(for: scope), 100)
    }

    func testLegacyOwnerWatermarkCanBeReadDuringMigration() {
        let suiteName = "WatermarkStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let ownerID = UUID()
        let store = WatermarkStore(defaults: defaults)
        defaults.set(77, forKey: "task114.syncEvents.watermark.\(ownerID.uuidString.lowercased())")

        let scope = WatermarkStore.Scope(ownerUserID: ownerID, storeIdentity: .anonymous)

        XCTAssertEqual(store.watermark(for: scope), 77)
    }

    func testLegacyAccountWatermarkCanBeReadDuringLegacyMigrationOnly() {
        let suiteName = "WatermarkStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = WatermarkStore(defaults: defaults)
        let scope = WatermarkStore.Scope(accountHash: "account-a", storeIdentity: .anonymous)
        defaults.set(88, forKey: WatermarkStore.legacyAccountWatermarkKey(accountHash: "account-a", storeIdentity: .anonymous))

        XCTAssertEqual(store.watermark(for: scope), 88)
    }

    func testShopScopedWatermarkDoesNotInheritLegacyOwnerOrAccountWatermark() {
        let suiteName = "WatermarkStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let ownerID = UUID()
        let store = WatermarkStore(defaults: defaults)
        let shopStore = LocalStoreIdentity(rawValue: "store-a")
        defaults.set(77, forKey: WatermarkStore.legacyOwnerWatermarkKey(ownerUserID: ownerID))
        defaults.set(88, forKey: WatermarkStore.legacyAccountWatermarkKey(accountHash: "account-a", storeIdentity: shopStore))

        let scope = WatermarkStore.Scope(accountHash: "account-a", storeIdentity: shopStore, legacyOwnerUserID: ownerID)

        XCTAssertEqual(store.watermark(for: scope), 0)
    }

    func testAuthoritativeRecoveryReplacesStaleCursorFromDiscardedGeneration() {
        let suiteName = "WatermarkStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = WatermarkStore(defaults: defaults)
        let scope = WatermarkStore.Scope(
            accountHash: "account-a",
            storeIdentity: LocalStoreIdentity(rawValue: "store-a")
        )
        let recoveredGeneration = UUID()
        store.save(900, for: scope)

        XCTAssertTrue(store.saveAuthoritativeRecoveryCheckpoint(
            41,
            generationID: recoveredGeneration,
            for: scope
        ))

        XCTAssertEqual(store.watermark(for: scope), 41)
        XCTAssertEqual(defaults.object(forKey: store.key(for: scope)) as? Int, 41)
    }

    func testTerminalRepairPreservesNewerCursorForSameGeneration() {
        let suiteName = "WatermarkStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = WatermarkStore(defaults: defaults)
        let scope = WatermarkStore.Scope(
            accountHash: "account-a",
            storeIdentity: LocalStoreIdentity(rawValue: "store-a")
        )
        let generationID = UUID()
        XCTAssertTrue(store.saveAuthoritativeRecoveryCheckpoint(
            41,
            generationID: generationID,
            for: scope
        ))
        store.save(55, for: scope)

        XCTAssertTrue(store.restoreAuthoritativeRecoveryCheckpoint(
            41,
            generationID: generationID,
            for: scope
        ))

        XCTAssertEqual(store.watermark(for: scope), 55)
        XCTAssertEqual(defaults.object(forKey: store.key(for: scope)) as? Int, 55)
    }

    func testTerminalRepairRestoresMissingMirrorAfterRelaunch() {
        let suiteName = "WatermarkStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scope = WatermarkStore.Scope(
            accountHash: "account-a",
            storeIdentity: LocalStoreIdentity(rawValue: "store-a")
        )
        let generationID = UUID()
        let firstLaunch = WatermarkStore(defaults: defaults)
        XCTAssertTrue(firstLaunch.saveAuthoritativeRecoveryCheckpoint(
            41,
            generationID: generationID,
            for: scope
        ))
        defaults.removeObject(forKey: firstLaunch.key(for: scope))
        XCTAssertNil(defaults.object(forKey: firstLaunch.key(for: scope)))

        let relaunched = WatermarkStore(defaults: defaults)
        XCTAssertTrue(relaunched.restoreAuthoritativeRecoveryCheckpoint(
            41,
            generationID: generationID,
            for: scope
        ))

        XCTAssertEqual(relaunched.watermark(for: scope), 41)
        XCTAssertEqual(defaults.object(forKey: relaunched.key(for: scope)) as? Int, 41)
    }
}
