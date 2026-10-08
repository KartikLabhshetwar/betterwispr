import Darwin
import Foundation

public enum NotesCLI: String, Codable, CaseIterable, Sendable {
    case claudeCode, codex

    public var name: String { self == .claudeCode ? "Claude Code" : "Codex" }
    public var loginCommand: String { self == .claudeCode ? "claude auth login" : "codex login" }
    private var command: String { self == .claudeCode ? "claude" : "codex" }

    public var executable: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
            + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        return paths.filter { $0.hasPrefix("/") }.map { URL(fileURLWithPath: $0).appendingPathComponent(command) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}

struct CLINotesModel: NotesLanguageModel {
    let cli: NotesCLI
    let model: String
    var instructions = NotesWriter.instructions

    func respond(to prompt: String) async throws -> String {
        try await response(to: prompt).text
    }

    private func response(to prompt: String) async throws -> (text: String, modelName: String) {
        guard let executable = cli.executable else {
            throw MeetingNotesError.unavailable("Install \(cli.name), then sign in with \(cli.loginCommand) in Terminal.")
        }
        // Use the CLI's login, never extract or store its OAuth credentials in BetterWispr.
        if cli == .claudeCode {
            let status = try await Self.run(executable, arguments: ["auth", "status"], input: "", cli: cli)
            guard let auth = try? JSONDecoder().decode(ClaudeAuth.self, from: Data(status.utf8)),
                  auth.loggedIn, auth.authMethod == "claude.ai" else {
                throw MeetingNotesError.unavailable("Sign in to your Claude subscription with claude auth login in Terminal.")
            }
        }
        let arguments: [String]
        switch cli {
        case .claudeCode:
            arguments = ["--print", "--output-format", "json", "--no-session-persistence", "--safe-mode",
                         "--tools", "", "--strict-mcp-config", "--disable-slash-commands",
                         "--system-prompt", instructions]
        case .codex:
            arguments = ["--no-daemon", "exec", "--ignore-user-config", "--skip-git-repo-check", "--ephemeral",
                         "--sandbox", "read-only", "--color", "never", "-c", "approval_policy=\"never\"",
                         "-c", "forced_login_method=\"chatgpt\"", "-c", "project_doc_max_bytes=0",
                         "-c", "web_search=\"disabled\"", "-c", "history.persistence=\"none\"",
                         "--disable", "shell_tool", "--disable", "apps", "--disable", "plugins",
                         "--disable", "multi_agent", "--disable", "hooks", "--disable", "skill_search"]
        }
        let chosen = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard chosen.count <= 200, !chosen.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw MeetingNotesError.unavailable("Enter a model ID of at most 200 characters without control characters.")
        }
        let output = try await Self.run(executable, arguments: arguments + (chosen.isEmpty ? [] : ["--model", chosen]),
                                        input: "\(instructions)\n\n\(prompt)", cli: cli, finalMessage: cli == .codex)
        if cli == .claudeCode {
            guard let result = try? JSONDecoder().decode(ClaudeResult.self, from: Data(output.utf8)),
                  !result.is_error, let text = result.result, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw Self.failure(cli)
            }
            let actual = result.modelUsage?.keys.sorted().joined(separator: ", ") ?? ""
            return (text, "\(cli.name) · \(actual.isEmpty ? chosen : actual)")
        }
        return (output, "\(cli.name) · \(chosen)")
    }

    func draft(_ prompt: String) async throws -> NotesDraft {
        let response = try await response(to: "\(prompt)\n\n\(NotesDraft.fields)")
        var draft = try NotesDraft.decode(response.text)
        draft.generatedWith = response.modelName
        return draft
    }

    private struct ClaudeAuth: Decodable { var loggedIn: Bool; var authMethod: String? }
    private struct ClaudeResult: Decodable {
        struct Usage: Decodable {}
        var is_error: Bool
        var result: String?
        var modelUsage: [String: Usage]?
    }

    private static func failure(_ cli: NotesCLI) -> MeetingNotesError {
        .unavailable("\(cli.name) couldn’t write notes. Update the CLI, check your subscription limits and model, and sign in with \(cli.loginCommand) in Terminal. Your meeting is still saved.")
    }

    /// File-backed stdio avoids pipe deadlocks. All Process access stays on the main actor;
    /// waiting suspends, and cancellation terminates the child before deleting its private files.
    @MainActor
    static func run(_ executable: URL, arguments: [String], input: String, cli: NotesCLI,
                    finalMessage: Bool = false, timeout: Duration = .seconds(600),
                    until: (@MainActor (String) -> Bool)? = nil) async throws -> String {
        try Task.checkCancellation()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("betterwispr-notes-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputURL = directory.appendingPathComponent("input")
        let outputURL = directory.appendingPathComponent("output")
        let finalURL = directory.appendingPathComponent("reply")
        try Data(input.utf8).write(to: inputURL, options: .atomic)
        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let stdin = try FileHandle(forReadingFrom: inputURL)
        let stdout = try FileHandle(forWritingTo: outputURL)
        defer { try? stdin.close(); try? stdout.close() }
        let process = Process()
        let controlInput = until == nil ? nil : Pipe()
        defer { try? controlInput?.fileHandleForWriting.close(); try? controlInput?.fileHandleForReading.close() }
        process.executableURL = executable
        process.arguments = arguments + (finalMessage ? ["--output-last-message", finalURL.path, "-"] : [])
        process.currentDirectoryURL = directory
        // Prevent inherited API keys or provider URLs from changing the selected subscription route.
        let allowed = ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "CODEX_HOME", "CLAUDE_CONFIG_DIR"]
        var environment = ProcessInfo.processInfo.environment.filter { allowed.contains($0.key) }
        environment["PATH"] = "\(executable.deletingLastPathComponent().path):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        process.environment = environment
        if let controlInput { process.standardInput = controlInput } else { process.standardInput = stdin }
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        try process.run()
        let deadline = ContinuousClock.now.advanced(by: timeout)
        var completed: String?
        do {
            // Discovery requests are small JSON messages. Keep stdin open until the reply arrives.
            if let controlInput { try controlInput.fileHandleForWriting.write(contentsOf: Data(input.utf8)) }
            while process.isRunning {
                try Task.checkCancellation()
                guard ContinuousClock.now < deadline else {
                    throw MeetingNotesError.unavailable("\(cli.name) took too long to respond. Try again; your meeting is still saved.")
                }
                let size = try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 2_000_000 else { throw Self.failure(cli) }
                if let until {
                    let output = String(decoding: try Data(contentsOf: outputURL), as: UTF8.self)
                    if until(output) { completed = output; break }
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            try Task.checkCancellation()
        } catch {
            await stop(process)
            throw error
        }
        if let completed {
            try? controlInput?.fileHandleForWriting.close()
            await stop(process)
            try Task.checkCancellation()
            return completed
        }
        guard process.terminationStatus == 0 else { throw Self.failure(cli) }
        let text = try String(contentsOf: finalMessage ? finalURL : outputURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Self.failure(cli) }
        return text
    }

    @MainActor private static func stop(_ process: Process) async {
        guard process.isRunning else { return }
        process.terminate()
        // Cleanup must finish even when the calling task is cancelled.
        await Task.detached { try? await Task.sleep(for: .milliseconds(300)) }.value
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        while process.isRunning {
            await Task.detached { try? await Task.sleep(for: .milliseconds(20)) }.value
        }
    }
}
