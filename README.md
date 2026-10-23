# EditForth

**Public domain.**

**EditForth** is a  macOS Forth editor + Forth runtime workspace. It is a **separate project** from [64Forth](https://github.com/Win32Forth/64Forth) and [64Edit](https://github.com/Win32Forth/64Edit), so those apps can keep evolving on their own (including 64Forth remaining a console-first Forth).

**Version:** **2.5.0** (build **19**). **EditForth.app** is one app. It runs a second process of the same executable as the Forth companion. Latest shipped DMG is `Releases/EditForth-2.5.0-macOS.dmg` (tag **v2.5.0**, one app). First public release was **v2.0.0**.

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

Typical use: open **Ask Forth**, ask a question, and watch a new `~/Documents/EditForth/AskForth/AskForth-N.fth` tab fill as the reply **streams** (wrapped at 80 columns). **Agent Enhance Reply** improves that answer in one click (appends an **Agent Enhanced Reply** section). Edit as needed, then **INCLUDE**. **Library context** defaults to `Library/Sample` and also searches **`Library/Reference`** (Forth 2012); **Library…** can use **Hybrid** retrieve with Ollama **`nomic-embed-text`** (pull once, then **Rebuild Index…**) so paraphrased questions still find ANS stack effects. Optional **Fetch URLs in Prompt** and **View → Open Web Page** (⇧⌘L) bring web pages into Ask. Full how-to: [`Forth/Resources/Docs/Ask-Forth.md`](Forth/Resources/Docs/Ask-Forth.md).

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

**Run the system by double clicking the EditForth.app icon.** EditForth starts, then launches itself again as the embedded companion. If that companion does not connect, the **Start Forth** button launches the same executable with `--companion`. Connection is still `~/Library/Application Support/64Forth/edit.sock`. User files and the default Forth working directory are **`~/Documents/EditForth`** (Library / AutoLoad / Docs / Config under that tree). FLOAD/CHDIR start there; dig into subfolders as needed (no FROMLIB for normal loads).

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

1. Open `Releases/EditForth-2.5.0-macOS.dmg` (or the matching GitHub release asset). From **2.5.0** on, the disk image contains **EditForth.app** only.
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
