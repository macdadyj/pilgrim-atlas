import Foundation

package enum DebugAppearance: String, Equatable, Sendable {
    case light
    case dark
}

/// Debug-only screenshot launch. Release builds parse every argument list as inactive,
/// and the flag spellings are compiled out.
package struct DebugLaunch: Equatable, Sendable {
    package var pinPlaza: Bool
    package var openPlace: String?
    package var search: String?
    package var showLayers: Bool
    package var showPlacesPicker: Bool
    package var showDisclaimer: Bool
    package var disclaimerDetailsOpen: Bool
    package var tap: LonLat?
    package var filterTokens: [String]
    package var showTerrain: Bool
    package var focusFood: Bool
    package var outsideCoverage: Bool
    /// Opens the nearby card at the 40 percent detent, with no drag.
    package var cardFull: Bool
    package var appearance: DebugAppearance?
    package var showSettings: Bool
    package var showFilters: Bool
    package var showNearby: Bool
    package var showOnboarding: Bool
    /// `map`, `search`, or `settings`.
    package var tab: String?
    /// One landmark role, such as `catholic` or `chapel`.
    package var onlyRole: String?
    package var center: LonLat?
    /// A stand-in GPS fix, such as a ZIP centroid, with no location prompt.
    package var simulatedUser: LonLat?
    /// Draws every church pin, including the selected state, for a screenshot.
    package var showPins: Bool
    /// A fixed city-search row. UI tests use this so Denver does not wait on Apple's geocoder
    /// or on Overpass for the one church that proves the map left the offline pack.
    package var stubGeocode: StubGeocode?

    package struct StubGeocode: Equatable, Sendable {
        package var name: String
        package var coordinate: LonLat
    }

    package static let inactive = DebugLaunch(
        pinPlaza: false,
        openPlace: nil,
        search: nil,
        showLayers: false,
        showPlacesPicker: false,
        showDisclaimer: false,
        disclaimerDetailsOpen: false,
        tap: nil,
        filterTokens: [],
        showTerrain: false,
        focusFood: false,
        outsideCoverage: false,
        cardFull: false,
        appearance: nil,
        showSettings: false,
        showFilters: false,
        showNearby: false,
        showOnboarding: false,
        tab: nil,
        onlyRole: nil,
        center: nil,
        simulatedUser: nil,
        showPins: false,
        stubGeocode: nil
    )

    /// Northeast Albuquerque in ZIP 87110, near Louisiana Boulevard and Menaul.
    package static let northeastAlbuquerque = LonLat(lon: -106.5700, lat: 35.1086)

    /// North of the pack, same longitude as the plaza, for screenshots without GPS.
    package static let outsideCoverageSample = LonLat(lon: -105.94, lat: 39.0)

    /// Cathedral steps. One 44-point tap here covers the basilica and the nearby statues.
    package static let placesPickerSample = LonLat(lon: -105.93624, lat: 35.686504)
    package static let tapRadiusPoints = 44.0
    package static let tapZoom = 15.0

    package var suppressesLocation: Bool {
        pinPlaza
            || openPlace != nil
            || search != nil
            || showLayers
            || showPlacesPicker
            || showDisclaimer
            || disclaimerDetailsOpen
            || tap != nil
            || !filterTokens.isEmpty
            || showTerrain
            || outsideCoverage
            || cardFull
            || showSettings
            || showFilters
            || showNearby
            || showOnboarding
            || tab != nil
            || onlyRole != nil
            || center != nil
            || simulatedUser != nil
            || showPins
            || stubGeocode != nil
    }

    /// A real packed place for each pin role, used to open that layer on a pin.
    package static func roleSample(_ role: String) -> LonLat? {
        switch role {
        case "catholic":
            return LonLat(lon: -105.93624, lat: 35.686504)
        case "chapel":
            return LonLat(lon: -105.937454, lat: 35.685617)
        case "worship":
            return LonLat(lon: -106.681415, lat: 35.036992)
        case "shrine":
            return LonLat(lon: -105.940548, lat: 35.683078)
        case "viewpoint":
            return LonLat(lon: -106.233148, lat: 35.872877)
        case "museum":
            return LonLat(lon: -105.889458, lat: 36.685019)
        case "parking":
            return LonLat(lon: -106.661153, lat: 35.205222)
        case "water":
            return LonLat(lon: -106.62973, lat: 35.849528)
        case "trailhead":
            return LonLat(lon: -106.872348, lat: 36.402862)
        case "landmark":
            return LonLat(lon: -105.938556, lat: 35.689653)
        default:
            return nil
        }
    }

    /// Map screenshots skip the first-launch gate for this process only.
    /// Disclaimer and onboarding flags win, so the gate still shows when those are set.
    package var skipsDisclaimer: Bool {
        if showDisclaimer || disclaimerDetailsOpen || showOnboarding { return false }
        return suppressesLocation
    }

    package static func parse(_ arguments: [String]) -> DebugLaunch {
        #if DEBUG
        return parseDebug(arguments)
        #else
        return .inactive
        #endif
    }

    /// Meters covered by a 44-point tap at `zoom`, using Web Mercator meters per point.
    package static func tapRadiusMeters(latitude: Double, zoom: Double = tapZoom) -> Double {
        let metersPerPoint = 156543.03392 * cos(latitude * .pi / 180) / pow(2.0, zoom)
        return metersPerPoint * tapRadiusPoints
    }

    package static func placesWithinTap(
        at point: LonLat,
        places: [PlaceRecord],
        zoom: Double = tapZoom
    ) -> [PlaceRecord] {
        let radius = tapRadiusMeters(latitude: point.lat, zoom: zoom)
        return places
            .map { place in (Geometry.haversineMeters(point, place.coordinate), place) }
            .filter { $0.0 <= radius }
            .sorted { lhs, rhs in
                if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
                return lhs.1.id < rhs.1.id
            }
            .map(\.1)
    }

    package enum Target: Equatable, Sendable {
        case place(Int)
        case trail(Int)
    }

    package static func resolve(_ query: String, places: [PlaceRecord], trails: [TrailRecord]) -> Target? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if let id = Int(trimmed) {
            if places.contains(where: { $0.id == id }) { return .place(id) }
            if trails.contains(where: { $0.id == id }) { return .trail(id) }
        }
        let hits = AtlasQuery.search(trimmed, places: places, trails: trails)
        for hit in hits {
            switch hit.kind {
            case .place:
                if let id = hit.placeId { return .place(id) }
            case .trail:
                if let id = hit.trailId { return .trail(id) }
            case .note, .town, .land:
                continue
            }
        }
        return nil
    }

    /// The injected row, when the query is that city. Any other query still uses the live geocoder.
    package func geocodeHit(matching query: String) -> SearchHit? {
        guard let stub = stubGeocode else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, AtlasQuery.fold(trimmed) == AtlasQuery.fold(stub.name) else { return nil }
        return SearchHit(
            id: "geocode-0",
            kind: .town,
            name: stub.name,
            catholic: false,
            placeId: nil,
            trailId: nil,
            lat: stub.coordinate.lat,
            lon: stub.coordinate.lon,
            city: stub.name,
            meters: nil,
            subtitle: "City"
        )
    }

    /// One Catholic church when the camera is on the injected city. Nil everywhere else,
    /// including Albuquerque, so the live Overpass query still runs.
    package func stubChurches(near center: LonLat) -> [PlaceRecord]? {
        guard let stub = stubGeocode else { return nil }
        guard Geometry.haversineMeters(center, stub.coordinate) <= 3_000 else { return nil }
        return [Self.stubChurch(at: stub.coordinate)]
    }

    private static func stubChurch(at coordinate: LonLat) -> PlaceRecord {
        PlaceRecord(
            id: -9_000_000_001,
            name: "Saint Mary Catholic Church",
            category: "worship",
            catholic: true,
            denomination: "catholic",
            lat: coordinate.lat,
            lon: coordinate.lon,
            description: "",
            address: "",
            openingHours: "",
            serviceTimes: "",
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
            sourceDate: "2026-10-19"
        )
    }

    package static func filter(from tokens: [String]) -> AtlasFilter {
        #if DEBUG
        return filterFromTokens(tokens)
        #else
        return .empty
        #endif
    }
}

