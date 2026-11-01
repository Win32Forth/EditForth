\ LOOK.fth — search text files from the EditForth console
\
\ Tom Zimmer's LOOK scanned DOS directories and could redirect the hits.
\ DIR lists the working folder here. Type one file name per line.
\ CHDIR changes the working folder. Each name is searched when you
\ press Return. A blank line finishes.
\ Space pauses. Esc stops. The match is case-sensitive.
\
\ Load:
\   FROMLIB FLOAD Sample/LOOK.fth
\   LOOK
\
\ See LOOK.txt for the old DOS command lines this replaces.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW LOOK_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

CREATE LOOK-FIND 128 ALLOT
VARIABLE LOOK-FLEN
CREATE LOOK-NAME 256 ALLOT
VARIABLE LOOK-NLEN
CREATE LOOK-LINE 240 ALLOT
VARIABLE LOOK-STOP

: LOOK-PAUSE ( -- flag )
  KEY? 0= IF FALSE EXIT THEN
  KEY DUP 27 = IF DROP TRUE EXIT THEN
  32 = IF
    BEGIN KEY DUP 27 = IF DROP TRUE EXIT THEN 32 <> UNTIL
  THEN
  FALSE ;

: LOOK-HIT ( len n -- )
  CR LOOK-NAME LOOK-NLEN @ TYPE ." :" .
  LOOK-LINE SWAP TYPE
  LOOK-PAUSE LOOK-STOP ! ;

: LOOK-FILE ( c-addr u -- )
  200 MIN DUP LOOK-NLEN !
  LOOK-NAME SWAP CMOVE
  LOOK-NAME LOOK-NLEN @ R/O OPEN-FILE IF
    DROP CR ." Could not open " LOOK-NAME LOOK-NLEN @ TYPE CR
    EXIT
  THEN
  >R
  0
  BEGIN
    LOOK-STOP @ 0=
  WHILE
    LOOK-LINE 240 R@ READ-LINE
    ?DUP IF
      DROP 2DROP DROP
      R> CLOSE-FILE DROP
      -1 LOOK-STOP !
      EXIT
    THEN
    0= IF
      DROP DROP
      R> CLOSE-FILE DROP
      EXIT
    THEN
    >R
    1+
    LOOK-LINE R@ LOOK-FIND LOOK-FLEN @ SEARCH NIP NIP IF
      R> OVER LOOK-HIT
    ELSE
      R> DROP
    THEN
  REPEAT
  DROP
  R> CLOSE-FILE DROP ;

: LOOK ( -- )
  0 LOOK-STOP !
  CR ." LOOK searches the files you name. DIR lists this folder." CR
  CR ." Text: "
  LOOK-FIND 120 ACCEPT DUP 0= IF
    DROP CR ." Nothing to find." CR EXIT
  THEN
  LOOK-FLEN !
  CR ." One file per line. A blank line finishes." CR
  BEGIN
    LOOK-STOP @ 0=
  WHILE
    CR ." File: "
    PAD 200 ACCEPT DUP
  WHILE
    PAD SWAP LOOK-FILE
  REPEAT
  DROP
  THEN
  CR ." LOOK finished." CR ;

CR .( Run: LOOK ) CR
