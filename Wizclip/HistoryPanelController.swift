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
    private var isTrackingMenu = false
    private var menuObservers: [NSObjectProtocol] = []

    private let panelSize = NSSize(width: 420, height: 560)

    func show(state: AppState) {
        self.state = state
        observeMenusIfNeeded()
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
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel, panel.isVisible, !self.isTrackingMenu else { return }
            self.state?.hidePanel()
        }
    }

    private func observeMenusIfNeeded() {
        guard menuObservers.isEmpty else { return }
        let center = NotificationCenter.default
        menuObservers.append(center.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isTrackingMenu = true
            }
        })
        menuObservers.append(center.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isTrackingMenu = false
                DispatchQueue.main.async {
                    guard let panel = self.panel, panel.isVisible, !panel.isKeyWindow, !self.isTrackingMenu else { return }
                    self.state?.hidePanel()
                }
            }
        })
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
