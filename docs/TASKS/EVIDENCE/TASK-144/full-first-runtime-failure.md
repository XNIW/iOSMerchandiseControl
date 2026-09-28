# First canonical full runtime failure

`full-final.xcresult`: 1353 PASS / 1 FAIL / 36 SKIP; total1390. The failed case is `SupabaseProductPriceApplyServiceTests/testPagedFullPullAppliesLargeProductPriceHistoryWithoutFixedTotalLimit()`, terminated by signal TERM during the second/no-op pass of 30000 rows. No assertion failure was reported.

A prior Xcode runner PID32644, identified by `/tmp/mc-task144-ios/canonical-focused-ui.log`, requested shutdown of the dedicated simulator at14:51:15 while full PID38470 was running. That earlier UI slice had failed automation and its diagnostic cleanup remained active. The full runner resumed the remaining cases in a new app process at14:53:57; it did not retry the terminated test. The diagnostics collector subsequently timed out at600s. This is a real failed gate, retained; passing test-line counts could not establish full success.

```text
Sep 28 14:51:15 <HOST> com.apple.dt.xcodebuild[32644] <Debug>: Shutdown requested: TASK144 Parity Isolated iPhone 17 (<REDACTED_SIMULATOR_ID>, iOS 27.0, Booted)
Sep 28 14:51:15 <HOST> CoreSimulatorService[1718] <Debug>: Received request for device <REDACTED_SIMULATOR_ID> from peer xcodebuild[32644]: device_shutdown
Sep 28 14:51:15 <HOST> CoreSimulatorService[1718] <Debug>: Shutdown requested: TASK144 Parity Isolated iPhone 17 (<REDACTED_SIMULATOR_ID>, iOS 27.0, Booted)
14:51:15.917 xcodebuild[38470:926002] Lost connection to test process
14:51:15.921 xcodebuild[38470:926002] 📱<DVTiPhoneSimulator (0x773946a600), TASK144 Parity Isolated iPhone 17, unknown class, 27.0 (24A434), <REDACTED_SIMULATOR_ID>> got death notice for pid 38550 (exit code: (null), signal: 15), removing from SimulatorSessionMap
```

The unchanged failing case is rerun in isolation, followed by the entire suite on final source with no concurrent Xcode runner/build. `-collect-test-diagnostics never` disables only post-failure sysdiagnose, preserving failure reporting and assertions. No timeout/skip/test behavior is weakened.
