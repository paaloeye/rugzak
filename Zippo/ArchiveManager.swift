import AppKit
import Combine
import Foundation

@MainActor
final class ArchiveManager: ObservableObject {
    static let shared = ArchiveManager()

    @Published private(set) var mounts: [MountedArchive] = []
    @Published var errorMessage: String?

    let mountsDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Mounts", isDirectory: true)
    }()

    static let supportedExtensions: Set<String> = ["zip", "tar", "gz", "tgz", "bz2", "xz", "tbz", "tbz2"]

    private init() {
        createMountsDirectoryIfNeeded()
        reconcile()
    }

    func mount(_ archiveURL: URL) {
        guard !mounts.contains(where: { $0.archivePath == archiveURL }) else { return }
        let name = archiveURL.deletingPathExtension().lastPathComponent
        let mountPoint = uniqueMountPoint(for: name)
        Task {
            do {
                try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
                try await FuseProcess.mount(archive: archiveURL, mountPoint: mountPoint)
                let archive = MountedArchive(id: UUID(), archivePath: archiveURL, mountPoint: mountPoint, mountedAt: .now)
                mounts.append(archive)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func unmount(_ archive: MountedArchive) {
        Task {
            do {
                try await UmountProcess.unmount(mountPoint: archive.mountPoint)
                mounts.removeAll { $0.id == archive.id }
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reconcile() {
        let found = MountReconciler.activeMounts(under: mountsDirectory)
        mounts = found
    }

    private func createMountsDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: mountsDirectory, withIntermediateDirectories: true)
    }

    private func uniqueMountPoint(for name: String) -> URL {
        var candidate = mountsDirectory.appendingPathComponent(name)
        var suffix = 1
        while mounts.contains(where: { $0.mountPoint == candidate }) {
            candidate = mountsDirectory.appendingPathComponent("\(name)_\(suffix)")
            suffix += 1
        }
        return candidate
    }
}
