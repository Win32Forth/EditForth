\ SPREAD.fth — a small spreadsheet for EditForth and EditForthPWA
\
\ Craig A. Lindley, Forth Dimensions Volume 7 Numbers 1 and 2 (1985).
\ Typed for F-PC by Tom Zimmer, 05/17/89.
\ The DOS program compiled formulas into F83 code and used a 6-byte cell.
\ This copy keeps a counted formula of at most 31 characters and an
\ integer result in each of 26 by 26 cells.
\
\ A formula is an integer, a cell such as A1 or Z26, or those pieces
\ joined by + - * / from left to right. A1+B1*2 is (A1+B1)*2.
\ A cell that names itself counts as 0. Other cells use the value from
\ the previous pass. Four passes settle a forward reference.
\ A circular reference changes on each of those passes and then stops.
\
\ Arrows move. Enter edits the formula. Backspace clears the cell.
\ Esc returns to the console.
\
\ Load:
\   FROMLIB FLOAD Sample/SPREAD.fth
\   SPREAD
\
\ Public domain.

[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]
[DEFINED] ANEW [IF] ANEW SPREAD_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

: SPREAD-CREDIT ( -- )
  CR ." SPREAD is a 26 by 26 sheet. Formulas use integers, A1..Z26,"
  CR ." and + - * / from left to right. Esc returns to the console." CR
  ;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

32 CONSTANT SP-TMAX
26 CONSTANT SP-N
6 CONSTANT SP-VW
16 CONSTANT SP-VH

CREATE SP-CELLS  26 26 * 32 1 CELLS + * ALLOT

VARIABLE SP-CC
VARIABLE SP-CR
VARIABLE SP-VC
VARIABLE SP-VR
VARIABLE SP-PC
VARIABLE SP-PEND
VARIABLE SP-FORM
VARIABLE SP-CC2
VARIABLE SP-CR2
VARIABLE SP-EDN
CREATE SP-ED 40 ALLOT
VARIABLE SP-EP
VARIABLE SP-EDIT?
VARIABLE SP-QUIT

: SP-ABS ( n -- u )
  DUP 0< IF NEGATE THEN ;

: SP.R ( n width -- )
  >R
  DUP SP-ABS 0 <# #S ROT SIGN #>
  R> OVER - 0 MAX 0 ?DO 32 EMIT LOOP
  TYPE ;

: SP-ADDR ( col row -- a )
  SP-N * +  SP-TMAX 1 CELLS + *  SP-CELLS + ;

: SP-CACHE ( col row -- a )
  SP-ADDR SP-TMAX + ;

: SP-SKIP ( -- )
  BEGIN
    SP-PC @ SP-PEND @ <
    SP-FORM @ SP-PC @ + C@ BL = AND
  WHILE
    1 SP-PC +!
  REPEAT ;

: SP-DIGIT? ( -- flag )
  SP-PC @ SP-PEND @ >= IF FALSE EXIT THEN
  SP-FORM @ SP-PC @ + C@
  [CHAR] 0 [CHAR] 9 1+ WITHIN ;

: SP-NUM ( -- n )
  SP-PC @ SP-PEND @ <
  SP-FORM @ SP-PC @ + C@ [CHAR] - = AND IF
    1 SP-PC +! -1
  ELSE
    1
  THEN
  >R  0
  BEGIN SP-DIGIT? WHILE
    10 *
    SP-FORM @ SP-PC @ + C@ [CHAR] 0 - +
    1 SP-PC +!
  REPEAT
  R> * ;

: SP-OP? ( c -- flag )
  DUP [CHAR] + =
  OVER [CHAR] - = OR
  OVER [CHAR] * = OR
  SWAP [CHAR] / = OR ;

