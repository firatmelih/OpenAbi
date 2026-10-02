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
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FinderExtensionSetup.enableOnFirstLaunch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
