\ DRAW.fth — mouse sketch
\
\ Port of TCOM DRAW.FTH (Tom Zimmer, public domain). The DOS program used
\ a 640x480 EGA screen, a mouse, and a text help box. This copy uses the
\ GRAPHICS window in COLOR8. It runs on EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/DRAW.fth
\   DRAW
\
\ Left drag draws. Right drag draws a thick line. Middle button or C
\ clears. Click a color chip along the top to choose the pen. QUIT and
\ CLEAR sit to the right of the chips. H shows help. Esc returns to the
\ console.
\
\ Public domain.

EMIT-NO-WRAPPER

ONLY FORTH DEFINITIONS
DECIMAL

: DRAW-CREDIT ( -- )
  CR ." DRAW is a mouse sketch on the graphics window."
  CR ." Left drag draws. Right drag is thick. Middle button or C clears."
  CR ." Click a top color chip to pick the pen. H shows help. Esc quits." CR
  ;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

VARIABLE RX
VARIABLE RY
VARIABLE RW
VARIABLE PEN
VARIABLE WASDOWN?
VARIABLE LAST-X
VARIABLE LAST-Y
VARIABLE FROM-X
VARIABLE FROM-Y
VARIABLE DONE?
VARIABLE HELP?

: FILL-RECT ( x y w h -- )
  DUP 0= IF 2DROP 2DROP EXIT THEN
  >R
  RW ! RY ! RX !
  R> 0 DO
    RX @ RY @ I +
    RX @ RW @ + 1- RY @ I +
    LINE
  LOOP ;

: CLIP-X ( x -- x2 ) 0 MAX G-PX 1- MIN ;
: CLIP-Y ( y -- y2 ) 0 MAX G-PY 28 - MIN ;

: DRAW-CHROME ( -- )
  16 0 DO
    I COLOR !
    I 18 * 4 +   G-PY 22 -
    14 16
    FILL-RECT
  LOOP
  15 COLOR !
  42 0 AT ." QUIT    CLEAR"
  PEN @ COLOR !
  ;

: CLEAR-CANVAS ( -- )
  WHITE PCLS
  DRAW-CHROME
  0 HELP? !
  PREFRESH
  ;

: DRAW-HELP ( -- )
  WHITE PCLS
  15 COLOR !
  4 4 AT ." DRAW"
  4 6 AT ." Left drag draws a line."
  4 7 AT ." Right drag draws a thick line."
  4 8 AT ." Middle button or C clears."
  4 9 AT ." Click a color chip at the top."
  4 11 AT ." Click or press a key to dismiss help."
  -1 HELP? !
  PREFRESH
  ;

: IN-CHROME? ( y -- flag ) G-PY 28 - >= ;

: HIT-CHROME ( x y -- )
  DROP
  DUP 292 < IF
    18 / 15 MIN PEN !
    DRAW-CHROME
    PREFRESH
    EXIT
  THEN
  DUP 328 384 WITHIN IF DROP -1 DONE? ! EXIT THEN
  DUP 392 456 WITHIN IF DROP CLEAR-CANVAS EXIT THEN
  DROP
  ;

: BUTTON-LEFT ( x y -- x y )
  DUP IN-CHROME? WASDOWN? @ 0= AND IF
    2DUP HIT-CHROME
    0 WASDOWN? !
  ELSE
    SWAP CLIP-X SWAP CLIP-Y
    WASDOWN? @ 0= IF
      2DUP LAST-Y ! LAST-X !
      -1 WASDOWN? !
    THEN
    PEN @ COLOR !
    2DUP
    LAST-X @ LAST-Y @ 2SWAP LINE
    2DUP LAST-Y ! LAST-X !
    PREFRESH
  THEN
  ;

: BUTTON-RIGHT ( x y -- x y )
  DUP IN-CHROME? IF BUTTON-LEFT EXIT THEN
  SWAP CLIP-X SWAP CLIP-Y
  WASDOWN? @ 0= IF
    2DUP FROM-Y ! FROM-X !
    -1 WASDOWN? !
  THEN
  PEN @ COLOR !
  3 -3 DO
    FROM-X @ FROM-Y @ I +
    2OVER I +
    LINE
  LOOP
  2DUP FROM-Y ! FROM-X !
  PREFRESH
  ;

: BUTTON-MIDDLE ( -- )
  CLEAR-CANVAS
  0 WASDOWN? !
  ;

: DO-KEY ( c -- flag )
  DUP 27 = IF DROP TRUE EXIT THEN
  DUP 72 = OVER 104 = OR IF DROP DRAW-HELP FALSE EXIT THEN
  DUP 67 = OVER 99 = OR IF DROP CLEAR-CANVAS FALSE EXIT THEN
  HELP? @ IF DROP 0 HELP? ! CLEAR-CANVAS FALSE EXIT THEN
  DROP FALSE
  ;

: HANDLE-MOUSE ( x y buttons -- )
  HELP? @ IF
    DUP IF
      DROP 2DROP
      0 HELP? ! CLEAR-CANVAS
      0 WASDOWN? !
    ELSE
      DROP 2DROP
    THEN
    EXIT
  THEN
  DUP 1 = IF DROP BUTTON-LEFT 2DROP EXIT THEN
  DUP 2 = IF DROP BUTTON-RIGHT 2DROP EXIT THEN
  DUP 4 = IF DROP 2DROP BUTTON-MIDDLE EXIT THEN
  DUP IF DROP 2DROP 0 WASDOWN? ! EXIT THEN
  DROP 0 WASDOWN? ! 2DROP
  ;

: DRAW ( -- )
  DECIMAL
  DRAW-CREDIT
  S" EditForth DRAW" APP-NAME
  WINDOW PIXEL-ON COLOR8
  15 PEN !
  0 DONE? !
  0 WASDOWN? !
  0 HELP? !
  CLEAR-CANVAS
  BEGIN
    DONE? @ 0=
  WHILE
    [DEFINED] (APP-PUMP) [IF] (APP-PUMP) [THEN]
    G-MOUSE HANDLE-MOUSE
    KEY? IF KEY DO-KEY IF -1 DONE? ! THEN THEN
  REPEAT
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

CR .( Run:  DRAW ) CR
CR .( Emit: EMIT-WINDOW-APP DRAW ) CR
