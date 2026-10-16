import XCTest
#if SWIFT_PACKAGE
@testable import PilgrimAtlasCore
#endif

final class LogicTests: XCTestCase {
    func testOwnerFieldsAreRemovedAndAgencyFieldsStay() {
        let cleaned = Names.stripOwnerFields([
            "OwnerName": "Jane Q. Public",
            "OWNER1": "Jane Q. Public",
            "owner": "Jane Q. Public",
            "address": "1 Old Santa Fe Trail",
            "Own_Name": "Bureau of Land Management",
            "Mang_Name": "Bureau of Land Management",
        ])
        let blob = cleaned.values.joined(separator: " ")
        XCTAssertFalse(blob.contains("Jane Q. Public"))
        XCTAssertEqual(cleaned["address"], "1 Old Santa Fe Trail")
        XCTAssertEqual(cleaned["Own_Name"], "Bureau of Land Management")
        XCTAssertTrue(Names.isOwnerField("OwnerName"))
        XCTAssertFalse(Names.isOwnerField("Own_Name"))
        XCTAssertTrue(Names.looksLikePrivatePerson("Jane Q. Public"))
        XCTAssertFalse(Names.looksLikePrivatePerson("Bureau of Land Management"))
        XCTAssertFalse(Names.looksLikePrivatePerson("Jornada Experimental Range"))
        XCTAssertEqual(Names.publicLabel("Jane Q. Public", ownType: "PVT"), "")
        XCTAssertEqual(Names.publicLabel("Bureau of Land Management", ownType: "FED"), "Bureau of Land Management")
    }

    func testCatholicClassificationKeepsOtherWorshipVisible() {
        XCTAssertTrue(Catholic.isCatholicDenomination("roman_catholic"))
        XCTAssertTrue(Catholic.isCatholicDenomination("Catholic"))
        XCTAssertTrue(Catholic.isCatholicDenomination("greek_catholic"))
        XCTAssertTrue(Catholic.isCatholicDenomination("ruthenian_catholic"))
        XCTAssertTrue(Catholic.isCatholicDenomination("byzantine_catholic"))
        XCTAssertFalse(Catholic.isCatholicDenomination("anglican_catholic"))
        XCTAssertFalse(Catholic.isCatholicDenomination("catholic1"))
        XCTAssertFalse(Catholic.isCatholicDenomination("baptist"))
        XCTAssertEqual(
            Catholic.classify(amenity: "place_of_worship", tourism: nil, historic: nil, place: nil, denomination: "roman_catholic"),
            .catholic
        )
        XCTAssertEqual(
            Catholic.classify(amenity: "place_of_worship", tourism: nil, historic: nil, place: nil, denomination: "baptist"),
            .otherWorship
        )
        XCTAssertEqual(
            Catholic.classify(amenity: nil, tourism: "museum", historic: nil, place: nil, denomination: nil),
            .landmark
        )
    }

    func testLandStatusWordingDoesNotGrantEntry() {
        XCTAssertTrue(Copy.text("blm").hasPrefix("Bureau of Land Management surface."))
        XCTAssertEqual(
            Copy.text("usfs_inholding"),
            "Inside a national-forest administrative boundary, but mapped as non-Forest Service. Do not assume you may enter."
        )
        XCTAssertTrue(Copy.text("state_trust").contains("Not federal public land"))
        XCTAssertTrue(Copy.text("unknown").hasPrefix("No open dataset covers this point."))
        for sentence in Copy.sentences.values {
            XCTAssertFalse(LandStatus.grantsEntry(sentence))
        }
        let inside = hit("blm", lon: -106.01, lat: 35.49)
        XCTAssertEqual(LandStatus.status(lon: -106.0, lat: 35.5, hits: [inside]).1, Copy.text("blm"))
        let trust = hit("state_trust", lon: -106.01, lat: 35.49)
        XCTAssertEqual(LandStatus.status(lon: -106.0, lat: 35.5, hits: [trust]).1, Copy.text("state_trust"))
        XCTAssertEqual(LandStatus.status(lon: -100, lat: 40, hits: [inside]).1, Copy.text("unknown"))
        let tribal = hit("tribal", lon: -106.01, lat: 35.49)
        XCTAssertEqual(LandStatus.status(lon: -106.0, lat: 35.5, hits: [tribal, inside]).1, Copy.text("tribal"))
        let forest = hit("usfs_inholding", lon: -106.01, lat: 35.49, name: "Santa Fe National Forest")
        let inholding = LandStatus.status(lon: -106.0, lat: 35.5, hits: [forest]).1
        XCTAssertTrue(inholding.contains(Copy.text("usfs_inholding")))
        XCTAssertTrue(inholding.contains("Santa Fe National Forest"))
        XCTAssertTrue(Copy.cabqDisclaimer.contains("www.cabq.gov"))
        XCTAssertTrue(Copy.sloDisclaimer.contains("New Mexico State Land Office"))
    }

    func testNearbySummaryAndSearch() {
        let place = samplePlace(name: "El Santuario de Chimayó", category: "worship", catholic: true, lat: 35.99, lon: -106.01)
        let far = samplePlace(name: "Loretto Chapel", category: "landmark", catholic: false, lat: 35.2, lon: -105.9)
        let trail = TrailRecord(
            id: 1,
            name: "Ridge Trail",
            access: "",
            geometry: .lineString([LonLat(lon: -106.02, lat: 35.98), LonLat(lon: -106.0, lat: 36.0)]),
            source: "OpenStreetMap",
            sourceDate: "2026-10-02"
        )
        let land = hit("usfs", lon: -106.02, lat: 35.98, name: "Carson National Forest")
        let summary = AtlasQuery.nearby(lat: 35.99, lon: -106.01, places: [place, far], trails: [trail], lands: [land])
        XCTAssertTrue(summary.land.contains("Forest Service"))
        XCTAssertEqual(summary.explore.first?.name, "El Santuario de Chimayó")
        XCTAssertEqual(summary.explore.first?.catholic, true)
        XCTAssertEqual(summary.trails.first?.name, "Ridge Trail")
        XCTAssertTrue(summary.trails.first?.access.contains("not permission") == true)
        XCTAssertTrue(summary.closures[0].contains("not in this pack"))
        let found = AtlasQuery.search("chimayo", places: [place, far], trails: [])
        XCTAssertEqual(found.first?.name, "El Santuario de Chimayó")
        let facts = AtlasQuery.facts(for: samplePlace(
            name: "Saint Edwin",
            category: "worship",
            catholic: true,
            lat: 35.1,
            lon: -106.6,
            serviceTimes: "Su"
        ))
        XCTAssertTrue(facts.contains { $0.label == "Service times" && $0.value == "Su" })
        XCTAssertFalse(facts.contains { $0.label == "Mass times" })
    }

    func testDebugPlazaPinStaysOffWithoutTheArgument() {
        XCTAssertFalse(DebugPin.isEnabled(arguments: ["/PilgrimAtlas"]))
        XCTAssertFalse(DebugPin.isEnabled(arguments: ["/PilgrimAtlas", "--debug"]))
        XCTAssertTrue(DebugPin.isEnabled(arguments: ["/PilgrimAtlas", "--debug-santa-fe-plaza"]))
        XCTAssertEqual(DebugPin.plaza.lat, 35.6870, accuracy: 0.00001)
        XCTAssertEqual(DebugPin.plaza.lon, -105.9378, accuracy: 0.00001)
    }

    func testNamedFeePolygonBeatsUnknownProclamation() {
        let fee = hit("usfs", lon: -105.85, lat: 35.75, name: "Santa Fe National Forest", pubAccess: "OA", size: 0.02)
        let proclamation = hit("usfs", lon: -105.85, lat: 35.75, name: "Santa Fe National Forest", pubAccess: "UK", size: 0.01)
        let sentence = LandStatus.status(lon: -105.845, lat: 35.755, hits: [fee, proclamation]).1
        XCTAssertTrue(sentence.contains("open"))
        XCTAssertFalse(sentence.contains("unknown"))
        XCTAssertFalse(LandStatus.grantsEntry(sentence))
        let onlyUnknown = LandStatus.status(lon: -105.845, lat: 35.755, hits: [proclamation]).1
        XCTAssertTrue(onlyUnknown.contains("unknown"))
        XCTAssertFalse(LandStatus.grantsEntry(Copy.text("unknown")))
        XCTAssertFalse(LandStatus.grantsEntry(PlaceText.permissionLine))
    }

