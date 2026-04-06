import AppKit
import SwiftUI

final class ClipboardPanel: NSPanel {
    var onRequestClose: (() -> Void)?

    init(initialContentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.nonactivatingPanel, .hudWindow, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96)
        self.contentView = initialContentView
    }

    func hideImmediately() {
        orderOut(nil)
    }

    override func resignKey() {
        super.resignKey()
        if isVisible {
            onRequestClose?()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
