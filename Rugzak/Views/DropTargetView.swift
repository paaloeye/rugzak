//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  DropTargetView.swift
//  Rugzak
//
//  NSView-backed drag-and-drop target that accepts archive files and shows drop feedback.
//

import AppKit
import SwiftUI
import os.log

enum DropState {
    case idle
    case accepting
    case rejecting
    case alreadyMounted
}

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DropTargetView")

@MainActor
struct DropTargetView: View {
    @Binding var dropState: DropState

    var body: some View {
        ArchiveDropNSView(dropState: $dropState)
            .ignoresSafeArea()
            .overlay {
                if dropState != .idle {
                    dropOverlay
                }
            }
    }

    @ViewBuilder
    private var dropOverlay: some View {
        let (color, icon, label): (Color, String, String) =
            switch dropState {
            case .accepting:
                (.accentColor, "plus.circle.fill", "Mount Archive")
            case .rejecting:
                (.red, "xmark.circle.fill", "Unsupported File")
            case .alreadyMounted:
                (.orange, "externaldrive.badge.checkmark", "Already Mounted")
            case .idle:
                (.clear, "", "")
            }
        RoundedRectangle(cornerRadius: 12)
            .stroke(color, lineWidth: 3)
            .background(color.opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 12)))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundStyle(color)
                    Text(label)
                        .font(.headline)
                        .foregroundStyle(color)
                }
            }
            .padding(8)
            .allowsHitTesting(false)
    }
}

@MainActor
private struct ArchiveDropNSView: NSViewRepresentable {
    @Binding var dropState: DropState

    func makeNSView(context: Context) -> ArchiveDropView {
        let view = ArchiveDropView()
        view.dropStateBinding = $dropState
        return view
    }

    func updateNSView(_ nsView: ArchiveDropView, context: Context) {}
}

final class ArchiveDropView: NSView {
    var dropStateBinding: Binding<DropState>?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let state = computeDropState(for: sender)
        dropStateBinding?.wrappedValue = state
        return state == .accepting ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropStateBinding?.wrappedValue = .idle
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropStateBinding?.wrappedValue = .idle
        let urls = archiveURLs(from: sender)
        guard !urls.isEmpty else { return false }
        for url in urls {
            ArchiveManager.shared.mount(url)
        }
        return true
    }

    private func computeDropState(for sender: NSDraggingInfo) -> DropState {
        let urls = archiveURLs(from: sender)
        guard !urls.isEmpty else {
            logger.debug("computeDropState → rejecting (no valid archive URLs)")
            return .rejecting
        }

        let mountedStems = ArchiveManager.shared.mounts.map { $0.mountPoint.lastPathComponent }
        logger.debug("computeDropState: mountedStems=\(mountedStems)")

        let allMounted = urls.allSatisfy { url in
            let stem = url.deletingPathExtension().lastPathComponent
            let matched = mountedStems.contains(stem)
            logger.debug("computeDropState: \(url.lastPathComponent) stem=\(stem) matched=\(matched)")
            return matched
        }
        let state: DropState = allMounted ? .alreadyMounted : .accepting
        logger.debug("computeDropState → \(String(describing: state))")
        return state
    }

    private func archiveURLs(from sender: NSDraggingInfo) -> [URL] {
        guard
            let items = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]) as? [URL]
        else {
            logger.debug("archiveURLs: pasteboard read returned nil")
            return []
        }
        let filtered = items.filter { ArchiveManager.supportedExtensions.contains($0.pathExtension.lowercased()) }
        let rejected = items.filter { !ArchiveManager.supportedExtensions.contains($0.pathExtension.lowercased()) }
        if !rejected.isEmpty {
            logger.debug("archiveURLs: rejected (unsupported ext): \(rejected.map(\.lastPathComponent))")
        }
        logger.debug("archiveURLs: accepted=\(filtered.map(\.lastPathComponent))")
        return filtered
    }
}

#Preview("Idle") {
    DropTargetView(dropState: .constant(.idle))
        .frame(width: 480, height: 320)
}

#Preview("Accepting") {
    DropTargetView(dropState: .constant(.accepting))
        .frame(width: 480, height: 320)
}

#Preview("Rejecting") {
    DropTargetView(dropState: .constant(.rejecting))
        .frame(width: 480, height: 320)
}

#Preview("Already mounted") {
    DropTargetView(dropState: .constant(.alreadyMounted))
        .frame(width: 480, height: 320)
}
