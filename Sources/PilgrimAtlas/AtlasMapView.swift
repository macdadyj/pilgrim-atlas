#if canImport(UIKit)
import CoreLocation
import MapLibre
import PilgrimAtlasCore
import SwiftUI
import UIKit

struct AtlasMapView: UIViewRepresentable {
    @Environment(AtlasModel.self) private var model
    var places: [PlaceRecord]
    var onSelect: (LonLat, [PlaceRecord]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: PackStyle.fileURL(online: model.onlineTiles))
        map.delegate = context.coordinator
        map.shouldRequestAuthorizationToUseLocationServices = !model.debugPlaza
        map.showsUserLocation = !model.debugPlaza
        map.setCenter(
            CLLocationCoordinate2D(latitude: model.mapCenter.lat, longitude: model.mapCenter.lon),
            zoomLevel: model.cameraZoom,
            animated: false
        )
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.numberOfTapsRequired = 1
        map.addGestureRecognizer(tap)
        context.coordinator.lastOnline = model.onlineTiles
        context.coordinator.lastCamera = model.cameraToken
        context.coordinator.lastFit = model.fitBounds == nil ? model.fitToken : -1
        context.coordinator.places = places
        context.coordinator.showLand = model.showLand
        context.coordinator.showTrails = model.showTrails
        context.coordinator.showPlaces = model.showPlaces
        context.coordinator.showParcels = model.showParcels
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.onCamera = { model.noteCamera($0) }
        context.coordinator.places = places
        context.coordinator.showLand = model.showLand
        context.coordinator.showTrails = model.showTrails
        context.coordinator.showPlaces = model.showPlaces
        context.coordinator.showParcels = model.showParcels
        map.shouldRequestAuthorizationToUseLocationServices = !model.debugPlaza
        map.showsUserLocation = !model.debugPlaza
        if context.coordinator.lastOnline != model.onlineTiles {
            context.coordinator.lastOnline = model.onlineTiles
            map.styleURL = PackStyle.fileURL(online: model.onlineTiles)
        }
        if context.coordinator.lastFit != model.fitToken, let fit = model.fitBounds {
            context.coordinator.lastFit = model.fitToken
            var minLon = fit.minLon
            var minLat = fit.minLat
            var maxLon = fit.maxLon
            var maxLat = fit.maxLat
            if maxLon - minLon < 0.004 {
                minLon -= 0.002
                maxLon += 0.002
            }
            if maxLat - minLat < 0.004 {
                minLat -= 0.002
                maxLat += 0.002
            }
            let bounds = MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
                ne: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon)
            )
            map.setVisibleCoordinateBounds(
                bounds,
                edgePadding: UIEdgeInsets(top: 96, left: 32, bottom: 240, right: 32),
                animated: true,
                completionHandler: nil
            )
        }
        if context.coordinator.lastCamera != model.cameraToken {
            context.coordinator.lastCamera = model.cameraToken
            map.setCenter(
                CLLocationCoordinate2D(latitude: model.mapCenter.lat, longitude: model.mapCenter.lon),
                zoomLevel: model.cameraZoom,
                animated: true
            )
        }
        PackStyle.applyVisibility(
            on: map,
            land: model.showLand,
            trails: model.showTrails,
            places: model.showPlaces,
            parcels: model.showParcels
        )
    }

    final class Coordinator: NSObject, @MainActor MLNMapViewDelegate {
        var onSelect: (LonLat, [PlaceRecord]) -> Void
        var onCamera: (LonLat) -> Void = { _ in }
        var places: [PlaceRecord] = []
        var lastOnline = false
        var lastCamera = 0
        var lastFit = 0
        var showLand = true
        var showTrails = true
        var showPlaces = true
        var showParcels = false

        init(onSelect: @escaping (LonLat, [PlaceRecord]) -> Void) {
            self.onSelect = onSelect
        }

        @MainActor
        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            var hits: [(CGFloat, PlaceRecord)] = []
            for place in places {
                let screen = map.convert(
                    CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon),
                    toPointTo: map
                )
                let distance = hypot(screen.x - point.x, screen.y - point.y)
                if distance <= 44 {
                    hits.append((distance, place))
                }
            }
            let ordered = hits.sorted { $0.0 < $1.0 }.map(\.1)
            onSelect(LonLat(lon: coordinate.longitude, lat: coordinate.latitude), ordered)
        }

        @MainActor
        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.centerCoordinate
            onCamera(LonLat(lon: center.longitude, lat: center.latitude))
        }

        @MainActor
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            PackStyle.installMarkers(on: style)
            PackStyle.applyVisibility(
                on: mapView,
                land: showLand,
                trails: showTrails,
                places: showPlaces,
                parcels: showParcels
            )
        }
    }
}

