import Foundation
import SwiftData

enum ClipboardContentKind: String, Codable {
    case text
    case image
}

@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var kindRawValue: String
    var textContent: String?
    var imagePath: String?
    var imageWidth: Double?
    var imageHeight: Double?
    var previewData: Data?
    var pasteboardSignature: String
    var isPinned: Bool

    var kind: ClipboardContentKind {
        get { ClipboardContentKind(rawValue: kindRawValue) ?? .text }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        kind: ClipboardContentKind,
        textContent: String? = nil,
        imagePath: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        previewData: Data? = nil,
        pasteboardSignature: String,
        isPinned: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kindRawValue = kind.rawValue
        self.textContent = textContent
        self.imagePath = imagePath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.previewData = previewData
        self.pasteboardSignature = pasteboardSignature
        self.isPinned = isPinned
    }

    var displayTitle: String {
        switch kind {
        case .text:
            let compact = (textContent ?? "")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return compact.isEmpty ? "Empty text" : compact
        case .image:
            return "Image"
        }
    }
}
