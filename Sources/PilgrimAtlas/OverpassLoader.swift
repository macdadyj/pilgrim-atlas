#if canImport(UIKit)
import Foundation
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

enum OverpassOutcome: Sendable {
    case places([PlaceRecord], trails: [TrailRecord])
    case unavailable
}

private struct CachedOverpass: Sendable {
    var places: [PlaceRecord]
    var trails: [TrailRecord]
}

/// One Overpass query at a time, with a short wait between calls and a memory cache.
actor OverpassLoader {
    static let shared = OverpassLoader()
    private var lastRequest = Date.distantPast
    private var cache: [String: CachedOverpass] = [:]
    private let minimumGap: TimeInterval = 1.2
    /// Separate from the map's tile session so a slow area query cannot sit on it.
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 14
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()
    private let endpoints = [
        URL(string: "https://overpass.openstreetmap.fr/api/interpreter"),
        URL(string: "https://overpass-api.de/api/interpreter"),
    ].compactMap { $0 }

    func places(
        south: Double,
        west: Double,
        north: Double,
        east: Double,
        zoom: Double,
        layers: OverpassLayers = .none
    ) async -> OverpassOutcome {
        guard OverpassQuery.allows(south: south, west: west, north: north, east: east, zoom: zoom) else {
            return .places([], trails: [])
        }
        let key = OverpassQuery.cacheKey(south: south, west: west, north: north, east: east, layers: layers)
        if let cached = cache[key] { return .places(cached.places, trails: cached.trails) }
        let wait = minimumGap - Date().timeIntervalSince(lastRequest)
        if wait > 0 {
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
        guard !Task.isCancelled else { return .unavailable }
        lastRequest = Date()
        let statement = OverpassQuery.statement(south: south, west: west, north: north, east: east, layers: layers)
        let day = isoDay(Date())
        for endpoint in endpoints {
            for attempt in 0..<2 {
                if let loaded = await fetch(statement, from: endpoint, fetchedOn: day) {
                    cache[key] = loaded
                    if cache.count > 40, let oldest = cache.keys.first { cache.removeValue(forKey: oldest) }
                    return .places(loaded.places, trails: loaded.trails)
                }
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    guard !Task.isCancelled else { return .unavailable }
                }
            }
        }
        return .unavailable
    }

    private func fetch(_ statement: String, from endpoint: URL, fetchedOn: String) async -> CachedOverpass? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("PilgrimAtlas/1.0 (church map; https://github.com/macdadyj/pilgrim-atlas)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = OverpassQuery.formBody(for: statement)
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { return nil }
        return CachedOverpass(
            places: OverpassQuery.places(from: data, fetchedOn: fetchedOn),
            trails: OverpassQuery.trails(from: data, fetchedOn: fetchedOn)
        )
    }

    private func isoDay(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

#endif
