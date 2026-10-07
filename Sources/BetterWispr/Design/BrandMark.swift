import AppKit
import SwiftUI

struct BrandMark: View {
    var size: CGFloat = 34
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let tile = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        tile
            .fill(LinearGradient(
                colors: dark
                    ? [Color(red: 0.149, green: 0.149, blue: 0.165), Color(red: 0.055, green: 0.055, blue: 0.063)]
                    : [.white, Color(red: 0.945, green: 0.937, blue: 0.922)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .overlay(tile.strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
            .overlay(
                BrandGlyph()
                    .stroke(style: StrokeStyle(lineWidth: size * 0.082, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(dark ? Color(red: 0.957, green: 0.949, blue: 0.929) : Color(red: 0.078, green: 0.078, blue: 0.086))
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct BrandGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for side: CGFloat in [1, -1] {
                func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: rect.midX + side * (x - 0.5) * rect.width, y: rect.minY + y * rect.height)
                }
                path.move(to: point(0.277, 0.377))
                path.addCurve(to: point(0.384, 0.63), control1: point(0.275, 0.547), control2: point(0.324, 0.63))
                path.addCurve(to: point(0.5, 0.454), control1: point(0.454, 0.63), control2: point(0.51, 0.523))
            }
        }
    }
}

extension BrandGlyph {
    @MainActor static let menuBarImage: NSImage = {
        let tile: CGFloat = 34
        let lineWidth = tile * 0.082
        let glyph = BrandGlyph().path(in: CGRect(x: 0, y: 0, width: tile, height: tile))
        let bounds = glyph.boundingRect.insetBy(dx: -lineWidth / 2, dy: -lineWidth / 2)
        let image = NSImage(size: bounds.size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.translateBy(x: -bounds.minX, y: -bounds.minY)
            context.addPath(glyph.cgPath)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
