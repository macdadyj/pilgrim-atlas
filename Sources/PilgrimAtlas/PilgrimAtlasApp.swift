#if canImport(UIKit)
import SwiftUI

@main
struct PilgrimAtlasApp: App {
    @State private var model = AtlasModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

#endif
