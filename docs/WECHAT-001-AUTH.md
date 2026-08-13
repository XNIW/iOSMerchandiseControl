# WECHAT-001 iOS personal-account adapter

WeChat is a feature-gated personal identity provider. `SupabaseAuthService` remains the only Supabase-session owner; `WeChatAuthCoordinator` obtains a temporary code through an adapter, exchanges it only through the canonical Admin Web gateway, and imports the returned session with the official Supabase Swift `setSession(accessToken:refreshToken:)` API. Local sign-out remains `.local` and does not revoke other platform sessions.

Public inputs are `WECHAT_AUTH_IOS_ENABLED`, `WECHAT_IOS_APP_ID`, and `WECHAT_AUTH_GATEWAY_BASE_URL`. The flag is OFF by default. AppSecret, `session_key`, OpenID, bridge secret and Supabase service role are forbidden in Info.plist/bundle. HTTPS, no redirects, 8-second timeouts, bounded response size, one-time state, nonce, callback expiry/duplicate checks and sanitized localized errors are implemented.

The checked-in provider is intentionally `UnconfiguredWeChatAuthorizationCodeProvider`, so the UI stays hidden. Activation requires official OpenSDK provenance/version/licence validation, approved AppID, bundle `com.niwcyber.iOSMerchandiseControl`, verified Universal Link/URL scheme/Associated Domains and current callback requirements. No binary, entitlement or URL scheme was invented without official evidence.

App Store Review Guideline 4.8 result: `APP_REVIEW_DECISION_REQUIRED`. The product/account eligibility and equivalent-login requirement need owner/legal/reviewer evidence; Sign in with Apple was not added automatically.

Live login, WeChat-not-installed, cold-start callback, same cross-platform identity and account-linking tests are not claimed until external activation is complete.
