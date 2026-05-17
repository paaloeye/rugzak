import Darwin
import Foundation

struct MountReconciler {
    nonisolated static func activeMounts(under directory: URL) -> [MountedArchive] {
        var list: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&list, MNT_NOWAIT)
        guard count > 0, let list else { return [] }
        let root = directory.standardized

        var result: [MountedArchive] = []
        for i in 0..<Int(count) {
            let entry = list[i]
            let mountOn = stringFromCTuple(entry.f_mntonname)
            let mountPointURL = URL(fileURLWithPath: mountOn).standardized
            guard mountPointURL.deletingLastPathComponent() == root else { continue }
            let mountFrom = stringFromCTuple(entry.f_mntfromname)
            result.append(
                MountedArchive(
                    id: UUID(),
                    archivePath: URL(fileURLWithPath: mountFrom),
                    mountPoint: mountPointURL,
                    mountedAt: .now
                ))
        }
        return result
    }

    private static func stringFromCTuple<T>(_ tuple: T) -> String {
        withUnsafeBytes(of: tuple) { ptr in
            String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
    }
}
