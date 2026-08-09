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
            "TASK131_INITIAL_TAB": "database"
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
        let newProductButton = app.buttons["New product"].firstMatch
        XCTAssertTrue(newProductButton.waitForExistence(timeout: 5))
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
        while !element.isHittable, attempts < 6 {
            if swipeDown {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
            attempts += 1
        }
        XCTAssertTrue(element.isHittable)
    }
}
