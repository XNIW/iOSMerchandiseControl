import XCTest
import UIKit

/// Drives the production App/ContentView/Database/EditProductView. Only the
/// SDK session, RPC transport and isolated file-backed TEST store are controlled.
final class LocalAvailabilityRootUITests: XCTestCase {
    private var app: XCUIApplication!
    private var runID = ""

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        runID = UUID().uuidString.lowercased()
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", UIContentSizeCategory.large.rawValue]
        app.launchEnvironment = ["TASK144_LOCAL_AVAILABILITY_FIXTURE": runID,
                                 "TASK131_INITIAL_TAB": "database"]
    }

    override func tearDown() {
        app.terminate()
        app = nil
        super.tearDown()
    }

    func testRealRootRemainsUsableWithHeldRecoveryAndPreservesSavedAndUnsavedIntentAcrossCutover() {
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20),
                      "The real recovery RPC must enter its held boundary before business input")
        app.tabBars.buttons["Options"].tap()
        app.tabBars.buttons["History"].tap()
        app.tabBars.buttons["Database"].tap()
        let search = app.textFields.matching(NSPredicate(
            format: "identifier == %@ AND label == %@",
            "task140.database.root", "Search by barcode, name, or code"
        )).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("LOCAL-ROOT")
        let row = app.staticTexts["Safe local baseline"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(in: name, with: "Saved before network release")
        assertHeldBoundary()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Saved before network release"].waitForExistence(timeout: 5))
        assertHeldBoundary()
        XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5),
                      "Durable Save must have honest public feedback before network release")
        XCTAssertTrue(app.staticTexts["task144.controlled.local-save-durable"].waitForExistence(timeout: 5),
                      "The fixture must read the real file-backed store with a fresh context while RPC is still held")
        app.staticTexts["Saved before network release"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(in: name, with: "Unsaved second draft")
        XCTAssertEqual(name.value as? String, "Unsaved second draft",
                       "The intended draft must be present before the cloud state update")
        app.buttons["task144.controlled.editor.state-update"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task144.controlled.state-updated"].waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Unsaved second draft", "A sync state update must preserve the actual editor draft")
        assertHeldBoundary()
        let beforeCutover = XCTAttachment(screenshot: app.screenshot())
        beforeCutover.name = "Task144 real unsaved focused editor before cutover"
        beforeCutover.lifetime = .keepAlways
        add(beforeCutover)
        app.buttons["task144.controlled.editor.release"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task144.controlled.released"].waitForExistence(timeout: 5))
        let activated = app.staticTexts["task144.controlled.activated"].waitForExistence(timeout: 20)
        if !activated { captureControlledAutomaticReadback() }
        XCTAssertTrue(activated)
        XCTAssertTrue(name.waitForExistence(timeout: 5), "The production editor must reopen in the new generation")
        XCTAssertEqual(name.value as? String, "Unsaved second draft")
        // Deliver actual keyboard input without tapping or refocusing the field.
        app.typeText(" continued after cutover")
        XCTAssertEqual(name.value as? String, "Unsaved second draft continued after cutover",
                       "The real focused editor must receive keyboard input after generation cutover")
        let afterCutover = XCTAttachment(screenshot: app.screenshot())
        afterCutover.name = "Task144 real preserved editor and focus after cutover"
        afterCutover.lifetime = .keepAlways
        add(afterCutover)
        app.buttons["Cancel"].tap()
        let drained = app.staticTexts["task144.controlled.activated-and-drained"].waitForExistence(timeout: 20)
        if !drained { captureControlledAutomaticReadback() }
        XCTAssertTrue(drained,
                      "Closing the editor must resume the actual automatic queue without a manual sync")
        XCTAssertTrue(app.staticTexts["Cloud confirmed this save"].waitForExistence(timeout: 5),
                      "Only the current record's verified operation ACK may confirm the public Save")
        XCTAssertEqual(search.value as? String, "LOCAL-ROOT")
        XCTAssertTrue(app.tabBars.buttons["Database"].isSelected)
        app.terminate(); app.launch()
        let reopened = app.staticTexts["task144.controlled.reopened"].waitForExistence(timeout: 20)
        if !reopened { captureControlledAutomaticReadback() }
        XCTAssertTrue(reopened)
        XCTAssertTrue(app.staticTexts["Saved before network release"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["task144.controlled.queue-empty-no-duplicates"].exists)
    }

    func testCurrentProductSaveIsCloudConfirmedWhileAnIndependentHistoryIntentRemainsPending() {
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_INDEPENDENT_PENDING"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
        let row = app.staticTexts["Safe local baseline"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(in: name, with: "Saved before network release")
        assertHeldBoundary()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Saved before network release"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["task144.controlled.independent-history-pending"].waitForExistence(timeout: 5),
                      "The independent intent must be durably present before release")
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task144.controlled.activated"].waitForExistence(timeout: 20))
        let ownACK = app.staticTexts["task144.controlled.product-ack-other-pending"].waitForExistence(timeout: 20)
        if !ownACK { captureControlledAutomaticReadback() }
        XCTAssertTrue(ownACK, "Actual product ACK must coexist with the other durable unacknowledged intent")
        XCTAssertTrue(app.staticTexts["Cloud confirmed this save"].waitForExistence(timeout: 5),
                      "Independent pending work must not hide an exact current-record ACK")
        XCTAssertFalse(app.staticTexts["task144.controlled.queue-empty-no-duplicates"].exists)
    }

    func testCurrentProductACKWithIndependentHistorySurvivesImmutableCommittedResponseReplay() {
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_LOSE_FIRST_PRODUCT_RESPONSE"] = "1"
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_INDEPENDENT_PENDING"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
        let row = app.staticTexts["Safe local baseline"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(in: name, with: "Saved before network release")
        assertHeldBoundary()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Saved before network release"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["task144.controlled.independent-history-pending"].waitForExistence(timeout: 5),
                      "The independent intent must be durably present before release")
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task144.controlled.activated"].waitForExistence(timeout: 20))
        // This new lost-response scenario may have no deferred foreground work.
        // Allow the existing 30s automatic safety poll plus 10s UI/transport
        // margin; the original normal-response test retains its 20s budget.
        // No manual Retry, lifecycle change or private runtime trigger is used.
        let ownACK = app.staticTexts["task144.controlled.product-ack-other-pending"].waitForExistence(timeout: 40)
        if !ownACK { captureControlledAutomaticReadback() }
        XCTAssertTrue(ownACK, "Actual product ACK must coexist with the other durable unacknowledged intent")
        XCTAssertTrue(app.staticTexts["Cloud confirmed this save"].waitForExistence(timeout: 5),
                      "Independent pending work must not hide an exact current-record ACK")
        XCTAssertFalse(app.staticTexts["task144.controlled.queue-empty-no-duplicates"].exists)
        let readback = app.buttons["task144.controlled.release"].value as? String ?? ""
        let expected = ["task144.controlled.auto.calls.2.events.1",
            "task144.controlled.independent.attempt-observation-capped.false",
            "task144.controlled.independent.first-product-commit-response-lost.true",
            ".provider-returned.false.", ".provider-returned.true.",
            ".preceding-ack.false.preceding-cas-matches.true.",
            "task144.controlled.independent.predicate.product-ack.true",
            "task144.controlled.independent.predicate.product-fingerprint.true",
            "task144.controlled.independent.predicate.history-status-pending.true",
            "task144.controlled.independent.predicate.product-exact-scope.true",
            "task144.controlled.independent.predicate.history-exact-scope.true",
            "task144.controlled.independent.predicate.single-immutable-product-ack-and-event.true"]
        let incoming = readback.components(separatedBy: ";").filter {
            $0.hasPrefix("task144.controlled.independent.http.")
        }
        let provesBothOriginal = incoming.count == 2 && incoming.allSatisfy {
            $0.contains(".sealed-owner-store-schema-device-valid.true.")
                && $0.contains(".sealed-corresponds.true.")
                && $0.contains(".same-first-id.true.same-first-body.true.same-first-scope.true.same-first-sealed-revision.true")
        }
        if !provesBothOriginal || !expected.allSatisfy({ readback.contains($0) }) {
            captureControlledAutomaticReadback()
        }
        XCTAssertTrue(provesBothOriginal, "Both real incoming bodies must be the same validated sealed Product attempt")
        for fact in expected { XCTAssertTrue(readback.contains(fact), "Missing actual controlled replay fact: \(fact)") }
    }

    func testSaveWithNewSupplierAndCategoryKeepsPublicPendingAndOwnACKFeedback() {
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_RELATED_SAVE"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
        let row = app.staticTexts["Safe local baseline"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(in: name, with: "Saved before network release")
        for (label, value) in [("Supplier name", "New related supplier"), ("Category name", "New related category")] {
            let field = app.textFields[label]
            for _ in 0..<4 where !field.isHittable {
                // Drag the Form's margin, not a TextField or keyboard key.
                // Reverse direction if the preceding drag moved it above the toolbar.
                let aboveToolbar = field.exists && field.frame.maxY < app.buttons["Save"].frame.maxY
                let startY = aboveToolbar ? 0.30 : 0.55
                let endY = aboveToolbar ? 0.55 : 0.30
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: startY))
                    .press(forDuration: 0, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: endY)),
                           withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            if !field.isHittable {
                let input = XCTAttachment(screenshot: app.screenshot())
                input.name = "Task144 relation input setup: \(label)"; input.lifetime = .keepAlways; add(input)
                let hierarchy = XCTAttachment(string: app.debugDescription)
                hierarchy.name = "Task144 relation input native hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
            }
            XCTAssertTrue(field.waitForExistence(timeout: 5)); XCTAssertTrue(field.isHittable)
            field.tap(); field.typeText(value)
            XCTAssertEqual(field.value as? String, value)
        }
        for _ in 0..<4 where !name.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.30))
                .press(forDuration: 0, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.55)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Saved before network release")
        assertHeldBoundary()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Saved before network release"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5))
        let pending = XCTAttachment(screenshot: app.screenshot())
        pending.name = "Task144 actual public Save pending with newly created supplier and category"
        pending.lifetime = .keepAlways; add(pending)
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task144.controlled.activated"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["task144.controlled.related-mapped-product-pending"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5),
                      "Relation ACK metadata must preserve pending feedback before this product's ACK")
        XCTAssertFalse(app.staticTexts["Cloud confirmed this save"].exists)
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        let ownACK = app.staticTexts["task144.controlled.related-save-ack"].waitForExistence(timeout: 20)
        if !ownACK { captureControlledAutomaticReadback() }
        XCTAssertTrue(ownACK, "Real typed relation and product ACKs must be durably present")
        let acknowledged = XCTAttachment(screenshot: app.screenshot())
        acknowledged.name = "Task144 actual public Save after typed supplier category and product ACK"
        acknowledged.lifetime = .keepAlways; add(acknowledged)
        XCTAssertTrue(app.staticTexts["Cloud confirmed this save"].waitForExistence(timeout: 5),
                      "Assigning remote relation IDs must not erase the same Save feedback")
    }

    func testFirstBootstrapWithHeldTransportShowsNavigableHonestEmptyShell() {
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_EMPTY_BOOTSTRAP"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
        for title in ["Options", "History", "Database", "Inventory"] {
            let tab = app.tabBars.buttons[title]
            let tabExists = tab.waitForExistence(timeout: 5)
            if !tabExists { captureControlledAutomaticReadback() }
            XCTAssertTrue(tabExists); tab.tap()
        }
        app.tabBars.buttons["Database"].tap()
        XCTAssertTrue(app.staticTexts["Preparing your catalog…"].waitForExistence(timeout: 5),
                      "A held first snapshot must show preparation, not a trustworthy empty catalog")
        XCTAssertFalse(app.staticTexts["No products"].exists)
        let add = app.buttons["New product"]
        XCTAssertTrue(!add.exists || !add.isEnabled, "No local mutation offer before the first snapshot is qualified")
        let importAction = app.buttons["task140.database.import"]
        XCTAssertTrue(!importAction.exists || !importAction.isEnabled)
        XCTAssertFalse(app.staticTexts["Safe local baseline"].exists)
        XCTAssertFalse(app.staticTexts["task144.controlled.activated-and-drained"].exists)
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task144.controlled.activated"].waitForExistence(timeout: 20),
                      "Complete the isolated empty recovery before leaving its namespace")
    }

    func testEmptyBootstrapRequalifiesAfterPhysicalFenceChangeWithoutScopeOrPhaseChange() {
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_EMPTY_BOOTSTRAP"] = "1"
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_EMPTY_FENCE_REQUALIFICATION"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.tabBars.buttons["Database"].waitForExistence(timeout: 5),
                      "The real root must render its admitted empty shell before file drift")
        app.buttons["task144.controlled.empty-fence.invalidate"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task144.controlled.empty-fence.initially-admitted"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["task144.controlled.empty-fence.invalidated"].waitForExistence(timeout: 5),
                      "The isolated legacy store fence must really change and deny the old proof")
        let requalified = app.staticTexts["task144.controlled.empty-fence.requalified"].waitForExistence(timeout: 10)
        if !requalified { captureControlledAutomaticReadback() }
        XCTAssertTrue(requalified, "A new qualification revision with fresh admission must arrive without Retry or scope/phase change")
        for title in ["Options", "History", "Database", "Inventory"] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        }
        XCTAssertFalse(app.staticTexts["Safe local baseline"].exists)
        XCTAssertFalse(app.staticTexts["task144.controlled.activated-and-drained"].exists)
        assertHeldBoundary()
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task144.controlled.activated"].waitForExistence(timeout: 20))
    }

    func testPreviousShopCallbackCannotInvalidateFreshEmptyRecoveryAdmission() {
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_EMPTY_BOOTSTRAP"] = "1"
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_CALLBACK_ORDER"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.previous-shop-callback-entered"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["task144.controlled.previous-shop-callback-released"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20),
                      "A previous heartbeat callback must not invalidate fresh recovery admission after its checkpoint")
        for title in ["Options", "History", "Database", "Inventory"] {
            let tab = app.tabBars.buttons[title]
            let tabExists = tab.waitForExistence(timeout: 5)
            if !tabExists { captureControlledAutomaticReadback() }
            XCTAssertTrue(tabExists); tab.tap()
        }
        XCTAssertFalse(app.staticTexts["Safe local baseline"].exists)
        XCTAssertFalse(app.staticTexts["task144.controlled.activated-and-drained"].exists)
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task144.controlled.activated"].waitForExistence(timeout: 20))
    }

    func testRealOptionsAndNavigationRemainReadableAtLargeFontInAllFourLanguages() {
        let variants = [
            ("en", "en_US", "Options", "Inventory", "History", "Database", "Cloud account connected"),
            ("it", "it_IT", "Opzioni", "Inventario", "Cronologia", "Database", "Account cloud collegato"),
            ("es", "es_ES", "Opciones", "Inventario", "Historial", "Base de datos", "Cuenta cloud conectada"),
            ("zh", "zh_CN", "选项", "库存", "历史", "数据库", "云账号已连接")
        ]
        for (language, locale, options, inventory, history, database, heading) in variants {
            XCTContext.runActivity(named: "Actual root large-font Options and navigation: \(language)") { _ in
                app = XCUIApplication()
                app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale,
                    "-appLanguage", language, "-UIPreferredContentSizeCategoryName",
                    UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue]
                app.launchEnvironment = ["TASK144_LOCAL_AVAILABILITY_FIXTURE": UUID().uuidString.lowercased(),
                    "TASK131_INITIAL_TAB": "options"]
                app.launch()
                XCTAssertTrue(app.staticTexts["task144.controlled.content-size.accessibility-xxxl"].waitForExistence(timeout: 5),
                              "The native application's actual preferredContentSizeCategory must match the requested public UIKit category")
                XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
                let optionsTab = app.tabBars.buttons[options]
                XCTAssertTrue(optionsTab.waitForExistence(timeout: 5)); optionsTab.tap()
                let email = "l***@long-account-domain.example.invalid"
                let account = app.descendants(matching: .any).matching(NSPredicate(
                    format: "label CONTAINS %@ AND label CONTAINS %@", heading, email)).firstMatch
                for _ in 0..<8 {
                    let top = max(app.navigationBars.firstMatch.frame.maxY,
                                  app.buttons["task144.controlled.release"].frame.maxY) + 12
                    let bottom = app.tabBars.firstMatch.frame.minY - 12
                    if account.exists && account.isHittable,
                       account.frame.minY >= top, account.frame.maxY <= bottom { break }
                    // Scroll the actual target into the center of the visible
                    // region, without momentum or covering it with TEST facts.
                    let height = app.windows.firstMatch.frame.height
                    if !account.exists || account.frame.minY - top > height * 0.7 {
                        app.swipeUp()
                        continue
                    }
                    let targetTop = (top + bottom - account.frame.height) / 2
                    let distance = account.frame.minY - targetTop
                    let delta = min(0.45, max(0.08, abs(distance) / height))
                    let origin: CGFloat = distance < 0 ? 0.3 : 0.7
                    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: origin))
                    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5,
                        dy: distance < 0 ? origin + delta : origin - delta))
                    start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
                }
                let accountExists = account.waitForExistence(timeout: 5)
                let measured = XCTAttachment(screenshot: app.screenshot())
                measured.name = "Task144 actual large-font account before layout assertions \(language)"
                measured.lifetime = .keepAlways
                add(measured)
                let targetReadback = accountExists ? "account=\(account.frame); label=\(account.label)" : "account=absent"
                let layout = XCTAttachment(string: "\(targetReadback); navigation=\(app.navigationBars.firstMatch.frame); tabBar=\(app.tabBars.firstMatch.frame)")
                layout.name = "Task144 actual large-font account layout \(language)"
                layout.lifetime = .keepAlways
                add(layout)
                XCTAssertTrue(accountExists, "The actual translated connected account and privacy-safe email must be exposed")
                XCTAssertTrue(account.isHittable)
                XCTAssertTrue(account.label.contains(heading))
                XCTAssertTrue(account.label.contains(email))
                XCTAssertTrue(app.staticTexts["task144.controlled.swiftui-type.accessibility5"].waitForExistence(timeout: 5),
                              "The actual Options SwiftUI environment must match UIKit's requested accessibility XXXL")
                XCTAssertTrue(app.staticTexts["task144.controlled.account-layout.accessibility-stack"].waitForExistence(timeout: 5))
                let bounds = app.windows.firstMatch.frame
                XCTAssertGreaterThanOrEqual(account.frame.minX, bounds.minX)
                XCTAssertLessThanOrEqual(account.frame.maxX, bounds.maxX)
                XCTAssertGreaterThan(account.frame.height, 70, "The real large-font account heading/email must wrap instead of becoming a one-line truncation")
                XCTAssertGreaterThanOrEqual(account.frame.minY, app.navigationBars.firstMatch.frame.maxY)
                XCTAssertLessThanOrEqual(account.frame.maxY, app.tabBars.firstMatch.frame.minY)
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "Task144 actual Options large font full heading and email \(language)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
                for title in [inventory, database, history, options] {
                    let tab = app.tabBars.buttons[title]
                    XCTAssertTrue(tab.exists); XCTAssertTrue(tab.isHittable)
                    XCTAssertGreaterThanOrEqual(tab.frame.minX, bounds.minX)
                    XCTAssertLessThanOrEqual(tab.frame.maxX, bounds.maxX)
                    tab.tap(); XCTAssertTrue(tab.isSelected)
                }
                app.buttons["task144.controlled.release"].press(forDuration: 1.2)
                let activated = app.staticTexts["task144.controlled.activated"].waitForExistence(timeout: 20)
                if !activated {
                    captureControlledAutomaticReadback()
                    let facts = ["held", "released", "activated", "failure", "failure-kind.scope-changed",
                                 "failure-journal-phase.activated", "failure-new-generation.true", "failure-scope.accepted"]
                        .map { "\($0)=\(app.staticTexts["task144.controlled." + $0].exists)" }.joined(separator: ";")
                    let readback = XCTAttachment(string: facts)
                    readback.name = "Task144 actual four-locale terminal facts \(language)"
                    readback.lifetime = .keepAlways
                    add(readback)
                }
                XCTAssertTrue(activated)
                app.terminate()
            }
        }
    }

    private func assertHeldBoundary(file: StaticString = #filePath, line: UInt = #line) {
        let held = app.staticTexts["task144.controlled.held"].exists
        let released = app.staticTexts["task144.controlled.released"].exists
        if !held || released {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Task144 actual root held-boundary hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Task144 actual root held-boundary screenshot"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertTrue(held, "The controlled RPC must still be held during actual editor input and Save", file: file, line: line)
        XCTAssertFalse(released, "Only the explicit controlled long-press may release recovery", file: file, line: line)
    }

    private func captureControlledAutomaticReadback() {
        let readback = ["task144.controlled.release", "task144.controlled.editor.release"].map { identifier in
            let button = app.buttons[identifier]
            return "\(identifier):\(button.exists ? (button.value as? String ?? "no-value") : "absent")"
        }.joined(separator: "\n")
        let tabs = app.tabBars.buttons.allElementsBoundByIndex.prefix(8).map(\.label).joined(separator: ",")
        let facts = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "task144.controlled."
        )).allElementsBoundByIndex.prefix(32).map(\.label).joined(separator: ";")
        let admission = app.progressIndicators.allElementsBoundByIndex.compactMap { $0.value as? String }
            .first(where: { $0.hasPrefix("task144.controlled.") }) ?? "absent"
        // CI retains stdout even when no xcresult artifact is published. These
        // values are only closed facts from this isolated controlled namespace.
        print("TASK144_CURRENT_FAILURE_READBACK tabs=\(tabs);facts=\(facts);admission=\(admission);\(readback)")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Task144 current native failure hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task144 current native failure screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let attachment = XCTAttachment(string: readback)
        attachment.name = "Task144 actual facade categorical result and bounded TEST counts"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func replaceText(in field: XCUIElement, with value: String) {
        field.tap()
        let current = field.value as? String ?? ""
        if !current.isEmpty {
            // Use the native edit menu rather than typing keyboard glyphs or
            // relying on the caret position chosen by a tap in the field.
            field.press(forDuration: 1.1)
            let selectAll = app.descendants(matching: .any).matching(NSPredicate(
                format: "label == %@ AND (elementType == %d OR elementType == %d)",
                "Select All", XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.menuItem.rawValue
            )).firstMatch
            XCTAssertTrue(selectAll.waitForExistence(timeout: 5), "The native edit menu must select the full existing value")
            selectAll.tap()
        }
        field.typeText(value)
        XCTAssertEqual(field.value as? String, value, "The actual input replacement must be complete")
    }
}