enum PackStyle {
    static let legend: [(name: String, hex: String)] = [
        ("Private on the surface map", "8C7B64"),
        ("National forest", "3E6B48"),
        ("BLM", "C4A35A"),
        ("National park", "2F5D50"),
        ("State trust", "C4652D"),
        ("Tribal land", "6E5A7D"),
        ("Albuquerque Open Space", "7D8F4E"),
    ]

    static func fileURL(online: Bool) -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("pilgrim-atlas-style-\(online ? "online" : "offline").json")
        let json = styleJSON(online: online)
        try? json.data(using: .utf8)?.write(to: destination)
        return destination
    }

    @MainActor
    static func installMarkers(on style: MLNStyle) {
        let markers = [("catholic", "marker-catholic"), ("worship", "marker-worship"), ("landmark", "marker-landmark")]
        for (name, file) in markers {
            guard let url = Bundle.module.url(forResource: file, withExtension: "png", subdirectory: "Resources"),
                  let image = UIImage(contentsOfFile: url.path)
            else { continue }
            style.setImage(image, forName: name)
        }
    }

    @MainActor
    static func applyVisibility(on map: MLNMapView, land: Bool, trails: Bool, places: Bool, parcels: Bool) {
        guard let style = map.style else { return }
        for layer in style.layers {
            let identifier = layer.identifier
            if identifier.hasPrefix("land-") {
                layer.isVisible = land
            } else if identifier == "trails" {
                layer.isVisible = trails
            } else if identifier.hasPrefix("places-") {
                layer.isVisible = places
            } else if identifier == "parcels" {
                layer.isVisible = parcels
            }
        }
    }

    private static func styleJSON(online: Bool) -> String {
        var sources = [packSource()]
        if online {
            sources.append(#""openmaptiles": {"type": "vector", "url": "https://tiles.openfreemap.org/planet"}"#)
        }
        var layers = [
            "{\"id\": \"background\", \"type\": \"background\", \"paint\": {\"background-color\": \"#EFE6D6\"}}"
        ]
        if online {
            layers.append(
                ##"{"id": "ofm-water", "type": "fill", "source": "openmaptiles", "source-layer": "water", "paint": {"fill-color": "#C5D5E4"}}"##
            )
        }
        layers.append(landLayer("land-tribal", "tribal", "#6E5A7D"))
        layers.append(landLayer("land-nps", "nps", "#2F5D50"))
        layers.append(landLayer("land-usfs", "usfs", "#3E6B48"))
        layers.append(landLayer("land-usfs-inholding", "usfs_inholding", "#8A8175"))
        layers.append(landLayer("land-usfs-other", "usfs_other", "#8A8175"))
        layers.append(landLayer("land-blm", "blm", "#C4A35A"))
        layers.append(landLayer("land-dod", "dod", "#6E4A4A"))
        layers.append(landLayer("land-federal", "federal_other", "#4F6D7A"))
        layers.append(landLayer("land-trust", "state_trust", "#C4652D"))
        layers.append(landLayer("land-state", "state_other", "#C49A6C"))
        layers.append(landLayer("land-abq-closed", "abq_closed", "#8C3A3A"))
        layers.append(landLayer("land-abq-open", "abq_open", "#7D8F4E"))
        layers.append(landLayer("land-local", "local_protected", "#7A8468"))
        layers.append(landLayer("land-private", "private_mapped", "#8C7B64", opacity: 0.78))
        layers.append(landLayer("land-undefined", "sma_undefined", "#8A8175", opacity: 0.55))
        layers.append(
            "{\"id\": \"land-private-line\", \"type\": \"line\", \"source\": \"pack\", \"source-layer\": \"land\", \"filter\": [\"==\", [\"get\", \"kind\"], \"private_mapped\"], \"paint\": {\"line-color\": \"#4A4036\", \"line-width\": 1.1}}"
        )
        if online {
            let roadClasses = #"["motorway", "trunk", "primary", "secondary", "tertiary", "minor", "service"]"#
            let roadFilter = #"["in", ["get", "class"], ["literal", \#(roadClasses)]]"#
            layers.append(
                ##"{"id": "ofm-roads-casing", "type": "line", "source": "openmaptiles", "source-layer": "transportation", "filter": \##(roadFilter), "paint": {"line-color": "#6E6254", "line-width": ["interpolate", ["linear"], ["zoom"], 11, 0.4, 14, 2.4, 16, 6]}}"##
            )
            layers.append(
                ##"{"id": "ofm-roads", "type": "line", "source": "openmaptiles", "source-layer": "transportation", "filter": \##(roadFilter), "paint": {"line-color": "#FBF7F0", "line-width": ["interpolate", ["linear"], ["zoom"], 11, 0.2, 14, 1.3, 16, 3.6]}}"##
            )
        }
        layers.append(
            "{\"id\": \"trails\", \"type\": \"line\", \"source\": \"pack\", \"source-layer\": \"trails\", \"paint\": {\"line-color\": \"#6B4F3A\", \"line-width\": 2.4}}"
        )
        layers.append(
            "{\"id\": \"parcels\", \"type\": \"line\", \"source\": \"pack\", \"source-layer\": \"parcels\", \"minzoom\": 13, \"paint\": {\"line-color\": \"#5C5346\", \"line-width\": 0.8}}"
        )
        layers.append(symbolLayer("places-catholic", "catholic", worship: true, catholic: true))
        layers.append(symbolLayer("places-worship", "worship", worship: true, catholic: false))
        layers.append(symbolLayer("places-landmark", "landmark", worship: false, catholic: false))
        layers.append(
            """
            {"id": "places-labels", "type": "symbol", "source": "pack", "source-layer": "places", "minzoom": 13, "filter": ["all", ["!=", ["get", "name"], "Unnamed place of worship"], ["!=", ["get", "name"], ""]], "layout": {"text-field": ["get", "name"], "text-font": ["NotoSansRegular"], "text-size": 12, "text-offset": [0, 1.15], "text-anchor": "top", "text-optional": true, "text-max-width": 10}, "paint": {"text-color": "#1C1915", "text-halo-color": "#F4EFE4", "text-halo-width": 1.4}}
            """
        )
        if online {
            layers.append(
                """
                {"id": "ofm-road-labels", "type": "symbol", "source": "openmaptiles", "source-layer": "transportation_name", "minzoom": 14, "layout": {"text-field": ["get", "name"], "text-font": ["NotoSansRegular"], "text-size": 11, "symbol-placement": "line", "text-optional": true}, "paint": {"text-color": "#2A241C", "text-halo-color": "#FBF7F0", "text-halo-width": 1.2}}
                """
            )
        }
        let glyphs = jsonString(glyphsTemplate())
        return """
        {"version": 8, "name": "Pilgrim Atlas", "glyphs": "\(glyphs)", "sources": {\(sources.joined(separator: ","))}, "layers": [\(layers.joined(separator: ","))]}
        """
    }

    private static func packSource() -> String {
        if let pmtiles = Bundle.module.url(forResource: "northern-new-mexico", withExtension: "pmtiles", subdirectory: "Resources") {
            let url = jsonString("pmtiles://file://\(pmtiles.path)")
            return #""pack": {"type": "vector", "url": "\#(url)"}"#
        }
        return #""pack": {"type": "geojson", "data": {"type": "FeatureCollection", "features": []}}"#
    }

    private static func glyphsTemplate() -> String {
        if let file = Bundle.module.url(
            forResource: "0-255",
            withExtension: "pbf",
            subdirectory: "Resources/glyphs/NotoSansRegular"
        ) {
            let folder = file.deletingLastPathComponent().deletingLastPathComponent()
            return folder.absoluteString + "/{fontstack}/{range}.pbf"
        }
        return "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf"
    }

    private static func jsonString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func landLayer(_ identifier: String, _ kind: String, _ color: String, opacity: Double = 0.5) -> String {
        """
        {"id": "\(identifier)", "type": "fill", "source": "pack", "source-layer": "land", "filter": ["==", ["get", "kind"], "\(kind)"], "paint": {"fill-color": "\(color)", "fill-opacity": \(opacity), "fill-outline-color": "\(color)"}}
        """
    }

    private static func symbolLayer(_ identifier: String, _ icon: String, worship: Bool, catholic: Bool) -> String {
        let filter: String
        if worship {
            filter = """
            ["all", ["==", ["get", "category"], "worship"], ["==", ["get", "catholic"], \(catholic ? 1 : 0)]]
            """
        } else {
            filter = """
            ["==", ["get", "category"], "landmark"]
            """
        }
        return """
        {"id": "\(identifier)", "type": "symbol", "source": "pack", "source-layer": "places", "filter": \(filter), "layout": {"icon-image": "\(icon)", "icon-size": 0.7, "icon-allow-overlap": true}}
        """
    }
}

#endif
