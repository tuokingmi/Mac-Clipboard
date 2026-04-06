import AppKit
import Foundation
import SwiftData

@MainActor
final class ClipboardStore: ObservableObject {
    private let modelContext: ModelContext
    private let imageStorage: ImageStorage
    let maxItemCount: Int

    private(set) var suppressedSignature: String?

    init(modelContext: ModelContext, imageStorage: ImageStorage, maxItemCount: Int = 100) {
        self.modelContext = modelContext
        self.imageStorage = imageStorage
        self.maxItemCount = maxItemCount
    }

    func fetchItems(searchText: String = "") -> [ClipboardItem] {
        let descriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)])
        let all = (try? modelContext.fetch(descriptor)) ?? []

        let filtered: [ClipboardItem]
        if searchText.isEmpty {
            filtered = Array(all.prefix(maxItemCount))
        } else {
            filtered = all.filter { item in
                switch item.kind {
                case .text:
                    return item.displayTitle.localizedCaseInsensitiveContains(searchText)
                case .image:
                    return "image".localizedCaseInsensitiveContains(searchText)
                }
            }
        }

        let pinned = filtered.filter { $0.isPinned }
        let unpinned = filtered.filter { !$0.isPinned }
        return pinned + unpinned
    }

    func latestItem() -> ClipboardItem? {
        fetchItems().first
    }

    func suppressNextCapture(signature: String) {
        suppressedSignature = signature
    }

    func saveText(_ text: String, signature: String) {
        guard shouldSave(signature: signature) else { return }
        let item = ClipboardItem(kind: .text, textContent: text, pasteboardSignature: signature)
        modelContext.insert(item)
        persistAndTrim()
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
        persistAndTrim()
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        try? modelContext.save()
        objectWillChange.send()
    }

    func clearAll() {
        let items = fetchItems().filter { !$0.isPinned }
        items.forEach { item in
            imageStorage.deleteImage(relativePath: item.imagePath)
            modelContext.delete(item)
        }
        try? modelContext.save()
        objectWillChange.send()
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

    private func persistAndTrim() {
        trimIfNeeded()
        try? modelContext.save()
        objectWillChange.send()
    }

    private func trimIfNeeded() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)]
        )
        let allItems = (try? modelContext.fetch(descriptor)) ?? []
        let unpinned = allItems.filter { !$0.isPinned }

        guard unpinned.count > maxItemCount else { return }

        for item in unpinned.dropFirst(maxItemCount) {
            imageStorage.deleteImage(relativePath: item.imagePath)
            modelContext.delete(item)
        }
    }
}
