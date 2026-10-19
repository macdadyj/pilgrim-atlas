#if canImport(UIKit)
import Foundation
import MapKit
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

/// City and place search through Apple's map search. One user query at a time.
enum CitySearch {
    static func search(_ query: String, near origin: LonLat = DebugPin.plaza) async -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start() else { return [] }
        let ranked = response.mapItems.prefix(8).map { item -> (Int, Double, MKMapItem) in
            let coordinate = item.placemark.coordinate
            let point = LonLat(lon: coordinate.longitude, lat: coordinate.latitude)
            let name = item.name ?? item.placemark.name ?? trimmed
            let locality = item.placemark.locality ?? ""
            let street = item.placemark.thoroughfare ?? ""
            let rank = CityPick.rank(name: name, locality: locality, thoroughfare: street, query: trimmed)
            return (rank, Geometry.haversineMeters(origin, point), item)
        }.sorted { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
            return lhs.1 < rhs.1
        }
        return ranked.prefix(5).enumerated().map { index, rankedItem in
            let item = rankedItem.2
            let coordinate = item.placemark.coordinate
            let title = item.name ?? item.placemark.name ?? trimmed
            let locality = item.placemark.locality ?? ""
            let region = item.placemark.administrativeArea ?? item.placemark.country ?? ""
            let city = [locality, region].filter { !$0.isEmpty }.joined(separator: ", ")
            return SearchHit(
                id: "geocode-\(index)",
                kind: .town,
                name: title,
                catholic: false,
                placeId: nil,
                trailId: nil,
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                city: city,
                meters: nil,
                subtitle: "City"
            )
        }
    }
}

#endif
