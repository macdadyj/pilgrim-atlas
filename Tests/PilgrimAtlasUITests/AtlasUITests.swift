import XCTest

final class AtlasUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingTapsEveryControl() {
        let app = launch("--debug-onboarding")
        XCTAssertTrue(app.otherElements["onboarding"].waitForExistence(timeout: 20))
        let skip = app.buttons["onboarding-skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8))
        skip.tap()
        let details = app.buttons["onboarding-details"]
        if details.waitForExistence(timeout: 4) {
            details.tap()
            details.tap()
        }
        let understand = app.buttons["onboarding-understand"]
        XCTAssertTrue(understand.waitForExistence(timeout: 8))
        attach(app.screenshot(), name: "onboarding-disclaimer")
        understand.tap()
        XCTAssertTrue(app.buttons["search-pill"].waitForExistence(timeout: 20))
    }

    func testOnboardingContinueThenUnderstand() {
        let app = launch("--debug-onboarding")
        let cont = app.buttons["onboarding-continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 20))
        cont.tap()
        if app.buttons["onboarding-continue"].waitForExistence(timeout: 4) {
            app.buttons["onboarding-continue"].tap()
        }
        XCTAssertTrue(app.buttons["onboarding-understand"].waitForExistence(timeout: 8))
        app.buttons["onboarding-understand"].tap()
        XCTAssertTrue(app.buttons["search-pill"].waitForExistence(timeout: 20))
    }

    func testMapTabsSearchFiltersLayersSettingsAndLocation() {
        let app = launch("--debug-santa-fe-plaza", "--debug-card=full")
        XCTAssertTrue(app.buttons["search-pill"].waitForExistence(timeout: 25))
        attach(app.screenshot(), name: "map-plaza")

        app.buttons["filters-button"].tap()
        XCTAssertTrue(app.otherElements["filters-sheet"].waitForExistence(timeout: 8)
            || app.navigationBars["Filters"].waitForExistence(timeout: 8))
        for identifier in [
            "filter-row-catholic",
            "filter-row-churches",
            "filter-row-trails",
            "filter-row-public-land",
            "filter-row-parks",
            "filter-row-food",
            "filter-row-open-now",
        ] {
            let row = app.buttons[identifier].firstMatch.exists ? app.buttons[identifier] : app.otherElements[identifier]
            XCTAssertTrue(row.waitForExistence(timeout: 4), identifier)
            if identifier != "filter-row-food" {
                row.tap()
            }
        }
        attach(app.screenshot(), name: "filters-sheet")
        if app.buttons["reset-filters"].waitForExistence(timeout: 2) {
            app.buttons["reset-filters"].tap()
        }
        tapDone(app, identifier: "filters-done", title: "Done")

        app.buttons["layers-button"].tap()
        XCTAssertTrue(app.navigationBars["More map options"].waitForExistence(timeout: 8))
        toggle(app, "toggle-terrain")
        toggle(app, "toggle-terrain")
        toggle(app, "toggle-parcels")
        toggle(app, "toggle-parcels")
        toggle(app, "toggle-hide-hours")
        toggle(app, "toggle-hide-hours")
        if app.switches["toggle-online-tiles"].waitForExistence(timeout: 2) {
            app.switches["toggle-online-tiles"].tap()
            if app.alerts["Online tiles"].waitForExistence(timeout: 4) {
                app.alerts["Online tiles"].buttons["Keep offline"].tap()
            }
        }
        attach(app.screenshot(), name: "layers-sheet")
        if app.buttons["licenses-row"].waitForExistence(timeout: 3) {
            app.buttons["licenses-row"].tap()
            _ = app.otherElements["licenses-screen"].waitForExistence(timeout: 4)
                || app.navigationBars["Licenses"].waitForExistence(timeout: 4)
            attach(app.screenshot(), name: "licenses")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        tapDone(app, identifier: "layers-done", title: "Done")

        app.buttons["location-button"].tap()
        app.buttons["search-pill"].tap()
        XCTAssertTrue(
            app.otherElements["search-screen"].waitForExistence(timeout: 8)
                || app.navigationBars.element.waitForExistence(timeout: 8)
        )
        attach(app.screenshot(), name: "search-tab")
        if app.buttons["search-filters"].waitForExistence(timeout: 4) {
            app.buttons["search-filters"].tap()
            tapDone(app, identifier: "filters-done", title: "Done")
        }

        tapTab(app, "Settings")
        XCTAssertTrue(
            app.otherElements["settings-screen"].waitForExistence(timeout: 8)
                || app.navigationBars["Settings"].waitForExistence(timeout: 8)
        )
        XCTAssertTrue(
            app.staticTexts["settings-build"].waitForExistence(timeout: 6)
                || app.staticTexts.matching(NSPredicate(format: "identifier == %@", "settings-build")).firstMatch.waitForExistence(timeout: 2)
                || app.staticTexts["Build"].waitForExistence(timeout: 4)
        )
        attach(app.screenshot(), name: "settings-build")
        if app.buttons["licenses-row"].waitForExistence(timeout: 3) {
            app.buttons["licenses-row"].tap()
            _ = app.navigationBars["Licenses"].waitForExistence(timeout: 4)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        tapTab(app, "Map")
        XCTAssertTrue(app.buttons["search-pill"].waitForExistence(timeout: 8))
        if app.otherElements["nearby-card"].waitForExistence(timeout: 4) {
            app.otherElements["nearby-grabber"].tap()
        }
        attach(app.screenshot(), name: "map-after-tabs")
    }

    func testSearchEmptyAndCathedral() {
        let app = launch("--debug-santa-fe-plaza", "--debug-search=zzzz-no-such-place")
        XCTAssertTrue(
            app.otherElements["search-no-matches"].waitForExistence(timeout: 20)
                || app.staticTexts["No matches in the offline pack"].waitForExistence(timeout: 8)
        )
        attach(app.screenshot(), name: "search-empty")
        let field = app.searchFields.firstMatch
        if field.waitForExistence(timeout: 4) {
            field.tap()
            field.buttons["Clear text"].tapIfExists()
            field.typeText("Cathedral Basilica of St. Francis")
        }
    }

    func testPlaceSheet() {
        let app = launch("--debug-santa-fe-plaza", "--debug-open-place=Loretto Chapel")
        XCTAssertTrue(
            app.otherElements["place-sheet"].waitForExistence(timeout: 25)
                || app.navigationBars.element.waitForExistence(timeout: 12)
        )
        attach(app.screenshot(), name: "loretto-sheet")
        tapDone(app, identifier: "place-done", title: "Done")
    }

    func testTrailSheet() {
        let app = launch("--debug-santa-fe-plaza", "--debug-open-place=Skyline Trail")
        XCTAssertTrue(
            app.otherElements["trail-sheet"].waitForExistence(timeout: 25)
                || app.staticTexts["Trail line"].waitForExistence(timeout: 12)
        )
        attach(app.screenshot(), name: "skyline-sheet")
        tapDone(app, identifier: "trail-done", title: "Done")
    }

    func testPlacesPicker() {
        let app = launch("--debug-santa-fe-plaza", "--debug-show-places-picker")
        XCTAssertTrue(
            app.navigationBars["Places here"].waitForExistence(timeout: 25)
                || app.otherElements["places-picker"].waitForExistence(timeout: 8)
        )
        attach(app.screenshot(), name: "places-picker")
        tapDone(app, identifier: "picker-done", title: "Done")
    }

    func testOutsideCoverageBanner() {
        let app = launch("--debug-outside-coverage")
        XCTAssertTrue(
            app.otherElements["outside-coverage-banner"].waitForExistence(timeout: 25)
                || app.staticTexts["This view is outside the offline pack."].waitForExistence(timeout: 12)
        )
        attach(app.screenshot(), name: "outside-coverage")
        if app.buttons["jump-nearest-mapped"].waitForExistence(timeout: 4) {
            app.buttons["jump-nearest-mapped"].tap()
        }
    }

    func testCatholicFilterAndSettingsTab() {
        let app = launch("--debug-santa-fe-plaza", "--debug-filter=catholic,open-now", "--debug-tab=settings")
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 25)
                || app.otherElements["settings-screen"].waitForExistence(timeout: 8)
        )
        XCTAssertTrue(app.staticTexts["Build"].waitForExistence(timeout: 6))
        tapTab(app, "Map")
        XCTAssertTrue(app.buttons["filters-button"].waitForExistence(timeout: 8))
        attach(app.screenshot(), name: "catholic-filter")
    }

    func testDisclaimerScreenshotPath() {
        let app = launch("--debug-disclaimer-details-open")
        XCTAssertTrue(app.buttons["onboarding-understand"].waitForExistence(timeout: 20))
        attach(app.screenshot(), name: "disclaimer-details")
    }

    private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func tapTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab \(name)")
        tab.tap()
    }

    private func tapDone(_ app: XCUIApplication, identifier: String, title: String) {
        if app.buttons[identifier].waitForExistence(timeout: 3) {
            app.buttons[identifier].tap()
            return
        }
        if app.buttons[title].waitForExistence(timeout: 3) {
            app.buttons[title].tap()
        }
    }

    private func toggle(_ app: XCUIApplication, _ identifier: String) {
        let control = app.switches[identifier]
        if control.waitForExistence(timeout: 4) {
            control.tap()
        }
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    func tapIfExists() {
        if exists { tap() }
    }
}
