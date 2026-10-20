#if canImport(UIKit)
import SwiftUI
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

struct DetailSheet: View {
    let place: PlaceRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let facts = AtlasQuery.facts(for: place)
        let hours = MapFilter.hoursReading(place.openingHours)
        let lines = MapFilter.hourLines(place.openingHours)
        let liturgy = ChurchMark.showsLiturgy(place) ? LiturgyLookup.card(for: place) : nil
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        placeBadge
                        VStack(alignment: .leading, spacing: 6) {
                            Text(place.name)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            if liturgy == nil {
                                let mark = Theme.hoursMark(hours)
                                StatusMark(kind: mark.0, title: mark.1)
                                if case .none = hours {
                                    Text(MapFilter.hoursMissing)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if !place.denomination.isEmpty {
                        labeledRow("Denomination", PlaceText.denominationLabel(place.denomination))
                    }
                    if let liturgy, !liturgy.verifiedLine.isEmpty {
                        Text(liturgy.verifiedLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("liturgy-verified")
                    }
                    if let note = PlaceText.diamondNote(for: place) {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                visitBlock
                if let liturgy {
                    liturgySection(liturgy)
                }
                if !lines.isEmpty || (liturgy == nil && facts.contains(where: { ["Service times", "Mass times", "Confession times"].contains($0.label) })) {
                    Section {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.primary)
                                .accessibilityIdentifier("place-hours")
                        }
                        switch hours {
                        case .none:
                            EmptyView()
                        case .notAClock:
                            if !facts.contains(where: { $0.label == "Hours note" }) {
                                Text(MapFilter.hoursUnparsed)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        case .clock:
                            EmptyView()
                        }
                        if let note = facts.first(where: { $0.label == "Hours note" }) {
                            Text(note.value)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let schedules = facts.first(where: { $0.label == "Schedules" }) {
                            Text(schedules.value)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        ForEach(facts.filter { ["Service times", "Mass times", "Confession times"].contains($0.label) }) { fact in
                            LabeledContent(fact.label, value: fact.value)
                        }
                    } header: {
                        SectionTitle(text: "Hours")
                    }
                }
                if let address = facts.first(where: { $0.label == "Address" }) {
                    Section {
                        Text(address.value)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if let raw = address.url, let url = URL(string: raw) {
                            Link("Open in Maps", destination: url)
                        }
                    } header: {
                        SectionTitle(text: "Address")
                    }
                }
                let details = facts.filter { fact in
                    !["Hours", "Hours note", "Schedules", "Address", "Website", "Wikipedia", "Wikidata", "Photo", "Service times", "Mass times", "Confession times"].contains(fact.label)
                }
                if !details.isEmpty {
                    Section {
                        ForEach(details) { fact in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fact.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(fact.value)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    } header: {
                        SectionTitle(text: "Details")
                    }
                }
                let links = facts.filter { fact in
                    if fact.label == "Website", liturgy?.website.isEmpty == false { return false }
                    return ["Website", "Wikipedia", "Wikidata", "Photo"].contains(fact.label)
                }
                if !links.isEmpty {
                    Section {
                        ForEach(links) { fact in
                            if let raw = fact.url, let url = URL(string: raw) {
                                Link(PlaceText.externalLinkTitle(label: fact.label, value: fact.value), destination: url)
                            }
                        }
                    } header: {
                        SectionTitle(text: "Links")
                    }
                }
                Section {
                    Text(PlaceText.sourceLine(source: place.source, sourceDate: place.sourceDate))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Copy.text("mass_footnote"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    SectionTitle(text: "Source")
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.bottom, 72, for: .scrollContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(PlaceText.kindLabel(for: place))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("place-done")
                }
            }
        }
        .accessibilityIdentifier("place-sheet")
    }

    @ViewBuilder
    private var placeBadge: some View {
        if let mark = ChurchMark.mark(for: place) {
            Image(uiImage: PinArt.image(mark: mark, selected: true))
                .resizable()
                .frame(width: 54, height: 54)
                .accessibilityHidden(true)
        } else {
            IconTile(systemName: PlaceText.rowSymbol(for: place))
        }
    }

    @ViewBuilder
    private func liturgySection(_ card: LiturgyCard) -> some View {
        Section {
            if !card.note.isEmpty {
                Text(card.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("liturgy-confirm")
            }
            if !card.phone.isEmpty {
                Text(card.phone)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("liturgy-phone")
            }
            if !card.directory.isEmpty {
                Text(card.directory)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("liturgy-directory")
            }
            if card.found {
                ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                    liturgyLine(line)
                }
                if !card.confession.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Confession")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(card.confession)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("liturgy-confession")
                }
            } else {
                Text(card.emptyTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("liturgy-empty")
                Text(card.emptyDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            SectionTitle(text: liturgyHeading)
        }
    }

    @ViewBuilder
    private func liturgyLine(_ line: String) -> some View {
        if let parts = LiturgyLine.dayAndRest(line) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(parts.day)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 44, alignment: .leading)
                Text(parts.rest)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(line)
            .accessibilityIdentifier("liturgy-line")
        } else {
            Text(line)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("liturgy-line")
        }
    }

    private var liturgyHeading: String {
        switch ChurchMark.mark(for: place) {
        case .byzantine, .orthodox:
            return "Liturgy"
        case .latin, .chapel, .shrine:
            return "Mass"
        case nil:
            return "Services"
        }
    }

    @ViewBuilder
    private var visitBlock: some View {
        let liturgy = ChurchMark.showsLiturgy(place) ? LiturgyLookup.card(for: place) : nil
        VisitBlock(
            candidates: [liturgy?.website ?? "", place.website],
            wikidata: place.wikidata,
            phone: liturgy?.phone ?? place.phone,
            name: place.name,
            address: place.address,
            coordinate: place.coordinate,
            walking: MapFilter.pinRole(for: place) == .trailhead
        )
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
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
                    HStack(alignment: .top, spacing: 12) {
                        IconTile(systemName: "figure.hiking")
                        Text(trail.name.isEmpty ? "Unnamed hiking route" : trail.name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    TrailSketch(geometry: trail.geometry)
                        .frame(height: 140)
                        .accessibilityLabel("Trail line")
                    labeledTrailRow("Length", trail.lengthLine, identifier: "trail-length")
                    if let surface = trail.surfaceLine {
                        labeledTrailRow("Surface", surface, identifier: "trail-surface")
                    }
                    if let difficulty = trail.difficultyLine {
                        labeledTrailRow("Difficulty", difficulty, identifier: "trail-difficulty")
                    }
                    if let trailhead = trail.trailheadLine {
                        labeledTrailRow("Trailhead", trailhead, identifier: "trail-trailhead")
                    }
                    labeledTrailRow("Access", AtlasQuery.trailSentence(trail.access), identifier: "trail-access")
                }
                if let point = trail.directionsPoint {
                    VisitSection(
                        website: nil,
                        phone: "",
                        name: trail.name.isEmpty ? "Hiking route" : trail.name,
                        coordinate: point,
                        walking: true,
                        websiteIdentifier: "trail-website",
                        directionsIdentifier: "trail-directions"
                    )
                }
                Section {
                    Text(PlaceText.sourceLine(source: trail.source, sourceDate: trail.sourceDate))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    SectionTitle(text: "Source")
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.bottom, 72, for: .scrollContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .accessibilityIdentifier("trail-done")
                }
            }
        }
        .accessibilityIdentifier("trail-sheet")
    }

    private func labeledTrailRow(_ title: String, _ value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(title). \(value)")
    }
}

private struct TrailSketch: View {
    let geometry: GeoJSONGeometry

    var body: some View {
        Canvas { context, size in
            let lines = trailLines(geometry)
            guard let box = geometry.bbox, !lines.isEmpty else { return }
            let pad = 12.0
            let spanLon = max(box.maxLon - box.minLon, 1e-6)
            let spanLat = max(box.maxLat - box.minLat, 1e-6)
            func point(_ coordinate: LonLat) -> CGPoint {
                let x = pad + (coordinate.lon - box.minLon) / spanLon * (size.width - pad * 2)
                let y = pad + (box.maxLat - coordinate.lat) / spanLat * (size.height - pad * 2)
                return CGPoint(x: x, y: y)
            }
            let brown = Color(red: 0x6B / 255, green: 0x4F / 255, blue: 0x3A / 255)
            for line in lines {
                guard let first = line.first else { continue }
                var path = Path()
                path.move(to: point(first))
                for coordinate in line.dropFirst() {
                    path.addLine(to: point(coordinate))
                }
                context.stroke(path, with: .color(brown), lineWidth: 3)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
    }

    private func trailLines(_ geometry: GeoJSONGeometry) -> [[LonLat]] {
        switch geometry {
        case .lineString(let line):
            return [line]
        case .multiLineString(let lines):
            return lines
        case .polygon, .multiPolygon, .point:
            return []
        }
    }
}

#endif
