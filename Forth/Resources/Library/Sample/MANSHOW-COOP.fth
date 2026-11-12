\ MANSHOW-COOP.fth — Mandelbrot with four cooperative tasks
\
\ Same window as MANSHOW. Left click zooms in at the cursor. Middle
\ click pans. Right click redraws. + and - zoom about the center.
\ Arrows pan. I and O change the iteration limit. R redraws.
\ Q or Esc returns to the console.
\
\ The view stays in FLOATING on the console, as MANSHOW does. Each
\ frame converts the origin and the step with F>X. Four tasks then
\ fill four row bands with X* from Library/FixPoint. A task does not
\ touch the float stack. PAUSE at the end of a row lets the other
\ tasks and the console run. There is no preemption inside NEXT.
\
\ Load:
\   FROMLIB FLOAD Sample/MANSHOW-COOP.fth
\   MANSHOW-COOP
\
\ Public domain. The picture is the Mandelbrot set (C. H. Ting, 1992).

[DEFINED] ANEW [IF] ANEW MANSHOW-COOP-MODULE [THEN]
[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]

[DEFINED] FIXED-POINT 0= [IF]
  FROMLIB FLOAD FixPoint/FIXEDPOINT.fth
[THEN]

ONLY FORTH DEFINITIONS
DECIMAL

: CO-CREDIT ( -- )
  CR ." MANSHOW-COOP draws the Mandelbrot set with four cooperative tasks."
  CR ." The view is floating point. The pixels use FixPoint X*."
  CR ." Left click zooms in. Middle pans. Right redraws."
  CR ." + - zoom. Arrows pan. I O iterations. R redraws. Q quits." CR
  ;

ONLY FORTH DEFINITIONS
ALSO FLOATING
ALSO GRAPHICS
ALSO FIXED-POINT
DECIMAL

FVARIABLE CO-X0
FVARIABLE CO-Y0
FVARIABLE CO-STEP
VARIABLE CO-MAX
VARIABLE CO-STOP
VARIABLE CO-HIT
VARIABLE CO-MX
VARIABLE CO-MY
VARIABLE CO-MB
VARIABLE CO-MS
VARIABLE CO-QX
VARIABLE CO-QY
VARIABLE CO-QS
VARIABLE CO-ABORT
VARIABLE CO-GW
VARIABLE CO-GH
VARIABLE CO-DONE0
VARIABLE CO-DONE1
VARIABLE CO-DONE2
VARIABLE CO-DONE3
VARIABLE CO-Y0A
VARIABLE CO-Y1A
VARIABLE CO-Y0B
VARIABLE CO-Y1B
VARIABLE CO-Y0C
VARIABLE CO-Y1C
VARIABLE CO-Y0D
VARIABLE CO-Y1D

: CO-ZR ( -- addr ) PAD ;
: CO-ZI ( -- addr ) PAD CELL+ ;
: CO-CR ( -- addr ) PAD 2 CELLS + ;
: CO-CI ( -- addr ) PAD 3 CELLS + ;
: CO-ZN ( -- addr ) PAD 4 CELLS + ;

: CO-HOME ( -- )
  -2.2e0 CO-X0 F!
  -1.15e0 CO-Y0 F!
  3.0e0 G-PX S>D D>F F/ CO-STEP F!
  40 CO-MAX ! ;

: CO-VIEW>Q ( -- )
  CO-X0 F@ F>X CO-QX !
  CO-Y0 F@ F>X CO-QY !
  CO-STEP F@ F>X CO-QS ! ;

: CO-ITER ( cr ci -- n )
  CO-CI ! CO-CR !
  0 CO-ZR !  0 CO-ZI !  0 CO-ZN !
  BEGIN
    CO-ZN @ CO-MAX @ <
  WHILE
    CO-ZR @ DUP X*
    CO-ZI @ DUP X* +
    XUNIT 2 LSHIFT >
    IF CO-ZN @ EXIT THEN
    CO-ZR @ CO-ZI @ X* 2* CO-CI @ +
    CO-ZR @ DUP X* CO-ZI @ DUP X* - CO-CR @ +
    CO-ZR ! CO-ZI !
    1 CO-ZN +!
  REPEAT
  CO-ZN @ ;

