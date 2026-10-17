#if canImport(UIKit)
import CoreLocation
import Foundation
import Observation
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

struct CameraFit: Equatable {
    var minLon: Double
    var minLat: Double
    var maxLon: Double
    var maxLat: Double
}

@MainActor
@Observable
package final class AtlasModel: NSObject, CLLocationManagerDelegate {
    var places: [PlaceRecord] = []
    private var packPlaces: [PlaceRecord] = []
    private var remotePlaces: [PlaceRecord] = []
    var remotePlaceCount = 0
    var geocodeHits: [SearchHit] = []
    var geocodeLoading = false
    private var churchTask: Task<Void, Never>?
    private var geocodeTask: Task<Void, Never>?
    var trails: [TrailRecord] = []
    var lands: [LandHit] = []
    var links: [LinkRecord] = []
    var meta: [String: String] = [:]
    var loadError: String?
    var acceptedDisclaimer = UserDefaults.standard.bool(forKey: "pilgrim.disclaimer.accepted")
    var userCoordinate: LonLat?
    var mapCenter = DebugPin.plaza
    package var summaryPoint = DebugPin.plaza
    package var cameraCenter = DebugPin.plaza
    package var selectedPlace: PlaceRecord?
    package var selectedTrail: TrailRecord?
    var summary: NearbySummary?
    var showLand = true
    var showTrails = true
    var showPlaces = true
    var showParcels = false
    /// Streets, water, parks, and labels. On from the first frame.
    var onlineTiles = true
    var showTerrain = false
    /// Neighborhood zoom. Close enough for street names, not a blurry overzoom of the hillshade.
    static let launchZoom = 14.0
    var searchReveal = false
    var filter = AtlasFilter.empty
    var focusFoodChip = false
    var pendingOnlineConfirm = false
    var cameraToken = 0
    var cameraZoom = launchZoom
    var fitBounds: CameraFit?
    var fitToken = 0
    var locationDenied = false
    var summaryPinned = false
    var disclaimerDetailsOpen = false
    var debugPickerPlaces: [PlaceRecord] = []
    package var debugTapPoint: LonLat?
    var selectedTab: AppTab = .map
    var showFilters = false
    var searchQuery = ""
    var onboardingPage = 0
    var onlyRole: String?
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
        if parsed.showDisclaimer || parsed.disclaimerDetailsOpen || parsed.showOnboarding {
            acceptedDisclaimer = false
            disclaimerDetailsOpen = parsed.disclaimerDetailsOpen
            if parsed.showDisclaimer || parsed.disclaimerDetailsOpen {
                onboardingPage = 2
            }
        } else if parsed.skipsDisclaimer {
            acceptedDisclaimer = true
        }
        if parsed.suppressesLocation {
            summaryPinned = true
            let origin = parsed.simulatedUser
                ?? parsed.center
                ?? (parsed.outsideCoverage ? DebugLaunch.outsideCoverageSample : DebugPin.plaza)
            mapCenter = origin
            summaryPoint = origin
            cameraCenter = origin
            if parsed.simulatedUser != nil {
                userCoordinate = origin
            }
        } else {
            let manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locator = manager
        }
        loadPack()
        filter = DebugLaunch.filter(from: parsed.filterTokens)
        focusFoodChip = parsed.focusFood
        onlyRole = parsed.onlyRole
        if parsed.showTerrain { showTerrain = true }
        if parsed.showFilters || parsed.focusFood { showFilters = true }
        if let tab = parsed.tab, let parsedTab = AppTab(rawValue: tab) {
            selectedTab = parsedTab
        }
        if parsed.showSettings { selectedTab = .settings }
        if let query = parsed.search {
            searchQuery = query
            selectedTab = .search
        }
        applyDebugLaunch()
        revealActivePlaceLayer()
        refreshSummary()
    }

    /// When a landmark layer is turned on, fit the real places of that role around the camera.
    func revealActivePlaceLayer() {
        if let onlyRole {
            frame(places: places.filter { MapFilter.pinRole(for: $0).rawValue == onlyRole })
            return
        }
        if filter.catholic {
            frame(places: places.filter { MapFilter.pinRole(for: $0) == .catholic })
            return
        }
        if filter.churches {
            frameChurches()
        }
    }

    func frameRole(_ roleName: String) {
        frame(places: places.filter { MapFilter.pinRole(for: $0).rawValue == roleName })
    }

    func frameChurches() {
        frame(places: places.filter { place in
            let role = MapFilter.pinRole(for: place)
            return role == .chapel || role == .worship || role == .shrine
        })
    }

    private func frame(places matching: [PlaceRecord]) {
        let shown = LayerFrame.nearest(matching, around: mapCenter)
        guard shown.count >= 2, let box = LayerFrame.box(for: shown) else { return }
        fitCamera(CameraFit(minLon: box.minLon, minLat: box.minLat, maxLon: box.maxLon, maxLat: box.maxLat))
        let mid = LonLat(lon: (box.minLon + box.maxLon) / 2, lat: (box.minLat + box.maxLat) / 2)
        summaryPoint = mid
        summaryPinned = true
    }

    var layerBadge: Int {
        var count = 0
        if showParcels { count += 1 }
        if !onlineTiles { count += 1 }
        if filter.hidePlacesWithoutHours { count += 1 }
        if showTerrain { count += 1 }
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

    /// Recenters on the nearest hit so a chip plus a common word does not fit the whole region.
    func revealSearch(_ query: String) {
        scheduleGeocode(query)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchReveal = false
            return
        }
        var points: [LonLat] = []
        for hit in search(trimmed) {
            if let point = coordinate(for: hit) {
                points.append(point)
            }
            if points.count == 24 { break }
        }
        guard let nearest = points.first else {
            searchReveal = false
            return
        }
        searchReveal = true
        summaryPinned = true
        let cluster = points.filter { Geometry.haversineMeters($0, nearest) <= 2_500 }
        if cluster.count <= 1 {
            summaryPoint = nearest
            focusCamera(on: nearest, zoom: 16)
            refreshSummary()
            return
        }
        var minLon = cluster[0].lon
        var minLat = cluster[0].lat
        var maxLon = cluster[0].lon
        var maxLat = cluster[0].lat
        for point in cluster.dropFirst() {
            minLon = min(minLon, point.lon)
            minLat = min(minLat, point.lat)
            maxLon = max(maxLon, point.lon)
            maxLat = max(maxLat, point.lat)
        }
        let mid = LonLat(lon: (minLon + maxLon) / 2, lat: (minLat + maxLat) / 2)
        let span = max(
            Geometry.haversineMeters(LonLat(lon: minLon, lat: mid.lat), LonLat(lon: maxLon, lat: mid.lat)),
            Geometry.haversineMeters(LonLat(lon: mid.lon, lat: minLat), LonLat(lon: mid.lon, lat: maxLat))
        )
        summaryPoint = span > 8_000 ? nearest : mid
        if span > 8_000 {
            focusCamera(on: nearest, zoom: 16)
        } else {
            fitCamera(CameraFit(minLon: minLon, minLat: minLat, maxLon: maxLon, maxLat: maxLat))
        }
        refreshSummary()
    }

    func endSearch() {
        searchReveal = false
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
            focusCamera(on: DebugPin.plaza, zoom: Self.launchZoom)
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
            focusCamera(on: userCoordinate, zoom: Self.launchZoom)
            refreshSummary()
        }
        locator.requestWhenInUseAuthorization()
        locator.startUpdatingLocation()
    }

    var viewIsOutsidePack: Bool {
        !PackCoverage.contains(cameraCenter)
    }

    func jumpToNearestMappedArea() {
        let point = PackCoverage.nearest(cameraCenter)
        summaryPoint = point
        summaryPinned = true
        focusCamera(on: point, zoom: 12)
        refreshSummary()
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
        selectedTab = .map
        summaryPoint = place.coordinate
        summaryPinned = true
        focusCamera(on: place.coordinate, zoom: 16)
        refreshSummary()
    }

    func openTrail(_ trail: TrailRecord) {
        selectedTrail = trail
        selectedPlace = nil
        selectedTab = .map
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

    /// Loads churches for the area on screen. The offline pack stays underneath.
    func noteViewport(southWest: LonLat, northEast: LonLat, zoom: Double) {
        cameraCenter = LonLat(
            lon: (southWest.lon + northEast.lon) / 2,
            lat: (southWest.lat + northEast.lat) / 2
        )
        churchTask?.cancel()
        let south = southWest.lat
        let west = southWest.lon
        let north = northEast.lat
        let east = northEast.lon
        churchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, let self else { return }
            let fetched = await OverpassLoader.shared.places(
                south: south,
                west: west,
                north: north,
                east: east,
                zoom: zoom
            )
            guard !Task.isCancelled else { return }
            self.absorbRemote(fetched)
        }
    }

    private func absorbRemote(_ fetched: [PlaceRecord]) {
        guard !fetched.isEmpty else { return }
        remotePlaces = PlaceMerge.combine(pack: remotePlaces, remote: fetched)
        remotePlaceCount = remotePlaces.count
        places = PlaceMerge.combine(pack: packPlaces, remote: remotePlaces)
    }

    private func scheduleGeocode(_ query: String) {
        geocodeTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            geocodeHits = []
            geocodeLoading = false
            return
        }
        geocodeLoading = true
        geocodeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, let self else { return }
            let hits = await CitySearch.search(trimmed)
            guard !Task.isCancelled else { return }
            self.geocodeHits = hits
            self.geocodeLoading = false
        }
    }

    var cameraMovedFromSummary: Bool {
        Geometry.haversineMeters(cameraCenter, summaryPoint) > 40
    }

    nonisolated package func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = LonLat(lon: location.coordinate.longitude, lat: location.coordinate.latitude)
        Task { @MainActor in
            guard !self.debugPlaza else { return }
            self.userCoordinate = coordinate
            if !self.didCenterOnUser && !self.summaryPinned {
                self.summaryPoint = coordinate
                self.focusCamera(on: coordinate, zoom: Self.launchZoom)
                self.didCenterOnUser = true
            }
            if !self.summaryPinned {
                self.summaryPoint = coordinate
            }
            self.refreshSummary()
        }
    }

    nonisolated package func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
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
        focusCamera(on: DebugPin.plaza, zoom: Self.launchZoom)
        refreshSummary()
    }

    private func applyDebugLaunch() {
        guard launch.suppressesLocation else { return }
        if launch.showDisclaimer || launch.disclaimerDetailsOpen { return }
        applyTapOrPicker()
        if let query = launch.search {
            revealSearch(query)
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
            debugPickerPlaces = PlaceText.dedupeByName(hits)
            debugTapPoint = point
            aim(at: point)
            return
        }
        if wantsPicker {
            let sample = DebugLaunch.placesPickerSample
            let sampleHits = DebugLaunch.placesWithinTap(at: sample, places: places)
            if !sampleHits.isEmpty {
                debugPickerPlaces = PlaceText.dedupeByName(sampleHits)
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

    private func coordinate(for hit: SearchHit) -> LonLat? {
        switch hit.kind {
        case .place:
            if let id = hit.placeId, let found = place(id: id) { return found.coordinate }
            if let lat = hit.lat, let lon = hit.lon { return LonLat(lon: lon, lat: lat) }
            return nil
        case .trail:
            if let id = hit.trailId, let found = trail(id: id), let box = found.geometry.bbox {
                return LonLat(lon: (box.minLon + box.maxLon) / 2, lat: (box.minLat + box.maxLat) / 2)
            }
            return nil
        case .town, .land:
            if let lat = hit.lat, let lon = hit.lon { return LonLat(lon: lon, lat: lat) }
            return nil
        case .note:
            return nil
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
            packPlaces = snapshot.places
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
