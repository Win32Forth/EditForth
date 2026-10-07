# EditForth

**Public domain.**

**EditForth** is a  macOS Forth editor + Forth runtime workspace. It is a **separate project** from [64Forth](https://github.com/Win32Forth/64Forth) and [64Edit](https://github.com/Win32Forth/64Edit), so those apps can keep evolving on their own (including 64Forth remaining a console-first Forth).

**Version:** **2.0.3** (build **4**) for both `EditForth.app` and companion `64Forth.app`. Latest shipped DMG is `Releases/EditForth-2.0.2-macOS.dmg` (tag **v2.0.2**). First public release was **v2.0.0**.

Product umbrella: **EditForth**. Internal source trees keep **64Edit** / **64Forth** filenames and symbols so changes can be backported with fewer rename conflicts.

## Not eForth

**EditForth is not a derivative of eForth.** The names are only a little alike. If it *were* a derivative of eForth, it would probably be a pretty nice Forth.

## Layout

One Xcode project, two targets, two source folders:

| Folder | Target / product | Role |
|--------|------------------|------|
| `Editor/` | **EditForth** → `EditForth.app` | Editor (from 64Edit; sources still SixtyFourEdit*) |
| `Forth/` | **64Forth** → `64Forth.app` | Forth runtime (from 64Forth; same bundle id and App Support paths) |

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

Two **separate processes**; one project window in Xcode.

## Direction

- Editor workspace with a status strip and **Start Forth**.
- The Forth REPL lives **inside** the editor when docked (embedded console).
- **64Forth** runs as a headless **companion** (`--companion`): kernel + `edit.sock`, no console window of its own.
- Companion **GRAPHICS** / App Output works from the docked console (open, blit, KEY); bare `FLOAD` / `EDIT` use EditForth panels.
- Status strip **INCLUDE** (F4), **RUN** (F5), **EMIT**; emit directives and Sample notes: **[ROADMAP.md](ROADMAP.md)**, `Forth/Resources/Docs/EMIT-AUTO.md`.
- **Undock** moves the REPL to a floating window; the red close button **hides** it (**Unhide Forth** brings it back); **Dock** embeds it under the strip again.
- 64Forth and 64Edit remain the shipped companion pair; EditForth is the place to try the combined direction without interfering with them.

## Status

Both targets build. **Run the system by double clicking the EditForth.app icon. EditForth will startup and automatically start 64Forth as an embedded companion. It for some reason 64Forth doesn't start automatically, the Start Forth** button launches this project’s **64Forth** companion (sibling Products / `EditForth-*` DerivedData in Debug; Release uses sibling or `/Applications`). Connection is still `~/Library/Application Support/64Forth/edit.sock`. User files and the default Forth working directory are **`~/Documents/EditForth`** (Library / AutoLoad / Docs / Config under that tree). FLOAD/CHDIR start there; dig into subfolders as needed (no FROMLIB for normal loads).

### Embedded companion console

**Start Forth** runs `64Forth as an embedded companion` (accessory activation, no Forth app window). While connected, Start Forth button is hidden. The editor hosts `DockedConsoleView` when docked; typing and output go over `edit.sock`. **Undock** opens a floating titled window; closing that window with the red traffic light hides the console (companion keeps running) and the strip shows **Unhide Forth**. **Dock** returns the console under the strip. Quit EditForth terminates the launched companion.

## Build

In Xcode, the scheme menu (next to the Run button) lists **EditForth** and **64Forth**.  
Choose **EditForth** and Build/Run — that also builds the **64Forth** target into the same Products folder (so Ping can launch the sibling app).  
Choose **64Forth** only when you want to run the Forth app alone.

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer

# Builds both 64Forth.app and EditForth.app
xcodebuild -project EditForth.xcodeproj -scheme EditForth \
  -configuration Debug -derivedDataPath DerivedData/EditForth-debug build
```

## Install (DMG)

1. Open `Releases/EditForth-2.0.1-macOS.dmg` (or the matching GitHub release asset).
2. Drag **EditForth.app** and **64Forth.app** into Applications (or keep them side by side in the same folder).
3. Approve each app once with Control-click **Open**, then Settings → Privacy & Security → **Open Anyway** (see `Releases/Getting EditForth to run.jpg` and `Releases/README.pdf`). Approving one app does not approve the other.

**Getting EditForth to run on your Mac:** All of the latest security changes Apple has made to MacOS, have made it fairly difficult to run apps obtained from outside the Apple App Store, but it is not impossible. Here is how you to it;
1. Open and view the .jpg image called 'Getting EditForth to run.jpg'.
2. This image shows a collage of the dialogs you have to traverse to get the MacOS to allow you to open the app. 
3. Don't despair, it's not that hard, just follow along;
4. Mount the .dmg file and you will see 64Forth.app and EditForth.app (versions match; last shipped DMG **2.0.1**).
5. Drag both apps into Applications (recommended) or onto the desktop — keep them in the same folder so EDIT / VIEW can find EditForth beside 64Forth.
6. Hold down the Control key and click 64Forth.app, then select Open. (Loop back here to do the same thing with EditForth.app)
7. You will get an error dialog that tells you that the app cannot be verified and will not be opened.
8. This last step is important because it sets up the MacOS so that you can now go into Settings and tell it to allow the app to open.
9. Open Settings, and scroll down to Privacy & Security. A list of apps and setting will be displayed.
10. Scroll down to the bottom of the Privacy & Security panel and you will see under the Security heading where it says '64Forth.app' (or EditForth.app) was blocked to protect your Mac.
11. To the right of the above message you will see a button "Open Anyway". Click the button.
12. After clicking Open Anyway, another dialog will pop up that says basically Trash, Open Anyway and Done. Click Open Anyway.
13. After you click Open Anyway in that dialog, another dialog will pop up and ask you for your password. This is the final system dialog that is keeping you from running 64Forth (or EditFoth). Simply type in your "Macs" password, and 64Forth will open and display it's Opening screen.
14. Go back to step 6. and Repeat Control-click Open / Open Anyway once for EditForth.app the first time you launch it (or the first time 64Forth opens it via EDIT / VIEW).
15. You are done. The two apps talk over ~/Library/Application Support/64Forth/edit.sock automatically — no extra pairing step.
    
## License

Public domain. Do what you want.
