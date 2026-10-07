import AppKit
import BetterWisprCore
import SwiftUI

struct Toast {
    let title: String
    let message: String
    let systemImage: String
    var isError = false
}

extension Toast {
    init(_ result: OutputResult) {
        switch result {
        case .copied: self.init(title: "Copied", message: "Ready to paste anywhere.", systemImage: "doc.on.doc")
        case .copiedForManualPaste: self.init(title: "Copied", message: "Paste into your app with ⌘V.", systemImage: "doc.on.clipboard")
        case .pasted(let app): self.init(title: "Pasted", message: "Sent to \(app).", systemImage: "text.cursor")
        }
    }

    init(failure title: String, _ error: Error) {
        self.init(title: title, message: error.localizedDescription, systemImage: "exclamationmark.triangle.fill", isError: true)
    }
}

@MainActor
final class ToastWindow {
    static let shared = ToastWindow()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ toast: Toast) {
        dismiss(animated: false)

        let hostingView = NSHostingView(rootView: ToastView(toast: toast))
        let size = hostingView.fittingSize
        hostingView.sizingOptions = []
        hostingView.setFrameSize(size)

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView

        guard let screen = NSApp.keyWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height)
        let slide: CGFloat = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 10
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y + slide))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(origin)
        }
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: "\(toast.title). \(toast.message)",
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(toast.isError ? 4 : 2.5))
            guard !Task.isCancelled else { return }
            self?.dismiss(animated: true)
        }
    }

    private func dismiss(animated: Bool) {
        dismissTask?.cancel()
        dismissTask = nil
        guard let panel else { return }
        self.panel = nil
        guard animated else { panel.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in panel.orderOut(nil) }
        }
    }
}

private struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(toast.isError ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(toast.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: 280, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .modifier(ToastSurface())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

private struct ToastSurface: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        } else {
            content
                .background(Color(nsColor: .windowBackgroundColor), in: shape)
                .overlay(shape.stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }
}
