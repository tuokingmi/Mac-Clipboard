import AppKit
import Foundation

struct StoredImagePayload {
    let relativePath: String
    let previewData: Data?
    let size: NSSize
}

final class ImageStorage {
    private let fileManager = FileManager.default
    private let imagesDirectory: URL

    init(bundleIdentifier: String) {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = baseDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        self.imagesDirectory = appDirectory.appendingPathComponent("Images", isDirectory: true)
        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    func store(imageData: Data) throws -> StoredImagePayload {
        guard let image = NSImage(data: imageData) else {
            throw ImageStorageError.decodingFailed
        }

        guard let pngData = encodedPNGData(from: image) else {
            throw ImageStorageError.encodingFailed
        }

        let fileName = "\(UUID().uuidString).png"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        try pngData.write(to: fileURL, options: .atomic)

        return StoredImagePayload(
            relativePath: fileName,
            previewData: makePreviewData(from: image),
            size: image.size
        )
    }

    func loadImage(relativePath: String) -> NSImage? {
        let url = imagesDirectory.appendingPathComponent(relativePath)
        return NSImage(contentsOf: url)
    }

    func deleteImage(relativePath: String?) {
        guard let relativePath else { return }
        let url = imagesDirectory.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: url)
    }

    private func encodedPNGData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func makePreviewData(from image: NSImage) -> Data? {
        let maxDimension: CGFloat = 120
        let fittedSize = fittedPreviewSize(for: image.size, maxDimension: maxDimension)
        let thumbnail = NSImage(size: fittedSize)

        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .medium
        image.draw(in: NSRect(origin: .zero, size: fittedSize), from: .zero, operation: .copy, fraction: 1)
        thumbnail.unlockFocus()

        return encodedPNGData(from: thumbnail)
    }

    private func fittedPreviewSize(for size: NSSize, maxDimension: CGFloat) -> NSSize {
        guard size.width > 0, size.height > 0 else {
            return NSSize(width: maxDimension, height: maxDimension)
        }

        let scale = min(maxDimension / size.width, maxDimension / size.height)
        return NSSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
    }
}

enum ImageStorageError: Error {
    case decodingFailed
    case encodingFailed
}
