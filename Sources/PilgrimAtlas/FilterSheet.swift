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
                        if control.id == "food" {
                            foodRow
                        } else {
                            filterRow(control)
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

    private func filterRow(_ control: FilterControl) -> some View {
        let on = model.filter.isOn(control.id)
        return Button {
            model.setFilter(control.id, on: !model.filter.isOn(control.id))
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
                    .foregroundStyle(on ? Theme.accentFill : Color.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("filter-row-\(control.id)")
        .accessibilityValue(on ? "1" : "0")
        .accessibilityAddTraits(.isToggle)
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
