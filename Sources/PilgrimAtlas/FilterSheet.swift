#if canImport(UIKit)
import SwiftUI
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

struct FilterSheet: View {
    @Environment(AtlasModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                if model.filter.anyChip {
                    Section {
                        Button {
                            model.resetFilters()
                            Haptics.selection()
                        } label: {
                            HStack(spacing: 12) {
                                IconTile(systemName: "xmark")
                                Text("Reset filters")
                                    .foregroundStyle(.primary)
                            }
                        }
                        .accessibilityIdentifier("reset-filters")
                    }
                }
                Section {
                    ForEach(FilterControl.all) { control in
                        switch control.id {
                        case "show-catholic":
                            filterRow(control, isOn: $model.filter.showCatholic)
                        case "orthodox":
                            filterRow(control, isOn: $model.filter.showOrthodox)
                        case "sspx":
                            filterRow(control, isOn: $model.filter.showSSPX)
                        case "catholic":
                            filterRow(control, isOn: $model.filter.catholic)
                        case "churches":
                            filterRow(control, isOn: $model.filter.churches)
                        case "trails":
                            filterRow(control, isOn: $model.filter.trails)
                        case "public-land":
                            filterRow(control, isOn: $model.filter.publicLand)
                        case "parks":
                            filterRow(control, isOn: $model.filter.parks)
                        case "open-now":
                            filterRow(control, isOn: $model.filter.openNow)
                        case "food":
                            foodRow
                        default:
                            EmptyView()
                        }
                    }
                } header: {
                    SectionTitle(text: "Show on the map")
                } footer: {
                    Text("Catholic, Orthodox, and SSPX start on. Turn one off to hide it. Non-Christian sites are not on this map. The other filters narrow what remains.")
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                if model.focusFoodChip {
                    proxy.scrollTo("food", anchor: .center)
                }
            }
            .onChange(of: model.filter.catholic) { _, on in
                if on { model.frameRole("catholic") }
            }
            .onChange(of: model.filter.churches) { _, on in
                if on { model.frameChurches() }
            }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("filters-done")
                }
            }
        }
        .accessibilityIdentifier("filters-sheet")
    }

    @ViewBuilder
    private func filterRow(_ control: FilterControl, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                IconTile(systemName: control.systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(control.title)
                        .foregroundStyle(.primary)
                    Text(control.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("filter-row-\(control.id)")
    }

    private var foodRow: some View {
        HStack(spacing: 12) {
            IconTile(systemName: "fork.knife")
            VStack(alignment: .leading, spacing: 2) {
                Text("Food and rest")
                    .foregroundStyle(.primary)
                Text(MapFilter.foodCount(model.places) == 0 ? MapFilter.foodSubtitle : "\(MapFilter.foodCount(model.places)) in the pack")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(0.7)
        .id("food")
        .accessibilityIdentifier("filter-row-food")
        .accessibilityLabel("Food and rest, \(MapFilter.foodSubtitle)")
    }
}

#endif
