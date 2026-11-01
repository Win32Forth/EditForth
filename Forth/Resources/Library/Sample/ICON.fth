\ ICON.fth — 40 by 40 color icon editor
\
\ Port of TCOM ICON.FTH (Tom Zimmer, public domain). The DOS program edited
\ a magnified icon with EGA blits, a directory of .ICZ files, and BYE.
\ This copy edits one 40x40 icon of color indices 0 through 15. 0 is left
\ blank. S writes icon.raw (1600 bytes) and L reads it back. It runs on
\ EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/ICON.fth
\   ICON
\
\ Left click or Space paints the pen. Right click erases. Click a chip on
\ the right to choose the pen. Arrows move the cell. F fills, C clears,
\ P plays a short color cycle, Esc returns to the console.
\
\ Public domain.

EMIT-NO-WRAPPER

ONLY FORTH DEFINITIONS
DECIMAL

: ICON-CREDIT ( -- )
  CR ." ICON edits a 40 by 40 color picture."
  CR ." Left click or Space paints. Right click erases. Chips on the right set the pen."
  CR ." Arrows move. F fills, C clears, S saves icon.raw, L loads it."
  CR ." P plays a short color cycle. Esc returns to the console." CR
  ;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

40 CONSTANT IC-N
8 CONSTANT IC-SC
1600 CONSTANT IC-BYTES
CREATE IC-BUF IC-BYTES ALLOT

VARIABLE RX
VARIABLE RY
VARIABLE RW
VARIABLE IC-X
VARIABLE IC-Y
VARIABLE IC-PEN
VARIABLE IC-QUIT

: FILL-RECT ( x y w h -- )
  DUP 0= IF 2DROP 2DROP EXIT THEN
  >R
  RW ! RY ! RX !
  R> 0 DO
    RX @ RY @ I +
    RX @ RW @ + 1- RY @ I +
    LINE
  LOOP ;

: IC-ADDR ( col row -- a )
  IC-N * + IC-BUF + ;

VARIABLE IC-BX
VARIABLE IC-BY

: IC-BOX ( -- )
  15 COLOR !
  IC-X @ IC-SC * 8 + IC-BX !
  IC-N 1- IC-Y @ - IC-SC * 8 + IC-BY !
  IC-BX @ IC-BY @  IC-BX @ IC-SC 1- + IC-BY @ LINE
  IC-BX @ IC-BY @  IC-BX @ IC-BY @ IC-SC 1- + LINE
  IC-BX @ IC-SC 1- + IC-BY @  IC-BX @ IC-SC 1- + IC-BY @ IC-SC 1- + LINE
  IC-BX @ IC-BY @ IC-SC 1- +  IC-BX @ IC-SC 1- + IC-BY @ IC-SC 1- + LINE
  ;

: IC-SHOW ( -- )
  WHITE PCLS
  IC-N 0 DO
    IC-N 0 DO
      I J IC-ADDR C@ ?DUP IF
        COLOR !
        I IC-SC * 8 +
        IC-N 1- J - IC-SC * 8 +
        IC-SC IC-SC FILL-RECT
      THEN
    LOOP
  LOOP
  IC-BOX
  16 0 DO
    I COLOR !
    348  I 18 * 8 +
    16 16 FILL-RECT
  LOOP
  IC-PEN @ COLOR !
  46 2 AT ." pen"
  PREFRESH
  ;

: IC-PAINT ( col row c -- )
  >R
  DUP 0 IC-N WITHIN IF
    OVER 0 IC-N WITHIN IF
      IC-ADDR R> SWAP C! EXIT
    THEN
  THEN
  R> 2DROP DROP
  ;

: IC-AT-XY ( x y -- col row flag )
  OVER 8 328 WITHIN OVER 8 328 WITHIN AND IF
    SWAP 8 - IC-SC /
    SWAP 8 - IC-SC /
    IC-N 1- SWAP -
    TRUE
  ELSE
    2DROP 0 0 FALSE
  THEN ;

: IC-HANDLE ( x y buttons -- )
  DUP 0= IF DROP 2DROP EXIT THEN
  >R
  OVER 348 366 WITHIN OVER 8 296 WITHIN AND IF
    NIP 8 - 18 / 0 MAX 15 MIN IC-PEN !
    R> DROP
    EXIT
  THEN
  IC-AT-XY IF
    2DUP IC-Y ! IC-X !
    R> 1 = IF IC-PEN @ ELSE 0 THEN
    IC-PAINT
  ELSE
    R> DROP
  THEN
  ;

: IC-FILL ( c -- )
  IC-BYTES 0 DO DUP IC-BUF I + C! LOOP DROP ;

: IC-SAVE ( -- )
  S" icon.raw" W/O BIN CREATE-FILE IF
    DROP CR ." Could not write icon.raw" CR EXIT
  THEN
  >R
  IC-BUF IC-BYTES R@ WRITE-FILE DROP
  R> CLOSE-FILE DROP
  CR ." Wrote icon.raw" CR
  ;

: IC-LOAD ( -- )
  S" icon.raw" R/O BIN OPEN-FILE IF
    DROP CR ." Could not open icon.raw" CR EXIT
  THEN
  >R
  IC-BUF IC-BYTES R@ READ-FILE DROP DROP
  R> CLOSE-FILE DROP
  ;

: IC-PLAY ( -- )
  16 0 DO
    IC-BYTES 0 DO
      IC-BUF I + C@ ?DUP IF
        1+ 15 MIN IC-BUF I + C!
      THEN
    LOOP
    IC-SHOW
    KEY? IF LEAVE THEN
    30 0 DO PAUSE LOOP
  LOOP
  ;

: IC-KEY ( c -- )
  DUP 27 = IF DROP -1 IC-QUIT ! EXIT THEN
  DUP 200 = IF DROP IC-Y @ 1- 0 MAX IC-Y ! EXIT THEN
  DUP 208 = IF DROP IC-Y @ 1+ IC-N 1- MIN IC-Y ! EXIT THEN
  DUP 203 = IF DROP IC-X @ 1- 0 MAX IC-X ! EXIT THEN
  DUP 205 = IF DROP IC-X @ 1+ IC-N 1- MIN IC-X ! EXIT THEN
  DUP 32 = IF DROP IC-X @ IC-Y @ IC-PEN @ IC-PAINT EXIT THEN
  DUP 70 = OVER 102 = OR IF DROP IC-PEN @ IC-FILL EXIT THEN
  DUP 67 = OVER 99 = OR IF DROP 0 IC-FILL EXIT THEN
  DUP 83 = OVER 115 = OR IF DROP IC-SAVE EXIT THEN
  DUP 76 = OVER 108 = OR IF DROP IC-LOAD EXIT THEN
  DUP 80 = OVER 112 = OR IF DROP IC-PLAY EXIT THEN
  DROP
  ;

: ICON ( -- )
  DECIMAL
  ICON-CREDIT
  S" EditForth ICON" APP-NAME
  WINDOW PIXEL-ON COLOR8
  IC-BUF IC-BYTES 0 FILL
  0 IC-X !  0 IC-Y !  15 IC-PEN !  0 IC-QUIT !
  BEGIN
    IC-QUIT @ 0=
  WHILE
    IC-SHOW
    [DEFINED] (APP-PUMP) [IF] (APP-PUMP) [THEN]
    G-MOUSE IC-HANDLE
    KEY? IF KEY IC-KEY THEN
  REPEAT
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

CR .( Run:  ICON ) CR
CR .( Emit: EMIT-WINDOW-APP ICON ) CR
