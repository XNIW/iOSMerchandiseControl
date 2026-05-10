import XCTest
@testable import iOSMerchandiseControl

final class SupabaseSyncPlanContractTests: XCTestCase {
    func testTask099StatePrecedenceAuthThenPermissionThenStaleThenFailedThenReview() {
        let authPlan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(
                toApply: 3,
                reviewNeeded: 4,
                blocked: 2,
                stale: 1,
                failed: 1
            ),
            requestedSections: [.cloud, .device],
            blockingReasons: [.authRequired, .accessOrSync]
        )

        XCTAssertEqual(authPlan.state, .blocked)
        XCTAssertFalse(authPlan.canApply)
        XCTAssertEqual(authPlan.primaryAction, .signInAgain)
        XCTAssertEqual(authPlan.sections.first?.id, .attention)

        let permissionPlan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(
                toApply: 3,
                reviewNeeded: 4,
                blocked: 2,
                stale: 1,
                failed: 1
            ),
            requestedSections: [.cloud, .device],
            blockingReasons: [.cloudPermission, .accessOrSync]
        )

        XCTAssertEqual(permissionPlan.state, .blocked)
        XCTAssertFalse(permissionPlan.canApply)
        XCTAssertEqual(permissionPlan.primaryAction, .recheck)
        XCTAssertEqual(permissionPlan.sections.first?.id, .attention)

        let authAndPermissionPlan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(
                toApply: 3,
                reviewNeeded: 4,
                blocked: 2,
                stale: 1,
                failed: 1
            ),
            requestedSections: [.cloud, .device],
            blockingReasons: [.authRequired, .cloudPermission, .accessOrSync]
        )

        XCTAssertEqual(authAndPermissionPlan.state, .blocked)
        XCTAssertFalse(authAndPermissionPlan.canApply)
        XCTAssertEqual(authAndPermissionPlan.primaryAction, .signInAgain)
        XCTAssertEqual(authAndPermissionPlan.sections.first?.id, .attention)

        let plan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(
                toApply: 3,
                reviewNeeded: 4,
                blocked: 2,
                stale: 1,
                failed: 1
            ),
            requestedSections: [.cloud, .device]
        )

        XCTAssertEqual(plan.state, .stale)
        XCTAssertFalse(plan.canApply)
        XCTAssertEqual(plan.primaryAction, .recheck)
        XCTAssertEqual(plan.sections.first?.id, .attention)
    }

    func testStaleWinsOverPartialBlockedAndReview() {
        let plan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(
                reviewNeeded: 1,
                blocked: 1,
                stale: 1
            ),
            requestedSections: [.prices],
            explicitState: .partial
        )

        XCTAssertEqual(plan.state, .stale)
        XCTAssertFalse(plan.canApply)
        XCTAssertEqual(plan.primaryAction, .recheck)
    }

    func testReadyAllowsApplyAndDoesNotCountSkippedAsApplied() {
        let plan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(
                toApply: 2,
                applied: 0,
                skipped: 5
            ),
            requestedSections: [.cloud, .prices]
        )

        XCTAssertEqual(plan.state, .ready)
        XCTAssertTrue(plan.canApply)
        XCTAssertEqual(plan.primaryAction, .apply)
        XCTAssertEqual(plan.counters.applied, 0)
        XCTAssertEqual(plan.counters.skipped, 5)
        XCTAssertEqual(plan.sections.map(\.id), [.cloud, .prices])
    }

    func testReadyWithoutWorkHasNoPrimaryAction() {
        let plan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(skipped: 2),
            requestedSections: [.cloud]
        )

        XCTAssertEqual(plan.state, .ready)
        XCTAssertTrue(plan.canApply)
        XCTAssertEqual(plan.primaryAction, .none)
    }

    func testBlockedInvalidLocalDataUsesDatabaseAction() {
        let plan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(blocked: 1),
            requestedSections: [.device],
            blockingReasons: [.invalidLocalData]
        )

        XCTAssertEqual(plan.state, .blocked)
        XCTAssertFalse(plan.canApply)
        XCTAssertEqual(plan.primaryAction, .openDatabase)
        XCTAssertEqual(plan.blockingReasons, [.invalidLocalData])
        XCTAssertEqual(plan.sections.map(\.id), [.attention, .device])
    }

    func testTask099GenericAccessOrSyncFailureUsesRecheckNotSignIn() {
        let plan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(failed: 1),
            requestedSections: [.activity],
            blockingReasons: [.accessOrSync]
        )

        XCTAssertEqual(plan.state, .failed)
        XCTAssertEqual(plan.primaryAction, .recheck)
        XCTAssertFalse(plan.canApply)
    }

    func testTask099AuthRequiredUsesSignInAgainAction() {
        let plan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(failed: 1),
            requestedSections: [.activity],
            blockingReasons: [.authRequired]
        )

        XCTAssertEqual(plan.state, .blocked)
        XCTAssertEqual(plan.primaryAction, .signInAgain)
        XCTAssertFalse(plan.canApply)
    }
}
