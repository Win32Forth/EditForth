# EditForth — issues and solutions

**Baseline:** **2.6.1** / build **28** (no disk image yet; shipped image remains **2.6.0**). One `EditForth.app`: the editor and a companion process of the same executable (`--companion`). Previous ship **2.5.4** / build **24**. Before that **2.5.2** / build **22**, **2.5.1** / build **21**, **2.5.0** / build **19**, and **2.3.9** / build **18** (two apps on the DMG). **2.6.1:** status bar reads EditForth, then the version, then the open file path. Docs and System open read-only. Loads accept only .fth, .fs, and .f, and refuse system files except System/Testing. PAUSE flushes console output and waits 1 ms. Find and Replace is ⌘⇧F. Search in Folders is ⌥⌘F. The find bar shows both rows. **2.6.0:** file list (Docs open, GettingStarted.txt), editor-only tabs, status bar, fixed window title, System folder (AutoLoad included), RUN from the included file's last definition, Restart, boot module lines on Show Boot Messages. **2.5.6:** Ask Forth circled help opens a dialog. **2.5.5:** Ask Forth context window (Ollama `num_ctx`, default 32K). **2.5.4:** Ask Forth keeps one session file (earlier drafts are `\` line comments); **Edit → Toggle Line Comment** (⌘/). Background HYPER-REINDEX, status-strip result, Search in Folders rows, and **Modify Search** in **2.3.9**. Ask Forth undock + compact help + quit visibility fix in **2.3.8**; Mac ANS **FALIGNED** (3.5) + EditForth **Help → Show Boot Messages** (3.4) in **2.3.7**; AskForth header + setup banner + nomic Prepare… in **2.3.6**; model profiles + Temperature + 8192 tokens + Stop + Library hybrid/semantic RAG in **2.3.5**; web search / Tool agent / OpenAI-compatible in **2.3.3**; Ask Forth first ship in **2.3.0**. Post-ship: ⌘-click VIEW no longer opens Xcode (3.6).  
**Updated:** 2026-10-29.

**Scope:** EditForth is one app as of 2.5.0 (editor process + companion process). The 64Forth scheme still builds a standalone app. Standalone 64Forth **1.5.4** / 64Edit repos are historical; no backport (see 3.3).

## Status key

| Mark | Meaning |
|------|---------|
| **Fixed** | In the working tree. Solution is what shipped in source, not a proposal. |
| **Open** | Not done. |
| **Limit** | Behaves this way on purpose. |
| **Won't do** | Deliberately not pursued. |

---

## Fixed

### 1.1 Space / F6 stepped into colon calls after Break Now — **Fixed**

**Problem:** After Break Now, Space, F6, and Step Over single-stepped into a colon call (`MAINX`, `SHOW-TIME`) instead of running the call and stopping after it.

**Why:** Break ASAP sets `debug_floor = 0` so the first pause can land in the current frame. `next_debug` used `cbz floor, 2f`, which jumped past the step-over and step-out checks. `DBG-STEP-OVER` still stored `debug_over`, but nothing read it.

**Solution:** In `Forth/Kernel/forth.s`, a zero floor branches to the over/out checks (`cbz floor, 20f`), not to the pause peek. Over and out still run when floor is 0. Kernel rebuild required. `Resources/System/Sources/forth.s` is kept in sync with `Forth/Kernel/forth.s`.

### 1.2 Literal and branch highlight — **Fixed**

**Problem:** The green wash sat on the wrong token, especially on `LIT` / `SLIT` / branch payload cells (`off=0 len=0`), then fell through to “find this name near the line.”

**Why:** dbg-map has one slot per body cell. The payload slot is empty. Pause IP often lands there. `DBG-MAP-CELL#` is `DBG-BODY#` then `1-` (kernel counts from CFA+8; the map indexes from `>BODY`, CFA+16). That index math was already correct; the empty slot was the miss.

**Solution:** `DBG-MAP-SPAN-RESOLVE` in `System/Debugger/dbg-map.fth` uses the current slot when `len <> 0`. If the slot is empty and the previous kind is LIT, SLIT, or BR, it uses the previous slot’s span. `DBG-PUBLISH-SPAN` and `DBG-MAP-HL` call it. Smoke: `Testing/DbgSpan/span-check.fth` (`DBG-SPAN: PASS`).

