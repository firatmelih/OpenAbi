import Foundation

enum ScriptInstaller {
    /// ~/Library/Application Scripts/<extension bundle id>/open-with.sh
    static var scriptURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Scripts", isDirectory: true)
            .appendingPathComponent(OpenAbiShared.extensionBundleID, isDirectory: true)
            .appendingPathComponent(OpenAbiShared.openScriptName)
    }

    /// Writes the open script if it's missing or outdated.
    static func install() throws {
        let url = scriptURL
        let fileManager = FileManager.default
        let data = Data(OpenAbiShared.openScript.utf8)

        if fileManager.contents(atPath: url.path) != data {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}

enum FinderExtensionSetup {
    private static let didAutoEnableKey = "didAutoEnableFinderExtension"

    /// Registers and turns on the bundled Finder extension the first time the app runs,
    /// so people don't have to find it in System Settings. Respects a later manual opt-out.
    static func enableOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didAutoEnableKey) else { return }
        defaults.set(true, forKey: didAutoEnableKey)

        if let appex = Bundle.main.builtInPlugInsURL?.appendingPathComponent("FinderExtension.appex") {
            pluginkit(["-a", appex.path])
        }
        pluginkit(["-e", "use", "-i", OpenAbiShared.extensionBundleID])
    }

    private static func pluginkit(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("OpenAbi: pluginkit %@ failed: %@", arguments.joined(separator: " "), error.localizedDescription)
        }
    }
}
