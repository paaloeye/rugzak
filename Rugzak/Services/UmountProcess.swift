//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  UmountProcess.swift
//  Rugzak
//
//  Invokes /sbin/umount to detach a FUSE mount point asynchronously.
//

import Foundation

enum UmountError: LocalizedError {
    case failed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .failed(let code, let output):
            return "umount exited with code \(code): \(output)"
        }
    }
}

struct UmountProcess {
    nonisolated static func unmount(mountPoint: URL, force: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/sbin/umount")
                    process.arguments = []

                    if force {
                        process.arguments!.append("-f")
                    }

                    process.arguments!.append(mountPoint.path)

                    let errorPipe = Pipe()
                    process.standardError = errorPipe
                    process.standardOutput = Pipe()

                    try process.run()
                    process.waitUntilExit()

                    guard process.terminationStatus == 0 else {
                        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8) ?? ""
                        continuation.resume(throwing: UmountError.failed(process.terminationStatus, errMsg))
                        return
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
