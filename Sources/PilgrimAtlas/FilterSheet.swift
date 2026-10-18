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
                        filterRow(control, isOn: filterBinding(control.id))
                    }
                } header: {
                    SectionTitle(text: "Show on the map")
                } footer: {
                    Text("Catholic, Orthodox, and SSPX start on. Turn one off to hide it. Non-Christian sites are not on this map. The other filters narrow what remains.")
                }
            }
            .listStyle(.insetGrouped)
            .buttonStyle(.borderless)
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

    private func filterBinding(_ id: String) -> Binding<Bool> {
        @Bindable var model = model
        switch id {
        case "show-catholic":
            return $model.filter.showCatholic
        case "orthodox":
            return $model.filter.showOrthodox
        case "sspx":
            return $model.filter.showSSPX
        case "catholic":
            return $model.filter.catholic
        case "churches":
            return $model.filter.churches
        case "trails":
            return $model.filter.trails
        case "public-land":
            return $model.filter.publicLand
        case "parks":
            return $model.filter.parks
        case "open-now":
            return $model.filter.openNow
        default:
            return .constant(false)
        }
    }

    @ViewBuilder
    private func filterRow(_ control: FilterControl, isOn: Binding<Bool>) -> some View {
        if control.enabled {
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
        } else {
            HStack(spacing: 12) {
                IconTile(systemName: control.systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(control.title)
                        .foregroundStyle(.primary)
                    Text(MapFilter.foodCount(model.places) == 0 ? control.subtitle : "\(MapFilter.foodCount(model.places)) in the pack")
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
}

#endif