**DO-CLOCK follow-up (fixed):** Step Over in `DO-CLOCK` jumped because branch alignment tried `IF` before `WHILE` and `ELSE` before `REPEAT`. The first hit was a later `IF`/`ELSE`, so `WHILE`, `REPEAT`, and the words between them never got spans. Name fallback then highlighted the wrong occurrence. `DBG-ALIGN-BRANCH` keeps the **closest** forward alias (`IF`/`WHILE`/`UNTIL`, or `ELSE`/`REPEAT`/`AGAIN`). After the fix, every `DO-CLOCK` call slot has a span in source order (`WHILE` at the inner `0BRANCH`, `REPEAT` at the following `BRANCH`, `UNTIL` at the outer `0BRANCH`). Restart the companion so Autoload reloads `dbg-map.fth`.

### 1.2b Highlight against an unsaved buffer — **Fixed**

**Problem:** Spans are file UTF-8 offsets. A dirty editor tab does not match the file the map was built from, so the wash landed on the wrong characters.

**Solution:** In `ContentView`, if the matching tab `isDirty`, the location is applied with `off=0 len=0` so the editor uses the name near the VIEW line. One console note per dirty spell: `debug highlight: buffer has unsaved edits — using the word name, not the file span`. A clean buffer uses the span again.

### 1.3 Break Now while KEY is blocked — **Fixed** (CODE still a limit)

**Problem:** Pause during a blocking `KEY` or graphics `(APP-KEY)` wait did nothing until the wait returned and Forth hit `NEXT`.

**Why:** `debug_break_asap` is only noticed by `NEXT`. A host wait does not run `NEXT`.

**Solution:**

- `kernel_debug_break_pending` reports the flag.
- Console `KEY` (`handleKeyFromKernel`): if Break Now is pending, return `-2` and do not take a character. `XKEY` treats `-2` as “back IP up onto `KEY` and re-enter `next_debug`,” so the pause shows `KEY` and a later step runs `KEY` again. The caller does not see a fake key.
- Graphics `(APP-KEY)` / `waitKey`: if Break Now is pending, return `-1` immediately so the `BEGIN (APP-KEY) … WHILE` loop returns to `NEXT` and can pause.

**Limit:** A tight `CODE` word that never calls `KEY` or `NEXT` still runs until it returns to threaded code. No watchdog aborts machine code.

### 1.4 Run to Here on a definition header — **Fixed** (wording)

**Problem:** Right-clicking `: initiate-seed` said “token not in debugger map.” The call inside `MAINX` is the real target.

**Why:** Run to arms one threaded cell (`debug_runto_ip`). A header is not a cell in a colon body.

**Solution:** Map miss `-3` in `debug-runto.fth` now prints: `runto: not a call site (click the use inside a definition, not the : header)`. Still console-only, no modal. Run to does not turn into `BREAK` on the word’s xt.

### 1.5 Gutter breakpoint marks — **Fixed**

**Problem:** Breaks were only a pale-red / gray wash and a popover list.

**Solution:** While the breakpoint wash scans the buffer, it records each matching line. `LineNumberRulerView.setGutterMarks` draws a dot in the gutter: red if any match on that line is enabled, gray if every match is disabled. The in-text wash is unchanged. The dot follows the name, not a dbg-map span, so it can mark more than one use of the same word. Clicking the gutter does not toggle; F9 / ⌘\ still does.

### 1.6 F9 / ⌘\ while DEBUG is paused — **Fixed**

**Problem:** Toggle Breakpoint worked only when idle. While paused, evaluate is rejected, so `TOGGLE-BREAK` could not run.

**Solution:** `kernel_break_toggle_name` FINDs the name in the current search order and toggles the 8-slot table. No `EVALUATE`. `ForthEditorServer` handles `.toggleBreakpoint` on the I/O queue before the busy/evaluate path. Returns: added (`1`), removed (`2`), `undefined: name` (`0`), `BREAK table full` (`-1`). The editor no longer refuses the key while armed. Idle and paused use the same path.

### 1.7 Idle Arm — **Fixed**

**Problem:** **Arm** worked only while already paused. From idle you had to type `BPGO name`.

**Solution:** `armBreakGo(runWord:)` while idle sends `BPGO` for the caret token if it is one Forth word, otherwise the first **enabled** breakpoint. The Breakpoints **Arm** button is enabled while connected, not only while paused. An empty table and no caret word still tells you to set a breakpoint or type `BPGO <word>`.

### 1.8 Break Now did not end when you returned — **Fixed**

**Problem:** `DEBUG name` disarms when the return stack gets shallower than `DBG-ON`. After Break Now, `debug_floor` stayed 0, so the session stayed armed until Continue or Stop.

