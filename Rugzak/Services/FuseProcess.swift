//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  FuseProcess.swift
//  Rugzak
//
//  Locates and invokes the fuse-archive binary to mount an archive at a given path.
//

import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FuseProcess")

enum FuseError: LocalizedError {
    case binaryNotFound
    case mountFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "fuse-archive not found. Install it with: brew install fuse-archive"
        case .mountFailed(let code, let output):
            return "fuse-archive exited with code \(code): \(output)"
        }
    }
}

struct FuseProcess {
    private static let fallbackPaths = [
        "/opt/homebrew/bin/fuse-archive",
        "/usr/local/bin/fuse-archive",
    ]

    nonisolated static func binaryPath() throws -> String {
        // bundled fuse-archive
        if let execDir = Bundle.main.executableURL?.deletingLastPathComponent() {
            let bundled = execDir.appendingPathComponent("fuse-archive")
            if FileManager.default.isExecutableFile(atPath: bundled.path) {
                logger.debug("fuse-archive resolved: bundled at \(bundled.path, privacy: .public)")
                return bundled.path
            }
        }

        for path in fallbackPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                logger.debug("fuse-archive resolved: fallback at \(path, privacy: .public)")
                return path
            }
        }

        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["fuse-archive"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = Pipe()
        try which.run()
        which.waitUntilExit()
        if which.terminationStatus == 0,
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        {
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty {
                logger.debug("fuse-archive resolved: PATH at \(path, privacy: .public)")
                return path
            }
        }

        logger.error("fuse-archive binary not found")
        throw FuseError.binaryNotFound
    }

    /// Extensions whose CPIO payloads lack AppleDouble files, causing fuse-archive's
    /// trim to collapse the top-level app bundle directory. Pass -o notrim for these.
    private static let notrimExtensions: Set<String> = ["xip"]

    nonisolated static func mount(archive: URL, mountPoint: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let binary = try Self.binaryPath()
                    logger.info(
                        "spawning: \(binary, privacy: .public) \(archive.path, privacy: .public) \(mountPoint.path, privacy: .public)"
                    )
                    let ext = archive.pathExtension.lowercased()
                    var args: [String] = []
                    if notrimExtensions.contains(ext) {
                        args += ["-o", "notrim"]
                    }
                    args += [archive.path, mountPoint.path]
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: binary)
                    process.arguments = args
                    let errorPipe = Pipe()
                    process.standardError = errorPipe
                    process.standardOutput = Pipe()
                    try process.run()
                    process.waitUntilExit()
                    let exitCode = process.terminationStatus
                    guard exitCode == 0 else {
                        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8) ?? ""
                        logger.error(
                            "fuse-archive exited \(exitCode): \(errMsg, privacy: .public)"
                        )
                        continuation.resume(throwing: FuseError.mountFailed(exitCode, errMsg))
                        return
                    }
                    logger.info("fuse-archive mounted successfully at \(mountPoint.path, privacy: .public)")
                    continuation.resume()
                } catch {
                    logger.error("fuse-archive mount error: \(error, privacy: .public)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
