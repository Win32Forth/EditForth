# EditForth / 64Forth roadmap notes

Captured 2026-10-06 from product discussion. Working notes — not a shipped design lock.

---

## 1. Automated release pipeline (64Forth + dual-app DMGs)

Goal: one repeatable path so version bumps, validation, samples, DMG, docs, commit/push, and GitHub release stay in sync and avoid manual mistakes.

### Intended sequence
1. **Bump version** — marketing + build for the relevant apps (EditForth lockstep companion when shipping EditForth; standalone 64Forth when shipping 64Forth). Mirror stamps in Info.plist / pbxproj / console banner / STATUS / README / DESIGN as today.
2. **Update docs** — README, DESIGN, STATUS, release notes draft; Gatekeeper / “Getting … to run” collage if UI changed.
3. **ANS-VALIDATE** — run and require a clean result (no errors).
4. **Hayes suite** — run and require a clean result (no errors). **"Hayes suite needs to accept automated key input so the ACCEPT test can succeed, but not by modifying the test itself, but by modifying the system to feed it keys automatically. If this is not possible, then we need to skip the ACCEPT test so that the tests run without user input."** **Done (host):** `KernelBridge` auto-feeds `hayes-accept` + Return when emit shows the stock `PLEASE TYPE UP TO 80 CHARACTERS:` prompt (EditForth companion); suite sources unchanged.
5. **App-window smoke** — built-in GRAPHICS smokes (`GRAPHICS-SMOKE`, `GRAPHICS-PSMOKE`, `GRAPHICS-CSMOKE` as appropriate) under a real window (not `--agent` for KEY loops).
6. **Sample programs** — build and run several Sample / Emitter stand-alones (e.g. lines-demo / RUN-LINES, IMAGEVIEW64, EDIT64 or current Sample set); confirm they launch and basic interaction works. **"This may be a challenge, since these programs normally require user input, so we may just see if they run and then shut them down."**
7. **Release DMG** — create the new dual-app (or single-app) DMG; include updated install aids.
8. **Retire old DMG** — remove previous `Releases/*-macOS.dmg` from the tree when replacing. **"Move the old dmg to the trash."**
9. **DMG contents** — refresh docs and “Getting … to run.jpg” (and README.pdf if used) **inside** the DMG volume as well as `Releases/`.
10. **Commit + push** — stage release assets + docs; leave `HYPER.NDX` / local noise unstaged.
11. **GitHub release** — tag, notes, attach DMG + collage (+ PDF if applicable).

### Automation shape (later)
- Prefer a single script or documented checklist under the repo (e.g. `scripts/release.sh` or `.grok` workflow) that fails fast on ANS/Hayes/smoke. Hayes ACCEPT auto-feed is in the host (see §1 step 4); no suite edit required.
- Keep human confirmation before `gh release create` / force-push / deleting old DMGs until trusted.
- EditForth and standalone 64Forth may share steps but different version lines and DMG layouts.

---

## 2. EditForth status-panel / function-key workflow

Editor-driven load / run / emit for the **current tab**, with less boilerplate in user source.

### Buttons / keys (function key TBD — user does not remember which)
| Action | Intent |
|--------|--------|
| **FLOAD current** | **Done:** status-panel **INCLUDE** + **F4** (also Forth → INCLUDE Current). Saves the tab if dirty/Untitled, `ANEW <STEM>_MODULE`, then `S" path" INCLUDED`. Menu **FLOAD…** (⇧⌘L) stays the open-panel path without auto-ANEW. |
| **Run default** | **Done (fill, not auto-exec):** status **RUN** + **F5** put `LAST`’s name on the console input; user may add stack args, then Return. **⌘F5** → `DEBUG <name>`; **⌘⇧F5** → `BPGO <name>`. Later: highlighted token in the editor overrides LAST. |
| **Emit stand-alone** | **Done:** status **EMIT** / Forth → EMIT Current. Re-INCLUDEs the tab, then **`EMIT-AUTO-FILE`** (stem = main path). Output under **Documents/EditForth** (`./<STEM>.app`). Default = window wrap of **LAST** + “Press a key to exit” + **KEY DROP**. See `Docs/EMIT-AUTO.md`. |

### Auto-ANEW on editor load/run
- **Done:** editor INCLUDE/EMIT use `ANEW <STEM>_MODULE` plus `EMIT-FLAGS-RESET` before `INCLUDED`.

### Source directives (Forth no-ops near top of main file)
| Directive | Intent |
|-----------|--------|
| *(none)* | Window `.app`: wrap **LAST** with `WINDOW`, print **Press a key to exit**, `KEY DROP`, `WINDOW-OFF`. Basename = main file stem (`LAST-INCLUDED`), not a sub-INCLUDE. |
| **`EMIT-NO-PAUSE`** | Window wrap **without** the pause (program keeps running until the user exits). |
| **`EMIT-NO-WINDOW`** | **Terminal/stdout** stand-alone (`EMIT-APP` style). Implies no auto pause — run from Terminal, not as a double-click GUI. |
| **`EMIT-NO-WRAPPER`** | **Power user only:** emit **LAST** with stock `EMIT-WINDOW-APP` / `EMIT-APP` wraps (no auto pause message). You own `WINDOW` / `KEY` / color modes yourself. |

`APP-WINDOW` / `STAND-ALONE` were dropped in favor of the above.

### Run / emit conventions
- **Run:** F5 family fills console from **LAST** (done).
- **Emit:** always to **Documents/EditForth**; see directives above.

### Open decisions
- INCLUDE = F4, RUN = F5 family (done). EMIT has no function key (button/menu).
- Marker / ANEW: `<STEM>_MODULE` (done).
- Directives: Forth words in Emitter/`EMIT-OPT` (done).

---

## 3. Quiet Emitter (log beside the app) — done (host, 2.0.1+)

Emitter works well but is noisy on the console.

### Behavior (`KernelBridge`)
- During `EMIT-APP` / `EMIT-WINDOW-APP` (and XT/TO forms), TYPE/EMIT is captured off-console.
- Full transcript → **`<stem>.emit.log`** beside the built `.app`.
- Success console: `Emitted /full/path/NAME.app` + `log: /full/path/NAME.emit.log`.
- Failure console: `Emit failed — see /full/path/….emit.log` + last ~12 log lines.
- Escape hatch: **`EMIT_VERBOSE=1`** keeps the full transcript on the console.

### EMIT-APP vs EMIT-WINDOW-APP
- **`EMIT-WINDOW-APP`**: GRAPHICS / App Output stand-alone (window I/O remap).
- **`EMIT-APP`**: console / terminal stand-alone (`SA-PRINT` → stdout); no App Output window.

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
