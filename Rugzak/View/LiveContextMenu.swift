//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  LiveContextMenu.swift
//  Rugzak
//
//  NSMenu-backed context menu that responds to Option key changes while open.
//

import AppKit
import SwiftUI

/// # Overview
///
/// `SwiftUI.contextMenu` evaluates its `@ViewBuilder` **once** at show time and never re-runs it
/// while the menu is open. `AppKit.NSMenu` drives its own private modal event loop on
/// `NSEventTrackingRunLoopMode`, which blocks normal event dispatch  so `NSEvent` local monitors
/// don't fire, `@State` doesn't update, and SwiftUI never re-renders an open menu.
///
/// `LiveContextMenu` works around this by owning the full `AppKit` menu stack.
///
/// ## Architecture
///
/// ```
/// right-click
///   → local NSEvent monitor fires (before hit testing)
///       → bounds check: is the event inside this view?
///       → items() closure runs   (captures live SwiftUI state)
///       → NSMenu built
///       → Timer started on .eventTracking run loop
///       → popUpContextMenu blocks
///           ↳ every 50 ms: poll NSEvent.modifierFlags
///                          → isHidden toggle
///       → menu dismissed → timer.invalidate()
///       → ClosureMenuItem.invoke() → original Swift action
/// ```
///
/// ## Layers
///
/// - `ClosureMenuItem`: bridges AppKit's selector-based action system to a Swift closure.
/// - ``InterceptView``: transparent `NSView` overlay (``InterceptView/hitTest(_:)`` returns `nil`)
///   that installs a local event monitor to intercept `rightMouseDown` events within its bounds,
///   builds the `NSMenu`, and manages the polling timer. Because ``InterceptView/hitTest(_:)`` is bypassed, all other
///   mouse events — clicks, button presses, gestures — pass through to SwiftUI as normal.
/// - `LiveContextMenuView`: `NSViewRepresentable` bridge that keeps ``InterceptView/items`` current as SwiftUI re-renders.
/// - ``LiveMenuBuilder``: `@resultBuilder` (same mechanism as `@ViewBuilder`) that transforms a flat statement block into `[LiveMenuItem]`.
///
/// ## The timer
///
/// `NSEvent` local monitors are not delivered into AppKit's menu modal session.
/// A `Timer` scheduled on `.eventTracking` *is* delivered, because that run loop mode stays active
/// for the duration of the modal session. The timer polls `NSEvent.modifierFlags` every 50 ms —
/// a class property that reads hardware keyboard state directly, bypassing the event queue — and
/// toggles `isHidden` on any debug items.
///
/// ## Why not `rightMouseDown(with:)`
///
/// Overriding `rightMouseDown` requires the view to win the hit test, which means it must return
/// `self` from `hitTest(_:)`. That makes the overlay opaque to all events, swallowing button
/// presses and tap gestures on child views. Using a local monitor instead lets `hitTest` return
/// `nil` (fully transparent), so only right-click is intercepted and everything else is untouched.
///
struct LiveMenuItem {
    let title: String
    let image: NSImage?
    let isEnabled: Bool
    /// Item is hidden unless Option is held when the menu opens, and toggled live while open.
    let isDebug: Bool
    let isDivider: Bool
    let action: () -> Void

    static func button(
        _ title: String,
        image: NSImage? = nil,
        isEnabled: Bool = true,
        isDebug: Bool = false,
        action: @escaping () -> Void
    ) -> LiveMenuItem {
        LiveMenuItem(
            title: title, image: image, isEnabled: isEnabled,
            isDebug: isDebug, isDivider: false, action: action)
    }

    static var divider: LiveMenuItem {
        LiveMenuItem(title: "", image: nil, isEnabled: false, isDebug: false, isDivider: true, action: {})
    }
}

// MARK: - Result builder

@resultBuilder
enum LiveMenuBuilder {
    static func buildBlock(_ components: [LiveMenuItem]...) -> [LiveMenuItem] { components.flatMap { $0 } }
    static func buildExpression(_ item: LiveMenuItem) -> [LiveMenuItem] { [item] }
    static func buildArray(_ components: [[LiveMenuItem]]) -> [LiveMenuItem] { components.flatMap { $0 } }
    static func buildOptional(_ component: [LiveMenuItem]?) -> [LiveMenuItem] { component ?? [] }
    static func buildEither(first component: [LiveMenuItem]) -> [LiveMenuItem] { component }
    static func buildEither(second component: [LiveMenuItem]) -> [LiveMenuItem] { component }
}

// MARK: - View modifier

extension View {
    func liveContextMenu(@LiveMenuBuilder _ items: @escaping () -> [LiveMenuItem]) -> some View {
        overlay(LiveContextMenuView(items: items))
    }
}

// MARK: - NSViewRepresentable

private struct LiveContextMenuView: NSViewRepresentable {
    let items: () -> [LiveMenuItem]

    func makeNSView(context: Context) -> InterceptView {
        InterceptView()
    }

    func updateNSView(_ nsView: InterceptView, context: Context) {
        nsView.items = items
    }
}

// MARK: - Intercepting NSView

final class InterceptView: NSView {
    var items: (() -> [LiveMenuItem])?
    private var monitor: Any?

    // Return nil so this view is invisible to hit testing — SwiftUI buttons and
    // gestures underneath work normally. Right-click is caught via the local monitor.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        removeMonitor()

        guard window != nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self, self.window != nil else { return event }
            let local = self.convert(event.locationInWindow, from: nil)
            guard self.bounds.contains(local) else { return event }
            self.showMenu(with: event)
            return nil
        }
    }

    override func removeFromSuperview() {
        removeMonitor()
        super.removeFromSuperview()
    }

    deinit { removeMonitor() }

    private func removeMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func showMenu(with event: NSEvent) {
        guard let items = items?() else { return }

        let menu = NSMenu()
        menu.autoenablesItems = false

        var debugItems: [NSMenuItem] = []
        for item in items {
            if item.isDivider {
                menu.addItem(.separator())
                continue
            }
            let menuItem = ClosureMenuItem(title: item.title, action: item.action)
            menuItem.image = item.image?.resized(to: NSSize(width: 16, height: 16))
            menuItem.isEnabled = item.isEnabled
            menuItem.isHidden = item.isDebug && !event.modifierFlags.contains(.option)
            if item.isDebug { debugItems.append(menuItem) }
            menu.addItem(menuItem)
        }

        // Local monitors don't fire during NSMenu's private modal event loop.
        // A timer in .eventTracking mode runs inside that loop and can poll modifier flags.
        var lastFlags = NSEvent.modifierFlags
        let timer = Timer(timeInterval: 0.05, repeats: true) { _ in
            let flags = NSEvent.modifierFlags
            guard flags != lastFlags else { return }
            lastFlags = flags
            let hidden = !flags.contains(.option)
            debugItems.forEach { $0.isHidden = hidden }
        }
        RunLoop.current.add(timer, forMode: .eventTracking)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
        timer.invalidate()
    }
}

// MARK: - Helpers

private final class ClosureMenuItem: NSMenuItem {
    private let closure: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.closure = action
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        self.target = self
    }

    required init(coder: NSCoder) { fatalError("not implemented") }

    @objc private func invoke() { closure() }
}

extension NSImage {
    fileprivate func resized(to size: NSSize) -> NSImage {
        let img = NSImage(size: size)
        img.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: self.size),
            operation: .copy,
            fraction: 1)
        img.unlockFocus()
        return img
    }
}
