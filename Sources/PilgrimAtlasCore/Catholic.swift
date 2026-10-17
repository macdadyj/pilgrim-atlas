import Foundation

package enum WorshipClass: Equatable, Sendable {
    case catholic
    case otherWorship
    case landmark
    case skip
}

package enum Catholic {
    private static let names: Set<String> = [
        "roman_catholic",
        "catholic",
        "greek_catholic",
        "ruthenian_catholic",
        "byzantine_catholic",
    ]

    package static func normalize(_ value: String?) -> String {
        guard let value else { return "" }
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    package static func isCatholicDenomination(_ value: String?) -> Bool {
        let name = normalize(value)
        if name.isEmpty || name.contains("anglican") { return false }
        if names.contains(name) { return true }
        if name.contains("byzantine") && name.contains("catholic") { return true }
        let eastern = [
            "melkite", "maronite", "chaldean", "syro_malabar", "syro_malankara",
            "armenian_catholic", "ukrainian_catholic", "greek_catholic",
            "geez_catholic", "ethiopian_catholic", "eritrean_catholic", "italo_albanian",
        ]
        return eastern.contains { name.contains($0) }
    }

    package static func classify(amenity: String?, tourism: String?, historic: String?, place: String?, denomination: String?) -> WorshipClass {
        let amenityName = (amenity ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tourismName = (tourism ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let historicName = (historic ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let placeName = (place ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if amenityName == "place_of_worship" {
            return isCatholicDenomination(denomination) ? .catholic : .otherWorship
        }
        let tourismLandmarks: Set<String> = ["attraction", "museum", "viewpoint", "gallery", "artwork"]
        let historicLandmarks: Set<String> = [
            "monument", "memorial", "church", "monastery", "wayside_shrine", "ruins", "archaeological_site", "shrine",
        ]
        if tourismLandmarks.contains(tourismName) || historicLandmarks.contains(historicName) || placeName == "square" {
            return .landmark
        }
        if amenityName == "monastery" { return .landmark }
        return .skip
    }
}
