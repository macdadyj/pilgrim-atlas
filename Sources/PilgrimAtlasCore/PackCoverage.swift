import Foundation

/// Northern New Mexico offline pack. Same edges as `pipeline/pilgrim/bbox.py`.
package enum PackCoverage {
    package static let south = 34.80
    package static let west = -107.30
    package static let north = 37.05
    package static let east = -104.70

    package static func contains(_ point: LonLat) -> Bool {
        west <= point.lon && point.lon <= east && south <= point.lat && point.lat <= north
    }

    /// Clamps a coordinate onto the pack. A point already inside is unchanged.
    package static func nearest(_ point: LonLat) -> LonLat {
        LonLat(
            lon: min(max(point.lon, west), east),
            lat: min(max(point.lat, south), north)
        )
    }
}
