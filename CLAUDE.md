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
  - `XcodeWrite` can be used for creating new files only, so they are tracked by Xcode
- ALWAYS make sure `BuildProject` is _green_ and `XcodeRefreshCodeIssuesInFile` is at least _yellow_ before reporting _ready_
- USE `RenderPreview` to render actual state and test your assumptions when working with UI and UX elements

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

## What This Repository Is

This is the founding repository for:

- **Waal Industries**
- **Betty** — a native macOS AI client with cost, carbon, and time visibility.

See `IDEA.md` for the full product vision and `NAME.md` for the domain strategy.

There is no code yet. This repository is currently a product and strategy document, not a software project.

## Conventions

- **We're Dutch honest**
- British English throughout (colour, licence, behaviour, etc.)
- No dashes in file or directory names — use underscores
- Follow conventional commit format (see workspace CLAUDE.md for the full format)

## Product Decisions That Are Settled

- **No OpenAI** — explicitly excluded. Supported providers: Anthropic direct, AWS Bedrock, Google Vertex, Gemini
- **No subscription model** — Free, one-time purchase, or enterprise licence when the time comes
- **Open source** — likely, but not decided yet. No commitment until Phase 1 or 2. Cards kept close.
- **Native only** — SwiftUI on macOS, WinUI3 on Windows. Not Electron, not a wrapper
- **No telemetry** — the XPC sidecar handles all provider calls; nothing leaves the user's machine without explicit consent
- **Phase 0** is TestFlight-only, closed source, invite-only before the open source transition at Phase 1

## App Store + XPC Sidecar Architecture

The sandboxed App Store build and the XPC sidecar are architecturally separate:

- **Without sidecar**: Betty uses `URLSession` in the sandbox to reach Anthropic direct. This must be a meaningful, functional experience — not a stub. Apple will reject an app that requires a post-install step to do anything useful.
- **With sidecar**: unlocks Ollama (local models) and installs the `betty` CLI. Users install it via a one-button onboarding flow (Touch ID prompt, no terminal needed). Betty never downloads or executes the sidecar automatically — that distinction is what keeps it inside App Review Guidelines 2.5.2.

**Do not design a flow where Betty downloads and executes the sidecar automatically.** That will be rejected regardless of signing. The terminal-copy pattern is intentional.

The sidecar must be bundled in the app for any future direct (non-App-Store) distribution. For the App Store build, it ships as an optional user-installed Login Item via `SMAppService`.

Precedents for the copy/paste terminal install pattern: Homebrew, Docker Desktop CLI, most serious developer tools that need system access.

## Directory Structure

The top-level directories mirror the domain portfolio:

```
ai/avond/          ← avond.ai — future platform (hold)
industries/        ← waal.industries — legal entity
xyz/askbetty/      ← askbetty.xyz — product domain
```

## Key Documents

- `IDEA.md` — north star document. When a decision is hard, come back here
- `NAME.md` — domain and naming strategy

## Xcode MCP Tools

Flight Engineer uses Xcode MCP for project integration. Available tools organised by category:

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
