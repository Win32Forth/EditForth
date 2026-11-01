\ OBJECT.fth — Rick Hoselton objects for EditForth and EditForthPWA
\
\ From Forth Dimensions, Volume 10 Number 2, adapted for F-PC by Tom Zimmer.
\ This is not Classes/classes.fth (Win32Forth :CLASS / :M) and it does not
\ use the OOP window host. Links are one cell wide, so the same source
\ runs on a 32-bit or a 64-bit Forth.
\
\ A method ends with ;M. The original listing ended methods with ; inside
\ its own compiler. ;M is that semicolon.
\
\ Load:
\   FROMLIB FLOAD Sample/OBJECT.fth
\   OBJECT-DEMO
\
\ The demo builds the vehicle and automobile examples from the end of the
\ TCOM listing. green-monster and queen-mary inherit a wheel count.
\ racer and slow-poke share drive and fill-gas. slow-poke replaces
\ tell-gas. racer still reports its tank.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW OBJECT_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

VARIABLE CURRENT-OBJ
VARIABLE PENDING-OBJ
VARIABLE PENDING-ID

: ME ( -- obj ) CURRENT-OBJ @ ;
: >OBJECT ( n -- addr ) ME + ;
: >SUPER ( n -- addr ) ME @ + ;

\ id is on the return stack. Walk this object, then its father.
: SEND ( id -- )
  >R
  CURRENT-OBJ @
  BEGIN
    DUP 0= IF
      R> 2DROP ." I don't understand" CR EXIT
    THEN
    DUP 3 CELLS + @
    BEGIN
      DUP
    WHILE
      DUP CELL+ @ R@ = IF
        R> DROP NIP
        2 CELLS + @ EXECUTE
        EXIT
      THEN
      @
    REPEAT
    DROP
    @
  AGAIN ;

\ MESSAGE parses a name. Its body address is the selector id.
\ Code after DOES> would belong to the new word, so the id is read below.
: MESSAGE ( "name" -- )
  CREATE
  DOES> ( obj id -- )
    SWAP CURRENT-OBJ !
    SEND ;

: METHOD: ( obj "name" -- )
  PENDING-OBJ !
  >IN @ >R
  BL WORD FIND ?DUP IF
    DROP >BODY PENDING-ID !
    R> DROP
  ELSE
    DROP
    R> >IN !
    >IN @ >R
    MESSAGE
    R> >IN !
    BL WORD FIND 0= ABORT" OBJECT: message was not created"
    >BODY PENDING-ID !
  THEN
  :NONAME ;

\ Lay down next, id, xt. HERE has moved three cells, so that node
\ becomes this object's method list. The father's list is left alone.
: LINK-METHOD ( xt id obj -- )
  >R
  R@ 3 CELLS + @ ,
  , ,
  HERE 3 CELLS -
  R> 3 CELLS + ! ;

: ;M ( C: colon-sys -- )
  POSTPONE ;
  PENDING-ID @ PENDING-OBJ @ LINK-METHOD
; IMMEDIATE

\ Child object. Cells: father, youngest son, next brother, method list.
: (OBJECT:) ( father "name" -- )
  CREATE
    HERE >R
    DUP ,
    0 ,
    DUP CELL+ @ ,
    DUP 3 CELLS + @ ,
    R> SWAP CELL+ !
  DOES> ( -- obj ) ;

CREATE MASTER
  0 , 0 , 0 , 0 ,

MASTER METHOD: object: ( "name" -- )
  ME (OBJECT:)
;M

\ ----- Vehicle example ----------------------------------------------------

MASTER object: vehicle

vehicle METHOD: #wheels ( -- n )
  4 CELLS >SUPER @
;M

vehicle object: boat       0 ,
vehicle object: car        4 ,
vehicle object: tricycle   3 ,

car object: green-monster
boat object: queen-mary

\ ----- Automobile example -------------------------------------------------

MASTER object: automobile

automobile METHOD: object: ( n "name" -- )
  ME (OBJECT:)
  0 ,                 \ 4 odometer
  0 ,                 \ 5 odometer at last fill
  0 ,                 \ 6 gallons in the tank
  ,                   \ 7 miles per gallon
;M

automobile METHOD: drive ( n -- )
  7 CELLS >OBJECT @ 1 MAX >R
  6 CELLS >OBJECT @ R@ *
  MIN
  DUP 4 CELLS >OBJECT +!
  DUP R> / NEGATE 6 CELLS >OBJECT +!
  ." I'm driving " . ." miles " CR
;M

automobile METHOD: tell-gas ( -- )
  CR ." I have " 6 CELLS >OBJECT @ . ." gallons in my tank" CR
;M

automobile METHOD: fill-gas ( n -- )
  6 CELLS >OBJECT +!
  ME tell-gas
;M

 7 automobile object: racer
23 automobile object: slow-poke

slow-poke METHOD: tell-gas ( -- )
  CR ." It's a secret!" CR
;M

: OBJECT-DEMO ( -- )
  CR ." green-monster wheels = " green-monster #wheels . CR
  CR ." queen-mary wheels = " queen-mary #wheels . CR
  18 racer fill-gas
  100 racer drive
  racer tell-gas
  slow-poke tell-gas
;

CR .( Run: OBJECT-DEMO ) CR
.( green-monster #wheels .   racer tell-gas   slow-poke tell-gas ) CR