: CO-COLOR ( sx sy -- index )
  2* CO-QS @ * CO-QY @ + >R
  2* CO-QS @ * CO-QX @ + R>
  CO-ITER
  DUP CO-MAX @ = IF DROP CBLACK ELSE 15 MOD 1+ THEN ;

: CO-BLOTS ( sx sy index -- )
  >R
  2* SWAP 2* SWAP
  2DUP XY>ADDR R@ SWAP C!
  2DUP 1+ XY>ADDR R@ SWAP C!
  OVER 1+ OVER XY>ADDR R@ SWAP C!
  1+ SWAP 1+ SWAP XY>ADDR R> SWAP C! ;

: CO-STAMP ( sx sy -- )
  2DUP CO-COLOR CO-BLOTS ;

: CO-PAN ( dx dy -- )
  S>D D>F CO-STEP F@ F* 20.0e0 F* CO-Y0 F@ F+ CO-Y0 F!
  S>D D>F CO-STEP F@ F* 20.0e0 F* CO-X0 F@ F+ CO-X0 F! ;

: CO-ZOOM ( F: factor -- )
  CO-X0 F@ CO-STEP F@ G-PX 2/ S>D D>F F* F+
  CO-Y0 F@ CO-STEP F@ G-PY 2/ S>D D>F F* F+
  FROT
  CO-STEP F@ F* CO-STEP F!
  CO-STEP F@ G-PY 2/ S>D D>F F* F- CO-Y0 F!
  CO-STEP F@ G-PX 2/ S>D D>F F* F- CO-X0 F! ;

\ Stop zooming when the step no longer survives F>X.
: CO-TRY-ZOOM ( F: factor -- )
  FDUP CO-STEP F@ F* F>X 0= IF FDROP EXIT THEN
  CO-ZOOM ;

: CO-CENTER ( x y -- )
  G-PY 2/ - S>D D>F CO-STEP F@ F* CO-Y0 F@ F+ CO-Y0 F!
  G-PX 2/ - S>D D>F CO-STEP F@ F* CO-X0 F@ F+ CO-X0 F! ;

: CO-NOTE ( -- flag )
  (APP-MOUSE)
  DUP IF
    CO-MB !
    CO-MY !
    CO-MX !
    -1 CO-HIT !
    -1
  ELSE
    DROP 2DROP
    0
  THEN ;

: CO-UP ( -- )
  BEGIN
    PAUSE
    (APP-MOUSE) NIP NIP 0=
  UNTIL ;

: CO-PAIR ( lo span -- lo hi )
  OVER + CO-GH @ MIN ;

: CO-SPLIT ( -- )
  CO-GH @ 4 / DUP 0= IF DROP 1 THEN >R
  0 R@ CO-PAIR CO-Y1A ! CO-Y0A !
  R@ R@ CO-PAIR CO-Y1B ! CO-Y0B !
  R@ 2* R@ CO-PAIR CO-Y1C ! CO-Y0C !
  R@ 3 * DUP CO-GH @ > IF DROP CO-GH @ DUP ELSE CO-GH @ THEN
  CO-Y1D ! CO-Y0D !
  R> DROP ;

\ LEAVE takes the next LOOP in this word. The pixel loop stays in
\ CO-ROW, so an abort leaves the row band and the done flag is stored
\ in the right cell.
: CO-ROW ( y -- )
  CO-GW @ 0 DO
    I OVER CO-STAMP
  LOOP
  DROP ;

: CO-BAND ( y0 y1 done -- )
  >R
  SWAP
  ?DO
    CO-ABORT @ IF LEAVE THEN
    I CO-ROW
    PAUSE
  LOOP
  -1 R> !
  STOP ;

: CO-BODY0 ( -- ) CO-Y0A @ CO-Y1A @ CO-DONE0 CO-BAND ;
: CO-BODY1 ( -- ) CO-Y0B @ CO-Y1B @ CO-DONE1 CO-BAND ;
: CO-BODY2 ( -- ) CO-Y0C @ CO-Y1C @ CO-DONE2 CO-BAND ;
: CO-BODY3 ( -- ) CO-Y0D @ CO-Y1D @ CO-DONE3 CO-BAND ;

TASK: CO-A
TASK: CO-B
TASK: CO-C
TASK: CO-D

