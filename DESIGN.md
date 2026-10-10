# EditForth design notes

## Version

Marketing **2.1.0** / build **6** for both targets (EditForth + companion 64Forth). Shipped DMG/tag **v2.1.0** (`Releases/EditForth-2.1.0-macOS.dmg`). First public release was **v2.0.0**. Highlights: Debug **Run to Here**, **Break Now / Pause** (`DEBUGGER-END` floor), **File → Compare with Disk**.

## Why a new project

- **64Forth** stays free to remain a console-first Forth app.
- **64Edit** stays the external editor companion for 64Forth over `edit.sock`.
- **EditForth** is the sandbox for a combined editor + dockable Forth UI so experiments do not block releases of the existing pair.

Earlier working name **64Forth2** was dropped for that reason.

## Naming

- Umbrella / repo / editor display name: **EditForth**.
- Internal trees keep **64Edit** and **64Forth** filenames, types, and (for the Forth app) product/bundle/App Support identity so diffs backport cleanly.
- README must keep the **not a derivative of eForth** note.

## Repo layout

```text
EditForth/                 # repo root
  EditForth.xcodeproj      # ONE project, two targets
  Editor/                  # EditForth target (64Edit sources)
  Forth/                   # 64Forth target (64Forth sources)
  Releases/                # versioned dual-app DMG + Gatekeeper aids
  README.md
  DESIGN.md
  ROADMAP.md               # planned release automation + editor/emit UX
```

## Companion GRAPHICS (post-2.0.0)

`(APP-OPEN)` and pixel blits must not `main.sync` from the Forth thread during sock evaluate — they use a pending-UI queue serviced by `KernelBridge`’s evaluate pump. Sock `pushKey` feeds App Output only while that window is open (idle typing must not poison `KEY?`). Bare `FLOAD`/`INCLUDE` and `EDIT` request EditForth panels over IPC. Editor status **INCLUDE** / **RUN** / **EMIT** and `EMIT-NO-*` directives: see `ROADMAP.md` and `Forth/Resources/Docs/EMIT-AUTO.md`. Live Autoload uses `~/Documents/EditForth/Library`; copy Sample/Emitter edits back into `Forth/Resources/Library/` before shipping. **File → Compare with Disk** (menu only) opens a colored hunk-list tab for the selected saved buffer vs disk (Reload / Revert); no FSEvents watch yet.

Two **separate processes**, one Xcode project. Schemes: `EditForth` and `64Forth`.

Ping in the editor launches the **EditForth** project’s `64Forth.app` (same Products folder, then `EditForth-*` DerivedData). It does not prefer the standalone Win32Forth/64Forth DerivedData tree.

### Companion embed (current)

Window overlay docking (separate NSWindow `setFrame` into a slot) failed UX (float/z-order/overhang). Replaced by:

- **64Forth `--companion` / `FORTH64_COMPANION=1`**: `CompanionChannel` — kernel + `edit.sock`, `NSApp` activation policy `.accessory`, no WindowGroup.
- **Editor** `DockedConsoleView` under Ping: protected transcript + editable tail; `executeCommand` / `pushKey` / streamed `consoleOutput`.
- IPC: `EditorRequest.pushKey`; legacy `dock`/`undock` are no-ops that ack `dockState`.
- Lifecycle: editor quit terminates Ping-launched companion (Process + bundle-URL match). Full quit-either-ends-both still open.
- GRAPHICS App Output / facility windows remain out of scope while headless.
- **Undock**: EditForth-owned floating `NSWindow` hosting `DockedConsoleView` (same companion / sock). Not a second 64Forth GUI process.
- **Dock** / closing the floating window: console returns under Ping. Preference `forthDocked` (default true).

## Intended architecture (dock / detach)

1. Default: embedded companion console under Ping (one editor window).
2. **Ping stays in the editor**.
3. Undock = floating console window (editor-owned); **quit editor ends companion**.
4. Re-dock always lands **below Ping**.

## Commit exclusions

- Leave `Forth/Resources/Config/HYPER.NDX` unstaged (local Hyper index).
- Leave emit products under `Forth/Resources/Library/PI` and Emitter smoke/runner artifacts gitignored.
- Leave xcuserdata unstaged.
