import Foundation

/// Offline MapLibre style. Land, trails, and place symbols all read the pack
/// vector source. A style that omits those layers is a failed map: the cream
/// background is all that remains.
package enum PackStyleDocument {
    package static let landOpacity = 0.85
    package static let placeLayerIDs = [
        "places-landmark",
        "places-viewpoint",
        "places-museum",
        "places-parking",
        "places-water",
        "places-trailhead",
        "places-worship",
        "places-shrine",
        "places-chapel",
        "places-catholic",
    ]
    package static let requiredLayerIDs = [
        "background",
        "land-usfs",
        "land-private",
        "land-nps",
        "land-blm",
        "trails",
        "trails-casing",
        "places-catholic",
        "places-worship",
        "places-landmark",
        "places-chapel",
    ]

    package static func json(packURL: String?, glyphsURL: String, online: Bool) -> String {
        let root = rootObject(packURL: packURL, glyphsURL: glyphsURL, online: online)
        guard JSONSerialization.isValidJSONObject(root),
              let data = try? JSONSerialization.data(withJSONObject: root),
              let text = String(data: data, encoding: .utf8)
        else { return "{}" }
        return text
    }

    /// Empty when every required pack layer is present and the pack source is a pmtiles vector URL.
    package static func missingLayers(in json: String) -> [String] {
        guard let root = parse(json) else { return requiredLayerIDs + ["pack"] }
        let layers = root["layers"] as? [[String: Any]] ?? []
        var byID: [String: [String: Any]] = [:]
        for layer in layers {
            if let id = layer["id"] as? String { byID[id] = layer }
        }
        var missing: [String] = []
        for id in requiredLayerIDs {
            guard let layer = byID[id] else {
                missing.append(id)
                continue
            }
            if id == "background" { continue }
            if layer["source"] as? String != "pack" {
                missing.append(id)
                continue
            }
            let sourceLayer = layer["source-layer"] as? String
            if id.hasPrefix("land-"), sourceLayer != "land" { missing.append(id) }
            if id == "trails" || id == "trails-casing", sourceLayer != "trails" { missing.append(id) }
            if id.hasPrefix("places-"), sourceLayer != "places" { missing.append(id) }
        }
        if !packIsVector(root) { missing.append("pack") }
        return missing
    }

    package static func missingRenderedLayers(_ present: Set<String>, packIsVector: Bool) -> [String] {
        var missing = requiredLayerIDs.filter { !present.contains($0) }
        if !packIsVector { missing.append("pack") }
        return missing
    }

    /// Trails-only fades every pin. Place chips hide the roles they do not include.
    /// Open now cannot drop a pin here: visitor hours are not stored on the tile.
    package static func showsPlaceLayer(_ identifier: String, filter: AtlasFilter) -> Bool {
        guard placeLayerIDs.contains(identifier) else { return false }
        if !filter.restrictsPlaces { return true }
        if !filter.catholic && !filter.churches { return true }
        switch identifier {
        case "places-catholic":
            return true
        case "places-chapel", "places-worship", "places-shrine":
            return filter.churches && !filter.catholic
        default:
            return false
        }
    }

    package static func placeOpacity(filter: AtlasFilter) -> Double {
        if filter.trails && !filter.restrictsPlaces { return 0.28 }
        return 1
    }

    private static func parse(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func packIsVector(_ root: [String: Any]) -> Bool {
        guard let sources = root["sources"] as? [String: Any],
              let pack = sources["pack"] as? [String: Any],
              pack["type"] as? String == "vector",
              let url = pack["url"] as? String
        else { return false }
        return url.hasPrefix("pmtiles://")
    }

    private static func rootObject(packURL: String?, glyphsURL: String, online: Bool) -> [String: Any] {
        var sources: [String: Any] = ["pack": packSource(packURL)]
        if online {
            sources["openmaptiles"] = [
                "type": "vector",
                "url": "https://tiles.openfreemap.org/planet",
            ]
        }
        var layers: [[String: Any]] = [
            [
                "id": "background",
                "type": "background",
                "paint": ["background-color": "#EFE6D6"],
            ],
        ]
        if online {
            layers.append([
                "id": "ofm-water",
                "type": "fill",
                "source": "openmaptiles",
                "source-layer": "water",
                "paint": ["fill-color": "#C5D5E4"],
            ])
        }
        let lands: [(String, String, String)] = [
            ("land-tribal", "tribal", "#7A3E8C"),
            ("land-nps", "nps", "#1F6F8A"),
            ("land-usfs", "usfs", "#1F7A3A"),
            ("land-usfs-inholding", "usfs_inholding", "#A89880"),
            ("land-usfs-other", "usfs_other", "#6E8F72"),
            ("land-blm", "blm", "#C48A12"),
            ("land-dod", "dod", "#8C3030"),
            ("land-federal", "federal_other", "#3D5A73"),
            ("land-trust", "state_trust", "#E06A1F"),
            ("land-state", "state_other", "#C4A06A"),
            ("land-abq-closed", "abq_closed", "#A33B3B"),
            ("land-abq-open", "abq_open", "#4F8A32"),
            ("land-local", "local_protected", "#2F8F7A"),
            ("land-private", "private_mapped", "#C4B49A"),
            ("land-undefined", "sma_undefined", "#B7A99A"),
        ]
        for (identifier, kind, color) in lands {
            layers.append(landLayer(identifier, kind, color))
        }
        layers.append([
            "id": "land-private-line",
            "type": "line",
            "source": "pack",
            "source-layer": "land",
            "filter": ["==", ["get", "kind"], "private_mapped"],
            "paint": ["line-color": "#4A4036", "line-width": 1.1],
        ])
        if online {
            let roadClasses = ["motorway", "trunk", "primary", "secondary", "tertiary", "minor", "service"]
            let roadFilter: [Any] = ["in", ["get", "class"], ["literal", roadClasses]]
            let width: [Any] = ["interpolate", ["linear"], ["zoom"], 11, 0.4, 14, 2.4, 16, 6]
            let core: [Any] = ["interpolate", ["linear"], ["zoom"], 11, 0.2, 14, 1.3, 16, 3.6]
            layers.append([
                "id": "ofm-roads-casing",
                "type": "line",
                "source": "openmaptiles",
                "source-layer": "transportation",
                "filter": roadFilter,
                "paint": ["line-color": "#6E6254", "line-width": width],
            ])
            layers.append([
                "id": "ofm-roads",
                "type": "line",
                "source": "openmaptiles",
                "source-layer": "transportation",
                "filter": roadFilter,
                "paint": ["line-color": "#FBF7F0", "line-width": core],
            ])
        }
        layers.append([
            "id": "trails-casing",
            "type": "line",
            "source": "pack",
            "source-layer": "trails",
            "paint": [
                "line-color": "#F4EFE4",
                "line-width": ["interpolate", ["linear"], ["zoom"], 10, 3, 16, 7],
            ],
        ])
        layers.append([
            "id": "trails",
            "type": "line",
            "source": "pack",
            "source-layer": "trails",
            "paint": [
                "line-color": "#6B4F3A",
                "line-width": ["interpolate", ["linear"], ["zoom"], 10, 1.6, 16, 4],
            ],
        ])
        layers.append([
            "id": "parcels",
            "type": "line",
            "source": "pack",
            "source-layer": "parcels",
            "minzoom": 13,
            "layout": ["visibility": "none"],
            "paint": ["line-color": "#5C5346", "line-width": 0.8],
        ])
        layers.append(contentsOf: placeLayers())
        if online {
            layers.append([
                "id": "ofm-road-labels",
                "type": "symbol",
                "source": "openmaptiles",
                "source-layer": "transportation_name",
                "minzoom": 14,
                "layout": [
                    "text-field": ["get", "name"],
                    "text-font": ["NotoSansRegular"],
                    "text-size": 11,
                    "symbol-placement": "line",
                    "text-optional": true,
                ],
                "paint": [
                    "text-color": "#2A241C",
                    "text-halo-color": "#FBF7F0",
                    "text-halo-width": 1.2,
                ],
            ])
        }
        return [
            "version": 8,
            "name": "Pilgrim Atlas",
            "glyphs": glyphsURL,
            "sources": sources,
            "layers": layers,
        ]
    }

    private static func packSource(_ packURL: String?) -> [String: Any] {
        if let packURL, packURL.hasPrefix("pmtiles://") {
            return ["type": "vector", "url": packURL]
        }
        return ["type": "geojson", "data": ["type": "FeatureCollection", "features": []]]
    }

    private static func landLayer(_ identifier: String, _ kind: String, _ color: String) -> [String: Any] {
        [
            "id": identifier,
            "type": "fill",
            "source": "pack",
            "source-layer": "land",
            "filter": ["==", ["get", "kind"], kind],
            "paint": [
                "fill-color": color,
                "fill-opacity": landOpacity,
                "fill-outline-color": color,
            ],
        ]
    }

    private static func placeLayers() -> [[String: Any]] {
        let chapel = ["chapel", "cathedral", "basilica", "santuario"]
        let shrine = ["shrine", "statue"]
        let viewpoint = ["viewpoint", "overlook", "scenic"]
        let museum = ["museum"]
        let parking = ["parking"]
        let water = ["spring", "cistern", "trough"]
        let trailhead = ["trailhead"]
        let special = chapel + shrine + viewpoint + museum + parking + water + trailhead
        return [
            symbol("places-landmark", "landmark", filter: landmark(excluding: special), overlap: false, textOptional: true, sort: 10),
            symbol("places-viewpoint", "viewpoint", filter: named(viewpoint), overlap: false, textOptional: true, sort: 40),
            symbol("places-museum", "museum", filter: named(museum), overlap: false, textOptional: true, sort: 40),
            symbol("places-parking", "parking", filter: named(parking), overlap: false, textOptional: true, sort: 40),
            symbol("places-water", "water", filter: named(water), overlap: false, textOptional: true, sort: 40),
            symbol("places-trailhead", "trailhead", filter: named(trailhead), overlap: false, textOptional: true, sort: 40),
            symbol("places-worship", "worship", filter: ["all", ["==", ["get", "category"], "worship"], ["==", ["get", "catholic"], 0]], overlap: false, textOptional: true, sort: 60),
            symbol("places-shrine", "shrine", filter: named(shrine), overlap: false, textOptional: true, sort: 50),
            symbol("places-chapel", "chapel", filter: named(chapel), overlap: true, textOptional: false, sort: 90),
            symbol("places-catholic", "catholic", filter: ["all", ["==", ["get", "category"], "worship"], ["==", ["get", "catholic"], 1]], overlap: true, textOptional: false, sort: 100),
        ]
    }

    private static func named(_ tokens: [String]) -> [Any] {
        ["all", ["==", ["get", "category"], "landmark"], anyName(tokens)]
    }

    private static func landmark(excluding tokens: [String]) -> [Any] {
        ["all", ["==", ["get", "category"], "landmark"], ["!", anyName(tokens)]]
    }

    private static func anyName(_ tokens: [String]) -> [Any] {
        var filter: [Any] = ["any"]
        for token in tokens {
            filter.append(["in", token, ["downcase", ["get", "name"]]])
        }
        return filter
    }

    private static func symbol(
        _ identifier: String,
        _ icon: String,
        filter: [Any],
        overlap: Bool,
        textOptional: Bool,
        sort: Double
    ) -> [String: Any] {
        [
            "id": identifier,
            "type": "symbol",
            "source": "pack",
            "source-layer": "places",
            "filter": filter,
            "layout": [
                "icon-image": icon,
                "icon-size": 0.62,
                "icon-allow-overlap": overlap,
                "icon-padding": 2,
                "symbol-sort-key": sort,
                "text-field": ["get", "name"],
                "text-font": ["NotoSansRegular"],
                "text-size": 12,
                "text-offset": [0.0, 1.25],
                "text-anchor": "top",
                "text-optional": textOptional,
                "text-max-width": 8,
            ],
            "paint": [
                "text-color": "#1C1915",
                "text-halo-color": "#F4EFE4",
                "text-halo-width": 1.4,
            ],
        ]
    }
}
