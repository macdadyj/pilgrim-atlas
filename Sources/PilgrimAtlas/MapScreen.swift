#if canImport(UIKit)
import SwiftUI
import PilgrimAtlasCore

struct MapScreen: View {
    @Environment(AtlasModel.self) private var model
    @State private var showSearch = false
    @State private var showLicenses = false
    @State private var showLayers = false
    @State private var query = ""

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .top) {
            AtlasMapView(onSelect: { coordinate in
                model.mapCenter = coordinate
                model.refreshSummary()
                if let nearest = nearestPlace(to: coordinate) {
                    model.selectedPlace = nearest
                }
            })
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
                    Button { showLicenses = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.bordered)
                    Button { model.requestLocation() } label: {
                        Image(systemName: "location")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                Text("© OpenStreetMap contributors")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                if let loadError = model.loadError {
                    Text(loadError)
                        .font(.footnote)
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                }
                Spacer()
                NearbyPanel()
            }
            .padding(.top, 8)
        }
        .sheet(isPresented: $showSearch) { SearchSheet() }
        .sheet(isPresented: $showLicenses) { LicensesView() }
        .sheet(isPresented: $showLayers) { LayersSheet() }
        .sheet(item: $model.selectedPlace) { place in
            DetailSheet(place: place)
        }
        .alert("Online tiles", isPresented: $model.pendingOnlineConfirm) {
            Button("Keep offline") { model.onlineTiles = false }
            Button("Use OpenFreeMap") { model.onlineTiles = true }
        } message: {
            Text("OpenFreeMap will see this phone's IP address and the map tiles it requests. That is an approximate location. Pilgrim Atlas still does not upload your GPS position, and it does not run a server.")
        }
        .onAppear { model.requestLocation() }
    }

    private func nearestPlace(to coordinate: LonLat) -> PlaceRecord? {
        placesNear(coordinate, limit: 1).first
    }

    private func placesNear(_ coordinate: LonLat, limit: Int) -> [PlaceRecord] {
        model.places
            .map { (Geometry.haversineMeters(coordinate, $0.coordinate), $0) }
            .filter { $0.0 < 80 }
            .sorted { $0.0 < $1.0 }
            .prefix(limit)
            .map(\.1)
    }
}

struct NearbyPanel: View {
    @Environment(AtlasModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.userCoordinate == nil ? "Map center" : "Where you are")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(model.summary?.land ?? Copy.text("unknown"))
                .font(.subheadline)
            if let summary = model.summary {
                if !summary.explore.isEmpty {
                    Text("Nearby: " + summary.explore.map(\.name).joined(separator: ", "))
                        .font(.footnote)
                        .lineLimit(2)
                }
                if let trail = summary.trails.first {
                    Text("Trail: \(trail.name). \(trail.access)")
                        .font(.footnote)
                        .lineLimit(3)
                }
                Text(summary.closures.joined(separator: " "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(summary.notASurvey)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}

struct LayersSheet: View {
    @Environment(AtlasModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Toggle("Land status", isOn: $model.showLand)
                Toggle("Trails", isOn: $model.showTrails)
                Toggle("Places", isOn: $model.showPlaces)
                Toggle("Albuquerque lot lines", isOn: $model.showParcels)
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
                Text("Lot lines are City of Albuquerque parcels without owner names. They are not a survey and not permission to enter. Santa Fe County parcels are not in this pack.")
                    .font(.footnote)
            }
            .navigationTitle("Layers")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SearchSheet: View {
    @Environment(AtlasModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(model.search(query)) { hit in
                Button {
                    if hit.kind == "place", let place = model.place(named: hit.name) {
                        model.selectedPlace = place
                        model.focusCamera(on: place.coordinate)
                    }
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(hit.name)
                        Text(hit.catholic ? "Catholic landmark" : hit.kind)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search the pack")
            .navigationTitle("Search")
            .overlay {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView("Search on this phone", systemImage: "magnifyingglass", description: Text("Names come from the offline pack. Nothing is sent to a geocoder."))
                }
            }
        }
    }
}

#endif