    func testPlazaCardSurfacesChapelAndCathedral() {
        let gallery = samplePlace(id: 1, name: "Maya's", category: "landmark", catholic: false, lat: 35.6872, lon: -105.9376)
        let loretto = samplePlace(id: 2, name: "Loretto Chapel", category: "landmark", catholic: false, lat: 35.685617, lon: -105.937454)
        let basilica = samplePlace(
            id: 3,
            name: "The Cathedral Basilica of Saint Francis of Assisi",
            category: "worship",
            catholic: true,
            lat: 35.686504,
            lon: -105.93624
        )
        let statue = samplePlace(id: 4, name: "Saint Francis of Assisi", category: "landmark", catholic: false, lat: 35.68635, lon: -105.93623)
        let land = hit("private_mapped", lon: -105.95, lat: 35.68)
        let summary = AtlasQuery.nearby(
            lat: 35.6870,
            lon: -105.9378,
            places: [gallery, loretto, basilica, statue],
            trails: [],
            lands: [land]
        )
        XCTAssertEqual(summary.headline, "Private on the surface map")
        XCTAssertEqual(summary.permissionLine, "This is not permission to enter.")
        XCTAssertNotEqual(summary.headline, summary.land)
        let names = summary.landmarks.map(\.name)
        XCTAssertTrue(names.contains("Loretto Chapel"))
        XCTAssertTrue(names.contains(where: { $0.contains("Cathedral Basilica") }))
        XCTAssertFalse(names.contains("Maya's"))
        XCTAssertFalse(names.contains("Saint Francis of Assisi"))
        XCTAssertEqual(summary.trailGap, "No trail within 3 km")
        XCTAssertEqual(summary.landmarkGap, "")
        let gap = AtlasQuery.nearby(lat: 40, lon: -100, places: [gallery], trails: [], lands: [])
        XCTAssertEqual(gap.headline, Copy.text("unknown"))
        XCTAssertEqual(gap.landmarkGap, "No landmark within 8 km")
        XCTAssertFalse(LandStatus.grantsEntry(gap.headline))
    }

    func testSearchFindsBasilicaChimayoAndTrails() {
        let emptyChimayo = samplePlace(id: 54, name: "Santuario de Chimayo", category: "worship", catholic: false, lat: 35.988871, lon: -105.931459)
        let richChimayo = samplePlace(
            id: 585,
            name: "Santuario de Chimayo",
            category: "worship",
            catholic: true,
            lat: 35.989078,
            lon: -105.931922,
            wikidata: "Q5352121"
        )
        let basilica = samplePlace(
            id: 1295,
            name: "The Cathedral Basilica of Saint Francis of Assisi",
            category: "worship",
            catholic: true,
            lat: 35.686504,
            lon: -105.93624,
            address: "231 Cathedral Place, Santa Fe, NM, 87501",
            website: "https://www.cbsfa.org/",
            wikipedia: "en:Cathedral Basilica of St. Francis of Assisi (Santa Fe)",
            wikidata: "Q3663700"
        )
        let albuquerque = samplePlace(
            id: 1270,
            name: "Cathedral Church of Saint John",
            category: "worship",
            catholic: false,
            lat: 35.082286,
            lon: -106.651584,
            address: "318 Silver Avenue Southwest, Albuquerque, NM, 87103"
        )
        let statue = samplePlace(id: 732, name: "Saint Francis of Assisi", category: "landmark", catholic: false, lat: 35.686349, lon: -105.936235)
        let prairie = samplePlace(id: 696, name: "St. Francis and the Prairie Dog", category: "landmark", catholic: false, lat: 35.689583, lon: -105.938323)
        let unnamed = samplePlace(id: 9, name: "Unnamed place of worship", category: "worship", catholic: false, lat: 35.69, lon: -105.94)
        let places = [emptyChimayo, richChimayo, basilica, albuquerque, statue, prairie, unnamed]
        let chimayo = AtlasQuery.search("Santuario de Chimayo", places: places, trails: [])
        XCTAssertEqual(chimayo.first?.placeId, 585)
        XCTAssertEqual(chimayo.first?.id, "place-585")
        XCTAssertFalse(chimayo.contains { $0.placeId == 54 })
        XCTAssertFalse(chimayo.contains { $0.subtitle == PlaceText.sameSitePhrase })
        let historic = samplePlace(
            id: 186,
            name: "El Santuario de Chimayo Historic Site",
            category: "worship",
            catholic: true,
            lat: 35.9892,
            lon: -105.9320
        )
        let merged = AtlasQuery.search(
            "Chimayo",
            places: places + [historic],
            trails: []
        )
        let chimayoIDs = merged.compactMap(\.placeId).filter { [54, 186, 585].contains($0) }
        XCTAssertEqual(chimayoIDs, [585])
        let church = samplePlace(
            id: 139,
            name: "El Santuario Church National Historic Landmark",
            category: "worship",
            catholic: false,
            lat: 35.989469,
            lon: -105.93141
        )
        let drawn = AtlasQuery.mapPlaces(places + [historic, church])
        let drawnIDs = Set(drawn.map(\.id))
        XCTAssertTrue(drawnIDs.contains(585))
        XCTAssertFalse(drawnIDs.contains(54))
        XCTAssertFalse(drawnIDs.contains(186))
        XCTAssertFalse(drawnIDs.contains(139))
        XCTAssertTrue(drawnIDs.contains(1295))
        XCTAssertTrue(drawnIDs.contains(732))
        XCTAssertEqual(PlaceText.kindLabel(for: statue), "Statue")
        XCTAssertEqual(PlaceText.rowSymbol(for: statue), "figure.stand")
        XCTAssertEqual(PlaceText.kindLabel(for: basilica), "Catholic landmark")
        XCTAssertEqual(PlaceText.rowSymbol(for: basilica), "cross.fill")
        XCTAssertEqual(Set(chimayo.map(\.id)).count, chimayo.count)
        let typed = AtlasQuery.search("Cathedral Basilica of St. Francis", places: places, trails: [])
        XCTAssertEqual(typed.first?.placeId, 1295)
        XCTAssertEqual(typed.first?.city, "Santa Fe")
        let cathedral = AtlasQuery.search("cathedral", places: places, trails: [], origin: DebugPin.plaza)
        XCTAssertEqual(cathedral.first?.placeId, 1295)
        XCTAssertTrue(cathedral.contains { $0.placeId == 1270 && $0.city == "Albuquerque" })
        let francis = AtlasQuery.search("St. Francis", places: places, trails: [])
        XCTAssertTrue(francis.contains { $0.placeId == 1295 })
        XCTAssertTrue(francis.contains { $0.placeId == 732 })
        XCTAssertFalse(francis.contains { $0.name == "Unnamed place of worship" })
        let hidden = AtlasQuery.search("chapel", places: places, trails: [])
        XCTAssertFalse(hidden.contains { $0.placeId == 9 })
        let grouped = AtlasQuery.search("unnamed", places: [unnamed], trails: [])
        XCTAssertEqual(grouped.first?.kind, .note)
        XCTAssertEqual(grouped.first?.name, "Unnamed worship (1)")
        let trail = TrailRecord(
            id: 2,
            name: "Skyline Trail",
            access: "",
            geometry: .lineString([LonLat(lon: -105.82, lat: 35.78), LonLat(lon: -105.78, lat: 35.80)]),
            source: "OpenStreetMap",
            sourceDate: "2026-10-02T20:21:34Z"
        )
        let trails = AtlasQuery.search("Skyline", places: [], trails: [trail])
        XCTAssertEqual(trails.first?.kind, .trail)
        XCTAssertEqual(trails.first?.trailId, 2)
        XCTAssertEqual(trails.first?.lat ?? 0, 35.79, accuracy: 0.001)
        XCTAssertEqual(trails.first?.lon ?? 0, -105.80, accuracy: 0.001)
    }

