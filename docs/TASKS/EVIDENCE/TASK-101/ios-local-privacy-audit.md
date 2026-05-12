# iOS Local Privacy Audit

## Static Result

- `Info.plist` declares document import support and Supabase OAuth callback scheme; no camera/location/contacts/photos permissions found.
- No tracked `SupabaseConfig.plist`; local real config is ignored by `.gitignore`.
- `SupabaseConfig.swift` requires HTTPS, rejects placeholders and rejects `sb_secret_`, `secret_key` and legacy JWT `service_role`.
- App code does not persist access/refresh tokens directly; session lifecycle is delegated to Supabase SDK.
- SwiftData stores catalog/history/price data locally. This is functional app data, not evidence data.

## Remediation Applied

- Full account email and full owner UUID no longer display in iOS Options; masked values are used.
- Auth and inventory diagnostic details are passed through privacy sanitizer.
- Import/backfill/history debug prints that could include local context are DEBUG-gated or generalized.

## Residual

- No app-level `PrivacyInfo.xcprivacy` file was found. Treat as release validation item, not a TASK-101 blocker.

