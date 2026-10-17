#if canImport(UIKit)
import Foundation
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

/// One Overpass query at a time, with a short wait between calls and a memory cache.
actor OverpassLoader {
    static let shared = OverpassLoader()
    private var lastRequest = Date.distantPast
    private var cache: [String: [PlaceRecord]] = [:]
    private let minimumGap: TimeInterval = 1.2
    private let endpoints = [
        URL(string: "https://overpass.openstreetmap.fr/api/interpreter"),
        URL(string: "https://overpass-api.de/api/interpreter"),
    ].compactMap { $0 }

    func places(south: Double, west: Double, north: Double, east: Double, zoom: Double) async -> [PlaceRecord] {
        guard OverpassQuery.allows(south: south, west: west, north: north, east: east, zoom: zoom) else { return [] }
        let key = OverpassQuery.cacheKey(south: south, west: west, north: north, east: east)
        if let cached = cache[key] { return cached }
        let wait = minimumGap - Date().timeIntervalSince(lastRequest)
        if wait > 0 {
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
        guard !Task.isCancelled else { return [] }
        lastRequest = Date()
        let statement = OverpassQuery.statement(south: south, west: west, north: north, east: east)
        let day = isoDay(Date())
        for endpoint in endpoints {
            if let places = await fetch(statement, from: endpoint, fetchedOn: day) {
                cache[key] = places
                if cache.count > 40, let oldest = cache.keys.first { cache.removeValue(forKey: oldest) }
                return places
            }
        }
        return []
    }

    private func fetch(_ statement: String, from endpoint: URL, fetchedOn: String) async -> [PlaceRecord]? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 18
        request.setValue("PilgrimAtlas/1.0 (church map; https://github.com/macdadyj/pilgrim-atlas)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = OverpassQuery.formBody(for: statement)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { return nil }
        return OverpassQuery.places(from: data, fetchedOn: fetchedOn)
    }

    private func isoDay(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

#endif
