# EditForth

**Public domain.**

**EditForth** is a greenfield macOS Forth editor + Forth runtime workspace. It is a **separate project** from [64Forth](https://github.com/Win32Forth/64Forth) and [64Edit](https://github.com/Win32Forth/64Edit), so those apps can keep evolving on their own (including 64Forth remaining a console-first Forth).

Current marketing version: **0.1.0** / build **1** (scaffold only).

## Not eForth

**EditForth is not a derivative of eForth.** The names are only a little alike. If it *were* a derivative of eForth, it would probably be a pretty nice Forth.

## Direction (scaffold)

Long-term shape (subject to change as we build):

- Editor workspace with a **Ping** panel that stays in the editor.
- A real Forth console/UI can **dock under Ping** and later **detach** as its own window, still lifecycle-tied (quit either side shuts both down).
- Prefer hosting a real Forth UI over cloning a second REPL inside the editor.
- 64Forth and 64Edit remain the shipped companion pair; EditForth is the place to try the combined direction without interfering with them.

## Status

Empty SwiftUI shell that builds and opens a window with placeholder Editor / Ping / Forth dock regions. No kernel, no IPC, no file tabs yet.

## Build

Open `EditForth.xcodeproj` in Xcode and run the **EditForth** scheme (Debug).

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project EditForth.xcodeproj -scheme EditForth \
  -configuration Debug -derivedDataPath DerivedData/EditForth-debug build
```

## License

Public domain. Do what you want.
