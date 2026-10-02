import FinderSync
import SwiftUI

struct ContentView: View {
    @Environment(RuleStore.self) private var store
    @State private var newExtensions = ""

    var body: some View {
        VStack(spacing: 0) {
            ExtensionStatusBar()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Drag apps from Finder onto a type. They'll show up when you right-click matching items in Finder.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if !store.folderSuggestions.isEmpty {
                        QuickSetupCard()
                    }

                    ForEach(store.rules) { rule in
                        RuleCard(rule: rule)
                    }

                    addTypeRow

                    Divider().padding(.vertical, 6)

                    FinderMenuSettings()
                }
                .padding(20)
            }

            if let error = store.errorMessage {
                Divider()
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
        }
    }

    private var addTypeRow: some View {
        HStack {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
            TextField("Add file types, e.g. md, json, xcodeproj", text: $newExtensions)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addExtensions)
            Button("Add", action: addExtensions)
                .disabled(newExtensions.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.top, 4)
    }

    private func addExtensions() {
        store.addFileExtensions(newExtensions)
        newExtensions = ""
    }
}

// MARK: - Quick setup

private struct QuickSetupCard: View {
    @Environment(RuleStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quick setup")
                        .font(.headline)
                    Text("Open folders in these apps with a right-click.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add All to Folders") {
                    store.addToFolders(store.folderSuggestions)
                }
                .buttonStyle(.borderedProminent)
            }

            FlowingChips(apps: store.folderSuggestions) { app in
                Button {
                    store.addToFolders([app])
                } label: {
                    AppLabel(app: app, trailingSymbol: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .help("Add \(app.name) to Folders")
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.25)))
    }
}

// MARK: - Finder menu settings

private struct FinderMenuSettings: View {
    @Environment(RuleStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 10) {
            Text("Finder Menu")
                .font(.headline)

            Toggle("Group apps in an “OpenAbi” submenu", isOn: $store.groupInSubmenu)

            Text(preview)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)

            Label {
                Text("Add a one-click OpenAbi button to Finder's toolbar: in any Finder window, choose **View ▸ Customize Toolbar…** and drag the mustache in.")
            } icon: {
                Image(systemName: "mustache")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private var preview: String {
        let names = store.rules.first { $0.target == .folders }?.apps.prefix(2).map(\.name) ?? []
        let examples = names.isEmpty ? ["Visual Studio Code"] : Array(names)
        let titles = examples.map { LinkedApp(path: "", name: $0).menuTitle(inSubmenu: store.groupInSubmenu) }
        return store.groupInSubmenu
            ? "OpenAbi ▸  " + titles.joined(separator: " · ")
            : titles.joined(separator: "\n")
    }
}

// MARK: - Rule card

private struct RuleCard: View {
    @Environment(RuleStore.self) private var store
    let rule: Rule
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                Text(rule.target.title)
                    .font(.headline)
                Spacer()
                Button {
                    store.chooseApps(for: rule.id)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Choose an app…")
                if case .fileExtension = rule.target {
                    Button {
                        store.removeRule(rule.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this file type")
                }
            }

            dropZone
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .dropDestination(for: URL.self) { urls, _ in
            store.addApps(at: urls, to: rule.id)
        } isTargeted: { isDropTargeted = $0 }
    }

    private var dropZone: some View {
        Group {
            if rule.apps.isEmpty {
                Text("Drop apps here")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 56)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(rule.apps) { app in
                            AppChip(app: app) { store.removeApp(app, from: rule.id) }
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 56)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(isDropTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                .background(isDropTargeted ? Color.accentColor.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .animation(.easeOut(duration: 0.12), value: isDropTargeted)
    }

    private var symbol: String {
        switch rule.target {
        case .folders: "folder"
        case .allFiles: "doc"
        case .fileExtension: "doc.text"
        }
    }
}

private struct AppChip: View {
    let app: LinkedApp
    let onRemove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            AppIcon(app: app)
            Text(app.name)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.35)
            .help("Remove \(app.name)")
        }
        .chipStyle()
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
            Button("Remove", role: .destructive, action: onRemove)
        }
    }
}

private struct AppLabel: View {
    let app: LinkedApp
    let trailingSymbol: String

    var body: some View {
        HStack(spacing: 6) {
            AppIcon(app: app)
            Text(app.name)
                .lineLimit(1)
            Image(systemName: trailingSymbol)
                .foregroundStyle(.tint)
        }
        .chipStyle()
    }
}

private struct AppIcon: View {
    let app: LinkedApp

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
            .resizable()
            .frame(width: 22, height: 22)
    }
}

/// Wraps chips onto multiple lines.
private struct FlowingChips<Chip: View>: View {
    let apps: [LinkedApp]
    @ViewBuilder let chip: (LinkedApp) -> Chip

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(apps) { chip($0) }
        }
    }
}

private extension View {
    func chipStyle() -> some View {
        padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(.background, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator))
    }
}

// MARK: - Extension status

private struct ExtensionStatusBar: View {
    @State private var isEnabled = FIFinderSyncController.isExtensionEnabled
    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isEnabled ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(isEnabled ? "Finder extension is enabled" : "Finder extension is turned off")
                .font(.callout)
            Spacer()
            if !isEnabled {
                Button("Enable in System Settings…") {
                    FIFinderSyncController.showExtensionManagementInterface()
                }
            }
            Button("v\(Self.version) · Check for Updates…") {
                Updater.shared.checkForUpdates()
            }
            .buttonStyle(.link)
            .font(.callout)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .task {
            // Picks up changes made in System Settings or by first-launch setup.
            while !Task.isCancelled {
                isEnabled = FIFinderSyncController.isExtensionEnabled
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
