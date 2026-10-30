import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class LocalRootConflictReviewRoutingTests: XCTestCase {
    func testUnqualifiedOrStaleRootCannotRequestConflictReview() async {
        let state = LocalRootPresentationState()
        state.advanceStoreGeneration(presentationID: "A")
        XCTAssertFalse(state.requestCatalogConflictReview(remoteID: UUID(), changeID: "change", presentationID: "A"))
        let owner = UUID()
        _ = state.admit(manifest: manifest(owner: owner), ownerUserID: owner,
                        presentationID: "A", localAccessPermitted: true)
        XCTAssertFalse(state.requestCatalogConflictReview(remoteID: UUID(), changeID: "change", presentationID: "old"))
        XCTAssertFalse(state.requestCatalogConflictReview(remoteID: UUID(), changeID: "", presentationID: "A"))
        XCTAssertNil(state.catalogConflictReviewRequest(presentationID: "A"))
    }

    func testStaleDismissalCannotClearNewerRequestAndDoesNotDiscardDraft() async throws {
        let owner = UUID(), state = LocalRootPresentationState()
        let current = manifest(owner: owner)
        state.advanceStoreGeneration(presentationID: "A")
        _ = state.admit(manifest: current, ownerUserID: owner,
                        presentationID: "A", localAccessPermitted: true)
        state.update(presentationID: "A") {
            $0.barcodeFilter = "preserved search"
            $0.editor = .init(remoteID: UUID(), originalBarcode: "one", baseline: nil,
                barcode: "one", name: "unsaved input", secondName: "", itemNumber: "",
                purchasePrice: "0", retailPrice: "1", stockQuantity: "2", supplierName: "",
                categoryName: "", focusedField: "name", selectionLowerBound: 2, selectionUpperBound: 5)
        }
        XCTAssertTrue(state.requestCatalogConflictReview(remoteID: UUID(), changeID: "A", presentationID: "A"))
        let old = try XCTUnwrap(state.catalogConflictReviewRequest(presentationID: "A"))
        XCTAssertTrue(state.requestCatalogConflictReview(remoteID: UUID(), changeID: "B", presentationID: "A"))
        let new = try XCTUnwrap(state.catalogConflictReviewRequest(presentationID: "A"))
        state.clearCatalogConflictReviewRequest(id: old.id, presentationID: "A")
        XCTAssertEqual(state.catalogConflictReviewRequest(presentationID: "A"), new)
        let values = try XCTUnwrap(state.admit(manifest: current, ownerUserID: owner,
            presentationID: "A", localAccessPermitted: true))
        XCTAssertEqual(values.selectedTab, 1)
        XCTAssertEqual(values.barcodeFilter, "preserved search")
        XCTAssertEqual(values.editor?.name, "unsaved input")
        XCTAssertEqual(values.editor?.selectionLowerBound, 2)
        XCTAssertEqual(values.editor?.selectionUpperBound, 5)
        state.clearCatalogConflictReviewRequest(id: new.id, presentationID: "old")
        XCTAssertEqual(state.catalogConflictReviewRequest(presentationID: "A"), new)
        state.clearCatalogConflictReviewRequest(id: new.id, presentationID: "A")
        XCTAssertNil(state.catalogConflictReviewRequest(presentationID: "A"))
    }

    func testSameScopeGenerationCarriesRequestButDifferentAccountWithdrawsIt() async throws {
        let owner = UUID(), state = LocalRootPresentationState()
        let current = manifest(owner: owner)
        state.advanceStoreGeneration(presentationID: "A")
        _ = state.admit(manifest: current, ownerUserID: owner,
                        presentationID: "A", localAccessPermitted: true)
        XCTAssertTrue(state.requestCatalogConflictReview(remoteID: UUID(), changeID: "A", presentationID: "A"))
        let request = try XCTUnwrap(state.catalogConflictReviewRequest(presentationID: "A"))
        state.advanceStoreGeneration(presentationID: "B")
        _ = state.admit(manifest: current, ownerUserID: owner,
                        presentationID: "B", localAccessPermitted: true)
        XCTAssertNil(state.catalogConflictReviewRequest(presentationID: "A"))
        XCTAssertEqual(state.catalogConflictReviewRequest(presentationID: "B"), request)
        _ = state.admit(manifest: current, ownerUserID: UUID(),
                        presentationID: "B", localAccessPermitted: true)
        XCTAssertNil(state.catalogConflictReviewRequest(presentationID: "B"))
    }

    func testSameScopeQualificationWithdrawsDraftUntilReadmittedWithoutErasingIt() async throws {
        let owner = UUID(), state = LocalRootPresentationState(), remote = UUID()
        let current = manifest(owner: owner)
        state.advanceStoreGeneration(presentationID: "A")
        _ = state.admit(manifest: current, ownerUserID: owner, presentationID: "A", localAccessPermitted: true)
        state.update(presentationID: "A") {
            $0.barcodeFilter = "kept search"
            $0.editor = .init(remoteID: remote, originalBarcode: "one", baseline: nil,
                barcode: "one", name: "kept draft", secondName: "", itemNumber: "",
                purchasePrice: "0", retailPrice: "1", stockQuantity: "2", supplierName: "",
                categoryName: "", focusedField: "name", selectionLowerBound: 1, selectionUpperBound: 4)
        }
        state.advanceStoreGeneration(presentationID: "B")
        XCTAssertNil(state.admit(manifest: current, ownerUserID: owner, presentationID: "B", localAccessPermitted: false))
        XCTAssertNil(state.editor(presentationID: "B", remoteID: remote, barcode: "one"))
        state.update(presentationID: "A") { $0.editor = nil }
        state.update(presentationID: "B") { $0.editor = nil }
        let values = try XCTUnwrap(state.admit(manifest: current, ownerUserID: owner,
            presentationID: "B", localAccessPermitted: true))
        XCTAssertEqual(values.barcodeFilter, "kept search")
        XCTAssertEqual(values.editor?.name, "kept draft")
        XCTAssertEqual(values.editor?.selectionLowerBound, 1)
        XCTAssertEqual(values.editor?.selectionUpperBound, 4)
        XCTAssertNil(state.admit(manifest: current, ownerUserID: UUID(), presentationID: "B", localAccessPermitted: true))
        XCTAssertNil(state.admit(manifest: current, ownerUserID: owner, presentationID: "B", localAccessPermitted: true)?.editor)
    }

    // Presentation-only values: these tests do not qualify a database or grant
    // any business authority. The production service still rechecks that scope.
    private func manifest(owner: UUID) -> SyncStoreGenerationManifest {
        let shop = UUID(), generation = UUID()
        let hash = AccountBindingStore.accountHash(for: owner)
        let digest = ShopSyncRecoveryEntityDigest(activeCount: 0, tombstoneCount: 0,
            idSetDigest: String(repeating: "1", count: 64), versionDigest: String(repeating: "2", count: 64))
        let checkpoint = ShopSyncRecoveryCheckpoint(schemaVersion: "shop-sync-recovery-checkpoint-v1",
            shopId: shop, scope: .init(kind: "shop_scoped", key: "presentation", legacyOwnerKey: nil,
                accountKey: hash, deviceKey: "presentation-device"), syncEvents: .init(maxId: "0"),
            catalog: .init(suppliers: digest, categories: digest, products: digest, digest: "catalog"),
            prices: digest, history: digest, images: digest,
            integrity: .init(productCategoryViolationCount: 0, productSupplierViolationCount: 0,
                priceProductViolationCount: 0, primaryImageViolationCount: 0,
                historyIdViolationCount: 0, totalViolationCount: 0), checkpointDigest: "checkpoint")
        return SyncStoreGenerationManifest(generationID: generation, relativeStorePath: "presentation.sqlite",
            accountHash: hash, shopID: shop, storeIdentity: .init(rawValue: "presentation-store"),
            deviceIdentityHash: "presentation-device", recoveryMode: .sameScopeRecovery,
            checkpointBeforeDownload: checkpoint, checkpoint: checkpoint,
            localVerification: .init(suppliers: digest, categories: digest, products: digest, prices: digest,
                history: digest, images: digest, catalogDigest: "catalog", relationshipViolationCount: 0,
                pendingLocalCount: 0, outboxCount: 0), baselineRunID: UUID())
    }
}
