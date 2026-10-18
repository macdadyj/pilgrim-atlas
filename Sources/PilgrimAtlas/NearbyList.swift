#if canImport(UIKit)
import SwiftUI
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

struct NearbyListSheet: View {
    @Environment(AtlasModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var origin: LonLat {
        model.userCoordinate ?? model.summaryPoint
    }

    private var rows: [(place: PlaceRecord, meters: Int)] {
        model.places
            .filter { MapFilter.includeInLists($0, filter: model.filter) }
            .map { place in
                (place: place, meters: Int(Geometry.haversineMeters(origin, place.coordinate).rounded()))
            }
            .sorted { $0.meters < $1.meters }
            .prefix(40)
            .map { $0 }
    }

    private var upcoming: UpcomingLiturgy? {
        MassSoon.next(places: model.places, origin: origin)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let upcoming {
                        Button {
                            open(upcoming.placeID)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(upcoming.placeName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(upcoming.line)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(PlaceText.distanceLabel(upcoming.meters))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("next-mass")
                    } else {
                        Text("No verified Mass within 25 miles. Times appear only after a hand-checked reading or the parish page.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("next-mass-empty")
                    }
                } header: {
                    SectionTitle(text: "Next verified Mass")
                }
                Section {
                    if rows.isEmpty {
                        Text("Nothing in this filter is loaded here yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(rows, id: \.place.id) { row in
                        Button {
                            open(row.place.id)
                        } label: {
                            HStack(spacing: 12) {
                                IconTile(systemName: PlaceText.rowSymbol(for: row.place))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.place.name)
                                        .foregroundStyle(.primary)
                                    Text(MapFilter.listKind(for: row.place).label)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Text(PlaceText.distanceLabel(row.meters))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("nearby-row-\(row.place.id)")
                    }
                } header: {
                    SectionTitle(text: "Nearby")
                }
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("nearby-done")
                }
            }
        }
        .accessibilityIdentifier("nearby-sheet")
    }

    private func open(_ id: Int) {
        guard let place = model.places.first(where: { $0.id == id }) else { return }
        model.showNearby = false
        model.openPlace(place)
    }
}

#endif
