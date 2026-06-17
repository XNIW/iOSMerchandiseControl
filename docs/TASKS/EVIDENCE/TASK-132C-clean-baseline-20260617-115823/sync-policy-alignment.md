# Sync policy alignment

## Policy verified by code/tests

- iOS automatic decision engine blocks automatic push when bootstrap, recovery, remote events, drift, account decision, or unsafe baseline state is present.
- iOS background refresh now routes through the decision engine before invoking automatic runtime work.
- iOS recovery snapshot pull restores catalog, prices, history, baseline records, and watermark when local store is reset and no pending changes exist.
- Android automatic catalog push blocks non-local triggers through `automatic_push_safety_guard`.
- Android history push on `login_fresh_tick` pulls/bootstraps history but does not upload when there are no real pending history sessions.
- Android bootstrap guard now treats empty product catalog as bootstrap-required even if history/session rows exist.
- Android import analysis remains read-only for missing suppliers/categories; creation is deferred to confirm/apply import.

## Evidence

- iOS policy/recovery/merge regression batch: `raw/ios-task132-policy-recovery-merge-tests-final.log`, exit `0`.
- Android policy/import/merge regression batch: `raw/android-task132-policy-import-merge-tests.log`, exit `0`.
- iOS final build: `raw/ios-debug-simulator-build-final-after-task133-harness.log`, exit `0`.
- Android final build/lint/debug-test assemble: `raw/android-assemble-lint-debugtest-final-after-task133-harness.log`, exit `0`.
- Runtime no-push: `runtime-no-push-after-clean-baseline.md`.

## Runtime gaps not promoted to PASS

- Field-level merge same barcode with concurrent Android `productName` and iOS `retailPrice` was not executed as a strict live two-device fixture.
- Android category + iOS purchasePrice same barcode was not executed as a strict live two-device fixture.
- Price append-only T1/T2 and same-effectiveAt conflict were covered by targeted/unit policy tests, not by the TASK-133 live benchmark.
- Dirty/protected reopen no-push was not executed with an injected unsafe local fixture after cleanup.

Result:
- Baseline cleanup, reset, parity, clean no-push, and policy guard tests are PASS.
- Full TASK-133 field-merge runtime acceptance remains REVIEW_REQUIRED / NOT_DONE until strict live fixtures exist or are run.

