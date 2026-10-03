import Foundation

package enum LandKind: String, Equatable, Sendable, CaseIterable {
    case tribal
    case nps
    case usfs
    case usfsInholding = "usfs_inholding"
    case usfsOther = "usfs_other"
    case blm
    case dod
    case federalOther = "federal_other"
    case stateTrust = "state_trust"
    case stateOther = "state_other"
    case abqClosed = "abq_closed"
    case abqOpen = "abq_open"
    case localProtected = "local_protected"
    case privateMapped = "private_mapped"
    case smaUndefined = "sma_undefined"
    case unknown

    package static func fromPack(_ raw: String) -> LandKind {
        LandKind(rawValue: raw) ?? .unknown
    }

    package var rank: Int {
        switch self {
        case .tribal: return 0
        case .nps: return 1
        case .usfs: return 2
        case .usfsInholding, .usfsOther: return 3
        case .blm: return 4
        case .dod, .federalOther: return 5
        case .stateTrust: return 6
        case .stateOther: return 7
        case .abqClosed: return 8
        case .abqOpen: return 9
        case .localProtected: return 10
        case .privateMapped: return 11
        case .smaUndefined: return 12
        case .unknown: return 99
        }
    }

    package var sentenceKey: String {
        switch self {
        case .tribal: return "tribal"
        case .nps: return "nps"
        case .usfs: return "usfs"
        case .usfsInholding: return "usfs_inholding"
        case .usfsOther: return "usfs_other"
        case .blm: return "blm"
        case .dod: return "dod"
        case .federalOther: return "federal_other"
        case .stateTrust: return "state_trust"
        case .stateOther: return "state_other"
        case .abqClosed: return "abq_closed"
        case .abqOpen: return "abq_open"
        case .localProtected: return "local_protected"
        case .privateMapped: return "private_mapped"
        case .smaUndefined: return "sma_undefined"
        case .unknown: return "unknown"
        }
    }
}

package struct LandHit: Equatable, Sendable {
    package var kind: LandKind
    package var name: String
    package var manager: String
    package var pubAccess: String
    package var source: String
    package var sourceDate: String
    package var geometry: GeoJSONGeometry

    package init(
        kind: LandKind,
        name: String,
        manager: String,
        pubAccess: String,
        source: String,
        sourceDate: String,
        geometry: GeoJSONGeometry
    ) {
        self.kind = kind
        self.name = name
        self.manager = manager
        self.pubAccess = pubAccess
        self.source = source
        self.sourceDate = sourceDate
        self.geometry = geometry
    }

    package var bboxArea: Double {
        guard let box = geometry.bbox else { return 1e9 }
        return max(0, (box.maxLon - box.minLon) * (box.maxLat - box.minLat))
    }
}

package enum LandStatus {
    private static let pubKeys = ["OA": "pub_oa", "RA": "pub_ra", "XA": "pub_xa", "UK": "pub_uk"]

    package static func sentence(_ hit: LandHit?) -> String {
        guard let hit else { return Copy.text("unknown") }
        let base = Copy.text(hit.kind.sentenceKey)
        let label = hit.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let manager = hit.manager.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = label.isEmpty ? manager : label
        var text = prefix.isEmpty ? base : "\(prefix). \(base)"
        if let key = pubKeys[hit.pubAccess.uppercased()] {
            text += " " + Copy.text(key)
        }
        return text
    }

    package static func status(lon: Double, lat: Double, hits: [LandHit]) -> (LandHit?, String) {
        let point = LonLat(lon: lon, lat: lat)
        let containing = hits.filter { hit in
            guard let box = hit.geometry.bbox else { return false }
            if lon < box.minLon || lon > box.maxLon || lat < box.minLat || lat > box.maxLat { return false }
            return Geometry.contains(point, hit.geometry)
        }
        guard !containing.isEmpty else { return (nil, sentence(nil)) }
        let preferred = preferNamedFee(containing)
        let winner = preferred.sorted { lhs, rhs in
            if lhs.kind.rank != rhs.kind.rank { return lhs.kind.rank < rhs.kind.rank }
            return lhs.bboxArea < rhs.bboxArea
        }[0]
        return (winner, sentence(winner))
    }

    /// Short card title. Unknown stays the full unknown sentence. Unnamed private land does not pretend to be a landmark.
    package static func headline(_ hit: LandHit?) -> String {
        guard let hit else { return Copy.text("unknown") }
        let name = hit.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if hit.kind == .privateMapped, name.isEmpty {
            return "Private on the surface map"
        }
        if !name.isEmpty { return name }
        let manager = hit.manager.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manager.isEmpty { return manager }
        return Copy.text(hit.kind.sentenceKey)
    }

    /// Drop a PAD-US "unknown" polygon when a named fee polygon of the same kind already says open, restricted, or closed.
    private static func preferNamedFee(_ hits: [LandHit]) -> [LandHit] {
        let known = Set(hits.compactMap { hit -> LandKind? in
            let access = hit.pubAccess.uppercased()
            let named = !hit.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if named && (access == "OA" || access == "RA" || access == "XA") {
                return hit.kind
            }
            return nil
        })
        guard !known.isEmpty else { return hits }
        let kept = hits.filter { hit in
            if hit.pubAccess.uppercased() != "UK" { return true }
            return !known.contains(hit.kind)
        }
        return kept.isEmpty ? hits : kept
    }

    package static func grantsEntry(_ sentence: String) -> Bool {
        let lowered = sentence.lowercased()
        let banned = [
            "you can enter",
            "you can go here",
            "entry is allowed",
            "permission to enter is granted",
            "public land you can",
        ]
        return banned.contains { lowered.contains($0) }
    }
}
