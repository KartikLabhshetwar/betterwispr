import Foundation

public enum CleanupLevel: String, Codable, CaseIterable, Sendable {
    case none, light, medium
}

public enum StyleContext: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case personal, work, email, other

    public var tones: [StyleTone] { self == .personal ? [.formal, .casual, .veryCasual] : [.formal, .casual, .excited] }
}

public enum StyleTone: String, Codable, CaseIterable, Sendable {
    case formal, casual, veryCasual, excited
}

public enum AppCategory: String, CaseIterable, Sendable {
    case aiPrompts, work, personal, documents, email, other

    static let registry: [String: AppCategory] = [
        "com.openai.chat": .aiPrompts, "com.openai.codex": .aiPrompts, "com.anthropic.claudefordesktop": .aiPrompts,
        "com.todesktop.230313mzl4w4u92": .aiPrompts, "com.exafunction.windsurf": .aiPrompts, "ai.perplexity.mac": .aiPrompts,
        "com.tinyspeck.slackmacgap": .work, "com.microsoft.teams2": .work, "com.microsoft.teams": .work,
        "us.zoom.xos": .work, "Cisco-Systems.Spark": .work, "Mattermost.Desktop": .work,
        "net.whatsapp.WhatsApp": .personal, "desktop.WhatsApp": .personal, "ru.keepcoder.Telegram": .personal,
        "org.telegram.desktop": .personal, "com.hnc.Discord": .personal, "com.apple.MobileSMS": .personal,
        "org.whispersystems.signal-desktop": .personal, "com.facebook.archon": .personal,
        "com.apple.Notes": .documents, "com.apple.iWork.Pages": .documents, "com.microsoft.Word": .documents,
        "notion.id": .documents, "md.obsidian": .documents, "com.apple.TextEdit": .documents, "net.shinyfrog.bear": .documents,
        "com.apple.mail": .email, "com.microsoft.Outlook": .email, "com.superhuman.electron": .email,
        "com.readdle.SparkDesktop": .email, "com.readdle.smartemail-Mac": .email, "com.mimestream.Mimestream": .email,
        "it.bloop.airmail2": .email, "org.mozilla.thunderbird": .email,
    ]

    /// Browsers and unknown apps are `other` because the website in use is not inspected.
    public init(bundleID: String?) {
        self = bundleID.flatMap { Self.registry[$0] } ?? .other
    }

    public var style: StyleContext {
        switch self {
        case .personal: .personal
        case .work: .work
        case .email: .email
        case .aiPrompts, .documents, .other: .other
        }
    }
}
