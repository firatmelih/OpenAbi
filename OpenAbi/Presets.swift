import AppKit

/// Popular editors and terminals that open a folder as a project or at that path.
enum Presets {
    static let folderAppBundleIDs = [
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.exafunction.windsurf",
        "dev.zed.Zed",
        "com.vscodium",
        "com.sublimetext.4",
        "com.panic.Nova",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
    ]

    /// The preset apps that are installed on this Mac.
    static func installedFolderApps() -> [LinkedApp] {
        folderAppBundleIDs
            .compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .compactMap(LinkedApp.init(appURL:))
    }
}
