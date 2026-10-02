import AppKit
import Observation
import UniformTypeIdentifiers

@Observable
final class RuleStore {
    private(set) var configuration: Configuration
    /// Installed preset editors/terminals that aren't on the Folders card yet.
    private(set) var folderSuggestions: [LinkedApp] = []
    var errorMessage: String?

    init() {
        configuration = ConfigurationStore.load()
        refreshSuggestions()
        do {
            try ScriptInstaller.install()
        } catch {
            errorMessage = "Couldn't install the Finder helper script: \(error.localizedDescription)"
        }
    }

    var rules: [Rule] { configuration.rules }

    var groupInSubmenu: Bool {
        get { configuration.groupInSubmenu }
        set {
            configuration.groupInSubmenu = newValue
            save()
        }
    }

    func addToFolders(_ apps: [LinkedApp]) {
        if !configuration.rules.contains(where: { $0.target == .folders }) {
            configuration.rules.insert(Rule(target: .folders), at: 0)
        }
        guard let ruleID = configuration.rules.first(where: { $0.target == .folders })?.id else { return }
        update(ruleID) { rule in
            for app in apps where !rule.apps.contains(where: { $0.path == app.path }) {
                rule.apps.append(app)
            }
        }
    }

    /// Adds every application among `urls` to the rule. Returns false if none were apps.
    @discardableResult
    func addApps(at urls: [URL], to ruleID: Rule.ID) -> Bool {
        let apps = urls.compactMap(LinkedApp.init(appURL:))
        guard !apps.isEmpty else { return false }
        update(ruleID) { rule in
            for app in apps where !rule.apps.contains(where: { $0.path == app.path }) {
                rule.apps.append(app)
            }
        }
        return true
    }

    func removeApp(_ app: LinkedApp, from ruleID: Rule.ID) {
        update(ruleID) { $0.apps.removeAll { $0.path == app.path } }
    }

    /// Accepts "md", ".md", "*.md" or a comma separated list of those.
    func addFileExtensions(_ input: String) {
        let extensions = input
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "*.")).lowercased() }
            .filter { !$0.isEmpty }

        for ext in extensions where !configuration.rules.contains(where: { $0.target == .fileExtension(ext) }) {
            configuration.rules.append(Rule(target: .fileExtension(ext)))
        }
        save()
    }

    func removeRule(_ ruleID: Rule.ID) {
        configuration.rules.removeAll { $0.id == ruleID }
        save()
    }

    func chooseApps(for ruleID: Rule.ID) {
        let panel = NSOpenPanel()
        panel.title = "Choose Applications"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        if panel.runModal() == .OK {
            addApps(at: panel.urls, to: ruleID)
        }
    }

    // MARK: - Private

    private func update(_ ruleID: Rule.ID, _ change: (inout Rule) -> Void) {
        guard let index = configuration.rules.firstIndex(where: { $0.id == ruleID }) else { return }
        change(&configuration.rules[index])
        save()
    }

    private func save() {
        refreshSuggestions()
        do {
            try ConfigurationStore.save(configuration)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't save rules: \(error.localizedDescription)"
        }
    }

    private func refreshSuggestions() {
        let added = Set(configuration.rules.filter { $0.target == .folders }.flatMap(\.apps).map(\.path))
        folderSuggestions = Presets.installedFolderApps().filter { !added.contains($0.path) }
    }
}

extension LinkedApp {
    /// Nil unless `appURL` is an application bundle.
    init?(appURL url: URL) {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
              type.conforms(to: .application)
        else { return nil }
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
        self.init(path: url.path, name: name)
    }
}
