\ ZLIST.fth — list a text file on the EditForth console
\
\ Tom Zimmer, public domain. The TCOM program was a DOS .COM file.
\ A line whose first character is % is not shown. That is how the
\ original hid its own help sections.
\
\ Load:
\   FROMLIB FLOAD Sample/ZLIST.fth
\   ZLIST
\
\ ZLIST asks for a file, then for an optional word. The listing starts
\ at the first line that contains that word. Space pauses. Esc stops.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW ZLIST_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

CREATE ZL-NAME 256 ALLOT
VARIABLE ZL-NLEN
CREATE ZL-FIND 80 ALLOT
VARIABLE ZL-FLEN
CREATE ZL-LINE 240 ALLOT
VARIABLE ZL-STOP
VARIABLE ZL-SEEN
VARIABLE ZL-PAGE

: ZL-PAUSE ( -- flag )
  KEY? 0= IF FALSE EXIT THEN
  KEY DUP 27 = IF DROP TRUE EXIT THEN
  32 = IF
    BEGIN KEY DUP 27 = IF DROP TRUE EXIT THEN 32 <> UNTIL
  THEN
  FALSE ;

: ZL-SHOW ( len n -- )
  CR 5 .R SPACE
  ZL-LINE SWAP TYPE
  1 ZL-PAGE +!
  ZL-PAGE @ 22 MOD 0= IF
    CR ." -- more -- "
    KEY DUP 27 = IF DROP -1 ZL-STOP ! EXIT THEN
    DROP
  THEN
  ZL-PAUSE IF -1 ZL-STOP ! THEN ;

: ZL-KEEP ( n len -- n )
  SWAP OVER ZL-SHOW ;

: ZLIST ( -- )
  0 ZL-STOP !  0 ZL-SEEN !  0 ZL-PAGE !
  CR ." ZLIST" CR
  CR ." File: "
  PAD 200 ACCEPT DUP 0= IF DROP EXIT THEN
  200 MIN DUP ZL-NLEN ! ZL-NAME SWAP CMOVE
  CR ." Find (or Return): "
  ZL-FIND 70 ACCEPT ZL-FLEN !
  ZL-NAME ZL-NLEN @ R/O OPEN-FILE IF
    DROP CR ." Could not open " ZL-NAME ZL-NLEN @ TYPE CR EXIT
  THEN
  >R
  0
  BEGIN
    ZL-STOP @ 0=
  WHILE
    ZL-LINE 240 R@ READ-LINE
    ?DUP IF
      DROP 2DROP DROP
      R> CLOSE-FILE DROP
      CR ." Read failed." CR
      EXIT
    THEN
    0= IF
      DROP DROP
      R> CLOSE-FILE DROP
      CR ." ZLIST finished." CR
      EXIT
    THEN
    >R
    1+
    ZL-LINE C@ [CHAR] % = IF
      R> DROP
    ELSE
      ZL-FLEN @ 0= ZL-SEEN @ OR IF
        -1 ZL-SEEN !
        R> ZL-KEEP
      ELSE
        ZL-LINE R@ ZL-FIND ZL-FLEN @ SEARCH NIP NIP IF
          -1 ZL-SEEN !
          R> ZL-KEEP
        ELSE
          R> DROP
        THEN
      THEN
    THEN
  REPEAT
  DROP
  R> CLOSE-FILE DROP
  CR ." ZLIST finished." CR ;

CR .( Run: ZLIST ) CR
