# GOTCHA.md

Common gotchas and pitfalls when working in AI-aided fashion.

This file provides guidance to Claude when it keeps making the same mistakes.

> [!WARNING]
> Read this before making any changes to the project.

## Xcode File Synchronisation

The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+). New `.swift` files dropped into
`Rugzak/` are picked up **automatically** — no need to add them to `project.pbxproj` manually.

## fuse-archive Binary

`fuse-archive` is built from source and bundled inside the app (`Contents/MacOS/fuse-archive`).
`FuseProcess.binaryPath()` checks `Bundle.main` first, then falls back to
`/opt/homebrew/bin`, `/usr/local/bin`, and `$PATH` in that order.

Sources are vendored in `vendor/` (gitignored). Run `scripts/vendor_init.sh` to clone them at the
pinned commits, then `scripts/vendor_build.sh` to compile. Both are called automatically by the
Xcode "Build fuse-archive" run-script phase.

## Debugging Preview Runtime Crashes

Xcode's preview canvas shows a generic "may have crashed" error with no stack trace. To find the
real crash site:

1. **Log stream** — run in a terminal _while_ triggering the preview:
   ```
   log stream --predicate 'process == "Rugzak"' --debug --info --style compact
   ```
   Swift fatal errors print to `os_log` before the trap, so the exact file/line appears here
   (e.g. `SwiftUI/TableViewListCore_Mac2.swift:<LINE_NUMBER>: Fatal error`).

## Toolbar Background Not Visible in SwiftUI Previews

`.toolbarBackground(_:for:)` and `.toolbarBackground(.visible, for:)` do not render in Xcode SwiftUI
previews on macOS — the toolbar chrome remains the default system colour regardless of what colour
is set. The modifier works correctly at runtime in the actual app. Do **not** treat a missing toolbar
colour in a preview as a bug or attempt to work around it with AppKit hacks.

## `generate_build_info.sh` Picks Up Wrong Git Repository in a Monorepo

Set `ENABLE_USER_SCRIPT_SANDBOXING = NO` in the Xcode build settings. When sandboxing is enabled,
the run-script phase that executes `generate_build_info.sh` runs in a restricted environment that
cannot traverse up to the correct `.git` directory — it will either fail silently or resolve the
wrong repository root, producing stale or incorrect build-info values.

This is especially likely when the project lives inside a monorepo (e.g. `workspace/.../rugzak/`)
because the nearest `.git` may be several levels above the `.xcodeproj`.

**Fix:** In `project.pbxproj` (or via Xcode's Build Settings UI), ensure:

```
ENABLE_USER_SCRIPT_SANDBOXING = NO;
```

## List crashes in SwiftUI Previews

`List` on macOS is backed by `NSTableView` (`TableViewListCore_Mac2`). This crashes in the Xcode
preview sandbox with a fatal error at a fixed line — the preview host process lacks the full
`NSApplication` lifecycle the NSTableView bridge expects.

**Fix:** use `ScrollView + LazyVStack + ForEach` instead of `List` in any view that will be
previewed. The real app is unaffected; only the preview sandbox hits this.

> [!CAUTION]
> This file was generated with AI assistance.
