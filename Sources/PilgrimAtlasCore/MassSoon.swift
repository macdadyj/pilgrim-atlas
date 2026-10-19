import Foundation

/// The soonest verified liturgy within a drive of the reader. Unparsed lines are skipped.
package struct UpcomingLiturgy: Equatable, Sendable {
    package var placeID: Int
    package var placeName: String
    package var line: String
    package var when: Date
    package var meters: Int
}

package enum MassSoon {
    /// About 25 miles. Far enough for a city, not a statewide guess.
    package static let radiusMeters = 25.0 * 1_609.344

    package static func next(
        places: [PlaceRecord],
        origin: LonLat,
        now: Date = Date(),
        timeZone: TimeZone = .current,
        radiusMeters: Double = radiusMeters
    ) -> UpcomingLiturgy? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var best: UpcomingLiturgy?
        for place in places {
            let meters = Geometry.haversineMeters(origin, place.coordinate)
            guard meters <= radiusMeters else { continue }
            let card = LiturgyLookup.card(for: place)
            guard card.found else { continue }
            for line in card.lines {
                guard let when = nextDate(on: line, now: now, calendar: calendar) else { continue }
                let candidate = UpcomingLiturgy(
                    placeID: place.id,
                    placeName: place.name,
                    line: line,
                    when: when,
                    meters: Int(meters.rounded())
                )
                if let current = best {
                    if candidate.when > current.when { continue }
                    if candidate.when == current.when, candidate.meters >= current.meters { continue }
                }
                best = candidate
            }
        }
        return best
    }

    /// Sunday-start weekday and a clock, from a line such as `Sun 10:00 AM Mass`.
    package static func nextDate(on line: String, now: Date, calendar: Calendar) -> Date? {
        guard let clock = clockExpression else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = clock.firstMatch(in: line, range: range), match.numberOfRanges == 5,
              let weekdayRange = Range(match.range(at: 1), in: line),
              let hourRange = Range(match.range(at: 2), in: line),
              let minuteRange = Range(match.range(at: 3), in: line),
              let meridianRange = Range(match.range(at: 4), in: line),
              let weekday = weekdayNumber(String(line[weekdayRange])),
              var hour = Int(line[hourRange]),
              let minute = Int(line[minuteRange]),
              (1...12).contains(hour),
              (0...59).contains(minute)
        else { return nil }
        let meridian = String(line[meridianRange]).lowercased()
        if meridian == "am" {
            if hour == 12 { hour = 0 }
        } else if hour != 12 {
            hour += 12
        }
        let today = calendar.component(.weekday, from: now)
        var delta = weekday - today
        if delta < 0 { delta += 7 }
        guard let day = calendar.date(byAdding: .day, value: delta, to: calendar.startOfDay(for: now)),
              var when = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        else { return nil }
        if when < now {
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: when) else { return nil }
            when = nextWeek
        }
        return when
    }

    private static let clockExpression: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(Sun|Mon|Tue|Wed|Thu|Fri|Sat)[A-Za-z]*[[:space:]]+([0-9]{1,2}):([0-9]{2})[[:space:]]*([AaPp][Mm])\b"#
    )

    private static func weekdayNumber(_ token: String) -> Int? {
        switch token.lowercased() {
        case "sun", "sunday":
            return 1
        case "mon", "monday":
            return 2
        case "tue", "tuesday":
            return 3
        case "wed", "wednesday":
            return 4
        case "thu", "thursday":
            return 5
        case "fri", "friday":
            return 6
        case "sat", "saturday":
            return 7
        default:
            return nil
        }
    }
}

/// Text sent with the system share sheet.
package enum PlaceShare {
    package static func message(name: String, address: String, phone: String, website: String) -> String {
        var lines = [name.trimmingCharacters(in: .whitespacesAndNewlines)]
        let street = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !street.isEmpty { lines.append(street) }
        let number = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !number.isEmpty { lines.append(number) }
        if let site = SiteLink.usable(website) {
            lines.append(site.absoluteString)
        }
        lines.append("Pilgrim Atlas")
        return lines.joined(separator: "\n")
    }
}
