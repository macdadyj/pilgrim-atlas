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
    package var url: String?
}

package struct NearbySummary: Equatable, Sendable {
    package var land: String
    package var landKind: String
    package var landSource: String
    package var landSourceDate: String
    package var headline: String
    package var permissionLine: String
    package var landmarks: [ExploreRow]
    package var landmarkGap: String
    package var explore: [ExploreRow]
    package var trails: [TrailRow]
    package var trailGap: String
    package var closures: [String]
    package var notASurvey: String
}

package struct ExploreRow: Equatable, Sendable, Identifiable {
    package var id: String
    package var placeId: Int
    package var name: String
    package var category: String
    package var meters: Int
    package var catholic: Bool
}

package struct TrailRow: Equatable, Sendable, Identifiable {
    package var id: String
    package var trailId: Int
    package var name: String
    package var meters: Int
    package var access: String
}

package enum SearchKind: String, Equatable, Sendable {
    case place
    case trail
    case note
    case town
    case land
}

package struct SearchHit: Equatable, Sendable, Identifiable {
    package var id: String
    package var kind: SearchKind
    package var name: String
    package var catholic: Bool
    package var placeId: Int?
    package var trailId: Int?
    package var lat: Double?
    package var lon: Double?
    package var city: String
    package var meters: Int?
    package var subtitle: String
}

