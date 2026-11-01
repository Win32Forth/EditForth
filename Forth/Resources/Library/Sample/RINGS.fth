\ RINGS.fth — random rings for EditForth GRAPHICS
\
\ Port of TCOM RINGS.FTH (Tom Zimmer and Robert Smith, public domain).
\ The DOS program set 640×350×16, read an optional distortion and diameter
\ from the command tail, and exited with BYE. This copy uses the GRAPHICS
\ window (COLOR8, 16 colors), the built-in limits, and returns to the console.
\
\ Load:
\   FROMLIB FLOAD Sample/RINGS.fth
\   RINGS
\
\ Click the graphics window. Any key stops and returns to the console.
\
\ Public domain.

EMIT-NO-WRAPPER

ONLY FORTH DEFINITIONS
DECIMAL

: RINGS-CREDIT  ( -- )
  CR ." RINGS draws random colored rings, then a small corner mark."
  CR ." Click the graphics window. Any key returns to the console." CR
  ;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

CREATE SINTBL
          0 ,    25 ,    49 ,    74 ,    97 ,   120 ,   141 ,   160 ,
        178 ,   194 ,   207 ,   219 ,   228 ,   234 ,   238 ,   240 ,
        238 ,   234 ,   228 ,   219 ,   207 ,   194 ,   178 ,   160 ,
        141 ,   119 ,    97 ,    74 ,    49 ,    25 ,     0 ,   -25 ,
        -49 ,   -74 ,   -97 ,  -120 ,  -141 ,  -160 ,  -178 ,  -194 ,
       -207 ,  -219 ,  -228 ,  -234 ,  -238 ,  -240 ,  -238 ,  -234 ,
       -228 ,  -219 ,  -207 ,  -194 ,  -178 ,  -160 ,  -141 ,  -119 ,
        -97 ,   -74 ,   -49 ,   -25 ,     0 ,    25 ,    49 ,    74 ,
         97 ,   120 ,   141 ,   160 ,   178 ,   194 ,   207 ,   219 ,
        228 ,   234 ,   238 ,   240 ,   238 ,

\ TCOM used 16-bit VALUEs. VARIABLEs keep EMIT reach on the xt.
VARIABLE CENTER-X
VARIABLE CENTER-Y
VARIABLE SCALE-Y
VARIABLE RING-SIZE     40 RING-SIZE !
VARIABLE RING-STEP      2 RING-STEP !
VARIABLE DIAMETER-MAX  60 DIAMETER-MAX !
VARIABLE OBLONG-MAX    12 OBLONG-MAX !
VARIABLE OBLONG
VARIABLE SEED1
VARIABLE SEED2
VARIABLE SEED3
VARIABLE RING-CNT

\ TCOM y grows downward. LINE uses bottom-left, so flip at draw time.
: T>Y  ( ty -- ey )  G-PY 1- SWAP - ;

: TLINE  ( x1 ty1 x2 ty2 -- )
  >R >R
  T>Y
  R> R>
  T>Y
  LINE
  ;

\ ( angle scale -- x ty )   angle is steps of 6 degrees. Sine table is cells.
: XY-SCALE  ( angle scale -- x ty )
  >R
  DUP CELLS SINTBL + @
  DUP R@ 240 */
  SWAP 1 AND  OBLONG @ NEGATE *  +
  CENTER-X @ +
  SWAP 15 +  CELLS SINTBL + @
  DUP R> SCALE-Y @ */
  SWAP 1 AND  OBLONG @ *  +
  NEGATE  CENTER-Y @ +
  ;

\ 16-bit TCOM generator. Seeds stay in 0..65535.
: RND  ( n1 -- n2 )
  1 MAX
  SEED1 @  177 /MOD  2*    SWAP 171 *  SWAP -  $FFFF AND  DUP SEED1 !
  SEED2 @  176 /MOD  35 *  SWAP 172 *  SWAP -  $FFFF AND  DUP SEED2 !
  SEED3 @  178 /MOD  63 *  SWAP 170 *  SWAP -  $FFFF AND  DUP SEED3 !
  + +  SWAP MOD
  ;

: RANDOMIZE  ( -- )
  MS@ $FFFF AND  SEED1 !
  MS@ 2* 1- $FFFF AND  SEED2 !
  MS@ 2/ 1+ $FFFF AND  SEED3 !
  ;

