import XCTest
import SwiftData
@testable import iOSMerchandiseControl

// MARK: - Test doubles

@MainActor
final class SupabaseManualSyncCoordinatingInvocationCounter: SupabaseManualSyncCoordinating {
    private let inner: SupabaseManualSyncCoordinator
    private(set) var runInvocationCount = 0

    init(inner: SupabaseManualSyncCoordinator) {
        self.inner = inner
    }

    func run(mode: SupabaseManualSyncRunMode, sessionID: UUID) async -> SupabaseManualSyncRunSummary {
        runInvocationCount += 1
        return await inner.run(mode: mode, sessionID: sessionID)
    }
}

@MainActor
final class ClosureSupabaseManualSyncCoordinatorFake: SupabaseManualSyncCoordinating {
    var handler: (@MainActor (_ mode: SupabaseManualSyncRunMode, _ sessionID: UUID) async -> SupabaseManualSyncRunSummary)?

    func run(mode: SupabaseManualSyncRunMode, sessionID: UUID) async -> SupabaseManualSyncRunSummary {
        guard let handler else {
            preconditionFailure("ClosureSupabaseManualSyncCoordinatorFake: handler not wired")
        }
        return await handler(mode, sessionID)
    }
}

@MainActor
private final class ManualSyncPreviewStagingFake: SupabaseManualSyncRemotePreviewStaging {
    var stagedPreviewForLocalApply: SyncPreview?
    private(set) var clearCount = 0

    func clearStagedPreviewForLocalApply() {
        clearCount += 1
        stagedPreviewForLocalApply = nil
    }
}

@MainActor
private final class ManualSyncCatalogPushProviderFake: SupabaseManualSyncCatalogPushProviding {
    var plans: [ManualPushPlan]
    var executeResult: SupabaseManualPushResult
    var makePlanError: Error?
    private(set) var makePlanCallCount = 0
    private(set) var executeCallCount = 0
    var executeDelayNanoseconds: UInt64 = 0
    var onMakePlan: ((Int) -> Void)?

    init(
        plans: [ManualPushPlan],
        executeResult: SupabaseManualPushResult = SupabaseManualPushResult(
            status: .completed,
            supplierCreates: 0,
            supplierUpdates: 0,
            supplierLinks: 0,
            categoryCreates: 0,
            categoryUpdates: 0,
            categoryLinks: 0,
            productCreates: 1,
            productUpdates: 0,
            productLinks: 0,
            baselineRunID: UUID(),
            message: nil
        )
    ) {
        self.plans = plans
        self.executeResult = executeResult
    }

    func makePushPlan(ownerUserID: UUID) async throws -> ManualPushPlan {
        makePlanCallCount += 1
        onMakePlan?(makePlanCallCount)
        if let makePlanError {
            throw makePlanError
        }
        if plans.count > 1 {
            return plans.removeFirst()
        }
        guard let plan = plans.first else {
            return ManualPushPlan(
                generatedAt: Date(timeIntervalSince1970: 1_778_500_000),
                ownerUserID: ownerUserID,
                candidates: [],
                blockedReasons: [],
                warnings: [],
                futureEventChangedCount: 0
            )
        }
        return plan
    }

    func execute(plan: ManualPushPlan, ownerUserID: UUID) async -> SupabaseManualPushResult {
        executeCallCount += 1
        if executeDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: executeDelayNanoseconds)
        }
        return executeResult
    }
}

@MainActor
private final class ManualSyncProductPriceProviderFake: SupabaseManualSyncProductPriceSyncProviding {
    var applyPlans: [ProductPriceApplyPlan]
    var pushPlans: [ProductPricePushDryRunPlan]
    var applyResult: ProductPriceApplyResult
    var pushResult: ProductPriceManualPushResult?
    var makeApplyPlanError: Error?
    var makePushPlanError: Error?
    var applyError: Error?
    var pushError: Error?
    private(set) var makeApplyPlanCallCount = 0
    private(set) var applyCallCount = 0
    private(set) var makePushPlanCallCount = 0
    private(set) var pushCallCount = 0

    init(
        applyPlans: [ProductPriceApplyPlan] = [],
        pushPlans: [ProductPricePushDryRunPlan] = [],
        applyResult: ProductPriceApplyResult = ProductPriceApplyResult(inserted: 0, skippedExisting: 0, totalConsidered: 0),
        pushResult: ProductPriceManualPushResult? = nil
    ) {
        self.applyPlans = applyPlans
        self.pushPlans = pushPlans
        self.applyResult = applyResult
        self.pushResult = pushResult
    }

    func makeApplyPlan(ownerUserID: UUID) async throws -> ProductPriceApplyPlan {
        makeApplyPlanCallCount += 1
        if let makeApplyPlanError {
            throw makeApplyPlanError
        }
        if applyPlans.count > 1 {
            return applyPlans.removeFirst()
        }
        return applyPlans.first ?? Self.emptyApplyPlan(ownerID: ownerUserID)
    }

    func apply(plan: ProductPriceApplyPlan, ownerUserID: UUID) async throws -> ProductPriceApplyResult {
        applyCallCount += 1
        if let applyError {
            throw applyError
        }
        return applyResult
    }

    func makePushPlan(ownerUserID: UUID) async throws -> ProductPricePushDryRunPlan {
        makePushPlanCallCount += 1
        if let makePushPlanError {
            throw makePushPlanError
        }
        if pushPlans.count > 1 {
            return pushPlans.removeFirst()
        }
        return pushPlans.first ?? Self.emptyPushPlan(ownerID: ownerUserID)
    }

    func push(plan: ProductPricePushDryRunPlan, ownerUserID: UUID) async throws -> ProductPriceManualPushResult {
        pushCallCount += 1
        if let pushError {
            throw pushError
        }
        if let pushResult {
            return pushResult
        }
        return ProductPriceManualPushResult(
            insertedCount: plan.summary.readyCandidates,
            verification: .exactMatch(verifiedCount: plan.summary.readyCandidates),
            fingerprint: "test-price-push"
        )
    }

    private static func emptyApplyPlan(ownerID: UUID) -> ProductPriceApplyPlan {
        ProductPriceApplyPlan(
            generatedAt: Date(timeIntervalSince1970: 1_778_500_000),
            sessionSnapshot: ProductPriceApplySessionSnapshot(userID: ownerID),
            sourceState: ProductPriceApplySourceState(),
            summary: ProductPriceApplySummary(
                remoteRead: 0,
                included: 0,
                skippedExisting: 0,
                unmapped: 0,
                invalid: 0,
                conflicts: 0,
                mappingConflicts: 0,
                partial: false,
                truncated: false,
                sourceError: nil
            ),
            blockReasons: [.noApplicableRows],
            linesToInsert: [],
            issues: [],
            remoteRows: []
        )
    }

    private static func emptyPushPlan(ownerID: UUID) -> ProductPricePushDryRunPlan {
        ProductPricePushDryRunPlan(
            generatedAt: Date(timeIntervalSince1970: 1_778_500_000),
            sessionSnapshot: ProductPricePushDryRunSessionSnapshot(userID: ownerID, lastLinkedUserID: ownerID),
            remoteDedupeStatus: .notNeeded,
            summary: ProductPricePushDryRunSummary(
                localPriceCount: 0,
                remoteRowsRead: 0,
                remotePagesRead: 0,
                readyCandidates: 0,
                alreadyPresentRemote: 0,
                conflictSameKeyDifferentPrice: 0,
                localDuplicateSameKey: 0,
                localConflictSameKeyDifferentPrice: 0,
                blockedNoRemoteID: 0,
                blockedNoAuth: 0,
                blockedAccountMismatch: 0,
                blockedBaselineMissing: 0,
                blockedBaselineStale: 0,
                blockedBaselinePartial: 0,
                excludedInvalidLocal: 0
            ),
            candidates: [],
            alreadyPresentRemote: [],
            conflictSameKeyDifferentPrice: [],
            localDuplicateSameKey: [],
            localConflictSameKeyDifferentPrice: [],
            blockedNoRemoteID: [],
            excludedInvalidLocal: []
        )
    }
}

