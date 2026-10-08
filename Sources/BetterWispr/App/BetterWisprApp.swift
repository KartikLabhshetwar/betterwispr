import AppKit
import SwiftUI

@main
struct BetterWisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    var body: some Scene {
        Window("BetterWispr", id: "dashboard") {
            DashboardView(model: delegate.model)
                .onAppear { delegate.start() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    delegate.model.refreshPermissions()
                }
                .sheet(isPresented: Binding(get: { !onboardingCompleted }, set: { onboardingCompleted = !$0 })) {
                    OnboardingView(model: delegate.model) { onboardingCompleted = true }
                        .interactiveDismissDisabled()
                }
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

private struct MenuContents: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    var body: some View {
        Button("\(model.phase == .recording ? "Finish" : "Start") dictation · \(model.settings.shortcut.displayName)") { model.toggleRecording() }
            .disabled(model.phase == .preparing || model.phase == .transcribing)
        if model.isBusy { Button("Cancel") { model.cancelRecording() } }
        Button(model.meetings.activity.capturingID == nil ? "Start meeting notes" : "Stop meeting") {
            guard model.meetings.activity.capturingID == nil else { return model.meetings.stop() }
            model.startMeeting()
            openWindow(id: "dashboard")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .disabled(model.meetings.activity != .idle && model.meetings.activity.capturingID == nil)
        Divider()
        Button("Open dashboard") {
            openWindow(id: "dashboard")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Button("Show capsule") { model.showCapsule() }
        Button("Show welcome guide") {
            onboardingCompleted = false
            openWindow(id: "dashboard")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Divider()
        Text(model.selectedModel.name)
        Button("Quit BetterWispr") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var capsule: CapsuleController?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        capsule = CapsuleController(model: model)
        model.onPresentationChange = { [weak self] in self?.capsule?.update() }
        model.onShowCapsule = { [weak self] in self?.capsule?.show() }
        model.registerShortcut()
        capsule?.update()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        model.cancelRecording()
        model.meetings.endForQuit()
        capsule?.close()
    }
}
