# TASK-108 Evidence 33 — iOS Unified Sync Live/Simulator Smoke

Date: 2026-05-13 23:45 -0400

Device/simulator:
- iOS simulator: `iPhone 15 Pro Max`, iOS 26.1, `459C668B-7CE8-443B-BAB3-7D3D5FFC9143`, booted.
- Physical iPhone: paired/detected earlier in TASK-108, not used in this pass.

What ran:
- Debug build/run via XcodeBuildMCP: PASS.
- Root banner smoke: PASS.
- Options progress smoke: PASS.
- Options `Sync now` copy after review/bootstrap state: PASS.
- Scroll during cloud count fetch: PASS.

Observed UI:
- Root banner no longer only says that cloud updates are ready; while work is active it shows the active phase (`Checking for updates...`, `Fetching cloud counts...`).
- Options card shows active progress and allows local work while the cloud check runs.
- After review-ready state, the public action is `Sync now`, not `Download cloud database`.
- Screenshot: `screenshots/2026-05-13-ios-root-progress-checking.jpg`.
- Screenshot: `screenshots/2026-05-13-ios-options-progress-scroll.jpg`.
- Screenshot: `screenshots/2026-05-13-ios-options-sync-now.jpg`.

Live app-auth:
- NOT RUN in this pass. The simulator was not in an authenticated app session; no service-role key, token injection, or RLS bypass was used.
- Earlier TASK-108 evidence contains partial authenticated large ProductPrice evidence, but this pass does not upgrade it to PASS.

Acceptance status:
- ✅ BUILD — Debug build/run simulator passed.
- ✅ SIM — banner and Options progress visible.
- ✅ SIM — scroll remained responsive during cloud count fetch.
- ✅ STATIC/UNIT — sync path now includes catalog apply, ProductPrice paged apply and History/session push/pull in one orchestrated local-apply flow.
- ❌ NOT RUN — live bootstrap/full pull with valid baseline after this pass.
- ❌ NOT RUN — live Database/Generated/History push/read-back.
- ❌ NOT RUN — physical iOS smoke.

Post-TASK-108 targeted FIX update 2026-05-14 00:38 -0400:

Additional live app-auth run:
- iOS simulator was signed in with a masked app-auth account; no raw email/token/JWT was recorded.
- Public Options `Sincronizza ora` was used; no History-specific Send/Download path was needed or available.
- Review before apply correctly showed local pending work after the dirty-History snapshot fix.

Observed local results after the run:
- Products: 19,886.
- Suppliers: 81.
- Categories: 49.
- ProductPrice rows: 15,386.
- History entries: 2.
- Dirty History entries: 2.
- Baseline records: 0.

Verdict for this live run:
- ✅ LIVE PARTIAL — public app-auth flow and global `Sync now` were exercised.
- ✅ LIVE PARTIAL — catalog/ProductPrice local data populated.
- ❌ LIVE FAIL/BLOCKED — baseline commit/valid state was not achieved.
- ❌ LIVE FAIL/BLOCKED — History/session did not clear dirty local entries or produce confirmed remote read-back.
- ❌ NOT RUN — controlled push/pull with `TASK108_SYNC_*` rows and cleanup.
