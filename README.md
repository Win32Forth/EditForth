# EditForth

**Public domain.**

**EditForth** is a greenfield macOS Forth editor + Forth runtime workspace. It is a **separate project** from [64Forth](https://github.com/Win32Forth/64Forth) and [64Edit](https://github.com/Win32Forth/64Edit), so those apps can keep evolving on their own (including 64Forth remaining a console-first Forth).

Current marketing version: **0.1.0** / build **1**.

## Not eForth

**EditForth is not a derivative of eForth.** The names are only a little alike. If it *were* a derivative of eForth, it would probably be a pretty nice Forth.

## Layout

Two sibling app folders in one repo (same idea as separate 64Edit / 64Forth trees, but colocated here):

| Folder | Role |
|--------|------|
| `Editor/` | Editor app sources (copied from 64Edit **1.5.4**; symbols still say 64Edit until renamed) |
| `Forth/` | Future Forth runtime app (separate process; empty placeholder for now) |

One Xcode project (`EditForth.xcodeproj`) builds the editor target today. A second target for `Forth/` comes later.

## Direction

- Editor workspace with a **Ping** panel that stays in the editor.
- A real Forth console/UI can **dock under Ping** and later **detach** as its own window, still lifecycle-tied (quit either side shuts both down).
- Prefer hosting a real Forth UI over cloning a second REPL inside the editor.
- 64Forth and 64Edit remain the shipped companion pair; EditForth is the place to try the combined direction without interfering with them.

## Status

Editor target builds from the 64Edit source copy under `Editor/`. It still talks to **64Forth** over `edit.sock` until the EditForth `Forth/` app exists. Display names and types still say 64Edit in places — rename pass comes next.

## Build

Open `EditForth.xcodeproj` in Xcode and run the **EditForth** scheme (Debug).

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project EditForth.xcodeproj -scheme EditForth \
  -configuration Debug -derivedDataPath DerivedData/EditForth-debug build
```

## License

Public domain. Do what you want.
