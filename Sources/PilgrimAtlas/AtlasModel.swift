#if canImport(UIKit)
import CoreLocation
import Foundation
import Observation
import PilgrimAtlasCore

@MainActor
@Observable
final class AtlasModel: NSObject, CLLocationManagerDelegate {
    var places: [PlaceRecord] = []
    var trails: [TrailRecord] = []
    var lands: [LandHit] = []
    var links: [LinkRecord] = []
    var meta: [String: String] = [:]
    var loadError: String?
    var acceptedDisclaimer = UserDefaults.standard.bool(forKey: "pilgrim.disclaimer.accepted")
    var userCoordinate: LonLat?
    var mapCenter = LonLat(lon: -105.9378, lat: 35.6870)
    var selectedPlace: PlaceRecord?
    var summary: NearbySummary?
    var showLand = true
    var showTrails = true
    var showPlaces = true
    var showParcels = true
    var onlineTiles = false
    var pendingOnlineConfirm = false
    var cameraToken = 0
    private let locator = CLLocationManager()
    private var centeredOnUser = false

    var focus: LonLat { userCoordinate ?? mapCenter }

    override init() {
        super.init()
        locator.delegate = self
        locator.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        loadPack()
        refreshSummary()
    }

    func acceptDisclaimer() {
        acceptedDisclaimer = true
        UserDefaults.standard.set(true, forKey: "pilgrim.disclaimer.accepted")
        locator.requestWhenInUseAuthorization()
        locator.startUpdatingLocation()
    }

    func refreshSummary() {
        summary = AtlasQuery.nearby(
            lat: focus.lat,
            lon: focus.lon,
            places: places,
            trails: trails,
            lands: lands
        )
    }

    func search(_ query: String) -> [SearchHit] {
        AtlasQuery.search(query, places: places, trails: trails)
    }

    func place(named name: String) -> PlaceRecord? {
        places.first { $0.name == name }
    }

    func requestLocation() {
        locator.requestWhenInUseAuthorization()
        locator.startUpdatingLocation()
    }

    func focusCamera(on coordinate: LonLat) {
        mapCenter = coordinate
        cameraToken += 1
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = LonLat(lon: location.coordinate.longitude, lat: location.coordinate.latitude)
        Task { @MainActor in
            self.userCoordinate = coordinate
            if !self.centeredOnUser {
                self.focusCamera(on: coordinate)
                self.centeredOnUser = true
            }
            self.refreshSummary()
        }
    }

    private func loadPack() {
        do {
            let snapshot = try PackDatabase.load()
            meta = snapshot.meta
            places = snapshot.places
            trails = snapshot.trails
            lands = snapshot.lands
            links = snapshot.links
        } catch {
            loadError = String(describing: error)
        }
    }
}

#endif
