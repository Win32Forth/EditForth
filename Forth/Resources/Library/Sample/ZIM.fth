\ ZIM.fth — byte-token text squeeze
\
\ Tom Zimmer's ZIM compressor. The TCOM program used DOS handles and
\ 16-bit segment pointers. This copy uses OPEN-FILE and a fixed buffer.
\ Tokens stay on byte boundaries:
\
\   0 0           end of stream
\   0 1 n data    raw bytes, n is the count
\   1..16         that many spaces
\   17            end of line
\   18..127       a word that occurred more than once
\
\ The dictionary is stored at the front of the .zim file, after "ZIM1".
\
\ Load:
\   FROMLIB FLOAD Sample/ZIM.fth
\   ZIM
\   ZIM-EXPAND
\
\ ZIM writes name.zim. ZIM-EXPAND reads a .zim file and writes name.out.
\ Files longer than 48K are refused.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW ZIM_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

48000 CONSTANT ZIM-CAP
110 CONSTANT ZIM-N
32 CONSTANT ZIM-W

CREATE ZIM-IN ZIM-CAP ALLOT
VARIABLE ZIM-LEN
CREATE ZIM-OUT ZIM-CAP 2 * ALLOT
VARIABLE ZIM-OLEN
CREATE ZIM-WORDS ZIM-N ZIM-W * ALLOT
CREATE ZIM-USED ZIM-N CELLS ALLOT
VARIABLE ZIM-COUNT
VARIABLE ZIM-I
VARIABLE ZIM-MODE
CREATE ZIM-PATH 300 ALLOT
VARIABLE ZIM-PLEN

: ZIM-WORD ( n -- c-addr ) ZIM-W * ZIM-WORDS + ;
: ZIM-AT ( i -- c ) ZIM-IN + C@ ;

: ZIM-CLEAR ( -- )
  ZIM-N 0 DO 0 I CELLS ZIM-USED + ! LOOP
  0 ZIM-COUNT ! ;

: ZIM-SAME ( c-addr u n -- flag )
  ZIM-WORD COUNT
  2>R 2R@ COMPARE 0= 2R> 2DROP ;

: ZIM-FIND ( c-addr u -- n true | false )
  ZIM-COUNT @ 0 ?DO
    2DUP I ZIM-SAME IF 2DROP I TRUE UNLOOP EXIT THEN
  LOOP
  2DROP FALSE ;

: ZIM-NOTE ( c-addr u -- )
  DUP 0= OVER 31 > OR IF 2DROP EXIT THEN
  2DUP ZIM-FIND IF
    CELLS ZIM-USED + 1 SWAP +!
    2DROP
  ELSE
    ZIM-COUNT @ ZIM-N >= IF 2DROP EXIT THEN
    ZIM-COUNT @ ZIM-WORD >R
    DUP R@ C!
    R> 1+ SWAP CMOVE
    1 ZIM-COUNT @ CELLS ZIM-USED + !
    1 ZIM-COUNT +!
  THEN ;

: ZIM-EMIT ( c -- )
  ZIM-OLEN @ ZIM-CAP 2 * >= IF DROP EXIT THEN
  ZIM-OUT ZIM-OLEN @ + C!
  1 ZIM-OLEN +! ;

: ZIM-TYPE ( c-addr u -- )
  0 ?DO DUP I + C@ ZIM-EMIT LOOP DROP ;

: ZIM-RAW ( c-addr u -- )
  0 ZIM-EMIT 1 ZIM-EMIT
  255 MIN
  DUP ZIM-EMIT
  ZIM-TYPE ;

: ZIM-SPACES ( n -- )
  BEGIN DUP 0> WHILE
    DUP 16 MIN DUP ZIM-EMIT -
  REPEAT DROP ;

: ZIM-PUT ( c-addr u -- )
  2DUP ZIM-FIND IF
    DUP CELLS ZIM-USED + @ 1 > IF
      NIP NIP 18 + ZIM-EMIT
    ELSE
      DROP ZIM-RAW
    THEN
  ELSE
    ZIM-RAW
  THEN ;

: ZIM-ON-WORD ( c-addr u -- )
  ZIM-MODE @ IF ZIM-PUT ELSE ZIM-NOTE THEN ;

: ZIM-ON-SPACES ( n -- )
  ZIM-MODE @ IF ZIM-SPACES ELSE DROP THEN ;

: ZIM-ON-NL ( -- )
  ZIM-MODE @ IF 17 ZIM-EMIT THEN ;

: ZIM-WALK ( -- )
  0 ZIM-I !
  BEGIN
    ZIM-I @ ZIM-LEN @ <
  WHILE
    ZIM-I @ ZIM-AT
    DUP 32 = IF
      DROP
      ZIM-I @
      BEGIN
        ZIM-I @ ZIM-LEN @ <
        ZIM-I @ ZIM-AT 32 = AND
      WHILE
        1 ZIM-I +!
      REPEAT
      ZIM-I @ SWAP - ZIM-ON-SPACES
    ELSE DUP 10 = OVER 13 = OR IF
      DROP
      1 ZIM-I +!
      ZIM-I @ ZIM-LEN @ < IF
        ZIM-I @ ZIM-AT 10 = IF 1 ZIM-I +! THEN
      THEN
      ZIM-ON-NL
    ELSE
      DROP
      ZIM-I @
      BEGIN
        ZIM-I @ ZIM-LEN @ <
        ZIM-I @ ZIM-AT 32 <> AND
        ZIM-I @ ZIM-AT 10 <> AND
        ZIM-I @ ZIM-AT 13 <> AND
      WHILE
        1 ZIM-I +!
      REPEAT
      ZIM-I @ OVER - >R
      ZIM-IN + R> ZIM-ON-WORD
    THEN
    THEN
  REPEAT ;