@MainActor
final class SupabaseManualSyncViewModelTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    private func repoRootURL() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assertNoForbiddenUserFacingJargon(_ vm: SupabaseManualSyncViewModel, file: StaticString = #filePath, line: UInt = #line) {
        let state = vm.presentationState
        let actionValues = [state.primaryAction, state.secondaryAction]
            .compactMap { $0 }
            .flatMap { action -> [String] in
                var values = [action.title, action.accessibilityLabel]
                if let hint = action.accessibilityHint {
                    values.append(hint)
                }
                return values
            }
        let reviewValues = state.reviewSheet.map { sheet in
            [sheet.title, sheet.subtitle, sheet.footerMessage, sheet.primaryActionTitle, sheet.secondaryActionTitle, sheet.accessibilityLabel]
                + sheet.sections.flatMap { [$0.title, $0.message] }
        } ?? []
        let blob = (
            [vm.title, vm.subtitle, vm.primaryActionTitle, vm.lastUserMessage]
                + [
                    state.title,
                    state.subtitle,
                    state.userFacingSummary?.message,
                    state.statusBadgeText,
                    state.accessibilityLabel,
                    state.accessibilityHint,
                ]
                + actionValues
                + reviewValues
        )
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        let forbidden = [
            "dto",
            "syncpreview",
            "outbox",
            "drain",
            "sync_events",
            "rpc",
            "record_sync_event",
            "baseline",
            "payload",
            "owneruserid",
            "owner_user_id",
            "jwt",
            "rls",
            "retryable",
            "uuid",
            "barcode",
        ]
        for word in forbidden {
            XCTAssertFalse(blob.contains(word), "Unexpected jargon fragment \(word)", file: file, line: line)
        }
    }

    private func assertSinglePrimaryAction(_ state: SupabaseManualSyncPresentationState, file: StaticString = #filePath, line: UInt = #line) {
        if let primary = state.primaryAction {
            XCTAssertNotEqual(primary.id, state.secondaryAction?.id, "Primary and secondary actions must be distinct", file: file, line: line)
        }
    }

    private func actionIDs(_ state: SupabaseManualSyncPresentationState) -> [SupabaseManualSyncPresentationActionID] {
        [state.primaryAction, state.secondaryAction]
            .compactMap { $0?.id }
    }

    private func assertNoDuplicateSummaryCopy(_ state: SupabaseManualSyncPresentationState, file: StaticString = #filePath, line: UInt = #line) {
        guard let summary = state.userFacingSummary else { return }
        let normalizedSummary = normalizeCopy(summary.message)
        XCTAssertNotEqual(normalizedSummary, normalizeCopy(state.title), file: file, line: line)
        if let subtitle = state.subtitle {
            XCTAssertNotEqual(normalizedSummary, normalizeCopy(subtitle), file: file, line: line)
        }
    }

    private func normalizeCopy(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".…"))
            .lowercased()
    }

    private func cloudCheckSummary(
        finalState: SupabaseManualSyncFinalUserState,
        counts: SupabaseManualSyncPrivacyCounts = .init(),
        remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary? = nil
    ) -> SupabaseManualSyncRunSummary {
        SupabaseManualSyncRunSummary(
            finalState: finalState,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.cloudCheckNoAction,
            executedPhases: [.authCheck, .baselineCheck, .localPendingCheck, .remotePreview, .summary],
            skippedPhases: [.userConfirmation, .catalogPush, .productPricePush, .pendingEventsFlush, .finalRefresh],
            countsSnapshot: counts,
            suggestedNextStep: nil,
            detailMessage: nil,
            remotePreviewSummary: remotePreviewSummary
        )
    }

    private func remotePreviewSummary(
        hasRemoteSignals: Bool = false,
        isComplete: Bool = true,
        isPartial: Bool = false,
        wasCancelled: Bool = false,
        counts: SupabaseManualSyncRemotePreviewAggregateCounts = .init(),
        key: SupabaseManualSyncRemotePreviewMessageKey = .cloudCheckCompleteNoAction,
        failureCategory: SupabaseManualSyncRemotePreviewFailureCategory? = nil
    ) -> SupabaseManualSyncRemotePreviewSummary {
        SupabaseManualSyncRemotePreviewSummary(
            hasRemoteSignals: hasRemoteSignals,
            isComplete: isComplete,
            isPartial: isPartial,
            wasCancelled: wasCancelled,
            safeAggregateCounts: counts,
            recommendedUserMessageKey: key,
            failureCategory: failureCategory
        )
    }

    func testInitialStateIdleReadyPrivacySafeTitles() async {
        await Task.yield()
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(coordinator: fake)

        XCTAssertEqual(vm.presentationKind, .idleReady)
        XCTAssertFalse(vm.isRunning)
        XCTAssertTrue(vm.canStart)
        XCTAssertNil(vm.lastSummary)
        XCTAssertFalse(vm.pendingConfirmation)
        XCTAssertFalse(vm.shouldShowConfirmation)

        XCTAssertEqual(vm.primaryActionTitle, "Avvia sincronizzazione")
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testPresentationStateSignedOutUsesSignInAsOnlyPrimaryAction() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(
            coordinator: fake,
            initialAuthPresentationContext: SupabaseManualSyncAuthPresentationContext(
                isSignedIn: false,
                canSignIn: true,
                isTransitioning: false
            )
        )

        let state = vm.presentationState

        XCTAssertEqual(state.primaryAction?.id, .signIn)
        XCTAssertNil(state.secondaryAction)
        XCTAssertFalse(state.isRunning)
        assertSinglePrimaryAction(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testPresentationStateWithoutCapabilitiesDoesNotExposeCloudOrSyncActions() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        let state = vm.presentationState

        XCTAssertNil(state.primaryAction)
        XCTAssertNil(state.secondaryAction)
        XCTAssertFalse(actionIDs(state).contains(.checkCloud))
        XCTAssertFalse(actionIDs(state).contains(.syncNow))
        assertSinglePrimaryAction(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testReleaseCurrentCapabilitiesKeepCloudAndSyncActionsHidden() async {
        let capabilities = SupabaseManualSyncCapabilitySet.releaseCurrent
        XCTAssertFalse(capabilities.supportsRemoteCloudCheck)
        XCTAssertFalse(capabilities.supportsGuidedManualSync)

        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(coordinator: fake, capabilities: capabilities)
        let state = vm.presentationState

        XCTAssertNil(state.primaryAction)
        XCTAssertNil(state.secondaryAction)
        XCTAssertNil(vm.runMode(for: .checkCloud))
        XCTAssertNil(vm.runMode(for: .syncNow))
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask073ReleaseCapabilitiesExposeCloudCheckOnlyWhenPreviewProviderExists() async {
        let fakeProvider = SupabaseManualSyncCoordinatorDryRunFake()
        let withProvider = SupabaseManualSyncCapabilitySet.releaseCurrent(remotePreviewProvider: fakeProvider)
        let withoutProvider = SupabaseManualSyncCapabilitySet.releaseCurrent(remotePreviewProvider: nil)

        XCTAssertTrue(withProvider.supportsRemoteCloudCheck)
        XCTAssertFalse(withProvider.supportsGuidedManualSync)
        XCTAssertFalse(withoutProvider.supportsRemoteCloudCheck)
        XCTAssertFalse(withoutProvider.supportsGuidedManualSync)
    }

    func testPresentationStateRemoteCapabilityShowsCheckCloudWithoutSyncNow() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(
            coordinator: fake,
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false
            )
        )
        let state = vm.presentationState

        XCTAssertEqual(state.primaryAction?.id, .checkCloud)
        XCTAssertNil(state.secondaryAction)
        XCTAssertFalse(actionIDs(state).contains(.syncNow))
        XCTAssertEqual(vm.runMode(for: .checkCloud), .dryRun)
        assertSinglePrimaryAction(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testPresentationStateGuidedCapabilityShowsSyncNowAndOptionalCloudSecondary() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(
            coordinator: fake,
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: true
            )
        )
        let state = vm.presentationState

        XCTAssertEqual(state.primaryAction?.id, .syncNow)
        XCTAssertEqual(state.secondaryAction?.id, .checkCloud)
        XCTAssertEqual(vm.runMode(for: .syncNow), .guidedManual)
        XCTAssertEqual(vm.runMode(for: .checkCloud), .dryRun)
        assertSinglePrimaryAction(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testStartWhileRunningIgnoresDuplicateCoordinatorRuns() async throws {
        let dryFake = SupabaseManualSyncCoordinatorDryRunFake()
        dryFake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        dryFake.holdAtPreviewUntilSignaled = true

        let inner = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: dryFake,
                baselineGate: dryFake,
                pendingSnapshot: dryFake,
                phaseSimulation: dryFake
            )
        )

        let counter = SupabaseManualSyncCoordinatingInvocationCounter(inner: inner)
        let vm = SupabaseManualSyncViewModel(coordinator: counter)

        let finished = XCTestExpectation(description: "first-run")

        Task {
            await vm.startDryRunVerification()
            finished.fulfill()
        }

        try await dryFake.waitUntilPreviewHoldEngaged()

        XCTAssertFalse(vm.canStart)

        await vm.startDryRunVerification()

        XCTAssertEqual(counter.runInvocationCount, 1)

        dryFake.releasePreviewHold()

        await fulfillment(of: [finished], timeout: 15)

        XCTAssertEqual(counter.runInvocationCount, 1)
        XCTAssertEqual(vm.presentationKind, .partialSync)
        XCTAssertEqual(vm.title, "Ci sono modifiche da controllare")
        XCTAssertEqual(vm.subtitle, "Nessun invio automatico.")
        XCTAssertTrue(vm.canStart)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testRunningPresentationStateShowsCancelWithoutPrimaryAction() async throws {
        let dryFake = SupabaseManualSyncCoordinatorDryRunFake()
        dryFake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        dryFake.holdAtPreviewUntilSignaled = true

        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: dryFake,
                baselineGate: dryFake,
                pendingSnapshot: dryFake,
                phaseSimulation: dryFake
            )
        )

        let vm = SupabaseManualSyncViewModel(coordinator: coordinator)
        let finished = XCTestExpectation(description: "running-state")

        Task {
            await vm.startDryRunVerification()
            finished.fulfill()
        }

        try await dryFake.waitUntilPreviewHoldEngaged()

        let state = vm.presentationState
        XCTAssertTrue(state.isRunning)
        XCTAssertTrue(state.isLoading)
        XCTAssertNil(state.primaryAction)
        XCTAssertEqual(state.secondaryAction?.id, .cancel)
        assertSinglePrimaryAction(state)

        dryFake.releasePreviewHold()
        await fulfillment(of: [finished], timeout: 15)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testDryRunWithPendingShowsNeedsReviewInsteadOfAllUpToDate() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 2, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)

        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: fake,
                baselineGate: fake,
                pendingSnapshot: fake,
                phaseSimulation: fake
            )
        )

        let vm = SupabaseManualSyncViewModel(coordinator: coordinator)
        await vm.startDryRunVerification()

        XCTAssertEqual(vm.presentationKind, .partialSync)
        XCTAssertEqual(vm.title, "Ci sono modifiche da controllare")
        XCTAssertEqual(vm.subtitle, "Nessun invio automatico.")
        XCTAssertEqual(vm.lastSummary?.finalState, .completedSuccessfully)
        XCTAssertNotEqual(vm.title, SupabaseManualSyncUserFacingCopy.allUpToDate)
        XCTAssertFalse(vm.presentationKind == .cancelledRun)
        XCTAssertNil(vm.presentationState.primaryAction)
        XCTAssertNil(vm.presentationState.secondaryAction)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testPartialOutcomeDoesNotAppearAsSuccessPresentation() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .partialSync,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.partialSync,
                executedPhases: [],
                skippedPhases: [],
                countsSnapshot: .init(),
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.partialSuggestion,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .partialSync)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.partialSync)
        XCTAssertNotEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertEqual(vm.primaryActionTitle, "Riprova")
        XCTAssertEqual(vm.lastSummary?.finalState, .partialSync)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testAuthBlockedMessaging() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .blocked,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.signInAgain,
                executedPhases: [.authCheck],
                skippedPhases: [],
                countsSnapshot: .init(),
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.signInAgain,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .blockedNeedsSignIn)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.signInAgain)
        XCTAssertEqual(vm.subtitle, "Accedi di nuovo per continuare.")
        XCTAssertEqual(vm.primaryActionTitle, "Accedi")
        XCTAssertNotEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertEqual(vm.lastSummary?.finalState, .blocked)
        XCTAssertFalse(vm.lastUserMessage.contains("\(SupabaseManualSyncUserFacingCopy.signInAgain) \(SupabaseManualSyncUserFacingCopy.signInAgain)"))
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testBaselineBlockedMessaging() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .blocked,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.realignFromCloud,
                executedPhases: [.baselineCheck],
                skippedPhases: [],
                countsSnapshot: .init(),
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.realignFromCloud,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .blockedNeedsCloudRealignment)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.realignFromCloud)
        XCTAssertEqual(vm.subtitle, "Prima aggiorna i dati dal cloud, poi riprova.")
        XCTAssertEqual(vm.primaryActionTitle, "Riallinea dati")
        XCTAssertNotEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertFalse(vm.lastUserMessage.contains("\(SupabaseManualSyncUserFacingCopy.realignFromCloud) \(SupabaseManualSyncUserFacingCopy.realignFromCloud)"))
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testCoordinatorBusyStateAllowsRetryAndAvoidsDuplicateCopy() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .concurrentRunNotAllowed,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.alreadyRunning,
                executedPhases: [],
                skippedPhases: SupabaseManualSyncPhase.allCases,
                countsSnapshot: .init(),
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.alreadyRunning,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .auxiliaryBusyConcurrent)
        XCTAssertTrue(vm.cannotStartConcurrently)
        XCTAssertFalse(vm.isRunning)
        XCTAssertTrue(vm.canStart)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.alreadyRunning)
        XCTAssertEqual(vm.subtitle, "Attendi che termini prima di riprovare.")
        XCTAssertEqual(vm.primaryActionTitle, "Riprova")
        XCTAssertFalse(vm.lastUserMessage.contains("\(SupabaseManualSyncUserFacingCopy.alreadyRunning) \(SupabaseManualSyncUserFacingCopy.alreadyRunning)"))
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testConnectivityMessaging() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .connectivityIssue,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.connectivityRetry,
                executedPhases: [],
                skippedPhases: [],
                countsSnapshot: .init(),
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.retryConnectivitySuggestion,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .connectivityIssue)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.connectivityRetry)
        XCTAssertNotEqual(vm.presentationKind, .partialSync)
        XCTAssertFalse(vm.presentationKind == .successFullyUpToDate)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testCancellationMessagingNeverSuccessPresentation() async throws {
        let coordinatorFake = SupabaseManualSyncCoordinatorDryRunFake()
        coordinatorFake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        coordinatorFake.delayPreviewNanoseconds = 200_000_000

        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: coordinatorFake,
                baselineGate: coordinatorFake,
                pendingSnapshot: coordinatorFake,
                phaseSimulation: coordinatorFake
            )
        )

        let vm = SupabaseManualSyncViewModel(coordinator: coordinator)

        let run = Task { await vm.startDryRunVerification() }
        try await Task.sleep(for: .milliseconds(25))
        run.cancel()

        await run.value

        XCTAssertEqual(vm.presentationKind, .cancelledRun)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.cancelled)
        XCTAssertFalse(vm.presentationKind == .successFullyUpToDate)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTechnicalReviewSoftCopyOverridesUnexpectedCoordinatorHeadline() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .technicalReviewNeeded,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.unexpected,
                executedPhases: [],
                skippedPhases: [],
                countsSnapshot: .init(),
                suggestedNextStep: nil,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .technicalFollowUpNeeded)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.technicalFollowUp)
        XCTAssertNotEqual(vm.title, SupabaseManualSyncUserFacingCopy.unexpected)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testCompletedRemotePreviewSignalsUseReviewStateWithoutTechnicalFailureCopy() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .technicalReviewNeeded,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.technicalFollowUp,
                executedPhases: [.authCheck, .baselineCheck, .localPendingCheck, .remotePreview, .summary],
                skippedPhases: [.userConfirmation, .catalogPush, .productPricePush, .pendingEventsFlush, .finalRefresh],
                countsSnapshot: .init(),
                suggestedNextStep: nil,
                detailMessage: nil,
                remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary(
                    hasRemoteSignals: true,
                    isComplete: true,
                    isPartial: false,
                    wasCancelled: false,
                    safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(newProductCount: 1),
                    recommendedUserMessageKey: .cloudDataNeedsReview,
                    failureCategory: nil
                )
            )
        }

        let vm = SupabaseManualSyncViewModel(
            coordinator: fake,
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false
            )
        )
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .partialSync)
        XCTAssertEqual(vm.title, "Ci sono modifiche da controllare")
        XCTAssertEqual(vm.subtitle, "Nessun invio automatico.")
        XCTAssertEqual(vm.presentationState.primaryAction?.id, .reviewChanges)
        XCTAssertNil(vm.runMode(for: .reviewChanges))
        XCTAssertNotNil(vm.presentationState.reviewSheet)
        XCTAssertFalse(actionIDs(vm.presentationState).contains(.syncNow))
        XCTAssertEqual(vm.lastSummary?.remotePreviewSummary?.safeAggregateCounts.newProductCount, 1)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testCloudCheckNoActionAddsCompactUserFacingSummary() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(
            coordinator: fake,
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false
            )
        )

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            remotePreviewSummary: remotePreviewSummary()
        ))

        let state = vm.presentationState
        XCTAssertEqual(state.userFacingSummary?.kind, .cloudCheckCompletedNoAction)
        XCTAssertEqual(state.primaryAction?.id, .reviewChanges)
        XCTAssertNotNil(state.reviewSheet)
        XCTAssertFalse(state.userFacingSummary?.message.localizedCaseInsensitiveContains("sincronizzato") ?? false)
        XCTAssertFalse(state.userFacingSummary?.message.localizedCaseInsensitiveContains("fully synced") ?? false)
        XCTAssertTrue(state.accessibilityLabel.contains(state.userFacingSummary?.message ?? ""))
        assertNoDuplicateSummaryCopy(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask077ReviewSheetIsPreparedForCompletedPreviewWithoutMutativeAction() async throws {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(
            coordinator: fake,
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false
            )
        )

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            counts: SupabaseManualSyncPrivacyCounts(
                pendingCatalogChangeCount: 1,
                pendingPriceChangeCount: 1,
                pendingQueuedCloudOperationCount: 1
            ),
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(
                    remoteProductPriceCount: 2,
                    newProductCount: 1,
                    conflictCount: 1,
                    priceHistorySignalCount: 1
                ),
                key: .cloudDataNeedsReview
            )
        ))

        let state = vm.presentationState
        let review = try XCTUnwrap(state.reviewSheet)

        XCTAssertEqual(state.primaryAction?.id, .reviewChanges)
        XCTAssertNil(vm.runMode(for: .reviewChanges))
        XCTAssertFalse(review.primaryActionIsEnabled)
        XCTAssertFalse(review.primaryActionIsLoading)
        XCTAssertEqual(review.primaryActionTitle, "Aggiorna questo dispositivo")
        XCTAssertEqual(review.footerMessage, "Riesegui Controlla cloud prima di aggiornare questo dispositivo.")
        XCTAssertEqual(review.secondaryActionTitle, "Annulla")
        XCTAssertEqual(review.sections.map(\.id), [.cloudToDevice, .deviceToCloud, .prices, .attention])
        XCTAssertFalse(actionIDs(state).contains(.syncNow))
        XCTAssertFalse(actionIDs(state).contains(.checkCloud))
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testRemoteSignalsSummaryAvoidsIdentifiersAndCounts() async throws {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(
            coordinator: fake,
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false
            )
        )
        let privateID = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(
                    remoteProductCount: 42,
                    newProductCount: 7,
                    conflictCount: 3
                ),
                key: .cloudDataNeedsReview
            )
        ))

        let state = vm.presentationState
        let summaryMessage = try XCTUnwrap(state.userFacingSummary?.message)
        let review = try XCTUnwrap(state.reviewSheet)
        let reviewCopy = ([review.title, review.subtitle, review.footerMessage] + review.sections.flatMap { [$0.title, $0.message] })
            .joined(separator: " ")
        XCTAssertEqual(state.userFacingSummary?.kind, .remoteReviewNeeded)
        XCTAssertFalse(summaryMessage.contains("42"))
        XCTAssertFalse(summaryMessage.contains("7"))
        XCTAssertFalse(summaryMessage.contains("3"))
        XCTAssertFalse(summaryMessage.localizedCaseInsensitiveContains(privateID.uuidString))
        XCTAssertFalse(summaryMessage.localizedCaseInsensitiveContains("987654321"))
        XCTAssertFalse(reviewCopy.contains("42"))
        XCTAssertFalse(reviewCopy.contains("7"))
        XCTAssertFalse(reviewCopy.contains("3"))
        XCTAssertFalse(reviewCopy.localizedCaseInsensitiveContains(privateID.uuidString))
        assertNoDuplicateSummaryCopy(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testNoLocalPendingSummaryDoesNotClaimCloudIsSynced() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(coordinator: fake)

        vm.apply(summary: cloudCheckSummary(finalState: .allUpToDate))

        let state = vm.presentationState
        XCTAssertEqual(state.userFacingSummary?.kind, .noLocalChangesToSend)
        XCTAssertFalse(state.userFacingSummary?.message.localizedCaseInsensitiveContains("tutto sincronizzato") ?? false)
        XCTAssertFalse(state.userFacingSummary?.message.localizedCaseInsensitiveContains("fully synced") ?? false)
        assertNoDuplicateSummaryCopy(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testRemotePartialSummaryWinsOverCompletedState() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(coordinator: fake)

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            remotePreviewSummary: remotePreviewSummary(
                isComplete: false,
                isPartial: true,
                key: .cloudCheckIncomplete
            )
        ))

        let state = vm.presentationState
        XCTAssertEqual(vm.presentationKind, .technicalFollowUpNeeded)
        XCTAssertNotEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertEqual(state.userFacingSummary?.kind, .cloudCheckIncomplete)
        assertNoDuplicateSummaryCopy(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testRemoteFailureSummariesUseUserFacingCategories() async {
        let cases: [(SupabaseManualSyncRemotePreviewFailureCategory, SupabaseManualSyncUserFacingSummaryKind)] = [
            (.network, .networkIssue),
            (.permission, .cloudAccessIssue),
            (.schemaOrDecode, .genericIssue),
            (.localSnapshot, .genericIssue),
            (.unknown, .genericIssue),
        ]

        for (failureCategory, expectedKind) in cases {
            let fake = ClosureSupabaseManualSyncCoordinatorFake()
            let vm = SupabaseManualSyncViewModel(coordinator: fake)

            vm.apply(summary: cloudCheckSummary(
                finalState: failureCategory == .network ? .connectivityIssue : .technicalReviewNeeded,
                remotePreviewSummary: remotePreviewSummary(
                    isComplete: false,
                    key: failureCategory == .network ? .cloudCheckFailedRetry : .cloudCheckFailedTechnical,
                    failureCategory: failureCategory
                )
            ))

            let state = vm.presentationState
            XCTAssertEqual(state.userFacingSummary?.kind, expectedKind)
            assertNoDuplicateSummaryCopy(state)
            assertNoForbiddenUserFacingJargon(vm)
        }
    }

    func testCancelledCloudCheckShowsNeutralSummary() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(coordinator: fake)

        vm.apply(summary: cloudCheckSummary(
            finalState: .cancelled,
            remotePreviewSummary: remotePreviewSummary(
                isComplete: false,
                wasCancelled: true,
                key: .cloudCheckCancelled
            )
        ))

        let state = vm.presentationState
        XCTAssertEqual(state.userFacingSummary?.kind, .cancelled)
        XCTAssertNotEqual(vm.presentationKind, .successFullyUpToDate)
        assertNoDuplicateSummaryCopy(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testRunningAuthAndBaselineStatesHidePreviousSummary() async throws {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            try? await Task.sleep(for: .milliseconds(200))
            return self.cloudCheckSummary(
                finalState: .completedSuccessfully,
                remotePreviewSummary: self.remotePreviewSummary()
            )
        }
        let vm = SupabaseManualSyncViewModel(
            coordinator: fake,
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false
            )
        )
        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            remotePreviewSummary: remotePreviewSummary()
        ))
        XCTAssertNotNil(vm.presentationState.userFacingSummary)

        let run = Task { await vm.start(with: .dryRun) }
        try await Task.sleep(for: .milliseconds(25))
        XCTAssertTrue(vm.presentationState.isRunning)
        XCTAssertNil(vm.presentationState.userFacingSummary)
        run.cancel()
        await run.value

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            remotePreviewSummary: remotePreviewSummary()
        ))
        vm.applyAuthPresentationContext(SupabaseManualSyncAuthPresentationContext(
            isSignedIn: false,
            canSignIn: true,
            isTransitioning: false
        ))
        XCTAssertNil(vm.presentationState.userFacingSummary)

        vm.applyAuthPresentationContext(.signedInReady)
        vm.apply(summary: SupabaseManualSyncRunSummary(
            finalState: .blocked,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.realignFromCloud,
            executedPhases: [.baselineCheck],
            skippedPhases: [],
            countsSnapshot: .init(),
            suggestedNextStep: SupabaseManualSyncUserFacingCopy.realignFromCloud,
            detailMessage: nil
        ))
        XCTAssertEqual(vm.presentationKind, .blockedNeedsCloudRealignment)
        XCTAssertNil(vm.presentationState.userFacingSummary)
    }

    func testZeroPendingDryRunLeavesAllUpToDateHeadlineWithoutPartialMasking() async {
        let dryFake = SupabaseManualSyncCoordinatorDryRunFake()
        dryFake.snapshot = SupabaseManualSyncPrivacyCounts()

        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: dryFake,
                baselineGate: dryFake,
                pendingSnapshot: dryFake,
                phaseSimulation: dryFake
            )
        )

        let vm = SupabaseManualSyncViewModel(coordinator: coordinator)
        await vm.startDryRunVerification()

        XCTAssertEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.allUpToDate)
        XCTAssertFalse(vm.presentationKind == .partialSync)
        XCTAssertEqual(vm.lastSummary?.finalState, .allUpToDate)
        XCTAssertNil(vm.presentationState.primaryAction)
        XCTAssertNil(vm.presentationState.secondaryAction)
        XCTAssertFalse(vm.presentationState.title.localizedCaseInsensitiveContains("aggiornato"))
        XCTAssertFalse(vm.presentationState.accessibilityLabel.localizedCaseInsensitiveContains("cloud aggiornato"))
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testPrivacySafeAggregateSnapshotCopiedFromSummary() async {
        let counts = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 2, pendingPriceChangeCount: 1, pendingQueuedCloudOperationCount: 4)

        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .connectivityIssue,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.connectivityRetry,
                executedPhases: [.authCheck],
                skippedPhases: [],
                countsSnapshot: counts,
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.retryConnectivitySuggestion,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.privacySafeAggregatesSnapshot, counts)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask075SmallDatasetNoPendingCompletesReadOnlyCloudCheck() async throws {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts()
        fake.remotePreviewSummary = remotePreviewSummary(
            counts: SupabaseManualSyncRemotePreviewAggregateCounts(
                remoteProductCount: 2,
                remoteSupplierCount: 1,
                remoteCategoryCount: 1,
                remoteProductPriceCount: 2
            )
        )
        fake.delayPreviewNanoseconds = 50_000_000
        let coordinator = makeTask075SmallDatasetCoordinator(fake: fake)
        let vm = makeTask075SmallDatasetViewModel(coordinator: coordinator)

        let idle = vm.presentationState
        XCTAssertEqual(idle.primaryAction?.id, .checkCloud)
        XCTAssertNil(idle.secondaryAction)
        XCTAssertFalse(actionIDs(idle).contains(.syncNow))

        let run = Task { await vm.start(with: .dryRun) }
        try await Task.sleep(for: .milliseconds(10))

        let running = vm.presentationState
        XCTAssertTrue(running.isRunning)
        XCTAssertTrue(running.isLoading)
        XCTAssertNil(running.primaryAction)
        XCTAssertEqual(running.secondaryAction?.id, .cancel)
        XCTAssertNil(running.userFacingSummary)

        await run.value

        let completed = vm.presentationState
        XCTAssertEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertEqual(completed.userFacingSummary?.kind, .cloudCheckCompletedNoAction)
        XCTAssertEqual(completed.primaryAction?.id, .reviewChanges)
        XCTAssertNotNil(completed.reviewSheet)
        XCTAssertNil(completed.secondaryAction)
        XCTAssertFalse(fake.calls.contains(.catalogPush))
        XCTAssertFalse(fake.calls.contains(.productPricePush))
        XCTAssertFalse(fake.calls.contains(.queuedCloudOperationsFlush))
        assertNoDuplicateSummaryCopy(completed)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask075SmallDatasetPendingLocalWorkRemainsReadOnlyAndRetryable() async throws {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(
            pendingCatalogChangeCount: 2,
            pendingPriceChangeCount: 0,
            pendingQueuedCloudOperationCount: 1
        )
        fake.remotePreviewSummary = remotePreviewSummary(
            counts: SupabaseManualSyncRemotePreviewAggregateCounts(
                remoteProductCount: 3,
                remoteSupplierCount: 1,
                remoteCategoryCount: 1,
                remoteProductPriceCount: 0
            )
        )
        let coordinator = makeTask075SmallDatasetCoordinator(fake: fake)
        let vm = makeTask075SmallDatasetViewModel(coordinator: coordinator)

        await vm.start(with: .dryRun)

        let state = vm.presentationState
        XCTAssertEqual(vm.presentationKind, .partialSync)
        XCTAssertEqual(state.userFacingSummary?.kind, .cloudCheckCompleted)
        XCTAssertEqual(state.primaryAction?.id, .reviewChanges)
        XCTAssertNotNil(state.reviewSheet)
        XCTAssertNil(state.secondaryAction)
        XCTAssertFalse(actionIDs(state).contains(.syncNow))
        XCTAssertEqual(vm.privacySafeAggregatesSnapshot?.pendingCatalogChangeCount, 2)
        XCTAssertEqual(vm.privacySafeAggregatesSnapshot?.pendingQueuedCloudOperationCount, 1)
        XCTAssertFalse(fake.calls.contains(.catalogPush))
        XCTAssertFalse(fake.calls.contains(.productPricePush))
        XCTAssertFalse(fake.calls.contains(.queuedCloudOperationsFlush))
        assertNoDuplicateSummaryCopy(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask075SmallDatasetPartialAndErrorStatesStayRecoverable() async throws {
        let partialFake = SupabaseManualSyncCoordinatorDryRunFake()
        partialFake.snapshot = SupabaseManualSyncPrivacyCounts()
        partialFake.remotePreviewSummary = remotePreviewSummary(
            isComplete: false,
            isPartial: true,
            counts: SupabaseManualSyncRemotePreviewAggregateCounts(sourceErrorCount: 1),
            key: .cloudCheckIncomplete
        )
        let partialVM = makeTask075SmallDatasetViewModel(
            coordinator: makeTask075SmallDatasetCoordinator(fake: partialFake)
        )

        await partialVM.start(with: .dryRun)

        let partialState = partialVM.presentationState
        XCTAssertEqual(partialVM.presentationKind, .technicalFollowUpNeeded)
        XCTAssertEqual(partialState.userFacingSummary?.kind, .cloudCheckIncomplete)
        XCTAssertEqual(partialState.primaryAction?.id, .retry)
        XCTAssertNil(partialState.secondaryAction)
        assertNoDuplicateSummaryCopy(partialState)
        assertNoForbiddenUserFacingJargon(partialVM)

        let errorFake = SupabaseManualSyncCoordinatorDryRunFake()
        errorFake.snapshot = SupabaseManualSyncPrivacyCounts()
        errorFake.remotePreviewSummary = remotePreviewSummary(
            isComplete: false,
            key: .cloudCheckFailedRetry,
            failureCategory: .network
        )
        let errorVM = makeTask075SmallDatasetViewModel(
            coordinator: makeTask075SmallDatasetCoordinator(fake: errorFake)
        )

        await errorVM.start(with: .dryRun)

        let errorState = errorVM.presentationState
        XCTAssertEqual(errorVM.presentationKind, .connectivityIssue)
        XCTAssertEqual(errorState.userFacingSummary?.kind, .networkIssue)
        XCTAssertEqual(errorState.primaryAction?.id, .retry)
        XCTAssertNil(errorState.secondaryAction)
        assertNoDuplicateSummaryCopy(errorState)
        assertNoForbiddenUserFacingJargon(errorVM)
    }

    func testTask075SmallDatasetCancelShowsRetryAndVolatileSummary() async throws {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts()
        fake.delayPreviewNanoseconds = 500_000_000
        let coordinator = makeTask075SmallDatasetCoordinator(fake: fake)
        let vm = makeTask075SmallDatasetViewModel(coordinator: coordinator)

        let run = Task { await vm.start(with: .dryRun) }
        try await Task.sleep(for: .milliseconds(25))
        XCTAssertTrue(vm.presentationState.isRunning)

        run.cancel()
        await run.value

        let state = vm.presentationState
        XCTAssertEqual(vm.presentationKind, .cancelledRun)
        XCTAssertEqual(state.userFacingSummary?.kind, .cancelled)
        XCTAssertEqual(state.primaryAction?.id, .retry)
        XCTAssertNil(state.secondaryAction)
        assertNoDuplicateSummaryCopy(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask075SmallDatasetDoubleTapDoesNotStartConcurrentRun() async throws {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts()
        fake.holdAtPreviewUntilSignaled = true
        let coordinator = SupabaseManualSyncCoordinatingInvocationCounter(
            inner: makeTask075SmallDatasetCoordinator(fake: fake)
        )
        let vm = makeTask075SmallDatasetViewModel(coordinator: coordinator)

        let firstRun = Task { await vm.start(with: .dryRun) }
        try await fake.waitUntilPreviewHoldEngaged()
        XCTAssertTrue(vm.presentationState.isRunning)

        await vm.start(with: .dryRun)

        XCTAssertEqual(coordinator.runInvocationCount, 1)
        XCTAssertTrue(vm.presentationState.isRunning)

        fake.releasePreviewHold()
        await firstRun.value

        XCTAssertEqual(coordinator.runInvocationCount, 1)
        XCTAssertFalse(vm.presentationState.isRunning)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask078FullApplicablePreviewEnablesUpdateDeviceAndAppliesLocally() async throws {
        let context = try makeContext()
        let staging = ManualSyncPreviewStagingFake()
        staging.stagedPreviewForLocalApply = makeApplicablePreview(
            newProducts: [
                makeApplicableProductSummary(
                    barcode: "100",
                    productName: "Remote item",
                    supplierName: "Cloud supplier",
                    categoryName: "Cloud category"
                )
            ]
        )
        let vm = makeApplyReadyViewModel(context: context, staging: staging)

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(newProductCount: 1),
                key: .cloudDataNeedsReview
            )
        ))

        let review = try XCTUnwrap(vm.presentationState.reviewSheet)
        XCTAssertTrue(vm.canApplyLocalChanges)
        XCTAssertNil(vm.applyBlockedReason)
        XCTAssertTrue(review.primaryActionIsEnabled)
        XCTAssertFalse(review.primaryActionIsLoading)
        XCTAssertEqual(review.primaryActionTitle, "Aggiorna questo dispositivo")
        XCTAssertEqual(review.footerMessage, "Aggiornerò solo questo dispositivo. I dati nel cloud non verranno modificati.")

        await vm.applyStagedLocalChanges()

        XCTAssertEqual(vm.presentationKind, .localApplyCompleted)
        XCTAssertEqual(vm.lastLocalApplySummary, SupabaseManualSyncLocalApplySummary(
            productsAdded: 1,
            productsUpdated: 0,
            suppliersCreated: 1,
            categoriesCreated: 1
        ))
        XCTAssertFalse(vm.canApplyLocalChanges)
        XCTAssertNil(staging.stagedPreviewForLocalApply)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 0)
        let appliedProduct = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first)
        XCTAssertNotEqual(appliedProduct.stockQuantity ?? -1, 99, "Stock remoto non deve essere copiato quando applyStockQuantity resta false")
        XCTAssertTrue(vm.presentationState.userFacingSummary?.message.contains("prodotti aggiunti: 1") ?? false)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask078PartialPreviewBlocksLocalApplyWithNaturalCopy() async throws {
        let context = try makeContext()
        let staging = ManualSyncPreviewStagingFake()
        let vm = makeApplyReadyViewModel(context: context, staging: staging)

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                isComplete: false,
                isPartial: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(sourceErrorCount: 1),
                key: .cloudCheckIncomplete
            )
        ))

        XCTAssertFalse(vm.canApplyLocalChanges)
        XCTAssertEqual(vm.applyBlockedReason, "Il controllo cloud non è completo. Riesegui Controlla cloud.")
        XCTAssertNil(staging.stagedPreviewForLocalApply)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask078ConflictsBlockLocalApplyAndDoNotExposeIdentifiers() async throws {
        let context = try makeContext()
        let staging = ManualSyncPreviewStagingFake()
        let privateID = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!
        staging.stagedPreviewForLocalApply = makeApplicablePreview(
            newProducts: [makeApplicableProductSummary(barcode: "PRIVATE-123", productName: "Secret product")],
            conflicts: [
                SyncPreviewConflict(
                    kind: .remoteIDConflict,
                    barcodeOrKey: "PRIVATE-123",
                    detail: privateID.uuidString,
                    relatedRemoteIDs: [privateID]
                )
            ]
        )
        let vm = makeApplyReadyViewModel(context: context, staging: staging)

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(newProductCount: 1, conflictCount: 1),
                key: .cloudDataNeedsReview
            )
        ))

        let review = try XCTUnwrap(vm.presentationState.reviewSheet)
        XCTAssertFalse(vm.canApplyLocalChanges)
        XCTAssertFalse(review.primaryActionIsEnabled)
        XCTAssertEqual(review.footerMessage, "Alcuni elementi richiedono attenzione. Riesegui Controlla cloud dopo averli controllati.")
        XCTAssertFalse(review.footerMessage.contains("PRIVATE-123"))
        XCTAssertFalse(review.footerMessage.localizedCaseInsensitiveContains("secret product"))
        XCTAssertFalse(review.footerMessage.localizedCaseInsensitiveContains(privateID.uuidString))
        XCTAssertNil(staging.stagedPreviewForLocalApply)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask078WarningsDoNotBlockApplicablePreview() async throws {
        let context = try makeContext()
        let staging = ManualSyncPreviewStagingFake()
        staging.stagedPreviewForLocalApply = makeApplicablePreview(
            newProducts: [makeApplicableProductSummary()],
            warnings: [
                SyncPreviewWarning(code: .remoteDuplicateName, detail: "supplier", relatedKey: "supplier")
            ]
        )
        let vm = makeApplyReadyViewModel(context: context, staging: staging)

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(newProductCount: 1, warningCount: 1),
                key: .cloudDataNeedsReview
            )
        ))

        let review = try XCTUnwrap(vm.presentationState.reviewSheet)
        XCTAssertTrue(vm.canApplyLocalChanges)
        XCTAssertTrue(review.primaryActionIsEnabled)
        XCTAssertEqual(review.sections.map(\.id), [.cloudToDevice, .deviceToCloud, .prices, .attention])
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask078StaleLocalDataInvalidatesStagingBeforeApply() async throws {
        let context = try makeContext()
        let staging = ManualSyncPreviewStagingFake()
        staging.stagedPreviewForLocalApply = makeApplicablePreview(
            newProducts: [makeApplicableProductSummary(barcode: "100")]
        )
        let vm = makeApplyReadyViewModel(context: context, staging: staging)

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(newProductCount: 1),
                key: .cloudDataNeedsReview
            )
        ))
        XCTAssertTrue(vm.canApplyLocalChanges)

        context.insert(Product(barcode: "100", productName: "Local edit"))
        try context.save()

        await vm.applyStagedLocalChanges()

        XCTAssertEqual(vm.presentationKind, .localApplyFailed)
        XCTAssertFalse(vm.canApplyLocalChanges)
        XCTAssertEqual(vm.applyBlockedReason, "I dati locali sono cambiati. Riesegui Controlla cloud.")
        XCTAssertNil(staging.stagedPreviewForLocalApply)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).count, 1)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask078CancelAndRelaunchLoseStaging() async throws {
        let context = try makeContext()
        let staging = ManualSyncPreviewStagingFake()
        staging.stagedPreviewForLocalApply = makeApplicablePreview(
            newProducts: [makeApplicableProductSummary()]
        )
        let vm = makeApplyReadyViewModel(context: context, staging: staging)

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(newProductCount: 1),
                key: .cloudDataNeedsReview
            )
        ))
        XCTAssertTrue(vm.canApplyLocalChanges)

        vm.cancelLocalApplyReview()

        XCTAssertFalse(vm.canApplyLocalChanges)
        XCTAssertEqual(vm.applyBlockedReason, "Riesegui Controlla cloud prima di aggiornare questo dispositivo.")
        XCTAssertNil(staging.stagedPreviewForLocalApply)

        let relaunchedVM = makeApplyReadyViewModel(context: context, staging: ManualSyncPreviewStagingFake())
        relaunchedVM.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(newProductCount: 1),
                key: .cloudDataNeedsReview
            )
        ))

        XCTAssertFalse(relaunchedVM.canApplyLocalChanges)
        XCTAssertEqual(relaunchedVM.applyBlockedReason, "Riesegui Controlla cloud prima di aggiornare questo dispositivo.")
        assertNoForbiddenUserFacingJargon(relaunchedVM)
    }

    func testTask078DoubleApplyTapOnlyWritesOnce() async throws {
        let context = try makeContext()
        let staging = ManualSyncPreviewStagingFake()
        staging.stagedPreviewForLocalApply = makeApplicablePreview(
            newProducts: [makeApplicableProductSummary(barcode: "100")]
        )
        let vm = makeApplyReadyViewModel(context: context, staging: staging)

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(newProductCount: 1),
                key: .cloudDataNeedsReview
            )
        ))

        await vm.applyStagedLocalChanges()
        await vm.applyStagedLocalChanges()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).count, 1)
        XCTAssertEqual(vm.lastLocalApplySummary?.productsAdded, 1)
        XCTAssertNil(staging.stagedPreviewForLocalApply)
    }

    func testTask079PreflightZeroChangeShowsNoMutativeCTAAndDoesNotExecute() async throws {
        let ownerID = UUID()
        let provider = ManualSyncCatalogPushProviderFake(plans: [
            makeCatalogPushPlan(ownerID: ownerID)
        ])
        let vm = makePushReadyViewModel(provider: provider, ownerID: ownerID)

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            remotePreviewSummary: remotePreviewSummary()
        ))
        await vm.prepareCatalogPushPlanForReview()

        let state = vm.presentationState
        XCTAssertEqual(state.title, "Nessuna modifica locale da inviare")
        XCTAssertEqual(state.userFacingSummary?.kind, .catalogPushNoChanges)
        XCTAssertNotEqual(state.primaryAction?.id, .sendCloudChanges)
        XCTAssertNil(state.reviewSheet)
        XCTAssertEqual(provider.makePlanCallCount, 1)
        XCTAssertEqual(provider.executeCallCount, 0)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask079PreflightValidCandidatesCreatesVolatileReviewPlan() async throws {
        let ownerID = UUID()
        let plan = makeCatalogPushPlan(
            ownerID: ownerID,
            candidates: [
                PushCandidate(entityKind: .product, localID: "100", action: .dryRunCreateCandidate)
            ]
        )
        let provider = ManualSyncCatalogPushProviderFake(plans: [plan])
        let vm = makePushReadyViewModel(provider: provider, ownerID: ownerID)

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            counts: SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1),
            remotePreviewSummary: remotePreviewSummary()
        ))
        await vm.prepareCatalogPushPlanForReview()

        let state = vm.presentationState
        let review = try XCTUnwrap(state.reviewSheet)
        XCTAssertEqual(state.primaryAction?.id, .reviewChanges)
        XCTAssertEqual(review.primaryActionID, .sendCloudChanges)
        XCTAssertTrue(review.primaryActionIsEnabled)
        XCTAssertEqual(review.primaryActionTitle, "Invia modifiche al cloud")
        XCTAssertEqual(review.sections.map(\.id), [.readyToSend])
        XCTAssertEqual(provider.executeCallCount, 0)
        assertSinglePrimaryAction(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask079RemoteApplyKeepsPriorityBeforeCatalogPush() async throws {
        let context = try makeContext()
        let staging = ManualSyncPreviewStagingFake()
        staging.stagedPreviewForLocalApply = makeApplicablePreview(
            newProducts: [makeApplicableProductSummary(barcode: "200")]
        )
        let ownerID = UUID()
        let provider = ManualSyncCatalogPushProviderFake(plans: [
            makeCatalogPushPlan(
                ownerID: ownerID,
                candidates: [
                    PushCandidate(entityKind: .product, localID: "100", action: .dryRunCreateCandidate)
                ]
            )
        ])
        let vm = SupabaseManualSyncViewModel(
            coordinator: ClosureSupabaseManualSyncCoordinatorFake(),
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false,
                supportsCatalogPush: true
            ),
            remotePreviewStaging: staging,
            localApplyService: SupabasePullApplyService(),
            localApplyContext: context,
            isLocalApplyAuthenticated: { true },
            catalogPushProvider: provider,
            currentCatalogPushOwnerID: { ownerID }
        )

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            counts: SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1),
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(newProductCount: 1),
                key: .cloudDataNeedsReview
            )
        ))
        await vm.prepareCatalogPushPlanForReview()

        let state = vm.presentationState
        let review = try XCTUnwrap(state.reviewSheet)
        XCTAssertTrue(vm.canApplyLocalChanges)
        XCTAssertEqual(provider.makePlanCallCount, 1)
        XCTAssertEqual(provider.executeCallCount, 0)
        XCTAssertEqual(review.primaryActionID, .updateDevice)
        XCTAssertEqual(review.primaryActionTitle, "Aggiorna questo dispositivo")
        XCTAssertEqual(review.sections.map(\.id), [.cloudToDevice, .deviceToCloud, .prices])
        XCTAssertNotEqual(state.primaryAction?.id, .sendCloudChanges)
        assertSinglePrimaryAction(state)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask079PreflightBlockersShowNeedsFixWithoutMutativeCTA() async throws {
        let ownerID = UUID()
        let provider = ManualSyncCatalogPushProviderFake(plans: [
            makeCatalogPushPlan(ownerID: ownerID, blockedReasons: [.blockedMissingBaseline])
        ])
        let vm = makePushReadyViewModel(provider: provider, ownerID: ownerID)

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            counts: SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1),
            remotePreviewSummary: remotePreviewSummary()
        ))
        await vm.prepareCatalogPushPlanForReview()

        let state = vm.presentationState
        let review = try XCTUnwrap(state.reviewSheet)
        XCTAssertEqual(state.title, "Da correggere")
        XCTAssertEqual(state.userFacingSummary?.kind, .catalogPushBlocked)
        XCTAssertEqual(review.primaryActionID, .none)
        XCTAssertFalse(review.primaryActionIsEnabled)
        XCTAssertEqual(review.sections.map(\.id), [.sendBlocked])
        XCTAssertEqual(provider.executeCallCount, 0)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask079AuthFailureFailsBeforeWriteAndDoesNotExecute() async throws {
        let ownerID = UUID()
        let plan = makeCatalogPushPlan(
            ownerID: ownerID,
            candidates: [
                PushCandidate(entityKind: .product, localID: "100", action: .dryRunCreateCandidate)
            ]
        )
        let provider = ManualSyncCatalogPushProviderFake(plans: [plan])
        let vm = makePushReadyViewModel(provider: provider, ownerID: nil)

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            counts: SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1),
            remotePreviewSummary: remotePreviewSummary()
        ))
        await vm.prepareCatalogPushPlanForReview()

        XCTAssertEqual(vm.presentationState.userFacingSummary?.kind, .catalogPushFailedBeforeWrite)
        XCTAssertEqual(provider.makePlanCallCount, 0)
        XCTAssertEqual(provider.executeCallCount, 0)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask079StalePlanCannotBeConfirmed() async throws {
        let ownerID = UUID()
        let firstPlan = makeCatalogPushPlan(
            ownerID: ownerID,
            candidates: [
                PushCandidate(entityKind: .product, localID: "100", action: .dryRunCreateCandidate)
            ]
        )
        let changedPlan = makeCatalogPushPlan(
            ownerID: ownerID,
            candidates: [
                PushCandidate(entityKind: .product, localID: "101", action: .dryRunCreateCandidate)
            ]
        )
        let provider = ManualSyncCatalogPushProviderFake(plans: [firstPlan, changedPlan])
        let vm = makePushReadyViewModel(provider: provider, ownerID: ownerID)

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            counts: SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1),
            remotePreviewSummary: remotePreviewSummary()
        ))
        await vm.prepareCatalogPushPlanForReview()
        await vm.sendConfirmedCatalogChanges()

        XCTAssertEqual(vm.presentationState.userFacingSummary?.kind, .catalogPushStale)
        XCTAssertEqual(provider.makePlanCallCount, 2)
        XCTAssertEqual(provider.executeCallCount, 0)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask079ConfirmedPushMapsTerminalResultsAndKeepsSummary() async throws {
        let ownerID = UUID()
        let cases: [(SupabaseManualPushTerminalStatus, SupabaseManualSyncUserFacingSummaryKind)] = [
            (.completed, .catalogPushSucceeded),
            (.completedBaselineRefreshFailed, .catalogPushSucceededNeedsCheck),
            (.partial, .catalogPushPartial),
            (.blockedBeforeWrite, .catalogPushBlocked),
            (.failedBeforeWrite, .catalogPushFailedBeforeWrite),
        ]

        for (status, expectedKind) in cases {
            let plan = makeCatalogPushPlan(
                ownerID: ownerID,
                candidates: [
                    PushCandidate(entityKind: .product, localID: "100", action: .dryRunCreateCandidate)
                ]
            )
            let provider = ManualSyncCatalogPushProviderFake(
                plans: [plan, plan],
                executeResult: SupabaseManualPushResult(
                    status: status,
                    supplierCreates: 0,
                    supplierUpdates: 0,
                    supplierLinks: 0,
                    categoryCreates: 0,
                    categoryUpdates: 0,
                    categoryLinks: 0,
                    productCreates: status == .failedBeforeWrite ? 0 : 1,
                    productUpdates: 0,
                    productLinks: 0,
                    baselineRunID: status == .completed ? UUID() : nil,
                    message: nil
                )
            )
            let vm = makePushReadyViewModel(provider: provider, ownerID: ownerID)
            vm.apply(summary: cloudCheckSummary(
                finalState: .completedSuccessfully,
                counts: SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1),
                remotePreviewSummary: remotePreviewSummary()
            ))
            await vm.prepareCatalogPushPlanForReview()
            await vm.sendConfirmedCatalogChanges()

            XCTAssertEqual(vm.presentationState.userFacingSummary?.kind, expectedKind)
            XCTAssertEqual(provider.executeCallCount, 1)
            XCTAssertNotNil(vm.presentationState.userFacingSummary?.message)
            assertNoForbiddenUserFacingJargon(vm)
        }
    }

    func testTask079DoubleSendTapOnlyExecutesOnce() async throws {
        let ownerID = UUID()
        let plan = makeCatalogPushPlan(
            ownerID: ownerID,
            candidates: [
                PushCandidate(entityKind: .product, localID: "100", action: .dryRunCreateCandidate)
            ]
        )
        let provider = ManualSyncCatalogPushProviderFake(plans: [plan, plan])
        provider.executeDelayNanoseconds = 100_000_000
        let vm = makePushReadyViewModel(provider: provider, ownerID: ownerID)

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            counts: SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1),
            remotePreviewSummary: remotePreviewSummary()
        ))
        await vm.prepareCatalogPushPlanForReview()

        async let first: Void = vm.sendConfirmedCatalogChanges()
        async let second: Void = vm.sendConfirmedCatalogChanges()
        _ = await (first, second)

        XCTAssertEqual(provider.executeCallCount, 1)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask079SessionChangeDuringPreWriteRecheckDoesNotExecute() async throws {
        let ownerID = UUID()
        let plan = makeCatalogPushPlan(
            ownerID: ownerID,
            candidates: [
                PushCandidate(entityKind: .product, localID: "100", action: .dryRunCreateCandidate)
            ]
        )
        let provider = ManualSyncCatalogPushProviderFake(plans: [plan, plan])
        var currentOwnerID: UUID? = ownerID
        provider.onMakePlan = { callCount in
            if callCount == 2 {
                currentOwnerID = nil
            }
        }
        let vm = SupabaseManualSyncViewModel(
            coordinator: ClosureSupabaseManualSyncCoordinatorFake(),
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false,
                supportsCatalogPush: true
            ),
            catalogPushProvider: provider,
            currentCatalogPushOwnerID: { currentOwnerID }
        )

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            counts: SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1),
            remotePreviewSummary: remotePreviewSummary()
        ))
        await vm.prepareCatalogPushPlanForReview()
        await vm.sendConfirmedCatalogChanges()

        XCTAssertEqual(provider.makePlanCallCount, 2)
        XCTAssertEqual(provider.executeCallCount, 0)
        XCTAssertEqual(vm.presentationState.userFacingSummary?.kind, .catalogPushFailedBeforeWrite)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask080RemoteProductPricesEnableUpdateDeviceAndApplyAfterRecheck() async throws {
        let ownerID = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!
        let applyPlan = makeProductPriceApplyPlan(ownerID: ownerID, lineCount: 2, skippedExisting: 1)
        let provider = ManualSyncProductPriceProviderFake(
            applyPlans: [applyPlan, applyPlan],
            applyResult: ProductPriceApplyResult(inserted: 2, skippedExisting: 1, totalConsidered: 3)
        )
        let vm = makeProductPriceReadyViewModel(provider: provider, ownerID: ownerID)

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(
                    remoteProductPriceCount: 3,
                    priceHistorySignalCount: 2
                ),
                key: .cloudDataNeedsReview
            )
        ))
        await vm.prepareProductPricePlansForReview()

        let review = try XCTUnwrap(vm.presentationState.reviewSheet)
        let priceSection = try XCTUnwrap(review.sections.first { $0.id == .prices })
        XCTAssertEqual(review.primaryActionID, .updateDevice)
        XCTAssertTrue(review.primaryActionIsEnabled)
        XCTAssertTrue(priceSection.title.contains("Prezzi da aggiornare"))
        XCTAssertTrue(priceSection.message.contains("Nuovi prezzi trovati: 2"))
        XCTAssertTrue(priceSection.message.contains("Prezzi già presenti: 1"))

        await vm.applyStagedLocalChanges()

        XCTAssertEqual(provider.makeApplyPlanCallCount, 2)
        XCTAssertEqual(provider.applyCallCount, 1)
        XCTAssertEqual(vm.productPriceSummary.applied, 2)
        XCTAssertEqual(vm.lastLocalApplySummary?.priceSummary.applied, 2)
        XCTAssertTrue(vm.presentationState.userFacingSummary?.message.contains("Prezzi aggiornati su questo dispositivo: 2") ?? false)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask080LocalProductPricesEnableCloudSendWithoutCatalogCandidates() async throws {
        let ownerID = UUID(uuidString: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC")!
        let pushPlan = makeProductPricePushPlan(ownerID: ownerID, candidateCount: 2, alreadyPresent: 1)
        let provider = ManualSyncProductPriceProviderFake(
            pushPlans: [pushPlan, pushPlan]
        )
        let vm = makeProductPriceReadyViewModel(provider: provider, ownerID: ownerID)

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            remotePreviewSummary: remotePreviewSummary()
        ))
        await vm.prepareProductPricePlansForReview()

        let state = vm.presentationState
        let review = try XCTUnwrap(state.reviewSheet)
        let priceSection = try XCTUnwrap(review.sections.first { $0.id == .prices })
        XCTAssertEqual(state.primaryAction?.id, .reviewChanges)
        XCTAssertEqual(review.primaryActionID, .sendCloudChanges)
        XCTAssertTrue(review.primaryActionIsEnabled)
        XCTAssertTrue(priceSection.message.contains("Prezzi pronti da inviare: 2"))
        XCTAssertTrue(priceSection.message.contains("Prezzi già presenti: 1"))

        await vm.sendConfirmedCatalogChanges()

        XCTAssertEqual(provider.makePushPlanCallCount, 2)
        XCTAssertEqual(provider.pushCallCount, 1)
        XCTAssertEqual(vm.productPriceSummary.pushed, 2)
        XCTAssertEqual(vm.presentationState.userFacingSummary?.kind, .catalogPushSucceeded)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask080ProductPricePushStalePlanDoesNotWrite() async throws {
        let ownerID = UUID(uuidString: "DDDDDDDD-DDDD-4DDD-8DDD-DDDDDDDDDDDD")!
        let firstPlan = makeProductPricePushPlan(ownerID: ownerID, candidateCount: 1, seed: 10)
        let changedPlan = makeProductPricePushPlan(ownerID: ownerID, candidateCount: 1, seed: 20)
        let provider = ManualSyncProductPriceProviderFake(
            pushPlans: [firstPlan, changedPlan]
        )
        let vm = makeProductPriceReadyViewModel(provider: provider, ownerID: ownerID)

        vm.apply(summary: cloudCheckSummary(
            finalState: .completedSuccessfully,
            remotePreviewSummary: remotePreviewSummary()
        ))
        await vm.prepareProductPricePlansForReview()
        await vm.sendConfirmedCatalogChanges()

        XCTAssertEqual(provider.makePushPlanCallCount, 2)
        XCTAssertEqual(provider.pushCallCount, 0)
        XCTAssertEqual(vm.presentationState.userFacingSummary?.kind, .catalogPushStale)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask080ProductPriceApplyStalePlanDoesNotWrite() async throws {
        let ownerID = UUID(uuidString: "EEEEEEEE-EEEE-4EEE-8EEE-EEEEEEEEEEEE")!
        let firstPlan = makeProductPriceApplyPlan(ownerID: ownerID, lineCount: 1, seed: 30)
        let changedPlan = makeProductPriceApplyPlan(ownerID: ownerID, lineCount: 1, seed: 40)
        let provider = ManualSyncProductPriceProviderFake(
            applyPlans: [firstPlan, changedPlan],
            applyResult: ProductPriceApplyResult(inserted: 1, skippedExisting: 0, totalConsidered: 1)
        )
        let vm = makeProductPriceReadyViewModel(provider: provider, ownerID: ownerID)

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(
                    remoteProductPriceCount: 1,
                    priceHistorySignalCount: 1
                ),
                key: .cloudDataNeedsReview
            )
        ))
        await vm.prepareProductPricePlansForReview()
        await vm.applyStagedLocalChanges()

        XCTAssertEqual(provider.makeApplyPlanCallCount, 2)
        XCTAssertEqual(provider.applyCallCount, 0)
        XCTAssertEqual(vm.lastLocalApplySummary?.priceSummary.applied, 0)
        XCTAssertEqual(vm.lastLocalApplySummary?.priceSummary.blocked, 1)
        XCTAssertTrue(vm.presentationState.userFacingSummary?.message.contains("Prezzi saltati: servono verifiche: 1") ?? false)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask080ProductPriceReviewCombinesSkippedAndBlockedCountsOnce() async throws {
        let ownerID = UUID(uuidString: "FFFFFFFF-FFFF-4FFF-8FFF-FFFFFFFFFFFF")!
        let applyPlan = makeProductPriceApplyPlan(ownerID: ownerID, lineCount: 0, skippedExisting: 1)
        let pushPlan = makeProductPricePushPlan(
            ownerID: ownerID,
            candidateCount: 0,
            alreadyPresent: 2,
            conflicts: 1,
            blocked: 2
        )
        let provider = ManualSyncProductPriceProviderFake(
            applyPlans: [applyPlan],
            pushPlans: [pushPlan]
        )
        let vm = makeProductPriceReadyViewModel(provider: provider, ownerID: ownerID)

        vm.apply(summary: cloudCheckSummary(
            finalState: .technicalReviewNeeded,
            remotePreviewSummary: remotePreviewSummary(
                hasRemoteSignals: true,
                counts: SupabaseManualSyncRemotePreviewAggregateCounts(
                    remoteProductPriceCount: 1,
                    priceHistorySignalCount: 1
                ),
                key: .cloudDataNeedsReview
            )
        ))
        await vm.prepareProductPricePlansForReview()

        let review = try XCTUnwrap(vm.presentationState.reviewSheet)
        let priceSection = try XCTUnwrap(review.sections.first { $0.id == .prices })
        XCTAssertTrue(priceSection.message.contains("Prezzi già presenti: 3"))
        XCTAssertTrue(priceSection.message.contains("Prezzi saltati: servono verifiche: 3"))
        XCTAssertFalse(priceSection.message.contains("Prezzi saltati: servono verifiche: 5"))
        XCTAssertEqual(vm.productPriceSummary.skippedDuplicate, 3)
        XCTAssertEqual(vm.productPriceSummary.skippedConflict, 1)
        XCTAssertEqual(vm.productPriceSummary.blocked, 2)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTask078NoFinalManualSyncCopyUsesOldApplyChangesLabel() throws {
        let root = repoRootURL()
        let supportedLanguages = ["it", "en", "es", "zh-Hans"]
        for language in supportedLanguages {
            let source = try String(
                contentsOf: root.appendingPathComponent("iOSMerchandiseControl/\(language).lproj/Localizable.strings"),
                encoding: .utf8
            )
            let manualSyncLines = source
                .components(separatedBy: .newlines)
                .filter { $0.contains("options.supabase.manualSync.") }
                .joined(separator: "\n")
            XCTAssertFalse(manualSyncLines.contains("Applica modifiche"))
            XCTAssertFalse(manualSyncLines.contains("Apply changes"))
            XCTAssertFalse(manualSyncLines.contains("Aplicar modificaciones"))
            XCTAssertFalse(manualSyncLines.contains("应用更改"))
        }
    }

    func testViewModelSourcesAvoidForbiddenScopeTerms() throws {
        let root = repoRootURL()
        let urls = [
            root.appendingPathComponent("iOSMerchandiseControl/SupabaseManualSyncViewModel.swift"),
            root.appendingPathComponent("iOSMerchandiseControl/SupabaseManualSyncCoordinating.swift"),
        ]
        for url in urls {
            let text = try String(contentsOf: url, encoding: .utf8).lowercased()
            XCTAssertFalse(text.contains("supabaseclient"))
            XCTAssertFalse(text.contains("bgtask"))
            XCTAssertFalse(text.contains("timer("))
            XCTAssertFalse(text.contains("realtime"))
            XCTAssertFalse(text.contains(".rpc"))
            XCTAssertFalse(text.contains(".channel"))
            XCTAssertFalse(text.contains("optionsview"))
            XCTAssertFalse(text.contains("task-067"))
        }
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }

    private func makeApplyReadyViewModel(
        context: ModelContext,
        staging: ManualSyncPreviewStagingFake,
        isAuthenticated: @MainActor @Sendable @escaping () -> Bool = { true }
    ) -> SupabaseManualSyncViewModel {
        SupabaseManualSyncViewModel(
            coordinator: ClosureSupabaseManualSyncCoordinatorFake(),
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false
            ),
            remotePreviewStaging: staging,
            localApplyService: SupabasePullApplyService(),
            localApplyContext: context,
            isLocalApplyAuthenticated: isAuthenticated
        )
    }

    private func makePushReadyViewModel(
        provider: ManualSyncCatalogPushProviderFake,
        ownerID: UUID? = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!,
        isSignedIn: Bool = true
    ) -> SupabaseManualSyncViewModel {
        SupabaseManualSyncViewModel(
            coordinator: ClosureSupabaseManualSyncCoordinatorFake(),
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false,
                supportsCatalogPush: true
            ),
            initialAuthPresentationContext: SupabaseManualSyncAuthPresentationContext(
                isSignedIn: isSignedIn,
                canSignIn: true,
                isTransitioning: false
            ),
            catalogPushProvider: provider,
            currentCatalogPushOwnerID: { ownerID }
        )
    }

    private func makeProductPriceReadyViewModel(
        provider: ManualSyncProductPriceProviderFake,
        ownerID: UUID?,
        isSignedIn: Bool = true
    ) -> SupabaseManualSyncViewModel {
        SupabaseManualSyncViewModel(
            coordinator: ClosureSupabaseManualSyncCoordinatorFake(),
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false,
                supportsCatalogPush: false,
                supportsProductPriceSync: true
            ),
            initialAuthPresentationContext: SupabaseManualSyncAuthPresentationContext(
                isSignedIn: isSignedIn,
                canSignIn: true,
                isTransitioning: false
            ),
            currentCatalogPushOwnerID: { ownerID },
            productPriceProvider: provider,
            currentProductPriceOwnerID: { ownerID }
        )
    }

    private func makeCatalogPushPlan(
        ownerID: UUID,
        candidates: [PushCandidate] = [],
        blockedReasons: [PushBlockedReason] = [],
        warnings: [PushWarning] = []
    ) -> ManualPushPlan {
        ManualPushPlan(
            generatedAt: Date(timeIntervalSince1970: 1_778_500_000),
            ownerUserID: ownerID,
            candidates: candidates,
            blockedReasons: blockedReasons,
            warnings: warnings,
            futureEventChangedCount: candidates.count
        )
    }

    private func makeProductPriceApplyPlan(
        ownerID: UUID,
        lineCount: Int,
        skippedExisting: Int = 0,
        conflicts: Int = 0,
        blocked: Int = 0,
        seed: Int = 0
    ) -> ProductPriceApplyPlan {
        var lines: [ProductPriceApplyLine] = []
        for index in 0..<lineCount {
            let remoteRowID = uuid(30_000 + seed + index)
            let productID = uuid(40_000 + seed + index)
            let canonicalPrice = PriceCanonicalizer.canonicalAmount(from: Double(index + 1))!
            let effectiveAt = Date(timeIntervalSince1970: TimeInterval(1_778_500_000 + index))
            lines.append(
                ProductPriceApplyLine(
                    remoteRowID: remoteRowID,
                    productID: productID,
                    productBarcode: "P\(index)",
                    type: PriceType.purchase.rawValue,
                    canonicalPrice: canonicalPrice,
                    effectiveAt: effectiveAt,
                    effectiveAtCanonical: "2026-05-0\(index + 1) 10:30:00",
                    createdAt: nil
                )
            )
        }
        let summary = ProductPriceApplySummary(
            remoteRead: lineCount + skippedExisting + conflicts + blocked,
            included: lineCount,
            skippedExisting: skippedExisting,
            unmapped: blocked,
            invalid: 0,
            conflicts: conflicts,
            mappingConflicts: 0,
            partial: false,
            truncated: false,
            sourceError: nil
        )
        let blockReasons: [ProductPriceApplyBlockReason] = {
            if lineCount == 0 {
                return [.noApplicableRows]
            }
            if conflicts > 0 {
                return [.conflicts]
            }
            if blocked > 0 {
                return [.unmappedProducts]
            }
            return []
        }()

        return ProductPriceApplyPlan(
            generatedAt: Date(timeIntervalSince1970: 1_778_500_000),
            sessionSnapshot: ProductPriceApplySessionSnapshot(userID: ownerID),
            sourceState: ProductPriceApplySourceState(),
            summary: summary,
            blockReasons: blockReasons,
            linesToInsert: lines,
            issues: [],
            remoteRows: []
        )
    }

    private func makeProductPricePushPlan(
        ownerID: UUID,
        candidateCount: Int,
        alreadyPresent: Int = 0,
        conflicts: Int = 0,
        blocked: Int = 0,
        seed: Int = 0
    ) -> ProductPricePushDryRunPlan {
        let candidates = (0..<candidateCount).map { index in
            makeProductPricePushLine(ownerID: ownerID, index: seed + index, reason: .candidate)
        }
        let present = (0..<alreadyPresent).map { index in
            makeProductPricePushLine(ownerID: ownerID, index: seed + 1_000 + index, reason: .alreadyPresentRemote)
        }
        let conflictLines = (0..<conflicts).map { index in
            makeProductPricePushLine(ownerID: ownerID, index: seed + 2_000 + index, reason: .conflictSameKeyDifferentPrice)
        }
        let blockedLines = (0..<blocked).map { index in
            ProductPricePushDryRunLine(
                id: "blocked-\(seed)-\(index)",
                reason: .blockedNoRemoteID,
                key: nil,
                productBarcode: "P\(seed)-blocked-\(index)",
                productDisplayName: "Price row",
                type: PriceType.purchase.rawValue,
                canonicalPrice: PriceCanonicalizer.canonicalAmount(from: Double(index + 1)),
                effectiveAtCanonical: "2026-05-01 10:30:00",
                createdAtCanonical: "2026-05-01 10:31:00",
                source: nil,
                note: nil,
                detail: nil,
                payload: nil
            )
        }

        return ProductPricePushDryRunPlan(
            generatedAt: Date(timeIntervalSince1970: 1_778_500_000),
            sessionSnapshot: ProductPricePushDryRunSessionSnapshot(userID: ownerID, lastLinkedUserID: ownerID),
            remoteDedupeStatus: .complete,
            summary: ProductPricePushDryRunSummary(
                localPriceCount: candidateCount + alreadyPresent + conflicts + blocked,
                remoteRowsRead: alreadyPresent + conflicts,
                remotePagesRead: alreadyPresent + conflicts > 0 ? 1 : 0,
                readyCandidates: candidateCount,
                alreadyPresentRemote: alreadyPresent,
                conflictSameKeyDifferentPrice: conflicts,
                localDuplicateSameKey: 0,
                localConflictSameKeyDifferentPrice: 0,
                blockedNoRemoteID: blocked,
                blockedNoAuth: 0,
                blockedAccountMismatch: 0,
                blockedBaselineMissing: 0,
                blockedBaselineStale: 0,
                blockedBaselinePartial: 0,
                excludedInvalidLocal: 0
            ),
            candidates: candidates,
            alreadyPresentRemote: present,
            conflictSameKeyDifferentPrice: conflictLines,
            localDuplicateSameKey: [],
            localConflictSameKeyDifferentPrice: [],
            blockedNoRemoteID: blockedLines,
            excludedInvalidLocal: []
        )
    }

    private func makeProductPricePushLine(
        ownerID: UUID,
        index: Int,
        reason: ProductPricePushDryRunLineReason
    ) -> ProductPricePushDryRunLine {
        let productID = uuid(50_000 + index)
        let effectiveAt = "2026-05-01 10:\(String(format: "%02d", index % 60)):00"
        let key = ProductPricePushDryRunLogicalKey(
            ownerUserID: ownerID,
            productID: productID,
            type: PriceType.purchase.rawValue,
            effectiveAt: effectiveAt
        )
        let canonicalPrice = PriceCanonicalizer.canonicalAmount(from: Double(index + 1))!
        let payload = ProductPricePushDryRunCandidatePayload(
            ownerUserID: ownerID,
            productID: productID,
            remoteType: "PURCHASE",
            canonicalPrice: canonicalPrice,
            effectiveAt: effectiveAt,
            createdAt: "2026-05-01 10:31:00",
            source: nil,
            note: nil
        )
        return ProductPricePushDryRunLine(
            id: "\(reason.rawValue)-\(index)",
            reason: reason,
            key: key,
            productBarcode: "P\(index)",
            productDisplayName: "Price row",
            type: PriceType.purchase.rawValue,
            canonicalPrice: canonicalPrice,
            effectiveAtCanonical: effectiveAt,
            createdAtCanonical: "2026-05-01 10:31:00",
            source: nil,
            note: nil,
            detail: nil,
            payload: payload
        )
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
    }

    private func makeApplicablePreview(
        outcome: SyncPreviewOutcome = .success,
        newProducts: [SyncPreviewProductSummary] = [],
        updateCandidates: [SyncPreviewProductSummary] = [],
        conflicts: [SyncPreviewConflict] = [],
        warnings: [SyncPreviewWarning] = [],
        sourceErrors: [SyncPreviewWarning] = []
    ) -> SyncPreview {
        SyncPreview(
            generatedAt: Date(timeIntervalSince1970: 1_778_400_000),
            outcome: outcome,
            remoteCounts: RemoteInventorySnapshotCounts(
                products: newProducts.count + updateCandidates.count + conflicts.count,
                activeProducts: newProducts.count + updateCandidates.count + conflicts.count,
                tombstonedProducts: 0,
                suppliers: 0,
                categories: 0,
                productPrices: 0
            ),
            localCounts: LocalInventorySnapshotCounts(products: 0, suppliers: 0, categories: 0, productPrices: 0),
            newProducts: newProducts,
            updateCandidates: updateCandidates,
            conflicts: conflicts,
            unchangedProducts: [],
            remoteTombstones: [],
            supplierDiffs: [],
            categoryDiffs: [],
            priceHistoryDiffs: [],
            warnings: warnings,
            metrics: [],
            sourceErrors: sourceErrors
        )
    }

    private func makeApplicableProductSummary(
        barcode: String = "100",
        productName: String = "Remote item",
        supplierName: String? = nil,
        categoryName: String? = nil
    ) -> SyncPreviewProductSummary {
        let payload = SyncPreviewProductApplyPayload(
            remoteID: UUID(),
            remoteUpdatedAt: Date(timeIntervalSince1970: 1_778_400_001),
            barcode: barcode,
            productName: productName,
            purchasePrice: 10,
            retailPrice: 12,
            stockQuantity: 99,
            supplierName: supplierName,
            supplierRemoteID: supplierName == nil ? nil : UUID(),
            categoryName: categoryName,
            categoryRemoteID: categoryName == nil ? nil : UUID()
        )
        return SyncPreviewProductSummary(
            classification: .newProduct,
            remoteID: payload.remoteID,
            barcode: barcode,
            productName: productName,
            applyPayload: payload
        )
    }

    private func makeTask075SmallDatasetCoordinator(
        fake: SupabaseManualSyncCoordinatorDryRunFake
    ) -> SupabaseManualSyncCoordinator {
        SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: fake,
                baselineGate: fake,
                pendingSnapshot: fake,
                phaseSimulation: fake,
                remotePreviewProvider: fake
            )
        )
    }

    private func makeTask075SmallDatasetViewModel(
        coordinator: any SupabaseManualSyncCoordinating
    ) -> SupabaseManualSyncViewModel {
        SupabaseManualSyncViewModel(
            coordinator: coordinator,
            capabilities: SupabaseManualSyncCapabilitySet(
                supportsRemoteCloudCheck: true,
                supportsGuidedManualSync: false
            )
        )
    }
}
