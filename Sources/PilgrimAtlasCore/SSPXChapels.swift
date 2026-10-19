import Foundation

/// United States chapels from the SSPX District of the USA list.
/// OpenStreetMap almost never tags these, so the list is bundled and merged with live results.
package enum SSPXChapels {
    package static let sourceName = "SSPX US District chapel list"
    package static let sourceURL = "https://sspx.org/en/list-sspx-chapels"
    package static let sourceDate = "2026-10-18"

    package static func places() -> [PlaceRecord] {
        guard let url = ResourceBundle.url(forResource: "sspx-chapels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ChapelFile.self, from: data)
        else { return [] }
        return file.chapels.compactMap(place(from:))
    }

    private static func place(from chapel: Chapel) -> PlaceRecord? {
        guard chapel.lat >= 18, chapel.lat <= 72, chapel.lon >= -170, chapel.lon <= -65 else { return nil }
        let website = SiteLink.usable(chapel.website)?.absoluteString ?? ""
        var description = "Chapel of the Society of St. Pius X, from the US District chapel list."
        if !chapel.note.isEmpty {
            description += " " + chapel.note
        }
        return PlaceRecord(
            id: chapel.id,
            name: chapel.name,
            category: "worship",
            catholic: false,
            denomination: "sspx",
            lat: chapel.lat,
            lon: chapel.lon,
            description: description,
            address: chapel.address,
            openingHours: "",
            serviceTimes: "",
            massTimes: "",
            confessionTimes: "",
            access: "",
            parking: "",
            wheelchair: "",
            website: website,
            wikipedia: "",
            wikidata: "",
            image: "",
            source: sourceName,
            sourceDate: sourceDate,
            phone: chapel.phone
        )
    }
}

private struct ChapelFile: Decodable {
    var chapels: [Chapel]
}

private struct Chapel: Decodable {
    var id: Int
    var name: String
    var address: String
    var phone: String
    var website: String
    var lat: Double
    var lon: Double
    var note: String
}
