import Foundation

enum ClipboardKind: String, Codable, Sendable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let kind: ClipboardKind
    let createdAt: Date
    let contentHash: String
    let preview: String
    var text: String?
    var imageFilename: String?

    var displayText: String {
        if kind == .image {
            return preview.isEmpty ? "Image" : preview
        }
        return text ?? preview
    }
}
