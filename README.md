# :school_satchel: Rugzak

> A minimal macOS app that mounts archives as read-only virtual disks via
> [fuse-archive](https://github.com/google/fuse-archive) and [macFUSE](https://github.com/macfuse/macfuse).

Drop a zip, tar, or any supported archive onto the Dock icon or the window — **Rugzak** mounts it
instantly under `~/Mounts/<name>/` and keeps a live list of what is mounted and where.
Unmounting is one click away.

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/screenshot_dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/screenshots/screenshot_light.png">
    <img alt="Rugzak main window" src="docs/screenshots/screenshot_light.png" width="600">
  </picture>
</div>

---

## Requirements

| Dependency                                             | Install                       |
| ------------------------------------------------------ | ----------------------------- |
| [macFUSE](https://osxfuse.github.io)                   | `brew install --cask macfuse` |
| [fuse-archive](https://github.com/google/fuse-archive) | `brew install fuse-archive`   |

> [!IMPORTANT]
> macFUSE requires a kernel extension. After installing, go to **System Settings → Privacy &
> Security** and allow the macFUSE system extension, then reboot.

---

## Getting started

```bash
# 1. Clone
git clone https://github.com/paaloeye/rugzak.git
cd rugzak

# 2. Generate build metadata (required before the first Xcode build)
bash scripts/generate_build_info.sh

# 3. Open in Xcode and run, or build from the command line
bash scripts/build.sh
```

`generate_build_info.sh` writes `Config/GeneratedBuildInfo.xcconfig` with the current Git commit
hash. Subsequent builds run the script automatically via an Xcode build phase.

---

## Usage

| Action                | How                                                                        |
| --------------------- | -------------------------------------------------------------------------- |
| Mount an archive      | Drop it onto the Dock icon or the app window                               |
| Browse contents       | Click **Open in Finder** next to the mount                                 |
| Open a terminal there | Click **Open in Terminal** (Ghostty preferred, falls back to Terminal.app) |
| Unmount               | Click **Unmount** and confirm                                              |

Mounts are placed under `~/Mounts/<archive-name>/`. If a name is already taken a numeric suffix is
appended (`project_1`, `project_2`, …).

Archives mounted outside of Rugzak (e.g. via the command line) are automatically reconciled into
the list on launch and whenever macOS reports a disk event.

---

## Supported formats

Rugzak passes the archive directly to `fuse-archive`, which supports:

**Containers** — `zip`, `zipx`, `tar`, `tar.gz`, `tar.bz2`, `tar.xz`, `tar.zst`, `7z`, `rar`,
`cab`, `iso`, `deb`, `rpm`, `jar`, `war`, `xar`, `cpio`, `lha`, `lzh`, `ar`, `a`, `warc`,
`mtree`

**ZIP-based** — `docx`, `xlsx`, `pptx`, `odt`, `ods`, `odp`, `odg`, `odf`, `epub`, `apk`, `ipa`,
`aab`, `whl`, `xpi`, `crx`, `cbz`

**RAR-based** — `cbr`

**Compression filters** — `gz`, `bz2`, `xz`, `zst`, `lz4`, `lzma`, `lzo`, `br`, `lrz`, `grz`,
`z`

**ASCII / encryption filters** — `base64`, `b64`, `uu`, `gpg`, `pgp`, `asc`

> [!NOTE]
> Encrypted archives (password-protected zip, gpg, …) are not supported in v0.1. Full UI for
> encrypted archives is planned for v0.2.

---

## Building a distributable DMG

```bash
bash scripts/create_dmg.sh
```

The script builds in Release configuration, creates a drag-to-install DMG with the app and an
Applications folder alias, and optionally code-signs and notarises if credentials are present.

---

## Project structure

```
Rugzak/
├── Models/
│   └── MountedArchive.swift     — value type for a single mounted archive
├── Services/
│   ├── ArchiveManager.swift     — observable owner of the mount list
│   ├── FuseProcess.swift        — fuse-archive process wrapper
│   ├── MountReconciler.swift    — reads kernel mount table on startup
│   └── UmountProcess.swift      — /sbin/umount wrapper
└── Views/
    ├── ContentView.swift         — main window
    ├── DropTargetView.swift      — drag-and-drop NSView bridge
    └── AboutView.swift           — version / build / commit panel
```

---

## Known limitations

- macFUSE mounts are **read-only**; you cannot write back into the archive.
- Encrypted archives are **not yet supported** (v0.2 planned).
- `fuse-archive` must be on PATH or in `/opt/homebrew/bin` / `/usr/local/bin`; bundled binary
  support is planned for v0.2.

---

## Licence

MIT — see [LICENCE](./LICENCE).

