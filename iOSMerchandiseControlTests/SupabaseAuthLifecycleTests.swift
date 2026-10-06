import Combine
import Foundation
import Supabase
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseAuthLifecycleTests: XCTestCase {
    func testRealDeviceAuthorizationPublicationOccursOnMainActorBeforeObservedDefaultsWrite() async throws {
        let fixture = try AuthLifecycleFixture()
        _ = try await fixture.provider.client.auth.session
        let scope = try makeDeviceStatusStandardSelection(owner: fixture.original.user.id)
        defer { scope.restore(); fixture.transport.releaseDeviceStatus() }
        let observation = DeviceAuthorizationPublicationObservation()
        let service = ShopDeviceRegistrationService(clientProvider: fixture.provider,
            authorizationPublicationObserver: { observation.record($0) })
        let first = Task { await service.currentOwnerDeviceStatus(reason: "TASK144_THREAD_FIRST_ACTIVE", force: true) }
        await fulfillment(of: [fixture.transport.deviceStatusStarted], timeout: 3)
        fixture.transport.releaseDeviceStatus()
        let firstActive = await first.value
        XCTAssertTrue(firstActive.canWrite)
        let refused = await service.currentOwnerDeviceStatus(reason: "TASK144_THREAD_PUBLICATION", force: true)
        XCTAssertEqual(refused.status, "revoked")
        XCTAssertFalse(refused.canWrite)
        XCTAssertEqual(observation.values, [true],
            "The real actor service must publish observed authorization defaults on MainActor; a worker lease cannot synchronously wait on the UI lease reader")
        XCTAssertTrue(SelectedShopStore().hasConfirmedDeviceDenial(accountHash: scope.accountHash,
            shopID: scope.shopID, deviceIdentityHash: scope.deviceHash))
    }

    func testHealthyCacheReadDoesNotSupersedeAnAdmittedHeldDeviceStatusRPC() async throws {
        let fixture = try AuthLifecycleFixture()
        _ = try await fixture.provider.client.auth.session
        let scope = try makeDeviceStatusStandardSelection(owner: fixture.original.user.id)
        defer { scope.restore(); fixture.transport.releaseDeviceStatus() }
        let service = ShopDeviceRegistrationService(clientProvider: fixture.provider)
        let initial = Task { await service.currentOwnerDeviceStatus(reason: "TASK144_CACHE_HTTP_FIRST", force: true) }
        await fulfillment(of: [fixture.transport.deviceStatusStarted], timeout: 3)
        fixture.transport.releaseDeviceStatus()
        let active = await initial.value
        XCTAssertTrue(active.canWrite)
        let held = expectation(description: "Actual later device RPC admitted and held")
        fixture.transport.holdNextDeviceStatus(active: false, entered: held)
        let admitted = Task { await service.currentOwnerDeviceStatus(reason: "TASK144_CACHE_HTTP_REVOKED", force: true) }
        await fulfillment(of: [held], timeout: 3)
        let cached = await service.currentOwnerDeviceStatus(reason: "TASK144_CACHE_READ_DURING_HTTP", force: false)
        XCTAssertEqual(cached, active)
        XCTAssertEqual(fixture.transport.deviceStatusRequestCount, 2, "Healthy cache must add no RPC")
        fixture.transport.releaseDeviceStatus()
        let revoked = await admitted.value
        XCTAssertEqual(revoked.status, "revoked", "A read-only healthy cache lookup must not retire genuine HTTP admission")
        XCTAssertFalse(revoked.canWrite)
        XCTAssertTrue(SelectedShopStore().hasConfirmedDeviceDenial(accountHash: scope.accountHash,
            shopID: scope.shopID, deviceIdentityHash: scope.deviceHash))
    }

    func testEarlierActiveDeviceStatusCannotEraseLaterRevocationOrGrantReturnedAuthority() async throws {
        let fixture = try AuthLifecycleFixture()
        _ = try await fixture.provider.client.auth.session
        let scope = try makeDeviceStatusStandardSelection(owner: fixture.original.user.id)
        defer { scope.restore(); fixture.transport.releaseDeviceStatus() }
        let service = ShopDeviceRegistrationService(clientProvider: fixture.provider)
        let oldActive = Task { await service.currentOwnerDeviceStatus(reason: "TASK144_HELD_ACTIVE", force: true) }
        await fulfillment(of: [fixture.transport.deviceStatusStarted], timeout: 3)
        let revoked = await service.currentOwnerDeviceStatus(reason: "TASK144_LATER_REVOKED", force: true)
        XCTAssertEqual(revoked.status, "revoked")
        XCTAssertFalse(revoked.canWrite)
        XCTAssertTrue(SelectedShopStore().hasConfirmedDeviceDenial(accountHash: scope.accountHash,
            shopID: scope.shopID, deviceIdentityHash: scope.deviceHash))
        fixture.transport.releaseDeviceStatus()
        let stale = await oldActive.value
        XCTAssertNotEqual(stale.status, "active", "The obsolete RPC return value must not grant authority either")
        XCTAssertFalse(stale.canWrite)
        let reopenedDefaults = UserDefaults()
        XCTAssertTrue(SelectedShopStore(defaults: reopenedDefaults).hasConfirmedDeviceDenial(accountHash: scope.accountHash,
            shopID: scope.shopID, deviceIdentityHash: scope.deviceHash), "A fresh store reader must retain the device revocation")
        let cached = await service.currentOwnerDeviceStatus(reason: "TASK144_CURRENT_SNAPSHOT", force: false)
        XCTAssertEqual(cached.status, "revoked")
        XCTAssertEqual(cached.checkedAt, revoked.checkedAt)
        XCTAssertEqual(fixture.transport.deviceStatusRequestCount, 2)
        let fresh = await service.currentOwnerDeviceStatus(reason: "TASK144_FRESH_ACTIVE_AFTER_REVOKED", force: true)
        XCTAssertEqual(fresh.status, "active")
        XCTAssertTrue(fresh.canWrite)
        XCTAssertFalse(SelectedShopStore(defaults: reopenedDefaults).hasConfirmedDeviceDenial(accountHash: scope.accountHash,
            shopID: scope.shopID, deviceIdentityHash: scope.deviceHash), "A genuinely new admission may restore this exact device")
        XCTAssertEqual(fixture.transport.deviceStatusRequestCount, 3)
    }

    func testCancelledHeldDeviceStatusCannotClearConfirmedRevocation() async throws {
        let fixture = try AuthLifecycleFixture()
        _ = try await fixture.provider.client.auth.session
        let scope = try makeDeviceStatusStandardSelection(owner: fixture.original.user.id)
        defer { scope.restore(); fixture.transport.releaseDeviceStatus() }
        let service = ShopDeviceRegistrationService(clientProvider: fixture.provider)
        let cancelled = Task { await service.currentOwnerDeviceStatus(reason: "TASK144_CANCELLED_ACTIVE", force: true) }
        await fulfillment(of: [fixture.transport.deviceStatusStarted], timeout: 3)
        let revoked = await service.currentOwnerDeviceStatus(reason: "TASK144_REVOCATION_BEFORE_CANCEL", force: true)
        XCTAssertEqual(revoked.status, "revoked")
        cancelled.cancel()
        fixture.transport.releaseDeviceStatus()
        let returned = await cancelled.value
        XCTAssertFalse(returned.canWrite)
        XCTAssertNotEqual(returned.status, "active")
        XCTAssertTrue(SelectedShopStore().hasConfirmedDeviceDenial(accountHash: scope.accountHash,
            shopID: scope.shopID, deviceIdentityHash: scope.deviceHash))
        let cached = await service.currentOwnerDeviceStatus(reason: "TASK144_CANCELLED_CURRENT_SNAPSHOT", force: false)
        XCTAssertEqual(cached.status, "revoked")
        XCTAssertEqual(cached.checkedAt, revoked.checkedAt)
    }

    func testCachedActiveDeviceStatusCannotOverrideExternalRevocationAndFreshAdmissionCanRestore() async throws {
        let fixture = try AuthLifecycleFixture()
        _ = try await fixture.provider.client.auth.session
        let scope = try makeDeviceStatusStandardSelection(owner: fixture.original.user.id)
        defer { scope.restore(); fixture.transport.releaseDeviceStatus() }
        let service = ShopDeviceRegistrationService(clientProvider: fixture.provider)
        let first = Task { await service.currentOwnerDeviceStatus(reason: "TASK144_CACHE_FIRST_ACTIVE", force: true) }
        await fulfillment(of: [fixture.transport.deviceStatusStarted], timeout: 3)
        fixture.transport.releaseDeviceStatus()
        let active = await first.value
        XCTAssertEqual(active.status, "active"); XCTAssertTrue(active.canWrite)
        let healthyCache = await service.currentOwnerDeviceStatus(reason: "TASK144_CACHE_HEALTHY", force: false)
        XCTAssertEqual(healthyCache, active)
        XCTAssertEqual(fixture.transport.deviceStatusRequestCount, 1, "Unchanged authority should reuse its healthy cache offline")
        let external = ShopDeviceRegistrationService(clientProvider: fixture.provider)
        let revoked = await external.currentOwnerDeviceStatus(reason: "TASK144_EXTERNAL_INSTANCE_REVOKED", force: true)
        XCTAssertEqual(revoked.status, "revoked")
        XCTAssertTrue(SelectedShopStore().hasConfirmedDeviceDenial(accountHash: scope.accountHash,
            shopID: scope.shopID, deviceIdentityHash: scope.deviceHash))
        let cachedAfterDenial = await service.currentOwnerDeviceStatus(reason: "TASK144_CACHE_AFTER_REVOCATION", force: false)
        XCTAssertFalse(cachedAfterDenial.canWrite, "A writable TTL cache cannot override a current durable denial")
        XCTAssertNotEqual(cachedAfterDenial.status, "active")
        XCTAssertEqual(fixture.transport.deviceStatusRequestCount, 2, "Known durable denial must be enforced without an online request")
        XCTAssertTrue(SelectedShopStore(defaults: UserDefaults()).hasConfirmedDeviceDenial(accountHash: scope.accountHash,
            shopID: scope.shopID, deviceIdentityHash: scope.deviceHash))
        let fresh = await service.currentOwnerDeviceStatus(reason: "TASK144_EXPLICIT_NEW_ACTIVE", force: true)
        XCTAssertTrue(fresh.canWrite); XCTAssertEqual(fresh.status, "active")
        XCTAssertFalse(SelectedShopStore().hasConfirmedDeviceDenial(accountHash: scope.accountHash,
            shopID: scope.shopID, deviceIdentityHash: scope.deviceHash))
        let freshCached = await service.currentOwnerDeviceStatus(reason: "TASK144_CACHE_FRESH_RESTORED", force: false)
        XCTAssertEqual(freshCached, fresh)
        XCTAssertEqual(fixture.transport.deviceStatusRequestCount, 3)
    }

    func testDeviceCacheCannotReuseAuthorityAcrossAccountBindingOrInstallChange() async throws {
        for mismatch in ["account", "binding", "device"] {
            let fixture = try AuthLifecycleFixture()
            _ = try await fixture.provider.client.auth.session
            let scope = try makeDeviceStatusStandardSelection(owner: fixture.original.user.id)
            defer { scope.restore(); fixture.transport.releaseDeviceStatus() }
            let suite = "Task144DeviceCache.\(UUID().uuidString)"
            let deviceDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { deviceDefaults.removePersistentDomain(forName: suite) }
            deviceDefaults.set(try DeviceInstallIDStore().requireDeviceInstallID(), forKey: "shop.device.install.id")
            let service = ShopDeviceRegistrationService(clientProvider: fixture.provider,
                installIDStore: DeviceInstallIDStore(defaults: deviceDefaults))
            let first = Task { await service.currentOwnerDeviceStatus(reason: "TASK144_CACHE_SCOPE_FIRST", force: true) }
            await fulfillment(of: [fixture.transport.deviceStatusStarted], timeout: 3)
            fixture.transport.releaseDeviceStatus()
            let original = await first.value
            XCTAssertTrue(original.canWrite)
            if mismatch == "account" {
                SelectedShopStore().noteActiveAccount(AccountBindingStore.accountHash(for: UUID()))
            } else if mismatch == "binding" {
                XCTAssertTrue(AccountBindingStore().saveBinding(accountHash: scope.accountHash, storeIdentity: .anonymous))
            } else {
                deviceDefaults.set(UUID().uuidString.lowercased(), forKey: "shop.device.install.id")
            }
            let changed = await service.currentOwnerDeviceStatus(reason: "TASK144_CACHE_SCOPE_CHANGED", force: false)
            XCTAssertFalse(changed.canWrite, "A cached authorization belongs only to the admitted account/binding/install")
            XCTAssertNotEqual(changed, original)
        }
    }

    private func makeDeviceStatusStandardSelection(owner: UUID) throws -> (accountHash: String, shopID: UUID, deviceHash: String, restore: () -> Void) {
        let defaults = UserDefaults.standard
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let shopID = UUID()
        let deviceHash = DeviceInstallIDStore.identityHash(for: try DeviceInstallIDStore().requireDeviceInstallID())
        let keys = ["mobile.shopContext.activeAccountHash.v1", "sync.accountBinding.v1",
                    "mobile.shopContext.selected.v1.account.\(accountHash)",
                    "mobile.shopContext.resolved.v1.account.\(accountHash)",
                    "mobile.shopContext.localDeviceDenied.v1.\(accountHash).\(shopID.uuidString.lowercased()).\(deviceHash)",
                    SelectedShopStore.localAuthorizationRevisionKey]
        // Only known admission keys are retained in memory and restored; no
        // private configuration/session or unrelated defaults are enumerated.
        let previous = keys.map { defaults.object(forKey: $0) }
        let selected = SelectedShop(shopID: shopID, code: "TASK144", name: "Controlled device status",
            role: "owner", status: "active", selectable: true, canWrite: true)
        let store = SelectedShopStore()
        store.noteActiveAccount(accountHash)
        XCTAssertTrue(store.save(selected, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore().saveBinding(accountHash: accountHash, storeIdentity: selected.localStoreIdentity))
        return (accountHash, shopID, deviceHash, {
            Task126OwnerStoreGate.withAutomaticScopeLeaseInvalidated {
                for (index, key) in keys.enumerated() {
                    if let old = previous[index] { defaults.set(old, forKey: key) }
                    else { defaults.removeObject(forKey: key) }
                }
            }
            for (index, key) in keys.enumerated() {
                XCTAssertEqual(defaults.object(forKey: key) as? NSObject, previous[index] as? NSObject)
            }
        })
    }

    func testExpiredKnownSessionKeepsLocalMutationIdentityWhileRefreshIsHeldAndLogoutClearsIt() async throws {
        let fixture = try AuthLifecycleFixture(expiredOriginal: true)
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        defer { fixture.transport.releaseRefresh() }
        let service = SupabaseAuthService(provider: fixture.provider)
        let viewModel = SupabaseAuthViewModel(authService: service)
        XCTAssertEqual(viewModel.sessionInfo?.userID, fixture.original.user.id)
        XCTAssertFalse(viewModel.isSignedIn, "Cloud calls still require the existing valid session gate")
        XCTAssertEqual(viewModel.localMutationOwnerUserID, fixture.original.user.id,
            "Known SDK identity must reach the exact local store fence before refresh completes")
        fixture.transport.releaseRefresh()
        _ = try await fixture.provider.client.auth.session
        try await service.signOut()
        viewModel.refreshCurrentSessionSnapshot()
        XCTAssertNil(viewModel.localMutationOwnerUserID, "Explicit logout must remove local identity")
    }

    func testEarlierRefreshCannotRestoreCompletedLogoutOrRestart() async throws {
        let fixture = try AuthLifecycleFixture()
        let service = SupabaseAuthService(provider: fixture.provider)
        let oldClient = fixture.provider.client
        let refreshed = expectation(description: "Real SDK late refresh completed")
        let registration = await oldClient.auth.onAuthStateChange { event, _ in
            if event == .tokenRefreshed { refreshed.fulfill() }
        }
        defer { registration.remove() }
        let refresh = Task { try await oldClient.auth.refreshSession() }
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        try await service.signOut()
        XCTAssertNil(service.currentSession)
        fixture.transport.releaseRefresh()
        _ = try await refresh.value
        await fulfillment(of: [refreshed], timeout: 3)
        XCTAssertNil(service.currentSession, "Late refresh must not restore the completed logout")
        let restarted = fixture.makeIndependentSDKClient()
        XCTAssertNil(restarted.auth.currentSession, "Restart on the same persisted storage must remain signed out")
    }

    func testBackgroundProviderRefreshCannotRestoreForegroundLogout() async throws {
        let fixture = try AuthLifecycleFixture()
        let backgroundProvider = fixture.makeProvider()
        let oldBackgroundClient = backgroundProvider.client
        let refresh = Task { try await oldBackgroundClient.auth.refreshSession() }
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        try await SupabaseAuthService(provider: fixture.provider).signOut()
        fixture.transport.releaseRefresh()
        _ = try await refresh.value
        XCTAssertNil(fixture.provider.client.auth.currentSession)
        XCTAssertNil(backgroundProvider.client.auth.currentSession)
        XCTAssertNil(fixture.makeIndependentSDKClient().auth.currentSession)
    }

    func testEarlierRefreshCannotOverwriteDifferentAccountLogin() async throws {
        try await assertEarlierRefreshCannotOverwriteNewLogin(sameUser: false)
    }

    func testEarlierRefreshCannotOverwriteSameAccountNewLogin() async throws {
        try await assertEarlierRefreshCannotOverwriteNewLogin(sameUser: true)
    }

    private func assertEarlierRefreshCannotOverwriteNewLogin(sameUser: Bool) async throws {
        let fixture = try AuthLifecycleFixture(sameUserForNewLogin: sameUser)
        let oldClient = fixture.provider.client
        let refresh = Task { try await oldClient.auth.refreshSession() }
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        try await SupabaseAuthService(provider: fixture.provider).signOut()
        let newSession = try await fixture.provider.client.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: "synthetic-new-login"))
        XCTAssertEqual(newSession.user.id, fixture.newLogin.user.id)
        fixture.transport.releaseRefresh()
        _ = try await refresh.value
        XCTAssertEqual(fixture.provider.client.auth.currentSession?.accessToken, fixture.newLogin.accessToken)
        XCTAssertEqual(fixture.makeIndependentSDKClient().auth.currentSession?.accessToken, fixture.newLogin.accessToken)
    }

    func testOrdinaryRefreshAndBootstrapRemainValid() async throws {
        let fixture = try AuthLifecycleFixture()
        let service = SupabaseAuthService(provider: fixture.provider)
        let viewModel = SupabaseAuthViewModel(authService: service)
        XCTAssertTrue(viewModel.isSignedIn)
        let refresh = Task { try await fixture.provider.client.auth.refreshSession() }
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        fixture.transport.releaseRefresh()
        _ = try await refresh.value
        XCTAssertEqual(fixture.provider.client.auth.currentSession?.accessToken, fixture.refreshed.accessToken)
        XCTAssertEqual(fixture.makeIndependentSDKClient().auth.currentSession?.accessToken, fixture.refreshed.accessToken)
    }

    func testForegroundAndBackgroundUseOneClientPerProjectStorageKey() async throws {
        let fixture = try AuthLifecycleFixture()
        XCTAssertTrue(fixture.provider.client === fixture.makeProvider().client)
        let other = SupabaseClientProvider(config: .init(projectURL: URL(string: "https://other-project.example.invalid")!,
            publishableKey: "synthetic-other-publishable", productImageAPIBaseURL: nil),
            authStorage: fixture.storage, session: fixture.session, autoRefreshToken: false,
            authRegistry: fixture.registry)
        XCTAssertFalse(fixture.provider.client === other.client)
        XCTAssertNil(other.client.auth.currentSession)
    }

    func testBufferedSDKEventCannotReviveLogoutOrReplaceSameUserNewLogin() async throws {
        let fixture = try AuthLifecycleFixture(sameUserForNewLogin: true)
        let service = SupabaseAuthService(provider: fixture.provider)
        let viewModel = SupabaseAuthViewModel(authService: service)
        var events = service.authStateChanges().makeAsyncIterator()
        let nextEvent = await events.next()
        let buffered = try XCTUnwrap(nextEvent)
        try await service.signOut()
        viewModel.refreshCurrentSessionSnapshot()
        XCTAssertFalse(viewModel.isSignedIn)
        viewModel.apply(buffered)
        XCTAssertFalse(viewModel.isSignedIn, "An already buffered SDK event keeps its retired generation")
        _ = try await fixture.provider.client.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: "synthetic-new-login"))
        viewModel.refreshCurrentSessionSnapshot()
        XCTAssertEqual(viewModel.sessionInfo?.email, fixture.newLogin.user.email)
        viewModel.apply(buffered)
        XCTAssertEqual(viewModel.sessionInfo?.email, fixture.newLogin.user.email)
        XCTAssertEqual(viewModel.sessionInfo?.userID, fixture.newLogin.user.id)
    }

    func testInteractiveGenerationDoesNotBootstrapRetiredExpiredSession() async throws {
        let fixture = try AuthLifecycleFixture(expiredOriginal: true)
        let oldClient = fixture.provider.client
        let oldRefreshed = expectation(description: "Retired bootstrap refresh completes")
        let oldRegistration = await oldClient.auth.onAuthStateChange { event, _ in
            if event == .tokenRefreshed { oldRefreshed.fulfill() }
        }
        defer { oldRegistration.remove() }
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        let replacement = try await fixture.provider.prepareInteractiveSignIn()
        let retainedExpiredSession = replacement.client.auth.currentSession
        XCTAssertNil(retainedExpiredSession, "Explicit login must start from verified empty session storage")
        var bootstrap: Task<Session?, Never>?
        if retainedExpiredSession != nil {
            // Before the fix this is the *new generation's* SDK bootstrap A.
            // Its valid reply must not overwrite B completed on the same client.
            bootstrap = Task { try? await replacement.client.auth.session }
            await fulfillment(of: [fixture.transport.secondRefreshStarted], timeout: 3)
        }
        _ = try await replacement.client.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: "synthetic-new-login"))
        fixture.transport.releaseRefresh(index: 1)
        _ = await bootstrap?.value
        fixture.transport.releaseRefresh(index: 0)
        await fulfillment(of: [oldRefreshed], timeout: 3)
        XCTAssertEqual(fixture.provider.client.auth.currentSession?.accessToken, fixture.newLogin.accessToken)
        XCTAssertEqual(fixture.makeIndependentSDKClient().auth.currentSession?.accessToken, fixture.newLogin.accessToken)
        XCTAssertEqual(fixture.transport.refreshRequestCount, 1, "Only the retired ordinary bootstrap was allowed to start")
    }

    func testOrdinaryExpiredBootstrapRefreshRemainsValid() async throws {
        let fixture = try AuthLifecycleFixture(expiredOriginal: true)
        let service = SupabaseAuthService(provider: fixture.provider)
        let viewModel = SupabaseAuthViewModel(authService: service)
        XCTAssertFalse(viewModel.isSignedIn)
        var events = service.authStateChanges().makeAsyncIterator()
        _ = await events.next()
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        fixture.transport.releaseRefresh()
        let nextRefresh = await awaitNextTokenRefresh(&events)
        let refreshed = try XCTUnwrap(nextRefresh)
        viewModel.apply(refreshed)
        XCTAssertTrue(viewModel.isSignedIn)
        XCTAssertEqual(service.currentSession?.email, fixture.refreshed.user.email)
        XCTAssertEqual(fixture.makeIndependentSDKClient().auth.currentSession?.accessToken, fixture.refreshed.accessToken)
    }

    private func awaitNextTokenRefresh(_ events: inout AsyncStream<SupabaseScopedAuthEvent>.Iterator) async -> SupabaseScopedAuthEvent? {
        while let event = await events.next() {
            if case .tokenRefreshed = event.event { return event }
        }
        return nil
    }

    func testNewExplicitLoginRetiresEarlierRefreshEvenWithoutLogout() async throws {
        let fixture = try AuthLifecycleFixture()
        let oldClient = fixture.provider.client
        let refresh = Task { try await oldClient.auth.refreshSession() }
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        let service = fixture.makeNativeSignInService()
        let login = try await service.signInWithGoogle()
        XCTAssertEqual(login.info.userID, fixture.newLogin.user.id)
        fixture.transport.releaseRefresh()
        _ = try await refresh.value
        XCTAssertEqual(fixture.provider.client.auth.currentSession?.accessToken, fixture.newLogin.accessToken)
        XCTAssertEqual(fixture.makeIndependentSDKClient().auth.currentSession?.accessToken, fixture.newLogin.accessToken)
    }

    func testEarlierSDKSignInCompletionCannotReturnSuccessAfterLogoutAndNewLogin() async throws {
        let fixture = try AuthLifecycleFixture(holdFirstLogin: true)
        let service = fixture.makeNativeSignInService()
        let login = Task { try await service.signInWithGoogle() }
        await fulfillment(of: [fixture.transport.loginStarted], timeout: 3)
        try await service.signOut()
        let current = try await service.signInWithGoogle()
        fixture.transport.releaseLogin()
        do { _ = try await login.value; XCTFail("Retired sign-in completion must be rejected") }
        catch let failure as SupabaseAuthOperationFailure {
            XCTAssertNotEqual(failure.generation, current.generation)
            XCTAssertEqual(failure.error, .oauthCancelled)
        }
        XCTAssertEqual(service.currentSession?.email, fixture.newLogin.user.email)
        XCTAssertEqual(fixture.makeIndependentSDKClient().auth.currentSession?.accessToken, fixture.newLogin.accessToken)
    }

    func testViewModelDropsEarlierSignInSuccessAfterNewLogin() async throws {
        try await assertViewModelDropsEarlierSignIn(heldStatus: 200)
    }

    func testViewModelDropsEarlierSignInFailureAfterNewLogin() async throws {
        try await assertViewModelDropsEarlierSignIn(heldStatus: 500)
    }

    private func assertViewModelDropsEarlierSignIn(heldStatus: Int) async throws {
        let fixture = try AuthLifecycleFixture(holdFirstLogin: true, heldLoginStatus: heldStatus)
        let oldCompletion = expectation(description: "Old real SDK sign-in result returned")
        var signInCalls = 0
        let service = SupabaseAuthService(provider: fixture.provider, googleSignIn: { client, _ in
            signInCalls += 1
            let isOld = signInCalls == 1
            defer { if isOld { oldCompletion.fulfill() } }
            return try await client.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: "synthetic-native-login"))
        })
        try await service.signOut()
        let viewModel = SupabaseAuthViewModel(authService: service)
        viewModel.signInWithGoogle()
        await fulfillment(of: [fixture.transport.loginStarted], timeout: 3)
        try await service.signOut()
        _ = try await service.signInWithGoogle()
        viewModel.refreshCurrentSessionSnapshot()
        XCTAssertEqual(viewModel.sessionInfo?.email, fixture.newLogin.user.email)
        let staleState = expectation(description: "Retired result must not publish a new VM state")
        staleState.isInverted = true
        let observation = viewModel.$state.dropFirst().sink { state in
            if state != .signedIn { staleState.fulfill() }
        }
        defer { observation.cancel() }
        fixture.transport.releaseLogin()
        await fulfillment(of: [oldCompletion], timeout: 3)
        // Inverted publication observation also lets the queued MainActor
        // consumer execute; the HTTP race itself is controlled by the transport.
        await fulfillment(of: [staleState], timeout: 0.2)
        XCTAssertTrue(viewModel.isSignedIn)
        XCTAssertEqual(viewModel.sessionInfo?.email, fixture.newLogin.user.email)
        XCTAssertEqual(fixture.makeIndependentSDKClient().auth.currentSession?.accessToken, fixture.newLogin.accessToken)
    }

    func testLogoutHTTPFailureStillRetiresRefreshAndClearsPersistedSession() async throws {
        let fixture = try AuthLifecycleFixture(logoutStatus: 500)
        let oldClient = fixture.provider.client
        let refresh = Task { try await oldClient.auth.refreshSession() }
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        let service = SupabaseAuthService(provider: fixture.provider)
        do { try await service.signOut(); XCTFail("Remote logout failure must be reported") }
        catch let failure as SupabaseAuthOperationFailure {
            XCTAssertEqual(failure.generation, service.authGeneration)
            XCTAssertNotEqual(failure.error, .oauthCancelled)
        }
        fixture.transport.releaseRefresh()
        _ = try await refresh.value
        XCTAssertNil(service.currentSession)
        XCTAssertNil(fixture.makeIndependentSDKClient().auth.currentSession)
        XCTAssertFalse(fixture.transport.logoutScopes.isEmpty)
        XCTAssertTrue(fixture.transport.logoutScopes.allSatisfy { $0 == "local" },
            "SDK HTTP retries must retain the local sign-out scope")
    }

    func testCancelledLogoutStillRetiresRefreshAndClearsPersistentSession() async throws {
        let fixture = try AuthLifecycleFixture(holdLogout: true)
        let oldClient = fixture.provider.client
        let refresh = Task { try await oldClient.auth.refreshSession() }
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        let service = SupabaseAuthService(provider: fixture.provider)
        let logout = Task { try await service.signOut() }
        await fulfillment(of: [fixture.transport.logoutStarted], timeout: 3)
        logout.cancel()
        do { _ = try await logout.value; XCTFail("Cancelled logout reports its cancellation") }
        catch is SupabaseAuthOperationFailure { }
        fixture.transport.releaseRefresh()
        _ = try await refresh.value
        XCTAssertNil(service.currentSession)
        XCTAssertNil(fixture.makeIndependentSDKClient().auth.currentSession)
    }

    func testLogoutStorageRemovalFailureCannotClaimSuccessOrPublishOldSession() async throws {
        let fixture = try AuthLifecycleFixture()
        let service = SupabaseAuthService(provider: fixture.provider)
        fixture.storage.failRemoval(key: fixture.storageKey)
        do { try await service.signOut(); XCTFail("SDK-swallowed deletion error must be reported") }
        catch let failure as SupabaseAuthOperationFailure {
            XCTAssertEqual(failure.generation, service.authGeneration)
        }
        XCTAssertNil(service.currentSession, "Failed deletion is blocked in this process")
        XCTAssertFalse(service.acceptsAuthGeneration(service.authGeneration))
        XCTAssertNotNil(fixture.makeIndependentSDKClient().auth.currentSession,
            "Actual deletion failed: this test must not claim a completed restart-safe logout")
        fixture.storage.failRemoval(key: nil)
        _ = try await fixture.makeNativeSignInService().signInWithGoogle()
        XCTAssertEqual(fixture.makeIndependentSDKClient().auth.currentSession?.accessToken, fixture.newLogin.accessToken)
    }

    func testNoOpLegacyRemovalCannotPassEmptySessionVerification() async throws {
        let fixture = try AuthLifecycleFixture()
        try fixture.storage.store(key: "supabase.session", value: JSONEncoder().encode(fixture.original))
        fixture.storage.ignoreRemoval(key: "supabase.session")
        let service = SupabaseAuthService(provider: fixture.provider)
        do { try await service.signOut(); XCTFail("Retained SDK migration alias must fail logout") }
        catch is SupabaseAuthOperationFailure { }
        XCTAssertNil(service.currentSession)
        XCTAssertFalse(service.acceptsAuthGeneration(service.authGeneration))
        XCTAssertNotNil(try fixture.storage.retrieve(key: "supabase.session"))
        fixture.storage.ignoreRemoval(key: nil)
        _ = try await fixture.makeNativeSignInService().signInWithGoogle()
        XCTAssertNil(try fixture.storage.retrieve(key: "supabase.session"))
        XCTAssertEqual(fixture.makeIndependentSDKClient().auth.currentSession?.accessToken, fixture.newLogin.accessToken)
    }

    func testRetiredSDKCannotWriteOrRemoveCurrentPKCEVerifier() async throws {
        let fixture = try AuthLifecycleFixture()
        let oldClient = fixture.provider.client
        _ = try oldClient.auth.getOAuthSignInURL(provider: .google)
        XCTAssertNotNil(try fixture.storage.retrieve(key: "\(fixture.storageKey)-code-verifier"))
        try await SupabaseAuthService(provider: fixture.provider).signOut()
        XCTAssertNil(try fixture.storage.retrieve(key: "\(fixture.storageKey)-code-verifier"))
        _ = try fixture.provider.client.auth.getOAuthSignInURL(provider: .google)
        let currentVerifier = try XCTUnwrap(fixture.storage.retrieve(key: "\(fixture.storageKey)-code-verifier"))
        _ = try oldClient.auth.getOAuthSignInURL(provider: .google)
        do { _ = try await oldClient.auth.exchangeCodeForSession(authCode: "synthetic-retired-code"); XCTFail("Retired verifier is inaccessible") }
        catch { }
        XCTAssertEqual(try fixture.storage.retrieve(key: "\(fixture.storageKey)-code-verifier"), currentVerifier)
    }

    func testFailedSessionStoreCannotPublishSuccessfulLogin() async throws {
        let fixture = try AuthLifecycleFixture()
        try await SupabaseAuthService(provider: fixture.provider).signOut()
        fixture.storage.failStore(key: fixture.storageKey)
        let service = fixture.makeNativeSignInService()
        do { _ = try await service.signInWithGoogle(); XCTFail("SDK store failure is not a persisted login") }
        catch let failure as SupabaseAuthOperationFailure {
            XCTAssertEqual(failure.error, .unknown(message: "Local session persistence failed"))
        }
        XCTAssertNil(service.currentSession)
        XCTAssertNil(fixture.makeIndependentSDKClient().auth.currentSession)
    }

    func testOrdinaryRefreshHTTPFailurePreservesCurrentStoredSession() async throws {
        let fixture = try AuthLifecycleFixture(refreshStatus: 500)
        let service = SupabaseAuthService(provider: fixture.provider)
        let generation = service.authGeneration
        let refresh = Task { try await fixture.provider.client.auth.refreshSession() }
        await fulfillment(of: [fixture.transport.refreshStarted], timeout: 3)
        fixture.transport.releaseRefresh()
        do { _ = try await refresh.value; XCTFail("SDK refresh failure is surfaced") }
        catch { }
        XCTAssertEqual(service.authGeneration, generation)
        XCTAssertEqual(service.currentSession?.email, fixture.original.user.email)
        XCTAssertEqual(fixture.makeIndependentSDKClient().auth.currentSession?.accessToken, fixture.original.accessToken)
    }

}

