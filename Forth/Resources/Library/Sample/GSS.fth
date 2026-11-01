\ GSS.fth — graphic squares
\
\ Port of TCOM GSS.FTH (Tom Zimmer, public domain). The DOS program filled
\ an EGA screen with growing random rectangles. The Samsung logo and the
\ video-fill assembly are not part of this copy. Defaults are size 20 and
\ no delay. It runs on EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/GSS.fth
\   GSS
\
\ Click the graphics window. Any key stops.
\
\ Public domain.

EMIT-NO-WRAPPER

ONLY FORTH DEFINITIONS
DECIMAL

: GSS-CREDIT ( -- )
  CR ." GSS fills the window with growing colored squares."
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

VARIABLE RX
VARIABLE RY
VARIABLE RW
VARIABLE GS-SIZE

: FILL-RECT ( x y w h -- )
  DUP 0= IF 2DROP 2DROP EXIT THEN
  >R
  RW ! RY ! RX !
  R> 0 DO
    RX @  RY @ I +
    RX @ RW @ + 1-  RY @ I +
    LINE
  LOOP ;

: GSS ( -- )
  DECIMAL
  S" EditForth GSS" APP-NAME
  WINDOW PIXEL-ON COLOR8
  WHITE PCLS
  RANDOMIZE
  20 GS-SIZE !
  BEGIN
    15 RND 1+ COLOR !
    G-PX GS-SIZE @ - 1 MAX RND
    G-PY GS-SIZE @ - 1 MAX RND
    GS-SIZE @ RND 4 MAX
    GS-SIZE @ 2* RND 4 MAX
    FILL-RECT
    PREFRESH
    GS-SIZE @ 72 > IF
      4 GS-SIZE !
    ELSE
      GS-SIZE @ 8 / 1+ GS-SIZE +!
    THEN
    KEY?
  UNTIL
  KEY? IF KEY DROP THEN
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

GSS-CREDIT
CR .( Run:  GSS ) CR
CR .( Emit: EMIT-WINDOW-APP GSS ) CR
