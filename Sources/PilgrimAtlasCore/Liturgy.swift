import Foundation

/// How a church is drawn. Latin and Byzantine Catholic share the Catholic layer
/// and use different pins. Orthodox is other worship with its own pin.
package enum ChurchMark: String, CaseIterable, Sendable {
    case latin
    case byzantine
    case orthodox
    case chapel
    case shrine

    package var imageName: String { rawValue }
    package var selectedImageName: String { rawValue + "-selected" }

    package static func mark(for place: PlaceRecord) -> ChurchMark? {
        let denomination = place.denomination.lowercased()
        switch MapFilter.pinRole(for: place) {
        case .chapel:
            return .chapel
        case .shrine:
            return .shrine
        case .catholic:
            if isByzantine(denomination) { return .byzantine }
            return .latin
        case .worship:
            if denomination.contains("orthodox") { return .orthodox }
            return nil
        case .viewpoint, .museum, .parking, .water, .trailhead, .landmark:
            return nil
        }
    }

    /// Catholic, Orthodox, chapel, and shrine cards use liturgy instead of visitor hours.
    package static func showsLiturgy(_ place: PlaceRecord) -> Bool {
        mark(for: place) != nil
    }

    /// Image name stored on the GeoJSON feature.
    package static func pinName(for place: PlaceRecord) -> String {
        mark(for: place)?.imageName ?? MapFilter.pinRole(for: place).rawValue
    }

    private static func isByzantine(_ denomination: String) -> Bool {
        denomination.contains("byzantine")
            || denomination.contains("ruthenian")
            || denomination.contains("greek_catholic")
            || (denomination.contains("greek") && denomination.contains("catholic"))
    }
}

package struct LiturgyLine: Equatable, Sendable {
    package var text: String
}

/// One successful read from a source. Later sources are skipped when this exists.
package struct LiturgyListing: Equatable, Sendable {
    package var lines: [String]
    package var confession: String
    package var verified: String
    package var sourceName: String
    package var sourceURL: String
    package var phone: String
    package var website: String
    package var directory: String
    package var confirm: String
}

/// What the place card shows. `found` is false when no source had times.
package struct LiturgyCard: Equatable, Sendable {
    package var lines: [String]
    package var confession: String
    package var lastVerified: String
    package var phone: String
    package var website: String
    package var directory: String
    package var note: String
    package var found: Bool
    package var emptyTitle: String
    package var emptyDetail: String

    package static let emptyTitle = "No liturgy times yet"
    package static let emptyDetail = "Nothing from the parish site is stored here. Call the office or open the website."

    package var verifiedLine: String {
        lastVerified.isEmpty ? "Last verified: not yet" : "Last verified \(lastVerified)"
    }
}

package protocol LiturgySource: Sendable {
    var id: String { get }
    /// Lower runs first. A later expert ranking can reorder these.
    var rank: Int { get }
    func listing(for place: PlaceRecord) -> LiturgyListing?
}

/// Phone and website from a diocesan directory. Not a Mass-times feed.
package struct ParishContact: Equatable, Sendable {
    package var name: String
    package var phone: String
    package var website: String
    package var directory: String
}

package enum ParishDirectories {
    /// Office number from the Eparchy of Phoenix directory for this parish.
    package static let olphPhone = "505-256-1539"
    package static let olphWebsite = "https://www.olphnm.org/"
    package static let eparchyName = "Holy Protection Byzantine Catholic Eparchy of Phoenix"

    /// Byzantine Catholic parishes in New Mexico are in the Eparchy of Phoenix.
    package static let eparchyOfPhoenix: [ParishContact] = [
        ParishContact(
            name: "Our Lady of Perpetual Help",
            phone: olphPhone,
            website: olphWebsite,
            directory: eparchyName
        ),
    ]

    /// Latin parishes. Add entries from the Archdiocese of Santa Fe directory.
    /// This list stays empty until those contacts are copied from the directory itself.
    package static let archdioceseOfSantaFe: [ParishContact] = []

    package static func contact(for place: PlaceRecord) -> ParishContact? {
        let folded = AtlasQuery.fold(place.name)
        for contact in eparchyOfPhoenix + archdioceseOfSantaFe {
            let needle = AtlasQuery.fold(contact.name)
            guard !needle.isEmpty, folded.contains(needle) else { continue }
            if needle.contains("perpetual help") {
                guard isOurLadyOfPerpetualHelp(place) else { continue }
            }
            return contact
        }
        return nil
    }

    /// Albuquerque's Byzantine parish, not Memorial of Perpetual Tears.
    package static func isOurLadyOfPerpetualHelp(_ place: PlaceRecord) -> Bool {
        let folded = AtlasQuery.fold(place.name)
        guard folded.contains("perpetual help"), !folded.contains("tears") else { return false }
        let address = AtlasQuery.fold(place.address)
        return address.contains("87110")
            || address.contains("alvarado")
            || place.website.contains("olphnm.org")
    }
}

