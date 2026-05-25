# TASK-124 Final Handoff

Status: `ACTIVE / REVIEW — SIMULATOR_EMULATOR_SCOPE_PASS`

## Scope
- Covered: iOS Simulator, Android Emulator `emulator-5554`, Supabase linked/local checks, same live account session.
- Deferred to TASK-125: physical iPhone, physical Android, locked/background/long-offline real-device behavior.
- Not claimed: DONE, REVIEW PASS, production-ready global, 100% architecture certification, physical-device coverage.

## Implemented
- Added TASK-124 canonical scanners with RED/GREEN fixtures and mc-agent routing.
- Split `ProductPriceRemoteSupabaseAdapter` into automatic, preview, manual push, and release composite adapters.
- Split Options remote count reads out of `SyncEventRemoteSupabaseAdapter` into `OptionsRemoteCountSupabaseAdapter`.
- Renamed misleading transport composition labels where scoped.
- Removed `SupabaseManualSyncAggregatedPushOutboxProducer.swift` and `SyncAutomaticRuntime.swift` compatibility residue after call-site proof.
- Added TASK-124 prefix support to iOS and Android live acceptance fixtures.
- Tightened the TASK-123 no-op live harness so measured no-op latency does not include a fixed one-second artificial wait.

## PASS Gates
- iOS auth-preflight live: PASS `20260525T192259Z-ios-auth-preflight-live-task-TASK-124-p48048`.
- Offline/reconnect simulator/emulator: PASS `20260525T192951Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p59570`.
- TASK-123 speed regression simulator/emulator: PASS for single propagation, no-op, burst-10, and cold-restart.
- Mutation near realtime: PASS `20260525T200943Z-live-mutation-near-realtime-task-TASK-124-prefix-TASK124_RT_SIM_-p49942`.
- Runtime parity: PASS `20260525T201515Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RT_SIM_-profile-linked-p57963`; explicit Android full pull was setup for parity only.
- Supabase cleanup/residue `TASK124_`: dry-run PASS, execute PASS, residue PASS.
- TASK-124 scanners, sensitive, evidence, repo-diff: PASS.
- iOS Debug/Release and iOS sync tests: PASS.
- Android Debug and Android sync tests: PASS.

## Residual Risk
- Physical device validation was not run by explicit user decision and is deferred.
- Real-device locked/background/long-offline behavior is not covered by TASK-124.
- Runtime parity required explicit Android full-pull setup because the emulator local store was scoped/smaller than Supabase/iOS before parity; this is documented as setup, not normal automatic path evidence.
