import Foundation
import XCTest
@testable import iOSMerchandiseControl

final class WeChatAuthContractTests: XCTestCase {
    func testProviderSelectionRequiresExplicitValidPublicConfiguration() {
        let disabled = WeChatAuthConfiguration.load(environment: [:])
        XCTAssertFalse(disabled.hasPublicConfiguration)

        let enabled = WeChatAuthConfiguration.load(environment: [
            WeChatAuthConfiguration.enabledKey: "1",
            WeChatAuthConfiguration.appIDKey: "wx1234567890abcdef",
            WeChatAuthConfiguration.gatewayBaseURLKey: "https://staging.example.com"
        ])
        XCTAssertTrue(enabled.hasPublicConfiguration)
        XCTAssertEqual(enabled.gatewayBaseURL?.absoluteString, "https://staging.example.com")

        let insecure = WeChatAuthConfiguration.load(environment: [
            WeChatAuthConfiguration.enabledKey: "1",
            WeChatAuthConfiguration.appIDKey: "wx1234567890abcdef",
            WeChatAuthConfiguration.gatewayBaseURLKey: "http://staging.example.com"
        ])
        XCTAssertFalse(insecure.hasPublicConfiguration)
    }

    func testCallbackSuccessThenDuplicateIsRejected() throws {
        var guardState = WeChatCallbackGuard(
            expectedState: "expected-state",
            expiresAt: Date(timeIntervalSince1970: 200)
        )
        let response = WeChatAuthorizationResponse(
            code: "temporary-code",
            state: "expected-state",
            outcome: .success
        )

        XCTAssertEqual(
            try guardState.consume(response, now: Date(timeIntervalSince1970: 100)),
            "temporary-code"
        )
        XCTAssertThrowsError(
            try guardState.consume(response, now: Date(timeIntervalSince1970: 100))
        ) { error in
            XCTAssertEqual(error as? WeChatAuthError, .callbackDuplicate)
        }
    }

    func testCallbackMismatchAndExpiryFailClosed() {
        var mismatch = WeChatCallbackGuard(
            expectedState: "expected-state",
            expiresAt: Date(timeIntervalSince1970: 200)
        )
        XCTAssertThrowsError(
            try mismatch.consume(
                WeChatAuthorizationResponse(code: "code", state: "wrong-state", outcome: .success),
                now: Date(timeIntervalSince1970: 100)
            )
        ) { error in
            XCTAssertEqual(error as? WeChatAuthError, .stateMismatch)
        }

        var expired = WeChatCallbackGuard(
            expectedState: "expected-state",
            expiresAt: Date(timeIntervalSince1970: 100)
        )
        XCTAssertThrowsError(
            try expired.consume(
                WeChatAuthorizationResponse(code: "code", state: "expected-state", outcome: .success),
                now: Date(timeIntervalSince1970: 100)
            )
        ) { error in
            XCTAssertEqual(error as? WeChatAuthError, .stateExpired)
        }
    }

    func testCancelAndDenyRemainDistinct() {
        for (outcome, expectedError) in [
            (WeChatAuthorizationResponse.Outcome.cancelled, WeChatAuthError.userCancelled),
            (.denied, .userDenied)
        ] {
            var guardState = WeChatCallbackGuard(
                expectedState: "expected-state",
                expiresAt: Date(timeIntervalSince1970: 200)
            )
            XCTAssertThrowsError(
                try guardState.consume(
                    WeChatAuthorizationResponse(code: nil, state: nil, outcome: outcome),
                    now: Date(timeIntervalSince1970: 100)
                )
            ) { error in
                XCTAssertEqual(error as? WeChatAuthError, expectedError)
            }
        }
    }

    func testCoordinatorHandoffSuccess() async throws {
        let configuration = WeChatAuthConfiguration.load(environment: [
            WeChatAuthConfiguration.enabledKey: "1",
            WeChatAuthConfiguration.appIDKey: "wx1234567890abcdef",
            WeChatAuthConfiguration.gatewayBaseURLKey: "https://staging.example.com"
        ])
        let expectedSession = WeChatSupabaseSession(
            accessToken: String(repeating: "a", count: 64),
            expiresAt: 2_000,
            expiresIn: 3_600,
            refreshToken: String(repeating: "r", count: 64),
            tokenType: "bearer",
            user: .init(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                provider: "custom:wechat"
            )
        )
        let coordinator = WeChatAuthCoordinator(
            configuration: configuration,
            codeProvider: EchoWeChatCodeProvider(),
            gateway: EchoWeChatGateway(session: expectedSession),
            now: { Date(timeIntervalSince1970: 100) }
        )

        XCTAssertTrue(coordinator.isConfigured)
        let authenticatedSession = try await coordinator.authenticate()
        XCTAssertEqual(authenticatedSession, expectedSession)
    }

    func testCoordinatorRejectsUnconfiguredProvider() async {
        let configuration = WeChatAuthConfiguration.load(environment: [
            WeChatAuthConfiguration.enabledKey: "1",
            WeChatAuthConfiguration.appIDKey: "wx1234567890abcdef",
            WeChatAuthConfiguration.gatewayBaseURLKey: "https://staging.example.com"
        ])
        let coordinator = WeChatAuthCoordinator(
            configuration: configuration,
            codeProvider: UnconfiguredWeChatAuthorizationCodeProvider(),
            gateway: UnconfiguredWeChatAuthGateway()
        )
        XCTAssertFalse(coordinator.isConfigured)
        do {
            _ = try await coordinator.authenticate()
            XCTFail("Expected fail-closed provider configuration")
        } catch {
            XCTAssertEqual(error as? WeChatAuthError, .providerNotConfigured)
        }
    }

    func testDeviceIdentifierIsStableAndContainsNoCredential() {
        let suiteName = "wechat-device-id-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Unable to create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WeChatDeviceIDStore(defaults: defaults)
        let first = store.getOrCreate()
        XCTAssertEqual(store.getOrCreate(), first)
        XCTAssertEqual(WeChatDeviceIDStore(defaults: defaults).getOrCreate(), first)
    }

    func testNoWeChatSecretNameIsBundledInPublicConfiguration() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let example = try String(
            contentsOf: sourceRoot.appendingPathComponent(
                "iOSMerchandiseControl/SupabaseConfig.example.plist"
            ),
            encoding: .utf8
        )
        XCTAssertFalse(example.contains("WECHAT_IOS_APP_SECRET"))
        XCTAssertFalse(example.contains("WECHAT_MINIPROGRAM_APP_SECRET"))
        XCTAssertFalse(example.contains("session_key"))
    }
}

private struct EchoWeChatCodeProvider: WeChatAuthorizationCodeProviding {
    let isAvailable = true

    func authorize(_ request: WeChatAuthorizationRequest) async throws -> WeChatAuthorizationResponse {
        WeChatAuthorizationResponse(
            code: "temporary-code",
            state: request.state,
            outcome: .success
        )
    }

    func handleOpenURL(_ url: URL) -> Bool {
        url.scheme == "wechat-test"
    }
}

private struct EchoWeChatGateway: WeChatAuthGateway {
    let isConfigured = true
    let session: WeChatSupabaseSession

    func issueChallenge(deviceID: UUID, state: String, nonce: String) async throws -> WeChatChallenge {
        WeChatChallenge(
            correlationID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            expiresInSeconds: 300,
            nonce: nonce,
            state: state
        )
    }

    func exchange(
        challenge: WeChatChallenge,
        code: String,
        deviceID: UUID
    ) async throws -> WeChatSupabaseSession {
        guard code == "temporary-code" else { throw WeChatAuthError.codeMissing }
        return session
    }
}
