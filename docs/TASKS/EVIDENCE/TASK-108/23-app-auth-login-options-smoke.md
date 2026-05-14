# TASK-108 Evidence 23 — App Auth Login / Options Smoke

Status: PARTIAL / BLOCKED_APP_AUTH.

Timestamp: 2026-05-13 20:45 -0400.

Environment:
- iOS simulator: `iPhone 17 Pro` (`AC6FBFC3-A97F-412C-BEC0-F88B9956107B`).
- Build: Debug simulator build/run PASS via XcodeBuildMCP.
- Initial app state: signed out.

Executed:
- Navigated to Options.
- Verified signed-out public surface:
  - visible `Accedi`;
  - local database status visible;
  - Developer diagnostics collapsed;
  - no Manual price history push / Outbox sync_events / Local Supabase baseline / Recent sync events as primary sections.
- Tapped `Accedi`.
- iOS presented ASWebAuthenticationSession consent for the Supabase OAuth domain.
- Tapped `Continua`.
- Google login page opened inside the auth session.

Screenshots:
- Public signed-out Options: `screenshots/2026-05-13-options-after-public-cloud-local.jpg`
- Diagnostics collapsed: `screenshots/2026-05-13-options-after-diagnostics-collapsed.jpg`
- iOS auth consent: `screenshots/2026-05-13-options-signin-system-prompt.jpg`
- Google credential prompt: `screenshots/2026-05-13-options-signin-google-credential-required.jpg`

Result:
- App-auth launch path is real and reaches Google OAuth.
- No authenticated app session was obtained because completing Google login requires human/test-account credentials not available to Codex.

Impact:
- Signed-in Options, Sign out, bootstrap/full pull, incremental pull, Database push, Generated push, and History push live app-auth tests remain NOT RUN.
- No service_role workaround, token injection, or RLS bypass was used.

## Manual app-auth continuation — 2026-05-13 21:35 -0400

Status: EXECUTED / PARTIAL. App-auth preview worked, but full live sync did not pass.

Context:
- The user completed Google OAuth manually in the simulator after the previous blocked prompt.
- Codex preserved the simulator app container and did not erase/reinstall data destructively.

Observed after relaunch:
- Signed-in Options shows masked account (`x***@gmail.com`) and a visible `Esci` action.
- Initial cloud check no longer reports signed-out/auth failure.
- Public cloud card is visually clean: account, cloud status, and CTA are in one card; debug/manual sections are not visible as primary content.

Fixes validated during this continuation:
- SwiftData migration no longer fails after adding defaults for new History sync revision fields.
- App-auth remote preview completed with authenticated Supabase session:
  - `complete=true`
  - `partial=false`
  - `failure=none`
  - remote catalog observed: 19,888 products, 101 suppliers, 64 categories.

Evidence:
- Clean signed-in/review card screenshot: `screenshots/22-options-after-clean-card-review.jpg`.
- Runtime log evidence path: `com.niwcyber.iOSMerchandiseControl_2026-05-14T01-25-44-248Z_helperpid51305_ownerpid92627_5530009f.log`.

Remaining note:
- Auth worked for the manual continuation, and remote preview no longer fails because ProductPrice history is larger than the preview sample.
- Full bootstrap apply is still not PASS because the first live run did not write a valid baseline; the baseline writer was fixed afterward, but app-auth was not available after rebuild to rerun the complete flow.
- See `30-large-price-history-bootstrap.md`.

## Large-history retry — 2026-05-13 22:45 -0400

Status: PARTIAL / BLOCKED_APP_AUTH_FOR_RERUN.

Observed:
- Manual app-auth session was available before rebuild and remote preview succeeded.
- After code rebuild for the batched baseline fix, Options returned to an app-auth attention/signed-out flow and `Sign in` reached the OAuth consent / Google credential path again.
- No token injection, service_role key, or RLS bypass was used to recover the session.

Impact:
- The ProductPrice fixed-cap blocker is resolved in code and partially verified live.
- A fresh authenticated baseline-verification run still requires human/test-account OAuth.
