# GOTCHA.md

Common gotchas and pitfalls when working [Claude Code](https://claude.ai/code) in AI-aided fashion.

This file provides guidance to Claude when it keeps making the same mistakes.

> [!WARNING]
> Read this before making any changes to the project.

## Xcode File Synchronisation

The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+). New `.swift` files dropped into
`Zippo/` are picked up **automatically** — no need to add them to `project.pbxproj` manually.
Use `XcodeWrite` (MCP) when creating new files so they are tracked on the Xcode side, but native
filesystem writes (`Write` tool) are preferred for edits because they produce visible diffs.

## fuse-archive Binary

For v0.1, `fuse-archive` is expected on PATH (Homebrew install). `FuseProcess` checks
`/opt/homebrew/bin`, `/usr/local/bin`, and `$PATH` in that order. If none found, it throws a
descriptive error surfaced in the UI. Bundled binary support is planned for v0.2.

## Debugging Preview Runtime Crashes

Xcode's preview canvas shows a generic "may have crashed" error with no stack trace. To find the
real crash site:

1. **Log stream** — run in a terminal _while_ triggering the preview:
   ```
   log stream --predicate 'process == "Zippo"' --debug --info --style compact
   ```
   Swift fatal errors print to `os_log` before the trap, so the exact file/line appears here
   (e.g. `SwiftUI/TableViewListCore_Mac2.swift:<LINE_NUMBER>: Fatal error`).

## List crashes in SwiftUI Previews

`List` on macOS is backed by `NSTableView` (`TableViewListCore_Mac2`). This crashes in the Xcode
preview sandbox with a fatal error at a fixed line — the preview host process lacks the full
`NSApplication` lifecycle the NSTableView bridge expects.

**Fix:** use `ScrollView + LazyVStack + ForEach` instead of `List` in any view that will be
previewed. The real app is unaffected; only the preview sandbox hits this.

> [!CAUTION]
> This file was generated with AI assistance.
