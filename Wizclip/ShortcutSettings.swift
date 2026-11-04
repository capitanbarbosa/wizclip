import AppKit
import SwiftUI

struct ShortcutSettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Opens clipboard history from any app.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if !state.isRecordingHotkey {
                    state.beginRecordingHotkey()
                }
            } label: {
                Text(recorderLabel)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(state.isRecordingHotkey
                          ? Color(red: 0.20, green: 0.49, blue: 0.96).opacity(0.16)
                          : Color.primary.opacity(0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        state.isRecordingHotkey
                            ? Color(red: 0.20, green: 0.49, blue: 0.96).opacity(0.85)
                            : Color.primary.opacity(0.08),
                        lineWidth: state.isRecordingHotkey ? 1.5 : 1
                    )
            }

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(state.hotkeyError == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 16)

            HStack(spacing: 8) {
                Button("Reset to \(Hotkey.defaultShortcut.displayString)") {
                    state.resetHotkey()
                }
                .disabled(state.hotkey == .defaultShortcut && !state.isRecordingHotkey)
                Spacer()
                Button("Done") {
                    ShortcutSettingsController.shared.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onExitCommand {
            ShortcutSettingsController.shared.close()
        }
    }

    private var recorderLabel: String {
        guard state.isRecordingHotkey else { return state.hotkey.displayString }
        if let hint = state.hotkeyRecordingHint, hint.hasSuffix("…") {
            return hint
        }
        return "Type shortcut…"
    }

    private var message: String {
        if let hotkeyError = state.hotkeyError {
            return hotkeyError
        }
        if state.isRecordingHotkey {
            if let hint = state.hotkeyRecordingHint, !hint.hasSuffix("…") {
                return hint
            }
            return "Esc to cancel"
        }
        return "Click the shortcut, then press the keys you want."
    }
}

@MainActor
final class ShortcutSettingsController: NSObject, NSWindowDelegate {
    static let shared = ShortcutSettingsController()

    private var panel: NSPanel?
    private weak var state: AppState?

    func show(state: AppState) {
        self.state = state
        let panel = self.panel ?? makePanel(state: state)
        self.panel = panel
        if !panel.isVisible {
            position(panel)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
        DispatchQueue.main.async {
            guard panel.isKeyWindow else { return }
            state.beginRecordingHotkey()
        }
    }

    func close() {
        panel?.close()
    }

    func windowDidResignKey(_ notification: Notification) {
        state?.cancelRecordingHotkey()
    }

    func windowWillClose(_ notification: Notification) {
        state?.cancelRecordingHotkey()
    }

    private func makePanel(state: AppState) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 220),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Keyboard Shortcut"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self

        let host = NSHostingView(rootView: ShortcutSettingsView().environment(state))
        host.safeAreaRegions = []
        panel.contentView = host
        host.layoutSubtreeIfNeeded()
        var size = host.fittingSize
        if size.width < 300 || size.height < 140 {
            size = NSSize(width: 340, height: 210)
        }
        panel.setContentSize(size)
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            panel.center()
            return
        }
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}
