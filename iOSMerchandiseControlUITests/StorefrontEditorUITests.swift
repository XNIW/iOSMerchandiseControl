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
        app.buttons["storefront.action.preview"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["storefront.preview.public-only"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["OK"].firstMatch.tap()

        let saveDraft = app.buttons["storefront.action.save-draft"]
        reveal(saveDraft, in: app, swipeDown: true)
        XCTAssertTrue(saveDraft.isEnabled)
        app.buttons["storefront.action.save-draft"].tap()
        let conflict = app.descendants(matching: .any)["storefront.editor.conflict"]
        var conflictScrollAttempts = 0
        while !conflict.exists, conflictScrollAttempts < 12 {
            app.swipeDown()
            conflictScrollAttempts += 1
        }
        XCTAssertTrue(conflict.exists)
    }

    func testRapidFilterSwitchStartsNewRequestAndAllClearsLoading() throws {
        let app = XCUIApplication()
        app.launchEnvironment["TASK143_STOREFRONT_UI_TEST"] = "1"
        app.launch()
        let published = app.buttons["storefront.filter.published"]
        XCTAssertTrue(published.waitForExistence(timeout: 8))
        published.tap()
        let result = app.staticTexts["storefront.filter.result"]
        let loading = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "loading"), object: result)
        XCTAssertEqual(XCTWaiter.wait(for: [loading], timeout: 3), .completed)
        app.buttons["storefront.filter.draft"].tap()
        let draft = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "draft:1"), object: result)
        XCTAssertEqual(XCTWaiter.wait(for: [draft], timeout: 3), .completed)
        app.buttons["storefront.filter.all"].tap()
        let all = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "all:0"), object: result)
        XCTAssertEqual(XCTWaiter.wait(for: [all], timeout: 3), .completed)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testFieldsCannotBeEditedWhileMutationAckIsPending() throws {
        let app = XCUIApplication()
        app.launchEnvironment["TASK143_STOREFRONT_UI_TEST"] = "1"
        app.launchEnvironment["TASK144_MUTATION_UI_TEST"] = "1"
        app.launch()
        let disclosure = app.descendants(matching: .any)["storefront.editor.disclosure"].firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 8))
        disclosure.tap()
        let publicName = app.textFields["storefront.editor.public-name"]
        XCTAssertTrue(publicName.waitForExistence(timeout: 5))
        XCTAssertTrue(publicName.isEnabled)
        let save = app.buttons["storefront.action.save-draft"]
        reveal(save, in: app)
        save.tap()
        var attempts = 0
        while !publicName.exists, attempts < 5 { app.swipeDown(); attempts += 1 }
        XCTAssertTrue(publicName.exists)
        let disabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: publicName)
        XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 3), .completed)
        app.buttons["storefront.filter.draft"].tap()
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
