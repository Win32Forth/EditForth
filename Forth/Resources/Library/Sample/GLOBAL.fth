\ GLOBAL.fth — replace text in one file
\
\ Tom Zimmer's GLOBAL edited a DOS file list in place. This copy asks
\ for the search text, the replacement, and one file. It writes
\ name.new and leaves the original in place.
\
\ Load:
\   FROMLIB FLOAD Sample/GLOBAL.fth
\   GLOBAL
\
\ On each matching line: Y replace, N skip, A replace the rest, Esc stop.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW GLOBAL_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

CREATE G-FIND 128 ALLOT
VARIABLE G-FLEN
CREATE G-REPL 128 ALLOT
VARIABLE G-RLEN
CREATE G-NAME 256 ALLOT
VARIABLE G-NLEN
CREATE G-LINE 300 ALLOT
CREATE G-WORK 300 ALLOT
VARIABLE G-LEN
VARIABLE G-I
VARIABLE G-OLEN
VARIABLE G-ALL
VARIABLE G-YES
VARIABLE G-STOP
VARIABLE G-IN
VARIABLE G-OUT

: G-APPEND ( c-addr u -- )
  DUP G-OLEN @ + 300 > IF 2DROP EXIT THEN
  G-WORK G-OLEN @ + SWAP DUP >R CMOVE
  R> G-OLEN +! ;

: G-REPLACE-LINE ( -- )
  0 G-I !  0 G-OLEN !
  BEGIN
    G-I @ G-LEN @ <
  WHILE
    G-LINE G-I @ +
    G-LEN @ G-I @ -
    G-FIND G-FLEN @
    SEARCH
    IF
      DROP >R
      G-LINE G-I @ +
      R@ G-LINE - G-I @ -
      G-APPEND
      G-REPL G-RLEN @ G-APPEND
      R> G-LINE - G-FLEN @ + G-I !
    ELSE
      2DROP
      G-LINE G-I @ + G-LEN @ G-I @ - G-APPEND
      G-LEN @ G-I !
    THEN
  REPEAT
  G-WORK G-LINE G-OLEN @ CMOVE
  G-OLEN @ G-LEN ! ;

: G-ASK ( -- )
  CR G-LINE G-LEN @ TYPE CR
  ." Replace? [Y/N/A/Esc] {N} "
  KEY
  DUP 27 = IF DROP -1 G-STOP ! 0 G-YES ! CR ." Stop." CR EXIT THEN
  DUP [CHAR] a [CHAR] z 1+ WITHIN IF 32 - THEN
  DUP [CHAR] Y = IF DROP -1 G-YES ! CR ." Yes" CR EXIT THEN
  DUP [CHAR] A = IF DROP -1 G-YES ! -1 G-ALL ! CR ." All" CR EXIT THEN
  DROP 0 G-YES ! CR ." No" CR ;

: G-OUTNAME ( -- c-addr u )
  G-NAME G-NLEN @ PAD SWAP CMOVE
  S" .new" PAD G-NLEN @ + SWAP CMOVE
  PAD G-NLEN @ 4 + ;

: G-CLOSE ( -- )
  G-OUT @ ?DUP IF CLOSE-FILE DROP 0 G-OUT ! THEN
  G-IN @ ?DUP IF CLOSE-FILE DROP 0 G-IN ! THEN ;

: GLOBAL ( -- )
  CR ." GLOBAL replaces text and writes name.new" CR
  CR ." Find: "
  G-FIND 120 ACCEPT DUP 0= IF DROP CR ." Nothing to find." CR EXIT THEN
  G-FLEN !
  CR ." Replace with: "
  G-REPL 120 ACCEPT G-RLEN !
  CR ." File: "
  PAD 200 ACCEPT DUP 0= IF DROP EXIT THEN
  200 MIN DUP G-NLEN ! G-NAME SWAP CMOVE
  0 G-ALL !  0 G-YES !  0 G-STOP !
  G-NAME G-NLEN @ R/O OPEN-FILE IF
    DROP CR ." Could not open " G-NAME G-NLEN @ TYPE CR EXIT
  THEN
  G-IN !
  G-OUTNAME W/O CREATE-FILE IF
    DROP G-CLOSE
    CR ." Could not create the .new file" CR EXIT
  THEN
  G-OUT !
  BEGIN
    G-STOP @ IF
      0 FALSE
    ELSE
      G-LINE 280 G-IN @ READ-LINE
      ?DUP IF
        DROP 2DROP
        -1 G-STOP !
        0 FALSE
      ELSE
        DUP 0= IF
          2DROP
          0 FALSE
        THEN
      THEN
    THEN
  WHILE
    G-LEN !
    G-LINE G-LEN @ G-FIND G-FLEN @ SEARCH NIP NIP IF
      G-ALL @ 0= IF G-ASK THEN
      G-YES @ IF G-REPLACE-LINE THEN
    THEN
    G-STOP @ 0= IF
      G-LINE G-LEN @ G-OUT @ WRITE-LINE IF
        CR ." Write failed." CR -1 G-STOP !
      THEN
    THEN
  REPEAT
  DROP
  G-CLOSE
  G-STOP @ IF
    G-OUTNAME DELETE-FILE DROP
    CR ." No file written." CR
  ELSE
    CR ." Wrote " G-OUTNAME TYPE CR
  THEN ;

CR .( Run: GLOBAL ) CR
