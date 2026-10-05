# EditForth

**Public domain.**

**EditForth** is a greenfield macOS Forth editor + Forth runtime workspace. It is a **separate project** from [64Forth](https://github.com/Win32Forth/64Forth) and [64Edit](https://github.com/Win32Forth/64Edit), so those apps can keep evolving on their own (including 64Forth remaining a console-first Forth).

Product umbrella: **EditForth**. Internal source trees keep **64Edit** / **64Forth** filenames and symbols so changes can be backported with fewer rename conflicts.

## Not eForth

**EditForth is not a derivative of eForth.** The names are only a little alike. If it *were* a derivative of eForth, it would probably be a pretty nice Forth.

## Layout

Sibling app folders in one repo:

| Folder / project | Role |
|------------------|------|
| `Editor/` + `EditForth.xcodeproj` | Editor app (from 64Edit). Product display name **EditForth**; sources still 64Edit / SixtyFourEdit*. |
| `Forth/` + `Forth.xcodeproj` | Forth runtime (from 64Forth). Target / app still **64Forth** (`64Forth.app`, same bundle id and App Support paths). |

```text
EditForth/
  EditForth.xcodeproj   # editor
  Forth.xcodeproj       # Forth runtime (scheme 64Forth)
  Editor/
  Forth/                # App, Host, Kernel, Resources, …
  README.md
  DESIGN.md
```

## Direction

- Editor workspace with a **Ping** panel that stays in the editor.
- A real Forth console/UI can **dock under Ping** and later **detach** as its own window, still lifecycle-tied (quit either side shuts both down).
- Prefer hosting a real Forth UI over cloning a second REPL inside the editor.
- 64Forth and 64Edit remain the shipped companion pair; EditForth is the place to try the combined direction without interfering with them.

## Status

Both trees build. The editor still connects over `~/Library/Application Support/64Forth/edit.sock` to a **64Forth** process (the one from `Forth.xcodeproj` or the standalone 64Forth app — same paths).

## Build

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer

# Editor
xcodebuild -project EditForth.xcodeproj -scheme EditForth \
  -configuration Debug -derivedDataPath DerivedData/EditForth-debug build

# Forth runtime (internal name 64Forth)
xcodebuild -project Forth.xcodeproj -scheme 64Forth \
  -configuration Debug -derivedDataPath DerivedData/Forth-debug build
```

## License

Public domain. Do what you want.
