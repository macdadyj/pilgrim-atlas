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
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pilgrim Atlas")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                    Text("A map of public datasets for Santa Fe, Albuquerque, and northern New Mexico.")
                        .font(.title3)
                        .foregroundStyle(.primary)
                    Text("This does not give you permission to enter.")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary, lineWidth: 1.5))
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
                        .padding(.top, 8)
                    } label: {
                        Text("Details")
                    }
                    .font(.body)
                    .foregroundStyle(.primary)
                }
                .padding()
            }
            .navigationTitle("Before you walk")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("I understand") { model.acceptDisclaimer() }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

#endif
