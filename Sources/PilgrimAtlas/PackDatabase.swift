#if canImport(UIKit)
import Foundation
import PilgrimAtlasCore
import SQLite3

enum PackError: Error, CustomStringConvertible {
    case open(String)
    case query(String)
    case missing

    var description: String {
        switch self {
        case .open(let message): return message
        case .query(let message): return message
        case .missing: return "The Northern New Mexico pack is not in this build."
        }
    }
}

struct PackSnapshot: Sendable {
    var meta: [String: String]
    var places: [PlaceRecord]
    var trails: [TrailRecord]
    var lands: [LandHit]
    var links: [LinkRecord]
}

enum PackDatabase {
    static func load() throws -> PackSnapshot {
        guard let url = Bundle.module.url(
            forResource: "northern-new-mexico",
            withExtension: "sqlite",
            subdirectory: "Resources"
        ) else {
            throw PackError.missing
        }
        var handle: OpaquePointer?
        if sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open the pack."
            sqlite3_close(handle)
            throw PackError.open(message)
        }
        defer { sqlite3_close(handle) }
        guard let handle else { throw PackError.open("Unable to open the pack.") }
        return PackSnapshot(
            meta: try strings(handle, "SELECT key, value FROM meta", map: { ($0, $1) }),
            places: try rows(handle, """
                SELECT id, name, category, catholic, denomination, lat, lon, description, address,
                       opening_hours, service_times, mass_times, confession_times, access, parking,
                       wheelchair, website, wikipedia, wikidata, image, source, source_date
                FROM places
                """) { statement in
                PlaceRecord(
                    id: Int(sqlite3_column_int64(statement, 0)),
                    name: text(statement, 1),
                    category: text(statement, 2),
                    catholic: sqlite3_column_int(statement, 3) != 0,
                    denomination: text(statement, 4),
                    lat: sqlite3_column_double(statement, 5),
                    lon: sqlite3_column_double(statement, 6),
                    description: text(statement, 7),
                    address: text(statement, 8),
                    openingHours: text(statement, 9),
                    serviceTimes: text(statement, 10),
                    massTimes: text(statement, 11),
                    confessionTimes: text(statement, 12),
                    access: text(statement, 13),
                    parking: text(statement, 14),
                    wheelchair: text(statement, 15),
                    website: text(statement, 16),
                    wikipedia: text(statement, 17),
                    wikidata: text(statement, 18),
                    image: text(statement, 19),
                    source: text(statement, 20),
                    sourceDate: text(statement, 21)
                )
            },
            trails: try rows(handle, "SELECT id, name, access, geojson, source, source_date FROM trails") { statement in
                let geometry = GeoJSONParser.geometry(from: Data(text(statement, 3).utf8)) ?? .lineString([])
                return TrailRecord(
                    id: Int(sqlite3_column_int64(statement, 0)),
                    name: text(statement, 1),
                    access: text(statement, 2),
                    geometry: geometry,
                    source: text(statement, 4),
                    sourceDate: text(statement, 5)
                )
            },
            lands: try rows(handle, "SELECT id, kind, name, manager, pub_access, geojson, source, source_date FROM land") { statement in
                let geometry = GeoJSONParser.geometry(from: Data(text(statement, 5).utf8)) ?? .polygon([])
                return LandHit(
                    kind: LandKind.fromPack(text(statement, 1)),
                    name: text(statement, 2),
                    manager: text(statement, 3),
                    pubAccess: text(statement, 4),
                    source: text(statement, 6),
                    sourceDate: text(statement, 7),
                    geometry: geometry
                )
            },
            links: try rows(handle, "SELECT id, title, url, note FROM links") { statement in
                LinkRecord(
                    id: Int(sqlite3_column_int64(statement, 0)),
                    title: text(statement, 1),
                    url: text(statement, 2),
                    note: text(statement, 3)
                )
            }
        )
    }

    private static func text(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let raw = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: UnsafeRawPointer(raw).assumingMemoryBound(to: CChar.self))
    }

    private static func rows<T>(_ handle: OpaquePointer, _ sql: String, map: (OpaquePointer?) -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw PackError.query(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }
        var values: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            values.append(map(statement))
        }
        return values
    }

    private static func strings(_ handle: OpaquePointer, _ sql: String, map: (String, String) -> (String, String)) throws -> [String: String] {
        let pairs: [(String, String)] = try rows(handle, sql) { statement in
            map(text(statement, 0), text(statement, 1))
        }
        return Dictionary(uniqueKeysWithValues: pairs)
    }
}

#endif
