import XCTest
@testable import iOSMerchandiseControl

final class CloudSyncOverviewStateTests: XCTestCase {
    func testSignedOutRequiresAccount() {
        let state = CloudSyncOverviewReducer.reduce(
            CloudSyncOverviewInput(oauthStatus: .signedOut)
        )

        XCTAssertEqual(state.category, .accountRequired)
        XCTAssertEqual(state.primaryAction, .signIn)
        XCTAssertTrue(state.isBlocking)
    }

    func testSignedInRemoteAuthFailureNeedsAccountCheckNotSignIn() {
        let state = CloudSyncOverviewReducer.reduce(
            CloudSyncOverviewInput(
                oauthStatus: .signedIn,
                remoteAccessStatus: .accountNeedsCheck,
                baselineStatus: .valid
            )
        )

        XCTAssertEqual(state.category, .accountNeedsCheck)
        XCTAssertEqual(state.primaryAction, .checkCloud)
    }

    func testPermissionMapsToCloudPermission() {
        let state = CloudSyncOverviewReducer.reduce(
            CloudSyncOverviewInput(
                oauthStatus: .signedIn,
                remoteAccessStatus: .cloudPermission,
                baselineStatus: .valid
            )
        )

        XCTAssertEqual(state.category, .cloudPermission)
        XCTAssertEqual(state.primaryAction, .checkCloud)
    }

    func testMissingBaselineOffersDownload() {
        let state = CloudSyncOverviewReducer.reduce(
            CloudSyncOverviewInput(
                oauthStatus: .signedIn,
                remoteAccessStatus: .available,
                baselineStatus: .absent
            )
        )

        XCTAssertEqual(state.category, .localNeedsDownload)
        XCTAssertEqual(state.primaryAction, .downloadDatabase)
        XCTAssertFalse(state.isBlocking)
    }

    func testReviewPrecedesBaseline() {
        let state = CloudSyncOverviewReducer.reduce(
            CloudSyncOverviewInput(
                oauthStatus: .signedIn,
                remoteAccessStatus: .available,
                baselineStatus: .absent,
                reviewItemCount: 1
            )
        )

        XCTAssertEqual(state.category, .needsReview)
        XCTAssertEqual(state.primaryAction, .reviewItems)
    }

    func testLocalPendingAfterValidBaseline() {
        let state = CloudSyncOverviewReducer.reduce(
            CloudSyncOverviewInput(
                oauthStatus: .signedIn,
                remoteAccessStatus: .available,
                baselineStatus: .valid,
                hasLocalPending: true
            )
        )

        XCTAssertEqual(state.category, .localPending)
        XCTAssertEqual(state.primaryAction, .sendChanges)
    }

    func testReadyWhenNoBlockingInputs() {
        let state = CloudSyncOverviewReducer.reduce(
            CloudSyncOverviewInput(
                oauthStatus: .signedIn,
                remoteAccessStatus: .available,
                baselineStatus: .valid
            )
        )

        XCTAssertEqual(state.category, .ready)
        XCTAssertEqual(state.primaryAction, .checkCloud)
    }
}
