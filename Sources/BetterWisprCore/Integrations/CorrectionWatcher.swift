import AppKit
import ApplicationServices
import Carbon

/// Watches the field that received a dictation and reports word fixes the user types there.
@MainActor
public final class CorrectionWatcher {
    private var task: Task<Void, Never>?

    public init() {}

    public func watch(_ inserted: String, in app: NSRunningApplication, onCorrections: @escaping @MainActor ([LearnedCorrection]) -> Void) {
        stop()
        guard AXIsProcessTrusted(), !inserted.isEmpty else { return }
        let pid = app.processIdentifier
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let field = Self.focusedField(pid: pid) else { return }
            var inserted = inserted
            var baseline: String?
            var settled = SettledText("")
            for _ in 0..<60 {
                guard !Task.isCancelled, !IsSecureEventInputEnabled(), let value = Self.value(of: field), value.count <= 100_000 else { break }
                if let base = baseline {
                    if let text = settled.observe(value), text != base, let edited = Self.edit(of: inserted, from: base, to: text) {
                        let found = CorrectionLearner.corrections(from: inserted, to: edited)
                        if !found.isEmpty { onCorrections(found) }
                        inserted = edited
                        baseline = text
                    }
                    if value.isEmpty { break }
                } else if value.contains(inserted) {
                    baseline = value
                    settled = SettledText(value)
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
            if self?.task?.isCancelled == false { self?.task = nil }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    /// Returns the inserted text with the user's change applied, or nil when the change falls outside it.
    nonisolated static func edit(of inserted: String, from before: String, to after: String) -> String? {
        guard let range = before.range(of: inserted, options: .backwards) else { return nil }
        let old = Array(before), new = Array(after)
        var prefix = 0
        while prefix < min(old.count, new.count), old[prefix] == new[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(old.count, new.count) - prefix, old[old.count - 1 - suffix] == new[new.count - 1 - suffix] { suffix += 1 }
        let start = before.distance(from: before.startIndex, to: range.lowerBound)
        let end = before.distance(from: before.startIndex, to: range.upperBound)
        guard prefix >= start, old.count - suffix <= end, old.count - suffix > prefix else { return nil }
        let local = Array(inserted)
        return String(local[..<(prefix - start)]) + String(new[prefix..<(new.count - suffix)]) + String(local[(old.count - suffix - start)...])
    }

    private static func focusedField(pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let field = focused as! AXUIElement
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(field, kAXSubroleAttribute as CFString, &subrole)
        return subrole as? String == kAXSecureTextFieldSubrole ? nil : field
    }

    private static func value(of field: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(field, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}

/// Decides when text in a field polled every half second is final enough to learn from.
struct SettledText {
    private var last: String
    private var polls = 1

    init(_ value: String) { last = value }

    /// Returns text left unchanged for two seconds, or the text that was in the field for at least half a second before it emptied.
    mutating func observe(_ value: String) -> String? {
        if value.isEmpty { return polls >= 2 ? last : nil }
        if value == last { polls += 1 } else { last = value; polls = 1 }
        return polls == 5 ? value : nil
    }
}
