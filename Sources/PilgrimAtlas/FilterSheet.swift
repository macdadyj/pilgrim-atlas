#if canImport(UIKit)
import SwiftUI
import PilgrimAtlasCore

struct FilterSheet: View {
    @Environment(AtlasModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
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
                    Text("No filter means the full map. Place filters intersect. Trails leave the map when another filter is on and Trails is off.")
                }
            }
            .listStyle(.insetGrouped)
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
        let on = model.filter.isOn(control.id)
        if control.enabled {
            Button {
                model.filter.toggle(control.id)
                Haptics.selection()
            } label: {
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
                    Spacer(minLength: 8)
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(on ? Theme.control : Color.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("filter-row-\(control.id)")
            .accessibilityAddTraits(on ? .isSelected : [])
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
