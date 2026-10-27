#if DEBUG
import Foundation
import Darwin
import SwiftUI
import UIKit

// TASK145_PERF: data owned exclusively by Task144RootObservation.shared.
// No disk, stdout, model fetch, published state, or periodic progress while open.
nonisolated enum Task145PerformanceCallContext {
    @TaskLocal static var invocationID: UUID?
}
nonisolated struct Task145PerformanceMark: Codable {
    let name: String
    let ns: UInt64
    let facts: String
}
nonisolated struct Task145DurableDomainProgress: Codable {
    var pages = 0
    var rows = 0
    var advances = 0
    var baselineNS: UInt64?
    var longestBetweenDurableAdvancesNS: UInt64 = 0
    var firstAdvanceNS: UInt64?
    var lastAdvanceNS: UInt64?
}
nonisolated struct Task145PerformanceSample: Codable {
    var schema = 1
    var sampleID: String
    var launchKind: String
    var group: String
    var offline: Bool
    var pid: Int32 = ProcessInfo.processInfo.processIdentifier
    var clockID: String = "process-\(ProcessInfo.processInfo.processIdentifier)-mach-uptime-nanoseconds"
    var utcAtT0 = Date().timeIntervalSince1970
    var observedAtNS: UInt64?
    var metadata: [String: String] = [
        "os": ProcessInfo.processInfo.operatingSystemVersionString,
        "thermalAtEntry": String(ProcessInfo.processInfo.thermalState.rawValue),
        "hardware": Task145PerformanceResourceSnapshot.hardwareIdentifier(),
        "clockUncertainty": "same-process monotonic; no cross-device subtraction",
        "PSS": "NOT_OBSERVED; Darwin RSS and process peak supplied",
        "osLaunchToEntry": "NOT_OBSERVED; separate external native trace required"]
    var durableDomains: [String: Task145DurableDomainProgress] = [:]
    var lastDurableProgressNS: UInt64?
    var phase = "app-entry"
    var phaseFirstNS: [String: UInt64] = [:]
    var phaseLastNS: [String: UInt64] = [:]
    var marks: [Task145PerformanceMark] = []
    var dropped = 0
    var status = "OPEN"
    var reason = ""
    var resources: [String: UInt64] = [:]
    var displayIntervals = 0
    var maxDisplayIntervalNS: UInt64 = 0
    var maxCutoverDisplayIntervalNS: UInt64?
    var lastDisplayNS: UInt64?
}
nonisolated enum Task145PerformanceConfiguration {
    static let environment = ProcessInfo.processInfo.environment
    static let mode = environment["TASK145_PERF_MODE"] ?? ""
    static let enabled = ["seed", "measure"].contains(mode)
        && environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"].flatMap(UUID.init(uuidString:)) != nil
    static let measures = enabled && mode == "measure"
    static let recovery = environment["TASK145_PERF_GROUP"] == "recovery"
    static let offline = environment["TASK145_PERF_OFFLINE"] == "1"
    static let targetBarcode = "T20-020000"
    static let targetID = UUID(uuidString: "20000000-0000-4000-8000-000000020000")!
    static let supplierIDs = [UUID(uuidString: "41000000-0000-4000-8000-000000000001")!, UUID(uuidString: "41000000-0000-4000-8000-000000000002")!]
    static let categoryIDs = [UUID(uuidString: "42000000-0000-4000-8000-000000000001")!, UUID(uuidString: "42000000-0000-4000-8000-000000000002")!]
    static let supplierNames = ["T20 Supplier One", "T20 Supplier Two"]
    static let categoryNames = ["T20 Category One", "T20 Category Two"]
}

