# EditForth / 64Forth roadmap notes

Captured 2026-10-06 from product discussion. Working notes — not a shipped design lock.

---

## 1. Automated release pipeline (64Forth + dual-app DMGs)

Goal: one repeatable path so version bumps, validation, samples, DMG, docs, commit/push, and GitHub release stay in sync and avoid manual mistakes.

### Intended sequence
1. **Bump version** — marketing + build for the relevant apps (EditForth lockstep companion when shipping EditForth; standalone 64Forth when shipping 64Forth). Mirror stamps in Info.plist / pbxproj / console banner / STATUS / README / DESIGN as today.
2. **Update docs** — README, DESIGN, STATUS, release notes draft; Gatekeeper / “Getting … to run” collage if UI changed.
3. **ANS-VALIDATE** — run and require a clean result (no errors).
4. **Hayes suite** — run and require a clean result (no errors). **"Hayes suite needs to accept automated key input so the ACCEPT test can succeed, but not by modifying the test itself, but by modifying the system to feed it keys automatically. If this is not possible, then we need to skip the ACCEPT test so that the tests run without user input."**
5. **App-window smoke** — built-in GRAPHICS smokes (`GRAPHICS-SMOKE`, `GRAPHICS-PSMOKE`, `GRAPHICS-CSMOKE` as appropriate) under a real window (not `--agent` for KEY loops).
6. **Sample programs** — build and run several Sample / Emitter stand-alones (e.g. lines-demo / RUN-LINES, IMAGEVIEW64, EDIT64 or current Sample set); confirm they launch and basic interaction works. **"This may be a challenge, since these programs normally require user input, so we may just see if they run and then shut them down."**
7. **Release DMG** — create the new dual-app (or single-app) DMG; include updated install aids.
8. **Retire old DMG** — remove previous `Releases/*-macOS.dmg` from the tree when replacing. **"Move the old dmg to the trash."**
9. **DMG contents** — refresh docs and “Getting … to run.jpg” (and README.pdf if used) **inside** the DMG volume as well as `Releases/`.
10. **Commit + push** — stage release assets + docs; leave `HYPER.NDX` / local noise unstaged.
11. **GitHub release** — tag, notes, attach DMG + collage (+ PDF if applicable).

### Automation shape (later)
- Prefer a single script or documented checklist under the repo (e.g. `scripts/release.sh` or `.grok` workflow) that fails fast on ANS/Hayes/smoke. **"As noted earlier, we eihtr need to figure out how to feed the Hayes tests keys, so ACCEPT can be tested, or we need to remove that test so Hayes runs without user input."**
- Keep human confirmation before `gh release create` / force-push / deleting old DMGs until trusted.
- EditForth and standalone 64Forth may share steps but different version lines and DMG layouts.

---

## 2. EditForth status-panel / function-key workflow

Editor-driven load / run / emit for the **current tab**, with less boilerplate in user source.

### Buttons / keys (function key TBD — user does not remember which)
| Action | Intent |
|--------|--------|
| **FLOAD current** | Status-panel button + function key: `FLOAD` / `INCLUDED` the file of the active editor tab. **Button can be INCLUDE (F4?), and it INCLUDEs the current editor tab file. The system automatic ANEW can use the base filename\_MODULE as the filename"**|
| **Run default** | Button: run the “default” entry (conventionally `MAIN` or last agreed runner) for the current project after load. **Button can just be named RUN (F5) with a floating text of "Run LAST FLOADed", and the button uses LAST to decide what to run."**|
| **Emit stand-alone** | Button: emit current program to a `.app` after ensuring it has been built; place artifacts beside the source or in a known output dir. **Button name can be EMIT (no F key)with a floating text of "Emit Window App"**|

### Auto-ANEW on editor load/run
- When loading/running from the editor buttons (not necessarily every bare console `FLOAD`), wrap or prepend an automatic **ANEW** (or equivalent forget/marker) so the same file can be reloaded repeatedly **without** the user putting `ANEW` at the top of the file. **The automatic ANEW can be the base "filename\_MODULE" so it is unique to every file we FLOAD**.
- Scope carefully: only the words defined by that session/file, or a named marker tied to the buffer — exact semantics TBD.

### Source directives (file head)
| Directive | Intent |
|-----------|--------|
| **`APP-WINDOW`** | Declare that this program targets the App Output / GRAPHICS window (not console-only). Drives search order, I/O remap, and run/emit defaults. |
| **`STAND-ALONE`** | Declare intent to emit a stand-alone app; implies / pairs with `APP-WINDOW` and sets up emit via `EMIT-WINDOW-APP` (or successor) for the designated runner word. |

Exact Forth spelling (`APP-WINDOW`, comment form, or `REQUIRE`-style) TBD; should be obvious at the top of the file.

### Run / emit conventions
- User supplies a default entry (e.g. `MAIN` or `RUN-…`) at the end of the source (or named by directive).
- **Run** button: load (with auto-ANEW) → run that entry. **"Not a bad idea, could be linked to the LAST definition compiled."**
- **Emit** button: ensure loaded/built → `EMIT-WINDOW-APP` (window) using `STAND-ALONE` / `APP-WINDOW` settings → write `.app` (+ image) next to project or under a Releases/build folder. **"No, for now we are going to always EMIT to the Documents/EditForth folder. This will simplify where the user needs to look to find their emmitted program."**

### Open decisions
- Which function key for FLOAD-current (and whether Run/Emit get keys too). **" INCLUDE-F4, RUN-F5"**
- Marker name / ANEW strategy for multi-file projects.
- Whether directives are parsed by the editor host, by a small prelude, or by Forth words in Autoload.

---

## 3. Quiet Emitter (log beside the app)

Emitter works well but is noisy on the console.

### Wanted behavior
- On successful (and failed) emit, **redirect Emitter console chatter to a log file** beside the built app (e.g. `MyApp.app` + `MyApp.emit.log` or `Contents/…` sibling in the output directory).
- Console stays quiet when emit succeeds; user opens the log only for debugging. **"Console can receive a brief error message if EMIT fails, and a brief success message when it succeeds, along with the full path of where the app was diposited."**
- Preserve full transcript (reach, reloc, sizes, warnings).

### Implementation sketch (later)
- Host or Emitter hook: capture `TYPE`/`EMIT` during `EMIT-WINDOW-APP` / `TGT-BUILD`, or tee Forth output to a file for that span.
- Always write the log; optionally print a one-line console summary: `Emitted MyApp.app (see MyApp.emit.log)`.
- **Are there really other options for EMIT, can EMIT without WINDOW actually emit a program that runs in a terminal?**

---

## 4. Related context (already working / recent)

- EditForth companion GRAPHICS: pending-open + pending-blit on evaluate pump; keys to App Output only while open.
- `lines-demo.fth`: `RUN-LINES`, emit with `EMIT-WINDOW-APP RUN-LINES`; end search order `FORTH GRAPHICS FORTH` so emit finds `RUN-LINES` without a manual `ALSO GRAPHICS`. 
- Releases: dual-app DMG pattern, Gatekeeper collage, GitHub assets.

---

## 5. Suggested order of attack

1. Emitter quiet log (small, high leverage while emitting often).
2. EditForth FLOAD-current button + function key (pick key).
3. Auto-ANEW + Run-default button.
4. `APP-WINDOW` / `STAND-ALONE` directives + Emit button.
5. Release automation script wrapping ANS → Hayes → smokes → samples → DMG → git → `gh release`.

---

*End of capture.*
