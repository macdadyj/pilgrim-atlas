#if canImport(UIKit)
import SwiftUI
import PilgrimAtlasCore

struct SettingsView: View {
    @Environment(AtlasModel.self) private var model
    @AppStorage("pilgrim.appearance") private var appearanceRaw = AppearanceChoice.system.rawValue

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $model.showTerrain) {
                        settingsRow("mountain.2.fill", "Terrain", "Hillshade and 100 ft contours stored on this phone.")
                    }
                    .accessibilityIdentifier("toggle-terrain")
                    Toggle(isOn: $model.showParcels) {
                        settingsRow("square.grid.3x3", "Albuquerque lot lines", "Albuquerque only. Not in Santa Fe. No owner names.")
                    }
                    .accessibilityIdentifier("toggle-parcels")
                    Toggle(isOn: Binding(
                        get: { model.onlineTiles },
                        set: { newValue in
                            if newValue {
                                model.pendingOnlineConfirm = true
                            } else {
                                model.onlineTiles = false
                            }
                        }
                    )) {
                        settingsRow("globe", "Online OpenFreeMap tiles", "Off until you accept that the tile host sees this phone's IP address.")
                    }
                    .accessibilityIdentifier("toggle-online-tiles")
                    Toggle(isOn: $model.filter.hidePlacesWithoutHours) {
                        settingsRow("clock", "Hide places with no hours", "Pins without visitor hours stay off the map.")
                    }
                    .accessibilityIdentifier("toggle-hide-hours")
                } header: {
                    SectionTitle(text: "Map")
                }

                Section {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(AppearanceChoice.allCases) { choice in
                            Text(choice.title).tag(choice.rawValue)
                        }
                    }
                    .accessibilityIdentifier("appearance-picker")
                } header: {
                    SectionTitle(text: "Appearance")
                } footer: {
                    Text("Cream and ink stay on the map. Screens follow this setting.")
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
                    Button("Show welcome screens again") {
                        model.acceptedDisclaimer = false
                        model.onboardingPage = 0
                        UserDefaults.standard.set(false, forKey: "pilgrim.disclaimer.accepted")
                    }
                    .accessibilityIdentifier("welcome-again")
                } header: {
                    SectionTitle(text: "About")
                }

                Section {
                    LabeledContent("Version") {
                        Text(AppInfo.line)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .accessibilityIdentifier("settings-version")
                    }
                    LabeledContent("Build") {
                        Text(AppInfo.build)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .accessibilityIdentifier("settings-build")
                    }
                    if let osm = model.meta["osm_date"], !osm.isEmpty {
                        LabeledContent("OpenStreetMap extract") {
                            Text(osm)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("settings-osm-date")
                        }
                    }
                    if let built = model.meta["built"], !built.isEmpty {
                        LabeledContent("Pack built") {
                            Text(built)
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Places") {
                        Text(model.meta["place_count"] ?? "—")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    LabeledContent("Hiking routes") {
                        Text(model.meta["trail_count"] ?? "—")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    LabeledContent("Land polygons") {
                        Text(model.meta["land_count"] ?? "—")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } header: {
                    SectionTitle(text: "This build")
                } footer: {
                    Text("Pilgrim Atlas is free and open source. The Swift code is MIT. The pack is other people's data and is not MIT.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("settings-screen")
    }

    private func settingsRow(_ systemImage: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: systemImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#endif
