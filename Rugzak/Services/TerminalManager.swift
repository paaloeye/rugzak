//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  TerminalManager.swift
//  Rugzak
//
//  Observable service that owns the list of supported terminal emulators and drives open operations.
//

import AppKit
import Foundation
import os.log

enum Terminal: String, CaseIterable, Identifiable {
    case ghostty = "ghostty"
    case ghosttyDebug = "ghosttyDebug"
    case appleTerminal = "appleTerminal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ghostty: "Ghostty"
        case .ghosttyDebug: "Ghostty[DEBUG]"
        case .appleTerminal: "Terminal"
        }
    }

    var bundleID: String {
        switch self {
        case .ghostty: "com.mitchellh.ghostty"
        case .ghosttyDebug: "com.mitchellh.ghostty.debug"
        case .appleTerminal: "com.apple.Terminal"
        }
    }
}

@MainActor
@Observable
final class TerminalManager {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TerminalManager.self)
    )

    static let shared: TerminalManager = {
        #if DEBUG
            if Debug.isPreview {
                return TerminalManager(preview: ())
            }
        #endif
        return TerminalManager()
    }()

    var lastUsed: Terminal = .ghostty {
        didSet { UserDefaults.standard.set(lastUsed.rawValue, forKey: "lastUsedTerminal") }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "lastUsedTerminal"),
            let t = Terminal(rawValue: raw)
        {
            lastUsed = t
        }
    }

    func isAvailable(_ terminal: Terminal) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleID) != nil
    }

    func icon(for terminal: Terminal) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)!
    }

    func open(_ terminal: Terminal, at mountPoint: URL) {
        lastUsed = terminal
        switch terminal {
        case .ghostty, .ghosttyDebug:
            openViaGhosttyAppleScript(bundleID: terminal.bundleID, path: mountPoint.path)
        case .appleTerminal:
            openViaTerminalAppleScript(path: mountPoint.path)
        }
    }

    private func openViaGhosttyAppleScript(bundleID: String, path: String) {
        let escaped =
            path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let src = """
            tell application id "\(bundleID)"
                set cfg to new surface configuration
                set initial working directory of cfg to "\(escaped)"
                try
                    set w to front window
                    new tab in w with configuration cfg
                on error
                    new window with configuration cfg
                end try
            end tell
            """
        logger.debug("Opening \(path) in \(bundleID) via AppleScript")
        execute(src)
    }

    private func openViaTerminalAppleScript(path: String) {
        let escaped =
            path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let src = """
            tell application "Terminal"
                activate
                if (count of windows) > 0 then
                    do script "cd " & quoted form of "\(escaped)" in front window
                else
                    do script "cd " & quoted form of "\(escaped)"
                end if
            end tell
            """
        logger.debug("Opening \(path) in Terminal via AppleScript")
        execute(src)
    }

    private func execute(_ src: String) {
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
        if let err {
            let number = err[NSAppleScript.errorNumber] as? Int ?? -1
            let message = err[NSAppleScript.errorMessage] as? String ?? "unknown"
            let appName = err[NSAppleScript.errorAppName] as? String ?? "unknown"
            let range = err[NSAppleScript.errorRange] as? String ?? "unknown"

            logger.error("AppleScript failed [\(number)][\(range)][\(appName)] \(message)")
        }
    }

    // MARK: - Preview

    #if DEBUG
        private init(preview _: ()) {}

        static func preview() -> TerminalManager {
            TerminalManager(preview: ())
        }
    #endif
}