nonisolated func task145PerformanceEditorMatches(_ name: String, barcode: String) -> Bool {
    guard barcode == "T20-020000" else { return false }
    let sample = Task144RootObservation.performanceSampleID()
    let expected = sample.hasSuffix("-warm") ? "T20 edited " + String(sample.dropLast(5)) + "-cold"
        : Task145PerformanceConfiguration.environment["TASK145_PERF_EXPECTED_EDITOR_NAME"]
    return name == expected
}
nonisolated func task145PerformanceSaveMatches(_ name: String?) -> Bool {
    name == "T20 edited " + Task144RootObservation.performanceSampleID()
}
nonisolated enum Task145PerformanceResourceSnapshot {
    static func hardwareIdentifier() -> String {
        var count = 0
        guard sysctlbyname("hw.machine", nil, &count, nil, 0) == 0, count > 0, count < 256 else { return "UNKNOWN" }
        var bytes = [CChar](repeating: 0, count: count)
        guard sysctlbyname("hw.machine", &bytes, &count, nil, 0) == 0 else { return "UNKNOWN" }
        return String(cString: bytes)
    }
    static func capture(prefix: String) -> [String: UInt64] {
        var usage = rusage()
        var values: [String: UInt64] = [prefix + "thermal_state_raw": UInt64(ProcessInfo.processInfo.thermalState.rawValue)]
        if getrusage(0, &usage) == 0 {
            values[prefix + "cpu_user_us"] = UInt64(usage.ru_utime.tv_sec) * 1_000_000 + UInt64(usage.ru_utime.tv_usec)
            values[prefix + "cpu_system_us"] = UInt64(usage.ru_stime.tv_sec) * 1_000_000 + UInt64(usage.ru_stime.tv_usec)
            values[prefix + "process_peak_rss_bytes"] = UInt64(usage.ru_maxrss)
        }
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if status == KERN_SUCCESS { values[prefix + "rss_bytes"] = UInt64(info.resident_size) }
        return values
    }
}

