import AppKit
import ApplicationServices
import CryptoKit
import Foundation

@MainActor
final class PasteService {
    static func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestAccessibilityPermission() {
        _ = hasAccessibilityPermission(prompt: true)
    }

    func paste(
        item: ClipboardItem,
        using store: ClipboardStore,
        panel: ClipboardPanel,
        targetApplication: NSRunningApplication?
    ) -> Bool {
        let pasteboard = NSPasteboard.general
        let signature: String

        switch item.kind {
        case .text:
            guard let text = item.textContent else { return false }
            signature = makeSignature(for: Data(text.utf8), prefix: "text")
            store.suppressNextCapture(signature: signature)
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        case .image:
            guard let image = store.image(for: item),
                  let tiffData = image.tiffRepresentation else { return false }
            signature = makeSignature(for: tiffData, prefix: "image")
            store.suppressNextCapture(signature: signature)
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        }

        panel.hideImmediately()

        let canAutoPaste = Self.hasAccessibilityPermission(prompt: false)

        if canAutoPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                targetApplication?.activate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    self.postCommandV()
                }
            }
        } else {
            targetApplication?.activate()
        }

        return true
    }

    private func postCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            return
        }

        commandDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand

        commandDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        commandUp.post(tap: .cghidEventTap)
    }

    private func makeSignature(for data: Data, prefix: String) -> String {
        let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        return "\(prefix)-\(hash)"
    }
}
