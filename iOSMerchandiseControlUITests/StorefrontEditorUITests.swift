import XCTest

final class StorefrontEditorUITests: XCTestCase {
    func testFiltersAndUnifiedEditorRemainAccessibleAtLargeDynamicType() throws {
        let app = XCUIApplication()
        app.launchEnvironment["TASK143_STOREFRONT_UI_TEST"] = "1"
        app.launchArguments += [
            "-AppleLanguages", "(it)",
            "-AppleLocale", "it_IT",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()

        let allFilter = app.buttons["storefront.filter.all"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["storefront.filter.published"].exists)
        XCTAssertTrue(app.buttons["storefront.filter.conflict"].exists)

        let disclosure = app.descendants(matching: .any)["storefront.editor.disclosure"].firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 8))
        disclosure.tap()

        let publicName = app.textFields["storefront.editor.public-name"]
        XCTAssertTrue(publicName.waitForExistence(timeout: 5))
        XCTAssertFalse((publicName.label).isEmpty)
        let publicPrice = app.textFields["storefront.editor.public-price"]
        reveal(publicPrice, in: app)
        XCTAssertFalse(publicPrice.label.isEmpty)

        let preview = app.buttons["storefront.action.preview"]
        reveal(preview, in: app)
        XCTAssertTrue(preview.isEnabled)
        XCTAssertTrue(app.buttons["storefront.action.save-draft"].exists)
    }

    func testPreviewAndConflictActionsUseRealSavedProduct() throws {
        let app = XCUIApplication()
        app.launchEnvironment["TASK143_STOREFRONT_UI_TEST"] = "1"
        app.launchArguments += ["-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()

        let disclosure = app.descendants(matching: .any)["storefront.editor.disclosure"].firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 8))
        disclosure.tap()

        let preview = app.buttons["storefront.action.preview"]
        reveal(preview, in: app)
        XCTAssertTrue(preview.isEnabled)
        app.navigationBars["Storefront UI Test"].tap()
        app.buttons["storefront.action.preview"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["storefront.preview.public-only"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["OK"].firstMatch.tap()

        let saveDraft = app.buttons["storefront.action.save-draft"]
        reveal(saveDraft, in: app, swipeDown: true)
        XCTAssertTrue(saveDraft.isEnabled)
        app.navigationBars["Storefront UI Test"].tap()
        app.buttons["storefront.action.save-draft"].tap()
        let conflict = app.descendants(matching: .any)["storefront.editor.conflict"]
        var conflictScrollAttempts = 0
        while !conflict.exists, conflictScrollAttempts < 12 {
            app.swipeDown()
            conflictScrollAttempts += 1
        }
        XCTAssertTrue(conflict.exists)
    }

    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        swipeDown: Bool = false
    ) {
        var attempts = 0
        while !element.isHittable, attempts < 12 {
            swipeDown ? app.swipeDown() : app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.isHittable)
    }
}
