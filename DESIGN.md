# EditForth design notes

## Why a new project

- **64Forth** stays free to remain a console-first Forth app.
- **64Edit** stays the external editor companion for 64Forth over `edit.sock`.
- **EditForth** is the sandbox for a combined editor + dockable Forth UI so experiments do not block releases of the existing pair.

Earlier working name **64Forth2** was dropped for that reason.

## Naming

Product and repo name: **EditForth**. Bundle id: `com.Win32Forth.EditForth`.

README must keep the **not a derivative of eForth** note (names only resemble each other).

## Repo layout

Sibling folders (like 64Edit and 64Forth as separate trees, but one git repo):

```text
EditForth/                 # repo root
  EditForth.xcodeproj      # editor target now; Forth target later
  Editor/                  # editor app (from 64Edit; rename pass deferred)
  Forth/                   # Forth runtime app (placeholder)
  README.md
  DESIGN.md
```

Two **separate processes** when both apps exist. One packaging story later (multi-target project / shared DMG) is fine; the process boundary still holds.

## Intended architecture (dock)

1. When docked, the editor shows the **real** Forth UI under the Ping panel — not a cloned character console.
2. **Ping stays in the editor** whether Forth is docked or floating.
3. Undock = separate window; **quit either app ends both** (lifecycle-tied).
4. Re-dock always lands **below Ping**.

IPC details (sock vs XPC, how the docked surface is embedded) are deferred until the first real Forth host lands under `Forth/`.

## Current state

- `Editor/` is a straight copy of 64Edit **1.5.4** sources (filenames and symbols still 64Edit / SixtyFourEdit*).
- Product display name and bundle id for the Xcode target remain **EditForth** / `com.Win32Forth.EditForth`.
- Until `Forth/` has a runtime, the editor still expects a running **64Forth** on `edit.sock`.
