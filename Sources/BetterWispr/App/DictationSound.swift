import Foundation

enum DictationSound: String {
    case finished, cancelled, attention

    static let overrideDirectory = URL.applicationSupportDirectory
        .appendingPathComponent("BetterWispr/SoundOverrides", isDirectory: true)

    var url: URL? { url(in: Self.overrideDirectory) }

    func url(in directory: URL) -> URL? {
        let file = directory.appendingPathComponent(rawValue).appendingPathExtension("wav")
        return FileManager.default.isReadableFile(atPath: file.path) ? file : nil
    }
}