: SP-TERM ( -- n )
  SP-SKIP
  SP-PC @ SP-PEND @ >= IF 0 EXIT THEN
  SP-FORM @ SP-PC @ + C@
  DUP [CHAR] a [CHAR] z 1+ WITHIN IF 32 - THEN
  DUP [CHAR] A [CHAR] Z 1+ WITHIN IF
    [CHAR] A - >R
    1 SP-PC +!
    0
    BEGIN SP-DIGIT? WHILE
      10 *
      SP-FORM @ SP-PC @ + C@ [CHAR] 0 - +
      1 SP-PC +!
    REPEAT
    1-
    DUP 0 SP-N WITHIN IF
      R> SWAP
      OVER SP-CC2 @ =
      OVER SP-CR2 @ = AND IF
        2DROP 0
      ELSE
        SP-CACHE @
      THEN
    ELSE
      R> DROP DROP 0
    THEN
  ELSE
    DROP SP-NUM
  THEN ;

: SP-OP ( n c -- n2 )
  CASE
    [CHAR] + OF SP-TERM + ENDOF
    [CHAR] - OF SP-TERM - ENDOF
    [CHAR] * OF SP-TERM * ENDOF
    [CHAR] / OF SP-TERM DUP 0= IF DROP 1 THEN / ENDOF
    DROP
  ENDCASE ;

: SP-EXPR ( -- n )
  SP-TERM
  BEGIN
    SP-SKIP
    SP-PC @ SP-PEND @ <
  WHILE
    SP-FORM @ SP-PC @ + C@
    DUP SP-OP? IF
      1 SP-PC +!
      SP-OP
    ELSE
      DROP EXIT
    THEN
  REPEAT ;

: SP-ONE ( col row -- )
  2DUP SP-CR2 ! SP-CC2 !
  SP-ADDR >R
  R@ C@ 0= IF
    0
  ELSE
    R@ 1+ SP-FORM !
    R@ C@ SP-PEND !
    0 SP-PC !
    SP-EXPR
  THEN
  R> SP-TMAX + ! ;

: SP-RECALC ( -- )
  4 0 DO
    SP-N 0 DO
      SP-N 0 DO
        I J SP-ONE
      LOOP
    LOOP
  LOOP ;

: SP-REVEAL ( -- )
  SP-CC @ SP-VC @ < IF SP-CC @ SP-VC ! THEN
  SP-CC @ SP-VC @ SP-VW + >= IF
    SP-CC @ SP-VW 1- - 0 MAX SP-VC !
  THEN
  SP-CR @ SP-VR @ < IF SP-CR @ SP-VR ! THEN
  SP-CR @ SP-VR @ SP-VH + >= IF
    SP-CR @ SP-VH 1- - 0 MAX SP-VR !
  THEN ;

: SP-CLEAR-CELL ( -- )
  SP-CC @ SP-CR @ SP-ADDR 0 OVER C!
  SP-TMAX + 0 SWAP !
  SP-RECALC ;

: SP-STORE ( -- )
  SP-EDN @ 31 MIN SP-EDN !
  SP-CC @ SP-CR @ SP-ADDR >R
  SP-EDN @ R@ C!
  SP-ED R@ 1+ SP-EDN @ CMOVE
  R> DROP
  SP-RECALC ;

: SP-HERE? ( col row -- flag )
  2DUP SP-CR @ = >R
  SP-CC @ = R> AND ;

: SP-SHOW ( col row -- )
  2DUP SP-HERE? IF CYELLOW ELSE CWHITE THEN COLOR !
  2DUP SP-ADDR C@ 0= IF
    DROP 2DROP 8 0 ?DO 32 EMIT LOOP
  ELSE
    DROP SP-CACHE @ 8 SP.R
  THEN ;

