import Foundation

package enum Names {
    private static let placeOrOrg = [
        "bureau", "service", "department", "county", "city", "state", "united", "national",
        "forest", "park", "district", "tribe", "tribal", "pueblo", "nation", "university",
        "college", "school", "office", "blm", "nps", "usda", "conservancy", "foundation",
        "society", "church", "diocese", "parish", "authority", "commission", "agency",
        "reservation", "monument", "refuge", "wilderness", "trust", "range", "canyon",
        "mesa", "trail", "mountain", "creek", "river", "lake", "experimental", "recreation",
        "preserve", "reserve", "cemetery", "chapel", "shrine", "plaza",
    ]

    package static func isOwnerField(_ key: String) -> Bool {
        key.range(of: "owner", options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    package static func stripOwnerFields(_ props: [String: String]) -> [String: String] {
        props.filter { !isOwnerField($0.key) }
    }

    package static func looksLikePrivatePerson(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return false }
        let upper = text.uppercased()
        if ["UNK", "UNKNOWN", "PVT", "PRIVATE", "NONE"].contains(upper) { return false }
        let lowered = text.lowercased()
        if placeOrOrg.contains(where: { lowered.contains($0) }) { return false }
        if text.contains(where: { $0.isNumber }) { return false }
        let words = text.split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "." && $0 != "-" }).filter { !$0.isEmpty }
        return (2...4).contains(words.count)
    }

    package static func publicLabel(_ value: String?, ownType: String? = nil) -> String {
        guard let value else { return "" }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || ["UNK", "UNKNOWN", "NONE"].contains(text.uppercased()) { return "" }
        if (ownType ?? "").uppercased() == "PVT" { return "" }
        if looksLikePrivatePerson(text) { return "" }
        return text
    }
}
