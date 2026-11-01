\ SZ.fth — a small text editor for EditForth and EditForthPWA
\
\ Tom Zimmer wrote SZ as an example TCOM application. The DOS program
\ used function keys, a swap file, and a configuration file. This copy
\ keeps one buffer of about 48 KB in the GRAPHICS window.
\
\   Type              insert
\   Enter             split the line
\   Backspace         delete left
\   Arrows            move
\   Esc               command menu
\     S or W          save
\     O               open
\     F               find
\     H               help
\     Q               quit (Y confirms when the buffer is unsaved)
\     Esc             return to the text
\
\ A typed name is a path in the working folder. Lines are stored with
\ a line feed. Carriage returns in a file are read as line feeds.
\
\ Load:
\   FROMLIB FLOAD Sample/SZ.fth
\   SZ
\
\ Public domain. Tom Zimmer.

[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]
[DEFINED] ANEW [IF] ANEW SZ_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

: SZ-CREDIT ( -- )
  CR ." SZ is a small text editor in the graphics window."
  CR ." Esc opens the menu. Q quits. S saves. O opens. F finds." CR
  ;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

48000 CONSTANT SZ-CAP
CREATE SZ-BUF SZ-CAP ALLOT
VARIABLE SZ-LEN
VARIABLE SZ-POS
VARIABLE SZ-TOP
VARIABLE SZ-DIRTY
VARIABLE SZ-MODE
VARIABLE SZ-WHY
VARIABLE SZ-COLS
VARIABLE SZ-ROWS
CREATE SZ-PATH 256 ALLOT
VARIABLE SZ-PLEN
CREATE SZ-FIND 64 ALLOT
VARIABLE SZ-FLEN
CREATE SZ-ASK 80 ALLOT
VARIABLE SZ-ALEN
CREATE SZ-NOTE 80 ALLOT
VARIABLE SZ-NLEN
VARIABLE SZ-QUIT

: SZ. ( n -- )
  DUP 0< IF 45 EMIT NEGATE THEN
  0 <# #S #> TYPE ;

: SZ-SAY ( c-addr u -- )
  70 MIN DUP SZ-NLEN ! SZ-NOTE SWAP CMOVE ;

: SZ-MEASURE ( -- )
  G-PX G-CELLW / 80 MIN 20 MAX SZ-COLS !
  G-PY G-CELLH / 25 MIN 8 MAX SZ-ROWS ! ;

: SZ-BOL ( pos -- pos2 )
  BEGIN
    DUP 0= IF EXIT THEN
    DUP 1- SZ-BUF + C@ 10 = IF EXIT THEN
    1-
  AGAIN ;

: SZ-NEXT ( pos -- pos2 )
  BEGIN
    DUP SZ-LEN @ >= IF EXIT THEN
    DUP SZ-BUF + C@ 10 = IF 1+ EXIT THEN
    1+
  AGAIN ;

: SZ-COL ( pos -- n )
  DUP SZ-BOL - ;

: SZ-FOLLOW ( -- )
  SZ-POS @ SZ-TOP @ < IF
    SZ-POS @ SZ-BOL SZ-TOP ! EXIT
  THEN
  0 SZ-TOP @
  BEGIN DUP SZ-POS @ < WHILE
    DUP SZ-BUF + C@ 10 = IF SWAP 1+ SWAP THEN
    1+
  REPEAT
  DROP
  SZ-ROWS @ 3 - > IF
    SZ-POS @ SZ-BOL SZ-TOP !
  THEN ;

: SZ-GAP ( n -- )
  >R
  SZ-LEN @ 1-
  BEGIN DUP 0< 0= OVER SZ-POS @ 1- > AND WHILE
    DUP SZ-BUF + C@
    OVER R@ + SZ-BUF + C!
    1-
  REPEAT
  DROP
  R> SZ-LEN +! ;

: SZ-INS ( c -- )
  SZ-LEN @ 1+ SZ-CAP > IF DROP EXIT THEN
  1 SZ-GAP
  SZ-BUF SZ-POS @ + C!
  1 SZ-POS +!
  -1 SZ-DIRTY ! ;

