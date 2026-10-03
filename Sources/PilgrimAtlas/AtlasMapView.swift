#if canImport(UIKit)
import CoreLocation
import MapLibre
import PilgrimAtlasCore
import SwiftUI
import UIKit

struct AtlasMapView: UIViewRepresentable {
    @Environment(AtlasModel.self) private var model
    var onSelect: (LonLat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: PackStyle.fileURL(online: model.onlineTiles))
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.setCenter(
            CLLocationCoordinate2D(latitude: model.mapCenter.lat, longitude: model.mapCenter.lon),
            zoomLevel: 11,
            animated: false
        )
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.numberOfTapsRequired = 1
        map.addGestureRecognizer(tap)
        context.coordinator.lastOnline = model.onlineTiles
        context.coordinator.lastCamera = model.cameraToken
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.onSelect = onSelect
        if context.coordinator.lastOnline != model.onlineTiles {
            context.coordinator.lastOnline = model.onlineTiles
            map.styleURL = PackStyle.fileURL(online: model.onlineTiles)
        }
        if context.coordinator.lastCamera != model.cameraToken {
            context.coordinator.lastCamera = model.cameraToken
            map.setCenter(
                CLLocationCoordinate2D(latitude: model.mapCenter.lat, longitude: model.mapCenter.lon),
                zoomLevel: 13,
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

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var onSelect: (LonLat) -> Void
        var lastOnline = false
        var lastCamera = 0

        init(onSelect: @escaping (LonLat) -> Void) {
            self.onSelect = onSelect
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            onSelect(LonLat(lon: coordinate.longitude, lat: coordinate.latitude))
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            PackStyle.installMarkers(on: style)
        }
    }
}

enum PackStyle {
    private static let openFreeMap = URL(string: "https://tiles.openfreemap.org/styles/liberty")

    static func fileURL(online: Bool) -> URL {
        if online, let openFreeMap {
            return openFreeMap
        }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("pilgrim-atlas-style.json")
        let json = styleJSON()
        try? json.data(using: .utf8)?.write(to: destination)
        return destination
    }

    static func installMarkers(on style: MLNStyle) {
        let markers = [("catholic", "marker-catholic"), ("worship", "marker-worship"), ("landmark", "marker-landmark")]
        for (name, file) in markers {
            guard let url = Bundle.module.url(forResource: file, withExtension: "png", subdirectory: "Resources"),
                  let image = UIImage(contentsOfFile: url.path)
            else { continue }
            style.setImage(image, forName: name)
        }
    }

    static func applyVisibility(on map: MLNMapView, land: Bool, trails: Bool, places: Bool, parcels: Bool) {
        guard let style = map.style else { return }
        let landLayers = style.layers.filter { $0.identifier.hasPrefix("land-") }
        let trailLayers = style.layers.filter { $0.identifier == "trails" }
        let placeLayers = style.layers.filter { $0.identifier.hasPrefix("places-") }
        let parcelLayers = style.layers.filter { $0.identifier == "parcels" }
        for layer in landLayers { layer.isVisible = land }
        for layer in trailLayers { layer.isVisible = trails }
        for layer in placeLayers { layer.isVisible = places }
        for layer in parcelLayers { layer.isVisible = parcels }
    }

    private static func styleJSON() -> String {
        let source: String
        if let pmtiles = Bundle.module.url(forResource: "northern-new-mexico", withExtension: "pmtiles", subdirectory: "Resources") {
            let url = "pmtiles://file://\(pmtiles.path)"
            source = """
            "pack": {"type": "vector", "url": "\(url)"}
            """
        } else {
            source = """
            "pack": {"type": "geojson", "data": {"type": "FeatureCollection", "features": []}}
            """
        }
        return """
        {
          "version": 8,
          "name": "Pilgrim Atlas",
          "sources": {\(source)},
          "layers": [
            {"id": "background", "type": "background", "paint": {"background-color": "#EFE6D6"}},
            \(landLayer("land-tribal", "tribal", "#6E5A7D")),
            \(landLayer("land-nps", "nps", "#2F5D50")),
            \(landLayer("land-usfs", "usfs", "#3E6B48")),
            \(landLayer("land-usfs-inholding", "usfs_inholding", "#8A8175")),
            \(landLayer("land-usfs-other", "usfs_other", "#8A8175")),
            \(landLayer("land-blm", "blm", "#C4A35A")),
            \(landLayer("land-dod", "dod", "#6E4A4A")),
            \(landLayer("land-federal", "federal_other", "#4F6D7A")),
            \(landLayer("land-trust", "state_trust", "#C4652D")),
            \(landLayer("land-state", "state_other", "#C49A6C")),
            \(landLayer("land-abq-closed", "abq_closed", "#8C3A3A")),
            \(landLayer("land-abq-open", "abq_open", "#7D8F4E")),
            \(landLayer("land-local", "local_protected", "#7A8468")),
            \(landLayer("land-private", "private_mapped", "#D9D3C7")),
            \(landLayer("land-undefined", "sma_undefined", "#C8C2B8")),
            {"id": "trails", "type": "line", "source": "pack", "source-layer": "trails", "paint": {"line-color": "#6B4F3A", "line-width": 2}},
            {"id": "parcels", "type": "line", "source": "pack", "source-layer": "parcels", "minzoom": 13, "paint": {"line-color": "#5C5346", "line-width": 0.8}},
            \(symbolLayer("places-catholic", "catholic", worship: true, catholic: true)),
            \(symbolLayer("places-worship", "worship", worship: true, catholic: false)),
            \(symbolLayer("places-landmark", "landmark", worship: false, catholic: false))
          ]
        }
        """
    }

    private static func landLayer(_ identifier: String, _ kind: String, _ color: String) -> String {
        """
        {"id": "\(identifier)", "type": "fill", "source": "pack", "source-layer": "land", "filter": ["==", ["get", "kind"], "\(kind)"], "paint": {"fill-color": "\(color)", "fill-opacity": 0.38, "fill-outline-color": "\(color)"}}
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
        {"id": "\(identifier)", "type": "symbol", "source": "pack", "source-layer": "places", "filter": \(filter), "layout": {"icon-image": "\(icon)", "icon-size": 0.45, "icon-allow-overlap": true}}
        """
    }
}

#endif
