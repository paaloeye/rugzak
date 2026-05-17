import Foundation

struct MountedArchive: Identifiable, Sendable {
    let id: UUID
    let archivePath: URL
    let mountPoint: URL
    let mountedAt: Date
}
