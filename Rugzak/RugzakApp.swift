//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  RugzakApp.swift
//  Rugzak
//
//  App entry point; configures the main and About windows and the app delegate.
//

import SwiftUI

@main
struct RugzakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Rugzak", id: "main") {
            ContentView()
                .environmentObject(ArchiveManager.shared)
        }
        .windowResizability(.contentSize)
        .commands {
            RugzakCommands()
        }

        Window("About Rugzak", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
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
