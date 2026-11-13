# EditForth design notes

## Version

Marketing **2.7.1** / build **33**. Disk image **2.7.1** (`Releases/EditForth-2.7.1-macOS.dmg`, one app). **EditForth.app** is one app: the editor process and a companion process of the same executable. The **64Forth** target remains for a standalone Forth app. The 2.7.0 image stays (`Releases/EditForth-2.7.0-macOS.dmg`). The 2.6.4 image stays (`Releases/EditForth-2.6.4-macOS.dmg`). Previous disk image remains **2.6.1** (`Releases/EditForth-2.6.1-macOS.dmg`). Earlier disk image remains **2.6.0** (`Releases/EditForth-2.6.0-macOS.dmg`). Earlier still: **2.5.6** (`Releases/EditForth-2.5.6-macOS.dmg`). Previous public release before that was **v2.5.4**. First public release was **v2.0.0**. **2.7.1:** the folder name above the file list is a menu of the ten most recent folders. Choose Folder… picks another. That menu does not change `~/Documents/EditForth`. `Library/WinEd/WINED64.fth` is a text editor translated from Win32Forth `wined.F`. `FROMLIB FLOAD WinEd/WINED64.fth` then `WINED64`. The window is the resizable GRAPHICS grid, with eight file slots. Keys match EditForth. Command-Q leaves the editor. Quit asks once for each dirty file. Open allocates twice the file size, and at least 4096 bytes, and later edits grow that buffer. A file is never truncated. `WINDOW` `SIZE:` and `?RESIZE:` report content size and a resize on a separate Mac window. ANS file words run in an `EMIT-WINDOW-APP` image. `FILE-SIZE` is `( fileid -- ud ior )`. A stand-alone graphics blit no longer fills the window with `?`. `LEAVE` and `(DO)` are not treated as branch offsets. A `DOES>` `CELL+` object is imported with its class. `RESIZE` is host slot **33**. `EMIT-WINDOW-APP WINED64` builds that editor. Load the emitter first. **2.7.0:** cooperative tasks. Cold start is `SINGLE`. `TASK:` `ACTIVATE` `SLEEP` `WAKE` `STOP` `MULTI` `SINGLE`. `PAUSE` yields when `MULTI` is on, then still flushes the console and waits 1 ms. Each task has its own `WORD` buffer, `PAD`, `HLD`, and `SOURCE`. `INCLUDE`, block load, and `GROWMEMORYMB` stay on the console task. Samples live in `System/Testing/Tasking/`: `1TASKCLOCK.fth`, `2TASKSCRATCH.fth`, `3TASKSEM.fth`, `4TASKQUEUE.fth`, `5TASKCORES.fth`, and `6TASKSLICE.fth`. `CLAIM` `RELEASE` `WAIT` `SIGNAL` use one cell: `1` is free, `0` is taken. `GRAPHICS-SEM`, `CONSOLE-SEM`, and `DICT-SEM` start free. `MAILBOX` allots a value and a full/empty pair. `>MBOX` stores, then signals full. `MBOX>` waits, reads, then signals empty. `QUEUE` allots a fixed ring. `>Q` publishes the tail with a release store. `Q>` acquire-loads the tail, then publishes the head. `4TASKQUEUE.fth` moved 4096 cells with no loss and a high-water depth of 15 on a 16-slot ring. `CORES` runs later activations on up to four worker queues. The console stays on its own queue. `COOP` waits, then uses the cooperative scheduler. `CORES-JOIN` waits until the workers stop. `5TASKCORES.fth` overlapped two counting loops through the ring: 100000 cells, `overlap=1`, `cbad=0`. `SLICE` `( n task -- )` is console-only. It allots n bytes, rounded up to a cell, from the console `HERE` onto one sleeping task. The user area is 280 bytes and the task block is 11736 bytes. A sliced cooperative task can `CREATE` and `ALLOT` without moving the console `HERE`. An unsliced background `ALLOT` is refused. While `CORES` is on, shared-dictionary allot and header linking take `DICT-SEM`, and a private-slice allot does not. `6TASKSLICE.fth` printed `answer=42`, `buf=99`, and `bare-hit=0`. `Library/FixPoint/FIXEDPOINT.fth` is introductory and incomplete. Vocabulary `FIXED-POINT` has `XBITS` (default 28), `XUNIT`, `F>X`, `X>F`, and `X*`. `+` and `-` are the cell words. `X*` multiplies, then divides the double-cell product by 2^XBITS, rounding toward zero. Division, square root, and trig are not included. `MANSHOW`, `MANSHOW-COOP`, and `MANSHOW-CORE` each start at 40 iterations and print the refresh time in milliseconds. `MANSHOW` draws with floating point. `MANSHOW-COOP` uses four cooperative tasks. `MANSHOW-CORE` uses four worker cores. The tasking apps keep the view in floating point and plot with `X*`. A click, pan, or scroll during a refresh stops that pass. The next action draws again. While a graphics window is open, mouse and key events are delivered, so the window stays selectable. `MULTI-TASKING.md` is the design. A Restart copies newer shipped files before `HYPER-REINDEX`. **2.6.4:** float arithmetic runs in the kernel. The docked console keeps a wrapped caret on screen. `TO` reports an undefined name. `FPICK`, `PUSH-ORDERS`, and `POP-ORDERS` are in the system. `Library/Sample/IMAGE-OUT.fth` writes a PNG and a JPEG. The graphic clock file is `GCLOCK.fth`. Click a line number to toggle a breakpoint. **2.6.3:** a second command while Forth is still evaluating shows `busy — finish current command first` on the status line and clears when that command returns. It does not print on the console. HYPER restamps `System/` as well as `Library/`, and does not take a colon word from a `.s` or `.inc` file. `SPLAT` no longer asks for a password. `LINEWALK` stays inside the window. `MANGEN` and `MANSHOW` fill the graphics window; left click zooms, middle pans, right redraws. `Library/Forth1968CM` is the 1968 IBM 1130 Forth. **2.6.2:** `Library/TCOM` is removed. Programs from that folder that run here are in `Library/Sample`. `ZTREE` needs the shell. The tab strip scrolls when the names do not fit. A selected tab is pale green, or pale yellow when the file is read-only. View → Open GitHub in Safari opens this repository. **2.6.1:** the status bar reads **EditForth**, then the version, then the open file path. Docs and System open read-only. INCLUDE, FLOAD, and EMIT accept only `.fth`, `.fs`, and `.f`, and refuse system files except `System/Testing`. `PAUSE` flushes console output and waits 1 ms. Find and Replace is ⌘⇧F. Search in Folders is ⌥⌘F. The find bar shows both rows in the console and the editor. **2.6.0:** left file list under `~/Documents/EditForth` with Docs open and `Docs/GettingStarted.txt` in the editor; tabs sit over the editor; the top status bar shows **Edit Forth**, the open file path, and the Ask Forth show/hide control; the window title stays **EditForth**. Assembler, AutoLoad, Debugger, Emitter, Hyper, Reference, Sources, and Testing live under `System`. RUN/F5 fills from a highlighted word, otherwise the last definition in the file just included. Restart relaunches Forth and clears the console to `Restarting Forth…`. AutoLoad `:Loading module` lines and the boot `HYPER-REINDEX` note go to Show Boot Messages. **2.5.6:** the circled Ask Forth help marks open a dialog. **2.5.5:** Ask Forth profiles set an Ollama context window (`num_ctx`, default **32K**). **2.5.4:** Ask Forth reuses one `AskForth-N.fth` until **New session** (earlier drafts are `\` line comments; INCLUDE loads the live section); **Edit → Toggle Line Comment** (⌘/). **2.5.3:** Forth menu **Open EditForth Folder** opens `~/Documents/EditForth`. **2.5.2:** `VIEW` opens `'`, `."`, `S"`, `C"`, `S\"`, and `\`; `DISKVALUES.fth` is not in Sample. **2.5.1:** `BYE` quits EditForth like Cmd-Q (dirty sheets; Cancel keeps Forth); `EMIT-APP` / `EMIT-WINDOW-APP` write `<source-dir>/<STEM>/` beside the included file; INCLUDE on a clean Untitled opens the picked file, then includes it. **2.5.0:** one app, companion via `--companion`. **2.3.9:** background HYPER-REINDEX (side file, then swap; result on the status strip); Search in Folders uses three path rows with Choose… and Clear; search results have **Modify Search**. Since 2.3.7: Ask Forth **Undock** floating window (visibility survives quit); `info.circle` help tips; Capture Selected button removed; tighter Prompt spacing. Shipped in 2.3.7: Mac ANS **`FALIGNED` / `SFALIGNED` / `DFALIGNED`** address round-up; EditForth **Help → Show Boot Messages**. Shipped in 2.3.6: **AskForth-N.fth** F-PC header (`\\` … `{`); orange **setup banner**; **nomic** auto-pull / **Prepare…**. Shipped in 2.3.5: **model profiles**, Temperature 0.3, **8192** tokens, **Stop**, Library hybrid/semantic RAG. Requires Ollama + a pulled chat model (default `gemma4:e4b`), or an OpenAI-compatible endpoint; Hybrid/Semantic also need `nomic-embed-text`. How-to: `Forth/Resources/Docs/Ask-Forth.md`.

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

`(APP-OPEN)` and pixel blits must not `main.sync` from the Forth thread during sock evaluate — they use a pending-UI queue serviced by `KernelBridge`’s evaluate pump. Sock `pushKey` feeds App Output only while that window is open (idle typing must not poison `KEY?`). Bare `FLOAD`/`INCLUDE` and `EDIT` request EditForth panels over IPC. Editor status **INCLUDE** / **RUN** / **EMIT** and `EMIT-NO-*` directives: see `ROADMAP.md` and `Forth/Resources/Docs/EMIT-AUTO.md`. Live Autoload uses `~/Documents/EditForth`. Copy Sample edits back into `Forth/Resources/Library/` and Emitter edits into `Forth/Resources/System/` before shipping. **File → Compare with Disk** (menu only) opens a colored hunk-list tab for the selected saved buffer vs disk (Reload / Revert); no FSEvents watch yet.

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
