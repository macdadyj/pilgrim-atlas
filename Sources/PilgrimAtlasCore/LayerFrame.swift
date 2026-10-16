import Foundation

/// Opens a landmark layer wide enough to show the real places around the camera,
/// instead of a single pin at the default zoom.
package enum LayerFrame {
    package static let minimumCount = 5
    /// Stay in the town. Do not jump to every place of that role in the pack.
    package static let maxKilometers = 12.0

    package struct Box: Equatable, Sendable {
        package var minLon: Double
        package var minLat: Double
        package var maxLon: Double
        package var maxLat: Double
    }

    /// Nearest places, widening until `minimum` are included or `maxKilometers` is reached.
    package static func nearest(
        _ places: [PlaceRecord],
        around center: LonLat,
        minimum: Int = minimumCount,
        maxKilometers: Double = maxKilometers
    ) -> [PlaceRecord] {
        let ranked = places
            .map { place in (Geometry.haversineMeters(center, place.coordinate), place) }
            .sorted { lhs, rhs in
                if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
                return lhs.1.id < rhs.1.id
            }
        let cap = maxKilometers * 1000
        var chosen: [(Double, PlaceRecord)] = []
        for item in ranked {
            if item.0 > cap { break }
            chosen.append(item)
            if chosen.count >= minimum { break }
        }
        guard let limit = chosen.last?.0 else { return [] }
        return ranked.filter { $0.0 <= limit }.map(\.1)
    }

    package static func box(for places: [PlaceRecord]) -> Box? {
        guard let first = places.first else { return nil }
        var box = Box(minLon: first.lon, minLat: first.lat, maxLon: first.lon, maxLat: first.lat)
        for place in places.dropFirst() {
            box.minLon = min(box.minLon, place.lon)
            box.minLat = min(box.minLat, place.lat)
            box.maxLon = max(box.maxLon, place.lon)
            box.maxLat = max(box.maxLat, place.lat)
        }
        return box
    }
}
