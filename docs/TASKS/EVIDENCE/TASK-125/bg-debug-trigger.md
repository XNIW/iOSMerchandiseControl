# TASK-125 iOS BGTask Debug Trigger

- Status: `BLOCKED_EXTERNAL`
- Task: `TASK-125`
- Redaction applied: `true`
- Generated: `2026-05-26T15:48:50Z`

BGTask debug-trigger was attempted through the available harness path, but physical iOS tooling did not provide a deterministic trigger in this run. The app-level fallback contract is covered by foreground/reconnect PASS evidence.

## Checks
- `BLOCKED_EXTERNAL` — `background_debug_trigger_not_available` — BGTask debug-trigger/expiration could not be forced from the available physical-device harness; this is tracked as iOS scheduler/tooling policy for REVIEW, not as PASS.

## References
- `PASS` — `ios build debug --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003534Z-ios-build-debug-task-TASK-125-p21500.json`
- `PASS` — `ios build release --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003559Z-ios-build-release-task-TASK-125-p22139.json`
- `PASS` — `ios test automatic-architecture --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003720Z-ios-test-automatic-architecture-task-TASK-125-p22882.json`
- `PASS` — `ios test automatic-domain --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003751Z-ios-test-automatic-domain-task-TASK-125-p23604.json`
- `PASS` — `ios test sync --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003802Z-ios-test-sync-task-TASK-125-p24196.json`
- `PASS` — `ios test manual-sync-regression --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004040Z-ios-test-manual-sync-regression-task-TASK-125-p24963.json`
- `PASS` — `android build debug --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004056Z-android-build-debug-task-TASK-125-p25553.json`
- `PASS` — `android test offline --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004109Z-android-test-offline-task-TASK-125-p26120.json`
- `PASS` — `android test sync --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004109Z-android-test-sync-task-TASK-125-p26121.json`
- `PASS` — `supabase verify-schema --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T023152Z-supabase-verify-schema-task-TASK-125-profile-linked-p6100.json`
- `PASS` — `supabase verify-rls --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T023443Z-supabase-verify-rls-task-TASK-125-profile-linked-p8443.json`
- `PASS` — `supabase verify-grants --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T023634Z-supabase-verify-grants-task-TASK-125-profile-linked-p9111.json`
- `PASS` — `supabase verify-rpc --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T023649Z-supabase-verify-rpc-task-TASK-125-profile-linked-p9645.json`
- `PASS` — `supabase verify-realtime --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T023949Z-supabase-verify-realtime-task-TASK-125-profile-linked-p10826.json`
- `PASS` — `scan no-hidden-manual-sync --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T053146Z-scan-no-hidden-manual-sync-task-TASK-125-strict-p44443.json`
- `PASS` — `scan no-full-pull-normal-path --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T053146Z-scan-no-full-pull-normal-path-task-TASK-125-strict-p44845.json`
- `PASS` — `scan no-service-role-client --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T053147Z-scan-no-service-role-client-task-TASK-125-strict-p45264.json`
- `PASS` — `scan no-rls-bypass --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T053148Z-scan-no-rls-bypass-task-TASK-125-strict-p45664.json`
- `PASS` — `scan no-mainactor-heavy-sync --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T053149Z-scan-no-mainactor-heavy-sync-task-TASK-125-strict-p46062.json`
- `PASS` — `scan remote-adapter-single-domain --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T053152Z-scan-remote-adapter-single-domain-task-TASK-125-strict-p48057.json`
- `PASS` — `scan background-task-registration --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T053153Z-scan-background-task-registration-task-TASK-125-strict-p48447.json`
- `PASS` — `scan background-task-no-ui-context --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T053153Z-scan-background-task-no-ui-context-task-TASK-125-strict-p48842.json`
- `PASS` — `scan outbox-pending-survives-restart --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T053154Z-scan-outbox-pending-survives-restart-task-TASK-125-strict-p49246.json`
- `PASS` — `scan evidence-redaction --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T053155Z-scan-evidence-redaction-task-TASK-125-strict-p49638.json`
- `BLOCKED_EXTERNAL` — `live real-device-background-sync --task TASK-125 --prefix TASK125_BG_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T152450Z-live-real-device-background-sync-task-TASK-125-prefix-TASK125_BG_-p45423.json`

## Next Action
Collect Xcode debug-trigger evidence on the physical iPhone if the reviewer requires DONE without policy note.