/// Observes a committed UIKit layout and the next display opportunity. It does
/// not claim pixel/scanout time; XCTest independently verifies displayed values.
/// A repeated value in a mounted row is observed after updateUIView, not onAppear.
struct Task145PerformanceRenderBoundary: UIViewRepresentable {
    let event: String
    let qualifies: Bool
    var facts: String = ""
    var validate: @MainActor () -> Bool = { true }
    func makeUIView(context: Context) -> Boundary {
        let view = Boundary(); view.isUserInteractionEnabled = false; return view
    }
    func updateUIView(_ view: Boundary, context: Context) {
        view.event = event; view.facts = facts; view.qualifies = qualifies; view.validate = validate
        view.setNeedsLayout()
    }
    final class Boundary: UIView {
        var event = ""; var facts = ""; var qualifies = false
        var validate: @MainActor () -> Bool = { true }
        private var link: CADisplayLink?
        private var token: String?
        private var visibilityDeadlineNS: UInt64?
        private var activation: NSObjectProtocol?
        override init(frame: CGRect) {
            super.init(frame: frame)
            activation = NotificationCenter.default.addObserver(forName: .init("TASK145_PERF_WARM_T0"), object: nil, queue: .main) { [weak self] _ in
                self?.setNeedsLayout()
            }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layoutSubviews() {
            super.layoutSubviews()
            guard Task145PerformanceConfiguration.measures, qualifies, window != nil,
                  !bounds.isEmpty,
                  token != Task144RootObservation.performanceSampleID() + ":" + event + ":" + facts,
                  link == nil else { return }
            visibilityDeadlineNS = DispatchTime.now().uptimeNanoseconds + 1_000_000_000
            let displayLink = CADisplayLink(target: self, selector: #selector(afterLayout))
            link = displayLink; displayLink.add(to: .main, forMode: .common)
        }
        private func visibleInHierarchy() -> Bool {
            guard let window, !bounds.isEmpty else { return false }
            var visible = convert(bounds, to: window).intersection(window.bounds)
            var ancestor: UIView? = self
            while let view = ancestor {
                guard !view.isHidden, view.alpha > 0 else { return false }
                if view.clipsToBounds { visible = visible.intersection(view.convert(view.bounds, to: window)) }
                guard !visible.isEmpty, !visible.isNull else { return false }
                ancestor = view.superview
            }
            if event == "saveRender" {
                // A row updated behind its editor is not yet visible feedback.
                // Keep waiting through the actual dismissal, without initiating it.
                var controllers = window.rootViewController.map { [$0] } ?? []
                var inspected = 0
                while let controller = controllers.popLast() {
                    inspected += 1
                    guard inspected <= 64, controller.presentedViewController == nil,
                          !controller.isBeingDismissed else { return false }
                    controllers.append(contentsOf: controller.children)
                }
            }
            return true
        }
        @objc private func afterLayout() {
            guard qualifies, validate(), visibleInHierarchy() else {
                if DispatchTime.now().uptimeNanoseconds >= (visibilityDeadlineNS ?? 0) {
                    link?.invalidate(); link = nil
                }
                return
            }
            link?.invalidate(); link = nil
            token = Task144RootObservation.performanceSampleID() + ":" + event + ":" + facts
            Task144RootObservation.performanceMark(event, facts: facts)
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { link?.invalidate(); link = nil }
            else { setNeedsLayout() }
        }
        deinit { link?.invalidate(); if let activation { NotificationCenter.default.removeObserver(activation) } }
    }
}

/// Passive input/lifecycle observation. Never recognizes, cancels or delays an
/// application gesture. Touch time is kept separately from handler entry.
struct Task145PerformanceWindowObservation: UIViewRepresentable {
    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) { }
    final class Probe: UIView {
        private var touch: TouchObserver?
        private var frames: CADisplayLink?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard Task145PerformanceConfiguration.measures else { return }
            guard let window else {
                frames?.invalidate(); frames = nil
                if let touch { touch.view?.removeGestureRecognizer(touch) }; touch = nil
                return
            }
            guard touch == nil else { return }
            let observer = TouchObserver(); observer.cancelsTouchesInView = false
            observer.delaysTouchesBegan = false; observer.delaysTouchesEnded = false
            window.addGestureRecognizer(observer); touch = observer
            let link = CADisplayLink(target: self, selector: #selector(observeFrame))
            frames = link; link.add(to: .main, forMode: .common)
        }
        @objc private func observeFrame(_ link: CADisplayLink) {
            Task144RootObservation.performanceFrame(UInt64(link.timestamp * 1_000_000_000))
        }
        deinit {
            frames?.invalidate()
            if let touch { touch.view?.removeGestureRecognizer(touch) }
        }
    }
    final class TouchObserver: UIGestureRecognizer {
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if let touch = touches.first {
                Task144RootObservation.performanceTouch(UInt64(touch.timestamp * 1_000_000_000))
            }
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
        override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    }
}

/// Read-only AX export of bounded RAM, after each UI milestone. AX never supplies
/// timestamps and never publishes/invalidate views. Enables stop at first max FAIL.
struct Task145PerformanceReadback: UIViewRepresentable {
    func makeUIView(context: Context) -> Readback { Readback() }
    func updateUIView(_ view: Readback, context: Context) { }
    final class Readback: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame); isAccessibilityElement = true
            accessibilityIdentifier = "task145.perf.live-sample"; isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override var accessibilityValue: String? {
            get { Task144RootObservation.performanceSnapshot() }
            set { }
        }
    }
}

extension View {
    @ViewBuilder func task145PerformanceRender(_ event: String, qualifies: Bool = true, facts: String = "", validate: @escaping @MainActor () -> Bool = { true }) -> some View {
        if Task145PerformanceConfiguration.measures {
            background(Task145PerformanceRenderBoundary(event: event, qualifies: qualifies, facts: facts, validate: validate))
        } else { self }
    }
}
#else
import SwiftUI
func task145PerformanceSaveMatches(_ name: String?) -> Bool { false }
func task145PerformanceEditorMatches(_ name: String, barcode: String) -> Bool { false }
extension View {
    func task145PerformanceRender(_ event: String, qualifies: Bool = true, facts: String = "", validate: @escaping @MainActor () -> Bool = { true }) -> some View { self }
}
#endif
