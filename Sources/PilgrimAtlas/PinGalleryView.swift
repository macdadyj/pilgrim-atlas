#if canImport(UIKit)
import SwiftUI
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

/// Every church pin at rest and selected, so a screenshot can check the drawing.
struct PinGalleryView: View {
    private struct Row: Identifiable {
        var mark: ChurchMark
        var title: String
        var id: String { mark.rawValue }
    }

    private let rows = [
        Row(mark: .latin, title: "Latin Catholic"),
        Row(mark: .byzantine, title: "Byzantine Catholic"),
        Row(mark: .orthodox, title: "Orthodox"),
        Row(mark: .chapel, title: "Chapel"),
        Row(mark: .shrine, title: "Shrine"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(rows) { row in
                        HStack(spacing: 16) {
                            pin(row.mark, selected: false, title: row.title)
                            pin(row.mark, selected: true, title: "\(row.title), selected")
                            Text(row.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .accessibilityElement(children: .contain)
                    }
                } header: {
                    Text("Church pins")
                }
            }
            .navigationTitle("Pins")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("pin-gallery")
    }

    private func pin(_ mark: ChurchMark, selected: Bool, title: String) -> some View {
        Image(uiImage: PinArt.image(mark: mark, selected: selected))
            .resizable()
            .interpolation(.high)
            .frame(width: 64, height: 64)
            .accessibilityLabel(title)
            .accessibilityIdentifier(selected ? "pin-\(mark.rawValue)-selected" : "pin-\(mark.rawValue)")
    }
}

#endif
