# TASK-123 Bottleneck Analysis

- Android test read-back initially excluded TASK123 single barcodes; fixed fixture scope.
- iOS XCTest result bundle was reused across iterations; fixed runner cleanup before each test-without-building.
- Android target app was not foreground after instrumentation; fixed harness to foreground Android before iOS->Android receive legs.
- Burst duplicate check initially used global target product delta; fixed to use scoped remote product count per direction.
