//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  MountReconciler.swift
//  Rugzak
//
//  Reads the kernel mount table to reconcile live FUSE mounts with app state.
//

import Darwin
import Foundation

struct MountReconciler {
    nonisolated static func activeFuseMounts() -> [MountedArchive] {
        var list: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&list, MNT_NOWAIT)
        guard count > 0, let list else { return [] }

        var result: [MountedArchive] = []
        for i in 0..<Int(count) {
            let entry = list[i]
            let fstype = stringFromCTuple(entry.f_fstypename)
            guard fstype.lowercased().contains("fuse") else { continue }
            let mountOn = stringFromCTuple(entry.f_mntonname)
            let mountFrom = stringFromCTuple(entry.f_mntfromname)
            result.append(
                MountedArchive(
                    id: UUID(),
                    archivePath: URL(fileURLWithPath: mountFrom),
                    mountPoint: URL(fileURLWithPath: mountOn)
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
