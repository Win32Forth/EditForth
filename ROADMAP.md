# EditForth / 64Forth roadmap notes

Captured 2026-10-06 from product discussion. Working notes — not a shipped design lock.

---

## 1. Automated release pipeline (64Forth + dual-app DMGs) — **done (v1 script)**

Goal: one repeatable path so version bumps, validation, samples, DMG, docs, commit/push, and GitHub release stay in sync and avoid manual mistakes.

**v1 script:** `scripts/release.sh` (helpers in `scripts/lib/release-common.sh`). EditForth dual-app only. Subcommands: `bump`, `validate`, `emit-smoke`, `archive`, `dmg`, `prep`. Does **not** trash old DMGs, commit, push, or `gh release create`. Smoked: `validate` (ANS + Hayes), `emit-smoke` (VED64), `archive` → stage both apps, `dmg --out /tmp/…`.

### Intended sequence
1. **Bump version** — **scripted (`bump` / `prep`):** marketing + build lockstep; pbxproj, Info.plist, banners, STATUS/README/DESIGN stubs. Review STATUS prose before ship.
2. **Update docs** — bump touches version lines; release notes / collage refresh still human as needed.
3. **ANS-VALIDATE** — **scripted (`validate`):** `--agent` + `FROMLIB FLOAD Testing/ANSValidate/ANS-VALIDATE.fth`; require `ALL PASS` / `0 failed`.
4. **Hayes suite** — **scripted (`validate`):** `--agent` + `FROMLIB FLOAD Testing/HayesTest/HayesTest.fth`; require `HAYES: ALL COUNTS ZERO — PASS`. **Done (host):** ACCEPT auto-feed (`hayes-accept` + Return) on stock prompt; suite unchanged.
5. **App-window smoke** — **deferred** (GUI KEY loops).
6. **Sample programs** — **v1 emit-smoke:** `Sample/VED64.fth` via `EMIT-AUTO-FILE`; require `VED64.app` + clean quiet log. Full interactive Sample runs deferred.
7. **Release DMG** — **scripted (`archive` + `dmg`):** Archive → stage apps + collage JPG + README.pdf → `diskutil image create` UDZO under `Releases/EditForth-<ver>-macOS.dmg`.
8. **Retire old DMG** — **human:** trash previous `Releases/*-macOS.dmg` after the new one is ready.
9. **DMG contents** — collage + PDF copied into the volume by `dmg`.
10. **Commit + push** — **human ask** after trash; leave `HYPER.NDX` unstaged.
11. **GitHub release** — **human ask** (tag, notes, attach DMG + collage).

### Automation shape
- `./scripts/release.sh prep <ver> <build> [--stamp "…"] [--force]` runs bump → archive → validate → emit-smoke → dmg, then prints the handoff checklist.
- Keep human confirmation before `gh release create` / deleting old DMGs.
- Standalone 64Forth / 64Edit automation later.

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
5. Release automation script wrapping ANS → Hayes → smokes → samples → DMG → git → `gh release`. **Done (v1):** `scripts/release.sh`; human still trashes old DMG and asks for commit/push/`gh`.

---

*End of capture.*