: CO-GO0 ( -- ) CO-A ACTIVATE CO-BODY0 ;
: CO-GO1 ( -- ) CO-B ACTIVATE CO-BODY1 ;
: CO-GO2 ( -- ) CO-C ACTIVATE CO-BODY2 ;
: CO-GO3 ( -- ) CO-D ACTIVATE CO-BODY3 ;

: CO-DONE? ( -- flag )
  CO-DONE0 @ CO-DONE1 @ AND
  CO-DONE2 @ AND CO-DONE3 @ AND ;

: CO-CLEAR ( -- )
  0 CO-DONE0 !  0 CO-DONE1 !  0 CO-DONE2 !  0 CO-DONE3 ! ;

: CO-WAIT ( -- )
  MS@
  BEGIN
    CO-DONE? IF DROP EXIT THEN
    MS@ OVER - 100 > IF PREFRESH DROP MS@ THEN
    CO-NOTE IF -1 CO-ABORT ! THEN
    KEY? IF
      KEY 27 = IF -1 CO-STOP ! THEN
      -1 CO-ABORT !
    THEN
    PAUSE
  AGAIN ;

: CO-FRAME ( -- )
  0 CO-ABORT !
  CO-CLEAR
  CO-VIEW>Q
  PCLS
  0 0 AT ." Q quit  L-click zoom  M pan  +-  arrows  I O  coop"
  CO-GO0 CO-GO1 CO-GO2 CO-GO3
  MS@ >R
  CO-WAIT
  MS@ R> - CO-MS !
  0 1 AT CO-MS @ . ." ms"
  PREFRESH ;

: CO-ACT ( -- )
  BEGIN
    CO-HIT @
  WHILE
    0 CO-HIT !
    CO-UP
    CO-MB @ DUP 1 AND IF
      DROP
      CO-MX @ CO-MY @ CO-CENTER
      0.5e0 CO-TRY-ZOOM
    ELSE DUP 4 AND IF
      DROP
      CO-MX @ CO-MY @ CO-CENTER
    ELSE
      DROP
    THEN THEN
    CO-FRAME
  REPEAT ;

: CO-REDRAW ( -- )
  CO-FRAME
  CO-ACT ;

: MANSHOW-COOP ( -- )
  DECIMAL
  CO-HOME
  0 CO-STOP !
  G-PX 2/ CO-GW !
  G-PY 2/ CO-GH !
  CO-SPLIT
  S" EditForth MANSHOW-COOP" APP-NAME
  WINDOW PIXEL-ON COLOR8
  MULTI
  CO-REDRAW
  BEGIN
    CO-STOP @ 0=
  WHILE
    CO-NOTE IF
      CO-ACT
    ELSE KEY? IF
      KEY
      DUP 27 = OVER [CHAR] Q = OR OVER [CHAR] q = OR IF
        DROP -1 CO-STOP !
      ELSE DUP 200 = IF DROP 0 1 CO-PAN CO-REDRAW
      ELSE DUP 208 = IF DROP 0 -1 CO-PAN CO-REDRAW
      ELSE DUP 203 = IF DROP -1 0 CO-PAN CO-REDRAW
      ELSE DUP 205 = IF DROP 1 0 CO-PAN CO-REDRAW
      ELSE DUP [CHAR] + = IF DROP 0.5e0 CO-TRY-ZOOM CO-REDRAW
      ELSE DUP [CHAR] - = IF DROP 2.0e0 CO-TRY-ZOOM CO-REDRAW
      ELSE DUP [CHAR] I = OVER [CHAR] i = OR IF
        DROP CO-MAX @ 2* 256 MIN CO-MAX ! CO-REDRAW
      ELSE DUP [CHAR] O = OVER [CHAR] o = OR IF
        DROP CO-MAX @ 2/ 8 MAX CO-MAX ! CO-REDRAW
      ELSE DUP [CHAR] R = OVER [CHAR] r = OR IF DROP CO-REDRAW
      ELSE DROP THEN THEN THEN THEN THEN THEN THEN THEN THEN THEN
    ELSE
      PAUSE
    THEN THEN
  REPEAT
  SINGLE
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH DEFINITIONS

CO-CREDIT
CR .( Run:  MANSHOW-COOP ) CR
