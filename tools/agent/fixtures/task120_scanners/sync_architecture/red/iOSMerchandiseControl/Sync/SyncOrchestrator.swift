final class SyncOrchestrator {
    func retryAfterBusy() async {
        recordRuntimeDiagnostic("foreground.outcome", "retry_after_sync_busy")
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
}
