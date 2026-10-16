import XCTest

final class AtlasUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingTapsEveryControl() {
        let app = launch("--debug-onboarding")
        let skip = find(app, "onboarding-skip", "Skip", timeout: 20)
        XCTAssertTrue(skip.exists, app.debugDescription)
        skip.tap()
        let details = app.buttons["onboarding-details"]
        if details.waitForExistence(timeout: 4) {
            details.tap()
            details.tap()
        }
        let understand = find(app, "onboarding-understand", "I understand", timeout: 8)
        XCTAssertTrue(understand.exists, app.debugDescription)
        attach(app.screenshot(), name: "onboarding-disclaimer")
        understand.tap()
        XCTAssertTrue(find(app, "search-pill", "Search", timeout: 20).exists, app.debugDescription)
    }

    func testOnboardingContinueThenUnderstand() {
        let app = launch("--debug-onboarding")
        let cont = find(app, "onboarding-continue", "Continue", timeout: 20)
        XCTAssertTrue(cont.exists, app.debugDescription)
        cont.tap()
        let next = find(app, "onboarding-continue", "Continue", timeout: 4)
        if next.exists { next.tap() }
        let understand = find(app, "onboarding-understand", "I understand", timeout: 8)
        XCTAssertTrue(understand.exists, app.debugDescription)
        understand.tap()
        XCTAssertTrue(find(app, "search-pill", "Search", timeout: 20).exists)
    }

    func testMapTabsSearchFiltersLayersSettingsAndLocation() {
        let app = launch("--debug-santa-fe-plaza", "--debug-card=full")
        let search = find(app, "search-pill", "Search", timeout: 25)
        XCTAssertTrue(search.exists, app.debugDescription)
        attach(app.screenshot(), name: "map-plaza")

        find(app, "filters-button", "Filters", timeout: 8).tap()
        XCTAssertTrue(app.otherElements["filters-sheet"].waitForExistence(timeout: 8)
            || app.navigationBars["Filters"].waitForExistence(timeout: 8))
        let filterRows = [
            ("filter-row-catholic", "Catholic sites"),
            ("filter-row-churches", "Churches and shrines"),
            ("filter-row-trails", "Trails"),
            ("filter-row-public-land", "Public land"),
            ("filter-row-parks", "Parks"),
            ("filter-row-open-now", "Open now"),
        ]
        for (identifier, title) in filterRows {
            if !app.buttons[identifier].exists && !app.staticTexts[title].exists {
                app.swipeUp()
            }
            let row = app.buttons[identifier].exists ? app.buttons[identifier] : app.staticTexts[title]
            XCTAssertTrue(row.waitForExistence(timeout: 4), identifier)
            row.tap()
        }
        attach(app.screenshot(), name: "filters-sheet")
        if app.buttons["reset-filters"].waitForExistence(timeout: 2) {
            app.buttons["reset-filters"].tap()
        }
        tapDone(app, identifier: "filters-done", title: "Done")

        find(app, "layers-button", "More map options", timeout: 8).tap()
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

        find(app, "location-button", "Location").tapIfExists()
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 8))
        searchTab.tap()
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
        XCTAssertTrue(find(app, "search-pill", "Search", timeout: 8).exists)
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
        XCTAssertTrue(find(app, "settings-build", "Build", timeout: 8).exists, app.debugDescription)
        tapTab(app, "Map")
        XCTAssertTrue(find(app, "filters-button", "Filters", timeout: 25).exists, app.debugDescription)
        attach(app.screenshot(), name: "catholic-filter")
    }

    func testFiltersOpenFromLaunchArgument() {
        let app = launch("--debug-santa-fe-plaza", "--debug-show-filters", "--debug-filter=food")
        XCTAssertTrue(
            app.navigationBars["Filters"].waitForExistence(timeout: 25)
                || app.otherElements["filters-sheet"].waitForExistence(timeout: 8)
        )
        app.swipeUp()
        XCTAssertTrue(find(app, "filter-row-food", "Food and rest", timeout: 8).exists, app.debugDescription)
        attach(app.screenshot(), name: "filters-food")
        tapDone(app, identifier: "filters-done", title: "Done")
        XCTAssertTrue(find(app, "search-pill", "Search", timeout: 8).exists)
    }

    func testSearchTownOpensTheMap() {
        let app = launch("--debug-santa-fe-plaza", "--debug-search=Taos")
        let hit = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Taos'")).firstMatch
        var found = hit.waitForExistence(timeout: 8)
        if !found {
            for _ in 0..<6 {
                app.swipeUp()
                if app.buttons.matching(NSPredicate(format: "label CONTAINS 'Taos'")).firstMatch.exists {
                    found = true
                    break
                }
            }
        }
        XCTAssertTrue(found, app.debugDescription)
        attach(app.screenshot(), name: "search-taos")
        hit.tap()
        XCTAssertTrue(find(app, "search-pill", "Search", timeout: 8).exists)
    }

    func testSettingsTogglesAppearanceAndWelcome() {
        let app = launch("--debug-tab=settings")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 25))
        toggle(app, "toggle-terrain")
        toggle(app, "toggle-parcels")
        if app.switches["toggle-online-tiles"].waitForExistence(timeout: 3) {
            app.switches["toggle-online-tiles"].tap()
            if app.alerts["Online tiles"].waitForExistence(timeout: 4) {
                app.alerts["Online tiles"].buttons["Use OpenFreeMap"].tap()
            }
        }
        let picker = app.pickers["appearance-picker"]
        if picker.waitForExistence(timeout: 3) {
            picker.tap()
            if app.buttons["Dark"].waitForExistence(timeout: 3) {
                app.buttons["Dark"].tap()
            }
        } else if app.buttons["Match iPhone"].waitForExistence(timeout: 2) {
            app.buttons["Match iPhone"].tap()
            if app.buttons["Dark"].waitForExistence(timeout: 3) {
                app.buttons["Dark"].tap()
            }
        }
        attach(app.screenshot(), name: "settings-appearance")
        let welcome = find(app, "welcome-again", "Show welcome screens again", timeout: 8)
        if !welcome.exists { app.swipeUp() }
        let welcomeRow = find(app, "welcome-again", "Show welcome screens again", timeout: 6)
        XCTAssertTrue(welcomeRow.exists, app.debugDescription)
        welcomeRow.tap()
        XCTAssertTrue(find(app, "onboarding-continue", "Continue", timeout: 8).exists, app.debugDescription)
        attach(app.screenshot(), name: "welcome-again")
    }

    func testCatholicSitesChipShowsRealPins() {
        let app = launch("--debug-center=35.686504,-105.93624")
        find(app, "filters-button", "Filters", timeout: 25).tap()
        let row = app.buttons["filter-row-catholic"].exists ? app.buttons["filter-row-catholic"] : app.staticTexts["Catholic sites"]
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()
        tapDone(app, identifier: "filters-done", title: "Done")
        let count = waitForPins(app, timeout: 30)
        saveLayerShot(app, "catholic-sites")
        XCTAssertGreaterThan(count, 0, "Catholic sites showed \(count) pins")
    }

    func testEachLandmarkLayerShowsARealPin() {
        let layers: [(String, String, String)] = [
            ("catholic", "35.686504", "-105.93624"),
            ("chapel", "35.685617", "-105.937454"),
            ("worship", "35.036992", "-106.681415"),
            ("shrine", "35.683078", "-105.940548"),
            ("viewpoint", "35.872877", "-106.233148"),
            ("museum", "36.685019", "-105.889458"),
            ("parking", "35.205222", "-106.661153"),
            ("water", "35.849528", "-106.62973"),
            ("trailhead", "36.402862", "-106.872348"),
            ("landmark", "35.689653", "-105.938556"),
        ]
        for (role, lat, lon) in layers {
            let app = launch("--debug-center=\(lat),\(lon)")
            find(app, "layers-button", "More map options", timeout: 25).tap()
            let toggle = app.descendants(matching: .any)["layer-only-\(role)"]
            for _ in 0..<16 where !toggle.isHittable {
                app.swipeUp()
            }
            XCTAssertTrue(toggle.waitForExistence(timeout: 8), role)
            toggle.tap()
            tapDone(app, identifier: "layers-done", title: "Done")
            let count = waitForPins(app, timeout: 30)
            saveLayerShot(app, "layer-\(role)")
            XCTAssertGreaterThan(count, 0, "\(role) showed \(count) pins")
            app.terminate()
        }
    }

    func testDisclaimerScreenshotPath() {
        let app = launch("--debug-disclaimer-details-open")
        XCTAssertTrue(find(app, "onboarding-understand", "I understand", timeout: 20).exists, app.debugDescription)
        attach(app.screenshot(), name: "disclaimer-details")
    }

    private func find(_ app: XCUIApplication, _ identifier: String, _ label: String, timeout: TimeInterval = 4) -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for query in [
                app.descendants(matching: .any)[identifier],
                app.descendants(matching: .any)[label],
            ] {
                if query.exists { return query }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        let fallback = app.descendants(matching: .any)[identifier]
        return fallback.exists ? fallback : app.descendants(matching: .any)[label]
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

    private func waitForPins(_ app: XCUIApplication, timeout: TimeInterval) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var count = 0
        while Date() < deadline {
            let element = app.descendants(matching: .any)["place-pin-count"]
            if element.exists {
                count = Int(element.label) ?? 0
                if count > 0 { return count }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return count
    }

    private func saveLayerShot(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        attach(shot, name: name)
        let override = ProcessInfo.processInfo.environment["PIN_SCREENSHOT_DIR"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_PIN_SCREENSHOT_DIR"]
        let directory = (override?.isEmpty == false) ? override! : "/tmp/layer-screenshots"
        let url = URL(fileURLWithPath: directory, isDirectory: true).appendingPathComponent("\(name).png")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: url)
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
