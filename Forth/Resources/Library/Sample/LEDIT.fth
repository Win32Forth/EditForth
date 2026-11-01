\ LEDIT.fth — one-line editor for EditForth and EditForthPWA
\
\ Tom Zimmer's LEDIT edited a counted string on the DOS screen.
\ This copy uses the GRAPHICS window. The same keys work on both hosts
\ where the host actually delivers them.
\
\   Left / Ctrl-S     previous character
\   Right / Ctrl-D    next character
\   Up / Ctrl-A       previous word
\   Down / Ctrl-F     next word
\   Home / End        ends of the line, when the host sends them
\   Backspace         delete left
\   Ctrl-G / Del      delete right, when the host sends them
\   Ctrl-T            delete the word
\   Ctrl-Y            clear the line
\   Ins               insert or overwrite
\   Enter             keep the line
\   Esc               discard the line
\
\ lineeditor ( x y a1 n1 -- flag )
\   x y are the character cell. a1 is a counted string.
\   n1 is the limit, at most 80. flag is true when Enter kept the line.
\
\ STRIPPING-BLANKS is true at the start of a run. AUTOCLEAR is off.
\ Both are reset when the edit ends: blanks are stripped next time,
\ and autoclear is off again.
\
\ Load:
\   FROMLIB FLOAD Sample/LEDIT.fth
\   LEDIT
\
\ Public domain.

[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]
[DEFINED] ANEW [IF] ANEW LEDIT_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

CREATE LE-SAMPLE 82 ALLOT

: LE-PLACE ( c-addr u dest -- )
  >R 80 MIN DUP R@ C!
  R> 1+ SWAP CMOVE ;

: LE-REPORT ( flag -- )
  CR
  IF ." Kept: " LE-SAMPLE COUNT TYPE CR
  ELSE ." Discarded." CR
  THEN ;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

CREATE LE-BUF 82 ALLOT
VARIABLE LE-LEN
VARIABLE LE-MAX
VARIABLE LE-POS
VARIABLE LE-X
VARIABLE LE-Y
VARIABLE LE-DEST
VARIABLE LE-SAVE
VARIABLE LE-DONE
VARIABLE LE-ONCE
VARIABLE LE-INS
VARIABLE STRIPPING-BLANKS
VARIABLE AUTOCLEAR

-1 STRIPPING-BLANKS !
0 AUTOCLEAR !
-1 LE-INS !

: LE-SPACES ( n -- )
  0 MAX 0 ?DO 32 EMIT LOOP ;

: LE-GAP ( -- )
  LE-LEN @ 1-
  BEGIN DUP LE-POS @ 1- > WHILE
    DUP LE-BUF + C@
    OVER 1+ LE-BUF + C!
    1-
  REPEAT
  DROP
  1 LE-LEN +! ;

: LE-FDEL ( -- )
  LE-POS @ LE-LEN @ >= IF EXIT THEN
  LE-BUF LE-POS @ + 1+
  LE-BUF LE-POS @ +
  LE-LEN @ LE-POS @ - 1-
  DUP 0> IF CMOVE ELSE DROP DROP DROP THEN
  LE-LEN @ 1- 0 MAX LE-LEN ! ;

: LE-BDEL ( -- )
  LE-POS @ 0= IF EXIT THEN
  -1 LE-POS +!
  LE-FDEL ;

: LE-CLR ( -- )
  0 LE-LEN !  0 LE-POS ! ;

: LE-LEFT ( -- )
  LE-POS @ 1- 0 MAX LE-POS ! ;

: LE-RIGHT ( -- )
  LE-POS @ 1+ LE-LEN @ MIN LE-POS ! ;

: LE-LWORD ( -- )
  BEGIN LE-POS @ 0>
        LE-POS @ 1- LE-BUF + C@ BL = AND
  WHILE -1 LE-POS +! REPEAT
  BEGIN LE-POS @ 0>
        LE-POS @ 1- LE-BUF + C@ BL <> AND
  WHILE -1 LE-POS +! REPEAT ;

: LE-RWORD ( -- )
  BEGIN LE-POS @ LE-LEN @ <
        LE-POS @ LE-BUF + C@ BL <> AND
  WHILE 1 LE-POS +! REPEAT
  BEGIN LE-POS @ LE-LEN @ <
        LE-POS @ LE-BUF + C@ BL = AND
  WHILE 1 LE-POS +! REPEAT ;

: LE-WDEL ( -- )
  BEGIN LE-POS @ LE-LEN @ <
        LE-POS @ LE-BUF + C@ BL <> AND
  WHILE LE-FDEL REPEAT
  BEGIN LE-POS @ LE-LEN @ <
        LE-POS @ LE-BUF + C@ BL = AND
  WHILE LE-FDEL REPEAT ;

