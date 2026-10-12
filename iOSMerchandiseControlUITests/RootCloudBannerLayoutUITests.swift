import XCTest
import UIKit

/// Proposed Task144 geometry regression. It uses the production root and the
/// existing held transport; it does not release recovery or mutate business data.
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

    func testHeldRecoveryErrorBannerReservesOnlyItsActualHeightAtDefaultTextSize() throws {
        try verifyRootBannerReservation(category: .large)
    }

    func testHeldRecoveryErrorBannerReservesOnlyItsActualHeightAtAccessibilityXXXL() throws {
        try verifyRootBannerReservation(category: .accessibilityExtraExtraExtraLarge)
    }

    private func verifyRootBannerReservation(category: UIContentSizeCategory) throws {
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-appLanguage", "en", "-UIPreferredContentSizeCategoryName", category.rawValue]
        app.launchEnvironment = ["TASK144_LOCAL_AVAILABILITY_FIXTURE": UUID().uuidString.lowercased(),
                                 "TASK131_INITIAL_TAB": "options"]
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20),
                      "The real same-scope recovery transport must be held before measuring the root")
        if category == .accessibilityExtraExtraExtraLarge {
            XCTAssertTrue(app.staticTexts["task144.controlled.content-size.accessibility-xxxl"]
                .waitForExistence(timeout: 5), "The actual UIKit text category must be accessibility XXXL")
        }

        // Options hides the root banner in the same process and root host.
        // No scrolling is performed, so navigation-bar collapse cannot supply
        // the comparison or compensate for a duplicate reservation.
        try selectTab("Options")
        let baseline = try settledGeometry(tab: "Options", showsBanner: false)
        let baselineNavigation = try XCTUnwrap(baseline.navigationBar)
        var measurements = [baseline]
        defer { attach(measurements, category: category) }

        for title in ["Database", "History"] {
            try selectTab(title)
            let measured = try settledGeometry(tab: title, showsBanner: true)
            measurements.append(measured)
            let banner = try XCTUnwrap(measured.banner,
                                       "The real recovery-error banner AX container must have a measured frame")
            XCTAssertEqual(measured.controls, baseline.controls,
                           "The shared fixture controls must not change their inset between tabs")
            let navigation = try XCTUnwrap(measured.navigationBar)
            try assertVisibleErrorBanner(measured, category: category)
            XCTAssertGreaterThanOrEqual(navigation.minY, measured.nativeViewport.minY,
                                       "Native navigation chrome must stay inside its measured viewport")
            XCTAssertEqual(measured.fixtureBand, baseline.fixtureBand)
            // Compare the actual native viewport edge, not its internal toolbar.
            // The AX outline includes a 1pt stroke; retain the existing 1pt edge
            // precision without subtracting empirically observed constants.
            XCTAssertEqual(banner.minY - measured.fixtureBand.maxY, 4,
                           accuracy: pointPrecision, "Only the intended top margin may precede the banner")
            XCTAssertEqual(measured.nativeViewport.minY - banner.maxY, 2,
                           accuracy: pointPrecision, "Only the intended bottom margin may precede the viewport")
        }

        try selectTab("Inventory")
        let inventory = try settledGeometry(tab: "Inventory", showsBanner: true)
        measurements.append(inventory)
        XCTAssertEqual(inventory.controls, baseline.controls)
        XCTAssertEqual(inventory.fixtureBand, baseline.fixtureBand)
        try assertVisibleErrorBanner(inventory, category: category)
        let inventoryBanner = try XCTUnwrap(inventory.banner)
        XCTAssertEqual(inventoryBanner.minY - inventory.fixtureBand.maxY, 4, accuracy: pointPrecision)
        XCTAssertEqual(inventory.nativeViewport.minY - inventoryBanner.maxY, 2, accuracy: pointPrecision)
        let inventoryScroll = try XCTUnwrap(inventory.inventoryScroll)
        let inventoryTitle = try XCTUnwrap(inventory.inventoryTitle)
        let visibleInventoryTitle = app.scrollViews
            .containing(.staticText, identifier: "Inventory").staticTexts["Inventory"]
        XCTAssertTrue(visibleInventoryTitle.isHittable,
                      "The real Inventory title must remain reachable with the banner present")
        XCTAssertGreaterThanOrEqual(inventoryTitle.minY, inventoryBanner.maxY + 2 - pointPrecision,
                                    "The banner must not cover the Inventory content")
        XCTAssertLessThanOrEqual(inventoryTitle.maxY, inventory.tabBar.minY + pointPrecision,
                                 "The complete Inventory title must remain above the tab bar")
        // Inventory has a manual header inside its root ScrollView, no root
        // navigationTitle. Its 28pt vertical content padding and preceding shop
        // header are intentional contributions, not comparable native bars.
        XCTAssertGreaterThanOrEqual(inventoryTitle.minY, inventoryScroll.minY + 28 - pointPrecision)

        // Returning to the hidden state must remove the entire reservation and
        // keep the same native baseline; no root replacement or relaunch occurs.
        try selectTab("Options")
        let hiddenAgain = try settledGeometry(tab: "Options", showsBanner: false)
        measurements.append(hiddenAgain)
        let hiddenNavigation = try XCTUnwrap(hiddenAgain.navigationBar)
        XCTAssertEqual(hiddenNavigation.minY, baselineNavigation.minY,
                       accuracy: pointPrecision, "Options must retain no phantom banner reservation")
        XCTAssertEqual(hiddenAgain.controls, baseline.controls)
        XCTAssertEqual(hiddenAgain.fixtureBand, baseline.fixtureBand)
        XCTAssertEqual(hiddenAgain.nativeViewport, baseline.nativeViewport,
                       "Returning to hidden must restore the original native viewport")
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
        let stable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            do {
                // All frames and the held/selected state come from one fresh
                // hierarchy. Never substitute the title Text's frame for the
                // .contain banner group or carry a failed snapshot forward.
                let snapshot = try self.app.snapshot()
                let sample = self.geometry(from: snapshot, tab: tab, showsBanner: showsBanner)
                if diagnostics.count < 16 { diagnostics.append(sample.diagnostic) }
                guard let geometry = sample.geometry else {
                    previous = nil
                    return false
                }
                let matchesPrevious = previous == geometry
                previous = geometry
                if matchesPrevious { settled = geometry }
                return matchesPrevious
            } catch {
                previous = nil
                let failure = error as NSError
                if diagnostics.count < 16 {
                    diagnostics.append("snapshot-error-domain=\(failure.domain);code=\(failure.code);prior-cleared=true")
                }
                return false
            }
        }, object: nil)
        let result = XCTWaiter.wait(for: [stable], timeout: 5)
        let evidence = XCTAttachment(string: "tab=\(tab);showsBanner=\(showsBanner);result=\(result.rawValue);units=points\n"
            + diagnostics.joined(separator: "\n"))
        evidence.name = "Task144 root banner fresh geometry: \(tab)"
        evidence.lifetime = .keepAlways
        add(evidence)
        XCTAssertEqual(result, .completed,
                       "Require one native navigation bar for titled roots, the Inventory scroll/title pair, and one .other recovery-error banner container when visible; AX ambiguity is not a layout PASS")
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
        let evidence = XCTAttachment(string: "units=points;requested-category=\(category.rawValue);external-top=4;external-bottom=2;tolerance=1;Inventory-manual-vertical-padding=28;Inventory-shop-header-precedes-title;Inventory-native-bar-comparison=not-applicable\n" + frames)
        evidence.name = "Task144 four-tab actual root banner reservation: \(category.rawValue)"
        evidence.lifetime = .keepAlways
        add(evidence)
    }
}
