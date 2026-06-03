# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

> [!WARNING]
> These rules override default behaviour. Follow them exactly when working with this codebase. Violations may cause
> linter failures or break pre-commit hooks.

- ALWAYS read [GOTCHA.md](./GOTCHA.md) first
- PREFER British English over American English spelling and grammar except in **inline code** sections
- USE Markdown banners ([see below](#a-tour-of-banners))
- Files and Directories MUST NOT have **dashes** in names/paths (use **underscore** instead)
- NEVER use Git LFS
- USE Emoji in [README.md](./README.md) or **docs/\*.md** with care. NOT MUCH.
- ALL development scripts use Nushell (\*.nu) - install nushell for development workflow
- ALWAYS use `[x]` or `[ ]` instead of ✅ / 🔲 / for checkmarks
- NEVER use `[x]` or `[ ]` in Markdown tables; USE ✅ / 🔲 / instead. **Reason**: it's not supported
- PREFER [GitHub Emoji API](https://api.github.com/emojis) over Unicode Emoji
- ALWAYS add footer to new Markdown files with a AI generated content banner (!CAUTION)
- PREFER 120 characters per line
- PREFER native file system update over `XcodeUpdate` MCP tools because:
  - it's easier to see what's changed, MCP tools don't show diffs
  - **auto-accept** doesn't work with MCP tools
- ALWAYS make sure `BuildProject` is _green_ and `XcodeRefreshCodeIssuesInFile` is at least _yellow_ before reporting _ready_
- USE `RenderPreview` to render actual state and test your assumptions when working with UI and UX elements
- `MACOS_DEPLOYMENT_TARGET=14.6`

## A Tour of Banners

> [!NOTE]
> Highlights information that users should take into account, even when skimming.

> [!TIP]
> Optional information to help a user be more successful.

> [!IMPORTANT]
> Crucial information necessary for users to succeed.

> [!WARNING]
> Critical content demanding immediate user attention due to potential risks.

> [!CAUTION]
> Negative potential consequences of an action.

## Conventions

- **We're Dutch honest**
- British English throughout (colour, licence, behaviour, etc.)
- No dashes in file or directory names — use underscores
- Follow conventional commit format (see workspace CLAUDE.md for the full format)

## Xcode MCP Tools

**Rugzak** uses Xcode MCP for project integration. Available tools organised by category:

> [!WARNING]
> Xcode MCP tools cannot directly rename schemes or targets. This requires manual intervention in Xcode.

### Project Navigation

- **XcodeListWindows** - List Xcode windows and workspace information
- **XcodeLS** - List files/directories in project structure (supports recursive listing)
- **XcodeGlob** - Find files matching wildcard patterns (`*.swift`, `**/*.json`)
- **XcodeGrep** - Search for text patterns with regex support and context lines

### File Operations

- **XcodeRead** - Read file contents (supports line offset/limit for large files)
- **XcodeWrite** - Create new files
- **XcodeRM** - Remove files and directories (optionally delete from filesystem)
- **XcodeMV** - Move or rename files and directories
- **XcodeMakeDir** - Create directories and groups

### Build & Compilation

- **BuildProject** - Build project and wait for completion
- **GetBuildLog** - Retrieve build logs filtered by severity (error, warning, remark)
- **XcodeListNavigatorIssues** - List current issues from Issue Navigator UI
- **XcodeRefreshCodeIssuesInFile** - Get compiler diagnostics for specific files

### Testing

- **GetTestList** - Get all available tests from active scheme
- **RunAllTests** - Execute all tests in active test plan
- **RunSomeTests** - Run specific tests by target name and identifier

### Debugging & Development

- **ExecuteSnippet** - Run Swift code snippets in file context (access to `fileprivate` declarations)
- **RenderPreview** - Build and render SwiftUI previews, return UI snapshot

### Documentation

- **DocumentationSearch** - Search Apple Developer Documentation with semantic matching

> [!NOTE]
> All Xcode MCP operations work on the **project structure** (as seen in Xcode Navigator), not the filesystem directly.
> Use `tabIdentifier` from `XcodeListWindows` to target specific workspace tabs.

### Quick Reference

```swift
// Get workspace identifier
XcodeListWindows() // Returns: tabIdentifier: windowtab1

// Build and check issues
BuildProject(tabIdentifier: "windowtab1")
XcodeListNavigatorIssues(tabIdentifier: "windowtab1", severity: "error")

// File operations
XcodeRead(tabIdentifier: "windowtab1", filePath: "Views/ContentView.swift")

// Testing
GetTestList(tabIdentifier: "windowtab1")
RunAllTests(tabIdentifier: "windowtab1")
```
