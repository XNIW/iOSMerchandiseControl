# 02 - Supabase Preflight

## Setup

| Item | Value |
|------|-------|
| Supabase CLI | `2.98.2` |
| project ref | redacted |
| project hash | `42a5d0119a30` |
| owner hash iOS | `ad3d747e936c` |
| owner hash Android | `ad3d747e936c` |
| client key class | publishable keys present, values redacted |
| schema source | local Supabase migrations path redacted |

## Steps

1. Read iOS and Android Supabase config locally and compare project hash.
2. Confirm no client key contains a server-only marker.
3. Verify authenticated session and owner hash on both physical devices before writes.
4. Inspect schema/migrations read-only for inventory tables and ProductPrice behavior.

## Expected

Same project, same owner, no service-role client, no raw auth data in evidence.

## Observed

- iOS and Android project hash matched: `42a5d0119a30`.
- iOS auth preflight printed `TASK103_IOS_AUTH_PREFLIGHT project_hash=42a5d0119a30 owner_hash=ad3d747e936c provider=google signed_in=true`.
- Android auth preflight printed `TASK103_ANDROID_AUTH_PREFLIGHT project_hash=42a5d0119a30 owner_hash=ad3d747e936c signed_in=true`.
- Local migrations include owner-scoped inventory catalog/ProductPrice tables.
- TASK-038 migration revokes authenticated DELETE on inventory tables; final cleanup therefore used a linked, scoped SQL cleanup with explicit prefix filtering, documented in `11-cleanup.md`.

## Result

`PASS` for CA-103-03 and supporting evidence for CA-103-16.

## Notes/Redactions

No API key, URL value, email, JWT, refresh token or owner UUID raw is recorded.
