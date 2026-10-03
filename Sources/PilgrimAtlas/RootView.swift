#if canImport(UIKit)
import SwiftUI
import PilgrimAtlasCore

struct RootView: View {
    @Environment(AtlasModel.self) private var model

    var body: some View {
        if model.acceptedDisclaimer {
            MapScreen()
        } else {
            DisclaimerGate()
        }
    }
}

struct DisclaimerGate: View {
    @Environment(AtlasModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pilgrim Atlas")
                        .font(.largeTitle.bold())
                    Text("This map shows public datasets for Santa Fe, Albuquerque, and northern New Mexico. It does not give you permission to enter.")
                    Text(Copy.text("trespass"))
                    Text(Copy.text("not_a_survey"))
                    Text(Copy.text("state_trust"))
                    Text(Copy.text("closures"))
                    Text("Your location stays on this phone. Pilgrim Atlas has no account and no server of its own. Online map tiles, if you turn them on later, are a separate choice.")
                    Text(Copy.text("mass_footnote"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
