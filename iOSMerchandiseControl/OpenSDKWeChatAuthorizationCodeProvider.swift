#if os(iOS)
import Foundation
import WebKit

/// Thin login-only adapter over Tencent's official OpenSDK artifact labelled NoPay.
/// The AppSecret and the authorization-code exchange remain server-only.
nonisolated final class OpenSDKWeChatAuthorizationCodeProvider: NSObject,
    WeChatAuthorizationCodeProviding,
    WXApiDelegate,
    @unchecked Sendable {
    private typealias AuthorizationContinuation = CheckedContinuation<
        WeChatAuthorizationResponse,
        any Error
    >
    typealias SendAuthorization = @Sendable (
        _ state: String,
        _ completion: @escaping @Sendable (Bool) -> Void
    ) -> Void

    private let appID: String?
    private let isAppReady: @Sendable () -> Bool
    private let sendAuthorization: SendAuthorization
    private let continuationLock = NSLock()
    private var pendingContinuation: AuthorizationContinuation?
    let isAvailable: Bool

    init(configuration: WeChatAuthConfiguration) {
        appID = configuration.appID
        isAppReady = {
            WXApi.isWXAppInstalled() && WXApi.isWXAppSupport()
        }
        sendAuthorization = { state, completion in
            let authRequest = SendAuthReq()
            authRequest.scope = "snsapi_userinfo"
            authRequest.state = state
            authRequest.nonautomatic = true
            WXApi.send(authRequest, completion: completion)
        }
        if configuration.enabled,
           let appID = configuration.appID,
           let universalLink = configuration.universalLink?.absoluteString,
           Self.hasURLScheme(
               appID,
               in: Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes")
           ) {
            isAvailable = WXApi.registerApp(appID, universalLink: universalLink)
        } else {
            isAvailable = false
        }
        super.init()
    }

    init(
        appID: String,
        isAvailable: Bool,
        isAppReady: @escaping @Sendable () -> Bool,
        sendAuthorization: @escaping SendAuthorization
    ) {
        self.appID = appID
        self.isAvailable = isAvailable
        self.isAppReady = isAppReady
        self.sendAuthorization = sendAuthorization
        super.init()
    }

    func authorize(_ request: WeChatAuthorizationRequest) async throws -> WeChatAuthorizationResponse {
        guard isAvailable, request.appID == appID else {
            throw WeChatAuthError.providerNotConfigured
        }

        return try await withCheckedThrowingContinuation { continuation in
            guard install(continuation) else {
                continuation.resume(throwing: WeChatAuthError.backendTemporary)
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.isAppReady() else {
                    self.finish(.failure(WeChatAuthError.appNotInstalled))
                    return
                }

                self.sendAuthorization(request.state) { [weak self] sent in
                    guard !sent else { return }
                    self?.finish(.failure(WeChatAuthError.backendTemporary))
                }
            }
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        guard isAvailable else { return false }
        return WXApi.handleOpen(url, delegate: self)
    }

    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool {
        guard isAvailable else { return false }
        return WXApi.handleOpenUniversalLink(userActivity, delegate: self)
    }

    func onReq(_ request: BaseReq) {
        // Login is request-only. Incoming WeChat requests are outside this surface.
    }

    func onResp(_ response: BaseResp) {
        guard let authResponse = response as? SendAuthResp else { return }
        do {
            finish(
                .success(
                    try Self.mapResponse(
                        errorCode: Int(authResponse.errCode),
                        code: authResponse.code,
                        state: authResponse.state
                    )
                )
            )
        } catch {
            finish(.failure(error))
        }
    }

    static func mapResponse(
        errorCode: Int,
        code: String?,
        state: String?
    ) throws -> WeChatAuthorizationResponse {
        switch errorCode {
        case 0:
            return WeChatAuthorizationResponse(code: code, state: state, outcome: .success)
        case -2:
            return WeChatAuthorizationResponse(code: nil, state: state, outcome: .cancelled)
        case -4:
            return WeChatAuthorizationResponse(code: nil, state: state, outcome: .denied)
        default:
            throw WeChatAuthError.backendTemporary
        }
    }

    static func hasURLScheme(_ expectedScheme: String, in urlTypes: Any?) -> Bool {
        guard let urlTypes = urlTypes as? [[String: Any]] else { return false }
        return urlTypes.contains { urlType in
            guard let schemes = urlType["CFBundleURLSchemes"] as? [String] else { return false }
            return schemes.contains(expectedScheme)
        }
    }

    private func install(_ continuation: AuthorizationContinuation) -> Bool {
        continuationLock.lock()
        defer { continuationLock.unlock() }
        guard pendingContinuation == nil else { return false }
        pendingContinuation = continuation
        return true
    }

    private func finish(_ result: Result<WeChatAuthorizationResponse, any Error>) {
        continuationLock.lock()
        let continuation = pendingContinuation
        pendingContinuation = nil
        continuationLock.unlock()

        guard let continuation else { return }
        switch result {
        case .success(let response):
            continuation.resume(returning: response)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
#endif
