# Logging Privacy Audit

## iOS Changes

- `SyncEventOutboxPrivacySanitizer` now redacts:
  - token/JWT/auth key-value shapes,
  - all HTTP(S) URLs,
  - email addresses,
  - UUIDs,
  - long numeric business identifiers.
- `SupabaseInventoryServiceError.sanitizedDiagnosticDetail` now delegates to the shared sanitizer.
- Full import, backfill, history deletion/export and JSON fault logs are DEBUG-only or generalized.
- Options account status no longer shows full owner UUID/email.
- Manual-push plan fingerprints are no longer persisted verbatim in outbox/sync `client_event_id`; non-empty fingerprints are SHA-256 hashed before identifier derivation.

## Remaining Runtime Logs

- DEBUG smoke/task logs still exist by design for developer-only paths and use privacy-safe summaries where reviewed.
- Android auth activation log no longer prints raw `userId`; F101-05 is closed.

## Verification

Targeted XCTest passed for sanitizer, auth privacy display and hashed plan-derived sync identifiers. Final full XCTest rerun passed in review on iOS 26.5: 640 passed, 12 skipped, 0 failed. Release build passed. Android unit/lint/debug/release build checks passed after the log fix.
