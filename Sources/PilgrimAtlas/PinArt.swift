#if canImport(UIKit)
import UIKit
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

enum PinArt {
    static let burgundy = color(0x8C, 0x2F, 0x39)
    static let gold = color(0xC6, 0xA1, 0x5B)
    static let indigo = color(0x1E, 0x2A, 0x4A)
    static let cream = color(0xF7, 0xF1, 0xE4)

    static func image(for role: PinRole, selected: Bool = false) -> UIImage {
        switch role {
        case .catholic, .sspx:
            return image(mark: .latin, selected: selected)
        case .orthodox:
            return image(mark: .orthodox, selected: selected)
        case .chapel:
            return image(mark: .chapel, selected: selected)
        case .shrine:
            return image(mark: .shrine, selected: selected)
        default:
            return badge(for: role, selected: selected)
        }
    }

    static func image(mark: ChurchMark, selected: Bool) -> UIImage {
        let side: CGFloat = 72
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            let bounds = CGRect(x: 6, y: 2, width: 60, height: 66)
            if selected {
                gold.setStroke()
                let ring = mapPin(in: bounds.insetBy(dx: -1.5, dy: -1))
                ring.lineWidth = 4
                ring.stroke()
            }
            let path = mapPin(in: bounds)
            UIColor.white.setStroke()
            path.lineWidth = 8
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.stroke()
            body(mark).setFill()
            path.fill()
            gold.setStroke()
            path.lineWidth = selected ? 3 : 1.75
            path.stroke()
            let head = bounds.width * 0.72
            let markSide = head * 0.62
            let markRect = CGRect(
                x: bounds.midX - markSide / 2,
                y: bounds.minY + head * 0.2,
                width: markSide,
                height: markSide
            )
            drawMark(mark, in: markRect)
        }
    }

    private static func badge(for role: PinRole, selected: Bool) -> UIImage {
        let side: CGFloat = 72
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            let bounds = CGRect(x: 6, y: 4, width: 60, height: 64)
            let path = shape(role, in: bounds)
            if selected {
                gold.setStroke()
                path.lineWidth = 8
                path.stroke()
            }
            UIColor.white.setStroke()
            path.lineWidth = 10
            path.stroke()
            fill(role).setFill()
            path.fill()
            stroke(role).setStroke()
            path.lineWidth = 2.5
            path.stroke()
            if role == .landmark {
                cream.setFill()
                UIBezierPath(ovalIn: CGRect(x: bounds.midX - 6, y: bounds.midY - 8, width: 12, height: 12)).fill()
            } else {
                let glyph = symbol(role)
                let iconSize = CGSize(width: 26, height: 26)
                let origin = CGPoint(x: bounds.midX - iconSize.width / 2, y: bounds.midY - iconSize.height / 2 - 4)
                glyph.draw(in: CGRect(origin: origin, size: iconSize))
            }
        }
    }

    private static func body(_ mark: ChurchMark) -> UIColor {
        switch mark {
        case .latin, .chapel, .shrine:
            return burgundy
        case .byzantine, .orthodox:
            return indigo
        }
    }

    private static func drawMark(_ mark: ChurchMark, in bounds: CGRect) {
        switch mark {
        case .latin:
            latinCross(in: bounds, color: gold)
        case .byzantine:
            threeBarCross(in: bounds, color: gold)
        case .orthodox:
            onionDome(in: bounds, color: gold)
        case .chapel:
            chapelHouse(in: bounds, color: cream, roof: gold)
        case .shrine:
            shrineMark(in: bounds, color: gold)
        }
    }

    private static func shape(_ role: PinRole, in bounds: CGRect) -> UIBezierPath {
        switch role {
        case .catholic, .chapel, .orthodox, .sspx:
            return mapPin(in: bounds)
        case .shrine:
            return diamond(in: bounds.insetBy(dx: 6, dy: 4))
        case .landmark:
            return hexagon(in: bounds.insetBy(dx: 6, dy: 8))
        case .museum:
            return UIBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 10), cornerRadius: 6)
        case .parking:
            return UIBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 12), cornerRadius: 4)
        case .viewpoint:
            return triangle(in: bounds.insetBy(dx: 8, dy: 8))
        case .worship:
            return UIBezierPath(ovalIn: bounds.insetBy(dx: 8, dy: 10))
        case .water:
            return UIBezierPath(ovalIn: bounds.insetBy(dx: 12, dy: 8))
        case .trailhead:
            return diamond(in: bounds.insetBy(dx: 10, dy: 6))
        }
    }

    private static func fill(_ role: PinRole) -> UIColor {
        switch role {
        case .catholic, .sspx: return color(0x8C, 0x2F, 0x39)
        case .orthodox: return color(0x1E, 0x2A, 0x4A)
        case .chapel: return color(0xF4, 0xEF, 0xE4)
        case .worship: return color(0x2F, 0x5F, 0x8A)
        case .shrine: return color(0x6E, 0x5A, 0x7D)
        case .viewpoint: return color(0x3E, 0x6B, 0x48)
        case .museum: return color(0x6B, 0x4F, 0x3A)
        case .parking: return color(0x1C, 0x3A, 0x5A)
        case .water: return color(0x2F, 0x6F, 0x8A)
        case .trailhead: return color(0x2F, 0x6B, 0x4A)
        case .landmark: return color(0xC4, 0x62, 0x2D)
        }
    }

    private static func stroke(_ role: PinRole) -> UIColor {
        switch role {
        case .chapel: return color(0x8C, 0x2F, 0x39)
        case .catholic, .orthodox, .sspx, .worship, .shrine, .viewpoint, .museum, .parking, .water, .trailhead, .landmark:
            return color(0x1C, 0x19, 0x15)
        }
    }

    private static func symbol(_ role: PinRole) -> UIImage {
        let name: String
        let glyph: UIColor
        switch role {
        case .catholic, .sspx:
            name = "cross.fill"
            glyph = color(0xF4, 0xEF, 0xE4)
        case .orthodox:
            name = "building.columns.fill"
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
            name = "circle.fill"
            glyph = color(0xF4, 0xEF, 0xE4)
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

    private static func latinCross(in bounds: CGRect, color: UIColor) {
        color.setFill()
        let thickness = bounds.width * 0.22
        UIBezierPath(roundedRect: CGRect(x: bounds.midX - thickness / 2, y: bounds.minY, width: thickness, height: bounds.height * 0.92), cornerRadius: 1.5).fill()
        let armY = bounds.minY + bounds.height * 0.28
        UIBezierPath(roundedRect: CGRect(x: bounds.minX, y: armY, width: bounds.width, height: thickness), cornerRadius: 1.5).fill()
    }

    private static func threeBarCross(in bounds: CGRect, color: UIColor) {
        color.setFill()
        let thickness = bounds.width * 0.16
        UIBezierPath(roundedRect: CGRect(x: bounds.midX - thickness / 2, y: bounds.minY, width: thickness, height: bounds.height), cornerRadius: 1).fill()
        let bars: [(CGFloat, CGFloat)] = [(0.08, 0.42), (0.30, 0.78), (0.72, 0.5)]
        for (yFactor, widthFactor) in bars {
            let width = bounds.width * widthFactor
            let y = bounds.minY + bounds.height * yFactor
            UIBezierPath(roundedRect: CGRect(x: bounds.midX - width / 2, y: y, width: width, height: thickness), cornerRadius: 1).fill()
        }
    }

    private static func onionDome(in bounds: CGRect, color: UIColor) {
        color.setFill()
        let domeTop = bounds.minY + bounds.height * 0.28
        let dome = UIBezierPath()
        dome.move(to: CGPoint(x: bounds.midX, y: domeTop))
        dome.addCurve(
            to: CGPoint(x: bounds.minX + bounds.width * 0.14, y: bounds.minY + bounds.height * 0.62),
            controlPoint1: CGPoint(x: bounds.minX, y: domeTop + bounds.height * 0.08),
            controlPoint2: CGPoint(x: bounds.minX, y: bounds.minY + bounds.height * 0.55)
        )
        dome.addLine(to: CGPoint(x: bounds.maxX - bounds.width * 0.14, y: bounds.minY + bounds.height * 0.62))
        dome.addCurve(
            to: CGPoint(x: bounds.midX, y: domeTop),
            controlPoint1: CGPoint(x: bounds.maxX, y: bounds.minY + bounds.height * 0.55),
            controlPoint2: CGPoint(x: bounds.maxX, y: domeTop + bounds.height * 0.08)
        )
        dome.close()
        dome.fill()
        UIBezierPath(rect: CGRect(
            x: bounds.minX + bounds.width * 0.18,
            y: bounds.minY + bounds.height * 0.58,
            width: bounds.width * 0.64,
            height: bounds.height * 0.2
        )).fill()
        latinCross(
            in: CGRect(
                x: bounds.midX - bounds.width * 0.16,
                y: bounds.minY,
                width: bounds.width * 0.32,
                height: bounds.height * 0.32
            ),
            color: color
        )
    }

    private static func chapelHouse(in bounds: CGRect, color: UIColor, roof: UIColor) {
        roof.setFill()
        let roofPath = UIBezierPath()
        roofPath.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
        roofPath.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + bounds.height * 0.38))
        roofPath.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY + bounds.height * 0.38))
        roofPath.close()
        roofPath.fill()
        color.setFill()
        UIBezierPath(rect: CGRect(x: bounds.minX + 4, y: bounds.minY + bounds.height * 0.36, width: bounds.width - 8, height: bounds.height * 0.5)).fill()
        latinCross(in: CGRect(x: bounds.midX - 5, y: bounds.minY + 2, width: 10, height: bounds.height * 0.28), color: burgundy)
    }

    private static func shrineMark(in bounds: CGRect, color: UIColor) {
        color.setFill()
        let arch = UIBezierPath()
        arch.move(to: CGPoint(x: bounds.minX + 4, y: bounds.maxY))
        arch.addLine(to: CGPoint(x: bounds.minX + 4, y: bounds.midY))
        arch.addQuadCurve(to: CGPoint(x: bounds.maxX - 4, y: bounds.midY), controlPoint: CGPoint(x: bounds.midX, y: bounds.minY))
        arch.addLine(to: CGPoint(x: bounds.maxX - 4, y: bounds.maxY))
        arch.close()
        arch.fill()
        burgundy.setFill()
        UIBezierPath(ovalIn: CGRect(x: bounds.midX - 4, y: bounds.midY, width: 8, height: 8)).fill()
    }

    /// Teardrop: the lower corners of the head meet at the point.
    private static func mapPin(in bounds: CGRect) -> UIBezierPath {
        let head = bounds.width * 0.72
        let radius = head / 2
        let center = CGPoint(x: bounds.midX, y: bounds.minY + radius)
        let path = UIBezierPath()
        // 7:30 to 4:30, the long way over 12 o'clock, then down to the point.
        path.addArc(
            withCenter: center,
            radius: radius,
            startAngle: .pi * 0.75,
            endAngle: .pi * 0.25,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
        path.close()
        return path
    }

    private static func hexagon(in bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let midY = bounds.midY
        path.move(to: CGPoint(x: bounds.minX + bounds.width * 0.25, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - bounds.width * 0.25, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: midY))
        path.addLine(to: CGPoint(x: bounds.maxX - bounds.width * 0.25, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + bounds.width * 0.25, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: midY))
        path.close()
        return path
    }

    private static func triangle(in bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
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