: SZ-DEL ( -- )
  SZ-POS @ SZ-LEN @ >= IF EXIT THEN
  SZ-BUF SZ-POS @ + 1+
  SZ-BUF SZ-POS @ +
  SZ-LEN @ SZ-POS @ - 1-
  DUP 0> IF CMOVE ELSE DROP DROP DROP THEN
  SZ-LEN @ 1- 0 MAX SZ-LEN !
  -1 SZ-DIRTY ! ;

: SZ-BS ( -- )
  SZ-POS @ 0= IF EXIT THEN
  -1 SZ-POS +!
  SZ-DEL ;

: SZ-UP ( -- )
  SZ-POS @ SZ-COL >R
  SZ-POS @ SZ-BOL DUP 0= IF
    R> DROP SZ-POS ! EXIT
  THEN
  1- SZ-BOL
  DUP R> +
  OVER SZ-NEXT 1- MIN
  SZ-POS ! ;

: SZ-DOWN ( -- )
  SZ-POS @ SZ-COL >R
  SZ-POS @ SZ-NEXT DUP SZ-LEN @ >= IF
    R> DROP SZ-POS ! EXIT
  THEN
  DUP R> +
  OVER SZ-NEXT 1- MIN
  SZ-POS ! ;

: SZ-LINE# ( -- n )
  1 0
  BEGIN DUP SZ-POS @ < WHILE
    DUP SZ-BUF + C@ 10 = IF SWAP 1+ SWAP THEN
    1+
  REPEAT
  DROP ;

: SZ-PAINT ( -- )
  SZ-TOP @
  SZ-ROWS @ 2 - 0 DO
    0 I 1+ AT
    SZ-COLS @ 0 DO
      DUP SZ-LEN @ >= IF LEAVE THEN
      DUP SZ-BUF + C@ DUP 10 = IF DROP LEAVE THEN
      EMIT 1+
    LOOP
    SZ-NEXT
  LOOP
  DROP ;

: SZ-STATUS ( -- )
  CWHITE COLOR !
  0 0 AT ." SZ "
  SZ-DIRTY @ IF ." * " ELSE 32 EMIT 32 EMIT THEN
  ." line " SZ-LINE# SZ. ."  col " SZ-POS @ SZ-COL SZ.
  ."   Esc menu" ;

: SZ-HELP ( -- )
  0 0 AT ." SZ    Tom Zimmer    public domain"
  0 2 AT ." Type inserts. Enter splits the line. Backspace deletes."
  0 3 AT ." Arrows move one character or one line. Esc opens the menu."
  0 5 AT ." S or W   save the buffer"
  0 6 AT ." O        open a file into the buffer"
  0 7 AT ." F        find text"
  0 8 AT ." H        this help"
  0 9 AT ." Q        quit, and Y confirms if the buffer was edited"
  0 11 AT ." About 48 KB of text. Paths are in the working folder."
  0 13 AT ." Any key returns to the text." ;

: SZ-MENU ( -- )
  0 0 AT ." SZ menu"
  0 2 AT ." S   save"
  0 3 AT ." W   save"
  0 4 AT ." O   open"
  0 5 AT ." F   find"
  0 6 AT ." H   help"
  0 7 AT ." Q   quit"
  0 9 AT ." Esc returns to the text."
  SZ-NLEN @ IF 0 11 AT SZ-NOTE SZ-NLEN @ TYPE THEN ;

: SZ-SURE ( -- )
  0 2 AT ." This buffer has unsaved changes."
  0 4 AT ." Y quits. Any other key returns to the menu." ;

: SZ-TAKE ( c-addr u -- flag )
  SZ-LEN @ OVER + 1+ SZ-CAP > IF 2DROP TRUE EXIT THEN
  >R
  SZ-BUF SZ-LEN @ + R@ CMOVE
  SZ-LEN @ R> + SZ-LEN !
  SZ-BUF SZ-LEN @ + 10 SWAP C!
  1 SZ-LEN +!
  FALSE ;

