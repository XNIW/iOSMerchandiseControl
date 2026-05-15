# TASK-110 final cross-platform completion — 02 iOS auth logout/login/re-login

Data: 2026-05-15  
Platform: iOS Simulator `iPhone 15 Pro Max`, iOS 26.1, UDID `459C668B-7CE8-443B-BAB3-7D3D5FFC9143`  
Build tool: XcodeBuildMCP  
Verdict: **PASS** su simulatore. Physical iPhone: **NON ESEGUIBILE** in questo pass perché `xctrace` lo lista offline.

## Build / launch

Defaults XcodeBuildMCP:

```text
projectPath=/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControl.xcodeproj
scheme=iOSMerchandiseControl
configuration=Debug
simulatorId=459C668B-7CE8-443B-BAB3-7D3D5FFC9143
bundleId=com.niwcyber.iOSMerchandiseControl
```

Build/run:

```text
build_run_sim CODE_SIGNING_ALLOWED=NO
status=SUCCEEDED
warnings=0
bundleId=com.niwcyber.iOSMerchandiseControl
```

Artifacts:

- build log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/build_run_sim_2026-05-15T19-38-16-882Z_pid40283_bffb79f1.log`
- runtime log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/com.niwcyber.iOSMerchandiseControl_2026-05-15T19-38-22-519Z_helperpid44137_ownerpid40283_5a227d66.log`
- post-restore runtime log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/com.niwcyber.iOSMerchandiseControl_2026-05-15T19-40-41-895Z_helperpid44578_ownerpid40283_4adc6c99.log`

## Steps executed

1. Launched app on simulator.
2. Opened Options tab.
3. Verified initial signed-in state:
   - UI: `Cloud account connected, Signed in as x***@gmail.com.`
   - `Sync now` enabled.
   - local counts visible: products `19695`, suppliers `57`, categories `27`, price history `41109`, history sessions `1`.
4. Tapped `Sign out`.
5. Verified signed-out UI:
   - UI: `Sign in to use the cloud`.
   - UI: `Local database needs a cloud check`.
   - `Sync now` not shown while signed out.
6. Tapped `Sign in`.
7. Confirmed `ASWebAuthenticationSession` prompt (`Continua`) for `supabase.co`.
8. OAuth returned to app without manual password entry.
9. Verified signed-in UI again:
   - UI: `Cloud account connected, Signed in as x***@gmail.com.`
   - auto check started only after auth was stable: `Checking cloud updates...`.
10. Waited for sync/check completion.
11. Verified final auth/sync UI:
   - UI: `No local changes to send`.
   - UI: `Sync completed with notes., history sessions changed: 1`.
   - `Sync now` enabled again.
12. Stopped app with XcodeBuildMCP `stop_app_sim`.
13. Relaunched app with XcodeBuildMCP `launch_app_sim`.
14. Returned to Options and verified restore session:
   - UI: `Cloud account connected, Signed in as x***@gmail.com.`
   - `Sync now` enabled.
   - local counts remain visible/coherent.

## Auth preflight / owner evidence

Targeted XCTest rerun:

```text
test_sim
-only-testing:iOSMerchandiseControlTests/SupabaseConfigSecurityTests/testTask103IOSAuthPreflightWhenEnabled
-parallel-testing-enabled NO
TEST_RUNNER_TASK103_IOS_AUTH_PREFLIGHT=1
```

First attempt hit simulator clone tooling:

```text
Failed to clone device named 'iPhone 15 Pro Max'
```

Retry with `-parallel-testing-enabled NO`: **PASS**, 1 test / 0 failures.

Preflight output:

```text
TASK103_IOS_AUTH_PREFLIGHT project_hash=42a5d0119a30 owner_hash=ad3d747e936c provider=google signed_in=true
```

Interpretazione:

- Supabase session present: **PASS**
- JWT `sub` / owner redacted as owner hash: **PASS**
- provider Google: **PASS**
- same project hash as prior environment parity evidence: **PASS**

## Error scan

Runtime and OS logs searched for:

```text
sessionMissing
callbackFailed
Operation cancelled
operation cancelled
cancelled
42501
permission denied
```

Result: no matches in the iOS runtime/OS logs for this pass.

## Acceptance mapping

| Check | Result | Evidence |
|-------|--------|----------|
| UI shows connected account | ✅ PASS | Options UI `Cloud account connected, Signed in as x***@gmail.com.` |
| Supabase session present | ✅ PASS | targeted auth preflight signed_in=true |
| JWT sub/owner redacted coherent | ✅ PASS | `owner_hash=ad3d747e936c` |
| Logout clears UI state | ✅ PASS | signed-out card and no Sync now |
| Re-login restores account | ✅ PASS | OAuth return + connected card |
| Auto sync/check starts after auth stable | ✅ PASS | `Checking cloud updates...` after connected card |
| Sync completes and re-enables CTA | ✅ PASS | `No local changes to send`, `Sync now` enabled |
| Stop/launch restore session | ✅ PASS | connected card after relaunch |
| No `sessionMissing` | ✅ PASS | log scan no matches |
| No stale `Operation cancelled` | ✅ PASS | UI/log scan no matches |

## Screenshots

- connected Options before logout: `/var/folders/nf/85_c2pqj60v6q0r7v8ktzkpw0000gn/T/screenshot_optimized_d79077dd-527a-4999-97bc-d48751adbe7f.jpg`

## Security

- Email redacted as `x***@gmail.com`.
- No JWT/access token/refresh token/password/anon key/service role key recorded.
