\ CARD.fth — small card file
\
\ Tom Zimmer's DOS card file kept 16 lines of 64 characters in each
\ record and edited them on the text screen. This copy keeps that
\ record and asks for commands on the console. The same words run in
\ EditForth and in EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/CARD.fth
\   CARD
\
\ Commands: N next, P previous, A add, G goto, F find, E edit,
\           W write, H help, Q quit.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW CARD_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

16 CONSTANT CD-LINES
64 CONSTANT CD-COLS
1024 CONSTANT CD-REC
200 CONSTANT CD-MAX

CREATE CD-BUF CD-MAX CD-REC * ALLOT
CREATE CD-PATH 300 ALLOT
CREATE CD-ASK 200 ALLOT
VARIABLE CD-PLEN
VARIABLE CD-N
VARIABLE CD-I
VARIABLE CD-DIRTY

: CD-ADDR ( n -- a ) CD-REC * CD-BUF + ;

: CD-BLANK ( n -- ) CD-ADDR CD-REC BLANK ;

: CD-LINE ( line -- a ) CD-COLS * CD-I @ CD-ADDR + ;

: CD-SHOW ( -- )
  CR ." Record " CD-I @ 1+ . ." of " CD-N @ . CR
  CD-LINES 0 DO
    CR I 2 .R SPACE
    I CD-LINE CD-COLS -TRAILING TYPE
  LOOP
  CR ;

: CD-HELP ( -- )
  CR ." N next   P previous   A add a record   G goto"
  CR ." F find   E edit a line   W write   H help   Q quit" CR ;

: CD-NUM ( c-addr u -- n flag )
  DUP 0= IF 2DROP 0 FALSE EXIT THEN
  0 SWAP 0 DO
    OVER I + C@
    DUP 48 58 WITHIN 0= IF DROP 2DROP DROP 0 FALSE UNLOOP EXIT THEN
    48 - SWAP 10 * +
  LOOP
  NIP TRUE ;

: CD-LOAD ( c-addr u -- flag )
  DUP CD-PLEN !
  CD-PATH SWAP CMOVE
  CD-BUF CD-MAX CD-REC * BLANK
  CD-PATH CD-PLEN @ R/O BIN OPEN-FILE IF DROP FALSE EXIT THEN
  >R
  R@ FILE-SIZE IF 2DROP R> CLOSE-FILE DROP FALSE EXIT THEN
  DROP
  CD-MAX CD-REC * MIN
  CD-BUF SWAP R@ READ-FILE
  R> CLOSE-FILE DROP
  IF DROP FALSE EXIT THEN
  CD-REC / DUP 0= IF DROP 1 THEN
  CD-MAX MIN CD-N !
  0 CD-I !  0 CD-DIRTY !  TRUE ;

: CD-NEW ( c-addr u -- )
  DUP CD-PLEN !
  CD-PATH SWAP CMOVE
  CD-BUF CD-MAX CD-REC * BLANK
  0 CD-BLANK
  1 CD-N !  0 CD-I !  -1 CD-DIRTY ! ;

: CD-SAVE ( -- )
  CD-PLEN @ 0= IF CR ." No file name yet." CR EXIT THEN
  CD-PATH CD-PLEN @ W/O BIN CREATE-FILE IF
    DROP CR ." Could not write that file." CR EXIT
  THEN
  >R
  CD-BUF CD-N @ CD-REC * R@ WRITE-FILE DROP
  R> CLOSE-FILE DROP
  0 CD-DIRTY !
  CR ." Wrote " CD-PATH CD-PLEN @ TYPE CR ;

: CD-EDIT ( -- )
  CR ." Line (1-16): "
  CD-ASK 10 ACCEPT
  CD-ASK SWAP CD-NUM 0= IF DROP CR ." Need a line number." CR EXIT THEN
  1- DUP 0 16 WITHIN 0= IF DROP CR ." Lines are 1 through 16." CR EXIT THEN
  >R
  CR ." Text: "
  CD-ASK 64 ACCEPT
  R@ CD-LINE CD-COLS BLANK
  CD-ASK R> CD-LINE ROT CMOVE
  -1 CD-DIRTY ! ;

: CD-FIND ( -- )
  CR ." Find: "
  CD-ASK 64 ACCEPT DUP 0= IF DROP EXIT THEN
  CD-ASK SWAP
  CD-N @ 0 DO
    2DUP I CD-ADDR CD-REC 2SWAP SEARCH IF
      2DROP 2DROP
      I CD-I !
      CR ." Found in record " I 1+ . CR
      CD-SHOW UNLOOP EXIT
    THEN
    2DROP
  LOOP
  2DROP
  CR ." Not found." CR ;

: CD-ADD ( -- )
  CD-N @ CD-MAX >= IF CR ." The card file is full." CR EXIT THEN
  CD-N @ CD-BLANK
  CD-N @ CD-I !
  1 CD-N +!
  -1 CD-DIRTY ! ;

: CD-GOTO ( -- )
  CR ." Record (1-" CD-N @ . ." ): "
  CD-ASK 10 ACCEPT
  CD-ASK SWAP CD-NUM 0= IF DROP EXIT THEN
  1- DUP 0 CD-N @ WITHIN IF CD-I ! ELSE DROP CR ." No such record." CR THEN ;

: CD-CMD ( c-addr u -- flag )
  DUP 0= IF 2DROP FALSE EXIT THEN
  OVER C@ 32 OR
  DUP 113 = IF DROP 2DROP TRUE EXIT THEN
  DUP 110 = IF DROP 2DROP
    CD-I @ 1+ CD-N @ < IF 1 CD-I +! THEN FALSE EXIT THEN
  DUP 112 = IF DROP 2DROP
    CD-I @ 0> IF -1 CD-I +! THEN FALSE EXIT THEN
  DUP 97 = IF DROP 2DROP CD-ADD FALSE EXIT THEN
  DUP 103 = IF DROP 2DROP CD-GOTO FALSE EXIT THEN
  DUP 102 = IF DROP 2DROP CD-FIND FALSE EXIT THEN
  DUP 101 = IF DROP 2DROP CD-EDIT FALSE EXIT THEN
  DUP 119 = IF DROP 2DROP CD-SAVE FALSE EXIT THEN
  DUP 104 = IF DROP 2DROP CD-HELP FALSE EXIT THEN
  DROP 2DROP CR ." Unknown command. H lists them." CR FALSE ;

: CARD ( -- )
  CR ." CARD keeps 16 lines of 64 characters in each record." CR
  CR ." File (new name is fine): "
  CD-ASK 240 ACCEPT DUP 0= IF DROP EXIT THEN
  CD-ASK SWAP 2DUP CD-LOAD 0= IF
    CR ." New file." CR
    CD-NEW
  ELSE
    2DROP
  THEN
  CD-HELP
  BEGIN
    CD-SHOW
    ." CARD> "
    CD-ASK 40 ACCEPT
    CD-ASK SWAP CD-CMD
  UNTIL
  CD-DIRTY @ IF
    CR ." Save changes? "
    CD-ASK 8 ACCEPT
    CD-ASK C@ 32 OR 121 = IF CD-SAVE THEN
  THEN
  CR ." CARD finished." CR ;

CR .( Run: CARD ) CR
