#if canImport(UIKit)
import SwiftUI
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

enum AppTab: String, Hashable {
    case map
    case search
    case settings
}

struct RootView: View {
    @Environment(AtlasModel.self) private var model
    @AppStorage("pilgrim.appearance") private var appearanceRaw = AppearanceChoice.system.rawValue

    var body: some View {
        Group {
            if model.launch.showPins {
                PinGalleryView()
            } else if model.acceptedDisclaimer {
                tabs
            } else {
                OnboardingView(startPage: model.onboardingPage, detailsOpen: model.disclaimerDetailsOpen)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.acceptedDisclaimer)
        .preferredColorScheme(resolvedScheme)
        .tint(Theme.control)
    }

    private var tabs: some View {
        @Bindable var model = model
        return TabView(selection: $model.selectedTab) {
            MapScreen()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(AppTab.map)
                .accessibilityIdentifier("tab-map")

            SearchSheet()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)
                .accessibilityIdentifier("tab-search")

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
                .accessibilityIdentifier("tab-settings")
        }
        .sheet(isPresented: $model.showFilters) {
            FilterSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Online tiles", isPresented: $model.pendingOnlineConfirm) {
            Button("Keep offline") { model.onlineTiles = false }
                .accessibilityIdentifier("online-tiles-keep-offline")
            Button("Use OpenFreeMap") { model.onlineTiles = true }
                .accessibilityIdentifier("online-tiles-use")
        } message: {
            Text("OpenFreeMap will see this phone's IP address and the map tiles it requests. That is an approximate location. Pilgrim Atlas still does not upload your GPS position, and it does not run a server.")
        }
    }

    private var resolvedScheme: ColorScheme? {
        if let debug = model.launch.appearance {
            return debug == .light ? .light : .dark
        }
        return AppearanceChoice(rawValue: appearanceRaw)?.colorScheme
    }
}

#endif
