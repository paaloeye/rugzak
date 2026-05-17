# Zippo

macOS Dock app which bridges [google/fuse-archive](https://github.com/google/fuse-archive) and **macOS**.

## Features

- **version 0.1**
- [x] drop archives (zip, tar.gz, or otherwise) on Dock **icon** and mount them according to _rules_ and _workflows_
- [x] drop archives (zip, tar.gz, or otherwise) on Dock on the **window** and mount them according to _rules_ and _workflows_
- [x] archive drop accept UX animation
- [x] show what mounted and where with metadata
- [x] unmount
- [x] `Process` interface with `fuse-archive` binary
- [x] `Process` interface with `umount` binary
- [x] `Process` interface with `mount` to reconcile current state: `darwin` <-> `UI`
- [x] support unencrypted archives
- [x] open in finder and open in Terminal buttons (Ghostty support if possible)
- [x] confirm alert for unmount
- [x] `DiskArbitration` for event-driven notification on mounted / umounted archives
- bugs:
  - [x] there should be only one window (singleton architecture)
  - [x] _fuse-mounted_ archives outside of Zippo should be enumerated
- **version 0.2**
- [ ] support encrypted archives (full UI)

## Quality of life

- [ ] custom icon

## Prerequisites

```bash
brew install macfuse fuse-archive
```

Mounts appear under `~/Mounts/<archive-name>/`.
