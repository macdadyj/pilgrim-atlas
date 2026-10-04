#if canImport(UIKit)
import SwiftUI
import UIKit
import PilgrimAtlasCore

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

struct IconTile: View {
    var systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
