import SwiftUI
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ContentView")

@MainActor
struct ContentView: View {
    @EnvironmentObject var manager: ArchiveManager
    @State private var dropState: DropState

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
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drop an archive here or on the Dock icon")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Supported: zip, tar, tar.gz, tar.bz2, tar.xz")
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
    @State private var showingUnmountConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.checkmark")
                .foregroundStyle(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(archive.displayName)
                    .font(.body)
                Text(archive.mountPoint.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(archive.mountedAt.formatted(.relative(presentation: .numeric)))
                .font(.caption)
                .foregroundStyle(.tertiary)

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

#Preview("Empty state") {
    ContentView()
        .environmentObject(ArchiveManager.preview())
}

#Preview("With mounts") {
    // raise(SIGSTOP) // pauses process — attach LLDB before crash
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
