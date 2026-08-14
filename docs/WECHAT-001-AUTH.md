# WECHAT-001 iOS personal-account adapter

WeChat is a feature-gated personal identity provider. `SupabaseAuthService` remains the only Supabase-session owner; `WeChatAuthCoordinator` obtains a temporary code through an adapter, exchanges it only through the canonical Admin Web gateway, and imports the returned session with the official Supabase Swift `setSession(accessToken:refreshToken:)` API. Local sign-out remains `.local` and does not revoke other platform sessions.

Public inputs are `WECHAT_AUTH_IOS_ENABLED`, `WECHAT_IOS_APP_ID`, `WECHAT_IOS_UNIVERSAL_LINK`, and `WECHAT_AUTH_GATEWAY_BASE_URL`. They are loaded from process environment first and then the ignored local `SupabaseConfig.plist`; the flag is OFF by default. AppSecret, `session_key`, OpenID, bridge secret and Supabase service role are forbidden in Info.plist/bundle. HTTPS, no redirects, 8-second timeouts, bounded response size, one-time state, nonce, callback expiry/duplicate checks and sanitized localized errors are implemented.

Tencent's official OpenSDK XCFramework `2.0.7` artifact labelled `NoPay` is pinned under `Vendor/WeChat`; the target defines `BUILD_WITHOUT_PAY=1` and the application integrates only login request/response APIs. The main iOS composition uses the real adapter only when all public inputs are valid, the exact AppID URL scheme exists in the bundle, and `WXApi.registerApp` succeeds. URL and Universal Link callbacks are wired for warm and cold launch. Activation still requires an approved AppID, matching AppID URL scheme, verified Universal Link and Associated Domains entitlement for bundle `com.niwcyber.iOSMerchandiseControl`; those external values are not invented or checked in. Until they exist, the UI remains hidden and the feature stays fail-closed.

App Store Review Guideline 4.8 result: `APP_REVIEW_DECISION_REQUIRED`. The product/account eligibility and equivalent-login requirement need owner/legal/reviewer evidence; Sign in with Apple was not added automatically.

Live login, WeChat-not-installed, cold-start callback, same cross-platform identity and account-linking tests are not claimed until external activation is complete.
