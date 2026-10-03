#if canImport(UIKit)
import CoreLocation
import MapLibre
import PilgrimAtlasCore
import UIKit

enum PlaceSymbols {
    private static let sourceID = "places-live"
    private static let selectionID = "selection-live"

    @MainActor
    static func install(on style: MLNStyle, places: [PlaceRecord], filter: AtlasFilter, selectedID: Int?) {
        for role in roles {
            style.setImage(PinArt.image(for: role), forName: role.rawValue)
        }
        let options: [MLNShapeSourceOption: Any] = [
            .clustered: true,
            .clusterRadius: 48,
            .maximumZoomLevelForClustering: 12,
        ]
        let source = MLNShapeSource(identifier: sourceID, shape: collection(places, filter: filter, selectedID: selectedID), options: options)
        let selection = MLNShapeSource(identifier: selectionID, shape: selectionShape(places, selectedID: selectedID), options: nil)
        style.addSource(source)
        style.addSource(selection)

        let ring = MLNCircleStyleLayer(identifier: "selection-ring", source: selection)
        ring.circleColor = NSExpression(forConstantValue: UIColor.clear)
        ring.circleStrokeColor = NSExpression(forConstantValue: UIColor(red: 0x8C / 255, green: 0x2F / 255, blue: 0x39 / 255, alpha: 1))
        ring.circleStrokeWidth = NSExpression(forConstantValue: 3)
        ring.circleRadius = NSExpression(forConstantValue: 26)
        style.addLayer(ring)

        let clusters = MLNCircleStyleLayer(identifier: "place-clusters", source: source)
        clusters.predicate = NSPredicate(format: "point_count != nil")
        clusters.circleColor = NSExpression(forConstantValue: UIColor(red: 0x8C / 255, green: 0x2F / 255, blue: 0x39 / 255, alpha: 1))
        clusters.circleStrokeColor = NSExpression(forConstantValue: UIColor(red: 0xF4 / 255, green: 0xEF / 255, blue: 0xE4 / 255, alpha: 1))
        clusters.circleStrokeWidth = NSExpression(forConstantValue: 2)
        clusters.circleRadius = NSExpression(forConstantValue: 16)
        style.addLayer(clusters)

        let count = MLNSymbolStyleLayer(identifier: "place-cluster-count", source: source)
        count.predicate = NSPredicate(format: "point_count != nil")
        count.text = NSExpression(format: "CAST(point_count, 'NSString')")
        count.textFontNames = NSExpression(forConstantValue: ["NotoSansRegular"])
        count.textFontSize = NSExpression(forConstantValue: 12)
        count.textColor = NSExpression(forConstantValue: UIColor(red: 0xF4 / 255, green: 0xEF / 255, blue: 0xE4 / 255, alpha: 1))
        style.addLayer(count)

        style.addLayer(symbolLayer(identifier: "places-other", source: source, priority: false))
        style.addLayer(symbolLayer(identifier: "places-priority", source: source, priority: true))
    }

    @MainActor
    static func update(on map: MLNMapView, places: [PlaceRecord], filter: AtlasFilter, selectedID: Int?) {
        guard let style = map.style,
              let source = style.source(withIdentifier: sourceID) as? MLNShapeSource,
              let selection = style.source(withIdentifier: selectionID) as? MLNShapeSource
        else { return }
        source.shape = collection(places, filter: filter, selectedID: selectedID)
        selection.shape = selectionShape(places, selectedID: selectedID)
    }

    private static let roles: [PinRole] = [
        .catholic, .chapel, .worship, .shrine, .viewpoint, .museum, .parking, .water, .trailhead, .landmark,
    ]

    private static func symbolLayer(identifier: String, source: MLNShapeSource, priority: Bool) -> MLNSymbolStyleLayer {
        let layer = MLNSymbolStyleLayer(identifier: identifier, source: source)
        if priority {
            layer.predicate = NSPredicate(format: "point_count == nil AND (role == 'catholic' OR role == 'chapel')")
            layer.iconAllowsOverlap = NSExpression(forConstantValue: true)
            layer.textOptional = NSExpression(forConstantValue: false)
        } else {
            layer.predicate = NSPredicate(format: "point_count == nil AND role != 'catholic' AND role != 'chapel'")
            layer.iconAllowsOverlap = NSExpression(forConstantValue: false)
            layer.textOptional = NSExpression(forConstantValue: true)
        }
        layer.iconImageName = NSExpression(forKeyPath: "icon")
        layer.iconScale = NSExpression(forConstantValue: 0.82)
        layer.iconPadding = NSExpression(forConstantValue: 2)
        layer.symbolSortKey = NSExpression(forKeyPath: "sort")
        layer.text = NSExpression(forKeyPath: "label")
        layer.textFontNames = NSExpression(forConstantValue: ["NotoSansRegular"])
        layer.textFontSize = NSExpression(forConstantValue: 12)
        layer.textOffset = NSExpression(forConstantValue: CGVector(dx: 0, dy: 1.2))
        layer.textAnchor = NSExpression(forConstantValue: "top")
        layer.textColor = NSExpression(forConstantValue: UIColor(red: 0x1C / 255, green: 0x19 / 255, blue: 0x15 / 255, alpha: 1))
        layer.textHaloColor = NSExpression(forConstantValue: UIColor(red: 0xF4 / 255, green: 0xEF / 255, blue: 0xE4 / 255, alpha: 1))
        layer.textHaloWidth = NSExpression(forConstantValue: 1.4)
        layer.maximumTextWidth = NSExpression(forConstantValue: 8)
        layer.iconOpacity = NSExpression(forKeyPath: "opacity")
        layer.textOpacity = NSExpression(forKeyPath: "opacity")
        return layer
    }

    private static func collection(_ places: [PlaceRecord], filter: AtlasFilter, selectedID: Int?) -> MLNShape {
        let features: [MLNPointFeature] = places.compactMap { place in
            let draw = MapFilter.placeDraw(place, filter: filter)
            if draw == .hide { return nil }
            let role = MapFilter.pinRole(for: place)
            let feature = MLNPointFeature()
            feature.identifier = NSNumber(value: place.id)
            feature.coordinate = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
            feature.attributes = [
                "icon": role.rawValue,
                "role": role.rawValue,
                "label": PlaceText.pinLabel(place.name),
                "sort": NSNumber(value: role.sortKey + (place.id == selectedID ? 20 : 0)),
                "opacity": NSNumber(value: draw == .fade ? 0.28 : 1),
            ]
            return feature
        }
        return MLNShapeCollection(shapes: features)
    }

    private static func selectionShape(_ places: [PlaceRecord], selectedID: Int?) -> MLNShape {
        guard let selectedID, let place = places.first(where: { $0.id == selectedID }) else {
            return MLNShapeCollection(shapes: [])
        }
        let feature = MLNPointFeature()
        feature.coordinate = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
        return feature
    }
}

#endif