    func testHoursAddressSourceAndLinks() {
        let loretto = samplePlace(
            id: 1296,
            name: "Loretto Chapel",
            category: "landmark",
            catholic: false,
            lat: 35.685617,
            lon: -105.937454,
            address: "207 Old Santa Fe Trail, Santa Fe, NM, 87501",
            openingHours: "Mo-Sa 09:00-17:00; Su 10:30-17:00; Mo-Sa 09:30-16:30; Su 10:30-16:30",
            access: "private",
            website: "https://lorettochapel.com",
            wikipedia: "en:Loretto Chapel",
            wikidata: "Q2956557",
            sourceDate: "2026-10-02T20:21:34Z"
        )
        let facts = AtlasQuery.facts(for: loretto)
        XCTAssertTrue(facts.contains { $0.label == "Hours" && $0.value.contains("Mon–Sat") && $0.value.contains("9:00 AM") })
        XCTAssertFalse(facts.contains { $0.label == "Hours" && $0.value.contains("Mo-Sa") })
        XCTAssertTrue(facts.contains { $0.label == "Hours note" && $0.value == PlaceText.hoursConflictNote })
        XCTAssertTrue(facts.contains { $0.label == "Access" && $0.value == "The map tag says private. That is how OpenStreetMap recorded it, not a ruling about your visit." })
        XCTAssertEqual(PlaceText.wikipediaURL("en:Loretto Chapel"), "https://en.wikipedia.org/wiki/Loretto_Chapel")
        XCTAssertEqual(facts.first { $0.label == "Wikipedia" }?.url, "https://en.wikipedia.org/wiki/Loretto_Chapel")
        XCTAssertEqual(facts.first { $0.label == "Wikidata" }?.url, "https://www.wikidata.org/wiki/Q2956557")
        XCTAssertEqual(PlaceText.sourceLine(source: loretto.source, sourceDate: loretto.sourceDate), "OpenStreetMap, 2 Oct 2026")
        XCTAssertNil(PlaceText.diamondNote(for: loretto))
        XCTAssertEqual(PlaceText.denominationLabel("roman_catholic"), "Roman Catholic")
        XCTAssertEqual(
            PlaceText.wikipediaTitle("en:Cathedral Basilica of St. Francis of Assisi (Santa Fe)"),
            "Cathedral Basilica of St. Francis of Assisi (Santa Fe)"
        )
        XCTAssertEqual(MapFilter.hourLines(loretto.openingHours).count, 4)
        XCTAssertEqual(MapFilter.hoursReading(loretto.openingHours), .notAClock)
        let tidy = PlaceText.hoursDisplay("Mo-Fr 09:00-17:00")
        XCTAssertEqual(tidy.shown, "Mon–Fri 9:00 AM–5:00 PM")
        XCTAssertNil(tidy.note)
        let basilica = samplePlace(
            id: 1295,
            name: "The Cathedral Basilica of Saint Francis of Assisi",
            category: "worship",
            catholic: true,
            lat: 35.686504,
            lon: -105.93624,
            wikipedia: "en:Cathedral Basilica of St. Francis of Assisi (Santa Fe)",
            wikidata: "Q3663700",
            image: "File:Saint Francis Cathedral in Santa Fe New Mexico.jpg"
        )
        let basilicaFacts = AtlasQuery.facts(for: basilica)
        XCTAssertFalse(basilicaFacts.contains { $0.label == "Photo" })
        XCTAssertFalse(basilicaFacts.contains { $0.label == "Hours" })
        XCTAssertNil(PlaceText.photoURL(basilica.image))
        XCTAssertTrue(PlaceText.wikipediaURL(basilica.wikipedia)?.contains("Cathedral_Basilica_of_St._Francis_of_Assisi_(Santa_Fe)") == true)
        XCTAssertNil(PlaceText.diamondNote(for: basilica))
        XCTAssertEqual(PlaceText.pinLabel(basilica.name), "Cathedral Basilica")
        XCTAssertFalse(LandStatus.grantsEntry("The map tag says private. That is how OpenStreetMap recorded it, not a ruling about your visit."))
    }

    func testDebugLaunchParsesScreenshotArguments() {
        let plain = DebugLaunch.parse(["/PilgrimAtlas"])
        XCTAssertEqual(plain, .inactive)
        XCTAssertFalse(plain.suppressesLocation)
        XCTAssertFalse(plain.skipsDisclaimer)

        let plaza = DebugLaunch.parse(["/PilgrimAtlas", "--debug-santa-fe-plaza"])
        XCTAssertTrue(plaza.pinPlaza)
        XCTAssertTrue(plaza.suppressesLocation)
        XCTAssertTrue(plaza.skipsDisclaimer)
        XCTAssertFalse(DebugLaunch.parse(["/PilgrimAtlas", "--debug"]).pinPlaza)

        let closed = DebugLaunch.parse(["/PilgrimAtlas", "--debug-disclaimer"])
        XCTAssertTrue(closed.showDisclaimer)
        XCTAssertFalse(closed.disclaimerDetailsOpen)
        XCTAssertTrue(closed.suppressesLocation)
        XCTAssertFalse(closed.skipsDisclaimer)

        let openDetails = DebugLaunch.parse(["/PilgrimAtlas", "--debug-disclaimer-details-open"])
        XCTAssertTrue(openDetails.showDisclaimer)
        XCTAssertTrue(openDetails.disclaimerDetailsOpen)
        XCTAssertFalse(openDetails.skipsDisclaimer)

        let place = DebugLaunch.parse(["/PilgrimAtlas", "--debug-open-place", "Loretto Chapel"])
        XCTAssertEqual(place.openPlace, "Loretto Chapel")
        let equals = DebugLaunch.parse(["/PilgrimAtlas", "--debug-open-place=Skyline Trail"])
        XCTAssertEqual(equals.openPlace, "Skyline Trail")

        let search = DebugLaunch.parse(["/PilgrimAtlas", "--debug-search", "Santuario de Chimayo"])
        XCTAssertEqual(search.search, "Santuario de Chimayo")
        XCTAssertTrue(search.suppressesLocation)
        XCTAssertTrue(search.skipsDisclaimer)

        let layers = DebugLaunch.parse(["/PilgrimAtlas", "--debug-show-layers", "--debug-show-places-picker"])
        XCTAssertTrue(layers.showLayers)
        XCTAssertTrue(layers.showPlacesPicker)

        let tap = DebugLaunch.parse(["/PilgrimAtlas", "--debug-tap-at", "35.686504,-105.93624"])
        XCTAssertEqual(tap.tap?.lat ?? 0, 35.686504, accuracy: 0.0000001)
        XCTAssertEqual(tap.tap?.lon ?? 0, -105.93624, accuracy: 0.0000001)
        let spaced = DebugLaunch.parse(["/PilgrimAtlas", "--debug-tap-at=35.686504, -105.93624"])
        XCTAssertEqual(spaced.tap?.lat ?? 0, 35.686504, accuracy: 0.0000001)
        XCTAssertNil(DebugLaunch.parse(["/PilgrimAtlas", "--debug-tap-at", "nope"]).tap)

        let gateWins = DebugLaunch.parse([
            "/PilgrimAtlas",
            "--debug-santa-fe-plaza",
            "--debug-disclaimer",
        ])
        XCTAssertTrue(gateWins.pinPlaza)
        XCTAssertTrue(gateWins.showDisclaimer)
        XCTAssertFalse(gateWins.skipsDisclaimer)
        XCTAssertTrue(gateWins.suppressesLocation)

        let albuquerque = DebugLaunch.parse(["/PilgrimAtlas", "--debug-location=35.1086,-106.5700"])
        XCTAssertEqual(albuquerque.simulatedUser?.lat ?? 0, DebugLaunch.northeastAlbuquerque.lat, accuracy: 0.0001)
        XCTAssertEqual(albuquerque.simulatedUser?.lon ?? 0, DebugLaunch.northeastAlbuquerque.lon, accuracy: 0.0001)
        XCTAssertEqual(albuquerque.center?.lat ?? 0, 35.1086, accuracy: 0.0001)
        XCTAssertTrue(albuquerque.suppressesLocation)
        XCTAssertTrue(PackCoverage.contains(DebugLaunch.northeastAlbuquerque))

        let terrain = DebugLaunch.parse(["/PilgrimAtlas", "--debug-terrain"])
        XCTAssertTrue(terrain.showTerrain)
        XCTAssertTrue(terrain.showLayers)
        XCTAssertTrue(terrain.suppressesLocation)
        XCTAssertTrue(terrain.skipsDisclaimer)
        XCTAssertFalse(terrain.pinPlaza)

        let outside = DebugLaunch.parse(["/PilgrimAtlas", "--debug-outside-coverage"])
        XCTAssertTrue(outside.outsideCoverage)
        XCTAssertTrue(outside.suppressesLocation)
        XCTAssertTrue(outside.skipsDisclaimer)
        XCTAssertFalse(PackCoverage.contains(DebugLaunch.outsideCoverageSample))

        let dark = DebugLaunch.parse(["/PilgrimAtlas", "--debug-appearance=dark"])
        XCTAssertEqual(dark.appearance, .dark)
        XCTAssertFalse(dark.suppressesLocation)
        let light = DebugLaunch.parse(["/PilgrimAtlas", "--debug-appearance", "light"])
        XCTAssertEqual(light.appearance, .light)
        XCTAssertNil(DebugLaunch.parse(["/PilgrimAtlas", "--debug-appearance=sepia"]).appearance)

        let card = DebugLaunch.parse(["/PilgrimAtlas", "--debug-card=full"])
        XCTAssertTrue(card.cardFull)
        XCTAssertTrue(card.suppressesLocation)
        XCTAssertTrue(card.skipsDisclaimer)
        XCTAssertFalse(card.pinPlaza)
        let cardSpaced = DebugLaunch.parse(["/PilgrimAtlas", "--debug-card", "full"])
        XCTAssertTrue(cardSpaced.cardFull)
        XCTAssertFalse(DebugLaunch.parse(["/PilgrimAtlas", "--debug-card=short"]).cardFull)
        XCTAssertFalse(plain.cardFull)

        let settings = DebugLaunch.parse(["/PilgrimAtlas", "--debug-show-settings"])
        XCTAssertTrue(settings.showSettings)
        XCTAssertEqual(settings.tab, "settings")
        XCTAssertTrue(settings.suppressesLocation)
        XCTAssertTrue(settings.skipsDisclaimer)

        let filters = DebugLaunch.parse(["/PilgrimAtlas", "--debug-show-filters"])
        XCTAssertTrue(filters.showFilters)
        XCTAssertTrue(filters.skipsDisclaimer)

        let onboarding = DebugLaunch.parse(["/PilgrimAtlas", "--debug-onboarding"])
        XCTAssertTrue(onboarding.showOnboarding)
        XCTAssertFalse(onboarding.skipsDisclaimer)
        XCTAssertTrue(onboarding.suppressesLocation)

        let searchTab = DebugLaunch.parse(["/PilgrimAtlas", "--debug-tab=search"])
        XCTAssertEqual(searchTab.tab, "search")
        XCTAssertTrue(searchTab.skipsDisclaimer)
        XCTAssertNil(DebugLaunch.parse(["/PilgrimAtlas", "--debug-tab=terminal"]).tab)
    }

