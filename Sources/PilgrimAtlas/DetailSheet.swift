#if canImport(UIKit)
import SwiftUI
import PilgrimAtlasCore

struct DetailSheet: View {
    let place: PlaceRecord
    @Environment(AtlasModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let facts = AtlasQuery.facts(for: place)
        let hours = MapFilter.hoursReading(place.openingHours)
        let lines = MapFilter.hourLines(place.openingHours)
        NavigationStack {
            List {
                Section {
                    Text(place.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !place.denomination.isEmpty {
                        LabeledContent("Denomination", value: PlaceText.denominationLabel(place.denomination))
                    }
                    if case .none = hours {
                        Text(MapFilter.hoursMissing)
                            .font(.subheadline)
                            .foregroundStyle(Color.fieldBrown)
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
                if !lines.isEmpty || facts.contains(where: { ["Service times", "Mass times", "Confession times"].contains($0.label) }) {
                    Section("Hours") {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.primary)
                        }
                        switch hours {
                        case .none:
                            EmptyView()
                        case .notAClock:
                            Text(MapFilter.hoursUnparsed)
                                .font(.subheadline)
                                .foregroundStyle(Color.fieldBrown)
                        case .clock(let open):
                            Text(open ? "Open now" : "Closed now")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        if let note = facts.first(where: { $0.label == "Hours note" }) {
                            Text(note.value)
                                .font(.subheadline)
                                .foregroundStyle(Color.fieldBrown)
                        }
                        if let schedules = facts.first(where: { $0.label == "Schedules" }) {
                            Text(schedules.value)
                                .font(.subheadline)
                                .foregroundStyle(Color.fieldBrown)
                        }
                        ForEach(facts.filter { ["Service times", "Mass times", "Confession times"].contains($0.label) }) { fact in
                            LabeledContent(fact.label, value: fact.value)
                        }
                    }
                }
                if let address = facts.first(where: { $0.label == "Address" }) {
                    Section("Address") {
                        Text(address.value)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if let raw = address.url, let url = URL(string: raw) {
                            Link("Open in Maps", destination: url)
                        }
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
                                Link(linkTitle(fact), destination: url)
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
            .navigationTitle(PlaceText.kindLabel(for: place))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func linkTitle(_ fact: FactLine) -> String {
        switch fact.label {
        case "Wikipedia": return PlaceText.wikipediaTitle(fact.value)
        case "Wikidata": return fact.value
        default: return fact.label
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
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(trail.name.isEmpty ? "Unnamed hiking route" : trail.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#endif
