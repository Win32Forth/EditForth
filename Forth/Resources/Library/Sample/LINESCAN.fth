\ LINESCAN.fth — several short lines crawling on the window
\
\ Port of TCOM LINESCAN.FTH (Tom Zimmer, public domain). The DOS program
\ kept a swap buffer of line ends and read a count from the command tail.
\ This copy keeps up to 64 lines in cells. + adds a line, - removes one.
\ It runs on EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/LINESCAN.fth
\   LINESCAN
\
\ Click the graphics window. + and - change how many lines crawl.
\ Esc returns to the console.
\
\ Public domain.

EMIT-NO-WRAPPER

ONLY FORTH DEFINITIONS
DECIMAL

: LINESCAN-CREDIT ( -- )
  CR ." LINESCAN crawls colored lines around the window."
  CR ." + adds a line (up to 64). - removes one. Esc returns to the console." CR
  ;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

64 CONSTANT LS-MAX

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

CREATE LS-X  LS-MAX CELLS ALLOT
CREATE LS-Y  LS-MAX CELLS ALLOT
CREATE LS-DX LS-MAX CELLS ALLOT
CREATE LS-DY LS-MAX CELLS ALLOT
CREATE LS-C  LS-MAX CELLS ALLOT
VARIABLE LS-N
VARIABLE LS-OX
VARIABLE LS-OY
VARIABLE LS-QUIT

: LS-DELTA ( -- n )
  BEGIN 2 RND 2 RND - ?DUP UNTIL ;

: LS-INIT ( i -- )
  >R
  G-PX RND  R@ CELLS LS-X + !
  G-PY RND  R@ CELLS LS-Y + !
  LS-DELTA  R@ CELLS LS-DX + !
  LS-DELTA  R@ CELLS LS-DY + !
  15 RND 1+ R> CELLS LS-C + ! ;

: LS-ONE ( i -- )
  >R
  R@ CELLS LS-X + @ LS-OX !
  R@ CELLS LS-Y + @ LS-OY !
  LS-OX @  R@ CELLS LS-DX + @  G-PX CLAMP-STEP
  R@ CELLS LS-DX + !  R@ CELLS LS-X + !
  LS-OY @  R@ CELLS LS-DY + @  G-PY CLAMP-STEP
  R@ CELLS LS-DY + !  R@ CELLS LS-Y + !
  R@ CELLS LS-C + @ COLOR !
  LS-OX @ LS-OY @
  R@ CELLS LS-X + @
  R> CELLS LS-Y + @
  LINE ;

: LS-KEY ( c -- )
  DUP 43 = IF
    DROP
    LS-N @ LS-MAX < IF
      LS-N @ LS-INIT
      1 LS-N +!
    THEN
    EXIT
  THEN
  DUP 45 = IF
    DROP
    LS-N @ 1 > IF -1 LS-N +! THEN
    EXIT
  THEN
  27 = IF -1 LS-QUIT ! THEN ;

: LINESCAN ( -- )
  DECIMAL
  S" EditForth LINESCAN" APP-NAME
  WINDOW PIXEL-ON COLOR8
  WHITE PCLS
  RANDOMIZE
  0 LS-QUIT !
  8 0 DO I LS-INIT LOOP
  8 LS-N !
  BEGIN
    LS-QUIT @ 0=
  WHILE
    LS-N @ 0 DO I LS-ONE LOOP
    PREFRESH
    KEY? IF KEY LS-KEY THEN
  REPEAT
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

LINESCAN-CREDIT
CR .( Run:  LINESCAN ) CR
CR .( Emit: EMIT-WINDOW-APP LINESCAN ) CR
