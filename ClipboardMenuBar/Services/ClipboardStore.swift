import AppKit
import Foundation
import SwiftData

@MainActor
final class ClipboardStore: ObservableObject {
    private let modelContext: ModelContext
    private let imageStorage: ImageStorage

    private(set) var suppressedSignature: String?

    init(modelContext: ModelContext, imageStorage: ImageStorage) {
        self.modelContext = modelContext
        self.imageStorage = imageStorage
    }

    func fetchItems() -> [ClipboardItem] {
        let descriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)])
        let all = (try? modelContext.fetch(descriptor)) ?? []

        let pinned = all.filter { $0.isPinned }
        let unpinned = all.filter { !$0.isPinned }
        return pinned + unpinned
    }

    func latestItem() -> ClipboardItem? {
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func suppressNextCapture(signature: String) {
        suppressedSignature = signature
    }

    func saveText(_ text: String, signature: String) {
        guard shouldSave(signature: signature) else { return }
        let item = ClipboardItem(kind: .text, textContent: text, pasteboardSignature: signature)
        modelContext.insert(item)
        persist()
    }

    func saveImage(payload: StoredImagePayload, signature: String) {
        guard shouldSave(signature: signature) else {
            imageStorage.deleteImage(relativePath: payload.relativePath)
            return
        }

        let item = ClipboardItem(
            kind: .image,
            imagePath: payload.relativePath,
            imageWidth: payload.size.width,
            imageHeight: payload.size.height,
            previewData: payload.previewData,
            pasteboardSignature: signature
        )
        modelContext.insert(item)
        persist()
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        try? modelContext.save()
        objectWillChange.send()
    }

    @discardableResult
    func clearAll() -> Int {
        let items = fetchItems().filter { !$0.isPinned }
        guard items.isEmpty == false else { return 0 }

        items.forEach { item in
            imageStorage.deleteImage(relativePath: item.imagePath)
            modelContext.delete(item)
        }
        try? modelContext.save()
        objectWillChange.send()
        return items.count
    }

    func image(for item: ClipboardItem) -> NSImage? {
        guard let path = item.imagePath else { return nil }
        return imageStorage.loadImage(relativePath: path)
    }

    func delete(_ item: ClipboardItem) {
        imageStorage.deleteImage(relativePath: item.imagePath)
        modelContext.delete(item)
        try? modelContext.save()
        objectWillChange.send()
    }

    private func shouldSave(signature: String) -> Bool {
        if suppressedSignature == signature {
            suppressedSignature = nil
            return false
        }

        if latestItem()?.pasteboardSignature == signature {
            return false
        }

        suppressedSignature = nil
        return true
    }

    private func persist() {
        try? modelContext.save()
        objectWillChange.send()
    }
}
