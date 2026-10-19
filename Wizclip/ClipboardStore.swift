import AppKit
import CryptoKit
import Foundation

@MainActor
final class ClipboardStore {
    static let shared = ClipboardStore()

    static let maxItems = 80
    static let maxTextCharacters = 200_000
    static let maxImageDimension: CGFloat = 2400

    private let folderURL: URL
    private let imagesURL: URL
    private let historyURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let imageCache = NSCache<NSString, NSImage>()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let newFolder = appSupport.appendingPathComponent("Wizclip", isDirectory: true)
        let oldFolder = appSupport.appendingPathComponent("MacWizClipboard", isDirectory: true)
        if !FileManager.default.fileExists(atPath: newFolder.path),
           FileManager.default.fileExists(atPath: oldFolder.path) {
            try? FileManager.default.moveItem(at: oldFolder, to: newFolder)
        }
        folderURL = newFolder
        imagesURL = folderURL.appendingPathComponent("images", isDirectory: true)
        historyURL = folderURL.appendingPathComponent("history.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        imageCache.countLimit = 40
        try? FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
    }

    func load() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: historyURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: historyURL)
            let items = try decoder.decode([ClipboardItem].self, from: data)
            return items.filter { item in
                if item.kind == .image {
                    guard let name = item.imageFilename else { return false }
                    return FileManager.default.fileExists(atPath: imagesURL.appendingPathComponent(name).path)
                }
                return !(item.text ?? "").isEmpty
            }
        } catch {
            return []
        }
    }

    func save(_ items: [ClipboardItem]) {
        do {
            try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            let data = try encoder.encode(items)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            // Keep the in-memory list even if a write fails.
        }
        pruneOrphanedImages(keeping: items)
    }

    func image(for item: ClipboardItem) -> NSImage? {
        guard item.kind == .image, let name = item.imageFilename else { return nil }
        if let cached = imageCache.object(forKey: name as NSString) {
            return cached
        }
        let url = imagesURL.appendingPathComponent(name)
        guard let image = NSImage(contentsOf: url) else { return nil }
        imageCache.setObject(image, forKey: name as NSString)
        return image
    }

    func persistImage(_ image: NSImage, id: UUID) -> String? {
        guard let png = pngData(from: image) else { return nil }
        let filename = "\(id.uuidString).png"
        do {
            try png.write(to: imagesURL.appendingPathComponent(filename), options: .atomic)
            if let stored = NSImage(data: png) {
                imageCache.setObject(stored, forKey: filename as NSString)
            }
            return filename
        } catch {
            return nil
        }
    }

    func removeImage(named filename: String?) {
        guard let filename else { return }
        imageCache.removeObject(forKey: filename as NSString)
        try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(filename))
    }

    func writeToPasteboard(_ item: ClipboardItem) {
        let board = NSPasteboard.general
        board.clearContents()
        switch item.kind {
        case .text:
            board.setString(item.text ?? item.preview, forType: .string)
        case .image:
            if let image = image(for: item) {
                board.writeObjects([image])
            }
        }
    }

    func hashForText(_ text: String) -> String {
        sha256(Data(text.utf8))
    }

    func hashForImage(_ image: NSImage) -> String {
        if let png = pngData(from: image) {
            return sha256(png)
        }
        return UUID().uuidString
    }

    func normalizedText(_ raw: String) -> String? {
        var text = raw
        if text.count > Self.maxTextCharacters {
            text = String(text.prefix(Self.maxTextCharacters))
        }
        return text.isEmpty ? nil : text
    }

    func preview(for text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.count <= 180 { return collapsed }
        return String(collapsed.prefix(180)) + "…"
    }

    func preparedImage(_ image: NSImage) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let longest = max(size.width, size.height)
        guard longest > Self.maxImageDimension else { return image }
        let scale = Self.maxImageDimension / longest
        let newSize = NSSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1)
        resized.unlockFocus()
        return resized
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func pruneOrphanedImages(keeping items: [ClipboardItem]) {
        let keep = Set(items.compactMap(\.imageFilename))
        guard let files = try? FileManager.default.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files where !keep.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
