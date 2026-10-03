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
    var showTerrain = false
    var filter = AtlasFilter.empty
    var focusFoodChip = false
    var pendingOnlineConfirm = false
    var cameraToken = 0
    var cameraZoom = 15.0
    var fitBounds: CameraFit?
    var fitToken = 0
    var locationDenied = false
    var summaryPinned = false
    var disclaimerDetailsOpen = false
    var debugPickerPlaces: [PlaceRecord] = []
    var debugTapPoint: LonLat?
    let launch: DebugLaunch
    /// True when this launch must not touch location services.
    let debugPlaza: Bool
    private var locator: CLLocationManager?
    private var didCenterOnUser = false

    override init() {
        let parsed = DebugLaunch.parse(ProcessInfo.processInfo.arguments)
        launch = parsed
        debugPlaza = parsed.suppressesLocation
        super.init()
        if parsed.showDisclaimer || parsed.disclaimerDetailsOpen {
            acceptedDisclaimer = false
            disclaimerDetailsOpen = parsed.disclaimerDetailsOpen
        } else if parsed.skipsDisclaimer {
            acceptedDisclaimer = true
        }
        if parsed.suppressesLocation {
            summaryPinned = true
            mapCenter = DebugPin.plaza
            summaryPoint = DebugPin.plaza
            cameraCenter = DebugPin.plaza
        } else {
            let manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locator = manager
        }
        loadPack()
        filter = DebugLaunch.filter(from: parsed.filterTokens)
        showTerrain = parsed.showTerrain
        focusFoodChip = parsed.focusFood
        applyDebugLaunch()
        refreshSummary()
    }

    var layerBadge: Int {
        var count = 0
        if showParcels { count += 1 }
        if onlineTiles { count += 1 }
        if showTerrain { count += 1 }
        if filter.hidePlacesWithoutHours { count += 1 }
        return count
    }

    func resetFilters() {
        let hideHours = filter.hidePlacesWithoutHours
        filter = AtlasFilter.empty
        filter.hidePlacesWithoutHours = hideHours
    }

    func acceptDisclaimer() {
        acceptedDisclaimer = true
        UserDefaults.standard.set(true, forKey: "pilgrim.disclaimer.accepted")
        guard let locator else { return }
        locator.requestWhenInUseAuthorization()
        locator.startUpdatingLocation()
    }

    func resumeLocationIfAllowed() {
        guard let locator else { return }
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
            lands: lands,
            filter: filter
        )
    }

    func search(_ query: String) -> [SearchHit] {
        AtlasQuery.search(query, places: places, trails: trails, origin: summaryPoint, lands: lands, filter: filter)
    }

    func place(id: Int) -> PlaceRecord? {
        places.first { $0.id == id }
    }

    func trail(id: Int) -> TrailRecord? {
        trails.first { $0.id == id }
    }

    func recenter() {
        guard let locator else {
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

    private func applyDebugLaunch() {
        guard launch.suppressesLocation else { return }
        if launch.showDisclaimer || launch.disclaimerDetailsOpen { return }
        applyTapOrPicker()
        if let query = launch.search {
            moveCameraToSearch(query)
        }
        if let query = launch.openPlace {
            openResolved(query)
        }
    }

    private func applyTapOrPicker() {
        let wantsPicker = launch.showPlacesPicker
        let point = launch.tap ?? (wantsPicker ? DebugLaunch.placesPickerSample : nil)
        guard let point else { return }
        let hits = DebugLaunch.placesWithinTap(at: point, places: places)
        if hits.count > 1 || (wantsPicker && !hits.isEmpty) {
            debugPickerPlaces = hits
            debugTapPoint = point
            aim(at: point)
            return
        }
        if wantsPicker {
            let sample = DebugLaunch.placesPickerSample
            let sampleHits = DebugLaunch.placesWithinTap(at: sample, places: places)
            if !sampleHits.isEmpty {
                debugPickerPlaces = sampleHits
                debugTapPoint = sample
                aim(at: sample)
            }
            return
        }
        if hits.count == 1, let only = hits.first {
            openPlace(only)
            return
        }
        aim(at: point)
    }

    private func moveCameraToSearch(_ query: String) {
        let hits = search(query)
        for hit in hits {
            switch hit.kind {
            case .place:
                guard let id = hit.placeId, let found = place(id: id) else { continue }
                summaryPoint = found.coordinate
                summaryPinned = true
                focusCamera(on: found.coordinate, zoom: 16)
                refreshSummary()
                return
            case .trail:
                guard let id = hit.trailId, let found = trail(id: id) else { continue }
                guard let box = found.geometry.bbox else { return }
                summaryPoint = LonLat(
                    lon: (box.minLon + box.maxLon) / 2,
                    lat: (box.minLat + box.maxLat) / 2
                )
                summaryPinned = true
                fitCamera(
                    CameraFit(minLon: box.minLon, minLat: box.minLat, maxLon: box.maxLon, maxLat: box.maxLat)
                )
                refreshSummary()
                return
            case .town, .land:
                guard let lat = hit.lat, let lon = hit.lon else { continue }
                let point = LonLat(lon: lon, lat: lat)
                summaryPoint = point
                summaryPinned = true
                focusCamera(on: point, zoom: hit.kind == .town ? 13 : 11)
                refreshSummary()
                return
            case .note:
                continue
            }
        }
    }

    private func openResolved(_ query: String) {
        guard let target = DebugLaunch.resolve(query, places: places, trails: trails) else { return }
        switch target {
        case .place(let id):
            if let found = place(id: id) { openPlace(found) }
        case .trail(let id):
            if let found = trail(id: id) { openTrail(found) }
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
