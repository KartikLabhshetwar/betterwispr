import AppKit
import SwiftUI

let size = CGSize(width: 642, height: 406)
let ink = Color(red: 0.078, green: 0.078, blue: 0.086)

struct Arrow: Shape {
    func path(in rect: CGRect) -> Path {
        let tip = CGPoint(x: 386, y: 152)
        let control = CGPoint(x: 352, y: 134)
        let angle = atan2(tip.y - control.y, tip.x - control.x)
        return Path { path in
            path.move(to: CGPoint(x: 256, y: 156))
            path.addCurve(to: tip, control1: CGPoint(x: 290, y: 128), control2: control)
            for side in [-1.0, 1.0] {
                path.move(to: tip)
                path.addLine(to: CGPoint(x: tip.x - 13 * cos(angle + side * 0.6), y: tip.y - 13 * sin(angle + side * 0.6)))
            }
        }
    }
}

struct Background: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.973, green: 0.965, blue: 0.949), Color(red: 0.929, green: 0.918, blue: 0.894)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { context, canvas in
                for x in stride(from: 9.0, to: canvas.width, by: 18) {
                    for y in stride(from: 9.0, to: canvas.height, by: 18) {
                        context.fill(Path(ellipseIn: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)), with: .color(ink.opacity(0.09)))
                    }
                }
            }
            .mask(RadialGradient(colors: [.clear, .black], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 120, endRadius: 380))
            Arrow()
                .stroke(ink.opacity(0.75), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            Text("Drag to Applications")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ink.opacity(0.5))
                .position(x: 321, y: 190)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .light)
    }
}

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift dmg-background.swift output.tiff")
}
let tiff = MainActor.assumeIsolated {
    let image = NSImage(size: size)
    for scale in [1.0, 2.0] {
        let renderer = ImageRenderer(content: Background())
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { fatalError("Could not render the background at \(scale)x") }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = size
        image.addRepresentation(bitmap)
    }
    return image.tiffRepresentation(using: .lzw, factor: 1)!
}
try tiff.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