package enum AtlasQuery {
    package static func fold(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// `St`, `St.`, and `Saint` become the same token. Punctuation splits tokens.
    package static func searchText(_ value: String) -> String {
        let folded = fold(value)
        var token = ""
        var tokens: [String] = []
        func flush() {
            if token.isEmpty { return }
            tokens.append(token == "st" || token == "saint" ? "saint" : token)
            token = ""
        }
        for character in folded {
            if character.isLetter || character.isNumber {
                token.append(character)
            } else {
                flush()
            }
        }
        flush()
        return tokens.joined(separator: " ")
    }

    package static func nearby(
        lat: Double,
        lon: Double,
        places: [PlaceRecord],
        trails: [TrailRecord],
        lands: [LandHit],
        exploreKilometers: Double = 8,
        trailKilometers: Double = 3,
        filter: AtlasFilter = .empty,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> NearbySummary {
        let point = LonLat(lon: lon, lat: lat)
        let listedPlaces = places.filter { MapFilter.includeInLists($0, filter: filter, now: now, timeZone: timeZone) }
        let listedTrails = filter.showsTrails ? trails : []
        let (hit, landText) = LandStatus.status(lon: lon, lat: lat, hits: lands)
        let explore = listedPlaces
            .map { place -> (Double, PlaceRecord) in
                (Geometry.haversineMeters(point, place.coordinate), place)
            }
            .filter { $0.0 <= exploreKilometers * 1000 }
            .sorted { $0.0 < $1.0 }
            .prefix(8)
            .map { meters, place in
                exploreRow(place, meters: meters)
            }
        let landmarks = landmarkRows(point: point, places: listedPlaces, kilometers: exploreKilometers)
        let anyPlace = listedPlaces.contains { Geometry.haversineMeters(point, $0.coordinate) <= exploreKilometers * 1000 }
        let landmarkGap: String
        if !landmarks.isEmpty {
            landmarkGap = ""
        } else if anyPlace {
            landmarkGap = "No Catholic landmark within 8 km"
        } else {
            landmarkGap = "No landmark within 8 km"
        }
        let trailRows = listedTrails.compactMap { trail -> TrailRow? in
            guard let distance = Geometry.distanceToLineMeters(point, trail.geometry), distance <= trailKilometers * 1000 else {
                return nil
            }
            return TrailRow(
                id: "trail-\(trail.id)-\(Int(distance.rounded()))",
                trailId: trail.id,
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
            headline: MapFilter.landHeadline(hit: hit, filter: filter, fallback: LandStatus.headline(hit)),
            permissionLine: PlaceText.permissionLine,
            landmarks: landmarks,
            landmarkGap: landmarkGap,
            explore: explore,
            trails: Array(trailRows),
            trailGap: filter.showsTrails ? (trailRows.isEmpty ? "No trail within 3 km" : "") : "",
            closures: closures,
            notASurvey: Copy.text("not_a_survey")
        )
    }

    package static func search(
        _ query: String,
        places: [PlaceRecord],
        trails: [TrailRecord],
        origin: LonLat = DebugPin.plaza,
        limit: Int = 30,
        lands: [LandHit] = [],
        filter: AtlasFilter = .empty,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> [SearchHit] {
        let needle = searchText(query)
        if needle.isEmpty { return [] }
        let queryTokens = needle.split(separator: " ").map(String.init)
        let listedPlaces = places.filter { MapFilter.includeInLists($0, filter: filter, now: now, timeZone: timeZone) }
        let listedTrails = filter.showsTrails ? trails : []
        var scored: [(Double, SearchHit)] = []
        let unnamedCount = places.filter { fold($0.name) == fold("Unnamed place of worship") }.count
        for place in listedPlaces {
            if fold(place.name) == fold("Unnamed place of worship") { continue }
            guard let score = matchScore(needle: needle, queryTokens: queryTokens, name: place.name) else { continue }
            let meters = Int(Geometry.haversineMeters(origin, place.coordinate).rounded())
            let adjusted = score + Double(PlaceText.richness(place)) * 5 - Double(meters) / 1000
            let subtitle = PlaceText.sameSiteNote(for: place, among: places) ?? PlaceText.kindLabel(for: place)
            scored.append((
                adjusted,
                SearchHit(
                    id: "place-\(place.id)",
                    kind: .place,
                    name: place.name,
                    catholic: place.catholic,
                    placeId: place.id,
                    trailId: nil,
                    lat: place.lat,
                    lon: place.lon,
                    city: PlaceText.cityLabel(address: place.address, coordinate: place.coordinate),
                    meters: meters,
                    subtitle: subtitle
                )
            ))
        }
        for trail in listedTrails {
            let displayName = trail.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if displayName.isEmpty { continue }
            guard let score = matchScore(needle: needle, queryTokens: queryTokens, name: displayName) else { continue }
            let point = representative(trail.geometry)
            let meters = point.map { Int(Geometry.haversineMeters(origin, $0).rounded()) }
            let adjusted = score + 40 - Double(meters ?? 0) / 1000
            scored.append((
                adjusted,
                SearchHit(
                    id: "trail-\(trail.id)",
                    kind: .trail,
                    name: displayName,
                    catholic: false,
                    placeId: nil,
                    trailId: trail.id,
                    lat: point?.lat,
                    lon: point?.lon,
                    city: point.map { PlaceText.cityLabel(address: "", coordinate: $0) } ?? "",
                    meters: meters,
                    subtitle: "Hiking trail"
                )
            ))
        }
        for town in PlaceText.towns {
            guard let score = matchScore(needle: needle, queryTokens: queryTokens, name: town.name) else { continue }
            let meters = Int(Geometry.haversineMeters(origin, town.coordinate).rounded())
            scored.append((
                score - 1050 - Double(meters) / 1000,
                SearchHit(
                    id: "town-\(fold(town.name))",
                    kind: .town,
                    name: town.name,
                    catholic: false,
                    placeId: nil,
                    trailId: nil,
                    lat: town.coordinate.lat,
                    lon: town.coordinate.lon,
                    city: town.name,
                    meters: meters,
                    subtitle: "Town"
                )
            ))
        }
        for land in lands {
            let displayName = land.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if displayName.isEmpty { continue }
            guard let score = matchScore(needle: needle, queryTokens: queryTokens, name: displayName) else { continue }
            guard let box = land.geometry.bbox else { continue }
            let center = LonLat(lon: (box.minLon + box.maxLon) / 2, lat: (box.minLat + box.maxLat) / 2)
            let meters = Int(Geometry.haversineMeters(origin, center).rounded())
            scored.append((
                score + 20 - Double(meters) / 1000,
                SearchHit(
                    id: "land-\(land.kind.rawValue)-\(fold(displayName))-\(meters)",
                    kind: .land,
                    name: displayName,
                    catholic: false,
                    placeId: nil,
                    trailId: nil,
                    lat: center.lat,
                    lon: center.lon,
                    city: "",
                    meters: meters,
                    subtitle: "Land"
                )
            ))
        }
        var ordered = scored.sorted { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0 > rhs.0 }
            return lhs.1.id < rhs.1.id
        }.map(\.1)
        let groupUnnamed = queryTokens.contains("unnamed")
            || (filter.churches && (queryTokens.contains("worship") || queryTokens.contains("church")))
        if groupUnnamed, unnamedCount > 0 {
            ordered.append(
                SearchHit(
                    id: "note-unnamed-worship",
                    kind: .note,
                    name: "Unnamed worship (\(unnamedCount))",
                    catholic: false,
                    placeId: nil,
                    trailId: nil,
                    lat: nil,
                    lon: nil,
                    city: "",
                    meters: nil,
                    subtitle: "These dots have no name in OpenStreetMap."
                )
            )
        }
        return Array(ordered.prefix(limit))
    }

    package static func facts(for place: PlaceRecord) -> [FactLine] {
        let source = PlaceText.sourceLine(source: place.source, sourceDate: place.sourceDate)
        var lines: [FactLine] = []
        func add(_ label: String, _ value: String, url: String? = nil) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return }
            lines.append(FactLine(id: label, label: label, value: trimmed, source: source, url: url))
        }
        add("Description", place.description)
        add("Address", place.address, url: PlaceText.mapsURL(for: place.address))
        let hours = PlaceText.hoursDisplay(place.openingHours)
        if !hours.shown.isEmpty {
            add("Hours", hours.shown)
        }
        if let note = hours.note {
            lines.append(FactLine(id: "hours-note", label: "Hours note", value: note, source: source, url: nil))
        }
        add("Service times", place.serviceTimes)
        add("Mass times", place.massTimes)
        add("Confession times", place.confessionTimes)
        if let access = PlaceText.accessSentence(place.access) {
            add("Access", access)
        }
        add("Parking", place.parking)
        add("Wheelchair", place.wheelchair)
        if let website = PlaceText.websiteURL(place.website) {
            add("Website", website, url: website)
        }
        if let wikipedia = PlaceText.wikipediaURL(place.wikipedia) {
            add("Wikipedia", place.wikipedia, url: wikipedia)
        }
        if let wikidata = PlaceText.wikidataURL(place.wikidata) {
            add("Wikidata", place.wikidata, url: wikidata)
        }
        if let photo = PlaceText.photoURL(place.image) {
            add("Photo", photo, url: photo)
        }
        if !place.openingHours.isEmpty && !place.serviceTimes.isEmpty {
            lines.append(
                FactLine(
                    id: "schedules",
                    label: "Schedules",
                    value: "Hours and service times both came from OpenStreetMap and may not agree. They are shown raw.",
                    source: source,
                    url: nil
                )
            )
        }
        return lines
    }

    package static func trailSentence(_ access: String) -> String {
        accessLine(access)
    }

    private static func exploreRow(_ place: PlaceRecord, meters: Double) -> ExploreRow {
        ExploreRow(
            id: "place-\(place.id)",
            placeId: place.id,
            name: place.name,
            category: PlaceText.kindLabel(for: place),
            meters: Int(meters.rounded()),
            catholic: place.catholic
        )
    }

    private static func landmarkRows(point: LonLat, places: [PlaceRecord], kilometers: Double) -> [ExploreRow] {
        let ranked = places
            .map { place in (Geometry.haversineMeters(point, place.coordinate), place) }
            .filter { $0.0 <= kilometers * 1000 }
            .sorted { $0.0 < $1.0 }
        var chosen: [(Double, PlaceRecord)] = []
        if let catholic = ranked.first(where: { $0.1.catholic && $0.1.category == "worship" }) {
            chosen.append(catholic)
        }
        let featured = ["chapel", "cathedral", "basilica", "santuario"]
        for item in ranked where item.0 <= 800 {
            let folded = fold(item.1.name)
            let special = featured.contains { folded.contains($0) }
            if special, !chosen.contains(where: { $0.1.id == item.1.id }) {
                chosen.append(item)
            }
            if chosen.count >= 3 { break }
        }
        return chosen.map { exploreRow($0.1, meters: $0.0) }
    }

    private static func matchScore(needle: String, queryTokens: [String], name: String) -> Double? {
        let nameText = searchText(name)
        let nameTokens = Set(nameText.split(separator: " ").map(String.init))
        let allTokens = queryTokens.allSatisfy { nameTokens.contains($0) }
        if !allTokens && !nameText.contains(needle) { return nil }
        let overlap = queryTokens.filter { nameTokens.contains($0) }.count
        let coverage = Double(overlap) / Double(max(nameTokens.count, 1))
        var score = coverage * 40
        if allTokens { score += 100 }
        if nameText.contains(needle) { score += 200 }
        if nameText == needle { score += 1000 }
        return score
    }

    private static func representative(_ geometry: GeoJSONGeometry) -> LonLat? {
        guard let box = geometry.bbox else { return nil }
        return LonLat(lon: (box.minLon + box.maxLon) / 2, lat: (box.minLat + box.maxLat) / 2)
    }

    private static func accessLine(_ access: String) -> String {
        let cleaned = access.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return Copy.text("trail_untagged") }
        return "Tagged access=\(cleaned). That tag is not permission to enter or to leave the trail."
    }
}
