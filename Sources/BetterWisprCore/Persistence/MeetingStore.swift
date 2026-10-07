import Foundation

public struct MeetingStore: Sendable {
    public let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory
            .appendingPathComponent("BetterWispr", isDirectory: true)
            .appendingPathComponent("Meetings", isDirectory: true)
    }

    private struct File: Codable {
        var version: Int
        var meeting: Meeting?
    }

    /// Returns meetings newest first; files that fail to decode or use another version are reported and left alone.
    public func load() -> (meetings: [Meeting], unreadable: [URL]) {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return ([], []) }
        var meetings: [Meeting] = []
        var unreadable: [URL] = []
        for url in urls where url.pathExtension == "json" {
            if let file = try? JSONDecoder().decode(File.self, from: Data(contentsOf: url)), file.version == 1, let meeting = file.meeting {
                meetings.append(meeting)
            } else {
                unreadable.append(url)
            }
        }
        return (meetings.sorted { $0.createdAt > $1.createdAt }, unreadable.sorted { $0.lastPathComponent < $1.lastPathComponent })
    }

    public func save(_ meeting: Meeting) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = url(for: meeting.id)
        try encoder.encode(File(version: 1, meeting: meeting)).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func delete(id: UUID) throws {
        let url = url(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
