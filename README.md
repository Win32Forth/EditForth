# EditForth

**Public domain.**

**EditForth** is a greenfield macOS Forth editor + Forth runtime workspace. It is a **separate project** from [64Forth](https://github.com/Win32Forth/64Forth) and [64Edit](https://github.com/Win32Forth/64Edit), so those apps can keep evolving on their own (including 64Forth remaining a console-first Forth).

**Version:** **2.0.0** (build **1**) for both `EditForth.app` and companion `64Forth.app`. First public release: DMG at `Releases/EditForth-2.0.0-macOS.dmg` and GitHub tag **v2.0.0**.

Product umbrella: **EditForth**. Internal source trees keep **64Edit** / **64Forth** filenames and symbols so changes can be backported with fewer rename conflicts.

## Not eForth

**EditForth is not a derivative of eForth.** The names are only a little alike. If it *were* a derivative of eForth, it would probably be a pretty nice Forth.

## Layout

One Xcode project, two targets, two source folders:

| Folder | Target / product | Role |
|--------|------------------|------|
| `Editor/` | **EditForth** → `EditForth.app` | Editor (from 64Edit; sources still SixtyFourEdit*) |
| `Forth/` | **64Forth** → `64Forth.app` | Forth runtime (from 64Forth; same bundle id and App Support paths) |

```text
EditForth/
  EditForth.xcodeproj   # schemes: EditForth, 64Forth
  Editor/
  Forth/                # App, Host, Kernel, Resources, …
  Releases/             # EditForth-*-macOS.dmg + install aids
  README.md
  DESIGN.md
```

Two **separate processes**; one project window in Xcode.

## Direction

- Editor workspace with a status strip and **Start Forth**.
- The Forth REPL lives **inside** the editor when docked (embedded console).
- **64Forth** runs as a headless **companion** (`--companion`): kernel + `edit.sock`, no console window of its own.
- **Undock** moves the REPL to a floating window; the red close button **hides** it (**Unhide Forth** brings it back); **Dock** embeds it under the strip again.
- 64Forth and 64Edit remain the shipped companion pair; EditForth is the place to try the combined direction without interfering with them.

## Status

Both targets build. **Start Forth** launches this project’s **64Forth** as a companion (sibling Products / `EditForth-*` DerivedData in Debug; Release uses sibling or `/Applications`). Connection is still `~/Library/Application Support/64Forth/edit.sock`. User files and the default Forth working directory are **`~/Documents/EditForth`** (Library / AutoLoad / Docs / Config under that tree). FLOAD/CHDIR start there; dig into subfolders as needed (no FROMLIB for normal loads).

### Embedded companion console

**Start Forth** runs `64Forth --companion` (accessory activation, no Forth app window). While connected, Start Forth is hidden. The editor hosts `DockedConsoleView` when docked; typing and output go over `edit.sock`. **Undock** opens a floating titled window; closing that window with the red traffic light hides the console (companion keeps running) and the strip shows **Unhide Forth**. **Dock** returns the console under the strip. Quit EditForth terminates the launched companion.

## Build

In Xcode, the scheme menu (next to the Run button) lists **EditForth** and **64Forth**.  
Choose **EditForth** and Build/Run — that also builds the **64Forth** target into the same Products folder (so Ping can launch the sibling app).  
Choose **64Forth** only when you want to run the Forth app alone.

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer

# Builds both 64Forth.app and EditForth.app
xcodebuild -project EditForth.xcodeproj -scheme EditForth \
  -configuration Debug -derivedDataPath DerivedData/EditForth-debug build
```

## Install (DMG)

1. Open `Releases/EditForth-2.0.0-macOS.dmg` (or the matching GitHub release asset).
2. Drag **EditForth.app** and **64Forth.app** into Applications (or keep them side by side in the same folder).
3. Approve each app once with Control-click **Open**, then Settings → Privacy & Security → **Open Anyway** (see `Releases/Getting EditForth to run.jpg` and `Releases/README.pdf`). Approving one app does not approve the other.

## License

Public domain. Do what you want.
