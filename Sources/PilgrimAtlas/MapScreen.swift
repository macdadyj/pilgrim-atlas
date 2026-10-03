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
            AtlasMapView(places: model.places) { coordinate, hits in
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
                    .accessibilityLabel("Layers")
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
                if model.onlineTiles {
                    statusChip("Streets on. Land and landmarks stay on.")
                } else {
                    statusChip("Offline. Place names are in the pack.")
                }
                Text("© OpenStreetMap contributors")
                    .font(.caption)
                    .foregroundStyle(.primary)
                if model.locationDenied && !model.debugPlaza {
                    statusChip("Location is off. The map is staying on Santa Fe Plaza.")
                }
                if let loadError = model.loadError {
                    statusChip(loadError)
                }
                Spacer()
                NearbyPanel()
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

struct NearbyPanel: View {
    @Environment(AtlasModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What you can do here")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(model.summary?.headline ?? Copy.text("unknown"))
                .font(.body)
                .foregroundStyle(.primary)
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
                                    .foregroundStyle(.primary)
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
                    .foregroundStyle(.primary)
            }
            if model.cameraMovedFromSummary {
                Button("Use this point") { model.useCameraPoint() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func landmarkLabel(_ row: ExploreRow) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .foregroundStyle(.primary)
                Text(row.category)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
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
                    Toggle(isOn: $model.showLand) {
                        labeledSwatch("8C7B64", "Land status")
                    }
                    Toggle(isOn: $model.showTrails) {
                        labeledSwatch("6B4F3A", "Trails")
                    }
                    Toggle(isOn: $model.showPlaces) {
                        labeledSwatch("8C2F39", "Places")
                    }
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
                }
                Section("Marker legend") {
                    markerRow("marker-catholic", "Catholic landmark")
                    markerRow("marker-worship", "Other worship")
                    markerRow("marker-landmark", "Landmark")
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
            .navigationTitle("Layers")
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
                .fill(Color(hex: hex))
                .frame(width: 18, height: 18)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.35), lineWidth: 1))
            Text(title)
                .foregroundStyle(.primary)
        }
    }

    private func markerRow(_ name: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            if let image = markerImage(name) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 28, height: 28)
            }
            Text(title)
                .foregroundStyle(.primary)
        }
    }

    private func markerImage(_ name: String) -> UIImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
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
            .navigationTitle("Search")
            .overlay {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Search names on this phone",
                        systemImage: "magnifyingglass",
                        description: Text("Names stay on this phone. Nothing is sent to a geocoder.")
                    )
                } else if hits.isEmpty {
                    ContentUnavailableView(
                        "No matches in the offline pack",
                        systemImage: "magnifyingglass",
                        description: Text("Try a chapel, a trail, or a town name.")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func searchRow(_ hit: SearchHit) -> some View {
        switch hit.kind {
        case .place, .trail:
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
                .foregroundStyle(.primary)
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
        case .note:
            break
        }
    }
}

private extension Color {
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
