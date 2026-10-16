import Foundation
import XCTest

/// Native synthetic T20 recorder. The real SwiftData/recovery fixture lives beside
/// the existing private helpers in AtomicGenerationRecoverySnapshotPullServiceTests.
/// Always runs when selected. No network/session/device APIs are called by this recorder.
@MainActor
final class MobileSyncPerformanceRecorder {
    let directory: URL
    private let ledger: URL
    private let clockID = "ios-process-\(UUID().uuidString)"

    init(caseName: String) throws {
        let base = ProcessInfo.processInfo.environment["MOBILE_SYNC_T20_OUTPUT"]
            ?? FileManager.default.temporaryDirectory.path
        guard base.hasPrefix("/") else { throw RecorderError.absoluteOutputRequired }
        directory = URL(fileURLWithPath: base, isDirectory: true)
            .appendingPathComponent("\(caseName)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        ledger = directory.appendingPathComponent("samples.jsonl")
        try Data().write(to: ledger, options: .withoutOverwriting)
    }

    func writeSetup(_ payload: [String: Any]) throws {
        try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("setup.json"), options: .withoutOverwriting)
    }

    /// The operation contains the measured path; verification and flushed evidence are outside it.
    func measure(group: Int, kind: String, condition: String,
                 operation: () async throws -> Void,
                 verify: () throws -> [String: Any],
                 diagnostics: () -> [String: Any] = { [:] }) async throws {
        for index in 1...33 {
            let started = DispatchTime.now().uptimeNanoseconds
            var ended = started
            var observed: [String: Any] = [:]
            var failure: Error?
            do {
                try await operation()
                ended = DispatchTime.now().uptimeNanoseconds
                observed = try verify()
            } catch {
                ended = DispatchTime.now().uptimeNanoseconds
                failure = error
            }
            let beginKey = kind == "save" ? "save_start" : "no_work_start"
            let endKey = kind == "save" ? "save_end" : "no_work_end"
            let row: [String: Any] = [
                "sample_id": String(format: "T20-G%02d-%02d", group, index),
                "status": failure == nil ? "PASS" : "FAIL",
                "reason": failure.map { String(reflecting: type(of: $0)) } ?? "",
                "failure_code": failure.flatMap { error -> String? in
                    guard let recorderError = error as? RecorderError else { return nil }
                    switch recorderError {
                    case .absoluteOutputRequired: return "absolute_output_required"
                    case .invariant(let code): return code
                    }
                } ?? "",
                // Snapshot after the monotonic end, including when operation/verify throws.
                "diagnostics": diagnostics(),
                "environment": "native_swiftdata_disk_synthetic_transport",
                "kind": kind, "platform": "ios", "direction": "", "category": "",
                "condition": condition, "warmup": index <= 3, "measurement_number": max(0, index - 3),
                "timestamp_utc": ISO8601DateFormatter().string(from: Date()),
                "timestamps": [beginKey: ["clock_id": clockID, "ns": started],
                               endKey: ["clock_id": clockID, "ns": ended]],
                "elapsed_ms": Double(ended - started) / 1_000_000,
                "row_verified": failure == nil,
                "invariants_verified": kind == "no_work" && failure == nil,
                "evidence": [ledger.path], "observed": observed,
                "network_mode": "controlled_in_process_fake_no_live_requests",
                "acceptance_boundary": "local synthetic only; no peer UI or server delta acceptance"
            ]
            var bytes = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
            bytes.append(0x0a)
            let handle = try FileHandle(forWritingTo: ledger)
            try handle.seekToEnd()
            try handle.write(contentsOf: bytes)
            try handle.synchronize()
            try handle.close()
            print("T20_NATIVE_SAMPLE " + String(decoding: bytes, as: UTF8.self))
            if let failure { throw failure }
        }
    }

    func attach(to test: XCTestCase) throws {
        let attachment = XCTAttachment(data: try Data(contentsOf: ledger),
                                       uniformTypeIdentifier: "public.json")
        attachment.name = "T20-native-samples"
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }

    enum RecorderError: Error { case absoluteOutputRequired, invariant(String) }
}


/// Observation of the actual recovery task and interception, not inferred from a release flag.
@MainActor
final class MobileSyncPerformanceRecoveryProbe {
    var entered = false
    var waiting = false
    var finished = false
    var failureType: String?

    func requireHeld(taskPresent: Bool, taskCancelled: Bool,
                     transportReleased: Bool, journalPresent: Bool) throws {
        guard taskPresent, !taskCancelled, entered, waiting, !finished,
              failureType == nil, !transportReleased, journalPresent else {
            throw MobileSyncPerformanceRecorder.RecorderError.invariant("recovery_not_observed_held")
        }
    }
}

@MainActor
final class MobileSyncPerformanceProbeTests: XCTestCase {
    func testHeldProbeRejectsMissingEntryAndTaskTermination() throws {
        let probe = MobileSyncPerformanceRecoveryProbe()
        func requireHeld() throws {
            try probe.requireHeld(taskPresent: true, taskCancelled: false,
                                  transportReleased: false, journalPresent: true)
        }
        XCTAssertThrowsError(try requireHeld())
        probe.entered = true
        XCTAssertThrowsError(try requireHeld())
        probe.waiting = true
        XCTAssertNoThrow(try requireHeld())
        probe.finished = true
        XCTAssertThrowsError(try requireHeld())
        probe.finished = false
        probe.failureType = "SyntheticFailure"
        XCTAssertThrowsError(try requireHeld())
    }

    func testHeldProbeRejectsMissingTaskCancellationReleaseAndJournalLoss() throws {
        let probe = MobileSyncPerformanceRecoveryProbe()
        probe.entered = true; probe.waiting = true
        for variant in 0..<4 {
            XCTAssertThrowsError(try probe.requireHeld(taskPresent: variant != 0,
                taskCancelled: variant == 1, transportReleased: variant == 2,
                journalPresent: variant != 3))
        }
    }
}
