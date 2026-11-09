import XCTest
import UIKit
import ObjectiveC

/// Drives the production App/ContentView/Database/EditProductView. Only the
/// SDK session, RPC transport and isolated file-backed TEST store are controlled.
final class LocalAvailabilityRootUITests: XCTestCase {
    private var app: XCUIApplication!
    private var runID = ""
    private static let r23ItemCodeFieldLabel = "Item code (itemNumber)"
    private var task146OriginalAnimationIdleWait: Bool?

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

    func testTask146OwnedTESTPOSOverviewWhenEnabled() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["TEST_RUNNER_TASK146_B4_IOS_POS_UI"] == "1", "Live TEST POS UI is explicitly gated.")
        guard let target = environment["TEST_RUNNER_TASK146_B4_IOS_TARGET_UDID"].flatMap(UUID.init(uuidString:)),
              environment["SIMULATOR_UDID"].flatMap(UUID.init(uuidString:)) == target,
              let date = environment["TEST_RUNNER_TASK146_B4_IOS_POS_BUSINESS_DATE"],
              date.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil,
              let zone = environment["TEST_RUNNER_TASK146_B4_IOS_POS_TIME_ZONE"],
              TimeZone(identifier: zone) != nil else {
            return XCTFail("Owned simulator and current TEST fixture business date and time zone required.")
        }
        app.launchEnvironment = [:]
        app.launchArguments += ["-appLanguage", "en"]
        app.launch()
        defer { app.terminate() }

        let inventory = app.tabBars.buttons["Inventory"]
        XCTAssertTrue(inventory.waitForExistence(timeout: 20))
        if !inventory.isSelected { inventory.tap() }
        let entry = app.buttons["pos.inventory.entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(entry.isHittable)
        entry.tap()

        let overview = app.scrollViews["pos.overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 20))
        XCTAssertTrue(app.navigationBars["POS sales"].exists)
        let freshness = overview.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label ENDSWITH %@", "Updated at ", " · " + zone)).firstMatch
        XCTAssertTrue(freshness.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(freshness.label.count, "Updated at  · ".count + zone.count)

        if let mode = environment["TEST_RUNNER_TASK146_B4_IOS_POS_MODE"] {
            guard mode == "nonempty-two-stage" else { return XCTFail("Unknown explicitly selected POS mode.") }
            try runOwnedTESTPOSNonemptyTwoStage(environment: environment, target: target,
                                               date: date, zone: zone, overview: overview)
            return
        }

        let day = overview.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS %@", date + ", ", "Transactions: 0")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        let money = NumberFormatter()
        money.locale = Locale(identifier: "en")
        money.numberStyle = .currency
        money.currencyCode = "CLP"
        money.minimumFractionDigits = 0
        money.maximumFractionDigits = 0
        let zero = money.string(from: NSNumber(value: 0)) ?? "CLP 0"
        let fields = day.label.components(separatedBy: ", ")
        XCTAssertEqual(fields.filter { $0 == zero }.count, 4)
        XCTAssertTrue(fields.contains("Transactions: 0"))
        for field in ["Gross sales", "Discounts", "Refunds", "Net revenue"] {
            XCTAssertTrue(fields.contains(field))
        }

        let empty = overview.staticTexts["No sales match these criteria"]
        for _ in 0..<2 where !empty.exists { overview.swipeUp() }
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        XCTAssertEqual(overview.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pos.sale.")).count, 0)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pos.notice.")).count, 0)

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "TASK146 owned TEST POS Overview accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "TASK146 owned TEST POS Overview empty CLP fixture"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }


    private func runOwnedTESTPOSNonemptyTwoStage(environment: [String: String], target: UUID,
                                                date: String, zone: String, overview: XCUIElement) throws {
        let fixtureRun = "bf848326a86a"
        guard environment["TEST_RUNNER_TASK146_B4_IOS_POS_RUN"] == fixtureRun,
              target.uuidString == "3B25E4F5-DCAB-4325-B50F-0951D21DAA9F",
              zone == "America/Santiago",
              let executionID = environment["TEST_RUNNER_TASK146_B4_IOS_POS_EXECUTION_ID"].flatMap(UUID.init(uuidString:)) else {
            return XCTFail("Exact owned synthetic POS cohort and fresh execution UUID required.")
        }
        let execution = executionID.uuidString.lowercased()
        let files = FileManager.default
        let caches = try XCTUnwrap(files.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let checkpoint = caches.appendingPathComponent("TASK146-POS-" + fixtureRun, isDirectory: true)
            .appendingPathComponent(execution, isDirectory: true)
        XCTAssertFalse(files.fileExists(atPath: checkpoint.path), "A POS execution directory must never be reused.")
        try files.createDirectory(at: checkpoint, withIntermediateDirectories: true)
        let stage2URL = checkpoint.appendingPathComponent("stage2.ready")
        let firstSale = "t146-pos-" + fixtureRun + "-s1"
        let secondSale = "t146-pos-" + fixtureRun + "-s2"
        let product = "TASK146 synthetic POS item " + fixtureRun
        let barcode = "T146POS-BF848326A86A-1"
        let money = NumberFormatter()
        money.locale = Locale(identifier: "en"); money.numberStyle = .currency; money.currencyCode = "CLP"
        money.minimumFractionDigits = 0; money.maximumFractionDigits = 0
        func amount(_ value: Int) throws -> String { try XCTUnwrap(money.string(from: NSNumber(value: value))) }
        func capture(_ stage: String) {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "TASK146 POS " + fixtureRun + " " + stage + " AX"
            hierarchy.lifetime = .keepAlways; add(hierarchy)
            let image = XCTAttachment(screenshot: app.screenshot())
            image.name = "TASK146 POS " + fixtureRun + " " + stage
            image.lifetime = .keepAlways; add(image)
        }
        func assertSummary(_ total: Int, transactions: Int) throws {
            let day = overview.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@",
                date + ", ", "Transactions: \(transactions)")).firstMatch
            XCTAssertTrue(day.waitForExistence(timeout: 20), "The actual summary must include the expected current transaction count.")
            let fields = day.label.components(separatedBy: ", ")
            for name in ["Gross sales", "Discounts", "Refunds", "Net revenue"] { XCTAssertTrue(fields.contains(name)) }
            XCTAssertEqual(fields.filter { $0 == (try? amount(total)) }.count, 2)
            XCTAssertEqual(fields.filter { $0 == (try? amount(0)) }.count, 2)
            XCTAssertTrue(fields.contains("Transactions: \(transactions)"))
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pos.notice.")).count, 0)
        }
        func saleButton(_ number: String) -> XCUIElement {
            overview.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                  "pos.sale.", number)).firstMatch
        }
        func openSale(_ number: String, total: Int) throws {
            let row = saleButton(number)
            for _ in 0..<2 where !row.exists || !row.isHittable { overview.swipeUp() }
            XCTAssertTrue(row.waitForExistence(timeout: 5)); XCTAssertTrue(row.isHittable)
            XCTAssertTrue(row.label.contains(number)); XCTAssertTrue(row.label.contains(try amount(total)))
            XCTAssertTrue(row.label.contains("Sale · Accepted"))
            row.tap()
        }
        func assertDetail(_ number: String, total: Int, quantity: String) throws {
            let detail = app.collectionViews["pos.detail"]
            XCTAssertTrue(detail.waitForExistence(timeout: 20))
            let line = detail.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", product, barcode)).firstMatch
            for _ in 0..<2 where !line.exists { detail.swipeUp() }
            XCTAssertTrue(line.waitForExistence(timeout: 5), "Actual sale line snapshots must be presented.")
            let tokens = line.label.components(separatedBy: ", ")
            for token in [product, barcode, "Quantity", quantity, "Unit amount", try amount(1000), "Line amount", try amount(total)] {
                XCTAssertTrue(tokens.contains(token), "Missing exact sale line snapshot token: " + token)
            }
            let sale = detail.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", number)).firstMatch
            for _ in 0..<2 where !sale.exists { detail.swipeDown() }
            XCTAssertTrue(sale.waitForExistence(timeout: 5)); XCTAssertTrue(sale.label.contains(try amount(total)))
            XCTAssertTrue(sale.label.contains("Sale · Accepted"))
            let fresh = detail.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH %@",
                                                               "Updated at ", " · " + zone)).firstMatch
            for _ in 0..<2 where !fresh.exists { detail.swipeUp() }
            XCTAssertTrue(fresh.waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pos.notice.")).count, 0)
        }
        try assertSummary(1500, transactions: 1)
        try openSale(firstSale, total: 1500)
        try assertDetail(firstSale, total: 1500, quantity: "1.5")
        capture("stage1 overview 1500 count1 and detail qty1.5 passed")
        let ready: [String: Any] = ["schema": 1, "run": fixtureRun, "executionID": execution,
            "stage": 1, "businessDate": date, "timeZone": zone, "targetUDID": target.uuidString,
            "saleNumber": firstSale, "amountCLP": 1500, "quantity": "1.5", "count": 1,
            "runnerPID": ProcessInfo.processInfo.processIdentifier,
            "observedUptime": ProcessInfo.processInfo.systemUptime, "checkpointDirectory": checkpoint.path]
        let readyBytes = try JSONSerialization.data(withJSONObject: ready, options: [.sortedKeys])
        try readyBytes.write(to: checkpoint.appendingPathComponent("stage1.ready"), options: .atomic)
        let stage1 = XCTAttachment(data: readyBytes, uniformTypeIdentifier: "public.json")
        stage1.name = "TASK146 POS stage1 verified ordinary UI checkpoint"; stage1.lifetime = .keepAlways; add(stage1)
        print("TASK146_POS_STAGE1_READY " + checkpoint.path)
        // ROOT submits only the already approved second canonical HTTP sale, then
        // writes the exact run-bound acknowledgement in this runner-owned cache.
        func acceptedStage2() -> Bool {
            guard let values = try? stage2URL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 2049) <= 2048,
                  let bytes = try? Data(contentsOf: stage2URL),
                  let receipt = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any] else { return false }
            return (receipt["schema"] as? Int) == 1 && (receipt["run"] as? String) == fixtureRun
                && (receipt["executionID"] as? String) == execution && (receipt["stage"] as? Int) == 2
                && (receipt["businessDate"] as? String) == date && (receipt["timeZone"] as? String) == zone
                && (receipt["saleNumber"] as? String) == secondSale && (receipt["amountCLP"] as? Int) == 500
                && (receipt["expectedTotalCLP"] as? Int) == 2000 && (receipt["expectedCount"] as? Int) == 2
        }
        let stage2 = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in acceptedStage2() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [stage2], timeout: 120), .completed,
                       "No exact ROOT stage2 acknowledgement arrived within 120 seconds; refresh NOT_TRAVERSED.")
        XCTAssertTrue(acceptedStage2())
        let refresh = app.buttons["Refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 5)); XCTAssertTrue(refresh.isHittable); refresh.tap()
        try assertDetail(firstSale, total: 1500, quantity: "1.5")
        capture("stage2 actual Detail Refresh")
        let back = app.buttons["Back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5)); XCTAssertTrue(back.isHittable); back.tap()
        XCTAssertTrue(overview.waitForExistence(timeout: 20))
        for _ in 0..<2 { overview.swipeDown() }
        try assertSummary(2000, transactions: 2)
        try openSale(secondSale, total: 500)
        try assertDetail(secondSale, total: 500, quantity: "0.5")
        capture("stage2 overview 2000 count2 and new sale500 detail qty0.5 passed")
        let final: [String: Any] = ["schema": 1, "run": fixtureRun, "executionID": execution,
            "stage": 2, "businessDate": date, "timeZone": zone, "count": 2, "totalCLP": 2000,
            "firstSale": firstSale, "secondSale": secondSale,
            "runnerPID": ProcessInfo.processInfo.processIdentifier, "observedUptime": ProcessInfo.processInfo.systemUptime]
        let finalBytes = try JSONSerialization.data(withJSONObject: final, options: [.sortedKeys])
        try finalBytes.write(to: checkpoint.appendingPathComponent("stage2.verified"), options: .atomic)
        let finished = XCTAttachment(data: finalBytes, uniformTypeIdentifier: "public.json")
        finished.name = "TASK146 POS two-stage ordinary UI verified"; finished.lifetime = .keepAlways; add(finished)
    }

    func testActualStoreLoadFailureKeepsFourTabsAndSafeOptionsWithoutBusinessConsumers() throws {
        app.launchEnvironment["TASK145_SAFE_STORE_FAILURE_UI"] = "malformed-manifest"
        app.launch()
        var completed = false
        func captureFailure() {
            if !completed {
                let hierarchy = XCTAttachment(string: app.debugDescription)
                hierarchy.name = "safe-store-failure-FIRST-FAIL-hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "safe-store-failure-FIRST-FAIL"; screenshot.lifetime = .keepAlways; add(screenshot)
            }
        }
        func require(_ condition: Bool, _ message: String = "safe-store-failure prerequisite", file: StaticString = #filePath, line: UInt = #line) {
            if !condition { captureFailure() }
            XCTAssertTrue(condition, message, file: file, line: line)
        }
        require(app.staticTexts["task145.safe-store-failure.actual-load-caught"].waitForExistence(timeout: 10))
        let ledger = app.staticTexts["task145.safe-store-failure.ledger"]
        func readLedger() throws -> [String: Any] {
            let encoded = try XCTUnwrap(ledger.value as? String)
            let data = try XCTUnwrap(Data(base64Encoded: encoded))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        func assertNoBusiness(_ value: [String: Any]) {
            if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
                let observation = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                observation.name = "safe-store-load-before-oracle"; observation.lifetime = .keepAlways; add(observation)
            }
            XCTAssertEqual(value["namespace"] as? String, runID)
            XCTAssertEqual(value["failureCode"] as? String, "sync_store_generation_load_failed")
            XCTAssertEqual(value["repositoryLoad"] as? Int, 1)
            XCTAssertEqual(value["invalidManifestCaught"] as? Int, 1)
            XCTAssertEqual(value["otherLoadFailureCaught"] as? Int, 0)
            XCTAssertEqual(value["businessRootConstructed"] as? Int, 0)
            XCTAssertEqual(value["optionsBusinessRead"] as? Int, 0)
            XCTAssertEqual(value["malformedManifestPreserved"] as? Bool, true)
            XCTAssertEqual(value["manifestAbsent"] as? Bool, true)
            require(!app.staticTexts["Safe local baseline"].exists)
            require(!app.staticTexts["Local database is empty"].exists)
            require(!app.buttons["Sign in"].exists)
        }
        let before = try readLedger(); assertNoBusiness(before)
        for title in ["Inventory", "Database", "History", "Options"] {
            let tab = app.tabBars.buttons[title]
            require(tab.waitForExistence(timeout: 5) && tab.isHittable, "reachable \(title)")
        }
        for title in ["Inventory", "Database", "History"] {
            let tab = app.tabBars.buttons[title]; tab.tap()
            require(tab.isSelected)
            require(app.staticTexts["Local data unavailable"].waitForExistence(timeout: 5))
            require(!app.staticTexts["Local database is empty"].exists)
        }
        app.tabBars.buttons["Options"].tap()
        require(app.navigationBars["Options"].waitForExistence(timeout: 5))
        let safeRoot = app.descendants(matching: .any).matching(identifier: "options.safe.root").firstMatch
        require(safeRoot.waitForExistence(timeout: 5))
        let details = app.descendants(matching: .any).matching(identifier: "options.safe.diagnostics").firstMatch
        require(details.waitForExistence(timeout: 5) && details.isHittable); details.tap()
        let failureCode = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@",
            "options.safe.diagnostics", "Code, sync_store_generation_load_failed"))
        require(failureCode.element.waitForExistence(timeout: 5) && failureCode.count == 1)
        require(app.staticTexts["Cloud account connected"].waitForExistence(timeout: 5))
        for _ in 0..<3 where !app.staticTexts["Theme"].isHittable { app.swipeUp() }
        require(app.staticTexts["Theme"].isHittable)
        for _ in 0..<3 where !app.staticTexts["Language"].isHittable { app.swipeUp() }
        require(app.staticTexts["Language"].isHittable)
        let observe = app.descendants(matching: .any).matching(identifier: "task145.safe-store-failure.observe").firstMatch
        require(observe.exists && observe.isHittable); observe.press(forDuration: 1.1)
        let previous = try XCTUnwrap(before["observation"] as? Int)
        let fresh = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let current = try? readLedger(), let ordinal = current["observation"] as? Int else { return false }
            return ordinal > previous
        }, object: nil)
        require(XCTWaiter.wait(for: [fresh], timeout: 5) == .completed)
        let after = try readLedger(); assertNoBusiness(after)
        XCTAssertEqual(after["signedIn"] as? Bool, true)
        let evidence = XCTAttachment(data: try JSONSerialization.data(withJSONObject: ["before": before, "after": after], options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        evidence.name = "safe-store-load-failure-qualified-observations"; evidence.lifetime = .keepAlways; add(evidence)
        completed = true
    }

    func testTransientSDKStorageReadFailureKeepsLocalOptionsAndSaveUntilActualLogout() throws {
        app.launchEnvironment["TASK145_AUTH_STORAGE_UI"] = "cached-read-failure"
        app.launch()
        func require(_ condition: Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
            if !condition {
                let hierarchy = XCTAttachment(string: app.debugDescription)
                hierarchy.name = "T13-FIRST-FAIL-" + message; hierarchy.lifetime = .keepAlways; add(hierarchy)
                let screen = XCTAttachment(screenshot: app.screenshot()); screen.lifetime = .keepAlways; add(screen)
            }
            XCTAssertTrue(condition, message, file: file, line: line)
        }
        func control(_ name: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: "task145.t13." + name).firstMatch
        }
        func readLedger() throws -> [String: Any] {
            let value = try XCTUnwrap(app.staticTexts["task145.t13.ledger"].value as? String)
            let bytes = try XCTUnwrap(Data(base64Encoded: value))
            let observation = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
            observation.name = "T13-fresh-observation"; observation.lifetime = .keepAlways; add(observation)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        }
        func pressAndObserve(_ name: String) {
            func ordinal() -> Int? {
                guard let value = app.staticTexts["task145.t13.ledger"].value as? String,
                      let bytes = Data(base64Encoded: value),
                      let payload = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return nil }
                return payload["observation"] as? Int
            }
            let before = ordinal() ?? 0
            require(control(name).isHittable, "reachable-" + name)
            control(name).press(forDuration: 1.1)
            let fresh = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in (ordinal() ?? 0) > before }, object: nil)
            require(XCTWaiter.wait(for: [fresh], timeout: 5) == .completed, "fresh-observation-" + name)
        }
        require(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20), "qualified-held-recovery")
        require(control("storage-fault").isHittable, "controlled-storage-fault-reachable")
        pressAndObserve("storage-fault")
        require(app.staticTexts["task145.t13.storage-read-held"].waitForExistence(timeout: 5), "actual-SDK-storage-read-held")
        let fault = try readLedger()
        require(fault["SDKSessionNil"] as? Bool == true && fault["appSessionNil"] as? Bool == true
            && fault["isSignedIn"] as? Bool == false, "SDK-nil-does-not-manufacture-cloud-auth")
        require(fault["sameGeneration"] as? Bool == true && fault["generationAccepted"] as? Bool == true
            && fault["storedBytesUnchanged"] as? Bool == true, "same-generation-bytes-preserved")
        require(fault["hasLocalOwner"] as? Bool == true && fault["localCapability"] as? Bool == true,
            "accepted-owner-keeps-qualified-local-capability")
        app.tabBars.buttons["Options"].tap()
        require(app.navigationBars["Options"].waitForExistence(timeout: 5), "actual-Options-opened")
        require(!app.buttons["Sign in"].exists, "Options-has-no-false-login")
        require(!app.staticTexts["Local database is empty"].exists, "Options-has-no-false-empty")
        app.tabBars.buttons["Database"].tap()
        let row = app.staticTexts["Safe local baseline"]
        require(row.waitForExistence(timeout: 5) && row.isHittable, "local-row-readable-with-SDK-nil")
        row.tap()
        let name = app.textFields["task144.product.name"]
        require(name.waitForExistence(timeout: 5), "real-local-editor")
        replaceText(in: name, with: "Saved before network release")
        app.buttons["Save"].tap()
        require(app.staticTexts["Saved before network release"].waitForExistence(timeout: 5), "real-Save-dismissed")
        require(app.staticTexts["task144.controlled.local-save-durable"].waitForExistence(timeout: 5), "fresh-durable-Save-readback")
        pressAndObserve("observe")
        let saved = try readLedger()
        require(saved["freshSavedProduct"] as? Bool == true && saved["freshPendingIntent"] as? Bool == true
            && saved["readFailure"] as? Bool == false, "fresh-product-plus-intent-after-real-Save")
        require(saved["SDKSessionNil"] as? Bool == true && saved["storedBytesUnchanged"] as? Bool == true
            && saved["catalogEntries"] as? Int == 0 && saved["authHTTPEntries"] as? Int == 0,
            "Save-is-local-while-SDK-read-stays-held")
        app.tabBars.buttons["Options"].tap()
        require(app.navigationBars["Options"].waitForExistence(timeout: 5), "Options-before-logout")
        require(!app.buttons["Sign in"].exists, "still-no-false-login-before-restoration")
        pressAndObserve("storage-restore")
        let restored = try readLedger()
        require(restored["isSignedIn"] as? Bool == true && restored["storedBytesUnchanged"] as? Bool == true,
            "same-SDK-session-readable-again")
        let signOut = app.buttons["Sign out"]
        r4Reveal(signOut)
        require(signOut.isHittable && signOut.isEnabled, "real-Options-Sign-out-action")
        signOut.tap()
        let signedOut = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !signOut.exists && self.app.buttons["Sign in"].exists
        }, object: nil)
        require(XCTWaiter.wait(for: [signedOut], timeout: 5) == .completed, "real-local-logout-published")
        pressAndObserve("observe")
        let retired = try readLedger()
        require(retired["generationAccepted"] as? Bool == false && retired["hasLocalOwner"] as? Bool == false
            && retired["localCapability"] as? Bool == false, "logout-revoked-cached-local-identity")
        require(retired["writerEnteredAfterLogout"] as? Bool == false
            && retired["writerDeniedAfterLogout"] as? Bool == true, "real-writer-denied-after-logout")
        app.tabBars.buttons["Database"].tap()
        require(!app.staticTexts["Saved before network release"].exists
            && !app.textFields["task144.product.name"].exists, "logout-removes-business-consumer")
    }

    override func tearDown() {
        if (testRun?.failureCount ?? 0) > 0, app?.state == .runningForeground {
            if app.launchEnvironment["TASK146_BASE_ROOT_RUNTIME_OBSERVATION"] == "1" {
                // The primary XCTest failure is already recorded. Read the one
                // existing UIKit getter before the broader central capture.
                let nodes = app.otherElements.matching(identifier: "task144.controlled.native-name-observation")
                let count = nodes.count
                let raw = count == 1 ? (nodes.element.value as? String ?? "MISSING_VALUE")
                    : "NON_UNIQUE_OR_MISSING_NATIVE_GETTER count=\(count)"
                let witness = XCTAttachment(string: raw.utf8.count <= 8192 ? raw : "NATIVE_RUNTIME_BYTE_LIMIT")
                witness.name = "BaseRoot FIRST_FAIL current runtime read-only"
                witness.lifetime = .keepAlways; add(witness)
            }
            captureControlledAutomaticReadback()
        }
        app.terminate()
        if let original = task146OriginalAnimationIdleWait {
            let before = (app.value(forKey: "idleAnimationWaitEnabled") as? NSNumber)?.boolValue
            app.setValue(NSNumber(value: original), forKey: "idleAnimationWaitEnabled")
            let after = (app.value(forKey: "idleAnimationWaitEnabled") as? NSNumber)?.boolValue
            task146OriginalAnimationIdleWait = nil
            let proof = XCTAttachment(string: "TASK146 runner-only per-instance animation-idle setting; "
                + "app animations and original main-loop wait retained; original=\(original); "
                + "beforeRestore=\(String(describing: before)); afterRestore=\(String(describing: after))")
            proof.name = "TASK146 animation-idle driver restoration"; proof.lifetime = .keepAlways; add(proof)
            XCTAssertEqual(before, Optional(false), "TASK146 runner animation-idle setting changed during its owned witness")
            XCTAssertEqual(after, Optional(original), "TASK146 runner animation-idle setting was not restored")
        }
        app = nil
        super.tearDown()
    }

    /// Runner-only, per-instance private SDK setting for the two long witnesses.
    /// App animations stay enabled; native events and original main-loop waits
    /// remain in force. Unknown SDK selectors, ABI or KVC behavior fail admission.
    private func task146ConfigureAnimationIdleDriver() throws {
        let unsupported = NSError(domain: "Task146AnimationIdleDriver", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Unsupported private XCTest animation-idle ABI or KVC behavior; witness not admitted."])
        guard let application = app else { throw unsupported }
        if task146OriginalAnimationIdleWait != nil {
            guard (application.value(forKey: "idleAnimationWaitEnabled") as? NSNumber)?.boolValue == false else {
                throw unsupported
            }
            return // This same test already owns the admitted setting and teardown restoration.
        }
        let getter = NSSelectorFromString("isIdleAnimationWaitEnabled")
        let setter = NSSelectorFromString("setIdleAnimationWaitEnabled:")
        let valueForKey = NSSelectorFromString("valueForKey:")
        let setValueForKey = NSSelectorFromString("setValue:forKey:")
        let type = object_getClass(application)
        let getterResponds = application.responds(to: getter)
        let setterResponds = application.responds(to: setter)
        let alternateGetter = application.responds(to: NSSelectorFromString("getIdleAnimationWaitEnabled"))
            || application.responds(to: NSSelectorFromString("idleAnimationWaitEnabled"))
        let getterType = class_getInstanceMethod(type, getter).flatMap { method_getTypeEncoding($0) }
            .map { String(cString: $0) }
        let setterType = class_getInstanceMethod(type, setter).flatMap { method_getTypeEncoding($0) }
            .map { String(cString: $0) }
        let defaultKVCGetter = class_getInstanceMethod(NSObject.self, valueForKey)
        let defaultKVCSetter = class_getInstanceMethod(NSObject.self, setValueForKey)
        let inheritedKVCGetter = defaultKVCGetter != nil
            && class_getInstanceMethod(type, valueForKey) == defaultKVCGetter
        let inheritedKVCSetter = defaultKVCSetter != nil
            && class_getInstanceMethod(type, setValueForKey) == defaultKVCSetter
        let proof = XCTAttachment(string: "TASK146 private runner-only animation-idle admission; witness=\(name); "
            + "classPresent=\(type != nil); getterResponds=\(getterResponds); setterResponds=\(setterResponds); "
            + "getterEncoding=\(getterType ?? "absent"); setterEncoding=\(setterType ?? "absent"); "
            + "alternateGetter=\(alternateGetter); NSObjectKVCGetter=\(inheritedKVCGetter); NSObjectKVCSetter=\(inheritedKVCSetter)")
        proof.name = "TASK146 animation-idle driver ABI admission"; proof.lifetime = .keepAlways; add(proof)
        guard task146OriginalAnimationIdleWait == nil, type != nil,
              getterResponds, setterResponds, !alternateGetter,
              getterType == "B16@0:8", setterType == "v20@0:8B16",
              inheritedKVCGetter, inheritedKVCSetter,
              let original = application.value(forKey: "idleAnimationWaitEnabled") as? NSNumber else { throw unsupported }
        task146OriginalAnimationIdleWait = original.boolValue
        application.setValue(NSNumber(value: false), forKey: "idleAnimationWaitEnabled")
        guard (application.value(forKey: "idleAnimationWaitEnabled") as? NSNumber)?.boolValue == false else {
            // tearDown still restores the saved original after this admission failure.
            throw unsupported
        }
    }

// TASK145_T14_INSERT_BEGIN native-long-use-witness
    private var t14ReadCount = 0
    private var t14LastAppUptime: TimeInterval = 0
    private var t14AppPID: Int?
    private var t14FailureCaptured = false
    private var t14EditorOpen = false

    /// Controlled native long-use subcase only. Review Cancel remains the
    /// separately qualified short C1 case, not part of these 600 seconds.
    func testTenMinuteNormalUseDuringHeldRecoveryPreservesNativeEditorAndResumesAfterQuietGap() throws {
        try task146ConfigureAnimationIdleDriver()
        var witnessCompleted = false
        defer {
            if !witnessCompleted && !t14FailureCaptured {
                t14FailureCaptured = true
                t14Capture("FIRST_FAIL uncaught observation or native prerequisite error; downstream NOT_TRAVERSED", screenshot: true)
            }
        }
        app.launchEnvironment["TASK145_T14_OBSERVATION"] = "1"
        app.launch()
        guard (app.value(forKey: "idleAnimationWaitEnabled") as? NSNumber)?.boolValue == false else {
            throw NSError(domain: "Task146AnimationIdleDriver", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Private XCTest animation-idle setting missing or reset after initial launch; witness not admitted."])
        }
        try t14Require(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20), "qualified-held-page")
        let initial = try t14Observe("qualified-held-page-before-t0")
        let startApp = try t14Number(initial["uptime"], "initial-app-uptime")
        let startUTC = try t14Number(initial["utc"], "initial-app-utc")
        let startRunner = ProcessInfo.processInfo.systemUptime
        let initialTick = t14DefaultNumber(initial, "sync.runtime.timer.lastTickAt")
        let initialRequest = t14DefaultNumber(initial, "sync.runtime.foreground.requestedAt")
        var freshTick = false
        var freshBusyDeferral = false
        var scrollMoved = false
        t14Capture("t0 real held recovery; initial producer is fixture Atomic, not coordinator admission", screenshot: true)

        let search = app.textFields.matching(NSPredicate(format: "identifier == %@ AND label == %@",
            "task140.database.root", "Search by barcode, name, or code")).firstMatch
        try t14Require(search.waitForExistence(timeout: 5) && search.isHittable, "native-search")
        search.tap(); search.typeText("LOCAL-ROOT")
        let savedName = "Saved before network release"
        let row = app.staticTexts["Safe local baseline"]
        try t14Require(row.waitForExistence(timeout: 5) && row.isHittable, "open-real-A-editor")
        row.tap()
        let name = app.textFields["task144.product.name"]
        try t14Require(name.waitForExistence(timeout: 5), "real-name-field")
        positionNameInEditorViewport(name)
        replaceText(in: name, with: savedName)
        try t14Require(app.staticTexts["task144.controlled.held"].exists, "held-before-single-Save-A")
        app.buttons["Save"].tap()
        try t14Require(app.staticTexts[savedName].waitForExistence(timeout: 5), "Save-A-dismissed")
        try t14Require(app.staticTexts["task144.controlled.local-save-durable"].waitForExistence(timeout: 5)
            && app.staticTexts["task144.controlled.held"].exists, "fresh-file-backed-Save-A-readback-while-held")
        try t14Require(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].exists,
            "honest-Save-A-feedback-before-release")
        // Finish the normal search before shell visits; its restored keyboard covers the tabs.
        if app.keyboards.count > 0 {
            try t14Require(search.value as? String == "LOCAL-ROOT" && search.isHittable,
                "search-before-shell-use")
            search.typeText("\n")
            let keyboardHidden = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
            try t14Require(XCTWaiter.wait(for: [keyboardHidden], timeout: 5) == .completed,
                "search-keyboard-hidden-before-shell-use")
        }
        let draft = "Unsaved second draft"

        for segment in 0..<30 {
            try t14Require(app.staticTexts["task144.controlled.held"].exists, "segment-\(segment)-still-held")
            if segment < 6 {
                // These are actual shell visits before the final modal editor.
                // They do not pretend a tab tap traverses a presented editor.
                for title in ["Options", "History", "Database"] {
                    let tab = app.tabBars.buttons[title]
                    try t14Require(tab.waitForExistence(timeout: 5) && tab.isHittable, "segment-\(segment)-\(title)-reachable")
                    tab.tap()
                    try t14Require(tab.isSelected, "segment-\(segment)-\(title)-selected")
                    try t14Require(app.alerts.count == 0, "segment-\(segment)-no-network-modal")
                }
                try t14Require(search.value as? String == "LOCAL-ROOT"
                    && app.staticTexts[savedName].exists, "segment-\(segment)-query-and-saved-row")
            } else {
                if segment == 6 {
                    let saved = app.staticTexts[savedName]
                    try t14Require(saved.exists && saved.isHittable, "reopen-A-after-shell-use")
                    saved.tap()
                    try t14Require(name.waitForExistence(timeout: 5), "final-editor-real-name")
                    t14EditorOpen = true
                    positionNameInEditorViewport(name)
                    replaceText(in: name, with: draft)
                }
                try t14Require(name.exists && name.value as? String == draft, "segment-\(segment)-draft-before-input")
                app.typeText("x")
                try t14Require(name.value as? String == draft + "x", "segment-\(segment)-native-input-without-retap")
                app.typeText(XCUIKeyboardKey.delete.rawValue)
                try t14Require(name.value as? String == draft, "segment-\(segment)-native-delete-restores-draft")
                if segment == 6 || segment == 16 || segment == 26 {
                    scrollMoved = try t14ScrollRoundTrip(name, expected: draft, stage: "segment-\(segment)") || scrollMoved
                }
            }
            let observed = try t14Observe("normal-use-segment-\(segment)")
            if segment >= 6 { try t14Editor(observed, expected: draft, stage: "segment-\(segment)") }
            if let tick = t14DefaultNumber(observed, "sync.runtime.timer.lastTickAt"), tick >= startUTC,
               initialTick == nil || tick != initialTick { freshTick = true }
            if segment >= 6, let requested = t14DefaultNumber(observed, "sync.runtime.foreground.requestedAt"), requested >= startUTC,
               initialRequest == nil || requested != initialRequest,
               let source = t14DefaultString(observed, "sync.runtime.foreground.source"), !source.isEmpty,
               let outcome = t14DefaultString(observed, "sync.runtime.foreground.outcome"),
               (["deferred_busy", "deferred_existing_task", "deferred_runtime_busy", "deferred_store_replacement"].contains(outcome)
                || (outcome == "recovery_required_preserved" && t14HeldRecoveryGuardIsCurrent(observed))) {
                // The controlled initial Atomic owner may leave the ordinary
                // coordinator preserving its exact pending recovery. This is a
                // recovery-guard witness, not necessarily the UI-busy branch.
                freshBusyDeferral = true
            }
            // Short bounded pacing between real actions is not the witness:
            // actual elapsed, native input and fresh observations are required.
            let segmentEnd = startRunner + Double(segment + 1) * 20
            while ProcessInfo.processInfo.systemUptime < segmentEnd {
                RunLoop.current.run(until: Date().addingTimeInterval(min(1, segmentEnd - ProcessInfo.processInfo.systemUptime)))
            }
        }
        try t14Require(ProcessInfo.processInfo.systemUptime - startRunner >= 600, "actual-runner-monotonic-600s")
        let elapsed = try t14Observe("normal-use-600s-app-clock")
        try t14Require(try t14Number(elapsed["uptime"], "elapsed-app-uptime") - startApp >= 600,
            "actual-app-monotonic-600s-same-PID")
        try t14Require(freshTick && freshBusyDeferral, "fresh-current-run-scheduler-tick-and-busy-deferral")
        try t14Require(scrollMoved, "native-editor-scroll-offset-really-moved")

        try t14SelectAll(name, expected: draft)
        let before = try t14StableEditor(expected: draft, stage: "before-cutover")
        try t14Require(try t14Number(before["selectionStart"], "before-selection-start") == 0
            && t14Number(before["selectionEnd"], "before-selection-end") == Double(draft.utf16.count),
            "native-meaningful-selected-range-before-cutover")
        let oldGeneration = try XCTUnwrap(before["activeManifestGeneration"] as? String)
        let beforeReleaseAppUptime = try t14Number(before["uptime"], "before-release-app-clock")
        t14Capture("600s meaningful selection, focused unsaved draft, measured scroll before release", screenshot: true)
        try t14Require(app.staticTexts["task144.controlled.held"].exists, "release-only-after-long-use")
        let release = app.buttons["task144.controlled.editor.release"]
        try t14Require(release.exists && release.isHittable, "existing-availability-only-release-control")
        release.press(forDuration: 1.2)
        try t14Require(app.staticTexts["task144.controlled.released"].waitForExistence(timeout: 5), "availability-released")
        try t14Require(app.staticTexts["task144.controlled.activated"].waitForExistence(timeout: 20), "real-generation-published")
        try t14Require(name.waitForExistence(timeout: 5), "real-editor-after-publish")
        let after = try t14StableEditor(expected: draft, stage: "after-cutover")
        try t14Require(after["activeManifestGeneration"] as? String != oldGeneration, "actual-new-generation")
        try t14Require(try t14EditorGeometry(before) == t14EditorGeometry(after), "equivalent-keyboard-and-scroll-geometry-across-cutover")
        try t14Require(try t14ScrollPosition(before) == t14ScrollPosition(after), "scroll-offset-preserved-across-cutover")
        try t14Require(try t14Number(after["selectionStart"], "after-selection-start") == t14Number(before["selectionStart"], "before-selection-start")
            && t14Number(after["selectionEnd"], "after-selection-end") == t14Number(before["selectionEnd"], "before-selection-end"),
            "native-selection-preserved-across-cutover")
        // The selected range must still receive real input without a focus tap.
        let continued = " continued after cutover"
        app.typeText(continued)
        try t14Require(name.value as? String == continued, "selected-draft-receives-input-without-retap")
        t14Capture("preserved selection/focus/scroll and actual input after cutover", screenshot: true)
        let beforeCancel = try t14Observe("last-editor-readback-before-real-Cancel")
        try t14Editor(beforeCancel, expected: continued, stage: "before-Cancel")
        let pendingBeforeClose = try XCTUnwrap(t14ReadbackBool(beforeCancel, "pendingSaveA"))
        let acknowledgedBeforeClose = try XCTUnwrap(t14ReadbackBool(beforeCancel, "terminalSaveA"))
        try t14Require(pendingBeforeClose != acknowledgedBeforeClose,
            "fresh-Save-A-is-exactly-pending-or-own-ACK-before-editor-close")
        if acknowledgedBeforeClose {
            // TASK-146 permits automatic work while a value draft is open.
            // An early ACK still needs the current physical store and counts.
            try t14RequireTerminalProof(beforeCancel, after: beforeReleaseAppUptime)
        } else {
            let runtime = try XCTUnwrap(beforeCancel["runtime"] as? [String: Any])
            try t14Require(runtime["terminalPublished"] as? Bool == false,
                "pending-Save-A-has-no-published-terminal-before-editor-close")
        }
        let lastInputStarted = ProcessInfo.processInfo.systemUptime
        app.buttons["Cancel"].tap()
        let quietStarted = ProcessInfo.processInfo.systemUptime
        t14EditorOpen = false
        // No input, availability control or manual sync after this real Cancel.
        let quietBoundary = try t14Observe("first-post-Cancel-app-clock-quiet-boundary")
        let quietAppUptime = try t14Number(quietBoundary["uptime"], "actual-post-Cancel-app-clock")
        let drained = app.staticTexts["task144.controlled.activated-and-drained"]
        try t14Require(drained.waitForExistence(timeout: 20), "ordinary-successor-after-activity-and-quiet")
        try t14Require(app.staticTexts["task144.controlled.queue-empty-no-duplicates"].exists,
            "existing-terminal-exact-ACK-sent-count-event-count-readback")
        try t14Require(app.staticTexts["Cloud confirmed this save"].waitForExistence(timeout: 5), "current-A-own-ACK-feedback")
        let terminal = try t14Observe("quiet-terminal-no-input")
        try t14Require(t14ReadbackBool(terminal, "pendingSaveA") == false
            && t14ReadbackBool(terminal, "terminalSaveA") == true, "fresh-terminal-ACK-and-outbox-readback-after-quiet")
        try t14RequireTerminalProof(terminal,
            after: pendingBeforeClose ? quietAppUptime : beforeReleaseAppUptime)
        try t14Require(search.value as? String == "LOCAL-ROOT" && app.tabBars.buttons["Database"].isSelected
            && app.staticTexts[savedName].exists && app.alerts.count == 0, "quiet-terminal-query-tab-saved-A-no-modal")
        t14Capture("quiet terminal; runner-last-input-start=\(lastInputStarted); input-end/quiet-start=\(quietStarted); terminal=\(ProcessInfo.processInfo.systemUptime); app-quiet-boundary=\(quietAppUptime); pending-before-close=\(pendingBeforeClose); current own ACK and exact counters verified before and after Cancel; C1 review Cancel is separate", screenshot: true)
        witnessCompleted = true
    }

    private func t14RequireTerminalProof(_ value: [String: Any], after boundary: Double) throws {
        let runtime = try XCTUnwrap(value["runtime"] as? [String: Any])
        let generation = try XCTUnwrap(value["activeManifestGeneration"] as? String)
        let callback = try XCTUnwrap(runtime["callback"] as? [String: Any])
        let result = try XCTUnwrap(callback["result"] as? String)
        try t14Require(t14ReadbackBool(value, "pendingSaveA") == false
            && t14ReadbackBool(value, "terminalSaveA") == true
            && runtime["terminalPublished"] as? Bool == true
            && runtime["bodyProof"] as? Bool == true
            && runtime["generation"] as? String == generation
            && runtime["catalogAttempts"] as? Int == 1
            && runtime["catalogEvents"] as? Int == 1,
            "fresh-current-own-ACK-one-request-one-event-and-sent-outbox")
        try t14Require(callback["status"] as? String == "OBSERVED"
            && callback["namespace"] as? String == runID && callback["pid"] as? Int == t14AppPID
            && callback["sourceCurrent"] as? Bool == true
            && callback["sourcePresentationID"] as? String == generation
            && callback["currentPresentationID"] as? String == generation
            && (result.hasSuffix(".success.none") || result.hasSuffix(".noWork.none"))
            && (callback["invocationID"] as? String).map({ !$0.isEmpty && $0 != "missing" && $0 != "none" }) == true,
            "actual-current-runtime-terminal-callback-provenance")
        let callbackUptime = try t14Number(callback["uptime"], "terminal-callback-uptime")
        let observationUptime = try t14Number(value["uptime"], "terminal-observation-uptime")
        try t14Require(callbackUptime > boundary
            && callbackUptime <= observationUptime,
            "current-callback-after-required-boundary-before-fresh-readback")
    }

    private func t14Require(_ condition: Bool, _ stage: String) throws {
        guard condition else {
            if !t14FailureCaptured {
                t14FailureCaptured = true
                t14Capture("FIRST_FAIL \(stage); downstream NOT_TRAVERSED", screenshot: true)
            }
            XCTFail("T14 witness NOT_QUALIFIED at \(stage)")
            throw NSError(domain: "Task145T14Witness", code: 1, userInfo: [NSLocalizedDescriptionKey: stage])
        }
    }

    private func t14Number(_ value: Any?, _ stage: String) throws -> Double {
        guard let number = value as? NSNumber, number.doubleValue.isFinite else {
            try t14Require(false, stage + "-missing-or-nonfinite")
            throw NSError(domain: "Task145T14Witness", code: 2)
        }
        return number.doubleValue
    }

    private func t14Observe(_ stage: String) throws -> [String: Any] {
        try t14Require(t14ReadCount < 96, stage + "-explicit-observation-cap96")
        t14ReadCount += 1
        let context = t14EditorOpen ? "editor" : "root"
        let observerIdentifier = "task145.t14.native-observation." + context
        let captureStarted = ProcessInfo.processInfo.systemUptime
        let snapshot = try app.snapshot()
        let captureFinished = ProcessInfo.processInfo.systemUptime
        let nodes = try c3OptionsSnapshotNodes(snapshot, stage: "T14-" + stage, downstream: [])
        let matches = nodes.filter { $0.elementType == .other
            && $0.identifier == observerIdentifier }
        try t14Require(matches.count == 1, stage + "-unique-passive-" + context + "-observer")
        // A complete SDK snapshot evaluates the actual native AX getter. Reuse
        // its value only when the producer clock proves it was made DURING this
        // capture, with the unique observer and keyboard in the same hierarchy.
        // A cached or unqualified value retains the original direct getter path.
        let text: String
        let valueSource: String
        if let capturedText = matches[0].rawValue as? String, capturedText.utf8.count <= 8192,
           let captured = (try? JSONSerialization.jsonObject(with: Data(capturedText.utf8))) as? [String: Any],
           let produced = (captured["uptime"] as? NSNumber)?.doubleValue,
           produced.isFinite, produced >= captureStarted, produced <= captureFinished {
            text = capturedText
            valueSource = "native-getter-during-current-snapshot"
        } else {
            let observer = app.otherElements.matching(NSPredicate(format: "identifier == %@", observerIdentifier)).element
            text = try XCTUnwrap(observer.value as? String)
            valueSource = "direct-native-getter"
        }
        try t14Require(text.utf8.count <= 8192, stage + "-observer-byte-cap")
        let keyboardFrame: [Double]
        if let frame = nodes.first(where: { $0.elementType == .keyboard })?.frame {
            keyboardFrame = [Double(frame.minX), Double(frame.minY), Double(frame.width), Double(frame.height)]
        } else {
            keyboardFrame = []
        }
        let attachment = XCTAttachment(string: "stage=\(stage); capture-start=\(captureStarted); capture-end=\(captureFinished); value-source=\(valueSource); runner-uptime=\(ProcessInfo.processInfo.systemUptime); runner-UTC=\(Date().timeIntervalSince1970); runner-pid=\(ProcessInfo.processInfo.processIdentifier); keyboard-frame-from-public-snapshot=\(keyboardFrame); \(text)")
        attachment.name = "T14 passive observation \(t14ReadCount) \(stage)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        try t14Require(["SHELL_NO_NAME", "EXACT_NATIVE_NAME"].contains(value["status"] as? String ?? ""), stage + "-actual-observer-status")
        let sample = try t14Number(value["sample"], stage + "-sample")
        let uptime = try t14Number(value["uptime"], stage + "-uptime")
        let pid = try t14Number(value["pid"], stage + "-pid")
        let observerID = try XCTUnwrap(value["observerID"] as? String)
        try t14Require(!observerID.isEmpty && value["context"] as? String == context, stage + "-actual-observer-context")
        try t14Require(sample.rounded() == sample && sample > 0 && sample <= 1024,
            stage + "-fresh-bounded-sample")
        try t14Require(pid.rounded() == pid && pid > 0 && (t14AppPID == nil || t14AppPID == Int(pid)), stage + "-same-real-app-PID")
        try t14Require(uptime > t14LastAppUptime && value["namespace"] as? String == runID, stage + "-current-run-namespace-and-fresh-time")
        let runtime = try XCTUnwrap(value["runtime"] as? [String: Any])
        try t14Require(runtime["bodyProof"] as? Bool == true
            && (value["activeManifestGeneration"] as? String).map({ !$0.isEmpty && $0 != "missing" }) == true,
            stage + "-current-file-backed-body-and-generation")
        try t14Require(app.state == .runningForeground && !nodes.contains(where: { $0.elementType == .alert }),
            stage + "-foreground-without-network-modal")
        t14LastAppUptime = uptime; t14AppPID = Int(pid)
        var observed = value
        observed["keyboardFrame"] = keyboardFrame
        return observed
    }

    private func t14HeldRecoveryGuardIsCurrent(_ snapshot: [String: Any]) -> Bool {
        guard let runtime = snapshot["runtime"] as? [String: Any],
              let witness = runtime["heldRecoveryGuard"] as? [String: Any],
              witness["schema"] as? Int == 2,
              witness["kind"] as? String == "HELD_RECOVERY_READ_ONLY_AUTHORITY",
              witness["status"] as? String == "CURRENT_READ_ONLY_MATCH",
              witness["scopeLeaseCurrent"] == nil, witness["leaseGeneration"] == nil,
              let currentLeaseText = witness["currentObservedLeaseGeneration"] as? String,
              let currentLease = UInt64(currentLeaseText), String(currentLease) == currentLeaseText,
              let heldLeaseText = witness["heldLeaseGeneration"] as? String,
              let heldLease = UInt64(heldLeaseText), String(heldLease) == heldLeaseText,
              currentLease >= heldLease,
              witness["runID"] as? String == runID.lowercased(), witness["pid"] as? Int == snapshot["pid"] as? Int,
              witness["phase"] as? String == "recovery-required",
              witness["journalMode"] as? String == "sameScopeRecovery", witness["journalPhase"] as? String == "staging",
              witness["ownerID"] as? String == "14400000-0000-4000-8000-000000000001",
              witness["shopID"] as? String == "14400000-0000-4000-8000-000000000002",
              let active = witness["activeGeneration"] as? String, UUID(uuidString: active) != nil,
              active == snapshot["activeManifestGeneration"] as? String, active == runtime["generation"] as? String,
              witness["heldGeneration"] as? String == active,
              let target = witness["stagingGeneration"] as? String, UUID(uuidString: target) != nil, target != active,
              let baseline = witness["baselineRunID"] as? String, UUID(uuidString: baseline) != nil,
              ["journalPhysical", "currentLeaseStable", "physicalFenceStable", "heldPage", "pendingSaveA", "bodyProof",
               "journalBaselineAbsent", "journalWatermarkAbsent"].allSatisfy({ witness[$0] as? Bool == true }),
              ["accountHash", "deviceIdentityHash", "checkpointDigest", "journalSHA256", "progressSHA256", "physicalFenceSHA256"]
                .allSatisfy({ (witness[$0] as? String)?.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil }) else { return false }
        return runtime["bodyProof"] as? Bool == true && t14ReadbackBool(snapshot, "pendingSaveA") == true
    }

    private func t14DefaultNumber(_ snapshot: [String: Any], _ key: String) -> Double? {
        guard let runtime = snapshot["runtime"] as? [String: Any], let values = runtime["defaults"] as? [String: Any],
              let entry = values[key] as? [String: Any], entry["status"] as? String == "VALUE",
              let number = entry["value"] as? NSNumber, number.doubleValue.isFinite else { return nil }
        return number.doubleValue
    }

    private func t14DefaultString(_ snapshot: [String: Any], _ key: String) -> String? {
        guard let runtime = snapshot["runtime"] as? [String: Any], let values = runtime["defaults"] as? [String: Any],
              let entry = values[key] as? [String: Any], entry["status"] as? String == "VALUE" else { return nil }
        return entry["value"] as? String
    }

    private func t14ReadbackBool(_ snapshot: [String: Any], _ key: String) -> Bool? {
        guard let runtime = snapshot["runtime"] as? [String: Any], let entry = runtime[key] as? [String: Any],
              entry["status"] as? String == "VALUE" else { return nil }
        return entry["value"] as? Bool
    }

    private func t14Editor(_ value: [String: Any], expected: String, stage: String) throws {
        try t14Require(value["status"] as? String == "EXACT_NATIVE_NAME"
            && value["draft"] as? String == expected && value["isFirstResponder"] as? Bool == true,
            stage + "-actual-draft-and-native-focus")
        try t14Require(value["selectionStatus"] as? String == "EXACT_UTF16", stage + "-actual-native-selection")
        let begin = try t14Number(value["selectionStart"], stage + "-selection-start")
        let end = try t14Number(value["selectionEnd"], stage + "-selection-end")
        try t14Require(begin >= 0 && end >= begin && end <= Double(expected.utf16.count), stage + "-selection-in-actual-text")
        let scroll = try XCTUnwrap(value["scroll"] as? [String: Any])
        try t14Require(scroll["status"] as? String == "EXACT_NEAREST_SCROLL", stage + "-unique-native-scroll-ancestor")
        _ = try t14EditorGeometry(value); _ = try t14ScrollPosition(value)
    }

    private func t14EditorGeometry(_ value: [String: Any]) throws -> [Double] {
        let window = try XCTUnwrap(value["windowBounds"] as? [String: Any])
        let field = try XCTUnwrap(value["fieldFrameInWindow"] as? [String: Any])
        let scroll = try XCTUnwrap(value["scroll"] as? [String: Any])
        let frame = try XCTUnwrap(scroll["frameInWindow"] as? [String: Any])
        var tuple: [Double] = []
        for rect in [window, field, frame] {
            for key in ["x", "y", "width", "height"] { tuple.append(try t14Number(rect[key], "geometry-\(key)")) }
            try t14Require(try t14Number(rect["width"], "geometry-width") > 0 && t14Number(rect["height"], "geometry-height") > 0,
                "nonempty-native-geometry")
        }
        // The viewport uses window/field/scroll frames, bounds, insets and keyboard.
        // Content extent remains a finite positive diagnostic in each raw readback.
        for key in ["sizeW", "sizeH"] {
            try t14Require(try t14Number(scroll[key], "scroll-extent-\(key)") > 0,
                "positive-scroll-extent-\(key)")
        }
        for key in ["boundsW", "boundsH", "insetTop", "insetBottom", "insetLeft", "insetRight"] {
            tuple.append(try t14Number(scroll[key], "scroll-geometry-\(key)"))
        }
        let keyboard = try XCTUnwrap(value["keyboardFrame"] as? [Double])
        try t14Require(keyboard.count == 4 && keyboard.allSatisfy({ $0.isFinite }) && keyboard[2] > 0 && keyboard[3] > 0,
            "real-keyboard-geometry")
        return try t14NativePixels(tuple + keyboard, in: value)
    }

    private func t14ScrollPosition(_ value: [String: Any]) throws -> [Double] {
        let scroll = try XCTUnwrap(value["scroll"] as? [String: Any])
        let x = try t14Number(scroll["offsetX"], "actual-scroll-x")
        let y = try t14Number(scroll["offsetY"], "actual-scroll-y")
        return try t14NativePixels([x, y], in: value)
    }

    private func t14NativePixels(_ points: [Double], in value: [String: Any]) throws -> [Double] {
        let scale = try t14Number(value["displayScale"], "native-display-scale")
        try t14Require(scale > 0, "positive-native-display-scale")
        // Compare the same physical pixels across new UIKit view instances.
        // Raw point coordinates remain in the attachments for diagnosis.
        let pixels = points.map { ($0 * scale).rounded() }
        try t14Require(pixels.allSatisfy { $0.isFinite }, "finite-native-pixel-coordinates")
        return [scale] + pixels
    }

    private func t14StableEditor(expected: String, stage: String) throws -> [String: Any] {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        var previous: [String: Any]?
        for sample in 0..<4 {
            try t14Require(ProcessInfo.processInfo.systemUptime < deadline, stage + "-geometry-bound5s")
            let current = try t14Observe(stage + "-fresh-\(sample)")
            try t14Editor(current, expected: expected, stage: stage)
            if let previous,
               try t14EditorGeometry(previous) == t14EditorGeometry(current),
               try t14ScrollPosition(previous) == t14ScrollPosition(current) {
                try t14Require(ProcessInfo.processInfo.systemUptime < deadline, stage + "-geometry-bound5s")
                return current
            }
            previous = current
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        try t14Require(false, stage + "-geometry-never-stabilized")
        throw NSError(domain: "Task145T14Witness", code: 3)
    }

    private func t14SelectAll(_ field: XCUIElement, expected: String) throws {
        try t14Require(field.exists && field.isHittable && field.value as? String == expected, "native-select-all-target")
        field.press(forDuration: 1.1)
        let action = app.descendants(matching: .any).matching(NSPredicate(format:
            "label == %@ AND (elementType == %d OR elementType == %d)", "Select All",
            XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.menuItem.rawValue)).firstMatch
        try t14Require(action.waitForExistence(timeout: 5) && action.isHittable, "native-select-all-menu-action")
        action.tap()
    }

    private func t14ScrollRoundTrip(_ field: XCUIElement, expected: String, stage: String) throws -> Bool {
        let before = try t14Observe(stage + "-before-native-scroll")
        try t14Editor(before, expected: expected, stage: stage)
        let form = app.collectionViews.containing(.textField, identifier: "task144.product.name").firstMatch
        let cell = form.cells.containing(.textField, identifier: "task144.product.name").firstMatch
        try t14Require(form.exists && cell.exists, stage + "-actual-native-Form-row")
        let visible = form.frame.intersection(app.frame)
        let row = cell.frame.intersection(visible), text = field.frame
        let left = max(row.minX, visible.minX), right = min(row.maxX, text.minX)
        let keyboard = app.keyboards.firstMatch
        try t14Require(keyboard.exists && right > left && text.height > 0, stage + "-native-scroll-padding")
        let x = (left + right) / 2, y = text.midY
        let controls = app.buttons["task144.controlled.editor.release"].frame
        let toolbar = app.navigationBars["Edit product"].frame
        let upper = max(visible.minY, max(controls.maxY, toolbar.maxY))
        let lower = min(visible.maxY, keyboard.frame.minY)
        let scroll = try XCTUnwrap(before["scroll"] as? [String: Any])
        let offset = try t14Number(scroll["offsetY"], stage + "-scroll-offset")
        let minimum = -(try t14Number(scroll["insetTop"], stage + "-scroll-inset-top"))
        let maximum = max(minimum, try t14Number(scroll["sizeH"], stage + "-scroll-content-height")
            - t14Number(scroll["boundsH"], stage + "-scroll-bounds-height")
            + t14Number(scroll["insetBottom"], stage + "-scroll-inset-bottom"))
        let direction: CGFloat = offset < maximum ? -1 : 1
        let available = direction < 0 ? y - upper : lower - y
        let travel = direction * min(text.height / 2, available / 2)
        try t14Require(maximum > minimum && (direction < 0 || offset > minimum)
            && travel != 0 && y > upper && y + travel > upper && y + travel < lower,
            stage + "-measured-native-scroll-room")
        let point = form.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x - form.frame.minX, dy: y - form.frame.minY))
        let movedPoint = point.withOffset(CGVector(dx: 0, dy: travel))
        point.press(forDuration: 0, thenDragTo: movedPoint, withVelocity: .slow, thenHoldForDuration: 0.2)
        let moved = try t14Observe(stage + "-after-real-scroll-gesture")
        try t14Editor(moved, expected: expected, stage: stage)
        movedPoint.press(forDuration: 0, thenDragTo: point, withVelocity: .slow, thenHoldForDuration: 0.2)
        let restored = try t14Observe(stage + "-after-real-reverse-scroll")
        try t14Editor(restored, expected: expected, stage: stage)
        return try t14ScrollPosition(before) != t14ScrollPosition(moved)
    }

    private func t14Capture(_ stage: String, screenshot: Bool) {
        let text = "T14 stage=\(stage); run=\(runID); runner-uptime=\(ProcessInfo.processInfo.systemUptime); UTC=\(Date().timeIntervalSince1970); observed-app-pid=\(String(describing: t14AppPID)); explicit-observations=\(t14ReadCount)\n"
            + String(app.debugDescription.prefix(32_768))
        let ax = XCTAttachment(string: text)
        ax.name = "T14 native AX \(String(stage.prefix(120)))"; ax.lifetime = .keepAlways; add(ax)
        if screenshot {
            let image = XCTAttachment(screenshot: app.screenshot())
            image.name = "T14 native viewport \(String(stage.prefix(120)))"; image.lifetime = .keepAlways; add(image)
        }
    }
// TASK145_T14_INSERT_END native-long-use-witness

    func testIndependentHistoryWorkbookAndCatalogReadWhileAnotherDomainIsHeld() throws {
        try task146ConfigureAnimationIdleDriver()
        XCTAssertTrue(_isDebugAssertConfiguration(), "B2 runner must retain Debug assertions")
        func launch(_ phase: String) {
            app.launchEnvironment["TASK146_B2_DOMAIN_UI"] = phase
            app.launch()
            XCTAssertEqual((app.value(forKey: "idleAnimationWaitEnabled") as? NSNumber)?.boolValue, false)
        }

        launch("seed")
        XCTAssertTrue(app.staticTexts["task146.b2.seed-qualified"].waitForExistence(timeout: 30))
        app.terminate()

        launch("hold-prices")
        let pricesHeld = app.staticTexts["task146.b2.hold-prices.held"]
        XCTAssertTrue(directNativeExists(pricesHeld, timeout: 10))
        app.tabBars.buttons["History"].tap()
        let session = app.staticTexts["B2 saved session"]
        XCTAssertTrue(session.waitForExistence(timeout: 5))
        session.tap()
        XCTAssertTrue(app.navigationBars["B2 saved session"].waitForExistence(timeout: 5))
        let payload = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ OR value == %@", "LOCAL-ROOT", "LOCAL-ROOT")).firstMatch
        XCTAssertTrue(payload.waitForExistence(timeout: 5))
        XCTAssertTrue(pricesHeld.exists)

        app.tabBars.buttons["Inventory"].tap()
        app.buttons["task146.b2.load-workbook"].tap()
        XCTAssertTrue(app.navigationBars["Pre-processing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "8050000000001")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(pricesHeld.exists)
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task146.b2.hold-prices.qualified"].waitForExistence(timeout: 10))
        app.terminate()

        launch("hold-sessions")
        let sessionsHeld = app.staticTexts["task146.b2.hold-sessions.held"]
        XCTAssertTrue(sessionsHeld.waitForExistence(timeout: 10))
        app.tabBars.buttons["Database"].tap()
        let catalogRow = app.staticTexts["Safe local baseline"]
        XCTAssertTrue(catalogRow.waitForExistence(timeout: 5))
        XCTAssertTrue(sessionsHeld.exists)
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task146.b2.hold-sessions.qualified"].waitForExistence(timeout: 10))
        app.terminate()

        app.launchEnvironment["TASK146_B2_DOMAIN_UI"] = "cache"
        app.launchEnvironment["TASK131_INITIAL_TAB"] = "database"
        let cacheLaunchStarted = ProcessInfo.processInfo.systemUptime
        app.launchEnvironment["TASK146_B2_LAUNCH_REQUEST_UPTIME"] = String(cacheLaunchStarted)
        app.launch()
        XCTAssertEqual((app.value(forKey: "idleAnimationWaitEnabled") as? NSNumber)?.boolValue, false)
        let catalogRowAppeared = catalogRow.waitForExistence(timeout: 5)
        let automationElapsed = ProcessInfo.processInfo.systemUptime - cacheLaunchStarted
        let render = app.descendants(matching: .any).matching(identifier: "task146.b2.catalog-render").firstMatch
        XCTAssertTrue(render.waitForExistence(timeout: 5))
        let renderData = try XCTUnwrap((render.value as? String)?.data(using: .utf8))
        let observation = try XCTUnwrap(JSONSerialization.jsonObject(with: renderData) as? [String: Any])
        XCTAssertEqual(observation["debugAssertionsEnabled"] as? Bool, true,
                       "The real app must retain Debug assertions in every build profile")
        #if TASK146_NATIVE_OPTIMIZED_ASSERTS
        XCTAssertEqual(observation["optimizedNativeProfile"] as? Bool, true)
        #else
        XCTAssertEqual(observation["optimizedNativeProfile"] as? Bool, false)
        #endif
        XCTAssertEqual(observation["namespace"] as? String, runID)
        XCTAssertEqual(try XCTUnwrap(observation["requestUptime"] as? Double), cacheLaunchStarted, accuracy: 0.000001)
        let renderedAt = try XCTUnwrap(observation["renderUptime"] as? Double)
        XCTAssertGreaterThanOrEqual(renderedAt, cacheLaunchStarted)
        let catalogElapsed = renderedAt - cacheLaunchStarted
        let memoObservation = app.staticTexts.matching(NSPredicate(
            format: "label IN %@", ["task146.b2.memo.hit", "task146.b2.memo.miss"])).firstMatch
        let memoObserved = memoObservation.waitForExistence(timeout: 10)
        let memoResult = memoObserved ? memoObservation.label : "memo-not-observed"
        let memoPresent = app.staticTexts["task146.b2.memo.present.true"].exists
        let validCacheHit = memoResult == "task146.b2.memo.hit" && memoPresent
        let timingStatus: String
        if validCacheHit {
            timingStatus = catalogRowAppeared && catalogElapsed <= 5 ? "PASS" : "FAIL"
        } else {
            timingStatus = "NOT_QUALIFIED_NO_VALID_CACHE_HIT"
        }
        let attachment = XCTAttachment(string: "\(memoResult) memoPresent=\(memoPresent) "
            + "catalogRowAppeared=\(catalogRowAppeared) launchToRenderedCatalogSeconds=\(catalogElapsed) "
            + "automationObservationSeconds=\(automationElapsed) within5Seconds=\(timingStatus) "
            + String(decoding: renderData, as: UTF8.self))
        attachment.name = "B2 physical memo on same scoped store reopen"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(catalogRowAppeared)
        XCTAssertTrue(app.tabBars.buttons["Database"].isSelected)
        XCTAssertTrue(memoObserved)
        XCTAssertTrue(validCacheHit, "A missing or missed physical memo cannot qualify valid-cache startup")
        if validCacheHit { XCTAssertLessThanOrEqual(catalogElapsed, 5) }
    }

    /// R23-T01/B1 prepatch discriminator, not the 20k/40k performance gate.
    /// A seed process establishes the real store; the measured process reuses it
    /// and mounts standardRootView before the deliberately held body proof.
    func testR23ColdShellKeepsAllTabsWhilePersistedLocalQualificationIsHeld() throws {
        app.launchEnvironment["TASK144_R23_SHELL_PROBE"] = "seed"
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.r23.seed-qualified"].waitForExistence(timeout: 30),
                      "The separate seed must publish a real persisted baseline")
        app.terminate()

        app.launchEnvironment["TASK144_R23_SHELL_PROBE"] = "hold"
        app.launch()
        // SwiftUI can propagate the gate container's identifier to its Text
        // children. Match the actual gate without assuming an AX element type.
        let gate = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ OR identifier == %@ OR label == %@",
            "sync-recovery-phase", "sync-replacement-business-data-gate", "Recovery required")).firstMatch
        let realRootRendered = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
            app.staticTexts["task144.r23.persisted-root-mounted"].exists
                && (gate.exists || app.tabBars.buttons["Options"].exists)
        }, object: nil)
        let rootWait = XCTWaiter.wait(for: [realRootRendered], timeout: 10)
        let rootHierarchy = XCTAttachment(string: app.debugDescription)
        rootHierarchy.name = "R23 persisted root hierarchy before handshake assertion"
        rootHierarchy.lifetime = .keepAlways; add(rootHierarchy)
        let rootScreenshot = XCTAttachment(screenshot: app.screenshot())
        rootScreenshot.name = "R23 persisted root before handshake assertion"
        rootScreenshot.lifetime = .keepAlways; add(rootScreenshot)
        XCTAssertEqual(rootWait, .completed,
                       "The fixture pre-gate must be absent and the real root rendered on persisted reopen")
        XCTAssertTrue(app.staticTexts["task144.r23.qualification-held"].waitForExistence(timeout: 10),
                      "The real local proof must reach its controlled publication boundary")
        let started = ProcessInfo.processInfo.systemUptime
        let titles = ["Inventory", "Database", "History", "Options"]
        var availability: [String: Bool] = [:]
        for title in titles {
            let tab = app.tabBars.buttons[title]
            availability[title] = tab.exists && tab.isHittable
        }
        let leakedBusinessRowBeforeNavigation = app.staticTexts["Safe local baseline"].exists
        var optionsNavigationSucceeded = false
        if availability["Options"] == true {
            app.tabBars.buttons["Options"].tap()
            optionsNavigationSucceeded = app.navigationBars["Options"].waitForExistence(timeout: 5)
        }
        let leakedBusinessRowAfterNavigation = app.staticTexts["Safe local baseline"].exists
        let capturedGate = gate.exists
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "R23 prepatch real root while local qualification held"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "R23 real root hierarchy before controlled release"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let payload: [String: Any] = [
            "case": "R23-T01-cold-qualified-store-proof-held", "namespace": runID,
            "dataset": ["products": 1, "prices": 0],
            "measurement": "functional_discriminator_not_performance_acceptance",
            "tabAvailability": availability, "globalBusinessGateExists": capturedGate,
            "optionsNavigationSucceeded": optionsNavigationSucceeded,
            "unqualifiedBusinessRowVisibleBeforeNavigation": leakedBusinessRowBeforeNavigation,
            "unqualifiedBusinessRowVisibleAfterNavigation": leakedBusinessRowAfterNavigation,
            "observationUptime": started, "observationDuration": elapsed,
            "root": "standardRootView; real recovery phase or Options tab observed; fixture pre-gate disabled only after persisted manifest",
            "localProof": "held_before_actual_publication"
        ]
        let evidence = XCTAttachment(data: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
                                     uniformTypeIdentifier: "public.json")
        evidence.name = "R23 prepatch shell discriminator observations"
        evidence.lifetime = .keepAlways
        add(evidence)

        // Release owned holds before reporting the preserved semantic failure.
        let release = app.buttons["task144.controlled.release"]
        XCTAssertTrue(release.exists && release.isHittable, "Owned cleanup control must be reachable")
        release.press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task144.r23.qualification-released-and-readback"].waitForExistence(timeout: 20),
                      "The hold must be released and the same persisted data read back")
        XCTAssertFalse(leakedBusinessRowBeforeNavigation, "Unqualified business data must be hidden on initial mount")
        XCTAssertFalse(leakedBusinessRowAfterNavigation, "Unqualified business data must remain hidden after navigation")
        XCTAssertEqual(availability.count, 4)
        XCTAssertTrue(availability.values.allSatisfy { $0 },
                      "R23-CA01: all four tabs must remain available while local qualification is pending")
        XCTAssertTrue(optionsNavigationSucceeded, "Safe Options navigation must work while local proof is pending")
    }

    func testSavedNameAndPriceSurviveKillBeforeRecoveryActivationAndTwoReopens() throws {
        app.launchEnvironment["TASK145_SAVE_BEFORE_ACTIVATION_UI"] = "name-price"
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
        XCTAssertTrue(tapStableInitialReplayProduct(app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Safe local baseline")).element(boundBy: 0)))
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); positionNameInEditorViewport(name)
        replaceText(in: name, with: "R23 saved before recovery activation")
        let price = app.textFields["task141.product.purchase-price"]
        r4Reveal(price); replaceText(in: price, with: "37", readinessTarget: .identifier("task141.product.purchase-price"))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["task145.t10a.save-durable-before-activation"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5))
        let before = try t10Ledger("Save durable with snapshot page still held")
        let beforeWitness = try t10PreACKPriceWitness(before)
        XCTAssertNil(before["terminalGeneration"])
        for key in ["catalogIngressCount", "priceIngressCount", "eventIngressCount"] { XCTAssertEqual(before[key] as? Int, 0) }
        XCTAssertEqual((before["savedTokens"] as? [[String: Any]])?.count, 2)
        XCTAssertEqual((before["catalogPayloads"] as? [String])?.count, 0)
        XCTAssertEqual((before["pricePayloads"] as? [String])?.count, 0)
        // Kill while staging is still held: never press Release, Retry or invoke a runtime manually.
        app.terminate(); XCTAssertEqual(app.state, .notRunning); app.launch()
        XCTAssertTrue(app.staticTexts["task145.t10a.reopen-qualified"].waitForExistence(timeout: 20))
        let reopened = try t10Ledger("Exact saved tokens and journal qualified before automatic admission", qualified: true)
        _ = try t10PreACKPriceWitness(reopened)
        for key in ["originalGeneration", "journalBytes", "savedTokens", "savedLocalPriceWitness"] {
            XCTAssertEqual(try retryCanonical(before[key]), try retryCanonical(reopened[key]))
        }
        XCTAssertNotEqual((before["processIDs"] as? [Int])?.last, (reopened["processIDs"] as? [Int])?.last)
        XCTAssertTrue(app.staticTexts["task145.t10a.automatic-finished-own-acks"].waitForExistence(timeout: 60))
        let terminal = try t10Ledger("Automatic recovery finished; catalog and price received their own ACK")
        try t10AssertObservedPriceIdentity(terminal)
        XCTAssertEqual(try retryCanonical(beforeWitness), try retryCanonical(terminal["savedLocalPriceWitness"]))
        for key in ["journalBytes", "savedTokens"] {
            XCTAssertEqual(try retryCanonical(before[key]), try retryCanonical(terminal[key]))
        }
        XCTAssertNotEqual(terminal["originalGeneration"] as? String, terminal["terminalGeneration"] as? String)
        XCTAssertEqual((terminal["prices"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((terminal["events"] as? [[String: Any]])?.count, 2)
        app.terminate(); XCTAssertEqual(app.state, .notRunning); app.launch()
        XCTAssertTrue(app.staticTexts["task145.t10a.second-reopen-own-ack-no-resend"].waitForExistence(timeout: 30))
        let final = try t10Ledger("Second persisted reopen and successful ordinary wake without resend")
        try t10AssertObservedPriceIdentity(final)
        XCTAssertEqual(try retryCanonical(beforeWitness), try retryCanonical(final["savedLocalPriceWitness"]))
        for key in ["originalGeneration", "terminalGeneration", "journalBytes", "savedTokens", "savedLocalPriceWitness", "savedPriceID", "catalogPayloads", "pricePayloads", "prices", "events", "catalogIngressCount", "priceIngressCount", "eventIngressCount"] {
            XCTAssertEqual(try retryCanonical(terminal[key]), try retryCanonical(final[key]))
        }
        XCTAssertNotEqual((terminal["processIDs"] as? [Int])?.last, (final["processIDs"] as? [Int])?.last)
    }

    private func t10Ledger(_ stage: String, qualified: Bool = false) throws -> [String: Any] {
        let element = app.staticTexts["task145.t10a.ledger"]
        let text = try XCTUnwrap(element.value as? String)
        let pieces = text.components(separatedBy: ";qualified.")
        XCTAssertEqual(pieces.count, 2)
        let encoded = qualified ? pieces[1] : pieces[0]
        let bytes = try XCTUnwrap(Data(base64Encoded: encoded))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(object["schema"] as? Int, 2)
        XCTAssertEqual((object["runID"] as? String)?.lowercased(), runID)
        let evidence = XCTAttachment(string: String(decoding: bytes, as: UTF8.self))
        evidence.name = "R23 T10a: " + stage; evidence.lifetime = .keepAlways; add(evidence)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "R23 T10a: " + stage; screenshot.lifetime = .keepAlways; add(screenshot)
        return object
    }

    // Schema2 separates exact persisted local identity from the cloud ID that
    // production observes only after its automatic request reaches the transport.
    private func t10PriceWitness(_ ledger: [String: Any]) throws -> [String: Any] {
        let witness = try XCTUnwrap(ledger["savedLocalPriceWitness"] as? [String: Any])
        let required: Set<String> = ["ownerUserID", "shopID", "accountHash", "storeRawValue",
            "defaultStoreID", "localStoreID", "schemaVersion", "syncProtocolVersion", "storeEpoch",
            "deviceInstallID", "deviceIdentityHash", "productID", "productBarcode", "type",
            "localPriceBits", "localEffectiveAt", "localCreatedAt", "price", "amountCanonical",
            "effectiveAt", "createdAt", "logicalKey", "intendedFingerprintHash", "originalToken"]
        XCTAssertEqual(Set(witness.keys).subtracting(["source", "note"]), required)
        for key in ["ownerUserID", "shopID", "productID"] {
            _ = try XCTUnwrap(UUID(uuidString: XCTUnwrap(witness[key] as? String)), key)
        }
        for key in ["accountHash", "storeRawValue", "defaultStoreID", "localStoreID", "deviceInstallID",
                    "deviceIdentityHash", "productBarcode", "amountCanonical", "effectiveAt", "createdAt",
                    "logicalKey", "intendedFingerprintHash"] {
            let value = try XCTUnwrap(witness[key] as? String, key)
            XCTAssertFalse(value.isEmpty, key)
        }
        for key in ["schemaVersion", "syncProtocolVersion", "storeEpoch"] {
            _ = try XCTUnwrap(witness[key] as? Int, key)
        }
        for key in ["localEffectiveAt", "localCreatedAt"] {
            _ = try XCTUnwrap(witness[key] as? NSNumber, key)
        }
        XCTAssertEqual(witness["type"] as? String, "PURCHASE")
        XCTAssertEqual(witness["price"] as? Double, 37)
        XCTAssertEqual((witness["localPriceBits"] as? NSNumber)?.uint64Value, Double(37).bitPattern)
        let tokens = try XCTUnwrap(ledger["savedTokens"] as? [[String: Any]])
        XCTAssertEqual(tokens.count, 2)
        let priceTokens = tokens.filter { $0["entityKindRaw"] as? String == "productPrice" }
        let token = try XCTUnwrap(priceTokens.count == 1 ? priceTokens.first : nil,
            "Exactly one original price token is required")
        XCTAssertEqual(try retryCanonical(witness["originalToken"]), try retryCanonical(token))
        XCTAssertEqual(token["statusRaw"] as? String, "pending")
        XCTAssertNil(token["entityRemoteIDRaw"])
        XCTAssertEqual(token["logicalKey"] as? String, witness["logicalKey"] as? String)
        XCTAssertEqual(token["intendedFingerprintHash"] as? String, witness["intendedFingerprintHash"] as? String)
        return witness
    }
    private func t10PreACKPriceWitness(_ ledger: [String: Any]) throws -> [String: Any] {
        let witness = try t10PriceWitness(ledger)
        XCTAssertNil(ledger["savedPriceID"], "A local Save must not manufacture a preACK cloud ID")
        for key in ["catalogIngressCount", "priceIngressCount", "eventIngressCount"] {
            XCTAssertEqual(ledger[key] as? Int, 0, key)
        }
        for key in ["catalogPayloads", "pricePayloads", "prices", "events"] {
            XCTAssertEqual((ledger[key] as? [Any])?.count, 0, key)
        }
        return witness
    }
    private func t10AssertObservedPriceIdentity(_ ledger: [String: Any]) throws {
        let witness = try t10PriceWitness(ledger)
        let observedID = try XCTUnwrap(UUID(uuidString: XCTUnwrap(ledger["savedPriceID"] as? String)))
        let encoded = try XCTUnwrap(ledger["pricePayloads"] as? [String])
        let encodedRequest = try XCTUnwrap(encoded.count == 1 ? encoded.first : nil)
        let payloads = try XCTUnwrap(JSONSerialization.jsonObject(with:
            XCTUnwrap(Data(base64Encoded: encodedRequest))) as? [[String: Any]])
        let payload = try XCTUnwrap(payloads.count == 1 ? payloads.first : nil)
        let rows = try XCTUnwrap(ledger["prices"] as? [[String: Any]])
        let row = try XCTUnwrap(rows.count == 1 ? rows.first : nil)
        XCTAssertEqual(UUID(uuidString: try XCTUnwrap(payload["id"] as? String)), observedID)
        XCTAssertEqual(UUID(uuidString: try XCTUnwrap(row["id"] as? String)), observedID)
        for (wire, local) in [("owner_user_id", "ownerUserID"), ("shop_id", "shopID"), ("product_id", "productID")] {
            let expected = try XCTUnwrap(UUID(uuidString: XCTUnwrap(witness[local] as? String)))
            XCTAssertEqual(UUID(uuidString: try XCTUnwrap(payload[wire] as? String)), expected)
            XCTAssertEqual(UUID(uuidString: try XCTUnwrap(row[wire] as? String)), expected)
        }
        for (wire, local) in [("type", "type"), ("effective_at", "effectiveAt"), ("created_at", "createdAt"),
                              ("source", "source"), ("note", "note")] {
            XCTAssertEqual(payload[wire] as? String, witness[local] as? String, wire)
            XCTAssertEqual(row[wire] as? String, witness[local] as? String, wire)
        }
        XCTAssertEqual(payload["price"] as? Double, 37)
        XCTAssertEqual(row["price"] as? Double, 37)
    }

    func testR23RealSavedConflictNoOpAdoptionSurvivesReopenAndOrdinarySaveBWithIndependentPriceACK() throws {
        try task146ConfigureAnimationIdleDriver()
        app.launchEnvironment["TASK145_R4_REVIEW_UI"] = "noop-price"
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_OBSERVE_NATIVE_NAME"] = "1"
        app.launch()
        try r4Await("ready", timeout: 20)
        let initial = app.staticTexts["Safe local baseline"]
        XCTAssertTrue(initial.waitForExistence(timeout: 5)); initial.tap()
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        positionNameInEditorViewport(name)
        app.buttons["task144.controlled.editor.r4-peer"].press(forDuration: 1.2)
        try r4Await("peer-ready", timeout: 5)
        replaceText(in: name, with: "R23 saved catalog A")
        let purchase = app.textFields["task141.product.purchase-price"]
        r4Reveal(purchase)
        replaceText(in: purchase, with: "37", readinessTarget: .identifier("task141.product.purchase-price"))
        app.buttons["Save"].tap()
        try r4Await("saved-rejected", timeout: 15)
        let rejected = try r4Ledger("Real editor Save A and price durable; typed rejection retained", inEditor: false)
        XCTAssertEqual((rejected["catalogRequests"] as? [String])?.count, 1)
        XCTAssertEqual((rejected["priceRequests"] as? [String])?.count, 0)
        XCTAssertEqual(rejected["catalogIngressCount"] as? Int, 1)
        XCTAssertEqual(rejected["priceIngressCount"] as? Int, 0)
        XCTAssertNotNil(rejected["originalPending"])
        XCTAssertNotNil(rejected["childBefore"])
        XCTAssertNil(rejected["receiptJSON"])
        let pending = try XCTUnwrap(rejected["originalPending"] as? [String: Any])
        XCTAssertEqual(pending["entityRemoteIDRaw"] as? String, "14400000-0000-4000-8000-000000000003")
        let savedRemoteIDText = try XCTUnwrap(pending["entityRemoteIDRaw"] as? String)
        let savedRemoteID = try XCTUnwrap(UUID(uuidString: savedRemoteIDText))
        let recordIdentifier = "task145.catalog.attention.\(savedRemoteID.uuidString.lowercased())"
        app.tabBars.buttons["Options"].tap()
        let attention = app.buttons.matching(identifier: "task145.catalog.attention").element
        r4Reveal(attention, optionsIdentifier: "task145.catalog.attention")
        attention.tap()
        let afterParent = try c3OptionsSnapshotNodes(try app.snapshot(),
            stage: "R4-after-single-parent-tap", downstream: [])
        r4OptionsSnapshotDiagnostic(afterParent, stage: "after-single-parent-tap")
        let records = app.buttons.matching(identifier: recordIdentifier)
            .matching(NSPredicate(format: "label == %@", "R23 saved catalog A"))
        let record = records.element
        r4Reveal(record, optionsIdentifier: recordIdentifier, optionsTitle: "R23 saved catalog A")
        XCTAssertEqual(records.count, 1, "The saved record must be the unique attention button with its exact title")
        record.tap()
        let adopt = app.buttons["task145.product.resolution.adopt-remote"]
        r4Reveal(adopt, resolution: true)
        let adoptionDeadline = ProcessInfo.processInfo.systemUptime + 15
        guard adopt.waitForExistence(timeout: max(0, adoptionDeadline - ProcessInfo.processInfo.systemUptime)) else {
            captureControlledAutomaticReadback()
            XCTFail("Options must route into the real editor and actual service.prepare"); return
        }
        let expectedPID = try XCTUnwrap((rejected["processIDs"] as? [Int])?.last)
        let expectedGeneration = try XCTUnwrap(rejected["generationID"] as? String).lowercased()
        let nativeWriter = app.otherElements.matching(identifier: "task144.controlled.native-name-observation").element
        let adoptedFact = app.staticTexts["task145.r4.adopted-durable"]
        let ownerBusy = app.staticTexts["Synchronization is using this record. Your choice is preserved; review it again after the current operation finishes."]
        var adoptedObserved = false
        for attempt in 0..<2 {
            let requestedAt = ProcessInfo.processInfo.systemUptime
            var admittedLedger: Data?
            let idle = NSPredicate { _, _ in
                guard ProcessInfo.processInfo.systemUptime < adoptionDeadline,
                      let raw = nativeWriter.value as? String, raw.utf8.count <= 524288,
                      let data = Data(base64Encoded: raw),
                      let ledger = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let sample = ledger["writerObservation"] as? [String: Any],
                      let started = sample["startedUptime"] as? Double,
                      let sampled = sample["sampledUptime"] as? Double,
                      started.isFinite, sampled.isFinite, started >= requestedAt, sampled >= started,
                      sampled <= ProcessInfo.processInfo.systemUptime,
                      (ledger["runID"] as? String)?.lowercased() == self.runID.lowercased(),
                      (ledger["generationID"] as? String)?.lowercased() == expectedGeneration,
                      sample["namespace"] as? String == self.runID.lowercased(), sample["pid"] as? Int == expectedPID,
                      sample["generationID"] as? String == expectedGeneration,
                      sample["scopeCurrentAtRead"] as? Bool == true,
                      let lease = sample["leaseGeneration"] as? String, let generation = UInt64(lease), String(generation) == lease,
                      sample["isRunning"] as? Bool == false, sample["isSuspended"] as? Bool == false,
                      ProcessInfo.processInfo.systemUptime <= adoptionDeadline else { return false }
                admittedLedger = data
                return true
            }
            let immediatelyIdle = idle.evaluate(with: nil)
            let remaining = adoptionDeadline - ProcessInfo.processInfo.systemUptime
            guard (immediatelyIdle || (remaining > 0 && XCTWaiter.wait(for: [
                XCTNSPredicateExpectation(predicate: idle, object: nil)], timeout: remaining) == .completed)),
                  adopt.isEnabled, adopt.isHittable, ProcessInfo.processInfo.systemUptime < adoptionDeadline else {
                captureControlledAutomaticReadback()
                XCTFail("R4 adoption requires a fresh current idle writer within the same15second budget"); return
            }
            let admission = XCTAttachment(data: try XCTUnwrap(admittedLedger), uniformTypeIdentifier: "public.json")
            admission.name = "R4 current idle writer before native adoption attempt \(attempt + 1)"
            admission.lifetime = .keepAlways; add(admission)
            guard ProcessInfo.processInfo.systemUptime < adoptionDeadline else {
                captureControlledAutomaticReadback()
                XCTFail("R4 adoption deadline reached before the single native tap"); return
            }
            adopt.tap()
            var ownerBusyObserved = false
            let outcome = NSPredicate { _, _ in
                guard ProcessInfo.processInfo.systemUptime < adoptionDeadline else { return false }
                if adoptedFact.exists { adoptedObserved = true }
                else { ownerBusyObserved = ownerBusy.exists }
                return (adoptedObserved || ownerBusyObserved) && ProcessInfo.processInfo.systemUptime <= adoptionDeadline
            }
            let immediatelyObserved = outcome.evaluate(with: nil)
            let outcomeRemaining = adoptionDeadline - ProcessInfo.processInfo.systemUptime
            guard (immediatelyObserved || (outcomeRemaining > 0 && XCTWaiter.wait(for: [
                XCTNSPredicateExpectation(predicate: outcome, object: nil)], timeout: outcomeRemaining) == .completed)),
                  ProcessInfo.processInfo.systemUptime <= adoptionDeadline else {
                captureControlledAutomaticReadback()
                XCTFail("R4 adoption outcome not observed within the same15second budget"); return
            }
            if adoptedObserved { break }
            guard attempt == 0, ownerBusyObserved else {
                captureControlledAutomaticReadback()
                XCTFail("R4 permits only one retry after the actual native ownerBusy error"); return
            }
            // The sole retry must obtain another post-error current idle sample.
        }
        XCTAssertTrue(adoptedObserved, "R4 adoption must create the actual durable decision")
        XCTAssertLessThanOrEqual(ProcessInfo.processInfo.systemUptime, adoptionDeadline)
        XCTAssertTrue(app.staticTexts["Remote version adopted."].waitForExistence(timeout: 5))
        let adopted = try r4Ledger("Actual no-op service.resolve wrote a non-ACK receipt", inEditor: true)
        XCTAssertEqual(rejected["originalSeal"] as? String, adopted["originalSeal"] as? String)
        XCTAssertEqual(try r4ObjectBytes(rejected["originalPending"]), try r4ObjectBytes(adopted["originalPending"]))
        let receipt = try XCTUnwrap(adopted["receiptJSON"] as? String)
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try r4Await("adopted-reopened", timeout: 20)
        let reopened = try r4Ledger("Same namespace in a distinct process retains no-op decision", inEditor: false)
        XCTAssertEqual(reopened["receiptJSON"] as? String, receipt)
        XCTAssertEqual(reopened["originalSeal"] as? String, adopted["originalSeal"] as? String)
        XCTAssertEqual((reopened["processIDs"] as? [Int])?.count, 2)
        let row = app.staticTexts["R23 saved catalog A"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let item = app.textFields[Self.r23ItemCodeFieldLabel]
        r4Reveal(item, focusInVisibleEditor: true)
        replaceText(in: item, with: "R23 ordinary item B", readinessTarget: .label(Self.r23ItemCodeFieldLabel),
            focusAlreadyPositioned: true)
        app.buttons["Save"].tap()
        try r4Await("b-and-price-own-ack", timeout: 15)
        let terminal = try r4Ledger("Ordinary Save B uses R and only itemNumber; price receives its own exact ACK", inEditor: false)
        XCTAssertEqual((terminal["catalogRequests"] as? [String])?.count, 2)
        XCTAssertEqual((terminal["priceRequests"] as? [String])?.count, 1)
        XCTAssertEqual(terminal["catalogIngressCount"] as? Int, 2)
        XCTAssertEqual(terminal["priceIngressCount"] as? Int, 1)
        XCTAssertEqual((terminal["prices"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual(terminal["receiptJSON"] as? String, receipt)
        XCTAssertEqual(terminal["originalSeal"] as? String, adopted["originalSeal"] as? String)
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try r4Await("terminal-reopened", timeout: 20)
        try r4Await("terminal-wake-observed", timeout: 15)
        let final = try r4Ledger("Second reopen and normal automatic wake retain exact ACKs without resends", inEditor: false)
        XCTAssertEqual(final["catalogRequests"] as? [String], terminal["catalogRequests"] as? [String])
        XCTAssertEqual(final["priceRequests"] as? [String], terminal["priceRequests"] as? [String])
        XCTAssertEqual(final["receiptJSON"] as? String, receipt)
        XCTAssertEqual(final["catalogIngressCount"] as? Int, 2)
        XCTAssertEqual(final["priceIngressCount"] as? Int, 1)
        XCTAssertEqual((final["processIDs"] as? [Int])?.count, 3)
    }

    private func r4Reveal(_ element: XCUIElement, optionsIdentifier: String? = nil,
                          optionsTitle: String? = nil, resolution: Bool = false,
                          focusInVisibleEditor: Bool = false) {
        let deadline = ProcessInfo.processInfo.systemUptime + 15
        if resolution {
            // Capture only the real resolution sheet. Its editor and Database
            // ancestors were consuming 6s or more in an application-wide capture.
            var drags = 0
            var observations: [String] = []
            var emitted = false
            let emit = { [weak self] in
                guard let self, !emitted else { return }
                emitted = true
                let evidence = XCTAttachment(string: observations.joined(separator: "\n"))
                evidence.name = "R4 bounded owned-sheet reveal"
                evidence.lifetime = .keepAlways; self.add(evidence)
            }
            addTeardownBlock { emit() }
            defer { emit() }
            let identifier = "task145.product.resolution"
            while ProcessInfo.processInfo.systemUptime < deadline {
                let captureStarted = ProcessInfo.processInfo.systemUptime
                let candidates = app.otherElements.matching(identifier: identifier)
                let count = candidates.count
                guard count == 1 else {
                    if observations.count < 24 { observations.append("capture-start=\(captureStarted); sheet-count=\(count); drags=\(drags)") }
                    continue
                }
                guard let root = try? candidates.element(boundBy: 0).snapshot(),
                      let nodes = try? c3OptionsSnapshotNodes(root, stage: "R4-resolution-\(drags)", downstream: []) else { continue }
                let sheets = nodes.filter { $0.elementType == .other && $0.identifier == identifier }
                guard sheets.count == 1 else { continue }
                let forms = nodes.filter { $0.elementType == .collectionView && $0.path.starts(with: sheets[0].path) }
                let bars = nodes.filter { $0.elementType == .navigationBar && $0.path.starts(with: sheets[0].path) }
                guard forms.count == 1, bars.count == 1, bars[0].identifier == "Review saved change" else { continue }
                let owners = app.windows.containing(.other, identifier: identifier)
                guard owners.count == 1 else { continue }
                let window = owners.element(boundBy: 0).frame
                let frame = forms[0].frame.intersection(window)
                let top = max(frame.minY, bars[0].frame.maxY) + 12
                let bottom = frame.maxY - 16
                guard [frame.minX, frame.maxX, top, bottom].allSatisfy({ $0.isFinite }),
                      frame.width > 24, bottom > top + 24 else { continue }
                let targets = nodes.filter { $0.elementType == .button
                    && $0.identifier == "task145.product.resolution.adopt-remote"
                    && $0.path.starts(with: forms[0].path) }
                guard targets.count <= 1 else { break }
                let target = targets.first?.frame
                let inside = target.map { $0.width > 0 && $0.height > 0 && $0.minY >= top && $0.maxY <= bottom } ?? false
                let hitStarted = ProcessInfo.processInfo.systemUptime
                let hit = inside && hitStarted < deadline ? element.isHittable : false
                if observations.count < 24 {
                    observations.append("capture-start=\(captureStarted); capture-end=\(hitStarted); target=\(String(describing: target)); top=\(top); bottom=\(bottom); inside=\(inside); hittable=\(hit); hit-end=\(ProcessInfo.processInfo.systemUptime); drags=\(drags); deadline=\(deadline)")
                }
                if inside, hit, ProcessInfo.processInfo.systemUptime < deadline { return }
                guard drags < 5, ProcessInfo.processInfo.systemUptime < deadline else { break }
                let upward = target.map { $0.midY > (top + bottom) / 2 } ?? true
                let distance = (bottom - top) * 0.85
                let y = (top + bottom) / 2 + (upward ? distance / 2 : -distance / 2)
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: frame.midX - window.minX, dy: y - window.minY))
                drags += 1
                start.press(forDuration: 0, thenDragTo: start.withOffset(CGVector(
                    dx: 0, dy: upward ? -distance : distance)), withVelocity: XCUIGestureVelocity(rawValue: 5_000), thenHoldForDuration: 0)
            }
            emit()
            XCTFail("R4 resolution control not reachable within 15 seconds and 5 drags")
            return
        }
        if focusInVisibleEditor {
            // SaveB alone owns focus/reveal within the original15s/five-drag
            // budget. One complete native tree replaces many separate geometry
            // RPCs; the actual field still supplies the final native hit query.
            var drags = 0
            var observations: [String] = []
            defer {
                let evidence = XCTAttachment(string: observations.joined(separator: "\n"))
                evidence.name = "R4 focused field coherent native reveal"
                evidence.lifetime = .keepAlways; add(evidence)
            }
            guard element.exists, element.isHittable,
                  ProcessInfo.processInfo.systemUptime < deadline else {
                XCTFail("R4 field must admit the real focus tap within15s"); return
            }
            element.tap()
            guard directNativeExists(app.keyboards.element(boundBy: 0),
                timeout: min(5, deadline - ProcessInfo.processInfo.systemUptime)) else {
                XCTFail("R4 keyboard must appear within the original focus budget"); return
            }
            while ProcessInfo.processInfo.systemUptime < deadline {
                let captureStarted = ProcessInfo.processInfo.systemUptime
                guard let root = try? app.snapshot(),
                      let nodes = try? c3OptionsSnapshotNodes(root, stage: "R4-focused-\(drags)", downstream: []) else { break }
                let fields = nodes.filter { $0.elementType == .textField && $0.label == Self.r23ItemCodeFieldLabel }
                let bars = nodes.filter { $0.elementType == .navigationBar && $0.identifier == "Edit product" }
                let bands = nodes.filter { $0.elementType == .other && $0.identifier == "task144.controlled.editor.band" }
                let keyboards = nodes.filter { $0.elementType == .keyboard }
                let assistants = nodes.filter { $0.elementType == .other && $0.identifier == "SystemInputAssistantView" }
                guard fields.count == 1, bars.count == 1, bands.count <= 1,
                      keyboards.count == 1, assistants.count <= 1 else { break }
                let windows = nodes.filter { $0.elementType == .window && fields[0].path.starts(with: $0.path) }
                let forms = nodes.filter { $0.elementType == .collectionView && fields[0].path.starts(with: $0.path) }
                guard windows.count == 1, forms.count == 1,
                      (bars + bands + forms).allSatisfy({ $0.path.starts(with: windows[0].path) }) else { break }
                let window = windows[0].frame
                let viewport = root.frame.intersection(window).intersection(forms[0].frame)
                let frame = fields[0].frame
                let upper = max(viewport.minY, max(bars[0].frame.maxY, bands.first?.frame.maxY ?? viewport.minY)) + 12
                var lower = min(viewport.maxY, keyboards[0].frame.minY) - 12
                if let assistant = assistants.first {
                    let covered = assistant.frame.intersection(viewport)
                    if covered.width > 0 && covered.height > 0 { lower = min(lower, covered.minY - 12) }
                }
                guard (fields + bars + bands + keyboards + assistants + windows + forms).allSatisfy({ node in
                    let f = node.frame
                    return [f.minX, f.minY, f.maxX, f.maxY].allSatisfy({ $0.isFinite })
                        && !f.isNull && !f.isInfinite && f.width > 0 && f.height > 0
                }), lower > upper + 16 else { break }
                let inside = viewport.contains(frame) && frame.minY >= upper && frame.maxY <= lower
                let captureFinished = ProcessInfo.processInfo.systemUptime
                let hit = inside && captureFinished < deadline ? element.isHittable : false
                observations.append("capture-start=\(captureStarted); capture-end=\(captureFinished); field=\(frame); viewport=\(viewport); upper=\(upper); lower=\(lower); inside=\(inside); hit=\(hit); hit-end=\(ProcessInfo.processInfo.systemUptime); deadline=\(deadline); drags=\(drags)")
                if inside, hit, ProcessInfo.processInfo.systemUptime < deadline { return }
                guard drags < 5, ProcessInfo.processInfo.systemUptime < deadline else { break }
                let upward = frame.midY > (upper + lower) / 2
                let startY = upward ? lower : upper
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: viewport.minX + 24 - root.frame.minX, dy: startY - root.frame.minY))
                drags += 1
                start.press(forDuration: 0, thenDragTo: start.withOffset(CGVector(
                    dx: 0, dy: (upward ? -1 : 1) * min(200, lower - upper))),
                    withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            XCTFail("R4 focused field not visible above keyboard within 15 seconds and 5 drags")
            return
        }
        let optionsNavigation = app.navigationBars["Options"]
        if app.navigationBars.count == 1 && optionsNavigation.exists && app.tabBars.buttons["Options"].isSelected {
            for drag in 0...5 {
                guard ProcessInfo.processInfo.systemUptime < deadline else { break }
                let nodes: [C3OptionsSnapshotNode]
                do {
                    nodes = try c3OptionsSnapshotNodes(try app.snapshot(),
                        stage: "R4-Options-reveal-\(drag)", downstream: [])
                } catch { XCTFail("R4 coherent Options snapshot unavailable"); return }
                let navigation = nodes.filter { $0.elementType == .navigationBar }
                let windows = nodes.filter { window in
                    window.elementType == .window && navigation.contains {
                        $0.identifier == "Options" && $0.path.starts(with: window.path)
                    }
                }
                let forms = nodes.filter { $0.elementType == .collectionView }
                let tabs = nodes.filter { $0.elementType == .tabBar }
                let bands = nodes.filter { $0.elementType == .other && $0.identifier == "task144.controlled.band" }
                guard navigation.count == 1, navigation[0].identifier == "Options",
                      windows.count == 1, forms.count == 1, tabs.count == 1, bands.count <= 1,
                      (navigation + forms + tabs + bands).allSatisfy({ $0.path.starts(with: windows[0].path) }) else { break }
                let optionsTabs = nodes.filter { $0.elementType == .button && $0.label == "Options"
                    && $0.path.starts(with: tabs[0].path) }
                guard optionsTabs.count == 1, optionsTabs[0].isSelected else { break }
                let formFrame = forms[0].frame, windowFrame = windows[0].frame
                let navigationFrame = navigation[0].frame, tabFrame = tabs[0].frame
                guard (forms + windows + navigation + tabs + bands).allSatisfy({ node in
                    let frame = node.frame
                    return [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy { $0.isFinite }
                        && !frame.isNull && !frame.isInfinite && frame.width > 1 && frame.height > 1
                }), tabFrame.minY > navigationFrame.maxY else { break }
                let upper = max(navigationFrame.maxY, bands.first?.frame.maxY ?? navigationFrame.maxY)
                let viewport = formFrame.intersection(windowFrame).intersection(CGRect(
                    x: windowFrame.minX, y: upper, width: windowFrame.width,
                    height: tabFrame.minY - upper))
                guard viewport.width > 24, viewport.height > 24,
                      ProcessInfo.processInfo.systemUptime < deadline else { break }
                let target: CGRect?
                if let optionsIdentifier {
                    let targets = nodes.filter { $0.elementType == .button && $0.identifier == optionsIdentifier
                        && (optionsTitle == nil || $0.label == optionsTitle) }
                    guard targets.count <= 1,
                          targets.allSatisfy({ $0.path.starts(with: windows[0].path) }) else { break }
                    target = targets.first?.frame
                } else {
                    // Preserve identifierless Options callers such as Sign out.
                    let exists = element.exists
                    target = exists ? element.frame : nil
                }
                if let target, [target.minX, target.minY, target.maxX, target.maxY].allSatisfy({ $0.isFinite }),
                   !target.isNull, !target.isInfinite, target.width > 0, target.height > 0,
                   viewport.contains(target), element.isHittable {
                    if optionsIdentifier == "task145.catalog.attention" {
                        r4OptionsSnapshotDiagnostic(nodes, stage: "before-single-parent-tap")
                    }
                    guard ProcessInfo.processInfo.systemUptime < deadline else { break }
                    return
                }
                guard drag < 5, ProcessInfo.processInfo.systemUptime < deadline else { break }
                let upward = target.map { $0.midY > viewport.midY } ?? true
                let distance = min(160, viewport.height - 24)
                let startY = upward ? viewport.maxY - 12 : viewport.minY + 12
                let form = app.collectionViews.element(boundBy: 0)
                let start = form.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: viewport.midX - formFrame.minX, dy: startY - formFrame.minY))
                start.press(forDuration: 0, thenDragTo: start.withOffset(CGVector(
                    dx: 0, dy: upward ? -distance : distance)), withVelocity: .fast, thenHoldForDuration: 0.2)
            }
            XCTFail("R4 control not reachable within 15 seconds and 5 drags")
            return
        }
        for drag in 0...5 {
            if element.exists && element.isHittable { return }
            guard drag < 5, ProcessInfo.processInfo.systemUptime < deadline else { break }
            let keyboard = app.keyboards.firstMatch
            let editor = app.navigationBars["Edit product"]
            if keyboard.exists && editor.exists {
                let viewport = app.frame.intersection(app.windows.firstMatch.frame)
                var upper = max(viewport.minY + 12, editor.frame.maxY + 12)
                let band = app.otherElements["task144.controlled.editor.band"]
                if band.exists { upper = max(upper, band.frame.maxY + 12) }
                var lower = min(viewport.maxY, keyboard.frame.minY) - 12
                // The predictive/input-assistant strip sits ABOVE Keyboard's
                // frame. The historical app swipe began on this strip, so the
                // Form never received any of the five real gestures.
                let assistant = app.otherElements["SystemInputAssistantView"]
                if assistant.exists {
                    let covered = assistant.frame.intersection(viewport)
                    if covered.width > 0 && covered.height > 0 { lower = min(lower, covered.minY - 12) }
                }
                guard lower > upper + 16, ProcessInfo.processInfo.systemUptime < deadline else { break }
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(
                    CGVector(dx: viewport.minX + 24 - app.frame.minX, dy: lower - app.frame.minY))
                start.press(forDuration: 0, thenDragTo: start.withOffset(
                    CGVector(dx: 0, dy: -min(200, lower - upper))), withVelocity: .slow, thenHoldForDuration: 0.2)
            } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable, "R4 control not reachable within 15 seconds and 5 drags")
    }
    private func r4OptionsSnapshotDiagnostic(_ nodes: [C3OptionsSnapshotNode], stage: String) {
        func bounded(_ text: String, utf8Limit: Int) -> String {
            var bytes = Array(text.utf8.prefix(utf8Limit))
            while String(bytes: bytes, encoding: .utf8) == nil { bytes.removeLast() }
            return String(decoding: bytes, as: UTF8.self)
        }
        func describe(_ node: C3OptionsSnapshotNode) -> [String: Any] {
            let raw: Any
            if let value = node.rawValue as? String { raw = bounded(value, utf8Limit: 512) }
            else if let value = node.rawValue as? NSNumber, value.doubleValue.isFinite { raw = value }
            else { raw = NSNull() }
            return ["type": node.elementType.rawValue, "identifier": node.identifier,
                "label": bounded(node.label, utf8Limit: 512), "frame": String(describing: node.frame),
                "isSelected": node.isSelected, "value": raw,
                "valueTruncated": ((node.rawValue as? String)?.utf8.count ?? 0) > 512, "valueType": node.rawValue.map { String(reflecting: type(of: $0)) } ?? "nil"]
        }
        let attention = nodes.filter { $0.identifier.hasPrefix("task145.catalog.attention") }
        let context = nodes.filter { node in
            [.window, .navigationBar, .collectionView, .tabBar].contains(node.elementType)
                || node.identifier == "task144.controlled.band"
                || (node.elementType == .button && node.label == "Options")
        }
        let runtime = nodes.first { $0.elementType == .button && $0.identifier == "task144.controlled.release" }?.value
        let source = nodes.first { $0.elementType == .button && $0.identifier == "task144.controlled.r4-peer" }?.value
        let encoded = source.flatMap { $0.utf8.count <= 43692 ? $0 : nil }
        let ledger = encoded.flatMap { Data(base64Encoded: $0) }.flatMap { data -> [String: Any]? in
            guard data.count <= 32768 else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        let product = ledger?["product"] as? [String: Any]
        let summary: [String: Any] = ["stage": stage, "source": "one-public-app.snapshot",
            "runnerNamespace": runID, "attentionNodeCount": attention.count, "attentionCapped": attention.count > 16,
            "attention": attention.prefix(16).map(describe), "contextNodeCount": context.count,
            "contextCapped": context.count > 16, "context": context.prefix(16).map(describe),
            "businessSummaryObserved": nodes.contains { $0.identifier == "options.sync-business-summary" },
            "businessSummaryUnavailableObserved": nodes.contains { $0.identifier == "options.business-summary-unavailable" },
            "runtimeReadback": runtime.map { bounded($0, utf8Limit: 2048) } ?? "unavailable",
            "runtimeReadbackTruncated": (runtime?.utf8.count ?? 0) > 2048,
            "ledgerEncodedOverCap": (source?.utf8.count ?? 0) > 43692,
            "ledgerRun": ledger?["runID"] as? String ?? "unavailable",
            "generation": ledger?["generationID"] as? String ?? "unavailable",
            "productID": product?["id"] as? String ?? "unavailable",
            "productTitle": product?["product_name"] as? String ?? "unavailable"]
        let data = (try? JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys]))
            ?? Data("R4 snapshot diagnostic serialization unavailable".utf8)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "R4 coherent Options \(stage)"; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func r4Await(_ suffix: String, timeout: TimeInterval) throws {
        let seen = app.staticTexts["task145.r4." + suffix].waitForExistence(timeout: timeout)
        if !seen { captureControlledAutomaticReadback() }
        XCTAssertTrue(seen, "R4 prerequisite failed: \(suffix); dependent assertions NOT_TRAVERSED")
    }
    private func r4ObjectBytes(_ value: Any?) throws -> Data {
        try JSONSerialization.data(withJSONObject: XCTUnwrap(value), options: [.sortedKeys])
    }
    private func r4Ledger(_ stage: String, inEditor: Bool) throws -> [String: Any] {
        let id = inEditor ? "task144.controlled.editor.r4-peer" : "task144.controlled.r4-peer"
        let data = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(app.buttons[id].value as? String)))
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let evidence = XCTAttachment(string: String(decoding: data, as: UTF8.self))
        evidence.name = "R23 R4 " + stage; evidence.lifetime = .keepAlways; add(evidence)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "R23 R4 UI " + stage; screenshot.lifetime = .keepAlways; add(screenshot)
        return result
    }

    func testR23RealEditorRetainsMixedPeerConflictAndOffersReviewWithoutPartialSave() {
        app.launchEnvironment["TASK145_EDITOR_CONFLICT_PROBE"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
        let row = app.staticTexts["Safe local baseline"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        positionNameInEditorViewport(name)
        replaceText(in: name, with: "R23 local desired name")
        app.buttons["task144.controlled.editor.peer-apply"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task145.editor.peer-applied"].waitForExistence(timeout: 5),
                      "The controlled peer must cross the real qualified targeted fetch/apply before the oracle")
        XCTAssertTrue(name.waitForExistence(timeout: 5),
                      "The production incremental commit must retain current local authority and the mounted editor")
        XCTAssertEqual(name.value as? String, "R23 local desired name")
        app.buttons["Save"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "R23 local desired name")
        app.buttons["task144.controlled.editor.peer-readback"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["task145.editor.no-partial-save"].waitForExistence(timeout: 5),
                      "A fresh context must retain both peer values and no intent after the rejected Save")
        let evidence = XCTAttachment(screenshot: app.screenshot())
        evidence.name = "R23 real editor rejected Save and retained draft before review oracle"
        evidence.lifetime = .keepAlways
        add(evidence)
        let review = app.buttons["task145.product.review.open"]
        XCTAssertTrue(review.waitForExistence(timeout: 5),
                      "A same-field conflict must expose review in the real editor, not only a generic Save error")
    }

    // R23 draft review: actual controls and guarded Save. These three scenarios
    // complement the immutable RED selector above, not the T18 visual matrix.
    func testR23MixedDraftReviewKeepsOnlySelectedFieldsAndRechecksNewPeerBeforeSave() throws {
        let desired = "R23 chosen local name"
        let name = try r3LaunchEditor("mixed")
        let second = app.textFields["Second name"]
        try r3Require(second.exists, "real-second-name-field")
        try r3Show(second, up: true); second.tap(); second.typeText("R23 unselected local second")
        positionNameInEditorViewport(name)
        replaceText(in: name, with: desired)
        try r3SelectAllName(name)
        let selection = try r3Native("before peer, full native selection")
        XCTAssertEqual(selection["selectionStart"] as? Int, 0)
        XCTAssertEqual(selection["selectionEnd"] as? Int, desired.utf16.count)
        try r3Peer(step: 1)
        XCTAssertEqual(name.value as? String, desired)
        app.buttons["Save"].tap()
        XCTAssertEqual(name.value as? String, desired)
        let rejected = try r3Ledger("peer1 rejected Save; no partial mutation", context: .editor)
        try r3AssertPeerOnly(rejected, step: 1)
        try r3OpenReview()
        try r3AssertReviewValues(base: "Safe local baseline", desired: desired, current: "R23 peer name 1",
            stage: "review-real-base-desired-current")
        app.buttons["Back to editing"].tap()
        try r3WaitNativeSelection(text: desired, start: 0, end: desired.utf16.count)
        // Keyboard entry without tapping/refocusing must replace the retained range.
        app.typeText(desired)
        XCTAssertEqual(name.value as? String, desired)
        XCTAssertEqual(second.value as? String, "R23 unselected local second")
        try r3AssertPeerOnly(r3Ledger("review Cancel preserves DB and original form", context: .editor), step: 1)
        try r3OpenReview()
        let keepName = app.switches["task145.product.review.keep.productName"]
        let reviewRoots = app.otherElements.matching(identifier: "task145.product.review")
        let allKeepNames = app.switches.matching(identifier: "task145.product.review.keep.productName")
        try r3Show(keepName, up: true)
        try r3Require(reviewRoots.count == 1 && reviewRoots.element.identifier == "task145.product.review"
            && allKeepNames.count == 1
            && reviewRoots.element.switches.matching(identifier: "task145.product.review.keep.productName").count == 1,
            "unique-review-name-switch-before-single-tap")
        let keepNameBefore = try keepName.snapshot()
        // The default Toggle exports a composite row plus one native track.
        // Qualify the track in this SAME BEFORE capture; never reuse AFTER geometry.
        let nativeNameTracks = keepNameBefore.children.filter { $0.elementType == .switch }
        let nameRowFrame = keepNameBefore.frame
        let nameTrackFrame = nativeNameTracks.count == 1 ? nativeNameTracks[0].frame : CGRect.null
        let nameTrackTarget = CGVector(dx: (nameTrackFrame.midX - nameRowFrame.minX) / nameRowFrame.width,
            dy: (nameTrackFrame.midY - nameRowFrame.minY) / nameRowFrame.height)
        let keepNameBeforeEvidence = XCTAttachment(string: String(decoding: try r3JSON([
            "phase": "before-single-tap", "identifier": keepNameBefore.identifier,
            "elementType": keepNameBefore.elementType.rawValue, "label": keepNameBefore.label,
            "value": keepNameBefore.value ?? NSNull(), "nativeTrackCount": nativeNameTracks.count,
            "rowFrame": String(describing: nameRowFrame), "nativeTrackFrame": String(describing: nameTrackFrame),
            "normalizedNativeTrackTarget": String(describing: nameTrackTarget)
        ]), as: UTF8.self))
        keepNameBeforeEvidence.name = "R23 review Name switch before the original single tap"
        keepNameBeforeEvidence.lifetime = .keepAlways; add(keepNameBeforeEvidence)
        try r3Require(keepNameBefore.elementType == .switch
            && keepNameBefore.identifier == "task145.product.review.keep.productName"
            && (keepNameBefore.value as? String) == "0", "review-name-off-before-single-tap")
        try r3Require(nativeNameTracks.count == 1, "unique-native-review-name-track-before-single-tap")
        try r3Require([nameRowFrame.minX, nameRowFrame.minY, nameRowFrame.width, nameRowFrame.height,
            nameTrackFrame.minX, nameTrackFrame.minY, nameTrackFrame.width, nameTrackFrame.height].allSatisfy { $0.isFinite }
            && nameRowFrame.width > 0 && nameRowFrame.height > 0
            && nameTrackFrame.width > 0 && nameTrackFrame.height > 0 && nameRowFrame.contains(nameTrackFrame)
            && nativeNameTracks[0].isEnabled && (nativeNameTracks[0].value as? String) == "0",
            "native-review-name-track-geometry-before-single-tap")
        try r3Require(nameTrackTarget.dx > 0 && nameTrackTarget.dx < 1
            && nameTrackTarget.dy > 0 && nameTrackTarget.dy < 1, "native-review-name-track-target-before-single-tap")
        keepName.coordinate(withNormalizedOffset: nameTrackTarget).tap()
        try r3Require(reviewRoots.count == 1 && reviewRoots.element.identifier == "task145.product.review"
            && allKeepNames.count == 1
            && reviewRoots.element.switches.matching(identifier: "task145.product.review.keep.productName").count == 1,
            "unique-review-name-switch-after-single-tap")
        let keepNameAfter = try keepName.snapshot()
        let keepNameAfterEvidence = XCTAttachment(string: String(decoding: try r3JSON([
            "phase": "after-single-tap", "identifier": keepNameAfter.identifier,
            "elementType": keepNameAfter.elementType.rawValue, "label": keepNameAfter.label,
            "value": keepNameAfter.value ?? NSNull()
        ]), as: UTF8.self))
        keepNameAfterEvidence.name = "R23 review Name switch after the original single tap"
        keepNameAfterEvidence.lifetime = .keepAlways; add(keepNameAfterEvidence)
        try r3Require(keepNameAfter.elementType == .switch
            && keepNameAfter.identifier == keepNameBefore.identifier
            && keepNameAfter.label == keepNameBefore.label
            && (keepNameAfter.value as? String) == "1", "review-name-on-after-single-tap")
        let keepSecond = app.switches["task145.product.review.keep.secondProductName"]
        try r3Show(keepSecond, up: true)
        XCTAssertEqual(keepSecond.value as? String, "0", "Unselected local second name must not become intentional")
        let choose = app.buttons["task145.product.review.edit-selected"]
        try r3Show(choose, up: true); choose.tap()
        try r3Require(name.waitForExistence(timeout: 5), "prepared-real-editor")
        XCTAssertEqual(name.value as? String, desired)
        XCTAssertEqual(second.value as? String, "R23 peer second 1")
        XCTAssertEqual(app.textFields[Self.r23ItemCodeFieldLabel].value as? String, "R23 peer item 1")
        try r3AssertPeerOnly(r3Ledger("choice changes draft only; no commit", context: .editor), step: 1)
        // A second peer update after the choice must still reject the fresh Save.
        try r3Peer(step: 2)
        app.buttons["Save"].tap()
        try r3Require(name.waitForExistence(timeout: 5), "new-peer-rejects-old-review-choice")
        XCTAssertEqual(name.value as? String, desired)
        try r3AssertPeerOnly(r3Ledger("peer2 causes fresh Save rejection", context: .editor), step: 2)
        try r3OpenReview()
        try r3AssertReviewValues(base: "R23 peer name 1", desired: desired, current: "R23 peer name 2",
            stage: "explicit-choice-established-peer1-as-new-base")
        try r3Show(keepName, up: true)
        try r3Require(reviewRoots.count == 1 && reviewRoots.element.identifier == "task145.product.review"
            && allKeepNames.count == 1
            && reviewRoots.element.switches.matching(identifier: "task145.product.review.keep.productName").count == 1,
            "second-unique-review-name-switch-before-single-tap")
        let keepNameSecondBefore = try keepName.snapshot()
        // The default Toggle exports a composite row plus one native track.
        // Qualify the track in this SAME BEFORE capture; never reuse AFTER geometry.
        let nativeNameSecondTracks = keepNameSecondBefore.children.filter { $0.elementType == .switch }
        let nameSecondRowFrame = keepNameSecondBefore.frame
        let nameSecondTrackFrame = nativeNameSecondTracks.count == 1 ? nativeNameSecondTracks[0].frame : CGRect.null
        let nameSecondTrackTarget = CGVector(dx: (nameSecondTrackFrame.midX - nameSecondRowFrame.minX) / nameSecondRowFrame.width,
            dy: (nameSecondTrackFrame.midY - nameSecondRowFrame.minY) / nameSecondRowFrame.height)
        let keepNameSecondBeforeEvidence = XCTAttachment(string: String(decoding: try r3JSON([
            "phase": "before-second-single-tap", "identifier": keepNameSecondBefore.identifier,
            "elementType": keepNameSecondBefore.elementType.rawValue, "label": keepNameSecondBefore.label,
            "value": keepNameSecondBefore.value ?? NSNull(), "nativeTrackCount": nativeNameSecondTracks.count,
            "rowFrame": String(describing: nameSecondRowFrame), "nativeTrackFrame": String(describing: nameSecondTrackFrame),
            "normalizedNativeTrackTarget": String(describing: nameSecondTrackTarget)
        ]), as: UTF8.self))
        keepNameSecondBeforeEvidence.name = "R23 review Name switch before the second original single tap"
        keepNameSecondBeforeEvidence.lifetime = .keepAlways; add(keepNameSecondBeforeEvidence)
        try r3Require(keepNameSecondBefore.elementType == .switch
            && keepNameSecondBefore.identifier == "task145.product.review.keep.productName"
            && (keepNameSecondBefore.value as? String) == "0", "second-review-name-off-before-single-tap")
        try r3Require(nativeNameSecondTracks.count == 1, "second-unique-native-review-name-track-before-single-tap")
        try r3Require([nameSecondRowFrame.minX, nameSecondRowFrame.minY, nameSecondRowFrame.width, nameSecondRowFrame.height,
            nameSecondTrackFrame.minX, nameSecondTrackFrame.minY, nameSecondTrackFrame.width, nameSecondTrackFrame.height].allSatisfy { $0.isFinite }
            && nameSecondRowFrame.width > 0 && nameSecondRowFrame.height > 0
            && nameSecondTrackFrame.width > 0 && nameSecondTrackFrame.height > 0 && nameSecondRowFrame.contains(nameSecondTrackFrame)
            && nativeNameSecondTracks[0].isEnabled && (nativeNameSecondTracks[0].value as? String) == "0",
            "second-native-review-name-track-geometry-before-single-tap")
        try r3Require(nameSecondTrackTarget.dx > 0 && nameSecondTrackTarget.dx < 1
            && nameSecondTrackTarget.dy > 0 && nameSecondTrackTarget.dy < 1, "second-native-review-name-track-target-before-single-tap")
        keepName.coordinate(withNormalizedOffset: nameSecondTrackTarget).tap()
        try r3Require(reviewRoots.count == 1 && reviewRoots.element.identifier == "task145.product.review"
            && allKeepNames.count == 1
            && reviewRoots.element.switches.matching(identifier: "task145.product.review.keep.productName").count == 1,
            "second-unique-review-name-switch-after-single-tap")
        let keepNameSecondAfter = try keepName.snapshot()
        let keepNameSecondAfterEvidence = XCTAttachment(string: String(decoding: try r3JSON([
            "phase": "after-second-single-tap", "identifier": keepNameSecondAfter.identifier,
            "elementType": keepNameSecondAfter.elementType.rawValue, "label": keepNameSecondAfter.label,
            "value": keepNameSecondAfter.value ?? NSNull()
        ]), as: UTF8.self))
        keepNameSecondAfterEvidence.name = "R23 review Name switch after the second original single tap"
        keepNameSecondAfterEvidence.lifetime = .keepAlways; add(keepNameSecondAfterEvidence)
        try r3Require(keepNameSecondAfter.elementType == .switch
            && keepNameSecondAfter.identifier == keepNameSecondBefore.identifier
            && keepNameSecondAfter.label == keepNameSecondBefore.label
            && (keepNameSecondAfter.value as? String) == "1", "second-review-name-on-after-single-tap")
        try r3Require(!app.switches["task145.product.review.keep.secondProductName"].exists,
            "peer-only-second-name-is-not-intentional-after-rebase")
        try r3Show(choose, up: true); choose.tap()
        try r3Require(name.waitForExistence(timeout: 5), "second-prepared-editor")
        app.buttons["Save"].tap()
        try r3Require(app.staticTexts[desired].waitForExistence(timeout: 5), "mixed-choice-real-Save-dismissed")
        try r3AwaitEditorDismissal(name)
        let saved = try r3Ledger("selected name durable; disjoint peer fields preserved", context: .root)
        try r3AssertSavedNameOnly(saved, name: desired, item: "R23 peer item 2", second: "R23 peer second 2")
        // A later unsaved draft and Cancel must retain the previous durable token.
        app.staticTexts[desired].tap()
        try r3Require(name.waitForExistence(timeout: 5), "reopen-durable-product")
        positionNameInEditorViewport(name); replaceText(in: name, with: "R23 discarded draft")
        app.buttons["Cancel"].tap()
        let cancelled = try r3Ledger("editor Cancel leaves prior product and pending token unchanged", context: .root)
        XCTAssertEqual(try r3JSON(saved["pending"]), try r3JSON(cancelled["pending"]))
        XCTAssertEqual(try r3JSON(saved["products"]), try r3JSON(cancelled["products"]))
    }

    func testR23UseCurrentThenEditorCancelDoesNotRollBackPeerAndDisjointSaveMerges() throws {
        let name = try r3LaunchEditor("use-current")
        replaceText(in: name, with: "R23 abandoned local draft", positionViewportAfterFocus: true)
        try r3Peer(step: 1)
        app.buttons["Save"].tap()
        try r3Require(name.waitForExistence(timeout: 5), "overlap-rejected-before-use-current")
        try r3OpenReview()
        let useCurrent = app.buttons["task145.product.review.use-current"]
        try r3Show(useCurrent, up: true); useCurrent.tap()
        try r3Require(name.waitForExistence(timeout: 5), "use-current-prepares-editor-only")
        XCTAssertEqual(name.value as? String, "R23 peer name 1")
        XCTAssertEqual(app.textFields[Self.r23ItemCodeFieldLabel].value as? String, "R23 peer item 1")
        XCTAssertEqual(app.textFields["Second name"].value as? String, "R23 peer second 1")
        let beforeCancel = try r3Ledger("use current has no durable side effect", context: .editor)
        try r3AssertPeerOnly(beforeCancel, step: 1)
        app.buttons["Cancel"].tap()
        try r3Require(app.staticTexts["R23 peer name 1"].waitForExistence(timeout: 5), "editor-Cancel-shows-peer-current")
        let afterCancel = try r3Ledger("editor Cancel does not restore opening base", context: .root)
        XCTAssertEqual(try r3JSON(beforeCancel["products"]), try r3JSON(afterCancel["products"]))
        try r3AssertPeerOnly(afterCancel, step: 1)
        app.staticTexts["R23 peer name 1"].tap()
        try r3Require(name.waitForExistence(timeout: 5), "new-editor-uses-peer-base")
        replaceText(in: name, with: "R23 disjoint local name", positionViewportAfterFocus: true)
        try r3Peer(step: 2) // This peer changes only itemNumber.
        app.buttons["Save"].tap()
        try r3Require(app.staticTexts["R23 disjoint local name"].waitForExistence(timeout: 5),
            "disjoint-Save-commits-without-required-review")
        try r3AwaitEditorDismissal(name)
        try r3AssertSavedNameOnly(r3Ledger("direct disjoint Save", context: .root), name: "R23 disjoint local name",
            item: "R23 peer item 2", second: "R23 peer second 1")
    }

    func testR23DraftSurvivesRealCutoverThenRemoteDeleteAndMissingTargetRebindWithoutResurrection() throws {
        let initial = "R23 unsaved through cutover"
        let name = try r3LaunchEditor("deleted-rebind")
        positionNameInEditorViewport(name); replaceText(in: name, with: initial)
        let before = try r3Native("draft focus and caret before actual cutover")
        XCTAssertEqual(before["selectionStart"] as? Int, initial.utf16.count)
        XCTAssertEqual(before["selectionEnd"] as? Int, initial.utf16.count)
        let original = try r3Ledger("qualified original generation", context: .editor)
        app.buttons["task144.controlled.editor.release"].press(forDuration: 1.2)
        try r3AwaitReattachedEditorMarker("task144.controlled.activated", timeout: 20, stage: "real-first-cutover")
        try r3WaitNativeSelection(text: initial, start: initial.utf16.count, end: initial.utf16.count)
        app.typeText(" continued")
        let desired = initial + " continued"
        XCTAssertEqual(name.value as? String, desired)
        let first = try r3Ledger("draft reattached to qualified new generation", context: .editor)
        try r3Require(first["generationChanged"] as? Bool == true, "new-generation-not-old-model")
        XCTAssertNotEqual(original["generation"] as? String, first["generation"] as? String)
        try r3Peer(step: 1)
        app.buttons["Save"].tap()
        try r3Require(name.waitForExistence(timeout: 5), "deleted-record-keeps-readable-draft")
        XCTAssertEqual(name.value as? String, desired)
        try r3OpenReview()
        try r3Require(app.staticTexts["This product is no longer available or could not be identified safely. Your changes have not been saved."].exists,
            "typed-unavailable-review")
        try r3Require(!app.buttons["task145.product.review.use-current"].exists
            && !app.buttons["task145.product.review.edit-selected"].exists, "no-resurrection-choice")
        app.buttons["Back to editing"].tap()
        let deleted = try r3Ledger("deleted target has no new product or pending intent", context: .editor)
        XCTAssertEqual((deleted["products"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual(deleted["activeProducts"] as? Int, 0)
        XCTAssertEqual(deleted["tombstones"] as? Int, 1)
        XCTAssertEqual((deleted["pending"] as? [[String: Any]])?.count, 0)
        try r3PressControl("rebind", context: .editor)
        let unresolved = app.descendants(matching: .any).matching(identifier: "task145.product.unresolved").firstMatch
        try r3Require(unresolved.waitForExistence(timeout: 20), "actual-second-cutover-missing-record-draft-surface")
        let unresolvedRoots = app.otherElements.matching(identifier: "task145.product.unresolved")
        let unresolvedNames = unresolvedRoots.staticTexts.matching(NSPredicate(
            format: "label == %@", "Product name, " + desired))
        try r3Require(unresolvedRoots.count == 1 && unresolvedNames.count == 1 && unresolvedNames.element.exists,
            "unresolved-draft-retains-user-value")
        try r3Require(!app.buttons["Save"].exists, "unresolved-rebind-cannot-create-product")
        let discard = app.buttons["task145.product.unresolved.discard"]
        try r3Show(discard, up: true); discard.tap()
        try r3AwaitMarker("task145.r3.deleted-rebound", context: .root, timeout: 5, stage: "real-second-recovery-finalized")
        let final = try r3Ledger("explicit discard after missing target rebind", context: .root)
        try r3Require(final["secondRecovery"] as? Bool == true, "completed-second-recovery")
        XCTAssertNotEqual(first["generation"] as? String, final["generation"] as? String)
        XCTAssertEqual((final["products"] as? [[String: Any]])?.count, 0)
        XCTAssertEqual((final["pending"] as? [[String: Any]])?.count, 0)
        XCTAssertEqual(final["productWriteEntries"] as? Int, 0)
    }

    private enum R3UIStop: Error { case failedBoundary(String) }
    private func r3Require(_ condition: Bool, _ stage: String) throws {
        if !condition {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "R23 draft FIRST-FAIL " + stage; hierarchy.lifetime = .keepAlways; add(hierarchy)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "R23 draft FIRST-FAIL " + stage; screenshot.lifetime = .keepAlways; add(screenshot)
            XCTFail(stage)
            throw R3UIStop.failedBoundary(stage)
        }
    }
    private func r3LaunchEditor(_ scenario: String) throws -> XCUIElement {
        app.launchEnvironment["TASK145_DRAFT_REVIEW_UI"] = scenario
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_OBSERVE_NATIVE_NAME"] = "1"
        app.launch()
        try r3Require(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20), "qualified-held-recovery")
        let row = app.staticTexts["Safe local baseline"]
        try r3Require(row.waitForExistence(timeout: 5) && row.isHittable, "real-product-row"); row.tap()
        let field = app.textFields["task144.product.name"]
        try r3Require(field.waitForExistence(timeout: 5), "real-editor-mounted")
        return field
    }
    private func r3AwaitEditorDismissal(_ field: XCUIElement) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !field.exists }, object: nil)
        try r3Require(XCTWaiter.wait(for: [expectation], timeout: 5) == .completed, "successful-Save-dismisses-real-editor")
    }
    private func r3Show(_ element: XCUIElement, up: Bool) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 15
        for drag in 0...5 {
            let targetExists = element.exists
            if targetExists && element.isHittable { return }
            guard drag < 5, ProcessInfo.processInfo.systemUptime < deadline else { break }
            let editor = app.navigationBars["Edit product"]
            if targetExists && element.elementType == .textField && editor.exists {
                let identifier = element.identifier.isEmpty ? element.label : element.identifier
                let form = app.collectionViews.containing(.textField, identifier: identifier).firstMatch
                try r3Require(form.exists, "editor-field-native-Form")
                let applicationFrame = app.frame
                let viewport = form.frame.intersection(applicationFrame)
                var upper = max(viewport.minY, editor.frame.maxY) + 12
                let band = app.otherElements["task144.controlled.editor.band"]
                if band.exists { upper = max(upper, band.frame.maxY + 12) }
                var lower = viewport.maxY - 12
                let keyboard = app.keyboards.firstMatch
                if keyboard.exists { lower = min(lower, keyboard.frame.minY - 12) }
                let assistant = app.otherElements["SystemInputAssistantView"]
                if assistant.exists {
                    let covered = assistant.frame.intersection(viewport)
                    if covered.width > 0 && covered.height > 0 { lower = min(lower, covered.minY - 12) }
                }
                let targetFrame = element.frame
                let hasTargetFrame = targetFrame.width > 0 && targetFrame.height > 0
                    && [targetFrame.minX, targetFrame.maxX, targetFrame.minY, targetFrame.maxY].allSatisfy { $0.isFinite }
                try r3Require(viewport.width > 48 && lower > upper + 16
                    && [upper, lower].allSatisfy { $0.isFinite },
                    "editor-field-measured-content-band")
                var upward = up
                if hasTargetFrame {
                    if targetFrame.minY < upper { upward = false }
                    else if targetFrame.maxY > lower { upward = true }
                }
                let travel = min(200, (lower - upper) / 2)
                let startY = upward ? lower : upper
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(
                    CGVector(dx: viewport.minX + 24 - applicationFrame.minX, dy: startY - applicationFrame.minY))
                try r3Require(ProcessInfo.processInfo.systemUptime < deadline,
                    "editor-field-existing-drag-deadline")
                start.press(forDuration: 0, thenDragTo: start.withOffset(
                    CGVector(dx: 0, dy: upward ? -travel : travel)), withVelocity: .slow, thenHoldForDuration: 0.2)
            } else if up { app.swipeUp() } else { app.swipeDown() }
        }
        try r3Require(element.exists && element.isHittable, "control-reachable-within-15s-five-drags")
    }
    private func r3AssertReviewValues(base: String, desired: String, current: String, stage: String) throws {
        let roots = app.otherElements.matching(identifier: "task145.product.review")
        try r3Require(roots.count == 1, "unique-draft-review-root")
        let review = roots.element
        try r3Require(review.navigationBars["Review changes"].exists, "draft-review-root-navigation")
        let baseRows = review.staticTexts.matching(NSPredicate(format: "label == %@", "When opened, " + base))
        let desiredRows = review.staticTexts.matching(NSPredicate(format: "label == %@", "Your changes, " + desired))
        let currentRows = review.staticTexts.matching(NSPredicate(format: "label == %@", "Current version, " + current))
        try r3Show(baseRows.element, up: true)
        try r3Require(roots.count == 1 && baseRows.count == 1 && baseRows.element.exists
            && desiredRows.count == 1 && desiredRows.element.exists
            && currentRows.count == 1 && currentRows.element.exists, stage)
    }
    private enum R3ControlContext {
        case root, editor
        var identifier: String {
            switch self {
            case .root: return "task144.controlled.band"
            case .editor: return "task144.controlled.editor.band"
            }
        }
    }
    private func r3ControlBand(_ context: R3ControlContext) throws -> XCUIElement {
        let bands = app.otherElements.matching(identifier: context.identifier)
        try r3Require(bands.count == 1, "unique-control-band-" + context.identifier)
        if case .root = context {
            try r3Require(app.otherElements.matching(identifier: R3ControlContext.editor.identifier).count == 0,
                "root-controls-require-editor-dismissal")
        }
        return bands.element
    }
    private func r3AwaitMarker(_ identifier: String, context: R3ControlContext,
                               timeout: TimeInterval, stage: String) throws {
        let band = try r3ControlBand(context)
        let marker = band.staticTexts.matching(identifier: identifier)
        try r3Require(marker.element.waitForExistence(timeout: timeout) && marker.count == 1, stage)
    }
    private func r3AwaitReattachedEditorMarker(_ identifier: String, timeout: TimeInterval, stage: String) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        let bands = app.otherElements.matching(identifier: R3ControlContext.editor.identifier)
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard ProcessInfo.processInfo.systemUptime < deadline, bands.count == 1 else { return false }
            // Probe query counts only; resolve the unique editor after the wait.
            let marker = bands.staticTexts.matching(identifier: identifier)
            let ready = marker.count == 1
            return ready && ProcessInfo.processInfo.systemUptime <= deadline
        }, object: nil)
        let remaining = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        let result = XCTWaiter.wait(for: [expectation], timeout: remaining)
        try r3Require(result == .completed, stage)
        let band = try r3ControlBand(.editor)
        let marker = band.staticTexts.matching(identifier: identifier)
        try r3Require(marker.count == 1 && marker.element.exists
            && ProcessInfo.processInfo.systemUptime <= deadline, stage)
    }
    private func r3PressControl(_ suffix: String, context: R3ControlContext) throws {
        let band = try r3ControlBand(context)
        let controls = band.buttons.matching(identifier: "task145.r3." + suffix)
        let control = controls.element
        try r3Require(control.waitForExistence(timeout: 5) && controls.count == 1 && control.isHittable,
            "control-" + suffix)
        control.press(forDuration: 1.2)
    }
    private func r3Peer(step: Int) throws {
        try r3PressControl("peer", context: .editor)
        try r3AwaitMarker("task145.r3.peer-applied.\(step)", context: .editor,
            timeout: 5, stage: "qualified-peer-\(step)")
    }
    private func r3OpenReview() throws {
        let open = app.buttons["task145.product.review.open"]
        try r3Show(open, up: false); open.tap()
        try r3Require(app.navigationBars["Review changes"].waitForExistence(timeout: 5), "actual-draft-review-sheet")
    }
    private func r3JSON(_ object: Any?) throws -> Data {
        try JSONSerialization.data(withJSONObject: XCTUnwrap(object), options: [.sortedKeys])
    }
    private enum R3LedgerObservationProbe {
        case empty, malformed, observation(Int)
    }
    private struct R3LedgerObservationHeader: Decodable {
        let observation: Int
    }
    private static func r3LedgerObservationProbe(_ encoded: String?) -> R3LedgerObservationProbe {
        guard let encoded else { return .malformed }
        // The fixture intentionally publishes an empty value before its first observe.
        guard !encoded.isEmpty else { return .empty }
        guard let data = Data(base64Encoded: encoded), !data.isEmpty,
              let header = try? JSONDecoder().decode(R3LedgerObservationHeader.self, from: data) else {
            return .malformed
        }
        return .observation(header.observation)
    }
    private func r3Ledger(_ stage: String, context: R3ControlContext) throws -> [String: Any] {
        let band = try r3ControlBand(context)
        let ledgers = band.staticTexts.matching(identifier: "task145.r3.ledger")
        try r3Require(ledgers.count == 1, "unique-ledger-" + stage)
        let element = ledgers.element
        func read() throws -> [String: Any] {
            let encoded = try XCTUnwrap(element.value as? String)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(Data(base64Encoded: encoded))) as? [String: Any])
        }
        let previous: Int
        switch Self.r3LedgerObservationProbe(element.value as? String) {
        case .empty: previous = 0
        case .observation(let observation): previous = observation
        case .malformed:
            let boundary = "malformed-initial-ledger-" + stage
            try r3Require(false, boundary)
            throw R3UIStop.failedBoundary(boundary)
        }
        try r3PressControl("observe", context: context)
        var malformedProbeObserved = false
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard !malformedProbeObserved else { return false }
            switch Self.r3LedgerObservationProbe(element.value as? String) {
            case .empty: return false
            case .malformed:
                malformedProbeObserved = true
                return false
            case .observation(let observation): return observation > previous
            }
        }, object: nil)
        let freshResult = XCTWaiter.wait(for: [expectation], timeout: 5)
        try r3Require(!malformedProbeObserved, "malformed-readback-ledger-" + stage)
        try r3Require(freshResult == .completed, "fresh-readback-" + stage)
        let value = try read()
        let attachment = XCTAttachment(data: try r3JSON(value), uniformTypeIdentifier: "public.json")
        attachment.name = "R23 draft " + stage; attachment.lifetime = .keepAlways; add(attachment)
        try r3Require(value["namespace"] as? String == runID && value["status"] as? String == "FRESH_QUALIFIED_READ"
            && value["bodyProof"] as? Bool == true && value["localAccess"] as? Bool == true,
            "qualified-current-readback-" + stage)
        XCTAssertEqual((value["failureFacts"] as? [String])?.count, 0)
        XCTAssertEqual(value["productWriteEntries"] as? Int, 0)
        XCTAssertEqual(value["eventEntries"] as? Int, 0)
        return value
    }
    private func r3AssertPeerOnly(_ value: [String: Any], step: Int) throws {
        let products = try XCTUnwrap(value["products"] as? [[String: Any]])
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?["name"] as? String, "R23 peer name \(step)")
        XCTAssertEqual(products.first?["item"] as? String, "R23 peer item \(step)")
        XCTAssertEqual(products.first?["second"] as? String, "R23 peer second \(step)")
        XCTAssertEqual((value["pending"] as? [[String: Any]])?.count, 0)
        XCTAssertEqual(value["prices"] as? Int, 0)
    }
    private func r3AssertSavedNameOnly(_ value: [String: Any], name: String, item: String, second: String) throws {
        let products = try XCTUnwrap(value["products"] as? [[String: Any]])
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?["remoteID"] as? String, "14400000-0000-4000-8000-000000000003")
        XCTAssertEqual(products.first?["barcode"] as? String, "LOCAL-ROOT")
        XCTAssertEqual(products.first?["name"] as? String, name)
        XCTAssertEqual(products.first?["item"] as? String, item)
        XCTAssertEqual(products.first?["second"] as? String, second)
        let pending = try XCTUnwrap(value["pending"] as? [[String: Any]])
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?["entityKindRaw"] as? String, "product")
        XCTAssertEqual(pending.first?["operationRaw"] as? String, "update")
        XCTAssertEqual(pending.first?["statusRaw"] as? String, "pending")
        XCTAssertNil(pending.first?["lastAttemptAt"])
        let raw = try XCTUnwrap(pending.first?["changedFieldsRaw"] as? String)
        XCTAssertEqual(raw, "productname")
        XCTAssertEqual(value["pendingBaseIsPeer"] as? Bool, true)
        XCTAssertEqual(value["pendingMatchesProduct"] as? Bool, true)
        XCTAssertEqual(value["prices"] as? Int, 0)
    }
    private func r3Native(_ stage: String) throws -> [String: Any] {
        let node = app.descendants(matching: .any).matching(identifier: "task144.controlled.native-name-observation").firstMatch
        try r3Require(node.waitForExistence(timeout: 5), "native-observer-" + stage)
        let text = try XCTUnwrap(node.value as? String)
        let data = try XCTUnwrap(text.data(using: .utf8))
        let value = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "R23 native " + stage; attachment.lifetime = .keepAlways; add(attachment)
        try r3Require(value["status"] as? String == "EXACT_NATIVE_NAME"
            && value["isFirstResponder"] as? Bool == true && value["selectionStatus"] as? String == "EXACT_UTF16",
            "actual-first-responder-selection-" + stage)
        return value
    }
    private func r3WaitNativeSelection(text: String, start: Int, end: Int) throws {
        let node = app.otherElements.matching(NSPredicate(format: "identifier == %@",
            "task144.controlled.native-name-observation")).element
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        var lastRaw: String?
        let predicate = NSPredicate { _, _ in
            guard ProcessInfo.processInfo.systemUptime < deadline, node.exists,
                  ProcessInfo.processInfo.systemUptime < deadline,
                  let raw = node.value as? String else { return false }
            lastRaw = raw.utf8.count <= 8192 ? raw : nil
            guard ProcessInfo.processInfo.systemUptime < deadline,
                  let data = raw.data(using: .utf8),
                  let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            return ProcessInfo.processInfo.systemUptime < deadline
                && value["status"] as? String == "EXACT_NATIVE_NAME" && value["isFirstResponder"] as? Bool == true
                && value["draft"] as? String == text && value["selectionStatus"] as? String == "EXACT_UTF16"
                && value["selectionStart"] as? Int == start && value["selectionEnd"] as? Int == end
        }
        var restored = predicate.evaluate(with: nil)
        let remaining = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        if !restored, remaining > 0 {
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
            restored = XCTWaiter.wait(for: [expectation], timeout: remaining) == .completed
        }
        let qualified = restored && ProcessInfo.processInfo.systemUptime < deadline
        if !qualified, let lastRaw {
            let attachment = XCTAttachment(string: lastRaw)
            attachment.name = "R23 last native focus and selection observation before failure"
            attachment.lifetime = .keepAlways; add(attachment)
        }
        try r3Require(qualified, "native-focus-selection-restored")
        _ = try r3Native("restored focus and exact selection")
    }
    private func r3SelectAllName(_ field: XCUIElement) throws {
        field.press(forDuration: 1.1)
        let selectAll = app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ AND (elementType == %d OR elementType == %d)",
            "Select All", XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.menuItem.rawValue)).firstMatch
        try r3Require(selectAll.waitForExistence(timeout: 5), "native-select-all-menu")
        selectAll.tap()
    }

    func testRealRootRemainsUsableWithHeldRecoveryAndPreservesSavedAndUnsavedIntentAcrossCutover() {
        app.launchEnvironment["TASK146_BASE_ROOT_RUNTIME_OBSERVATION"] = "1"
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
        // Use the existing single real Form pan before this first focus too.
        // The Photo row can otherwise leave Name below the visible keyboard.
        positionNameInEditorViewport(name, nativeSelectionReadinessFollows: true)
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
        positionNameInEditorViewport(name)
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


    func testConfirmedMembershipRefusalWithdrawsBusinessAccessAndRejectsCapturedWriter() throws {
        app.launchEnvironment["TASK145_SCOPE_INCREMENTAL_UI"] = "membership-refusal"
        app.launch()
        try awaitSeq6Fact("ready")
        XCTAssertTrue(app.staticTexts["Safe local baseline"].waitForExistence(timeout: 5))
        let before = try seq6Ledger("D qualified initial nonempty scope")
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        try awaitSeq6Fact("safety-terminal")
        let denied = try seq6Ledger("D decoded revoked membership, real resolver and fenced writer denial")
        let values = try XCTUnwrap(denied["facts"] as? [String: String])
        XCTAssertEqual(values["safety-denied"], "true")
        XCTAssertEqual(values["writer-entered"], "false")
        XCTAssertEqual(values["server-membership"], "revoked")
        XCTAssertEqual(values["sdk-session-preserved"], "true")
        XCTAssertNotNil(values["captured-scope-rejected"])
        XCTAssertEqual(try seq6Facts(before)["initial-generation"], values["initial-generation"])
        XCTAssertGreaterThanOrEqual(try seq6Entries(denied, "membership-rpc-revoked").count, 1)
        try assertSeq6DeniedBusinessAndShell()
        let afterNavigation = try seq6Ledger("D denial persists through real tabs")
        XCTAssertEqual(try seq6Entries(afterNavigation, "checkpoint").count, 0)
        XCTAssertEqual(try seq6Entries(afterNavigation, "product-write").count, 0)
        XCTAssertEqual(try seq6Entries(afterNavigation, "event-write").count, 0)
    }

    func testNonemptyUnexplainedBodyCorruptionDeniesReadAndSaveWithoutReset() throws {
        app.launchEnvironment["TASK145_SCOPE_INCREMENTAL_UI"] = "corrupt-body"
        app.launch()
        try awaitSeq6Fact("ready")
        XCTAssertTrue(app.staticTexts["Safe local baseline"].waitForExistence(timeout: 5))
        let before = try seq6Ledger("E qualified nonempty body before actual corruption")
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        try awaitSeq6Fact("safety-terminal")
        let denied = try seq6Ledger("E changed body rejected by completed qualification")
        let facts = try seq6Facts(denied)
        XCTAssertEqual(facts["qualification-rejected"], "true")
        XCTAssertEqual(facts["corruption-persisted"], "true")
        XCTAssertNotEqual(facts["initial-fingerprint"], facts["corrupt-fingerprint"])
        XCTAssertEqual(try seq6Facts(before)["initial-outbox"], facts["initial-outbox"])
        XCTAssertEqual(facts["writer-entered"], "false")
        try assertSeq6DeniedBusinessAndShell()
        app.terminate(); XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try awaitSeq6Fact("corrupt-reopen-denied", timeout: 30)
        let reopened = try seq6Ledger("E fresh process rejects same corrupt nonempty generation")
        let reopenFacts = try seq6Facts(reopened)
        XCTAssertEqual(reopenFacts["reopen-denied"], "true")
        XCTAssertEqual(reopenFacts["initial-generation"], facts["initial-generation"])
        XCTAssertEqual(reopenFacts["corrupt-fingerprint"], facts["corrupt-fingerprint"])
        XCTAssertNotEqual(Int(reopenFacts["observed-pid"] ?? ""), reopened["firstPID"] as? Int)
        let readback = try XCTUnwrap(try seq6Entries(reopened, "reopen-denial-readback").last?["values"] as? [String: String])
        XCTAssertEqual(readback["products"], "1")
        XCTAssertEqual(readback["pending"], "0")
        XCTAssertEqual(readback["body-proof"], "false")
        XCTAssertEqual(readback["outbox"], facts["initial-outbox"])
        try assertSeq6DeniedBusinessAndShell()
    }

    func testHealthyIncrementalAppliesRemoteProductWithoutSnapshotReplacement() throws {
        app.launchEnvironment["TASK145_SCOPE_INCREMENTAL_UI"] = "healthy-incremental"
        app.launch()
        try awaitSeq6Fact("automatic-terminal", timeout: 45)
        XCTAssertTrue(app.staticTexts["Seq6 remote incremental product"].waitForExistence(timeout: 5))
        let ledger = try seq6Ledger("Healthy ordinary incremental body and continuation receipt")
        let summary = try XCTUnwrap(try seq6Entries(ledger, "incremental-summary").compactMap { $0["values"] as? [String: String] }
            .first { $0["applied"] == "1" })
        XCTAssertEqual(summary["before"], "41"); XCTAssertEqual(summary["after"], "42")
        XCTAssertEqual(summary["requires-recovery"], "false")
        let terminal = try XCTUnwrap(try seq6Entries(ledger, "terminal-readback").last?["values"] as? [String: String])
        XCTAssertEqual(terminal["generation"], try seq6Facts(ledger)["initial-generation"])
        XCTAssertEqual(terminal["body-proof"], "true"); XCTAssertEqual(terminal["pending"], "0")
        let results = try seq6Entries(ledger, "runtime-result").compactMap { $0["values"] as? [String: String] }
        XCTAssertTrue(results.contains { $0["continuation"] == "true" })
        XCTAssertEqual(try seq6Entries(ledger, "checkpoint").count, 0)
        XCTAssertEqual(try seq6Entries(ledger, "product-write").count, 0)
        XCTAssertEqual(try seq6Entries(ledger, "event-write").count, 0)
    }

    func testMissingEntityEventGapRequiresRecoveryWithoutAdvancingPastGap() throws {
        try runSeq6IncrementalRefusal("missing-entity-gap", reason: "sync_event_missing_entity_ids")
    }

    func testInvalidCursorRequiresContractualRecoveryWithoutBlindReset() throws {
        try runSeq6IncrementalRefusal("invalid-cursor", reason: "sync_event_invalid_cursor")
    }

    func testSnapshotChangedDuringRecoveryPreservesQualifiedOldGeneration() throws {
        app.launchEnvironment["TASK145_SCOPE_INCREMENTAL_UI"] = "snapshot-changed"
        app.launch()
        try awaitSeq6Fact("automatic-terminal", timeout: 45)
        let ledger = try seq6Ledger("Actual changed checkpoint B rejects publication")
        let terminal = try XCTUnwrap(try seq6Entries(ledger, "terminal-readback").last?["values"] as? [String: String])
        XCTAssertEqual(terminal["generation"], try seq6Facts(ledger)["initial-generation"])
        XCTAssertEqual(terminal["fingerprint"], try seq6Facts(ledger)["initial-fingerprint"])
        XCTAssertEqual(terminal["watermark"], "41")
        XCTAssertEqual(terminal["body-proof"], "true"); XCTAssertEqual(terminal["local-access"], "true")
        XCTAssertEqual(try seq6Facts(ledger)["snapshot-error"], "checkpointChanged")
        XCTAssertGreaterThanOrEqual(try seq6Entries(ledger, "snapshot-moved-before-B").count, 1)
        XCTAssertEqual(try seq6Entries(ledger, "marker").count, 0)
        XCTAssertLessThanOrEqual(try seq6Entries(ledger, "checkpoint").count, 4)
        XCTAssertTrue(app.staticTexts["Safe local baseline"].waitForExistence(timeout: 5))
        XCTAssertTrue(tapStableInitialReplayProduct(app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Safe local baseline")).element(boundBy: 0)))
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Safe local baseline")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Seq6 changed snapshot retains qualified old editor"; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    private func runSeq6IncrementalRefusal(_ scenario: String, reason: String) throws {
        app.launchEnvironment["TASK145_SCOPE_INCREMENTAL_UI"] = scenario
        app.launch()
        try awaitSeq6Fact("automatic-terminal", timeout: 45)
        let ledger = try seq6Ledger("Contractual incremental refusal " + scenario)
        let summaries = try seq6Entries(ledger, "incremental-summary").compactMap { $0["values"] as? [String: String] }
        let summary = try XCTUnwrap(summaries.last)
        XCTAssertEqual(summary["reason"], reason)
        XCTAssertEqual(summary["before"], "41"); XCTAssertEqual(summary["after"], "41")
        XCTAssertEqual(summary["requires-recovery"], "true")
        XCTAssertEqual(try seq6Entries(ledger, "fence-advance").count, 0)
        XCTAssertEqual(try seq6Entries(ledger, "checkpoint").count, 0,
            "The ordinary incremental path may request recovery but cannot silently replace the generation")
        let results = try seq6Entries(ledger, "runtime-result").compactMap { $0["values"] as? [String: String] }
        XCTAssertTrue(results.contains { $0["status"] == "recoveryRequired" && $0["verified"] == "false" })
        XCTAssertTrue(app.staticTexts["Safe local baseline"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Options"].tap()
        XCTAssertTrue(app.tabBars.buttons["Database"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Seq6 actionable recovery Options " + scenario; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    private func assertSeq6DeniedBusinessAndShell() throws {
        for title in ["Options", "History", "Database", "Inventory"] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
            XCTAssertFalse(app.staticTexts["Safe local baseline"].exists)
            XCTAssertFalse(app.staticTexts["Unexplained Seq6 clean-body corruption"].exists)
            XCTAssertFalse(app.textFields["task144.product.name"].exists)
        }
        app.tabBars.buttons["Database"].tap()
        let add = app.buttons["New product"]
        XCTAssertTrue(!add.exists || !add.isEnabled)
        let importButton = app.buttons["task140.database.import"]
        XCTAssertTrue(!importButton.exists || !importButton.isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Seq6 real root business denial with navigable shell"; screenshot.lifetime = .keepAlways; self.add(screenshot)
    }

    private func awaitSeq6Fact(_ suffix: String, timeout: TimeInterval = 20) throws {
        let found = app.staticTexts["task145.seq6." + suffix].waitForExistence(timeout: timeout)
        if !found { captureControlledAutomaticReadback() }
        XCTAssertTrue(found, "Seq6 boundary not traversed: " + suffix)
    }
    private func seq6Facts(_ ledger: [String: Any]) throws -> [String: String] {
        try XCTUnwrap(ledger["facts"] as? [String: String])
    }
    private func seq6Entries(_ ledger: [String: Any], _ kind: String) throws -> [[String: Any]] {
        try XCTUnwrap(ledger["entries"] as? [[String: Any]]).filter { $0["kind"] as? String == kind }
    }
    private func seq6Ledger(_ stage: String, diagnosticOnly: Bool = false) throws -> [String: Any] {
        let readback = app.buttons["task144.controlled.release"].value as? String ?? ""
        let prefix = "task145.seq6.ledger."
        if diagnosticOnly {
            // A failed optional diagnostic must not record a new assertion or
            // replace the producer's original failure. Validate this same value first.
            guard let part = readback.components(separatedBy: ";").first(where: { $0.hasPrefix(prefix) }),
                  let data = Data(base64Encoded: String(part.dropFirst(prefix.count))),
                  let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  value["schema"] as? Int == 1,
                  (value["runID"] as? String)?.lowercased() == runID else {
                throw NSError(domain: "Task145Seq6Diagnostic", code: 1)
            }
        }
        let part = try XCTUnwrap(readback.components(separatedBy: ";").first { $0.hasPrefix(prefix) })
        let data = try XCTUnwrap(Data(base64Encoded: String(part.dropFirst(prefix.count))))
        let value = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(value["schema"] as? Int, 1)
        XCTAssertEqual((value["runID"] as? String)?.lowercased(), runID)
        let attachment = XCTAttachment(string: String(decoding: data, as: UTF8.self) + "\n" + readback)
        attachment.name = "Seq6 native ledger: " + stage; attachment.lifetime = .keepAlways; add(attachment)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Seq6 native UI: " + stage; screenshot.lifetime = .keepAlways; add(screenshot)
        return value
    }

    func testMixedTypedTransientFaultsBeyondThreeAttemptsReopenDuringRealCooldownAndRecoverAutomatically() throws {
        app.launchEnvironment["TASK145_RETRY_UI"] = "mixed-real-cooldown"
        let testStarted = ProcessInfo.processInfo.systemUptime
        app.launch()
        try awaitRetryFact("cooldown-after-three", timeout: 40)
        let first = try retryLedgerAttachment("Three real typed failures; busy released during real cooldown")
        let firstEntries = try XCTUnwrap(first["entries"] as? [[String: Any]])
        let completions = try XCTUnwrap(first["completions"] as? [[String: Any]])
        XCTAssertEqual(firstEntries.count, 3); XCTAssertEqual(completions.count, 3)
        XCTAssertEqual((first["reads"] as? [[String: Any]])?.count, 0)
        let third = try retryBudget(completions[2])
        let completed = try XCTUnwrap(third["lastCompletedAt"] as? Double)
        let deadline = try XCTUnwrap(third["nextAllowedAt"] as? Double)
        XCTAssertGreaterThanOrEqual(deadline - completed, 300)
        XCTAssertEqual(third["totalAttempts"] as? Int, 3)
        XCTAssertEqual(third["attemptsInWindow"] as? Int, 3)
        XCTAssertEqual(third["windowIndex"] as? Int, 1)
        XCTAssertTrue(completions.allSatisfy { ($0["busy"] as? Bool) == false })
        XCTAssertTrue(tapStableInitialReplayProduct(app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Safe local baseline")).element(boundBy: 0)))
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        positionNameInEditorViewport(name)
        replaceText(in: name, with: "Saved during real recovery cooldown")
        app.buttons["Save"].tap()
        try awaitRetryFact("save-durable-during-cooldown", timeout: 10)
        XCTAssertTrue(app.staticTexts["Saved during real recovery cooldown"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Cloud confirmed this save"].exists)
        let before = try retryLedgerAttachment("Real Save remains pending before controlled process restart")
        XCTAssertEqual(before["productEntries"] as? Int, 0)
        XCTAssertEqual(before["eventEntries"] as? Int, 0)
        app.terminate(); XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try awaitRetryFact("pending-reopened-before-deadline", timeout: 30)
        XCTAssertTrue(app.staticTexts["Saved during real recovery cooldown"].waitForExistence(timeout: 5))
        let after = try retryLedgerAttachment("New PID qualifies exact pending token and retry bytes before admission")
        XCTAssertEqual(before["generationID"] as? String, after["generationID"] as? String)
        XCTAssertEqual(before["journalIdentity"] as? String, after["journalIdentity"] as? String)
        XCTAssertEqual(before["savedBudgetBytes"] as? String, after["savedBudgetBytes"] as? String)
        XCTAssertEqual(try retryCanonical(before["savedToken"]), try retryCanonical(after["savedToken"]))
        XCTAssertEqual((after["entries"] as? [[String: Any]])?.count, 3)
        XCTAssertEqual(after["productEntries"] as? Int, 0)
        let readback = app.buttons["task144.controlled.release"].value as? String ?? ""
        let pidText = try XCTUnwrap(readback.components(separatedBy: ";").first { $0.hasPrefix("task145.retry.pid.") })
        XCTAssertNotEqual(Int(pidText.dropFirst("task145.retry.pid.".count)), after["firstPID"] as? Int)
        let qualifiedText = try XCTUnwrap(readback.components(separatedBy: ";").first { $0.hasPrefix("task145.retry.qualified-reopen.") })
        let qualifiedBytes = try XCTUnwrap(Data(base64Encoded: String(qualifiedText.dropFirst("task145.retry.qualified-reopen.".count))))
        let qualified = try XCTUnwrap(JSONSerialization.jsonObject(with: qualifiedBytes) as? [String: Any])
        XCTAssertEqual(try retryCanonical(before), try retryCanonical(qualified),
            "Pre-root reopen readback must preserve the exact observed state; no budget/journal reseed")
        // No Retry/control tap, fake clock, injected deadline, or manual runtime invocation.
        try awaitRetryFact("automatic-terminal-after-real-cooldown", timeout: 380)
        let terminal = try retryLedgerAttachment("429 server floor and timeout in renewed window, then automatic atomic success")
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - testStarted, 300)
        let entries = try XCTUnwrap(terminal["entries"] as? [[String: Any]])
        let results = try XCTUnwrap(terminal["results"] as? [[String: Any]])
        let finalCompletions = try XCTUnwrap(terminal["completions"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(entries.count, 6); XCTAssertLessThanOrEqual(entries.count, 12)
        XCTAssertEqual(entries.filter { $0["failureUTC"] != nil }.count, 5)
        XCTAssertEqual(results.count, 5); XCTAssertEqual(finalCompletions.count, 5)
        // The first three attempts precede the real Save. Attempt four pushes
        // that Save before recovery; its own ACK leaves attempt five bootstrap-only.
        let expectedActions = ["bootstrap", "bootstrap", "bootstrap", "push-bootstrap", "bootstrap"]
        for index in 0..<5 {
            let claim = try retryBudget(entries[index])
            XCTAssertEqual(claim["totalAttempts"] as? Int, index + 1)
            XCTAssertEqual(claim["identity"] as? String, terminal["journalIdentity"] as? String)
            XCTAssertEqual(entries[index]["journalIdentity"] as? String, terminal["journalIdentity"] as? String)
            XCTAssertEqual(entries[index]["journalPhase"] as? String, "prepared")
            let result = results[index]
            XCTAssertEqual(result["action"] as? String, expectedActions[index])
            XCTAssertEqual(result["status"] as? String, "failed")
            XCTAssertEqual(result["verified"] as? Bool, false)
            let failure = try XCTUnwrap(result["failure"] as? [String: Any])
            XCTAssertEqual(failure["disposition"] as? String, "transient")
            let expectedCategories = ["server", "server", "network", "rateLimited", "timeout"]
            XCTAssertEqual(failure["category"] as? String, expectedCategories[index])
            XCTAssertEqual(try retryCanonical(failure), try retryCanonical(entries[index]["thrownFailure"]))
            switch index {
            case 0: XCTAssertEqual(failure["httpStatus"] as? Int, 503)
            case 1: XCTAssertEqual(failure["httpStatus"] as? Int, 500)
            case 2: XCTAssertEqual(failure["urlErrorCode"] as? Int, URLError.dnsLookupFailed.rawValue)
            case 3: XCTAssertEqual(failure["httpStatus"] as? Int, 429)
            case 4: XCTAssertEqual(failure["urlErrorCode"] as? Int, URLError.timedOut.rawValue)
            default: XCTFail("Unexpected fault index")
            }
        }
        let claimIDs = try entries.map { try XCTUnwrap(retryBudget($0)["invocationID"] as? String) }
        XCTAssertEqual(Set(claimIDs).count, 6,
            "Checkpoint RPC entries are distinct from the six admitted coordinator attempts")
        let reads = try XCTUnwrap(terminal["reads"] as? [[String: Any]])
        XCTAssertFalse(reads.isEmpty)
        XCTAssertTrue(reads.contains { ($0["kind"] as? String) == "marker" })
        for read in reads {
            let claim = try retryBudget(read)
            XCTAssertEqual(claim["totalAttempts"] as? Int, 6,
                "Failed checkpoint attempts must not download pages or request a convergence marker")
            XCTAssertEqual(claim["invocationID"] as? String, claimIDs.last)
        }
        let fourth = try retryBudget(entries[3])
        XCTAssertEqual(fourth["windowIndex"] as? Int, 2)
        XCTAssertEqual(fourth["attemptsInWindow"] as? Int, 1)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(entries[3]["utc"] as? Double), deadline)
        let fourthUptime = try XCTUnwrap(entries[3]["uptime"] as? Double)
        let thirdFailureUptime = try XCTUnwrap(entries[2]["failureUptime"] as? Double)
        XCTAssertGreaterThanOrEqual(fourthUptime - thirdFailureUptime, 300,
            "Real monotonic time must include the cooldown after the third failure")
        let rateLimited = try retryBudget(finalCompletions[3])
        let serverFloor = try XCTUnwrap(rateLimited["retryAfterUntil"] as? Double)
        let rateDeadline = try XCTUnwrap(rateLimited["nextAllowedAt"] as? Double)
        XCTAssertGreaterThanOrEqual(rateDeadline, serverFloor)
        let fourthEntryUTC = try XCTUnwrap(entries[3]["utc"] as? Double)
        XCTAssertGreaterThanOrEqual(serverFloor - fourthEntryUTC, 12)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(entries[4]["utc"] as? Double), rateDeadline)
        let fifth = try retryBudget(entries[4])
        XCTAssertEqual(fifth["windowIndex"] as? Int, 2)
        XCTAssertEqual(fifth["attemptsInWindow"] as? Int, 2)
        for entry in entries.dropFirst(5) {
            let claim = try retryBudget(entry)
            XCTAssertEqual(claim["totalAttempts"] as? Int, 6)
            XCTAssertEqual(claim["windowIndex"] as? Int, 2)
            XCTAssertEqual(claim["attemptsInWindow"] as? Int, 3)
            XCTAssertEqual(claim["identity"] as? String, terminal["journalIdentity"] as? String)
        }
        XCTAssertEqual(terminal["ownACKBeforeRecovery"] as? Bool, true)
        XCTAssertEqual(terminal["productEntries"] as? Int, 1)
        XCTAssertEqual(terminal["eventEntries"] as? Int, 1)
        XCTAssertNotNil(terminal["terminalGeneration"])
        XCTAssertNotEqual(terminal["terminalGeneration"] as? String, terminal["generationID"] as? String)
        XCTAssertTrue(app.staticTexts["Saved during real recovery cooldown"].waitForExistence(timeout: 5))
    }

    private func awaitRetryFact(_ suffix: String, timeout: TimeInterval) throws {
        let observed = app.staticTexts["task145.retry." + suffix].waitForExistence(timeout: timeout)
        if !observed { captureControlledAutomaticReadback() }
        XCTAssertTrue(observed, "T05 boundary not traversed: \(suffix)")
    }
    private func retryLedgerAttachment(_ stage: String) throws -> [String: Any] {
        let readback = app.buttons["task144.controlled.release"].value as? String ?? ""
        let prefix = "task145.retry.ledger."
        let encoded = try XCTUnwrap(readback.components(separatedBy: ";").first { $0.hasPrefix(prefix) })
        let data = try XCTUnwrap(Data(base64Encoded: String(encoded.dropFirst(prefix.count))))
        let ledger = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let attachment = XCTAttachment(string: readback + "\n" + String(decoding: data, as: UTF8.self))
        attachment.name = "Task145 native real retry: " + stage; attachment.lifetime = .keepAlways; add(attachment)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task145 native real retry UI: " + stage; screenshot.lifetime = .keepAlways; add(screenshot)
        return ledger
    }
    private func retryBudget(_ observation: [String: Any]) throws -> [String: Any] {
        let encoded = try XCTUnwrap(observation["budgetBytes"] as? String)
        let bytes = try XCTUnwrap(Data(base64Encoded: encoded))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    }
    private func retryCanonical(_ value: Any?) throws -> Data {
        let unwrapped = try XCTUnwrap(value)
        return try JSONSerialization.data(withJSONObject: unwrapped, options: [.sortedKeys, .fragmentsAllowed])
    }

    func testSecondSavedNameSurvivesFirstACKAndProcessReopenUntilItsOwnACK() throws {
        app.launchEnvironment["TASK145_SAVE_B_UI"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
        let row = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Safe local baseline")).element(boundBy: 0)
        XCTAssertTrue(tapStableInitialReplayProduct(row))
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        positionNameInEditorViewport(name)
        replaceText(in: name, with: "Saved before network release")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["task144.controlled.local-save-durable"].waitForExistence(timeout: 5))
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        try awaitSaveBFact("a-committed-response-held", timeout: 40)
        let committedA = try saveBLedgerAttachment("A committed, immutable response held")
        app.staticTexts["Saved before network release"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        positionNameInEditorViewport(name)
        replaceText(in: name, with: "Saved while first ACK is held")
        app.buttons["Save"].tap()
        try awaitSaveBFact("b-durable-a-held", timeout: 5)
        XCTAssertTrue(app.staticTexts["Saved while first ACK is held"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Cloud confirmed this save"].exists)
        let savedB = try saveBLedgerAttachment("B durable while A response held")
        XCTAssertEqual(committedA["firstEnvelope"] as? String, savedB["firstEnvelope"] as? String)
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        try awaitSaveBFact("ack-a-b-pending", timeout: 40)
        XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Cloud confirmed this save"].exists,
                       "A's typed ACK cannot confirm the later real Save B")
        let beforeRestart = try saveBLedgerAttachment("A ACK, B sealed and pending before process termination")
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try awaitSaveBFact("pending-reopened", timeout: 20)
        XCTAssertTrue(app.staticTexts["Saved while first ACK is held"].waitForExistence(timeout: 5))
        let afterRestart = try saveBLedgerAttachment("Same store, qualified B pending after new process")
        XCTAssertEqual(beforeRestart["firstEnvelope"] as? String, afterRestart["firstEnvelope"] as? String)
        XCTAssertEqual(beforeRestart["secondEnvelope"] as? String, afterRestart["secondEnvelope"] as? String)
        XCTAssertEqual(beforeRestart["generationID"] as? String, afterRestart["generationID"] as? String)
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        try awaitSaveBFact("b-own-ack", timeout: 40)
        let terminal = try saveBLedgerAttachment("Only B ACK confirms B; two durable remote operations and events")
        XCTAssertEqual((terminal["committed"] as? [String])?.count, 2)
        XCTAssertEqual((terminal["returned"] as? [String])?.count, 2)
        let requests = try XCTUnwrap(terminal["requests"] as? [String])
        let firstEnvelope = try XCTUnwrap(terminal["firstEnvelope"] as? String)
        let secondEnvelope = try XCTUnwrap(terminal["secondEnvelope"] as? String)
        XCTAssertNotEqual(firstEnvelope, secondEnvelope)
        let firstRequests = requests.filter { $0 == firstEnvelope }
        XCTAssertTrue((1...2).contains(firstRequests.count))
        XCTAssertEqual(requests, firstRequests + [secondEnvelope, secondEnvelope])
        let terminalEventAttempts = try JSONSerialization.data(
            withJSONObject: XCTUnwrap(terminal["eventAttempts"]), options: [.sortedKeys])
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try awaitSaveBFact("terminal-reopened-no-resend", timeout: 40)
        let final = try saveBLedgerAttachment("Terminal second reopen retains two ACKs without duplicate work")
        XCTAssertEqual(terminal["requests"] as? [String], final["requests"] as? [String])
        XCTAssertEqual(terminal["committed"] as? [String], final["committed"] as? [String])
        XCTAssertEqual(terminalEventAttempts, try JSONSerialization.data(
            withJSONObject: XCTUnwrap(final["eventAttempts"]), options: [.sortedKeys]),
            "The normal terminal wake must not replay either acknowledged event RPC")
    }

    private func awaitSaveBFact(_ suffix: String, timeout: TimeInterval) throws {
        let observed = app.staticTexts["task145.save-b." + suffix].waitForExistence(timeout: timeout)
        if !observed { captureControlledAutomaticReadback() }
        XCTAssertTrue(observed, "Save B boundary not traversed: \(suffix)")
    }

    private func saveBLedgerAttachment(_ stage: String) throws -> [String: Any] {
        let readback = app.buttons["task144.controlled.release"].value as? String ?? ""
        let prefix = "task145.save-b.ledger."
        let encoded = try XCTUnwrap(readback.components(separatedBy: ";").first { $0.hasPrefix(prefix) })
        let data = try XCTUnwrap(Data(base64Encoded: String(encoded.dropFirst(prefix.count))))
        let ledger = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let evidence = XCTAttachment(string: readback + "\n" + String(decoding: data, as: UTF8.self))
        evidence.name = "Task145 Save B: " + stage; evidence.lifetime = .keepAlways; add(evidence)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task145 Save B UI: " + stage; screenshot.lifetime = .keepAlways; add(screenshot)
        return ledger
    }

    func testSavedNameBeforeSendSurvivesControlledProcessRestartAndNormalAutomaticACK() throws {
        try runSavedNameRestartScenario("pre-send")
    }

    func testCommittedNameWithUnknownACKReplaysIdenticalSealedAttemptAfterControlledProcessRestart() throws {
        try runSavedNameRestartScenario("post-commit")
    }

    private func runSavedNameRestartScenario(_ scenario: String) throws {
        if scenario == "post-commit" { try task146ConfigureAnimationIdleDriver() }
        app.launchEnvironment["TASK145_RESTART_UI"] = scenario
        app.launch()
        if task146OriginalAnimationIdleWait != nil {
            guard (app.value(forKey: "idleAnimationWaitEnabled") as? NSNumber)?.boolValue == false else {
                throw NSError(domain: "Task146AnimationIdleDriver", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Private XCTest animation-idle setting missing or reset after initial launch; witness not admitted."])
            }
        }
        try awaitRestartFact("admission-held", timeout: 20)
        if scenario == "post-commit" {
            app.buttons["task144.controlled.release"].press(forDuration: 1.5)
            try awaitRestartFact("availability-restored", timeout: 5)
        }
        XCTAssertTrue(tapStableInitialReplayProduct(app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Safe local baseline")).element(boundBy: 0)))
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        positionNameInEditorViewport(name)
        replaceText(in: name, with: "Saved before network release")
        app.buttons["Save"].tap()
        try awaitRestartFact(scenario == "pre-send" ? "pre-send-durable-zero-rpc" : "post-commit-response-held", timeout: 40)
        XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Cloud confirmed this save"].exists)
        let before = try restartLedgerAttachment("durable stop before controlled termination")
        XCTAssertEqual((before.state["requests"] as? [String])?.count, scenario == "pre-send" ? 0 : 1)
        XCTAssertEqual((before.state["returned"] as? [String])?.count, 0)
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try awaitRestartFact("pending-reopen-qualified", timeout: 20)
        XCTAssertTrue(app.staticTexts["Saved before network release"].waitForExistence(timeout: 5))
        let reopened = try restartLedgerAttachment("same generation and pending work qualified in new process")
        XCTAssertNotEqual(before.pid, reopened.pid)
        XCTAssertEqual(before.bytes, reopened.qualification,
                       "Reopen must preserve the entire persisted backend, sealed bytes, token, base and generation before admission")
        try awaitRestartFact("own-ack", timeout: 40)
        let terminal = try restartLedgerAttachment("ordinary runtime returned the original operation ACK")
        XCTAssertEqual((terminal.state["requests"] as? [String])?.count, scenario == "pre-send" ? 1 : 2)
        XCTAssertEqual((terminal.state["committed"] as? [String])?.count, 1)
        XCTAssertEqual((terminal.state["eventAttempts"] as? [[String: Any]])?.count, 1)
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try awaitRestartFact("terminal-reopened-no-resend", timeout: 40)
        let final = try restartLedgerAttachment("terminal reopen and successful normal wake without resend")
        XCTAssertNotEqual(terminal.pid, final.pid)
        XCTAssertEqual(terminal.bytes, final.bytes,
                       "Normal terminal wake must not create a business request, duplicate row or event RPC replay")
    }

    private func awaitRestartFact(_ suffix: String, timeout: TimeInterval) throws {
        let observed = app.staticTexts["task145.restart." + suffix].waitForExistence(timeout: timeout)
        if !observed { captureControlledAutomaticReadback() }
        XCTAssertTrue(observed, "Restart boundary not traversed: \(suffix)")
    }

    private func restartLedgerAttachment(_ stage: String) throws -> (state: [String: Any], bytes: Data, pid: String, qualification: Data?) {
        let readback = app.buttons["task144.controlled.release"].value as? String ?? ""
        let prefix = "task145.restart.ledger."
        let encoded = try XCTUnwrap(readback.components(separatedBy: ";").first { $0.hasPrefix(prefix) })
        let data = try XCTUnwrap(Data(base64Encoded: String(encoded.dropFirst(prefix.count))))
        let state = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let pid = try XCTUnwrap(readback.components(separatedBy: ";").first { $0.hasPrefix("task145.restart.pid.") })
        let qualificationPrefix = "task145.restart.reopen-qualification."
        let qualification = readback.components(separatedBy: ";").first { $0.hasPrefix(qualificationPrefix) }
            .flatMap { Data(base64Encoded: String($0.dropFirst(qualificationPrefix.count))) }
        let evidence = XCTAttachment(string: readback + "\n" + String(decoding: data, as: UTF8.self))
        evidence.name = "Task145 restart: " + stage; evidence.lifetime = .keepAlways; add(evidence)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task145 restart UI: " + stage; screenshot.lifetime = .keepAlways; add(screenshot)
        return (state, data, pid, qualification)
    }

    func testRetailPriceSavesSurviveRecoveryCutoverAndLostACKProcessRestartWithoutDuplicatePoints() throws {
        try runDomainSaveRestart("prices")
    }

    func testHistoryTitleSavesSurviveRecoveryCutoverAndReplayOriginalSealedRevisionAfterProcessRestart() throws {
        try runDomainSaveRestart("history")
    }

    /// Passive native input admission only; callers own the one press and their absolute budget.
    private func controlledReleaseInputIsReady(_ release: XCUIElement, identifier: String,
                                                stage: String, deadline: TimeInterval) throws -> Bool {
        var previousReleaseGeometry: (button: CGRect, window: CGRect)?
        var releaseReady = false
        while ProcessInfo.processInfo.systemUptime < deadline {
            let nodes = try c3OptionsSnapshotNodes(try app.snapshot(), stage: stage, downstream: [])
            let matches = nodes.filter { $0.elementType == .button && $0.identifier == identifier }
            let buttonFrame = matches.first?.frame ?? .zero
            let windows = nodes.filter { $0.elementType == .window && matches.count == 1
                && matches[0].path.starts(with: $0.path) }
            let windowFrame = windows.first?.frame ?? .zero
            let geometryReady = matches.count == 1 && windows.count == 1
                && [buttonFrame, windowFrame].allSatisfy({ frame in
                    [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy { $0.isFinite }
                        && frame.width > 0 && frame.height > 0
                }) && windowFrame.contains(buttonFrame)
            let stable = geometryReady && previousReleaseGeometry?.button == buttonFrame
                && previousReleaseGeometry?.window == windowFrame
            previousReleaseGeometry = geometryReady ? (buttonFrame, windowFrame) : nil
            if stable {
                releaseReady = ProcessInfo.processInfo.systemUptime < deadline
                    && release.isHittable && ProcessInfo.processInfo.systemUptime < deadline
                if releaseReady { break }
            }
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            if remaining > 0 { RunLoop.current.run(until: Date().addingTimeInterval(min(0.05, remaining))) }
        }
        return releaseReady
    }

    private func runDomainSaveRestart(_ domain: String) throws {
        app.launchEnvironment["TASK145_DOMAIN_UI"] = domain
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 30))
        try saveDomainValue(domain, second: false)
        try awaitDomainFact("a-durable-held-page", timeout: 5)
        let savedA = try domainLedgerAttachment("real Save A committed locally during held recovery page")
        XCTAssertEqual((savedA.state["requests"] as? [Any])?.count, 0)
        let release = app.buttons["task144.controlled.release"]
        if domain == "history" || domain == "prices" {
            let releaseDeadline = ProcessInfo.processInfo.systemUptime + 5
            let ready = try controlledReleaseInputIsReady(release,
                identifier: "task144.controlled.release", stage: domain + "-first-release-admission",
                deadline: releaseDeadline)
            guard ready && ProcessInfo.processInfo.systemUptime < releaseDeadline else {
                XCTFail("The domain requires stable current native release input before its sole press")
                return
            }
        }
        release.press(forDuration: 1.5)
        try awaitDomainFact("cutover-pending-stale-writer-rejected", timeout: 40)
        try awaitDomainFact("a-committed-response-held", timeout: 40)
        let remoteA = try domainLedgerAttachment("publish preserves A; old gate rejects writer; remote A committed and response held")
        XCTAssertNotEqual(remoteA.state["generationBeforeCutover"] as? String, remoteA.state["generationAfterCutover"] as? String)
        let stale = try XCTUnwrap(remoteA.state["staleWriter"] as? [String: Any])
        XCTAssertEqual(stale["error"] as? String, "retiredStoreGeneration")
        XCTAssertEqual(stale["closureEntered"] as? Bool, false)
        XCTAssertEqual(stale["before"] as? String, stale["after"] as? String)
        XCTAssertEqual(stale["rpcBefore"] as? Int, 0)
        XCTAssertEqual(stale["rpcAfter"] as? Int, 0)
        try saveDomainValue(domain, second: true)
        try awaitDomainFact("b-durable-a-held", timeout: 5)
        if domain == "prices" {
            XCTAssertTrue(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["Cloud confirmed this save"].exists)
        } else {
            XCTAssertTrue(app.staticTexts["History title saved while ACK is held"].waitForExistence(timeout: 5))
        }
        let before = try domainLedgerAttachment("real Save B durable while A response remains held")
        XCTAssertEqual((before.state["requests"] as? [Any])?.count, 1)
        XCTAssertEqual((before.state["returnedChangeIDs"] as? [String])?.count, 0)
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try awaitDomainFact("pending-reopen-qualified", timeout: 20)
        let reopened = try domainLedgerAttachment("new process qualifies same generation and pending original request before admission")
        XCTAssertNotEqual(before.pid, reopened.pid)
        XCTAssertEqual(before.bytes, reopened.qualification)
        try awaitDomainFact("b-own-ack", timeout: 40)
        let terminal = try domainLedgerAttachment("ordinary providers acknowledge original A and later B with scoped event rows")
        XCTAssertEqual((terminal.state["committedChangeIDs"] as? [String])?.count, 2)
        XCTAssertEqual((terminal.state["returnedChangeIDs"] as? [String])?.count, 2)
        XCTAssertEqual((terminal.state["requests"] as? [Any])?.count, domain == "prices" ? 2 : 3)
        let eventAttempts = try XCTUnwrap(terminal.state["eventAttempts"] as? [[String: Any]])
        XCTAssertEqual(eventAttempts.count, domain == "prices" ? 3 : 2)
        XCTAssertEqual(Set(eventAttempts.compactMap { $0["clientEventID"] as? String }).count, eventAttempts.count)
        XCTAssertEqual((terminal.state["prices"] as? [Any])?.count, domain == "prices" ? 2 : 0)
        XCTAssertEqual((terminal.state["history"] as? [Any])?.count, domain == "history" ? 1 : 0)
        if domain == "history" {
            app.tabBars.buttons["History"].tap()
            XCTAssertTrue(app.staticTexts["History title saved while ACK is held"].waitForExistence(timeout: 5))
        }
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try awaitDomainFact("terminal-reopened-no-resend", timeout: 40)
        let final = try domainLedgerAttachment("terminal reopen successful normal wake, no business or recorder replay")
        XCTAssertNotEqual(terminal.pid, final.pid)
        XCTAssertEqual(terminal.bytes, final.bytes)
    }

    private func saveDomainValue(_ domain: String, second: Bool) throws {
        if domain == "prices" {
            app.tabBars.buttons["Database"].tap()
            XCTAssertTrue(tapStableInitialReplayProduct(app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Safe local baseline")).element(boundBy: 0)))
            let field = app.textFields["task141.product.retail-price"]
            try replaceDomainField(field, with: second ? "13" : "12", historyTitle: false)
        } else {
            app.tabBars.buttons["History"].tap()
            let row = app.staticTexts[second ? "History title saved during recovery" : "Controlled history baseline"]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.swipeRight()
            let edit = app.buttons["Edit"].firstMatch
            XCTAssertTrue(edit.waitForExistence(timeout: 5)); edit.tap()
            let field = app.textFields["Display name (optional)"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            try replaceDomainField(field, with: second ? "History title saved while ACK is held" : "History title saved during recovery", historyTitle: true)
        }
        let save = app.buttons["Save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5)); save.tap()
    }

    private func replaceDomainField(_ field: XCUIElement, with value: String, historyTitle: Bool, feedbackUI: Bool = false) throws {
        // The same four gestures also materialize a virtualized price row before
        // its existing five-second existence gate. No extra scroll loop is added.
        // No Name-only observation is reused for a price or history field.
        for _ in 0..<4 {
            if !field.exists {
                guard !historyTitle else { break }
                let editor = app.collectionViews.containing(.textField, identifier: "task144.product.name").firstMatch
                guard app.navigationBars["Edit product"].exists, editor.exists else { break }
                editor.swipeUp()
                continue
            }
            let targetIdentifier = field.identifier
            let targetPlaceholder = historyTitle && targetIdentifier.isEmpty ? field.placeholderValue : nil
            let form = app.collectionViews.containing(.textField, identifier: targetIdentifier).firstMatch
            let formPresent = form.exists
            let root = try app.snapshot()
            var nodes: [(XCUIElementSnapshot, [XCUIElementSnapshot])] = [(root, [])]
            var targets: [(XCUIElementSnapshot, [XCUIElementSnapshot])] = []
            var controls: [CGRect] = []
            var visited = 0
            while let (node, ancestors) = nodes.popLast() {
                visited += 1
                guard visited <= 1_024 else { break }
                if node.elementType == .textField
                    && (historyTitle && targetIdentifier.isEmpty
                        ? targetPlaceholder?.isEmpty == false && node.placeholderValue == targetPlaceholder
                        : node.identifier == targetIdentifier) {
                    targets.append((node, ancestors))
                }
                if node.elementType == .button && node.identifier == "task144.controlled.editor.release" {
                    controls.append(node.frame)
                }
                nodes.append(contentsOf: node.children.map { ($0, ancestors + [node]) })
            }
            guard visited <= 1_024, targets.count == 1, controls.count <= 1,
                  let target = targets.first else {
                let evidence = XCTAttachment(string: "visited=\(visited); target-count=\(targets.count); controls-count=\(controls.count); historyTitle=\(historyTitle)")
                evidence.name = "Task145 domain field geometry FIRST-FAIL"; evidence.lifetime = .keepAlways; add(evidence)
                throw NSError(domain: "Task145DomainUI", code: 5)
            }
            let applicationFrame = root.frame
            let frame = target.0.frame
            let surfaceFrame: CGRect
            if formPresent {
                guard let nativeForm = target.1.last(where: { $0.elementType == .collectionView }) else {
                    throw NSError(domain: "Task145DomainUI", code: 6)
                }
                surfaceFrame = nativeForm.frame
            } else {
                surfaceFrame = applicationFrame
            }
            let viewport = surfaceFrame.intersection(applicationFrame)
            let upper = max(viewport.minY + 24, controls.first.map { $0.maxY + 16 } ?? viewport.minY + 24)
            let lower = min(viewport.maxY - 24, applicationFrame.midY)
            guard lower > upper + frame.height else { throw NSError(domain: "Task145DomainUI", code: 4) }
            if field.isHittable, frame.minY >= upper, frame.maxY <= lower { break }
            let displacement = frame.midY - (upper + lower) / 2
            let travel = min(viewport.height * 0.5, max(-viewport.height * 0.5, displacement))
            let startY = travel >= 0 ? viewport.maxY - 32 : upper + 16
            let finishY = min(viewport.maxY - 24, max(upper + 8, startY - travel))
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(
                CGVector(dx: viewport.minX + 8 - applicationFrame.minX, dy: startY - applicationFrame.minY))
            start.press(forDuration: 0, thenDragTo: start.withOffset(CGVector(dx: 0, dy: finishY - startY)),
                        withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        if !historyTitle { XCTAssertTrue(field.waitForExistence(timeout: 5)) }
        guard field.isHittable else { throw NSError(domain: "Task145DomainUI", code: 1) }
        field.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(feedbackUI ? historyFeedbackExists(keyboard, timeout: 5) : keyboard.waitForExistence(timeout: 5))
        if historyTitle {
            let clear = app.buttons["Clear"].firstMatch
            XCTAssertTrue(feedbackUI ? historyFeedbackExists(clear, timeout: 5) : clear.waitForExistence(timeout: 5)); clear.tap()
        } else if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.press(forDuration: 1.1)
            let selectAll = app.menuItems["Select All"].firstMatch
            let selectAllButton = app.buttons["Select All"].firstMatch
            if selectAll.waitForExistence(timeout: 2) { selectAll.tap() }
            else if selectAllButton.waitForExistence(timeout: 2) { selectAllButton.tap() }
            else { throw NSError(domain: "Task145DomainUI", code: 2) }
            field.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        let cleared = field.value as? String ?? ""
        guard cleared.isEmpty || cleared == field.placeholderValue else { throw NSError(domain: "Task145DomainUI", code: 3) }
        field.typeText(value)
        XCTAssertEqual(field.value as? String, value, "The real target field must contain the exact new value before Save")
        if historyTitle, app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
    }

    private func awaitDomainFact(_ suffix: String, timeout: TimeInterval, fastPresence: Bool = false) throws {
        let fact = app.staticTexts["task145.domain." + suffix]
        let observed = fastPresence ? historyFeedbackExists(fact, timeout: timeout) : fact.waitForExistence(timeout: timeout)
        if !observed { captureControlledAutomaticReadback() }
        XCTAssertTrue(observed, "Native domain boundary not traversed: \(suffix)")
    }

    private func domainLedgerAttachment(_ stage: String) throws -> (state: [String: Any], bytes: Data, pid: String, qualification: Data?) {
        let readback = app.buttons["task144.controlled.release"].value as? String ?? ""
        let prefix = "task145.domain.ledger."
        let encoded = try XCTUnwrap(readback.components(separatedBy: ";").first { $0.hasPrefix(prefix) })
        let data = try XCTUnwrap(Data(base64Encoded: String(encoded.dropFirst(prefix.count))))
        let state = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let pid = try XCTUnwrap(readback.components(separatedBy: ";").first { $0.hasPrefix("task145.domain.pid.") })
        let qualificationPrefix = "task145.domain.reopen-qualification."
        let qualification = readback.components(separatedBy: ";").first { $0.hasPrefix(qualificationPrefix) }
            .flatMap { Data(base64Encoded: String($0.dropFirst(qualificationPrefix.count))) }
        let evidence = XCTAttachment(string: readback + "\n" + String(decoding: data, as: UTF8.self))
        evidence.name = "Task145 domain: " + stage; evidence.lifetime = .keepAlways; add(evidence)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task145 domain UI: " + stage; screenshot.lifetime = .keepAlways; add(screenshot)
        return (state, data, pid, qualification)
    }

    func testHistoryLocalSuccessDoesNotClaimCloudConfirmationForNewerSavedRevision() throws {
        app.launchEnvironment["TASK145_DOMAIN_UI"] = "history"
        app.launchEnvironment["TASK145_HISTORY_FEEDBACK_UI"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["task145.history-feedback.local-success-qualified"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
        try openHistoryFeedback()
        let initialCard = try captureHistoryFeedbackUI("initial real local success", title: "Controlled history baseline", pending: false)
        try saveHistoryFeedback(second: false)
        try closeHistoryFeedback()
        try awaitDomainFact("a-durable-held-page", timeout: 5, fastPresence: true)
        let localA = try domainLedgerAttachment("History feedback: real local application followed by real Save A")
        let localSuccess = try XCTUnwrap((localA.state["historyFeedback"] as? [String: Any])?["localSuccess"] as? [String: Int])
        XCTAssertEqual(localSuccess["attempted"], 1); XCTAssertEqual(localSuccess["succeeded"], 1)
        XCTAssertEqual(localSuccess["failed"], 0); XCTAssertEqual(localSuccess["pendingCloudChanges"], 0)
        app.buttons["task144.controlled.release"].press(forDuration: 1.2)
        try awaitDomainFact("cutover-pending-stale-writer-rejected", timeout: 40, fastPresence: true)
        try awaitDomainFact("a-committed-response-held", timeout: 40, fastPresence: true)
        try openHistoryFeedback()
        try saveHistoryFeedback(second: true)
        // Capture first; semantic assertions are evaluated after the full ACK/reopen
        // sequence so an ambiguous label does not discard later causal evidence.
        let dirtyB = try captureHistoryFeedbackUI("B dirty while response A is held", title: "History title saved while ACK is held", pending: true)
        try closeHistoryFeedback()
        try awaitDomainFact("b-durable-a-held", timeout: 5, fastPresence: true)
        let beforeA = try domainLedgerAttachment("History feedback B dirty, local success preserved, A remote response held")
        try assertHistoryFeedbackFrame(beforeA.state, stage: "b-dirty-a-held", dirty: true, pending: "2")
        XCTAssertEqual((beforeA.state["requests"] as? [Any])?.count, 1)
        XCTAssertEqual((beforeA.state["returnedChangeIDs"] as? [Any])?.count, 0)
        try openHistoryFeedback()
        app.buttons["task145.history-feedback.return-a"].tap()
        try closeHistoryFeedback()
        XCTAssertTrue(app.staticTexts["task145.history-feedback.a-ack-b-pending"].waitForExistence(timeout: 40))
        let afterA = try domainLedgerAttachment("Own ACK A applied; original B intent/body still pending and B remote commit held")
        try assertHistoryFeedbackFrame(afterA.state, stage: "a-ack-b-pending", dirty: true, pending: "1")
        XCTAssertEqual((afterA.state["requests"] as? [Any])?.count, 2)
        XCTAssertEqual((afterA.state["returnedChangeIDs"] as? [Any])?.count, 1)
        XCTAssertEqual((afterA.state["committedChangeIDs"] as? [Any])?.count, 1)
        try openHistoryFeedback()
        let dirtyAfterA = try captureHistoryFeedbackUI("B still dirty after ACK A", title: "History title saved while ACK is held", pending: true)
        app.buttons["task145.history-feedback.release-b"].tap()
        try closeHistoryFeedback()
        try awaitDomainFact("b-own-ack", timeout: 40, fastPresence: true)
        let ownB = try domainLedgerAttachment("Own ACK B and one emitted History event per sealed revision")
        try assertHistoryFeedbackFrame(ownB.state, stage: "b-own-ack", dirty: false, pending: "0")
        XCTAssertEqual((ownB.state["requests"] as? [Any])?.count, 2)
        XCTAssertEqual((ownB.state["returnedChangeIDs"] as? [Any])?.count, 2)
        XCTAssertEqual((ownB.state["committedChangeIDs"] as? [Any])?.count, 2)
        let eventAttempts = try XCTUnwrap(ownB.state["eventAttempts"] as? [[String: Any]])
        XCTAssertEqual(eventAttempts.count, 2)
        XCTAssertEqual(Set(eventAttempts.compactMap { $0["clientEventID"] as? String }).count, 2)
        try openHistoryFeedback()
        let confirmedB = try captureHistoryFeedbackUI("B own ACK visible", title: "History title saved while ACK is held", pending: false)
        try closeHistoryFeedback()
        app.terminate(); XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try awaitDomainFact("terminal-reopened-no-resend", timeout: 40, fastPresence: true)
        let reopened = try domainLedgerAttachment("New process real normal wake, same B ACK and no business/event resend")
        XCTAssertNotEqual(ownB.pid, reopened.pid)
        XCTAssertEqual(ownB.bytes, reopened.bytes)
        try assertHistoryFeedbackFrame(reopened.state, stage: "b-own-ack", dirty: false, pending: "0")
        try openHistoryFeedback()
        let reopenedB = try captureHistoryFeedbackUI("B own ACK after controlled reopen", title: "History title saved while ACK is held", pending: false)
        XCTAssertNotEqual(initialCard.cloudText, confirmedB.cloudText, "The date must come from B's own ACK")
        XCTAssertEqual(confirmedB.cloudText, reopenedB.cloudText, "Reopen cannot invent a new success time")
        XCTAssertTrue(dirtyB.pendingVisible && dirtyAfterA.pendingVisible, "The actual cloud card must describe B pending before and after ACK A")
        XCTAssertFalse(dirtyB.unqualifiedSynced || dirtyAfterA.unqualifiedSynced,
            "The actual B row must not present the prior local/import success as unqualified cloud convergence of B")
    }

    private func historyFeedbackExists(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        let present = element.exists || element.waitForExistence(
            timeout: max(0, deadline - ProcessInfo.processInfo.systemUptime))
        return present && ProcessInfo.processInfo.systemUptime <= deadline
    }

    private func openHistoryFeedback() throws {
        let open = app.buttons["task145.history-feedback.open"]
        XCTAssertTrue(historyFeedbackExists(open, timeout: 5)); open.tap()
        XCTAssertTrue(historyFeedbackExists(app.buttons["task145.history-feedback.close"], timeout: 5))
        XCTAssertFalse(app.staticTexts["Cloud history is not available on this device."].exists,
            "This is the real History consumer with its real concrete service, not the nil fixture card")
    }
    private func closeHistoryFeedback() throws {
        let close = app.buttons["task145.history-feedback.close"]
        XCTAssertTrue(historyFeedbackExists(close, timeout: 5)); close.tap()
        XCTAssertTrue(historyFeedbackExists(app.buttons["task145.history-feedback.open"], timeout: 5))
    }
    private func saveHistoryFeedback(second: Bool) throws {
        let title = second ? "History title saved during recovery" : "Controlled history baseline"
        let row = app.staticTexts[title]
        for _ in 0..<4 {
            if historyFeedbackExists(row, timeout: 1), row.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.exists && row.isHittable); row.swipeRight()
        let edit = app.buttons["Edit"].firstMatch
        XCTAssertTrue(historyFeedbackExists(edit, timeout: 5)); edit.tap()
        let field = app.textFields["Display name (optional)"]
        XCTAssertTrue(historyFeedbackExists(field, timeout: 5))
        try replaceDomainField(field, with: second ? "History title saved while ACK is held" : "History title saved during recovery", historyTitle: true, feedbackUI: true)
        let save = app.buttons["Save"].firstMatch
        XCTAssertTrue(historyFeedbackExists(save, timeout: 5)); save.tap()
    }
    private func assertHistoryFeedbackFrame(_ ledger: [String: Any], stage: String, dirty: Bool, pending: String) throws {
        let feedback = try XCTUnwrap(ledger["historyFeedback"] as? [String: Any])
        XCTAssertEqual(feedback["poisoned"] as? Bool, false)
        let frames = try XCTUnwrap(feedback["frames"] as? [[String: String]])
        let frame = try XCTUnwrap(frames.first { $0["stage"] == stage })
        XCTAssertEqual(frame["dirty"], String(dirty)); XCTAssertEqual(frame["pending"], pending)
        XCTAssertEqual(frame["localStatus"], "1", "The real successful local application must survive; do not reset syncStatus to fake pending feedback")
        XCTAssertEqual(frame["title"], "History title saved while ACK is held")
        if stage == "a-ack-b-pending" {
            XCTAssertEqual(frame["syncedRevision"], String(try XCTUnwrap(ledger["revisionA"] as? Int)))
        }
        XCTAssertEqual(frame["localRevision"], String(try XCTUnwrap(ledger["revisionB"] as? Int)))
    }
    private func captureHistoryFeedbackUI(_ stage: String, title: String, pending: Bool) throws -> (cloudText: String, pendingVisible: Bool, unqualifiedSynced: Bool) {
        if pending { _ = historyFeedbackExists(app.staticTexts["Local History changes pending: 1."], timeout: 5) }
        let card = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
            "Local History changes pending:", "History synchronized:")).firstMatch
        for _ in 0..<4 {
            if historyFeedbackExists(card, timeout: 1), card.isHittable { break }
            app.swipeDown()
        }
        let cardText = card.exists ? card.label : "MISSING_REAL_CLOUD_CARD"
        let cardVisible = card.exists && card.isHittable
        let cloudScreen = XCTAttachment(screenshot: app.screenshot()); cloudScreen.name = "History feedback cloud card: " + stage
        cloudScreen.lifetime = .keepAlways; add(cloudScreen)
        XCTAssertTrue(cardVisible, "Actual cloud card must be available and visible before a semantic assertion")
        XCTAssertFalse(app.staticTexts["Cloud history is not available on this device."].exists)
        if !pending { XCTAssertTrue(cardText.hasPrefix("History synchronized:")) }
        let label = app.staticTexts[title]
        for _ in 0..<4 {
            if historyFeedbackExists(label, timeout: 1), label.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(label.exists && label.isHittable, "The current real History body stays consultable")
        let row = app.cells.containing(.staticText, identifier: title).firstMatch
        XCTAssertTrue(row.exists, "Scope feedback to this exact native History row")
        let rowSnapshot = try row.snapshot()
        var pendingNodes = Array(rowSnapshot.children.reversed())
        var rowLabels: [String] = []
        while let node = pendingNodes.popLast() {
            if node.elementType == .staticText { rowLabels.append(node.label) }
            pendingNodes.append(contentsOf: node.children.reversed())
        }
        XCTAssertLessThanOrEqual(rowLabels.count, 24, "Bounded row-only accessibility observation")
        XCTAssertTrue(rowLabels.contains(title), "The coherent row snapshot must still contain this exact History title")
        let rowText = ([rowSnapshot.label] + Array(rowLabels.prefix(24))).joined(separator: " | ")
        let genericSynced = rowText.range(of: "\\bSynced\\b", options: [.regularExpression, .caseInsensitive]) != nil
        let localQualifier = rowText.range(of: "\\b(local|locally|import|imported|stock|device)\\b", options: [.regularExpression, .caseInsensitive]) != nil
        XCTAssertTrue(genericSynced || localQualifier, "Observe the actual row status; a missing accessibility label cannot qualify the feedback")
        let raw = XCTAttachment(string: "stage=" + stage + "\ncloud=" + cardText + "\nrow=" + rowText)
        raw.name = "History feedback real AX: " + stage; raw.lifetime = .keepAlways; add(raw)
        let screen = XCTAttachment(screenshot: app.screenshot()); screen.name = "History feedback row: " + stage
        screen.lifetime = .keepAlways; add(screen)
        return (cardText, cardVisible && cardText == "Local History changes pending: 1.", genericSynced && !localQualifier)
    }

    func testStableInvalidSupplierPreservesDependentIntentWhileIndependentProductSyncs() throws {
        try exerciseIsolation("stable-supplier", pending: "2", failedUI: true)
    }

    func testStableInvalidSupplierIsolationDoesNotBypassCorruptSealInAutomaticRuntime() throws {
        try exerciseIsolation("corrupt-seal", pending: "3", failedUI: true)
    }

    func testMalformedNotificationHeadPreservesItsBytesWhileValidSiblingRegistersOnce() throws {
        try exerciseIsolation("malformed-head", pending: "1", failedUI: false)
    }

    private func exerciseIsolation(_ scenario: String, pending: String, failedUI: Bool) throws {
        app.launchEnvironment["TASK145_ISOLATION_UI"] = scenario
        app.launch()
        XCTAssertTrue(app.staticTexts["task145.isolation.seed-qualified"].waitForExistence(timeout: 25))
        try awaitIsolationFact("observed", timeout: 40)
        let first = try isolationAttachment("First actual provider/runtime outcome")
        XCTAssertEqual(first.0["scenario"] as? String, scenario)
        XCTAssertEqual(first.0["failed"] as? Bool, false)
        XCTAssertEqual(first.0["overflow"] as? Bool, false)
        XCTAssertEqual(first.1["pending"] as? String, pending)
        try assertIsolationVisible(scenario, pending: pending, failedUI: failedUI)
        let before = try isolationAttachment("Before controlled process restart")
        let businessRequests = try isolationBusinessRequests(before.0)
        app.terminate(); XCTAssertEqual(app.state, .notRunning)
        app.launch()
        try awaitIsolationFact("reopen-qualified", timeout: 25)
        try awaitIsolationFact("reopen-observed", timeout: 40)
        let reopened = try isolationAttachment("New process, original store/authority, real body qualification")
        try assertIsolationReopenRuntime(reopened, scenario: scenario, businessRequests: businessRequests)
        XCTAssertNotEqual(before.1["pid"] as? String, reopened.1["pid"] as? String)
        XCTAssertEqual(before.0["generationID"] as? String, reopened.0["generationID"] as? String)
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: XCTUnwrap(before.0["tokens"]), options: [.sortedKeys]),
                       try JSONSerialization.data(withJSONObject: XCTUnwrap(reopened.0["tokens"]), options: [.sortedKeys]))
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: XCTUnwrap(before.0["seededOutbox"]), options: [.sortedKeys]),
                       try JSONSerialization.data(withJSONObject: XCTUnwrap(reopened.0["seededOutbox"]), options: [.sortedKeys]))
        XCTAssertEqual(businessRequests, try isolationBusinessRequests(reopened.0), "No acknowledged Q or notification resend")
        XCTAssertEqual(reopened.1["pending"] as? String, pending)
        try assertIsolationVisible(scenario, pending: pending, failedUI: failedUI)
        let terminal = try isolationAttachment("Final native visible state and bounded no-resend observation")
        try assertIsolationReopenRuntime(terminal, scenario: scenario, businessRequests: businessRequests)
        XCTAssertEqual(businessRequests, try isolationBusinessRequests(terminal.0))
        XCTAssertEqual(terminal.0["failed"] as? Bool, false)
        XCTAssertEqual(terminal.0["overflow"] as? Bool, false)
    }

    private func assertIsolationReopenRuntime(_ observation: ([String: Any], [String: Any]), scenario: String, businessRequests: Data) throws {
        let (ledger, local) = observation
        let pidText = try XCTUnwrap(local["pid"] as? String), pid = try XCTUnwrap(Int(pidText))
        XCTAssertEqual(local["runtimePID"] as? String, pidText, "Current process facade must complete before reopen PASS")
        let qualified = try XCTUnwrap(ledger["reopenQualification"] as? [String: Any])
        XCTAssertEqual(qualified["pid"] as? Int, pid)
        XCTAssertEqual(qualified["generationID"] as? String, ledger["generationID"] as? String)
        let priorLocal = try XCTUnwrap(qualified["localSnapshot"] as? [String: String])
        XCTAssertEqual(priorLocal["pid"], pidText)
        XCTAssertNil(priorLocal["runtimePID"], "Pre-root qualification must not claim a runtime outcome")
        for key in ["actualTokens", "actualOutboxIdentities"] { XCTAssertEqual(priorLocal[key], local[key] as? String) }
        XCTAssertEqual(businessRequests, try JSONSerialization.data(withJSONObject: XCTUnwrap(qualified["business"]), options: [.sortedKeys]))
        let catalogOffset = try XCTUnwrap(qualified["catalogCount"] as? Int)
        let activityOffset = try XCTUnwrap(qualified["activityCount"] as? Int)
        let runOffset = try XCTUnwrap(qualified["runCount"] as? Int)
        let catalogs = try XCTUnwrap(ledger["catalogs"] as? [[String: Any]])
        let activities = try XCTUnwrap(ledger["activities"] as? [[String: Any]])
        let runs = try XCTUnwrap(ledger["runs"] as? [[String: Any]])
        XCTAssertTrue(runs.dropFirst(runOffset).contains { run in
            guard run["pid"] as? Int == pid, let catalogEnd = run["catalogCount"] as? Int,
                  let activityEnd = run["activityCount"] as? Int,
                  catalogEnd >= catalogOffset, catalogEnd <= catalogs.count,
                  activityEnd >= activityOffset, activityEnd <= activities.count else { return false }
            let currentCatalogs = catalogs.prefix(catalogEnd).dropFirst(catalogOffset)
            let currentActivities = activities.prefix(activityEnd).dropFirst(activityOffset)
            guard currentCatalogs.allSatisfy({ $0["pid"] as? Int == pid && $0["creates"] as? Int == 0 && $0["total"] as? Int == 0 }) else { return false }
            if scenario == "malformed-head" {
                return currentCatalogs.allSatisfy({ $0["error"] as? String == nil && ($0["blockers"] as? [String])?.isEmpty == true })
                    && currentActivities.allSatisfy { $0["pid"] as? Int == pid && $0["status"] as? String == "blocked"
                        && $0["registered"] as? Int == 0 && $0["waiting"] as? Int == 0 && $0["blocked"] as? Int == 1 }
            }
            guard !currentCatalogs.isEmpty else { return false }
            if scenario == "corrupt-seal" {
                return currentActivities.isEmpty && run["stable"] as? Bool == true && run["category"] as? String == "integrity"
                    && currentCatalogs.allSatisfy { $0["error"] as? String == "activationReadBackFailed" }
            }
            guard !currentActivities.isEmpty, currentActivities.allSatisfy({ $0["pid"] as? Int == pid && $0["registered"] as? Int == 0 && $0["waiting"] as? Int == 0 }) else { return false }
            if scenario == "stable-supplier" {
                return run["error"] as? String == "catalog_local_changes_blocked" && run["stable"] as? Bool == true && run["category"] as? String == "payload"
                    && currentActivities.allSatisfy { $0["status"] as? String == "empty" && $0["blocked"] as? Int == 0 }
            }
            return false
        }, "Need a new current-PID facade outcome and the providers required by this scenario; old outcomes cannot qualify")
    }

    private func isolationTabIsSelected(_ title: String, requiresForm: Bool = false,
                                        observe: ((String) -> Void)? = nil) -> Bool {
        let started = ProcessInfo.processInfo.systemUptime
        // Avoid requesting every diagnostic accessibilityValue in app.snapshot().
        // One owning window proves AT LEAST one of each required structure;
        // the global union count proves EXACTLY one of each, not just a match.
        let types = [XCUIElement.ElementType.tabBar.rawValue, XCUIElement.ElementType.navigationBar.rawValue]
            + (requiresForm ? [XCUIElement.ElementType.collectionView.rawValue] : [])
        // Include the target title in the same global union. The owning window
        // and actual selected getter below establish at least one of EVERY role;
        // this total proves exactly one of each, including the selected title.
        let structures = app.descendants(matching: .any).matching(NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "elementType IN %@", types),
            NSPredicate(format: "elementType == %d AND label == %@", XCUIElement.ElementType.button.rawValue, title)
        ]))
        let expectedCount = types.count + 1
        let owners = app.windows.containing(.tabBar, identifier: nil)
            .containing(.navigationBar, identifier: title)
        let windows = requiresForm ? owners.containing(.collectionView, identifier: nil) : owners
        // The public selected attribute is available during query matching
        // (XCUIElementAttributes). One native filtered count establishes the
        // selected title under its actual owning TabBar/window and all required
        // structures, without separate window-count and selected RPCs.
        let selectedButtons = windows.tabBars.buttons.matching(NSPredicate(
            format: "label == %@ AND selected == YES", title))
        let selectedCount = selectedButtons.count
        guard selectedCount == 1 else {
            observe?("capture-start=\(started); capture-end=\(ProcessInfo.processInfo.systemUptime); owned-native-selected-count=\(selectedCount)")
            return false
        }
        // The native owned-selected query proves at least one of EVERY role.
        // The subsequent global total proves exactly one of each role/title,
        // including unselected duplicates elsewhere. A separate earlier global
        // count adds no missing role/uniqueness condition; avoid that third RPC.
        // Both native results must still finish in the caller's original5s.
        let afterCount = structures.count
        let admitted = afterCount == expectedCount
        observe?("capture-start=\(started); capture-end=\(ProcessInfo.processInfo.systemUptime); global-after=\(afterCount); expected=\(expectedCount); owned-native-selected-count=\(selectedCount); native-filtered-admission=\(admitted)")
        return admitted
    }

    private func assertIsolationVisible(_ scenario: String, pending: String, failedUI: Bool) throws {
        try task146ConfigureAnimationIdleDriver()
        app.tabBars.buttons["Options"].tap()
        var observations: [String] = []
        func require(_ condition: Bool, _ stage: String) throws {
            guard condition else {
                let frames = XCTAttachment(string: observations.joined(separator: "\n"))
                frames.name = "T11 FIRST_FAIL frames " + scenario + " " + stage
                frames.lifetime = .keepAlways; add(frames)
                let hierarchy = XCTAttachment(string: app.debugDescription)
                hierarchy.name = "T11 FIRST_FAIL hierarchy " + scenario + " " + stage
                hierarchy.lifetime = .keepAlways; add(hierarchy)
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "T11 FIRST_FAIL " + scenario + " " + stage
                screenshot.lifetime = .keepAlways; add(screenshot)
                XCTFail(stage)
                throw NSError(domain: "Task145.IsolationVisible", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: stage])
            }
        }
        let forms = app.collectionViews
        let optionsNavigation = app.navigationBars.matching(NSPredicate(format: "identifier == %@", "Options"))
        // The existing Form admission owns one five-second window. A Form
        // from the previously selected Database cannot admit Options geometry.
        let admissionDeadline = ProcessInfo.processInfo.systemUptime + 5
        var optionsAdmitted = false
        // Reuse one complete current snapshot per sample. XCTest predicate
        // polling adds an idle interval between already expensive snapshots.
        while ProcessInfo.processInfo.systemUptime < admissionDeadline {
            if isolationTabIsSelected("Options", requiresForm: true, observe: {
                if observations.count < 8 { observations.append($0) }
            }) {
                optionsAdmitted = ProcessInfo.processInfo.systemUptime <= admissionDeadline
                break
            }
        }
        try require(optionsAdmitted,
            "T11 requires selected Options with its unique navigation bar and Form")
        let form = forms.element(boundBy: 0)
        func reveal(_ rows: XCUIElementQuery, stage: String, upward: Bool,
                    stableFirstRow: XCUIElement? = nil, liveLabel: String? = nil) throws -> XCUIElement {
            for drag in 0...4 {
                let frame = form.frame.intersection(app.windows.firstMatch.frame)
                let top = max(frame.minY, optionsNavigation.element(boundBy: 0).frame.maxY)
                let bottom = min(frame.maxY, app.tabBars.firstMatch.frame.minY)
                let viewport = CGRect(x: frame.minX, y: top, width: frame.width, height: max(0, bottom - top))
                let count = rows.count
                observations.append("stage=\(stage);drag=\(drag);form=\(frame);viewport=\(viewport);matches=\(count)")
                try require(count <= 20 && viewport.width > 0 && viewport.height > 0,
                    stage + " bounded query and visible Form")
                var scrollUp = upward
                if count == 1 {
                    // A normal poll can replace the attention label after count.
                    // Keep its exact role-count gate, but resolve the persistent
                    // first summary row and re-read its current public label.
                    let row = stableFirstRow ?? rows.element(boundBy: 0)
                    if let liveLabel, !row.label.contains(liveLabel) { continue }
                    let rowFrame = row.frame
                    let hittable = row.isHittable
                    observations.append("label=\(row.label);value=\(String(describing: row.value));frame=\(rowFrame);hittable=\(hittable)")
                    if rowFrame.width > 0 && rowFrame.height > 0 && viewport.contains(rowFrame) && hittable {
                        if let liveLabel, !row.label.contains(liveLabel) { continue }
                        return row
                    }
                    if rowFrame.height > 0 && rowFrame.maxY <= viewport.minY { scrollUp = false }
                    if rowFrame.height > 0 && rowFrame.minY >= viewport.maxY { scrollUp = true }
                }
                try require(count <= 1, stage + " must identify one public row")
                // Missing transient status is not a scroll-position defect. The
                // same bounded observations wait for the real terminal label.
                if stableFirstRow != nil && count == 0 { continue }
                guard drag < 4 else { break }
                let offset = viewport.height * (scrollUp ? 0.29 : -0.29)
                let origin = form.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                let start = origin.withOffset(CGVector(dx: viewport.midX - form.frame.minX,
                    dy: viewport.midY + offset - form.frame.minY))
                let end = origin.withOffset(CGVector(dx: viewport.midX - form.frame.minX,
                    dy: viewport.midY - offset - form.frame.minY))
                start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            try require(false, stage + " not qualified within four Form drags")
            throw NSError(domain: "Task145.IsolationVisible", code: 2)
        }
        let pendingRows = form.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND label BEGINSWITH %@", "options.sync-business-summary", "Local changes waiting"))
        let pendingRow = try reveal(pendingRows, stage: "T11 public pending row", upward: true)
        let pendingText = pendingRow.label + " " + (pendingRow.value as? String ?? "")
        try require(pendingText.range(of: "(^|[^0-9])" + NSRegularExpression.escapedPattern(for: pending) + "([^0-9]|$)",
            options: .regularExpression) != nil, "The visible public pending row must expose its own count")
        if failedUI {
            let attention = form.staticTexts.matching(NSPredicate(
                format: "identifier == %@ AND label CONTAINS %@", "options.sync-business-summary", "Automatic sync needs attention"))
            _ = try reveal(attention, stage: "T11 contextual automatic sync error", upward: false,
                stableFirstRow: form.staticTexts.matching(identifier: "options.sync-business-summary").element(boundBy: 0),
                liveLabel: "Automatic sync needs attention")
        }
        let publicState = XCTAttachment(screenshot: app.screenshot())
        publicState.name = "Task145 T11 actual Options diagnosis " + scenario; publicState.lifetime = .keepAlways; add(publicState)
        for title in ["History", "Database"] {
            let tab = app.tabBars.buttons[title]
            tab.tap()
            let deadline = ProcessInfo.processInfo.systemUptime + 5
            var selected = false
            // The same direct bounded admission used above avoids spending a
            // predicate polling interval before the first native observation.
            while ProcessInfo.processInfo.systemUptime < deadline {
                if isolationTabIsSelected(title, observe: {
                    if observations.count < 32 { observations.append("return-tab=\(title); " + $0) }
                }) {
                    selected = ProcessInfo.processInfo.systemUptime <= deadline
                    break
                }
                // Give the UI a turn after a negative observation, matching
                // the existing switcher cadence inside the SAME absolute5s.
                let remaining = deadline - ProcessInfo.processInfo.systemUptime
                if remaining > 0 { RunLoop.current.run(until: Date().addingTimeInterval(min(0.05, remaining))) }
            }
            if !selected {
                let timing = XCTAttachment(string: observations.joined(separator: "\n"))
                timing.name = "T11 return-tab native admission " + scenario
                timing.lifetime = .keepAlways; add(timing)
            }
            XCTAssertTrue(selected, "T11 return tab must be natively selected within the original5s")
        }
        let search = app.textFields.matching(NSPredicate(format: "identifier == %@ AND label == %@",
            "task140.database.root", "Search by barcode, name, or code")).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        if scenario != "malformed-head" {
            for (barcode, name) in [("T145-ISOLATION-P", "Dependent T11 intent"), ("T145-ISOLATION-Q", "Independent T11 intent")] {
                setIsolationSearch(search, value: barcode)
                XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "Preserved real product row must remain accessible")
            }
        } else {
            setIsolationSearch(search, value: "LOCAL-ROOT")
            XCTAssertTrue(app.staticTexts["Safe local baseline"].waitForExistence(timeout: 5))
        }
    }

    // Pertinent native admissions only: avoid XCTest's initial polling sleep
    // and automatic debugDescription capture after every negative observation.
    // A getter completing beyond the original absolute deadline cannot pass.
    private func directNativeExists(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        guard timeout > 0 else { return false }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while ProcessInfo.processInfo.systemUptime < deadline {
            let exists = element.exists
            if ProcessInfo.processInfo.systemUptime > deadline { return false }
            if exists { return true }
        }
        return false
    }

    private func setIsolationSearch(_ field: XCUIElement, value: String) {
        field.tap()
        XCTAssertTrue(directNativeExists(app.keyboards.element(boundBy: 0), timeout: 5))
        let current = field.value as? String ?? ""
        if !current.isEmpty && current != field.placeholderValue {
            let clear = app.buttons["Clear search"]
            XCTAssertTrue(clear.waitForExistence(timeout: 5) && clear.isHittable)
            clear.tap()
            let cleared = field.value as? String ?? ""
            XCTAssertTrue(cleared.isEmpty || cleared == field.placeholderValue)
            field.tap()
        }
        field.typeText(value)
        let enteredDeadline = ProcessInfo.processInfo.systemUptime + 5
        var entered = false
        // Keep the exact native value and the same absolute5s. Sample directly
        // instead of spending the first interval on a predicate timer/KVC path.
        while ProcessInfo.processInfo.systemUptime < enteredDeadline {
            let matches = field.value as? String == value
            if matches && ProcessInfo.processInfo.systemUptime <= enteredDeadline {
                entered = true
                break
            }
        }
        XCTAssertTrue(entered, "The actual typed T11 search must match within the original5s")
        XCTAssertEqual(field.value as? String, value)
        // Activate the actual native Search action exposed by this keyboard;
        // a newline sent as field text need not submit or resign focus.
        let submit = app.keyboards.firstMatch.buttons.matching(NSPredicate(format: "identifier == %@", "Search"))
        XCTAssertEqual(submit.count, 1)
        let search = submit.element(boundBy: 0)
        XCTAssertTrue(search.isHittable); search.tap()
        // A missing firstMatch performs SDK retries while proving absence.
        // The direct native count proves the same absence without resolving a
        // nonexistent element. Preserve the original absolute5s before/after.
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        var hidden = false
        while ProcessInfo.processInfo.systemUptime < deadline {
            let count = app.keyboards.count
            guard ProcessInfo.processInfo.systemUptime <= deadline else { break }
            if count == 0 { hidden = true; break }
        }
        XCTAssertTrue(hidden, "T11 native keyboard must be absent within the original5s")
    }

    private func awaitIsolationFact(_ suffix: String, timeout: TimeInterval) throws {
        let found = directNativeExists(app.staticTexts.matching(identifier: "task145.isolation." + suffix).element(boundBy: 0), timeout: timeout)
        if !found { captureControlledAutomaticReadback() }
        XCTAssertTrue(found, "T11 boundary not traversed: " + suffix)
    }
    private func isolationBusinessRequests(_ ledger: [String: Any]) throws -> Data {
        let entries = try XCTUnwrap(ledger["rpc"] as? [[String: Any]])
        return try JSONSerialization.data(withJSONObject: entries.filter { !(($0["kind"] as? String ?? "").hasPrefix("read:")) }, options: [.sortedKeys])
    }
    private func isolationAttachment(_ stage: String) throws -> ([String: Any], [String: Any]) {
        let raw = app.buttons["task144.controlled.release"].value as? String ?? ""
        func decode(_ prefix: String) throws -> [String: Any] {
            let field = try XCTUnwrap(raw.components(separatedBy: ";").first { $0.hasPrefix(prefix) })
            let bytes = try XCTUnwrap(Data(base64Encoded: String(field.dropFirst(prefix.count))))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        }
        let ledger = try decode("task145.isolation.ledger."), local = try decode("task145.isolation.local.")
        let attachment = XCTAttachment(string: raw); attachment.name = "Task145 T11 " + stage; attachment.lifetime = .keepAlways; add(attachment)
        let screen = XCTAttachment(screenshot: app.screenshot()); screen.name = "Task145 T11 UI " + stage; screen.lifetime = .keepAlways; add(screen)
        return (ledger, local)
    }

    func testCurrentProductSaveIsCloudConfirmedWhileAnIndependentHistoryIntentRemainsPending() {
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_INDEPENDENT_PENDING"] = "1"
        app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_OBSERVE_SCOPE"] = "1"
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
        let row = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Safe local baseline")).element(boundBy: 0)
        let rowAppeared = tapStableInitialReplayProduct(row)
        if !rowAppeared {
            let result = XCTAttachment(string: "rowAppeared=\(rowAppeared); timeoutSeconds=5")
            result.name = "Task144 initial replay product admission result before diagnostic queries"
            result.lifetime = .keepAlways
            add(result)
            captureControlledAutomaticReadback()
        }
        XCTAssertTrue(rowAppeared, "The initial product must have stable native layout and a current hit point within five seconds")
        let name = app.textFields["task144.product.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        // Position the Name row with a bounded drag before the sole focus tap.
        positionNameInEditorViewport(name)
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
        let replayReadback = XCTAttachment(string: readback)
        replayReadback.name = "Task144 immutable committed response replay existing readback"
        replayReadback.lifetime = .keepAlways
        add(replayReadback)
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
            field.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            field.typeText(value)
            let inputDeadline = ProcessInfo.processInfo.systemUptime + 5
            var actual: String?
            let published = NSPredicate { _, _ in
                guard ProcessInfo.processInfo.systemUptime < inputDeadline else { return false }
                actual = field.value as? String
                return actual == value && ProcessInfo.processInfo.systemUptime <= inputDeadline
            }
            let immediatelyPublished = published.evaluate(with: nil)
            let remaining = inputDeadline - ProcessInfo.processInfo.systemUptime
            let observed = immediatelyPublished || (remaining > 0 && XCTWaiter.wait(for: [
                XCTNSPredicateExpectation(predicate: published, object: nil)], timeout: remaining) == .completed)
            let inputQualified = observed && ProcessInfo.processInfo.systemUptime <= inputDeadline
            if !inputQualified { captureControlledAutomaticReadback() }
            XCTAssertTrue(inputQualified, "The one native relation input must publish its exact value within five seconds")
            XCTAssertEqual(actual, value)
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
        let activated = app.staticTexts["task144.controlled.activated"].waitForExistence(timeout: 20)
        if !activated {
            let waitResult = XCTAttachment(string: "activated=\(activated); timeoutSeconds=20")
            waitResult.name = "Task144 PreviousShop original activation wait result before diagnostic queries"
            waitResult.lifetime = .keepAlways
            add(waitResult)
            captureControlledAutomaticReadback()
        }
        XCTAssertTrue(activated)
    }

    func testDatabaseLabelsFollowNormalLanguageChangeWithoutLosingQueryOrFilter() {
        app.launch()
        XCTAssertTrue(app.staticTexts["task144.controlled.held"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Options"].tap()
        tapFullyVisibleLanguageOption("English")
        app.tabBars.buttons["Database"].tap()
        let search = app.textFields.matching(NSPredicate(
            format: "identifier == %@", "task140.database.root"
        )).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("LOCAL-ROOT")
        XCTAssertTrue(app.staticTexts["Safe local baseline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Products"].exists)
        XCTAssertEqual(app.buttons["storefront.filter.all"].label, "All")
        XCTAssertTrue(app.buttons["storefront.filter.all"].isSelected)
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "Task144 language change: English Database before normal Options input"
        before.lifetime = .keepAlways
        add(before)

        // The software keyboard covers the tab bar. Complete the normal
        // single-line search before navigating; do not tap through its keys.
        search.typeText("\n")
        let keyboardHidden = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [keyboardHidden], timeout: 5), .completed)
        XCTAssertTrue(app.tabBars.buttons["Options"].isHittable)
        app.tabBars.buttons["Options"].tap()
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 5))
        tapFullyVisibleLanguageOption("Italiano")
        XCTAssertTrue(app.tabBars.buttons["Opzioni"].waitForExistence(timeout: 5),
                      "The real root must observe the normal language selection before checking cached labels")
        app.tabBars.buttons["Database"].tap()
        let expectedFilters = [("all", "Tutti"), ("published", "Pubblicati"),
                               ("unpublished", "Non pubblicati"), ("draft", "Bozze"),
                               ("scheduled", "Programmati"), ("hidden", "Nascosti"),
                               ("needs_update", "Da aggiornare"), ("conflict", "Con conflitto")]
        let labels = app.segmentedControls.buttons.allElementsBoundByIndex.map(\.label)
        let filterLabels = expectedFilters.map { "\($0.0)=\(app.buttons["storefront.filter." + $0.0].label)" }
        let readback = XCTAttachment(string: "sections=\(labels); filters=\(filterLabels); query=\(search.value ?? "nil")")
        readback.name = "Task144 actual mounted Database labels after Italian Options selection"
        readback.lifetime = .keepAlways
        add(readback)
        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "Task144 language change: Database after Italian selection without relaunch"
        after.lifetime = .keepAlways
        add(after)

        XCTAssertEqual(labels, ["Prodotti", "Fornitori", "Categorie"])
        for (id, title) in expectedFilters {
            XCTAssertEqual(app.buttons["storefront.filter." + id].label, title)
        }
        XCTAssertEqual(search.value as? String, "LOCAL-ROOT")
        XCTAssertTrue(app.buttons["storefront.filter.all"].isSelected)
        XCTAssertTrue(app.staticTexts["Safe local baseline"].exists)
        assertHeldBoundary()

        // Restore the suite's ordinary English preference through the real UI.
        // This also verifies the reverse language change without relaunching.
        app.tabBars.buttons["Opzioni"].tap()
        tapFullyVisibleLanguageOption("English")
        XCTAssertTrue(app.tabBars.buttons["Options"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Database"].tap()
        XCTAssertEqual(app.segmentedControls.buttons.allElementsBoundByIndex.map(\.label),
                       ["Products", "Suppliers", "Categories"])
        let englishFilters = [("all", "All"), ("published", "Published"),
                              ("unpublished", "Unpublished"), ("draft", "Drafts"),
                              ("scheduled", "Scheduled"), ("hidden", "Hidden"),
                              ("needs_update", "Needs update"), ("conflict", "Conflicts")]
        for (id, title) in englishFilters {
            XCTAssertEqual(app.buttons["storefront.filter." + id].label, title)
        }
        XCTAssertEqual(search.value as? String, "LOCAL-ROOT")
        XCTAssertTrue(app.buttons["storefront.filter.all"].isSelected)
        XCTAssertTrue(app.staticTexts["Safe local baseline"].exists)
        assertHeldBoundary()
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

    private func tapFullyVisibleLanguageOption(
        _ title: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        let controls = app.buttons["task144.controlled.release"]
        let navigationBar = app.navigationBars.firstMatch
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(controls.exists, file: file, line: line)
        XCTAssertTrue(navigationBar.exists, file: file, line: line)
        XCTAssertTrue(tabBar.exists, file: file, line: line)

        // A partly exposed row can be reported hittable while XCTest chooses
        // an edge point covered by the fixture's observation controls. Reveal
        // the whole row through ordinary scrolling before the single tap.
        for _ in 0..<5 {
            let top = max(controls.frame.maxY, navigationBar.frame.maxY) + 8
            let bottom = tabBar.frame.minY - 8
            var movement: CGFloat = -160
            if option.exists {
                let frame = option.frame
                if frame.minY >= top && frame.maxY <= bottom { break }
                movement = max(-160, min(160, (top + bottom) / 2 - frame.midY))
            }
            // A gesture with little or no movement could be interpreted as
            // a premature tap. Leave an ambiguous row to the guards below.
            if abs(movement) < 44 { break }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
                .withOffset(CGVector(dx: 0, dy: (top + bottom) / 2))
            start.press(forDuration: 0.05,
                        thenDragTo: start.withOffset(CGVector(dx: 0, dy: movement)))
        }
        XCTAssertTrue(option.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(option.isHittable, file: file, line: line)
        XCTAssertGreaterThanOrEqual(option.frame.minY,
                                   max(controls.frame.maxY, navigationBar.frame.maxY) + 8,
                                   file: file, line: line)
        XCTAssertLessThanOrEqual(option.frame.maxY, tabBar.frame.minY - 8, file: file, line: line)
        let exposed = XCTAttachment(screenshot: app.screenshot())
        exposed.name = "Task144 fully visible language row before single normal tap: \(title)"
        exposed.lifetime = .keepAlways
        add(exposed)
        option.tap()
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

    private func tapStableInitialReplayProduct(_ row: XCUIElement) -> Bool {
        let started = ProcessInfo.processInfo.systemUptime
        let deadline = started + 5
        var previousLayout: [[CGRect]]?
        var samples: [String] = []
        var sampleCount = 0
        var tapStarted: TimeInterval?
        var tapFinished: TimeInterval?
        var emitted = false
        let emit = { [weak self] in
            guard let self, !emitted else { return }
            emitted = true
            let attachment = XCTAttachment(string: "start=\(started); deadline=\(deadline); samples=\(sampleCount); retained=\(samples.count); tap-start=\(String(describing: tapStarted)); tap-end=\(String(describing: tapFinished))\n" + samples.joined(separator: "\n"))
            attachment.name = "Task144 initial replay product native layout before the sole tap"
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
        addTeardownBlock { emit() }
        defer { emit() }
        // Reuse the existing synchronous snapshot pattern inside the original
        // row's five-second admission window; no separate timer or sleep.
        while ProcessInfo.processInfo.systemUptime < deadline {
            sampleCount += 1
            let captureStarted = ProcessInfo.processInfo.systemUptime
            guard let root = try? app.snapshot() else {
                previousLayout = nil
                if samples.count < 64 { samples.append("sample=\(sampleCount); capture-start=\(captureStarted); capture-end=\(ProcessInfo.processInfo.systemUptime); invalid-snapshot=true; prior-layout-cleared=true") }
                continue
            }
            let captureFinished = ProcessInfo.processInfo.systemUptime
            var pending: [(XCUIElementSnapshot, [CGRect])] = [(root, [])]
            var titles: [[CGRect]] = []
            var histories: [CGRect] = []
            var controls: [CGRect] = []
            var navigation: [CGRect] = []
            var banners: [CGRect] = []
            var visited = 0
            while let (node, ancestors) = pending.popLast() {
                visited += 1
                if visited > 1_024 { break }
                let path = ancestors + [node.frame]
                if node.elementType == .staticText && node.label == "Safe local baseline" { titles.append(path) }
                if node.elementType == .button && node.label == "Price history" { histories.append(node.frame) }
                if node.identifier == "task144.controlled.band" { controls.append(node.frame) }
                if node.elementType == .navigationBar && node.identifier == "Database" { navigation.append(node.frame) }
                if node.identifier == "sync.root.foreground.banner" { banners.append(node.frame) }
                pending.append(contentsOf: node.children.map { ($0, path) })
            }
            let title = titles.first?.last ?? .zero
            let history = histories.first ?? .zero
            let layout = [titles.first ?? [], histories, controls, navigation, banners]
            let valid = visited <= 1_024 && titles.count == 1 && histories.count == 1
                && controls.count == 1 && navigation.count == 1 && banners.count <= 1
                && title.width > 0 && title.height > 0 && history.width > 0 && history.height > 0
                && root.frame.contains(title) && root.frame.contains(history)
                && title.maxY <= history.minY && !title.intersects(history)
                && title.minY > max(controls.first?.maxY ?? 0, navigation.first?.maxY ?? 0)
                && layout.joined().allSatisfy { $0.origin.x.isFinite && $0.origin.y.isFinite && $0.width.isFinite && $0.height.isFinite }
            let stable = valid && previousLayout == layout
            previousLayout = valid ? layout : nil
            let hitStarted = ProcessInfo.processInfo.systemUptime
            let queryHit = stable && hitStarted < deadline
            let hittable = queryHit ? row.isHittable : false
            let hitFinished = ProcessInfo.processInfo.systemUptime
            if samples.count < 64 {
                samples.append("sample=\(sampleCount); capture-start=\(captureStarted); capture-end=\(captureFinished); visited=\(visited); title-count=\(titles.count); title=\(title); history-count=\(histories.count); history=\(history); ancestor-layout=\(layout); valid=\(valid); stable=\(stable); hit-queried=\(queryHit); hittable=\(hittable); hit-start=\(hitStarted); hit-end=\(hitFinished)")
            }
            guard queryHit, hittable, hitFinished < deadline else { continue }
            let tapAdmission = ProcessInfo.processInfo.systemUptime
            guard tapAdmission < deadline else { return false }
            tapStarted = tapAdmission
            // Keep the same unique, stable and currently hittable native label
            // as the SDK gesture target. Reconstructing an application-relative
            // coordinate did not deliver the editor action on the hosted target.
            // This remains one real tap; the actual Name field must still appear.
            row.tap()
            let finished = ProcessInfo.processInfo.systemUptime
            tapFinished = finished
            // Five seconds bound admission through the last pre-tap guard.
            // XCTest's post-input idle return is recorded, not a startup timing oracle.
            return true
        }
        return false
    }

    private func positionNameInEditorViewport(_ field: XCUIElement, nativeSelectionReadinessFollows: Bool = false) {
        let form = app.collectionViews.containing(.textField, identifier: "task144.product.name").firstMatch
        let padding: CGFloat = 16
        func observeNameViewport() -> (viewport: CGRect, formFrame: CGRect, visibleForm: CGRect,
                                      toolbar: CGRect, controls: CGRect, upper: CGFloat, lower: CGFloat,
                                      scrollBottom: CGFloat, keyboard: CGRect?, field: CGRect, row: CGRect?)? {
            // One fresh public tree supplies coherent geometry. Live existence and
            // hit-point checks below and in text readiness keep their original gates.
            guard let root = try? app.snapshot() else {
                XCTFail("The native editor geometry snapshot must be available")
                return nil
            }
            var pending: [(XCUIElementSnapshot, [XCUIElementSnapshot])] = [(root, [])]
            var targets: [(XCUIElementSnapshot, [XCUIElementSnapshot])] = []
            var toolbars: [CGRect] = []
            var controlsFrames: [CGRect] = []
            var keyboardFrames: [CGRect] = []
            var visited = 0
            while let (node, ancestors) = pending.popLast() {
                visited += 1
                guard visited <= 1_024 else { break }
                if node.elementType == .textField && node.identifier == "task144.product.name" {
                    targets.append((node, ancestors))
                }
                if node.elementType == .navigationBar && node.identifier == "Edit product" { toolbars.append(node.frame) }
                if node.elementType == .button && node.identifier == "task144.controlled.editor.release" { controlsFrames.append(node.frame) }
                if node.elementType == .keyboard { keyboardFrames.append(node.frame) }
                pending.append(contentsOf: node.children.map { ($0, ancestors + [node]) })
            }
            guard visited <= 1_024, targets.count == 1, toolbars.count == 1,
                  controlsFrames.count <= 1, keyboardFrames.count <= 1,
                  let target = targets.first,
                  let nativeForm = target.1.last(where: { $0.elementType == .collectionView }) else {
                let evidence = XCTAttachment(string: "visited=\(visited); Name=\(targets.count); toolbar=\(toolbars.count); controls=\(controlsFrames.count); keyboard=\(keyboardFrames.count)")
                evidence.name = "Task144 Name geometry FIRST-FAIL"; evidence.lifetime = .keepAlways; add(evidence)
                XCTFail("Require one current native Name field, enclosing Form and editor toolbar")
                return nil
            }
            let viewport = root.frame
            let formFrame = nativeForm.frame
            let visibleForm = formFrame.intersection(viewport)
            let toolbar = toolbars[0]
            let controls = controlsFrames.first ?? .zero
            let upper = max(visibleForm.minY, max(toolbar.maxY, controls.maxY)) + padding
            // Reserve the lower half before focus; AX keyboard.frame can omit its accessory strip.
            var lower = min(visibleForm.maxY - padding, viewport.midY)
            var scrollBottom = visibleForm.maxY
            var measuredKeyboardFrame: CGRect?
            if let keyboardFrame = keyboardFrames.first {
                let accessoryReserve = max(44, viewport.height * 0.08)
                measuredKeyboardFrame = keyboardFrame
                let keyboardTop = keyboardFrame.minY - accessoryReserve
                lower = min(lower, keyboardTop - padding)
                scrollBottom = min(scrollBottom, keyboardTop)
            }
            let before = target.0.frame
            guard visibleForm.width > padding, before.height > 0, lower - upper > before.height else {
                XCTFail("No usable Name band: form=\(visibleForm); upper=\(upper); lower=\(lower); field=\(before)")
                return nil
            }
            return (viewport, formFrame, visibleForm, toolbar, controls, upper, lower,
                    scrollBottom, measuredKeyboardFrame, before,
                    target.1.last(where: { $0.elementType == .cell })?.frame)
        }
        guard let initial = observeNameViewport() else { return }
        let viewport = initial.viewport
        let formFrame = initial.formFrame
        let visibleForm = initial.visibleForm
        let toolbar = initial.toolbar
        let controls = initial.controls
        let upper = initial.upper
        let lower = initial.lower
        let scrollBottom = initial.scrollBottom
        let measuredKeyboardFrame = initial.keyboard
        let before = initial.field
        var finalUpper = upper
        var finalLower = lower
        var finalVisibleForm = visibleForm
        var postPanGeometry: String?
        let inside = before.minY >= upper && before.maxY <= lower
        var positioned = before
        var requestedTravel: CGFloat = 0
        var rowExists: Bool?
        var measuredRowFrame: CGRect?
        var panStart: CGPoint?
        var panEnd: CGPoint?
        var panTop: CGFloat?
        var panBottom: CGFloat?
        var panStripLeft: CGFloat?
        var panStripRight: CGFloat?
        var panExecuted = false
        func captureGeometry() {
            let geometry = XCTAttachment(string: "form=\(visibleForm); toolbar=\(toolbar); controls=\(controls); band=\(upper)...\(lower); before=\(before); after=\(positioned); pan=\(!inside); requestedTravel=\(requestedTravel); rowExists=\(String(describing: rowExists)); row=\(String(describing: measuredRowFrame)); start=\(String(describing: panStart)); end=\(String(describing: panEnd)); panExecuted=\(panExecuted); admittedBand=\(finalUpper)...\(finalLower); nativeSelectionReadinessFollows=\(nativeSelectionReadinessFollows); keyboard=\(String(describing: measuredKeyboardFrame)); scrollBottom=\(scrollBottom); panTop=\(String(describing: panTop)); panBottom=\(String(describing: panBottom)); panStripLeft=\(String(describing: panStripLeft)); panStripRight=\(String(describing: panStripRight)); postPan=\(String(describing: postPanGeometry))")
            geometry.name = "Task144 actual Name viewport before the sole focus tap"
            geometry.lifetime = .keepAlways
            add(geometry)
        }
        if !inside {
            // Center the complete field to leave equal geometric margin for
            // either direction of native scroll/layout adjustment. One pan only.
            let targetMidY = (upper + lower) / 2
            let displacement = before.midY - targetMidY
            let top = upper + padding
            let bottom = scrollBottom - max(32, viewport.height * 0.06)
            panTop = top
            panBottom = bottom
            guard bottom > top else {
                captureGeometry()
                XCTFail("No scrollable Form margin above the keyboard/accessory region")
                return
            }
            let row = form.cells.containing(.textField, identifier: "task144.product.name").firstMatch
            rowExists = row.exists
            guard rowExists == true else {
                captureGeometry()
                XCTFail("The actual Name row must exist before the sole scroll gesture")
                return
            }
            guard let rowFrame = initial.row else {
                captureGeometry()
                XCTFail("The actual Name row must be in the current Form snapshot before the sole scroll gesture")
                return
            }
            measuredRowFrame = rowFrame
            let stripLeft = max(visibleForm.minX, rowFrame.minX)
            let stripRight = min(rowFrame.maxX, before.minX)
            let stripTop = max(rowFrame.minY, top)
            let stripBottom = min(rowFrame.maxY, bottom)
            panStripLeft = stripLeft
            panStripRight = stripRight
            let startX = (stripLeft + stripRight) / 2
            // The Name row can lie just below the safe drag band. Its leading
            // Form padding stays outside the field; clamp the start into the
            // visible Form band instead of requiring an impossible row overlap.
            let startY = min(bottom, max(top, (stripTop + stripBottom) / 2))
            let startPoint = CGPoint(x: startX, y: startY)
            panStart = startPoint
            guard stripRight > stripLeft, startY >= top, startY <= bottom,
                  visibleForm.contains(startPoint), !before.contains(startPoint) else {
                captureGeometry()
                XCTFail("The visible Form must expose a leading padding strip outside the Name field")
                return
            }
            let endY = min(bottom, max(top, startY - displacement))
            requestedTravel = endY - startY
            panEnd = CGPoint(x: startX, y: endY)
            // Begin in the measured Form leading padding, outside the editable field.
            let start = form.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: startX - formFrame.minX, dy: startY - formFrame.minY))
            panExecuted = true
            // Give the Form's native recognizer a real touch-down before the
            // same sole drag. A zero-duration press delivered the full pointer
            // path but left the Name row completely stationary on the hosted SDK.
            start.press(forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: 0, dy: endY - startY)),
                        withVelocity: .slow, thenHoldForDuration: 0.2)
            // Scrolling may change the toolbar/control layout. One fresh tree
            // must qualify the field against its current band, not the pre-pan one.
            guard let current = observeNameViewport() else { return }
            positioned = current.field
            finalUpper = current.upper
            finalLower = current.lower
            if nativeSelectionReadinessFollows && current.keyboard == nil {
                // This existing nonempty Name is immediately followed by the
                // original5s, two-snapshot native keyboard/selection readiness.
                // Before focus, the current visible Form is the actual boundary;
                // the upper-half reserve predicts a keyboard not yet present.
                XCTAssertFalse((field.value as? String ?? "").isEmpty,
                    "The unchanged native selection readiness must follow this nonempty Name")
                finalLower = current.scrollBottom - padding
            }
            finalVisibleForm = current.visibleForm
            postPanGeometry = "form=\(current.visibleForm); toolbar=\(current.toolbar); controls=\(current.controls); band=\(current.upper)...\(current.lower); keyboard=\(String(describing: current.keyboard))"
        }
        captureGeometry()
        XCTAssertTrue(finalVisibleForm.contains(positioned)
            && positioned.minY >= finalUpper && positioned.maxY <= finalLower,
                      "One controlled movement must put the complete Name field inside the usable band")
    }

    private enum TextFieldReadinessTarget {
        case identifier(String)
        case label(String)
    }

    private func readinessFrames(from root: XCUIElementSnapshot, target: TextFieldReadinessTarget) ->
        (field: CGRect, keyboard: CGRect, fieldCount: Int, keyboardCount: Int, complete: Bool) {
        var pending = [root]
        var fieldFrames: [CGRect] = []
        var keyboardFrames: [CGRect] = []
        var visited = 0
        while let node = pending.popLast() {
            visited += 1
            guard visited <= 1_024 else {
                return (.zero, .zero, fieldFrames.count, keyboardFrames.count, false)
            }
            if node.elementType == .textField {
                let matchesTarget: Bool
                switch target {
                case .identifier(let identifier): matchesTarget = node.identifier == identifier
                case .label(let label): matchesTarget = node.label == label
                }
                if matchesTarget { fieldFrames.append(node.frame) }
            }
            if node.elementType == .keyboard { keyboardFrames.append(node.frame) }
            pending.append(contentsOf: node.children)
        }
        return (fieldFrames.first ?? .zero, keyboardFrames.first ?? .zero,
                fieldFrames.count, keyboardFrames.count, true)
    }

    private func replaceText(in field: XCUIElement, with value: String,
                             readinessTarget: TextFieldReadinessTarget = .identifier("task144.product.name"),
                             positionViewportAfterFocus: Bool = false,
                             focusAlreadyPositioned: Bool = false) {
        if !focusAlreadyPositioned { field.tap() }
        let current = field.value as? String ?? ""
        let hasCurrentText = !current.isEmpty && current != field.placeholderValue
        let keyboard = app.keyboards.firstMatch
        if hasCurrentText || positionViewportAfterFocus {
            XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
            if positionViewportAfterFocus { positionNameInEditorViewport(field) }
        }
        if hasCurrentText {
            var previousFieldFrame: CGRect?
            var previousKeyboardFrame: CGRect?
            var readinessSamples: [String] = []
            var readinessSampleCount = 0
            var readinessPollCount = 0
            var hittabilityQueryCount = 0
            var invalidSnapshotSampleCount = 0
            var invalidSnapshotSamples: [String] = []
            var deferredReadinessAttachments: [(name: String, contents: String)] = []
            var readinessWaitStartedUptime: TimeInterval?
            var readinessWaitFinishedUptime: TimeInterval?
            var recordedReadinessResult: XCTWaiter.Result?
            var latestHitStartedUptime: TimeInterval?
            var latestHitFinishedUptime: TimeInterval?
            var readinessDiagnosticsEmitted = false
            let emitReadinessDiagnostics: (String) -> Void = { [weak self] phase in
                guard let self, !readinessDiagnosticsEmitted else { return }
                readinessDiagnosticsEmitted = true
                let attachmentEmissionStartedUptime = ProcessInfo.processInfo.systemUptime
                for deferred in deferredReadinessAttachments {
                    let attachment = XCTAttachment(string: deferred.contents)
                    attachment.name = deferred.name
                    attachment.lifetime = .keepAlways
                    self.add(attachment)
                }
                let attachmentEmissionFinishedUptime = ProcessInfo.processInfo.systemUptime
                let result = recordedReadinessResult.map { String($0.rawValue) } ?? "NOT_RETURNED"
                let waitStart = readinessWaitStartedUptime.map { String($0) } ?? "NOT_ARMED"
                let waitEnd = readinessWaitFinishedUptime.map { String($0) } ?? "NOT_RETURNED"
                let deadline = readinessWaitStartedUptime.map { String($0 + 5) } ?? "NOT_ARMED"
                let hitStart = latestHitStartedUptime.map { String($0) } ?? "NOT_QUERIED"
                let hitEnd = latestHitFinishedUptime.map { String($0) }
                    ?? (latestHitStartedUptime == nil ? "NOT_QUERIED" : "NOT_RETURNED")
                let hitRemaining = latestHitStartedUptime.flatMap { hitStart in
                    readinessWaitStartedUptime.map { String($0 + 5 - hitStart) }
                } ?? "NOT_QUERIED"
                let readinessText = "result=\(result); observed=\(readinessSampleCount); retained=\(readinessSamples.count); later=\(max(0, readinessSampleCount - readinessSamples.count)); polls=\(readinessPollCount); hit-queries=\(hittabilityQueryCount); invalid-snapshots=\(invalidSnapshotSampleCount); retained-invalid=\(invalidSnapshotSamples.count); later-invalid=\(max(0, invalidSnapshotSampleCount - invalidSnapshotSamples.count)); wait-start=\(waitStart); wait-end=\(waitEnd); deadline=\(deadline); latest-hit-start=\(hitStart); latest-hit-end=\(hitEnd); remaining-before-latest-hit=\(hitRemaining); hit-in-flight=\(latestHitStartedUptime != nil && latestHitFinishedUptime == nil); emission-phase=\(phase); attachment-emission-start=\(attachmentEmissionStartedUptime); attachment-emission-end=\(attachmentEmissionFinishedUptime); attachment-emission-seconds=\(attachmentEmissionFinishedUptime - attachmentEmissionStartedUptime)\n" + readinessSamples.joined(separator: "\n") + "\n" + invalidSnapshotSamples.joined(separator: "\n")
                let readiness = XCTAttachment(string: readinessText)
                readiness.name = "Task144 existing readiness predicate observations before assertion"
                readiness.lifetime = .keepAlways
                self.add(readiness)
                print("TASK144_READINESS_OBSERVATIONS \(readinessText)")
            }
            // XCTest still runs teardown blocks when a native getter records a
            // failure with continueAfterFailure=false. Flush only existing RAM
            // facts if that failure prevented the normal post-wait emission.
            addTeardownBlock { emitReadinessDiagnostics("teardown") }
            let sampleReadiness: () -> Bool = {
                guard let waitStartedUptime = readinessWaitStartedUptime else { return false }
                let deadlineUptime = waitStartedUptime + 5
                let pollStartedUptime = ProcessInfo.processInfo.systemUptime
                guard pollStartedUptime < deadlineUptime else { return false }
                readinessPollCount += 1
                // Capture the geometry pair from one hierarchy. The latest CI
                // returned a zero keyboard frame from separate queries while
                // nearby video frames showed the keyboard. Hittability below
                // still comes from the actual field's separate hit-point query.
                let captureStartedUptime = ProcessInfo.processInfo.systemUptime
                guard captureStartedUptime < deadlineUptime else { return false }
                let captureResult = Result(catching: { try self.app.snapshot() })
                let captureFinishedUptime = ProcessInfo.processInfo.systemUptime
                let captureTiming = "poll-start=\(pollStartedUptime); capture-start=\(captureStartedUptime); capture-end=\(captureFinishedUptime); capture-seconds=\(captureFinishedUptime - captureStartedUptime); remaining-before-capture=\(deadlineUptime - captureStartedUptime); remaining-after-capture=\(deadlineUptime - captureFinishedUptime); capture-out-of-window=\(captureFinishedUptime > deadlineUptime)"
                let snapshot: XCUIElementSnapshot
                switch captureResult {
                case .success(let captured):
                    snapshot = captured
                case .failure(let error):
                    previousFieldFrame = nil
                    previousKeyboardFrame = nil
                    invalidSnapshotSampleCount += 1
                    let snapshotError = error as NSError
                    let invalidSample = "poll=\(readinessPollCount); uptime=\(ProcessInfo.processInfo.systemUptime); \(captureTiming); snapshot-error-type=\(String(reflecting: type(of: error))); domain=\(snapshotError.domain); code=\(snapshotError.code); prior-geometry-cleared=true"
                    if invalidSnapshotSamples.count < 64 {
                        invalidSnapshotSamples.append(invalidSample)
                        deferredReadinessAttachments.append((
                            name: "Task144 readiness snapshot failure before assertion",
                            contents: invalidSample))
                    }
                    // An invalid observation cannot establish readiness or
                    // carry stability into the next sample. The original
                    // five-second waiter still requires two fresh valid samples.
                    return false
                }
                let frames = self.readinessFrames(from: snapshot, target: readinessTarget)
                let fieldFrame = frames.field
                let keyboardFrame = frames.keyboard
                let geometryIsUnambiguous = frames.complete && frames.fieldCount == 1 && frames.keyboardCount == 1
                let stable = geometryIsUnambiguous
                    && previousFieldFrame == fieldFrame && previousKeyboardFrame == keyboardFrame
                previousFieldFrame = geometryIsUnambiguous ? fieldFrame : nil
                previousKeyboardFrame = geometryIsUnambiguous ? keyboardFrame : nil
                let geometryReady = geometryIsUnambiguous && stable
                    && fieldFrame.height > 0 && keyboardFrame.height > 0
                    && fieldFrame.maxY < keyboardFrame.minY
                if readinessSampleCount < 64 {
                    deferredReadinessAttachments.append((
                        name: "Task144 actual readiness geometry before conditional hit-point query",
                        contents: "sample=\(readinessSampleCount + 1); field=\(fieldFrame); keyboard=\(keyboardFrame); stable=\(stable); snapshot-complete=\(frames.complete); field-count=\(frames.fieldCount); keyboard-count=\(frames.keyboardCount); hit-query-planned=\(geometryReady); \(captureTiming)"))
                }
                // Geometry that is already negative cannot admit this sample.
                // Query the actual hit point only for a candidate sample, keeping
                // its result mandatory without spending the waiter on a query
                // whose answer cannot change an unstable sample's verdict.
                let hittable: Bool?
                let hitStartedUptime = ProcessInfo.processInfo.systemUptime
                let queryHit = geometryReady && hitStartedUptime < deadlineUptime
                if queryHit {
                    hittabilityQueryCount += 1
                    latestHitStartedUptime = hitStartedUptime
                    latestHitFinishedUptime = nil
                    // Both coherent snapshots already require one exact target.
                    // Bind that exact predicate by index, avoiding the broad
                    // label-or-identifier unique-match resolver for the hit query.
                    let exactFields: XCUIElementQuery
                    switch readinessTarget {
                    case .identifier(let identifier):
                        exactFields = self.app.textFields.matching(NSPredicate(format: "identifier == %@", identifier))
                    case .label(let label):
                        exactFields = self.app.textFields.matching(NSPredicate(format: "label == %@", label))
                    }
                    hittable = exactFields.element(boundBy: 0).isHittable
                } else {
                    hittable = nil
                }
                let hitFinishedUptime = ProcessInfo.processInfo.systemUptime
                if queryHit { latestHitFinishedUptime = hitFinishedUptime }
                let hitTiming = queryHit
                    ? "hit-start=\(hitStartedUptime); hit-end=\(hitFinishedUptime); hit-seconds=\(hitFinishedUptime - hitStartedUptime); hit-out-of-window=\(hitFinishedUptime > deadlineUptime)"
                    : "hit-timing=NOT_QUERIED"
                let hittableObservation = hittable.map { String($0) }
                    ?? (geometryReady ? "NOT_QUERIED_DEADLINE_EXPIRED" : "NOT_QUERIED_GEOMETRY_NOT_READY")
                readinessSampleCount += 1
                if readinessSamples.count < 64 {
                    let pollFinishedUptime = ProcessInfo.processInfo.systemUptime
                    readinessSamples.append("sample=\(readinessSampleCount); uptime=\(pollFinishedUptime); \(captureTiming); \(hitTiming); remaining-after-observation=\(deadlineUptime - pollFinishedUptime); field=\(fieldFrame); keyboard=\(keyboardFrame); hittable=\(hittableObservation); hit-query-performed=\(queryHit); stable=\(stable); field-height-positive=\(fieldFrame.height > 0); keyboard-height-positive=\(keyboardFrame.height > 0); field-above-keyboard=\(fieldFrame.maxY < keyboardFrame.minY); snapshot-complete=\(frames.complete); field-count=\(frames.fieldCount); keyboard-count=\(frames.keyboardCount)")
                }
                return geometryReady && hittable == true
                    && hitFinishedUptime <= deadlineUptime
            }
            let ready = XCTestExpectation(description: "Name and keyboard are ready for native selection")
            let waitStartedUptime = ProcessInfo.processInfo.systemUptime
            readinessWaitStartedUptime = waitStartedUptime
            // Each synchronous sample obtains a new hierarchy. Start the next
            // one directly, without a predicate timer consuming the same budget.
            while ProcessInfo.processInfo.systemUptime < waitStartedUptime + 5 {
                if sampleReadiness() {
                    ready.fulfill()
                    break
                }
            }
            let remainingReadinessTime = max(
                0, waitStartedUptime + 5 - ProcessInfo.processInfo.systemUptime)
            let readinessResult = XCTWaiter.wait(for: [ready], timeout: remainingReadinessTime)
            readinessWaitFinishedUptime = ProcessInfo.processInfo.systemUptime
            recordedReadinessResult = readinessResult
            // Keep the same bounded diagnostics and order without writing
            // attachments while the five-second readiness budget is running.
            emitReadinessDiagnostics("after-wait")
            // A failed readiness may be observed after its deadline; diagnostic
            // AX queries must not consume the predicate's five-second budget.
            if readinessResult != .completed,
               app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_OBSERVE_NATIVE_NAME"] == "1" {
                let observationUptime = ProcessInfo.processInfo.systemUptime
                let observer = app.otherElements["task144.controlled.native-name-observation"]
                let observation = observer.exists ? (observer.value as? String ?? "MISSING_VALUE") : "MISSING_OBSERVER"
                let native = XCTAttachment(string: "post-readiness-result=\(readinessResult.rawValue); query-start-uptime=\(observationUptime); query-end-uptime=\(ProcessInfo.processInfo.systemUptime); \(observation)")
                native.name = "Task144 native Name post-readiness failure observation"
                native.lifetime = .keepAlways
                add(native)
            }
            XCTAssertEqual(readinessResult, .completed,
                           "The focused field and visible keyboard must finish repositioning before native selection")
            let geometry = XCTAttachment(string: "field=\(field.frame); keyboard=\(keyboard.frame)")
            geometry.name = "Task144 focused field geometry before the single native selection press"
            geometry.lifetime = .keepAlways
            add(geometry)
            // Use the native edit menu rather than typing keyboard glyphs or
            // relying on the caret position chosen by a tap in the field.
            field.press(forDuration: 1.1)
            let selectAll = app.descendants(matching: .any).matching(NSPredicate(
                format: "label == %@ AND (elementType == %d OR elementType == %d)",
                "Select All", XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.menuItem.rawValue
            )).firstMatch
            XCTAssertTrue(selectAll.waitForExistence(timeout: 5), "The native edit menu must select the full existing value")
            selectAll.tap()
            if case .identifier("task144.product.name") = readinessTarget,
               app.launchEnvironment["TASK145_DRAFT_REVIEW_UI"] != nil,
               app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_OBSERVE_NATIVE_NAME"] == "1" {
                do { try r3WaitNativeSelection(text: current, start: 0, end: current.utf16.count) }
                catch { XCTFail("Native Select All did not select the complete Name before typing"); return }
            }
        }
        field.typeText(value)
        XCTAssertEqual(field.value as? String, value, "The actual input replacement must be complete")
    }
    // TASK145_SCOPE_SWITCH_INSERT_BEGIN ui-tests
    private enum ScopeSwitchUIStop: Error { case semanticGate }
    private static let scopeDraftA = "Scope A unsaved isolated draft"
    private static let scopeNameB = "Qualified scope B product"
    private static let scopeShopB = "Controlled scope B"
    private static let scopeShopA = "Controlled local root"

    func testCancelledShopReplacementThenExplicitReturnPreservesOriginalDraft() throws {
        app.launchEnvironment["TASK145_SCOPE_SWITCH_UI"] = "cancel-explicit-return"
        app.launch()
        try scopeRequire(app.staticTexts["task145.scope.root-startup-completed"].waitForExistence(timeout: 30),
            stage: "C1-qualified-A-startup", downstream: ["draft-input", "select-B", "cancel", "explicit-return-A", "original-draft-readback"])
        let original = try scopeLedger("C1 real qualified A before input")
        try scopeAssertInitialA(original, stage: "C1-initial-A")
        let row = app.staticTexts["Safe local baseline"]
        try scopeRequire(row.waitForExistence(timeout: 5) && row.isHittable, stage: "C1-open-A-editor",
            downstream: ["draft-input", "select-B", "cancel", "explicit-return-A", "original-draft-readback"])
        row.tap()
        let name = app.textFields["task144.product.name"]
        try scopeRequire(name.waitForExistence(timeout: 5) && name.isHittable, stage: "C1-real-name-input",
            downstream: ["draft-input", "select-B", "cancel", "explicit-return-A", "original-draft-readback"])
        name.tap()
        try scopeRequire(app.keyboards.firstMatch.waitForExistence(timeout: 5) && name.isHittable,
            stage: "C1-native-keyboard-input-ready", downstream: ["draft-input", "select-B", "cancel", "explicit-return-A", "original-draft-readback"])
        name.press(forDuration: 1.1)
        let selectAll = app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ AND (elementType == %d OR elementType == %d)", "Select All",
            XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.menuItem.rawValue)).firstMatch
        try scopeRequire(selectAll.waitForExistence(timeout: 5), stage: "C1-native-select-all",
            downstream: ["draft-input", "select-B", "cancel", "explicit-return-A", "original-draft-readback"])
        selectAll.tap(); name.typeText(Self.scopeDraftA)
        try scopeRequire(name.value as? String == Self.scopeDraftA, stage: "C1-original-native-draft",
            downstream: ["select-B", "cancel", "explicit-return-A", "original-draft-readback"])
        let selectB = app.buttons["task144.controlled.editor.scope.select-b"]
        try scopeRequire(selectB.waitForExistence(timeout: 5) && selectB.isHittable, stage: "C1-debug-selection-producer",
            downstream: ["select-B", "cancel", "explicit-return-A", "original-draft-readback"])
        scopeUIAttachment("C1 input is the DEBUG ShopContextStore.selectShop producer while the actual editor is open; this is not a native picker tap")
        selectB.tap()
        try scopeRequire(app.staticTexts["task145.scope.b-selected"].waitForExistence(timeout: 10),
            stage: "C1-selected-B-without-confirmation", downstream: ["cancel", "explicit-return-A", "original-draft-readback"])
        let selectedB = try scopeLedger("C1 selected B; old A body retained, never exposed as B")
        let foreignAHidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !name.exists && !row.exists
        }, object: nil)
        try scopeRequire(XCTWaiter.wait(for: [foreignAHidden], timeout: 5) == .completed,
            stage: "C1-selected-B-does-not-expose-A-editor-or-row", downstream: ["cancel", "explicit-return-A", "original-draft-readback"])
        let before = try scopeLastValues(selectedB, kind: "native-draft-before-controlled-select-b")
        try scopeRequire(before["draft-name"] == Self.scopeDraftA && before["draft-observer-bound"] == "true",
            stage: "C1-real-presentation-draft-producer", downstream: ["cancel", "explicit-return-A", "original-draft-readback"])
        try scopeOpenReplacementDecision(stage: "C1-normal-replacement-decision", downstream: ["cancel", "explicit-return-A", "original-draft-readback"], revealOptionsWithinOriginalBudget: true)
        let keep = app.alerts.buttons["Keep local data"]
        try scopeRequire(keep.exists && keep.isHittable, stage: "C1-real-cancel-choice",
            downstream: ["cancel", "explicit-return-A", "original-draft-readback"])
        keep.tap()
        let cancelled = try scopeObserveAndRead("C1 after real Keep local; no automatic A reselection required")
        let cancelBody = try scopeLastValues(cancelled, kind: "native-ui-checkpoint")
        let initial = try scopeFacts(original)
        try scopeRequire(cancelBody["manifest-sha256"] == initial["initial-manifest-sha256"]
            && cancelBody["binding-sha256"] == initial["initial-binding-sha256"]
            && cancelBody["fingerprint"] == initial["initial-fingerprint"]
            && cancelBody["pending"] == initial["initial-pending"]
            && cancelBody["outbox"] == initial["initial-outbox"]
            && cancelBody["journal-present"] == "false" && cancelBody["raw-write-count"] == "0",
            stage: "C1-cancel-preserves-A-storage", downstream: ["explicit-return-A", "original-draft-readback"])
        // The test explicitly chooses A through the actual picker. Cancel is not expected to do this.
        try scopeChooseShop(current: Self.scopeShopB, target: Self.scopeShopA,
            stage: "C1-explicit-normal-return-A", downstream: ["original-draft-readback"])
        let database = app.tabBars.buttons["Database"]
        try scopeRequire(database.waitForExistence(timeout: 10) && database.isHittable,
            stage: "C1-returned-A-database", downstream: ["original-draft-readback"])
        database.tap()
        if !name.exists {
            try scopeRequire(row.waitForExistence(timeout: 10) && row.isHittable,
                stage: "C1-reopen-original-A-record", downstream: ["original-draft-readback"])
            row.tap()
        }
        try scopeRequire(name.waitForExistence(timeout: 5), stage: "C1-reopened-native-editor",
            downstream: ["original-draft-readback"])
        let returned = try scopeObserveAndRead("C1 explicit A return; original native draft readback")
        let returnedBody = try scopeLastValues(returned, kind: "native-ui-checkpoint")
        try scopeRequire(name.value as? String == Self.scopeDraftA && returnedBody["draft-name"] == Self.scopeDraftA,
            stage: "C1-original-draft-preserved-without-reinjection", downstream: [])
        try scopeRequire(returnedBody["manifest-sha256"] == initial["initial-manifest-sha256"]
            && returnedBody["selected-shop"] == initial["initial-selected-shop"]
            && returnedBody["local-access"] == "true" && returnedBody["body-proof"] == "true"
            && returnedBody["raw-write-count"] == "0", stage: "C1-terminal-A-qualified", downstream: [])
        scopeUIAttachment("C1 PASS through actual Cancel, explicit A selection, unchanged storage and native draft")
    }

    func testConfirmedShopReplacementQualifiesBAndRejectsDelayedAResponse() throws {
        app.launchEnvironment["TASK145_SCOPE_SWITCH_UI"] = "confirmed-delayed-response"
        app.launchEnvironment["TASK131_INITIAL_TAB"] = "inventory"
        app.launch()
        try scopeRequire(app.staticTexts["task145.scope.root-startup-completed"].waitForExistence(timeout: 30),
            stage: "C2-qualified-A-startup", downstream: ["hold-real-A-response", "select-B", "confirm", "qualify-B", "late-A-completion"])
        try scopeAssertInitialA(try scopeLedger("C2 actual initial A qualification"), stage: "C2-initial-A")
        let hold = app.buttons["task144.controlled.scope.hold-a"]
        try scopeRequire(hold.waitForExistence(timeout: 5) && hold.isHittable, stage: "C2-request-real-A-refresh",
            downstream: ["hold-real-A-response", "select-B", "confirm", "qualify-B", "late-A-completion"])
        hold.tap()
        let held = scopeWaitForEntry("old-a-response-held", timeout: 10)
        try scopeRequire(held, stage: "C2-provider-actually-held-A", downstream: ["select-B", "confirm", "qualify-B", "late-A-completion"])
        let heldLedger = try scopeLedger("C2 actual A refresh producer and held provider response")
        try scopeRequire(try scopeEntries(heldLedger, kind: "old-a-refresh-requested").count == 1
            && scopeEntries(heldLedger, kind: "old-a-provider-return").isEmpty,
            stage: "C2-old-A-not-returned-early", downstream: ["select-B", "confirm", "qualify-B", "late-A-completion"])
        try scopeChooseShop(current: Self.scopeShopA, target: Self.scopeShopB,
            stage: "C2-normal-picker-B", downstream: ["confirm", "qualify-B", "late-A-completion"])
        try scopeRequire(app.staticTexts["task145.scope.b-selected"].waitForExistence(timeout: 10),
            stage: "C2-selected-B", downstream: ["confirm", "qualify-B", "late-A-completion"])
        try scopeOpenReplacementDecision(stage: "C2-normal-replacement-decision", downstream: ["confirm", "qualify-B", "late-A-completion"], revealOptionsWithinOriginalBudget: true)
        let unconfirmed = try scopeLedger("C2 B selected before actual destructive confirmation")
        try scopeRequire(try scopeEntries(unconfirmed, kind: "b-real-replacement-journal").isEmpty
            && scopeEntries(unconfirmed, kind: "b-qualified-real-body").isEmpty,
            stage: "C2-no-B-before-confirmation", downstream: ["confirm", "qualify-B", "late-A-completion"])
        let replace = app.alerts.buttons["Replace with cloud data"]
        try scopeRequire(replace.exists && replace.isEnabled && replace.isHittable,
            stage: "C2-real-enabled-confirmation", downstream: ["confirm", "qualify-B", "late-A-completion"])
        replace.tap()
        try scopeRequire(app.staticTexts["task145.scope.b-qualified"].waitForExistence(timeout: 45),
            stage: "C2-real-B-qualification", downstream: ["late-A-completion"])
        let before = try scopeLedger("C2 B qualified via actual coordinator and recovery before A response returns")
        try scopeRequire(try !scopeEntries(before, kind: "b-real-replacement-journal").isEmpty
            && scopeEntries(before, kind: "old-a-provider-return").isEmpty,
            stage: "C2-real-order-confirm-B-before-A", downstream: ["late-A-completion"])
        let database = app.tabBars.buttons["Database"]
        try scopeRequire(database.waitForExistence(timeout: 5) && database.isHittable,
            stage: "C2-qualified-B-visible-shell", downstream: ["late-A-completion"])
        database.tap()
        try scopeRequire(app.staticTexts[Self.scopeNameB].waitForExistence(timeout: 5)
            && !app.staticTexts["Safe local baseline"].exists,
            stage: "C2-real-B-row-A-not-exposed", downstream: ["late-A-completion"])
        let release = app.buttons["task144.controlled.scope.release-a"]
        try scopeRequire(release.waitForExistence(timeout: 5) && release.isHittable,
            stage: "C2-release-real-old-A-response", downstream: ["late-A-completion"])
        release.tap()
        try scopeRequire(app.staticTexts["task145.scope.callback-terminal"].waitForExistence(timeout: 15),
            stage: "C2-real-old-A-consumer-completion", downstream: [])
        let after = try scopeLedger("C2 old A response returned and consumer completed; B remains current")
        let qualified = try scopeLastValues(before, kind: "b-qualified-real-body")
        let terminal = try scopeLastValues(after, kind: "b-after-old-a-completion")
        let protected = ["manifest-sha256", "generation", "binding-sha256", "selected-shop", "product-id",
            "name", "fingerprint", "pending", "outbox", "watermark", "local-access", "body-proof"]
        try scopeRequire(protected.allSatisfy { terminal[$0] == qualified[$0] }
            && terminal["raw-write-count"] == "0" && terminal["captured-a-scope-rejected"] == "true"
            && terminal["old-generation-lease-rejected"] == "true",
            stage: "C2-B-protected-after-actual-A-callback", downstream: [])
        try scopeRequire(try scopeEntries(after, kind: "old-a-provider-return").count == 1
            && scopeEntries(after, kind: "old-a-refresh-completed").count == 1,
            stage: "C2-single-actual-provider-and-consumer-completion", downstream: [])
        try scopeRequire(app.staticTexts[Self.scopeNameB].exists && !app.staticTexts["Safe local baseline"].exists,
            stage: "C2-terminal-visible-B-no-foreign-A", downstream: [])
        scopeUIAttachment("C2 PASS actual B qualification and delayed A callback isolation")
    }

    private func scopeChooseShop(current: String, target: String, stage: String, downstream: [String]) throws {
        let inventory = app.tabBars.buttons["Inventory"]
        try scopeRequire(inventory.waitForExistence(timeout: 5) && inventory.isHittable,
            stage: stage + "-inventory-entry", downstream: downstream)
        inventory.tap()
        // One five-second window admits existence and two coherent native frames.
        let switcherDeadline = ProcessInfo.processInfo.systemUptime + 5
        let switcher = app.buttons.matching(NSPredicate(format: "label == %@", current)).element(boundBy: 0)
        var previousGeometry: (button: CGRect, window: CGRect)?
        var switcherReady = false
        while ProcessInfo.processInfo.systemUptime < switcherDeadline {
            let nodes = try c3OptionsSnapshotNodes(try app.snapshot(), stage: stage + "-switcher", downstream: downstream)
            let matches = nodes.filter { $0.elementType == .button && $0.label == current }
            let buttonFrame = matches.first?.frame ?? .zero
            let windows = nodes.filter { $0.elementType == .window && matches.count == 1
                && matches[0].path.starts(with: $0.path) }
            let windowFrame = windows.first?.frame ?? .zero
            let geometryReady = matches.count == 1 && windows.count == 1
                && [buttonFrame, windowFrame].allSatisfy({ frame in
                    [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy { $0.isFinite }
                        && frame.width > 0 && frame.height > 0
                }) && windowFrame.contains(buttonFrame)
            let stable = geometryReady && previousGeometry?.button == buttonFrame
                && previousGeometry?.window == windowFrame
            previousGeometry = geometryReady ? (buttonFrame, windowFrame) : nil
            if stable {
                switcherReady = ProcessInfo.processInfo.systemUptime < switcherDeadline
                    && switcher.isHittable && ProcessInfo.processInfo.systemUptime < switcherDeadline
                if switcherReady { break }
            }
            let remaining = switcherDeadline - ProcessInfo.processInfo.systemUptime
            if remaining > 0 { RunLoop.current.run(until: Date().addingTimeInterval(min(0.05, remaining))) }
        }
        try scopeRequire(switcherReady && ProcessInfo.processInfo.systemUptime < switcherDeadline,
            stage: stage + "-actual-switcher", downstream: downstream)
        let admission = XCTAttachment(string: "stage=\(stage); native-geometry=\(String(describing: previousGeometry)); admitted-uptime=\(ProcessInfo.processInfo.systemUptime); deadline=\(switcherDeadline)")
        admission.name = "Task145 shop switcher admission " + stage
        admission.lifetime = .keepAlways
        add(admission)
        try scopeRequire(ProcessInfo.processInfo.systemUptime < switcherDeadline,
            stage: stage + "-switcher-admission-before-single-tap", downstream: downstream)
        switcher.tap()
        let choice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", target)).firstMatch
        try scopeRequire(choice.waitForExistence(timeout: 5) && choice.isEnabled && choice.isHittable,
            stage: stage + "-actual-target-row", downstream: downstream)
        choice.tap()
    }
    private func scopeOpenReplacementDecision(stage: String, downstream: [String],
                                               revealOptionsWithinOriginalBudget: Bool = false) throws {
        let keep = app.alerts.buttons["Keep local data"]
        if !keep.exists {
            let options = app.tabBars.buttons["Options"]
            try scopeRequire(options.waitForExistence(timeout: 5) && options.isHittable,
                stage: stage + "-Options-reachable", downstream: downstream)
            options.tap()
            if revealOptionsWithinOriginalBudget {
                // One absolute window replaces Keep5 + Review5.
                // Added reveal, sole Review tap and dialog admission ALL consume it.
                let decisionDeadline = ProcessInfo.processInfo.systemUptime + 10
                var reviewTapped = false
                var drags = 0
                var decisionGeometry: [String] = []
                defer {
                    let attachment = XCTAttachment(string: decisionGeometry.joined(separator: "\n"))
                    attachment.name = "C3 bounded real-decision geometry"
                    attachment.lifetime = .keepAlways; add(attachment)
                }
                func checked<T>(_ operation: () -> T) throws -> T {
                    let failureStage = stage + (reviewTapped ? "-real-dialog" : "-Review-reachable")
                    try scopeRequire(ProcessInfo.processInfo.systemUptime < decisionDeadline,
                        stage: failureStage, downstream: downstream)
                    let result = operation()
                    try scopeRequire(ProcessInfo.processInfo.systemUptime < decisionDeadline,
                        stage: failureStage, downstream: downstream)
                    return result
                }
                let review = app.buttons["Review"].firstMatch
                // A single native containment query proves both alternatives
                // belong to the same real dialog. Keep still needs a live hit point.
                let decisionDialogs = app.alerts
                    .containing(.button, identifier: "Keep local data")
                    .containing(.button, identifier: "Replace with cloud data")
                let forms = app.collectionViews
                try scopeRequire(try checked({ forms.count == 1 }),
                    stage: stage + "-unique-Options-Form", downstream: downstream)
                let form = forms.element(boundBy: 0)
                while ProcessInfo.processInfo.systemUptime < decisionDeadline {
                    if try checked({ decisionDialogs.count == 1 }) {
                        let keepHittable = try checked({ keep.isHittable })
                        if keepHittable {
                            try scopeRequire(ProcessInfo.processInfo.systemUptime < decisionDeadline,
                                stage: stage + "-real-dialog", downstream: downstream)
                            return
                        }
                    }
                    if !reviewTapped {
                        try scopeRequire(try checked({ app.navigationBars["Options"].exists }),
                            stage: stage + "-actual-Options-navigation", downstream: downstream)
                        let observation = try c3OptionsViewport(form, stage: stage + "-decision", ordinal: drags,
                            deadline: decisionDeadline, collectContentAnchors: false, downstream: downstream)
                        let viewport = observation.viewport
                        let reviewFrame = observation.decisionReviewFrame
                        if decisionGeometry.count < 16 {
                            decisionGeometry.append("uptime=\(ProcessInfo.processInfo.systemUptime); deadline=\(decisionDeadline); drags=\(drags); viewport=\(viewport); review=\(String(describing: reviewFrame))")
                        }
                        if let frame = reviewFrame {
                            try scopeRequire([frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy { $0.isFinite }
                                && !frame.isNull && !frame.isInfinite && frame.width > 0 && frame.height > 0,
                                stage: stage + "-Review-frame", downstream: downstream)
                            // Hittability alone admitted a Review tap above the
                            // actual Options Form. Admit its entire current frame.
                            if viewport.contains(frame), try checked({ review.isHittable }) {
                                reviewTapped = true
                                try checked({ review.tap() })
                                continue
                            }
                        }
                        if drags < 5 {
                            let upward: Bool
                            if let frame = reviewFrame {
                                upward = frame.midY > viewport.midY
                            } else {
                                // No gesture occurred after this viewport capture.
                                // Its native Form scrollbar values are the same
                                // observation used to decide this reveal direction.
                                let offsets = observation.scrollValues
                                try scopeRequire(!offsets.isEmpty && Set(offsets).count == 1
                                    && offsets[0].range(of: "^(100|[0-9]{1,2})%$", options: .regularExpression) != nil,
                                    stage: stage + "-observed-Form-offset", downstream: downstream)
                                // Review belongs to the first Cloud section.
                                // When a retained offset hides it, seek the top
                                // before scrolling toward lower content.
                                upward = offsets[0] == "0%"
                            }
                            drags += 1
                            // Decision reveal has no consecutive-content overlap
                            // requirement. A longer in-viewport pan reaches the
                            // retained Cloud offset before the same10s deadline.
                            let halfStep: CGFloat
                            if let frame = reviewFrame {
                                halfStep = min(0.45, max(12 / viewport.height,
                                    abs(viewport.midY - frame.midY) / viewport.height / 2))
                            } else { halfStep = 0.45 }
                            try checked({ c3OptionsDrag(form, viewport: viewport,
                                applicationOrigin: observation.applicationOrigin, upward: upward,
                                halfStepFraction: halfStep, velocity: .fast) })
                        }
                    }
                }
                try scopeRequire(false, stage: stage + (reviewTapped ? "-real-dialog" : "-Review-reachable"),
                    downstream: downstream)
                return // The opted-in branch never falls back to a restarted wait.
            }
            if !keep.waitForExistence(timeout: 5) {
                let review = app.buttons["Review"].firstMatch
                try scopeRequire(review.waitForExistence(timeout: 5) && review.isHittable,
                    stage: stage + "-Review-reachable", downstream: downstream)
                review.tap()
            }
        }
        try scopeRequire(keep.waitForExistence(timeout: 5)
            && app.alerts.buttons["Replace with cloud data"].exists,
            stage: stage + "-real-dialog", downstream: downstream)
    }
    private func scopeObserveAndRead(_ stage: String) throws -> [String: Any] {
        let before = try scopeEntries(try scopeLedger(stage + " before observation"), kind: "native-ui-checkpoint").count
        let editor = app.buttons["task144.controlled.editor.scope.observe"]
        let button = editor.exists ? editor : app.buttons["task144.controlled.scope.observe"]
        try scopeRequire(button.waitForExistence(timeout: 5) && button.isHittable,
            stage: stage + "-read-only-observation", downstream: ["downstream-oracles"])
        button.tap()
        try scopeRequire(scopeWaitForEntry("native-ui-checkpoint", minimumCount: before + 1, timeout: 5),
            stage: stage + "-fresh-readback", downstream: ["downstream-oracles"])
        return try scopeLedger(stage)
    }
    private func scopeRawLedger() -> String? {
        let editor = app.staticTexts["task144.controlled.editor.scope.ledger"]
        let element = editor.exists ? editor : app.staticTexts["task144.controlled.scope.ledger"]
        return element.exists ? element.value as? String : nil
    }
    private func scopeLedger(_ stage: String) throws -> [String: Any] {
        guard let raw = scopeRawLedger(), let bytes = Data(base64Encoded: raw),
              let object = try? JSONSerialization.jsonObject(with: bytes),
              let ledger = object as? [String: Any] else {
            try scopeRequire(false, stage: stage + "-actual-ledger-missing-or-invalid", downstream: ["all-dependent-oracles"])
            throw ScopeSwitchUIStop.semanticGate
        }
        try scopeRequire(ledger["schema"] as? String == "task145-scope-switch-observation-v1"
            && (ledger["runID"] as? String)?.lowercased() == runID.lowercased(),
            stage: stage + "-namespace", downstream: ["all-dependent-oracles"])
        try scopeRequire(!app.staticTexts["task145.scope.failure"].exists
            && (ledger["facts"] as? [String: String])?["failure-stage"] == nil,
            stage: stage + "-fixture-observation-without-failure", downstream: ["all-dependent-oracles"])
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = "TASK145 C actual ledger: " + stage; attachment.lifetime = .keepAlways; add(attachment)
        scopeUIAttachment(stage)
        return ledger
    }
    private func scopeFacts(_ ledger: [String: Any]) throws -> [String: String] {
        guard let facts = ledger["facts"] as? [String: String] else {
            try scopeRequire(false, stage: "actual-ledger-facts-missing", downstream: ["all-dependent-oracles"])
            throw ScopeSwitchUIStop.semanticGate
        }
        return facts
    }
    private func scopeEntries(_ ledger: [String: Any], kind: String) throws -> [[String: Any]] {
        guard let entries = ledger["entries"] as? [[String: Any]] else {
            try scopeRequire(false, stage: "actual-ledger-entries-missing", downstream: ["all-dependent-oracles"])
            throw ScopeSwitchUIStop.semanticGate
        }
        return entries.filter { $0["kind"] as? String == kind }
    }
    private func scopeLastValues(_ ledger: [String: Any], kind: String) throws -> [String: String] {
        guard let values = try scopeEntries(ledger, kind: kind).last?["values"] as? [String: String] else {
            try scopeRequire(false, stage: "actual-boundary-not-traversed-" + kind, downstream: ["all-dependent-oracles"])
            throw ScopeSwitchUIStop.semanticGate
        }
        return values
    }
    private func scopeAssertInitialA(_ ledger: [String: Any], stage: String) throws {
        let facts = try scopeFacts(ledger)
        try scopeRequire(facts["initial-name"] == "Safe local baseline" && facts["initial-body-proof"] == "true"
            && facts["initial-local-access"] == "true" && facts["initial-pending"] == "0"
            && facts["initial-journal-present"] == "false",
            stage: stage, downstream: ["all-dependent-oracles"])
    }
    private func scopeWaitForEntry(_ kind: String, minimumCount: Int = 1, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { [weak self] _, _ in
            guard let raw = self?.scopeRawLedger(), let data = Data(base64Encoded: raw),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let ledger = object as? [String: Any], let entries = ledger["entries"] as? [[String: Any]] else { return false }
            return entries.filter { $0["kind"] as? String == kind }.count >= minimumCount
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
    private func scopeRequire(_ condition: Bool, stage: String, downstream: [String],
        file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else {
            let result: [String: Any] = ["runID": runID, "failedStage": stage, "status": "FAIL",
                "type": "SIM_NATIVE_UI_SEMANTIC", "downstream": Dictionary(uniqueKeysWithValues: downstream.map { ($0, "NOT_TRAVERSED") }),
                "uptime": ProcessInfo.processInfo.systemUptime, "fixtureFailureVisible": app.staticTexts["task145.scope.failure"].exists]
            let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            let outcome = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            outcome.name = "TASK145 C first semantic FAIL and NOT_TRAVERSED downstream"; outcome.lifetime = .keepAlways; add(outcome)
            if let raw = scopeRawLedger(), let bytes = Data(base64Encoded: raw) {
                let ledger = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
                ledger.name = "TASK145 C unchanged actual ledger at first FAIL"; ledger.lifetime = .keepAlways; add(ledger)
            }
            scopeUIAttachment("FIRST_FAIL " + stage)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "TASK145 C native hierarchy at first semantic FAIL"; hierarchy.lifetime = .keepAlways; add(hierarchy)
            print("TASK145_SCOPE_SWITCH_FIRST_FAIL \(String(decoding: data, as: UTF8.self))")
            XCTFail("TASK145 C semantic gate missing: \(stage); downstream NOT_TRAVERSED", file: file, line: line)
            throw ScopeSwitchUIStop.semanticGate
        }
    }
    private func scopeUIAttachment(_ stage: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "TASK145 C native UI: " + stage; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    // TASK145_SCOPE_SWITCH_INSERT_END ui-tests

    // Adjacent privacy witness uses the same bounded explicit Review reveal.
    func testOptionsWithdrawsQualifiedASummaryWhileBSelectedAndRestoresItOnlyAfterExplicitReturn() throws {
        try task146ConfigureAnimationIdleDriver()
        app.launchEnvironment["TASK146_C3_COMPACT_FACT_BAND"] = "1"
        app.launchEnvironment["TASK145_SCOPE_SWITCH_UI"] = "cancel-explicit-return"
        app.launch()
        try scopeRequire(app.staticTexts["task145.scope.root-startup-completed"].waitForExistence(timeout: 30),
            stage: "C3-qualified-A-startup", downstream: ["load-A-summary", "select-B", "administrative-privacy", "explicit-return-A"])
        let initial = try scopeLedger("C3 actual qualified A before Options")
        try scopeAssertInitialA(initial, stage: "C3-initial-A")
        let options = app.tabBars.buttons["Options"]
        try scopeRequire(options.waitForExistence(timeout: 5) && options.isHittable,
            stage: "C3-actual-Options-entry", downstream: ["load-A-summary", "select-B", "administrative-privacy", "explicit-return-A"])
        options.tap()
        // SwiftUI propagates the card ID to status and count Text descendants.
        // Reveal the exact public Products row attested by this one-product fixture.
        let summaryRows = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@",
            "options.local-database-summary", "Products, 1"))
        let summary = summaryRows.firstMatch
        let sync = app.descendants(matching: .any).matching(identifier: "options.sync-business-summary").firstMatch
        let form = try c3OptionsForm(stage: "C3-A", downstream: ["select-B", "administrative-privacy", "explicit-return-A"])
        try c3OptionsRewindToTop(form, stage: "C3-A-top", privacy: false,
            downstream: ["select-B", "administrative-privacy", "explicit-return-A"])
        try c3OptionsReveal(sync, form: form, stage: "C3-A-cloud", downstream: ["select-B", "administrative-privacy", "explicit-return-A"], velocity: .fast)
        try scopeRequire(sync.waitForExistence(timeout: 10) && sync.isHittable,
            stage: "C3-actual-qualified-A-cloud-summary-loaded", downstream: ["select-B", "administrative-privacy", "explicit-return-A"])
        let admittedSyncAX = sync.debugDescription
        try c3OptionsReveal(summary, form: form, stage: "C3-A-local", downstream: ["select-B", "administrative-privacy", "explicit-return-A"], velocity: .slow, halfStepFraction: 0.45)
        try scopeRequire(summary.waitForExistence(timeout: 10) && summaryRows.count == 1 && summary.isHittable,
            stage: "C3-actual-qualified-A-summary-loaded", downstream: ["select-B", "administrative-privacy", "explicit-return-A"])
        try c3RequireLocalSummaryValues(form,
            stage: "C3-real-A-product-count-and-baseline-date", downstream: ["select-B", "administrative-privacy", "explicit-return-A"])
        let summaryAX = XCTAttachment(string: summary.debugDescription + "\nSYNC EARLIER QUALIFIED NATIVE VIEWPORT\n" + admittedSyncAX)
        summaryAX.name = "TASK145 C3 admitted A actual counts, baseline date, pending and diagnostics surface"
        summaryAX.lifetime = .keepAlways; add(summaryAX)
        let beforeSelection = try scopeObserveAndRead("C3 A summary loaded before normal picker selection")
        try scopeChooseShop(current: Self.scopeShopA, target: Self.scopeShopB,
            stage: "C3-normal-picker-B", downstream: ["administrative-privacy", "explicit-return-A"])
        try scopeRequire(app.staticTexts["task145.scope.b-selected"].waitForExistence(timeout: 10),
            stage: "C3-B-selected-with-A-body-retained", downstream: ["administrative-privacy", "explicit-return-A"])
        try scopeOpenReplacementDecision(stage: "C3-real-administrative-decision", downstream: ["administrative-privacy", "explicit-return-A"], revealOptionsWithinOriginalBudget: true)
        let keep = app.alerts.buttons["Keep local data"]
        let replace = app.alerts.buttons["Replace with cloud data"]
        try scopeRequire(keep.isHittable && replace.exists && replace.isEnabled,
            stage: "C3-real-current-replacement-choices", downstream: ["administrative-privacy", "explicit-return-A"])
        scopeUIAttachment("C3 real replacement decision with A summary withdrawn")
        keep.tap()
        options.tap()
        let unavailable = app.staticTexts["options.business-summary-unavailable"]
        let administrativeForm = try c3OptionsForm(stage: "C3-B", downstream: ["explicit-return-A"])
        try c3OptionsTraverseAdministrativeForm(administrativeForm)
        let deniedAX = XCTAttachment(string: app.debugDescription)
        deniedAX.name = "TASK145 C3 B-selected Options native AX: administrative controls and no A business cards"
        deniedAX.lifetime = .keepAlways; add(deniedAX)
        let blocked = try scopeObserveAndRead("C3 after actual Keep local, blocked Options privacy readback")
        let blockedBody = try scopeLastValues(blocked, kind: "native-ui-checkpoint")
        let original = try scopeFacts(initial)
        let ingressAfter = try scopeEntries(blocked, kind: "raw-ingress")
        let entriesBefore = try XCTUnwrap(beforeSelection["entries"] as? [[String: Any]])
        let entriesAfter = try XCTUnwrap(blocked["entries"] as? [[String: Any]])
        let selectedBEntries = try scopeEntries(blocked, kind: "b-selected-readback")
        try scopeRequire(selectedBEntries.count == 1,
            stage: "C3-unique-selected-B-boundary", downstream: ["explicit-return-A"])
        let selectedB = try XCTUnwrap(selectedBEntries.first)
        let selectedOrdinal = try XCTUnwrap(selectedB["ordinal"] as? Int)
        let selectedUptime = try XCTUnwrap(selectedB["uptime"] as? Double)
        let selectedBody = try XCTUnwrap(selectedB["values"] as? [String: String])
        let blockedCheckpoint = try XCTUnwrap(try scopeEntries(blocked, kind: "native-ui-checkpoint").last)
        let scopeA = try XCTUnwrap(initial["shopA"] as? String).lowercased()
        let scopeB = try XCTUnwrap(initial["shopB"] as? String).lowercased()
        try scopeRequire((blocked["shopA"] as? String)?.lowercased() == scopeA
            && (blocked["shopB"] as? String)?.lowercased() == scopeB
            && selectedBody["selected-shop"] == scopeB && selectedBody["context-shop"] == scopeB
            && selectedBody["manifest-shop"] == scopeA && selectedBody["local-access"] == "false"
            && selectedOrdinal > entriesBefore.count
            && selectedOrdinal < (blockedCheckpoint["ordinal"] as? Int ?? 0)
            && selectedUptime < (blockedCheckpoint["uptime"] as? Double ?? 0),
            stage: "C3-attested-blocked-B-window", downstream: ["explicit-return-A"])
        let prefixBefore = try JSONSerialization.data(withJSONObject: entriesBefore, options: [.sortedKeys])
        let prefixAfter = try JSONSerialization.data(withJSONObject: Array(entriesAfter.prefix(entriesBefore.count)), options: [.sortedKeys])
        // Inventory can reconcile A while the native picker is reached. Once B
        // is attested, every business ingress must remain absent, for either shop.
        let noBlockedIngress = ingressAfter.allSatisfy { entry in
            guard let ordinal = entry["ordinal"] as? Int, let uptime = entry["uptime"] as? Double,
                  let values = entry["values"] as? [String: String] else { return false }
            return ordinal < selectedOrdinal && uptime < selectedUptime && values["shop"] == scopeA
        }
        try scopeRequire(prefixAfter == prefixBefore && noBlockedIngress,
            stage: "C3-no-new-observed-business-ingress-from-blocked-surface", downstream: ["explicit-return-A"])
        try scopeRequire(blockedBody["manifest-sha256"] == original["initial-manifest-sha256"]
            && blockedBody["binding-sha256"] == original["initial-binding-sha256"]
            && blockedBody["fingerprint"] == original["initial-fingerprint"]
            && blockedBody["pending"] == original["initial-pending"] && blockedBody["outbox"] == original["initial-outbox"]
            && blockedBody["local-access"] == "false" && blockedBody["journal-present"] == "false"
            && blockedBody["raw-write-count"] == "0", stage: "C3-hidden-not-deleted-A", downstream: ["explicit-return-A"])
        try scopeChooseShop(current: Self.scopeShopB, target: Self.scopeShopA,
            stage: "C3-explicit-normal-return-A", downstream: ["qualified-summary-return"])
        options.tap()
        let returnedForm = try c3OptionsForm(stage: "C3-return-A", downstream: ["qualified-summary-return"])
        try c3OptionsRewindToTop(returnedForm, stage: "C3-return-A-top", privacy: false, downstream: ["qualified-summary-return"], halfStepFraction: 0.45, velocity: .fast)
        try c3OptionsReveal(sync, form: returnedForm, stage: "C3-return-A-cloud", downstream: ["qualified-summary-return"], velocity: .fast)
        try scopeRequire(sync.waitForExistence(timeout: 10) && sync.isHittable && !unavailable.exists,
            stage: "C3-current-A-cloud-return", downstream: ["qualified-summary-return"])
        try c3OptionsReveal(summary, form: returnedForm, stage: "C3-return-A-local", downstream: ["qualified-summary-return"], velocity: .slow, halfStepFraction: 0.45)
        try scopeRequire(summary.waitForExistence(timeout: 10) && summary.isHittable && !unavailable.exists,
            stage: "C3-current-A-summary-return", downstream: ["qualified-summary-return"])
        try c3RequireLocalSummaryValues(returnedForm,
            stage: "C3-real-A-values-return-without-injection", downstream: [])
        let returned = try scopeObserveAndRead("C3 explicit A return qualifies original preserved body")
        let returnedBody = try scopeLastValues(returned, kind: "native-ui-checkpoint")
        try scopeRequire(returnedBody["fingerprint"] == original["initial-fingerprint"]
            && returnedBody["manifest-sha256"] == original["initial-manifest-sha256"]
            && returnedBody["local-access"] == "true" && returnedBody["body-proof"] == "true"
            && returnedBody["raw-write-count"] == "0", stage: "C3-terminal-qualified-A-no-business-write", downstream: [])
        scopeUIAttachment("C3 PASS actual A summary, B administrative privacy, explicit qualified A return")
    }
    // LabeledContent exports sibling StaticText rows with the card's identifier.
    // Bind the two exact public rows to one Cell rather than treating a row as their container.
    private func c3RequireLocalSummaryValues(_ form: XCUIElement, stage: String,
                                             downstream: [String]) throws {
        let identifier = "options.local-database-summary"
        let datePrefix = "Last sync, "
        let productsPredicate = NSPredicate(format: "identifier == %@ AND label == %@", identifier, "Products, 1")
        let baselinePredicate = NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", identifier, datePrefix)
        let products = form.staticTexts.matching(productsPredicate)
        let baselines = form.staticTexts.matching(baselinePredicate)
        let cards = form.cells.containing(productsPredicate).containing(baselinePredicate)
        try scopeRequire(products.count == 1 && baselines.count == 1 && cards.count == 1,
            stage: stage, downstream: downstream)
        let product = products.element(boundBy: 0)
        let baseline = baselines.element(boundBy: 0)
        let card = cards.element(boundBy: 0)
        try scopeRequire(card.exists && card.isHittable && product.exists && baseline.exists
            && card.staticTexts.matching(productsPredicate).count == 1
            && card.staticTexts.matching(baselinePredicate).count == 1
            && !baseline.label.dropFirst(datePrefix.count).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            stage: stage, downstream: downstream)
    }
    // C3-only native Form traversal. No C1/C2 helper or production authority changes.
    private func c3OptionsForm(stage: String, downstream: [String]) throws -> XCUIElement {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        var ready = false
        while ProcessInfo.processInfo.systemUptime < deadline {
            if isolationTabIsSelected("Options", requiresForm: true) {
                ready = ProcessInfo.processInfo.systemUptime < deadline
                break
            }
        }
        try scopeRequire(ready, stage: stage + "-unique-native-Form", downstream: downstream)
        return app.collectionViews.element(boundBy: 0)
    }
    private func c3OptionsScrollValues(_ form: XCUIElement) -> [String] {
        form.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Vertical scroll bar"))
            .allElementsBoundByIndex.map { $0.value as? String ?? "UNAVAILABLE" }
    }
    private func c3OptionsEndpoint(_ form: XCUIElement, value: String) -> Bool {
        let values = c3OptionsScrollValues(form)
        return !values.isEmpty && values.allSatisfy { $0 == value }
    }
    private struct C3OptionsContentAnchor {
        let role: String
        let identity: String
        let frame: CGRect
        let viewport: CGRect
        let visibleContent: CGRect
    }
    private struct C3OptionsSnapshotNode {
        let path: [Int]
        let elementType: XCUIElement.ElementType
        let identifier: String
        let label: String
        let frame: CGRect
        let rawValue: Any?
        let isSelected: Bool
        var value: String? { rawValue as? String }
    }
    private func c3OptionsSnapshotNodes(_ root: XCUIElementSnapshot, stage: String,
                                        downstream: [String]) throws -> [C3OptionsSnapshotNode] {
        // Same finite 1,024-node observation bound used by the readiness helpers.
        // Overflow cannot supply a partial hierarchy to the association checks.
        var pending: [(XCUIElementSnapshot, [Int])] = [(root, [])]
        var nodes: [C3OptionsSnapshotNode] = []
        while let (node, path) = pending.popLast() {
            let children = node.children
            try scopeRequire(nodes.count + pending.count + children.count + 1 <= 1_024,
                stage: stage + "-snapshot-overflow-NOT_QUALIFIED", downstream: downstream)
            nodes.append(C3OptionsSnapshotNode(path: path, elementType: node.elementType,
                identifier: node.identifier, label: node.label, frame: node.frame,
                rawValue: node.value, isSelected: node.isSelected))
            for (index, child) in children.enumerated().reversed() {
                pending.append((child, path + [index]))
            }
        }
        return nodes
    }
    // C3's source-defined OptionRow contract, not matching(identifier:) emulation.
    // Only the two complete public shapes observed for this component qualify.
    // Non-string public values retain their presence and cannot masquerade as nil.
    private func c3OptionRowSnapshotIsExact(_ nodes: [C3OptionsSnapshotNode],
                                            title: String, subtitle: String) -> Bool {
        guard let button = nodes.first, button.path.isEmpty, button.elementType == .button,
              button.identifier.isEmpty, button.rawValue == nil, nodes.count <= 1_024 else { return false }
        let selected: Bool
        if button.label == title + ", Current, " + subtitle { selected = true }
        else if button.label == title + ", " + subtitle { selected = false }
        else { return false }
        let expected: [(XCUIElement.ElementType, String, String)] = selected
            ? [(.staticText, "", title), (.staticText, "", "Current"), (.staticText, "", subtitle),
               (.image, "checkmark.circle.fill", "Selected")]
            : [(.staticText, "", title), (.staticText, "", subtitle), (.image, "circle", "circle")]
        guard nodes.count == expected.count + 1 else { return false }
        for (index, attributes) in expected.enumerated() {
            let node = nodes[index + 1]
            guard node.path == [index], node.elementType == attributes.0,
                  node.identifier == attributes.1, node.label == attributes.2,
                  node.rawValue == nil else { return false }
        }
        return true
    }
    private func c3OptionRowRootAssociation(_ freshNodes: [C3OptionsSnapshotNode],
                                             formNodes: [C3OptionsSnapshotNode],
                                             title: String, subtitle: String) -> C3OptionsSnapshotNode? {
        guard c3OptionRowSnapshotIsExact(freshNodes, title: title, subtitle: subtitle),
              let fresh = freshNodes.first, formNodes.count <= 1_024 else { return nil }
        // Search the complete Form before geometry pruning, including offscreen twins.
        let matches = formNodes.filter {
            $0.elementType == fresh.elementType && $0.identifier == fresh.identifier && $0.label == fresh.label
        }
        guard matches.count == 1, let root = matches.first else { return nil }
        let rootSubtree = formNodes.filter { $0.path.starts(with: root.path) }.map { node in
            C3OptionsSnapshotNode(path: Array(node.path.dropFirst(root.path.count)),
                elementType: node.elementType, identifier: node.identifier, label: node.label,
                frame: node.frame, rawValue: node.rawValue, isSelected: node.isSelected)
        }
        guard c3OptionRowSnapshotIsExact(rootSubtree, title: title, subtitle: subtitle) else { return nil }
        return root
    }
    func testC3OptionRowSnapshotOracleRejectsFourteenMalformedTrees() {
        // Pure helper vectors: no app launch, query, gesture, or fixture mutation.
        let title = "Automatic"
        let subtitle = "Use the same theme (light/dark) set in iOS."
        func node(_ path: [Int], _ type: XCUIElement.ElementType, _ label: String,
                  identifier: String = "", rawValue: Any? = nil) -> C3OptionsSnapshotNode {
            C3OptionsSnapshotNode(path: path, elementType: type, identifier: identifier,
                label: label, frame: .zero, rawValue: rawValue, isSelected: false)
        }
        let plain = [node([], .button, title + ", " + subtitle), node([0], .staticText, title),
            node([1], .staticText, subtitle), node([2], .image, "circle", identifier: "circle")]
        let selected = [node([], .button, title + ", Current, " + subtitle), node([0], .staticText, title),
            node([1], .staticText, "Current"), node([2], .staticText, subtitle),
            node([3], .image, "Selected", identifier: "checkmark.circle.fill")]
        func association(_ fresh: [C3OptionsSnapshotNode], _ root: [C3OptionsSnapshotNode]) -> C3OptionsSnapshotNode? {
            c3OptionRowRootAssociation(fresh, formNodes: root, title: title, subtitle: subtitle)
        }
        XCTAssertNotNil(association(plain, plain))
        XCTAssertNotNil(association(selected, selected))
        var negatives: [(String, [C3OptionsSnapshotNode], [C3OptionsSnapshotNode])] = []
        var bad = plain; bad[0] = node([], .other, plain[0].label)
        negatives.append(("wrong-button-type", bad, plain))
        bad = plain; bad[0] = node([], .button, plain[0].label, identifier: title)
        negatives.append(("conflicting-button-identifier", bad, plain))
        bad = plain; bad[0] = node([], .button, plain[0].label, rawValue: NSNumber(value: 1))
        negatives.append(("unexpected-button-public-value-including-nonstring", bad, plain))
        bad = plain; bad.remove(at: 1)
        negatives.append(("missing-title-even-when-root-has-it", bad, plain))
        bad = plain; bad.insert(node([3], .staticText, title), at: 2)
        negatives.append(("duplicate-title", bad, plain))
        bad = plain; bad.remove(at: 2)
        negatives.append(("missing-subtitle-even-when-root-has-it", bad, plain))
        bad = plain; bad.append(node([3], .staticText, subtitle))
        negatives.append(("duplicate-subtitle", bad, plain))
        bad = plain; bad[0] = node([], .button, title + ", wrong subtitle")
        negatives.append(("wrong-composite-content-label", bad, plain))
        bad = plain; bad[1] = node([0], .button, title)
        negatives.append(("title-has-wrong-element-type", bad, plain))
        bad = plain; bad[1] = node([0], .staticText, "wrong title", identifier: title)
        negatives.append(("identifier-correct-label-wrong", bad, plain))
        bad = plain; bad[2] = node([1], .staticText, subtitle, rawValue: false)
        negatives.append(("unexpected-text-public-value-including-nonstring", bad, plain))
        bad = selected; bad[4] = node([3], .image, "circle", identifier: "circle")
        negatives.append(("Current-selection-image-conflict", bad, selected))
        bad = plain; bad.append(node([1, 0], .staticText, "extra", identifier: subtitle))
        negatives.append(("extra-nested-identifier-collision", bad, plain))
        let twin = plain.map { node([10] + $0.path, $0.elementType, $0.label, identifier: $0.identifier) }
        negatives.append(("duplicate-full-root-button-including-offscreen", plain, plain + twin))
        XCTAssertEqual(negatives.count, 14)
        for (name, fresh, root) in negatives {
            XCTAssertNil(association(fresh, root), name)
        }
        // Root association cannot borrow siblings, ignore stale structure, or accept
        // a partial/overflow hierarchy, even when the fresh Button alone is valid.
        XCTAssertNil(association(plain, []))
        bad = plain; bad[2] = node([1], .staticText, "stale subtitle")
        XCTAssertNil(association(plain, bad))
        XCTAssertNil(association(plain, plain + Array(repeating: node([99], .other, ""), count: 1_024)))
        bad = plain; bad[2] = node([9, 1], .staticText, subtitle)
        XCTAssertNil(association(bad, plain))
        bad = plain; bad[1] = node([0], .staticText, title, identifier: subtitle)
        XCTAssertNil(association(bad, plain))
        bad = plain; bad[1] = node([0], .staticText, title, rawValue: "unexpected")
        XCTAssertNil(association(bad, plain))
    }
    // One synchronous recorder per viewport. Keys are a fixed site/opcode product;
    // stage, ordinal and the maximum-call index are values, never extra buckets.
    private final class C3OptionsQueryTiming {
        enum Site: String, CaseIterable, Hashable {
            case form, navigation, band, tab, button, administrative
        }
        enum Opcode: String, CaseIterable, Hashable {
            case enumeration, exists, hittable, label, titleCount, subtitleCount, identifier, elementType, elementSnapshot, count
        }
        private struct Key: Hashable {
            let site: Site
            let opcode: Opcode
        }
        private struct Aggregate {
            var count: Int
            var sum: TimeInterval
            var minimum: TimeInterval
            var maximum: TimeInterval
            var maximumStarted: TimeInterval
            var maximumFinished: TimeInterval
            var maximumIndex: Int?
        }
        private let stage: String
        private let ordinal: Int
        private var aggregates: [Key: Aggregate] = [:]

        init(stage: String, ordinal: Int) {
            self.stage = stage
            self.ordinal = ordinal
        }

        func measure<T>(_ opcode: Opcode, site: Site, index: Int? = nil,
                        _ read: () throws -> T) rethrows -> T {
            let started = ProcessInfo.processInfo.systemUptime
            defer {
                let finished = ProcessInfo.processInfo.systemUptime
                let duration = finished - started
                let key = Key(site: site, opcode: opcode)
                if var aggregate = aggregates[key] {
                    aggregate.count += 1
                    aggregate.sum += duration
                    aggregate.minimum = min(aggregate.minimum, duration)
                    if duration > aggregate.maximum {
                        aggregate.maximum = duration
                        aggregate.maximumStarted = started
                        aggregate.maximumFinished = finished
                        aggregate.maximumIndex = index
                    }
                    aggregates[key] = aggregate
                } else {
                    aggregates[key] = Aggregate(count: 1, sum: duration, minimum: duration,
                        maximum: duration, maximumStarted: started, maximumFinished: finished,
                        maximumIndex: index)
                }
            }
            return try read()
        }

        func diagnosticText() -> String {
            // Reads only bounded aggregates, never XCUIElement/snapshot properties.
            var lines = ["stage=\(stage); ordinal=\(ordinal); clock=systemUptime; unit=seconds",
                "public-call durations include XCTest internals; not IPC/network latency",
                "button indexes are the pinned eight-role order for native hittability; the shared post-getter snapshot has no index"]
            for site in Site.allCases {
                for opcode in Opcode.allCases {
                    guard let value = aggregates[Key(site: site, opcode: opcode)] else { continue }
                    let index = value.maximumIndex.map { String($0) } ?? "none"
                    lines.append("site=\(site.rawValue); opcode=\(opcode.rawValue); count=\(value.count); sum=\(value.sum); min=\(value.minimum); max=\(value.maximum); max-start=\(value.maximumStarted); max-end=\(value.maximumFinished); max-index=\(index)")
                }
            }
            return lines.joined(separator: "\n")
        }
    }
    private func c3OptionsSnapshotMatch(_ element: XCUIElement, type: XCUIElement.ElementType,
                                        nodes: [C3OptionsSnapshotNode], stage: String,
                                        downstream: [String], timing: C3OptionsQueryTiming,
                                        site: C3OptionsQueryTiming.Site) throws -> C3OptionsSnapshotNode {
        // This fresh per-element capture supplies type, identifier and label together.
        // Reuse only this capture, never a prior viewport or the older root label.
        // Correlate within the same full snapshot subtree, never traversal order.
        let elementSnapshot: XCUIElementSnapshot
        do {
            elementSnapshot = try timing.measure(.elementSnapshot, site: site) {
                try element.snapshot()
            }
        } catch {
            try scopeRequire(false,
                stage: stage + "-snapshot-live-capture-NOT_QUALIFIED", downstream: downstream)
            throw ScopeSwitchUIStop.semanticGate
        }
        let identifier = elementSnapshot.identifier
        let label = elementSnapshot.label
        let matches = nodes.filter { $0.elementType == type && $0.identifier == identifier && $0.label == label }
        try scopeRequire(elementSnapshot.elementType == type && matches.count == 1,
            stage: stage + "-snapshot-live-association-NOT_QUALIFIED", downstream: downstream)
        return matches[0]
    }
    @discardableResult
    private func c3OptionsViewport(_ form: XCUIElement, stage: String, ordinal: Int,
                                   deadline: TimeInterval, collectContentAnchors: Bool = true,
                                   downstream: [String]) throws -> (anchors: [String: C3OptionsContentAnchor], viewport: CGRect, applicationOrigin: CGPoint, decisionReviewFrame: CGRect?, scrollValues: [String]) {
        try scopeRequire(ProcessInfo.processInfo.systemUptime < deadline,
            stage: stage + "-traversal-deadline-before-viewport", downstream: downstream)
        let observationStarted = ProcessInfo.processInfo.systemUptime
        // One coherent global capture preserves the original cardinality gates.
        // Separate global counts plus owning-window queries added native round
        // trips to every decision viewport without reducing that window's data.
        let captureStarted = ProcessInfo.processInfo.systemUptime
        let captureResult = Result(catching: { try app.snapshot() })
        let captureFinished = ProcessInfo.processInfo.systemUptime
        let root: XCUIElementSnapshot
        switch captureResult {
        case .success(let captured): root = captured
        case .failure(let error):
            let snapshotError = error as NSError
            let failure = XCTAttachment(string: "capture-start=\(captureStarted); capture-end=\(captureFinished); domain=\(snapshotError.domain); code=\(snapshotError.code)")
            failure.name = "TASK145 C3 snapshot capture failure " + stage
            failure.lifetime = .keepAlways; add(failure)
            try scopeRequire(false, stage: stage + "-snapshot-capture-NOT_QUALIFIED", downstream: downstream)
            throw ScopeSwitchUIStop.semanticGate
        }
        // This cache is local to one viewport call. Every subsequent call, including
        // after every drag, takes a new snapshot; it never supplies hittability.
        let queryTiming = C3OptionsQueryTiming(stage: stage, ordinal: ordinal)
        let nodes = try c3OptionsSnapshotNodes(root, stage: stage, downstream: downstream)
        // Use one fresh same-window geometry for all C3 viewports. The Form
        // query is firstMatch and this hierarchy must contain exactly one Form.
        // Live Button hit points and fresh complete association remain below.
        let forms = nodes.filter { $0.elementType == .collectionView }
        let navigation = nodes.filter { $0.elementType == .navigationBar }
        let windows = nodes.filter { window in
            window.elementType == .window && navigation.contains { node in
                node.identifier == "Options" && node.path.starts(with: window.path)
            }
        }
        let bands = nodes.filter { $0.elementType == .other && $0.identifier == "task144.controlled.band" }
        let tabs = nodes.filter { $0.elementType == .tabBar }
        try scopeRequire(forms.count == 1 && windows.count == 1 && navigation.count <= 1
            && bands.count <= 1 && tabs.count <= 1
            && forms[0].path.starts(with: windows[0].path)
            && (navigation + bands + tabs).allSatisfy({ $0.path.starts(with: windows[0].path) }),
            stage: stage + "-coherent-native-Form-geometry", downstream: downstream)
        let geometry = forms + windows + navigation + bands + tabs
        try scopeRequire(geometry.allSatisfy { node in
            let frame = node.frame
            return [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy { $0.isFinite }
                && !frame.isNull && !frame.isInfinite && frame.width > 1 && frame.height > 1
        }, stage: stage + "-coherent-native-geometry-frames", downstream: downstream)
        let formNode = forms[0]
        let formFrame = formNode.frame
        let clipped = formFrame.intersection(windows[0].frame)
        var top = clipped.minY
        var bottom = clipped.maxY
        if let frame = navigation.first?.frame { top = max(top, frame.maxY) }
        if let frame = bands.first?.frame { top = max(top, frame.maxY) }
        if let frame = tabs.first?.frame { bottom = min(bottom, frame.minY) }
        let viewportFrame = CGRect(x: clipped.minX, y: top, width: clipped.width, height: bottom - top)
        try scopeRequire([viewportFrame.minX, viewportFrame.minY, viewportFrame.maxX, viewportFrame.maxY].allSatisfy { $0.isFinite }
            && !viewportFrame.isNull && !viewportFrame.isInfinite && viewportFrame.width > 1 && viewportFrame.height > 1
            && ProcessInfo.processInfo.systemUptime < deadline,
            stage: stage + "-actual-visible-Form-frame-NOT_QUALIFIED", downstream: downstream)
        if !collectContentAnchors {
            // Use this same fresh hierarchy for Review geometry; the caller
            // still requires its actual live hit point before the sole tap.
            let reviews = nodes.filter { $0.elementType == .button && $0.label == "Review" }
            try scopeRequire(reviews.count <= 1
                && reviews.allSatisfy({ $0.path.starts(with: forms[0].path) }),
                stage: stage + "-unique-native-Review-in-Form", downstream: downstream)
            let scrollValues = nodes.filter { $0.path.count > formNode.path.count
                && $0.path.starts(with: formNode.path) && $0.label.hasPrefix("Vertical scroll bar") }
                .map { $0.value ?? "UNAVAILABLE" }
            return (anchors: [:], viewport: viewportFrame, applicationOrigin: root.frame.origin,
                decisionReviewFrame: reviews.first?.frame, scrollValues: scrollValues)
        }
        let formNodes = nodes.filter { $0.path.count > formNode.path.count && $0.path.starts(with: formNode.path) }
        // These eight source-unique OptionRow roles are Buttons in Section bodies,
        // never Theme/Language/Cloud headers. Titles and subtitles are the pinned English UI.
        let optionRows: [(role: String, title: String, subtitle: String)] = [
            ("theme.system", "Automatic", "Use the same theme (light/dark) set in iOS."),
            ("theme.light", "Light", "Light background, ideal in very bright environments."),
            ("theme.dark", "Dark", "Dark background, easier on the eyes indoors or at night."),
            ("language.system", "System", "Use the device's default language."),
            ("language.zh", "中文", "Chinese (Simplified)."),
            ("language.it", "Italiano", "Recommended primary language for this installation."),
            ("language.es", "Español", "For stores and staff who speak Spanish."),
            ("language.en", "English", "Basic international interface.")
        ]
        // Preserve the current public OptionRows before any Button hittability
        // getter can terminate this viewport. This cached projection is evidence
        // only: it never supplies live existence, hittability or privacy.
        let preGetterPublicRows: [[String: Any]] = optionRows.map { role in
            let labels = [role.title + ", " + role.subtitle, role.title + ", Current, " + role.subtitle]
            let matches = formNodes.filter { $0.elementType == .button && labels.contains($0.label) }
            return ["role": role.role, "publicLabels": labels,
                "prefixMatchCount": formNodes.filter { $0.elementType == .button && $0.label.hasPrefix(role.title + ",") }.count,
                "publicMatches": matches.map { node in
                    ["type": node.elementType.rawValue, "label": node.label,
                     "identifierEmpty": node.identifier.isEmpty, "valuePresent": node.rawValue != nil,
                     "frame": String(describing: node.frame)] as [String: Any]
                }]
        }
        let preGetterRootValues: [String: Any] = ["stage": stage, "ordinal": ordinal,
            "snapshotStarted": captureStarted, "snapshotFinished": captureFinished,
            "uptime": ProcessInfo.processInfo.systemUptime, "deadline": deadline,
            "viewport": String(describing: viewportFrame), "publicOptionRows": preGetterPublicRows]
        let preGetterRoot = XCTAttachment(data: try JSONSerialization.data(withJSONObject: preGetterRootValues, options: [.sortedKeys]),
            uniformTypeIdentifier: "public.json")
        preGetterRoot.name = "TASK145 C3 PRE-GETTER eight public OptionRows " + stage + " #\(ordinal)"
        preGetterRoot.lifetime = .keepAlways; add(preGetterRoot)
        // Enumerate the complete union and every role natively. An absent
        // virtualized row is an empty result, never an unresolved firstMatch
        // whose implicit retries consume the traversal window. No snapshot
        // geometry prunes candidates or supplies their native hittability.
        let rolePredicates: [NSPredicate] = optionRows.map { role in
            NSPredicate(format: "label BEGINSWITH %@", role.title + ",")
        }
        let unionCount = queryTiming.measure(.enumeration, site: .button) {
            form.buttons.matching(NSCompoundPredicate(orPredicateWithSubpredicates: rolePredicates))
                .allElementsBoundByIndex.count
        }
        var enumeratedCount = 0
        var liveRoles: Set<String> = []
        for (roleIndex, role) in optionRows.enumerated() {
            try scopeRequire(ProcessInfo.processInfo.systemUptime < deadline,
                stage: stage + "-pre-getter-witness-deadline-before", downstream: downstream)
            let buttons = queryTiming.measure(.enumeration, site: .button, index: roleIndex) {
                form.buttons.matching(rolePredicates[roleIndex]).allElementsBoundByIndex
            }
            enumeratedCount += buttons.count
            try scopeRequire(buttons.count <= 1,
                stage: stage + "-native-option-role-not-unique", downstream: downstream)
            for button in buttons {
                let hittable = queryTiming.measure(.hittable, site: .button, index: roleIndex) { button.isHittable }
                if hittable { liveRoles.insert(role.role) }
            }
            try scopeRequire(ProcessInfo.processInfo.systemUptime < deadline,
                stage: stage + "-pre-getter-witness-deadline-after", downstream: downstream)
        }
        try scopeRequire(enumeratedCount == unionCount,
            stage: stage + "-complete-native-option-role-enumeration", downstream: downstream)
        // One complete, fresh capture AFTER every live getter supplies all
        // role subtrees at the same instant. No role is pruned by geometry;
        // the native getters above cover every enumerated row, including offscreen rows.
        let postGetterSnapshot: XCUIElementSnapshot
        do {
            postGetterSnapshot = try queryTiming.measure(.elementSnapshot, site: .button) { try form.snapshot() }
        } catch {
            let failure = error as NSError
            let detail = XCTAttachment(string: "stage=\(stage); ordinal=\(ordinal); domain=\(failure.domain); code=\(failure.code); description=\(String(failure.localizedDescription.prefix(2_048)))")
            detail.name = "TASK145 C3 complete post-getter Form snapshot error"
            detail.lifetime = .keepAlways; add(detail)
            try scopeRequire(false, stage: stage + "-option-snapshot-live-capture-NOT_QUALIFIED", downstream: downstream)
            throw ScopeSwitchUIStop.semanticGate
        }
        try scopeRequire(ProcessInfo.processInfo.systemUptime < deadline && postGetterSnapshot.elementType == .collectionView,
            stage: stage + "-post-getter-complete-Form-within-deadline", downstream: downstream)
        let postGetterNodes = try c3OptionsSnapshotNodes(postGetterSnapshot, stage: stage + "-all-options", downstream: downstream)
        var qualifiedButtons: [String: [C3OptionsSnapshotNode]] = [:]
        for role in optionRows where liveRoles.contains(role.role) {
            let roots = postGetterNodes.filter { $0.elementType == .button && $0.label.hasPrefix(role.title + ",") }
            try scopeRequire(roots.count == 1,
                stage: stage + "-option-role-routing-NOT_QUALIFIED", downstream: downstream)
            let root = roots[0]
            let freshNodes = postGetterNodes.filter { $0.path.starts(with: root.path) }.map { node in
                C3OptionsSnapshotNode(path: Array(node.path.dropFirst(root.path.count)),
                    elementType: node.elementType, identifier: node.identifier, label: node.label,
                    frame: node.frame, rawValue: node.rawValue, isSelected: node.isSelected)
            }
            guard c3OptionRowRootAssociation(freshNodes, formNodes: postGetterNodes,
                    title: role.title, subtitle: role.subtitle) != nil,
                  let node = c3OptionRowRootAssociation(freshNodes, formNodes: formNodes,
                    title: role.title, subtitle: role.subtitle) else {
                try scopeRequire(false, stage: stage + "-" + role.role + "-snapshot-content-and-association-NOT_QUALIFIED", downstream: downstream)
                throw ScopeSwitchUIStop.semanticGate
            }
            qualifiedButtons[role.role, default: []].append(node)
        }
        var anchors: [String: C3OptionsContentAnchor] = [:]
        for role in optionRows {
            let matches = qualifiedButtons[role.role] ?? []
            guard matches.count == 1, let node = matches.first else { continue }
            let frame = node.frame
            let visibleFrame = frame.intersection(viewportFrame)
            guard [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy({ $0.isFinite }),
                  !frame.isNull && !frame.isInfinite && frame.width > 1 && frame.height > 1,
                  !visibleFrame.isNull && visibleFrame.width > 1 && visibleFrame.height > 1 else { continue }
            let identity = ["OptionRow.Button", role.role, role.title, role.subtitle, node.identifier, node.label].joined(separator: "\u{1f}")
            anchors[role.role] = C3OptionsContentAnchor(role: role.role, identity: identity, frame: frame,
                viewport: viewportFrame, visibleContent: visibleFrame.offsetBy(dx: -frame.minX, dy: -frame.minY))
        }
        // The only additional content role is the source-unique administrative Text ID
        // inside the Cloud body. A header, footer or arbitrary matching label is not an anchor.
        let administrative = form.staticTexts.matching(identifier: "options.business-summary-unavailable")
        if queryTiming.measure(.count, site: .administrative, { administrative.count }) == 1 {
            let element = administrative.firstMatch
            if queryTiming.measure(.hittable, site: .administrative, { element.isHittable }) {
                let node = try c3OptionsSnapshotMatch(element, type: .staticText, nodes: formNodes,
                    stage: stage + "-administrative", downstream: downstream, timing: queryTiming, site: .administrative)
                let frame = node.frame
                let visibleFrame = frame.intersection(viewportFrame)
                if [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy({ $0.isFinite }),
                   !frame.isNull && !frame.isInfinite && frame.width > 1 && frame.height > 1,
                   !visibleFrame.isNull && visibleFrame.width > 1 && visibleFrame.height > 1 {
                    let role = "cloud.administrative-text"
                    let identity = ["CloudBody.StaticText", role, node.identifier, node.label].joined(separator: "\u{1f}")
                    anchors[role] = C3OptionsContentAnchor(role: role, identity: identity, frame: frame,
                        viewport: viewportFrame, visibleContent: visibleFrame.offsetBy(dx: -frame.minX, dy: -frame.minY))
                }
            }
        }
        let anchorsFinished = ProcessInfo.processInfo.systemUptime
        // Geometric diagnostic projection only. Neither snapshot presence nor
        // intersection is reported as live exists/isHittable or a privacy oracle.
        let staticTextDiagnostics: [[String: Any]] = formNodes.filter { $0.elementType == .staticText }.map { node in
            let intersection = node.frame.intersection(viewportFrame)
            return ["label": node.label, "identifier": node.identifier, "frame": String(describing: node.frame),
                "intersectionWithViewport": String(describing: intersection)]
        }
        let snapshotHierarchy: [[String: Any]] = nodes.map { node in
            ["path": node.path, "type": node.elementType.rawValue, "identifier": node.identifier,
             "label": node.label, "frame": String(describing: node.frame), "value": node.value ?? "UNAVAILABLE"]
        }
        let snapshotScrollValues = formNodes.filter { $0.label.hasPrefix("Vertical scroll bar") }
            .map { $0.value ?? "UNAVAILABLE" }
        let values: [String: Any] = ["stage": stage, "ordinal": ordinal,
            "uptime": ProcessInfo.processInfo.systemUptime, "observationStarted": observationStarted,
            "snapshotStarted": captureStarted, "snapshotFinished": captureFinished, "anchorsFinished": anchorsFinished,
            "deadline": deadline, "snapshotNodeCount": nodes.count, "snapshotScrollValues": snapshotScrollValues,
            "snapshotStaticTextsGeometryOnly": staticTextDiagnostics,
            "qualifiedContentAnchors": anchors.values.sorted { $0.role < $1.role }.map {
                ["role": $0.role, "identity": $0.identity, "frame": String(describing: $0.frame),
                 "viewport": String(describing: $0.viewport), "visibleContent": String(describing: $0.visibleContent)] }]
        let viewport = XCTAttachment(data: try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]),
            uniformTypeIdentifier: "public.json")
        viewport.name = "TASK145 C3 actual Form viewport " + stage + " #\(ordinal)"
        viewport.lifetime = .keepAlways; add(viewport)
        let hierarchy = XCTAttachment(data: try JSONSerialization.data(withJSONObject: snapshotHierarchy, options: [.sortedKeys]),
            uniformTypeIdentifier: "public.json")
        hierarchy.name = "TASK145 C3 public snapshot hierarchy " + stage + " #\(ordinal)"
        hierarchy.lifetime = .keepAlways; add(hierarchy)
        scopeUIAttachment("C3 Form " + stage + " #\(ordinal)")
        let queryMetrics = XCTAttachment(string: queryTiming.diagnosticText())
        queryMetrics.name = "TASK145 C3 live query timing " + stage + " #\(ordinal)"
        queryMetrics.lifetime = .keepAlways; add(queryMetrics)
        let diagnosticsFinished = ProcessInfo.processInfo.systemUptime
        let timing = XCTAttachment(string: "observation-start=\(observationStarted); snapshot-start=\(captureStarted); snapshot-end=\(captureFinished); anchors-end=\(anchorsFinished); diagnostics-end=\(diagnosticsFinished); deadline=\(deadline)")
        timing.name = "TASK145 C3 viewport timing " + stage + " #\(ordinal)"
        timing.lifetime = .keepAlways; add(timing)
        try scopeRequire(ProcessInfo.processInfo.systemUptime < deadline,
            stage: stage + "-traversal-deadline-after-viewport", downstream: downstream)
        return (anchors: anchors, viewport: viewportFrame, applicationOrigin: root.frame.origin,
            decisionReviewFrame: nil, scrollValues: snapshotScrollValues)
    }
    private func c3OptionsDrag(_ form: XCUIElement, viewport: CGRect, applicationOrigin: CGPoint, upward: Bool,
                               halfStepFraction: CGFloat = 0.29, velocity: XCUIGestureVelocity = .slow) {
        // The default keeps 42% pointer overlap; B bounds its step by a
        // qualified content anchor and verifies actual content overlap below.
        // Both endpoints remain inside the just-qualified viewport, and each
        // later viewport rechecks actual content overlap before advancing.
        let halfStep = viewport.height * halfStepFraction
        let offset = upward ? halfStep : -halfStep
        let appOrigin = applicationOrigin
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: viewport.midX - appOrigin.x, dy: viewport.midY + offset - appOrigin.y))
        let end = origin.withOffset(CGVector(dx: viewport.midX - appOrigin.x, dy: viewport.midY - offset - appOrigin.y))
        start.press(forDuration: 0.2, thenDragTo: end, withVelocity: velocity, thenHoldForDuration: 0.2)
    }
    private func c3NoBusinessInCurrentViewport(stage: String, downstream: [String]) throws {
        // One public query resolves the four original absence conditions together.
        // Both known public name forms are rejected; this is a finite privacy
        // contract for these components, not general matching(identifier:) emulation.
        let summaryIDs = ["options.local-database-summary", "options.sync-business-summary"]
        let hiddenPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "identifier IN %@ OR label IN %@", summaryIDs, summaryIDs),
            NSPredicate(format: "elementType == %d AND (identifier == %@ OR label == %@)",
                XCUIElement.ElementType.staticText.rawValue, "Safe local baseline", "Safe local baseline"),
            NSPredicate(format: "elementType == %d AND (identifier == %@ OR label == %@)",
                XCUIElement.ElementType.textField.rawValue, "task144.product.name", "task144.product.name")
        ])
        let businessLabels = ["Products", "Suppliers", "Categories", "Price history", "History sessions", "Last sync", "Local changes waiting"]
        let businessPredicate = NSPredicate(
            format: "elementType == %d AND (identifier IN %@ OR label IN %@)",
            XCUIElement.ElementType.staticText.rawValue, businessLabels, businessLabels)
        // One current global query can prove ALL original absences together.
        // A nonzero result follows the original separate checks/wait unchanged.
        let allForbidden = app.descendants(matching: .any).matching(
            NSCompoundPredicate(orPredicateWithSubpredicates: [hiddenPredicate, businessPredicate]))
        if allForbidden.count == 0 { return }
        let forbiddenSurfaces = app.descendants(matching: .any).matching(hiddenPredicate)
        if forbiddenSurfaces.count != 0 {
            let hidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                forbiddenSurfaces.count == 0
            }, object: nil)
            try scopeRequire(XCTWaiter.wait(for: [hidden], timeout: 5) == .completed,
                stage: stage + "-no-A-summary-diagnostics-row-or-editor", downstream: downstream)
        }
        let forbiddenLabels = app.staticTexts.matching(NSPredicate(
            format: "identifier IN %@ OR label IN %@", businessLabels, businessLabels))
        // A single fresh query covers ALL seven names, including offscreen matches.
        // No geometry pruning, privacy omission or per-viewport timeout reset.
        try scopeRequire(forbiddenLabels.count == 0,
            stage: stage + "-no-business-labels", downstream: downstream)
    }
    private func c3OptionsRewindToTop(_ form: XCUIElement, stage: String, privacy: Bool,
                                     downstream: [String], halfStepFraction: CGFloat = 0.29,
                                     velocity: XCUIGestureVelocity = .slow) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 15
        for ordinal in 0...5 {
            let observation = try c3OptionsViewport(form, stage: stage, ordinal: ordinal,
                deadline: deadline, collectContentAnchors: privacy, downstream: downstream)
            if privacy { try c3NoBusinessInCurrentViewport(stage: stage + "-rewind-\(ordinal)", downstream: downstream) }
            try scopeRequire(ProcessInfo.processInfo.systemUptime < deadline,
                stage: stage + "-traversal-deadline-after-privacy", downstream: downstream)
            // ReturnA has no intervening privacy wait or gesture: use the
            // scrollbar values from this same complete native viewport rather
            // than resolving every scrollbar again. B keeps its live endpoint.
            let atTop = privacy ? c3OptionsEndpoint(form, value: "0%")
                : !observation.scrollValues.isEmpty && observation.scrollValues.allSatisfy { $0 == "0%" }
            if atTop && app.staticTexts["Theme"].isHittable {
                try scopeRequire(ProcessInfo.processInfo.systemUptime < deadline,
                    stage: stage + "-top-deadline-after-native-hit", downstream: downstream)
                return
            }
            try scopeRequire(ordinal < 5 && ProcessInfo.processInfo.systemUptime < deadline,
                stage: stage + "-top-endpoint-NOT_QUALIFIED", downstream: downstream)
            // Return A may traverse 90% of the real viewport per pan; B keeps
            // its original smaller rewind and all measured overlap checks.
            c3OptionsDrag(form, viewport: observation.viewport, applicationOrigin: observation.applicationOrigin, upward: false,
                halfStepFraction: halfStepFraction, velocity: velocity)
        }
    }
    private func c3OptionsReveal(_ target: XCUIElement, form: XCUIElement, stage: String,
                                downstream: [String], velocity: XCUIGestureVelocity = .slow,
                                halfStepFraction: CGFloat = 0.29) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 15
        for ordinal in 0...5 {
            if target.exists && target.isHittable {
                try scopeRequire(ProcessInfo.processInfo.systemUptime < deadline,
                    stage: stage + "-traversal-deadline-at-target", downstream: downstream)
                return
            }
            try scopeRequire(ordinal < 5 && ProcessInfo.processInfo.systemUptime < deadline,
                stage: stage + "-visible-target-NOT_QUALIFIED", downstream: downstream)
            let observation = try c3OptionsViewport(form, stage: stage, ordinal: ordinal,
                deadline: deadline, collectContentAnchors: false, downstream: downstream)
            c3OptionsDrag(form, viewport: observation.viewport, applicationOrigin: observation.applicationOrigin, upward: true,
                halfStepFraction: halfStepFraction, velocity: velocity)
        }
    }
    private func c3OptionsTraverseAdministrativeForm(_ form: XCUIElement) throws {
        let downstream = ["explicit-return-A"]
        try c3OptionsRewindToTop(form, stage: "C3-B-qualified-top", privacy: true, downstream: downstream)
        let deadline = ProcessInfo.processInfo.systemUptime + 15
        var previousAnchors: [String: C3OptionsContentAnchor]?
        var administrativeSurfaceSeen = false
        for ordinal in 0...5 {
            let observation = try c3OptionsViewport(form, stage: "C3-B-top-to-bottom", ordinal: ordinal,
                deadline: deadline, downstream: downstream)
            let anchors = observation.anchors
            try scopeRequire(!anchors.isEmpty,
                stage: "C3-B-content-anchor-identity-NOT_QUALIFIED-\(ordinal)", downstream: downstream)
            if let previousAnchors {
                let hasContentOverlap = anchors.contains { entry in
                    let current = entry.value
                    guard let previous = previousAnchors[entry.key], previous.identity == current.identity else { return false }
                    let displacement = previous.frame.minY - current.frame.minY
                    let sameShape = abs(previous.frame.minX - current.frame.minX) <= 1
                        && abs(previous.frame.width - current.frame.width) <= 1
                        && abs(previous.frame.height - current.frame.height) <= 1
                    let sameViewportBounds = abs(previous.viewport.minX - current.viewport.minX) <= 1
                        && abs(previous.viewport.width - current.viewport.width) <= 1
                        && abs(previous.viewport.maxY - current.viewport.maxY) <= 1
                    // Each viewport already excludes its fresh native occluders.
                    // A collapsing navigation bar may change its top edge.
                    let commonViewport = previous.viewport.intersection(current.viewport)
                    let commonVisibleContent = previous.visibleContent.intersection(current.visibleContent)
                    return sameShape && sameViewportBounds && displacement.isFinite && displacement > 1
                        && !commonViewport.isNull && commonViewport.width > 1 && commonViewport.height > 1
                        && !commonVisibleContent.isNull && commonVisibleContent.width > 1 && commonVisibleContent.height > 1
                }
                try scopeRequire(hasContentOverlap,
                    stage: "C3-B-consecutive-viewports-overlap-\(ordinal)", downstream: downstream)
            }
            try c3NoBusinessInCurrentViewport(stage: "C3-B-viewport-\(ordinal)", downstream: downstream)
            try scopeRequire(ProcessInfo.processInfo.systemUptime < deadline,
                stage: "C3-B-traversal-deadline-after-privacy", downstream: downstream)
            // This anchor already required current live hit and fresh identity/content.
            if anchors["cloud.administrative-text"] != nil { administrativeSurfaceSeen = true }
            // Cloud is now first; Language is the final administrative section.
            let footer = form.staticTexts["Language changes apply immediately."]
            // This viewport's actual native scrollbar values were captured with
            // its geometry. No gesture has intervened. Keep nonempty/all100%,
            // the live footer and the SAME traversal deadline; no offset estimate.
            if !observation.scrollValues.isEmpty && observation.scrollValues.allSatisfy({ $0 == "100%" })
                && footer.exists && footer.isHittable {
                try scopeRequire(ProcessInfo.processInfo.systemUptime < deadline,
                    stage: "C3-B-traversal-deadline-at-bottom", downstream: downstream)
                try scopeRequire(administrativeSurfaceSeen,
                    stage: "C3-administrative-Options-surface", downstream: downstream)
                return
            }
            try scopeRequire(ordinal < 5 && ProcessInfo.processInfo.systemUptime < deadline,
                stage: "C3-B-bottom-endpoint-NOT_QUALIFIED", downstream: downstream)
            previousAnchors = anchors
            // Keep a previously qualified body anchor in the next viewport.
            // The first Cloud-only viewport needs a shorter step; later rows
            // allow a larger native pan. Actual overlap is still mandatory.
            let anchorBottom = anchors.values.map { min($0.frame.maxY, observation.viewport.maxY) }.max()!
            // The initial Cloud viewport exposes only a 39pt Theme sliver.
            // Use the helper's existing 42% pointer overlap for that first pan;
            // later, several body rows support the larger bounded step.
            let distance = min(observation.viewport.height * (ordinal == 0 ? 0.58 : 0.9),
                // The collapsing large title plus measured native overshoot
                // consumed the previous44pt margin and lost all shared pixels.
                max(24, anchorBottom - observation.viewport.minY - 88))
            c3OptionsDrag(form, viewport: observation.viewport, applicationOrigin: observation.applicationOrigin, upward: true,
                halfStepFraction: distance / observation.viewport.height / 2,
                velocity: ordinal == 0 ? .slow : XCUIGestureVelocity(rawValue: 400))
        }
    }

    // TASK145_T18_INSERT_BEGIN configured-native-captures
    private struct T18Stop: Error { let stage: String }

    /// Parameterizes the existing real-root UI paths. This is capture plus scoped
    /// automated checks; native visual judgment, reader speech and physical remain separate.
    private func t18CaptureGroup(language: String, maximumFont: Bool, theme: String, state: String) throws {
        let groupID = "T18_IOS_\(language)_\(maximumFont ? "max" : "normal")_\(theme)_\(state)"
        let routes = ["inventory", "history", "database", "options"]
        let stateIndex = ["idle", "offline", "retrying", "action", "recovery"].firstIndex(of: state)!
        let languageIndex = ["it", "en", "es", "zh"].firstIndex(of: language)!
        let first = stateIndex * 64 + languageIndex * 16 + (maximumFont ? 8 : 0) + (theme == "dark" ? 4 : 0) + 1
        var cells: [[String: Any]] = routes.enumerated().map { offset, route in
            ["id": String(format: "T18-IOS-%03d", first + offset), "route": route, "state": state,
             "status": "NOT_TRAVERSED", "nativeJudgment": "NOT_RUN", "reader": "NOT_RUN", "physical": "NOT_RUN"]
        }
        let expectedInput = "LOCAL-ROOT"
        var currentCell = 0
        var failure: String?
        do {
            // The runner/operator must isolate only this target at the OS level.
            // The request below is not evidence: actual NWPath and production denial gate every capture.
            let titles = t18TabTitles(language)
            let locale = ["en": "en_US", "it": "it_IT", "es": "es_ES", "zh": "zh_CN"][language]!
            let category: UIContentSizeCategory = maximumFont ? .accessibilityExtraExtraExtraLarge : .large
            app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale,
                "-appLanguage", language, "-appTheme", theme,
                "-UIPreferredContentSizeCategoryName", category.rawValue]
            app.launchEnvironment = ["TASK144_LOCAL_AVAILABILITY_FIXTURE": runID,
                "TASK145_T18_OBSERVATION": "1", "TASK131_INITIAL_TAB": "database"]
            if state == "offline" { app.launchEnvironment["TASK146_T18_OS_OFFLINE"] = "1" }
            if state == "idle" { app.launchEnvironment["TASK145_SCOPE_INCREMENTAL_UI"] = "healthy-incremental" }
            if state == "action" { app.launchEnvironment["TASK145_SCOPE_INCREMENTAL_UI"] = "membership-refusal" }
            if state == "retrying" { app.launchEnvironment["TASK145_RETRY_UI"] = "mixed-real-cooldown" }
            app.launch()
            switch state {
            case "idle": try t18Await("task145.seq6.automatic-terminal", timeout: 45)
            case "offline":
                try t18AwaitOSOffline(language: language, category: category, theme: theme)
                let persisted = try t18Snapshot(state: state, language: language, category: category, theme: theme)
                app.terminate()
                app.launch() // Same fixture namespace and file-backed generation, new process.
                try t18AwaitOSOffline(language: language, category: category, theme: theme)
                let reopened = try t18Snapshot(state: state, language: language, category: category, theme: theme)
                try t18Require(persisted["pid"] as? Int != reopened["pid"] as? Int
                    && persisted["generation"] as? String == reopened["generation"] as? String
                    && persisted["manifestShop"] as? String == reopened["manifestShop"] as? String
                    && persisted["accountHash"] as? String == reopened["accountHash"] as? String
                    && persisted["osOfflineBody"] as? [String: String] == reopened["osOfflineBody"] as? [String: String],
                    "offline-restart-did-not-preserve-qualified-body-and-scope")
            case "recovery": try t18Await("task144.controlled.held", timeout: 30)
            case "retrying": try t18Await("task145.retry.cooldown-after-three", timeout: 45)
            case "action":
                // Marker and native input admission share the original 30-second window.
                let releaseDeadline = ProcessInfo.processInfo.systemUptime + 30
                try t18Await("task145.seq6.ready", timeout: max(0, releaseDeadline - ProcessInfo.processInfo.systemUptime))
                let release = app.buttons.matching(NSPredicate(format: "identifier == %@", "task144.controlled.release")).element(boundBy: 0)
                let releaseReady = try controlledReleaseInputIsReady(release,
                    identifier: "task144.controlled.release", stage: groupID + "-release-admission",
                    deadline: releaseDeadline)
                try t18Require(releaseReady && ProcessInfo.processInfo.systemUptime < releaseDeadline,
                    "release-input-not-qualified-within-ready-window")
                // The fixture still requires one full second of recognized
                // pressing. Keep margin for native delivery of this one gesture.
                release.press(forDuration: 1.5)
                do {
                    try t18Await("task145.seq6.safety-terminal", timeout: 30)
                } catch {
                    if app.state == .runningForeground {
                        _ = try? seq6Ledger("T18 " + groupID + " FIRST_FAIL missing safety-terminal", diagnosticOnly: true)
                    }
                    throw error
                }
                try t18DismissExpectedDecision(language)
            default: throw T18Stop(stage: "unsupported-state")
            }
            let initial = try t18Snapshot(state: state, language: language, category: category, theme: theme)
            for (index, route) in routes.enumerated() {
                currentCell = index
                if route == "options" && state != "action" && app.keyboards.count > 0 {
                    let search = app.textFields.matching(identifier: "task140.database.root").firstMatch
                    try t18Require(search.value as? String == "LOCAL-ROOT" && search.isHittable,
                        "database-search-before-keyboard-dismissal")
                    search.typeText("\n")
                    let keyboardHidden = XCTNSPredicateExpectation(
                        predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
                    try t18Require(XCTWaiter.wait(for: [keyboardHidden], timeout: 5) == .completed,
                        "database-keyboard-not-dismissed-before-options")
                }
                let tab = app.tabBars.buttons[titles[index]]
                try t18Require(tab.waitForExistence(timeout: 5) && tab.isHittable, route + "-tab-not-reachable")
                tab.tap()
                // Keyboard dismissal may rebuild the bar. Read the selected state
                // from the current exact-label row rather than the pre-tap element.
                let selected = app.tabBars.buttons.matching(NSPredicate(format: "label == %@", titles[index]))
                    .element(boundBy: 0)
                let selectedPublication = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "isSelected == true"), object: selected)
                try t18Require(XCTWaiter.wait(for: [selectedPublication], timeout: 5) == .completed,
                    route + "-tab-not-selected")
                try t18Require(app.alerts.count == 0, route + "-unexpected-modal")
                if route == "options" {
                    if state == "action" { try t18ExerciseReview(language) }
                    else { try t18ReachAccount(language) }
                }
                if state == "action" {
                    try t18Require(!app.staticTexts["Safe local baseline"].exists
                        && !app.textFields["task144.product.name"].exists, route + "-denied-business-exposed")
                }
                // Actual keyboard input through the ordinary search control; no Save/mutation.
                if route == "database" && state != "action" {
                    let search = app.textFields.matching(identifier: "task140.database.root").firstMatch
                    try t18Require(search.waitForExistence(timeout: 5) && search.isHittable, "database-search-not-reachable")
                    search.tap()
                    // One public native insertion per character, for every language.
                    // This changes delivery duration, not the post-input value budget.
                    var nativeTypeTextCalls = 0
                    for character in expectedInput {
                        search.typeText(String(character))
                        nativeTypeTextCalls += 1
                    }
                    let inputDeadline = ProcessInfo.processInfo.systemUptime + 5
                    cells[index]["nativeInputDelivery"] = ["driver": "public-typeText-per-character",
                        "expectedCharacterCount": expectedInput.count,
                        "expectedUTF16Count": expectedInput.utf16.count,
                        "returnedNativeTypeTextCalls": nativeTypeTextCalls]
                    let inputPredicate = NSPredicate { _, _ in
                        guard ProcessInfo.processInfo.systemUptime < inputDeadline else { return false }
                        let complete = search.value as? String == expectedInput
                        return complete && ProcessInfo.processInfo.systemUptime <= inputDeadline
                    }
                    let inputImmediatelyPublished = inputPredicate.evaluate(with: nil)
                    let inputRemaining = inputDeadline - ProcessInfo.processInfo.systemUptime
                    let inputPublished = inputImmediatelyPublished || (inputRemaining > 0
                        && XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: inputPredicate, object: nil)],
                            timeout: inputRemaining) == .completed)
                    try t18Require(inputPublished && ProcessInfo.processInfo.systemUptime <= inputDeadline,
                        "database-keyboard-input-not-retained")
                }
                let before = try t18Snapshot(state: state, language: language, category: category, theme: theme)
                if route == "database" && state != "action" {
                    let nativeInput = before["nativeSearchInput"] as? [String: Any] ?? [:]
                    cells[index]["nativeInputBefore"] = nativeInput
                    try t18Require(nativeInput["status"] as? String == "UNIQUE_FOCUSED_UI_TEXT_FIELD"
                        && nativeInput["hierarchyComplete"] as? Bool == true
                        && nativeInput["focusedTextFieldCount"] as? Int == 1
                        && nativeInput["pid"] as? Int == before["pid"] as? Int
                        && nativeInput["textUTF16Count"] as? Int == expectedInput.utf16.count
                        && nativeInput["exactExpected"] as? Bool == true,
                        "database-native-input-not-exact-or-focused")
                }
                if route == "options" && maximumFont {
                    try t18Require(before["optionsSwiftUIAccessibility5"] as? Bool == true,
                        "actual-Options-SwiftUI-accessibility5-not-observed")
                }
                try t18Require(before["generation"] as? String == initial["generation"] as? String,
                    route + "-generation-changed-before-capture")
                let bounds = app.windows.firstMatch.frame
                try t18Require(bounds.width > 0 && bounds.height > 0 && tab.frame.minX >= bounds.minX
                    && tab.frame.maxX <= bounds.maxX && tab.frame.maxY <= bounds.maxY,
                    route + "-tab-outside-native-window")
                let banners = app.descendants(matching: .any).matching(identifier: "sync.root.foreground.banner")
                try t18Require(banners.count <= 1 && (route != "options" || banners.count == 0),
                    route + "-duplicate-or-Options-root-banner")
                let id = cells[index]["id"] as! String
                let screenshotName = groupID + " " + id + " screenshot"
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = screenshotName; screenshot.lifetime = .keepAlways; add(screenshot)
                let axName = groupID + " " + id + " AX"
                let ax = XCTAttachment(string: app.debugDescription)
                ax.name = axName; ax.lifetime = .keepAlways; add(ax)
                let after = try t18Snapshot(state: state, language: language, category: category, theme: theme)
                try t18Require((after["uptime"] as? Double ?? 0) > (before["uptime"] as? Double ?? .infinity)
                    && after["generation"] as? String == before["generation"] as? String
                    && after["manifestShop"] as? String == before["manifestShop"] as? String
                    && after["accountHash"] as? String == before["accountHash"] as? String,
                    route + "-capture-not-bracketed-by-current-same-scope-reads")
                if state == "offline" {
                    try t18Require(after["osPathSequence"] as? Int == before["osPathSequence"] as? Int
                        && before["osPathSequence"] as? Int == initial["osPathSequence"] as? Int
                        && after["osOfflineBody"] as? [String: String] == initial["osOfflineBody"] as? [String: String],
                        route + "-OS-path-or-persisted-body-changed-during-offline-capture")
                }
                cells[index]["status"] = "CAPTURED_AUTOMATED_PENDING_NATIVE_REVIEW"
                cells[index]["before"] = before; cells[index]["after"] = after
                cells[index]["screenshotAttachment"] = screenshotName; cells[index]["axAttachment"] = axName
                cells[index]["keyboardCount"] = app.keyboards.count
                cells[index]["lastRowHitTargetLabelJudgment"] = "PENDING_NATIVE_REVIEW"
            }
            try t18EmitResult(groupID: groupID, failure: nil, cells: cells)
        } catch {
            failure = (error as? T18Stop)?.stage ?? "unclassified-test-read-failure"
            cells[currentCell]["status"] = "FAIL"
            cells[currentCell]["failure"] = failure ?? "unknown"
            // Persist/print the primary failure before optional capture or XCTest can stop this method.
            do { try t18EmitResult(groupID: groupID, failure: failure, cells: cells) }
            catch { print("TASK145_T18_RESULT_ENCODING_FAILURE " + groupID) }
            if app.state != .notRunning {
                if failure == "database-keyboard-input-not-retained" {
                    // The original FAIL is already persisted. Read this existing
                    // native getter directly; hierarchy snapshots may truncate it.
                    let native = app.otherElements.matching(NSPredicate(format: "identifier == %@",
                        "task144.controlled.native-name-observation")).element
                    if let raw = native.value as? String, raw.utf8.count <= 8192 {
                        let input = XCTAttachment(string: raw)
                        input.name = "T18 FIRST_FAIL native input " + groupID
                        input.lifetime = .keepAlways; add(input)
                    }
                }
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "T18 FIRST_FAIL " + groupID; screenshot.lifetime = .keepAlways; add(screenshot)
                let ax = XCTAttachment(string: app.debugDescription)
                ax.name = "T18 FIRST_FAIL AX " + groupID; ax.lifetime = .keepAlways; add(ax)
            }
            XCTFail("T18 \(groupID): \(failure!); dependent cells NOT_TRAVERSED")
        }
    }

    private func t18EmitResult(groupID: String, failure: String?, cells: [[String: Any]]) throws {
        let result: [String: Any] = ["schema": 1, "groupID": groupID, "runID": runID,
            "status": failure == nil ? "CAPTURED_AUTOMATED_PENDING_NATIVE_REVIEW" : "FAIL",
            "failure": failure ?? "none", "cells": cells]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        let item = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        item.name = "TASK145_T18_RESULT " + groupID; item.lifetime = .keepAlways; add(item)
        print("TASK145_T18_RESULT " + String(decoding: data, as: UTF8.self))
    }

    private func t18Require(_ condition: Bool, _ stage: String) throws {
        if !condition { throw T18Stop(stage: stage) }
    }
    private func t18Await(_ marker: String, timeout: TimeInterval) throws {
        try t18Require(app.staticTexts[marker].waitForExistence(timeout: timeout), "producer-boundary-not-traversed-" + marker)
    }
    private func t18AwaitOSOffline(language: String, category: UIContentSizeCategory, theme: String) throws {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { [weak self] _, _ in
            guard let self else { return false }
            return (try? self.t18Snapshot(state: "offline", language: language, category: category, theme: theme)) != nil
        }, object: nil)
        try t18Require(XCTWaiter.wait(for: [ready], timeout: 30) == .completed,
            "offline-actual-OS-path-or-production-network-denial-NOT_QUALIFIED")
    }

    private func t18Snapshot(state: String, language: String, category: UIContentSizeCategory, theme: String) throws -> [String: Any] {
        let readDeadline = ProcessInfo.processInfo.systemUptime + 5
        let node = app.otherElements.matching(NSPredicate(format: "identifier == %@",
            "task144.controlled.native-name-observation")).element
        try t18Require(node.exists || node.waitForExistence(
            timeout: max(0, readDeadline - ProcessInfo.processInfo.systemUptime)), "passive-observer-missing")
        guard let raw = node.value as? String, var bytes = raw.data(using: .utf8), bytes.count <= 8192,
              var value = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
            throw T18Stop(stage: "passive-observer-invalid-JSON")
        }
        func isHealthyIdle(_ current: [String: Any]) -> Bool {
            current["healthyTerminal"] as? Bool == true && current["phase"] as? String == "idle"
                && current["automaticWorkActive"] as? Bool == false && current["journalPresent"] as? Bool == false
        }
        if state == "idle" && !isHealthyIdle(value) {
            // The producer marker is durable/latched; a normal subsequent poll
            // may already be active. Admit only an actual current idle read in
            // the existing five-second observer budget, without pausing work.
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard ProcessInfo.processInfo.systemUptime < readDeadline,
                      let nextRaw = node.value as? String, let nextBytes = nextRaw.data(using: .utf8), nextBytes.count <= 8192,
                      let next = (try? JSONSerialization.jsonObject(with: nextBytes)) as? [String: Any] else { return false }
                bytes = nextBytes; value = next
                return isHealthyIdle(next) && ProcessInfo.processInfo.systemUptime <= readDeadline
            }, object: nil)
            let remaining = readDeadline - ProcessInfo.processInfo.systemUptime
            let current = remaining > 0 && XCTWaiter.wait(for: [ready], timeout: remaining) == .completed
                && ProcessInfo.processInfo.systemUptime <= readDeadline
            if !current {
                let last = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
                last.name = "T18 idle LAST_READ before healthy-idle-not-current"; last.lifetime = .keepAlways; add(last)
                throw T18Stop(stage: "healthy-idle-not-current")
            }
        }
        try t18Require(value["status"] as? String == "CURRENT_READ_ONLY"
            && (value["runID"] as? String)?.lowercased() == runID.lowercased()
            && value["fixtureFailure"] as? Bool == false && value["bodyProof"] as? Bool == true
            && value["scopeMatchesFixture"] as? Bool == true
            && value["sessionSignedIn"] as? Bool == true && value["sessionOwnerMatches"] as? Bool == true,
            "current-root-proof-or-scope-unqualified")
        try t18Require(value["fontCategory"] as? String == category.rawValue
            && value["theme"] as? String == theme && value["appLanguage"] as? String == language,
            "actual-font-theme-language-mismatch")
        switch state {
        case "idle":
            try t18Require(isHealthyIdle(value), "healthy-idle-not-current")
        case "offline":
            guard let observed = value["osPathObservedUptime"] as? Double,
                  let uptime = value["uptime"] as? Double,
                  let sequence = value["osPathSequence"] as? Int,
                  let body = value["osOfflineBody"] as? [String: String] else {
                throw T18Stop(stage: "offline-OS-or-local-body-observation-missing")
            }
            try t18Require(value["osPathSource"] as? String == "production-NWPathMonitor"
                && value["osPathUnsatisfied"] as? Bool == true && sequence > 0 && observed > 0 && observed <= uptime
                && value["phase"] as? String == "blocked" && value["phaseBlockReason"] as? String == "networkUnavailable"
                && value["outcome"] as? String == "blocked" && value["blockReason"] as? String == "networkUnavailable"
                && value["automaticWorkActive"] as? Bool == false && value["journalPresent"] as? Bool == false
                && body["name"] == "Safe local baseline" && body["products"] == "1"
                && body["pending"] == "0" && body["outbox"] == "" && body["watermark"] == "41"
                && body["body-proof"] == "true" && body["local-access"] == "true",
                "offline-actual-OS-path-production-denial-or-persisted-body-unqualified")
        case "recovery":
            do {
                try t18Require(value["heldPage"] as? Bool == true && value["journalPresent"] as? Bool == true
                    && value["automaticWorkActive"] as? Bool == true
                    && ["checking", "reconciling"].contains(value["phase"] as? String ?? "missing"),
                    "actual-held-recovery-not-current")
            } catch {
                t18RecordRecoveryFailure(value, language: language, category: category, theme: theme)
                throw error
            }
        case "retrying":
            guard let deadline = value["retryDeadlineUTC"] as? Double,
                  let completed = value["retryCompletedUTC"] as? Double,
                  let observedUTC = value["utc"] as? Double else { throw T18Stop(stage: "retry-budget-read-missing") }
            try t18Require(value["automaticWorkActive"] as? Bool == false && value["journalPresent"] as? Bool == true
                && value["retryTotalAttempts"] as? Int == 3 && value["retryWindowAttempts"] as? Int == 3
                && value["retryWindowIndex"] as? Int == 1 && value["retryEntries"] as? Int == 3
                && value["retryCompletions"] as? Int == 3 && deadline >= completed + 300 && deadline > observedUTC,
                "real-retry-cooldown-expired-or-unqualified")
        case "action":
            try t18Require(value["membershipRefused"] as? Bool == true && value["membershipTerminal"] as? Bool == true
                && value["syncAllowed"] as? Bool == false && value["selectedShop"] as? String == "none"
                && value["localAccess"] as? Bool == false && value["journalPresent"] as? Bool == false,
                "real-membership-action-denial-not-current")
        default: throw T18Stop(stage: "unsupported-state")
        }
        if state != "action" {
            try t18Require(value["localAccess"] as? Bool == true && value["syncAllowed"] as? Bool == true
                && value["selectedShop"] as? String == value["manifestShop"] as? String,
                "qualified-local-access-missing")
        }
        return value
    }
    /// Records only scalar fields from the same passive value used by the failed oracle.
    private func t18RecordRecoveryFailure(_ value: [String: Any], language: String,
                                          category: UIContentSizeCategory, theme: String) {
        var observed: [String: Any] = [:]
        for key in ["heldPage", "journalPresent", "automaticWorkActive", "bodyProof", "fixtureFailure",
                    "scopeMatchesFixture", "sessionSignedIn", "sessionOwnerMatches", "localAccess", "syncAllowed"] {
            if let flag = value[key] as? Bool { observed[key] = flag }
            else { observed[key] = "UNKNOWN" }
        }
        for key in ["phase", "status", "runID", "generation", "accountHash", "manifestShop", "selectedShop",
                    "journalPhase", "theme", "appLanguage", "fontCategory", "observerFontCategory", "backendScope"] {
            if let text = value[key] as? String { observed[key] = text }
            else { observed[key] = "UNKNOWN" }
        }
        for key in ["pid", "schema", "expectedEpoch", "epoch", "storeEpoch"] {
            if let number = value[key] as? Int { observed[key] = number }
            else if let text = value[key] as? String { observed[key] = text }
            else { observed[key] = "UNKNOWN" }
        }
        for key in ["utc", "uptime"] {
            if let number = value[key] as? Double { observed[key] = number }
            else { observed[key] = "UNKNOWN" }
        }
        let record: [String: Any] = ["schema": 1, "testName": name,
            "stage": "actual-held-recovery-not-current", "expectedFixtureRunID": runID,
            "source": "same-already-read-passive-observer-value", "observed": observed,
            "expectedLanguage": language, "expectedTheme": theme, "expectedFontCategory": category.rawValue,
            "expectedPhaseMembership": ["checking", "reconciling"], "originalOracleSatisfied": false]
        guard let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) else {
            print("TASK146_T18_RECOVERY_FAILURE_WITNESS_ENCODING_FAILURE " + runID)
            return
        }
        let item = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        item.name = "TASK146_T18_RECOVERY_FAILURE_WITNESS_V1 " + runID
        item.lifetime = .keepAlways
        add(item)
        print("TASK146_T18_RECOVERY_FAILURE_WITNESS_V1 " + String(decoding: data, as: UTF8.self))
    }

    private func t18TabTitles(_ language: String) -> [String] {
        ["en": ["Inventory", "History", "Database", "Options"],
         "it": ["Inventario", "Cronologia", "Database", "Opzioni"],
         "es": ["Inventario", "Historial", "Base de datos", "Opciones"],
         "zh": ["库存", "历史", "数据库", "选项"]][language]!
    }
    private func t18Seek(_ element: XCUIElement, stage: String, requiresFullVisibility: Bool = false) throws {
        var observations: [String] = []
        defer {
            let evidence = XCTAttachment(string: observations.joined(separator: "\n"))
            evidence.name = "T18 bounded native seek geometry " + stage
            evidence.lifetime = .keepAlways; add(evidence)
        }
        let fullyVisible = {
            let captureStarted = ProcessInfo.processInfo.systemUptime
            guard element.exists else { return false }
            let frame = element.frame, window = self.app.frame
            guard [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy({ $0.isFinite }),
                  frame.width > 0 && frame.height > 0 else { return false }
            // Qualify geometry before asking XCTest for a live activation point;
            // the SDK can fail that query for a clipped composite account label.
            if !requiresFullVisibility { return window.intersects(frame) && element.isHittable }
            let top = max(window.minY, self.app.navigationBars.firstMatch.frame.maxY)
            let bottom = min(window.maxY, self.app.tabBars.firstMatch.frame.minY)
            let geometry = window.contains(frame) && frame.minY >= top && frame.maxY <= bottom
            let hit = geometry ? element.isHittable : false
            if observations.count < 24 {
                observations.append("capture-start=\(captureStarted); capture-end=\(ProcessInfo.processInfo.systemUptime); target=\(frame); window=\(window); top=\(top); bottom=\(bottom); geometry=\(geometry); hit-queried=\(geometry); hittable=\(hit)")
            }
            return geometry && hit
        }
        for gesture in 0..<8 {
            if fullyVisible() { return }
            let window = app.frame
            let top = max(window.minY, app.navigationBars.firstMatch.frame.maxY) + 8
            let bottom = min(window.maxY, app.tabBars.firstMatch.frame.minY) - 8
            try t18Require(bottom > top, stage)
            var movement: CGFloat = -160
            if element.exists {
                // A full-screen swipe can carry the row past the navigation
                // bar. Reveal it in either direction through bounded gestures.
                let frame = element.frame
                if [frame.minY, frame.maxY].allSatisfy({ $0.isFinite }), frame.height > 0 {
                    // A held max-font Cloud card can be more than four screens
                    // below the top. Spend each of the same eight gestures on
                    // the measured viewport, leaving both endpoints inside it.
                    let pageDistance = (bottom - top) * 0.90
                    if frame.minY > bottom {
                        movement = -min(pageDistance, max(24, frame.maxY - bottom))
                    } else if frame.maxY < top {
                        movement = min(pageDistance, max(24, top - frame.minY))
                    } else if requiresFullVisibility, frame.height <= bottom - top {
                        // Correct the clipped edge. Centering plus the old44pt
                        // minimum oscillated across the narrow max-font fit.
                        // Keep24pt of real movement: observed8-13pt drags did
                        // not begin scrolling a clipped Review button.
                        // Native drag recognition consumed 10-14pt in the
                        // failed seek. Land inside the available slack rather
                        // than exactly on the clipped edge; retain the existing
                        // 24pt minimum and avoid overshooting a nearly full row.
                        let inset = min(24, max(0, (bottom - top - frame.height) / 2))
                        if frame.maxY > bottom { movement = -min(pageDistance, max(24, frame.maxY - bottom + inset)) }
                        else if frame.minY < top { movement = min(pageDistance, max(24, top - frame.minY + inset)) }
                        else { movement = 0 }
                    } else {
                        movement = max(-160, min(160, (top + bottom) / 2 - frame.midY))
                        if abs(movement) < 44 { movement = movement < 0 ? -44 : 44 }
                    }
                }
            }
            // Both ends stay inside the measured viewport, including the
            // longer page used only for a wholly offscreen target.
            let maximumTravel = (bottom - top) * 0.90
            movement = max(-maximumTravel, min(maximumTravel, movement))
            let startY = (top + bottom) / 2 - movement / 2
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
                .withOffset(CGVector(dx: 0, dy: startY))
            if observations.count < 24 {
                observations.append("gesture=\(gesture); requested-dy=\(movement); viewport-top=\(top); viewport-bottom=\(bottom); midpoint=\((top + bottom) / 2)")
            }
            start.press(forDuration: 0.05,
                        thenDragTo: start.withOffset(CGVector(dx: 0, dy: movement)),
                        withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        try t18Require(fullyVisible(), stage)
    }
    private func t18ReachAccount(_ language: String) throws {
        let heading = ["en": "Cloud account connected", "it": "Account cloud collegato",
            "es": "Cuenta cloud conectada", "zh": "云账号已连接"][language]!
        let element = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
            heading, "l***@long-account-domain.example.invalid")).firstMatch
        try t18Seek(element, stage: "actual-account-card-not-reachable", requiresFullVisibility: true)
        let bounds = app.windows.firstMatch.frame
        try t18Require(element.frame.minX >= bounds.minX && element.frame.maxX <= bounds.maxX,
            "actual-account-card-outside-width")
    }
    private func t18DismissExpectedDecision(_ language: String) throws {
        guard app.alerts.count > 0 else { return }
        let keep = app.alerts.buttons[t18DecisionLabels(language)[1]]
        try t18Require(keep.exists && keep.isHittable, "unexpected-modal-in-action-producer")
        keep.tap()
    }
    private func t18ExerciseReview(_ language: String) throws {
        let labels = t18DecisionLabels(language)
        try t18DismissExpectedDecision(language)
        let review = app.buttons[labels[0]]
        try t18Seek(review, stage: "ordinary-review-action-not-reachable", requiresFullVisibility: true)
        review.tap()
        let keep = app.alerts.buttons[labels[1]], replace = app.alerts.buttons[labels[2]]
        try t18Require(keep.waitForExistence(timeout: 5) && keep.isHittable && replace.exists && !replace.isEnabled,
            "ordinary-review-dialog-does-not-preserve-denial")
        keep.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate { [weak self] _, _ in self?.app.alerts.count == 0 }, object: nil)
        try t18Require(XCTWaiter.wait(for: [closed], timeout: 5) == .completed, "keep-local-did-not-return-to-shell")
        try t18Require(review.exists && review.isHittable, "review-not-retained-after-keep-local")
    }
    private func t18DecisionLabels(_ language: String) -> [String] {
        [
            "en": ["Review", "Keep local data", "Replace with cloud data"],
            "it": ["Rivedi", "Mantieni dati locali", "Sostituisci con dati cloud"],
            "es": ["Revisar", "Conservar datos locales", "Sustituir con datos de la nube"],
            "zh": ["检查", "保留本地数据", "替换为云端数据"]
        ][language]!
    }
    func testT18_it_normal_light_idle() throws { try t18CaptureGroup(language: "it", maximumFont: false, theme: "light", state: "idle") }
    func testT18_it_normal_light_recovery() throws { try t18CaptureGroup(language: "it", maximumFont: false, theme: "light", state: "recovery") }
    func testT18_it_normal_light_retrying() throws { try t18CaptureGroup(language: "it", maximumFont: false, theme: "light", state: "retrying") }
    func testT18_it_normal_light_action() throws { try t18CaptureGroup(language: "it", maximumFont: false, theme: "light", state: "action") }
    func testT18_it_normal_light_offline() throws { try t18CaptureGroup(language: "it", maximumFont: false, theme: "light", state: "offline") }
    func testT18_it_normal_dark_idle() throws { try t18CaptureGroup(language: "it", maximumFont: false, theme: "dark", state: "idle") }
    func testT18_it_normal_dark_recovery() throws { try t18CaptureGroup(language: "it", maximumFont: false, theme: "dark", state: "recovery") }
    func testT18_it_normal_dark_retrying() throws { try t18CaptureGroup(language: "it", maximumFont: false, theme: "dark", state: "retrying") }
    func testT18_it_normal_dark_action() throws { try t18CaptureGroup(language: "it", maximumFont: false, theme: "dark", state: "action") }
    func testT18_it_normal_dark_offline() throws { try t18CaptureGroup(language: "it", maximumFont: false, theme: "dark", state: "offline") }
    func testT18_it_max_light_idle() throws { try t18CaptureGroup(language: "it", maximumFont: true, theme: "light", state: "idle") }
    func testT18_it_max_light_recovery() throws { try t18CaptureGroup(language: "it", maximumFont: true, theme: "light", state: "recovery") }
    func testT18_it_max_light_retrying() throws { try t18CaptureGroup(language: "it", maximumFont: true, theme: "light", state: "retrying") }
    func testT18_it_max_light_action() throws { try t18CaptureGroup(language: "it", maximumFont: true, theme: "light", state: "action") }
    func testT18_it_max_light_offline() throws { try t18CaptureGroup(language: "it", maximumFont: true, theme: "light", state: "offline") }
    func testT18_it_max_dark_idle() throws { try t18CaptureGroup(language: "it", maximumFont: true, theme: "dark", state: "idle") }
    func testT18_it_max_dark_recovery() throws { try t18CaptureGroup(language: "it", maximumFont: true, theme: "dark", state: "recovery") }
    func testT18_it_max_dark_retrying() throws { try t18CaptureGroup(language: "it", maximumFont: true, theme: "dark", state: "retrying") }
    func testT18_it_max_dark_action() throws { try t18CaptureGroup(language: "it", maximumFont: true, theme: "dark", state: "action") }
    func testT18_it_max_dark_offline() throws { try t18CaptureGroup(language: "it", maximumFont: true, theme: "dark", state: "offline") }
    func testT18_en_normal_light_idle() throws { try t18CaptureGroup(language: "en", maximumFont: false, theme: "light", state: "idle") }
    func testT18_en_normal_light_recovery() throws { try t18CaptureGroup(language: "en", maximumFont: false, theme: "light", state: "recovery") }
    func testT18_en_normal_light_retrying() throws { try t18CaptureGroup(language: "en", maximumFont: false, theme: "light", state: "retrying") }
    func testT18_en_normal_light_action() throws { try t18CaptureGroup(language: "en", maximumFont: false, theme: "light", state: "action") }
    func testT18_en_normal_light_offline() throws { try t18CaptureGroup(language: "en", maximumFont: false, theme: "light", state: "offline") }
    func testT18_en_normal_dark_idle() throws { try t18CaptureGroup(language: "en", maximumFont: false, theme: "dark", state: "idle") }
    func testT18_en_normal_dark_recovery() throws { try t18CaptureGroup(language: "en", maximumFont: false, theme: "dark", state: "recovery") }
    func testT18_en_normal_dark_retrying() throws { try t18CaptureGroup(language: "en", maximumFont: false, theme: "dark", state: "retrying") }
    func testT18_en_normal_dark_action() throws { try t18CaptureGroup(language: "en", maximumFont: false, theme: "dark", state: "action") }
    func testT18_en_normal_dark_offline() throws { try t18CaptureGroup(language: "en", maximumFont: false, theme: "dark", state: "offline") }
    func testT18_en_max_light_idle() throws { try t18CaptureGroup(language: "en", maximumFont: true, theme: "light", state: "idle") }
    func testT18_en_max_light_recovery() throws { try t18CaptureGroup(language: "en", maximumFont: true, theme: "light", state: "recovery") }
    func testT18_en_max_light_retrying() throws { try t18CaptureGroup(language: "en", maximumFont: true, theme: "light", state: "retrying") }
    func testT18_en_max_light_action() throws { try t18CaptureGroup(language: "en", maximumFont: true, theme: "light", state: "action") }
    func testT18_en_max_light_offline() throws { try t18CaptureGroup(language: "en", maximumFont: true, theme: "light", state: "offline") }
    func testT18_en_max_dark_idle() throws { try t18CaptureGroup(language: "en", maximumFont: true, theme: "dark", state: "idle") }
    func testT18_en_max_dark_recovery() throws { try t18CaptureGroup(language: "en", maximumFont: true, theme: "dark", state: "recovery") }
    func testT18_en_max_dark_retrying() throws { try t18CaptureGroup(language: "en", maximumFont: true, theme: "dark", state: "retrying") }
    func testT18_en_max_dark_action() throws { try t18CaptureGroup(language: "en", maximumFont: true, theme: "dark", state: "action") }
    func testT18_en_max_dark_offline() throws { try t18CaptureGroup(language: "en", maximumFont: true, theme: "dark", state: "offline") }
    func testT18_es_normal_light_idle() throws { try t18CaptureGroup(language: "es", maximumFont: false, theme: "light", state: "idle") }
    func testT18_es_normal_light_recovery() throws { try t18CaptureGroup(language: "es", maximumFont: false, theme: "light", state: "recovery") }
    func testT18_es_normal_light_retrying() throws { try t18CaptureGroup(language: "es", maximumFont: false, theme: "light", state: "retrying") }
    func testT18_es_normal_light_action() throws { try t18CaptureGroup(language: "es", maximumFont: false, theme: "light", state: "action") }
    func testT18_es_normal_light_offline() throws { try t18CaptureGroup(language: "es", maximumFont: false, theme: "light", state: "offline") }
    func testT18_es_normal_dark_idle() throws { try t18CaptureGroup(language: "es", maximumFont: false, theme: "dark", state: "idle") }
    func testT18_es_normal_dark_recovery() throws { try t18CaptureGroup(language: "es", maximumFont: false, theme: "dark", state: "recovery") }
    func testT18_es_normal_dark_retrying() throws { try t18CaptureGroup(language: "es", maximumFont: false, theme: "dark", state: "retrying") }
    func testT18_es_normal_dark_action() throws { try t18CaptureGroup(language: "es", maximumFont: false, theme: "dark", state: "action") }
    func testT18_es_normal_dark_offline() throws { try t18CaptureGroup(language: "es", maximumFont: false, theme: "dark", state: "offline") }
    func testT18_es_max_light_idle() throws { try t18CaptureGroup(language: "es", maximumFont: true, theme: "light", state: "idle") }
    func testT18_es_max_light_recovery() throws { try t18CaptureGroup(language: "es", maximumFont: true, theme: "light", state: "recovery") }
    func testT18_es_max_light_retrying() throws { try t18CaptureGroup(language: "es", maximumFont: true, theme: "light", state: "retrying") }
    func testT18_es_max_light_action() throws { try t18CaptureGroup(language: "es", maximumFont: true, theme: "light", state: "action") }
    func testT18_es_max_light_offline() throws { try t18CaptureGroup(language: "es", maximumFont: true, theme: "light", state: "offline") }
    func testT18_es_max_dark_idle() throws { try t18CaptureGroup(language: "es", maximumFont: true, theme: "dark", state: "idle") }
    func testT18_es_max_dark_recovery() throws { try t18CaptureGroup(language: "es", maximumFont: true, theme: "dark", state: "recovery") }
    func testT18_es_max_dark_retrying() throws { try t18CaptureGroup(language: "es", maximumFont: true, theme: "dark", state: "retrying") }
    func testT18_es_max_dark_action() throws { try t18CaptureGroup(language: "es", maximumFont: true, theme: "dark", state: "action") }
    func testT18_es_max_dark_offline() throws { try t18CaptureGroup(language: "es", maximumFont: true, theme: "dark", state: "offline") }
    func testT18_zh_normal_light_idle() throws { try t18CaptureGroup(language: "zh", maximumFont: false, theme: "light", state: "idle") }
    func testT18_zh_normal_light_recovery() throws { try t18CaptureGroup(language: "zh", maximumFont: false, theme: "light", state: "recovery") }
    func testT18_zh_normal_light_retrying() throws { try t18CaptureGroup(language: "zh", maximumFont: false, theme: "light", state: "retrying") }
    func testT18_zh_normal_light_action() throws { try t18CaptureGroup(language: "zh", maximumFont: false, theme: "light", state: "action") }
    func testT18_zh_normal_light_offline() throws { try t18CaptureGroup(language: "zh", maximumFont: false, theme: "light", state: "offline") }
    func testT18_zh_normal_dark_idle() throws { try t18CaptureGroup(language: "zh", maximumFont: false, theme: "dark", state: "idle") }
    func testT18_zh_normal_dark_recovery() throws { try t18CaptureGroup(language: "zh", maximumFont: false, theme: "dark", state: "recovery") }
    func testT18_zh_normal_dark_retrying() throws { try t18CaptureGroup(language: "zh", maximumFont: false, theme: "dark", state: "retrying") }
    func testT18_zh_normal_dark_action() throws { try t18CaptureGroup(language: "zh", maximumFont: false, theme: "dark", state: "action") }
    func testT18_zh_normal_dark_offline() throws { try t18CaptureGroup(language: "zh", maximumFont: false, theme: "dark", state: "offline") }
    func testT18_zh_max_light_idle() throws { try t18CaptureGroup(language: "zh", maximumFont: true, theme: "light", state: "idle") }
    func testT18_zh_max_light_recovery() throws { try t18CaptureGroup(language: "zh", maximumFont: true, theme: "light", state: "recovery") }
    func testT18_zh_max_light_retrying() throws { try t18CaptureGroup(language: "zh", maximumFont: true, theme: "light", state: "retrying") }
    func testT18_zh_max_light_action() throws { try t18CaptureGroup(language: "zh", maximumFont: true, theme: "light", state: "action") }
    func testT18_zh_max_light_offline() throws { try t18CaptureGroup(language: "zh", maximumFont: true, theme: "light", state: "offline") }
    func testT18_zh_max_dark_idle() throws { try t18CaptureGroup(language: "zh", maximumFont: true, theme: "dark", state: "idle") }
    func testT18_zh_max_dark_recovery() throws { try t18CaptureGroup(language: "zh", maximumFont: true, theme: "dark", state: "recovery") }
    func testT18_zh_max_dark_retrying() throws { try t18CaptureGroup(language: "zh", maximumFont: true, theme: "dark", state: "retrying") }
    func testT18_zh_max_dark_action() throws { try t18CaptureGroup(language: "zh", maximumFont: true, theme: "dark", state: "action") }
    func testT18_zh_max_dark_offline() throws { try t18CaptureGroup(language: "zh", maximumFont: true, theme: "dark", state: "offline") }
    // TASK145_T18_INSERT_END configured-native-captures

}

// TASK145_T19_INSERT_BEGIN ui
extension LocalAvailabilityRootUITests {
    func testThirtyHealthyNoOpCyclesPreserveStoreAndTabsAcrossRootRecreation() throws {
        try t19Run(mode: "cycles", cycles: 30)
    }

    func testDistinctEventsWithIdenticalBodyPreserveLedgerThenReturnToNoWork() throws {
        try t19Run(mode: "repeated-material", cycles: 1)
    }

    private func t19Run(mode: String, cycles: Int) throws {
        app.launchEnvironment["TASK145_T19_UI"] = mode
        app.launchEnvironment["TASK145_T19_STAGE"] = "setup"
        let deadline = ProcessInfo.processInfo.systemUptime + (cycles == 30 ? 1530 : 180)
        if mode == "cycles", cycles == 30 { try task146ConfigureAnimationIdleDriver() }
        var stage = "own-ACK-precondition"
        var uiRows: [[String: Any]] = []
        var terminal = "FAIL"
        var firstError: Error?
        defer {
            // Only the owned controlled app process. Host later archives its exact namespace.
            app.terminate()
            let stopped = app.state == .notRunning
            let receipt: [String: Any] = ["protocol": "task145-t19-controlled-v1", "mode": mode, "namespace": runID,
                "status": terminal, "stage": stage, "expectedCycles": cycles, "observedUI": uiRows,
                "ordinaryAuthenticatedTEST": "NOT_TRAVERSED", "lateDiagnostic": "UNKNOWN_NOT_TRAVERSED",
                "ownedAppStopped": stopped, "hostPreservation": "PENDING",
                "errorType": firstError.map { String(reflecting: type(of: $0)) } as Any? ?? NSNull()]
            let data = (try? JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys])) ?? Data("T19 terminal serialization failed".utf8)
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "T19 controlled UI terminal"; attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertTrue(stopped, "Owned app must be stopped before host preservation; otherwise native qualification fails")
        }
        do {
            try runSavedNameRestartScenario("pre-send")
            app.terminate(); XCTAssertEqual(app.state, .notRunning)
            app.launchEnvironment["TASK145_T19_STAGE"] = "collect"
            app.launch()
            stage = "qualified-baseline"
            let baseline = try t19Wait(deadline: min(deadline, ProcessInfo.processInfo.systemUptime + 45)) { value in
                value["baseline"] as? String != nil && value["qualifiedPID"] as? Int == value["pid"] as? Int
            }
            let originalPID = try XCTUnwrap(baseline["pid"] as? Int)
            var previousPID = originalPID
            var previousInvocations = Set<String>()
            let expectedVerified = try XCTUnwrap(baseline["verifiedText"] as? String)
            for number in 1...cycles {
                stage = "cycle-\(number)"
                let state = try t19Wait(deadline: min(deadline, ProcessInfo.processInfo.systemUptime + (mode == "cycles" ? 45 : 80))) {
                    ($0["completed"] as? Int ?? 0) >= number
                }
                let completedBeforeTabs = try XCTUnwrap(state["completed"] as? Int)
                // Normal polls continue while XCTest traverses tabs. Witness
                // every immutable indexed row in order, without skipping a poll
                // merely because a later one has already completed.
                XCTAssertGreaterThanOrEqual(completedBeforeTabs, number)
                XCTAssertLessThanOrEqual(completedBeforeTabs, cycles)
                let rows = try XCTUnwrap(state["cycles"] as? [[String: Any]])
                XCTAssertEqual(rows.count, cycles)
                let row = rows[number - 1]
                XCTAssertEqual(row["cycle"] as? Int, number)
                XCTAssertEqual(row["status"] as? String, "PASS")
                XCTAssertEqual(row["source"] as? String, "foregroundPoll")
                let observation = try XCTUnwrap(row["observation"] as? [String: Any])
                let invocation = try XCTUnwrap(observation["invocationID"] as? String)
                XCTAssertTrue(previousInvocations.insert(invocation).inserted, "A previous published outcome must not count again")
                let pid = try XCTUnwrap(row["pid"] as? Int)
                let frame = try XCTUnwrap(row["frame"] as? Int)
                XCTAssertGreaterThan(frame, 0)
                for tab in ["Database", "History", "Inventory", "Options"] {
                    XCTAssertEqual(app.state, .runningForeground)
                    let tabDeadline = ProcessInfo.processInfo.systemUptime + 5
                    let buttons = app.tabBars.buttons.matching(NSPredicate(format: "label == %@", tab))
                    let button = buttons.element(boundBy: 0)
                    // A present tab needs no one-second existence polling. An
                    // absent tab retains the same bounded five-second admission.
                    let present = button.exists || button.waitForExistence(
                        timeout: max(0, tabDeadline - ProcessInfo.processInfo.systemUptime))
                    XCTAssertTrue(present && ProcessInfo.processInfo.systemUptime <= tabDeadline)
                    if !button.isSelected { button.tap() }
                    // Root recreation may replace the bar; require the real
                    // current selected flag even when no redundant tap was needed.
                    XCTAssertTrue(buttons.element(boundBy: 0).isSelected)
                    XCTAssertFalse(app.staticTexts["task145.t19.failed"].exists)
                }
                let optionsForm = try c3OptionsForm(stage: "T19-verified-date", downstream: ["verified-date"])
                let verifiedRow = optionsForm.staticTexts.matching(NSPredicate(
                    format: "identifier == %@ AND label BEGINSWITH %@",
                    "options.sync-business-summary", "Last data sync, ")).firstMatch
                try c3OptionsReveal(verifiedRow, form: optionsForm, stage: "T19-verified-date", downstream: ["verified-date"])
                let date = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", expectedVerified)).firstMatch
                XCTAssertTrue(date.waitForExistence(timeout: 5), "Options must show the date of the actual scoped verified proof, preserved across poll/remount")
                let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.lifetime = .keepAlways
                screenshot.name = "T19 cycle \(number) Options real date and status"; add(screenshot)
                let afterTabs = try t19State()
                let completedAfterTabs = try XCTUnwrap(afterTabs["completed"] as? Int)
                XCTAssertGreaterThanOrEqual(completedAfterTabs, completedBeforeTabs)
                XCTAssertLessThanOrEqual(completedAfterTabs, cycles)
                XCTAssertEqual(afterTabs["verifiedText"] as? String, expectedVerified)
                let unchangedRows = try XCTUnwrap(afterTabs["cycles"] as? [[String: Any]])
                XCTAssertEqual(unchangedRows.count, rows.count)
                XCTAssertEqual(try JSONSerialization.data(withJSONObject: Array(unchangedRows.prefix(completedBeforeTabs)), options: [.sortedKeys]),
                    try JSONSerialization.data(withJSONObject: Array(rows.prefix(completedBeforeTabs)), options: [.sortedKeys]),
                    "All previously completed producer rows must remain byte-identical while normal polls append")
                XCTAssertEqual(try JSONSerialization.data(withJSONObject: unchangedRows[number - 1], options: [.sortedKeys]),
                    try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]))
                uiRows.append(["cycle": number, "status": "PASS", "pid": pid, "frame": frame,
                    "invocation": invocation, "tabs": ["Database", "History", "Inventory", "Options"], "verifiedText": expectedVerified,
                    "producerCompletedBeforeTabs": completedBeforeTabs, "producerCompletedAfterTabs": completedAfterTabs,
                    "observedAppPID": try XCTUnwrap(afterTabs["pid"] as? Int)])
                if cycles == 30 && [10, 20].contains(number) {
                    stage = "quiet-reopen-\(number)"
                    app.terminate(); XCTAssertEqual(app.state, .notRunning); app.launch()
                    let reopened = try t19Wait(deadline: min(deadline, ProcessInfo.processInfo.systemUptime + 45)) {
                        $0["qualifiedPID"] as? Int == $0["pid"] as? Int && ($0["pid"] as? Int) != previousPID
                    }
                    let newPID = try XCTUnwrap(reopened["pid"] as? Int)
                    XCTAssertNotEqual(newPID, previousPID); previousPID = newPID
                    let completedAfterReopen = try XCTUnwrap(reopened["completed"] as? Int)
                    XCTAssertGreaterThanOrEqual(completedAfterReopen, completedAfterTabs)
                    XCTAssertLessThanOrEqual(completedAfterReopen, cycles)
                    let reopenedRows = try XCTUnwrap(reopened["cycles"] as? [[String: Any]])
                    XCTAssertEqual(reopenedRows.count, unchangedRows.count)
                    XCTAssertEqual(try JSONSerialization.data(withJSONObject: Array(reopenedRows.prefix(completedAfterTabs)), options: [.sortedKeys]),
                        try JSONSerialization.data(withJSONObject: Array(unchangedRows.prefix(completedAfterTabs)), options: [.sortedKeys]),
                        "Reopen preserves every completed poll; the fixture appends foregroundPoll, never bootstrap")
                    XCTAssertEqual(reopened["verifiedText"] as? String, expectedVerified)
                }
            }
            stage = "terminal"
            let final = try t19State()
            XCTAssertEqual(final["status"] as? String, "COMPLETE")
            XCTAssertEqual(final["completed"] as? Int, cycles)
            XCTAssertEqual(uiRows.compactMap { $0["cycle"] as? Int }, Array(1...cycles),
                "Every actual poll retains its own ordered native UI witness")
            XCTAssertEqual(previousInvocations.count, cycles)
            if mode == "repeated-material" { XCTAssertEqual((final["variant"] as? [String: Any])?["status"] as? String, "PASS") }
            let evidence = XCTAttachment(data: try JSONSerialization.data(withJSONObject: final, options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
            evidence.name = "T19 complete passive ledger index"; evidence.lifetime = .keepAlways; add(evidence)
            terminal = "PASS_PENDING_HOST_PRESERVATION"
        } catch {
            firstError = error
            captureControlledAutomaticReadback()
            throw error
        }
    }

    private func t19State(_ publishedReadback: String? = nil) throws -> [String: Any] {
        let readback = publishedReadback ?? (app.buttons["task144.controlled.release"].value as? String ?? "")
        let prefix = "task145.t19.state."
        let encoded = try XCTUnwrap(readback.components(separatedBy: ";").first { $0.hasPrefix(prefix) })
        let data = try XCTUnwrap(Data(base64Encoded: String(encoded.dropFirst(prefix.count))))
        XCTAssertLessThanOrEqual(data.count, 65_536)
        let value = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(value["runID"] as? String, runID)
        XCTAssertEqual(value["protocol"] as? String, "task145-t19-controlled-v1")
        return value
    }

    private func t19Wait(deadline: TimeInterval, predicate: ([String: Any]) -> Bool) throws -> [String: Any] {
        // Polls read-only accessibility. No Retry, hidden runtime trigger, or direct producer call.
        while ProcessInfo.processInfo.systemUptime < deadline {
            let control = app.buttons["task144.controlled.release"]
            if control.exists, let readback = control.value as? String,
               readback.components(separatedBy: ";").contains(where: { $0.hasPrefix("task145.t19.") }) {
                // Existence precedes the first passive publication; present malformed T19 data still fails below.
                let value = try t19State(readback)
                if value["error"] != nil {
                    let evidence = XCTAttachment(data: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
                    evidence.name = "T19 original failure"; evidence.lifetime = .keepAlways; add(evidence)
                    throw NSError(domain: "Task145T19", code: 1, userInfo: [NSLocalizedDescriptionKey: "Passive native observer failed; preserve original owned ledger"])
                }
                if predicate(value) { return value }
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        throw NSError(domain: "Task145T19", code: 2, userInfo: [NSLocalizedDescriptionKey: "Bounded T19 observation timeout; do not retry or count missing cycles"])
    }
}
// TASK145_T19_INSERT_END ui


// TASK145_PERF: same production root and real UI gestures, with app-side clocks.
// This selector is separately pinned/reviewed; it is not auto-enabled by other UI tests.
extension LocalAvailabilityRootUITests {
    @MainActor
    func testR23LargeUIColdWarmBaselineAndHeldRecovery() throws {
        let performancePinKeys = ["TASK145_PERF_SOURCE_PIN", "TASK145_PERF_ARTIFACT_PIN",
                                  "TASK145_PERF_CONFIG_PIN", "TASK145_PERF_TARGET_STORAGE"]
        try XCTSkipUnless(performancePinKeys.contains { ProcessInfo.processInfo.environment[$0] != nil },
                          "Performance UI requires its explicit four-pin binding.")
        let recorder = try MobileSyncPerformanceRecorder(caseName: "ios-r23-large-ui")
        defer { try? recorder.attach(to: self) }
        guard let sourcePin = ProcessInfo.processInfo.environment["TASK145_PERF_SOURCE_PIN"], !sourcePin.isEmpty,
              let artifactPin = ProcessInfo.processInfo.environment["TASK145_PERF_ARTIFACT_PIN"], !artifactPin.isEmpty,
              let configPin = ProcessInfo.processInfo.environment["TASK145_PERF_CONFIG_PIN"], !configPin.isEmpty,
              let storage = ProcessInfo.processInfo.environment["TASK145_PERF_TARGET_STORAGE"], !storage.isEmpty else {
            throw MobileSyncPerformanceRecorder.RecorderError.invariant("source_artifact_config_or_target_storage_missing")
        }
        try recorder.writeSetup(["schema": 1, "protocol": "REPLANNING_20261023-section14",
            "seed": "T20-20261016-v1-relations-2x2", "products": 20_000, "prices": 40_000,
            "price_product_relations": 40_000, "product_supplier_relations": 1, "product_category_relations": 1,
            "suppliers": 2, "categories": 2, "history": 0,
            "save_variants": ["name": 10, "name_and_retail_price": 10, "name_and_existing_relations": 10],
            "queries": ["selective": "T20-020000 (1 row)", "broad": "T20-000 (999 rows)"] ,
            "warmups_per_group": 3, "cold_per_group": 15, "warm_per_group": 15,
            "offline_cold": 5, "offline_warm": 5, "clock": "app-monotonic",
            "transport": "actual-coordinator-with-controlled-request",
            "source_pin": sourcePin, "artifact_pin": artifactPin, "config_pin": configPin, "target_storage": storage,
            "os_launch_to_app_entry": "NOT_OBSERVED; separate from app-entry T0",
            "device": ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "runner-not-proven"])
        var groupResults: [String: [String: Double]] = [:]
        let allIDs = ["idle", "recovery"].flatMap { group in
            (1...15).flatMap { index in ["\(group)-\(index)-cold", "\(group)-\(index)-warm"] }
        }
        var traversed: Set<String> = []
        var currentSample: (id: String, warmup: Bool)?
        do {
            for group in ["idle", "recovery"] {
                // Fresh namespace once per group, seeded BEFORE any timed launch.
                // Subsequent cold runs reuse its on-disk store; warm runs keep PID.
                runID = UUID().uuidString.lowercased()
                app.launchEnvironment["TASK144_LOCAL_AVAILABILITY_FIXTURE"] = runID
                app.launchEnvironment["TASK145_PERF_MODE"] = "seed"
                app.launchEnvironment["TASK145_PERF_GROUP"] = group
                app.launchEnvironment["TASK145_PERF_SOURCE_PIN"] = sourcePin
                app.launchEnvironment["TASK145_PERF_ARTIFACT_PIN"] = artifactPin
                app.launchEnvironment["TASK145_PERF_CONFIG_PIN"] = configPin
                app.launchEnvironment["TASK145_PERF_TARGET_STORAGE"] = storage
                app.launchEnvironment["TASK145_PERF_OFFLINE"] = "0"
                app.launch()
                guard app.staticTexts["task145.perf.seed-qualified"].waitForExistence(timeout: 180) else {
                    throw MobileSyncPerformanceRecorder.RecorderError.invariant("seed_not_qualified")
                }
                let datasetJSON = app.staticTexts["task145.perf.dataset-json"].value as? String ?? ""
                try recorder.recordDatasetManifest(datasetJSON, group: group, namespace: runID)
                app.terminate()
                var measurements: [(kind: String, offline: Bool, variant: String, values: [String: Double])] = []
                var expectedName = "Synthetic T20 20000", expectedRetail = "20"
                var expectedSupplier = "T20 Supplier One", expectedCategory = "T20 Category One"
                var precedingColdPID: Int?
                var pairPID: Int?
                for index in -2...15 {
                    let warmup = index <= 0
                    let prefix = "\(group)-\(index)"
                    app.launchEnvironment["TASK145_PERF_MODE"] = "measure"
                    app.launchEnvironment["TASK145_PERF_SAMPLE"] = prefix
                    let offline = group == "idle" && (11...15).contains(index)
                    let variant = index <= 0 ? "name" : ["name", "price", "relations"][(index - 1) % 3]
                    app.launchEnvironment["TASK145_PERF_OFFLINE"] = offline ? "1" : "0"
                    app.launchEnvironment["TASK145_PERF_EXPECTED_EDITOR_NAME"] = expectedName
                    app.launchEnvironment["TASK145_PERF_VARIANT"] = variant
                    app.launchEnvironment["TASK145_PERF_INDEX"] = String(index)
                    app.launch()
                    for kind in warmup ? ["cold"] : ["cold", "warm"] {
                        let id = prefix + "-" + kind
                        currentSample = (id, warmup)
                        if kind == "warm" {
                            // Actual user clear, outside next timing window. No seed/restart/clock reset.
                            try r23ReplacePerformanceText(in: app.textFields["task144.database.search"], with: "")
                            app.buttons["task145.perf.arm-warm"].tap()
                            guard app.staticTexts["task145.perf.warm-ready"].waitForExistence(timeout: 6) else {
                                throw MobileSyncPerformanceRecorder.RecorderError.invariant("warm_arm_previous_runtime_not_released_or_journal_not_retired")
                            }
                            XCUIDevice.shared.press(.home)
                            guard app.wait(for: .runningBackground, timeout: 5) else {
                                throw MobileSyncPerformanceRecorder.RecorderError.invariant("warm_no_real_background")
                            }
                            app.activate()
                        }
                        if !warmup { traversed.insert(id) }
                        let afterRetail = variant == "price" ? String(1100 + index * 2 + (kind == "warm" ? 1 : 0)) : expectedRetail
                        let afterSupplier = variant == "relations" ? (kind == "cold" ? "T20 Supplier Two" : "T20 Supplier One") : expectedSupplier
                        let afterCategory = variant == "relations" ? (kind == "cold" ? "T20 Category Two" : "T20 Category One") : expectedCategory
                        let observation = try runR23MeasuredUI(recorder: recorder, sampleID: id, warmup: warmup, recovery: group == "recovery",
                            expectedName: expectedName, expectedRetail: expectedRetail, expectedSupplier: expectedSupplier, expectedCategory: expectedCategory,
                            afterRetail: afterRetail, afterSupplier: afterSupplier, afterCategory: afterCategory, variant: variant,
                            expectedPID: kind == "warm" ? pairPID : nil, precedingColdPID: kind == "cold" ? precedingColdPID : nil)
                        if kind == "cold" { precedingColdPID = observation.pid; pairPID = observation.pid }
                        expectedName = "T20 edited " + id; expectedRetail = afterRetail
                        expectedSupplier = afterSupplier; expectedCategory = afterCategory
                        if !warmup { measurements.append((kind, offline, variant, observation.values)) }
                    }
                    app.terminate()
                }
                groupResults[group] = try recorder.writeUIAggregate(measurements, group: group)
            }
            try recorder.writeUIPairedComparison(idle: groupResults["idle"]!, recovery: groupResults["recovery"]!)
        } catch {
            if let currentSample, !recorder.hasRecordedUI(currentSample.id) {
                let raw = app.descendants(matching: .any).matching(identifier: "task145.perf.live-sample").firstMatch.value as? String ?? "{}"
                let sample = (try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any] ?? [:]
                // A setup failure before warm T0 does not relabel cold timestamps as warm.
                let current = sample["sampleID"] as? String == currentSample.id ? sample : [:]
                _ = try? recorder.recordObservedUI(current, sampleID: currentSample.id, warmup: currentSample.warmup,
                    functionalFailure: String(describing: error))
                traversed.insert(currentSample.id)
            }
            try recorder.recordUIHarnessFailure(reason: String(describing: error))
            try recorder.recordNotTraversed(sampleIDs: allIDs.filter { !traversed.contains($0) }, reason: "first_prior_FAIL: " + String(describing: error))
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "R23 large UI first failure"; shot.lifetime = .keepAlways; add(shot)
            let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.name = "R23 large UI first failure hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
            throw error
        }
    }

    @MainActor
    private func runR23MeasuredUI(recorder: MobileSyncPerformanceRecorder, sampleID: String,
                                 warmup: Bool, recovery: Bool,
                                 expectedName: String, expectedRetail: String, expectedSupplier: String, expectedCategory: String,
                                 afterRetail: String, afterSupplier: String, afterCategory: String, variant: String,
                                 expectedPID: Int?, precedingColdPID: Int?) throws -> (pid: Int, values: [String: Double]) {
        func require(_ condition: @autoclosure () -> Bool, _ gate: String) throws {
            guard condition() else {
                // The first gate failure is retained, then dependent actions stop.
                if app.buttons["task145.perf.fail"].exists { app.buttons["task145.perf.fail"].tap() }
                let exported = observedPayload(), live = liveSample()
                let payload = exported["sampleID"] as? String == sampleID ? exported
                    : (live["sampleID"] as? String == sampleID ? live : [:])
                _ = try recorder.recordObservedUI(payload, sampleID: sampleID, warmup: warmup, functionalFailure: gate)
                throw MobileSyncPerformanceRecorder.RecorderError.invariant(gate)
            }
        }
        func observedPayload() -> [String: Any] {
            let json = app.staticTexts["task145.perf.sample-json"].value as? String ?? "{}"
            return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
        }
        func liveSample() -> [String: Any] {
            let raw = app.descendants(matching: .any).matching(identifier: "task145.perf.live-sample").firstMatch.value as? String ?? "{}"
            return (try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any] ?? [:]
        }
        func checkMetric(_ name: String, _ start: String, _ end: String, maxSeconds: Double) throws {
            func times() -> (UInt64, UInt64)? {
                let payload = liveSample()
                guard payload["sampleID"] as? String == sampleID, let rows = payload["marks"] as? [[String: Any]],
                      let begin = rows.first(where: { $0["name"] as? String == start })?["ns"] as? NSNumber,
                      let finish = rows.first(where: { $0["name"] as? String == end })?["ns"] as? NSNumber else { return nil }
                return (begin.uint64Value, finish.uint64Value)
            }
            let observed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in times() != nil }, object: nil)
            // Read-only RAM observation after the real UI value exists. This wait
            // does not become the metric and cannot make a slow app-side result pass.
            try require(XCTWaiter.wait(for: [observed], timeout: 1) == .completed, name + "_render_observation_missing")
            guard let (begin, finish) = times() else { throw MobileSyncPerformanceRecorder.RecorderError.invariant(name + "_observation_lost") }
            try require(finish >= begin && Double(finish - begin) / 1_000_000_000 <= maxSeconds, name + "_absolute_max_exceeded")
            if recovery && ["shell", "data"].contains(name) {
                let sample = liveSample(), marks = sample["marks"] as? [[String: Any]] ?? []
                let held = marks.first(where: { $0["name"] as? String == "requestHeld" })?["ns"] as? NSNumber
                let metadata = sample["metadata"] as? [String: String] ?? [:]
                // Observation only, after the measured endpoint. Never wait for
                // a later RPC to retroactively qualify shell/data under recovery.
                try require(held != nil && held!.uint64Value <= finish
                    && metadata["activeRequest"] == "recovery-page.products" && metadata["responseHeld"] == "true",
                    "recovery_hold_not_active_before_" + end)
            }
        }
        // AX waits are functional guards only, not timing samples or timestamps.
        try require(app.tabBars.buttons["Options"].waitForExistence(timeout: 2), "shell_options_missing")
        // Navigate immediately. Do not put the remote-entry wait or four AX
        // queries between shell availability and its actual navigation endpoint.
        app.tabBars.buttons["Options"].tap()
        try require(app.navigationBars["Options"].waitForExistence(timeout: 2), "options_navigation_failed")
        try checkMetric("shell", "t0", "optionsRender", maxSeconds: 2)
        for title in ["Inventory", "Database", "History", "Options"] {
            try require(app.tabBars.buttons[title].exists && app.tabBars.buttons[title].isHittable, "shell_tab_not_hittable_" + title)
        }
        if recovery {
            try require(app.staticTexts["task145.perf.actual-recovery-request-held"].exists, "actual_recovery_request_not_entered")
        }
        let currentPID = (liveSample()["pid"] as? NSNumber)?.intValue
        try require(currentPID != nil && (expectedPID == nil || currentPID == expectedPID)
            && (precedingColdPID == nil || currentPID != precedingColdPID), "cold_warm_process_identity_mismatch")
        app.tabBars.buttons["Database"].tap()
        try require(app.staticTexts["Synthetic T20 1"].waitForExistence(timeout: 5), "qualified_initial_query_or_row_missing")
        try checkMetric("data", "t0", "dataRender", maxSeconds: sampleID.hasSuffix("-cold") ? 5 : 1)
        let search = app.textFields["task144.database.search"]
        try require(search.exists && search.isHittable, "search_not_editable")
        search.tap(); search.typeText("T20-000")
        try require(app.staticTexts["Synthetic T20 1"].waitForExistence(timeout: 1)
            && app.staticTexts["T20-000001"].exists && !app.staticTexts["T20-020000"].exists, "broad_search_wrong_visible_results")
        try require((liveSample()["metadata"] as? [String: String])?["broadQueryCount"] == "999", "broad_query_cardinality_wrong")
        try checkMetric("searchBroad", "searchBroadInputComplete", "searchBroadRender", maxSeconds: 1)
        try r23ReplacePerformanceText(in: search, with: "T20-020000")
        let target = app.staticTexts["T20-020000"].firstMatch
        try require(target.waitForExistence(timeout: 1), "search_exact_record_missing")
        try require((liveSample()["metadata"] as? [String: String])?["selectiveQueryCount"] == "1", "selective_query_cardinality_wrong")
        try checkMetric("search", "searchInputComplete", "searchRender", maxSeconds: 1)
        target.tap()
        let name = app.textFields["task144.product.name"]
        try require(name.waitForExistence(timeout: 1), "editor_not_editable")
        try require(app.textFields["task141.product.barcode"].value as? String == "T20-020000", "editor_wrong_record")
        try require(name.value as? String == expectedName && name.isEnabled && name.isHittable, "editor_wrong_name_or_not_editable")
        try checkMetric("editor", "editorTap", "editorRender", maxSeconds: 1)
        let expected = "T20 edited " + sampleID
        try r23ReplacePerformanceText(in: name, with: expected)
        let retail = app.textFields["task141.product.retail-price"]
        for _ in 0..<4 { if retail.isHittable { break }; app.swipeUp() }
        try require(retail.value as? String == expectedRetail, "editor_wrong_retail_price")
        if variant == "price" { try r23ReplacePerformanceText(in: retail, with: afterRetail) }
        let supplier = app.textFields["Supplier name"], category = app.textFields["Category name"]
        for _ in 0..<4 { if supplier.isHittable && category.isHittable { break }; app.swipeUp() }
        try require(supplier.value as? String == expectedSupplier && category.value as? String == expectedCategory, "editor_wrong_existing_relations")
        if variant == "relations" {
            try r23ReplacePerformanceText(in: supplier, with: afterSupplier)
            try r23ReplacePerformanceText(in: category, with: afterCategory)
        }
        try require(name.value as? String == expected, "editor_input_not_complete")
        app.buttons["Save"].tap()
        try require(app.staticTexts[expected].waitForExistence(timeout: 1), "save_value_not_rendered")
        try require(app.staticTexts["Saved on this device · Waiting for cloud confirmation"].waitForExistence(timeout: 1), "save_confirmation_missing")
        try checkMetric("save", "saveTap", "saveRender", maxSeconds: 1)
        if recovery {
            // An elapsed controlled hold is checked in the app, not inferred from waiting.
            // The actual request still has its 45s deadline; no fake progress is emitted.
            let heldLongEnough = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let sample = liveSample(), metadata = sample["metadata"] as? [String: String] ?? [:]
                guard metadata["responseHeld"] == "true", metadata["activeRequest"] == "recovery-page.products",
                      let now = sample["observedAtNS"] as? NSNumber,
                      let marks = sample["marks"] as? [[String: Any]],
                      let began = marks.first(where: { $0["name"] as? String == "requestHeld" })?["ns"] as? NSNumber else { return false }
                return now.uint64Value >= began.uint64Value && now.uint64Value - began.uint64Value >= 10_000_000_000
            }, object: nil)
            try require(XCTWaiter.wait(for: [heldLongEnough], timeout: 11) == .completed, "actual_held_request_minimum_or_ownership_missing")
        }
        app.buttons["task145.perf.export"].tap()
        let exported = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            observedPayload()["sampleID"] as? String == sampleID
        }, object: nil)
        // An external observation ceiling, not a full-recovery performance budget.
        // App watchdog independently records no-progress10s and first failure.
        try require(XCTWaiter.wait(for: [exported], timeout: 180) == .completed, "external_export_observation_timeout")
        let payload = observedPayload()
        try require(payload["sampleID"] as? String == sampleID, "stale_or_missing_app_sample")
        return (currentPID!, try recorder.recordObservedUI(payload, sampleID: sampleID, warmup: warmup))
    }
    @MainActor
    private func r23ReplacePerformanceText(in field: XCUIElement, with value: String) throws {
        guard field.exists, field.isHittable else { throw MobileSyncPerformanceRecorder.RecorderError.invariant("input_field_not_hittable") }
        field.tap()
        if let previous = field.value as? String, !previous.isEmpty {
            field.press(forDuration: 1.1)
            let selectAll = app.descendants(matching: .any).matching(NSPredicate(
                format: "label == %@ AND (elementType == %d OR elementType == %d)", "Select All",
                XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.menuItem.rawValue)).firstMatch
            guard selectAll.waitForExistence(timeout: 5) else { throw MobileSyncPerformanceRecorder.RecorderError.invariant("native_select_all_missing") }
            selectAll.tap()
        }
        field.typeText(value.isEmpty ? XCUIKeyboardKey.delete.rawValue : value)
        guard field.value as? String == value else { throw MobileSyncPerformanceRecorder.RecorderError.invariant("native_input_incomplete") }
    }

}
