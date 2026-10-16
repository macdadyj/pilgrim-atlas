#if canImport(UIKit)
import SwiftUI
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

struct OnboardingView: View {
    @Environment(AtlasModel.self) private var model
    @State private var page: Int
    @State private var detailsExpanded: Bool

    init(startPage: Int, detailsOpen: Bool) {
        _page = State(initialValue: startPage)
        _detailsExpanded = State(initialValue: detailsOpen)
    }

    var body: some View {
        ZStack {
            Theme.accentGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("PILGRIM")
                        .font(.headline.weight(.heavy))
                        .tracking(2)
                    Text("Atlas")
                        .font(.headline.weight(.regular))
                        .opacity(0.85)
                    Spacer()
                    if page < 2 {
                        Button("Skip") {
                            withAnimation(.easeInOut) { page = 2 }
                            Haptics.selection()
                        }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("onboarding-skip")
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $page) {
                    introPage(
                        icon: "map.fill",
                        title: "Walk northern New Mexico",
                        body: "Santa Fe, Albuquerque, Chimayó, Taos, and the country around them, with the phone offline. Location stays on this device."
                    )
                    .tag(0)
                    introPage(
                        icon: "mountain.2.fill",
                        title: "Land, trails, and landmarks",
                        body: packBody
                    )
                    .tag(1)
                    disclaimerPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                .frame(maxHeight: .infinity)
                .onChange(of: page) { _, _ in Haptics.selection() }

                VStack(spacing: 12) {
                    if page == 2 {
                        Button("I understand") {
                            Haptics.success()
                            model.acceptDisclaimer()
                        }
                        .buttonStyle(OnboardingPrimaryStyle())
                        .accessibilityIdentifier("onboarding-understand")
                    } else {
                        Button("Continue") {
                            withAnimation(.easeInOut) { page += 1 }
                        }
                        .buttonStyle(OnboardingPrimaryStyle())
                        .accessibilityIdentifier("onboarding-continue")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.2), value: page)
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("onboarding")
    }

    private var packBody: String {
        let places = model.meta["place_count"] ?? "the packed"
        let trails = model.meta["trail_count"] ?? "packed"
        let lands = model.meta["land_count"] ?? "packed"
        return "This phone holds \(places) places, \(trails) hiking routes, and \(lands) land polygons from public datasets. Catholic worship is marked only when OpenStreetMap tags it. A polygon is not permission to enter."
    }

    private func introPage(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle().fill(.white.opacity(0.12)).frame(width: 150, height: 150)
                Circle().fill(.white.opacity(0.10)).frame(width: 110, height: 110)
                Image(systemName: icon)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: page)
            }
            .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Text(body)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var disclaimerPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Before you walk")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("A map of public datasets for Santa Fe, Albuquerque, and northern New Mexico.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                Text("This does not give you permission to enter.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
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
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.top, 4)
                } label: {
                    Text("Details")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .foregroundStyle(.white)
                .accessibilityIdentifier("onboarding-details")
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }
}

private struct OnboardingPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(Theme.accentFill)
            .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(.white))
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

#endif
