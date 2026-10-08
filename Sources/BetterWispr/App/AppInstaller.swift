import AppKit
import Foundation

struct AppInstaller {
    let bundleURL: URL
    let applicationsURL: URL
    let downloadsURL: URL

    static let current = AppInstaller(
        bundleURL: Bundle.main.bundleURL,
        applicationsURL: .applicationDirectory,
        downloadsURL: .downloadsDirectory
    )

    var needsMove: Bool {
        bundleURL.path.hasPrefix("/Volumes/") || bundleURL.path.contains("/AppTranslocation/") || isInDownloads
    }

    var destinationURL: URL { applicationsURL.appending(path: bundleURL.lastPathComponent) }

    private var isInDownloads: Bool {
        bundleURL.deletingLastPathComponent().path == downloadsURL.path
    }

    private var diskImageVolume: String? {
        let components = bundleURL.pathComponents
        guard components.count > 2, components[1] == "Volumes",
              (try? bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) == true
        else { return nil }
        return "/Volumes/\(components[2])"
    }

    func install() throws -> URL {
        let files = FileManager.default
        let destination = destinationURL
        if files.fileExists(atPath: destination.path) { try files.trashItem(at: destination, resultingItemURL: nil) }
        try files.copyItem(at: bundleURL, to: destination)
        let xattr = Process()
        xattr.executableURL = URL(filePath: "/usr/bin/xattr")
        xattr.arguments = ["-d", "-r", "com.apple.quarantine", destination.path]
        xattr.standardError = FileHandle.nullDevice
        try xattr.run()
        xattr.waitUntilExit()
        if isInDownloads { try? files.trashItem(at: bundleURL, resultingItemURL: nil) }
        return destination
    }

    @MainActor
    func relaunch(at url: URL) throws {
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.1; done
        [ -n "$2" ] && /usr/bin/hdiutil detach "$2" -quiet
        /usr/bin/open "$3"
        """
        let shell = Process()
        shell.executableURL = URL(filePath: "/bin/sh")
        shell.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), diskImageVolume ?? "", url.path]
        try shell.run()
        NSApplication.shared.terminate(nil)
    }
}
