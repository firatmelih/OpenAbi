import Cocoa
import FinderSync

/// Adds "Open in <App>" items to Finder's context menu and toolbar button based on the rules set up in the app.
class FinderSync: FIFinderSync {
    // Finder copies menu items and drops representedObject, so items carry an index (tag) into these.
    private var menuApps: [LinkedApp] = []
    private var menuTargets: [URL] = []

    override init() {
        super.init()
        updateWatchedDirectories()

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(volumesChanged), name: NSWorkspace.didMountNotification, object: nil)
        center.addObserver(self, selector: #selector(volumesChanged), name: NSWorkspace.didUnmountNotification, object: nil)
    }

    @objc private func volumesChanged(_ notification: Notification) {
        updateWatchedDirectories()
    }

    /// The context menu is only offered inside watched directories, so watch everything.
    private func updateWatchedDirectories() {
        var urls: Set<URL> = [URL(fileURLWithPath: "/")]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
        urls.formUnion(volumes)
        FIFinderSyncController.default().directoryURLs = urls
    }

    // MARK: - Toolbar button (Finder ▸ View ▸ Customize Toolbar…)

    override var toolbarItemName: String { "OpenAbi" }

    override var toolbarItemToolTip: String { "Open the selection, or this folder, in one of your apps" }

    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "mustache", accessibilityDescription: "OpenAbi") ?? NSImage()
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        UpdateCheck.checkIfDue()
        let controller = FIFinderSyncController.default()
        let selection = controller.selectedItemURLs() ?? []
        let folder = controller.targetedURL().map { [$0] } ?? []

        switch menuKind {
        case .contextualMenuForItems:
            return contextMenu(for: selection)
        case .contextualMenuForContainer:
            return contextMenu(for: folder)
        case .toolbarItemMenu:
            return toolbarMenu(for: selection.isEmpty ? folder : selection)
        default:
            return nil
        }
    }

    private func contextMenu(for targets: [URL]) -> NSMenu? {
        let config = ConfigurationStore.load()
        let items = appItems(for: targets, config: config)
        guard !items.isEmpty else { return nil }

        let menu = NSMenu(title: "")
        if config.groupInSubmenu {
            let submenu = NSMenu(title: "OpenAbi")
            items.forEach(submenu.addItem)
            let parent = NSMenuItem(title: "OpenAbi", action: nil, keyEquivalent: "")
            parent.image = NSImage(systemSymbolName: "mustache", accessibilityDescription: nil)
            parent.submenu = submenu
            menu.addItem(parent)
        } else {
            items.forEach(menu.addItem)
        }
        addUpdateItem(to: menu)
        return menu
    }

    /// The toolbar button always shows a menu, so it can point people to the app when nothing matches.
    private func toolbarMenu(for targets: [URL]) -> NSMenu {
        let config = ConfigurationStore.load()
        let menu = NSMenu(title: "")
        let items = appItems(for: targets, config: config, inSubmenu: false)
        if items.isEmpty {
            let empty = NSMenuItem(title: "No apps for this selection", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            items.forEach(menu.addItem)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "OpenAbi Settings…", action: #selector(openSettings(_:)), keyEquivalent: ""))
        addUpdateItem(to: menu)
        return menu
    }

    private func addUpdateItem(to menu: NSMenu) {
        guard let version = UpdateCheck.availableVersion else { return }
        let item = NSMenuItem(title: "Update OpenAbi to \(version)…", action: #selector(installUpdate(_:)), keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
        menu.addItem(item)
    }

    private func appItems(for targets: [URL], config: Configuration, inSubmenu: Bool? = nil) -> [NSMenuItem] {
        let apps = config.apps(for: targets)
        menuApps = apps
        menuTargets = targets

        let inSubmenu = inSubmenu ?? config.groupInSubmenu
        return apps.enumerated().map { index, app in
            let item = NSMenuItem(title: app.menuTitle(inSubmenu: inSubmenu), action: #selector(openWithApp(_:)), keyEquivalent: "")
            item.tag = index
            item.image = icon(for: app)
            return item
        }
    }

    // MARK: - Actions

    @objc private func openWithApp(_ sender: NSMenuItem) {
        guard menuApps.indices.contains(sender.tag), !menuTargets.isEmpty else { return }
        let app = menuApps[sender.tag]
        let targets = menuTargets

        // NSWorkspace.open is refused for files outside our sandbox, so hand off to the unsandboxed script.
        do {
            let scripts = try FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let task = try NSUserUnixTask(url: scripts.appendingPathComponent(OpenAbiShared.openScriptName))
            task.execute(withArguments: [app.path] + targets.map(\.path)) { error in
                if let error {
                    NSLog("OpenAbi: failed to open %@ with %@: %@", targets.description, app.path, error.localizedDescription)
                }
            }
        } catch {
            NSLog("OpenAbi: open script unavailable (launch OpenAbi once to install it): %@", error.localizedDescription)
        }
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        // FinderExtension.appex lives in OpenAbi.app/Contents/PlugIns.
        let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func installUpdate(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(UpdateCheck.checkForUpdatesURL)
    }

    private func icon(for app: LinkedApp) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: app.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
