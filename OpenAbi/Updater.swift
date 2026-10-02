import Sparkle

/// Sparkle's standard updater: checks the appcast, shows release notes, installs and relaunches.
final class Updater {
    static let shared = Updater()

    private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// Handles openabi://check-for-updates from the Finder extension's "Update OpenAbi…" item.
    func handle(_ url: URL) {
        if url.scheme == "openabi", url.host == "check-for-updates" {
            checkForUpdates()
        }
    }
}
