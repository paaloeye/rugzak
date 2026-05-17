import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: ArchiveManager
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            DropTargetView(isTargeted: $isTargeted)
                .ignoresSafeArea()

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
        }
        .frame(minWidth: 480, minHeight: 320)
        .overlay {
            if isTargeted {
                dropOverlay
            }
        }
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
        List(manager.mounts) { archive in
            MountRow(archive: archive)
        }
        .listStyle(.inset)
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

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.accentColor, lineWidth: 3)
            .background(Color.accentColor.opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 12)))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentColor)
                    Text("Mount Archive")
                        .font(.headline)
                }
            }
            .padding(8)
            .allowsHitTesting(false)
    }
}

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
                Text(archive.archivePath.lastPathComponent)
                    .font(.body)
                Text(archive.mountPoint.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(archive.mountedAt, style: .relative)
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

#Preview {
    ContentView()
        .environmentObject(ArchiveManager.shared)
}
