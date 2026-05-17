import Foundation

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
    private static let knownPaths = [
        "/opt/homebrew/bin/fuse-archive",
        "/usr/local/bin/fuse-archive",
    ]

    nonisolated static func binaryPath() throws -> String {
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
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
            if !path.isEmpty { return path }
        }
        throw FuseError.binaryNotFound
    }

    nonisolated static func mount(archive: URL, mountPoint: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let binary = try Self.binaryPath()
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: binary)
                    process.arguments = [archive.path, mountPoint.path]
                    let errorPipe = Pipe()
                    process.standardError = errorPipe
                    process.standardOutput = Pipe()
                    try process.run()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else {
                        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8) ?? ""
                        continuation.resume(throwing: FuseError.mountFailed(process.terminationStatus, errMsg))
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
