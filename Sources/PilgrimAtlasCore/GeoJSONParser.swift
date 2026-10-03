import Foundation

package enum GeoJSONParser {
    package static func geometry(from data: Data) -> GeoJSONGeometry? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return geometry(from: object)
    }

    package static func geometry(from object: Any) -> GeoJSONGeometry? {
        guard let dict = object as? [String: Any], let type = dict["type"] as? String else { return nil }
        switch type {
        case "Polygon":
            return .polygon(rings(dict["coordinates"]))
        case "MultiPolygon":
            guard let polygons = dict["coordinates"] as? [Any] else { return nil }
            return .multiPolygon(polygons.map { rings($0) })
        case "LineString":
            return .lineString(points(dict["coordinates"]))
        case "MultiLineString":
            guard let lines = dict["coordinates"] as? [Any] else { return nil }
            return .multiLineString(lines.map { points($0) })
        case "Point":
            let point = points([dict["coordinates"] as Any])
            return point.first.map { .point($0) }
        default:
            return nil
        }
    }

    private static func rings(_ value: Any?) -> [[LonLat]] {
        guard let rings = value as? [Any] else { return [] }
        return rings.map { points($0) }
    }

    private static func points(_ value: Any?) -> [LonLat] {
        guard let pairs = value as? [Any] else { return [] }
        return pairs.compactMap { item in
            guard let pair = item as? [Any], pair.count >= 2 else { return nil }
            guard let lon = number(pair[0]), let lat = number(pair[1]) else { return nil }
            return LonLat(lon: lon, lat: lat)
        }
    }

    private static func number(_ value: Any) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }
}
