import Foundation

/// Offline MapLibre style. Land uses a detail archive through zoom 14.
/// Trails stay on the main pack and overzoom from zoom 12. The main pack's
/// zoom 14 tiles hold places (and Albuquerque parcels) only.
package enum PackStyleDocument {
    package static let landOpacity = 0.48
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

    package static func json(
        packURL: String?,
        glyphsURL: String,
        online: Bool,
        hillshadeURL: String? = nil,
        contourURL: String? = nil,
        landURL: String? = nil
    ) -> String {
        let root = rootObject(
            packURL: packURL,
            glyphsURL: glyphsURL,
            online: online,
            hillshadeURL: hillshadeURL,
            contourURL: contourURL,
            landURL: landURL
        )
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
            if layer["source"] as? String != expectedSource(id) {
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

    /// Empty when land and trails overzoom the zooms that contain them, fills stay
    /// opaque enough to see, and no full-map beige layer sits above the land.
    package static func renderProblems(in json: String) -> [String] {
        let contract = RenderContract.load()
        guard let root = parse(json) else { return ["style"] }
        var problems = missingLayers(in: json)
        let sources = root["sources"] as? [String: Any] ?? [:]
        if zoom(sources["pack-land"]) != contract.landMaxZoom { problems.append("land-maxzoom") }
        if zoom(sources["pack-trails"]) != contract.trailMaxZoom { problems.append("trail-maxzoom") }
        if zoom(sources["pack"]) != contract.placeMaxZoom { problems.append("place-maxzoom") }
        if sources["hillshade"] != nil, zoom(sources["hillshade"]) != contract.hillshadeMaxZoom {
            problems.append("hillshade-maxzoom")
        }
        if sources["contours"] != nil, zoom(sources["contours"]) != contract.terrainMaxZoom {
            problems.append("contour-maxzoom")
        }
        let layers = root["layers"] as? [[String: Any]] ?? []
        let ids = layers.compactMap { $0["id"] as? String }
        guard let landIndex = ids.firstIndex(of: "land-usfs"),
              let backgroundIndex = ids.firstIndex(of: "background")
        else { return problems + ["order"] }
        if backgroundIndex > landIndex { problems.append("background-above-land") }
        if let hill = ids.firstIndex(of: "hillshade"), hill > landIndex {
            problems.append("hillshade-above-land")
        }
        if let contours = ids.firstIndex(of: "contours-index"), let trails = ids.firstIndex(of: "trails") {
            if contours < landIndex || contours > trails { problems.append("contour-order") }
        }
        for layer in layers {
            let identifier = layer["id"] as? String ?? ""
            let type = layer["type"] as? String ?? ""
            let paint = layer["paint"] as? [String: Any] ?? [:]
            let index = ids.firstIndex(of: identifier) ?? -1
            if identifier.hasPrefix("land-"), type == "fill" {
                let opacity = number(paint["fill-opacity"]) ?? 0
                if opacity < contract.minFillOpacity { problems.append("\(identifier)-opacity") }
            }
            if identifier == "trails" {
                let opacity = number(paint["line-opacity"]) ?? 1
                if opacity < 0.5 { problems.append("trails-opacity") }
            }
            if index > landIndex {
                if type == "background" { problems.append("opaque-background") }
                if type == "fill", layer["filter"] == nil, (number(paint["fill-opacity"]) ?? 1) >= 0.98 {
                    problems.append("opaque-cover-\(identifier)")
                }
            }
            if identifier == "places-catholic" {
                let layout = layer["layout"] as? [String: Any] ?? [:]
                if layout["text-allow-overlap"] as? Bool == true { problems.append("label-overlap") }
                if layout["icon-allow-overlap"] as? Bool != true { problems.append("catholic-priority") }
                if layout["text-optional"] as? Bool != true { problems.append("label-required") }
                if layout["text-variable-anchor"] == nil { problems.append("label-anchor") }
            }
        }
        return problems
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
        if filter.trails && !filter.restrictsPlaces { return 0.55 }
        return 1
    }

    /// Trail mode fades the marker, not the name. A 0.28 label on cream cannot be read.
    package static func labelOpacity(filter: AtlasFilter) -> Double {
        1
    }

    private static func parse(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func expectedSource(_ identifier: String) -> String {
        if identifier.hasPrefix("land-") { return "pack-land" }
        if identifier == "trails" || identifier == "trails-casing" { return "pack-trails" }
        return "pack"
    }

    private static func zoom(_ source: Any?) -> Int? {
        guard let source = source as? [String: Any] else { return nil }
        if let value = source["maxzoom"] as? Int { return value }
        if let value = source["maxzoom"] as? Double { return Int(value) }
        if let value = source["maxzoom"] as? NSNumber { return value.intValue }
        return nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private static func packIsVector(_ root: [String: Any]) -> Bool {
        guard let sources = root["sources"] as? [String: Any] else { return false }
        for name in ["pack", "pack-land", "pack-trails"] {
            guard let source = sources[name] as? [String: Any],
                  source["type"] as? String == "vector",
                  let url = source["url"] as? String,
                  url.hasPrefix("pmtiles://")
            else { return false }
        }
        return true
    }

    private static func rootObject(
        packURL: String?,
        glyphsURL: String,
        online: Bool,
        hillshadeURL: String?,
        contourURL: String?,
        landURL: String?
    ) -> [String: Any] {
        let contract = RenderContract.load()
        var sources: [String: Any] = [
            "pack": vectorSource(packURL, contract.placeMaxZoom),
            "pack-land": vectorSource(landURL ?? packURL, contract.landMaxZoom),
            "pack-trails": vectorSource(packURL, contract.trailMaxZoom),
        ]
        let hillshade = hillshadeURL?.hasPrefix("pmtiles://") == true ? hillshadeURL : nil
        let contours = contourURL?.hasPrefix("pmtiles://") == true ? contourURL : nil
        if let hillshade {
            sources["hillshade"] = [
                "type": "raster",
                "url": hillshade,
                "tileSize": 256,
                "maxzoom": contract.hillshadeMaxZoom,
            ]
        }
        if let contours {
            sources["contours"] = [
                "type": "vector",
                "url": contours,
                "maxzoom": contract.terrainMaxZoom,
            ]
        }
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
        if hillshade != nil {
            layers.append([
                "id": "hillshade",
                "type": "raster",
                "source": "hillshade",
                "paint": [
                    "raster-opacity": 1,
                    "raster-fade-duration": 0,
                    "raster-contrast": 0.45,
                    "raster-brightness-min": 0.08,
                    "raster-brightness-max": 1,
                ],
            ])
        }
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
            "source": "pack-land",
            "source-layer": "land",
            "filter": ["==", ["get", "kind"], "private_mapped"],
            "paint": ["line-color": "#4A4036", "line-width": 1.1],
        ])
        if contours != nil {
            layers.append([
                "id": "contours-casing",
                "type": "line",
                "source": "contours",
                "source-layer": "contours",
                "paint": [
                    "line-color": "#FFFFFF",
                    "line-width": ["interpolate", ["linear"], ["zoom"], 12, 2.4, 16, 5.2],
                    "line-opacity": 0.95,
                ],
            ])
            layers.append([
                "id": "contours-intermediate",
                "type": "line",
                "source": "contours",
                "source-layer": "contours",
                "filter": ["!=", ["get", "index"], 1],
                "paint": [
                    "line-color": "#5C4E3E",
                    "line-width": ["interpolate", ["linear"], ["zoom"], 12, 0.8, 16, 1.6],
                    "line-opacity": 0.95,
                ],
            ])
            layers.append([
                "id": "contours-index",
                "type": "line",
                "source": "contours",
                "source-layer": "contours",
                "filter": ["==", ["get", "index"], 1],
                "paint": [
                    "line-color": "#1C1915",
                    "line-width": ["interpolate", ["linear"], ["zoom"], 12, 1.8, 16, 3.2],
                    "line-opacity": 1,
                ],
            ])
            layers.append([
                "id": "contour-labels",
                "type": "symbol",
                "source": "contours",
                "source-layer": "contours",
                "filter": ["==", ["get", "index"], 1],
                "layout": [
                    "text-field": ["concat", ["to-string", ["get", "elev"]], " ft"],
                    "text-font": ["NotoSansRegular"],
                    "text-size": ["interpolate", ["linear"], ["zoom"], 12, 12, 16, 16],
                    "symbol-placement": "line",
                    "text-optional": true,
                    "text-max-angle": 30,
                    "text-padding": 8,
                ],
                "paint": [
                    "text-color": "#1C1915",
                    "text-halo-color": "#FFFFFF",
                    "text-halo-width": 2.2,
                ],
            ])
        }
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
            "source": "pack-trails",
            "source-layer": "trails",
            "paint": [
                "line-color": "#F4EFE4",
                "line-width": ["interpolate", ["linear"], ["zoom"], 10, 3, 16, 7],
            ],
        ])
        layers.append([
            "id": "trails",
            "type": "line",
            "source": "pack-trails",
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

    private static func vectorSource(_ packURL: String?, _ maxZoom: Int) -> [String: Any] {
        if let packURL, packURL.hasPrefix("pmtiles://") {
            return ["type": "vector", "url": packURL, "maxzoom": maxZoom]
        }
        return [
            "type": "geojson",
            "data": ["type": "FeatureCollection", "features": []],
            "maxzoom": maxZoom,
        ]
    }

    private static func landLayer(_ identifier: String, _ kind: String, _ color: String) -> [String: Any] {
        [
            "id": identifier,
            "type": "fill",
            "source": "pack-land",
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
            symbol("places-worship", "worship", filter: ["all", ["==", ["get", "category"], "worship"], ["==", ["get", "catholic"], 0]], overlap: false, sort: 6, iconSize: 0.78, anchors: ["top", "bottom", "left", "right"]),
            symbol("places-shrine", "shrine", filter: named(shrine), overlap: false, sort: 5, iconSize: 0.78, anchors: ["top", "bottom", "left", "right"]),
            symbol("places-viewpoint", "viewpoint", filter: named(viewpoint), overlap: false, sort: 8, iconSize: 0.78, anchors: ["top", "bottom", "left", "right"]),
            symbol("places-museum", "museum", filter: named(museum), overlap: false, sort: 8, iconSize: 0.78, anchors: ["top", "bottom", "left", "right"]),
            symbol("places-parking", "parking", filter: named(parking), overlap: false, sort: 8, iconSize: 0.78, anchors: ["top", "bottom", "left", "right"]),
            symbol("places-water", "water", filter: named(water), overlap: false, sort: 8, iconSize: 0.78, anchors: ["top", "bottom", "left", "right"]),
            symbol("places-trailhead", "trailhead", filter: named(trailhead), overlap: false, sort: 8, iconSize: 0.78, anchors: ["top", "bottom", "left", "right"]),
            symbol("places-landmark", "landmark", filter: landmark(excluding: special), overlap: false, sort: 12, iconSize: 0.78, anchors: ["top", "bottom", "left", "right"]),
            symbol("places-chapel", "chapel", filter: named(chapel), overlap: false, sort: 2, iconSize: 0.92, anchors: ["bottom", "right", "left", "top"]),
            symbol("places-catholic", "catholic", filter: ["all", ["==", ["get", "category"], "worship"], ["==", ["get", "catholic"], 1]], overlap: true, sort: 1, iconSize: 1.0, anchors: ["top", "left", "right", "bottom"]),
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

    /// Hide “Untitled …” and “Unnamed …” so they do not cover a real name.
    private static var placeLabel: [Any] {
        [
            "case",
            [
                "any",
                ["in", "untitled", ["downcase", ["get", "name"]]],
                ["in", "unnamed", ["downcase", ["get", "name"]]],
            ],
            "",
            ["get", "name"],
        ]
    }

    private static func symbol(
        _ identifier: String,
        _ icon: String,
        filter: [Any],
        overlap: Bool,
        sort: Double,
        iconSize: Double,
        anchors: [String]
    ) -> [String: Any] {
        [
            "id": identifier,
            "type": "symbol",
            "source": "pack",
            "source-layer": "places",
            "filter": filter,
            "layout": [
                "icon-image": icon,
                "icon-size": iconSize,
                "icon-allow-overlap": overlap,
                "icon-ignore-placement": false,
                "icon-padding": 6,
                "symbol-sort-key": sort,
                "symbol-z-order": "source",
                "text-field": placeLabel,
                "text-font": ["NotoSansRegular"],
                "text-size": identifier == "places-catholic" ? 13 : 12,
                "text-variable-anchor": anchors,
                "text-radial-offset": 1.7,
                "text-justify": "auto",
                "text-allow-overlap": false,
                "text-optional": true,
                "text-padding": 10,
                "text-max-width": 10,
            ],
            "paint": [
                "text-color": "#1C1915",
                "text-halo-color": "#FFFFFF",
                "text-halo-width": 2.0,
            ],
        ]
    }
}
