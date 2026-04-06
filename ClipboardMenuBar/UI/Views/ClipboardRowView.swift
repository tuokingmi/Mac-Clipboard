import AppKit
import SwiftUI

struct ClipboardPreviewImageView: View {
    let item: ClipboardItem

    var body: some View {
        Group {
            if item.kind == .image, let previewData = item.previewData, let image = NSImage(data: previewData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: item.kind == .text ? "text.alignleft" : "photo")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 52, height: 52)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct ClipboardRowView: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ClipboardPreviewImageView(item: item)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                }

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 12))
    }

    private var backgroundStyle: some ShapeStyle {
        isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.18)) : AnyShapeStyle(Color.white.opacity(0.04))
    }

    private var title: String {
        switch item.kind {
        case .text:
            return item.displayTitle
        case .image:
            return "Image"
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .text:
            return item.createdAt.formatted(.dateTime.hour().minute())
        case .image:
            let width = Int(item.imageWidth ?? 0)
            let height = Int(item.imageHeight ?? 0)
            return "\(width)×\(height)  ·  \(item.createdAt.formatted(.dateTime.hour().minute()))"
        }
    }
}
