import AppKit
import SwiftUI

final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class HistoryPanelController: NSObject, NSWindowDelegate {
    static let shared = HistoryPanelController()

    private var panel: NSPanel?
    private weak var state: AppState?

    private let panelSize = NSSize(width: 420, height: 560)

    func show(state: AppState) {
        self.state = state
        let panel = panel ?? makePanel(state: state)
        self.panel = panel
        position(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        state?.hidePanel()
    }

    func windowWillClose(_ notification: Notification) {
        state?.isPanelVisible = false
    }

    private func makePanel(state: AppState) -> NSPanel {
        let panel = ClipboardPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Clipboard"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        let host = NSHostingView(rootView: HistoryView().environment(state))
        host.safeAreaRegions = []
        panel.contentView = host
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let width = panelSize.width
        let height = panelSize.height
        let x = visible.midX - width / 2
        let y = visible.midY - height / 2 + 36
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
