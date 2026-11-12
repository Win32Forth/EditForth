64Forth Library — sources under 64Forth/Resources/Library/

Build (TZForth-style Run Script "Copy Library") wipes and re-copies this
folder into the app bundle as Contents/Resources/Library/ on every build
so FROMLIB never sees a stale tree. Docs is copied the same way.
AutoLoad ships inside System (Copy System).

Library/TCOM was removed in 2.6.2. Programs from that folder that run
on EditForth are in Sample. ZTREE needs the host shell.

FROMLIB resolves relative paths under the bundle Library. Assembler,
Debugger, Emitter, Hyper, Reference, Sources, and Testing live in the
sibling System folder. FROMLIB still finds those names there
(FROMLIB FLOAD Emitter/emitter.fth, FROMLIB FLOAD Testing/…). A path
written as System/Debugger/… is relative to Documents/EditForth.

Examples
--------
  FROMLIB FLOAD Testing/HayesTest/HayesTest.fth
  FROMLIB FLOAD Testing/ANSValidate/ANS-VALIDATE.fth
  FROMLIB FLOAD Testing/DbgSpanSmoke/span-tests.fth
  FROMLIB FLOAD BigInteger/big-int.fth
  FROMLIB FLOAD FixPoint/FIXEDPOINT.fth    \ ALSO FIXED-POINT
  \ FixPoint is introductory and incomplete. XBITS defaults to 28.
  \ XUNIT, F>X, X>F, and X* are in. + and - are the cell words.
  \ Division, square root, and trig are not in this slice.
  FROMLIB FLOAD PI/pi-test.fth
  FROMLIB FLOAD xchar-smoke.fth
  FROMLIB FLOAD Debugger/debugger.fth  \ DEBUG hub + loads Debugger/* (AutoLoad)
  FROMLIB FLOAD Assembler/asmarm64.fth     \ AArch64 host toolkit (not used by TCOM)
  FROMLIB FLOAD Assembler/ASSEMBLER.fth    \ interactive CODE / END-CODE (64Forth only)
  FROMLIB FLOAD Assembler/ASMARMTESTS.fth \ then: ASM-TESTS
  FROMLIB FLOAD Emitter/emitter.fth        \ turnkey slicer (IN PROGRESS)
  \ Stand-alone app kit base = GRAPHICS (see Docs/APPKIT.md); first emit target: tetra
  FROMLIB FLOAD Pascal/PASCAL.fth          \ Tiny Pascal → Forth translator
  FROMLIB S" Pascal/PASY.PAS" PASCAL-TO-FILE   \ then INCLUDED + DEMO
  FROMLIB FLOAD Sample/DOODLE64.fth        \ then: DOODLE (1-bit mouse demo)
  FROMLIB FLOAD Sample/DOODLECOLOR64.fth   \ then: DOODLECOLOR (COLOR8 + color bar)
  FROMLIB FLOAD Sample/RINGS.fth           \ then: RINGS (random COLOR8 rings; any key stops)
  FROMLIB FLOAD Sample/KOKO.fth            \ then: KOKO (COLOR8 fractal; any key stops)
  FROMLIB FLOAD Sample/MANGEN.fth          \ then: MANGEN (COLOR8 Mandelbrot; S writes mandel.raw)
  FROMLIB FLOAD Sample/MANSHOW.fth         \ then: MANSHOW (pan and zoom mandel.raw)
  FROMLIB FLOAD Sample/MANSHOW-COOP.fth    \ then: MANSHOW-COOP (four cooperative tasks)
  FROMLIB FLOAD Sample/MANSHOW-CORE.fth    \ then: MANSHOW-CORE (four worker cores)
  FROMLIB FLOAD Sample/OBJECT.fth          \ then: OBJECT-DEMO (vehicles and automobiles)
  FROMLIB FLOAD Sample/SPREAD.fth          \ then: SPREAD (26x26 sheet; Esc quits)
  FROMLIB FLOAD Sample/SZ.fth              \ then: SZ (graphics editor; Esc opens the menu)
  FROMLIB FLOAD Sample/LEDIT.fth           \ then: LEDIT (one-line editor)
  FROMLIB FLOAD Sample/ZLIST.fth           \ then: ZLIST (list a file; skip lines that start with %)
  FROMLIB FLOAD Sample/LOOK.fth            \ then: LOOK (find a string; a blank line finishes)
  FROMLIB FLOAD Sample/GLOBAL.fth          \ then: GLOBAL (replace text in one file)
  FROMLIB FLOAD Sample/ZIM.fth             \ then: ZIM or ZIM-EXPAND
  FROMLIB FLOAD Sample/ALLSPECS.fth        \ then: ALLSPECS (collect file names)
  \ Sample/LOOK.txt                        \ notes for LOOK (not a Forth program)
  FROMLIB FLOAD Sample/BANNER.fth          \ then: BANNER-DEMO (big text; any key stops)
  FROMLIB FLOAD Sample/COMPLEX.fth         \ then: COMPLEX-DEMO (complex arithmetic)
  FROMLIB FLOAD Sample/FPMATH.fth          \ then: FPMATH (square root, log, exp, arctan, sine)
  FROMLIB FLOAD Sample/FILTER.fth          \ then: FILTER (copy a file and tidy control characters)
  FROMLIB FLOAD Sample/CARD.fth            \ then: CARD (16-line card file)
  FROMLIB FLOAD Sample/TEXTFORM.fth        \ then: TEXTFORM (dot commands, writes name.prn)
  FROMLIB FLOAD Sample/ZTREE.fth           \ then: ZTREE (directory sizes; EditForth only, needs the shell)
  FROMLIB FLOAD Sample/SWINDOW.fth         \ then: SWINDOW (message box; a key returns)
  FROMLIB FLOAD Sample/LINES.fth           \ then: LINES (random lines; any key stops)
  FROMLIB FLOAD Sample/LINEWALK.fth        \ then: LINEWALK (a bouncing line; any key stops)
  FROMLIB FLOAD Sample/LINESCAN.fth        \ then: LINESCAN (crawling lines; + and - change the count)
  FROMLIB FLOAD Sample/GSS.fth             \ then: GSS (growing squares; any key stops)
  FROMLIB FLOAD Sample/SPLAT.fth           \ then: SPLAT (wandering dots; Esc stops if no password)
  FROMLIB FLOAD Sample/DRAW.fth            \ then: DRAW (mouse sketch; Esc returns)
  FROMLIB FLOAD Sample/ICON.fth            \ then: ICON (40x40 color icon; Esc returns)
  FROMLIB FLOAD Sample/SSBLIT.fth          \ then: SSBLIT (logo and a moving Z; any key stops)
  FROMLIB FLOAD Sample/IMAGEVIEW64.fth     \ then: IMAGEVIEW (TRUECOLOR open/zoom)
  FROMLIB FLOAD Sample/EDIT64.fth          \ then: EDIT64 (GRAPHICS mini-editor; EMITable)
  \ REF / XREF / USEDIN / CALLS / ANYWORDS — cold-loaded (Kernel/xref.fth .incbin)
  \   REF DUP          \ colon/DEFER refs; Space=pause Esc/Q=stop; title shows leaf:line
  \   ANYWORDS OVER    \ WORDS-like across FORTH + named VOCABULARYs (optional filter)
  \   (Library/TCOM was removed in 2.6.2. Do not FLOAD Sample/XREF.)

Assembler (ASMARM64)
--------------------
  Full source: System/Assembler/asmarm64.fth
  Interactive: System/Assembler/ASSEMBLER.fth  →  CODE / END-CODE / C; / NEXT,
               (64Forth ITC only; not loaded by 64TCOM; does not redefine ASSEMBLER)
  Tests:       System/Assembler/ASMARMTESTS.fth  →  ASM-TESTS
  Twin copies: Documents/64TCOM/64TCOMARM64/ASMARM64.fth + ASMARMTESTS.fth
  Last synced: Aug 23, 2026 3:16 PM (see header stamp in both .fth files)
  TCOM loads only the pack assembler via TARGETARM64.
  Monitor: Docs/STATUSASM64.md (twin of 64TCOM/STATUSASM64.md)
  After load: .ASMARM64  ASM-TESTS  ASMARM64-DISCARD
  CODE words:  FROMLIB FLOAD Assembler/ASSEMBLER.fth  then  CODE name … END-CODE

Emitter (IN PROGRESS)
---------------------
  Experimental space-optimizing / turnkey slicer toward stand-alone apps.
  Load:   FROMLIB FLOAD Emitter/emitter.fth
  Pieces: reach.fth (reachable xts), target.fth (target image),
          reloc.fth (PC-rel retarget / veneers), run.fth (trampoline + CALL-NATIVE)
  Kernel CODE words carry _END labels so primitive sizes can be measured for copy.
  Not finished — do not treat as a shipping compiler yet.
  Status: Docs/STATUS.md § v1.3.4

Pascal (Tiny Pascal → Forth)
----------------------------
  Load:    FROMLIB FLOAD Pascal/PASCAL.fth
  Words:   PASCAL"  PASCAL  PASCAL-TO-FILE   (.pas only; FROMLIB via PAS-RESOLVE)
  Samples: PASY.PAS / PASY-SAMPLE.fth (clear demo), PASX.PAS / PASX-SAMPLE.fth
  Docs:    Library/Pascal/README.txt

User data (Documents/64Forth)
-----------------------------
  First launch copies Library / AutoLoad / Docs into Documents/64Forth.
  FROMLIB prefers that tree. Tools menu: Update User Data / Restore Shipped Files.

After editing Library .fth files, rebuild/run so the bundle copy updates
(or use Tools → Update / Restore for the Documents/64Forth tree).

See Testing/ANSValidate/src/README.txt, Editor/SZ-EDITOR-README.txt,
Pascal/README.txt, and Docs/README.txt.