**Why:** Floor 0 was required so the first pause could happen in the current frame. Setting floor to the current RSP would have skipped that stop (`same frame → do not pause`).

**Solution:** On the Break Now hit (label `24` in `next_debug`), after clearing `debug_break_asap`, store `debug_floor = RSP + 8` (one cell shallower, the caller). The current word stays deeper, so single-step still pauses. Returning past that word disarms, same idea as `DBG-ON`. The 1.1 fix remains so over/out still run if floor is ever 0.

### 1.9 Debugger library drift — **Fixed**

**Problem:** Autoload reads `~/Documents/EditForth/Library`. The ship copy is `Forth/Resources/Library`. They are not the same files. Update User Data only copies missing files, so a newer Debugger library in the app never replaced a stale Documents copy.

**Solution:** `FileHost.syncNewerShippedFiles` copies shipped `Library`, `System` (including AutoLoad), and `Docs` files into Documents when the shipped file is missing or newer. A Documents file that is newer than the app is left alone. Called at the end of `installUserTree` (launch and **Update User Data**). **Restore Shipped Files** still replaces the whole tree.

### 2.1 Compare with Disk did not watch the file — **Fixed**

**Problem:** **File → Compare with Disk** built the hunk list once. A later write on disk stayed stale until **Reload Diff**.

**Solution:** `BufferDiskDiffSession` opens the file with `O_EVTONLY` and a `DispatchSource` for write, extend, rename, and delete. Those events call `reload()`. **Reload Diff** and **Revert to Disk…** stay. Still no keyboard shortcut (⌘⇧D is CHDIR).

### 2.2 RUN ignored the caret — **Fixed**

**Problem:** F5 / RUN always filled the console from `LAST`.

**Solution:** `prepareRunLine(_:name:)` types a highlighted word when the selection is one Forth word (`forthHighlightedWord`). A bare caret is ignored, so the `\` on the first line of a file is not the run word. With nothing selected, it types the last `: NAME` in the file just passed to INCLUDE or FLOAD (`ForthColonScan`). If that file has no colon definition, it queries `LAST`. Return still runs the line. ⌘F5 is `DEBUG`, ⌘⇧F5 is `BPGO`. The editor, the global F5 monitor, the Forth menu, and the RUN button all use that rule. Restart clears the remembered name.

### 2.3 EMIT had no function key — **Fixed**

**Problem:** INCLUDE is F4 and RUN is F5. EMIT was only a button and a menu.

**Solution:** Idle **F6** calls EMIT Current (`EditorTextView` when the editor is focused, `DebugKeyMonitor` otherwise). While a debug session is armed, F6 stays Step Over.

### 2.4 Debug chrome was too tall — **Fixed**

**Problem:** While debugging, INCLUDE / RUN / EMIT and the Debug toolbar were both under the splitter.

**Solution:** While `isDebugSessionArmed`, those three buttons are hidden. The strip shows `· debugging` and `F6 over · F7 into · view mode: Space/i`. Pause stays on the strip. The Debug toolbar stays below the splitter. The buttons return when the session ends.

### 2.5 Letter keys only in view mode — **Fixed** (hint)

**Problem:** Space / i / o / g / q step only in view mode. In edit mode they type. That looked like Space was broken.

**Solution:** The armed status strip says to use F6/F7, and Space/i only in view mode. Edit mode still does not steal Space. F6–F8 work in either mode.

### 4.2 Headless debugger check — **Fixed** (library half)

**Problem:** `release.sh validate` ran ANS-VALIDATE and Hayes only. A dbg-map or `DEBUGGER-END` regression could pass `prep`.

**Solution:** `validate` also runs `FROMLIB FLOAD Testing/DbgSpan/span-check.fth`. The log must contain `DBG-SPAN: PASS` and `DEBUGGER-END: PASS` and must not contain `DBG-SPAN: FAIL`. Checked here: both PASS, depth 0. Space-over, Break Now, and paused F9 still need a live pause; they are not driven by this script.

### 4.3 Shipped in 2.2.0

The 2.2.0 DMG includes this working tree: kernel rebuild, `DBG-MAP-SPAN-RESOLVE`, nearest branch alignment, `debug-runto.fth`, `kernel_break_toggle_name`, `kernel_debug_busy`, and `Testing/DbgSpan/span-check.fth`. STATUS states that 2.1.0 Break Now + Space stepped into colon calls.

---

## Still open

### 1.10 Two copies of the kernel sources — **Not worth a change**

`Forth/Kernel/` is what you edit. The **Copy System** build phase copies `forth.s`, `kernel_api.h`, the boot `.inc` files, and the kernel `.fth` files into `Forth/Resources/System/Sources/` and then into the app. A debug or release build of the companion does that. `release.sh` does not copy them itself. `System/Sources/README.txt` lives only in Sources.

### 3.1 GRAPHICS window is not the console — **Limit**

Dock and undock move the Forth console only. GCLOCK and other App Output windows stay separate. Esc in the graphics window quits that app. q / Stop in the debugger aborts the session. The windows are not merged.

### 3.2 BYE quits EditForth — **Fixed**

`BYE` in the console quits the editor the same way as Cmd-Q. Dirty tabs get Save / Don’t Save / Cancel. Cancel leaves the editor and Forth running. A confirmed quit stops only the companion process this editor launched. Standalone 64Forth (no editor client) still quits on `BYE`.

### 3.7 INCLUDE on a clean Untitled — **Fixed**

A clean Untitled tab has nothing to save. INCLUDE and F4 open the load panel, open the picked file, close that Untitled tab, then `ANEW <stem>_MODULE` and INCLUDE. A dirty Untitled still saves first. Forth → FLOAD… still includes without opening the editor and without `ANEW`.

### 3.8 Emitted app landed in Documents/EditForth — **Fixed**

`EMIT-APP` and `EMIT-WINDOW-APP` used the companion working directory (`~/Documents/EditForth`). They now write `<source-dir>/<STEM>/` beside the last included file (app, image, and log). The status EMIT button already did that and names the app after the file. `*-TO` still takes an explicit directory. With no included file, the default is still the companion folder.

### 3.9 Terminal emit aborted in PATCH-BL-ABS — **Fixed**

`EMIT-APP` and `EMIT-NO-WINDOW` died on a plain `B` inside `KEY` (`b next_debug`) with `stand-alone cannot veneer abs B`. Stand-alone now tail-branches a copyable target and NOPs a host-only one (the debugger edge). `(PUTCHAR)`, `(WRITE-STDOUT)`, and `(GETCHAR)` are copied with a null hook so they use `write(1)` / `read(0)`. Window emit was already fine.

### 3.10 Failed emit log ignored the source path — **Fixed**

`parseEmitAutoFilePath` kept the space after `S"`, so ` /path` failed the absolute-path test and the log fell back to `Documents/EditForth/emit-failed.emit.log`. The space is trimmed. A failed `EMIT-AUTO-FILE` logs in `<source-dir>/<STEM>/`.

