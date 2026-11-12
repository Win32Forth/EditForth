\ MANSHOW-CORE.fth — Mandelbrot on four worker cores
\
\ Same window as MANSHOW. Left click zooms in at the cursor. Middle
\ click pans. Right click redraws. + and - zoom about the center.
\ Arrows pan. I and O change the iteration limit. R redraws.
\ Q or Esc returns to the console.
\
\ The view stays in FLOATING on the console. Each frame converts the
\ origin and the step with F>X. CORES then places one task on each of
\ 64Forth.core.0 through 64Forth.core.3. The tasks fill four row bands
\ with X* from Library/FixPoint and do not PAUSE inside a band. The
\ console stays on 64Forth.kernel. COOP runs on the way out.
\
\ Load:
\   FROMLIB FLOAD Sample/MANSHOW-CORE.fth
\   MANSHOW-CORE
\
\ Public domain. The picture is the Mandelbrot set (C. H. Ting, 1992).

[DEFINED] ANEW [IF] ANEW MANSHOW-CORE-MODULE [THEN]
[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]

[DEFINED] FIXED-POINT 0= [IF]
  FROMLIB FLOAD FixPoint/FIXEDPOINT.fth
[THEN]

ONLY FORTH DEFINITIONS
DECIMAL

: CE-CREDIT ( -- )
  CR ." MANSHOW-CORE draws the Mandelbrot set on four worker cores."
  CR ." The view is floating point. The pixels use FixPoint X*."
  CR ." Left click zooms in. Middle pans. Right redraws."
  CR ." + - zoom. Arrows pan. I O iterations. R redraws. Q quits." CR
  ;

ONLY FORTH DEFINITIONS
ALSO FLOATING
ALSO GRAPHICS
ALSO FIXED-POINT
DECIMAL

FVARIABLE CE-X0
FVARIABLE CE-Y0
FVARIABLE CE-STEP
VARIABLE CE-MAX
VARIABLE CE-STOP
VARIABLE CE-HIT
VARIABLE CE-MX
VARIABLE CE-MY
VARIABLE CE-MB
VARIABLE CE-MS
VARIABLE CE-QX
VARIABLE CE-QY
VARIABLE CE-QS
VARIABLE CE-ABORT
VARIABLE CE-GW
VARIABLE CE-GH
VARIABLE CE-DONE0
VARIABLE CE-DONE1
VARIABLE CE-DONE2
VARIABLE CE-DONE3
VARIABLE CE-Y0A
VARIABLE CE-Y1A
VARIABLE CE-Y0B
VARIABLE CE-Y1B
VARIABLE CE-Y0C
VARIABLE CE-Y1C
VARIABLE CE-Y0D
VARIABLE CE-Y1D

: CE-ZR ( -- addr ) PAD ;
: CE-ZI ( -- addr ) PAD CELL+ ;
: CE-CR ( -- addr ) PAD 2 CELLS + ;
: CE-CI ( -- addr ) PAD 3 CELLS + ;
: CE-ZN ( -- addr ) PAD 4 CELLS + ;

: CE-HOME ( -- )
  -2.2e0 CE-X0 F!
  -1.15e0 CE-Y0 F!
  3.0e0 G-PX S>D D>F F/ CE-STEP F!
  40 CE-MAX ! ;

: CE-VIEW>Q ( -- )
  CE-X0 F@ F>X CE-QX !
  CE-Y0 F@ F>X CE-QY !
  CE-STEP F@ F>X CE-QS ! ;

: CE-ITER ( cr ci -- n )
  CE-CI ! CE-CR !
  0 CE-ZR !  0 CE-ZI !  0 CE-ZN !
  BEGIN
    CE-ZN @ CE-MAX @ <
  WHILE
    CE-ZR @ DUP X*
    CE-ZI @ DUP X* +
    XUNIT 2 LSHIFT >
    IF CE-ZN @ EXIT THEN
    CE-ZR @ CE-ZI @ X* 2* CE-CI @ +
    CE-ZR @ DUP X* CE-ZI @ DUP X* - CE-CR @ +
    CE-ZR ! CE-ZI !
    1 CE-ZN +!
  REPEAT
  CE-ZN @ ;

