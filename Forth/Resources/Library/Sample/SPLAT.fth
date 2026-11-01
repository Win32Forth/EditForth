\ SPLAT.fth — wandering dots
\
\ Port of TCOM SPLAT.FTH (Tom Zimmer, public domain). The DOS program was
\ a graphics screen saver with a video-mode list and a reboot hook. This
\ copy draws on the GRAPHICS window. An empty password lets Esc stop it.
\ A password must be typed and confirmed with Enter. It runs on EditForth
\ and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/SPLAT.fth
\   SPLAT
\
\ S toggles a second erasing dot. + slows the walk and - speeds it up.
\ Those keys are available when no password was set.
\
\ Public domain.

EMIT-NO-WRAPPER

ONLY FORTH DEFINITIONS
DECIMAL

: SPLAT-CREDIT ( -- )
  CR ." SPLAT walks colored dots around the window."
  CR ." With no password, Esc returns to the console."
  CR ." With a password, type it and press Enter."
  CR ." S toggles an erasing dot. + slows the walk. - speeds it up." CR
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

: SP-WRAP ( n lim -- n2 )
  OVER 0< IF 2DROP 0 EXIT THEN
  2DUP < IF DROP EXIT THEN
  DROP 1- ;

VARIABLE SP-X
VARIABLE SP-Y
VARIABLE SP-EX
VARIABLE SP-EY
VARIABLE SP-SNAKE
VARIABLE SP-DELAY
VARIABLE SP-QUIT
CREATE SP-PASS 80 ALLOT
VARIABLE SP-PLEN
CREATE SP-TYPE 80 ALLOT
VARIABLE SP-TLEN

: SP-DOT ( x y c -- )
  COLOR !
  PLOT ;

: SP-MOVE ( x-addr y-addr -- )
  DUP @ 3 RND 1- + G-PY SP-WRAP SWAP !
  @ 3 RND 1- + G-PX SP-WRAP SWAP ! ;

: SP-MATCH ( -- flag )
  SP-TLEN @ SP-PLEN @ <> IF FALSE EXIT THEN
  SP-TYPE SP-TLEN @ SP-PASS SP-PLEN @ COMPARE 0= ;

: SP-KEY ( c -- )
  SP-PLEN @ 0= IF
    DUP 27 = IF -1 SP-QUIT ! THEN
    DUP 83 = OVER 115 = OR IF
      SP-SNAKE @ 0= SP-SNAKE !
    THEN
    DUP 43 = IF SP-DELAY @ 1+ 20 MIN SP-DELAY ! THEN
    DUP 45 = IF SP-DELAY @ 1- 0 MAX SP-DELAY ! THEN
    DROP EXIT
  THEN
  DUP 13 = OVER 10 = OR IF
    DROP
    SP-MATCH IF -1 SP-QUIT ! THEN
    0 SP-TLEN !
    EXIT
  THEN
  DUP 27 = IF DROP 0 SP-TLEN ! EXIT THEN
  SP-TLEN @ 70 < IF
    SP-TYPE SP-TLEN @ + C!
    1 SP-TLEN +!
  ELSE
    DROP
  THEN ;

: SPLAT-GO ( -- )
  DECIMAL
  S" EditForth SPLAT" APP-NAME
  WINDOW PIXEL-ON COLOR8
  WHITE PCLS
  RANDOMIZE
  G-PX 2/ SP-X !   G-PY 2/ SP-Y !
  G-PX 2/ SP-EX !  G-PY 2/ 30 + SP-EY !
  -1 SP-SNAKE !
  0 SP-DELAY !
  0 SP-QUIT !
  0 SP-TLEN !
  BEGIN
    SP-QUIT @ 0=
  WHILE
    40 0 DO
      SP-X @ SP-Y @ 15 RND 1+ SP-DOT
      SP-X SP-Y SP-MOVE
      SP-SNAKE @ IF
        SP-EX @ SP-EY @ 0 SP-DOT
        SP-EX SP-EY SP-MOVE
      THEN
    LOOP
    PREFRESH
    SP-DELAY @ 0 DO PAUSE LOOP
    KEY? IF KEY SP-KEY THEN
  REPEAT
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

: SPLAT ( -- )
  SPLAT-CREDIT
  CR ." Password (empty line, then Enter, allows Esc to quit): "
  SP-PASS 60 ACCEPT SP-PLEN !
  SPLAT-GO
  ;

CR .( Run:  SPLAT ) CR
CR .( Emit: EMIT-WINDOW-APP SPLAT ) CR
