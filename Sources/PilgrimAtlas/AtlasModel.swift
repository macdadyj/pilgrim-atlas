#if canImport(UIKit)
import CoreLocation
import Foundation
import Observation
import PilgrimAtlasCore

struct CameraFit: Equatable {
    var minLon: Double
    var minLat: Double
    var maxLon: Double
    var maxLat: Double
}

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
    var mapCenter = DebugPin.plaza
    var summaryPoint = DebugPin.plaza
    var cameraCenter = DebugPin.plaza
    var selectedPlace: PlaceRecord?
    var selectedTrail: TrailRecord?
    var summary: NearbySummary?
    var showLand = true
    var showTrails = true
    var showPlaces = true
    var showParcels = false
    var onlineTiles = false
    var pendingOnlineConfirm = false
    var cameraToken = 0
    var cameraZoom = 15.0
    var fitBounds: CameraFit?
    var fitToken = 0
    var locationDenied = false
    var summaryPinned = false
    let debugPlaza: Bool
    private let locator = CLLocationManager()
    private var didCenterOnUser = false

    override init() {
        debugPlaza = DebugPin.isEnabled(arguments: ProcessInfo.processInfo.arguments)
        super.init()
        locator.delegate = self
        locator.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        if debugPlaza {
            summaryPinned = true
            mapCenter = DebugPin.plaza
            summaryPoint = DebugPin.plaza
            cameraCenter = DebugPin.plaza
        }
        loadPack()
        refreshSummary()
    }

    func acceptDisclaimer() {
        acceptedDisclaimer = true
        UserDefaults.standard.set(true, forKey: "pilgrim.disclaimer.accepted")
        guard !debugPlaza else { return }
        locator.requestWhenInUseAuthorization()
        locator.startUpdatingLocation()
    }

    func resumeLocationIfAllowed() {
        guard !debugPlaza else { return }
        switch locator.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locator.startUpdatingLocation()
        case .denied, .restricted:
            locationDenied = true
            if userCoordinate == nil {
                holdOnPlaza()
            }
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func refreshSummary() {
        summary = AtlasQuery.nearby(
            lat: summaryPoint.lat,
            lon: summaryPoint.lon,
            places: places,
            trails: trails,
            lands: lands
        )
    }

    func search(_ query: String) -> [SearchHit] {
        AtlasQuery.search(query, places: places, trails: trails, origin: summaryPoint)
    }

    func place(id: Int) -> PlaceRecord? {
        places.first { $0.id == id }
    }

    func trail(id: Int) -> TrailRecord? {
        trails.first { $0.id == id }
    }

    func recenter() {
        if debugPlaza {
            summaryPoint = DebugPin.plaza
            summaryPinned = true
            focusCamera(on: DebugPin.plaza, zoom: 15)
            refreshSummary()
            return
        }
        let status = locator.authorizationStatus
        if status == .denied || status == .restricted {
            locationDenied = true
            holdOnPlaza()
            return
        }
        locationDenied = false
        if let userCoordinate {
            summaryPoint = userCoordinate
            summaryPinned = false
            focusCamera(on: userCoordinate, zoom: 15)
            refreshSummary()
        }
        locator.requestWhenInUseAuthorization()
        locator.startUpdatingLocation()
    }

    func focusCamera(on coordinate: LonLat, zoom: Double) {
        mapCenter = coordinate
        cameraCenter = coordinate
        cameraZoom = zoom
        fitBounds = nil
        cameraToken += 1
    }

    func fitCamera(_ fit: CameraFit) {
        fitBounds = fit
        fitToken += 1
        let mid = LonLat(lon: (fit.minLon + fit.maxLon) / 2, lat: (fit.minLat + fit.maxLat) / 2)
        mapCenter = mid
        cameraCenter = mid
    }

    func openPlace(_ place: PlaceRecord) {
        selectedPlace = place
        selectedTrail = nil
        summaryPoint = place.coordinate
        summaryPinned = true
        focusCamera(on: place.coordinate, zoom: 16)
        refreshSummary()
    }

    func openTrail(_ trail: TrailRecord) {
        selectedTrail = trail
        selectedPlace = nil
        guard let box = trail.geometry.bbox else { return }
        summaryPoint = LonLat(lon: (box.minLon + box.maxLon) / 2, lat: (box.minLat + box.maxLat) / 2)
        summaryPinned = true
        fitCamera(CameraFit(minLon: box.minLon, minLat: box.minLat, maxLon: box.maxLon, maxLat: box.maxLat))
        refreshSummary()
    }

    func aim(at coordinate: LonLat) {
        summaryPoint = coordinate
        summaryPinned = true
        refreshSummary()
    }

    func useCameraPoint() {
        summaryPoint = cameraCenter
        summaryPinned = true
        refreshSummary()
    }

    func noteCamera(_ coordinate: LonLat) {
        cameraCenter = coordinate
    }

    var cameraMovedFromSummary: Bool {
        Geometry.haversineMeters(cameraCenter, summaryPoint) > 40
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = LonLat(lon: location.coordinate.longitude, lat: location.coordinate.latitude)
        Task { @MainActor in
            guard !self.debugPlaza else { return }
            self.userCoordinate = coordinate
            if !self.didCenterOnUser && !self.summaryPinned {
                self.summaryPoint = coordinate
                self.focusCamera(on: coordinate, zoom: 15)
                self.didCenterOnUser = true
            }
            if !self.summaryPinned {
                self.summaryPoint = coordinate
            }
            self.refreshSummary()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard !self.debugPlaza else {
                self.locationDenied = false
                return
            }
            if status == .denied || status == .restricted {
                self.locationDenied = true
                if self.userCoordinate == nil {
                    self.holdOnPlaza()
                }
            } else {
                self.locationDenied = false
            }
        }
    }

    private func holdOnPlaza() {
        summaryPoint = DebugPin.plaza
        summaryPinned = true
        focusCamera(on: DebugPin.plaza, zoom: 15)
        refreshSummary()
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
