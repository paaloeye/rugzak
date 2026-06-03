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
    @Environment(ArchiveManager.self) private var manager: ArchiveManager
    @Environment(\.openWindow) private var openWindow

    @AppStorage("rowFontSize") private var fontSize: Double = RowFontSizeKey.defaultValue

    @State private var dropState: DropState

    init(dropState: DropState = .idle) {
        _dropState = State(initialValue: dropState)
    }

    var body: some View {
        ZStack {
            TranslucentBackgroundEffect(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

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
        .toolbarBackground(.thinMaterial, for: .windowToolbar)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Archives Mounted", systemImage: "archivebox")
        } description: {
            Text("Drop an archive here or on the Dock icon.\nSupported: zip, tar, tar.gz, tar.bz2, tar.xz, ipsw, xip")
        }
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

    @Environment(ArchiveManager.self) private var archiveManager: ArchiveManager
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
                archiveManager.openInFinder(archive)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Open in Finder")

            Button {
                archiveManager.openInTerminal(archive)
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
            archiveManager.openInFinder(archive)
        }
        .confirmationDialog(
            "Unmount \(archive.archivePath.lastPathComponent)?",
            isPresented: $showingUnmountConfirm,
            titleVisibility: .visible
        ) {
            Button("Unmount", role: .destructive) {
                archiveManager.unmount(archive)
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
            .environment(ArchiveManager.preview())
    }

    #Preview("With mounts") {
        ContentView()
            .environment(ArchiveManager.previewWithMounts())
    }

    #Preview("With error") {
        ContentView()
            .environment(
                ArchiveManager.preview(
                    error: "fuse-archive not found. Install it with: brew install fuse-archive"
                ))
    }

    #Preview("Drop targeted — accepting") {
        ContentView(dropState: .accepting)
            .environment(ArchiveManager.preview())
    }

    #Preview("Drop targeted — rejecting") {
        ContentView(dropState: .rejecting)
            .environment(ArchiveManager.preview())
    }

    #Preview("Drop targeted — already mounted") {
        ContentView(dropState: .alreadyMounted)
            .environment(ArchiveManager.previewWithMounts())
    }

    // MARK - README

    #Preview("Rugzak") {
        ContentView()
            .environment(ArchiveManager.previewWithMounts())
            .preferredColorScheme(.light)
    }

    #Preview("Rugzak") {
        ContentView()
            .environment(ArchiveManager.previewWithMounts())
            .preferredColorScheme(.dark)
    }

#endif
