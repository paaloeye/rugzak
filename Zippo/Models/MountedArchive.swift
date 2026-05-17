import Foundation

struct MountedArchive: Identifiable, Sendable {
    let id: UUID
    let archivePath: URL
    let mountPoint: URL
    let mountedAt: Date

    // archivePath.lastPathComponent is a fuse device string (e.g. "fuse-archive@macfuse0")
    // when the mount was discovered via getmntinfo on cold launch — fall back to mount folder name.
    var displayName: String {
        let name = archivePath.lastPathComponent
        return name.contains("@macfuse") ? mountPoint.lastPathComponent : name
    }
}
