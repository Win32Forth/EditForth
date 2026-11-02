\ LINEWALK.fth — a line whose ends bounce around the window
\
\ Port of TCOM LINEWALK.FTH (Tom Zimmer, public domain). The DOS program
\ took a maximum length and a line count from the command tail. This copy
\ uses those built-in defaults (length 200, 400 steps) on the GRAPHICS
\ window. It runs on EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/LINEWALK.fth
\   LINEWALK
\
\ Click the graphics window. Any key stops.
\
\ Public domain.

EMIT-NO-WRAPPER

ONLY FORTH DEFINITIONS
DECIMAL

: LINEWALK-CREDIT ( -- )
  CR ." LINEWALK bounces a colored line around the window."
  CR ." Click the graphics window. Any key returns to the console." CR
  ;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

VARIABLE SEED1
VARIABLE SEED2
VARIABLE SEED3

: RND ( n1 -- n2 )
  1 MAX
  SEED1 @ 177 /MOD 2*    SWAP 171 * SWAP - $FFFF AND DUP SEED1 !
  SEED2 @ 176 /MOD 35 *  SWAP 172 * SWAP - $FFFF AND DUP SEED2 !
  SEED3 @ 178 /MOD 63 *  SWAP 170 * SWAP - $FFFF AND DUP SEED3 !
  + + SWAP MOD ;

: RANDOMIZE ( -- )
  MS@ $FFFF AND SEED1 !
  MS@ 2* 1- $FFFF AND SEED2 !
  MS@ 2/ 1+ $FFFF AND SEED3 ! ;

\ ( x dx lim -- x2 dx2 )  keep the point inside 0 .. lim-1
: CLAMP-STEP ( x dx lim -- x2 dx2 )
  >R
  2DUP +
  DUP 0< IF DROP 2DROP 0 1 R> DROP EXIT THEN
  DUP R@ >= IF DROP 2DROP R> 1- -1 EXIT THEN
  R> DROP
  ROT DROP SWAP ;

VARIABLE XA  VARIABLE YA  VARIABLE XB  VARIABLE YB
VARIABLE DXA VARIABLE DYA VARIABLE DXB VARIABLE DYB
VARIABLE LW-LIM
VARIABLE LW-WAIT
VARIABLE LW-SKIP

: LW-COLOR ( -- ) 15 RND 1+ COLOR ! ;

: LW-DELTA ( -- n ) 2 RND 2 RND - ;

: LW-DRAW ( -- )
  LW-LIM @ RND 10 MAX LW-LIM !
  LW-DELTA DXA !  LW-DELTA DYA !
  LW-DELTA DXB !  LW-DELTA DYB !
  400 0 DO
    LW-WAIT @ 0= IF
      XA @ YA @ XB @ YB @ LINE
      LW-SKIP @ LW-WAIT !
    ELSE
      -1 LW-WAIT +!
    THEN
    XA @ DXA @ G-PX CLAMP-STEP DXA ! XA !
    YA @ DYA @ G-PY CLAMP-STEP DYA ! YA !
    XB @ DXB @ G-PX CLAMP-STEP DXB ! XB !
    YB @ DYB @ G-PY CLAMP-STEP DYB ! YB !
    I 16 MOD 0= IF LW-COLOR THEN
    KEY? IF LEAVE THEN
  LOOP
  PREFRESH
  LW-COLOR ;

: LINEWALK ( -- )
  DECIMAL
  S" EditForth LINEWALK" APP-NAME
  WINDOW PIXEL-ON COLOR8
  WHITE PCLS
  RANDOMIZE
  200 LW-LIM !   0 LW-SKIP !   0 LW-WAIT !
  G-PX 2/ XA !  G-PY 2/ YA !
  G-PX 2/ 20 + XB !  G-PY 2/ YB !
  1 DXA !  1 DYA !  -1 DXB !  1 DYB !
  2 COLOR !
  BEGIN LW-DRAW KEY? UNTIL
  KEY? IF KEY DROP THEN
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

LINEWALK-CREDIT
CR .( Run:  LINEWALK ) CR
CR .( Emit: EMIT-WINDOW-APP LINEWALK ) CR
