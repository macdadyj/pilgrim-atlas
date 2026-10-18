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
                        filterRow(control)
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
    private func filterRow(_ control: FilterControl) -> some View {
        if control.enabled {
            Toggle(isOn: Binding(
                get: { model.filter.isOn(control.id) },
                set: { on in
                    model.setFilter(control.id, on: on)
                    Haptics.selection()
                }
            )) {
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
