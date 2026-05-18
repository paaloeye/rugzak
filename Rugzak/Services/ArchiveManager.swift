//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  ArchiveManager.swift
//  Rugzak
//
//  Observable service that owns the mount list and drives mount/unmount operations.
//

import AppKit
import Combine
import DiskArbitration
import Foundation
import os.log

@MainActor
final class ArchiveManager: ObservableObject {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ArchiveManager.self)
    )

    static let shared: ArchiveManager = {
        #if DEBUG
            if Debug.isPreview {
                return ArchiveManager(preview: ())
            }
        #endif
        return ArchiveManager()
    }()

    @Published private(set) var mounts: [MountedArchive] = []
    @Published var errorMessage: String?

    let mountsDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Mounts", isDirectory: true)
    }()

    static let supportedExtensions: Set<String> = [
        // archive containers
        "7z", "7zip", "a", "ar", "cab", "cpio", "deb", "iso", "iso9660",
        "jar", "lha", "lzh", "mtree", "rar", "rpm", "tar", "war", "warc", "xar",
        "zip", "zipx",
        // zip-based formats
        "aab", "apk", "cbz", "crx", "docx", "epub", "ipa", "odf", "odg",
        "odp", "ods", "odt", "ppsx", "pptx", "whl", "xlsx", "xpi",
        // rar-based
        "cbr",
        // compressed tars
        "tb2", "tbr", "tbz", "tbz2", "tz2", "tgz", "tlz", "tlz4", "tlzip",
        "tlzma", "tlrz", "tlzo", "tlzop", "txz", "tz", "taz", "tzs", "tzst", "tzstd",
        // compression filters (bare compressed files)
        "br", "brotli", "bz", "bz2", "bzip2", "grz", "grzip", "gz", "gzip",
        "lrz", "lrzip", "lz", "lz4", "lzip", "lzma", "lzo", "lzop", "xz",
        "z", "zst", "zstd",
        // ascii encoding filters
        "b64", "base64", "uu",
        // encryption filters (gpg-wrapped archives)
        "asc", "gpg", "pgp",
    ]

    private var daSession: DASession?

    private init() {
        createMountsDirectoryIfNeeded()
        reconcile()
        setupDiskArbitration()
    }

    func mount(_ archiveURL: URL) {
        guard !mounts.contains(where: { $0.archivePath == archiveURL }) else { return }
        let name = archiveURL.deletingPathExtension().lastPathComponent
        let mountPoint = uniqueMountPoint(for: name)
        Task {
            do {
                try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
                try await FuseProcess.mount(archive: archiveURL, mountPoint: mountPoint)
                let archive = MountedArchive(id: UUID(), archivePath: archiveURL, mountPoint: mountPoint)
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

    func openInFinder(_ archive: MountedArchive) {
        NSWorkspace.shared.open(archive.mountPoint)
    }

    func openInTerminal(_ archive: MountedArchive) {
        let pb = NSPasteboard(name: NSPasteboard.Name(Bundle.main.bundleIdentifier!))
        pb.clearContents()
        pb.writeObjects([archive.mountPoint as NSURL])

        logger.debug("Opening \(archive.mountPoint.path) in Ghostty")
        if NSPerformService("New Ghostty Tab Here", pb) { return }

        // Terminal fallback
        let path = archive.mountPoint.path.replacingOccurrences(of: "'", with: "\\'")
        let src = "tell application \"Terminal\" to activate\ntell application \"Terminal\" to do script \"cd '\(path)'\""

        logger.debug("Opening \(archive.mountPoint.path) in Terminal")
        NSAppleScript(source: src)?.executeAndReturnError(nil)
    }

    func reconcile() {
        let found = MountReconciler.activeFuseMounts()
        let foundPaths = Set(found.map { $0.mountPoint.standardized })
        mounts.removeAll { !foundPaths.contains($0.mountPoint.standardized) }
        let knownPaths = Set(mounts.map { $0.mountPoint.standardized })
        for mount in found where !knownPaths.contains(mount.mountPoint.standardized) {
            mounts.append(mount)
        }
    }

    private func setupDiskArbitration() {
        guard let session = DASessionCreate(kCFAllocatorDefault) else { return }
        daSession = session
        DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let ctx = Unmanaged.passUnretained(self).toOpaque()

        DARegisterDiskAppearedCallback(
            session, nil,
            { _, context in
                guard let ctx = context else { return }
                let mgr = Unmanaged<ArchiveManager>.fromOpaque(ctx).takeUnretainedValue()
                Task { @MainActor in mgr.reconcile() }
            }, ctx)

        DARegisterDiskDisappearedCallback(
            session, nil,
            { _, context in
                guard let ctx = context else { return }
                let mgr = Unmanaged<ArchiveManager>.fromOpaque(ctx).takeUnretainedValue()
                Task { @MainActor in mgr.reconcile() }
            }, ctx)
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

    // MARK: - Preview
    // only needed for preview in Xcode
    #if DEBUG
        private init(preview _: ()) {}

        static func preview(mounts: [MountedArchive] = [], error: String? = nil) -> ArchiveManager {
            let m = ArchiveManager(preview: ())
            m.mounts = mounts
            m.errorMessage = error
            return m
        }

        static func previewWithMounts() -> ArchiveManager {
            preview(mounts: [
                MountedArchive(
                    id: UUID(),
                    archivePath: URL(fileURLWithPath: "/Downloads/homebrew-core-20260518.tar.gz"),
                    mountPoint: URL(fileURLWithPath: "/Mounts/homebrew-core-20260518")
                ),
                MountedArchive(
                    id: UUID(),
                    archivePath: URL(fileURLWithPath: "/Archives/swift-6.1-RELEASE.tar.gz"),
                    mountPoint: URL(fileURLWithPath: "/Mounts/swift-6.1-RELEASE")
                ),
                MountedArchive(
                    id: UUID(),
                    archivePath: URL(fileURLWithPath: "/Downloads/Xcode_16.3.xip"),
                    mountPoint: URL(fileURLWithPath: "/Mounts/Xcode_16.3")
                ),
                MountedArchive(
                    id: UUID(),
                    archivePath: URL(fileURLWithPath: "/Downloads/linux-6.9.tar.xz"),
                    mountPoint: URL(fileURLWithPath: "/Mounts/linux-6.9")
                ),
                MountedArchive(
                    id: UUID(),
                    archivePath: URL(fileURLWithPath: "/tmp/macOS-Sequoia-15.5.ipsw"),
                    mountPoint: URL(fileURLWithPath: "/Mounts/macOS-Sequoia-15.5")
                ),
                MountedArchive(
                    id: UUID(),
                    archivePath: URL(fileURLWithPath: "/Downloads/helix-25.01-x86_64-macos.tar.xz"),
                    mountPoint: URL(fileURLWithPath: "/Mounts/helix-25.01-x86_64-macos")
                ),
                MountedArchive(
                    id: UUID(),
                    archivePath: URL(fileURLWithPath: "/Downloads/dotfiles-backup-2026.tar.bz2"),
                    mountPoint: URL(fileURLWithPath: "/Mounts/dotfiles-backup-2026")
                ),
            ])
        }
    #endif
}
