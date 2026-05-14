# TASK-108 Evidence 24 — Live Bootstrap Pull Smoke

Status: NOT RUN / BLOCKED_APP_AUTH.

Planned:
- Use app-auth session.
- If baseline/local DB absent, tap `Scarica database dal cloud`.
- Verify preview, SwiftData apply, ProductPrice import, baseline write, Database tab refresh, and Options refresh.

Actual:
- App-auth reached Google login but no authenticated session was available.
- Live bootstrap/full pull was not executed.

Evidence:
- Auth blocker documented in `23-app-auth-login-options-smoke.md`.
- Local signed-out Database smoke shows the current simulator database is empty: `screenshots/2026-05-13-database-smoke-empty-after-fix.jpg`.

Supabase data touched:
- None.

## Manual app-auth large-history continuation — 2026-05-13 22:45 -0400

Status: PARTIAL LIVE / NOT PASS.

Executed after the user completed OAuth manually:
- Opened Options with an authenticated app session.
- Ran cloud preview/review for the current remote account.
- Confirmed local apply from the review sheet.

Observed:
- Preview no longer fails as a source error due to large ProductPrice history.
- Preview sample: 1,000 ProductPrice rows.
- Local store after paged apply:
  - Products: 19,886.
  - Suppliers: 79.
  - Categories: 47.
  - ProductPrice: 53,022.
- Local ProductPrice duplicate logical groups: 0.
- Supabase data created/modified/deleted: none.

Not PASS:
- Baseline remained absent after the first live run.
- Baseline writer was fixed afterward to write baseline records in batches and verified by unit test.
- Fresh app-auth rerun after the baseline fix was blocked because OAuth needed human/test-account credentials again.

Evidence:
- `30-large-price-history-bootstrap.md`.
