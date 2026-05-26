# TASK-125 Shared Sync Contract Spec

- Status: `PASS`
- Task: `TASK-125`
- Redaction applied: `true`
- Generated: `2026-05-26T15:48:50Z`

Executable contract gate bridge PASS: the contract is backed by repeatable source scanners, iOS/Android unit tests, Supabase linked checks and real-device matrices rather than audit-only prose.

## Checks
- `PASS` — `ios_debug_build` — Latest matching report is PASS.
- `PASS` — `ios_release_build` — Latest matching report is PASS.
- `PASS` — `ios_automatic_architecture_tests` — Latest matching report is PASS.
- `PASS` — `ios_automatic_domain_tests` — Latest matching report is PASS.
- `PASS` — `ios_sync_tests` — Latest matching report is PASS.
- `PASS` — `ios_manual_regression_tests` — Latest matching report is PASS.
- `PASS` — `android_debug_build` — Latest matching report is PASS.
- `PASS` — `android_offline_tests` — Latest matching report is PASS.
- `PASS` — `android_sync_tests` — Latest matching report is PASS.
- `PASS` — `supabase_schema_linked` — Latest matching report is PASS.
- `PASS` — `supabase_rls_linked` — Latest matching report is PASS.
- `PASS` — `supabase_grants_linked` — Latest matching report is PASS.
- `PASS` — `supabase_rpc_linked` — Latest matching report is PASS.
- `PASS` — `supabase_realtime_linked` — Latest matching report is PASS.
- `PASS` — `scan_no_hidden_manual_sync` — Latest matching report is PASS.
- `PASS` — `scan_no_full_pull_normal_path` — Latest matching report is PASS.
- `PASS` — `scan_no_service_role_client` — Latest matching report is PASS.
- `PASS` — `scan_no_rls_bypass` — Latest matching report is PASS.
- `PASS` — `scan_no_mainactor_heavy_sync` — Latest matching report is PASS.
- `PASS` — `scan_remote_adapter_single_domain` — Latest matching report is PASS.
- `PASS` — `scan_background_registration` — Latest matching report is PASS.
- `PASS` — `scan_background_no_ui_context` — Latest matching report is PASS.
- `PASS` — `scan_outbox_restart` — Latest matching report is PASS.
- `PASS` — `scan_evidence_redaction` — Latest matching report is PASS.
- `PASS` — `ios_state_provider` — Source contract marker is present.
- `PASS` — `ios_options_single_status_provider` — Source contract marker is present.
- `PASS` — `ios_orchestrator_has_driver_boundaries` — Source contract marker is present.
- `PASS` — `ios_background_uses_modelcontainer` — Source contract marker is present.
- `PASS` — `ios_background_expiration_handler_implemented` — Source contract marker is present.
- `PASS` — `ios_outbox_idempotency_and_backoff` — Source contract marker is present.
- `PASS` — `ios_productprice_keyset_pipeline` — Source contract marker is present.
- `PASS` — `ios_account_boundary` — Source contract marker is present.
- `PASS` — `ios_sync_event_error_taxonomy` — Source contract marker is present.
- `PASS` — `ios_tombstone_dto_columns` — Source contract marker is present.
- `PASS` — `ios_remote_query_executor_primitive` — Source contract marker is present.
- `PASS` — `android_repository_sync_owner` — Source contract marker is present.
- `PASS` — `android_realtime_resubscribe` — Source contract marker is present.
- `PASS` — `android_room_outbox_tables` — Source contract marker is present.
- `PASS` — `android_tombstone_tables` — Source contract marker is present.
- `PASS` — `android_productprice_targeted_pipeline` — Source contract marker is present.
- `PASS` — `android_productprice_targeted_test` — Source contract marker is present.
- `PASS` — `android_fault_and_recovery_tests` — Source contract marker is present.
- `PASS` — `real-device-realtime-matrix_acceptable` — Runtime top-level evidence is acceptable.
- `PASS` — `offline-reconnect-matrix_acceptable` — Runtime top-level evidence is acceptable.
- `PASS` — `kill-restart-pending_acceptable` — Runtime top-level evidence is acceptable.
- `PASS` — `network-flapping_acceptable` — Runtime top-level evidence is acceptable.
- `PASS` — `final-runtime-parity_acceptable` — Runtime top-level evidence is acceptable.
- `PASS` — `residue-check_acceptable` — Runtime top-level evidence is acceptable.

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

## Next Action
Proceed to Claude review; expand with dedicated new fixtures only if reviewer requests stricter per-invariant granularity.
