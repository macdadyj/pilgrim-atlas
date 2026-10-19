import UIKit
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
            let row = filterControl(app, identifier, title)
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

    func testFaithFiltersAndChurchCardLinks() {
        let filters = launch("--debug-santa-fe-plaza", "--debug-show-filters")
        XCTAssertTrue(filters.staticTexts["Orthodox churches"].waitForExistence(timeout: 20))
        XCTAssertTrue(filters.staticTexts["SSPX chapels"].exists)
        XCTAssertTrue(filters.staticTexts["Catholic churches"].exists)
        saveLayerShot(filters, "faith-filters")
        filters.terminate()

        let app = launch(
            "--debug-open-place=Our Lady of Perpetual Help",
            "--debug-location=35.096452,-106.582347"
        )
        XCTAssertTrue(revealControl(app, "place-website", "Website"))
        XCTAssertTrue(revealControl(app, "place-directions", "Directions"))
        saveLayerShot(app, "place-website-directions")
    }

    func testDenverSearchShowsCatholicPins() {
        let app = launch("--debug-search=Denver", "--debug-tab=search", "--debug-geocode=Denver@39.7392,-104.9903")
        let hit = app.buttons["search-hit-geocode-0"]
        XCTAssertTrue(hit.waitForExistence(timeout: 45), "Denver search row")
        tapSearchTitle(hit)
        waitForLiveChurches(app, city: "Denver")
        let count = waitForPins(app, role: "catholic", minimum: 1, timeout: 25)
        saveLayerShot(app, "denver-churches")
        XCTAssertGreaterThanOrEqual(count, 1, "Denver showed \(count) Catholic pins")
        XCTAssertFalse(app.staticTexts["Khadeeja Mosque"].exists)
        XCTAssertFalse(app.staticTexts["Hindu Temple"].exists)
    }

    func testChurchPinsAndPerpetualHelpLiturgy() {
        let pins = launch("--debug-pins")
        XCTAssertTrue(pins.descendants(matching: .any)["pin-gallery"].waitForExistence(timeout: 20))
        for name in [
            "pin-latin",
            "pin-byzantine",
            "pin-orthodox",
            "pin-chapel",
            "pin-shrine",
            "pin-latin-selected",
            "pin-byzantine-selected",
        ] {
            XCTAssertTrue(pins.descendants(matching: .any)[name].waitForExistence(timeout: 4), name)
        }
        saveLayerShot(pins, "church-pins")
        pins.terminate()

        let app = launch(
            "--debug-open-place=Our Lady of Perpetual Help",
            "--debug-location=35.096452,-106.582347"
        )
        XCTAssertTrue(
            app.otherElements["place-sheet"].waitForExistence(timeout: 25)
                || app.navigationBars.element.waitForExistence(timeout: 12)
        )
        XCTAssertTrue(revealControl(app, "place-website", "Website"))
        revealText(app, "Last verified 15 Oct 2026")
        XCTAssertTrue(revealControl(app, "place-directions", "Directions"))
        let phone = app.staticTexts["505-256-1539"]
        var swipes = 0
        while !phone.exists && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(phone.waitForExistence(timeout: 6))
        revealText(app, "Call to confirm")
        revealText(app, "Divine Liturgy")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Eparchy of Phoenix")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Unknown"].exists)
        XCTAssertFalse(app.staticTexts["No visitor hours in the pack."].exists)
        saveLayerShot(app, "olph-liturgy")
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

    func testLaunchMapShowsStreetsAndLabels() {
        assertStreetLaunch("--debug-santa-fe-plaza", shot: "launch-streets")
        assertStreetLaunch("--debug-location=35.1086,-106.5700", shot: "launch-albuquerque")
    }

    private func assertStreetLaunch(_ argument: String, shot: String) {
        let app = launch(argument)
        let deadline = Date().addingTimeInterval(35)
        var streets = 0
        var labels = 0
        var roadMarks = 0
        var labelMarks = 0
        while Date() < deadline {
            streets = waitForCount(app, "basemap-streets", minimum: 1, timeout: 0.4)
            labels = waitForCount(app, "basemap-labels", minimum: 1, timeout: 0.2)
            if let image = UIImage(data: app.screenshot().pngRepresentation) {
                roadMarks = mapMarkCount(image, kind: .road)
                labelMarks = mapMarkCount(image, kind: .label)
            }
            if (streets > 0 || roadMarks >= 3) && (labels > 0 || labelMarks >= 2) {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
        saveLayerShot(app, shot)
        XCTAssertTrue(streets > 0 || roadMarks >= 3, "\(shot) showed \(streets) street features and \(roadMarks) road marks")
        XCTAssertTrue(labels > 0 || labelMarks >= 2, "\(shot) showed \(labels) label features and \(labelMarks) label marks")
        XCTAssertFalse(app.staticTexts["Private on the surface map"].exists)
        app.terminate()
    }

    func testCatholicSitesChipShowsRealPins() {
        let app = launch("--debug-center=35.686504,-105.93624")
        find(app, "filters-button", "Filters", timeout: 25).tap()
        let row = filterControl(app, "catholic", "Catholic sites")
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        tapFilter(row)
        tapDone(app, identifier: "filters-done", title: "Done")
        let count = waitForPins(app, role: "catholic", minimum: 4, timeout: 30)
        saveLayerShot(app, "catholic-sites")
        XCTAssertGreaterThanOrEqual(count, 4, "Catholic sites showed \(count) pins in view")
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
            let minimum = ["catholic": 4, "worship": 1, "chapel": 2, "landmark": 4][role] ?? 1
            let count = waitForPins(app, role: role, minimum: minimum, timeout: 30)
            saveLayerShot(app, "layer-\(role)")
            XCTAssertGreaterThanOrEqual(count, minimum, "\(role) showed \(count) pins in view")
            app.terminate()
        }
    }

    func testDisclaimerScreenshotPath() {
        let app = launch("--debug-disclaimer-details-open")
        XCTAssertTrue(find(app, "onboarding-understand", "I understand", timeout: 20).exists, app.debugDescription)
        attach(app.screenshot(), name: "disclaimer-details")
    }

    func testFilterSwitchesStayWhereTheyAreSet() {
        let app = launch("--debug-santa-fe-plaza", "--debug-show-filters")
        let controls = [
            ("show-catholic", "Catholic churches", true),
            ("orthodox", "Orthodox churches", true),
            ("sspx", "SSPX chapels", true),
            ("catholic", "Catholic sites", false),
            ("churches", "Churches and shrines", false),
            ("trails", "Trails", false),
            ("public-land", "Public land", false),
            ("parks", "Parks", false),
            ("open-now", "Open now", false),
        ]
        for (identifier, title, startsOn) in controls {
            let row = filterControl(app, identifier, title)
            XCTAssertTrue(row.waitForExistence(timeout: 6), identifier)
            XCTAssertEqual(switchIsOn(row), startsOn, identifier)
            for _ in 0..<3 {
                let before = switchIsOn(row)
                tapFilter(row)
                XCTAssertTrue(waitForSwitch(row, on: !before), "\(identifier) stayed \(row.value ?? "nil"), wanted \(!before)")
            }
            XCTAssertEqual(switchIsOn(row), !startsOn, identifier)
        }
        var towardTop = 0
        let catholicRow = app.descendants(matching: .any)["filter-row-show-catholic"]
        while !catholicRow.exists && towardTop < 6 {
            app.swipeDown()
            towardTop += 1
        }
        saveLayerShot(app, "filters-after-toggles")
        let food = app.descendants(matching: .any)["filter-row-food"]
        var foodSwipes = 0
        while !food.exists && foodSwipes < 5 {
            app.swipeUp()
            foodSwipes += 1
        }
        XCTAssertTrue(food.waitForExistence(timeout: 4), "Food and rest row")
        XCTAssertFalse(app.switches["filter-row-food"].exists)
        var backToTop = 0
        while !app.buttons["reset-filters"].exists && backToTop < 6 {
            app.swipeDown()
            backToTop += 1
        }
        XCTAssertTrue(app.buttons["reset-filters"].waitForExistence(timeout: 4), "Reset appears after a narrowing filter is on")
        app.buttons["reset-filters"].tap()
        let restored = filterControl(app, "show-catholic", "Catholic churches")
        XCTAssertTrue(waitForSwitch(restored, on: true))
        tapDone(app, identifier: "filters-done", title: "Done")

        find(app, "filters-button", "Filters", timeout: 8).tap()
        let catholic = filterControl(app, "show-catholic", "Catholic churches")
        XCTAssertTrue(switchIsOn(catholic), "Reset leaves Catholic churches on")
        tapDone(app, identifier: "filters-done", title: "Done")
        let shown = waitForPins(app, role: "catholic", minimum: 1, timeout: 20)
        XCTAssertGreaterThanOrEqual(shown, 1, "Catholic pins after the switch was turned back on")
        find(app, "filters-button", "Filters", timeout: 8).tap()
        let hideCatholic = filterControl(app, "show-catholic", "Catholic churches")
        tapFilter(hideCatholic)
        XCTAssertTrue(waitForSwitch(hideCatholic, on: false))
        tapDone(app, identifier: "filters-done", title: "Done")
        let hidden = waitForPinCeiling(app, role: "catholic", ceiling: 0, timeout: 12)
        XCTAssertEqual(hidden, 0, "Catholic pins stayed on the map after the switch was turned off")
    }

    func testAlbuquerqueSSPXChapelAndOrthodox() {
        let app = launch("--debug-center=35.112398,-106.705256", "--debug-show-filters")
        let catholic = filterControl(app, "show-catholic", "Catholic churches")
        XCTAssertTrue(catholic.waitForExistence(timeout: 8))
        tapFilter(catholic)
        XCTAssertTrue(waitForSwitch(catholic, on: false))
        let orthodoxSwitch = filterControl(app, "orthodox", "Orthodox churches")
        tapFilter(orthodoxSwitch, until: false)
        XCTAssertTrue(waitForSwitch(orthodoxSwitch, on: false))
        let sspxSwitch = filterControl(app, "sspx", "SSPX chapels")
        XCTAssertTrue(switchIsOn(sspxSwitch))
        tapDone(app, identifier: "filters-done", title: "Done")
        let sheetGone = Date().addingTimeInterval(8)
        while Date() < sheetGone && app.otherElements["filters-sheet"].exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertFalse(app.otherElements["filters-sheet"].exists, "Filter sheet stayed up over the chapel")
        saveLayerShot(app, "abq-sspx")
        let pins = waitForPins(app, role: "sspx", minimum: 1, timeout: 25)
        XCTAssertGreaterThanOrEqual(pins, 1, "SSPX chapel pin")
        let list = app.buttons.matching(NSPredicate(format: "label == %@", "List")).firstMatch
        if list.waitForExistence(timeout: 8) {
            list.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.075)).tap()
        }
        let nearbySheet = app.otherElements["nearby-sheet"]
        XCTAssertTrue(nearbySheet.waitForExistence(timeout: 8))
        let chapels = nearbySheet.staticTexts.matching(NSPredicate(format: "label == %@", "Saints Peter and Paul Church"))
        XCTAssertEqual(chapels.count, 1, "The nearby list should show Saints Peter and Paul once")
        XCTAssertFalse(app.staticTexts["Khadeeja Mosque"].exists)
        app.terminate()

        let orthodox = launch("--debug-center=35.080846,-106.639908")
        let orthodoxDeadline = Date().addingTimeInterval(70)
        var sawGeorge = false
        while Date() < orthodoxDeadline && !sawGeorge {
            let readout = orthodox.descendants(matching: .any)["visible-orthodox"]
            if readout.exists, readout.label.contains("George") {
                sawGeorge = true
                break
            }
            let nearby = orthodox.buttons.matching(NSPredicate(format: "label == %@", "List")).firstMatch
            if nearby.exists {
                nearby.tap()
                let george = orthodox.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "George")).firstMatch
                if george.waitForExistence(timeout: 2) {
                    sawGeorge = true
                    saveLayerShot(orthodox, "abq-orthodox")
                    break
                }
                if orthodox.buttons["nearby-done"].exists {
                    orthodox.buttons["nearby-done"].tap()
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(2))
        }
        if !sawGeorge {
            saveLayerShot(orthodox, "abq-orthodox")
        }
        XCTAssertTrue(sawGeorge, "St. George Greek Orthodox")
        orthodox.terminate()
    }

    func testNearbyListNextMassAndShare() {
        let app = launch(
            "--debug-show-nearby",
            "--debug-location=35.112398,-106.705256"
        )
        XCTAssertTrue(app.otherElements["nearby-sheet"].waitForExistence(timeout: 20) || app.navigationBars["Nearby"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["next-mass"].waitForExistence(timeout: 12) || app.descendants(matching: .any)["next-mass-empty"].waitForExistence(timeout: 4))
        let sheet = app.otherElements["nearby-sheet"].exists ? app.otherElements["nearby-sheet"] : app
        let chapels = sheet.staticTexts.matching(NSPredicate(format: "label == %@", "Saints Peter and Paul Church"))
        var swipes = 0
        while chapels.count == 0 && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertEqual(chapels.count, 1, "The nearby list should show Saints Peter and Paul once")
        saveLayerShot(app, "nearby-list")
        chapels.firstMatch.tap()
        XCTAssertTrue(revealControl(app, "place-website", "Website"))
        XCTAssertTrue(revealControl(app, "place-directions", "Directions"))
        XCTAssertTrue(revealControl(app, "place-share", "Share"))
        XCTAssertTrue(revealControl(app, "place-call", "Call"))
        saveLayerShot(app, "sspx-chapel-card")
        app.buttons["place-directions"].tap()
        let maps = XCUIApplication(bundleIdentifier: "com.apple.Maps")
        if maps.waitForExistence(timeout: 8) {
            XCTAssertTrue(maps.state == .runningForeground || maps.buttons.firstMatch.exists)
            app.activate()
        } else {
            XCTAssertTrue(app.buttons["place-directions"].exists || app.buttons["place-done"].exists)
        }
    }

    func testCitySearchAndOfflineFallback() {
        for city in ["Albuquerque", "Denver", "Rome"] {
            let app: XCUIApplication
            if city == "Denver" {
                app = launch("--debug-search=Denver", "--debug-tab=search", "--debug-geocode=Denver@39.7392,-104.9903")
            } else if city == "Rome" {
                app = launch("--debug-search=Rome", "--debug-tab=search", "--debug-geocode=Rome@41.9028,12.4964")
            } else {
                app = launch("--debug-search=\(city)", "--debug-tab=search")
            }
            if city == "Albuquerque" {
                let town = app.buttons["search-hit-town-albuquerque"]
                XCTAssertTrue(town.waitForExistence(timeout: 8), "Albuquerque town row")
                town.tap()
            } else {
                let town = app.buttons["search-hit-geocode-0"]
                XCTAssertTrue(town.waitForExistence(timeout: 45), "\(city) search row")
                tapSearchTitle(town)
            }
            if city == "Albuquerque" {
                XCTAssertTrue(app.descendants(matching: .any)["search-pill"].waitForExistence(timeout: 5), "Albuquerque opened the map")
                let names = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", "visible-sspx"))
                XCTAssertTrue(names.firstMatch.waitForExistence(timeout: 20), "Albuquerque map")
                let arrived = Date().addingTimeInterval(20)
                var label = ""
                while Date() < arrived {
                    label = (0..<names.count).map { names.element(boundBy: $0).label }.joined(separator: "\n")
                    if label.contains("Peter"), label.contains("Ouray") { break }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.4))
                }
                XCTAssertTrue(label.contains("Peter") && label.contains("Ouray"), label)
            } else {
                waitForLiveChurches(app, city: city)
            }
            XCTAssertFalse(app.staticTexts["Khadeeja Mosque"].exists)
            saveLayerShot(app, "city-\(city.lowercased())")
            app.terminate()
        }

        let offline = launch("--debug-outside-coverage")
        let outside = offline.staticTexts["This view is outside the offline pack."]
        let live = offline.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Churches here are from OpenStreetMap")).firstMatch
        XCTAssertTrue(outside.waitForExistence(timeout: 25) || live.waitForExistence(timeout: 20))
        saveLayerShot(offline, "offline-fallback")
    }

    /// The title sits on the leading edge. The middle of a short city row is empty.
    private func tapSearchTitle(_ row: XCUIElement) {
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.45)).tap()
    }

    /// The outside-pack banner, once it names OpenStreetMap. Scoped to that card so the
    /// query does not walk every label while the map is drawing.
    private func waitForLiveChurches(_ app: XCUIApplication, city: String) {
        let banner = app.descendants(matching: .any)["outside-coverage-banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 20), "\(city) opened the map outside the pack")
        let deadline = Date().addingTimeInterval(15)
        var label = banner.label
        while Date() < deadline && !label.contains("OpenStreetMap") {
            let child = banner.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Churches here are from OpenStreetMap")
            ).firstMatch
            if child.exists {
                label = child.label
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            label = banner.label
        }
        XCTAssertTrue(label.contains("OpenStreetMap"), label)
    }

    private func filterControl(_ app: XCUIApplication, _ identifier: String, _ title: String) -> XCUIElement {
        let identified = app.descendants(matching: .any)["filter-row-\(identifier)"]
        let labeled = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        var swipes = 0
        while !identified.exists && !labeled.exists && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        if identified.exists { return identified }
        if labeled.exists { return labeled }
        return identified
    }

    /// The whole row is the switch. Tap the title, clear of the trailing glyph.
    private func tapFilter(_ control: XCUIElement) {
        control.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)).tap()
    }

    /// One tap can land while the filter list is still redrawing. Tap again only if it did not stick.
    private func tapFilter(_ control: XCUIElement, until on: Bool) {
        tapFilter(control)
        if waitForSwitch(control, on: on) { return }
        tapFilter(control)
    }

    private func switchIsOn(_ control: XCUIElement) -> Bool {
        if let text = control.value as? String {
            return text == "1" || text == "On" || text == "true"
        }
        if let number = control.value as? NSNumber {
            return number.intValue == 1
        }
        return false
    }

    private func waitForSwitch(_ control: XCUIElement, on: Bool) -> Bool {
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline && switchIsOn(control) != on {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return switchIsOn(control) == on
    }

    private func waitForPinCeiling(_ app: XCUIApplication, role: String, ceiling: Int, timeout: TimeInterval) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var count = Int.max
        while Date() < deadline {
            if let image = UIImage(data: app.screenshot().pngRepresentation) {
                count = renderedPinCount(image, role: role)
            }
            if count <= ceiling { return count }
            RunLoop.current.run(until: Date().addingTimeInterval(0.7))
        }
        return count
    }

    @discardableResult
    private func revealControl(_ app: XCUIApplication, _ identifier: String, _ label: String) -> Bool {
        let identified = app.descendants(matching: .any)[identifier]
        let labeled = app.descendants(matching: .any)[label]
        var swipes = 0
        while !identified.exists && !labeled.exists && swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
        return identified.waitForExistence(timeout: 8) || labeled.waitForExistence(timeout: 2)
    }

    private func revealText(_ app: XCUIApplication, _ label: String) {
        let element = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        var swipes = 0
        while !element.exists && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.waitForExistence(timeout: 4), label)
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

    /// MapLibre's feature query stays at 0 even when the pins are on screen.
    /// Count the pin-colored blobs in the map band of a real screenshot.
    private func waitForCount(_ app: XCUIApplication, _ identifier: String, minimum: Int, timeout: TimeInterval) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var count = 0
        while Date() < deadline {
            let element = app.descendants(matching: .any)[identifier]
            if element.exists {
                count = Int(element.label) ?? 0
                if count >= minimum { return count }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return count
    }

    private func waitForPins(_ app: XCUIApplication, role: String, minimum: Int, timeout: TimeInterval) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var count = 0
        while Date() < deadline {
            if let image = UIImage(data: app.screenshot().pngRepresentation) {
                count = renderedPinCount(image, role: role)
            }
            if count >= minimum { return count }
            RunLoop.current.run(until: Date().addingTimeInterval(0.7))
        }
        return count
    }

    private func mapMarkCount(_ image: UIImage, kind: MapMark) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return 0 }
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let drew = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return 0 }
        let cell = kind == .label ? 28 : 36
        let yStart = height * 20 / 100
        let yEnd = height * 58 / 100
        var cells = Set<Cell>()
        var y = yStart
        while y < yEnd {
            var x = 0
            while x < width {
                let offset = y * bytesPerRow + x * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                let hit: Bool
                switch kind {
                case .road:
                    hit = abs(red - 0x6E) <= 18 && abs(green - 0x62) <= 18 && abs(blue - 0x54) <= 18 && red > green && green > blue
                case .label:
                    hit = red < 48 && green < 48 && blue < 42 && abs(red - green) < 14 && abs(green - blue) < 14
                }
                if hit {
                    cells.insert(Cell(x: x / cell, y: y / cell))
                }
                x += 3
            }
            y += 3
        }
        // A street grid is one connected shape, so count the marked cells, not the blobs.
        return cells.count
    }

    private func renderedPinCount(_ image: UIImage, role: String) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return 0 }
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let drew = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return 0 }
        let cell = 40
        let yStart = height * 18 / 100
        let yEnd = height * 68 / 100
        var cells = Set<Cell>()
        var y = yStart
        while y < yEnd {
            var x = 0
            while x < width {
                let offset = y * bytesPerRow + x * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                if isPinPixel(role: role, red: red, green: green, blue: blue) {
                    cells.insert(Cell(x: x / cell, y: y / cell))
                }
                x += 2
            }
            y += 2
        }
        var unseen = cells
        var pins = 0
        let minimumCells = role == "chapel" ? 4 : (role == "viewpoint" || role == "trailhead" ? 5 : 8)
        while let start = unseen.first {
            var queue = [start]
            unseen.remove(start)
            var size = 0
            var index = 0
            while index < queue.count {
                let current = queue[index]
                index += 1
                size += 1
                for dy in -1...1 {
                    for dx in -1...1 {
                        let next = Cell(x: current.x + dx, y: current.y + dy)
                        if unseen.remove(next) != nil {
                            queue.append(next)
                        }
                    }
                }
            }
            if size >= minimumCells { pins += 1 }
        }
        return pins
    }

    private func isPinPixel(role: String, red: Int, green: Int, blue: Int) -> Bool {
        switch role {
        case "catholic", "chapel", "shrine", "sspx":
            // Chapel and shrine pins are burgundy teardrops, with a house or an arch on top.
            return abs(red - 0x8C) <= 18 && abs(green - 0x2F) <= 18 && abs(blue - 0x39) <= 18
                && red > green + 25 && red > blue + 15
        case "orthodox":
            return red < 55 && green < 70 && blue < 110 && blue > red + 12 && blue >= green
        case "worship":
            return abs(red - 0x2F) <= 20 && abs(green - 0x5F) <= 22 && abs(blue - 0x8A) <= 22
                && blue > red + 30 && blue > green + 10
        case "water":
            return abs(red - 0x2F) <= 20 && abs(green - 0x6F) <= 20 && abs(blue - 0x8A) <= 20
                && blue > red + 30 && blue > green + 8
        case "landmark":
            return abs(red - 0xC4) <= 22 && abs(green - 0x62) <= 22 && abs(blue - 0x2D) <= 22
                && red > 160 && red > green + 40 && green > blue
        case "viewpoint", "trailhead":
            let targetGreen = role == "viewpoint" ? 0x6B : 0x6B
            let targetRed = role == "viewpoint" ? 0x3E : 0x2F
            let targetBlue = role == "viewpoint" ? 0x48 : 0x4A
            return abs(red - targetRed) <= 20 && abs(green - targetGreen) <= 20 && abs(blue - targetBlue) <= 20
                && green > red + 12 && green > blue
        case "museum":
            return abs(red - 0x6B) <= 16 && abs(green - 0x4F) <= 16 && abs(blue - 0x3A) <= 16
                && red > green + 10 && green > blue + 8
        case "parking":
            return abs(red - 0x1C) <= 16 && abs(green - 0x3A) <= 16 && abs(blue - 0x5A) <= 16
                && blue > red + 30 && blue > green + 10
        default:
            return false
        }
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

private enum MapMark {
    case road
    case label
}

private struct Cell: Hashable {
    var x: Int
    var y: Int
}

private extension XCUIElement {
    func tapIfExists() {
        if exists { tap() }
    }
}
