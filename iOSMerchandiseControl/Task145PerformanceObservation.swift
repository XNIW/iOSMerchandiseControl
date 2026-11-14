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
    // One current-thread snapshot, not a periodic sampler. The caller must
    // be on main; failures omit CPU values rather than inventing zero cost.
    static func captureCurrentMainThreadCPU(prefix: String) -> [String: UInt64] {
        var values: [String: UInt64] = [prefix + "observed_on_main_thread": Thread.isMainThread ? 1 : 0]
        guard Thread.isMainThread else { return values }
        let thread = mach_thread_self()
        guard thread != MACH_PORT_NULL else { return values }
        // mach_thread_self grants a send right. Release only that owned right,
        // including a failed thread_info call; never enumerate other threads.
        defer { _ = mach_port_deallocate(mach_task_self_, thread) }
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
            }
        }
        values[prefix + "main_thread_cpu_status"] = UInt64(UInt32(bitPattern: status))
        if status == KERN_SUCCESS {
            values[prefix + "main_thread_user_us"] = UInt64(info.user_time.seconds) * 1_000_000 + UInt64(info.user_time.microseconds)
            values[prefix + "main_thread_system_us"] = UInt64(info.system_time.seconds) * 1_000_000 + UInt64(info.system_time.microseconds)
        }
        return values
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
    var onRendered: (@MainActor () -> Void)?
    var validateNative: (@MainActor (UIView) -> Bool)? = nil
    var onNativeRendered: (@MainActor (UIView) -> Void)? = nil
    var onNativeObservationEnded: (@MainActor (UIView, String) -> Void)? = nil
    func makeUIView(context: Context) -> Boundary {
        let view = Boundary(); view.isUserInteractionEnabled = false; return view
    }
    func updateUIView(_ view: Boundary, context: Context) {
        view.event = event; view.facts = facts; view.qualifies = qualifies; view.validate = validate
        view.onRendered = onRendered
        view.validateNative = validateNative; view.onNativeRendered = onNativeRendered
        view.onNativeObservationEnded = onNativeObservationEnded
        view.setNeedsLayout()
    }
    final class Boundary: UIView {
        var event = ""; var facts = ""; var qualifies = false
        var validate: @MainActor () -> Bool = { true }
        var onRendered: (@MainActor () -> Void)?
        var validateNative: (@MainActor (UIView) -> Bool)?
        var onNativeRendered: (@MainActor (UIView) -> Void)?
        var onNativeObservationEnded: (@MainActor (UIView, String) -> Void)?
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
            guard Task145PerformanceConfiguration.measures || onRendered != nil || onNativeRendered != nil else { return }
            guard qualifies, window != nil,
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
            guard qualifies, validate(), validateNative?(self) != false, visibleInHierarchy() else {
                if DispatchTime.now().uptimeNanoseconds >= (visibilityDeadlineNS ?? 0) {
                    link?.invalidate(); link = nil
                    onNativeObservationEnded?(self, "existing-one-second-visibility-window-expired")
                }
                return
            }
            link?.invalidate(); link = nil
            token = Task144RootObservation.performanceSampleID() + ":" + event + ":" + facts
            if let onNativeRendered { onNativeRendered(self) }
            else if let onRendered { onRendered() }
            else { Task144RootObservation.performanceMark(event, facts: facts) }
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                if link != nil { onNativeObservationEnded?(self, "window-detached-before-observation") }
                link?.invalidate(); link = nil
            } else { setNeedsLayout() }
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
    var identifier = "task145.perf.live-sample"
    var readValue: @MainActor () -> String = { Task144RootObservation.performanceSnapshot() }
    func makeUIView(context: Context) -> Readback {
        let view = Readback()
        view.accessibilityIdentifier = identifier
        view.readValue = readValue
        return view
    }
    func updateUIView(_ view: Readback, context: Context) { }
    final class Readback: UIView {
        var readValue: @MainActor () -> String = { "{}" }
        override init(frame: CGRect) {
            super.init(frame: frame); isAccessibilityElement = true
            accessibilityIdentifier = "task145.perf.live-sample"; isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override var accessibilityValue: String? {
            get { readValue() }
            set { }
        }
    }
}


