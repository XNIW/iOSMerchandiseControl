# TASK-125 Final Review

- Status: `BLOCKED_EXTERNAL`
- Task: `TASK-125`
- Redaction applied: `true`
- Generated: `2026-05-26T00:57:09Z`

TASK-125 is not REVIEW/DONE. Local architecture scanners/build/tests and physical auth preflights passed, but executable contract gates, linked Supabase RLS/grants, full real-device matrices, BG debug/expiration, linked cleanup/residue and final drift are incomplete or blocked.

## Referenced agent runs
- `PASS` — `git head-consistency --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003004Z-git-head-consistency-task-TASK-125-p10318.json`
- `PASS` — `ios build debug --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003534Z-ios-build-debug-task-TASK-125-p21500.json`
- `PASS` — `ios build release --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003559Z-ios-build-release-task-TASK-125-p22139.json`
- `PASS` — `ios test sync --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003802Z-ios-test-sync-task-TASK-125-p24196.json`
- `PASS` — `android build debug --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004056Z-android-build-debug-task-TASK-125-p25553.json`
- `PASS` — `android test sync --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004109Z-android-test-sync-task-TASK-125-p26121.json`
- `PASS` — `supabase verify-schema --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004148Z-supabase-verify-schema-task-TASK-125-profile-linked-p27203.json`
- `BLOCKED_EXTERNAL` — `supabase verify-rls --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004148Z-supabase-verify-rls-task-TASK-125-profile-linked-p27204.json`
- `BLOCKED_EXTERNAL` — `supabase verify-grants --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004148Z-supabase-verify-grants-task-TASK-125-profile-linked-p27211.json`
- `PASS` — `ios device-auth-preflight --live --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004717Z-ios-device-auth-preflight-live-task-TASK-125-p34023.json`
- `PASS` — `android auth-preflight --live --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004810Z-android-auth-preflight-live-task-TASK-125-p34794.json`
- `BLOCKED_EXTERNAL` — `live real-device-realtime --task TASK-125 --prefix TASK125_RT_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005105Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p38862.json`
- `BLOCKED_EXTERNAL` — `live real-device-offline-reconnect --task TASK-125 --prefix TASK125_OFFLINE_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005106Z-live-real-device-offline-reconnect-task-TASK-125-prefix-TASK125_OFFLINE_-p39291.json`
- `BLOCKED_EXTERNAL` — `live real-device-background-sync --task TASK-125 --prefix TASK125_BG_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005107Z-live-real-device-background-sync-task-TASK-125-prefix-TASK125_BG_-p39721.json`
- `BLOCKED_EXTERNAL` — `live real-device-kill-restart-pending --task TASK-125 --prefix TASK125_RESTART_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005108Z-live-real-device-kill-restart-pending-task-TASK-125-prefix-TASK125_RESTART_-p40147.json`
- `BLOCKED_EXTERNAL` — `live real-device-network-flapping --task TASK-125 --prefix TASK125_FLAP_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005056Z-live-real-device-network-flapping-task-TASK-125-prefix-TASK125_FLAP_-p37011.json`
- `PASS` — `supabase cleanup --task TASK-125 --prefix TASK125_ --profile local` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005031Z-supabase-cleanup-task-TASK-125-prefix-TASK125_-profile-local-p35806.json`
- `PASS` — `supabase residue-check --task TASK-125 --prefix TASK125_ --profile local` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005031Z-supabase-residue-check-task-TASK-125-prefix-TASK125_-profile-local-p35807.json`

## Next action
Continue in ACTIVE / FIX: implement executable contract gates and full TASK-125 real-device matrix, resolve linked Supabase pooler/auth, rerun all gates.
