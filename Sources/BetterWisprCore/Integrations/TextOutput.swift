import AppKit
import ApplicationServices

public enum OutputResult: Sendable, Equatable {
    case copied
    case copiedForManualPaste
    case pasted(into: String)
}

@MainActor
public protocol TextOutputIntegration {
    func deliver(_ text: String, to target: NSRunningApplication?) async throws -> OutputResult
}

@MainActor
public struct ClipboardIntegration: TextOutputIntegration {
    public init() {}
    public func deliver(_ text: String, to target: NSRunningApplication?) async throws -> OutputResult {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else { throw OutputError.clipboard }
        return .copied
    }
}

@MainActor
public struct FocusedAppIntegration: TextOutputIntegration {
    public let keepsCopy: Bool
    public init(keepsCopy: Bool) { self.keepsCopy = keepsCopy }
    public func deliver(_ text: String, to target: NSRunningApplication?) async throws -> OutputResult {
        // Never steal focus or paste into an app the user switched to while decoding.
        guard let target, !target.isTerminated,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier,
              AXIsProcessTrusted() else {
            _ = try await ClipboardIntegration().deliver(text, to: nil)
            return .copiedForManualPaste
        }
        let pasteboard = NSPasteboard.general
        let previousItems: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []
        _ = try await ClipboardIntegration().deliver(text, to: target)
        let ourChange = pasteboard.changeCount
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return .copiedForManualPaste
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(target.processIdentifier)
        up.postToPid(target.processIdentifier)
        if !keepsCopy {
            // ponytail: applications expose no paste acknowledgement; allow 750 ms before restoring.
            try? await Task.sleep(for: .milliseconds(750))
            if pasteboard.changeCount == ourChange {
                pasteboard.clearContents()
                if !previousItems.isEmpty { _ = pasteboard.writeObjects(previousItems) }
            }
        }
        return .pasted(into: target.localizedName ?? "your app")
    }
}

public enum OutputError: LocalizedError {
    case clipboard
    public var errorDescription: String? { "Could not write to the clipboard. Your transcript is still available in BetterWispr." }
}
