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
}
