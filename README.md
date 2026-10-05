# EditForth

**Public domain.**

**EditForth** is a greenfield macOS Forth editor + Forth runtime workspace. It is a **separate project** from [64Forth](https://github.com/Win32Forth/64Forth) and [64Edit](https://github.com/Win32Forth/64Edit), so those apps can keep evolving on their own (including 64Forth remaining a console-first Forth).

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
  README.md
  DESIGN.md
```

Two **separate processes**; one project window in Xcode.

## Direction

- Editor workspace with a **Ping** panel that stays in the editor.
- A real Forth console/UI can **dock under Ping** and later **detach** as its own window, still lifecycle-tied (quit either side shuts both down).
- Prefer hosting a real Forth UI over cloning a second REPL inside the editor.
- 64Forth and 64Edit remain the shipped companion pair; EditForth is the place to try the combined direction without interfering with them.

## Status

Both targets build. Ping launches this project’s **64Forth** scheme app (sibling Products / `EditForth-*` DerivedData in Debug; Release uses sibling or `/Applications`). Connection is still `~/Library/Application Support/64Forth/edit.sock`.

## Build

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer

xcodebuild -project EditForth.xcodeproj -scheme EditForth \
  -configuration Debug -derivedDataPath DerivedData/EditForth-debug build

xcodebuild -project EditForth.xcodeproj -scheme 64Forth \
  -configuration Debug -derivedDataPath DerivedData/EditForth-debug build
```

## License

Public domain. Do what you want.
