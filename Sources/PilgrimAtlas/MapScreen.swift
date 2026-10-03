#if canImport(UIKit)
import SwiftUI
import UIKit
import PilgrimAtlasCore

struct PlaceHit: Identifiable {
    var place: PlaceRecord
    var meters: Int
    var id: Int { place.id }
}

struct TapMenu: Identifiable {
    let id = UUID()
    var choices: [PlaceHit]
}

struct MapScreen: View {
    @Environment(AtlasModel.self) private var model

    var body: some View {
        MapChrome(
            showSearch: model.launch.search != nil,
            showLayers: model.launch.showLayers,
            tapMenu: launchMenu
        )
    }

    private var launchMenu: TapMenu? {
        let choices = model.debugPickerPlaces
        guard !choices.isEmpty else { return nil }
        let point = model.debugTapPoint ?? choices[0].coordinate
        return TapMenu(choices: choices.map { place in
            PlaceHit(
                place: place,
                meters: Int(Geometry.haversineMeters(point, place.coordinate).rounded())
            )
        })
    }
}

private struct MapChrome: View {
    @Environment(AtlasModel.self) private var model
    @State private var showSearch: Bool
    @State private var showLicenses = false
    @State private var showLayers: Bool
    @State private var tapMenu: TapMenu?

    init(showSearch: Bool, showLayers: Bool, tapMenu: TapMenu?) {
        _showSearch = State(initialValue: showSearch)
        _showLayers = State(initialValue: showLayers)
        _tapMenu = State(initialValue: tapMenu)
    }

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .top) {
            AtlasMapView(places: model.places.filter { MapFilter.includeInLists($0, filter: model.filter) }) { coordinate, hits in
                if hits.count == 1, let place = hits.first {
                    model.openPlace(place)
                } else if hits.count > 1 {
                    model.aim(at: coordinate)
                    tapMenu = TapMenu(choices: hits.map { place in
                        PlaceHit(
                            place: place,
                            meters: Int(Geometry.haversineMeters(coordinate, place.coordinate).rounded())
                        )
                    })
                } else {
                    model.aim(at: coordinate)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                HStack {
                    Button { showSearch = true } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button { showLayers = true } label: {
                        Image(systemName: "square.3.layers.3d")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("More map options")
                    .overlay(alignment: .topTrailing) {
                        if model.layerBadge > 0 {
                            Text("\(model.layerBadge)")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.fieldCream)
                                .padding(4)
                                .background(Color.fieldInk, in: Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                    Button { showLicenses = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Licenses")
                    Button { model.recenter() } label: {
                        Image(systemName: "location")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Location")
                }
                .padding(.horizontal)
                FilterBar(scrollToFood: model.focusFoodChip)
                statusChip(statusLine)
                if model.locationDenied && !model.debugPlaza {
                    statusChip("Location is off. The map is staying on Santa Fe Plaza.")
                }
                if let loadError = model.loadError {
                    statusChip(loadError)
                }
                Spacer()
                HStack {
                    Text("© OpenStreetMap contributors")
                        .font(.caption2)
                        .foregroundStyle(Color.fieldInk)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.fieldCream.opacity(0.92), in: Capsule())
                    Spacer()
                }
                .padding(.horizontal, 12)
                NearbyPanel()
                    .frame(maxHeight: 320)
            }
            .padding(.top, 8)
        }
        .sheet(isPresented: $showSearch) {
            SearchSheet(initialQuery: model.launch.search ?? "")
                .presentationDetents(model.launch.search == nil ? [.large] : [.medium, .large])
        }
        .sheet(isPresented: $showLicenses) { LicensesView() }
        .sheet(isPresented: $showLayers) { LayersSheet() }
        .sheet(item: $model.selectedPlace) { place in
            DetailSheet(place: place)
        }
        .sheet(item: $model.selectedTrail) { trail in
            TrailSheet(trail: trail)
        }
        .sheet(item: $tapMenu) { menu in
            NavigationStack {
                List(menu.choices) { choice in
                    Button {
                        tapMenu = nil
                        model.openPlace(choice.place)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(choice.place.name)
                                .foregroundStyle(.primary)
                            Text("\(PlaceText.kindLabel(for: choice.place)) · \(PlaceText.distanceLabel(choice.meters))")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .navigationTitle("Places here")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .alert("Online tiles", isPresented: $model.pendingOnlineConfirm) {
            Button("Keep offline") { model.onlineTiles = false }
            Button("Use OpenFreeMap") { model.onlineTiles = true }
        } message: {
            Text("OpenFreeMap will see this phone's IP address and the map tiles it requests. That is an approximate location. Pilgrim Atlas still does not upload your GPS position, and it does not run a server.")
        }
        .onAppear { model.resumeLocationIfAllowed() }
        .onChange(of: model.filter) { _, _ in model.refreshSummary() }
    }

    private var statusLine: String {
        if model.filter.anyChip {
            var lines = [model.filter.summary]
            if model.filter.publicLand { lines.append(MapFilter.publicLandSubtitle) }
            if model.filter.openNow {
                let coverage = MapFilter.coverage(model.places)
                lines.append(coverage.line)
                if let none = coverage.noneOpenLine { lines.append(none) }
            }
            return lines.joined(separator: "\n")
        }
        if model.showTerrain { return MapFilter.terrainMissing }
        if model.onlineTiles { return "Streets on. Land and landmarks stay on." }
        return "Offline. Place names are in the pack."
    }

    private func statusChip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct FilterBar: View {
    @Environment(AtlasModel.self) private var model
    var scrollToFood: Bool

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("Catholic sites", on: model.filter.catholic) { model.filter.catholic.toggle() }
                        chip("Churches and shrines", on: model.filter.churches) { model.filter.churches.toggle() }
                        chip("Trails", on: model.filter.trails) { model.filter.trails.toggle() }
                        chip("Public land", on: model.filter.publicLand) { model.filter.publicLand.toggle() }
                        chip("Parks", on: model.filter.parks) { model.filter.parks.toggle() }
                        foodChip
                        chip("Open now", on: model.filter.openNow) { model.filter.openNow.toggle() }
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    if scrollToFood {
                        proxy.scrollTo("food", anchor: .center)
                    }
                }
            }
            if model.filter.anyChip {
                HStack(spacing: 8) {
                    Text(model.filter.summary)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Button("Reset") { model.resetFilters() }
                        .buttonStyle(.bordered)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
            }
        }
    }

    private var foodChip: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Food and rest")
                .font(.subheadline.weight(.semibold))
            Text(MapFilter.foodCount(model.places) == 0 ? MapFilter.foodSubtitle : "\(MapFilter.foodCount(model.places)) in the pack")
                .font(.caption2)
        }
        .foregroundStyle(Color.fieldBrown)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.fieldCream, in: Capsule())
        .overlay(Capsule().stroke(Color.fieldBrown, lineWidth: 1))
        .id("food")
        .accessibilityLabel("Food and rest, \(MapFilter.foodSubtitle)")
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(on ? Color.fieldCream : Color.fieldInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(on ? Color.fieldInk : Color.fieldCream, in: Capsule())
                .overlay(Capsule().stroke(Color.fieldInk, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct NearbyPanel: View {
    @Environment(AtlasModel.self) private var model

    var body: some View {
        ScrollView {
            card
        }
        .frame(maxHeight: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What you can do here")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(model.summary?.headline ?? Copy.text("unknown"))
                .font(.body)
                .foregroundStyle(Color.fieldBrown)
            Text(model.summary?.permissionLine ?? PlaceText.permissionLine)
                .font(.body)
                .foregroundStyle(.primary)
            if let summary = model.summary {
                ForEach(summary.landmarks) { row in
                    if let place = model.place(id: row.placeId) {
                        Button {
                            model.openPlace(place)
                        } label: {
                            landmarkLabel(row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !summary.landmarkGap.isEmpty {
                    Text(summary.landmarkGap)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                if let trail = summary.trails.first, let record = model.trail(id: trail.trailId) {
                    Button {
                        model.openTrail(record)
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trail.name)
                                    .foregroundStyle(.primary)
                                Text("Hiking trail")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.fieldBrown)
                            }
                            Spacer(minLength: 8)
                            Text(PlaceText.distanceLabel(trail.meters))
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !summary.trailGap.isEmpty {
                    Text(summary.trailGap)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                if summary.headline != summary.land {
                    DisclosureGroup("About this land") {
                        Text(summary.land)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(.top, 4)
                    }
                    .font(.body)
                    .foregroundStyle(.primary)
                }
                Text(summary.closures.joined(separator: " "))
                    .font(.subheadline)
                    .foregroundStyle(Color.fieldBrown)
            }
            if model.cameraMovedFromSummary {
                Button("Use this point") { model.useCameraPoint() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func landmarkLabel(_ row: ExploreRow) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .foregroundStyle(.primary)
                Text(row.category)
                    .font(.subheadline)
                    .foregroundStyle(Color.fieldBrown)
            }
            Spacer(minLength: 8)
            Text(PlaceText.distanceLabel(row.meters))
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

struct LayersSheet: View {
    @Environment(AtlasModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $model.showParcels) {
                        VStack(alignment: .leading, spacing: 2) {
                            labeledSwatch("5C5346", "Albuquerque lot lines")
                            Text("Albuquerque only. Not in Santa Fe.")
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                    Toggle("Online OpenFreeMap tiles", isOn: Binding(
                        get: { model.onlineTiles },
                        set: { newValue in
                            if newValue {
                                model.pendingOnlineConfirm = true
                            } else {
                                model.onlineTiles = false
                            }
                        }
                    ))
                    Toggle("Hide places with no hours", isOn: $model.filter.hidePlacesWithoutHours)
                    Toggle("Terrain", isOn: $model.showTerrain)
                    if model.showTerrain {
                        Text(MapFilter.terrainMissing)
                            .font(.body)
                            .foregroundStyle(Color.fieldBrown)
                    }
                }
                Section("Marker legend") {
                    ForEach(PinRole.allCases, id: \.rawValue) { role in
                        HStack(spacing: 12) {
                            Image(uiImage: PinArt.image(for: role))
                                .resizable()
                                .frame(width: 44, height: 44)
                            Text(role.legend)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                Section("Land colors") {
                    ForEach(PackStyle.legend, id: \.name) { item in
                        labeledSwatch(item.hex, item.name)
                    }
                    Text("Lot lines are City of Albuquerque parcels without owner names. They are not a survey and not permission to enter. Santa Fe County parcels are not in this pack.")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            .navigationTitle("More map options")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func labeledSwatch(_ hex: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.fieldCream)
                .frame(width: 18, height: 18)
                .overlay(RoundedRectangle(cornerRadius: 3).fill(Color(hex: hex).opacity(PackStyle.landOpacity)))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.fieldInk.opacity(0.35), lineWidth: 1))
            Text(title)
                .foregroundStyle(.primary)
        }
    }

}

struct SearchSheet: View {
    @Environment(AtlasModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query: String

    init(initialQuery: String = "") {
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        let hits = model.search(query)
        NavigationStack {
            List(hits) { hit in
                searchRow(hit)
            }
            .searchable(text: $query, prompt: "Search names on this phone")
            .navigationTitle(model.filter.searchTitle)
            .safeAreaInset(edge: .top) {
                FilterBar(scrollToFood: false)
                    .padding(.vertical, 4)
                    .background(.background)
            }
            .overlay {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Search names on this phone",
                        systemImage: "magnifyingglass",
                        description: Text("Names stay on this phone. Nothing is sent to a geocoder.")
                    )
                } else if hits.isEmpty {
                    ContentUnavailableView(
                        model.filter.emptySearchTitle,
                        systemImage: "magnifyingglass",
                        description: Text("Try a chapel, a trail, a town, or a land name.")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func searchRow(_ hit: SearchHit) -> some View {
        switch hit.kind {
        case .place, .trail, .town, .land:
            Button {
                activate(hit)
            } label: {
                searchLabel(hit)
            }
        case .note:
            searchLabel(hit)
        }
    }

    private func searchLabel(_ hit: SearchHit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(hit.name)
                .foregroundStyle(.primary)
            Text(searchDetail(hit))
                .font(.subheadline)
                .foregroundStyle(Color.fieldBrown)
        }
    }

    private func searchDetail(_ hit: SearchHit) -> String {
        var parts: [String] = []
        if !hit.subtitle.isEmpty { parts.append(hit.subtitle) }
        if !hit.city.isEmpty { parts.append(hit.city) }
        if let meters = hit.meters { parts.append(PlaceText.distanceLabel(meters)) }
        return parts.joined(separator: " · ")
    }

    private func activate(_ hit: SearchHit) {
        switch hit.kind {
        case .place:
            if let id = hit.placeId, let place = model.place(id: id) {
                model.openPlace(place)
            }
            dismiss()
        case .trail:
            if let id = hit.trailId, let trail = model.trail(id: id) {
                model.openTrail(trail)
            }
            dismiss()
        case .town, .land:
            if let lat = hit.lat, let lon = hit.lon {
                let point = LonLat(lon: lon, lat: lat)
                model.aim(at: point)
                model.focusCamera(on: point, zoom: hit.kind == .town ? 13 : 11)
            }
            dismiss()
        case .note:
            break
        }
    }
}

extension Color {
    static let fieldInk = Color(red: 0x1C / 255, green: 0x19 / 255, blue: 0x15 / 255)
    static let fieldCream = Color(red: 0xF4 / 255, green: 0xEF / 255, blue: 0xE4 / 255)
    static let fieldBrown = Color(red: 0x3A / 255, green: 0x32 / 255, blue: 0x28 / 255)

    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

#endif
