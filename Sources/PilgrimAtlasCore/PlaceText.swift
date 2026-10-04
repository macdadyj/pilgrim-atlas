import Foundation

package enum PlaceText {
    package static let permissionLine = "This is not permission to enter."
    package static let hoursConflictNote = "These ranges cover the same days. The sources do not agree."
    package static let diamondNote = "OpenStreetMap lists this as a landmark, so the map uses the diamond."
    package static let sameSitePhrase = "same site, second OpenStreetMap object"

    package static let towns: [(name: String, coordinate: LonLat)] = [
        ("Santa Fe", LonLat(lon: -105.9378, lat: 35.6870)),
        ("Chimayó", LonLat(lon: -105.9319, lat: 35.9891)),
        ("Española", LonLat(lon: -106.0790, lat: 35.9911)),
        ("Los Alamos", LonLat(lon: -106.3031, lat: 35.8800)),
        ("Taos", LonLat(lon: -105.5731, lat: 36.4072)),
        ("Albuquerque", LonLat(lon: -106.6504, lat: 35.0844)),
        ("Dulce", LonLat(lon: -106.9324, lat: 36.9307)),
    ]

    package static func kindLabel(for place: PlaceRecord) -> String {
        MapFilter.pinRole(for: place).legend
    }

    package static func denominationLabel(_ raw: String) -> String {
        let words = raw.replacingOccurrences(of: "_", with: " ").split(separator: " ")
        return words.map { word in
            let lower = word.lowercased()
            guard let first = lower.first else { return "" }
            return first.uppercased() + lower.dropFirst()
        }.joined(separator: " ")
    }

    package static func wikipediaTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return trimmed }
        let language = parts[0]
        guard (language.count == 2 || language.count == 3), language.allSatisfy(\.isLetter) else { return trimmed }
        return parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "_", with: " ")
    }

    package static func pinLabel(_ name: String) -> String {
        var words = name.split(separator: " ").map(String.init)
        if words.first?.lowercased() == "the" { words.removeFirst() }
        let folded = words.map { AtlasQuery.fold($0) }
        if folded.contains("cathedral") && folded.contains("basilica") { return "Cathedral Basilica" }
        var kept: [String] = []
        for word in words {
            let next = (kept + [word]).joined(separator: " ")
            if !kept.isEmpty && next.count > 24 { break }
            kept.append(word)
            if kept.count == 3 { break }
        }
        let label = kept.joined(separator: " ")
        return label.isEmpty ? name : label
    }

    package static func distanceLabel(_ meters: Int) -> String {
        if meters < 1000 { return "\(meters) m" }
        return String(format: "%.1f km", Double(meters) / 1000)
    }

    package static func sourceLine(source: String, sourceDate: String) -> String {
        let name = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let date = formatSourceDate(sourceDate)
        if name.isEmpty { return date }
        if date.isEmpty { return name }
        return "\(name), \(date)"
    }

    package static func formatSourceDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]
        let day = ISO8601DateFormatter()
        day.formatOptions = [.withFullDate]
        let parsed = internet.date(from: trimmed) ?? day.date(from: String(trimmed.prefix(10)))
        guard let parsed else { return trimmed }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: parsed)
    }

    package static func hoursDisplay(_ raw: String) -> (shown: String, note: String?) {
        let lines = MapFilter.hourLines(raw)
        if lines.isEmpty { return ("", nil) }
        let shown = lines.joined(separator: "\n")
        if MapFilter.hoursConflict(raw) { return (shown, hoursConflictNote) }
        if case .notAClock = MapFilter.hoursReading(raw) { return (shown, MapFilter.hoursUnparsed) }
        return (shown, nil)
    }

    package static func externalLinkTitle(label: String, value: String) -> String {
        switch label {
        case "Wikipedia": return wikipediaTitle(value)
        case "Wikidata": return "Wikidata"
        default: return label
        }
    }

    /// One row per name. Keeps the closer place unless a later one is a richer record.
    package static func dedupeByName(_ places: [PlaceRecord]) -> [PlaceRecord] {
        var best: [String: PlaceRecord] = [:]
        var order: [String] = []
        for place in places {
            let key = AtlasQuery.fold(place.name)
            if let existing = best[key] {
                if richness(place) > richness(existing) {
                    best[key] = place
                }
            } else {
                order.append(key)
                best[key] = place
            }
        }
        return order.compactMap { best[$0] }
    }

    package static func accessSentence(_ value: String) -> String? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return nil }
        return "Tagged access=\(cleaned). That tag is not a legal ruling."
    }

    package static func websiteURL(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://") { return trimmed }
        return nil
    }

    package static func wikipediaURL(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://") { return trimmed }
        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let language = parts[0]
        guard language.count == 2 || language.count == 3, language.allSatisfy(\.isLetter) else { return nil }
        let title = parts[1]
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
        guard !title.isEmpty else { return nil }
        let allowed = CharacterSet.urlPathAllowed.union(CharacterSet(charactersIn: "()"))
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return "https://\(language).wikipedia.org/wiki/\(encoded)"
    }

    package static func wikidataURL(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://") { return trimmed }
        let identifier = trimmed.uppercased()
        guard identifier.first == "Q", identifier.dropFirst().allSatisfy(\.isNumber) else { return nil }
        return "https://www.wikidata.org/wiki/\(identifier)"
    }

    package static func photoURL(_ value: String) -> String? {
        guard let url = websiteURL(value) else { return nil }
        let lower = url.lowercased()
        let extensions = [".jpg", ".jpeg", ".png", ".gif", ".webp"]
        if extensions.contains(where: { lower.contains($0) }) { return url }
        return nil
    }

    package static func mapsURL(for address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return "https://maps.apple.com/?q=\(encoded)"
    }

    package static func diamondNote(for place: PlaceRecord) -> String? {
        guard place.category == "landmark", !place.catholic else { return nil }
        if MapFilter.pinRole(for: place) == .chapel { return nil }
        let folded = AtlasQuery.fold(place.name)
        let tokens = ["chapel", "church", "cathedral", "basilica", "santuario"]
        if tokens.contains(where: { folded.contains($0) }) { return diamondNote }
        return nil
    }

    package static func richness(_ place: PlaceRecord) -> Int {
        var score = place.catholic ? 4 : 0
        if !place.wikidata.isEmpty { score += 2 }
        if !place.website.isEmpty { score += 2 }
        if !place.address.isEmpty { score += 1 }
        if !place.wikipedia.isEmpty { score += 1 }
        return score
    }

    package static func sameSiteNote(for place: PlaceRecord, among places: [PlaceRecord]) -> String? {
        let key = AtlasQuery.fold(place.name)
        let siblings = places.filter { AtlasQuery.fold($0.name) == key }
        guard siblings.count > 1 else { return nil }
        let best = siblings.max { lhs, rhs in
            let left = richness(lhs)
            let right = richness(rhs)
            if left != right { return left < right }
            return lhs.id > rhs.id
        }
        if best?.id == place.id { return nil }
        return sameSitePhrase
    }

    package static func cityLabel(address: String, coordinate: LonLat) -> String {
        let towns = PlaceText.towns
        let foldedAddress = AtlasQuery.fold(address)
        if !foldedAddress.isEmpty {
            for town in towns where foldedAddress.contains(AtlasQuery.fold(town.0)) {
                return town.0
            }
        }
        var bestName = ""
        var bestMeters = 20_001.0
        for town in towns {
            let meters = Geometry.haversineMeters(coordinate, town.1)
            if meters <= 20_000, meters < bestMeters {
                bestName = town.0
                bestMeters = meters
            }
        }
        return bestName
    }
}
