#if canImport(UIKit)
import SwiftUI
import PilgrimAtlasCore

struct RootView: View {
    @Environment(AtlasModel.self) private var model

    var body: some View {
        if model.acceptedDisclaimer {
            MapScreen()
        } else {
            DisclaimerGate(detailsOpen: model.disclaimerDetailsOpen)
        }
    }
}

struct DisclaimerGate: View {
    @Environment(AtlasModel.self) private var model
    @State private var detailsExpanded: Bool

    init(detailsOpen: Bool) {
        _detailsExpanded = State(initialValue: detailsOpen)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("A map of public datasets for Santa Fe, Albuquerque, and northern New Mexico.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("This does not give you permission to enter.")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.statusAmber.opacity(0.16), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                                .stroke(Theme.statusAmber.opacity(0.06), lineWidth: 1)
                        )
                    DisclosureGroup(isExpanded: $detailsExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(Copy.text("trespass"))
                            Text(Copy.text("not_a_survey"))
                            Text(Copy.text("state_trust"))
                            Text(Copy.text("closures"))
                            Text("Your location stays on this phone. Pilgrim Atlas has no account and no server of its own. Online map tiles, if you turn them on later, are a separate choice.")
                            Text(Copy.text("mass_footnote"))
                        }
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.top, 4)
                    } label: {
                        Text("Details")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    Button("I understand") { model.acceptDisclaimer() }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 4)
                }
                .padding(Theme.screenPadding)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Before you walk")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#endif
