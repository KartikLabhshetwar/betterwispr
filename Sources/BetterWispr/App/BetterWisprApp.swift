import AppKit
import SwiftUI

@main
struct BetterWisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("BetterWispr", id: "dashboard") {
            ZStack {
                if delegate.model.needsOnboarding {
                    OnboardingView(model: delegate.model)
                        .windowChromeHidden()
                        .transition(.opacity)
                } else {
                    DashboardView(model: delegate.model)
                        .transition(.opacity)
                }
            }
            .onAppear { delegate.start() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                delegate.model.refreshPermissions()
            }
            .frame(minWidth: 760, minHeight: 520)
            .animation(.easeInOut(duration: 0.4), value: delegate.model.needsOnboarding)
        }
        .defaultSize(width: 920, height: 680)
        .commands {
            SidebarCommands()
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { delegate.model.updater.checkForUpdates() }
                    .disabled(!delegate.model.updater.canCheckForUpdates)
            }
            CommandGroup(after: .saveItem) {
                Button("Export History…") { delegate.model.exportHistory() }
                    .disabled(delegate.model.history.isEmpty)
            }
            CommandGroup(after: .newItem) {
                Button(delegate.model.phase == .recording ? "Finish dictation" : "Start dictation") {
                    delegate.model.toggleRecording()
                }
                Button("Cancel dictation") { delegate.model.cancelRecording() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!delegate.model.isBusy)
            }
            CommandGroup(after: .help) {
                WelcomeGuideButton(model: delegate.model)
            }
        }
        MenuBarExtra {
            MenuContents(model: delegate.model)
        } label: {
            Label {
                Text("BetterWispr")
            } icon: {
                if delegate.model.phase == .recording {
                    Image(systemName: "mic.fill")
                } else {
                    Image(nsImage: BrandGlyph.menuBarImage)
                }
            }
        }
    }
}

private struct WelcomeGuideButton: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Welcome Guide") {
            model.showOnboarding()
            openWindow(id: "dashboard")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .disabled(model.needsOnboarding)
    }
}

private struct MenuContents: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(status)
        Button { model.toggleRecording() } label: {
            Text(model.phase == .recording ? "Finish Dictation" : "Start Dictation")
            Text(model.settings.shortcut.displayName)
        }
        .disabled(model.phase == .preparing || model.phase == .transcribing)
        if model.isBusy { Button("Cancel") { model.cancelRecording() } }
        Button(model.meetings.activity.capturingID == nil ? "Start Meeting Notes" : "Stop Meeting") {
            guard model.meetings.activity.capturingID == nil else { return model.meetings.stop() }
            model.startNotetaker()
        }
        .disabled(model.meetings.activity != .idle && model.meetings.activity.capturingID == nil)
        Divider()
        Picker("Model", selection: Binding(
            get: { model.selectedModel.id },
            set: { id in
                if let speechModel = model.models.first(where: { $0.id == id }) { model.selectModel(speechModel) }
            }
        )) {
            ForEach(model.models.filter(model.isModelInstalled)) { speechModel in
                Text(speechModel.name).tag(speechModel.id)
            }
        }
        .disabled(model.isBusy)
        MicrophonePicker(model: model) { Text("Microphone") }
        Divider()
        Button("Open Dashboard", action: openDashboard)
        Button("Settings…") {
            model.selectedPage = .settings
            openDashboard()
        }
        .keyboardShortcut(",")
        Button("Check for Updates…") { model.updater.checkForUpdates() }
            .disabled(!model.updater.canCheckForUpdates)
        Divider()
        Button("Quit BetterWispr") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }

    private var status: String {
        switch model.phase {
        case .recording: "Listening…"
        case .transcribing: "Transcribing…"
        case .preparing: "Preparing…"
        case .idle, .failed: "BetterWispr: Ready"
        }
    }

    private func openDashboard() {
        openWindow(id: "dashboard")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var capsule: CapsuleController?
    private var notetaker: NotetakerController?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        capsule = CapsuleController(model: model)
        model.onPresentationChange = { [weak self] in self?.capsule?.update() }
        notetaker = NotetakerController(model: model)
        model.onShowNotetaker = { [weak self] in self?.notetaker?.show($0) }
        model.registerShortcut()
        capsule?.update()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        model.cancelRecording()
        model.meetings.endForQuit()
        capsule?.close()
        notetaker?.close()
    }
}

private extension View {
    @ViewBuilder func windowChromeHidden() -> some View {
        if #available(macOS 15, *) {
            toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            self
        }
    }
}
