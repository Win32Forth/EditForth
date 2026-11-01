\ LINES.fth — random lines
\
\ Port of TCOM LINES.FTH (Tom Zimmer, public domain). The DOS program
\ filled a CGA, EGA, or Hercules screen and left with BYE. This copy
\ draws on the EditForth GRAPHICS window and returns to the console.
\ It runs on EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/LINES.fth
\   LINES
\
\ Click the graphics window. Any key stops.
\
\ Public domain.

EMIT-NO-WRAPPER

ONLY FORTH DEFINITIONS
DECIMAL

: LINES-CREDIT ( -- )
  CR ." LINES draws fans of random colored lines."
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

VARIABLE LX1
VARIABLE LY1
VARIABLE LX2
VARIABLE LY2

: FAN ( -- )
  G-PX RND LX1 !   G-PY RND LY1 !
  G-PX RND LX2 !   G-PY RND LY2 !
  12 0 DO
    15 RND 2 < IF 15 RND 1+ COLOR ! THEN
    LX1 @ I + LY1 @ I -
    LX2 @ I - LY2 @ I +
    LINE
    KEY? IF LEAVE THEN
  LOOP
  PREFRESH ;

: LINES ( -- )
  DECIMAL
  S" EditForth LINES" APP-NAME
  WINDOW PIXEL-ON COLOR8
  WHITE PCLS
  RANDOMIZE
  14 COLOR !
  BEGIN FAN KEY? UNTIL
  KEY? IF KEY DROP THEN
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

LINES-CREDIT
CR .( Run:  LINES ) CR
CR .( Emit: EMIT-WINDOW-APP LINES ) CR
