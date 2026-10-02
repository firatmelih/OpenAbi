import Foundation

enum OpenAbiShared {
    /// Team-prefixed (macOS-style) app group shared by the app and the Finder extension.
    static let appGroup = "XQH36L7379.com.melihfirat.OpenAbi"
    static let extensionBundleID = "com.melihfirat.OpenAbi.FinderExtension"

    /// The sandboxed extension can't make another app open arbitrary files, but scripts in its
    /// Application Scripts folder run unsandboxed. The app installs this one; the extension runs it.
    static let openScriptName = "open-with.sh"
    static let openScript = """
        #!/bin/sh
        # Installed by OpenAbi. Usage: open-with.sh <app path> <item>...
        app="$1"
        shift
        exec /usr/bin/open -a "$app" "$@"

        """
}

/// An application the user dropped onto a target.
struct LinkedApp: Codable, Hashable, Identifiable {
    var path: String
    var name: String

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
}

/// What kind of Finder item a rule applies to.
enum TargetKind: Codable, Hashable {
    case folders
    case allFiles
    case fileExtension(String)

    var title: String {
        switch self {
        case .folders: "Folders"
        case .allFiles: "All Files"
        case .fileExtension(let ext): ".\(ext) Files"
        }
    }

    func matches(isFolder: Bool, fileExtension ext: String) -> Bool {
        switch self {
        case .folders: isFolder
        case .allFiles: !isFolder
        case .fileExtension(let wanted): !isFolder && wanted == ext
        }
    }

    /// Lower sorts first: specific extensions win over the generic catch-alls.
    var priority: Int {
        switch self {
        case .fileExtension: 0
        case .allFiles, .folders: 1
        }
    }
}

struct Rule: Codable, Hashable, Identifiable {
    var id = UUID()
    var target: TargetKind
    var apps: [LinkedApp] = []
}

struct Configuration: Codable {
    var rules: [Rule]

    static let `default` = Configuration(rules: [Rule(target: .folders), Rule(target: .allFiles)])

    /// Apps that can open every one of `urls`, most specific first, without duplicates.
    func apps(for urls: [URL]) -> [LinkedApp] {
        guard let first = urls.first else { return [] }
        var result = apps(for: first)
        for url in urls.dropFirst() {
            let paths = Set(apps(for: url).map(\.path))
            result.removeAll { !paths.contains($0.path) }
        }
        return result
    }

    func apps(for url: URL) -> [LinkedApp] {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        // Packages (Foo.xcodeproj, Bar.app) behave like files so extension rules can target them.
        let isFolder = (values?.isDirectory ?? url.hasDirectoryPath) && !(values?.isPackage ?? false)
        let ext = url.pathExtension.lowercased()

        var seen = Set<String>()
        return rules
            .filter { $0.target.matches(isFolder: isFolder, fileExtension: ext) }
            .sorted { $0.target.priority < $1.target.priority }
            .flatMap(\.apps)
            .filter { seen.insert($0.path).inserted }
    }
}

enum ConfigurationStore {
    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: OpenAbiShared.appGroup)?
            .appendingPathComponent("rules.json")
    }

    static func load() -> Configuration {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Configuration.self, from: data)
        else { return .default }
        return config
    }

    static func save(_ config: Configuration) throws {
        guard let url = fileURL else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "App group container is unavailable."])
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
    }
}