: ZIM-HEADER ( -- )
  0 ZIM-OLEN !
  S" ZIM1" ZIM-TYPE
  ZIM-COUNT @ ZIM-EMIT
  ZIM-COUNT @ 0 DO
    I ZIM-WORD COUNT
    DUP ZIM-EMIT
    ZIM-TYPE
  LOOP ;

: ZIM-SLURP ( c-addr u -- flag )
  R/O BIN OPEN-FILE IF DROP FALSE EXIT THEN
  >R
  ZIM-IN ZIM-CAP R@ READ-FILE
  R> CLOSE-FILE DROP
  IF DROP FALSE EXIT THEN
  DUP ZIM-CAP >= IF DROP FALSE EXIT THEN
  ZIM-LEN ! TRUE ;

: ZIM-SUFFIX ( c-addr u c-addr2 u2 -- c-addr3 u3 )
  2>R
  240 MIN DUP ZIM-PLEN !
  ZIM-PATH SWAP CMOVE
  2R> ZIM-PATH ZIM-PLEN @ + SWAP DUP >R CMOVE
  R> ZIM-PLEN +!
  ZIM-PATH ZIM-PLEN @ ;

: ZIM-SPEW ( c-addr u -- flag )
  W/O BIN CREATE-FILE IF DROP FALSE EXIT THEN
  >R
  ZIM-OUT ZIM-OLEN @ R@ WRITE-FILE
  R> CLOSE-FILE DROP
  0= ;

: ZIM-LOAD-DICT ( -- flag )
  ZIM-LEN @ 5 < IF FALSE EXIT THEN
  ZIM-IN 4 S" ZIM1" COMPARE IF FALSE EXIT THEN
  4 ZIM-AT ZIM-COUNT !
  ZIM-COUNT @ ZIM-N > IF FALSE EXIT THEN
  5 ZIM-I !
  ZIM-COUNT @ 0 DO
    ZIM-I @ ZIM-LEN @ >= IF UNLOOP FALSE EXIT THEN
    ZIM-I @ ZIM-AT DUP 31 > IF DROP UNLOOP FALSE EXIT THEN
    1 ZIM-I +!
    DUP ZIM-I @ + ZIM-LEN @ > IF DROP UNLOOP FALSE EXIT THEN
    I ZIM-WORD
    2DUP C!
    1+
    ZIM-IN ZIM-I @ +
    SWAP ROT
    DUP >R
    CMOVE
    R> ZIM-I +!
  LOOP
  TRUE ;

: ZIM-EXPAND-BYTES ( -- )
  0 ZIM-OLEN !
  BEGIN
    ZIM-I @ ZIM-LEN @ <
  WHILE
    ZIM-I @ ZIM-AT 1 ZIM-I +!
    DUP 0= IF
      DROP
      ZIM-I @ ZIM-LEN @ >= IF EXIT THEN
      ZIM-I @ ZIM-AT 1 ZIM-I +!
      DUP 0= IF DROP EXIT THEN
      1 = IF
        ZIM-I @ ZIM-LEN @ >= IF EXIT THEN
        ZIM-I @ ZIM-AT 1 ZIM-I +!
        0 DO
          ZIM-I @ ZIM-LEN @ >= IF LEAVE THEN
          ZIM-I @ ZIM-AT ZIM-EMIT
          1 ZIM-I +!
        LOOP
      THEN
    ELSE DUP 17 < IF
      0 DO 32 ZIM-EMIT LOOP
    ELSE DUP 17 = IF
      DROP 10 ZIM-EMIT
    ELSE
      18 -
      DUP 0 ZIM-COUNT @ WITHIN IF
        ZIM-WORD COUNT ZIM-TYPE
      ELSE
        DROP
      THEN
    THEN THEN THEN
  REPEAT ;

: ZIM ( -- )
  CR ." ZIM writes name.zim" CR
  CR ." File: "
  PAD 200 ACCEPT DUP 0= IF DROP EXIT THEN
  PAD SWAP 2DUP ZIM-SLURP 0= IF
    2DROP CR ." Could not read that file, or it is longer than 48K." CR EXIT
  THEN
  ZIM-CLEAR
  0 ZIM-MODE !
  ZIM-WALK
  ZIM-HEADER
  1 ZIM-MODE !
  ZIM-WALK
  0 ZIM-EMIT 0 ZIM-EMIT
  S" .zim" ZIM-SUFFIX ZIM-SPEW 0= IF
    CR ." Could not write the .zim file." CR EXIT
  THEN
  CR ." Wrote " ZIM-PATH ZIM-PLEN @ TYPE
  ."  (" ZIM-LEN @ . ." bytes -> " ZIM-OLEN @ . ." bytes)" CR ;

: ZIM-EXPAND ( -- )
  CR ." ZIM-EXPAND writes name.out" CR
  CR ." File: "
  PAD 200 ACCEPT DUP 0= IF DROP EXIT THEN
  PAD SWAP 2DUP ZIM-SLURP 0= IF
    2DROP CR ." Could not read that file." CR EXIT
  THEN
  ZIM-LOAD-DICT 0= IF
    2DROP CR ." That is not a ZIM1 file." CR EXIT
  THEN
  ZIM-EXPAND-BYTES
  S" .out" ZIM-SUFFIX ZIM-SPEW 0= IF
    CR ." Could not write the .out file." CR EXIT
  THEN
  CR ." Wrote " ZIM-PATH ZIM-PLEN @ TYPE CR ;

CR .( Run: ZIM  or  ZIM-EXPAND ) CR
