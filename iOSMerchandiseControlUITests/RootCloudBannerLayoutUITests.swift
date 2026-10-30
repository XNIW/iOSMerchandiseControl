import XCTest
import UIKit

/// R23 root geometry and scoped-error regression. Retains the original fresh
/// snapshot/two-sample/5s/1pt oracle. It never releases the held request or Retry.
final class RootCloudBannerLayoutUITests: XCTestCase {
    private var app: XCUIApplication!
    private let bannerIdentifier = "sync.root.foreground.banner"
    private let errorTitle = "Cloud check failed"
    private let errorDetail = "You can retry whenever you want."
    // These are the two intentional external margins in AppSyncRootHost.
    private let fixtureBandIdentifier = "task144.controlled.band"
    private let pointPrecision: CGFloat = 1

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        app?.terminate()
        app = nil
        super.tearDown()
    }

    func testR23QuietRootReservesNoGlobalBannerAndKeepsScopedRecoveryActionsAtDefaultTextSize() throws {
        try verifyQuietRootAndScopedRecovery(category: .large)
    }

    func testR23QuietRootReservesNoGlobalBannerAndKeepsScopedRecoveryActionsAtAccessibilityXXXL() throws {
        try verifyQuietRootAndScopedRecovery(category: .accessibilityExtraExtraExtraLarge)
    }

    private func verifyQuietRootAndScopedRecovery(category: UIContentSizeCategory) throws {
        app = XCUIApplication()
        let namespace = UUID().uuidString.lowercased()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-appLanguage", "en", "-UIPreferredContentSizeCategoryName", category.rawValue]
        app.launchEnvironment = ["TASK144_LOCAL_AVAILABILITY_FIXTURE": namespace,
            "TASK131_INITIAL_TAB": "options", "TASK145_ROOT_PRESENTATION_OBSERVATION": "1"]
        app.launch()
        try requirePresentation(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20), "real-held-recovery")
        if category == .accessibilityExtraExtraExtraLarge {
            try requirePresentation(app.staticTexts["task144.controlled.content-size.accessibility-xxxl"].waitForExistence(timeout: 5), "actual-max-font")
        }
        // Existing fixture control publishes failed outcome followed by checking.
        // It creates no runtime owner; this tests stale progress, not a new error.
        let state = app.descendants(matching: .any).matching(identifier: "task144.controlled.state-update").firstMatch
        try requirePresentation(state.isHittable, "existing-state-control")
        state.press(forDuration: 1.1)
        try requirePresentation(app.staticTexts["task144.controlled.state-updated"].waitForExistence(timeout: 5), "state-control-observed")
        let before = try observePresentation()
        try requirePresentation(before["namespace"] as? String == namespace
            && before["hasActivePresentationInvocation"] as? Bool == false
            && before["phase"] as? String == "checking" && before["outcome"] as? String == "failed",
            "ordinary-checking-without-owned-flight")

        try selectTab("Options")
        let baseline = try settledGeometry(tab: "Options", showsBanner: false)
        let baselineNavigation = try XCTUnwrap(baseline.navigationBar)
        var measurements = [baseline]
        defer { attach(measurements, category: category) }
        for title in ["Database", "History"] {
            try selectTab(title)
            let measured = try settledGeometry(tab: title, showsBanner: false)
            measurements.append(measured)
            try requirePresentation(measured.banner == nil && measured.nativeViewport == baseline.nativeViewport,
                title + "-no-global-band-or-phantom-viewport")
            XCTAssertEqual(measured.controls, baseline.controls)
            XCTAssertEqual(measured.fixtureBand, baseline.fixtureBand)
            XCTAssertEqual(try XCTUnwrap(measured.navigationBar).minY, baselineNavigation.minY, accuracy: pointPrecision)
            try assertOrdinaryRootQuiet()
        }
        try selectTab("Inventory")
        let inventory = try settledGeometry(tab: "Inventory", showsBanner: false)
        measurements.append(inventory)
        XCTAssertEqual(inventory.controls, baseline.controls)
        XCTAssertEqual(inventory.fixtureBand, baseline.fixtureBand)
        XCTAssertEqual(inventory.nativeViewport, baseline.nativeViewport)
        let inventoryTitle = try XCTUnwrap(inventory.inventoryTitle)
        let inventoryScroll = try XCTUnwrap(inventory.inventoryScroll)
        XCTAssertGreaterThanOrEqual(inventoryTitle.minY, inventoryScroll.minY + 28 - pointPrecision)
        XCTAssertLessThanOrEqual(inventoryTitle.maxY, inventory.tabBar.minY + pointPrecision)
        try assertOrdinaryRootQuiet()

        try selectTab("Options")
        let returned = try settledGeometry(tab: "Options", showsBanner: false)
        measurements.append(returned)
        XCTAssertEqual(returned.nativeViewport, baseline.nativeViewport)
        XCTAssertEqual(try XCTUnwrap(returned.navigationBar).minY, baselineNavigation.minY, accuracy: pointPrecision)
        try assertOrdinaryRootQuiet()
        // A scoped failed outcome is retained in its relevant surface. We do not
        // generalize the ordinary no-flight case to "every error is silent".
        let attention = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Automatic sync needs attention")).firstMatch
        let diagnostics = app.buttons["Diagnostics"]
        let deadline = ProcessInfo.processInfo.systemUptime + 15
        var attentionWasReachable = false
        for drag in 0...5 {
            if attention.exists && attention.isHittable { attentionWasReachable = true }
            if attentionWasReachable && diagnostics.isHittable { break }
            guard drag < 5, ProcessInfo.processInfo.systemUptime < deadline else { break }
            app.swipeUp()
        }
        try requirePresentation(attentionWasReachable && diagnostics.isHittable,
            "scoped-error-and-diagnostics-reachable-in-Options")
        diagnostics.tap()
        try requirePresentation(app.buttons["Hide diagnostics"].waitForExistence(timeout: 5), "real-diagnostics-action-opens")
        let after = try observePresentation()
        try requirePresentation(after["presentationID"] as? String == before["presentationID"] as? String
            && after["hasActivePresentationInvocation"] as? Bool == false
            && after["held"] as? Bool == true && after["released"] as? Bool == false,
            "same-presentation-no-invented-owner-no-release")
    }

    private func assertOrdinaryRootQuiet() throws {
        try requirePresentation(app.descendants(matching: .any).matching(identifier: bannerIdentifier).count == 0,
            "no-global-error-checking-banner")
        try requirePresentation(app.descendants(matching: .any).matching(identifier: "sync-root-significant-work").count == 0,
            "no-spinner-for-checking-without-flight")
    }

    private func observePresentation() throws -> [String: Any] {
        let ledger = app.staticTexts["task145.root-presentation.ledger"]
        func parse() -> [String: Any]? {
            guard let value = ledger.value as? String, let bytes = Data(base64Encoded: value) else { return nil }
            return (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any]
        }
        let previous = parse()?["observation"] as? Int ?? 0
        let observe = app.descendants(matching: .any).matching(identifier: "task145.root-presentation.observe").firstMatch
        try requirePresentation(observe.isHittable, "read-only-presentation-control")
        observe.press(forDuration: 1.1)
        let fresh = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in (parse()?["observation"] as? Int ?? 0) > previous }, object: nil)
        try requirePresentation(XCTWaiter.wait(for: [fresh], timeout: 5) == .completed, "fresh-presentation-observation")
        let result = try XCTUnwrap(parse())
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "R23 root current owner and phase"; attachment.lifetime = .keepAlways; add(attachment)
        return result
    }

    private func requirePresentation(_ condition: Bool, _ stage: String, file: StaticString = #filePath, line: UInt = #line) throws {
        if !condition {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "R23 FIRST_FAIL " + stage; hierarchy.lifetime = .keepAlways; add(hierarchy)
            let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.lifetime = .keepAlways; add(screenshot)
        }
        XCTAssertTrue(condition, stage, file: file, line: line)
        if !condition { throw NSError(domain: "Task145.RootPresentation", code: 1, userInfo: [NSLocalizedDescriptionKey: stage]) }
    }

    private func selectTab(_ title: String) throws {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        XCTAssertTrue(tab.isHittable, "The actual root tab must be reachable without scrolling or coordinate taps")
        tab.tap()
        XCTAssertTrue(tab.isSelected)
    }

    private struct SnapshotRegion: Equatable {
        let path: String
        let frame: CGRect
    }

    private struct Geometry: Equatable {
        let tab: String
        let navigationBar: CGRect?
        let banner: CGRect?
        let controls: CGRect
        let fixtureBand: CGRect
        let nativeViewport: CGRect
        let messageFrames: [CGRect]
        let messageLabels: [String]
        let retryFrame: CGRect?
        let tabBar: CGRect
        let inventoryScroll: CGRect?
        let inventoryTitle: CGRect?
    }

    private func settledGeometry(tab: String, showsBanner: Bool) throws -> Geometry {
        var previous: Geometry?
        var settled: Geometry?
        var diagnostics: [String] = []
        var pollCount = 0
        var waitStartedUptime: TimeInterval?
        var waitFinishedUptime: TimeInterval?
        var recordedResult: XCTWaiter.Result?
        var latestCaptureStartedUptime: TimeInterval?
        var latestCaptureFinishedUptime: TimeInterval?
        var diagnosticsEmitted = false
        let emitDiagnostics: (String) -> Void = { [weak self] phase in
            guard let self, !diagnosticsEmitted else { return }
            diagnosticsEmitted = true
            let result = recordedResult.map { String($0.rawValue) } ?? "NOT_RETURNED"
            let start = waitStartedUptime.map { String($0) } ?? "NOT_ARMED"
            let end = waitFinishedUptime.map { String($0) } ?? "NOT_RETURNED"
            let deadline = waitStartedUptime.map { String($0 + 5) } ?? "NOT_ARMED"
            let captureStart = latestCaptureStartedUptime.map { String($0) } ?? "NOT_STARTED"
            let captureEnd = latestCaptureFinishedUptime.map { String($0) } ?? "NOT_RETURNED"
            let contents = "tab=\(tab);showsBanner=\(showsBanner);result=\(result);units=points;polls=\(pollCount);retained=\(diagnostics.count);wait-start=\(start);wait-end=\(end);deadline=\(deadline);latest-capture-start=\(captureStart);latest-capture-end=\(captureEnd);emission-phase=\(phase)\n"
                + diagnostics.joined(separator: "\n")
            let evidence = XCTAttachment(string: contents)
            evidence.name = "Task144 root banner fresh geometry: \(tab)"
            evidence.lifetime = .keepAlways
            self.add(evidence)
            print("TASK144_ROOT_BANNER_GEOMETRY \(contents)")
        }
        // Preserve the existing RAM observations if a native failure prevents
        // the ordinary post-wait emission. Never query the app from teardown.
        addTeardownBlock { emitDiagnostics("teardown") }
        let sampleGeometry: () -> Bool = {
            guard let waitStartedUptime else { return false }
            let deadlineUptime = waitStartedUptime + 5
            let pollStartedUptime = ProcessInfo.processInfo.systemUptime
            guard pollStartedUptime < deadlineUptime else { return false }
            pollCount += 1
            // All frames and the held/selected state come from one fresh
            // hierarchy. Never substitute the title Text's frame for the
            // .contain banner group or carry a failed snapshot forward.
            let captureStartedUptime = ProcessInfo.processInfo.systemUptime
            guard captureStartedUptime < deadlineUptime else { return false }
            latestCaptureStartedUptime = captureStartedUptime
            latestCaptureFinishedUptime = nil
            let captureResult = Result(catching: { try self.app.snapshot() })
            let captureFinishedUptime = ProcessInfo.processInfo.systemUptime
            latestCaptureFinishedUptime = captureFinishedUptime
            let captureTiming = "poll=\(pollCount);poll-start=\(pollStartedUptime);capture-start=\(captureStartedUptime);capture-end=\(captureFinishedUptime);capture-seconds=\(captureFinishedUptime - captureStartedUptime);remaining-before-capture=\(deadlineUptime - captureStartedUptime);remaining-after-capture=\(deadlineUptime - captureFinishedUptime);capture-out-of-window=\(captureFinishedUptime > deadlineUptime)"
            switch captureResult {
            case .success(let snapshot):
                let sample = self.geometry(from: snapshot, tab: tab, showsBanner: showsBanner)
                let matchesPrevious = sample.geometry != nil && previous == sample.geometry
                previous = sample.geometry
                let observationFinishedUptime = ProcessInfo.processInfo.systemUptime
                if diagnostics.count < 16 {
                    diagnostics.append("\(captureTiming);observation-end=\(observationFinishedUptime);remaining-after-observation=\(deadlineUptime - observationFinishedUptime);geometry-valid=\(sample.geometry != nil);stable=\(matchesPrevious);\(sample.diagnostic)")
                }
                guard let geometry = sample.geometry else {
                    return false
                }
                let ready = matchesPrevious && captureFinishedUptime <= deadlineUptime
                    && observationFinishedUptime <= deadlineUptime
                if ready { settled = geometry }
                return ready
            case .failure(let error):
                previous = nil
                let failure = error as NSError
                let observationFinishedUptime = ProcessInfo.processInfo.systemUptime
                if diagnostics.count < 16 {
                    diagnostics.append("\(captureTiming);observation-end=\(observationFinishedUptime);remaining-after-observation=\(deadlineUptime - observationFinishedUptime);snapshot-error-domain=\(failure.domain);code=\(failure.code);prior-cleared=true")
                }
                return false
            }
        }
        let stable = XCTestExpectation(description: "Two fresh complete root geometry samples are stable")
        let start = ProcessInfo.processInfo.systemUptime
        waitStartedUptime = start
        // Each synchronous sample obtains a new hierarchy immediately, without
        // a predicate timer consuming the same five-second observation budget.
        while ProcessInfo.processInfo.systemUptime < start + 5 {
            if sampleGeometry() {
                stable.fulfill()
                break
            }
        }
        let remainingTime = max(0, start + 5 - ProcessInfo.processInfo.systemUptime)
        let result = XCTWaiter.wait(for: [stable], timeout: remainingTime)
        waitFinishedUptime = ProcessInfo.processInfo.systemUptime
        recordedResult = result
        emitDiagnostics("after-wait")
        XCTAssertEqual(result, .completed,
                       "Require one native navigation bar for titled roots, the Inventory scroll/title pair, and no global banner reservation in this no-owned-flight scenario; AX ambiguity is not a layout PASS")
        return try XCTUnwrap(settled, "No two complete stable root geometry samples were observed")
    }

    private func geometry(from root: XCUIElementSnapshot, tab: String, showsBanner: Bool)
        -> (geometry: Geometry?, diagnostic: String) {
        var pending: [(node: XCUIElementSnapshot, scroll: CGRect?, inTabBar: Bool, inBanner: Bool, ancestors: [String], ancestorFrames: [SnapshotRegion], path: String)] = [(root, nil, false, false, [], [], "root")]
        var visited = 0
        var navigation: [CGRect] = []
        var navigationAncestors: [[String]] = []
        var nativeAnchorAncestors: [[SnapshotRegion]] = []
        var tabBarAncestors: [[SnapshotRegion]] = []
        var fixtureBands: [CGRect] = []
        var controlAncestors: [[String]] = []
        var bannerAncestors: [[String]] = []
        var banners: [CGRect] = []
        var bannerIdentities: [String] = []
        var messageFrames: [CGRect] = []
        var messageLabels: [String] = []
        var retries: [CGRect] = []
        var controls: [CGRect] = []
        var tabBars: [CGRect] = []
        var selectedTabs = 0
        var inventoryAnchors: [(scroll: CGRect, title: CGRect)] = []
        var held = false
        var released = false
        while let entry = pending.popLast() {
            let node = entry.node
            visited += 1
            guard visited <= 1_024 else {
                return (nil, "snapshot-incomplete=true;node-cap=1024")
            }
            if node.elementType == .navigationBar {
                navigation.append(node.frame)
                navigationAncestors.append(entry.ancestors)
                if tab != "Inventory" { nativeAnchorAncestors.append(entry.ancestorFrames) }
            }
            let isBanner = node.identifier == bannerIdentifier && node.elementType == .other
            if node.identifier == bannerIdentifier {
                bannerIdentities.append("type=\(node.elementType.rawValue);label=\(node.label);frame=\(node.frame)")
            }
            if isBanner {
                banners.append(node.frame)
                bannerAncestors.append(entry.ancestors)
            }
            if entry.inBanner && node.elementType == .staticText && [errorTitle, errorDetail].contains(node.label) {
                messageFrames.append(node.frame)
                messageLabels.append(node.label)
            }
            if entry.inBanner && node.elementType == .button && node.label == "Retry" { retries.append(node.frame) }
            if node.elementType == .button && node.identifier == "task144.controlled.release" {
                controls.append(node.frame)
                controlAncestors.append(entry.ancestors)
            }
            if node.elementType == .other && node.identifier == fixtureBandIdentifier {
                fixtureBands.append(node.frame)
            }
            if node.elementType == .tabBar {
                tabBars.append(node.frame)
                tabBarAncestors.append(entry.ancestorFrames)
            }
            if entry.inTabBar, node.elementType == .button, node.label == tab, node.isSelected {
                selectedTabs += 1
            }
            if tab == "Inventory", node.elementType == .staticText, node.label == "Inventory",
               let scroll = entry.scroll {
                inventoryAnchors.append((scroll, node.frame))
                nativeAnchorAncestors.append(entry.ancestorFrames)
            }
            if node.identifier == "task144.controlled.held" { held = true }
            if node.identifier == "task144.controlled.released" { released = true }
            let scroll = node.elementType == .scrollView ? node.frame : entry.scroll
            let inTabBar = entry.inTabBar || node.elementType == .tabBar
            let ancestors = entry.ancestors + ["type=\(node.elementType.rawValue);id=\(node.identifier);frame=\(node.frame)"]
            let ancestorFrames = entry.ancestorFrames + (node.elementType == .other
                ? [SnapshotRegion(path: entry.path, frame: node.frame)] : [])
            pending.append(contentsOf: node.children.enumerated().map {
                ($0.element, scroll, inTabBar, entry.inBanner || isBanner, ancestors,
                 ancestorFrames, entry.path + "." + String($0.offset))
            })
        }
        let isInventory = tab == "Inventory"
        var viewports: [CGRect] = []
        if nativeAnchorAncestors.count == 1 && tabBarAncestors.count == 1 {
            // UIKit wrappers repeat the same observed viewport. Require a shared
            // ancestor of the selected content and tab bar; reject ambiguous
            // partial regions rather than selecting the first matching element.
            for region in nativeAnchorAncestors[0] where tabBarAncestors[0].contains(region) {
                let frame = region.frame
                if frame.width > 0 && frame.height > 0 && !viewports.contains(frame) {
                    viewports.append(frame)
                }
            }
            let partial = viewports.filter { $0 != root.frame }
            if !partial.isEmpty { viewports = partial }
        }
        let diagnostic = "fixture-band=\(fixtureBands);native-viewports=\(viewports);navigation=\(navigation);navigation-ancestors=\(navigationAncestors);control-ancestors=\(controlAncestors);banner-ancestors=\(bannerAncestors);inventory-scroll-title=\(inventoryAnchors);banner-identities=\(bannerIdentities);error-message-frames=\(messageFrames);message-labels=\(messageLabels);retry=\(retries);banner-container=\(banners);controls=\(controls);tabBar=\(tabBars);selected=\(selectedTabs);held=\(held);released=\(released)"
        guard (isInventory || navigation.count == 1), controls.count == 1, tabBars.count == 1,
              fixtureBands.count == 1, fixtureBands[0].width > 0, fixtureBands[0].height > 0,
              viewports.count == 1,
              (showsBanner ? viewports[0] != root.frame : viewports[0] == root.frame),
              banners.count == (showsBanner ? 1 : 0), selectedTabs == 1, held, !released,
              (isInventory || navigation[0].height > 0), controls[0].height > 0, tabBars[0].height > 0,
              !isInventory || (inventoryAnchors.count == 1 && inventoryAnchors[0].scroll.height > 0
                              && inventoryAnchors[0].title.height > 0),
              !showsBanner || (banners[0].height > 0 && messageFrames.count == 2 && messageLabels.sorted() == [errorTitle, errorDetail].sorted()
                               && retries.count == 1
                               && retries[0].height > 0 && retries[0].width > 0
                               && messageFrames.allSatisfy({ $0.height > 0 && $0.width > 0 })) else { return (nil, diagnostic) }
        return (Geometry(tab: tab, navigationBar: isInventory ? nil : navigation[0], banner: banners.first,
                         controls: controls[0], fixtureBand: fixtureBands[0], nativeViewport: viewports[0], messageFrames: messageFrames, messageLabels: messageLabels, retryFrame: retries.first, tabBar: tabBars[0],
                         inventoryScroll: inventoryAnchors.first?.scroll,
                         inventoryTitle: inventoryAnchors.first?.title), diagnostic)
    }

    private func assertVisibleErrorBanner(_ sample: Geometry, category: UIContentSizeCategory) throws {
        let banner = try XCTUnwrap(sample.banner)
        let retry = try XCTUnwrap(sample.retryFrame)
        XCTAssertEqual(sample.messageFrames.count, 2, "Both complete public error messages must be exposed in the real banner")
        let bounds = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(banner.minX, bounds.minX - pointPrecision)
        XCTAssertLessThanOrEqual(banner.maxX, bounds.maxX + pointPrecision)
        XCTAssertLessThanOrEqual(banner.maxY, sample.tabBar.minY + pointPrecision,
                                 "The complete banner must leave the real tab bar uncovered")
        for frame in sample.messageFrames + [retry] {
            XCTAssertGreaterThanOrEqual(frame.minX, banner.minX - pointPrecision)
            XCTAssertLessThanOrEqual(frame.maxX, banner.maxX + pointPrecision)
            XCTAssertGreaterThanOrEqual(frame.minY, banner.minY - pointPrecision)
            XCTAssertLessThanOrEqual(frame.maxY, banner.maxY + pointPrecision)
        }
        let retryButton = app.descendants(matching: .other).matching(identifier: bannerIdentifier).buttons["Retry"]
        XCTAssertTrue(retryButton.isHittable, "The public remediation button must remain reachable")
        if category == .accessibilityExtraExtraExtraLarge {
            let messageBottom = try XCTUnwrap(sample.messageFrames.map(\.maxY).max())
            XCTAssertGreaterThanOrEqual(retry.minY, messageBottom - pointPrecision,
                                        "At accessibility text size the action must be on a separate row")
        }
    }

    private func attach(_ measurements: [Geometry], category: UIContentSizeCategory) {
        let frames = measurements.map { sample in
            let banner = sample.banner.map { String(describing: $0) } ?? "hidden"
            let navigation = sample.navigationBar.map { String(describing: $0) } ?? "not-used-for-Inventory"
            let scroll = sample.inventoryScroll.map { String(describing: $0) } ?? "n/a"
            let title = sample.inventoryTitle.map { String(describing: $0) } ?? "n/a"
            return "tab=\(sample.tab);fixture-band=\(sample.fixtureBand);native-viewport=\(sample.nativeViewport);error-messages=\(sample.messageFrames);message-labels=\(sample.messageLabels);retry=\(String(describing: sample.retryFrame));navigation=\(navigation);banner=\(banner);controls=\(sample.controls);tabBar=\(sample.tabBar);Inventory-scroll=\(scroll);Inventory-title=\(title)"
        }.joined(separator: "\n")
        let evidence = XCTAttachment(string: "units=points;requested-category=\(category.rawValue);global-banner-reservation=0;tolerance=1;Inventory-manual-vertical-padding=28;Inventory-shop-header-precedes-title;Inventory-native-bar-comparison=not-applicable\n" + frames)
        evidence.name = "Task144 four-tab actual root banner reservation: \(category.rawValue)"
        evidence.lifetime = .keepAlways
        add(evidence)
    }
}