/// Diagnostic-only T19 selection timestamps. No publisher, disk write, input,
/// forced layout or navigation. Existing XCTest selected/deadline gate is final.
@MainActor
enum Task146T19TabObservation {
    private static let environment = ProcessInfo.processInfo.environment
    static let enabled = ["cycles", "repeated-material"].contains(environment["TASK145_T19_UI"] ?? "")
        && environment["TASK145_T19_STAGE"] == "collect"
        && environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"].flatMap(UUID.init(uuidString:)) != nil
    private static let namespace = environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"]?.lowercased() ?? "absent"
    private static let pid = ProcessInfo.processInfo.processIdentifier
    private static let capacity = 512
    private(set) static var requestOrdinal = 0
    private static var requestedTab: Int?
    private static var requestedPresentation: String?
    private static var marks: [[String: Any]] = []
    private static var dropped = 0
    private static var committed: Set<Int> = []
    private static var noChangeAssignments = 0
    private static var noChangeAssignmentsCapped = false
    private static weak var nativeProbe: UIView?
    private static var nativeProbePresentation: String?
    private static var lastProbeSnapshot: [String: Any] = [:]
    private static var transitionRegistrations: Set<String> = []
    private static var transitionCounts: [Int: Int] = [:]
    private static var transitionRegistrationsDropped = 0
    private static var completedTransitions: Set<String> = []
    private static var endedRequests: Set<Int> = []
    private static var publishedRequests: Set<Int> = []
    private static var repeatedEvents: [String: Int] = [:]
    private static var repeatedEventCountsCapped = false
    private static var lastPublicationMismatch: [String: Any] = [:]

    private static func noteRepeatedEvent(_ kind: String) {
        let count = repeatedEvents[kind, default: 0]
        if count < capacity { repeatedEvents[kind] = count + 1 }
        else { repeatedEventCountsCapped = true }
    }

