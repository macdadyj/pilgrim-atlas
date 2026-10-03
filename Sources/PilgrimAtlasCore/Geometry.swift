import Foundation

package struct LonLat: Equatable, Sendable {
    package var lon: Double
    package var lat: Double

    package init(lon: Double, lat: Double) {
        self.lon = lon
        self.lat = lat
    }
}

package enum GeoJSONGeometry: Equatable, Sendable {
    case polygon([[LonLat]])
    case multiPolygon([[[LonLat]]])
    case lineString([LonLat])
    case multiLineString([[LonLat]])
    case point(LonLat)

    package var bbox: (minLon: Double, minLat: Double, maxLon: Double, maxLat: Double)? {
        var points: [LonLat] = []
        switch self {
        case .polygon(let rings):
            points = rings.flatMap { $0 }
        case .multiPolygon(let polygons):
            points = polygons.flatMap { $0.flatMap { $0 } }
        case .lineString(let line):
            points = line
        case .multiLineString(let lines):
            points = lines.flatMap { $0 }
        case .point(let point):
            points = [point]
        }
        guard let first = points.first else { return nil }
        var box = (first.lon, first.lat, first.lon, first.lat)
        for point in points {
            box.0 = min(box.0, point.lon)
            box.1 = min(box.1, point.lat)
            box.2 = max(box.2, point.lon)
            box.3 = max(box.3, point.lat)
        }
        return box
    }
}

package enum Geometry {
    private static let earth: Double = 6_371_000

    package static func haversineMeters(_ a: LonLat, _ b: LonLat) -> Double {
        let p1 = a.lat * .pi / 180
        let p2 = b.lat * .pi / 180
        let dp = (b.lat - a.lat) * .pi / 180
        let dl = (b.lon - a.lon) * .pi / 180
        let h = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * earth * asin(min(1, sqrt(h)))
    }

    package static func contains(_ point: LonLat, _ geometry: GeoJSONGeometry) -> Bool {
        switch geometry {
        case .polygon(let rings):
            return pointInPolygon(point, rings)
        case .multiPolygon(let polygons):
            return polygons.contains { pointInPolygon(point, $0) }
        case .lineString, .multiLineString, .point:
            return false
        }
    }

    package static func distanceToLineMeters(_ point: LonLat, _ geometry: GeoJSONGeometry) -> Double? {
        let lines: [[LonLat]]
        switch geometry {
        case .lineString(let line):
            lines = [line]
        case .multiLineString(let many):
            lines = many
        default:
            return nil
        }
        var best: Double?
        for line in lines {
            guard let distance = distance(point, line) else { continue }
            best = best.map { min($0, distance) } ?? distance
        }
        return best
    }

    private static func pointInPolygon(_ point: LonLat, _ rings: [[LonLat]]) -> Bool {
        guard let exterior = rings.first, pointInRing(point, exterior) else { return false }
        for hole in rings.dropFirst() where pointInRing(point, hole) {
            return false
        }
        return true
    }

    private static func pointInRing(_ point: LonLat, _ ring: [LonLat]) -> Bool {
        guard ring.count >= 3 else { return false }
        var inside = false
        var previous = ring.count - 1
        for index in ring.indices {
            let current = ring[index]
            let prior = ring[previous]
            if (current.lat > point.lat) != (prior.lat > point.lat) {
                let span = prior.lat - current.lat
                let cross = (prior.lon - current.lon) * (point.lat - current.lat) / (span == 0 ? 1e-15 : span) + current.lon
                if point.lon < cross {
                    inside.toggle()
                }
            }
            previous = index
        }
        return inside
    }

    private static func xy(_ point: LonLat, lat0: Double) -> (Double, Double) {
        let x = point.lon * .pi / 180 * cos(lat0 * .pi / 180) * earth
        let y = point.lat * .pi / 180 * earth
        return (x, y)
    }

    private static func distance(_ point: LonLat, _ line: [LonLat]) -> Double? {
        guard let first = line.first else { return nil }
        if line.count == 1 { return haversineMeters(point, first) }
        let origin = xy(point, lat0: point.lat)
        var best: Double?
        for pair in zip(line, line.dropFirst()) {
            let start = xy(pair.0, lat0: point.lat)
            let end = xy(pair.1, lat0: point.lat)
            let dx = end.0 - start.0
            let dy = end.1 - start.1
            let lengthSquared = dx * dx + dy * dy
            let distance: Double
            if lengthSquared == 0 {
                distance = hypot(origin.0 - start.0, origin.1 - start.1)
            } else {
                let raw = ((origin.0 - start.0) * dx + (origin.1 - start.1) * dy) / lengthSquared
                let t = min(1, max(0, raw))
                distance = hypot(origin.0 - (start.0 + t * dx), origin.1 - (start.1 + t * dy))
            }
            best = best.map { min($0, distance) } ?? distance
        }
        return best
    }
}
