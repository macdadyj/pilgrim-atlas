#if canImport(UIKit)
import SwiftUI
import UIKit
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

/// LOJO-shaped chrome. Cream and ink stay on the map. Screens use system surfaces.
enum Theme {
    static let accentFill = Color(red: 0x8C / 255, green: 0x2F / 255, blue: 0x39 / 255)
    static let control = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0xE7 / 255, green: 0xA8 / 255, blue: 0xA0 / 255, alpha: 1)
        }
        return UIColor(red: 0x8C / 255, green: 0x2F / 255, blue: 0x39 / 255, alpha: 1)
    })
    static let partner = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0xC4 / 255, green: 0x62 / 255, blue: 0x2D / 255, alpha: 1)
        }
        return UIColor(red: 0x3A / 255, green: 0x22 / 255, blue: 0x18 / 255, alpha: 1)
    })
    static let statusOpen = Color(red: 0x29 / 255, green: 0xB8 / 255, blue: 0x73 / 255)
    static let statusClosed = Color(red: 0xE6 / 255, green: 0x45 / 255, blue: 0x40 / 255)
    static let statusAmber = Color(red: 0xF2 / 255, green: 0x9E / 255, blue: 0x1A / 255)
    static let mapInk = Color(red: 0x1C / 255, green: 0x19 / 255, blue: 0x15 / 255)
    static let mapCream = Color(red: 0xF4 / 255, green: 0xEF / 255, blue: 0xE4 / 255)
    static let hairline = Color.primary.opacity(0.06)
    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 14
    static let screenPadding: CGFloat = 16

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentFill, partner],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func hoursMark(_ reading: HoursReading) -> (StatusMark.Kind, String) {
        switch reading {
        case .none:
            return (.unknown, "Unknown")
        case .notAClock:
            return (.disagree, "Hours disagree")
        case .clock(let openNow):
            return openNow ? (.open, "Open now") : (.closed, "Closed now")
        }
    }
}

/// One tile color per symbol, so list rows are not all the same burgundy square.
enum TilePalette {
    static func colors(for systemImage: String) -> [Color] {
        switch systemImage {
        case "cross.fill", "cross":
            return [Color(red: 0x8C / 255, green: 0x2F / 255, blue: 0x39 / 255), Color(red: 0x3A / 255, green: 0x22 / 255, blue: 0x18 / 255)]
        case "figure.hiking":
            return [Color(red: 0x6B / 255, green: 0x4F / 255, blue: 0x3A / 255), Color(red: 0x3A / 255, green: 0x22 / 255, blue: 0x18 / 255)]
        case "tree.fill", "leaf.fill":
            return [Color(red: 0x1F / 255, green: 0x7A / 255, blue: 0x3A / 255), Color(red: 0x14 / 255, green: 0x4A / 255, blue: 0x28 / 255)]
        case "drop.fill":
            return [Color(red: 0x1F / 255, green: 0x6F / 255, blue: 0x8A / 255), Color(red: 0x14 / 255, green: 0x3A / 255, blue: 0x55 / 255)]
        case "mountain.2", "mountain.2.fill":
            return [Color(red: 0x5C / 255, green: 0x6B / 255, blue: 0x73 / 255), Color(red: 0x2C / 255, green: 0x33 / 255, blue: 0x38 / 255)]
        case "eye.fill", "binoculars":
            return [Color(red: 0xC4 / 255, green: 0x62 / 255, blue: 0x2D / 255), Color(red: 0x8C / 255, green: 0x3E / 255, blue: 0x16 / 255)]
        case "fork.knife":
            return [Color(red: 0xC4 / 255, green: 0x8A / 255, blue: 0x12 / 255), Color(red: 0x8C / 255, green: 0x5A / 255, blue: 0x10 / 255)]
        case "clock", "clock.fill":
            return [Color(red: 0x2F / 255, green: 0x8F / 255, blue: 0x7A / 255), Color(red: 0x1A / 255, green: 0x55 / 255, blue: 0x48 / 255)]
        case "building.2", "building.columns", "building.columns.fill":
            return [Color(red: 0x3D / 255, green: 0x5A / 255, blue: 0x73 / 255), Color(red: 0x24 / 255, green: 0x34 / 255, blue: 0x44 / 255)]
        case "map", "square.grid.3x3", "globe":
            return [Color(red: 0xE0 / 255, green: 0x6A / 255, blue: 0x1F / 255), Color(red: 0x8C / 255, green: 0x3E / 255, blue: 0x12 / 255)]
        case "hexagon.fill", "diamond.fill":
            return [Color(red: 0xC4 / 255, green: 0x62 / 255, blue: 0x2D / 255), Color(red: 0x6B / 255, green: 0x3A / 255, blue: 0x1F / 255)]
        case "parkingsign":
            return [Color(red: 0x1F / 255, green: 0x6F / 255, blue: 0x8A / 255), Color(red: 0x14 / 255, green: 0x40 / 255, blue: 0x55 / 255)]
        case "doc.text", "info.circle", "xmark":
            return [Theme.accentFill, Theme.partner]
        default:
            return [Theme.accentFill, Theme.partner]
        }
    }
}

struct IconTile: View {
    var systemName: String
    var colors: [Color]? = nil

    var body: some View {
        let palette = colors ?? TilePalette.colors(for: systemName)
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

struct SectionTitle: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusMark: View {
    enum Kind {
        case open
        case closed
        case disagree
        case unknown
    }

    var kind: Kind
    var title: String

    var body: some View {
        HStack(spacing: 8) {
            mark
                .frame(width: 14, height: 14)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var mark: some View {
        switch kind {
        case .open:
            Circle().fill(Theme.statusOpen)
        case .closed:
            Circle().stroke(Theme.statusClosed, lineWidth: 2)
        case .disagree, .unknown:
            Circle()
                .trim(from: 0.08, to: 0.58)
                .stroke(Theme.statusAmber, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct Chip: View {
    var title: String
    var on: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(on ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background {
                    ZStack {
                        Capsule().fill(.regularMaterial)
                        Capsule().fill(on ? Theme.accentFill : Theme.control.opacity(0.12))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chip-\(title)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct IconChip: View {
    var title: String
    var systemImage: String
    var on: Bool
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(on ? Color.white : Color.primary)
                .frame(width: 44, height: 44)
                .background {
                    ZStack {
                        Circle().fill(.regularMaterial)
                        Circle().fill(on ? Theme.accentFill : Theme.control.opacity(0.12))
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
        .accessibilityLabel(title)
        .accessibilityIdentifier("chip-\(title)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.control)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                Theme.control.opacity(0.12),
                in: RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Match iPhone"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

struct EmptyStateCard: View {
    var systemImage: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.accentGradient)
                .symbolEffect(.pulse, options: .repeating, isActive: false)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .fieldCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("empty-state")
    }
}

struct FieldCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.screenPadding)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func fieldCard() -> some View {
        modifier(FieldCard())
    }

    func pilgrimSheet() -> some View {
        presentationDetents([.medium, .large, .height(360)])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
    }
}

#endif