    static func bindingRequested(from: Int, to: Int, presentationID: String) -> Int? {
        guard enabled else { return nil }
        // Same-value presentation restoration need not invalidate SwiftUI.
        // Keep its passive count separate; do not supersede a real request.
        guard from != to else {
            if noChangeAssignments < capacity { noChangeAssignments += 1 }
            else { noChangeAssignmentsCapped = true }
            return nil
        }
        guard marks.count < capacity else { dropped += 1; return nil }
        requestOrdinal += 1; requestedTab = to; requestedPresentation = presentationID
        append("binding-entry", tab: to, presentationID: presentationID,
            extra: ["fromTab": from, "request": requestOrdinal])
        snapshot("native-state-at-binding-entry", tab: to, request: requestOrdinal, presentationID: presentationID)
        return requestOrdinal
    }
    static func bindingAssignmentReturned(request: Int?, tab: Int, presentationID: String) {
        guard enabled, let request else { return }
        append("binding-assignment-returned", tab: tab, presentationID: presentationID,
            extra: ["request": request, "requestIsCurrent": current(tab: tab, request: request, presentationID: presentationID)])
        snapshot("native-state-at-binding-return", tab: tab, request: request, presentationID: presentationID)
    }
    static func publicationObserved(tab: Int, presentationID: String) {
        guard enabled else { return }
        guard current(tab: tab, request: requestOrdinal, presentationID: presentationID) else {
            noteRepeatedEvent("publication-without-current-matching-request")
            lastPublicationMismatch = ["request": requestOrdinal, "tab": tab, "presentation": presentationID,
                "uptime": ProcessInfo.processInfo.systemUptime,
                "requestedTab": requestedTab as Any? ?? NSNull(),
                "requestedPresentation": requestedPresentation as Any? ?? NSNull()]
            return
        }
        guard !publishedRequests.contains(requestOrdinal) else { noteRepeatedEvent("publication"); return }
        guard publishedRequests.count < capacity else { dropped += 1; return }
        publishedRequests.insert(requestOrdinal)
        append("binding-published", tab: tab, presentationID: presentationID,
            extra: ["request": requestOrdinal])
        snapshot("native-state-at-publication", tab: tab, request: requestOrdinal, presentationID: presentationID)
    }
    private static func append(_ kind: String, tab: Int, presentationID: String, extra: [String: Any]) {
        guard marks.count < capacity else { dropped += 1; return }
        var row = extra
        row["sequence"] = marks.count + 1; row["kind"] = kind
        row["tab"] = tab; row["presentation"] = presentationID
        row["uptime"] = ProcessInfo.processInfo.systemUptime
        if ["binding-entry", "binding-assignment-returned", "binding-published",
            "native-transition-completed", "native-render-observation-ended"].contains(kind) {
            let began = DispatchTime.now().uptimeNanoseconds
            var cpu = Task145PerformanceResourceSnapshot.captureCurrentMainThreadCPU(prefix: "")
            cpu["capture_start_uptime_ns"] = began
            cpu["capture_end_uptime_ns"] = DispatchTime.now().uptimeNanoseconds
            row["mainCPU"] = cpu
        }
        marks.append(row)
    }
    private static func current(tab: Int, request: Int, presentationID: String) -> Bool {
        enabled && request > 0 && request == requestOrdinal
            && requestedTab == tab && requestedPresentation == presentationID
    }
    private static func snapshot(_ kind: String, tab: Int, request: Int, presentationID: String) {
        var value: [String: Any] = ["request": request]
        guard current(tab: tab, request: request, presentationID: presentationID) else {
            value["rejection"] = "binding-request-superseded-or-unavailable"
            append(kind, tab: tab, presentationID: presentationID, extra: value); return
        }
        guard nativeProbePresentation == presentationID, let probe = nativeProbe else {
            value["rejection"] = "current-window-probe-unavailable"
            append(kind, tab: tab, presentationID: presentationID, extra: value); return
        }
        let native = inspectNative(probe, tab: tab, includeDetails: true)
        value["native"] = native.values
        append(kind, tab: tab, presentationID: presentationID, extra: value)
        observeTransitions(native.transitions, probe: probe, tab: tab, request: request, presentationID: presentationID)
    }
    // Completion-only registration observes the actual UIKit transition. No
    // alongside animation, timer, polling, view loading or layout is requested.
    private static func observeTransitions(_ transitions: [(String, UIViewControllerTransitionCoordinator)],
        probe: UIView, tab: Int, request: Int, presentationID: String) {
        for (role, coordinator) in transitions {
            let identity = String(describing: ObjectIdentifier(coordinator as AnyObject))
            let key = "\(request):\(identity)"
            guard !transitionRegistrations.contains(key) else { continue }
            guard transitionRegistrations.count < 80, (transitionCounts[request] ?? 0) < 2,
                  marks.count < capacity else { transitionRegistrationsDropped += 1; continue }
            transitionRegistrations.insert(key); transitionCounts[request, default: 0] += 1
            let started = ProcessInfo.processInfo.systemUptime
            let original = transitionDetails(coordinator)
            let accepted = coordinator.animate(alongsideTransition: nil) { [weak probe] context in
                let callbackEntry = ProcessInfo.processInfo.systemUptime
                guard !completedTransitions.contains(key) else { noteRepeatedEvent("transition-completion"); return }
                guard completedTransitions.count < 80 else { dropped += 1; return }
                completedTransitions.insert(key)
                var value: [String: Any] = ["request": request, "coordinator": identity, "role": role,
                    "callbackEntryUptime": callbackEntry,
                    "registrationStartedUptime": started, "transition": transitionDetails(context),
                    "requestIsCurrent": current(tab: tab, request: request, presentationID: presentationID)]
                if let probe { value["native"] = inspectNative(probe, tab: tab, includeDetails: true).values }
                else { value["native"] = ["rejection": "registered-probe-released"] }
                append("native-transition-completed", tab: tab, presentationID: presentationID, extra: value)
            }
            // UIKit may invoke completion even when registration returns false.
            // Record both facts; neither alone overrides the original UI gate.
            append("native-transition-registration", tab: tab, presentationID: presentationID,
                extra: ["request": request, "coordinator": identity, "role": role,
                    "registrationStartedUptime": started, "registrationReturnedUptime": ProcessInfo.processInfo.systemUptime,
                    "alongsideRegistrationAccepted": accepted, "transition": original])
        }
    }
    private static func transitionDetails(_ context: UIViewControllerTransitionCoordinatorContext) -> [String: Any] {
        ["identity": String(describing: ObjectIdentifier(context as AnyObject)),
            "expectedDurationSeconds": context.transitionDuration, "animated": context.isAnimated,
            "initiallyInteractive": context.initiallyInteractive, "interactive": context.isInteractive,
            "cancelled": context.isCancelled, "percentComplete": Double(context.percentComplete),
            "completionVelocity": Double(context.completionVelocity), "completionCurve": context.completionCurve.rawValue]
    }
    static func nativeQualifies(_ view: UIView, tab: Int, request: Int, presentationID: String) -> Bool {
        guard enabled else { return false }
        // Only a weak reference to an already attached observer; no lookup,
        // new view, layout, navigation, input or state publication is requested.
        if view.window != nil {
            nativeProbe = view; nativeProbePresentation = presentationID
        }
        guard current(tab: tab, request: request, presentationID: presentationID) else { return false }
        let native = inspectNative(view, tab: tab)
        lastProbeSnapshot = ["request": request, "presentation": presentationID,
            "uptime": ProcessInfo.processInfo.systemUptime, "native": native.values]
        return native.settledSelection
    }
    static func nativeCommitted(_ view: UIView, tab: Int, request: Int, presentationID: String) {
        guard current(tab: tab, request: request, presentationID: presentationID),
              !committed.contains(request) else { return }
        let native = inspectNative(view, tab: tab)
        guard native.settledSelection else { return }
        guard marks.count < capacity, committed.count < capacity else { dropped += 1; return }
        committed.insert(request)
        append("native-selected-visible-display-opportunity", tab: tab, presentationID: presentationID,
            extra: ["request": request, "native": native.values])
    }
    static func nativeObservationEnded(_ reason: String, tab: Int, request: Int, presentationID: String) {
        guard current(tab: tab, request: request, presentationID: presentationID) else { return }
        guard !endedRequests.contains(request) else { noteRepeatedEvent("observation-end"); return }
        guard endedRequests.count < capacity else { dropped += 1; return }
        endedRequests.insert(request)
        var value: [String: Any] = ["request": request, "reason": reason, "lastProbe": lastProbeSnapshot]
        if nativeProbePresentation == presentationID, let probe = nativeProbe {
            value["nativeAtObservationEnd"] = inspectNative(probe, tab: tab, includeDetails: true).values
        }
        append("native-render-observation-ended", tab: tab, presentationID: presentationID, extra: value)
    }
    private struct NativeInspection {
        let values: [String: Any]
        let settledSelection: Bool
        var transitions: [(String, UIViewControllerTransitionCoordinator)] = []
    }
    // Explain the existing model-geometry predicate only at explicit snapshots
    // and completion/expiry, never at every display-link poll. No scanout claim.
    private static func visibilityDetails(_ view: UIView?, in window: UIWindow, role: String) -> [String: Any] {
        guard let view else { return ["reason": "view-not-loaded"] }
        var value: [String: Any] = ["role": role,
            "viewIdentity": String(describing: ObjectIdentifier(view)),
            "windowMatches": view.window === window, "hasWindow": view.window != nil,
            "bounds": NSStringFromCGRect(view.bounds), "windowFrame": NSStringFromCGRect(view.convert(view.bounds, to: window)),
            "clock": ProcessInfo.processInfo.systemUptime]
        guard view.window === window else { value["reason"] = "window-mismatch-or-detached"; return value }
        guard !view.bounds.isEmpty else { value["reason"] = "empty-bounds"; return value }
        var rectangle = view.convert(view.bounds, to: window).intersection(window.bounds)
        var ancestor: UIView? = view, count = 0
        while let node = ancestor {
            count += 1
            guard count <= 64 else { value["reason"] = "explanation-ancestor-limit"; return value }
            var reason: String?
            if node.isHidden { reason = "ancestor-hidden" }
            else if !(node.alpha > 0.99) { reason = "ancestor-alpha-not-above-0.99" }
            else {
                if node.clipsToBounds { rectangle = rectangle.intersection(node.convert(node.bounds, to: window)) }
                if rectangle.isNull || rectangle.isEmpty { reason = "ancestor-clips-intersection-empty" }
            }
            if let reason {
                value["reason"] = reason; value["ancestorDepth"] = count
                value["ancestor"] = ["role": "visibility-predicate-ancestor",
                    "identity": String(describing: ObjectIdentifier(node)), "hidden": node.isHidden,
                    "alpha": Double(node.alpha), "clipsToBounds": node.clipsToBounds,
                    "bounds": NSStringFromCGRect(node.bounds),
                    "windowFrame": NSStringFromCGRect(node.convert(node.bounds, to: window))]
                return value
            }
            ancestor = node.superview
        }
        value["reason"] = "model-geometry-visible"; value["ancestorDepth"] = count
        return value
    }
    private static func visible(_ view: UIView, in window: UIWindow) -> Bool {
        guard view.window === window, !view.bounds.isEmpty else { return false }
        var rectangle = view.convert(view.bounds, to: window).intersection(window.bounds)
        var ancestor: UIView? = view
        while let node = ancestor {
            guard !node.isHidden, node.alpha > 0.99 else { return false }
            if node.clipsToBounds { rectangle = rectangle.intersection(node.convert(node.bounds, to: window)) }
            guard !rectangle.isNull, !rectangle.isEmpty else { return false }
            ancestor = node.superview
        }
        return true
    }
    private static func inspectNative(_ probe: UIView, tab: Int, includeDetails: Bool = false) -> NativeInspection {
        func rejected(_ reason: String) -> NativeInspection {
            var value: [String: Any] = ["rejection": reason, "stateReadUptime": ProcessInfo.processInfo.systemUptime]
            if includeDetails, let window = probe.window { value["probeVisibility"] = visibilityDetails(probe, in: window, role: "observer-probe") }
            return NativeInspection(values: value, settledSelection: false)
        }
        guard let window = probe.window, window.isKeyWindow, !window.isHidden,
              window.windowScene?.activationState == .foregroundActive,
              visible(probe, in: window), var root = window.rootViewController else {
            return rejected("probe-or-foreground-window-not-visible")
        }
        // A sheet remains authoritative until UIKit removes it.
        while let presented = root.presentedViewController { root = presented }
        var queue = [root], seen = Set<ObjectIdentifier>(), candidates: [UITabBarController] = []
        while let controller = queue.popLast() {
            guard seen.insert(ObjectIdentifier(controller)).inserted else { continue }
            guard seen.count <= 64 else { return rejected("controller-inventory-bound") }
            queue.append(contentsOf: controller.children)
            if let tabs = controller as? UITabBarController, tabs.isViewLoaded,
               tabs.viewIfLoaded?.window === window {
                candidates.append(tabs)
            }
        }
        guard candidates.count == 1, let tabs = candidates.first else {
            return rejected(candidates.isEmpty ? "native-tab-controller-unavailable" : "ambiguous-native-tab-controllers")
        }
        // Date the actual selectedIndex/selectedItem even while transition is
        // active; that state is distinct from a later settled display mark.
        let selectedIndex = tabs.selectedIndex
        let itemIndex = tabs.tabBar.selectedItem.flatMap { selected in
            tabs.tabBar.items?.firstIndex(where: { $0 === selected })
        }
        let stateReadUptime = ProcessInfo.processInfo.systemUptime
        let selected = tabs.selectedViewController
        let barVisible = visible(tabs.tabBar, in: window)
        let contentVisible: Bool
        if let selectedView = selected?.viewIfLoaded { contentVisible = visible(selectedView, in: window) }
        else { contentVisible = false }
        let tabsCoordinator = tabs.transitionCoordinator
        let selectedCoordinator = selected?.transitionCoordinator
        let tabsTransition = tabsCoordinator != nil
        let selectedTransition = selectedCoordinator != nil
        let presenting = tabs.isBeingPresented || selected?.isBeingPresented == true
        let dismissing = tabs.isBeingDismissed || selected?.isBeingDismissed == true
        let actualSelected = selectedIndex == tab && itemIndex == tab
        let settled = actualSelected && barVisible && contentVisible
            && !tabsTransition && !selectedTransition && !presenting && !dismissing
        var values: [String: Any] = ["stateReadUptime": stateReadUptime,
            "nativeController": String(reflecting: type(of: tabs)),
            "selectedIndex": selectedIndex, "selectedItemIndex": itemIndex as Any? ?? NSNull(),
            "selectedIndexAndItemMatchTarget": actualSelected, "tabBarVisible": barVisible,
            "selectedContentVisible": contentVisible, "tabControllerTransitionActive": tabsTransition,
            "selectedControllerTransitionActive": selectedTransition, "presenting": presenting,
            "dismissing": dismissing, "settledSelection": settled]
        var transitions: [(String, UIViewControllerTransitionCoordinator)] = []
        if includeDetails {
            values["selectedContentVisibility"] = visibilityDetails(selected?.viewIfLoaded, in: window, role: "selected-content")
            values["tabBarVisibility"] = visibilityDetails(tabs.tabBar, in: window, role: "tab-bar")
            if let tabsCoordinator {
                values["tabTransition"] = transitionDetails(tabsCoordinator)
                transitions.append(("tabController", tabsCoordinator))
            }
            if let selectedCoordinator {
                values["selectedTransition"] = transitionDetails(selectedCoordinator)
                transitions.append(("selectedController", selectedCoordinator))
            }
        }
        return NativeInspection(values: values, settledSelection: settled, transitions: transitions)
    }
    static func readback() -> String {
        let value: [String: Any] = ["protocol": "task146-t19-tab-observation-v3", "pid": pid,
            "namespace": namespace, "clock": "same-Simulator-boot-systemUptime",
            "capacity": capacity, "dropped": dropped, "requestOrdinal": requestOrdinal,
            "noChangeAssignments": noChangeAssignments, "noChangeAssignmentsCapped": noChangeAssignmentsCapped,
            "marks": marks, "lastProbe": lastProbeSnapshot,
            "transitionRegistrationCount": transitionRegistrations.count,
            "transitionRegistrationsDropped": transitionRegistrationsDropped,
            "repeatedEvents": repeatedEvents, "repeatedEventCountsCapped": repeatedEventCountsCapped,
            "lastPublicationMismatch": lastPublicationMismatch,
            "acceptance": "DIAGNOSTIC_ONLY_ORIGINAL_XCTEST_5S_GATE_UNCHANGED"]
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            return "SERIALIZATION_FAILED_NOT_OBSERVED"
        }
        return String(decoding: data, as: UTF8.self)
    }
}

extension View {
    @ViewBuilder func task145PerformanceRender(_ event: String, qualifies: @autoclosure () -> Bool = true, facts: @autoclosure () -> String = "", validate: @escaping @MainActor () -> Bool = { true }) -> some View {
        if Task145PerformanceConfiguration.measures {
            background(Task145PerformanceRenderBoundary(event: event, qualifies: qualifies(), facts: facts(), validate: validate))
        } else { self }
    }
}
#else
import SwiftUI
func task145PerformanceSaveMatches(_ name: String?) -> Bool { false }
func task145PerformanceEditorMatches(_ name: String, barcode: String) -> Bool { false }
extension View {
    func task145PerformanceRender(_ event: String, qualifies: @autoclosure () -> Bool = true, facts: @autoclosure () -> String = "", validate: @escaping @MainActor () -> Bool = { true }) -> some View { self }
}
#endif
