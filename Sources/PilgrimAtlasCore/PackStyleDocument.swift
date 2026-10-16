import Foundation

/// Offline MapLibre style. Land uses a detail archive through zoom 14.
/// Trails stay on the main pack and overzoom from zoom 12. The main pack's
/// zoom 14 tiles hold places (and Albuquerque parcels) only.
package enum PackStyleDocument {
    package static let landOpacity = 0.48
    /// Church pins cluster when the map is zoomed out. Other worship stays
    /// unclustered so a neighborhood frame still draws each pin.
    package static let clusteredRoles: Set<String> = ["catholic", "chapel", "shrine"]
    package static let streetLayerIDs = [
        "ofm-water",
        "ofm-parks",
        "ofm-roads-casing",
        "ofm-roads",
        "ofm-place-labels",
        "ofm-road-labels",
    ]
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
        landURL: String? = nil,
        places: [PlaceRecord]? = nil
    ) -> String {
        let root = rootObject(
            packURL: packURL,
            glyphsURL: glyphsURL,
            online: online,
            hillshadeURL: hillshadeURL,
            contourURL: contourURL,
            landURL: landURL,
            places: places
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
            if id.hasPrefix("places-") {
                let source = layer["source"] as? String ?? ""
                let role = String(id.dropFirst("places-".count))
                if source == placeSourceID(role) { continue }
                let sourceLayer = layer["source-layer"] as? String
                if source != "pack" || sourceLayer != "places" { missing.append(id) }
                continue
            }
            if layer["source"] as? String != expectedSource(id) {
                missing.append(id)
                continue
            }
            let sourceLayer = layer["source-layer"] as? String
            if id.hasPrefix("land-"), sourceLayer != "land" { missing.append(id) }
            if id == "trails" || id == "trails-casing", sourceLayer != "trails" { missing.append(id) }
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

    /// GeoJSON source that holds only this role. The layer draws every feature in it.
    package static func placeSourceID(_ role: String) -> String {
        "pack-places-\(role)"
    }

    /// One bucket per pin role. A layer with no filter draws its whole bucket.
    package static func placesGroupedByRole(_ places: [PlaceRecord]) -> [String: [PlaceRecord]] {
        var grouped: [String: [PlaceRecord]] = [:]
        for role in PinRole.allCases {
            grouped[role.rawValue] = []
        }
        for place in places {
            let role = MapFilter.pinRole(for: place).rawValue
            grouped[role, default: []].append(place)
        }
        return grouped
    }

    /// Trails-only fades every pin. Place chips hide the roles they do not include.
    /// Open now cannot drop a pin here: visitor hours are not stored on the tile.
    package static func showsPlaceLayer(_ identifier: String, filter: AtlasFilter, onlyRole: String? = nil) -> Bool {
        guard placeLayerIDs.contains(identifier) else { return false }
        if let onlyRole {
            return identifier == "places-\(onlyRole)"
        }
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
        landURL: String?,
        places: [PlaceRecord]?
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
        let drawnPlaces = places.map(AtlasQuery.mapPlaces)
        if let drawnPlaces {
            let grouped = placesGroupedByRole(drawnPlaces)
            for role in PinRole.allCases {
                var source: [String: Any] = [
                    "type": "geojson",
                    "data": placeFeatureCollection(grouped[role.rawValue] ?? []),
                ]
                if clusteredRoles.contains(role.rawValue) {
                    source["cluster"] = true
                    source["clusterRadius"] = 48
                    source["clusterMaxZoom"] = 13
                }
                sources[placeSourceID(role.rawValue)] = source
            }
            sources["places-selected"] = [
                "type": "geojson",
                "data": ["type": "FeatureCollection", "features": []],
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
                    "raster-opacity": 0.35,
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
        if online {
            layers.append(contentsOf: parkLayers())
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
                "filter": ["all", ["==", ["get", "index"], 1], [">", ["get", "elev"], 0]],
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
                    "text-halo-width": ["interpolate", ["linear"], ["zoom"], 12, 1.5, 16, 3.5],
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
        if online {
            layers.append(contentsOf: streetLabelLayers())
        }
        if places != nil {
            for role in clusteredRoles {
                layers.append(clusterCircle(role))
                layers.append(clusterCount(role))
            }
        }
        layers.append(contentsOf: placeLayers(geoJSON: places != nil))
        if places != nil {
            layers.append(selectedPinLayer())
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

    private static func parkLayers() -> [[String: Any]] {
        [
            [
                "id": "ofm-parks",
                "type": "fill",
                "source": "openmaptiles",
                "source-layer": "landuse",
                "filter": ["in", ["get", "class"], ["literal", ["park", "grass", "wood", "cemetery"]]],
                "paint": ["fill-color": "#C9D7B8", "fill-opacity": 0.9],
            ],
        ]
    }

    private static func streetLabelLayers() -> [[String: Any]] {
        [
            [
                "id": "ofm-place-labels",
                "type": "symbol",
                "source": "openmaptiles",
                "source-layer": "place",
                "minzoom": 8,
                "filter": ["in", ["get", "class"], ["literal", ["city", "town", "village", "suburb", "neighbourhood"]]],
                "layout": [
                    "text-field": ["get", "name"],
                    "text-font": ["NotoSansRegular"],
                    "text-size": ["interpolate", ["linear"], ["zoom"], 8, 12, 14, 16],
                    "text-optional": true,
                    "text-padding": 6,
                ],
                "paint": [
                    "text-color": "#1C1915",
                    "text-halo-color": "#FBF7F0",
                    "text-halo-width": 1.6,
                ],
            ],
            [
                "id": "ofm-road-labels",
                "type": "symbol",
                "source": "openmaptiles",
                "source-layer": "transportation_name",
                "minzoom": 12,
                "layout": [
                    "text-field": ["get", "name"],
                    "text-font": ["NotoSansRegular"],
                    "text-size": 12,
                    "symbol-placement": "line",
                    "text-optional": true,
                ],
                "paint": [
                    "text-color": "#2A241C",
                    "text-halo-color": "#FBF7F0",
                    "text-halo-width": 1.4,
                ],
            ],
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

    private static func placeFeatureCollection(_ places: [PlaceRecord]) -> [String: Any] {
        [
            "type": "FeatureCollection",
            "features": places.map { place -> [String: Any] in
                [
                    "type": "Feature",
                    "geometry": [
                        "type": "Point",
                        "coordinates": [place.lon, place.lat],
                    ],
                    "id": place.id,
                    "properties": [
                        "name": place.name,
                        "label": PlaceText.pinLabel(place.name),
                        "role": MapFilter.pinRole(for: place).rawValue,
                        "pin": ChurchMark.pinName(for: place),
                        "catholic": place.catholic ? "yes" : "no",
                        "category": place.category,
                    ],
                ]
            },
        ]
    }

    private static func placeLayers(geoJSON: Bool) -> [[String: Any]] {
        let roles: [(String, String, Bool, Double, Double, [String], Double, Double)] = [
            ("places-worship", "worship", false, 6, 0.78, ["top", "bottom", "left", "right"], 1.7, 10),
            ("places-shrine", "shrine", false, 5, 0.78, ["top", "bottom", "left", "right"], 1.7, 10),
            ("places-viewpoint", "viewpoint", false, 8, 0.78, ["top", "bottom", "left", "right"], 1.7, 10),
            ("places-museum", "museum", false, 8, 0.78, ["top", "bottom", "left", "right"], 1.7, 10),
            ("places-parking", "parking", false, 8, 0.78, ["top", "bottom", "left", "right"], 1.7, 10),
            ("places-water", "water", false, 8, 0.78, ["top", "bottom", "left", "right"], 1.7, 10),
            ("places-trailhead", "trailhead", false, 8, 0.78, ["top", "bottom", "left", "right"], 1.7, 10),
            ("places-landmark", "landmark", false, 12, 0.78, ["top", "bottom", "left", "right"], 1.7, 10),
            ("places-chapel", "chapel", false, 2, 0.92, ["bottom", "right", "left", "top"], 1.7, 10),
            ("places-catholic", "catholic", true, 1, 1.0, ["top", "left", "right"], 2.4, 7),
        ]
        return roles.map { identifier, role, overlap, sort, iconSize, anchors, radial, width in
            symbol(
                identifier,
                role,
                filter: ["==", ["get", "role"], role],
                overlap: overlap,
                sort: sort,
                iconSize: iconSize,
                anchors: anchors,
                geoJSON: geoJSON,
                radialOffset: radial,
                textMaxWidth: width
            )
        }
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
            [
                "case",
                ["!=", ["coalesce", ["get", "label"], ""], ""],
                ["get", "label"],
                ["get", "name"],
            ],
        ]
    }

    private static func symbol(
        _ identifier: String,
        _ icon: String,
        filter: [Any],
        overlap: Bool,
        sort: Double,
        iconSize: Double,
        anchors: [String],
        geoJSON: Bool,
        radialOffset: Double = 1.7,
        textMaxWidth: Double = 10
    ) -> [String: Any] {
        var layer: [String: Any] = [
            "id": identifier,
            "type": "symbol",
            "source": geoJSON ? placeSourceID(icon) : "pack",
            "layout": [
                "icon-image": ["coalesce", ["get", "pin"], icon],
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
                "text-radial-offset": radialOffset,
                "text-justify": "auto",
                "text-allow-overlap": false,
                "text-optional": true,
                "text-padding": 10,
                "text-max-width": textMaxWidth,
            ],
            "paint": [
                "text-color": "#1C1915",
                "text-halo-color": "#FFFFFF",
                "text-halo-width": 2.0,
            ],
        ]
        if geoJSON, clusteredRoles.contains(icon) {
            layer["filter"] = ["!", ["has", "point_count"]]
        } else if !geoJSON {
            layer["source-layer"] = "places"
            layer["filter"] = filter
        }
        return layer
    }

    /// `cluster-catholic` and `cluster-catholic-count` both belong to the catholic pins.
    package static func clusterRole(_ identifier: String) -> String? {
        guard identifier.hasPrefix("cluster-") else { return nil }
        var name = String(identifier.dropFirst("cluster-".count))
        if name.hasSuffix("-count") {
            name.removeLast("-count".count)
        }
        guard clusteredRoles.contains(name) else { return nil }
        return name
    }

    private static func clusterCircle(_ role: String) -> [String: Any] {
        [
            "id": "cluster-\(role)",
            "type": "circle",
            "source": placeSourceID(role),
            "filter": ["has", "point_count"],
            "paint": [
                "circle-color": "#6E1E2A",
                "circle-radius": ["step", ["get", "point_count"], 16, 8, 20, 20, 26],
                "circle-stroke-width": 3,
                "circle-stroke-color": "#C6A15B",
            ],
        ]
    }

    private static func clusterCount(_ role: String) -> [String: Any] {
        [
            "id": "cluster-\(role)-count",
            "type": "symbol",
            "source": placeSourceID(role),
            "filter": ["has", "point_count"],
            "layout": [
                "text-field": ["get", "point_count_abbreviated"],
                "text-font": ["NotoSansRegular"],
                "text-size": 12,
            ],
            "paint": [
                "text-color": "#F4EFE4",
            ],
        ]
    }

    private static func selectedPinLayer() -> [String: Any] {
        [
            "id": "places-selected",
            "type": "symbol",
            "source": "places-selected",
            "layout": [
                "icon-image": ["get", "pin"],
                "icon-size": 1.05,
                "icon-allow-overlap": true,
                "icon-ignore-placement": true,
            ],
        ]
    }
}
