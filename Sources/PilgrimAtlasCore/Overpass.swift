import Foundation

/// Builds and reads an Overpass answer. The network call lives in the app.
package enum OverpassQuery {
    package static let maxSpan = 0.9
    package static let minimumZoom = 10.0
    package static let resultCap = 250

    package static func allows(south: Double, west: Double, north: Double, east: Double, zoom: Double) -> Bool {
        guard zoom >= minimumZoom else { return false }
        guard north > south, east > west else { return false }
        return (north - south) <= maxSpan && (east - west) <= maxSpan
    }

    package static func cacheKey(south: Double, west: Double, north: Double, east: Double) -> String {
        func snap(_ value: Double) -> String { String(format: "%.2f", (value * 50).rounded() / 50) }
        return [snap(south), snap(west), snap(north), snap(east)].joined(separator: ",")
    }

    /// Christian worship, plus Catholic, Orthodox, and SSPX tags when religion is missing.
    /// Form body for a POST. `=` inside the query must be percent-encoded or the server cuts the statement off.
    package static func formBody(for statement: String) -> Data? {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "data", value: statement)]
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    package static func statement(south: Double, west: Double, north: Double, east: Double) -> String {
        let box = "\(south),\(west),\(north),\(east)"
        return """
        [out:json][timeout:25];
        (
          nwr["amenity"="place_of_worship"]["religion"="christian"](\(box));
          nwr["amenity"="place_of_worship"]["denomination"~"catholic|orthodox|sspx|fsspx|byzantine|ruthenian|maronite|melkite",i](\(box));
          nwr["historic"~"church|monastery|wayside_shrine"](\(box));
        );
        out center tags \(resultCap);
        """
    }

    package static func places(from json: Data, fetchedOn: String) -> [PlaceRecord] {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let elements = root["elements"] as? [[String: Any]]
        else { return [] }
        var places: [PlaceRecord] = []
        for element in elements {
            guard let place = place(from: element, fetchedOn: fetchedOn) else { continue }
            if Faith.kind(for: place) == .nonChristian { continue }
            let duplicate = places.contains { existing in
                Geometry.haversineMeters(existing.coordinate, place.coordinate) <= 70
                    && AtlasQuery.fold(existing.name) == AtlasQuery.fold(place.name)
            }
            if !duplicate { places.append(place) }
        }
        return places
    }

    private static func place(from element: [String: Any], fetchedOn: String) -> PlaceRecord? {
        let tags = element["tags"] as? [String: Any] ?? [:]
        let name = string(tags["name"])
        guard !name.isEmpty else { return nil }
        guard let lat = coordinate(element, key: "lat"), let lon = coordinate(element, key: "lon") else { return nil }
        let denomination = Catholic.normalize(string(tags["denomination"]))
        let religion = Catholic.normalize(string(tags["religion"]))
        let kind = Faith.kind(name: name, category: "worship", denomination: denomination, catholic: false)
        if religion == "muslim" || religion == "hindu" || religion == "buddhist" || religion == "sikh" || religion == "jewish" {
            return nil
        }
        let catholic = kind == .catholic
        let website = first(tags, ["website", "contact:website", "url"])
        let phone = first(tags, ["phone", "contact:phone", "phone:mobile"])
        let address = postalAddress(tags)
        let identifier = stableID(element)
        return PlaceRecord(
            id: identifier,
            name: name,
            category: "worship",
            catholic: catholic,
            denomination: denomination,
            lat: lat,
            lon: lon,
            description: "",
            address: address,
            openingHours: string(tags["opening_hours"]),
            serviceTimes: "",
            massTimes: "",
            confessionTimes: "",
            access: "",
            parking: "",
            wheelchair: "",
            website: website,
            wikipedia: "",
            wikidata: "",
            image: "",
            source: "OpenStreetMap",
            sourceDate: fetchedOn,
            phone: phone
        )
    }

    private static func stableID(_ element: [String: Any]) -> Int {
        let raw = (element["id"] as? NSNumber)?.int64Value ?? Int64(element["id"] as? Int ?? 0)
        let type = element["type"] as? String ?? "node"
        let shifted: Int64
        switch type {
        case "way":
            shifted = raw &+ 2_000_000_000_000
        case "relation":
            shifted = raw &+ 4_000_000_000_000
        default:
            shifted = raw
        }
        let negative = shifted > 0 ? -shifted : shifted
        return Int(negative)
    }

    private static func coordinate(_ element: [String: Any], key: String) -> Double? {
        if let number = element[key] as? Double { return number }
        if let number = element[key] as? NSNumber { return number.doubleValue }
        if let center = element["center"] as? [String: Any] {
            if let number = center[key] as? Double { return number }
            if let number = center[key] as? NSNumber { return number.doubleValue }
        }
        return nil
    }

    private static func postalAddress(_ tags: [String: Any]) -> String {
        let full = string(tags["addr:full"])
        if !full.isEmpty { return full }
        let parts = ["addr:housenumber", "addr:street", "addr:city", "addr:state", "addr:postcode"].map { string(tags[$0]) }.filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    private static func first(_ tags: [String: Any], _ keys: [String]) -> String {
        for key in keys {
            let value = string(tags[key])
            if !value.isEmpty { return value }
        }
        return ""
    }

    private static func string(_ value: Any?) -> String {
        if let text = value as? String { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        return ""
    }
}

package enum PlaceMerge {
    /// Keeps the first record when a later pin is the same named place.
    /// Matching uses a coarse grid so a full pack does not compare every pair on launch.
    package static func combine(pack: [PlaceRecord], remote: [PlaceRecord]) -> [PlaceRecord] {
        var kept = pack
        var grid = PlaceGrid(kept)
        for place in remote {
            if let index = grid.match(place, in: kept) {
                kept[index] = fillEmpty(kept[index], from: place)
                continue
            }
            grid.insert(place, at: kept.count)
            kept.append(place)
        }
        return kept
    }

    /// Incoming chapels replace a nearby same-name pin. The chapel keeps its affiliation.
    package static func install(_ incoming: [PlaceRecord], into existing: [PlaceRecord]) -> [PlaceRecord] {
        var kept = existing
        var grid = PlaceGrid(kept)
        for place in incoming {
            if let index = grid.match(place, in: kept) {
                var winner = place
                winner = fillEmpty(winner, from: kept[index])
                kept[index] = winner
                grid.insert(winner, at: index)
                continue
            }
            grid.insert(place, at: kept.count)
            kept.append(place)
        }
        return kept
    }

    package static func worshipNamesMatch(_ left: String, _ right: String) -> Bool {
        let a = worshipKey(left)
        let b = worshipKey(right)
        if a.isEmpty || b.isEmpty { return false }
        return a == b || a.contains(b) || b.contains(a)
    }

    fileprivate static func sameSite(_ left: PlaceRecord, _ right: PlaceRecord) -> Bool {
        let eitherSSPX = Faith.kind(for: left) == .sspx || Faith.kind(for: right) == .sspx
        let radius = eitherSSPX ? 200.0 : 80.0
        guard Geometry.haversineMeters(left.coordinate, right.coordinate) <= radius else { return false }
        return worshipNamesMatch(left.name, right.name)
    }

    /// Copies contact fields the kept pin does not already have. Affiliation stays on the kept pin.
    private static func fillEmpty(_ kept: PlaceRecord, from extra: PlaceRecord) -> PlaceRecord {
        var place = kept
        if place.address.isEmpty { place.address = extra.address }
        if place.phone.isEmpty { place.phone = extra.phone }
        if place.website.isEmpty { place.website = extra.website }
        if place.wikipedia.isEmpty { place.wikipedia = extra.wikipedia }
        if place.wikidata.isEmpty { place.wikidata = extra.wikidata }
        if place.image.isEmpty { place.image = extra.image }
        return place
    }

    private static func worshipKey(_ name: String) -> String {
        let drop: Set<String> = ["church", "chapel", "mission", "catholic", "roman", "the", "parish", "priory", "shrine", "of", "and"]
        let tokens = AtlasQuery.searchText(name).split(separator: " ").map { token -> String in
            if token == "sts" || token == "ss" { return "saints" }
            return String(token)
        }
        return tokens.filter { !drop.contains($0) }.joined(separator: " ")
    }
}

/// About 330 m cells. A match only looks at the home cell and its neighbors.
private struct PlaceGrid {
    private var cells: [Cell: [Int]] = [:]
    private static let step = 0.003

    init(_ places: [PlaceRecord]) {
        cells.reserveCapacity(places.count)
        for (index, place) in places.enumerated() {
            insert(place, at: index)
        }
    }

    mutating func insert(_ place: PlaceRecord, at index: Int) {
        cells[Self.cell(place.coordinate), default: []].append(index)
    }

    func match(_ place: PlaceRecord, in kept: [PlaceRecord]) -> Int? {
        let origin = Self.cell(place.coordinate)
        for latOffset in -1...1 {
            for lonOffset in -1...1 {
                let key = Cell(lat: origin.lat + latOffset, lon: origin.lon + lonOffset)
                for index in cells[key] ?? [] where index < kept.count {
                    if PlaceMerge.sameSite(kept[index], place) {
                        return index
                    }
                }
            }
        }
        return nil
    }

    private static func cell(_ coordinate: LonLat) -> Cell {
        Cell(
            lat: Int((coordinate.lat / step).rounded()),
            lon: Int((coordinate.lon / step).rounded())
        )
    }

    private struct Cell: Hashable {
        var lat: Int
        var lon: Int
    }
}
