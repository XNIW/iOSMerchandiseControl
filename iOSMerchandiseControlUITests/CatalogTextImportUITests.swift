import XCTest

final class CatalogTextImportUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment = [
            "TASK140_UI_TEST": "1",
            "TASK131_INITIAL_TAB": "database",
            "TASK144_LOCAL_AVAILABILITY_FIXTURE": UUID().uuidString.lowercased()
        ]
    }

    override func tearDown() {
        app.terminate()
        app = nil
        super.tearDown()
    }

    func testDatabaseCSVImportPresentsSystemFilePicker() {
        app.launch()

        XCTAssertTrue(
            app.segmentedControls["task140.database.root"]
                .waitForExistence(timeout: 10)
        )
        let importButton = app.buttons["task140.database.import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        importButton.tap()

        let csvAction = app.buttons["task140.database.import.csv"].firstMatch
        XCTAssertTrue(csvAction.waitForExistence(timeout: 5))
        csvAction.tap()

        XCTAssertTrue(
            app.collectionViews["File View"].waitForExistence(timeout: 10),
            "Il fileImporter CSV deve presentare il picker Files di sistema."
        )
        XCTAssertTrue(app.staticTexts["Recents"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }

    func testImportAnalysisShowsBlockingRowErrorAndDisablesApply() {
        app.launchEnvironment["TASK140_UI_IMPORT_ANALYSIS"] = "1"
        app.launch()

        XCTAssertTrue(
            app.collectionViews["task140.import-analysis.root"]
                .waitForExistence(timeout: 10)
        )
        let applyButton = app.buttons["task140.import-analysis.apply"]
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
        XCTAssertFalse(applyButton.isEnabled)
        XCTAssertTrue(app.navigationBars["Import from Excel"].exists)
    }

    func testProductEditorBlocksInvalidNumericInputAndRetainsDraftDuringCorrection() {
        app.launch()

        let newProductButton = app.buttons["New product"].firstMatch
        XCTAssertTrue(newProductButton.waitForExistence(timeout: 10))
        newProductButton.tap()

        let barcode = app.textFields["task141.product.barcode"]
        XCTAssertTrue(barcode.waitForExistence(timeout: 5))
        scrollUntilHittable(barcode)
        barcode.tap()
        barcode.typeText("TASK141-\(UUID().uuidString.prefix(8))")

        let stockQuantity = app.textFields["task141.product.stock-quantity"]
        XCTAssertTrue(stockQuantity.waitForExistence(timeout: 5))
        scrollUntilHittable(stockQuantity)
        stockQuantity.tap()
        stockQuantity.typeText("-1")

        let purchasePrice = app.textFields["task141.product.purchase-price"]
        XCTAssertTrue(purchasePrice.waitForExistence(timeout: 5))
        scrollUntilHittable(purchasePrice)
        purchasePrice.tap()
        purchasePrice.typeText("1..2")

        app.buttons["Save"].tap()
        let purchaseError = app.descendants(matching: .any)[
            "task141.product.purchase-price-error"
        ]
        let quantityError = app.descendants(matching: .any)[
            "task141.product.stock-quantity-error"
        ]
        XCTAssertTrue(
            purchaseError.waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            quantityError.waitForExistence(timeout: 5)
        )

        let invalidAttachment = XCTAttachment(screenshot: app.screenshot())
        invalidAttachment.name = "TASK-141 invalid numeric field feedback"
        invalidAttachment.lifetime = .keepAlways
        add(invalidAttachment)

        replaceText(in: stockQuantity, with: "2", swipeDown: true)
        replaceText(in: purchasePrice, with: "1.234,5")
        XCTAssertFalse(purchaseError.exists)
        XCTAssertFalse(quantityError.exists)
        XCTAssertEqual(stockQuantity.value as? String, "2")
        XCTAssertEqual(purchasePrice.value as? String, "1.234,5")
        scrollUntilHittable(barcode, swipeDown: true)
        XCTAssertTrue((barcode.value as? String)?.hasPrefix("TASK141-") == true)
    }

    func testInvalidSaveDoesNotInsertAndChileQuantityPersistsExactValue() {
        app.launchEnvironment["TASK141_RESET_UI_STATE"] = "1"
        app.launch()
        let barcodeValue = "TASK141-PERSIST-\(UUID().uuidString.prefix(8))"

        openNewProductAndEnterBarcode(barcodeValue)
        let stockQuantity = app.textFields["task141.product.stock-quantity"]
        let purchasePrice = app.textFields["task141.product.purchase-price"]
        replaceText(in: stockQuantity, with: "1,234")
        replaceText(in: purchasePrice, with: "1..2")

        app.buttons["Save"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["task141.product.purchase-price-error"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["Cancel"].tap()

        let search = databaseSearchField()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(barcodeValue)
        XCTAssertFalse(
            app.staticTexts[barcodeValue].waitForExistence(timeout: 1),
            "Un Save invalido non deve inserire alcun prodotto."
        )

        replaceText(in: search, with: "")
        openNewProductAndEnterBarcode(barcodeValue)
        replaceText(
            in: app.textFields["task141.product.stock-quantity"],
            with: "1,234"
        )
        replaceText(
            in: app.textFields["task141.product.purchase-price"],
            with: "1.234,5"
        )
        app.buttons["Save"].tap()

        let persistedSearch = databaseSearchField()
        XCTAssertTrue(persistedSearch.waitForExistence(timeout: 5))
        replaceText(in: persistedSearch, with: barcodeValue)
        let persistedProduct = app.staticTexts[barcodeValue].firstMatch
        XCTAssertTrue(persistedProduct.waitForExistence(timeout: 5))
        persistedProduct.tap()

        let persistedStock = app.textFields["task141.product.stock-quantity"]
        let persistedPurchase = app.textFields["task141.product.purchase-price"]
        XCTAssertTrue(persistedStock.waitForExistence(timeout: 5))
        XCTAssertEqual(persistedStock.value as? String, "1.234")
        XCTAssertEqual(persistedPurchase.value as? String, "1234.5")
    }

    private func openNewProductAndEnterBarcode(_ value: String) {
        let admissionDeadline = ProcessInfo.processInfo.systemUptime + 5
        let newProductButton = app.buttons["New product"].firstMatch
        let ready = NSPredicate { _, _ in
            guard ProcessInfo.processInfo.systemUptime < admissionDeadline,
                  newProductButton.exists,
                  ProcessInfo.processInfo.systemUptime < admissionDeadline else { return false }
            return newProductButton.isHittable && ProcessInfo.processInfo.systemUptime < admissionDeadline
        }
        let immediatelyReady = ready.evaluate(with: nil)
        let remaining = admissionDeadline - ProcessInfo.processInfo.systemUptime
        let admitted = immediatelyReady || (remaining > 0 && XCTWaiter.wait(for: [
            XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: remaining) == .completed)
        XCTAssertTrue(admitted && ProcessInfo.processInfo.systemUptime < admissionDeadline,
            "New product must admit its native hit point within the existing five seconds")
        newProductButton.tap()

        let barcode = app.textFields["task141.product.barcode"]
        XCTAssertTrue(barcode.waitForExistence(timeout: 5))
        scrollUntilHittable(barcode)
        barcode.tap()
        barcode.typeText(value)
    }

    private func databaseSearchField() -> XCUIElement {
        app.textFields
            .matching(
                NSPredicate(
                    format: "label == %@",
                    "Search by barcode, name, or code"
                )
            )
            .firstMatch
    }

    private func replaceText(
        in element: XCUIElement,
        with text: String,
        swipeDown: Bool = false
    ) {
        scrollUntilHittable(element, swipeDown: swipeDown)
        element.tap()
        if let currentValue = element.value as? String, !currentValue.isEmpty {
            element.typeText(
                String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            )
        }
        element.typeText(text)
    }

    private func scrollUntilHittable(_ element: XCUIElement, swipeDown: Bool = false) {
        var attempts = 0
        while attempts < 6 {
            let editorBars = app.navigationBars.matching(NSPredicate(
                format: "identifier IN %@ OR label IN %@", ["New product", "Edit product"], ["New product", "Edit product"]))
            if editorBars.count > 0 {
                let editorFieldIDs = ["task141.product.barcode", "task141.product.stock-quantity",
                    "task141.product.purchase-price", "task141.product.retail-price"]
                let forms = app.collectionViews.containing(NSPredicate(
                    format: "elementType == %d AND identifier IN %@", XCUIElement.ElementType.textField.rawValue, editorFieldIDs))
                XCTAssertEqual(editorBars.count, 1, "Require the current product editor's native navigation bar")
                XCTAssertEqual(forms.count, 1, "Require the native Form containing the product editor fields")
                let applicationFrame = app.frame
                let viewport = forms.element(boundBy: 0).frame.intersection(applicationFrame)
                var upper = max(viewport.minY, editorBars.element(boundBy: 0).frame.maxY) + 12
                let band = app.otherElements["task144.controlled.editor.band"]
                if band.exists { upper = max(upper, band.frame.maxY + 12) }
                var lower = viewport.maxY - 12
                let keyboard = app.keyboards.firstMatch
                if keyboard.exists {
                    // AX keyboard.frame omits the rounded native keyboard edge.
                    // Reuse the existing Name helper's accessory-safe Form margin.
                    let accessoryReserve = max(44, applicationFrame.height * 0.08)
                    lower = min(lower, keyboard.frame.minY - accessoryReserve - 12)
                }
                let assistant = app.otherElements["SystemInputAssistantView"]
                if assistant.exists {
                    let covered = assistant.frame.intersection(viewport)
                    if covered.width > 0 && covered.height > 0 { lower = min(lower, covered.minY - 12) }
                }
                guard viewport.width > 48 && lower > upper + 16
                    && [viewport.minX, upper, lower].allSatisfy({ $0.isFinite }) else { break }
                let present = element.exists
                let frame = present ? element.frame : CGRect.null
                let hasTargetFrame = present && frame.width > 0 && frame.height > 0
                    && [frame.minX, frame.maxX, frame.minY, frame.maxY].allSatisfy { $0.isFinite }
                let inside = hasTargetFrame && frame.minY >= upper && frame.maxY <= lower
                if inside && element.isHittable { break }
                // A whole-app fling overshot Stock, then the reverse fling
                // overshot back. Move only toward this actual usable Form band.
                var upward = !swipeDown
                if hasTargetFrame {
                    if frame.minY < upper { upward = false }
                    else if frame.maxY > lower { upward = true }
                }
                let displacement = hasTargetFrame && !inside ? abs(frame.midY - (upper + lower) / 2) : (lower - upper) / 2
                let travel = min((lower - upper) / 2, displacement)
                guard travel > 0 && travel.isFinite else { break }
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(
                    CGVector(dx: viewport.minX + 24 - applicationFrame.minX,
                        dy: (upward ? lower : upper) - applicationFrame.minY))
                start.press(forDuration: 0, thenDragTo: start.withOffset(CGVector(dx: 0, dy: upward ? -travel : travel)),
                    withVelocity: .slow, thenHoldForDuration: 0.2)
                attempts += 1
                continue
            }
            let coveredByNavigation = element.exists && app.navigationBars.firstMatch.exists
                && element.frame.midY <= app.navigationBars.firstMatch.frame.maxY + 20
            if element.isHittable && !coveredByNavigation { break }
            if swipeDown || coveredByNavigation {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
            attempts += 1
        }
        XCTAssertTrue(element.isHittable)
    }
}
