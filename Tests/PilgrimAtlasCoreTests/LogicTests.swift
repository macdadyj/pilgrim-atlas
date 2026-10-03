import XCTest
@testable import PilgrimAtlasCore

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

    private func hit(_ kind: String, lon: Double, lat: Double, name: String = "") -> LandHit {
        let ring = [
            LonLat(lon: lon, lat: lat),
            LonLat(lon: lon + 0.02, lat: lat),
            LonLat(lon: lon + 0.02, lat: lat + 0.02),
            LonLat(lon: lon, lat: lat + 0.02),
            LonLat(lon: lon, lat: lat),
        ]
        return LandHit(
            kind: LandKind.fromPack(kind),
            name: name,
            manager: "",
            pubAccess: "",
            source: "test",
            sourceDate: "2026-10-03",
            geometry: .polygon([ring])
        )
    }

    private func samplePlace(
        name: String,
        category: String,
        catholic: Bool,
        lat: Double,
        lon: Double,
        serviceTimes: String = ""
    ) -> PlaceRecord {
        PlaceRecord(
            id: 1,
            name: name,
            category: category,
            catholic: catholic,
            denomination: catholic ? "roman_catholic" : "",
            lat: lat,
            lon: lon,
            description: "",
            address: "",
            openingHours: "",
            serviceTimes: serviceTimes,
            massTimes: "",
            confessionTimes: "",
            access: "",
            parking: "",
            wheelchair: "",
            website: "",
            wikipedia: "",
            wikidata: "",
            image: "",
            source: "OpenStreetMap",
            sourceDate: "2026-10-02"
        )
    }
}
