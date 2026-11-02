\ MANSHOW.fth — interactive Mandelbrot for EditForth
\
\ C. H. Ting, 21 Oct 1992. Tom Zimmer's TCOM viewer selected a VGA card
\ from the DOS command line and quit with BYE. This copy uses the
\ COLOR8 graphics window on EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/MANSHOW.fth
\   MANSHOW
\
\ Left click centers on that point and zooms in. Middle click pans
\ there. Right click redraws. + and - zoom about the window center.
\ Arrows pan. I and O change the iteration limit. R redraws.
\ L loads mandel.raw written by MANGEN. Q or Esc returns to the console.
\ Each sample is a 2 by 2 block. The loops cover half of G-PX and
\ G-PY so those blocks fill the window.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW MANSHOW_MODULE [THEN]
[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

: MANSHOW-CREDIT ( -- )
  CR ." MANSHOW draws the Mandelbrot set (C. H. Ting, public domain)."
  CR ." Left click zooms in at the cursor. Middle pans. Right redraws."
  CR ." + - zoom. Arrows pan. I O iterations. R redraw. L load. Q quits." CR
  ;

ONLY FORTH ALSO FLOATING ALSO GRAPHICS DEFINITIONS
DECIMAL

FVARIABLE MS-X0
FVARIABLE MS-Y0
FVARIABLE MS-STEP
FVARIABLE MS-ZR
FVARIABLE MS-ZI
FVARIABLE MS-CR
FVARIABLE MS-CI
VARIABLE MS-MAX
VARIABLE MS-N
VARIABLE MS-STOP
VARIABLE MS-HIT
VARIABLE MS-MX
VARIABLE MS-MY
VARIABLE MS-MB

: MS-HOME ( -- )
  -2.2e0 MS-X0 F!
  -1.15e0 MS-Y0 F!
  3.0e0 G-PX S>D D>F F/ MS-STEP F!
  40 MS-MAX ! ;

: MS-ITER ( -- n )
  0.0e0 MS-ZR F!
  0.0e0 MS-ZI F!
  0 MS-N !
  BEGIN
    MS-N @ MS-MAX @ <
  WHILE
    MS-ZR F@ FDUP F*
    MS-ZI F@ FDUP F*
    F+ 4.0e0 F> IF MS-N @ EXIT THEN
    MS-ZR F@ FDUP F*
    MS-ZI F@ FDUP F*
    F- MS-CR F@ F+
    MS-ZR F@ MS-ZI F@ F* 2.0e0 F* MS-CI F@ F+
    MS-ZI F!
    MS-ZR F!
    1 MS-N +!
  REPEAT
  MS-N @ ;

: MS-COLOR ( px py -- index )
  S>D D>F MS-STEP F@ F* MS-Y0 F@ F+ MS-CI F!
  S>D D>F MS-STEP F@ F* MS-X0 F@ F+ MS-CR F!
  MS-ITER
  DUP MS-MAX @ = IF DROP CBLACK ELSE 15 MOD 1+ THEN ;

: MS-DOT ( x y index -- )
  COLOR ! WHITE
  2DUP PLOT
  OVER 1+ OVER PLOT
  2DUP 1+ PLOT
  1+ SWAP 1+ SWAP PLOT ;

: MS-PAN ( dx dy -- )
  S>D D>F MS-STEP F@ F* 20.0e0 F* MS-Y0 F@ F+ MS-Y0 F!
  S>D D>F MS-STEP F@ F* 20.0e0 F* MS-X0 F@ F+ MS-X0 F! ;

: MS-ZOOM ( F: factor -- )
  MS-X0 F@ MS-STEP F@ G-PX 2/ S>D D>F F* F+
  MS-Y0 F@ MS-STEP F@ G-PY 2/ S>D D>F F* F+
  FROT
  MS-STEP F@ F* MS-STEP F!
  MS-STEP F@ G-PY 2/ S>D D>F F* F- MS-Y0 F!
  MS-STEP F@ G-PX 2/ S>D D>F F* F- MS-X0 F! ;

\ Put pixel (x,y) at the window center. Step is one pixel.
: MS-CENTER ( x y -- )
  G-PY 2/ - S>D D>F MS-STEP F@ F* MS-Y0 F@ F+ MS-Y0 F!
  G-PX 2/ - S>D D>F MS-STEP F@ F* MS-X0 F@ F+ MS-X0 F! ;

\ Latest sample. (APP-MOUSE) does not sleep; (APP-PUMP) sleeps 10 ms.
: MS-NOTE ( -- flag )
  (APP-MOUSE)
  DUP IF
    MS-MB !
    MS-MY !
    MS-MX !
    -1 MS-HIT !
    -1
  ELSE
    DROP 2DROP
    0
  THEN ;

: MS-UP ( -- )
  BEGIN
    PAUSE
    (APP-MOUSE) NIP NIP 0=
  UNTIL ;

: MS-DRAW ( -- )
  CLS
  0 0 AT ." Q quit  L-click zoom  M pan  R redraw  +- zoom  arrows  I O  L load"
  0 MS-HIT !
  G-PY 2/ 0 DO
    MS-STOP @ MS-HIT @ OR IF LEAVE THEN
    G-PX 2/ 0 DO
      I 2* J 2* MS-COLOR
      I 2* J 2* ROT MS-DOT
      I 15 AND 0= IF
        MS-NOTE IF LEAVE THEN
      THEN
    LOOP
    MS-HIT @ IF LEAVE THEN
    PREFRESH
    KEY? IF
      KEY 27 = IF -1 MS-STOP ! THEN
      LEAVE
    THEN
    PAUSE
    MS-NOTE IF LEAVE THEN
  LOOP
  PREFRESH ;

\ Left recenters and zooms in. Middle recenters. Right redraws.
: MS-ACT ( -- )
  BEGIN
    MS-HIT @
  WHILE
    0 MS-HIT !
    MS-UP
    MS-MB @ DUP 1 AND IF
      DROP
      MS-MX @ MS-MY @ MS-CENTER
      0.5e0 MS-ZOOM
    ELSE DUP 4 AND IF
      DROP
      MS-MX @ MS-MY @ MS-CENTER
    ELSE
      DROP
    THEN THEN
    MS-DRAW
  REPEAT ;

: MS-REDRAW ( -- )
  MS-DRAW
  MS-ACT ;

: MS-LOAD ( -- )
  S" mandel.raw" R/O BIN OPEN-FILE IF DROP EXIT THEN
  >R
  G-PY 2/ 0 DO
    G-PX 2/ 0 DO
      PAD 1 R@ READ-FILE IF DROP LEAVE THEN
      DUP 0= IF DROP LEAVE THEN
      DROP PAD C@
      I 2* J 2* ROT MS-DOT
    LOOP
  LOOP
  R> CLOSE-FILE DROP
  PREFRESH ;

: MANSHOW ( -- )
  DECIMAL
  MS-HOME
  0 MS-STOP !
  S" EditForth MANSHOW" APP-NAME
  WINDOW PIXEL-ON COLOR8
  MS-REDRAW
  BEGIN
    MS-STOP @ 0=
  WHILE
    MS-NOTE IF
      MS-ACT
    ELSE KEY? IF
      KEY
      DUP 27 = OVER [CHAR] Q = OR OVER [CHAR] q = OR IF
        DROP -1 MS-STOP !
      ELSE DUP 200 = IF DROP 0 1 MS-PAN MS-REDRAW
      ELSE DUP 208 = IF DROP 0 -1 MS-PAN MS-REDRAW
      ELSE DUP 203 = IF DROP -1 0 MS-PAN MS-REDRAW
      ELSE DUP 205 = IF DROP 1 0 MS-PAN MS-REDRAW
      ELSE DUP [CHAR] + = IF DROP 0.5e0 MS-ZOOM MS-REDRAW
      ELSE DUP [CHAR] - = IF DROP 2.0e0 MS-ZOOM MS-REDRAW
      ELSE DUP [CHAR] I = OVER [CHAR] i = OR IF
        DROP MS-MAX @ 2* 256 MIN MS-MAX ! MS-REDRAW
      ELSE DUP [CHAR] O = OVER [CHAR] o = OR IF
        DROP MS-MAX @ 2/ 8 MAX MS-MAX ! MS-REDRAW
      ELSE DUP [CHAR] R = OVER [CHAR] r = OR IF DROP MS-REDRAW
      ELSE DUP [CHAR] L = OVER [CHAR] l = OR IF DROP MS-LOAD
      ELSE DROP THEN THEN THEN THEN THEN THEN THEN THEN THEN THEN THEN
    ELSE
      PAUSE
    THEN THEN
  REPEAT
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO FLOATING ALSO GRAPHICS ALSO FORTH DEFINITIONS

MANSHOW-CREDIT
CR .( Run:  MANSHOW ) CR
