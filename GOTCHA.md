# GOTCHA.md

> [!WARNING]
> Read this before making any changes to the project.

## App Sandbox

App Sandbox is **disabled** (`ENABLE_APP_SANDBOX = NO`) for v0.1. This is intentional — `fuse-archive`
and `umount` are spawned via `Process`, which requires unsandboxed access. Do not re-enable without
also implementing a privileged XPC helper.

## macOS Deployment Target

This project targets **macOS 26** (Tahoe). APIs introduced in macOS 26 are fair game. Do not
add `@available` guards for anything in macOS 26 or earlier.

## Xcode File Synchronisation

The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+). New `.swift` files dropped into
`Zippo/` are picked up **automatically** — no need to add them to `project.pbxproj` manually.
Use `XcodeWrite` (MCP) when creating new files so they are tracked on the Xcode side, but native
filesystem writes (`Write` tool) are preferred for edits because they produce visible diffs.

## fuse-archive Binary

For v0.1, `fuse-archive` is expected on PATH (Homebrew install). `FuseProcess` checks
`/opt/homebrew/bin`, `/usr/local/bin`, and `$PATH` in that order. If none found, it throws a
descriptive error surfaced in the UI. Bundled binary support is planned for v0.2.

## Mount Reconciliation

State reconciliation on launch uses `getmntinfo()`/`statfs` (Darwin syscall) — **not** `mount`
shell output. This reads the kernel mount table directly. The filesystem type for macFUSE mounts
is `macfuse` on macOS 26.

## ~/Mounts Directory

`ArchiveManager` creates `~/Mounts/<archive-name>/` before calling `fuse-archive`. If the directory
already exists (e.g. from a previous run), it is reused. It is **not** deleted on unmount — only
the FUSE mount is removed. The directory is left as a breadcrumb so the user can see what was there.

> [!CAUTION]
> This file was generated with AI assistance.
