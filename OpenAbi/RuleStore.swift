import AppKit
import Observation
import UniformTypeIdentifiers

@Observable
final class RuleStore {
    private(set) var configuration: Configuration
    var errorMessage: String?

    init() {
        configuration = ConfigurationStore.load()
        do {
            try ScriptInstaller.install()
        } catch {
            errorMessage = "Couldn't install the Finder helper script: \(error.localizedDescription)"
        }
    }

    var rules: [Rule] { configuration.rules }

    /// Adds every application among `urls` to the rule. Returns false if none were apps.
    @discardableResult
    func addApps(at urls: [URL], to ruleID: Rule.ID) -> Bool {
        let apps = urls.compactMap(Self.linkedApp(at:))
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
        do {
            try ConfigurationStore.save(configuration)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't save rules: \(error.localizedDescription)"
        }
    }

    private static func linkedApp(at url: URL) -> LinkedApp? {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
              type.conforms(to: .application)
        else { return nil }
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
        return LinkedApp(path: url.path, name: name)
    }
}
