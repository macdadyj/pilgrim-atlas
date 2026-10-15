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
            showLayers: model.launch.showLayers,
            showFilters: model.showFilters,
            tapMenu: launchMenu,
            cardFull: model.launch.cardFull
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
    @State private var showLayers: Bool
    @State private var tapMenu: TapMenu?
    @State private var cardExpanded: Bool
    @State private var sheetsReady = false

    init(showLayers: Bool, showFilters: Bool, tapMenu: TapMenu?, cardFull: Bool) {
        _showLayers = State(initialValue: showLayers)
        _tapMenu = State(initialValue: tapMenu)
        _cardExpanded = State(initialValue: cardFull)
        _ = showFilters
    }

    var body: some View {
        @Bindable var model = model
        GeometryReader { geo in
            let cardHeight = NearbyPanel.height(expanded: cardExpanded, in: geo)
            let obstruction = cardHeight + 8
            ZStack(alignment: .top) {
                AtlasMapView(
                    topInset: model.filter.anyChip ? 140 : 88,
                    places: AtlasQuery.mapPlaces(model.places.filter { MapFilter.includeInLists($0, filter: model.filter) }),
                    bottomObstruction: obstruction,
                    bottomSafeArea: geo.safeAreaInsets.bottom
                ) { coordinate, hits in
                    handleTap(coordinate: coordinate, hits: hits)
                }
                .ignoresSafeArea()

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            model.selectedTab = .search
                            Haptics.light()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                Text("Search")
                                Spacer(minLength: 0)
                            }
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(.regularMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Search")
                        .accessibilityIdentifier("search-pill")

                        Button {
                            model.showFilters = true
                            Haptics.light()
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(model.filter.anyChip ? Color.white : Color.primary)
                                .frame(width: 44, height: 44)
                                .background {
                                    ZStack {
                                        Circle().fill(.regularMaterial)
                                        if model.filter.anyChip {
                                            Circle().fill(Theme.accentFill)
                                        }
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Filters")
                        .accessibilityIdentifier("filters-button")
                        .overlay(alignment: .topTrailing) {
                            if model.filter.anyChip {
                                Text("\(model.filter.chipTitles.count)")
                                    .font(.caption2.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Theme.partner, in: Circle())
                                    .offset(x: 4, y: -4)
                                    .accessibilityHidden(true)
                            }
                        }

                        Button {
                            showLayers = true
                            Haptics.light()
                        } label: {
                            Image(systemName: "square.3.layers.3d")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 44, height: 44)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("More map options")
                        .accessibilityIdentifier("layers-button")
                        .overlay(alignment: .topTrailing) {
                            if model.layerBadge > 0 {
                                Text("\(model.layerBadge)")
                                    .font(.caption2.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Theme.accentFill, in: Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)

                    if model.filter.anyChip {
                        ActiveFilterStrip()
                    }

                    if model.viewIsOutsidePack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This view is outside the offline pack.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Show the nearest mapped area") {
                                model.jumpToNearestMappedArea()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("jump-nearest-mapped")
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                        .padding(.horizontal, Theme.screenPadding)
                        .accessibilityIdentifier("outside-coverage-banner")
                    }

                    Spacer(minLength: 0)

                    HStack(alignment: .bottom, spacing: 12) {
                        Text("© OpenStreetMap contributors")
                            .font(.caption2)
                            .foregroundStyle(Theme.mapInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.mapCream.opacity(0.92), in: Capsule())
                        Spacer(minLength: 0)
                        Button { model.recenter() } label: {
                            Image(systemName: "location")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 50, height: 50)
                                .background(.regularMaterial, in: Circle())
                                .symbolEffect(.bounce, value: model.cameraToken)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Location")
                        .accessibilityIdentifier("location-button")
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 8)
                }
                .padding(.top, 8)
                .padding(.bottom, obstruction + AtlasMapView.ornamentGap + AtlasMapView.ornamentBand)
                .zIndex(1)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    NearbyPanel(
                        expanded: $cardExpanded,
                        statusLine: statusLine,
                        height: cardHeight
                    )
                }
            }
        }
        .onAppear {
            sheetsReady = true
            model.resumeLocationIfAllowed()
        }
        .onChange(of: model.filter) { _, _ in model.refreshSummary() }
        .sheet(isPresented: $showLayers) {
            LayersSheet()
                .pilgrimSheet()
        }
        .sheet(item: presentedPlace) { place in
            DetailSheet(place: place)
                .pilgrimSheet()
        }
        .sheet(item: presentedTrail) { trail in
            TrailSheet(trail: trail)
                .pilgrimSheet()
        }
        .sheet(item: presentedMenu) { menu in
            NavigationStack {
                List(menu.choices) { choice in
                    Button {
                        tapMenu = nil
                        model.openPlace(choice.place)
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(systemName: PlaceText.rowSymbol(for: choice.place))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(choice.place.name)
                                    .foregroundStyle(.primary)
                                Text("\(PlaceText.kindLabel(for: choice.place)) · \(PlaceText.distanceLabel(choice.meters))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("picker-place-\(choice.id)")
                }
                .contentMargins(.bottom, 88, for: .scrollContent)
                .navigationTitle("Places here")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { tapMenu = nil }
                            .accessibilityIdentifier("picker-done")
                    }
                }
            }
            .pilgrimSheet()
            .accessibilityIdentifier("places-picker")
        }
    }

    private var presentedPlace: Binding<PlaceRecord?> {
        Binding(
            get: { sheetsReady ? model.selectedPlace : nil },
            set: { model.selectedPlace = $0 }
        )
    }

    private var presentedTrail: Binding<TrailRecord?> {
        Binding(
            get: { sheetsReady ? model.selectedTrail : nil },
            set: { model.selectedTrail = $0 }
        )
    }

    private var presentedMenu: Binding<TapMenu?> {
        Binding(
            get: { sheetsReady ? tapMenu : nil },
            set: { tapMenu = $0 }
        )
    }

    private var statusLine: String {
        if let loadError = model.loadError { return loadError }
        if model.locationDenied && !model.debugPlaza {
            return "Location is off. The map is staying on Santa Fe Plaza."
        }
        if model.filter.publicLand { return MapFilter.publicLandSubtitle }
        if model.filter.openNow {
            let coverage = MapFilter.coverage(model.places)
            if let none = coverage.noneOpenLine { return none }
            return coverage.line
        }
        if model.onlineTiles { return "Streets on. Land and landmarks stay on." }
        return "Offline. Place names are in the pack."
    }

    private func handleTap(coordinate: LonLat, hits: [PlaceRecord]) {
        if hits.count == 1, let place = hits.first {
            model.openPlace(place)
        } else if hits.count > 1 {
            let unique = PlaceText.dedupeByName(hits)
            if unique.count == 1, let place = unique.first {
                model.openPlace(place)
            } else {
                model.aim(at: coordinate)
                tapMenu = TapMenu(choices: unique.map { place in
                    PlaceHit(
                        place: place,
                        meters: Int(Geometry.haversineMeters(coordinate, place.coordinate).rounded())
                    )
                })
            }
        } else {
            model.aim(at: coordinate)
        }
    }
}

private struct ActiveFilterStrip: View {
    @Environment(AtlasModel.self) private var model

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                IconChip(title: "Reset", systemImage: "xmark", on: true) {
                    model.resetFilters()
                    Haptics.selection()
                }
                ForEach(model.filter.activeControls) { control in
                    IconChip(title: control.title, systemImage: control.systemImage, on: true) {
                        model.filter.toggle(control.id)
                        Haptics.selection()
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .frame(height: 44)
        .sensoryFeedback(.selection, trigger: model.filter)
        .accessibilityIdentifier("active-filters")
    }
}

struct NearbyPanel: View {
    static func height(expanded: Bool, in geo: GeometryProxy) -> CGFloat {
        expanded ? max(geo.size.height * 0.36, 220) : 96
    }

    @Environment(AtlasModel.self) private var model
    @Binding var expanded: Bool
    var statusLine: String
    var height: CGFloat

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .accessibilityIdentifier("nearby-grabber")
                Text(model.viewIsOutsidePack ? "This view is outside the offline pack." : (model.summary?.headline ?? Copy.text("unknown")))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(expanded ? nil : 1)
                    .fixedSize(horizontal: false, vertical: expanded)
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, expanded ? 0 : 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("nearby-headline")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.35)) { expanded.toggle() }
            }
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        if value.translation.height < -24 {
                            withAnimation(.spring(duration: 0.35)) { expanded = true }
                        } else if value.translation.height > 24 {
                            withAnimation(.spring(duration: 0.35)) { expanded = false }
                        }
                    }
            )
            if expanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(statusLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("nearby-status")
                        Text("What you can do here")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        details
                    }
                    .padding(Theme.screenPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: height, alignment: .top)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, y: -2)
        .accessibilityIdentifier("nearby-card")
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.summary?.permissionLine ?? PlaceText.permissionLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let summary = model.summary {
                if summary.landmarks.isEmpty && summary.trails.isEmpty {
                    EmptyStateCard(
                        systemImage: "binoculars",
                        title: "Nothing named right here",
                        message: "Pan the map, search a chapel or a trail, or jump back if you left the offline pack."
                    )
                }
                ForEach(summary.landmarks) { row in
                    if let place = model.place(id: row.placeId) {
                        Button {
                            model.openPlace(place)
                        } label: {
                            landmarkLabel(row)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("nearby-place-\(row.placeId)")
                    }
                }
                if !summary.landmarkGap.isEmpty {
                    Text(summary.landmarkGap)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let trail = summary.trails.first, let record = model.trail(id: trail.trailId) {
                    Button {
                        model.openTrail(record)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            IconTile(systemName: "figure.hiking")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trail.name)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Hiking trail")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text(PlaceText.distanceLabel(trail.meters))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("nearby-trail-\(trail.trailId)")
                }
                if !summary.trailGap.isEmpty {
                    Text(summary.trailGap)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if summary.headline != summary.land {
                    SectionTitle(text: "About this land")
                    Text(summary.land)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !summary.closures.isEmpty {
                    Text(summary.closures.joined(separator: " "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if model.cameraMovedFromSummary {
                Button("Use this point") { model.useCameraPoint() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("use-this-point")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func landmarkLabel(_ row: ExploreRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            IconTile(systemName: model.place(id: row.placeId).map { PlaceText.rowSymbol(for: $0) } ?? PinRole.landmark.systemImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(PlaceText.distanceLabel(row.meters))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
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
                    Toggle(isOn: $model.showTerrain) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Terrain")
                            Text("Hillshade, 100 ft contours, and labeled 500 ft index lines, stored on this phone.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("toggle-terrain")
                    Toggle(isOn: $model.showParcels) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Albuquerque lot lines")
                            Text("Albuquerque only. Not in Santa Fe.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("toggle-parcels")
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
                    .accessibilityIdentifier("toggle-online-tiles")
                    Toggle("Hide places with no hours", isOn: $model.filter.hidePlacesWithoutHours)
                        .accessibilityIdentifier("toggle-hide-hours")
                    LabeledContent("Appearance") {
                        Text("Follows Settings")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    SectionTitle(text: "Map")
                }
                Section {
                    NavigationLink {
                        LicensesView()
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(systemName: "doc.text")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Licenses")
                                Text("Datasets and terms")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("licenses-row")
                } header: {
                    SectionTitle(text: "About")
                }
                Section {
                    terrainRow(weight: 3, color: Color(red: 0.16, green: 0.14, blue: 0.11), title: "Index contour, every 500 ft", detail: "Heavier line, labeled with elevation")
                    terrainRow(weight: 1, color: Color(red: 0.55, green: 0.49, blue: 0.43), title: "Intermediate contour, every 100 ft", detail: "Thinner and lighter")
                    HStack(spacing: 12) {
                        IconTile(systemName: "mountain.2")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hillshade")
                                .foregroundStyle(.primary)
                            Text("Slope from the bundled elevation. Flat ground stays even.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    SectionTitle(text: "Terrain legend")
                }
                Section {
                    ForEach(PinRole.allCases, id: \.rawValue) { role in
                        HStack(spacing: 12) {
                            Image(uiImage: PinArt.image(for: role))
                                .resizable()
                                .frame(width: 44, height: 44)
                            Text(role.legend)
                                .foregroundStyle(.primary)
                        }
                        .accessibilityIdentifier("legend-\(role.rawValue)")
                    }
                } header: {
                    SectionTitle(text: "Marker legend")
                }
                Section {
                    ForEach(PackStyle.legend, id: \.name) { item in
                        labeledSwatch(item.hex, item.name)
                    }
                    Text("Lot lines are City of Albuquerque parcels without owner names. They are not a survey and not permission to enter. Santa Fe County parcels are not in this pack.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    SectionTitle(text: "Land colors")
                }
            }
            .navigationTitle("More map options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("layers-done")
                }
            }
        }
        .accessibilityIdentifier("layers-sheet")
    }

    private func terrainRow(weight: CGFloat, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(color)
                .frame(width: 36, height: weight)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func labeledSwatch(_ hex: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.mapCream)
                .frame(width: 28, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: hex).opacity(PackStyle.landOpacity)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            Text(title)
                .foregroundStyle(.primary)
        }
    }
}

struct SearchSheet: View {
    @Environment(AtlasModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let hits = model.search(model.searchQuery)
        NavigationStack {
            List(hits) { hit in
                searchRow(hit)
            }
            .listStyle(.insetGrouped)
            .searchable(text: $model.searchQuery, prompt: "Search names on this phone")
            .navigationTitle(model.filter.searchTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Filters") { model.showFilters = true }
                        .accessibilityIdentifier("search-filters")
                }
            }
            .onAppear {
                model.revealSearch(model.searchQuery)
            }
            .onChange(of: model.searchQuery) { _, newValue in
                model.revealSearch(newValue)
            }
            .onDisappear {
                model.endSearch()
            }
            .overlay {
                if model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Search names on this phone",
                        systemImage: "magnifyingglass",
                        description: Text("Names stay on this phone. Nothing is sent to a geocoder.")
                    )
                    .accessibilityIdentifier("search-empty-prompt")
                } else if hits.isEmpty {
                    ContentUnavailableView(
                        model.filter.emptySearchTitle,
                        systemImage: "magnifyingglass",
                        description: Text("Try a chapel, a trail, a town, or a land name.")
                    )
                    .accessibilityIdentifier("search-no-matches")
                }
            }
        }
        .accessibilityIdentifier("search-screen")
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
            .accessibilityIdentifier("search-hit-\(hit.id)")
        case .note:
            searchLabel(hit)
        }
    }

    private func searchLabel(_ hit: SearchHit) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: iconName(hit))
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.name)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(searchDetail(hit))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func iconName(_ hit: SearchHit) -> String {
        switch hit.kind {
        case .place:
            if let id = hit.placeId, let place = model.place(id: id) {
                return PlaceText.rowSymbol(for: place)
            }
            return PinRole.landmark.systemImage
        case .trail: return "figure.hiking"
        case .town: return "building.2"
        case .land: return "map"
        case .note: return "info.circle"
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
        case .trail:
            if let id = hit.trailId, let trail = model.trail(id: id) {
                model.openTrail(trail)
            }
        case .town, .land:
            if let lat = hit.lat, let lon = hit.lon {
                let point = LonLat(lon: lon, lat: lat)
                model.aim(at: point)
                model.focusCamera(on: point, zoom: hit.kind == .town ? 13 : 11)
                model.selectedTab = .map
            }
        case .note:
            break
        }
    }
}

extension Color {
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
