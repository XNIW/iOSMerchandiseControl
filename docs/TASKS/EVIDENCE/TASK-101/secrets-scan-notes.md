# Secrets Scan Notes

## Commands / Scope

- `git ls-files | rg "SupabaseConfig\\.plist|\\.env|GoogleService-Info\\.plist|Secrets|secret|key"`: no tracked secret config file output.
- `git check-ignore -v iOSMerchandiseControl/SupabaseConfig.plist`: confirmed ignored by `.gitignore`.
- `rg` over iOS runtime code for `service_role`, `sb_secret`, JWT-like strings, bearer tokens and email-like strings: only validator/sanitizer code paths.
- `rg` over Android main source for secret/service-role patterns: BuildConfig publishable URL/key references only; no service-role pattern.
- Scan of TASK-101 evidence after final review: no real key/token/email/connection string found. Matches are literal policy/role names and intentionally documented placeholders, not secrets.

## Result

PASS for consumer app source and TASK-101 evidence. No server key, JWT, refresh token, connection string, raw Supabase project URL or full real email was intentionally recorded here.

## Historical Note

Older completed task docs may contain historical account references outside this evidence pack. TASK-101 records this as residual documentation hygiene; DONE task files were not edited under the active tracking rules.