: SZ-OPEN-PATH ( -- )
  SZ-PATH SZ-PLEN @ R/O OPEN-FILE IF
    DROP S" Could not open that file." SZ-SAY EXIT
  THEN
  >R
  0 SZ-LEN !  0 SZ-POS !  0 SZ-TOP !
  BEGIN
    PAD 180 R@ READ-LINE
    ?DUP IF
      DROP 2DROP
      R> CLOSE-FILE DROP
      S" The read stopped early." SZ-SAY
      EXIT
    THEN
    0= IF
      DROP
      R> CLOSE-FILE DROP
      0 SZ-DIRTY !
      S" Opened." SZ-SAY
      EXIT
    THEN
    PAD SWAP SZ-TAKE
  UNTIL
  R> CLOSE-FILE DROP
  0 SZ-DIRTY !
  S" Opened. The rest did not fit." SZ-SAY ;

: SZ-SAVE ( -- )
  SZ-PLEN @ 0= IF
    S" Use O and a name before saving." SZ-SAY EXIT
  THEN
  SZ-PATH SZ-PLEN @ W/O CREATE-FILE IF
    DROP S" Could not create that file." SZ-SAY EXIT
  THEN
  >R
  SZ-BUF SZ-LEN @ R@ WRITE-FILE IF
    DROP S" The write failed." SZ-SAY
  ELSE
    0 SZ-DIRTY !
    S" Saved." SZ-SAY
  THEN
  R> CLOSE-FILE DROP ;

: SZ-SEEK ( -- )
  SZ-FLEN @ 0= IF EXIT THEN
  SZ-POS @ 1+ SZ-LEN @ MIN >R
  SZ-BUF R@ +
  SZ-LEN @ R> -
  SZ-FIND SZ-FLEN @ SEARCH IF
    DROP SZ-BUF - SZ-POS !
    SZ-FOLLOW
    S" Found." SZ-SAY
  ELSE
    2DROP
    SZ-BUF SZ-LEN @ SZ-FIND SZ-FLEN @ SEARCH IF
      DROP SZ-BUF - SZ-POS !
      SZ-FOLLOW
      S" Found from the start." SZ-SAY
    ELSE
      2DROP
      S" Not found." SZ-SAY
    THEN
  THEN ;

: SZ-DO-ASK ( -- )
  SZ-ALEN @ 0= IF S" Cancelled." SZ-SAY EXIT THEN
  SZ-WHY @ 2 = IF
    SZ-ALEN @ 60 MIN DUP SZ-FLEN !
    SZ-ASK SZ-FIND ROT CMOVE
    SZ-SEEK
    EXIT
  THEN
  SZ-ALEN @ 240 MIN DUP SZ-PLEN !
  SZ-ASK SZ-PATH ROT CMOVE
  SZ-WHY @ 0= IF SZ-OPEN-PATH ELSE SZ-SAVE THEN ;

: SZ-EDIT-KEY ( c -- )
  DUP 27 = IF DROP 1 SZ-MODE ! EXIT THEN
  DUP 13 = OVER 10 = OR IF DROP 10 SZ-INS SZ-FOLLOW EXIT THEN
  DUP 8 = OVER 127 = OR IF DROP SZ-BS SZ-FOLLOW EXIT THEN
  DUP 203 = IF DROP SZ-POS @ 1- 0 MAX SZ-POS ! SZ-FOLLOW EXIT THEN
  DUP 205 = IF DROP SZ-POS @ 1+ SZ-LEN @ MIN SZ-POS ! SZ-FOLLOW EXIT THEN
  DUP 200 = IF DROP SZ-UP SZ-FOLLOW EXIT THEN
  DUP 208 = IF DROP SZ-DOWN SZ-FOLLOW EXIT THEN
  DUP 199 = IF DROP SZ-POS @ SZ-BOL SZ-POS ! EXIT THEN
  DUP 207 = IF
    DROP SZ-POS @ SZ-NEXT DUP 0= IF DROP 0 ELSE 1- THEN
    SZ-POS ! EXIT
  THEN
  DUP 7 = OVER 211 = OR IF DROP SZ-DEL SZ-FOLLOW EXIT THEN
  DUP BL 127 WITHIN IF SZ-INS SZ-FOLLOW EXIT THEN
  DROP ;

