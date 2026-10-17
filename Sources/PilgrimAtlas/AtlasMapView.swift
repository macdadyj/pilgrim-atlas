#if canImport(UIKit)
import CoreLocation
import MapLibre
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif
import SwiftUI
import UIKit

struct AtlasMapView: UIViewRepresentable {
    @Environment(AtlasModel.self) private var model
    /// Search row, optional active-filter icons, and one full pin.
    var topInset: CGFloat = 132
    var places: [PlaceRecord]
    /// Sheet height from the bottom of the screen. The logo and info button sit one gap above it.
    var bottomObstruction: CGFloat
    /// Home-indicator inset. The full-bleed map does not keep it, and MapLibre still subtracts it.
    var bottomSafeArea: CGFloat
    var onSelect: (LonLat, [PlaceRecord]) -> Void
    /// Logo and info button, just above the card. The caption and location control sit above this band.
    static let ornamentGap: CGFloat = 16
    /// Tall enough for the info button. The wordmark is shorter.
    static let ornamentBand: CGFloat = 44
    static let ornamentRowGap: CGFloat = 8

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: PackStyle.fileURL(online: model.onlineTiles, places: model.places))
        map.delegate = context.coordinator
        let displayScale = map.traitCollection.displayScale
        map.contentScaleFactor = displayScale > 1 ? displayScale : 2
        map.shouldRequestAuthorizationToUseLocationServices = !model.debugPlaza
        map.showsUserLocation = !model.debugPlaza && model.launch.simulatedUser == nil
        context.coordinator.syncSimulatedUser(on: map, at: model.launch.simulatedUser)
        map.setCenter(
            CLLocationCoordinate2D(latitude: model.mapCenter.lat, longitude: model.mapCenter.lon),
            zoomLevel: model.cameraZoom,
            animated: false
        )
        applyChrome(on: map)
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
        context.coordinator.onlyRole = model.onlyRole
        context.coordinator.selectedID = model.selectedPlace?.id
        context.coordinator.installBasemapReadout(on: map)
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let displayScale = map.traitCollection.displayScale
        map.contentScaleFactor = displayScale > 1 ? displayScale : 2
        context.coordinator.onSelect = onSelect
        context.coordinator.onCamera = { model.noteCamera($0) }
        context.coordinator.onViewport = { southWest, northEast, zoom in
            model.noteViewport(southWest: southWest, northEast: northEast, zoom: zoom)
        }
        context.coordinator.places = places
        context.coordinator.showLand = model.showLand
        context.coordinator.showTrails = model.showTrails
        context.coordinator.showPlaces = model.showPlaces
        context.coordinator.showParcels = model.showParcels
        context.coordinator.showTerrain = model.showTerrain
        context.coordinator.searchReveal = model.searchReveal
        context.coordinator.filter = model.filter
        context.coordinator.onlyRole = model.onlyRole
        context.coordinator.selectedID = model.selectedPlace?.id
        map.shouldRequestAuthorizationToUseLocationServices = !model.debugPlaza
        map.showsUserLocation = !model.debugPlaza && model.launch.simulatedUser == nil
        context.coordinator.syncSimulatedUser(on: map, at: model.launch.simulatedUser)
        applyChrome(on: map)
        if context.coordinator.lastOnline != model.onlineTiles {
            context.coordinator.lastOnline = model.onlineTiles
            context.coordinator.lastPlaceIDs = nil
            map.styleURL = PackStyle.fileURL(online: model.onlineTiles, places: model.places)
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
        context.coordinator.syncPlaceSources(on: map)
        PackStyle.applyVisibility(
            on: map,
            land: model.showLand,
            places: model.showPlaces,
            trails: model.showTrails && (model.filter.showsTrails || model.searchReveal),
            parcels: model.showParcels,
            terrain: model.showTerrain,
            reveal: model.searchReveal,
            filter: model.filter,
            onlyRole: model.onlyRole
        )
        context.coordinator.publishPinCount(on: map)
        context.coordinator.publishBasemap(on: map)
        PackStyle.syncSelectedPin(on: map, places: model.places, selectedID: model.selectedPlace?.id)
    }

    private func applyChrome(on map: MLNMapView) {
        map.contentInset = UIEdgeInsets(top: topInset, left: 8, bottom: bottomObstruction, right: 8)
        let margin = CGPoint(x: 8, y: Self.ornamentGap + bottomSafeArea)
        map.logoViewPosition = .bottomLeft
        map.attributionButtonPosition = .bottomRight
        map.logoViewMargins = margin
        map.attributionButtonMargins = margin
    }

    final class Coordinator: NSObject, @MainActor MLNMapViewDelegate {
        var onSelect: (LonLat, [PlaceRecord]) -> Void
        var onCamera: (LonLat) -> Void = { _ in }
        var onViewport: (LonLat, LonLat, Double) -> Void = { _, _, _ in }
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
        var onlyRole: String?
        var selectedID: Int?
        var onPackLayersMissing: ([String]) -> Void = { _ in }
        var lastPlaceIDs: [Int]?
        private var userAnnotation: MLNPointAnnotation?
        private var lastPinCountTime = Date.distantPast
        private var streetReadout: UILabel?
        private var labelReadout: UILabel?

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
        func syncSimulatedUser(on map: MLNMapView, at point: LonLat?) {
            guard let point else {
                if let userAnnotation {
                    map.removeAnnotation(userAnnotation)
                    self.userAnnotation = nil
                }
                return
            }
            let coordinate = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
            if let userAnnotation {
                userAnnotation.coordinate = coordinate
                return
            }
            let pin = MLNPointAnnotation()
            pin.coordinate = coordinate
            pin.title = "Simulated location"
            userAnnotation = pin
            map.addAnnotation(pin)
        }

        @MainActor
        func syncPlaceSources(on map: MLNMapView) {
            guard map.style != nil else { return }
            let signature = places.map(\.id)
            guard signature != lastPlaceIDs else { return }
            lastPlaceIDs = signature
            PackStyle.syncPlaceSources(on: map, places: places)
        }

        @MainActor
        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.centerCoordinate
            onCamera(LonLat(lon: center.longitude, lat: center.latitude))
            let bounds = mapView.visibleCoordinateBounds
            onViewport(
                LonLat(lon: bounds.sw.longitude, lat: bounds.sw.latitude),
                LonLat(lon: bounds.ne.longitude, lat: bounds.ne.latitude),
                mapView.zoomLevel
            )
            publishPinCount(on: mapView)
        }

        /// Symbols are placed after the camera settles. Sampling only then left the count at 0.
        @MainActor
        func mapViewDidFinishRenderingFrame(_ mapView: MLNMapView, fullyRendered: Bool) {
            let now = Date()
            guard fullyRendered || now.timeIntervalSince(lastPinCountTime) > 0.25 else { return }
            lastPinCountTime = now
            publishPinCount(on: mapView)
            publishBasemap(on: mapView)
        }

        @MainActor
        func installBasemapReadout(on map: MLNMapView) {
            if streetReadout == nil {
                streetReadout = basemapReadout("basemap-streets")
                labelReadout = basemapReadout("basemap-labels")
            }
            if let streetReadout, streetReadout.superview !== map {
                map.addSubview(streetReadout)
            }
            if let labelReadout, labelReadout.superview !== map {
                map.addSubview(labelReadout)
            }
        }

        private func basemapReadout(_ identifier: String) -> UILabel {
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
            label.isAccessibilityElement = true
            label.accessibilityIdentifier = identifier
            label.accessibilityLabel = "0"
            label.text = "0"
            label.textColor = .clear
            label.isUserInteractionEnabled = false
            return label
        }

        @MainActor
        func publishBasemap(on map: MLNMapView) {
            installBasemapReadout(on: map)
            let streets = map.visibleFeatures(
                in: map.bounds,
                styleLayerIdentifiers: ["ofm-roads", "ofm-roads-casing"],
                predicate: nil
            ).count
            let labels = map.visibleFeatures(
                in: map.bounds,
                styleLayerIdentifiers: ["ofm-road-labels", "ofm-place-labels"],
                predicate: nil
            ).count
            streetReadout?.accessibilityLabel = "\(streets)"
            streetReadout?.text = "\(streets)"
            labelReadout?.accessibilityLabel = "\(labels)"
            labelReadout?.text = "\(labels)"
        }

        @MainActor
        func publishPinCount(on map: MLNMapView) {
            let visible = PackStyleDocument.placeLayerIDs.filter { identifier in
                PackStyleDocument.showsPlaceLayer(identifier, filter: filter, onlyRole: onlyRole)
            }
            let identifiers = Set(visible)
            let inView = map.visibleFeatures(
                in: map.bounds,
                styleLayerIdentifiers: identifiers,
                predicate: nil
            )
            let padded = Self.visibleMapRect(map)
            let atCenter = map.visibleFeatures(
                at: CGPoint(x: padded.midX, y: padded.midY),
                styleLayerIdentifiers: identifiers,
                predicate: nil
            )
            let count = max(inView.count, atCenter.count)
            let text = "\(count)"
            guard map.accessibilityIdentifier != "place-pin-count" || map.accessibilityLabel != text else { return }
            map.accessibilityIdentifier = "place-pin-count"
            map.accessibilityLabel = text
        }

        private static func visibleMapRect(_ map: MLNMapView) -> CGRect {
            let rect = map.bounds.inset(by: map.contentInset)
            if rect.width < 20 || rect.height < 20 { return map.bounds }
            return rect
        }

        @MainActor
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            PackStyle.installMarkers(on: style)
            let present = Set(style.layers.map(\.identifier))
            let packIsVector = style.source(withIdentifier: "pack") is MLNVectorTileSource
            let missing = PackStyleDocument.missingRenderedLayers(present, packIsVector: packIsVector)
            if !missing.isEmpty { onPackLayersMissing(missing) }
            lastPlaceIDs = nil
            syncPlaceSources(on: mapView)
            PackStyle.applyVisibility(
                on: mapView,
                land: showLand,
                places: showPlaces,
                trails: showTrails && (filter.showsTrails || searchReveal),
                parcels: showParcels,
                terrain: showTerrain,
                reveal: searchReveal,
                filter: filter,
                onlyRole: onlyRole
            )
            publishPinCount(on: mapView)
            publishBasemap(on: mapView)
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

    static func fileURL(online: Bool, places: [PlaceRecord]) -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("pilgrim-atlas-style-\(online ? "online" : "offline").json")
        let json = PackStyleDocument.json(
            packURL: packURL(),
            glyphsURL: glyphsTemplate(),
            online: online,
            hillshadeURL: archiveURL("northern-new-mexico-hillshade"),
            contourURL: archiveURL("northern-new-mexico-contours"),
            landURL: archiveURL("northern-new-mexico-land"),
            places: places
        )
        try? json.data(using: .utf8)?.write(to: destination)
        return destination
    }

    @MainActor
    static func installMarkers(on style: MLNStyle) {
        for role in PinRole.allCases {
            style.setImage(PinArt.image(for: role), forName: role.rawValue)
            style.setImage(PinArt.image(for: role, selected: true), forName: role.rawValue + "-selected")
        }
        for mark in ChurchMark.allCases {
            style.setImage(PinArt.image(mark: mark, selected: false), forName: mark.imageName)
            style.setImage(PinArt.image(mark: mark, selected: true), forName: mark.selectedImageName)
        }
    }

    /// Replace each role source with the places that should draw. The layer has no filter.
    @MainActor
    static func syncPlaceSources(on map: MLNMapView, places: [PlaceRecord]) {
        guard let style = map.style else { return }
        installMarkers(on: style)
        let grouped = PackStyleDocument.placesGroupedByRole(places)
        for role in PinRole.allCases {
            guard let source = style.source(withIdentifier: PackStyleDocument.placeSourceID(role.rawValue)) as? MLNShapeSource else {
                continue
            }
            source.shape = pointCollection(grouped[role.rawValue] ?? [])
        }
    }

    @MainActor
    static func syncSelectedPin(on map: MLNMapView, places: [PlaceRecord], selectedID: Int?) {
        guard let source = map.style?.source(withIdentifier: "places-selected") as? MLNShapeSource else { return }
        guard let selectedID, let place = places.first(where: { $0.id == selectedID }) else {
            source.shape = MLNShapeCollectionFeature(shapes: [])
            return
        }
        let feature = MLNPointFeature()
        feature.coordinate = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
        let mark = ChurchMark.mark(for: place)
        feature.attributes = ["pin": mark?.selectedImageName ?? (MapFilter.pinRole(for: place).rawValue + "-selected")]
        source.shape = MLNShapeCollectionFeature(shapes: [feature])
    }

    @MainActor
    private static func pointCollection(_ places: [PlaceRecord]) -> MLNShape {
        let features: [MLNPointFeature] = places.map { place in
            let feature = MLNPointFeature()
            feature.coordinate = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
            feature.identifier = NSNumber(value: place.id)
            feature.attributes = [
                "name": place.name,
                "label": PlaceText.pinLabel(place.name),
                "role": MapFilter.pinRole(for: place).rawValue,
                "pin": ChurchMark.pinName(for: place),
                "category": place.category,
            ]
            return feature
        }
        let shapes: [MLNShape] = features
        return MLNShapeCollectionFeature(shapes: shapes)
    }

    @MainActor
    static func applyVisibility(
        on map: MLNMapView,
        land: Bool,
        places: Bool,
        trails: Bool,
        parcels: Bool,
        terrain: Bool,
        reveal: Bool,
        filter: AtlasFilter,
        onlyRole: String?
    ) {
        guard let style = map.style else { return }
        for layer in style.layers {
            let identifier = layer.identifier
            if let fill = layer as? MLNFillStyleLayer, let kind = landKind(identifier) {
                fill.isVisible = land
                fill.fillOpacity = landOpacityExpression(kind: kind, filter: filter)
            } else if identifier == "hillshade"
                || identifier == "contours-casing"
                || identifier == "contours-intermediate"
                || identifier == "contours-index"
                || identifier == "contour-labels"
            {
                layer.isVisible = terrain
            } else if identifier == "trails" || identifier == "trails-casing" {
                layer.isVisible = trails
            } else if identifier == "parcels" {
                layer.isVisible = parcels
            } else if PackStyleDocument.placeLayerIDs.contains(identifier) {
                let shown = reveal || PackStyleDocument.showsPlaceLayer(identifier, filter: filter, onlyRole: onlyRole)
                layer.isVisible = places && shown
                if let symbol = layer as? MLNSymbolStyleLayer {
                    let roleName = String(identifier.dropFirst("places-".count))
                    symbol.iconImageName = NSExpression(forKeyPath: "pin")
                    let isolate = onlyRole != nil || filter.catholic || filter.churches
                    let overlap = isolate || (PinRole(rawValue: roleName)?.allowsOverlap ?? false)
                    symbol.iconAllowsOverlap = NSExpression(forConstantValue: NSNumber(value: overlap))
                    symbol.iconIgnoresPlacement = NSExpression(forConstantValue: NSNumber(value: isolate))
                    let iconOpacity = reveal ? 1.0 : PackStyleDocument.placeOpacity(filter: filter)
                    let textOpacity = reveal ? 1.0 : PackStyleDocument.labelOpacity(filter: filter)
                    symbol.iconOpacity = iconOpacity < 1
                        ? NSExpression(forConstantValue: NSNumber(value: iconOpacity))
                        : nil
                    symbol.textOpacity = textOpacity < 1
                        ? NSExpression(forConstantValue: NSNumber(value: textOpacity))
                        : nil
                }
            } else if let roleName = PackStyleDocument.clusterRole(identifier) {
                let shown = reveal || PackStyleDocument.showsPlaceLayer("places-\(roleName)", filter: filter, onlyRole: onlyRole)
                layer.isVisible = places && shown
            } else if identifier == "places-selected" {
                layer.isVisible = places
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
        guard let pmtiles = PackResources.url(
            forResource: name,
            withExtension: "pmtiles",
            subdirectory: "Resources"
        ) else { return nil }
        return "pmtiles://file://\(pmtiles.path)"
    }

    /// MapLibre will not draw a pin until this font file loads. A flattened
    /// copy of `0-255.pbf` at the bundle root is not a font stack.
    private static func glyphsTemplate() -> String {
        let candidates = [
            "glyphs/NotoSansRegular",
            "Resources/glyphs/NotoSansRegular",
        ]
        for subdirectory in candidates {
            guard let file = PackResources.url(
                forResource: "0-255",
                withExtension: "pbf",
                subdirectory: subdirectory
            ) else { continue }
            let fontFolder = file.deletingLastPathComponent()
            guard fontFolder.lastPathComponent == "NotoSansRegular" else { continue }
            let glyphs = fontFolder.deletingLastPathComponent()
            return glyphs.absoluteString + "/{fontstack}/{range}.pbf"
        }
        return "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf"
    }
}

#endif
