# EditForth

**Public domain.**

**EditForth** is a  macOS Forth editor + Forth runtime workspace. It is a **separate project** from [64Forth](https://github.com/Win32Forth/64Forth) and [64Edit](https://github.com/Win32Forth/64Edit), so those apps can keep evolving on their own (including 64Forth remaining a console-first Forth).

**Version:** **2.7.1** (build **33**). Disk image `Releases/EditForth-2.7.1-macOS.dmg` (one app). The 2.7.0 image stays: `Releases/EditForth-2.7.0-macOS.dmg`. The 2.6.4 image stays: `Releases/EditForth-2.6.4-macOS.dmg`. Previous image: `Releases/EditForth-2.6.1-macOS.dmg`. Earlier image: `Releases/EditForth-2.6.0-macOS.dmg`. Earlier still: `Releases/EditForth-2.5.6-macOS.dmg` and `Releases/EditForth-2.5.4-macOS.dmg` (tag **v2.5.4**). **2.7.1:** the folder name above the file list is a menu of the ten most recent folders. Choose Folder… picks another. That menu does not change `~/Documents/EditForth`. `Library/WinEd/WINED64.fth` is a text editor translated from Win32Forth `wined.F`. `FROMLIB FLOAD WinEd/WINED64.fth` then `WINED64`. The window is the resizable GRAPHICS grid, with eight file slots. Keys match EditForth. Command-Q leaves the editor. Quit asks once for each dirty file. Open allocates twice the file size, and at least 4096 bytes, and later edits grow that buffer. A file is never truncated. `WINDOW` `SIZE:` and `?RESIZE:` report content size and a resize on a separate Mac window. ANS file words run in an `EMIT-WINDOW-APP` image. `FILE-SIZE` is `( fileid -- ud ior )`. A stand-alone graphics blit no longer fills the window with `?`. `LEAVE` and `(DO)` are not treated as branch offsets. A `DOES>` `CELL+` object is imported with its class. `RESIZE` is host slot **33**. `EMIT-WINDOW-APP WINED64` builds that editor. Load the emitter first. **2.7.0:** cooperative tasks. Cold start is `SINGLE`. `TASK:` `ACTIVATE` `SLEEP` `WAKE` `STOP` `MULTI` `SINGLE`. `PAUSE` yields when `MULTI` is on, then still flushes the console and waits 1 ms. Each task has its own `WORD` buffer, `PAD`, `HLD`, and `SOURCE`. `INCLUDE`, block load, and `GROWMEMORYMB` stay on the console task. Samples live in `System/Testing/Tasking/`: `1TASKCLOCK.fth`, `2TASKSCRATCH.fth`, `3TASKSEM.fth`, `4TASKQUEUE.fth`, `5TASKCORES.fth`, and `6TASKSLICE.fth`. `CLAIM` `RELEASE` `WAIT` `SIGNAL` use one cell: `1` is free, `0` is taken. `GRAPHICS-SEM`, `CONSOLE-SEM`, and `DICT-SEM` start free. `MAILBOX` allots a value and a full/empty pair. `>MBOX` stores, then signals full. `MBOX>` waits, reads, then signals empty. `QUEUE` allots a fixed ring. `>Q` publishes the tail with a release store. `Q>` acquire-loads the tail, then publishes the head. `4TASKQUEUE.fth` moved 4096 cells with no loss and a high-water depth of 15 on a 16-slot ring. `CORES` runs later activations on up to four worker queues. The console stays on its own queue. `COOP` waits, then uses the cooperative scheduler. `CORES-JOIN` waits until the workers stop. `5TASKCORES.fth` overlapped two counting loops through the ring: 100000 cells, `overlap=1`, `cbad=0`. `SLICE` `( n task -- )` is console-only. It allots n bytes, rounded up to a cell, from the console `HERE` onto one sleeping task. The user area is 280 bytes and the task block is 11736 bytes. A sliced cooperative task can `CREATE` and `ALLOT` without moving the console `HERE`. An unsliced background `ALLOT` is refused. While `CORES` is on, shared-dictionary allot and header linking take `DICT-SEM`, and a private-slice allot does not. `6TASKSLICE.fth` printed `answer=42`, `buf=99`, and `bare-hit=0`. `Library/FixPoint/FIXEDPOINT.fth` is introductory and incomplete. Vocabulary `FIXED-POINT` has `XBITS` (default 28), `XUNIT`, `F>X`, `X>F`, and `X*`. `+` and `-` are the cell words. `X*` multiplies, then divides the double-cell product by 2^XBITS, rounding toward zero. Division, square root, and trig are not included. `MANSHOW`, `MANSHOW-COOP`, and `MANSHOW-CORE` each start at 40 iterations and print the refresh time in milliseconds. `MANSHOW` draws with floating point. `MANSHOW-COOP` uses four cooperative tasks. `MANSHOW-CORE` uses four worker cores. The tasking apps keep the view in floating point and plot with `X*`. A click, pan, or scroll during a refresh stops that pass. The next action draws again. While a graphics window is open, mouse and key events are delivered, so the window stays selectable. `MULTI-TASKING.md` is the design. A Restart copies newer shipped files before `HYPER-REINDEX`. **2.6.4:** float arithmetic runs in the kernel. The docked console keeps a wrapped caret on screen. `TO` reports an undefined name. `FPICK`, `PUSH-ORDERS`, and `POP-ORDERS` are in the system. `Library/Sample/IMAGE-OUT.fth` writes a PNG and a JPEG. The graphic clock file is `GCLOCK.fth`. Click a line number to toggle a breakpoint. **2.6.3:** a second command while Forth is still evaluating shows `busy — finish current command first` on the status line and clears when that command returns. It does not print on the console. HYPER restamps `System/` as well as `Library/`, and does not take a colon word from a `.s` or `.inc` file. `SPLAT` no longer asks for a password. `LINEWALK` stays inside the window. `MANGEN` and `MANSHOW` fill the graphics window; left click zooms, middle pans, right redraws. `Library/Forth1968CM` is the 1968 IBM 1130 Forth. **2.6.2:** `Library/TCOM` is removed. Programs from that folder that run here are in `Library/Sample`. `ZTREE` needs the shell. The tab strip scrolls when the names do not fit. A selected tab is pale green, or pale yellow when the file is read-only. View → Open GitHub in Safari opens this repository. **2.6.1:** the status bar reads **EditForth**, then the version, then the open file path. Docs and System open read-only. INCLUDE, FLOAD, and EMIT accept only `.fth`, `.fs`, and `.f`, and refuse system files except `System/Testing`. `PAUSE` flushes console output and waits 1 ms. Find and Replace is ⌘⇧F. Search in Folders is ⌥⌘F. The find bar shows both rows in the console and the editor. **2.6.0:** a left file list under `~/Documents/EditForth` (Docs open, `Docs/GettingStarted.txt` in the editor), editor tabs only over the editor, a status bar (Edit Forth, the open file path, Ask Forth show/hide), window title **EditForth**, Restart, and boot-time module lines on Show Boot Messages. System sources (Assembler, AutoLoad, Debugger, Emitter, Hyper, Reference, Sources, Testing) live in `System` beside `Library`. RUN/F5 types a highlighted word, otherwise the last definition in the file just included; Return runs that line. **2.5.6:** the circled help marks in Ask Forth open a dialog. **2.5.5:** each Ask Forth model profile has a context window (Ollama `num_ctx`, default **32K**). **2.5.4:** Ask Forth keeps one `AskForth-N.fth` session (earlier drafts are `\` line comments); **Edit → Toggle Line Comment** (⌘/) adds or removes a leading `\ `. **2.5.3:** the Forth menu **Open EditForth Folder** opens `~/Documents/EditForth`. **EditForth.app** is one app. It runs a second process of the same executable as the Forth companion. First public release was **v2.0.0**.

Product umbrella: **EditForth**. Internal source trees keep **64Edit** / **64Forth** filenames and symbols so changes can be backported with fewer rename conflicts.

## Ask Forth (local AI) 

**About Ask Forth** **About Ask Forth** The term Ask Forth was coined by Grok AI, when I asked about adding AI support to EditForth. I am a paying subscriber of Grok, and I therefore own any code or new Term Grok produces for me. The term Ask Forth and AskForth sounded like new and unused terms to me, and terms that another company might want to snatch up to use for their product, so I did some research, and found no company on the internet that had been using the terms Ask Forth or AskForth. Therefore, since the software I write on my own, like EditForth is always placed in the public domain, I also publicly commit the term Ask Forth, and AskForth to copyright 2026 Thomas Zimmer, and they are hereby released for free use by anyone, as long as the use of the term is for the advancement of the Forth computer language, whether that use is private or commercial. 

I don't particularly like having to do this, but as far as I know there is no other way to protect such a term and prevent it from being locked away by some other company. 

If you don't agree with me, and can provide sufficient evidence that Ask Forth or AskForth are already being used by your company, I will happily release my copyright. 

**View → Ask Forth** (⌥⌘A) opens a trailing panel. Default provider is local **[Ollama](https://ollama.com)**; you can also choose **OpenAI-compatible** (SpaceXAI / xAI, LM Studio, etc.). For Ollama, install it and pull a model before Ask or Agent Enhance Reply will return answers:

```bash
ollama pull gemma4:e4b
```

Leave Ollama running. The panel default is **`gemma4:e4b`**. Other tags that work: **`gemma4:12b`** (better answers, much more memory) and **`gemma4:31b-cloud`** (fast cloud path — not fully local).

Typical use: open **Ask Forth**, ask a question, and watch `~/Documents/EditForth/AskForth/AskForth-N.fth` fill as the reply streams. Later Asks continue that file until **New session**. Earlier drafts stay as `\` line comments; INCLUDE loads only the newest section. **Agent Enhance Reply** replaces that live section after a headless test. Edit as needed, then **INCLUDE**. **Library context** defaults to `Library/Sample` and also searches **`System/Reference`** (Forth 2012); **Library…** can use **Hybrid** retrieve with Ollama **`nomic-embed-text`** (pull once, then **Rebuild Index…**) so paraphrased questions still find ANS stack effects. Optional **Fetch URLs in Prompt** and **View → Open Web Page** (⇧⌘L) bring web pages into Ask. Full how-to: [`Forth/Resources/Docs/Ask-Forth.md`](Forth/Resources/Docs/Ask-Forth.md).

## Not eForth

**EditForth is not a derivative of eForth.** The names are only a little alike. If it *were* a derivative of eForth, it would probably be a pretty nice Forth.

## Layout

One Xcode project. The **EditForth** scheme builds one app. The engine sources stay in `Forth/` and are linked into that app. The **64Forth** scheme still builds a standalone `64Forth.app` when you want Forth without the editor.

| Folder | Product | Role |
|--------|---------|------|
| `Editor/` | **EditForth.app** | Editor UI (from 64Edit; sources still SixtyFourEdit*) |
| `Forth/` | Linked into **EditForth.app** | Forth runtime (`forth.s` kernel, host, Library). Socket path stays `~/Library/Application Support/64Forth/edit.sock` |

```text
EditForth/
  EditForth.xcodeproj   # schemes: EditForth, 64Forth
  Editor/
  Forth/                # App, Host, Kernel, Resources, …
  Releases/             # EditForth-*-macOS.dmg + install aids
  README.md
  DESIGN.md
  ROADMAP.md            # release automation + EditForth editor/emit plans
```

Two **separate processes** of one executable; one project window in Xcode.

## Direction

- Editor workspace with a status strip and **Start Forth**.
- The Forth REPL lives **inside** the editor when docked (embedded console).
- The same **EditForth** executable runs again as a headless **companion** (`--companion`): kernel + `edit.sock`, no console window of its own.
- Companion **GRAPHICS** / App Output works from the docked console (open, blit, KEY); bare `FLOAD` / `EDIT` use EditForth panels.
- Status strip **INCLUDE** (F4), **RUN** (F5), **EMIT**; emit directives and Sample notes: **[ROADMAP.md](ROADMAP.md)**, `Forth/Resources/Docs/EMIT-AUTO.md`.
- **Undock** moves the REPL to a floating window; the red close button **hides** it (**Unhide Forth** brings it back); **Dock** embeds it under the strip again.
- **64Forth** and **64Edit** stay separate projects. EditForth 2.5.0 ships as one app.

## Status

**Run the system by double clicking the EditForth.app icon.** EditForth starts, then launches itself again as the embedded companion. If that companion does not connect, the **Start Forth** button launches the same executable with `--companion`. Connection is still `~/Library/Application Support/64Forth/edit.sock`. User files and the default Forth working directory are **`~/Documents/EditForth`** (Library / System / Docs under that tree). AutoLoad is `System/AutoLoad`. The file list starts with Docs open, and `Docs/GettingStarted.txt` opens in the editor. FLOAD/CHDIR start there; dig into subfolders as needed (no FROMLIB for normal loads).

### Embedded companion console

**Start Forth** runs this app again as an embedded companion (no Forth console window). While connected, Start Forth button is hidden. The editor hosts `DockedConsoleView` when docked; typing and output go over `edit.sock`. **Undock** opens a floating titled window; closing that window with the red traffic light hides the console (companion keeps running) and the strip shows **Unhide Forth**. **Dock** returns the console under the strip. Quit EditForth terminates the launched companion process. **Help → Show Boot Messages** appends retained cold-bootstrap `Loading:` / `Finished Loading:` text to the console (not shown automatically at startup).

## Build

In Xcode, the scheme menu (next to the Run button) lists **EditForth** and **64Forth**.  
Choose **EditForth** and Build/Run. That produces one **EditForth.app**. The Forth engine is inside it.  
Choose **64Forth** only when you want the standalone Forth app, without the editor.

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer

# One app: editor + companion engine
xcodebuild -project EditForth.xcodeproj -scheme EditForth \
  -configuration Debug -derivedDataPath DerivedData/EditForth-debug build
```

## Install (DMG)

Source on main is **2.7.1**. The disk image to install is **2.7.1**.

1. Open `Releases/EditForth-2.7.1-macOS.dmg` (or the matching GitHub release asset). From **2.5.0** on, the disk image contains **EditForth.app** only.
2. Drag **EditForth.app** into Applications.
3. Approve it once with Control-click **Open**, then Settings → Privacy & Security → **Open Anyway** (see `Releases/Getting EditForth to run.jpg` and `Releases/README.pdf`).

**Getting EditForth to run on your Mac:** All of the latest security changes Apple has made to MacOS, have made it fairly difficult to run apps obtained from outside the Apple App Store, but it is not impossible. Here is how you to it;
1. Open and view the .jpg image called 'Getting EditForth to run.jpg'.
2. This image shows a collage of the dialogs you have to traverse to get the MacOS to allow you to open the app. 
3. Don't despair, it's not that hard, just follow along;
4. Mount the .dmg file and you will see EditForth.app. A 2.5.0 image has that one app. Older images also contain 64Forth.app; you only need EditForth.app from 2.5.0 on.
5. Drag EditForth.app into Applications (recommended) or onto the desktop.
6. Hold down the Control key and click EditForth.app, then select Open.
7. You will get an error dialog that tells you that the app cannot be verified and will not be opened.
8. This last step is important because it sets up the MacOS so that you can now go into Settings and tell it to allow the app to open.
9. Open Settings, and scroll down to Privacy & Security. A list of apps and setting will be displayed.
10. Scroll down to the bottom of the Privacy & Security panel and you will see under the Security heading where it says 'EditForth.app' was blocked to protect your Mac.
11. To the right of the above message you will see a button "Open Anyway". Click the button.
12. After clicking Open Anyway, another dialog will pop up that says basically Trash, Open Anyway and Done. Click Open Anyway.
13. After you click Open Anyway in that dialog, another dialog will pop up and ask you for your password. This is the final system dialog that is keeping you from running EditForth. Simply type in your "Macs" password, and EditForth will open.
14. You are done. The editor starts a second process of the same app. They talk over ~/Library/Application Support/64Forth/edit.sock automatically — no extra pairing step. Older two-app DMGs (through 2.3.9) still need both apps approved the first time.
    
## License

Public domain. Do what you want.
