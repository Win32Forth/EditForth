# EditForth design notes

## Version

Marketing **2.5.3** / build **23**. **EditForth.app** is one app: the editor process and a companion process of the same executable. The **64Forth** target remains for a standalone Forth app. Shipped DMG/tag is **v2.5.3** (`Releases/EditForth-2.5.3-macOS.dmg`, one app); previous public release **v2.5.2**. First public release was **v2.0.0**. **2.5.3:** Forth menu **Open EditForth Folder** opens `~/Documents/EditForth`. **2.5.2:** `VIEW` opens `'`, `."`, `S"`, `C"`, `S\"`, and `\`; `DISKVALUES.fth` is not in Sample. **2.5.1:** `BYE` quits EditForth like Cmd-Q (dirty sheets; Cancel keeps Forth); `EMIT-APP` / `EMIT-WINDOW-APP` write `<source-dir>/<STEM>/` beside the included file; INCLUDE on a clean Untitled opens the picked file, then includes it. **2.5.0:** one app, companion via `--companion`. **2.3.9:** background HYPER-REINDEX (side file, then swap; result on the status strip); Search in Folders uses three path rows with Choose… and Clear; search results have **Modify Search**. Since 2.3.7: Ask Forth **Undock** floating window (visibility survives quit); `info.circle` help tips; Capture Selected button removed; tighter Prompt spacing. Shipped in 2.3.7: Mac ANS **`FALIGNED` / `SFALIGNED` / `DFALIGNED`** address round-up; EditForth **Help → Show Boot Messages**. Shipped in 2.3.6: **AskForth-N.fth** F-PC header (`\\` … `{`); orange **setup banner**; **nomic** auto-pull / **Prepare…**. Shipped in 2.3.5: **model profiles**, Temperature 0.3, **8192** tokens, **Stop**, Library hybrid/semantic RAG. Requires Ollama + a pulled chat model (default `gemma4:e4b`), or an OpenAI-compatible endpoint; Hybrid/Semantic also need `nomic-embed-text`. How-to: `Forth/Resources/Docs/Ask-Forth.md`.

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
  EditForth.xcodeproj      # ONE project; EditForth scheme builds one app
  Editor/                  # editor UI + EditForthMain (companion/agent dispatch)
  Forth/                   # engine sources linked into EditForth.app
  Releases/                # versioned DMG + Gatekeeper aids (2.5.0+ is one app)
  README.md
  DESIGN.md
  ROADMAP.md               # planned release automation + editor/emit UX
```

## Companion GRAPHICS (post-2.0.0)

`(APP-OPEN)` and pixel blits must not `main.sync` from the Forth thread during sock evaluate — they use a pending-UI queue serviced by `KernelBridge`’s evaluate pump. Sock `pushKey` feeds App Output only while that window is open (idle typing must not poison `KEY?`). Bare `FLOAD`/`INCLUDE` and `EDIT` request EditForth panels over IPC. Editor status **INCLUDE** / **RUN** / **EMIT** and `EMIT-NO-*` directives: see `ROADMAP.md` and `Forth/Resources/Docs/EMIT-AUTO.md`. Live Autoload uses `~/Documents/EditForth/Library`; copy Sample/Emitter edits back into `Forth/Resources/Library/` before shipping. **File → Compare with Disk** (menu only) opens a colored hunk-list tab for the selected saved buffer vs disk (Reload / Revert); no FSEvents watch yet.

Two **separate processes** of one executable, one Xcode project. Schemes: `EditForth` (the app) and `64Forth` (standalone Forth, optional).

Ping launches `Bundle.main.executableURL` with `--companion`. It does not look for a sibling `64Forth.app`.

### Companion embed (current)

Window overlay docking (separate NSWindow `setFrame` into a slot) failed UX (float/z-order/overhang). Replaced by:

- **`--companion` / `FORTH64_COMPANION=1`**: `CompanionChannel` — kernel + `edit.sock`, `NSApp` activation policy `.regular` (Dock icon and its menu bar when that process is frontmost), no editor window.
- **Editor** `DockedConsoleView` under Ping: protected transcript + editable tail; `executeCommand` / `pushKey` / streamed `consoleOutput`.
- IPC: `EditorRequest.pushKey`; legacy `dock`/`undock` are no-ops that ack `dockState`.
- Lifecycle: editor quit terminates the Ping-launched child `Process` only. The companion shares EditForth’s bundle id, so quit must not match running apps by bundle id. Full quit-either-ends-both still open.
- GRAPHICS App Output / facility windows remain out of scope while headless.
- **Undock**: EditForth-owned floating `NSWindow` hosting `DockedConsoleView` (same companion / sock). Not a second 64Forth GUI process.
- **Dock** / closing the floating window: console returns under Ping. Preference `forthDocked` (default true).
- **Menus while EditForth is frontmost:** Forth INCLUDE/FLOAD/CLS and **Help → Show Boot Messages** live on EditForth’s menu bar (`ForthMenuSupport` / `EditorRequest`). Companion File/Tools/Help (including Show Boot Messages) appear only when the companion process’s Dock icon is frontmost. Cold-bootstrap `Loading:` / `Finished Loading:` emit stays in `KernelBridge.bootTranscript` until requested (`showBootMessages` over edit.sock).

## Intended architecture (dock / detach)

1. Default: embedded companion console under Ping (one editor window).
2. **Ping stays in the editor**.
3. Undock = floating console window (editor-owned); **quit editor ends companion**.
4. Re-dock always lands **below Ping**.

## Commit exclusions

- Leave `Forth/Resources/Config/HYPER.NDX` unstaged (local Hyper index).
- Leave emit products under `Forth/Resources/Library/PI` and Emitter smoke/runner artifacts gitignored.
- Leave xcuserdata unstaged.
