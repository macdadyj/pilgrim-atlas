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
        let ornament = CGPoint(x: 8, y: 400)
        map.logoViewMargins = ornament
        map.attributionButtonMargins = ornament
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
        context.coordinator.showTerrain = model.showTerrain
        context.coordinator.searchReveal = model.searchReveal
        context.coordinator.filter = model.filter
        context.coordinator.selectedID = model.selectedPlace?.id
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
        context.coordinator.showTerrain = model.showTerrain
        context.coordinator.searchReveal = model.searchReveal
        context.coordinator.filter = model.filter
        context.coordinator.selectedID = model.selectedPlace?.id
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
        context.coordinator.onPackLayersMissing = { missing in
            model.loadError = "Pack map layers did not render: \(missing.joined(separator: ", "))."
        }
        PackStyle.applyVisibility(
            on: map,
            places: model.showPlaces,
            trails: model.showTrails && (model.filter.showsTrails || model.searchReveal),
            parcels: model.showParcels,
            terrain: model.showTerrain,
            reveal: model.searchReveal,
            filter: model.filter
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
        var showTerrain = true
        var searchReveal = false
        var filter = AtlasFilter.empty
        var selectedID: Int?
        var onPackLayersMissing: ([String]) -> Void = { _ in }

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
            let present = Set(style.layers.map(\.identifier))
            let packIsVector = style.source(withIdentifier: "pack") is MLNVectorTileSource
            let missing = PackStyleDocument.missingRenderedLayers(present, packIsVector: packIsVector)
            if !missing.isEmpty { onPackLayersMissing(missing) }
            PackStyle.applyVisibility(
                on: mapView,
                places: showPlaces,
                trails: showTrails && (filter.showsTrails || searchReveal),
                parcels: showParcels,
                terrain: showTerrain,
                reveal: searchReveal,
                filter: filter
            )
        }
    }
}

enum PackStyle {
    static let legend: [(name: String, hex: String)] = [
        ("Private on the surface map", "C4B49A"),
        ("National forest", "1F7A3A"),
        ("BLM", "C48A12"),
        ("National park", "1F6F8A"),
        ("State trust", "E06A1F"),
        ("Tribal land", "7A3E8C"),
        ("Albuquerque Open Space", "4F8A32"),
        ("Local protected area", "2F8F7A"),
        ("Defense", "8C3030"),
        ("Other federal", "3D5A73"),
        ("Forest inholding", "A89880"),
        ("Other forest", "6E8F72"),
        ("Other state", "C4A06A"),
        ("Open Space closed", "A33B3B"),
        ("Surface status unclear", "B7A99A"),
    ]
    static let landOpacity = PackStyleDocument.landOpacity

    static func fileURL(online: Bool) -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("pilgrim-atlas-style-\(online ? "online" : "offline").json")
        let json = PackStyleDocument.json(
            packURL: packURL(),
            glyphsURL: glyphsTemplate(),
            online: online,
            hillshadeURL: archiveURL("northern-new-mexico-hillshade"),
            contourURL: archiveURL("northern-new-mexico-contours")
        )
        try? json.data(using: .utf8)?.write(to: destination)
        return destination
    }

    @MainActor
    static func installMarkers(on style: MLNStyle) {
        for role in PinRole.allCases {
            style.setImage(PinArt.image(for: role), forName: role.rawValue)
        }
    }

    @MainActor
    static func applyVisibility(
        on map: MLNMapView,
        places: Bool,
        trails: Bool,
        parcels: Bool,
        terrain: Bool,
        reveal: Bool,
        filter: AtlasFilter
    ) {
        guard let style = map.style else { return }
        for layer in style.layers {
            let identifier = layer.identifier
            if let fill = layer as? MLNFillStyleLayer, let kind = landKind(identifier) {
                fill.fillOpacity = landOpacityExpression(kind: kind, filter: filter)
            } else if identifier == "hillshade" || identifier == "contours" {
                layer.isVisible = terrain
            } else if identifier == "trails" || identifier == "trails-casing" {
                layer.isVisible = trails
            } else if identifier == "parcels" {
                layer.isVisible = parcels
            } else if PackStyleDocument.placeLayerIDs.contains(identifier) {
                let shown = reveal || PackStyleDocument.showsPlaceLayer(identifier, filter: filter)
                layer.isVisible = places && shown
                if let symbol = layer as? MLNSymbolStyleLayer {
                    let opacity = reveal ? 1.0 : PackStyleDocument.placeOpacity(filter: filter)
                    if opacity < 1 {
                        let value = NSExpression(forConstantValue: NSNumber(value: opacity))
                        symbol.iconOpacity = value
                        symbol.textOpacity = value
                    } else {
                        symbol.iconOpacity = nil
                        symbol.textOpacity = nil
                    }
                }
                if identifier == "places-worship", let vector = layer as? MLNVectorStyleLayer {
                    if filter.churches && !filter.catholic {
                        vector.predicate = NSPredicate(
                            format: "category == 'worship' AND catholic == 0 AND name != %@",
                            "Unnamed place of worship"
                        )
                    } else {
                        vector.predicate = NSPredicate(format: "category == 'worship' AND catholic == 0")
                    }
                }
            }
        }
    }

    private static func landKind(_ identifier: String) -> String? {
        switch identifier {
        case "land-tribal": return "tribal"
        case "land-nps": return "nps"
        case "land-usfs": return "usfs"
        case "land-usfs-inholding": return "usfs_inholding"
        case "land-usfs-other": return "usfs_other"
        case "land-blm": return "blm"
        case "land-dod": return "dod"
        case "land-federal": return "federal_other"
        case "land-trust": return "state_trust"
        case "land-state": return "state_other"
        case "land-abq-closed": return "abq_closed"
        case "land-abq-open": return "abq_open"
        case "land-local": return "local_protected"
        case "land-private": return "private_mapped"
        case "land-undefined": return "sma_undefined"
        default: return nil
        }
    }

    private static func landOpacityExpression(kind: String, filter: AtlasFilter) -> NSExpression {
        if kind == "local_protected", filter.parks {
            return NSExpression(mglJSONObject: [
                "case",
                ["in", "park", ["downcase", ["coalesce", ["get", "name"], ""]]],
                NSNumber(value: landOpacity),
                NSNumber(value: 0.18),
            ])
        }
        let fading = filter.publicLand || filter.parks
        let shown = MapFilter.landShown(kind: kind, name: "", filter: filter)
        let opacity = fading ? (shown ? landOpacity : 0.18) : landOpacity
        return NSExpression(forConstantValue: NSNumber(value: opacity))
    }

    private static func packURL() -> String? {
        archiveURL("northern-new-mexico")
    }

    private static func archiveURL(_ name: String) -> String? {
        guard let pmtiles = Bundle.module.url(
            forResource: name,
            withExtension: "pmtiles",
            subdirectory: "Resources"
        ) else { return nil }
        return "pmtiles://file://\(pmtiles.path)"
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
}

#endif
