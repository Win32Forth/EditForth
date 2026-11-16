# ANS THROW Codes — 64Forth Exception Model

This document describes how **64Forth** implements the ANS Forth 2012 Exception
word set (`CATCH` / `THROW` / `ABORT` / `ABORT"`) and how that relates to the
standard throw-code table (§9.3.1).

It is **not** the old TZForth `kernelThrow` / `errorFlag` migration plan.
64Forth is a hybrid **ARM64 ITC kernel** (`forth.s`) + **Swift host**;
exceptions live in the kernel, not in a Swift `errorFlag` path.

**Reference:**
[ANS THROW](https://forth-standard.org/standard/exception/THROW), Forth-2012
§9.3.1–§9.3.5.

**Last update:** 2026-07-30 (64Forth v0.9.0).

---

## Model overview

- **`CATCH` / `THROW`** — Where: Kernel CODE (`XCATCH` / `XTHROW`);
  CATCH-able?: **Yes** when a frame is active; Typical recovery: Restore
  IP/DSP/TOS from frame; leave code on data stack
- **Uncaught `THROW`** — Where: Kernel `_throw_abort`; CATCH-able?: N/A;
  Typical recovery: Print `uncaught THROW n`, clear stacks / CATCH nesting,
  abandon rest of SOURCE
- **Soft system faults** — Where: Kernel messages + `_error_abandon`;
  CATCH-able?: **Only if** the site uses `THROW` (see table below); Typical
  recovery: Print message (e.g. `undefined: name`, `stack underflow`), pin
  `>IN` to end of SOURCE, continue outer interpret
- **Host file I/O** — Where: Swift `FileAccess`; CATCH-able?: Usually **ior**
  on stack (ANS File-Access), not THROW; Typical recovery: Caller checks `ior`

### `CATCH` frame (implementation)

Return-stack frame (top first): **saved IP**, **saved DSP**, **saved TOS**,
**previous handler**. Handler pointer lives in `throw_handler`.

- Success: `(CATCH-OK)` restores the frame and pushes **0**.
- `0 THROW` is a no-op (drops 0).
- Nonzero `THROW` restores the frame and leaves the throw code as TOS.

---

## Standard throw codes (ANS §9.3.1)

| Code | Condition |
|------|-----------|
| -1 | `ABORT` |
| -2 | `ABORT"` |
| -3 | Stack underflow |
| -4 | Stack overflow |
| -5 | Return stack underflow |
| -6 | Return stack overflow |
| -7 | Invalid memory address |
| -8 | Double-cell number expected |
| -9 | Division by zero |
| -10 | Attempt to use zero-length string as a name |
| -11 | Attempt to use zero-length buffer as a name |
| -12 | Address not aligned |
| -13 | Undefined word |
| -14 | Interpreting a compile-only word |
| -15 | Uncompleted IF / DO / CASE |
| -16 | Attempt to use non-existent execution token |
| -17 | Nesting limit exceeded |
| -18–19 | *(reserved by standard)* |
| -20–21 | Search-order / related (optional) |
| -22–39 | *(reserved by standard)* |
| -40 | First of **user** throw range |
| -60–65 | Floating-point word set |
| -66–75 | File-access / block word sets |

User applications may `THROW` any nonzero value; codes ≤ -40 are conventionally
for application-defined faults.

---

## What 64Forth maps today

### Explicit `THROW` sites (CATCH-able)

- **`ABORT`** — Code: **-1**; Notes: High-level: `-1 THROW`
- **`ABORT"`** — Code: **-2**; Notes: Nonzero flag: type message, then
  `-2 THROW`. Compile path: `IF S" … TYPE CR -2 LITERAL THROW THEN` (v0.8.1:
  must `POSTPONE LITERAL` for -2 so IF/THEN is not corrupted)
- **Undefined word** (text interpreter, `'`, `[']` interpret) — Code: **-13**;
  Notes: If `throw_handler` nonzero → `THROW -13`; else print `undefined: name`
  and abandon SOURCE
- **`?COMP`** (compile-only in interpret) — Code: **-14**; Notes: High-level:
  type `compile only`, then `-14 THROW`
- **Application `THROW n`** — Code: *n*; Notes: Any nonzero *n*

### Soft faults (message + abandon; not standard THROW unless noted)

These clear compile state and pin `>IN` to end of the current SOURCE
(`_error_abandon`). They do **not** walk a `CATCH` frame unless the site was
changed to `THROW`.

- Data stack under/overflow (`_check_stack`) — Uncaught behaviour: Print
  `stack underflow` / `stack overflow`, reset DSP; Future CATCH mapping: -3 / -4
- Memory fault (SIGSEGV/SIGBUS recovery) — Uncaught behaviour: Print
  `memory access error`, reset stacks; Future CATCH mapping: -7
- `ALLOT` past dictionary limits — Uncaught behaviour: Print allot error,
  abandon; Future CATCH mapping: -8-ish / implementation
- `GROWMEMORYMB` rule violations — Uncaught behaviour: Print `? GROWMEMORYMB…`,
  abandon; Future CATCH mapping: -20 (implementation)
- Dictionary full on compile — Uncaught behaviour: Print `dictionary full`,
  abandon; Future CATCH mapping: -8 / -17
- `INCLUDE`/`FLOAD` open failure — Uncaught behaviour: Print
  `can't open: path`, return (nested load does not kill parent SOURCE); Future
  CATCH mapping: -74 if raised via THROW
- File words (`OPEN-FILE`, …) — Uncaught behaviour: **`ior` on stack** (0 =
  ok); Future CATCH mapping: Keep ANS ior model

### Division by zero

`/` and related CODE use ARM `sdiv` with no pre-check. Hardware/undefined
behaviour is **not** converted to `-9 THROW` today. Prefer application checks
or a future trap mapping.

### Floating-point

FP stack under/overflow is handled in the Swift host (`FloatHost`) and is
**not** currently mapped to ANS float codes -60–-65. No automatic `THROW` from
FP ops.

---

## Uncaught vs caught UX

- `CATCH` absorbs `THROW` — Only the numeric code on the stack; **no** standard
  message
- Uncaught `THROW n` — `uncaught THROW` + absolute value of *n*, then rest of
  line abandoned
- Uncaught undefined (no CATCH) — `undefined: name`, rest of SOURCE abandoned
- Uncaught stack under/overflow — `stack underflow` / `stack overflow`, DSP
  reset, SOURCE abandoned

**REPL tip:** wrap risky interpretation:

```forth
: try  ( c-addr u -- n )  ['] EVALUATE CATCH ;
S" no-such-word" try .     \ -13 when CATCH path is used
```

Typing a missing word alone at the prompt is **uncaught** → `undefined: …` (not
a silent fail).

---

## Hayes / exception tests

`FROMLIB FLOAD HayesTest/HayesTest.fth` runs `exceptiontest.fth`, which assumes:

| Expectation | 64Forth |
|-------------|---------|
| `ABORT` → CATCH code **-1** | Yes (`-1 THROW`) |
| `ABORT"` → CATCH code **-2** | Yes (`-2 THROW`) |
| Undefined via nested `EVALUATE` → **-13** | Yes when CATCH is active |

Driver: `Resources/Library/HayesTest/`; expect `EERRORS @ = 0` in the summary.

---

## Gaps / optional future work

1. Map data-stack under/overflow to **-3** / **-4** when a CATCH frame is
   active (still print message when uncaught).
2. Map division-by-zero to **-9** (check before `sdiv` or trap).
3. Map memory faults to **-7** via THROW when CATCH active.
4. Map float stack faults to **-3/-4** or ANS **-60–-65** if desired.
5. Optional **`.ERROR` ( n -- )** helper for spaced standard messages after
   `CATCH` (not required by ANS; useful for apps).

None of these are required for the current Hayes exception subset green on
64Forth v0.8.

---

## Implementation map (kernel)

| Piece | Location |
|-------|----------|
| `CATCH` / `(CATCH-OK)` / `THROW` | `forth.s` `XCATCH`, `XCATCH_OK`, `XTHROW` |
| Uncaught THROW soft path | `_throw_abort` → message + `_error_abandon` |
| Undefined word | `_undefined_word` (-13 if handler, else print + abandon) |
| Compile-only | High-level `?COMP` → `-14 THROW` |
| `ABORT` / `ABORT"` | `forth_init_str` colon definitions |
| Soft abandon | `_error_abandon` |
| Handler cell | `throw_handler` |

---

## Related docs

- **ANS_COMPLIANCE.md** — word-set status (Core / Core Ext detailed for v0.8).
- **Hayes:** `Resources/Library/HayesTest/` — driver + stock suite; baseline
  `src/HAYES-RESULTS.txt`.

For full standard wording, see the official Forth-2012 document, Exception word
set (§9).
