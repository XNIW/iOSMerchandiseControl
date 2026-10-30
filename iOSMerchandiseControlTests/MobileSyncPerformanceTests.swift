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
    private var recordedUISampleIDs: Set<String> = []
    func hasRecordedUI(_ id: String) -> Bool { recordedUISampleIDs.contains(id) }

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

    // TASK145_PERF consumes app-side timestamps. XCTest/AX polling is NEVER a latency clock.
    @discardableResult
    func recordObservedUI(_ payload: [String: Any], sampleID: String, warmup: Bool,
                          functionalFailure: String? = nil) throws -> [String: Double] {
        var row = payload
        row["sample_id"] = sampleID; row["warmup"] = warmup
        row["environment"] = "native_production_UI_synthetic_session_transport_persisted_20k_40k"
        row["acceptance_boundary"] = "local UI timing only; no authenticated backend or peer acceptance"
        row["render_boundary"] = "in-process committed UIKit layout plus next display opportunity; UI values separately verified"
        let marks = (payload["marks"] as? [[String: Any]]) ?? []
        let names = Dictionary(marks.compactMap { mark -> (String, UInt64)? in
            guard let name = mark["name"] as? String, let value = mark["ns"] as? NSNumber else { return nil }
            return (name, value.uint64Value)
        }, uniquingKeysWith: { first, _ in first })
        let cold = payload["launchKind"] as? String == "cold"
        let definitions: [(String, String, String, Double)] = [
            ("shell", "t0", "optionsRender", 2), ("data", "t0", "dataRender", cold ? 5 : 1),
            ("searchBroad", "searchBroadInputComplete", "searchBroadRender", 1),
            ("search", "searchInputComplete", "searchRender", 1),
            ("editor", "editorTap", "editorRender", 1), ("save", "saveTap", "saveRender", 1)]
        var measurements: [String: Double] = [:]
        var gateRows: [[String: Any]] = []
        var failure = functionalFailure
        if failure == nil, payload["status"] as? String != "PASS" { failure = payload["reason"] as? String ?? "observer_not_pass" }
        for (metric, start, end, maxSeconds) in definitions {
            guard let begin = names[start], let finish = names[end], finish >= begin else {
                if failure != nil {
                    gateRows.append(["metric": metric, "status": "NOT_TRAVERSED", "reason": "previous_gate_failed"])
                } else {
                    failure = "missing_or_invalid_" + metric
                    gateRows.append(["metric": metric, "status": "FAIL", "reason": failure!])
                }
                continue
            }
            let seconds = Double(finish - begin) / 1_000_000_000
            measurements[metric] = seconds
            let pass = seconds <= maxSeconds
            gateRows.append(["metric": metric, "status": pass ? "PASS" : "FAIL", "seconds": seconds, "max_seconds": maxSeconds])
            if !pass { failure = metric + "_absolute_max_exceeded" }
        }
        if failure == nil, let commit = names["saveCommit"], let render = names["saveRender"], commit > render {
            failure = "save_render_preceded_durable_commit"
        }
        if failure == nil, names["saveCommit"] == nil || names["durableReadbackVerified"] == nil { failure = "save_commit_or_readback_missing" }
        if payload["group"] as? String == "recovery" {
            let qualificationFailure = Self.recoveryHoldQualificationFailure(marks: names)
            row["recovery_hold_qualification"] = ["status": qualificationFailure == nil ? "PASS" : "FAIL",
                "reason": qualificationFailure ?? "actual_hold_precedes_all_UI_endpoints_and_spans_readback",
                "classification": qualificationFailure == nil ? "qualified_recovery_held" : "unqualified_recovery_held_not_counted"]
            if failure == nil, let qualificationFailure { failure = qualificationFailure }
        }
        if failure == nil, (payload["dropped"] as? Int ?? 0) != 0 { failure = "observer_capacity_exceeded" }
        if let entered = names["cutoverEntered"], let released = names["cutoverReleased"], released >= entered {
            let seconds = Double(released - entered) / 1_000_000_000
            measurements["cutover"] = seconds
            gateRows.append(["metric": "cutover", "seconds": seconds, "max_seconds": 0.3, "status": seconds <= 0.3 ? "PASS" : "FAIL"])
            if seconds > 0.3, failure == nil { failure = "cutover_absolute_max_exceeded" }
            if let pause = payload["maxCutoverDisplayIntervalNS"] as? NSNumber {
                let gap = pause.doubleValue / 1_000_000_000
                gateRows.append(["metric": "cutover_display_interval", "seconds": gap, "max_seconds": 0.1,
                    "status": gap <= 0.1 ? "PASS" : "FAIL"])
                if gap > 0.1, failure == nil { failure = "cutover_display_interval_exceeded" }
            } else if failure == nil { failure = "cutover_display_interval_not_observed" }
        } else {
            gateRows.append(["metric": "cutover", "status": "NOT_TRAVERSED", "reason": "no_physical_publication_in_this_sample"])
        }
        if let t0 = names["t0"], let tabs = names["tabsRender"], tabs >= t0 {
            row["shell_composition_seconds"] = Double(tabs - t0) / 1_000_000_000
            if let options = names["optionsRender"], options >= tabs {
                row["shell_navigation_observation_seconds"] = Double(options - tabs) / 1_000_000_000
            }
        }
        row["gates"] = gateRows; row["status"] = failure == nil ? "PASS" : "FAIL"; row["reason"] = failure ?? ""
        try appendObservedEvidence(row)
        recordedUISampleIDs.insert(sampleID)
        if let failure { throw RecorderError.invariant(failure) }
        return measurements
    }

    // Pure timestamp qualification. Neither AX waits nor later request entry
    // can turn an endpoint that preceded the hold into a held-recovery sample.
    static func recoveryHoldQualificationFailure(marks: [String: UInt64]) -> String? {
        guard let t0 = marks["t0"], let held = marks["requestHeld"], held >= t0,
              let through = marks["heldThroughEnd"], through >= held,
              let released = marks["controlledHoldReleased"], released >= through else {
            return "recovery_hold_order_missing_or_invalid"
        }
        for endpoint in ["optionsRender", "dataRender", "searchBroadRender", "searchRender",
                         "editorRender", "saveCommit", "saveRender", "durableReadbackVerified"] {
            guard let end = marks[endpoint] else { return "recovery_hold_endpoint_missing_" + endpoint }
            guard held <= end else { return "recovery_hold_started_after_" + endpoint }
            guard end <= through else { return "recovery_hold_ended_before_" + endpoint }
        }
        guard through - held >= 10_000_000_000 else { return "recovery_hold_shorter_than_10s" }
        return nil
    }

    func recordDatasetManifest(_ json: String, group: String, namespace: String) throws {
        guard let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: String],
              object["products"] == "20000", object["prices"] == "40000",
              object["suppliers"] == "2", object["categories"] == "2", object["history"] == "0",
              object["priceProductRelations"] == "40000" else { throw RecorderError.invariant("actual_seed_manifest_missing") }
        try appendObservedEvidence(["event": "verified_seed_manifest", "group": group, "namespace": namespace, "manifest": object])
    }

    func recordUIHarnessFailure(reason: String) throws {
        try appendObservedEvidence(["event": "first_harness_failure", "status": "FAIL", "reason": reason])
    }

    func recordNotTraversed(sampleIDs: [String], reason: String) throws {
        for id in sampleIDs { try appendObservedEvidence(["sample_id": id, "status": "NOT_TRAVERSED", "reason": reason]) }
    }

    func writeUIAggregate(_ rows: [(kind: String, offline: Bool, variant: String, values: [String: Double])], group: String) throws -> [String: Double] {
        guard rows.count == 30, rows.filter({ $0.kind == "cold" }).count == 15,
              rows.filter({ $0.kind == "warm" }).count == 15 else { throw RecorderError.invariant("incomplete_UI_group") }
        if group == "idle" {
            guard rows.filter({ $0.kind == "cold" && $0.offline }).count == 5,
                  rows.filter({ $0.kind == "warm" && $0.offline }).count == 5 else { throw RecorderError.invariant("offline_subgroup_incomplete") }
        }
        for variant in ["name", "price", "relations"] {
            guard rows.filter({ $0.variant == variant }).count == 10 else { throw RecorderError.invariant("save_variant_incomplete_" + variant) }
        }
        for kind in ["cold", "warm"] {
            for offline in [false, true] {
                let subset = rows.filter { $0.kind == kind && $0.offline == offline }
                guard !subset.isEmpty else { continue }
                for metric in ["shell", "data", "searchBroad", "search", "editor", "save"] {
                    let samples = subset.compactMap { $0.values[metric] }.sorted()
                    try appendObservedEvidence(["subgroup": group + "." + kind + (offline ? ".offline" : ".controlled-online"),
                        "metric": metric, "n": samples.count, "values_seconds": samples, "max_seconds": samples.last ?? 0,
                        "p95_claim": "NOT_CLAIMED_SMALL_SUBGROUP; all absolute maxima already gated"])
                }
            }
        }
        var result: [String: Double] = [:]
        for kind in ["cold", "warm"] {
            for (metric, limit) in [("shell", 1.0), ("data", kind == "cold" ? 2.0 : 0.5),
                                     ("searchBroad", 0.3), ("search", 0.3), ("editor", 0.5), ("save", 0.3)] {
                let samples = rows.filter { $0.kind == kind }.compactMap { $0.values[metric] }.sorted()
                guard samples.count == 15 else { throw RecorderError.invariant("missing_aggregate_metric") }
                let p95 = samples[Int(ceil(Double(samples.count) * 0.95)) - 1]
                result[kind + "." + metric] = p95
                try appendObservedEvidence(["aggregate": group + "." + kind + "." + metric, "p95_seconds": p95,
                    "max_seconds": samples.last!, "p95_limit": limit, "status": p95 <= limit ? "PASS" : "FAIL"])
                if p95 > limit { throw RecorderError.invariant("p95_" + kind + "_" + metric) }
            }
        }
        if group == "recovery" {
            let cutovers = rows.compactMap { $0.values["cutover"] }.sorted()
            guard cutovers.count == 30 else { throw RecorderError.invariant("cutover_series_incomplete") }
            let p95 = cutovers[Int(ceil(Double(cutovers.count) * 0.95)) - 1]
            try appendObservedEvidence(["aggregate": "cutover", "p95_seconds": p95, "p95_limit": 0.1,
                "status": p95 <= 0.1 ? "PASS" : "FAIL"])
            if p95 > 0.1 { throw RecorderError.invariant("cutover_p95_exceeded") }
        }
        return result
    }
    func writeUIPairedComparison(idle: [String: Double], recovery: [String: Double]) throws {
        for key in idle.keys.sorted() where key.hasSuffix(".search") || key.hasSuffix(".searchBroad") || key.hasSuffix(".editor") {
            guard let baseline = idle[key], let held = recovery[key] else { throw RecorderError.invariant("unpaired_UI_metric") }
            let limit = max(1.2 * baseline, baseline + 0.1)
            try appendObservedEvidence(["paired_metric": key, "idle_p95_seconds": baseline, "recovery_p95_seconds": held,
                "limit_seconds": limit, "status": held <= limit ? "PASS" : "FAIL"])
            if held > limit { throw RecorderError.invariant("paired_recovery_" + key) }
        }
    }
    private func appendObservedEvidence(_ row: [String: Any]) throws {
        var bytes = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]); bytes.append(0x0a)
        let handle = try FileHandle(forWritingTo: ledger); defer { try? handle.close() }
        try handle.seekToEnd(); try handle.write(contentsOf: bytes); try handle.synchronize()
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
    func testRecoveryHoldQualificationRejectsLateEntryEarlyReleaseAndMissingEndpoints() {
        let second: UInt64 = 1_000_000_000
        let qualified: [String: UInt64] = ["t0": 0, "requestHeld": second,
            "optionsRender": 2 * second, "dataRender": 3 * second,
            "searchBroadRender": 4 * second, "searchRender": 5 * second,
            "editorRender": 6 * second, "saveCommit": 7 * second,
            "saveRender": 8 * second, "durableReadbackVerified": 11 * second,
            "heldThroughEnd": 12 * second, "controlledHoldReleased": 13 * second]
        XCTAssertNil(MobileSyncPerformanceRecorder.recoveryHoldQualificationFailure(marks: qualified))
        for endpoint in ["optionsRender", "dataRender"] {
            var early = qualified; early[endpoint] = 0
            XCTAssertEqual(MobileSyncPerformanceRecorder.recoveryHoldQualificationFailure(marks: early),
                "recovery_hold_started_after_" + endpoint)
            var equalBoundary = qualified; equalBoundary[endpoint] = second
            XCTAssertNil(MobileSyncPerformanceRecorder.recoveryHoldQualificationFailure(marks: equalBoundary))
        }
        var releasedEarly = qualified; releasedEarly["controlledHoldReleased"] = 9 * second
        XCTAssertEqual(MobileSyncPerformanceRecorder.recoveryHoldQualificationFailure(marks: releasedEarly),
            "recovery_hold_order_missing_or_invalid")
        var absent = qualified; absent.removeValue(forKey: "dataRender")
        XCTAssertEqual(MobileSyncPerformanceRecorder.recoveryHoldQualificationFailure(marks: absent),
            "recovery_hold_endpoint_missing_dataRender")
        var beforeReadback = qualified; beforeReadback["heldThroughEnd"] = 10 * second
        XCTAssertEqual(MobileSyncPerformanceRecorder.recoveryHoldQualificationFailure(marks: beforeReadback),
            "recovery_hold_ended_before_durableReadbackVerified")
        var tooShort = qualified; tooShort["heldThroughEnd"] = 10 * second
        tooShort["durableReadbackVerified"] = 10 * second
        XCTAssertEqual(MobileSyncPerformanceRecorder.recoveryHoldQualificationFailure(marks: tooShort),
            "recovery_hold_shorter_than_10s")
    }

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
