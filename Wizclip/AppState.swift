import AppKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppState {
    var items: [ClipboardItem] = []
    var searchText = ""
    var selectedID: UUID?
    var isPanelVisible = false
    var launchesAtLogin = SMAppService.mainApp.status == .enabled
    var hotkey = Hotkey.load()
    var isRecordingHotkey = false
    var hotkeyRecordingHint: String?
    var hotkeyError: String?

    private var recordingGeneration = 0

    let store = ClipboardStore.shared
    let monitor = ClipboardMonitor()

    private var previousApp: NSRunningApplication?
    private var workspaceObserver: NSObjectProtocol?

    var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.displayText.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedItem: ClipboardItem? {
        if let selectedID, let match = filteredItems.first(where: { $0.id == selectedID }) {
            return match
        }
        return filteredItems.first
    }

    func start() {
        items = store.load()
        selectedID = items.first?.id
        monitor.onCapture = { [weak self] item in
            self?.ingest(item)
        }
        monitor.start()
        HotkeyManager.shared.onHotkey = { [weak self] in
            guard let self, !self.isRecordingHotkey else { return }
            self.togglePanel()
        }
        if !HotkeyManager.shared.register(hotkey) {
            hotkeyError = "Couldn’t register \(hotkey.displayString)."
        }
        watchForegroundApp()
    }

    func beginRecordingHotkey() {
        guard !isRecordingHotkey else { return }
        recordingGeneration += 1
        let generation = recordingGeneration
        isRecordingHotkey = true
        hotkeyRecordingHint = "Esc to cancel"
        hotkeyError = nil
        HotkeyRecorder.start { [weak self] event in
            self?.handleRecordedEvent(event, generation: generation)
        }
    }

    func cancelRecordingHotkey() {
        guard isRecordingHotkey else { return }
        endRecording()
    }

    func resetHotkey() {
        if isRecordingHotkey {
            endRecording()
        }
        applyHotkey(.defaultShortcut)
    }

    private func handleRecordedEvent(_ event: NSEvent, generation: Int) {
        guard isRecordingHotkey, recordingGeneration == generation else { return }
        if event.type == .flagsChanged {
            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            hotkeyRecordingHint = flags.isEmpty ? "Esc to cancel" : Hotkey.modifierSymbols(flags: flags) + "…"
            return
        }

        switch Hotkey.capture(event) {
        case .ignore:
            break
        case .cancel:
            cancelRecordingHotkey()
        case .needsModifier:
            hotkeyRecordingHint = "Include ⌘, ⌥, or ⌃"
        case .captured(let recorded):
            endRecording()
            applyHotkey(recorded)
        }
    }

    private func endRecording() {
        recordingGeneration += 1
        isRecordingHotkey = false
        hotkeyRecordingHint = nil
        HotkeyRecorder.stop()
    }

    private func applyHotkey(_ newValue: Hotkey) {
        if HotkeyManager.shared.register(newValue) {
            hotkey = newValue
            newValue.save()
            hotkeyError = nil
        } else {
            hotkeyError = "That shortcut is unavailable."
            if !HotkeyManager.shared.register(hotkey) {
                hotkeyError = "Couldn’t register \(hotkey.displayString)."
            }
        }
    }

    func ingest(_ item: ClipboardItem) {
        if let existing = items.first(where: { $0.contentHash == item.contentHash }) {
            if existing.kind == .image, existing.imageFilename != item.imageFilename {
                store.removeImage(named: item.imageFilename)
            }
            items.removeAll { $0.id == existing.id }
            let promoted = ClipboardItem(
                id: existing.id,
                kind: existing.kind,
                createdAt: Date(),
                contentHash: existing.contentHash,
                preview: existing.preview,
                text: existing.text,
                imageFilename: existing.imageFilename
            )
            items.insert(promoted, at: 0)
        } else {
            items.insert(item, at: 0)
        }

        while items.count > ClipboardStore.maxItems {
            if let dropped = items.popLast() {
                store.removeImage(named: dropped.imageFilename)
            }
        }

        if searchText.isEmpty {
            selectedID = items.first?.id
        }
        persist()
    }

    func persist() {
        store.save(items)
    }

    func togglePanel() {
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    var closeHandler: (() -> Void)?

    func preparePresentation() {
        searchText = ""
        selectedID = filteredItems.first?.id
    }

    func showPanel() {
        preparePresentation()
        HistoryPanelController.shared.show(state: self)
        isPanelVisible = true
    }

    func hidePanel() {
        HistoryPanelController.shared.hide()
        isPanelVisible = false
        searchText = ""
        closeHandler?()
    }

    func selectNext() {
        moveSelection(by: 1)
    }

    func selectPrevious() {
        moveSelection(by: -1)
    }

    func pasteSelected() {
        guard let item = selectedItem else { return }
        paste(item)
    }

    func paste(_ item: ClipboardItem) {
        let targetApp = previousApp
        monitor.ignoreNextWrite()
        store.writeToPasteboard(item)
        monitor.markOwnWriteComplete()
        ingest(item)
        hidePanel()

        guard PasteService.isTrusted else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if let targetApp, targetApp != NSRunningApplication.current {
                NSApp.yieldActivation(to: targetApp)
                targetApp.activate()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                PasteService.pasteCommandV()
            }
        }
    }

    func deleteSelected() {
        guard let item = selectedItem else { return }
        delete(item)
    }

    func delete(_ item: ClipboardItem) {
        let list = filteredItems
        let index = list.firstIndex(of: item)
        items.removeAll { $0.id == item.id }
        store.removeImage(named: item.imageFilename)
        persist()

        if let index {
            let next = filteredItems
            if next.indices.contains(index) {
                selectedID = next[index].id
            } else if next.indices.contains(index - 1) {
                selectedID = next[index - 1].id
            } else {
                selectedID = next.first?.id
            }
        }
    }

    func clearHistory() {
        for item in items {
            store.removeImage(named: item.imageFilename)
        }
        items = []
        selectedID = nil
        persist()
    }

    func toggleLaunchAtLogin() {
        do {
            if launchesAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func requestPastePermissionIfNeeded() {
        if !PasteService.isTrusted {
            PasteService.requestAccess()
        }
    }

    func ensureSelectionIsVisible() {
        if selectedID == nil || !filteredItems.contains(where: { $0.id == selectedID }) {
            selectedID = filteredItems.first?.id
        }
    }

    private func watchForegroundApp() {
        let front = NSWorkspace.shared.frontmostApplication
        if front != NSRunningApplication.current {
            previousApp = front
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor in
                guard let self, app != NSRunningApplication.current else { return }
                self.previousApp = app
            }
        }
    }

    private func moveSelection(by offset: Int) {
        let list = filteredItems
        guard !list.isEmpty else { return }
        let current = list.firstIndex(where: { $0.id == selectedID }) ?? 0
        let next = min(max(current + offset, 0), list.count - 1)
        selectedID = list[next].id
    }
}