### 3.11 BYE after a load memory fault left the editor — **Fixed**

A load that prints `memory access error` returns to the console. `BYE` after that can exit the companion without `requestQuit`. The editor remembers a console `BYE`, and a companion process that exits on its own (not a crash, and not a stop the editor asked for) quits EditForth the same way as Cmd-Q.

### 3.4 Show Boot Messages missing from EditForth Help — **Fixed**

**Problem:** Cold-bootstrap `Loading:` / `Finished Loading:` chatter is retained in the companion and shown via **Help → Show Boot Messages**, but that item lived only on the **64Forth** menu bar (standalone GUI or companion when frontmost). While EditForth owns the console, users never saw it.

**Solution:** EditForth **Help → Show Boot Messages** sends `EditorRequest.showBootMessages` over `edit.sock`; the companion appends `=== Cold bootstrap messages ===` plus `bootTranscript` to the EditForth console (same text as companion Help). Disabled when Forth is disconnected. Both `IPCProtocol.swift` copies stay in sync.

### 3.6 ⌘-click VIEW also opened Xcode — **Fixed**

**Problem:** Console ⌘-click / VIEW correctly opened the source in EditForth (pending-goto + browse mode) and also opened the same file in Xcode (or the system default editor).

**Cause:** `FileHost.openInSystemEditor` only skipped `NSWorkspace.shared.open` when `64Edit.app` was found *and* a sock client was connected. EditForth is the sock client but is not `64Edit.app`, so VIEW fell through to the system opener.

**Solution:** If `ForthEditorServer.hasConnectedClients`, write pending-goto / notify and return — do not launch 64Edit or call `NSWorkspace.open`.

### 3.5 Mac FALIGNED returned a flag — **Fixed**

**Problem:** `FloatHost` opcodes 73–75 (`FALIGNED` / `SFALIGNED` / `DFALIGNED`) returned an “already aligned?” flag (`-1`/`0`). `kernel2.fth` DOC strings and `FALIGN` (`HERE DUP FALIGNED SWAP - ALLOT`) expect ANS address round-up, so Mac `FALIGN` could `ALLOT` a huge value and abort. `host.fth` had been written to match the flag behavior.