: CE-COLOR ( sx sy -- index )
  2* CE-QS @ * CE-QY @ + >R
  2* CE-QS @ * CE-QX @ + R>
  CE-ITER
  DUP CE-MAX @ = IF DROP CBLACK ELSE 15 MOD 1+ THEN ;

: CE-BLOTS ( sx sy index -- )
  >R
  2* SWAP 2* SWAP
  2DUP XY>ADDR R@ SWAP C!
  2DUP 1+ XY>ADDR R@ SWAP C!
  OVER 1+ OVER XY>ADDR R@ SWAP C!
  1+ SWAP 1+ SWAP XY>ADDR R> SWAP C! ;

: CE-STAMP ( sx sy -- )
  2DUP CE-COLOR CE-BLOTS ;

: CE-PAN ( dx dy -- )
  S>D D>F CE-STEP F@ F* 20.0e0 F* CE-Y0 F@ F+ CE-Y0 F!
  S>D D>F CE-STEP F@ F* 20.0e0 F* CE-X0 F@ F+ CE-X0 F! ;

: CE-ZOOM ( F: factor -- )
  CE-X0 F@ CE-STEP F@ G-PX 2/ S>D D>F F* F+
  CE-Y0 F@ CE-STEP F@ G-PY 2/ S>D D>F F* F+
  FROT
  CE-STEP F@ F* CE-STEP F!
  CE-STEP F@ G-PY 2/ S>D D>F F* F- CE-Y0 F!
  CE-STEP F@ G-PX 2/ S>D D>F F* F- CE-X0 F! ;

\ Stop zooming when the step no longer survives F>X.
: CE-TRY-ZOOM ( F: factor -- )
  FDUP CE-STEP F@ F* F>X 0= IF FDROP EXIT THEN
  CE-ZOOM ;

: CE-CENTER ( x y -- )
  G-PY 2/ - S>D D>F CE-STEP F@ F* CE-Y0 F@ F+ CE-Y0 F!
  G-PX 2/ - S>D D>F CE-STEP F@ F* CE-X0 F@ F+ CE-X0 F! ;

: CE-NOTE ( -- flag )
  (APP-MOUSE)
  DUP IF
    CE-MB !
    CE-MY !
    CE-MX !
    -1 CE-HIT !
    -1
  ELSE
    DROP 2DROP
    0
  THEN ;

: CE-UP ( -- )
  BEGIN
    PAUSE
    (APP-MOUSE) NIP NIP 0=
  UNTIL ;

: CE-PAIR ( lo span -- lo hi )
  OVER + CE-GH @ MIN ;

: CE-SPLIT ( -- )
  CE-GH @ 4 / DUP 0= IF DROP 1 THEN >R
  0 R@ CE-PAIR CE-Y1A ! CE-Y0A !
  R@ R@ CE-PAIR CE-Y1B ! CE-Y0B !
  R@ 2* R@ CE-PAIR CE-Y1C ! CE-Y0C !
  R@ 3 * DUP CE-GH @ > IF DROP CE-GH @ DUP ELSE CE-GH @ THEN
  CE-Y1D ! CE-Y0D !
  R> DROP ;

\ No PAUSE here. A worker runs until STOP, on its own queue.
\ LEAVE takes the next LOOP in this word. The pixel loop stays in
\ CE-ROW, so an abort leaves the row band and the done flag is stored
\ in the right cell.
: CE-ROW ( y -- )
  CE-GW @ 0 DO
    I OVER CE-STAMP
  LOOP
  DROP ;

: CE-BAND ( y0 y1 done -- )
  >R
  SWAP
  ?DO
    CE-ABORT @ IF LEAVE THEN
    I CE-ROW
  LOOP
  -1 R> !
  STOP ;

: CE-BODY0 ( -- ) CE-Y0A @ CE-Y1A @ CE-DONE0 CE-BAND ;
: CE-BODY1 ( -- ) CE-Y0B @ CE-Y1B @ CE-DONE1 CE-BAND ;
: CE-BODY2 ( -- ) CE-Y0C @ CE-Y1C @ CE-DONE2 CE-BAND ;
: CE-BODY3 ( -- ) CE-Y0D @ CE-Y1D @ CE-DONE3 CE-BAND ;

TASK: CE-A
TASK: CE-B
TASK: CE-C
TASK: CE-D

