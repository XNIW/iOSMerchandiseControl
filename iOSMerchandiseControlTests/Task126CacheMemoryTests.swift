import XCTest
@testable import iOSMerchandiseControl

final class Task126CacheMemoryTests: XCTestCase {
    func testCacheManifestPrivacySnapshotRedactsOwnerAndStore() {
        let manifest = Task126CacheManifest(
            ownerHash: "raw-owner-hash",
            storeId: "raw-store-id",
            localStoreId: "raw-local-store-id",
            schemaVersion: 2,
            syncProtocolVersion: 126,
            storeEpoch: 1,
            isActive: true,
            isDirty: false,
            estimatedBytes: 1_024
        )

        let snapshot = manifest.privacySafeSnapshot

        XCTAssertFalse(snapshot.description.contains("raw-owner-hash"))
        XCTAssertFalse(snapshot.description.contains("raw-store-id"))
        XCTAssertFalse(snapshot.description.contains("raw-local-store-id"))
        XCTAssertEqual(snapshot.ownerHashRedacted, "redacted:owner")
        XCTAssertEqual(snapshot.storeIdRedacted, "redacted:store")
    }

    func testActiveStoreOnlyKeepsInactiveCacheClosed() {
        let active = Task126CacheManifest.fixture(storeId: "store-a", isActive: true, isDirty: false)
        let inactive = Task126CacheManifest.fixture(storeId: "store-b", isActive: false, isDirty: false)

        let decision = Task126CachePolicy.validateActiveStoreOnly(
            activeStoreId: "store-a",
            loadedManifests: [active, inactive]
        )

        XCTAssertEqual(decision, .blocked(reason: .inactiveStoreLoaded))
    }

    func testInactiveDirtyCacheRequiresBackupExportBeforeCleanup() {
        let dirtyInactive = Task126CacheManifest.fixture(storeId: "store-b", isActive: false, isDirty: true)

        XCTAssertEqual(
            Task126CachePolicy.cleanupDecision(for: dirtyInactive),
            .keepDirtyRequiresBackupExport
        )
    }

    func testProductPricePageLimitCapsMemoryBudget() {
        XCTAssertEqual(Task126ProductPriceHistoryPolicy.pageLimit(requested: 20_000), 500)
        XCTAssertEqual(Task126ProductPriceHistoryPolicy.pageLimit(requested: 100), 100)
    }
}
