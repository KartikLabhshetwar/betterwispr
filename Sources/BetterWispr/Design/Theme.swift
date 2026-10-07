import SwiftUI

struct SymbolTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct KeyboardHint: View {
    var body: some View {
        Text("⌥ Space")
            .foregroundStyle(.secondary)
            .accessibilityLabel("Option Space")
    }
}

struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        LabeledContent {
            if granted {
                Label {
                    Text("Allowed")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                .foregroundStyle(.secondary)
            } else {
                Button("Allow…", action: action)
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }
}

func durationLabel(_ duration: TimeInterval) -> String {
    let seconds = max(0, Int(duration))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}