: SZ-ASK-KEY ( c -- )
  DUP 27 = IF DROP 0 SZ-MODE ! EXIT THEN
  DUP 13 = OVER 10 = OR IF DROP SZ-DO-ASK 0 SZ-MODE ! EXIT THEN
  DUP 8 = OVER 127 = OR IF
    DROP SZ-ALEN @ 0> IF -1 SZ-ALEN +! THEN EXIT
  THEN
  DUP BL 127 WITHIN IF
    SZ-ALEN @ 70 < IF
      SZ-ASK SZ-ALEN @ + C! 1 SZ-ALEN +!
    ELSE
      DROP
    THEN
    EXIT
  THEN
  DROP ;

: SZ-MENU-KEY ( c -- )
  DUP 27 = IF DROP 0 SZ-MODE ! EXIT THEN
  DUP [CHAR] q = OVER [CHAR] Q = OR IF
    DROP SZ-DIRTY @ IF 4 SZ-MODE ! ELSE -1 SZ-QUIT ! THEN EXIT
  THEN
  DUP [CHAR] s = OVER [CHAR] S = OR IF
    DROP SZ-SAVE 0 SZ-MODE ! EXIT
  THEN
  DUP [CHAR] w = OVER [CHAR] W = OR IF
    DROP SZ-SAVE 0 SZ-MODE ! EXIT
  THEN
  DUP [CHAR] o = OVER [CHAR] O = OR IF
    DROP 0 SZ-WHY ! 0 SZ-ALEN ! 2 SZ-MODE ! EXIT
  THEN
  DUP [CHAR] f = OVER [CHAR] F = OR IF
    DROP 2 SZ-WHY ! 0 SZ-ALEN ! 2 SZ-MODE ! EXIT
  THEN
  DUP [CHAR] h = OVER [CHAR] H = OR IF
    DROP 3 SZ-MODE ! EXIT
  THEN
  DROP ;

: SZ-CONFIRM ( c -- )
  DUP [CHAR] y = OVER [CHAR] Y = OR IF DROP -1 SZ-QUIT ! EXIT THEN
  DROP 1 SZ-MODE ! ;

: SZ-HELP-KEY ( c -- )
  DROP 0 SZ-MODE ! ;

: SZ-DRAW ( -- )
  WHITE PCLS
  CWHITE COLOR !
  SZ-MODE @ 3 = IF SZ-HELP EXIT THEN
  SZ-MODE @ 1 = IF SZ-MENU EXIT THEN
  SZ-MODE @ 4 = IF SZ-SURE EXIT THEN
  SZ-PAINT
  SZ-STATUS
  SZ-MODE @ 2 = IF
    0 SZ-ROWS @ 1- AT
    SZ-WHY @ 0= IF ." Open: " THEN
    SZ-WHY @ 1 = IF ." Save: " THEN
    SZ-WHY @ 2 = IF ." Find: " THEN
    SZ-ASK SZ-ALEN @ TYPE
  THEN ;

: SZ-SEED ( -- )
  S" SZ   Esc opens the menu."
  SZ-BUF SWAP DUP SZ-LEN ! CMOVE
  SZ-BUF SZ-LEN @ + 10 SWAP C!
  1 SZ-LEN +!
  0 SZ-DIRTY ! ;

: SZ ( -- )
  SZ-MEASURE
  0 SZ-LEN !  0 SZ-POS !  0 SZ-TOP !
  0 SZ-DIRTY !  0 SZ-MODE !  0 SZ-QUIT !
  0 SZ-PLEN !  0 SZ-FLEN !  0 SZ-NLEN !  0 SZ-ALEN !
  SZ-SEED
  S" EditForth SZ" APP-NAME
  WINDOW PIXEL-ON COLOR8
  S" Esc opens the menu." SZ-SAY
  BEGIN
    SZ-DRAW
    PREFRESH
    KEY
    SZ-MODE @ CASE
      0 OF SZ-EDIT-KEY ENDOF
      1 OF SZ-MENU-KEY ENDOF
      2 OF SZ-ASK-KEY ENDOF
      3 OF SZ-HELP-KEY ENDOF
      4 OF SZ-CONFIRM ENDOF
      DROP
    ENDCASE
    SZ-QUIT @
  UNTIL
  1BIT
  WINDOW-OFF ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

SZ-CREDIT
CR .( Run:  SZ ) CR