: LE-PUT ( c -- )
  LE-ONCE @ IF
    0 LE-ONCE !
    LE-CLR
  THEN
  LE-INS @ 0= LE-POS @ LE-LEN @ < AND IF
    LE-BUF LE-POS @ + C!
    LE-POS @ 1+ LE-MAX @ MIN LE-POS !
    EXIT
  THEN
  LE-LEN @ LE-MAX @ >= IF DROP EXIT THEN
  LE-GAP
  LE-BUF LE-POS @ + C!
  1 LE-POS +! ;

: LE-SHOW ( -- )
  LE-X @ LE-Y @ AT
  LE-BUF LE-LEN @ TYPE
  LE-MAX @ LE-LEN @ - 0 MAX LE-SPACES
  LE-Y @ 1+ G-PY G-CELLH / < IF
    0 LE-Y @ 1+ AT
    70 LE-SPACES
    LE-X @ LE-POS @ + LE-Y @ 1+ AT ." ^"
  THEN
  PREFRESH ;

: LE-STRIP ( -- )
  STRIPPING-BLANKS @ 0= IF EXIT THEN
  BEGIN LE-LEN @ 0>
        LE-BUF LE-LEN @ 1- + C@ BL = AND
  WHILE -1 LE-LEN +! REPEAT
  LE-LEN @ 1 = LE-BUF C@ BL = AND IF 0 LE-LEN ! THEN ;

: LE-KEY ( c -- )
  DUP 27 = IF DROP -1 LE-DONE ! 0 LE-SAVE ! EXIT THEN
  DUP 13 = OVER 10 = OR IF DROP -1 LE-DONE ! -1 LE-SAVE ! EXIT THEN
  DUP 203 = OVER 19 = OR IF DROP 0 LE-ONCE ! LE-LEFT EXIT THEN
  DUP 205 = OVER 4 = OR IF DROP 0 LE-ONCE ! LE-RIGHT EXIT THEN
  DUP 200 = OVER 1 = OR IF DROP 0 LE-ONCE ! LE-LWORD EXIT THEN
  DUP 208 = OVER 6 = OR IF DROP 0 LE-ONCE ! LE-RWORD EXIT THEN
  DUP 199 = IF DROP 0 LE-ONCE ! 0 LE-POS ! EXIT THEN
  DUP 207 = IF DROP 0 LE-ONCE ! LE-LEN @ LE-POS ! EXIT THEN
  DUP 8 = OVER 127 = OR IF DROP 0 LE-ONCE ! LE-BDEL EXIT THEN
  DUP 7 = OVER 211 = OR IF DROP 0 LE-ONCE ! LE-FDEL EXIT THEN
  DUP 20 = IF DROP 0 LE-ONCE ! LE-WDEL EXIT THEN
  DUP 25 = IF DROP 0 LE-ONCE ! LE-CLR EXIT THEN
  DUP 210 = IF DROP 0 LE-ONCE ! LE-INS @ 0= LE-INS ! EXIT THEN
  DUP BL 127 WITHIN IF LE-PUT EXIT THEN
  DROP ;

: LINEEDITOR ( x y a1 n1 -- flag )
  80 MIN 1 MAX LE-MAX !
  LE-DEST !
  LE-Y ! LE-X !
  LE-DEST @ C@ LE-MAX @ MIN LE-LEN !
  LE-DEST @ 1+ LE-BUF LE-LEN @ CMOVE
  0 LE-POS !
  0 LE-DONE !  0 LE-SAVE !
  -1 LE-INS !
  AUTOCLEAR @ LE-ONCE !
  BEGIN
    LE-SHOW
    KEY LE-KEY
    LE-DONE @
  UNTIL
  LE-SAVE @ IF
    LE-STRIP
    LE-LEN @ LE-DEST @ C!
    LE-BUF LE-DEST @ 1+ LE-LEN @ CMOVE
  THEN
  -1 STRIPPING-BLANKS !
  0 AUTOCLEAR !
  LE-SAVE @ ;

: LEDIT ( -- )
  S" EditForth LEDIT" APP-NAME
  WINDOW PIXEL-ON COLOR8
  WHITE PCLS
  CWHITE COLOR !
  0 1 AT ." Arrows move. Up and Down move a word. Enter keeps. Esc discards."
  0 2 AT ." Backspace deletes. The first typed character replaces the line."
  S" Zimmer, Harold" LE-SAMPLE LE-PLACE
  -1 AUTOCLEAR !
  2 5 LE-SAMPLE 40 LINEEDITOR
  1BIT WINDOW-OFF
  LE-REPORT ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

CR .( LEDIT edits one counted string in the graphics window. ) CR
CR .( Run:  LEDIT ) CR
