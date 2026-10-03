#if canImport(UIKit)
import SwiftUI
import PilgrimAtlasCore

struct DetailSheet: View {
    let place: PlaceRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(place.catholic ? "Catholic landmark" : place.category == "worship" ? "Place of worship" : "Landmark")
                        .font(.headline)
                    if !place.denomination.isEmpty {
                        LabeledContent("Denomination", value: place.denomination.replacingOccurrences(of: "_", with: " "))
                    }
                }
                ForEach(AtlasQuery.facts(for: place)) { fact in
                    Section {
                        Text(fact.value)
                        Text("Source: \(fact.source)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(fact.label)
                    }
                }
                Section {
                    Text(Copy.text("mass_footnote"))
                        .font(.footnote)
                    if place.access.isEmpty {
                        Text(Copy.text("trail_untagged"))
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#endif
