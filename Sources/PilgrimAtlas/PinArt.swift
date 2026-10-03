#if canImport(UIKit)
import UIKit
import PilgrimAtlasCore

enum PinArt {
    static func image(for role: PinRole) -> UIImage {
        let side: CGFloat = 72
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            let bounds = CGRect(x: 8, y: 6, width: 56, height: 60)
            let path = shape(role, in: bounds)
            UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1).setStroke()
            path.lineWidth = 7
            path.lineJoinStyle = .round
            path.stroke()
            fill(role).setFill()
            path.fill()
            stroke(role).setStroke()
            path.lineWidth = 2
            path.stroke()
            let glyph = symbol(role)
            let iconSize = CGSize(width: 28, height: 28)
            let origin = CGPoint(x: bounds.midX - iconSize.width / 2, y: bounds.midY - iconSize.height / 2 - 1)
            glyph.draw(in: CGRect(origin: origin, size: iconSize))
        }
    }

    private static func shape(_ role: PinRole, in bounds: CGRect) -> UIBezierPath {
        switch role {
        case .catholic, .chapel:
            return shield(in: bounds)
        case .shrine:
            return diamond(in: bounds.insetBy(dx: 4, dy: 2))
        case .landmark, .museum, .parking:
            return UIBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 8), cornerRadius: 10)
        case .worship, .viewpoint, .water, .trailhead:
            return UIBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 6))
        }
    }

    private static func fill(_ role: PinRole) -> UIColor {
        switch role {
        case .catholic: return color(0x8C, 0x2F, 0x39)
        case .chapel: return color(0xF4, 0xEF, 0xE4)
        case .worship: return color(0x2F, 0x5F, 0x8A)
        case .shrine: return color(0x6E, 0x5A, 0x7D)
        case .viewpoint: return color(0x3E, 0x6B, 0x48)
        case .museum: return color(0x6B, 0x4F, 0x3A)
        case .parking: return color(0x1C, 0x3A, 0x5A)
        case .water: return color(0x2F, 0x6F, 0x8A)
        case .trailhead: return color(0x2F, 0x6B, 0x4A)
        case .landmark: return color(0x8C, 0x7B, 0x64)
        }
    }

    private static func stroke(_ role: PinRole) -> UIColor {
        switch role {
        case .chapel: return color(0x8C, 0x2F, 0x39)
        case .catholic, .worship, .shrine, .viewpoint, .museum, .parking, .water, .trailhead, .landmark:
            return color(0x1C, 0x19, 0x15)
        }
    }

    private static func symbol(_ role: PinRole) -> UIImage {
        let name: String
        let glyph: UIColor
        switch role {
        case .catholic:
            name = "cross.fill"
            glyph = color(0xF4, 0xEF, 0xE4)
        case .chapel:
            name = "cross.fill"
            glyph = color(0x8C, 0x2F, 0x39)
        case .worship:
            name = "building.columns.fill"
            glyph = color(0xF4, 0xEF, 0xE4)
        case .shrine:
            name = "figure.stand"
            glyph = color(0xF4, 0xEF, 0xE4)
        case .viewpoint:
            name = "binoculars.fill"
            glyph = color(0xF4, 0xEF, 0xE4)
        case .museum:
            name = "building.columns.fill"
            glyph = color(0xF4, 0xEF, 0xE4)
        case .parking:
            name = "parkingsign"
            glyph = color(0xF4, 0xEF, 0xE4)
        case .water:
            name = "drop.fill"
            glyph = color(0xF4, 0xEF, 0xE4)
        case .trailhead:
            name = "figure.hiking"
            glyph = color(0xF4, 0xEF, 0xE4)
        case .landmark:
            name = "star.fill"
            glyph = color(0x1C, 0x19, 0x15)
        }
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        if let image = UIImage(systemName: name, withConfiguration: config)?.withTintColor(glyph, renderingMode: .alwaysOriginal) {
            return image
        }
        return fallbackCross(glyph)
    }

    private static func fallbackCross(_ color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28))
        return renderer.image { _ in
            color.setFill()
            UIBezierPath(rect: CGRect(x: 11, y: 2, width: 6, height: 24)).fill()
            UIBezierPath(rect: CGRect(x: 2, y: 11, width: 24, height: 6)).fill()
        }
    }

    private static func shield(in bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY + 6))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + 6))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
        path.addQuadCurve(to: CGPoint(x: bounds.midX, y: bounds.maxY), controlPoint: CGPoint(x: bounds.maxX, y: bounds.maxY - 8))
        path.addQuadCurve(to: CGPoint(x: bounds.minX, y: bounds.midY), controlPoint: CGPoint(x: bounds.minX, y: bounds.maxY - 8))
        path.close()
        return path
    }

    private static func diamond(in bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.midY))
        path.close()
        return path
    }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }
}

#endif
