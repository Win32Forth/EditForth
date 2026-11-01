\ MANGEN.fth — Mandelbrot for the EditForth graphics window
\
\ C. H. Ting, 21 Oct 1992. The TCOM program drove VGA dots from x86
\ code and left through BYE. This copy plots COLOR8 pixels and can
\ write mandel.raw for MANSHOW.
\
\ Load:
\   FROMLIB FLOAD Sample/MANGEN.fth
\   MANGEN
\
\ Any key stops the drawing and returns to the console.
\ S after a finished picture writes mandel.raw in the working folder.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW MANGEN_MODULE [THEN]
[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

: MANGEN-CREDIT ( -- )
  CR ." MANGEN draws the Mandelbrot set (C. H. Ting, public domain)."
  CR ." Any key stops and returns to the console." CR
  ;

ONLY FORTH ALSO FLOATING ALSO GRAPHICS DEFINITIONS
DECIMAL

FVARIABLE MB-X0
FVARIABLE MB-Y0
FVARIABLE MB-STEP
FVARIABLE MB-ZR
FVARIABLE MB-ZI
FVARIABLE MB-CR
FVARIABLE MB-CI
VARIABLE MB-MAX
VARIABLE MB-N
VARIABLE MB-DX
CREATE MB-RAW 160 100 * ALLOT

: MB-SETUP ( -- )
  -2.2e0 MB-X0 F!
  -1.15e0 MB-Y0 F!
  3.0e0 G-PX S>D D>F F/ MB-STEP F!
  48 MB-MAX !
  2 MB-DX ! ;

: MB-ITER ( -- n )
  0.0e0 MB-ZR F!
  0.0e0 MB-ZI F!
  0 MB-N !
  BEGIN
    MB-N @ MB-MAX @ <
  WHILE
    MB-ZR F@ FDUP F*
    MB-ZI F@ FDUP F*
    F+ 4.0e0 F> IF MB-N @ EXIT THEN
    MB-ZR F@ FDUP F*
    MB-ZI F@ FDUP F*
    F- MB-CR F@ F+
    MB-ZR F@ MB-ZI F@ F* 2.0e0 F* MB-CI F@ F+
    MB-ZI F!
    MB-ZR F!
    1 MB-N +!
  REPEAT
  MB-N @ ;

: MB-COLOR ( px py -- index )
  S>D D>F MB-STEP F@ F* MB-Y0 F@ F+ MB-CI F!
  S>D D>F MB-STEP F@ F* MB-X0 F@ F+ MB-CR F!
  MB-ITER
  DUP MB-MAX @ = IF DROP CBLACK ELSE 15 MOD 1+ THEN ;

: MB-DOT ( x y index -- )
  COLOR !
  WHITE
  2DUP PLOT
  OVER 1+ OVER PLOT
  2DUP 1+ PLOT
  1+ SWAP 1+ SWAP PLOT ;

: MB-SAVE ( -- )
  S" mandel.raw" W/O BIN CREATE-FILE IF
    DROP CR ." Could not write mandel.raw" CR EXIT
  THEN
  >R
  MB-RAW 160 100 * R@ WRITE-FILE DROP
  R> CLOSE-FILE DROP
  CR ." Wrote mandel.raw" CR ;

: MANGEN ( -- )
  DECIMAL
  MB-SETUP
  S" EditForth MANGEN" APP-NAME
  WINDOW PIXEL-ON COLOR8
  WHITE
  100 0 DO
    160 0 DO
      I 2* J 2* MB-COLOR
      DUP MB-RAW J 160 * I + + C!
      I 2* J 2* ROT MB-DOT
    LOOP
    PREFRESH
    KEY? IF LEAVE THEN
    PAUSE
  LOOP
  PREFRESH
  KEY
  DUP [CHAR] S = OVER [CHAR] s = OR IF MB-SAVE THEN
  DROP
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO FLOATING ALSO GRAPHICS ALSO FORTH DEFINITIONS

MANGEN-CREDIT
CR .( Run:  MANGEN ) CR