package enum HandVerifiedLiturgy {
    /// Week published on https://www.olphnm.org/ and read on 2026-10-16.
    /// The page writes "Diving Liturgy" and "Great Vesper"; those are stored as the liturgical names.
    /// This is one week, not a standing schedule.
    package static let ourLadyOfPerpetualHelp = LiturgyListing(
        lines: [
            "Sat 10 Oct, 4:00 PM Great Vespers",
            "Sat 10 Oct, 5:00 PM Divine Liturgy",
            "Sun 11 Oct, 8:30 AM Rosary",
            "Sun 11 Oct, 9:00 AM Matins and confessions",
            "Sun 11 Oct, 10:00 AM Divine Liturgy",
            "Mon 12 Oct, 9:00 AM Divine Liturgy",
            "Tue 13 Oct, 9:00 AM Moleben for the Sick",
            "Wed 14 Oct, 6:00 PM Vespers",
            "Thu 15 Oct, No Divine Liturgy. Parish and office closed.",
            "Fri 16 Oct, 6:00 PM Divine Liturgy",
            "Sat 17 Oct, 4:00 PM Great Vespers",
            "Sat 17 Oct, 5:00 PM Divine Liturgy",
            "Sun 18 Oct, 8:30 AM Rosary",
            "Sun 18 Oct, 9:00 AM Matins and confessions",
            "Sun 18 Oct, 10:00 AM Divine Liturgy",
        ],
        confession: "Confession is available before and after any Divine Liturgy, or by appointment during office hours.",
        verified: "2026-10-16",
        sourceName: "Parish website",
        sourceURL: ParishDirectories.olphWebsite,
        phone: ParishDirectories.olphPhone,
        website: ParishDirectories.olphWebsite,
        directory: ParishDirectories.eparchyName,
        confirm: "Call to confirm. Liturgy times vary."
    )

    package static func listing(for place: PlaceRecord) -> LiturgyListing? {
        guard ParishDirectories.isOurLadyOfPerpetualHelp(place) else { return nil }
        return ourLadyOfPerpetualHelp
    }
}

package struct HandVerifiedSource: LiturgySource {
    package var id: String { LiturgySourceID.handVerified }
    package var rank: Int { 0 }
    package func listing(for place: PlaceRecord) -> LiturgyListing? {
        HandVerifiedLiturgy.listing(for: place)
    }
}

/// Reads schema.org Event data, then a simple Mass-times heading, from HTML already in hand.
/// Does not fetch the network. A loader can supply the HTML.
package struct ParishPageSource: LiturgySource {
    package var id: String { LiturgySourceID.parishWebsite }
    package var rank: Int { 10 }
    package var pages: [Int: String]
    package var verified: String

    package init(pages: [Int: String] = [:], verified: String = "") {
        self.pages = pages
        self.verified = verified
    }

    package func listing(for place: PlaceRecord) -> LiturgyListing? {
        guard let html = pages[place.id] else { return nil }
        let lines = ParishScheduleParser.lines(from: html)
        guard !lines.isEmpty else { return nil }
        let contact = ParishDirectories.contact(for: place)
        return LiturgyListing(
            lines: lines,
            confession: ParishScheduleParser.confession(from: html),
            verified: verified,
            sourceName: "Parish website",
            sourceURL: contact?.website ?? place.website,
            phone: contact?.phone ?? "",
            website: contact?.website ?? place.website,
            directory: contact?.directory ?? "",
            confirm: "Call to confirm."
        )
    }
}

