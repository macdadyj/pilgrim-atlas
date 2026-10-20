import Foundation

/// Who a worship place belongs to. Non-Christian sites are never drawn.
package enum FaithKind: Equatable, Sendable {
    case catholic
    case orthodox
    case sspx
    case otherChristian
    case nonChristian
    case unknownWorship
    case secular
}

package enum Faith {
    package static func kind(for place: PlaceRecord) -> FaithKind {
        kind(name: place.name, category: place.category, denomination: place.denomination, catholic: place.catholic)
    }

    package static func kind(name: String, category: String, denomination: String, catholic: Bool) -> FaithKind {
        if category == "restaurant" || category == "grocery" || category == "fuel" || category == "hiking" {
            return .secular
        }
        let foldedName = AtlasQuery.fold(name)
        let foldedDenomination = Catholic.normalize(denomination)
        if isNonChristian(name: foldedName, denomination: foldedDenomination) { return .nonChristian }
        if isSSPX(name: foldedName, denomination: foldedDenomination) { return .sspx }
        if isOrthodox(name: foldedName, denomination: foldedDenomination) { return .orthodox }
        if catholic || Catholic.isCatholicDenomination(denomination) { return .catholic }
        if isOtherChristian(foldedDenomination) { return .otherChristian }
        if catholicSiteName(foldedName) && foldedDenomination.isEmpty { return .catholic }
        if category == "worship" || foldedName.contains("church") {
            return .unknownWorship
        }
        return .secular
    }

    /// Non-Christian worship never appears. Other and unknown worship wait for that layer.
    package static func included(_ place: PlaceRecord, showOtherWorship: Bool) -> Bool {
        switch kind(for: place) {
        case .nonChristian:
            return false
        case .otherChristian, .unknownWorship:
            return showOtherWorship
        case .catholic, .orthodox, .sspx, .secular:
            return true
        }
    }

    private static func isSSPX(name: String, denomination: String) -> Bool {
        let blob = name + " " + denomination
        if blob.contains("fsspx") || blob.contains("sspx") { return true }
        if blob.contains("priestly fraternity") && blob.contains("pius") { return true }
        if blob.contains("society of") && blob.contains("pius") { return true }
        return false
    }

    private static func isOrthodox(name: String, denomination: String) -> Bool {
        if denomination.contains("presbyterian") { return false }
        return denomination.contains("orthodox") || name.contains("orthodox")
    }

    private static func isOtherChristian(_ denomination: String) -> Bool {
        if denomination.isEmpty { return false }
        let tokens = [
            "baptist", "lutheran", "methodist", "presbyterian", "pentecostal", "episcopal",
            "anglican", "protestant", "evangelical", "nondenominational", "adventist",
            "jehovah", "messianic", "congregational", "foursquare", "holiness", "reformed",
            "mennonite", "quaker", "friends", "assembly", "nazarene", "christian",
        ]
        return tokens.contains { denomination.contains($0) }
    }

    private static func isNonChristian(name: String, denomination: String) -> Bool {
        let blob = name + " " + denomination
        if blob.contains("messianic") { return false }
        let tokens = [
            "muslim", "islam", "mosque", "masjid", "hindu", "budd", "sikh", "gurdwara", "gurudwara",
            "synagogue", "jewish", "chabad", "shinto", "taoist", "jain", "pagan", "wicca", "bahai",
            "mormon", "latter_day", "latter day", "lds",
        ]
        return tokens.contains { blob.contains($0) }
    }

    /// Chapels, shrines, missions, cathedrals, and monasteries stay on when no other church claims them.
    private static func catholicSiteName(_ name: String) -> Bool {
        let tokens = ["chapel", "cathedral", "basilica", "santuario", "shrine", "mission", "monastery"]
        if tokens.contains(where: { name.contains($0) }) { return true }
        return name.contains("our lady")
    }
}
