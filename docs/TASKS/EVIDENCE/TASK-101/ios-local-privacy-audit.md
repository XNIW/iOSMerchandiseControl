# iOS Local Privacy Audit

## Static Result

- `Info.plist` declares document import support and Supabase OAuth callback scheme; no camera/location/contacts/photos permissions found.
- No tracked `SupabaseConfig.plist`; local real config is ignored by `.gitignore`.
- `SupabaseConfig.swift` requires HTTPS, rejects placeholders and rejects `sb_secret_`, `secret_key` and legacy JWT `service_role`.
- App code does not persist access/refresh tokens directly; session lifecycle is delegated to Supabase SDK.
- App-level `PrivacyInfo.xcprivacy` now exists and declares UserDefaults required-reason API usage with reason `CA92.1`; no tracking domains and no collected data types are declared.
- SwiftData stores catalog/history/price data locally. This is functional app data, not evidence data.

## Remediation Applied

- Full account email and full owner UUID no longer display in iOS Options; masked values are used.
- Auth and inventory diagnostic details are passed through privacy sanitizer.
- Import/backfill/history debug prints that could include local context are DEBUG-gated or generalized.
- App privacy manifest added and verified with `plutil`; Release simulator app bundle includes the manifest.

## Residual

- No iOS privacy-manifest blocker remains for TASK-101. Final App Store export validation is still a normal release pipeline step.
