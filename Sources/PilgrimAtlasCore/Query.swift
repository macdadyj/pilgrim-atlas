import Foundation

package struct PlaceRecord: Equatable, Sendable, Identifiable {
    package var id: Int
    package var name: String
    package var category: String
    package var catholic: Bool
    package var denomination: String
    package var lat: Double
    package var lon: Double
    package var description: String
    package var address: String
    package var openingHours: String
    package var serviceTimes: String
    package var massTimes: String
    package var confessionTimes: String
    package var access: String
    package var parking: String
    package var wheelchair: String
    package var website: String
    package var wikipedia: String
    package var wikidata: String
    package var image: String
    package var source: String
    package var sourceDate: String

    package init(
        id: Int,
        name: String,
        category: String,
        catholic: Bool,
        denomination: String,
        lat: Double,
        lon: Double,
        description: String,
        address: String,
        openingHours: String,
        serviceTimes: String,
        massTimes: String,
        confessionTimes: String,
        access: String,
        parking: String,
        wheelchair: String,
        website: String,
        wikipedia: String,
        wikidata: String,
        image: String,
        source: String,
        sourceDate: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.catholic = catholic
        self.denomination = denomination
        self.lat = lat
        self.lon = lon
        self.description = description
        self.address = address
        self.openingHours = openingHours
        self.serviceTimes = serviceTimes
        self.massTimes = massTimes
        self.confessionTimes = confessionTimes
        self.access = access
        self.parking = parking
        self.wheelchair = wheelchair
        self.website = website
        self.wikipedia = wikipedia
        self.wikidata = wikidata
        self.image = image
        self.source = source
        self.sourceDate = sourceDate
    }

    package var coordinate: LonLat { LonLat(lon: lon, lat: lat) }
}

package struct TrailRecord: Equatable, Sendable, Identifiable {
    package var id: Int
    package var name: String
    package var access: String
    package var geometry: GeoJSONGeometry
    package var source: String
    package var sourceDate: String

    package init(id: Int, name: String, access: String, geometry: GeoJSONGeometry, source: String, sourceDate: String) {
        self.id = id
        self.name = name
        self.access = access
        self.geometry = geometry
        self.source = source
        self.sourceDate = sourceDate
    }
}

package struct LinkRecord: Equatable, Sendable, Identifiable {
    package var id: Int
    package var title: String
    package var url: String
    package var note: String

    package init(id: Int, title: String, url: String, note: String) {
        self.id = id
        self.title = title
        self.url = url
        self.note = note
    }
}

package struct FactLine: Equatable, Sendable, Identifiable {
    package var id: String
    package var label: String
    package var value: String
    package var source: String
}

package struct NearbySummary: Equatable, Sendable {
    package var land: String
    package var landKind: String
    package var landSource: String
    package var landSourceDate: String
    package var explore: [ExploreRow]
    package var trails: [TrailRow]
    package var closures: [String]
    package var notASurvey: String
}

package struct ExploreRow: Equatable, Sendable, Identifiable {
    package var id: String { name }
    package var name: String
    package var category: String
    package var meters: Int
    package var catholic: Bool
}

package struct TrailRow: Equatable, Sendable, Identifiable {
    package var id: String { "\(name)-\(meters)" }
    package var name: String
    package var meters: Int
    package var access: String
}

package struct SearchHit: Equatable, Sendable, Identifiable {
    package var id: String { "\(kind)-\(name)" }
    package var kind: String
    package var name: String
    package var catholic: Bool
    package var lat: Double?
    package var lon: Double?
}

package enum AtlasQuery {
    package static func fold(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    package static func nearby(
        lat: Double,
        lon: Double,
        places: [PlaceRecord],
        trails: [TrailRecord],
        lands: [LandHit],
        exploreKilometers: Double = 8,
        trailKilometers: Double = 3
    ) -> NearbySummary {
        let point = LonLat(lon: lon, lat: lat)
        let (hit, landText) = LandStatus.status(lon: lon, lat: lat, hits: lands)
        let explore = places
            .map { place -> (Double, PlaceRecord) in
                (Geometry.haversineMeters(point, place.coordinate), place)
            }
            .filter { $0.0 <= exploreKilometers * 1000 }
            .sorted { $0.0 < $1.0 }
            .prefix(8)
            .map { meters, place in
                let category = place.catholic ? "Catholic landmark" : place.category.replacingOccurrences(of: "_", with: " ")
                return ExploreRow(name: place.name, category: category, meters: Int(meters.rounded()), catholic: place.catholic)
            }
        let trailRows = trails.compactMap { trail -> TrailRow? in
            guard let distance = Geometry.distanceToLineMeters(point, trail.geometry), distance <= trailKilometers * 1000 else {
                return nil
            }
            return TrailRow(
                name: trail.name.isEmpty ? "Unnamed hiking route" : trail.name,
                meters: Int(distance.rounded()),
                access: accessLine(trail.access)
            )
        }
        .sorted { $0.meters < $1.meters }
        .prefix(6)
        var closures = [Copy.text("closures")]
        if hit?.pubAccess.uppercased() == "XA" {
            closures.append("The land record under this point maps public access as closed. That is not a live alert.")
        }
        if let hit, hit.kind == .abqClosed {
            let label = hit.name.isEmpty ? "An Open Space unit" : hit.name
            closures.append("\(label) is mapped closed to the public.")
        }
        return NearbySummary(
            land: landText,
            landKind: hit?.kind.rawValue ?? "",
            landSource: hit?.source ?? "",
            landSourceDate: hit?.sourceDate ?? "",
            explore: explore,
            trails: Array(trailRows),
            closures: closures,
            notASurvey: Copy.text("not_a_survey")
        )
    }

    package static func search(_ query: String, places: [PlaceRecord], trails: [TrailRecord], limit: Int = 30) -> [SearchHit] {
        let needle = fold(query).trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return [] }
        var rows: [SearchHit] = []
        for place in places where fold(place.name).contains(needle) {
            rows.append(SearchHit(kind: "place", name: place.name, catholic: place.catholic, lat: place.lat, lon: place.lon))
        }
        for trail in trails where fold(trail.name).contains(needle) {
            rows.append(SearchHit(kind: "trail", name: trail.name, catholic: false, lat: nil, lon: nil))
        }
        return Array(rows.prefix(limit))
    }

    package static func facts(for place: PlaceRecord) -> [FactLine] {
        let source = "\(place.source), \(place.sourceDate)"
        var lines: [FactLine] = []
        func add(_ label: String, _ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return }
            lines.append(FactLine(id: label, label: label, value: trimmed, source: source))
        }
        add("Description", place.description)
        add("Address", place.address)
        add("Hours", place.openingHours)
        add("Service times", place.serviceTimes)
        add("Mass times", place.massTimes)
        add("Confession times", place.confessionTimes)
        add("Access", place.access)
        add("Parking", place.parking)
        add("Wheelchair", place.wheelchair)
        add("Website", place.website)
        add("Wikipedia", place.wikipedia)
        add("Wikidata", place.wikidata)
        add("Photo", place.image)
        if !place.openingHours.isEmpty && !place.serviceTimes.isEmpty {
            lines.append(
                FactLine(
                    id: "schedules",
                    label: "Schedules",
                    value: "Hours and service times both came from OpenStreetMap and may not agree. They are shown raw.",
                    source: source
                )
            )
        }
        return lines
    }

    private static func accessLine(_ access: String) -> String {
        let cleaned = access.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return Copy.text("trail_untagged") }
        return "Tagged access=\(cleaned). That tag is not permission to enter or to leave the trail."
    }
}
