import SwiftUI

@main
struct OpenAbiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var store = RuleStore()

    var body: some Scene {
        Window("OpenAbi", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 560, minHeight: 520)
                .onOpenURL { Updater.shared.handle($0) }
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { Updater.shared.checkForUpdates() }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = Updater.shared
        FinderExtensionSetup.enableOnFirstLaunch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
