//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  AboutView.swift
//  Rugzak
//
//  About window showing app version, build number, and current git commit.
//

import SwiftUI

struct AboutView: View {
    private let version: String
    private let build: String
    private let commit_hash: String
    private let commit_hash_long: String
    private let build_status: String

    init() {
        guard !Debug.isPreview else {
            version = "—"
            build = "—"
            commit_hash = "—"
            commit_hash_long = "—"
            build_status = "dirty"
            return
        }

        version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"

        commit_hash = Bundle.main.object(forInfoDictionaryKey: "GitCommitHash") as? String ?? "—"
        commit_hash_long = Bundle.main.object(forInfoDictionaryKey: "GitCommitHashLong") as? String ?? "—"

        build_status = Bundle.main.object(forInfoDictionaryKey: "GitBuildStatus") as? String ?? "dirty"
    }

    fileprivate init(version: String, build: String, commit_hash: String, commit_hash_long: String, build_status: String) {
        self.version = version
        self.build = build
        self.commit_hash = commit_hash
        self.commit_hash_long = commit_hash_long
        self.build_status = build_status
    }

    private static let repoURL = URL(string: "https://github.com/paaloeye/rugzak")!
    private static let commitBase = "https://github.com/paaloeye/rugzak/commit/"

    private var appIcon: NSImage {
        NSApp?.applicationIconImage ?? NSImage(named: "AppIcon") ?? NSImage()
    }

    var body: some View {
        ZStack {
            TranslucentBackgroundEffect(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 128, height: 128)

                VStack(spacing: 6) {
                    Text("Rugzak")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.brandText)
                    Text("Mount archives as virtual disks via FUSE")
                        .font(.subheadline)
                        .foregroundStyle(Color.brandText.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text("Version")
                            .gridColumnAlignment(.trailing)
                            .foregroundStyle(Color.brandText.opacity(0.6))
                        Text(version)
                            .fontDesign(.monospaced)
                            .foregroundStyle(Color.brandText)
                    }
                    GridRow {
                        Text("Build")
                            .foregroundStyle(Color.brandText.opacity(0.6))
                        Text(build)
                            .fontDesign(.monospaced)
                            .foregroundStyle(Color.brandText)
                    }
                    GridRow {
                        Text("Commit")
                            .foregroundStyle(Color.brandText.opacity(0.6))
                        Link(
                            build_status == "clean" ? commit_hash : commit_hash + "-" + build_status,
                            destination: URL(string: Self.commitBase + commit_hash_long) ?? Self.repoURL
                        )
                        .fontDesign(.monospaced)
                    }
                }

                Button("GitHub") {
                    NSWorkspace.shared.open(Self.repoURL)
                }
                .controlSize(.large)
            }
            .padding(32)
        }
        .frame(width: 300)
    }
}

#Preview("Light") {
    AboutView(version: "0.1", build: "1", commit_hash: "cd10282", commit_hash_long: "cd102820552420b6f6c4950d30b0a2072b9d38fc", build_status: "clean")
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    AboutView(version: "0.1", build: "1", commit_hash: "cd10282", commit_hash_long: "cd102820552420b6f6c4950d30b0a2072b9d38fc", build_status: "clean")
        .preferredColorScheme(.dark)
}

#Preview("Dark - dirty") {
    AboutView(version: "0.1", build: "1", commit_hash: "cd10282", commit_hash_long: "cd102820552420b6f6c4950d30b0a2072b9d38fc", build_status: "dirty")
        .preferredColorScheme(.dark)
}