: SP-DRAW ( -- )
  WHITE PCLS
  CWHITE COLOR !
  0 0 AT ." SPREAD   arrows move   Enter edits   Backspace clears   Esc quits"
  0 2 AT ."    "
  SP-VW 0 DO
    SP-VC @ I + DUP SP-N < IF
      [CHAR] A + EMIT 7 0 ?DO 32 EMIT LOOP
    ELSE
      DROP
    THEN
  LOOP
  SP-VH 0 DO
    SP-VR @ I + DUP SP-N < IF
      0 I 3 + AT
      DUP 1+ 3 SP.R
      SP-VW 0 DO
        SP-VC @ I + DUP SP-N < IF
          SP-VR @ J + SP-SHOW
        ELSE
          DROP
        THEN
      LOOP
      DROP
    ELSE
      DROP
    THEN
  LOOP
  CWHITE COLOR !
  0 22 AT ." > "
  SP-EDIT? @ IF
    SP-ED SP-EDN @ TYPE
    0 23 AT 32 EMIT 32 EMIT
    SP-EP @ 0 ?DO 32 EMIT LOOP
    ." ^"
  ELSE
    SP-CC @ [CHAR] A + EMIT
    SP-CR @ 1+ 0 SP.R
    32 EMIT
    SP-CC @ SP-CR @ SP-ADDR COUNT TYPE
  THEN ;

: SP-BEGIN ( -- )
  SP-CC @ SP-CR @ SP-ADDR
  DUP 1+ SWAP C@ 31 MIN
  DUP SP-EDN ! DUP SP-EP !
  SP-ED SWAP CMOVE
  -1 SP-EDIT? ! ;

: SP-EINS ( c -- )
  SP-EDN @ 31 >= IF DROP EXIT THEN
  SP-EDN @ 1-
  BEGIN DUP SP-EP @ 1- > WHILE
    DUP SP-ED + C@ OVER 1+ SP-ED + C! 1-
  REPEAT DROP
  1 SP-EDN +!
  SP-ED SP-EP @ + C!
  1 SP-EP +! ;

: SP-EBS ( -- )
  SP-EP @ 0= IF EXIT THEN
  -1 SP-EP +!
  SP-ED SP-EP @ + 1+
  SP-ED SP-EP @ +
  SP-EDN @ SP-EP @ - 1-
  DUP 0> IF CMOVE ELSE DROP DROP DROP THEN
  SP-EDN @ 1- 0 MAX SP-EDN ! ;

: SP-EKEY ( c -- )
  DUP 27 = IF DROP 0 SP-EDIT? ! EXIT THEN
  DUP 13 = OVER 10 = OR IF DROP SP-STORE 0 SP-EDIT? ! EXIT THEN
  DUP 203 = IF DROP SP-EP @ 1- 0 MAX SP-EP ! EXIT THEN
  DUP 205 = IF DROP SP-EP @ 1+ SP-EDN @ MIN SP-EP ! EXIT THEN
  DUP 8 = OVER 127 = OR IF DROP SP-EBS EXIT THEN
  DUP BL 127 WITHIN IF SP-EINS EXIT THEN
  DROP ;

: SP-MKEY ( c -- )
  DUP 27 = IF DROP -1 SP-QUIT ! EXIT THEN
  DUP 200 = IF DROP SP-CR @ 1- 0 MAX SP-CR ! EXIT THEN
  DUP 208 = IF DROP SP-CR @ 1+ SP-N 1- MIN SP-CR ! EXIT THEN
  DUP 203 = IF DROP SP-CC @ 1- 0 MAX SP-CC ! EXIT THEN
  DUP 205 = IF DROP SP-CC @ 1+ SP-N 1- MIN SP-CC ! EXIT THEN
  DUP 13 = OVER 10 = OR IF DROP SP-BEGIN EXIT THEN
  DUP 8 = OVER 127 = OR IF DROP SP-CLEAR-CELL EXIT THEN
  DROP ;

: SPREAD ( -- )
  SP-CELLS SP-N SP-N * SP-TMAX 1 CELLS + * ERASE
  0 SP-CC !  0 SP-CR !  0 SP-VC !  0 SP-VR !
  0 SP-EDIT? !  0 SP-QUIT !
  S" EditForth SPREAD" APP-NAME
  WINDOW PIXEL-ON COLOR8
  BEGIN
    SP-REVEAL
    SP-DRAW
    PREFRESH
    KEY
    SP-EDIT? @ IF SP-EKEY ELSE SP-MKEY THEN
    SP-QUIT @
  UNTIL
  1BIT
  WINDOW-OFF ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

SPREAD-CREDIT
CR .( Run:  SPREAD ) CR
