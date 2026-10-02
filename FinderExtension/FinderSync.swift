import Cocoa
import FinderSync

/// Adds "<App> — OpenAbi" items to Finder's context menu based on the rules set up in the app.
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

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = FIFinderSyncController.default()
        let targets: [URL]
        switch menuKind {
        case .contextualMenuForItems:
            targets = controller.selectedItemURLs() ?? []
        case .contextualMenuForContainer:
            targets = controller.targetedURL().map { [$0] } ?? []
        default:
            return nil
        }

        let apps = ConfigurationStore.load().apps(for: targets)
        guard !apps.isEmpty else { return nil }
        menuApps = apps
        menuTargets = targets

        let menu = NSMenu(title: "")
        for (index, app) in apps.enumerated() {
            let item = NSMenuItem(title: "\(app.name) — OpenAbi", action: #selector(openWithApp(_:)), keyEquivalent: "")
            item.tag = index
            item.image = icon(for: app)
            menu.addItem(item)
        }
        return menu
    }

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

    private func icon(for app: LinkedApp) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: app.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
