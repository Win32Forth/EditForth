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
\ Left click centers on that point and zooms in. Middle click pans
\ there. Right click redraws. S writes mandel.raw in the working folder.
\ Q or Esc returns to the console. A key during the picture stops that pass.
\ Each sample is a 2 by 2 block. The loops cover half of G-PX and
\ G-PY so those blocks fill the window.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW MANGEN_MODULE [THEN]
[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

: MANGEN-CREDIT ( -- )
  CR ." MANGEN draws the Mandelbrot set (C. H. Ting, public domain)."
  CR ." Left click zooms in at the cursor. Middle pans. Right redraws."
  CR ." S saves mandel.raw. Q quits." CR
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
VARIABLE MB-STOP
VARIABLE MB-HIT
VARIABLE MB-MX
VARIABLE MB-MY
VARIABLE MB-MB
CREATE MB-RAW G-PX 2/ G-PY 2/ * ALLOT

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
  MB-RAW G-PX 2/ G-PY 2/ * R@ WRITE-FILE DROP
  R> CLOSE-FILE DROP
  CR ." Wrote mandel.raw" CR ;

\ Put pixel (x,y) at the window center. Step is one pixel.
: MB-CENTER ( x y -- )
  G-PY 2/ - S>D D>F MB-STEP F@ F* MB-Y0 F@ F+ MB-Y0 F!
  G-PX 2/ - S>D D>F MB-STEP F@ F* MB-X0 F@ F+ MB-X0 F! ;

: MB-ZOOM ( F: factor -- )
  MB-X0 F@ MB-STEP F@ G-PX 2/ S>D D>F F* F+
  MB-Y0 F@ MB-STEP F@ G-PY 2/ S>D D>F F* F+
  FROT
  MB-STEP F@ F* MB-STEP F!
  MB-STEP F@ G-PY 2/ S>D D>F F* F- MB-Y0 F!
  MB-STEP F@ G-PX 2/ S>D D>F F* F- MB-X0 F! ;

\ Latest sample. (APP-MOUSE) does not sleep; (APP-PUMP) sleeps 10 ms.
: MB-NOTE ( -- flag )
  (APP-MOUSE)
  DUP IF
    MB-MB !
    MB-MY !
    MB-MX !
    -1 MB-HIT !
    -1
  ELSE
    DROP 2DROP
    0
  THEN ;

: MB-UP ( -- )
  BEGIN
    PAUSE
    (APP-MOUSE) NIP NIP 0=
  UNTIL ;

: MB-DRAW ( -- )
  CLS
  0 0 AT ." Q quit  L-click zoom  M pan  R redraw  S save"
  0 MB-HIT !
  G-PY 2/ 0 DO
    MB-STOP @ MB-HIT @ OR IF LEAVE THEN
    G-PX 2/ 0 DO
      I 2* J 2* MB-COLOR
      DUP MB-RAW J G-PX 2/ * I + + C!
      I 2* J 2* ROT MB-DOT
      I 15 AND 0= IF
        MB-NOTE IF LEAVE THEN
      THEN
    LOOP
    MB-HIT @ IF LEAVE THEN
    PREFRESH
    KEY? IF LEAVE THEN
    PAUSE
    MB-NOTE IF LEAVE THEN
  LOOP
  PREFRESH ;

\ Left recenters and zooms in. Middle recenters. Right redraws.
: MB-ACT ( -- )
  BEGIN
    MB-HIT @
  WHILE
    0 MB-HIT !
    MB-UP
    MB-MB @ DUP 1 AND IF
      DROP
      MB-MX @ MB-MY @ MB-CENTER
      0.5e0 MB-ZOOM
    ELSE DUP 4 AND IF
      DROP
      MB-MX @ MB-MY @ MB-CENTER
    ELSE
      DROP
    THEN THEN
    MB-DRAW
  REPEAT ;

: MB-REDRAW ( -- )
  MB-DRAW
  MB-ACT ;

: MANGEN ( -- )
  DECIMAL
  MB-SETUP
  0 MB-STOP !
  S" EditForth MANGEN" APP-NAME
  WINDOW PIXEL-ON COLOR8
  MB-REDRAW
  BEGIN
    MB-STOP @ 0=
  WHILE
    MB-NOTE IF
      MB-ACT
    ELSE KEY? IF
      KEY
      DUP 27 = OVER [CHAR] Q = OR OVER [CHAR] q = OR IF
        DROP -1 MB-STOP !
      ELSE DUP [CHAR] S = OVER [CHAR] s = OR IF
        DROP MB-SAVE
      ELSE DROP THEN THEN
    ELSE
      PAUSE
    THEN THEN
  REPEAT
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO FLOATING ALSO GRAPHICS ALSO FORTH DEFINITIONS

MANGEN-CREDIT
CR .( Run:  MANGEN ) CR
