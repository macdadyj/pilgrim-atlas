import Foundation

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

    package static let inactive = DebugLaunch(
        pinPlaza: false,
        openPlace: nil,
        search: nil,
        showLayers: false,
        showPlacesPicker: false,
        showDisclaimer: false,
        disclaimerDetailsOpen: false,
        tap: nil
    )

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
    }

    /// Map screenshots skip the first-launch gate for this process only.
    /// Disclaimer flags win, so the gate still shows when those are set.
    package var skipsDisclaimer: Bool {
        if showDisclaimer || disclaimerDetailsOpen { return false }
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
            case .note:
                continue
            }
        }
        return nil
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
            } else if let value = taking("--debug-open-place", argument, arguments, index) {
                launch.openPlace = value.value
                index = value.next
                continue
            } else if let value = taking("--debug-search", argument, arguments, index) {
                launch.search = value.value
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

    private static func coordinate(_ raw: String) -> LonLat? {
        let parts = raw.split(separator: ",", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) else { return nil }
        guard (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return LonLat(lon: lon, lat: lat)
    }
}
#endif