    func testAppInfoAndFilterControls() {
        XCTAssertEqual(AppInfo.versionLine(marketing: "1.0", build: "101"), "1.0 (101)")
        XCTAssertEqual(FilterControl.all.map(\.id), [
            "catholic", "churches", "trails", "public-land", "parks", "food", "open-now",
        ])
        XCTAssertFalse(FilterControl.all.first { $0.id == "food" }?.enabled ?? true)
        var filter = AtlasFilter.empty
        filter.toggle("catholic")
        filter.toggle("trails")
        XCTAssertTrue(filter.catholic)
        XCTAssertTrue(filter.trails)
        XCTAssertEqual(filter.activeControls.map(\.id), ["catholic", "trails"])
        filter.toggle("food")
        XCTAssertFalse(filter.isOn("food"))
        XCTAssertEqual(AppInfo.versionLine(marketing: "1.0", build: "5.3"), "1.0 (5.3)")
    }

    func testEachFilterControlChangesOnlyItsOwnField() {
        for control in FilterControl.all {
            var filter = AtlasFilter.empty
            filter.toggle(control.id)
            XCTAssertEqual(filter.isOn(control.id), control.enabled, control.id)
            let flags = [
                filter.catholic, filter.churches, filter.trails,
                filter.publicLand, filter.parks, filter.openNow,
            ]
            XCTAssertEqual(flags.filter { $0 }.count, control.enabled ? 1 : 0, control.id)
            filter.toggle(control.id)
            XCTAssertFalse(filter.anyChip, control.id)
        }
    }

    func testTownSearchUsesThePackedTownList() {
        XCTAssertEqual(
            PlaceText.towns.map(\.name),
            ["Santa Fe", "Chimayó", "Española", "Los Alamos", "Taos", "Albuquerque", "Dulce"]
        )
        let hits = AtlasQuery.search("Taos", places: [], trails: [])
        XCTAssertEqual(hits.first?.kind, .town)
        XCTAssertEqual(hits.first?.id, "town-taos")
        XCTAssertEqual(hits.first?.name, "Taos")
        XCTAssertTrue(AtlasQuery.search("zzzz-no-such-place", places: [], trails: []).isEmpty)
        let chimayo = AtlasQuery.search("Chimayo", places: [], trails: [])
        XCTAssertTrue(chimayo.contains { $0.id == "town-chimayo" })
    }

    func testDebugLaunchResolvesLandmarksAndTapRadius() {
        let places = screenshotPlaces()
        let trail = TrailRecord(
            id: 2,
            name: "Skyline Trail",
            access: "",
            geometry: .lineString([LonLat(lon: -105.82, lat: 35.78), LonLat(lon: -105.78, lat: 35.80)]),
            source: "OpenStreetMap",
            sourceDate: "2026-10-02T20:21:34Z"
        )
        XCTAssertEqual(DebugLaunch.resolve("Loretto Chapel", places: places, trails: [trail]), .place(1296))
        XCTAssertEqual(
            DebugLaunch.resolve("Cathedral Basilica of St. Francis", places: places, trails: [trail]),
            .place(1295)
        )
        XCTAssertEqual(DebugLaunch.resolve("Santuario de Chimayo", places: places, trails: [trail]), .place(585))
        XCTAssertEqual(DebugLaunch.resolve("Chimayó", places: places, trails: [trail]), .place(585))
        XCTAssertEqual(DebugLaunch.resolve("Skyline Trail", places: places, trails: [trail]), .trail(2))
        XCTAssertEqual(DebugLaunch.resolve("1296", places: places, trails: [trail]), .place(1296))
        XCTAssertEqual(DebugLaunch.resolve("2", places: places, trails: [trail]), .trail(2))

        let radius = DebugLaunch.tapRadiusMeters(latitude: 35.6870)
        XCTAssertEqual(radius, 170.7, accuracy: 1.0)
        let center = DebugLaunch.placesPickerSample
        let close = samplePlace(id: 732, name: "Saint Francis of Assisi", category: "landmark", catholic: false, lat: center.lat + 20 / 111_320, lon: center.lon)
        let inside = samplePlace(id: 770, name: "Prayer of Saint Francis", category: "landmark", catholic: false, lat: center.lat + 140 / 111_320, lon: center.lon)
        let far = samplePlace(id: 9, name: "Far Chapel", category: "landmark", catholic: false, lat: center.lat + 0.02, lon: center.lon)
        let hits = DebugLaunch.placesWithinTap(at: center, places: [far, inside, close] + places)
        XCTAssertGreaterThan(hits.count, 1)
        XCTAssertEqual(hits.first?.id, 1295)
        XCTAssertTrue(hits.contains { $0.id == 732 })
        XCTAssertTrue(hits.contains { $0.id == 770 })
        XCTAssertTrue(hits.contains { $0.id == 1296 })
        XCTAssertFalse(hits.contains { $0.id == 9 })
    }

    func testPackedSkylineSheetDoesNotShowTheNetworkSum() throws {
        let geometry = try XCTUnwrap(packedSkylineGeometry())
        let meters = try XCTUnwrap(Geometry.lengthMeters(geometry))
        XCTAssertGreaterThan(meters, 100_000)
        XCTAssertLessThan(meters, 110_000)
        let sentence = Geometry.lengthSentence(geometry)
        XCTAssertFalse(sentence.contains("103"))
        XCTAssertNotEqual(sentence, Geometry.lengthLabel(meters))
        XCTAssertTrue(sentence.contains("network of ways"))
    }

