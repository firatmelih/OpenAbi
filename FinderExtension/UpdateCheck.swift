import Foundation

/// People rarely open the app itself, so the extension peeks at the appcast once a day and,
/// when there's a newer version, Finder's menus offer "Update OpenAbi…" (which hands off to Sparkle in the app).
enum UpdateCheck {
    private static let latestVersionKey = "latestVersion"
    private static let lastCheckKey = "lastUpdateCheck"
    private static let interval: TimeInterval = 24 * 60 * 60

    static let checkForUpdatesURL = URL(string: "openabi://check-for-updates")!

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// The newer version found by the last check, if any.
    static var availableVersion: String? {
        guard let latest = UserDefaults.standard.string(forKey: latestVersionKey),
              latest.compare(currentVersion, options: .numeric) == .orderedDescending
        else { return nil }
        return latest
    }

    static func checkIfDue() {
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        guard now - defaults.double(forKey: lastCheckKey) > interval else { return }
        defaults.set(now, forKey: lastCheckKey)

        URLSession.shared.dataTask(with: OpenAbiShared.appcastURL) { data, _, _ in
            guard let data, let appcast = String(data: data, encoding: .utf8),
                  let latest = newestVersion(in: appcast)
            else { return }
            defaults.set(latest, forKey: latestVersionKey)
        }.resume()
    }

    private static func newestVersion(in appcast: String) -> String? {
        let pattern = try! NSRegularExpression(pattern: "<sparkle:shortVersionString>\\s*([^<\\s]+)\\s*</sparkle:shortVersionString>")
        let range = NSRange(appcast.startIndex..., in: appcast)
        return pattern.matches(in: appcast, range: range)
            .compactMap { Range($0.range(at: 1), in: appcast).map { String(appcast[$0]) } }
            .max { $0.compare($1, options: .numeric) == .orderedAscending }
    }
}
