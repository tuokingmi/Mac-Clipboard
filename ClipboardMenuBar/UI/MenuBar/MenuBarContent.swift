import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var services: AppServices

    var body: some View {
        Button("Show Clipboard History") {
            services.panelController?.show()
        }
        .disabled(services.panelController == nil)

        Toggle(
            "Launch at Login",
            isOn: Binding(
                get: { services.launchAtLoginEnabled },
                set: { services.setLaunchAtLogin($0) }
            )
        )

        if services.launchAtLoginNeedsApproval {
            Text("Approve in Login Items")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if services.accessibilityEnabled == false {
            Button("Grant Accessibility Permission") {
                services.promptForAccessibilityPermission()
            }
        }

        Button("Clear History") {
            services.clipboardStore?.clearAll()
        }
        .disabled(services.clipboardStore == nil)

        if let statusMessage = services.statusMessage {
            Divider()
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .onAppear {
            services.refreshSystemState()
        }
    }
}
