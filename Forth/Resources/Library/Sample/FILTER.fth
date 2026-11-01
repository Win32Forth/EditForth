\ FILTER.fth — copy a file through a control-character table
\
\ Tom Zimmer. The DOS program was a stdin/stdout filter (FILTER <in >out).
\ EditForth has no redirected standard input, and EditForthPWA is a
\ browser, so this copy asks for an input file and an output file.
\
\ Tab (9) becomes eight spaces. CR or LF becomes one LF. A CR LF pair
\ is one line. Control-Z ends the file. Other bytes below 32 are
\ dropped. Bytes from 32 up are copied.
\
\ Load:
\   FROMLIB FLOAD Sample/FILTER.fth
\   FILTER
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW FILTER_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

CREATE FI-IN 4096 ALLOT
CREATE FI-OUT 8192 ALLOT
CREATE FI-PATH 512 ALLOT
VARIABLE FI-OLEN
VARIABLE FI-ID
VARIABLE FI-CR
VARIABLE FI-STOP

: FI-FLUSH ( -- )
  FI-OLEN @ 0= IF EXIT THEN
  FI-OUT FI-OLEN @ FI-ID @ WRITE-FILE DROP
  0 FI-OLEN ! ;

: FI-EMIT ( c -- )
  FI-OLEN @ 8000 > IF FI-FLUSH THEN
  FI-OUT FI-OLEN @ + C!
  1 FI-OLEN +! ;

: FI-SPACES ( n -- )
  0 ?DO 32 FI-EMIT LOOP ;

: FI-BYTE ( c -- flag )
  DUP 26 = IF DROP FALSE EXIT THEN
  DUP 32 < IF
    DUP 9 = IF DROP 8 FI-SPACES TRUE EXIT THEN
    DUP 13 = IF DROP -1 FI-CR ! TRUE EXIT THEN
    DUP 10 = IF
      DROP
      10 FI-EMIT
      0 FI-CR !
      TRUE EXIT
    THEN
    DROP 0 FI-CR ! TRUE EXIT
  THEN
  FI-CR @ IF 10 FI-EMIT 0 FI-CR ! THEN
  FI-EMIT TRUE ;

: FI-CHUNK ( u -- )
  0 DO
    FI-STOP @ IF LEAVE THEN
    FI-IN I + C@ FI-BYTE 0= IF -1 FI-STOP ! LEAVE THEN
  LOOP ;

: FI-GO ( c-addr u c-addr2 u2 -- )
  2SWAP R/O BIN OPEN-FILE IF
    DROP 2DROP CR ." Could not open the input file." CR EXIT
  THEN
  >R
  W/O BIN CREATE-FILE IF
    DROP R> CLOSE-FILE DROP
    CR ." Could not create the output file." CR EXIT
  THEN
  FI-ID !
  0 FI-OLEN !  0 FI-CR !  0 FI-STOP !
  BEGIN
    FI-STOP @ 0=
  WHILE
    FI-IN 4096 R@ READ-FILE
    ?DUP IF
      DROP DROP
      -1 FI-STOP !
    ELSE
      DUP 0= IF
        DROP
        -1 FI-STOP !
      ELSE
        FI-CHUNK
      THEN
    THEN
  REPEAT
  FI-CR @ IF 10 FI-EMIT THEN
  FI-FLUSH
  FI-ID @ CLOSE-FILE DROP
  R> CLOSE-FILE DROP
  CR ." FILTER finished." CR ;

: FILTER ( -- )
  CR ." FILTER copies a file and tidies control characters." CR
  CR ." Input file: "
  FI-PATH 240 ACCEPT DUP 0= IF DROP EXIT THEN
  FI-PATH SWAP
  CR ." Output file: "
  FI-PATH 256 + 240 ACCEPT DUP 0= IF DROP 2DROP EXIT THEN
  FI-PATH 256 + SWAP
  FI-GO ;

CR .( Run: FILTER ) CR
