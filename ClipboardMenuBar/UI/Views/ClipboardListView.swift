import SwiftUI

struct ClipboardListView: View {
    @ObservedObject var clipboardStore: ClipboardStore
    @ObservedObject var panelController: PanelController

    @State private var searchText = ""
    @State private var selectedIndex = 0

    private var items: [ClipboardItem] {
        clipboardStore.fetchItems(searchText: searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Clipboard History")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Clear") {
                    clipboardStore.clearAll()
                    selectedIndex = 0
                }
                .buttonStyle(.borderless)
            }

            TextField("Search text history", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in
                    selectedIndex = 0
                }

            if panelController.accessibilityEnabled == false {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Accessibility permission is required for automatic paste.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Button("Refresh") {
                            panelController.notifyPermissionStateChanged()
                        }
                        Button("Grant") {
                            panelController.requestAccessibilityPermission()
                        }
                    }
                }
                .padding(10)
                .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if items.isEmpty {
                ContentUnavailableView("No clipboard history", systemImage: "clipboard", description: Text("Copy text or images to start building history."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    selectedIndex = index
                                    _ = panelController.paste(item)
                                } label: {
                                    ClipboardRowView(item: item, isSelected: selectedIndex == index)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        clipboardStore.togglePin(item)
                                    } label: {
                                        Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                                    }
                                    Button(role: .destructive) {
                                        let currentCount = items.count
                                        clipboardStore.delete(item)
                                        selectedIndex = min(index, max(currentCount - 2, 0))
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .id(item.id)
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        guard items.indices.contains(newValue) else { return }
                        proxy.scrollTo(items[newValue].id, anchor: .center)
                    }
                }
            }

            HStack {
                Text("⌥V 打开  ·  ↑↓ 选择  ·  Enter 粘贴  ·  Esc 关闭")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .font(.footnote)
        }
        .padding(16)
        .frame(width: 460, height: 520)
        .background(
            KeyEventHandlingView { event in
                handleKeyDown(event)
            }
        )
        .onAppear {
            panelController.notifyPermissionStateChanged()
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard items.isEmpty == false else {
            if event.keyCode == 53 { panelController.hide() }
            return
        }

        switch event.keyCode {
        case 125:
            selectedIndex = min(selectedIndex + 1, max(items.count - 1, 0))
        case 126:
            selectedIndex = max(selectedIndex - 1, 0)
        case 36, 76:
            guard items.indices.contains(selectedIndex) else { return }
            _ = panelController.paste(items[selectedIndex])
        case 53:
            panelController.hide()
        default:
            break
        }
    }
}

struct KeyEventHandlingView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }
}

final class KeyView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }
}
