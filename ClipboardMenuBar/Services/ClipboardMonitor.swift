import AppKit
import CryptoKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private let clipboardStore: ClipboardStore
    private let imageStorage: ImageStorage
    private let pasteboard = NSPasteboard.general
    private var timer: Timer?
    private var lastChangeCount: Int
    private var processingImageSignature: String?

    init(clipboardStore: ClipboardStore, imageStorage: ImageStorage) {
        self.clipboardStore = clipboardStore
        self.imageStorage = imageStorage
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.captureIfNeeded()
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

    private func captureIfNeeded() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let imageTypes: Set<NSPasteboard.PasteboardType> = [.tiff, .png]
        let stringTypes: Set<NSPasteboard.PasteboardType> = [.string]
        let types = pasteboard.types ?? []
        let firstImageIndex = types.firstIndex(where: { imageTypes.contains($0) })
        let firstStringIndex = types.firstIndex(where: { stringTypes.contains($0) })

        // If image types appear before string types in the pasteboard, the source
        // primarily intends to provide an image (e.g., copying an image from a browser).
        let preferImage: Bool
        if let imgIdx = firstImageIndex, let strIdx = firstStringIndex {
            preferImage = imgIdx < strIdx
        } else {
            preferImage = firstImageIndex != nil
        }

        if preferImage, let tiffData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            captureImage(tiffData: tiffData)
            return
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let signature = digest(for: Data(text.utf8), prefix: "text")
            clipboardStore.saveText(text, signature: signature)
            return
        }

        // Last resort: try image even if text types appeared first but no text was found
        if let tiffData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            captureImage(tiffData: tiffData)
        }
    }

    private func captureImage(tiffData: Data) {
        let signature = digest(for: tiffData, prefix: "image")
        guard processingImageSignature != signature else { return }
        processingImageSignature = signature

        let imageStorage = self.imageStorage
        Task.detached(priority: .utility) { [weak self] in
            do {
                let payload = try imageStorage.store(imageData: tiffData)
                await MainActor.run {
                    self?.clipboardStore.saveImage(payload: payload, signature: signature)
                    self?.processingImageSignature = nil
                }
            } catch {
                await MainActor.run {
                    NSLog("Failed to persist clipboard image: %@", error.localizedDescription)
                    self?.processingImageSignature = nil
                }
            }
        }
    }

    private func digest(for data: Data, prefix: String) -> String {
        let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        return "\(prefix)-\(hash)"
    }
}