: .SECTION  ( n -- )
  0 1 XY-SCALE
  ROT  DUP 10 + SWAP
  DO  2DUP  I 16 XY-SCALE  TLINE
  LOOP
  2DROP
  ;

: .UR  ( -- )
  KEY? ?EXIT
   3 .SECTION   20 CENTER-X +!  -16 CENTER-Y +!
  33 .SECTION  -20 CENTER-X +!   16 CENTER-Y +!
  ;

: .LR  ( -- )
  KEY? ?EXIT
  18 .SECTION   20 CENTER-X +!   16 CENTER-Y +!
  48 .SECTION  -20 CENTER-X +!  -16 CENTER-Y +!
  ;

: .UL  ( -- )
  KEY? ?EXIT
  48 .SECTION  -20 CENTER-X +!  -16 CENTER-Y +!
  18 .SECTION   20 CENTER-X +!   16 CENTER-Y +!
  ;

: .LL  ( -- )
  KEY? ?EXIT
  33 .SECTION  -20 CENTER-X +!   16 CENTER-Y +!
   3 .SECTION   20 CENTER-X +!  -16 CENTER-Y +!
  ;

: SHOW-SAMSUNG  ( -- )
  OBLONG @ >R  0 OBLONG !
  CRED COLOR !
  55 CENTER-X !   40 CENTER-Y !
  .UR .LR .UL .LL
  -40 CENTER-X +!  .UR .LR
   40 CENTER-X +!
  -32 CENTER-Y +!  .LR .LL
   64 CENTER-Y +!  .UL .UR
  15 RND 1+ COLOR !
  R> OBLONG !
  PREFRESH
  ;

: SHOW-WEBS  ( -- )
  COLOR @ >R
  16 RND COLOR !
  60 0 DO
    I RING-SIZE @ 2/      RND     XY-SCALE
    I RING-SIZE @ 2/      RND     XY-SCALE  TLINE
    I RING-SIZE @ 2/ DUP  RND +   XY-SCALE
    I RING-SIZE @ 2/ DUP  RND +   XY-SCALE  TLINE
  5 RND 1+ +LOOP
  R> COLOR !
  ;

: SHOW-RING  ( -- )
  60 0 DO
    I RING-SIZE @ XY-SCALE  I 1+ RING-SIZE @ XY-SCALE  TLINE
  LOOP
  1 RING-CNT +!
  RING-CNT @  6000 DIAMETER-MAX @ 20 * -  >
  IF  0 RING-CNT !
      30 RND        OBLONG-MAX !
      200 RND 1+    DIAMETER-MAX !
      SHOW-SAMSUNG
      10 0 DO  1 TENTHS  KEY? IF LEAVE THEN  LOOP
  THEN
  RING-CNT @  3000 DIAMETER-MAX @ 6 * -  <
  IF  RING-CNT @ 3 AND 0=
      IF  16 RND COLOR !  THEN
  ELSE  CBLACK COLOR !
  THEN
  PREFRESH
  ;

: SHOW-DISK  ( -- )
  G-PY RND 4 MAX  CENTER-Y !
  G-PX RND 4 MAX  CENTER-X !
  DIAMETER-MAX @ RND 4 MAX  2
  DO  I RING-SIZE !
      SHOW-RING
      KEY? IF LEAVE THEN
  RING-STEP @ +LOOP
  RING-STEP @ 2 > IF  SHOW-WEBS  THEN
  ;

: RINGS  ( -- )
  DECIMAL
  S" EditForth RINGS" APP-NAME
  WINDOW  PIXEL-ON  COLOR8
  WHITE  PCLS
  RANDOMIZE
  G-PY 2/ 1-  CENTER-Y !
  240 240 CENTER-Y @ */  SCALE-Y !
  CWHITE COLOR !
  12 OBLONG-MAX !   60 DIAMETER-MAX !   2 RING-STEP !
  0 OBLONG !  0 RING-CNT !
  SHOW-SAMSUNG
  BEGIN
    OBLONG-MAX @ 2 +  OBLONG @ -  1 MAX  0
    DO  SHOW-DISK
        12 RND 1+  RING-STEP !
        KEY? IF LEAVE THEN
    4 +LOOP
    OBLONG-MAX @ 6 /  RND  6 *  0 MAX  OBLONG !
  KEY? UNTIL
  KEY? IF  KEY DROP  THEN
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

RINGS-CREDIT
CR .( Run:  RINGS ) CR
CR .( Emit: EMIT-WINDOW-APP RINGS ) CR