package enum LiturgySourceID {
    package static let handVerified = "hand-verified"
    package static let parishWebsite = "parish-website"
    package static let archdioceseDirectory = "archdiocese-santa-fe"
    package static let eparchyDirectory = "eparchy-phoenix"
    /// Reserved plug-in ids. Licensing is not confirmed, so nothing may call these.
    package static let massTimesSlot = "masstimes"
    package static let discoverMassSlot = "discover-mass"
    package static let unusedSlots = [massTimesSlot, discoverMassSlot]
}

/// schema.org Event first. If the parish page has none, read the Mass or Liturgy schedule in the HTML.
package enum ParishScheduleParser {
    package static func lines(from html: String) -> [String] {
        let structured = SchemaEventParser.lines(from: html)
        if !structured.isEmpty { return structured }
        return scheduleLines(from: html)
    }

    package static func confession(from html: String) -> String {
        let hits = plainLines(html).filter { line in
            let folded = AtlasQuery.fold(line)
            return folded.contains("confession") && line.count > 40
        }
        return hits.first ?? ""
    }

    private static func scheduleLines(from html: String) -> [String] {
        let lines = plainLines(html)
        guard let start = lines.firstIndex(where: isScheduleHeading) else { return [] }
        var collected: [String] = []
        for line in lines[lines.index(after: start)...] {
            if collected.count >= 16 { break }
            if isStopHeading(line) { break }
            if isServiceLine(line) { collected.append(line) }
        }
        return collected
    }

    private static func isScheduleHeading(_ line: String) -> Bool {
        if containsClock(line) { return false }
        let folded = AtlasQuery.fold(line)
        let keys = ["mass times", "mass schedule", "liturgy schedule", "divine liturgy schedule", "service schedule"]
        return keys.contains { folded.contains($0) }
    }

    private static func isStopHeading(_ line: String) -> Bool {
        if containsClock(line) || isServiceLine(line) { return false }
        let folded = AtlasQuery.fold(line)
        let stops = ["contact", "office hours", "giving", "donate", "address", "miracles"]
        return stops.contains { folded.contains($0) }
    }

    private static func isServiceLine(_ line: String) -> Bool {
        guard line.count <= 140 else { return false }
        let folded = AtlasQuery.fold(line)
        if folded.contains("confession"), (folded.contains("available") || folded.contains("appointment")) {
            return false
        }
        if containsClock(line) { return true }
        if folded.contains("no divine liturgy") || folded.contains("no mass") { return true }
        return folded.contains("parish") && folded.contains("closed")
    }

    private static func containsClock(_ line: String) -> Bool {
        let characters = Array(line)
        for index in characters.indices where characters[index] == ":" {
            let after = characters.index(after: index)
            guard after < characters.endIndex else { continue }
            let before = index > characters.startIndex ? characters[characters.index(before: index)] : nil
            if before?.isNumber == true, characters[after].isNumber { return true }
        }
        return false
    }

    private static func plainLines(_ html: String) -> [String] {
        var text = stripTag(html, tag: "script")
        text = stripTag(text, tag: "style")
        let breaks = ["<br>", "<br/>", "<br />", "</p>", "</div>", "</li>", "</h1>", "</h2>", "</h3>", "</h4>", "</tr>"]
        for tag in breaks {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
        return text
            .components(separatedBy: .newlines)
            .map { line in
                line.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private static func stripTag(_ html: String, tag: String) -> String {
        var result = ""
        var rest = html[...]
        let open = "<\(tag)"
        let close = "</\(tag)>"
        while let start = rest.range(of: open, options: .caseInsensitive) {
            result.append(contentsOf: rest[..<start.lowerBound])
            rest = rest[start.upperBound...]
            if let end = rest.range(of: close, options: .caseInsensitive) {
                rest = rest[end.upperBound...]
            } else {
                rest = Substring()
            }
        }
        result.append(contentsOf: rest)
        return result
    }
}

package enum SchemaEventParser {
    package static func lines(from html: String) -> [String] {
        var lines: [String] = []
        for block in jsonBlocks(in: html) {
            guard let data = block.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data)
            else { continue }
            collect(object, into: &lines)
        }
        return lines
    }

    private static func jsonBlocks(in html: String) -> [String] {
        let needle = "application/ld+json"
        var blocks: [String] = []
        var rest = html[...]
        while let range = rest.range(of: needle) {
            rest = rest[range.upperBound...]
            guard let open = rest.range(of: ">"), let close = rest.range(of: "</script>") else { break }
            let json = rest[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if !json.isEmpty { blocks.append(json) }
            rest = rest[close.upperBound...]
        }
        return blocks
    }

    private static func collect(_ object: Any, into lines: inout [String]) {
        if let list = object as? [Any] {
            for item in list { collect(item, into: &lines) }
            return
        }
        guard let record = object as? [String: Any] else { return }
        if let graph = record["@graph"] {
            collect(graph, into: &lines)
        }
        let type = record["@type"]
        let typeName = (type as? String) ?? ""
        let isEvent = typeName == "Event" || (type as? [String])?.contains("Event") == true
        if isEvent, let name = record["name"] as? String {
            let when = formatted(record["startDate"] as? String)
            let text = when.isEmpty ? name : "\(when) \(name)"
            if !lines.contains(text) { lines.append(text) }
        }
    }

    private static func formatted(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        guard let date = parser.date(from: raw) ?? fallback.date(from: raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Denver") ?? TimeZone(secondsFromGMT: -6 * 3600)
        formatter.dateFormat = "EEE d MMM, h:mm a"
        return formatter.string(from: date)
    }
}

package final class LiturgyCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [Int: (listing: LiturgyListing, saved: Date)] = [:]
    package var maxAge: TimeInterval

    package init(maxAge: TimeInterval = 60 * 60 * 24 * 7) {
        self.maxAge = maxAge
    }

    package func save(_ listing: LiturgyListing, placeID: Int, now: Date = Date()) {
        lock.lock()
        entries[placeID] = (listing, now)
        lock.unlock()
    }

    package func load(placeID: Int, now: Date = Date()) -> LiturgyListing? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[placeID] else { return nil }
        if now.timeIntervalSince(entry.saved) > maxAge { return nil }
        return entry.listing
    }
}

package struct CachedLiturgySource: LiturgySource {
    package var id: String { "cache" }
    /// After a parish page, so a stored copy does not hide the page that was just supplied.
    package var rank: Int { 20 }
    package var cache: LiturgyCache
    package func listing(for place: PlaceRecord) -> LiturgyListing? {
        cache.load(placeID: place.id)
    }
}

package enum LiturgyLookup {
    /// Hand-checked parish readings, then a parsed parish page, then the cache.
    /// MassTimes.org and Discover Mass stay in `LiturgySourceID.unusedSlots` and are not called.
    package static func sources(pages: [Int: String] = [:], verified: String = "", cache: LiturgyCache = LiturgyCache()) -> [any LiturgySource] {
        [
            HandVerifiedSource(),
            CachedLiturgySource(cache: cache),
            ParishPageSource(pages: pages, verified: verified),
        ].sorted { $0.rank < $1.rank }
    }

    package static func card(for place: PlaceRecord, sources: [any LiturgySource]? = nil) -> LiturgyCard {
        let chain = sources ?? self.sources()
        let contact = ParishDirectories.contact(for: place)
        if let listing = chain.compactMap({ $0.listing(for: place) }).first {
            return LiturgyCard(
                lines: listing.lines,
                confession: listing.confession,
                lastVerified: PlaceText.formatSourceDate(listing.verified),
                phone: listing.phone.isEmpty ? (contact?.phone ?? "") : listing.phone,
                website: listing.website.isEmpty ? (contact?.website ?? place.website) : listing.website,
                directory: listing.directory.isEmpty ? (contact?.directory ?? "") : listing.directory,
                note: listing.confirm,
                found: true,
                emptyTitle: "",
                emptyDetail: ""
            )
        }
        return LiturgyCard(
            lines: [],
            confession: "",
            lastVerified: "",
            phone: contact?.phone ?? "",
            website: contact?.website ?? place.website,
            directory: contact?.directory ?? "",
            note: "",
            found: false,
            emptyTitle: LiturgyCard.emptyTitle,
            emptyDetail: LiturgyCard.emptyDetail
        )
    }
}