    func testFiltersHoursAndLandChips() throws {
        var filter = AtlasFilter.empty
        let loretto = samplePlace(id: 1296, name: "Loretto Chapel", category: "landmark", catholic: false, lat: 35.685617, lon: -105.937454)
        let basilica = samplePlace(id: 1295, name: "The Cathedral Basilica of Saint Francis of Assisi", category: "worship", catholic: true, lat: 35.686504, lon: -105.93624)
        let gallery = samplePlace(id: 1, name: "Maya's", category: "landmark", catholic: false, lat: 35.6872, lon: -105.9376)
        let closed = samplePlace(id: 8, name: "Saturday Chapel", category: "worship", catholic: true, lat: 35.7, lon: -105.9, openingHours: "Sa 16:00-17:00")
        let open = samplePlace(id: 9, name: "Weekday Hall", category: "landmark", catholic: false, lat: 35.7, lon: -105.9, openingHours: "Mo-Fr 09:00-17:00")
        let zone = TimeZone(identifier: "America/Denver")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 15, minute: 0))!
        XCTAssertEqual(MapFilter.hoursReading(open.openingHours, now: now, timeZone: zone), .clock(openNow: true))
        XCTAssertEqual(MapFilter.hoursReading(closed.openingHours, now: now, timeZone: zone), .clock(openNow: false))
        XCTAssertEqual(MapFilter.hoursReading("", now: now, timeZone: zone), .none)
        XCTAssertEqual(MapFilter.pinRole(for: loretto), .chapel)
        XCTAssertEqual(MapFilter.pinRole(for: basilica), .catholic)
        XCTAssertEqual(MapFilter.pinRole(for: gallery), .landmark)
        filter.catholic = true
        XCTAssertEqual(MapFilter.placeDraw(basilica, filter: filter, now: now, timeZone: zone), .show)
        XCTAssertEqual(MapFilter.placeDraw(loretto, filter: filter, now: now, timeZone: zone), .hide)
        filter.churches = true
        XCTAssertEqual(MapFilter.placeDraw(basilica, filter: filter, now: now, timeZone: zone), .show)
        XCTAssertEqual(MapFilter.placeDraw(loretto, filter: filter, now: now, timeZone: zone), .hide)
        filter.catholic = false
        XCTAssertEqual(MapFilter.placeDraw(loretto, filter: filter, now: now, timeZone: zone), .show)
        var openFilter = AtlasFilter.empty
        openFilter.openNow = true
        XCTAssertEqual(MapFilter.placeDraw(basilica, filter: openFilter, now: now, timeZone: zone), .show)
        XCTAssertEqual(MapFilter.placeDraw(closed, filter: openFilter, now: now, timeZone: zone), .hide)
        XCTAssertEqual(MapFilter.placeDraw(open, filter: openFilter, now: now, timeZone: zone), .show)
        XCTAssertFalse(MapFilter.publicKinds.contains("state_trust"))
        XCTAssertTrue(MapFilter.landShown(kind: "usfs", name: "Santa Fe National Forest", filter: AtlasFilter(publicLand: true)))
        XCTAssertFalse(MapFilter.landShown(kind: "state_trust", name: "State Trust", filter: AtlasFilter(publicLand: true)))
        XCTAssertFalse(MapFilter.isPark(kind: "landmark", name: "Cathedral Park Church"))
        XCTAssertTrue(MapFilter.isPark(kind: "local_protected", name: "Frenchy's Field Park"))
        XCTAssertFalse(MapFilter.isPark(kind: "local_protected", name: "Watershed"))
        let trust = hit("state_trust", lon: -105.95, lat: 35.68, name: "State Trust")
        var landFilter = AtlasFilter.empty
        landFilter.publicLand = true
        let summary = AtlasQuery.nearby(lat: 35.687, lon: -105.9378, places: [basilica, loretto], trails: [], lands: [trust], filter: landFilter)
        XCTAssertEqual(summary.headline, MapFilter.stateTrustLine)
        let hits = AtlasQuery.search("Loretto", places: [loretto, basilica, gallery], trails: [], filter: filter)
        XCTAssertEqual(hits.first?.placeId, 1296)
        var catholic = AtlasFilter.empty
        catholic.catholic = true
        let catholicHits = AtlasQuery.search("chapel", places: [loretto, basilica], trails: [], filter: catholic)
        XCTAssertFalse(catholicHits.contains { $0.placeId == 1296 })
        let parsed = DebugLaunch.parse(["/PilgrimAtlas", "--debug-filter=catholic,open-now", "--debug-filter", "nope"])
        XCTAssertEqual(DebugLaunch.filter(from: parsed.filterTokens), AtlasFilter(catholic: true, openNow: true))
        XCTAssertTrue(parsed.suppressesLocation)
        XCTAssertTrue(parsed.skipsDisclaimer)
        XCTAssertTrue(DebugLaunch.parse(["/PilgrimAtlas", "--debug-filter=food"]).focusFood)
        XCTAssertFalse(DebugLaunch.parse(["/PilgrimAtlas", "--debug-show-layers"]).filterTokens.contains("catholic"))
        XCTAssertEqual(MapFilter.foodCount([gallery, basilica]), 0)
        var trailsOnly = AtlasFilter.empty
        trailsOnly.trails = true
        let trailSummary = AtlasQuery.nearby(
            lat: 35.687,
            lon: -105.9378,
            places: [basilica],
            trails: [],
            lands: [],
            filter: trailsOnly
        )
        XCTAssertEqual(trailSummary.trailGap, "No trail within 3 km of this point.")
        XCTAssertEqual(trailSummary.landmarkGap, "")
        var parks = AtlasFilter.empty
        parks.parks = true
        let parkSummary = AtlasQuery.nearby(
            lat: 35.687,
            lon: -105.9378,
            places: [],
            trails: [],
            lands: [trust],
            filter: parks
        )
        XCTAssertEqual(parkSummary.headline, MapFilter.notParkLine)
        let statues = PlaceText.dedupeByName([
            samplePlace(id: 732, name: "Saint Francis of Assisi", category: "landmark", catholic: false, lat: 35.68635, lon: -105.93623),
            samplePlace(id: 733, name: "Saint Francis of Assisi", category: "landmark", catholic: false, lat: 35.68636, lon: -105.93622),
        ])
        XCTAssertEqual(statues.map(\.id), [732])
        XCTAssertEqual(PlaceText.externalLinkTitle(label: "Wikidata", value: "Q3663700"), "Wikidata")
        let skyline = TrailRecord(
            id: 2,
            name: "Skyline Trail",
            access: "",
            geometry: .lineString([LonLat(lon: -105.82, lat: 35.78), LonLat(lon: -105.78, lat: 35.80)]),
            source: "OpenStreetMap",
            sourceDate: "2026-10-02"
        )
        let length = Geometry.lengthMeters(skyline.geometry)
        XCTAssertNotNil(length)
        XCTAssertGreaterThan(length ?? 0, 1000)
        XCTAssertTrue(Geometry.lengthLabel(length).contains("km"))
        XCTAssertFalse(Geometry.isBranchedNetwork(skyline.geometry))
        let network = GeoJSONGeometry.multiLineString([
            [LonLat(lon: -105.80, lat: 35.70), LonLat(lon: -105.70, lat: 35.80)],
            [LonLat(lon: -105.70, lat: 35.80), LonLat(lon: -105.60, lat: 35.70)],
            [LonLat(lon: -105.70, lat: 35.80), LonLat(lon: -105.70, lat: 35.90)],
        ])
        XCTAssertTrue(Geometry.isBranchedNetwork(network))
        XCTAssertTrue(Geometry.lengthSentence(network).contains("network of ways"))
        let chain = GeoJSONGeometry.multiLineString([
            [LonLat(lon: -105.80, lat: 35.70), LonLat(lon: -105.70, lat: 35.80)],
            [LonLat(lon: -105.70, lat: 35.80), LonLat(lon: -105.60, lat: 35.70)],
        ])
        XCTAssertFalse(Geometry.isBranchedNetwork(chain))
        XCTAssertTrue(Geometry.lengthSentence(chain).contains("km"))
        let streets = PackStyleDocument.json(
            packURL: "pmtiles://file:///tmp/northern-new-mexico.pmtiles",
            glyphsURL: "file:///tmp/glyphs/{fontstack}/{range}.pbf",
            online: true
        )
        for identifier in PackStyleDocument.streetLayerIDs {
            XCTAssertTrue(streets.contains("\"id\":\"\(identifier)\""), identifier)
        }
        XCTAssertTrue(streets.contains("\"source-layer\":\"place\""))
        XCTAssertTrue(streets.contains("park"))
        XCTAssertEqual(PackStyleDocument.showsPlaceLayer("places-catholic", filter: AtlasFilter(catholic: true)), true)
        XCTAssertEqual(PackStyleDocument.showsPlaceLayer("places-chapel", filter: AtlasFilter(catholic: true)), false)
        XCTAssertEqual(PackStyleDocument.showsPlaceLayer("places-chapel", filter: AtlasFilter(churches: true)), true)
        XCTAssertEqual(PackStyleDocument.placeOpacity(filter: AtlasFilter(trails: true)), 0.55)
        XCTAssertEqual(PackStyleDocument.labelOpacity(filter: AtlasFilter(trails: true)), 1)
        let style = PackStyleDocument.json(
            packURL: "pmtiles://file:///tmp/northern-new-mexico.pmtiles",
            glyphsURL: "file:///tmp/glyphs/{fontstack}/{range}.pbf",
            online: false
        )
        XCTAssertEqual(PackStyleDocument.missingLayers(in: style), [])
        XCTAssertEqual(PackStyleDocument.renderProblems(in: style), [])
        let terrainStyle = PackStyleDocument.json(
            packURL: "pmtiles://file:///tmp/northern-new-mexico.pmtiles",
            glyphsURL: "file:///tmp/glyphs/{fontstack}/{range}.pbf",
            online: false,
            hillshadeURL: "pmtiles://file:///tmp/northern-new-mexico-hillshade.pmtiles",
            contourURL: "pmtiles://file:///tmp/northern-new-mexico-contours.pmtiles"
        )
        XCTAssertEqual(PackStyleDocument.renderProblems(in: terrainStyle), [])
        XCTAssertTrue(terrainStyle.contains("\"hillshade\""))
        XCTAssertTrue(terrainStyle.contains("\"contours\""))
        XCTAssertTrue(terrainStyle.contains("\"raster-contrast\""))
        XCTAssertTrue(terrainStyle.contains("contours-casing"))
        XCTAssertTrue(terrainStyle.contains("untitled"))
        XCTAssertTrue(terrainStyle.contains("\"text-halo-width\":[\"interpolate\",[\"linear\"],[\"zoom\"],12,1.5,16,3.5]"))
        XCTAssertTrue(terrainStyle.contains("[\"all\",[\"==\",[\"get\",\"index\"],1],[\">\",[\"get\",\"elev\"],0]]"))
        let deduped = PackStyleDocument.json(
            packURL: "pmtiles://file:///tmp/northern-new-mexico.pmtiles",
            glyphsURL: "file:///tmp/glyphs/{fontstack}/{range}.pbf",
            online: false,
            places: [
                samplePlace(id: 585, name: "Santuario de Chimayo", category: "worship", catholic: true, lat: 35.989078, lon: -105.931922, wikidata: "Q5352121"),
                samplePlace(id: 186, name: "El Santuario de Chimayo Historic Site", category: "worship", catholic: true, lat: 35.989258, lon: -105.931691),
            ]
        )
        XCTAssertTrue(deduped.contains("pack-places"))
        XCTAssertTrue(deduped.contains("Santuario de Chimayo"))
        XCTAssertFalse(deduped.contains("Historic Site"))
        let labeled = PackStyleDocument.json(
            packURL: "pmtiles://file:///tmp/northern-new-mexico.pmtiles",
            glyphsURL: "file:///tmp/glyphs/{fontstack}/{range}.pbf",
            online: false,
            places: [
                samplePlace(
                    id: 1295,
                    name: "The Cathedral Basilica of Saint Francis of Assisi",
                    category: "worship",
                    catholic: true,
                    lat: 35.686504,
                    lon: -105.93624
                ),
            ]
        )
        XCTAssertTrue(labeled.contains("\"label\":\"Cathedral Basilica\""))
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(labeled.utf8)) as? [String: Any])
        let layers = try XCTUnwrap(decoded["layers"] as? [[String: Any]])
        let catholicLayer = try XCTUnwrap(layers.first { ($0["id"] as? String) == "places-catholic" })
        let layout = try XCTUnwrap(catholicLayer["layout"] as? [String: Any])
        let offset = try XCTUnwrap(layout["text-radial-offset"] as? Double)
        XCTAssertEqual(offset, 2.4, accuracy: 0.0001)
        XCTAssertEqual(layout["text-variable-anchor"] as? [String], ["top", "left", "right"])
        XCTAssertFalse(labeled.contains("\"text-variable-anchor\":[\"top\",\"left\",\"right\",\"bottom\"]"))
        XCTAssertTrue(PackCoverage.contains(DebugPin.plaza))
        let north = LonLat(lon: -105.94, lat: 39.74)
        XCTAssertFalse(PackCoverage.contains(north))
        let nearest = PackCoverage.nearest(north)
        XCTAssertEqual(nearest.lat, PackCoverage.north, accuracy: 0.0001)
        XCTAssertEqual(nearest.lon, -105.94, accuracy: 0.0001)
        XCTAssertTrue(PackCoverage.contains(nearest))
        let outside = LonLat(lon: -108.2, lat: 33.4)
        let clamped = PackCoverage.nearest(outside)
        XCTAssertEqual(clamped.lon, PackCoverage.west, accuracy: 0.0001)
        XCTAssertEqual(clamped.lat, PackCoverage.south, accuracy: 0.0001)
        XCTAssertNotEqual(PinRole.catholic.systemImage, PinRole.landmark.systemImage)
        XCTAssertEqual(PinRole.water.systemImage, "drop.fill")
        XCTAssertFalse(PackStyleDocument.missingLayers(in: "{\"layers\":[]}").isEmpty)
        XCTAssertFalse(PackStyleDocument.missingRenderedLayers([], packIsVector: false).isEmpty)
        XCTAssertEqual(
            PackStyleDocument.missingRenderedLayers(Set(PackStyleDocument.requiredLayerIDs), packIsVector: true),
            []
        )
        XCTAssertTrue(MapFilter.hoursConflict("Mo-Sa 09:00-17:00; Mo-Sa 09:30-16:30"))
        let conflict = PlaceText.hoursDisplay("Mo-Sa 09:00-17:00; Mo-Sa 09:30-16:30")
        XCTAssertTrue(conflict.shown.contains("Mon–Sat"))
        XCTAssertFalse(conflict.shown.contains("Mo-Sa"))
        XCTAssertEqual(conflict.note, PlaceText.hoursConflictNote)
    }

    func testLandmarkLayersFilterOnRoleStrings() throws {
        let basilica = samplePlace(
            id: 1295,
            name: "The Cathedral Basilica of Saint Francis of Assisi",
            category: "worship",
            catholic: true,
            lat: 35.686504,
            lon: -105.93624
        )
        let loretto = samplePlace(
            id: 1296,
            name: "Loretto Chapel",
            category: "landmark",
            catholic: false,
            lat: 35.685617,
            lon: -105.937454
        )
        XCTAssertEqual(MapFilter.pinRole(for: basilica), .catholic)
        XCTAssertEqual(MapFilter.pinRole(for: loretto), .chapel)
        let json = PackStyleDocument.json(
            packURL: "pmtiles://file:///tmp/northern-new-mexico.pmtiles",
            glyphsURL: "file:///tmp/glyphs/{fontstack}/{range}.pbf",
            online: false,
            places: [basilica, loretto]
        )
        let grouped = PackStyleDocument.placesGroupedByRole([basilica, loretto])
        XCTAssertEqual(grouped["catholic"]?.map(\.id), [basilica.id])
        XCTAssertEqual(grouped["chapel"]?.map(\.id), [loretto.id])
        XCTAssertTrue((grouped["landmark"] ?? []).isEmpty)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let sources = try XCTUnwrap(root["sources"] as? [String: Any])
        let geo = try XCTUnwrap(sources["pack-places-catholic"] as? [String: Any])
        let data = try XCTUnwrap(geo["data"] as? [String: Any])
        let features = try XCTUnwrap(data["features"] as? [[String: Any]])
        let roles = features.compactMap { ($0["properties"] as? [String: Any])?["role"] as? String }
        XCTAssertEqual(roles, ["catholic"])
        let layers = try XCTUnwrap(root["layers"] as? [[String: Any]])
        for role in ["catholic", "chapel", "worship", "shrine", "viewpoint", "museum", "parking", "water", "trailhead", "landmark"] {
            let layer = try XCTUnwrap(layers.first { ($0["id"] as? String) == "places-\(role)" })
            XCTAssertEqual(layer["source"] as? String, "pack-places-\(role)")
            XCTAssertNil(layer["source-layer"])
            if PackStyleDocument.clusteredRoles.contains(role) {
                let layerFilter = try XCTUnwrap(layer["filter"] as? [Any])
                XCTAssertEqual(layerFilter.first as? String, "!")
            } else {
                XCTAssertNil(layer["filter"])
            }
        }
        let parsed = DebugLaunch.parse(["/PilgrimAtlas", "--debug-layer=catholic"])
        XCTAssertEqual(parsed.onlyRole, "catholic")
        XCTAssertEqual(parsed.center?.lat ?? 0, 35.686504, accuracy: 0.000001)
        XCTAssertTrue(parsed.suppressesLocation)
        let plaza = LonLat(lon: -105.9378, lat: 35.6870)
        let cluster = [
            samplePlace(id: 1, name: "Cathedral", category: "worship", catholic: true, lat: 35.6865, lon: -105.9362),
            samplePlace(id: 2, name: "Guadalupe", category: "worship", catholic: true, lat: 35.6880, lon: -105.9440),
            samplePlace(id: 3, name: "Cristo Rey", category: "worship", catholic: true, lat: 35.6720, lon: -105.9300),
            samplePlace(id: 4, name: "Saint Anne", category: "worship", catholic: true, lat: 35.6700, lon: -105.9500),
            samplePlace(id: 5, name: "San Isidro", category: "worship", catholic: true, lat: 35.6575, lon: -106.0117),
            samplePlace(id: 6, name: "Far Church", category: "worship", catholic: true, lat: 36.40, lon: -105.57),
        ]
        let catholicPlaces = cluster.filter { MapFilter.pinRole(for: $0) == .catholic }
        let framed = LayerFrame.nearest(catholicPlaces, around: plaza)
        XCTAssertEqual(framed.map(\.id), [1, 2, 3, 4, 5])
        XCTAssertFalse(framed.contains { $0.id == 6 })
        let lone = LayerFrame.nearest([cluster[0]], around: plaza)
        XCTAssertEqual(lone.map(\.id), [1])
        XCTAssertTrue(PackStyleDocument.showsPlaceLayer("places-catholic", filter: .empty, onlyRole: "catholic"))
        XCTAssertFalse(PackStyleDocument.showsPlaceLayer("places-landmark", filter: .empty, onlyRole: "catholic"))
    }

    func testLiturgyComesFromTheParishAndSkipsUnlicensedFeeds() throws {
        let olph = perpetualHelp()
        let tears = samplePlace(
            id: 1367,
            name: "Memorial of Perpetual Tears",
            category: "worship",
            catholic: false,
            lat: 35.2,
            lon: -106.6,
            address: "Albuquerque",
            website: "http://www.dwimemorialofperpetualtears.org/"
        )
        let namesake = samplePlace(
            id: 50,
            name: "Our Lady of Perpetual Help",
            category: "worship",
            catholic: true,
            lat: 35.6,
            lon: -105.9,
            address: "Santa Fe, NM",
            denomination: "ruthenian_catholic"
        )
        XCTAssertEqual(ChurchMark.mark(for: olph), .byzantine)
        XCTAssertEqual(ChurchMark.pinName(for: olph), "byzantine")
        XCTAssertTrue(ChurchMark.showsLiturgy(olph))
        XCTAssertEqual(ChurchMark.mark(for: samplePlace(
            id: 1295,
            name: "The Cathedral Basilica of Saint Francis of Assisi",
            category: "worship",
            catholic: true,
            lat: 35.686504,
            lon: -105.93624
        )), .latin)
        XCTAssertEqual(ChurchMark.mark(for: samplePlace(
            id: 80,
            name: "Holy Trinity Orthodox Church",
            category: "worship",
            catholic: false,
            lat: 35.1,
            lon: -106.6,
            denomination: "eastern_orthodox"
        )), .orthodox)
        XCTAssertFalse(ChurchMark.showsLiturgy(samplePlace(
            id: 81,
            name: "Georgia O'Keeffe Museum",
            category: "museum",
            catholic: false,
            lat: 35.6,
            lon: -105.9
        )))
        XCTAssertNil(HandVerifiedLiturgy.listing(for: tears))
        XCTAssertNil(ParishDirectories.contact(for: tears))
        XCTAssertNil(HandVerifiedLiturgy.listing(for: namesake))

        let card = LiturgyLookup.card(for: olph)
        XCTAssertTrue(card.found)
        XCTAssertEqual(card.phone, "505-256-1539")
        XCTAssertEqual(card.website, "https://www.olphnm.org/")
        XCTAssertEqual(card.verifiedLine, "Last verified 15 Oct 2026")
        XCTAssertTrue(card.note.contains("Call to confirm"))
        XCTAssertTrue(card.note.contains("vary"))
        XCTAssertTrue(card.directory.contains("Eparchy of Phoenix"))
        XCTAssertTrue(card.lines.contains("Sun 8:30 AM Rosary"))
        XCTAssertTrue(card.lines.contains("Sun 9:00 AM Matins"))
        XCTAssertTrue(card.lines.contains("Sun 10:00 AM Divine Liturgy"))
        XCTAssertTrue(card.lines.contains("Mon 9:00 AM Divine Liturgy"))
        XCTAssertTrue(card.lines.contains("Fri 6:00 PM Divine Liturgy"))
        XCTAssertTrue(card.lines.contains("Sat 4:00 PM Great Vespers"))
        XCTAssertTrue(card.lines.contains("Sat 5:00 PM Divine Liturgy"))
        XCTAssertFalse(card.lines.contains { $0.contains("Diving") })

        let basilica = samplePlace(
            id: 1295,
            name: "The Cathedral Basilica of Saint Francis of Assisi",
            category: "worship",
            catholic: true,
            lat: 35.686504,
            lon: -105.93624,
            website: "https://www.cbsfa.org/"
        )
        let empty = LiturgyLookup.card(for: basilica)
        XCTAssertFalse(empty.found)
        XCTAssertEqual(empty.verifiedLine, "Last verified: not yet")
        XCTAssertEqual(empty.website, "https://www.cbsfa.org/")
        XCTAssertTrue(empty.phone.isEmpty)
        XCTAssertEqual(empty.emptyTitle, LiturgyCard.emptyTitle)

        let ids = LiturgyLookup.sources().map(\.id)
        XCTAssertEqual(ids, [LiturgySourceID.handVerified, "cache", LiturgySourceID.parishWebsite])
        XCTAssertEqual(LiturgySourceID.unusedSlots, [LiturgySourceID.massTimesSlot, LiturgySourceID.discoverMassSlot])
        XCTAssertFalse(ids.contains(LiturgySourceID.massTimesSlot))
        XCTAssertFalse(ids.contains(LiturgySourceID.discoverMassSlot))
        let footnote = Copy.text("mass_footnote")
        XCTAssertTrue(footnote.contains("bulletin"))
        XCTAssertTrue(footnote.contains("does not use MassTimes.org or Discover Mass"))

        let structured = """
        <h2>Mass Schedule</h2>
        <p>Sunday 8:00 AM Mass</p>
        <script type="application/ld+json">
        {"@graph":[
          {"@type":"Church","name":"Example"},
          {"@type":["Event"],"name":"Divine Liturgy","startDate":"2026-10-17T17:00:00-06:00"}
        ]}
        </script>
        """
        XCTAssertEqual(
            SchemaEventParser.lines(from: structured),
            ["Sat 17 Oct, 5:00 PM Divine Liturgy"]
        )
        XCTAssertEqual(ParishScheduleParser.lines(from: structured), ["Sat 17 Oct, 5:00 PM Divine Liturgy"])

        let plain = """
        <h2>Mass Schedule</h2>
        <ul>
        <li>Sunday 8:00 AM Mass</li>
        <li>Sunday 10:30 AM Mass</li>
        </ul>
        <p>Confession is available on Saturday from 3:30 PM until 4:30 PM, or by appointment.</p>
        <h2>Office Hours</h2>
        <p>Monday 9:00 AM to 1:00 PM</p>
        """
        XCTAssertEqual(
            ParishScheduleParser.lines(from: plain),
            ["Sunday 8:00 AM Mass", "Sunday 10:30 AM Mass"]
        )
        XCTAssertTrue(ParishScheduleParser.confession(from: plain).contains("3:30 PM"))

        let example = samplePlace(
            id: 9,
            name: "Saint Example",
            category: "worship",
            catholic: true,
            lat: 35.1,
            lon: -106.5,
            website: "https://example.org/parish"
        )
        let cache = LiturgyCache(maxAge: 60)
        let cached = LiturgyListing(
            lines: ["cached line"],
            confession: "",
            verified: "2026-10-01",
            sourceName: "cache",
            sourceURL: "",
            phone: "",
            website: "",
            directory: "",
            confirm: "Call to confirm."
        )
        let saved = Date(timeIntervalSince1970: 1_000)
        cache.save(cached, placeID: example.id, now: saved)
        XCTAssertNil(cache.load(placeID: example.id, now: saved.addingTimeInterval(61)))
        XCTAssertEqual(cache.load(placeID: example.id, now: saved.addingTimeInterval(30))?.lines, ["cached line"])

        let fromPage = LiturgyLookup.card(
            for: example,
            sources: LiturgyLookup.sources(pages: [example.id: plain], verified: "2026-10-16", cache: cache)
        )
        XCTAssertEqual(fromPage.lines, ["Sunday 8:00 AM Mass", "Sunday 10:30 AM Mass"])
        XCTAssertEqual(fromPage.verifiedLine, "Last verified 16 Oct 2026")
        XCTAssertTrue(fromPage.confession.contains("3:30 PM"))
        XCTAssertEqual(fromPage.website, "https://example.org/parish")

        let fromCache = LiturgyLookup.card(
            for: example,
            sources: LiturgyLookup.sources(cache: cache)
        )
        XCTAssertEqual(fromCache.lines, ["cached line"])

        let seeded = LiturgyLookup.card(
            for: olph,
            sources: LiturgyLookup.sources(
                pages: [olph.id: plain],
                verified: "2026-10-01",
                cache: cache
            )
        )
        XCTAssertTrue(seeded.lines.contains("Fri 6:00 PM Divine Liturgy"))
        XCTAssertFalse(seeded.lines.contains("Sunday 8:00 AM Mass"))

        let style = PackStyleDocument.json(
            packURL: "pmtiles://file:///tmp/northern-new-mexico.pmtiles",
            glyphsURL: "file:///tmp/glyphs/{fontstack}/{range}.pbf",
            online: false,
            places: [olph]
        )
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(style.utf8)) as? [String: Any])
        let sources = try XCTUnwrap(root["sources"] as? [String: Any])
        let geo = try XCTUnwrap(sources["pack-places-catholic"] as? [String: Any])
        let clusterOn = (geo["cluster"] as? Bool) ?? ((geo["cluster"] as? NSNumber)?.boolValue ?? false)
        let maxZoom = (geo["clusterMaxZoom"] as? Int) ?? (geo["clusterMaxZoom"] as? NSNumber)?.intValue
        XCTAssertTrue(clusterOn)
        XCTAssertEqual(maxZoom, 13)
        let data = try XCTUnwrap(geo["data"] as? [String: Any])
        let features = try XCTUnwrap(data["features"] as? [[String: Any]])
        let pin = (features[0]["properties"] as? [String: Any])?["pin"] as? String
        XCTAssertEqual(pin, "byzantine")
        let layers = try XCTUnwrap(root["layers"] as? [[String: Any]])
        let catholic = try XCTUnwrap(layers.first { ($0["id"] as? String) == "places-catholic" })
        let layout = try XCTUnwrap(catholic["layout"] as? [String: Any])
        let icon = try XCTUnwrap(layout["icon-image"] as? [Any])
        XCTAssertEqual(icon.first as? String, "coalesce")
        XCTAssertNotNil(layers.first { ($0["id"] as? String) == "places-selected" })
        XCTAssertEqual(PackStyleDocument.clusterRole("cluster-catholic"), "catholic")
        XCTAssertEqual(PackStyleDocument.clusterRole("cluster-worship-count"), "worship")
        XCTAssertNil(PackStyleDocument.clusterRole("places-catholic"))
        let pins = DebugLaunch.parse(["/PilgrimAtlas", "--debug-pins"])
        XCTAssertTrue(pins.showPins)
        XCTAssertTrue(pins.suppressesLocation)
    }

    func testAlbuquerqueSeedStaysOnThePackedParish() {
        XCTAssertEqual(AlbuquerqueParishes.all.count, 33)
        let queen = samplePlace(
            id: 1277,
            name: "Queen of Heaven Catholic Church",
            category: "worship",
            catholic: true,
            lat: 35.112393,
            lon: -106.584821,
            address: "5300 Claremont Avenue Northeast, Albuquerque, NM, 87110"
        )
        let queenCard = LiturgyLookup.card(for: queen)
        XCTAssertTrue(queenCard.found)
        XCTAssertEqual(queenCard.phone, "505-881-1772")
        XCTAssertEqual(queenCard.website, "https://qofhabq.com/")
        XCTAssertEqual(queenCard.verifiedLine, "Last verified 15 Oct 2026")
        XCTAssertTrue(queenCard.directory.contains("Archdiocese of Santa Fe"))
        XCTAssertTrue(queenCard.lines.contains("Sun 7:30 AM Mass"))
        XCTAssertTrue(queenCard.lines.contains("Sat 4:30 PM Vigil"))
        XCTAssertTrue(queenCard.lines.contains("Tue 7:30 AM Mass, only when Chesterton Academy is in session"))

        let chimayo = samplePlace(
            id: 39,
            name: "Holy Family Catholic Church",
            category: "worship",
            catholic: true,
            lat: 35.98983,
            lon: -105.932427,
            address: "#10 Route 76, Chimayo, NM, 87522"
        )
        XCTAssertNil(HandVerifiedLiturgy.listing(for: chimayo))

        let rioRancho = samplePlace(
            id: 1580,
            name: "Saint Thomas Aquinas Catholic Church",
            category: "worship",
            catholic: true,
            lat: 35.232721,
            lon: -106.661767,
            address: "1502 Sara Road Southeast, Rio Rancho, NM, 87124"
        )
        XCTAssertNil(HandVerifiedLiturgy.listing(for: rioRancho))

        let newman = samplePlace(
            id: 1572,
            name: "Saint Thomas Aquinas University Parish",
            category: "worship",
            catholic: true,
            lat: 35.087149,
            lon: -106.623074
        )
        let newmanCard = LiturgyLookup.card(for: newman)
        XCTAssertEqual(newmanCard.phone, "505-247-1094")
        XCTAssertTrue(newmanCard.lines.contains("Sun 5:00 PM Mass, Student Mass; schedule may shift during university breaks"))

        let province = samplePlace(
            id: 922,
            name: "Our Lady of Guadalupe Fransiscan Province",
            category: "worship",
            catholic: true,
            lat: 35.061061,
            lon: -106.717643
        )
        XCTAssertNil(HandVerifiedLiturgy.listing(for: province))

        let guadalupe = samplePlace(
            id: 1280,
            name: "Our Lady of Guadalupe Catholic Church",
            category: "worship",
            catholic: true,
            lat: 35.132775,
            lon: -106.665829
        )
        XCTAssertEqual(LiturgyLookup.card(for: guadalupe).phone, "505-345-4596")

        let edwin = samplePlace(
            id: 499,
            name: "Saint Edwin Catholic Church",
            category: "worship",
            catholic: true,
            lat: 35.031311,
            lon: -106.69052
        )
        let edwinCard = LiturgyLookup.card(for: edwin)
        XCTAssertTrue(edwinCard.lines.allSatisfy { $0.contains("Archdiocese directory only") })
        XCTAssertTrue(edwinCard.note.contains("does not post a schedule"))
        XCTAssertEqual(edwinCard.phone, "505-877-2967")

        let assumption = samplePlace(
            id: 1303,
            name: "Our Lady of the Assumption Catholic Church",
            category: "worship",
            catholic: true,
            lat: 35.086732,
            lon: -106.557555
        )
        let assumptionCard = LiturgyLookup.card(for: assumption)
        XCTAssertTrue(assumptionCard.lines.contains("Sun 7:30 AM Mass"))
        XCTAssertTrue(assumptionCard.lines.contains("Mon 8:30 AM Mass, Archdiocese directory only"))

        let jemez = samplePlace(
            id: 1471,
            name: "Our Lady of the Assumption Catholic Church",
            category: "worship",
            catholic: true,
            lat: 35.768,
            lon: -106.692459
        )
        XCTAssertNil(HandVerifiedLiturgy.listing(for: jemez))
        XCTAssertFalse(AlbuquerqueParishes.all.contains { $0.name.contains("Queen of Peace") || $0.name.contains("Pius") })
    }

    private func packedSkylineGeometry() -> GeoJSONGeometry? {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: LogicTests.self)
        #endif
        guard let url = bundle.url(forResource: "skyline-trail", withExtension: "geojson") else {
            return nil
        }
        return GeoJSONParser.geometry(from: (try? Data(contentsOf: url)) ?? Data())
    }

    private func screenshotPlaces() -> [PlaceRecord] {
        [
            samplePlace(id: 54, name: "Santuario de Chimayo", category: "worship", catholic: false, lat: 35.988871, lon: -105.931459),
            samplePlace(
                id: 585,
                name: "Santuario de Chimayo",
                category: "worship",
                catholic: true,
                lat: 35.989078,
                lon: -105.931922,
                wikidata: "Q5352121"
            ),
            samplePlace(
                id: 186,
                name: "El Santuario de Chimayo Historic Site",
                category: "worship",
                catholic: true,
                lat: 35.9892,
                lon: -105.9320
            ),
            samplePlace(
                id: 1295,
                name: "The Cathedral Basilica of Saint Francis of Assisi",
                category: "worship",
                catholic: true,
                lat: 35.686504,
                lon: -105.93624,
                address: "231 Cathedral Place, Santa Fe, NM, 87501",
                website: "https://www.cbsfa.org/",
                wikipedia: "en:Cathedral Basilica of St. Francis of Assisi (Santa Fe)",
                wikidata: "Q3663700"
            ),
            samplePlace(
                id: 1296,
                name: "Loretto Chapel",
                category: "landmark",
                catholic: false,
                lat: 35.685617,
                lon: -105.937454,
                wikidata: "Q2956557"
            ),
        ]
    }

    private func hit(
        _ kind: String,
        lon: Double,
        lat: Double,
        name: String = "",
        pubAccess: String = "",
        size: Double = 0.02
    ) -> LandHit {
        let ring = [
            LonLat(lon: lon, lat: lat),
            LonLat(lon: lon + size, lat: lat),
            LonLat(lon: lon + size, lat: lat + size),
            LonLat(lon: lon, lat: lat + size),
            LonLat(lon: lon, lat: lat),
        ]
        return LandHit(
            kind: LandKind.fromPack(kind),
            name: name,
            manager: "",
            pubAccess: pubAccess,
            source: "test",
            sourceDate: "2026-10-03",
            geometry: .polygon([ring])
        )
    }

    private func samplePlace(
        id: Int = 1,
        name: String,
        category: String,
        catholic: Bool,
        lat: Double,
        lon: Double,
        address: String = "",
        openingHours: String = "",
        serviceTimes: String = "",
        access: String = "",
        website: String = "",
        wikipedia: String = "",
        wikidata: String = "",
        image: String = "",
        sourceDate: String = "2026-10-02",
        denomination: String? = nil
    ) -> PlaceRecord {
        PlaceRecord(
            id: id,
            name: name,
            category: category,
            catholic: catholic,
            denomination: denomination ?? (catholic ? "roman_catholic" : ""),
            lat: lat,
            lon: lon,
            description: "",
            address: address,
            openingHours: openingHours,
            serviceTimes: serviceTimes,
            massTimes: "",
            confessionTimes: "",
            access: access,
            parking: "",
            wheelchair: "",
            website: website,
            wikipedia: wikipedia,
            wikidata: wikidata,
            image: image,
            source: "OpenStreetMap",
            sourceDate: sourceDate
        )
    }

    private func perpetualHelp() -> PlaceRecord {
        samplePlace(
            id: 334,
            name: "Our Lady of Perpetual Help",
            category: "worship",
            catholic: true,
            lat: 35.096452,
            lon: -106.582347,
            address: "1837 Alvarado Drive Northeast, Albuquerque, NM, 87110",
            website: "https://www.olphnm.org/",
            denomination: "ruthenian_catholic"
        )
    }
}