: CE-GO0 ( -- ) CE-A ACTIVATE CE-BODY0 ;
: CE-GO1 ( -- ) CE-B ACTIVATE CE-BODY1 ;
: CE-GO2 ( -- ) CE-C ACTIVATE CE-BODY2 ;
: CE-GO3 ( -- ) CE-D ACTIVATE CE-BODY3 ;

: CE-DONE? ( -- flag )
  CE-DONE0 @ CE-DONE1 @ AND
  CE-DONE2 @ AND CE-DONE3 @ AND ;

: CE-CLEAR ( -- )
  0 CE-DONE0 !  0 CE-DONE1 !  0 CE-DONE2 !  0 CE-DONE3 ! ;

: CE-WAIT ( -- )
  MS@
  BEGIN
    CE-DONE? IF DROP EXIT THEN
    MS@ OVER - 100 > IF PREFRESH DROP MS@ THEN
    CE-NOTE IF -1 CE-ABORT ! THEN
    KEY? IF
      KEY 27 = IF -1 CE-STOP ! THEN
      -1 CE-ABORT !
    THEN
    PAUSE
  AGAIN ;

: CE-FRAME ( -- )
  0 CE-ABORT !
  CE-CLEAR
  CE-VIEW>Q
  PCLS
  0 0 AT ." Q quit  L-click zoom  M pan  +-  arrows  I O  core"
  CE-GO0 CE-GO1 CE-GO2 CE-GO3
  MS@ >R
  CE-WAIT
  CORES-JOIN
  MS@ R> - CE-MS !
  0 1 AT CE-MS @ . ." ms"
  PREFRESH ;

: CE-ACT ( -- )
  BEGIN
    CE-HIT @
  WHILE
    0 CE-HIT !
    CE-UP
    CE-MB @ DUP 1 AND IF
      DROP
      CE-MX @ CE-MY @ CE-CENTER
      0.5e0 CE-TRY-ZOOM
    ELSE DUP 4 AND IF
      DROP
      CE-MX @ CE-MY @ CE-CENTER
    ELSE
      DROP
    THEN THEN
    CE-FRAME
  REPEAT ;

: CE-REDRAW ( -- )
  CE-FRAME
  CE-ACT ;

: MANSHOW-CORE ( -- )
  DECIMAL
  CE-HOME
  0 CE-STOP !
  G-PX 2/ CE-GW !
  G-PY 2/ CE-GH !
  CE-SPLIT
  S" EditForth MANSHOW-CORE" APP-NAME
  WINDOW PIXEL-ON COLOR8
  SINGLE
  CORES
  CE-REDRAW
  BEGIN
    CE-STOP @ 0=
  WHILE
    CE-NOTE IF
      CE-ACT
    ELSE KEY? IF
      KEY
      DUP 27 = OVER [CHAR] Q = OR OVER [CHAR] q = OR IF
        DROP -1 CE-STOP !
      ELSE DUP 200 = IF DROP 0 1 CE-PAN CE-REDRAW
      ELSE DUP 208 = IF DROP 0 -1 CE-PAN CE-REDRAW
      ELSE DUP 203 = IF DROP -1 0 CE-PAN CE-REDRAW
      ELSE DUP 205 = IF DROP 1 0 CE-PAN CE-REDRAW
      ELSE DUP [CHAR] + = IF DROP 0.5e0 CE-TRY-ZOOM CE-REDRAW
      ELSE DUP [CHAR] - = IF DROP 2.0e0 CE-TRY-ZOOM CE-REDRAW
      ELSE DUP [CHAR] I = OVER [CHAR] i = OR IF
        DROP CE-MAX @ 2* 256 MIN CE-MAX ! CE-REDRAW
      ELSE DUP [CHAR] O = OVER [CHAR] o = OR IF
        DROP CE-MAX @ 2/ 8 MAX CE-MAX ! CE-REDRAW
      ELSE DUP [CHAR] R = OVER [CHAR] r = OR IF DROP CE-REDRAW
      ELSE DROP THEN THEN THEN THEN THEN THEN THEN THEN THEN THEN
    ELSE
      PAUSE
    THEN THEN
  REPEAT
  COOP
  SINGLE
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH DEFINITIONS

CE-CREDIT
CR .( Run:  MANSHOW-CORE ) CR
