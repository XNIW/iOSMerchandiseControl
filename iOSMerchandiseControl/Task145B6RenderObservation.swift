import SwiftUI

/// Visible strings supplied by the actual route, not a separate database readback.
/// The helper matches only a manifest-selected projection and a returned receiver commit.
enum Task145B6RenderSubject: Equatable {
    case entity(id: UUID?, kinds: [String], route: String, visibleFields: [String: String])
    case deletion(query: String, emptyMessage: String)
}

#if DEBUG
import UIKit

@MainActor
private enum Task145B6Visibility {
    static weak var queryControl: Task145B6QueryControlBoundary.Control?

    static func qualifies(_ view: UIView) -> Bool {
        guard let window = view.window, window.isKeyWindow, !window.isHidden,
              window.windowScene?.activationState == .foregroundActive,
              !view.bounds.isEmpty, let root = window.rootViewController else { return false }
        let rectangle = view.convert(view.bounds, to: window)
        guard rectangle.width.isFinite, rectangle.height.isFinite,
              window.bounds.contains(rectangle) else { return false }
        var ancestor: UIView? = view
        while let current = ancestor {
            guard !current.isHidden, current.alpha > 0.99 else { return false }
            if current.clipsToBounds,
               !current.bounds.contains(view.convert(view.bounds, to: current)) { return false }
            ancestor = current.superview
        }
        let controller = visibleController(root)
        guard !controller.isBeingDismissed, !controller.isBeingPresented,
              controller.transitionCoordinator == nil,
              let visibleRoot = controller.viewIfLoaded,
              view.isDescendant(of: visibleRoot) else { return false }
        return true
    }

    private static func visibleController(_ controller: UIViewController) -> UIViewController {
        // Keep a dismissing sheet authoritative until UIKit actually removes it.
        if let presented = controller.presentedViewController { return visibleController(presented) }
        if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController {
            return visibleController(visible)
        }
        if let tabs = controller as? UITabBarController, let selected = tabs.selectedViewController {
            return visibleController(selected)
        }
        return controller
    }
}

/// A passive sibling of the real search TextField, used only to qualify deletion.
private struct Task145B6QueryControlBoundary: UIViewRepresentable {
    let query: String
    let validate: @MainActor () -> Bool

    func makeUIView(context: Context) -> Control { Control() }
    func updateUIView(_ view: Control, context: Context) {
        view.query = query; view.validate = validate
        if view.window != nil { Task145B6Visibility.queryControl = view }
    }
    final class Control: UIView {
        var query = ""
        var validate: @MainActor () -> Bool = { false }
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false; isAccessibilityElement = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { Task145B6Visibility.queryControl = self }
            else if Task145B6Visibility.queryControl === self { Task145B6Visibility.queryControl = nil }
        }
    }
}

/// Records a qualified display opportunity after real layout. No product state,
/// query, navigation, refresh, scroll, mutation, or accessibility result is synthesized.
/// External visible-window/AX evidence remains required; this is not scanout proof.
private struct Task145B6RenderBoundary: UIViewRepresentable {
    let subject: Task145B6RenderSubject
    let validate: @MainActor () -> Bool

    func makeUIView(context: Context) -> Boundary { Boundary() }
    func updateUIView(_ view: Boundary, context: Context) {
        view.subject = subject; view.validate = validate
        view.arm()
    }
    static func dismantleUIView(_ view: Boundary, coordinator: ()) { view.stop() }

    final class Boundary: UIView {
        var subject: Task145B6RenderSubject?
        var validate: @MainActor () -> Bool = { false }
        private var link: CADisplayLink?
        private var remainingTicks = 0
        private var commitObserver: NSObjectProtocol?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false; isAccessibilityElement = false
            commitObserver = NotificationCenter.default.addObserver(
                forName: .init("TASK145_B6_RECEIVER_COMMIT_RETURNED"), object: nil, queue: .main
            ) { [weak self] _ in
                // Helper emits only after tD. Re-arm this observer's layout, never the product view.
                MainActor.assumeIsolated { self?.arm() }
            }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        func arm() { remainingTicks = 3; setNeedsLayout() }
        func stop() { link?.invalidate(); link = nil; remainingTicks = 0 }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { stop() } else { arm() }
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            guard PilotCommitTrace.b6RenderObservationEnabled, remainingTicks > 0,
                  window != nil, link == nil else { return }
            let display = CADisplayLink(target: self, selector: #selector(displayOpportunity))
            link = display; display.add(to: .main, forMode: .common)
        }
        @objc private func displayOpportunity() {
            guard remainingTicks > 0 else { stop(); return }
            remainingTicks -= 1
            defer { if remainingTicks == 0 { stop() } }
            guard PilotCommitTrace.b6RenderObservationEnabled, validate(),
                  Task145B6Visibility.qualifies(self), let subject else { return }
            let id: UUID
            let kinds: [String]
            let route: String
            let fields: [String: String]
            switch subject {
            case let .entity(remoteID, candidates, actualRoute, visibleFields):
                guard let remoteID else { return }
                id = remoteID; kinds = candidates; route = actualRoute; fields = visibleFields
            case let .deletion(query, emptyMessage):
                guard let control = Task145B6Visibility.queryControl,
                      control.window === window, control.query == query, control.validate(),
                      Task145B6Visibility.qualifies(control),
                      let candidate = PilotCommitTrace.b6DeletionCandidate(query: query),
                      candidate.barcode == query else { return }
                id = candidate.entityRemoteID; kinds = ["delete"]; route = "database.products.exact-query"
                fields = ["barcodeQuery": query, "resultCount": "0", "emptyMessage": emptyMessage]
            }
            for kind in kinds {
                // Both calls occur here, after layout and commit return. No witness is cached in body.
                guard let witness = PilotCommitTrace.b6RenderWitness(entityRemoteID: id,
                    kind: kind, route: route, visibleFields: fields) else { continue }
                PilotCommitTrace.b6Rendered(witness, ns: DispatchTime.now().uptimeNanoseconds)
            }
        }
        deinit {
            link?.invalidate()
            if let commitObserver { NotificationCenter.default.removeObserver(commitObserver) }
        }
    }
}
#endif

extension View {
    @ViewBuilder
    func task145B6Render(_ subject: @autoclosure @escaping @MainActor () -> Task145B6RenderSubject,
                         validate: @escaping @MainActor () -> Bool) -> some View {
        #if DEBUG
        if PilotCommitTrace.b6RenderObservationEnabled {
            background(Task145B6RenderBoundary(subject: subject(), validate: validate))
        } else { self }
        #else
        self
        #endif
    }

    @ViewBuilder
    func task145B6DeletionQueryControl(_ query: String,
                                      validate: @escaping @MainActor () -> Bool) -> some View {
        #if DEBUG
        if PilotCommitTrace.b6RenderObservationEnabled {
            background(Task145B6QueryControlBoundary(query: query, validate: validate))
        } else { self }
        #else
        self
        #endif
    }
}
