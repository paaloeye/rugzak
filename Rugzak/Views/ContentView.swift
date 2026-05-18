//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  ContentView.swift
//  Rugzak
//
//  Main window: empty-state prompt, mounted-archive list, and error banner.
//

import SwiftUI
import os.log

struct RowFontSizeKey: EnvironmentKey {
    static let defaultValue: Double = 14
}

extension EnvironmentValues {
    var rowFontSize: Double {
        get { self[RowFontSizeKey.self] }
        set { self[RowFontSizeKey.self] = newValue }
    }
}

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ContentView")

@MainActor
struct ContentView: View {
    @EnvironmentObject var manager: ArchiveManager
    @Environment(\.openWindow) private var openWindow
    @State private var dropState: DropState
    @AppStorage("rowFontSize") private var fontSize: Double = RowFontSizeKey.defaultValue

    init(dropState: DropState = .idle) {
        _dropState = State(initialValue: dropState)
    }

    var body: some View {
        ZStack {
            DropTargetView(dropState: $dropState)

            VStack(spacing: 0) {
                if manager.mounts.isEmpty {
                    emptyState
                } else {
                    mountList
                }

                if let error = manager.errorMessage {
                    errorBanner(error)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(dropState == .idle ? 1 : 0)
        }
        .frame(minWidth: 480, minHeight: 320)
        .environment(\.rowFontSize, fontSize)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    openWindow(id: "about")
                } label: {
                    Image(systemName: "info.circle")
                }
                .foregroundStyle(Color.brandText)
                .help("About Rugzak")
            }
        }
        .toolbarBackground(Color.brandBackground, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .background(Color.brandBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drop an archive here or on the Dock icon")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Supported: zip, tar, tar.gz, tar.bz2, tar.xz, ipsw, xip")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mountList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(manager.mounts) { archive in
                    MountRow(archive: archive)
                    Divider()
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
            Button("Dismiss") { manager.errorMessage = nil }
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

}

@MainActor
private struct MountRow: View {
    let archive: MountedArchive
    @EnvironmentObject var manager: ArchiveManager
    @Environment(\.rowFontSize) private var fontSize
    @State private var showingUnmountConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.checkmark")
                .foregroundStyle(.green)
                .font(.system(size: fontSize))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(archive.displayName)
                    .font(.system(size: fontSize))
                Text(archive.mountPoint.path)
                    .font(.system(size: fontSize - 2))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                manager.openInFinder(archive)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Open in Finder")

            Button {
                manager.openInTerminal(archive)
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.borderless)
            .help("Open in Terminal")

            Button("Unmount") {
                showingUnmountConfirm = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            manager.openInFinder(archive)
        }
        .confirmationDialog(
            "Unmount \(archive.archivePath.lastPathComponent)?",
            isPresented: $showingUnmountConfirm,
            titleVisibility: .visible
        ) {
            Button("Unmount", role: .destructive) {
                manager.unmount(archive)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(archive.mountPoint.path)
        }
    }
}

// MARK: - Preview

#if DEBUG

    #Preview("Empty state") {
        ContentView()
            .environmentObject(ArchiveManager.preview())
    }

    #Preview("With mounts") {
        ContentView()
            .environmentObject(ArchiveManager.previewWithMounts())
    }

    #Preview("With error") {
        ContentView()
            .environmentObject(
                ArchiveManager.preview(
                    error: "fuse-archive not found. Install it with: brew install fuse-archive"
                ))
    }

    #Preview("Drop targeted — accepting") {
        ContentView(dropState: .accepting)
            .environmentObject(ArchiveManager.preview())
    }

    #Preview("Drop targeted — rejecting") {
        ContentView(dropState: .rejecting)
            .environmentObject(ArchiveManager.preview())
    }

    #Preview("Drop targeted — already mounted") {
        ContentView(dropState: .alreadyMounted)
            .environmentObject(ArchiveManager.previewWithMounts())
    }

    // MARK - README

    #Preview("Rugzak") {
        ContentView()
            .environmentObject(ArchiveManager.previewWithMounts())
            .preferredColorScheme(.light)
    }

    #Preview("Rugzak") {
        ContentView()
            .environmentObject(ArchiveManager.previewWithMounts())
            .preferredColorScheme(.dark)
    }

#endif
