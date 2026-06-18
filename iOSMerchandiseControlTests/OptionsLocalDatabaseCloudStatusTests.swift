import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class OptionsLocalDatabaseCloudStatusTests: XCTestCase {
    func testParityWithVerifiedBaselineIsUpToDate() {
        let input = makeInput(
            baselineStatus: .valid,
            hasAlignedCounts: true,
            needsRemoteCountVerification: false
        )

        XCTAssertEqual(LocalDatabaseCloudStatusResolver.resolve(input), .upToDate)
        XCTAssertFalse(LocalDatabaseCloudStatusResolver.shouldRequestAutomaticCloudCheck(input))
    }

    func testBaselineStaleOnlineSchedulesAutomaticReconcile() {
        let input = makeInput(baselineStatus: .stale)

        XCTAssertEqual(LocalDatabaseCloudStatusResolver.resolve(input), .reconciling)
        XCTAssertTrue(LocalDatabaseCloudStatusResolver.shouldRequestAutomaticCloudCheck(input))
    }

    func testBaselineStaleOfflineShowsOfflinePendingMessage() {
        let input = makeInput(
            baselineStatus: .stale,
            syncPhase: .blocked(.networkUnavailable),
            lastOutcome: .blocked(.networkUnavailable)
        )

        XCTAssertEqual(LocalDatabaseCloudStatusResolver.resolve(input), .offlineCloudCheckPending)
        XCTAssertFalse(LocalDatabaseCloudStatusResolver.shouldRequestAutomaticCloudCheck(input))
    }

    func testNoWorkWithVerifiedBaselineIsUpToDate() {
        let input = makeInput(
            baselineStatus: .valid,
            needsRemoteCountVerification: true,
            lastOutcome: .noWork
        )

        XCTAssertEqual(LocalDatabaseCloudStatusResolver.resolve(input), .upToDate)
        XCTAssertFalse(LocalDatabaseCloudStatusResolver.shouldRequestAutomaticCloudCheck(input))
    }

    func testNoWorkWithUnverifiedBaselineStartsCloudCheck() {
        let input = makeInput(
            baselineStatus: .absent,
            lastOutcome: .noWork
        )

        XCTAssertEqual(LocalDatabaseCloudStatusResolver.resolve(input), .checkingCloud)
        XCTAssertTrue(LocalDatabaseCloudStatusResolver.shouldRequestAutomaticCloudCheck(input))
    }

    func testSuccessfulRecoveryClearsCloudCheckState() {
        let input = makeInput(
            baselineStatus: .valid,
            hasAlignedCounts: true,
            needsRemoteCountVerification: false,
            lastOutcome: .succeeded
        )

        XCTAssertEqual(LocalDatabaseCloudStatusResolver.resolve(input), .upToDate)
        XCTAssertFalse(LocalDatabaseCloudStatusResolver.shouldRequestAutomaticCloudCheck(input))
    }

    func testCleanOnlineStateDoesNotUseNeedsCloudCheckCopy() {
        let status = LocalDatabaseCloudStatusResolver.resolve(makeInput(
            baselineStatus: .valid,
            hasAlignedCounts: true,
            needsRemoteCountVerification: false,
            lastOutcome: .noWork
        ))

        XCTAssertEqual(status.titleKey, "options.localDatabase.ready.title")
        XCTAssertNotEqual(status.titleKey, "options.localDatabase.needsCheck.title")
    }

    private func makeInput(
        isSignedIn: Bool = true,
        isAuthFailed: Bool = false,
        isLoading: Bool = false,
        localSummary: LocalDatabasePublicSummary = LocalDatabasePublicSummary(
            products: 1,
            suppliers: 1,
            categories: 1,
            productPrices: 1,
            historySessions: 0
        ),
        pendingCount: Int = 0,
        baselineStatus: SupabaseCatalogBaselineDebugStatus = .valid,
        hasAccountDecision: Bool = false,
        hasAlignedCounts: Bool = false,
        hasCountDrift: Bool = false,
        syncCountDriftCheckFailed: Bool = false,
        needsRemoteCountVerification: Bool = true,
        isCheckingRemoteCounts: Bool = false,
        syncPhase: SyncPhase = .idle,
        lastOutcome: SyncOutcome? = nil
    ) -> LocalDatabaseCloudStatusInput {
        LocalDatabaseCloudStatusInput(
            isSignedIn: isSignedIn,
            isAuthFailed: isAuthFailed,
            isLoading: isLoading,
            localSummary: localSummary,
            pendingCount: pendingCount,
            baselineStatus: baselineStatus,
            hasAccountDecision: hasAccountDecision,
            hasAlignedCounts: hasAlignedCounts,
            hasCountDrift: hasCountDrift,
            syncCountDriftCheckFailed: syncCountDriftCheckFailed,
            needsRemoteCountVerification: needsRemoteCountVerification,
            isCheckingRemoteCounts: isCheckingRemoteCounts,
            syncPhase: syncPhase,
            lastOutcome: lastOutcome
        )
    }
}
