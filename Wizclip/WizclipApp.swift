import AppKit
import SwiftUI

@main
struct WizclipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Wizclip", systemImage: "clipboard") {
            HistoryView(chrome: .popover)
                .environment(appDelegate.state)
                .frame(width: 380, height: 520)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        state.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        state.showPanel()
        return false
    }
}

