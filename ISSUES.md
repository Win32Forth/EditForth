# EditForth — issues and solutions

**Baseline:** **2.2.0** / build **7** ships the fixes below. **2.1.0** (tag **v2.1.0**, commit `b941544`) did not include them.  
**Updated:** 2026-10-10.

**Scope:** EditForth editor + companion 64Forth in this repo. Standalone Win32Forth/64Forth (1.5.4) is a separate product and has not received these changes.

## Status key

| Mark | Meaning |
|------|---------|
| **Fixed** | In the working tree. Solution is what shipped in source, not a proposal. |
| **Open** | Not done. |
| **Limit** | Behaves this way on purpose. |

---

## Fixed

### 1.1 Space / F6 stepped into colon calls after Break Now — **Fixed**

**Problem:** After Break Now, Space, F6, and Step Over single-stepped into a colon call (`MAINX`, `SHOW-TIME`) instead of running the call and stopping after it.

**Why:** Break ASAP sets `debug_floor = 0` so the first pause can land in the current frame. `next_debug` used `cbz floor, 2f`, which jumped past the step-over and step-out checks. `DBG-STEP-OVER` still stored `debug_over`, but nothing read it.

**Solution:** In `Forth/Kernel/forth.s`, a zero floor branches to the over/out checks (`cbz floor, 20f`), not to the pause peek. Over and out still run when floor is 0. Kernel rebuild required. `Resources/Library/Sources/forth.s` is kept in sync with `Forth/Kernel/forth.s`.

### 1.2 Literal and branch highlight — **Fixed**

**Problem:** The green wash sat on the wrong token, especially on `LIT` / `SLIT` / branch payload cells (`off=0 len=0`), then fell through to “find this name near the line.”

**Why:** dbg-map has one slot per body cell. The payload slot is empty. Pause IP often lands there. `DBG-MAP-CELL#` is `DBG-BODY#` then `1-` (kernel counts from CFA+8; the map indexes from `>BODY`, CFA+16). That index math was already correct; the empty slot was the miss.

**Solution:** `DBG-MAP-SPAN-RESOLVE` in `Library/Debugger/dbg-map.fth` uses the current slot when `len <> 0`. If the slot is empty and the previous kind is LIT, SLIT, or BR, it uses the previous slot’s span. `DBG-PUBLISH-SPAN` and `DBG-MAP-HL` call it. Smoke: `Testing/DbgSpan/span-check.fth` (`DBG-SPAN: PASS`).

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

**Solution:** `FileHost.syncNewerShippedDebugger` copies each `Resources/Library/Debugger/*.fth` into Documents when the shipped file is missing or newer. A Documents file that is newer than the app is left alone. Called at the end of `installUserTree` (launch and **Update User Data**). Other Library folders are not overwritten. **Restore Shipped Files** still replaces the whole tree.

### 2.1 Compare with Disk did not watch the file — **Fixed**

**Problem:** **File → Compare with Disk** built the hunk list once. A later write on disk stayed stale until **Reload Diff**.

**Solution:** `BufferDiskDiffSession` opens the file with `O_EVTONLY` and a `DispatchSource` for write, extend, rename, and delete. Those events call `reload()`. **Reload Diff** and **Revert to Disk…** stay. Still no keyboard shortcut (⌘⇧D is CHDIR).

### 2.2 RUN ignored the caret — **Fixed**

**Problem:** F5 / RUN always filled the console from `LAST`.

**Solution:** `prepareRunLine(_:name:)` uses the caret token when it is one whitespace-delimited Forth word (`WorkspaceModel.forthTokenAtCaret` / the text view). Otherwise it still queries `LAST`. Return still runs the line. ⌘F5 is `DEBUG`, ⌘⇧F5 is `BPGO`. The editor, the global F5 monitor, and the RUN button all pass the caret name.

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

`Forth/Kernel/` is what you edit. The 64Forth **Copy Library** build phase copies `forth.s`, `kernel_api.h`, the boot `.inc` files, and the kernel `.fth` files into `Forth/Resources/Library/Sources/` and then into the app. A debug or release build of the companion does that. `release.sh` does not copy them itself. `Library/Sources/README.txt` lives only in Sources.

### 3.1 GRAPHICS window is not the console — **Limit**

Dock and undock move the Forth console only. GCLOCK and other App Output windows stay separate. Esc in the graphics window quits that app. q / Stop in the debugger aborts the session. The windows are not merged.

### 3.2 BYE drops the console — **Fixed**

`BYE` used to send `requestQuit`, and EditForth called `NSApp.terminate` (same as Cmd-Q). Now the editor stays open with its files. The console is hidden, the debugger is cleared, and a Ping-launched companion is stopped so the VM is not left dead on `edit.sock`. The next successful connect shows the console again. Standalone 64Forth (no editor client) still quits on `BYE`.

### 3.3 Standalone 64Forth is still 1.5.4 — **Open** (P3)

These debugger and editor fixes are EditForth-only. Backport is a separate cherry-pick of `forth.s`, `kernel_api.h`, and `Library/Debugger` into the standalone tree. Do not do that from this repo silently.

### 4.1 Release script stops before git — **Limit**

`scripts/release.sh prep` bumps, archives, validates (ANS, Hayes, dbg-span), emit-smokes VED64, and builds the DMG. It does not delete the old DMG, commit, push, or run `gh release create`. That stays a human step. Leave `HYPER.NDX` unstaged.

### CODE without NEXT — **Limit**

Break Now cannot stop inside a `CODE` word that never returns to ITC `NEXT`. See 1.3.

---

## Out of scope

- Replacing `edit.sock` with NSXPC.
- Listing / xref UI and TCOM / SIMARM64 highlighting.
- Retiring old SZ-EDITOR stubs beyond what dbg-map already bypasses.
- Interactive sample runs inside `release.sh`.
- Making Run to Here stop on a definition header.
