#if canImport(UIKit)
import Foundation
import MapKit
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

/// City and place search through Apple's map search. One user query at a time.
enum CitySearch {
    static func search(_ query: String) async -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = .address
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start() else { return [] }
        return response.mapItems.prefix(5).enumerated().map { index, item in
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
