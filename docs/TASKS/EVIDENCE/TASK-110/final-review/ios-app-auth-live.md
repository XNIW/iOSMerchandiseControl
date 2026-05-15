# TASK-110 iOS app-auth live

Date: 2026-05-15 15:04 -0400

## Result
- ✅ PASS — iOS app-auth `sessionMissing` discrepancy corrected and verified.

## User-visible bug reproduced
- User symptom: after granting login permission, the app repeatedly showed failed/not logged in; after restarting, the app could show the account already signed in.
- Sanitized root cause: OAuth callback had auth code but missing PKCE verifier; global URL handling could race with `ASWebAuthenticationSession`; simulator session storage restore was not deterministic enough for smoke verification.

## Fix verified
- ✅ PASS — OAuth login with authorized account redacted as `x***@gmail.com`.
- ✅ PASS — Options shows cloud account connected after login.
- ✅ PASS — app stop/launch restore keeps cloud account connected.
- ✅ PASS — `Sync now` available after restored session.
- ✅ PASS — local UI counts visible after restore: products `19695`, suppliers `57`, categories `27`, price history `41109`, history sessions `1`.

## Automated check
- ✅ PASS — `SupabaseConfigSecurityTests/testTask103IOSAuthPreflightWhenEnabled` with `TASK103_IOS_AUTH_PREFLIGHT=1`.

## Files changed for auth
- `/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControl/SupabaseAuthViewModel.swift`
- `/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControl/SupabaseClientProvider.swift`

## Privacy
- No full email, JWT, refresh token, access token, anon key, or service role key recorded here.

