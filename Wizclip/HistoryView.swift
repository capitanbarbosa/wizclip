import AppKit
import SwiftUI

enum HistoryChrome {
    case panel
    case popover
}

struct HistoryView: View {
    var chrome: HistoryChrome = .panel

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 0) {
            header
            searchField
            content
            footer
        }
        .padding(.horizontal, chrome == .popover ? 12 : 14)
        .padding(.top, chrome == .popover ? 12 : 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panelBackground)
        .onAppear {
            state.preparePresentation()
            state.closeHandler = { dismiss() }
            state.ensureSelectionIsVisible()
            searchFocused = true
            HistoryKeyMonitor.start(state)
        }
        .onDisappear {
            state.closeHandler = nil
            HistoryKeyMonitor.stop()
        }
        .onChange(of: state.searchText) {
            state.ensureSelectionIsVisible()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Clipboard")
                .font(.system(size: chrome == .popover ? 17 : 20, weight: .semibold, design: .rounded))
            Spacer()
            Text(countLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            if chrome == .popover {
                overflowMenu
            }
        }
        .padding(.bottom, 12)
    }

    private var overflowMenu: some View {
        Menu {
            Button(state.launchesAtLogin ? "Do Not Open at Login" : "Open at Login") {
                state.toggleLaunchAtLogin()
            }
            Button("Allow Auto-Paste…") {
                state.requestPastePermissionIfNeeded()
            }
            Divider()
            Button("Clear History", role: .destructive) {
                state.clearHistory()
            }
            .disabled(state.items.isEmpty)
            Button("Quit Wizclip") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .frame(width: 22, height: 22)
    }

    private var searchField: some View {
        @Bindable var state = state
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard", text: $state.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !state.searchText.isEmpty {
                Button {
                    state.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        if state.filteredItems.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(state.filteredItems) { item in
                            HistoryRow(
                                item: item,
                                image: item.kind == .image ? state.store.image(for: item) : nil,
                                isSelected: item.id == state.selectedItem?.id
                            )
                            .id(item.id)
                            .onTapGesture {
                                state.selectedID = item.id
                                state.paste(item)
                            }
                            .contextMenu {
                                Button("Paste") { state.paste(item) }
                                Button("Copy") {
                                    state.monitor.ignoreNextWrite()
                                    state.store.writeToPasteboard(item)
                                    state.monitor.markOwnWriteComplete()
                                }
                                Divider()
                                Button("Delete", role: .destructive) { state.delete(item) }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
                .scrollIndicators(.never)
                .onChange(of: state.selectedID) { _, newValue in
                    if let newValue {
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: state.items.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            Text(state.items.isEmpty ? "Nothing copied yet" : "No matches")
                .font(.system(size: 15, weight: .semibold))
            Text(state.items.isEmpty
                 ? "Copy text or an image and it will show up here."
                 : "Try a different search.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            hint("⏎", "paste")
            hint("⌫", "delete")
            hint("esc", "close")
            Spacer()
            Text("⌘⇧V")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var countLabel: String {
        let count = state.filteredItems.count
        if state.searchText.isEmpty {
            return count == 1 ? "1 item" : "\(count) items"
        }
        return count == 1 ? "1 match" : "\(count) matches"
    }

    @ViewBuilder
    private var panelBackground: some View {
        if chrome == .popover {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
        }
    }
}

enum HistoryKeyMonitor {
    private static var monitor: Any?

    @MainActor
    static func start(_ state: AppState) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event, state: state)
        }
    }

    static func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    @MainActor
    private static func handle(_ event: NSEvent, state: AppState) -> NSEvent? {
        switch event.keyCode {
        case 125:
            state.selectNext()
            return nil
        case 126:
            state.selectPrevious()
            return nil
        case 36, 76:
            state.pasteSelected()
            return nil
        case 53:
            state.hidePanel()
            return nil
        case 51, 117:
            if event.modifierFlags.contains(.command) || state.searchText.isEmpty {
                state.deleteSelected()
                return nil
            }
            return event
        default:
            return event
        }
    }
}

struct HistoryRow: View {
    let item: ClipboardItem
    let image: NSImage?
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.kind == .image {
                imagePreview
            } else {
                Text(item.displayText)
                    .font(.system(size: 13))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 6) {
                Image(systemName: item.kind == .image ? "photo" : "text.alignleft")
                    .font(.system(size: 10, weight: .semibold))
                Text(item.createdAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                Spacer()
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color(red: 0.20, green: 0.49, blue: 0.96).opacity(0.85) : Color.primary.opacity(0.05), lineWidth: isSelected ? 1.5 : 1)
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 92)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Text(item.preview)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                }
        } else {
            Text(item.preview)
                .font(.system(size: 13))
        }
    }

    private var rowBackground: Color {
        isSelected ? Color(red: 0.20, green: 0.49, blue: 0.96).opacity(0.12) : Color.primary.opacity(0.045)
    }
}
