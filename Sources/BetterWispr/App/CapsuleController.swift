import AppKit
import Observation
import SwiftUI

private final class RecordingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor @Observable
final class CapsuleHover {
    var isHovering = false
}

private final class CapsuleHostingView: NSHostingView<CapsuleView> {
    let hover: CapsuleHover

    init(model: AppModel, hover: CapsuleHover) {
        self.hover = hover
        super.init(rootView: CapsuleView(model: model, hover: hover))
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    @MainActor @preconcurrency required init(rootView: CapsuleView) { fatalError("init(rootView:) is unavailable") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseMoved(with event: NSEvent) { track(event) }
    override func mouseEntered(with event: NSEvent) { track(event) }
    override func mouseExited(with event: NSEvent) { hover.isHovering = false }

    private func track(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let fromBottom = isFlipped ? bounds.maxY - point.y : point.y
        let inside = abs(point.x - bounds.midX) < 80 && fromBottom < 52
        if hover.isHovering != inside { hover.isHovering = inside }
    }
}

@MainActor
final class CapsuleController {
    private let panel: NSPanel
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        panel = RecordingPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 160),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.isReleasedWhenClosed = false
        panel.contentView = CapsuleHostingView(model: model, hover: CapsuleHover())
        NotificationCenter.default.addObserver(self, selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reposition),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    func update() {
        if model.settings.showCapsule || model.isBusy || model.failure != nil { show() }
        else { panel.orderOut(nil) }
    }

    func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    @objc private func reposition() {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: frame.midX - 220, y: frame.minY + 12))
    }

    func close() {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        panel.close()
    }
}