**Solution:** Mac host now returns the first aligned address ≥ `addr` (8-byte for `FALIGNED`/`DFALIGNED`, 4-byte for `SFALIGNED`), matching ANS and the Windows host. `host.fth` checks `0→0`, `1→8`, `8→8`, and `1 SFALIGNED → 4`.

### 3.3 Standalone 64Forth is still 1.5.4 — **Won't do**

Standalone Win32Forth/64Forth (**1.5.4**) and 64Edit do not get these debugger/editor fixes. A cherry-pick of `forth.s`, `kernel_api.h`, and `System/Debugger` into the old tree is wasted dual maintenance.

**Decision:** Keep EditForth (and its in-tree companion) as the living line. Archive the standalone **64Forth** / **64Edit** GitHub repos when ready and leave **v1.5.4** as history. If a future “64Forth + some other editor” is needed, start from EditForth and extract the companion rather than revive the old 64Forth project.

### 4.1 Release script stops before git — **Limit**

`scripts/release.sh prep` bumps, archives, validates (ANS, Hayes, dbg-span), emit-smokes VED64, and builds the DMG. It does not delete the old DMG, commit, push, or run `gh release create`. That stays a human step. Leave `HYPER.NDX` unstaged.

### CODE without NEXT — **Limit**

Break Now cannot stop inside a `CODE` word that never returns to ITC `NEXT`. See 1.3.

---

## Out of scope

### Replacing `edit.sock` with NSXPC

EditForth and companion 64Forth talk over the Unix domain socket  
`~/Library/Application Support/64Forth/edit.sock` (JSON `EditorRequest` / `ForthResponse`). That path already carries console I/O, panels, debugger, and BYE. **NSXPC** would change the transport to Apple’s typed XPC APIs (`ForthEngineXPC` is only a sketch in `IPCProtocol.swift`). Payloads would still be `Data`/JSON. Large rewrite, little user-visible gain — not planned.

### Listing / xref UI and TCOM / SIMARM64 highlighting

No EditForth panels for Forth **listings** (SEE-style decompile) or **xref** browsers. Kernel console words (`SEE`, `REF` / `XREF` / …) stay as they are. No TCOM-dialect syntax mode and no SIMARM64/`TDBG` debug wash in the editor; ITC debug highlight is what EditForth has. Those IDE extras were deferred on purpose.

### Retiring old SZ-EDITOR stubs beyond what dbg-map already bypasses

**SZ-EDITOR** (in-app facility grid editor) is gone; editing is EditForth / was 64Edit. Leftover stubs remain: `DBG-ED-*` DEFERs that once bound to `SZ-*`, Hyper `HYPER-*-XT` slots that stay 0, facility/host comments and key-injection paths, stale docs.

**Already bypassed:** `dbg-map.fth` / `DBG-MAP-BIND` slurps source, resolves spans, and publishes them over `edit.sock` — no SZ-EDITOR required for debug highlight or Run to Here.

**Out of scope:** a cleanup pass to delete or rename all remaining SZ wiring. High churn / break risk for little user-visible gain. Leave the stubs.

### Interactive sample runs inside `release.sh`

`prep` already does **non-interactive** checks: ANS-VALIDATE, Hayes, dbg-span, and VED64 **emit-smoke** (`EMIT-AUTO-FILE` → `VED64.app` + clean log). That proves Emitter packaging, not that GCLOCK/DOODLE/TETRA windows behave under a real GUI.

**Out of scope:** driving interactive Sample apps (launch, keys/clicks, window assertions) from `release.sh`. Needs a logged-in desktop, automation, and flaky timing — poor fit for a batch release script. Spot-check samples by hand when needed. ROADMAP keeps full interactive Sample runs deferred.

### Making Run to Here stop on a definition header

**Run to Here** arms one threaded cell (`debug_runto_ip`) — a **call site** inside a colon body. A `: name` header is not a threaded cell, so it cannot be a runto target.

**Already done (1.4):** clicking a header prints  
`runto: not a call site (click the use inside a definition, not the : header)`  
instead of a vague map miss. Run to does **not** become `BREAK` on the word’s xt.

**Out of scope:** redefining header clicks as “stop when this word runs” (entry/BREAK/first-cell). That is a different feature; use Break / gutter / BPGO for word-level stops.
