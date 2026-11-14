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
        value["native"] = inspectNative(probe, tab: tab).values
        append(kind, tab: tab, presentationID: presentationID, extra: value)
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
        append("native-render-observation-ended", tab: tab, presentationID: presentationID,
            extra: ["request": request, "reason": reason, "lastProbe": lastProbeSnapshot])
    }
    private struct NativeInspection {
        let values: [String: Any]
        let settledSelection: Bool
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
    private static func inspectNative(_ probe: UIView, tab: Int) -> NativeInspection {
        func rejected(_ reason: String) -> NativeInspection {
            NativeInspection(values: ["rejection": reason, "stateReadUptime": ProcessInfo.processInfo.systemUptime],
                settledSelection: false)
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
        let tabsTransition = tabs.transitionCoordinator != nil
        let selectedTransition = selected?.transitionCoordinator != nil
        let presenting = tabs.isBeingPresented || selected?.isBeingPresented == true
        let dismissing = tabs.isBeingDismissed || selected?.isBeingDismissed == true
        let actualSelected = selectedIndex == tab && itemIndex == tab
        let settled = actualSelected && barVisible && contentVisible
            && !tabsTransition && !selectedTransition && !presenting && !dismissing
        let values: [String: Any] = ["stateReadUptime": stateReadUptime,
            "nativeController": String(reflecting: type(of: tabs)),
            "selectedIndex": selectedIndex, "selectedItemIndex": itemIndex as Any? ?? NSNull(),
            "selectedIndexAndItemMatchTarget": actualSelected, "tabBarVisible": barVisible,
            "selectedContentVisible": contentVisible, "tabControllerTransitionActive": tabsTransition,
            "selectedControllerTransitionActive": selectedTransition, "presenting": presenting,
            "dismissing": dismissing, "settledSelection": settled]
        return NativeInspection(values: values, settledSelection: settled)
    }
    static func readback() -> String {
        let value: [String: Any] = ["protocol": "task146-t19-tab-observation-v2", "pid": pid,
            "namespace": namespace, "clock": "same-Simulator-boot-systemUptime",
            "capacity": capacity, "dropped": dropped, "requestOrdinal": requestOrdinal,
            "noChangeAssignments": noChangeAssignments, "noChangeAssignmentsCapped": noChangeAssignmentsCapped,
            "marks": marks, "lastProbe": lastProbeSnapshot,
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
