import Foundation

/// Map chips. All off is the everyday map: every place, trail, and land kind.
/// Turning chips on narrows places by intersection and fades land that is outside the selection.
package struct AtlasFilter: Equatable, Sendable {
    package var catholic = false
    package var churches = false
    package var trails = false
    package var publicLand = false
    package var parks = false
    package var openNow = false
    package var hidePlacesWithoutHours = false
    /// Protestant and unnamed worship stay off until this is on. Non-Christian sites never draw.
    package var showOtherWorship = false
    /// Latin and Byzantine Catholic places. On until turned off.
    package var showCatholic = true
    /// Eastern Orthodox churches. On until turned off.
    package var showOrthodox = true
    /// Chapels of the Society of St. Pius X. On until turned off.
    package var showSSPX = true
    /// Hexagon landmark pins. On until turned off, and remembered on this phone.
    package var showLandmarks = true
    /// Optional viewport layers. Off until turned on, so the church map stays the same.
    package var restaurants = false
    package var groceries = false
    package var fuel = false

    package static let empty = AtlasFilter()

    package var anyChip: Bool {
        catholic || churches || trails || publicLand || parks || openNow
    }

    package var restrictsPlaces: Bool {
        catholic || churches || openNow || hidePlacesWithoutHours
    }

    /// Trails stay on the map and in search until a chip is on and Trails is not one of them.
    package var showsTrails: Bool {
        trails || !anyChip
    }

    package var chipTitles: [String] {
        var titles: [String] = []
        if catholic { titles.append("Catholic sites") }
        if churches { titles.append("Churches and shrines") }
        if trails { titles.append("Trails") }
        if publicLand { titles.append("Public land") }
        if parks { titles.append("Parks") }
        if openNow { titles.append("Open now") }
        return titles
    }

    package var summary: String {
        chipTitles.joined(separator: ", ")
    }

    package var searchTitle: String {
        let titles = chipTitles
        if titles.isEmpty { return "Search" }
        return "Search · \(titles.joined(separator: ", "))"
    }

    package var emptySearchTitle: String {
        let titles = chipTitles
        if titles.isEmpty { return "No matches in the offline pack" }
        return "No matches in \(titles.joined(separator: ", "))"
    }
}

package enum PinRole: String, Equatable, Sendable, CaseIterable {
    case catholic
    case chapel
    case worship
    case orthodox
    case sspx
    case shrine
    case viewpoint
    case museum
    case parking
    case water
    case trailhead
    case landmark
    case restaurant
    case grocery
    case fuel

    package var legend: String {
        switch self {
        case .catholic: return "Catholic landmark"
        case .chapel: return "Chapel"
        case .worship: return "Other worship"
        case .orthodox: return "Orthodox church"
        case .sspx: return "SSPX chapel"
        case .shrine: return "Shrine or statue"
        case .viewpoint: return "Viewpoint"
        case .museum: return "Museum"
        case .parking: return "Parking"
        case .water: return "Water"
        case .trailhead: return "Trailhead"
        case .landmark: return "Landmark"
        case .restaurant: return "Restaurant"
        case .grocery: return "Grocery"
        case .fuel: return "Gas station"
        }
    }

    /// Sheet and list tiles. Map badges stay the drawn pin art.
    package var systemImage: String {
        switch self {
        case .catholic: return "cross.fill"
        case .chapel: return "cross"
        case .worship: return "building.columns"
        case .orthodox: return "building.columns"
        case .sspx: return "cross.circle.fill"
        case .shrine: return "diamond.fill"
        case .viewpoint: return "eye.fill"
        case .museum: return "building.columns.fill"
        case .parking: return "parkingsign"
        case .water: return "drop.fill"
        case .trailhead: return "figure.hiking"
        case .landmark: return "hexagon.fill"
        case .restaurant: return "fork.knife"
        case .grocery: return "basket.fill"
        case .fuel: return "fuelpump.fill"
        }
    }

    /// Higher values draw above other pins.
    package var sortKey: Double {
        switch self {
        case .catholic: return 100
        case .chapel: return 90
        case .orthodox: return 95
        case .sspx: return 94
        case .worship: return 60
        case .shrine: return 50
        case .viewpoint, .museum, .parking, .water, .trailhead: return 40
        case .restaurant, .grocery, .fuel: return 15
        case .landmark: return 10
        }
    }

    package var allowsOverlap: Bool {
        switch self {
        case .catholic, .chapel, .orthodox, .sspx: return true
        case .worship, .shrine, .viewpoint, .museum, .parking, .water, .trailhead, .landmark, .restaurant, .grocery, .fuel: return false
        }
    }
}

