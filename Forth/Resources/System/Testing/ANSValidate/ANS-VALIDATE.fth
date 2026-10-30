\ ANS-VALIDATE.fth — 64Forth Library validation driver (pure Forth)
\
\ Port of TZForth ANS-VALIDATE / FTEST spot-checks, one word set at a time.
\ Not a formal ANS certificate. Hayes stock suites stay under HayesTest/.
\
\ Canonical run - same pattern as HayesTest (bundle Resources/Library):
\   FROMLIB FLOAD Testing/ANSValidate/ANS-VALIDATE.fth
\
\ Named FLOAD/INCLUDE chdirs to this file's folder - ANSValidate/ - for the
\ duration of its SOURCE, then returns. Modules live in src/, so each load is
\ FLOAD src/<module>.fth from this folder.
\
\ Modules - load order:
\   1) tester.fth     harness
\   2) core.fth       Core
\   3) core-ext.fth   Core Ext
\   4) search.fth     Search-Order
\   5) string.fth     String
\   6) facility.fth   Facility structures
\   7) exception.fth  Exception CATCH/THROW
\   8) memory.fth     Memory-Allocation
\   9) double.fth     Double-Number
\  10) locals.fth     Locals
\  11) tools.fth      Programming-Tools
\  12) file.fth       File-Access
\  13) block.fth      Block
\  14) xchar.fth      Extended Character
\  15) float.fth      Float Tier A/B
\  16) host.fth       TZForth FTEST high-ROI port wave (FIND, POSTPONE, …)
\
\ CRITICAL: no interpret-time IF/ELSE/THEN/BEGIN.
\ CRITICAL: .( stops at first ) — no nested parentheses in messages.

DECIMAL
ONLY FORTH DEFINITIONS

CR .( === 64Forth ANS-VALIDATE ===) CR
CR .( Library Forth - not a formal ANS certificate.) CR
CR .( Modules: tester, core, core-ext, search, string, facility, exception, memory, double, locals, tools, file, block, xchar, float, host ) CR

\ Relative to this file's directory. Modules are in src/.
\ FILE-ECHO ON
FLOAD src/tester.fth
FLOAD src/core.fth
FLOAD src/core-ext.fth
FLOAD src/search.fth
FLOAD src/string.fth
FLOAD src/facility.fth
FLOAD src/exception.fth
FLOAD src/memory.fth
FLOAD src/double.fth
FLOAD src/locals.fth
FLOAD src/tools.fth
FLOAD src/file.fth
FLOAD src/block.fth
FLOAD src/xchar.fth
FLOAD src/float.fth
FLOAD src/host.fth

S" ANS-VALIDATE" .TEST-SUMMARY
.( === ANS-VALIDATE driver done ===) .STACK-DEPTH CR
\ Leave a clean data stack for subsequent work (e.g. Hayes).
EMPTY-DATA
