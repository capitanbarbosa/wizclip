import AppKit

@MainActor
final class ClipboardMonitor {
    var onCapture: ((ClipboardItem) -> Void)?

    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private var ignoringOwnWrite = false

    func start() {
        timer?.invalidate()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreNextWrite() {
        ignoringOwnWrite = true
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func markOwnWriteComplete() {
        lastChangeCount = NSPasteboard.general.changeCount
        ignoringOwnWrite = false
    }

    private func poll() {
        let board = NSPasteboard.general
        let changeCount = board.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        if ignoringOwnWrite {
            ignoringOwnWrite = false
            return
        }

        if let item = capture(from: board) {
            onCapture?(item)
        }
    }

    private func capture(from board: NSPasteboard) -> ClipboardItem? {
        let store = ClipboardStore.shared
        let text = board.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasUsefulText = (text?.isEmpty == false)

        if let image = bestImage(from: board), !hasUsefulText {
            let prepared = store.preparedImage(image)
            let id = UUID()
            guard let filename = store.persistImage(prepared, id: id) else { return nil }
            return ClipboardItem(
                id: id,
                kind: .image,
                createdAt: Date(),
                contentHash: store.hashForImage(prepared),
                preview: imageLabel(for: prepared),
                text: nil,
                imageFilename: filename
            )
        }

        if let raw = text, let normalized = store.normalizedText(raw) {
            return ClipboardItem(
                id: UUID(),
                kind: .text,
                createdAt: Date(),
                contentHash: store.hashForText(normalized),
                preview: store.preview(for: normalized),
                text: normalized,
                imageFilename: nil
            )
        }

        if let image = bestImage(from: board) {
            let prepared = store.preparedImage(image)
            let id = UUID()
            guard let filename = store.persistImage(prepared, id: id) else { return nil }
            return ClipboardItem(
                id: id,
                kind: .image,
                createdAt: Date(),
                contentHash: store.hashForImage(prepared),
                preview: imageLabel(for: prepared),
                text: nil,
                imageFilename: filename
            )
        }

        return nil
    }

    private func bestImage(from board: NSPasteboard) -> NSImage? {
        if let image = NSImage(pasteboard: board), image.isValid, image.size.width > 1, image.size.height > 1 {
            return image
        }

        let urls = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        if urls.count == 1, let url = urls.first, isImageFile(url), let image = NSImage(contentsOf: url), image.isValid {
            return image
        }

        return nil
    }

    private func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "tif", "tiff", "bmp", "heic", "webp"].contains(ext)
    }

    private func imageLabel(for image: NSImage) -> String {
        let width = Int(image.size.width.rounded())
        let height = Int(image.size.height.rounded())
        return "Image · \(width)×\(height)"
    }
}