package enum PlaceDraw: Equatable, Sendable {
    case show
    case fade
    case hide
}

package enum HoursReading: Equatable, Sendable {
    case none
    case notAClock
    case clock(openNow: Bool)
}

package struct HoursCoverage: Equatable, Sendable {
    package var listed: Int
    package var catholicListed: Int
    package var openClocks: Int

    package var line: String {
        "Visitor hours are on \(listed) places, \(catholicListed) of them Catholic."
    }

    package var noneOpenLine: String? {
        guard listed > 0, openClocks == 0 else { return nil }
        return "None of the \(listed) listed hours match right now."
    }
}

package enum MapFilter {
    package static let churchTokens = ["chapel", "church", "shrine", "santuario", "cathedral", "basilica"]
    package static let chapelTokens = ["chapel", "cathedral", "basilica", "santuario"]
    package static let publicKinds: Set<String> = ["usfs", "blm", "nps", "federal_other", "local_protected", "abq_open"]
    package static let publicLandSubtitle = "Forest, BLM, park, and open space. State Trust stays off this chip."
    package static let foodSubtitle = "Not in this pack yet."
    package static let stateTrustLine = "State Trust is not in Public land"
    package static let notParkLine = "This point is not inside a park."
    package static let hoursMissing = "No visitor hours in the pack."
    package static let hoursUnparsed = "Hours listed, not a single clock."
    package static let terrainMissing = "Hillshade and contours are not in this pack yet."

    package static func foodCount(_ places: [PlaceRecord]) -> Int {
        let kinds: Set<String> = ["cafe", "restaurant", "fast_food", "toilets", "food"]
        return places.filter { kinds.contains($0.category) }.count
    }

    package static func isChurchOrShrine(_ place: PlaceRecord) -> Bool {
        if place.category == "worship" { return true }
        guard place.category == "landmark" else { return false }
        let folded = AtlasQuery.fold(place.name)
        return churchTokens.contains { folded.contains($0) }
    }

    package static func isUnnamedWorship(_ place: PlaceRecord) -> Bool {
        AtlasQuery.fold(place.name) == AtlasQuery.fold("Unnamed place of worship")
    }

    package static func pinRole(for place: PlaceRecord) -> PinRole {
        let folded = AtlasQuery.fold(place.name)
        switch Faith.kind(for: place) {
        case .orthodox:
            return .orthodox
        case .sspx:
            return .sspx
        case .nonChristian, .otherChristian, .unknownWorship:
            return .worship
        case .catholic, .secular:
            break
        }
        switch place.category {
        case "hiking", "trailhead":
            return .trailhead
        case "restaurant":
            return .restaurant
        case "grocery":
            return .grocery
        case "fuel":
            return .fuel
        default:
            break
        }
        if place.catholic && place.category == "worship" { return .catholic }
        if Faith.kind(for: place) == .catholic, chapelTokens.contains(where: { folded.contains($0) }) {
            return folded.contains("shrine") || folded.contains("statue") ? .shrine : .chapel
        }
        if chapelTokens.contains(where: { folded.contains($0) }) { return .chapel }
        if folded.contains("shrine") || folded.contains("statue") { return .shrine }
        if folded.contains("viewpoint") || folded.contains("overlook") || folded.contains("scenic") { return .viewpoint }
        if folded.contains("trailhead") { return .trailhead }
        if folded.contains("parking") { return .parking }
        if folded.contains("spring") || folded.contains("cistern") || folded.contains("water trough") { return .water }
        if folded.contains("museum") { return .museum }
        if place.category == "worship" { return .worship }
        if place.category == "trailhead" { return .trailhead }
        return .landmark
    }

    /// Picker and sheet label. Landmark rows use the name when it says gallery, monument, or saint.
    package static func listKind(for place: PlaceRecord) -> (label: String, systemImage: String) {
        let role = pinRole(for: place)
        if role == .landmark, let finer = finerLandmark(place) {
            return finer
        }
        return (role.legend, role.systemImage)
    }

    private static func finerLandmark(_ place: PlaceRecord) -> (label: String, systemImage: String)? {
        let folded = AtlasQuery.fold(place.name)
        if folded.contains("gallery") || folded.contains("fine art") {
            return ("Gallery", "paintpalette.fill")
        }
        if folded.contains("monument") || folded.contains("memorial") || folded.contains("marker") {
            return ("Monument", "flag.fill")
        }
        if folded.contains("statue") || namesASaint(folded) {
            return ("Statue", "figure.stand")
        }
        if folded.contains("historic site") {
            return ("Historic site", "building.columns")
        }
        return nil
    }

    private static func namesASaint(_ folded: String) -> Bool {
        let tokens = folded.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return tokens.contains("saint") || tokens.contains("st")
    }

    package static func hoursReading(
        _ raw: String,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> HoursReading {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .none }
        let parts = trimmed.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if parts.isEmpty { return .none }
        var clocks: [DayClock] = []
        var seen: Set<String> = []
        for part in parts {
            guard let clock = dayClock(part) else { return .notAClock }
            for day in clock.days {
                if seen.contains(day) { return .notAClock }
                seen.insert(day)
            }
            clocks.append(clock)
        }
        let open = clocks.contains { clock in clock.covers(now, timeZone: timeZone) }
        return .clock(openNow: open)
    }

    /// True when two parsed ranges cover the same weekday. Those sources do not agree.
    package static func hoursConflict(_ raw: String) -> Bool {
        let parts = raw.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var seen: Set<String> = []
        for part in parts {
            guard let clock = dayClock(part) else { return false }
            for day in clock.days {
                if seen.contains(day) { return true }
                seen.insert(day)
            }
        }
        return false
    }

    package static func hourLines(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        return trimmed.split(separator: ";").map { part in
            let piece = part.trimmingCharacters(in: .whitespaces)
            if let clock = dayClock(piece) { return clock.shown }
            return piece
        }
    }

    package static func coverage(_ places: [PlaceRecord], now: Date = Date(), timeZone: TimeZone = .current) -> HoursCoverage {
        var listed = 0
        var catholicListed = 0
        var openClocks = 0
        for place in places {
            let reading = hoursReading(place.openingHours, now: now, timeZone: timeZone)
            if case .none = reading { continue }
            listed += 1
            if place.catholic { catholicListed += 1 }
            if case .clock(let open) = reading, open { openClocks += 1 }
        }
        return HoursCoverage(listed: listed, catholicListed: catholicListed, openClocks: openClocks)
    }

    package static func placeDraw(
        _ place: PlaceRecord,
        filter: AtlasFilter,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> PlaceDraw {
        if !filter.showLandmarks, pinRole(for: place) == .landmark { return .hide }
        if place.category == "restaurant", !filter.restaurants { return .hide }
        if place.category == "grocery", !filter.groceries { return .hide }
        if place.category == "fuel", !filter.fuel { return .hide }
        switch Faith.kind(for: place) {
        case .nonChristian:
            return .hide
        case .catholic:
            if !filter.showCatholic { return .hide }
        case .orthodox:
            if !filter.showOrthodox { return .hide }
        case .sspx:
            if !filter.showSSPX { return .hide }
        case .otherChristian, .unknownWorship:
            if !filter.showOtherWorship { return .hide }
        case .secular:
            break
        }
        if filter.churches && isUnnamedWorship(place) { return .hide }
        if !matchesPlaceChips(place, filter: filter, now: now, timeZone: timeZone) { return .hide }
        if filter.trails && !filter.restrictsPlaces { return .fade }
        return .show
    }

    /// Map sources keep other worship so that layer can be turned on. Non-Christian sites stay out.
    package static func includeOnMap(
        _ place: PlaceRecord,
        filter: AtlasFilter,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> Bool {
        if Faith.kind(for: place) == .nonChristian { return false }
        var relaxed = filter
        relaxed.showOtherWorship = true
        return placeDraw(place, filter: relaxed, now: now, timeZone: timeZone) != .hide
    }

    package static func includeInLists(
        _ place: PlaceRecord,
        filter: AtlasFilter,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> Bool {
        placeDraw(place, filter: filter, now: now, timeZone: timeZone) == .show
    }

    package static func landShown(kind: String, name: String, filter: AtlasFilter) -> Bool {
        let pub = publicKinds.contains(kind)
        let park = isPark(kind: kind, name: name)
        switch (filter.publicLand, filter.parks) {
        case (false, false): return true
        case (true, false): return pub
        case (false, true): return park
        case (true, true): return pub && park
        }
    }

    package static func isPark(kind: String, name: String) -> Bool {
        if kind == "nps" || kind == "abq_open" { return true }
        if kind == "local_protected" {
            return AtlasQuery.fold(name).contains("park")
        }
        return false
    }

    package static func landHeadline(hit: LandHit?, filter: AtlasFilter, fallback: String) -> String {
        guard let hit else { return fallback }
        if filter.publicLand && hit.kind == .stateTrust { return stateTrustLine }
        if filter.parks && !isPark(kind: hit.kind.rawValue, name: hit.name) { return notParkLine }
        return fallback
    }

    private static func matchesPlaceChips(
        _ place: PlaceRecord,
        filter: AtlasFilter,
        now: Date,
        timeZone: TimeZone
    ) -> Bool {
        if filter.catholic && !place.catholic { return false }
        if filter.churches && !isChurchOrShrine(place) { return false }
        let reading = hoursReading(place.openingHours, now: now, timeZone: timeZone)
        if filter.hidePlacesWithoutHours, case .none = reading { return false }
        if filter.openNow {
            if case .clock(let open) = reading, !open { return false }
        }
        return true
    }

    private struct DayClock {
        var days: [String]
        var startMinute: Int
        var endMinute: Int
        var shown: String

        func covers(_ now: Date, timeZone: TimeZone) -> Bool {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let weekday = calendar.component(.weekday, from: now)
            let symbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            guard (1...7).contains(weekday) else { return false }
            let today = symbols[weekday - 1]
            guard days.contains(today) else { return false }
            let nowMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
            if startMinute == endMinute { return false }
            if startMinute < endMinute {
                return nowMinute >= startMinute && nowMinute < endMinute
            }
            return nowMinute >= startMinute || nowMinute < endMinute
        }
    }

    private static let dayOrder = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    private static let dayNames = [
        "Mo": "Mon", "Tu": "Tue", "We": "Wed", "Th": "Thu", "Fr": "Fri", "Sa": "Sat", "Su": "Sun",
    ]

    private static func dayClock(_ part: String) -> DayClock? {
        let lowered = AtlasQuery.fold(part)
        let blocked = ["sunrise", "sunset", "appointment", "closed", "season", "dawn", "dusk", "off"]
        if blocked.contains(where: { lowered.contains($0) }) { return nil }
        let pieces = part.split(separator: " ").map(String.init)
        guard pieces.count >= 2, let days = expandDays(pieces[0]), !days.isEmpty else { return nil }
        let times = pieces.dropFirst().joined(separator: " ").split(separator: "-").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard times.count == 2, let start = minute(times[0]), let end = minute(times[1]) else { return nil }
        let shownDays = formatDayList(days)
        let shownTime = "\(clockLabel(start))–\(clockLabel(end))"
        return DayClock(days: days, startMinute: start, endMinute: end, shown: "\(shownDays) \(shownTime)")
    }

    private static func expandDays(_ spec: String) -> [String]? {
        var days: [String] = []
        for token in spec.split(separator: ",") {
            let piece = String(token)
            if piece.contains("-") {
                let ends = piece.split(separator: "-", maxSplits: 1).map(String.init)
                guard ends.count == 2,
                      let start = dayOrder.firstIndex(of: ends[0]),
                      let finish = dayOrder.firstIndex(of: ends[1]),
                      start <= finish
                else { return nil }
                days.append(contentsOf: dayOrder[start...finish])
            } else {
                guard dayOrder.contains(piece) else { return nil }
                days.append(piece)
            }
        }
        return days
    }

    private static func formatDayList(_ days: [String]) -> String {
        let indexes = days.compactMap { dayOrder.firstIndex(of: $0) }
        if let first = indexes.first, let last = indexes.last, indexes.count == days.count, indexes.count > 1 {
            let span = Array(first...last)
            if indexes == span {
                let start = dayNames[dayOrder[first]] ?? dayOrder[first]
                let finish = dayNames[dayOrder[last]] ?? dayOrder[last]
                return "\(start)–\(finish)"
            }
        }
        return days.map { dayNames[$0] ?? $0 }.joined(separator: ", ")
    }

    private static func minute(_ value: String) -> Int? {
        let parts = value.split(separator: ":").map(String.init)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute)
        else { return nil }
        return hour * 60 + minute
    }

    private static func clockLabel(_ minuteOfDay: Int) -> String {
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        let suffix = hour < 12 ? "AM" : "PM"
        let clock = hour % 12 == 0 ? 12 : hour % 12
        return "\(clock):\(String(format: "%02d", minute)) \(suffix)"
    }
}

/// One filter control. Food and rest stays in the list so the empty pack is visible, but it is not tappable.
package struct FilterControl: Equatable, Sendable, Identifiable {
    package var id: String
    package var title: String
    package var systemImage: String
    package var subtitle: String
    package var enabled: Bool

    package static let all: [FilterControl] = [
        FilterControl(id: "show-catholic", title: "Catholic churches", systemImage: "cross.fill", subtitle: "Latin and Byzantine Catholic churches, chapels, shrines, and monasteries", enabled: true),
        FilterControl(id: "orthodox", title: "Orthodox churches", systemImage: "building.columns", subtitle: "Eastern Orthodox churches", enabled: true),
        FilterControl(id: "sspx", title: "SSPX chapels", systemImage: "cross.fill", subtitle: "Chapels of the Society of St. Pius X", enabled: true),
        FilterControl(id: "catholic", title: "Catholic sites", systemImage: "cross.fill", subtitle: "Tagged Roman Catholic worship", enabled: true),
        FilterControl(id: "churches", title: "Churches and shrines", systemImage: "building.columns", subtitle: "Chapels, churches, and shrines", enabled: true),
        FilterControl(id: "trails", title: "Trails", systemImage: "figure.hiking", subtitle: "Hiking routes in the pack", enabled: true),
        FilterControl(id: "public-land", title: "Public land", systemImage: "tree.fill", subtitle: MapFilter.publicLandSubtitle, enabled: true),
        FilterControl(id: "parks", title: "Parks", systemImage: "leaf.fill", subtitle: "National parks, city Open Space, and named parks", enabled: true),
        FilterControl(id: "food", title: "Food and rest", systemImage: "fork.knife", subtitle: MapFilter.foodSubtitle, enabled: false),
        FilterControl(id: "open-now", title: "Open now", systemImage: "clock.fill", subtitle: "Places whose visitor hours match this clock", enabled: true),
        FilterControl(id: "landmarks", title: "Landmarks", systemImage: "hexagon.fill", subtitle: "Monuments, memorials, and other named landmarks", enabled: true),
        FilterControl(id: "restaurants", title: "Restaurants", systemImage: "fork.knife", subtitle: "Off until turned on. Loads restaurants and cafes for this view.", enabled: true),
        FilterControl(id: "groceries", title: "Groceries", systemImage: "basket.fill", subtitle: "Off until turned on. Loads grocery stores for this view.", enabled: true),
        FilterControl(id: "gas", title: "Gas stations", systemImage: "fuelpump.fill", subtitle: "Off until turned on. Loads gas stations for this view.", enabled: true),
    ]
}

extension AtlasFilter {
    package func isOn(_ id: String) -> Bool {
        switch id {
        case "show-catholic": return showCatholic
        case "orthodox": return showOrthodox
        case "sspx": return showSSPX
        case "catholic": return catholic
        case "churches": return churches
        case "trails": return trails
        case "public-land": return publicLand
        case "parks": return parks
        case "open-now": return openNow
        case "landmarks": return showLandmarks
        case "restaurants": return restaurants
        case "groceries": return groceries
        case "gas": return fuel
        default: return false
        }
    }

    /// Writes one control to an absolute value. A repeated call with the same value changes nothing.
    package mutating func set(_ id: String, on: Bool) {
        switch id {
        case "show-catholic": showCatholic = on
        case "orthodox": showOrthodox = on
        case "sspx": showSSPX = on
        case "catholic": catholic = on
        case "churches": churches = on
        case "trails": trails = on
        case "public-land": publicLand = on
        case "parks": parks = on
        case "open-now": openNow = on
        case "landmarks": showLandmarks = on
        case "restaurants": restaurants = on
        case "groceries": groceries = on
        case "gas": fuel = on
        default: break
        }
    }

    package mutating func toggle(_ id: String) {
        set(id, on: !isOn(id))
    }

    package var activeControls: [FilterControl] {
        let layers: Set<String> = ["landmarks", "restaurants", "groceries", "gas"]
        return FilterControl.all.filter { $0.enabled && isOn($0.id) && !layers.contains($0.id) }
    }
}