#if DEBUG
extension DebugLaunch {
    fileprivate static func parseDebug(_ arguments: [String]) -> DebugLaunch {
        var launch = DebugLaunch.inactive
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--debug-santa-fe-plaza" {
                launch.pinPlaza = true
            } else if argument == "--debug-pins" {
                launch.showPins = true
            } else if let value = taking("--debug-open-place", argument, arguments, index) {
                launch.openPlace = value.value
                index = value.next
                continue
            } else if let value = taking("--debug-search", argument, arguments, index) {
                launch.search = value.value
                index = value.next
                continue
            } else if let value = taking("--debug-geocode", argument, arguments, index) {
                launch.stubGeocode = stubGeocode(value.value)
                index = value.next
                continue
            } else if argument == "--debug-show-layers" {
                launch.showLayers = true
            } else if argument == "--debug-show-places-picker" {
                launch.showPlacesPicker = true
            } else if argument == "--debug-disclaimer-details-open" {
                launch.showDisclaimer = true
                launch.disclaimerDetailsOpen = true
            } else if argument == "--debug-disclaimer" {
                launch.showDisclaimer = true
            } else if argument == "--debug-terrain" {
                launch.showTerrain = true
                launch.showLayers = true
            } else if argument == "--debug-outside-coverage" {
                launch.outsideCoverage = true
            } else if argument == "--debug-show-settings" {
                launch.showSettings = true
                launch.tab = "settings"
            } else if argument == "--debug-show-filters" {
                launch.showFilters = true
            } else if argument == "--debug-show-nearby" {
                launch.showNearby = true
            } else if argument == "--debug-onboarding" {
                launch.showOnboarding = true
            } else if let value = taking("--debug-layer", argument, arguments, index) {
                launch.onlyRole = value.value
                if launch.center == nil {
                    launch.center = roleSample(value.value)
                }
                index = value.next
                continue
            } else if let value = taking("--debug-center", argument, arguments, index) {
                launch.center = coordinate(value.value)
                index = value.next
                continue
            } else if let value = taking("--debug-location", argument, arguments, index) {
                if let point = coordinate(value.value) {
                    launch.simulatedUser = point
                    launch.center = point
                }
                index = value.next
                continue
            } else if let value = taking("--debug-tab", argument, arguments, index) {
                let tab = value.value
                if tab == "map" || tab == "search" || tab == "settings" {
                    launch.tab = tab
                }
                index = value.next
                continue
            } else if let value = taking("--debug-card", argument, arguments, index) {
                if value.value == "full" { launch.cardFull = true }
                index = value.next
                continue
            } else if let value = taking("--debug-appearance", argument, arguments, index) {
                if value.value == "light" {
                    launch.appearance = .light
                } else if value.value == "dark" {
                    launch.appearance = .dark
                }
                index = value.next
                continue
            } else if let value = taking("--debug-filter", argument, arguments, index) {
                let parts = value.value.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let tokens = parts.filter { !$0.isEmpty }
                launch.filterTokens.append(contentsOf: tokens)
                if tokens.contains("food") { launch.focusFood = true }
                index = value.next
                continue
            } else if let value = taking("--debug-tap-at", argument, arguments, index) {
                launch.tap = coordinate(value.value)
                index = value.next
                continue
            }
            index += 1
        }
        return launch
    }

    private static func taking(
        _ flag: String,
        _ argument: String,
        _ arguments: [String],
        _ index: Int
    ) -> (value: String, next: Int)? {
        let prefix = flag + "="
        if argument.hasPrefix(prefix) {
            let value = String(argument.dropFirst(prefix.count))
            if value.isEmpty { return nil }
            return (value, index + 1)
        }
        if argument == flag, index + 1 < arguments.count {
            return (arguments[index + 1], index + 2)
        }
        return nil
    }

    /// `Denver@39.7392,-104.9903` becomes one geocode row and skips Apple's search.
    private static func stubGeocode(_ raw: String) -> StubGeocode? {
        guard let separator = raw.firstIndex(of: "@") else { return nil }
        let name = String(raw[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
        let point = coordinate(String(raw[raw.index(after: separator)...]))
        guard !name.isEmpty, let point else { return nil }
        return StubGeocode(name: name, coordinate: point)
    }

    private static func coordinate(_ raw: String) -> LonLat? {
        let parts = raw.split(separator: ",", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) else { return nil }
        guard (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return LonLat(lon: lon, lat: lat)
    }

    fileprivate static func filterFromTokens(_ tokens: [String]) -> AtlasFilter {
        var filter = AtlasFilter.empty
        for token in tokens {
            switch token {
            case "catholic": filter.catholic = true
            case "churches": filter.churches = true
            case "trails": filter.trails = true
            case "public-land": filter.publicLand = true
            case "parks": filter.parks = true
            case "open-now": filter.openNow = true
            case "food": break
            default: break
            }
        }
        return filter
    }
}
#endif
