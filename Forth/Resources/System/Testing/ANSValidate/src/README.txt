64Forth ANS-VALIDATE (Library, pure Forth)
==========================================

Purpose
-------
Port of TZForth ANS-VALIDATE / FTEST spot-checks into pure Forth, one word
set at a time. Not a formal ANS certificate. Hayes stays under HayesTest/.

See PORT-PLAN.txt for the full module roadmap.

Canonical run
-------------
  FROMLIB FLOAD Testing/ANSValidate/ANS-VALIDATE.fth

  FROMLIB resolves Testing under System (Documents/EditForth/System/Testing,
  or the bundled System copy). The driver stays in ANSValidate/. Modules
  live in src/. Named FLOAD chdirs into the file being loaded, then returns,
  so each module is loaded as FLOAD src/<name>.fth from the driver folder.

Expected
--------
  ANS-VALIDATE: N passed, 0 failed.
  ALL PASS
  === ANS-VALIDATE driver done ===

  Approximate count after host.fth (v0.8.2): mid-370s EXPECT cases.
  TZForth FTEST logs ~427 including Swift host-only checks — not a 1:1 goal.

Current modules - driver load order
-----------------------------------
  tester.fth     PASS/FAIL harness - EXPECT #PASS #FAIL
  core.fth       Core batch 1 - TZForth TEST6 arithmetic..control
  core-ext.fth   Core Ext - VALUE TO DEFER CASE COMPILE, BUFFER: …
  search.fth     Search-Order - WORDLIST ALSO ONLY VOCABULARY …
  string.fth     String - COMPARE SEARCH /STRING CMOVE …
  facility.fth   Facility + Facility Ext - structures, MS, K-*/EKEY>FKEY
  exception.fth  Exception - CATCH THROW
  memory.fth     Memory-Allocation - ALLOCATE FREE RESIZE
  double.fth     Double-Number - D+ D- D= 2VALUE …
  locals.fth     Locals - LOCALS| {: TO
  tools.fth      Programming-Tools - NAME>STRING AHEAD N>R …
  file.fth       File-Access - CREATE/OPEN/READ/WRITE under /tmp
  block.fth      Block - /tmp .blk volume, LOAD
  xchar.fth      Extended Character UTF-8
  float.fth      Float Tier A/B - ALSO FLOATING vocabulary
  host.fth       High-ROI TZForth FTEST ports (FIND, POSTPONE, SLITERAL,
                 MARKER, 2!/2@, SIGN, REQUIRED/INCLUDED, EMIT?/EKEY?,
                 double literals, {:} order, FALIGNED/FATAN2/FLITERAL,
                 GD8 +LOOP, compile ABORT")

Standalone XChar only
---------------------
  FROMLIB FLOAD Testing/ANSValidate/src/all-in-one.fth

CRITICAL 64Forth rules
----------------------
  - No IF/ELSE/THEN/BEGIN while interpreting - only inside colon defs
  - .( stops at the first ) - no nested parentheses in messages

Layout
------
  ANS-VALIDATE.fth          multi-module driver - FROMLIB entry point
  ANS-VALIDATE-RESULTS.txt  last green log
  src/PORT-PLAN.txt         word-set port order
  src/tester.fth            harness
  src/core.fth … src/float.fth  word-set modules
  src/host.fth              extra FTEST port wave (see above)
  src/all-in-one.fth        self-contained XChar suite
  src/run-from-disk.fth     alias → FROMLIB FLOAD Testing/ANSValidate/ANS-VALIDATE.fth
  src/probe src/bisect src/hello   diagnostics
