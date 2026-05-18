import SwiftUI

@main
struct ZippoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Zippo", id: "main") {
            ContentView()
                .environmentObject(ArchiveManager.shared)
        }
        .windowResizability(.contentSize)
        .commands {
            ZippoCommands()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        for url in urls {
            ArchiveManager.shared.mount(url)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
