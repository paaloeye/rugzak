# AppleScript API — Terminal.app

Reference for Terminal.app's AppleScript dictionary (`terminal.sdef`), covering both the Standard Suite
and the Terminal-specific suite.

## Terminal Suite

### Commands

#### `do script`

Run a UNIX shell script or command in a tab.

```applescript
do script "command" [in tab|window]
-- returns tab
```

| Parameter | Type             | Required | Description                                         |
| --------- | ---------------- | -------- | --------------------------------------------------- |
| direct    | `text`           | 🔲       | Command to execute                                  |
| `in`      | `tab` / `window` | 🔲       | Target tab or window; opens a new window if omitted |

**Examples:**

```applescript
-- Run in a new window
do script "echo hello"

-- Run in an existing tab
tell application "Terminal"
    do script "ls -la" in tab 1 of window 1
end tell

-- Capture the resulting tab
set t to do script "top"
```

> [!NOTE]
> When `in` is omitted Terminal opens a new window. Passing an existing `tab` sends the command to
> that tab. Passing a `window` sends it to the window's selected tab.

---

### `application` Extensions

The Terminal suite extends `application` with:

| Property           | Type           | Access | Description                         |
| ------------------ | -------------- | ------ | ----------------------------------- |
| `default settings` | `settings set` | r/w    | Profile used for new windows        |
| `startup settings` | `settings set` | r/w    | Profile used for the startup window |

**Elements:** `settings set` (read-only)

---

### Classes

#### `settings set`

A named profile controlling a tab's appearance and behaviour.

| Property                       | Type          | Access | Description                               |
| ------------------------------ | ------------- | ------ | ----------------------------------------- |
| `id`                           | `integer`     | r      | Unique identifier                         |
| `name`                         | `text`        | r/w    | Profile name                              |
| `number of rows`               | `integer`     | r/w    | Row count                                 |
| `number of columns`            | `integer`     | r/w    | Column count                              |
| `cursor color`                 | `color`       | r/w    | Cursor colour                             |
| `background color`             | `color`       | r/w    | Background colour                         |
| `normal text color`            | `color`       | r/w    | Normal text colour                        |
| `bold text color`              | `color`       | r/w    | Bold text colour                          |
| `font name`                    | `text`        | r/w    | Font name                                 |
| `font size`                    | `integer`     | r/w    | Font size (pt)                            |
| `font antialiasing`            | `boolean`     | r/w    | Antialiasing enabled                      |
| `clean commands`               | `text` (list) | r/w    | Processes ignored when prompting to close |
| `title displays device name`   | `boolean`     | r/w    | Show device name in title                 |
| `title displays shell path`    | `boolean`     | r/w    | Show shell path in title                  |
| `title displays window size`   | `boolean`     | r/w    | Show rows × columns in title              |
| `title displays settings name` | `boolean`     | r/w    | Show profile name in title                |
| `title displays custom title`  | `boolean`     | r/w    | Show custom title                         |
| `custom title`                 | `text`        | r/w    | Custom title string                       |

---

#### `tab`

A single terminal session tab.

| Property                      | Type           | Access | Description                           |
| ----------------------------- | -------------- | ------ | ------------------------------------- |
| `number of rows`              | `integer`      | r/w    | Row count                             |
| `number of columns`           | `integer`      | r/w    | Column count                          |
| `contents`                    | `text`         | r      | Currently visible buffer text         |
| `history`                     | `text`         | r      | Full scrollback buffer text           |
| `busy`                        | `boolean`      | r      | Whether a process is running          |
| `processes`                   | `text` (list)  | r      | Currently running processes           |
| `selected`                    | `boolean`      | r/w    | Whether this tab is selected          |
| `title displays custom title` | `boolean`      | r/w    | Show custom title                     |
| `custom title`                | `text`         | r/w    | Custom title string                   |
| `tty`                         | `text`         | r      | TTY device path (e.g. `/dev/ttys003`) |
| `current settings`            | `settings set` | r/w    | Active profile for this tab           |

**Deprecated tab properties** (use `current settings` instead):

| Property                     | Type          | Description                |
| ---------------------------- | ------------- | -------------------------- |
| `cursor color`               | `color`       | Cursor colour              |
| `background color`           | `color`       | Background colour          |
| `normal text color`          | `color`       | Normal text colour         |
| `bold text color`            | `color`       | Bold text colour           |
| `clean commands`             | `text` (list) | Processes ignored on close |
| `title displays device name` | `boolean`     | Device name in title       |
| `title displays shell path`  | `boolean`     | Shell path in title        |
| `title displays window size` | `boolean`     | Size in title              |
| `title displays file name`   | `boolean`     | File name in title         |
| `font name`                  | `text`        | Font name                  |
| `font size`                  | `integer`     | Font size                  |
| `font antialiasing`          | `boolean`     | Antialiasing               |

---

## Practical Examples

```applescript
-- Open a new window and run a command
tell application "Terminal"
    do script "ssh user@host"
end tell

-- Read the current tab's scrollback buffer
tell application "Terminal"
    set buf to history of selected tab of front window
end tell

-- Check whether the front tab is still busy
tell application "Terminal"
    set running to busy of selected tab of front window
end tell

-- Change the profile of the front tab
tell application "Terminal"
    set current settings of selected tab of front window ¬
        to settings set "Homebrew"
end tell

-- Resize the front window
tell application "Terminal"
    set number of rows of selected tab of front window to 50
    set number of columns of selected tab of front window to 220
end tell

-- Send a command to a specific tab without activating Terminal
tell application "Terminal"
    do script "make test" in tab 2 of window 1
end tell
```

---

> [!CAUTION]
> This document was generated with AI assistance on **macOS 26.4.1** (Build 25E253). Verify against
> the live SDEF dictionary at
> `/System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.sdef` for the definitive
> reference, as the API may differ between macOS versions.
