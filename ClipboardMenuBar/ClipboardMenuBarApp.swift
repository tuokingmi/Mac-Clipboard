import AppKit
import ServiceManagement
import SwiftData
import SwiftUI

@MainActor
final class AppServices: ObservableObject {
    static let shared = AppServices()

    @Published private(set) var panelController: PanelController?
    @Published private(set) var clipboardStore: ClipboardStore?
    @Published private(set) var accessibilityEnabled = PasteService.hasAccessibilityPermission(prompt: false)
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginNeedsApproval = false
    @Published var statusMessage: String?

    let modelContainer: ModelContainer

    private var monitor: ClipboardMonitor?
    private var hotKeyManager: HotKeyManager?
    private var permissionRefreshTimer: Timer?

    private init() {
        let schema = Schema([ClipboardItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }

        refreshSystemState()
        startPermissionRefreshTimer()
    }

    func start() {
        if clipboardStore != nil {
            refreshSystemState()
            return
        }

        let context = modelContainer.mainContext
        let imageStorage = ImageStorage(bundleIdentifier: Bundle.main.bundleIdentifier ?? "ClipboardMenuBar")
        let store = ClipboardStore(modelContext: context, imageStorage: imageStorage)
        let pasteService = PasteService()
        let panelController = PanelController(clipboardStore: store, pasteService: pasteService, appServices: self)
        let monitor = ClipboardMonitor(clipboardStore: store, imageStorage: imageStorage)
        let hotKeyManager = HotKeyManager { [weak panelController] in
            panelController?.toggle()
        }

        self.clipboardStore = store
        self.panelController = panelController
        self.monitor = monitor
        self.hotKeyManager = hotKeyManager

        monitor.start()
        hotKeyManager.registerOptionV()
        refreshSystemState()
    }

    func refreshSystemState() {
        let oldAccessibility = accessibilityEnabled
        accessibilityEnabled = PasteService.hasAccessibilityPermission(prompt: false)
        refreshLaunchAtLoginState()
        if oldAccessibility != accessibilityEnabled {
            panelController?.notifyPermissionStateChanged()
        }
    }

    func promptForAccessibilityPermission() {
        PasteService.requestAccessibilityPermission()
        refreshSystemState()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }

        refreshLaunchAtLoginState()
    }

    private func refreshLaunchAtLoginState() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginEnabled = true
            launchAtLoginNeedsApproval = false
        case .requiresApproval:
            launchAtLoginEnabled = false
            launchAtLoginNeedsApproval = true
        default:
            launchAtLoginEnabled = false
            launchAtLoginNeedsApproval = false
        }
    }

    private func startPermissionRefreshTimer() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSystemState()
            }
        }
        if let permissionRefreshTimer {
            RunLoop.main.add(permissionRefreshTimer, forMode: .common)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppServices.shared.start()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            AppServices.shared.refreshSystemState()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

struct SettingsView: View {
    @ObservedObject var services: AppServices

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ClipboardMenuBar")
                .font(.title2.weight(.semibold))

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { services.launchAtLoginEnabled },
                    set: { services.setLaunchAtLogin($0) }
                )
            )

            if services.launchAtLoginNeedsApproval {
                Text("macOS requires you to approve this app in Login Items after enabling launch at login.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if services.accessibilityEnabled {
                Label("Accessibility permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accessibility permission is required for automatic Cmd+V paste.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Grant Accessibility Permission") {
                            services.promptForAccessibilityPermission()
                        }
                        Button("Refresh Status") {
                            services.refreshSystemState()
                        }
                    }
                }
            }

            if let statusMessage = services.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Hotkey: Option + V")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            services.refreshSystemState()
        }
    }
}

@main
struct ClipboardMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var services = AppServices.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(services: services)
        } label: {
            Label("ClipboardMenuBar", systemImage: "clipboard")
        }
        .modelContainer(services.modelContainer)
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(services: services)
        }
        .modelContainer(services.modelContainer)
    }
}
