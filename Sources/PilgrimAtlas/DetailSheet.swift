#if canImport(UIKit)
import SwiftUI
import PilgrimAtlasCore

struct DetailSheet: View {
    let place: PlaceRecord
    @Environment(AtlasModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let facts = AtlasQuery.facts(for: place)
        NavigationStack {
            List {
                Section {
                    Text(PlaceText.kindLabel(for: place))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !place.denomination.isEmpty {
                        LabeledContent("Denomination", value: place.denomination.replacingOccurrences(of: "_", with: " "))
                    }
                    if let note = PlaceText.diamondNote(for: place) {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    if let note = PlaceText.sameSiteNote(for: place, among: model.places) {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
                Section("Hours") {
                    if let hours = facts.first(where: { $0.label == "Hours" }) {
                        Text(hours.value)
                            .font(.body)
                            .foregroundStyle(.primary)
                    } else {
                        Text("No hours in the pack")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    if let note = facts.first(where: { $0.label == "Hours note" }) {
                        Text(note.value)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    if let schedules = facts.first(where: { $0.label == "Schedules" }) {
                        Text(schedules.value)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    ForEach(facts.filter { ["Service times", "Mass times", "Confession times"].contains($0.label) }) { fact in
                        LabeledContent(fact.label, value: fact.value)
                    }
                }
                Section("Address") {
                    if let address = facts.first(where: { $0.label == "Address" }) {
                        Text(address.value)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if let raw = address.url, let url = URL(string: raw) {
                            Link("Open in Maps", destination: url)
                        }
                    } else {
                        Text("No address in the pack")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
                let details = facts.filter { fact in
                    !["Hours", "Hours note", "Schedules", "Address", "Website", "Wikipedia", "Wikidata", "Photo", "Service times", "Mass times", "Confession times"].contains(fact.label)
                }
                if !details.isEmpty {
                    Section("Details") {
                        ForEach(details) { fact in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fact.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text(fact.value)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                let links = facts.filter { ["Website", "Wikipedia", "Wikidata", "Photo"].contains($0.label) }
                if !links.isEmpty {
                    Section("Links") {
                        ForEach(links) { fact in
                            if let raw = fact.url, let url = URL(string: raw) {
                                Link(fact.label, destination: url)
                            }
                        }
                    }
                }
                Section("Source") {
                    Text(PlaceText.sourceLine(source: place.source, sourceDate: place.sourceDate))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(Copy.text("mass_footnote"))
                        .font(.body)
                        .foregroundStyle(.primary)
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

struct TrailSheet: View {
    let trail: TrailRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(trail.name.isEmpty ? "Unnamed hiking route" : trail.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(AtlasQuery.trailSentence(trail.access))
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                Section("Source") {
                    Text(PlaceText.sourceLine(source: trail.source, sourceDate: trail.sourceDate))
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Trail")
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
