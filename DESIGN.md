# EditForth design notes

## Why a new project

- **64Forth** stays free to remain a console-first Forth app.
- **64Edit** stays the external editor companion for 64Forth over `edit.sock`.
- **EditForth** is the sandbox for a combined editor + dockable Forth UI so experiments do not block releases of the existing pair.

Earlier working name **64Forth2** was dropped for that reason.

## Naming

Product and repo name: **EditForth**. Bundle id: `com.Win32Forth.EditForth`.

README must keep the **not a derivative of eForth** note (names only resemble each other).

## Intended architecture (not implemented in the scaffold)

1. **Separate processes** for editor shell and Forth runtime (not one process with two windows sharing KernelBridge).
2. **Same packaging story later** (multi-target Xcode project or shared DMG) is allowed; process boundary still holds.
3. When docked, the editor shows the **real** Forth UI under the Ping panel — not a cloned character console.
4. **Ping stays in the editor** whether Forth is docked or floating.
5. Undock = separate window; **quit either app ends both** (lifecycle-tied).
6. Re-dock always lands **below Ping**.

IPC details (sock vs XPC, how the docked surface is embedded) are deferred until the first real Forth host lands.

## Scaffold contents

- Single macOS SwiftUI app target `EditForth`.
- Placeholder layout: editor region, Ping strip, Forth dock stub.
- Version **0.1.0** / build **1**.
- No copy of 64Forth kernel or 64Edit sources in this first commit.
