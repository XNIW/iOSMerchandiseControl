# CLI Architecture

Status: PASS.

Canonical entrypoint:
- `tools/agent/mc-agent.sh`

Modules:
- `lib/common.sh`: dispatcher helpers, config, prefix validation, locks, scans, report/list/config commands.
- `lib/report.sh`: atomic `.log/.md/.json` report writer, JSON schema `1.1`.
- `lib/redact.sh`: JWT/token/email/path/device/URL redaction.
- `lib/ios.sh`: xcodebuild/XCTest/smoke/live wrappers.
- `lib/android.sh`: Gradle/ADB/offline L1/L2/L3 wrappers.
- `lib/supabase.sh`: status/verify/residue/cleanup/profile wrappers.

Command contract:
- `help-json` and `list commands-json` are valid JSON.
- Wrapped commands produce concise final output: `RESULT`, `EXIT_CODE`, `REPORT_MD`, `REPORT_JSON`, `NEXT_ACTION`.
- `--quiet` suppresses final console output.
- `--verbose` prints only a short tail while preserving full redacted log in evidence.

Professional review update — 2026-05-21:
- PASS: run IDs now include the shell pid suffix to avoid same-second collisions for identical commands.
- PASS: iOS xcodebuild invocations now use a dedicated stale-aware lock so parallel review runs return BLOCKED instead of failing on Xcode `build.db`.
- PASS: live/cleanup locks now handle dead/stale owners and keep a clear pid/timestamp next action.
- PASS: `report validate-json --path <agent-runs-dir>` validates all top-level report JSON files in one call.
- PASS: `scan repo-diff` scans both iOS TASK-113 changes and Android TASK-113 test source changes.
