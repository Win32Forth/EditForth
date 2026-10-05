# EditForth design notes

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
  README.md
  DESIGN.md
```

Two **separate processes**, one Xcode project. Schemes: `EditForth` and `64Forth`.

## Intended architecture (dock)

1. When docked, the editor shows the **real** Forth UI under the Ping panel — not a cloned character console.
2. **Ping stays in the editor** whether Forth is docked or floating.
3. Undock = separate window; **quit either app ends both** (lifecycle-tied).
4. Re-dock always lands **below Ping**.

IPC / embedding details deferred until dock work starts.

## Commit exclusions

- Leave `Forth/Resources/Config/HYPER.NDX` unstaged (local Hyper index).
- Leave emit products under `Forth/Resources/Library/PI` and Emitter smoke/runner artifacts gitignored.
- Leave xcuserdata unstaged.
