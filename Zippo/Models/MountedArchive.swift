import Foundation

/// A single archive currently mounted via fuse-archive.
struct MountedArchive: Identifiable, Sendable {
    /// Stable identity used by SwiftUI diffing and unmount look-ups.
    let id: UUID

    /// Absolute path to the source archive file on disk.
    let archivePath: URL

    /// Directory where the archive contents are exposed by macFUSE.
    let mountPoint: URL

    /// Wall-clock time the mount was registered in-process.
    let mountedAt: Date

    /// Human-readable name shown in the mount list.
    ///
    /// `archivePath.lastPathComponent` is a macFUSE device string (e.g. `fuse-archive@macfuse0`)
    /// when the mount was discovered via `getmntinfo` on cold launch rather than mounted in this
    /// process. In that case the mount-point folder name is used instead.
    var displayName: String {
        let name = archivePath.lastPathComponent
        return name.contains("@macfuse") ? mountPoint.lastPathComponent : name
    }
}