@MainActor
private final class AuthLifecycleFixture {
    let config: SupabaseConfig
    let storage = AuthLifecycleMemoryStorage()
    let registry = SupabaseAuthClientRegistry()
    let storageKey: String
    let original: Session
    let transport: AuthLifecycleTransport
    let session: URLSession
    let provider: SupabaseClientProvider
    let refreshed: Session
    let newLogin: Session

    init(sameUserForNewLogin: Bool = false, holdFirstLogin: Bool = false,
         logoutStatus: Int = 204, holdLogout: Bool = false, refreshStatus: Int = 200,
         expiredOriginal: Bool = false, heldLoginStatus: Int = 200) throws {
        let host = "auth-\(UUID().uuidString.lowercased()).example.invalid"
        config = SupabaseConfig(projectURL: URL(string: "https://\(host)")!, publishableKey: "synthetic-publishable", productImageAPIBaseURL: nil)
        original = Self.session(userID: "11111111-2222-4333-8444-555555555555", suffix: "original", expired: expiredOriginal)
        refreshed = Self.session(userID: "11111111-2222-4333-8444-555555555555", suffix: "old-refresh")
        newLogin = Self.session(userID: sameUserForNewLogin ? "11111111-2222-4333-8444-555555555555" : "66666666-7777-4888-8999-000000000000", suffix: "new-login")
        storageKey = "sb-\(host.split(separator: ".")[0])-auth-token"
        try storage.store(key: storageKey, value: JSONEncoder().encode(original))
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase; encoder.dateEncodingStrategy = .iso8601
        transport = AuthLifecycleTransport(refreshed: try encoder.encode(refreshed), newLogin: try encoder.encode(newLogin),
            oldLogin: try encoder.encode(Self.session(userID: "11111111-2222-4333-8444-555555555555", suffix: "old-sign-in")),
            holdFirstLogin: holdFirstLogin, logoutStatus: logoutStatus, holdLogout: holdLogout, refreshStatus: refreshStatus, heldLoginStatus: heldLoginStatus)
        AuthLifecycleURLProtocol.registry.register(host: host, transport: transport)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthLifecycleURLProtocol.self]
        session = URLSession(configuration: configuration)
        provider = SupabaseClientProvider(config: config, authStorage: storage, session: session, autoRefreshToken: false, authRegistry: registry)
    }

    func makeProvider() -> SupabaseClientProvider {
        SupabaseClientProvider(config: config, authStorage: storage, session: session, autoRefreshToken: false, authRegistry: registry)
    }

    func makeIndependentSDKClient() -> SupabaseClient {
        SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.publishableKey, options: .init(auth: .init(storage: storage, autoRefreshToken: false, emitLocalSessionAsInitialSession: true), global: .init(session: session)))
    }

    func makeNativeSignInService() -> SupabaseAuthService {
        SupabaseAuthService(provider: provider, googleSignIn: { client, _ in
            try await client.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: "synthetic-native-login"))
        })
    }

    private static func session(userID: String, suffix: String, expired: Bool = false) -> Session {
        let user = User(id: UUID(uuidString: userID)!, appMetadata: [:], userMetadata: [:], aud: "authenticated", email: "\(suffix)@example.invalid", createdAt: Date(timeIntervalSince1970: 1_700_000_000), updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        return Session(accessToken: "synthetic-access-\(suffix)", tokenType: "bearer", expiresIn: 3600, expiresAt: Date().timeIntervalSince1970 + (expired ? -60 : 3600), refreshToken: "synthetic-refresh-\(suffix)", user: user)
    }
}

