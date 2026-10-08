# EMIT-AUTO and EMIT-NO-* directives

Editor **EMIT** re-INCLUDEs the tab, then runs `S" <main-path>" EMIT-AUTO-FILE`. The `.app` basename is always that **main file stem** (e.g. `hello.fth` → `HELLO.app`), even if the program `INCLUDE`s other files.

Console `EMIT-AUTO` uses `LAST-INCLUDED` (now updated by high-level `INCLUDED`, not only Autoload/`REQUIRE`). Prefer `EMIT-AUTO-FILE` when you care about the stem.

Artifacts are written **beside the main source file** in a stem folder:

`<source-dir>/<STEM>/` → `HELLO.app`, `HELLO.img`, `HELLO.emit.log`

Example: `…/Library/Sample/HELLO.fth` → `…/Library/Sample/HELLO/HELLO.app`.

That works for any writable folder (including Downloads). Emitting a file that lives inside a read-only app bundle (`…/EditForth.app/Contents/Resources/…`) fails at `mkdir` with a clear message — copy or open the source under Documents (or elsewhere writable) first.

Override the outdir with `EMIT-AUTO-FILE-TO` / `EMIT-AUTO-TO` when needed. Plain `EMIT-APP` / `EMIT-WINDOW-APP` still default to the companion cwd (`.`).

## Default (no directives)

Window (App Output) stand-alone:

1. Open `WINDOW` (title = file stem)
2. Run **LAST**
3. Print `Press a key to exit`
4. `KEY DROP`
5. `WINDOW-OFF`

Tiny programs like `hello.fth` need no `WINDOW` / `KEY` in the source for emit.

## Directives (put near the top of the **main** source file)

These are ordinary Forth words (Autoload/Emitter). They set flags; editor INCLUDE runs `EMIT-FLAGS-RESET` first so a previous file’s flags do not stick.

| Word | Effect |
|------|--------|
| `EMIT-NO-PAUSE` | Still a **window** app, but **no** “Press a key to exit” / `KEY DROP`. Use when the program keeps running until the user exits (menus, games, loops). |
| `EMIT-NO-WINDOW` | **Terminal / stdout** stand-alone (no App Output). Implies **no** auto pause. Run from Terminal (e.g. `EMIT_HEADLESS=1 ./NAME.app/Contents/MacOS/NAME`). Double-click will not show a useful console. |
| `EMIT-NO-WRAPPER` | **Power user.** Emits **LAST** with the stock `EMIT-WINDOW-APP` / `EMIT-APP` wraps only (no automatic pause message). Use only if you know what you are doing — e.g. sample GRAPHICS programs that set up color modes / `WINDOW` / `KEY` themselves (`IMAGEVIEW64`). |

`EMIT-NO-WINDOW` and `EMIT-NO-WRAPPER` together select a stock **console** pack of **LAST**.

## IMAGEVIEW64 / live GRAPHICS loops

Sample `IMAGEVIEW64.fth` already has `EMIT-NO-WRAPPER`. Press **EMIT** while the companion is **idle** (do not leave `IMAGEVIEW` running). A live graphics `KEY` loop holds evaluate; further EMIT/INCLUDE used to queue silently behind it. The companion now replies immediately with a busy error — Esc/Q in the graphics window (or Stop Forth) first.

## Examples

```forth
\ hello.fth — default emit is enough
: HELLO  ." Hello World!" CR ;
```

```forth
EMIT-NO-PAUSE
\ long-running window app; user quits from the UI
: GAME  ... ;
```

```forth
EMIT-NO-WINDOW
\ tool meant for Terminal stdout
: BATCH  ... ;
```

```forth
EMIT-NO-WRAPPER
\ you call WINDOW / KEY / bitmaps yourself — same idea as advanced samples
: MYAPP  ... ;
```
