\ ALLSPECS.fth — collect a list of file names
\
\ The TCOM tool walked DOS directories with find-first. EditForth and
\ EditForthPWA list a folder with DIR and change it with CHDIR. This
\ copy remembers the names you type and hands them back one at a time.
\
\ Load:
\   FROMLIB FLOAD Sample/ALLSPECS.fth
\   ALLSPECS
\   NEXTDIR TYPE
\
\ A blank line finishes the list. NEXTDIR returns the next name.
\ AS-REWIND starts the list over.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW ALLSPECS_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

8192 CONSTANT AS-CAP
CREATE AS-BUF AS-CAP ALLOT
VARIABLE AS-LEN
VARIABLE AS-PTR

: AS-REWIND ( -- ) 0 AS-PTR ! ;

: NEXTDIR ( -- c-addr u )
  AS-PTR @ AS-LEN @ >= IF 0 0 EXIT THEN
  AS-BUF AS-PTR @ + COUNT
  2DUP NIP 1+ AS-PTR +! ;

: ALLSPECS ( -- )
  0 AS-LEN !  AS-REWIND
  CR ." ALLSPECS remembers file names. DIR lists the working folder." CR
  CR ." One name per line. A blank line finishes." CR
  BEGIN
    CR ." File: "
    PAD 200 ACCEPT DUP
  WHILE
    AS-LEN @ OVER 2 + + AS-CAP > IF
      DROP ." The list is full." CR
    ELSE
      DUP >R
      AS-BUF AS-LEN @ +
      R@ OVER C!
      1+ PAD SWAP R@ CMOVE
      DROP
      R> 1+ AS-LEN +!
    THEN
  REPEAT
  DROP
  AS-REWIND
  CR ." Names stored. NEXTDIR returns the next one." CR
  ;

CR .( Run: ALLSPECS ) CR