nonisolated private final class AuthLifecycleMemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    private var removalFailureKey: String?
    private var ignoredRemovalKey: String?
    private var storeFailureKey: String?
    func failRemoval(key: String?) { lock.withLock { removalFailureKey = key } }
    func ignoreRemoval(key: String?) { lock.withLock { ignoredRemovalKey = key } }
    func failStore(key: String?) { lock.withLock { storeFailureKey = key } }
    func store(key: String, value: Data) throws {
        try lock.withLock {
            if storeFailureKey == key { throw CocoaError(.fileWriteUnknown) }
            values[key] = value
        }
    }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws {
        try lock.withLock {
            if removalFailureKey == key { throw CocoaError(.fileWriteNoPermission) }
            if ignoredRemovalKey != key { _ = values.removeValue(forKey: key) }
        }
    }
}

nonisolated private final class AuthLifecycleTransport: @unchecked Sendable {
    let deviceStatusStarted = XCTestExpectation(description: "Real device status RPC held")
    let refreshStarted = XCTestExpectation(description: "Real SDK refresh HTTP started")
    let secondRefreshStarted = XCTestExpectation(description: "Replacement SDK refresh HTTP started")
    let loginStarted = XCTestExpectation(description: "Real SDK sign-in HTTP started")
    let logoutStarted = XCTestExpectation(description: "Real SDK logout HTTP started")
    private let lock = NSLock()
    private var pendingRefresh: [Int: AuthLifecycleURLProtocol] = [:]
    private var refreshCount = 0
    private var pendingLogin: AuthLifecycleURLProtocol?
    private var loginCount = 0
    private var observedLogoutScopes: [String] = []
    private var heldDeviceStatus: AuthLifecycleURLProtocol?
    private var heldDeviceStatusActive = true
    private var nextDeviceStatusHold: (active: Bool, entered: XCTestExpectation)?
    private var deviceStatusCount = 0
    var deviceStatusRequestCount: Int { lock.withLock { deviceStatusCount } }
    private let refreshed: Data
    private let newLogin: Data
    private let oldLogin: Data
    private let holdFirstLogin: Bool
    private let logoutStatus: Int
    private let holdLogout: Bool
    private let refreshStatus: Int
    private let heldLoginStatus: Int
    var refreshRequestCount: Int { lock.withLock { refreshCount } }
    var logoutScopes: [String] { lock.withLock { observedLogoutScopes } }
    init(refreshed: Data, newLogin: Data, oldLogin: Data, holdFirstLogin: Bool,
         logoutStatus: Int, holdLogout: Bool, refreshStatus: Int, heldLoginStatus: Int) {
        self.refreshed = refreshed; self.newLogin = newLogin; self.oldLogin = oldLogin
        self.holdFirstLogin = holdFirstLogin; self.logoutStatus = logoutStatus
        self.holdLogout = holdLogout; self.refreshStatus = refreshStatus; self.heldLoginStatus = heldLoginStatus
    }
    func start(_ request: AuthLifecycleURLProtocol) {
        guard let url = request.request.url else { return }
        if url.lastPathComponent == "token" && url.query?.contains("refresh_token") == true {
            let index = lock.withLock {
                let index = refreshCount
                refreshCount += 1
                pendingRefresh[index] = request
                return index
            }
            if index == 0 { refreshStarted.fulfill() }
            if index == 1 { secondRefreshStarted.fulfill() }
            if index > 0 && refreshStatus >= 400 {
                lock.withLock { _ = pendingRefresh.removeValue(forKey: index) }
                request.respond(status: refreshStatus, data: responseData(status: refreshStatus, success: refreshed))
            }
        } else if url.lastPathComponent == "token" && url.query?.contains("id_token") == true {
            let shouldHold = lock.withLock {
                loginCount += 1
                if holdFirstLogin && loginCount == 1 { pendingLogin = request; return true }
                return false
            }
            if shouldHold { loginStarted.fulfill() }
            else { request.respond(status: 200, data: newLogin) }
        } else if url.lastPathComponent == "logout" {
            let scope = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "scope" }?.value ?? "missing"
            lock.withLock { observedLogoutScopes.append(scope) }
            logoutStarted.fulfill()
            if !holdLogout { request.respond(status: logoutStatus, data: responseData(status: logoutStatus, success: Data())) }
        } else if url.lastPathComponent == "shop_device_status_for_shop" {
            let (index, extraHold) = lock.withLock { () -> (Int, XCTestExpectation?) in
                let index = deviceStatusCount
                deviceStatusCount += 1
                if index == 0 { heldDeviceStatus = request; heldDeviceStatusActive = true }
                else if let extra = nextDeviceStatusHold {
                    heldDeviceStatus = request; heldDeviceStatusActive = extra.active
                    nextDeviceStatusHold = nil
                    return (index, extra.entered)
                }
                return (index, nil)
            }
            if index == 0 { deviceStatusStarted.fulfill() }
            else if let extraHold { extraHold.fulfill() }
            else { request.respond(status: 200, data: deviceStatusData(active: index > 1)) }
        } else {
            request.client?.urlProtocol(request, didFailWithError: URLError(.unsupportedURL))
        }
    }
    func releaseRefresh(index: Int = 0) {
        let request = lock.withLock { pendingRefresh.removeValue(forKey: index) }
        request?.respond(status: refreshStatus, data: responseData(status: refreshStatus, success: refreshed))
    }
    func releaseLogin() {
        let request = lock.withLock { let value = pendingLogin; pendingLogin = nil; return value }
        request?.respond(status: heldLoginStatus, data: responseData(status: heldLoginStatus, success: oldLogin))
    }
    func holdNextDeviceStatus(active: Bool, entered: XCTestExpectation) {
        lock.withLock { nextDeviceStatusHold = (active, entered) }
    }
    func releaseDeviceStatus() {
        let (request, active) = lock.withLock { let value = heldDeviceStatus; heldDeviceStatus = nil; return (value, heldDeviceStatusActive) }
        request?.respond(status: 200, data: deviceStatusData(active: active))
    }
    private func deviceStatusData(active: Bool) -> Data {
        Data((active ? #"{"ok":true,"status":"active","code":"active","can_write":true}"#
                    : #"{"ok":false,"status":"revoked","code":"revoked","can_write":false}"#).utf8)
    }
    private func responseData(status: Int, success: Data) -> Data {
        status < 400 ? success : Data(#"{"code":"synthetic_test_error","message":"synthetic controlled error"}"#.utf8)
    }
}

nonisolated private final class AuthLifecycleRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var transports: [String: AuthLifecycleTransport] = [:]
    func register(host: String, transport: AuthLifecycleTransport) { lock.withLock { transports[host] = transport } }
    func transport(host: String) -> AuthLifecycleTransport? { lock.withLock { transports[host] } }
}

nonisolated private final class AuthLifecycleURLProtocol: URLProtocol, @unchecked Sendable {
    static let registry = AuthLifecycleRegistry()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let host = request.url?.host, let transport = Self.registry.transport(host: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        transport.start(self)
    }
    override func stopLoading() {}
    func respond(status: Int, data: Data) {
        guard let url = request.url else { return }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

nonisolated private final class DeviceAuthorizationPublicationObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Bool] = []
    func record(_ value: Bool) { lock.withLock { recorded.append(value) } }
    var values: [Bool] { lock.withLock { recorded } }
}
