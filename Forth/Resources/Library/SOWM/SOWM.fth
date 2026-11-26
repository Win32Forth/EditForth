\ SOWM.fth — floating-window policy, ANS Forth.
\
\ Rectangles, focus, drag, and six desktops. No display and no X11.
\ A client is an index into a fixed table. Each desktop keeps a circular
\ list. The head is the oldest window. The head's previous link is the
\ newest, and that one is painted last.
\
\ A program is a step word on a client. SOWM-TICK runs every live step,
\ including a window on a hidden desktop. The step writes text with
\ SOWM-PAGE, SOWM-TYPE, and SOWM-EMIT, and keeps eight private cells with
\ SOWM-P@ and SOWM-P!. The host paints the text when that desktop is shown.
\ It installs the content box, then calls the draw word with an empty stack.
\ SOWM-VIEW is that box: the window inset by the border, and shorter by the
\ border plus the title. Local (0,0) is its bottom-left, and Y grows up.
\
\ A program is loaded after SOWM. It writes through SOWM-PAGE, SOWM-TYPE,
\ SOWM-EMIT, SOWM., SOWM-PLOT, SOWM-LINE, and SOWM-RECT. Then it links:
\   ['] step ['] draw keys-flag SOWM-LINK
\ Each link is kept. Linking the same step again updates that program.
\ A zero step clears the list. SOWM-RESET keeps the list. SOWM-ATTACH
\ opens the most recently linked program. SOWM-ATTACH-ALL opens one
\ window of each. SOWM-NEXT-PROG walks the list from the start.
\
\ The host supplies a pixel size, then delivers pointer and key actions.
\ Load:
\   S" /Users/thomaszimmer/Documents/EditForth/SOWM/SOWM.fth" INCLUDED
\   SOWM-TEST
\
\ Public domain. The list shape follows dylanaraps/sowm.

ONLY FORTH DEFINITIONS
DECIMAL
[DEFINED] ANEW [IF] ANEW SOWM_MODULE [THEN]

32 CONSTANT SOWM-MAX
48 CONSTANT SOWM-MINW
32 CONSTANT SOWM-MINH
180 CONSTANT SOWM-DEFW
110 CONSTANT SOWM-DEFH
3 CONSTANT SOWM-EDGE
12 CONSTANT SOWM-BDIA
8 CONSTANT SOWM-PSLOTS
8 CONSTANT SOWM-NPROG

0 CONSTANT F-USED
1 CONSTANT F-X
2 CONSTANT F-Y
3 CONSTANT F-W
4 CONSTANT F-H
5 CONSTANT F-FS
6 CONSTANT F-SX
7 CONSTANT F-SY
8 CONSTANT F-SW
9 CONSTANT F-SH
10 CONSTANT F-PREV
11 CONSTANT F-NEXT
12 CONSTANT F-DESK
13 CONSTANT F-STEP
14 CONSTANT F-DRAW
15 CONSTANT F-LEN
16 CONSTANT F-KEYS
17 CONSTANT F-PRIV
18 CONSTANT SOWM-FIELDS
256 CONSTANT SOWM-TMAX

CREATE SOWM-CLIENTS  SOWM-MAX SOWM-FIELDS * CELLS ALLOT
CREATE SOWM-TBUF     SOWM-MAX SOWM-TMAX * ALLOT
CREATE SOWM-PRIV     SOWM-MAX SOWM-PSLOTS * CELLS ALLOT
CREATE SOWM-WS       6 CELLS ALLOT
CREATE SOWM-PROGS    SOWM-NPROG 3 * CELLS ALLOT
CREATE SOWM-PSAVE    SOWM-NPROG 3 * CELLS ALLOT

VARIABLE SOWM-DESK     1 SOWM-DESK !
VARIABLE SOWM-CUR      0 SOWM-CUR !
VARIABLE SOWM-SW       0 SOWM-SW !
VARIABLE SOWM-SH       0 SOWM-SH !
VARIABLE SOWM-STEP     0 SOWM-STEP !
VARIABLE SOWM-BTN      0 SOWM-BTN !
VARIABLE SOWM-DRAG     0 SOWM-DRAG !
VARIABLE SOWM-PX
VARIABLE SOWM-PY
VARIABLE SOWM-OX
VARIABLE SOWM-OY
VARIABLE SOWM-OW
VARIABLE SOWM-OH
VARIABLE SOWM-N
VARIABLE EW-XT
VARIABLE EW-ID
VARIABLE UL-ID
VARIABLE UL-PREV
VARIABLE UL-NEXT
VARIABLE LK-ID
VARIABLE LK-HEAD
VARIABLE LK-TAIL
VARIABLE PL-ID
VARIABLE SOWM-OUT
VARIABLE SOWM-LSTEP   0 SOWM-LSTEP !
VARIABLE SOWM-LDRAW   0 SOWM-LDRAW !
VARIABLE SOWM-LKEYS   0 SOWM-LKEYS !
VARIABLE SOWM-PN      0 SOWM-PN !
VARIABLE SOWM-PI      0 SOWM-PI !
VARIABLE SOWM-PNS
VARIABLE SOWM-PIS
VARIABLE SOWM-LSS
VARIABLE SOWM-LDS
VARIABLE SOWM-LKS
VARIABLE SOWM-CX
VARIABLE SOWM-CY
VARIABLE SOWM-CW
VARIABLE SOWM-CH
VARIABLE BA-P
VARIABLE BA-D
VARIABLE BA-R
VARIABLE BX
VARIABLE BY
VARIABLE BW
VARIABLE BH
VARIABLE BR
VARIABLE BT

: C-ADDR ( id fld -- addr )
  SWAP 1- SOWM-FIELDS * + CELLS SOWM-CLIENTS + ;

: F@ ( id fld -- n )  C-ADDR @ ;
: F! ( n id fld -- )  C-ADDR ! ;

: SOWM-LIVE? ( id -- flag )
  DUP 0= IF EXIT THEN
  F-USED F@
;

: WS@ ( -- id )  SOWM-DESK @ 1- CELLS SOWM-WS + @ ;
: WS! ( id -- )  SOWM-DESK @ 1- CELLS SOWM-WS + ! ;

: SOWM-FOCUS@ ( -- id )  SOWM-CUR @ ;
: SOWM-DESK@  ( -- n )   SOWM-DESK @ ;
: SOWM-HEAD@  ( -- id )  WS@ ;
: SOWM-X@ ( id -- n )  F-X F@ ;
: SOWM-Y@ ( id -- n )  F-Y F@ ;
: SOWM-W@ ( id -- n )  F-W F@ ;
: SOWM-H@ ( id -- n )  F-H F@ ;
: SOWM-NEXT@ ( id -- id )  F-NEXT F@ ;
: SOWM-PREV@ ( id -- id )  F-PREV F@ ;
: SOWM-FS@ ( id -- flag )  F-FS F@ ;

: SOWM-EACH ( xt -- )
  EW-XT !
  WS@ 0= IF EXIT THEN
  WS@ EW-ID !
  SOWM-MAX 0 DO
    EW-ID @ EW-XT @ EXECUTE
    EW-ID @ F-NEXT F@ DUP 0= IF DROP UNLOOP EXIT THEN
    DUP EW-ID !
    WS@ = IF UNLOOP EXIT THEN
  LOOP
;

: SOWM-COUNT1 ( id -- )  DROP 1 SOWM-N +! ;

: SOWM-COUNT ( -- n )
  0 SOWM-N !
  ['] SOWM-COUNT1 SOWM-EACH
  SOWM-N @
;

: SOWM-CLEAR ( id -- )
  DUP 1- SOWM-PSLOTS * CELLS SOWM-PRIV + SOWM-PSLOTS CELLS 0 FILL
  SOWM-FIELDS 0 DO
    0 OVER I F!
  LOOP
  -1 SWAP F-USED F!
;

: SOWM-ALLOC ( -- id )
  SOWM-MAX 1+ 1 DO
    I F-USED F@ 0= IF
      I SOWM-CLEAR
      I UNLOOP EXIT
    THEN
  LOOP
  0
;

: WIN-UNLINK ( id -- )
  UL-ID !
  UL-ID @ F-NEXT F@ UL-NEXT !
  UL-ID @ F-PREV F@ UL-PREV !
  UL-NEXT @ UL-ID @ = IF
    0 WS! EXIT
  THEN
  UL-NEXT @ UL-PREV @ F-NEXT F!
  UL-PREV @ UL-NEXT @ F-PREV F!
  WS@ UL-ID @ = IF UL-NEXT @ WS! THEN
  0 UL-ID @ F-NEXT F!
  0 UL-ID @ F-PREV F!
;

: WIN-LINK ( id -- )
  LK-ID !
  SOWM-DESK @ LK-ID @ F-DESK F!
  WS@ LK-HEAD !
  LK-HEAD @ 0= IF
    LK-ID @ LK-ID @ F-PREV F!
    LK-ID @ LK-ID @ F-NEXT F!
    LK-ID @ WS! EXIT
  THEN
  LK-HEAD @ F-PREV F@ LK-TAIL !
  LK-ID @ LK-TAIL @ F-NEXT F!
  LK-TAIL @ LK-ID @ F-PREV F!
  LK-HEAD @ LK-ID @ F-NEXT F!
  LK-ID @ LK-HEAD @ F-PREV F!
;

: WIN-RAISE ( id -- )
  DUP SOWM-LIVE? 0= IF DROP EXIT THEN
  DUP WIN-UNLINK
  DUP WIN-LINK
  SOWM-CUR !
;

VARIABLE HT-X
VARIABLE HT-Y
VARIABLE HT-ID

\ Inside means x0 <= x < x0+w and y0 <= y < y0+h.
: SOWM-IN? ( id -- flag )
  DUP F-X F@
  DUP HT-X @ SWAP < IF 2DROP 0 EXIT THEN
  OVER F-W F@ +
  HT-X @ SWAP < 0= IF DROP 0 EXIT THEN
  DUP F-Y F@
  DUP HT-Y @ SWAP < IF 2DROP 0 EXIT THEN
  OVER F-H F@ +
  HT-Y @ SWAP < 0= IF DROP 0 EXIT THEN
  DROP -1
;

\ Newest window first, so the top rectangle wins.
: SOWM-HIT ( x y -- id )
  HT-Y ! HT-X !
  WS@ 0= IF 0 EXIT THEN
  WS@ F-PREV F@ HT-ID !
  SOWM-MAX 0 DO
    HT-ID @ SOWM-IN? IF HT-ID @ UNLOOP EXIT THEN
    HT-ID @ F-PREV F@ DUP 0= IF DROP 0 UNLOOP EXIT THEN
    HT-ID !
    HT-ID @ WS@ F-PREV F@ = IF 0 UNLOOP EXIT THEN
  LOOP
  0
;

: SOWM-XY! ( x y id -- )
  PL-ID !
  SWAP >R
  PL-ID @ F-Y F!
  R> PL-ID @ F-X F!
  0 PL-ID @ F-FS F!
;

: SOWM-WH! ( w h id -- )
  >R
  SWAP SOWM-MINW MAX R@ F-W F!
  SOWM-MINH MAX R@ F-H F!
  0 R> F-FS F!
;

: SOWM-PLACE ( id -- )
  PL-ID !
  SOWM-DEFW PL-ID @ F-W F!
  SOWM-DEFH PL-ID @ F-H F!
  SOWM-STEP @ 28 * 40 +
  SOWM-SW @ 220 - 0 MAX MIN  0 MAX
  PL-ID @ F-X F!
  SOWM-STEP @ 28 * 40 +
  SOWM-SH @ 150 - 0 MAX MIN  0 MAX
  PL-ID @ F-Y F!
  SOWM-STEP @ 1+ 8 MOD SOWM-STEP !
;

: SOWM-NEW ( -- id )
  SOWM-ALLOC DUP 0= IF EXIT THEN
  DUP SOWM-PLACE
  DUP WIN-LINK
  DUP -1 SWAP F-KEYS F!
  DUP SOWM-CUR !
;

: SOWM-SCREEN ( w h -- )
  1 MAX SOWM-SH !
  1 MAX SOWM-SW !
;

: SOWM-RESET ( -- )
  SOWM-CLIENTS SOWM-MAX SOWM-FIELDS * CELLS 0 FILL
  SOWM-PRIV SOWM-MAX SOWM-PSLOTS * CELLS 0 FILL
  SOWM-WS 6 CELLS 0 FILL
  1 SOWM-DESK !
  0 SOWM-CUR !
  0 SOWM-STEP !
  0 SOWM-BTN !
  0 SOWM-DRAG !
  0 SOWM-OUT !
  0 SOWM-CX !  0 SOWM-CY !
  0 SOWM-CW !  0 SOWM-CH !
  0 SOWM-PI !
;

: (SOWM-CENTER) ( id -- )
  DUP SOWM-LIVE? 0= IF DROP EXIT THEN
  SOWM-SW @ OVER F-W F@ - 2/
  OVER F-X F!
  SOWM-SH @ OVER F-H F@ - 2/
  OVER F-Y F!
  0 SWAP F-FS F!
;

: SOWM-CENTER ( -- )  SOWM-CUR @ (SOWM-CENTER) ;

: SOWM-FS ( id -- )
  DUP SOWM-LIVE? 0= IF DROP EXIT THEN
  DUP F-FS F@ IF
    DUP F-SX F@ OVER F-X F!
    DUP F-SY F@ OVER F-Y F!
    DUP F-SW F@ OVER F-W F!
    DUP F-SH F@ OVER F-H F!
    0 SWAP F-FS F!
  ELSE
    DUP F-X F@ OVER F-SX F!
    DUP F-Y F@ OVER F-SY F!
    DUP F-W F@ OVER F-SW F!
    DUP F-H F@ OVER F-SH F!
    0 OVER F-X F!
    0 OVER F-Y F!
    SOWM-SW @ OVER F-W F!
    SOWM-SH @ OVER F-H F!
    -1 SWAP F-FS F!
  THEN
;

: SOWM-FULL ( -- )  SOWM-CUR @ SOWM-FS ;

: SOWM-KILL ( -- )
  SOWM-CUR @ DUP SOWM-LIVE? 0= IF DROP EXIT THEN
  DUP SOWM-DRAG @ = IF 0 SOWM-DRAG ! THEN
  DUP WIN-UNLINK
  0 SWAP F-USED F!
  WS@ DUP IF F-PREV F@ THEN SOWM-CUR !
;

: SOWM-NEXT ( -- )
  SOWM-CUR @ DUP SOWM-LIVE? 0= IF DROP EXIT THEN
  F-NEXT F@ WIN-RAISE
;

: SOWM-PREV ( -- )
  SOWM-CUR @ DUP SOWM-LIVE? 0= IF DROP EXIT THEN
  F-PREV F@ WIN-RAISE
;

: SOWM-GO ( n -- )
  DUP 1 7 WITHIN 0= IF DROP EXIT THEN
  DUP SOWM-DESK @ = IF DROP EXIT THEN
  SOWM-DESK !
  0 SOWM-DRAG !
  0 SOWM-BTN !
  WS@ SOWM-CUR !
;

: SOWM-SEND ( n -- )
  SOWM-CUR @ SOWM-LIVE? 0= IF DROP EXIT THEN
  DUP 1 7 WITHIN 0= IF DROP EXIT THEN
  DUP SOWM-DESK @ = IF DROP EXIT THEN
  SOWM-CUR @ WIN-UNLINK
  SOWM-DESK @ >R
  SOWM-DESK !
  SOWM-CUR @ WIN-LINK
  R> SOWM-DESK !
  0 SOWM-DRAG !
  0 SOWM-BTN !
  WS@ SOWM-CUR !
;

: SOWM-DOWN ( btn x y -- )
  DUP SOWM-SH @ >= IF 2DROP DROP EXIT THEN
  SOWM-PY ! SOWM-PX !
  DUP 1 <> OVER 2 <> AND IF DROP EXIT THEN
  SOWM-BTN !
  SOWM-PX @ SOWM-PY @ SOWM-HIT
  DUP 0= IF DROP 0 SOWM-DRAG ! EXIT THEN
  DUP WIN-RAISE
  DUP SOWM-DRAG !
  DUP F-X F@ SOWM-OX !
  DUP F-Y F@ SOWM-OY !
  DUP F-W F@ SOWM-OW !
  F-H F@ SOWM-OH !
;

: SOWM-MOTION ( x y -- )
  SOWM-DRAG @ SOWM-LIVE? 0= IF
    2DROP 0 SOWM-DRAG ! EXIT
  THEN
  SOWM-BTN @ 2 = IF
    OVER SOWM-PX @ - SOWM-OW @ +
    OVER SOWM-PY @ - SOWM-OH @ +
    SOWM-DRAG @ SOWM-WH!
    2DROP
  ELSE
    OVER SOWM-PX @ - SOWM-OX @ +
    OVER SOWM-PY @ - SOWM-OY @ +
    SOWM-DRAG @ SOWM-XY!
    2DROP
  THEN
;

: SOWM-UP ( -- )
  0 SOWM-DRAG !
  0 SOWM-BTN !
;

: SOWM-HOVER ( x y -- )
  DUP SOWM-SH @ >= IF 2DROP EXIT THEN
  SOWM-DRAG @ IF 2DROP EXIT THEN
  SOWM-HIT DUP 0= IF DROP EXIT THEN
  DUP SOWM-CUR @ = IF DROP EXIT THEN
  SOWM-CUR !
;

\ --- program text. SOWM-OUT is the client that receives characters. ---

: SOWM-TPTR ( id -- c-addr )
  1- SOWM-TMAX * SOWM-TBUF + ;

: SOWM-TEXT ( id -- c-addr u )
  DUP SOWM-TPTR SWAP F-LEN F@ ;

: SOWM-PAGE ( -- )
  SOWM-OUT @ SOWM-LIVE? 0= IF EXIT THEN
  0 SOWM-OUT @ F-LEN F!
;

\ A full buffer slides one byte toward the start. The destination sits
\ below the source, so the copy has to run low to high.
: SOWM-EMIT ( c -- )
  SOWM-OUT @ SOWM-LIVE? 0= IF DROP EXIT THEN
  SOWM-OUT @ F-LEN F@ SOWM-TMAX = IF
    SOWM-OUT @ SOWM-TPTR DUP 1+ SWAP SOWM-TMAX 1- CMOVE
    SOWM-OUT @ F-LEN F@ 1- SOWM-OUT @ F-LEN F!
  THEN
  SOWM-OUT @ SOWM-TPTR SOWM-OUT @ F-LEN F@ + C!
  1 SOWM-OUT @ F-LEN C-ADDR +!
;

: SOWM-TYPE ( c-addr u -- )
  OVER + SWAP ?DO
    I C@ SOWM-EMIT
  LOOP
;

: SOWM. ( n -- )
  BASE @ >R DECIMAL
  DUP ABS 0 <# #S ROT SIGN #> SOWM-TYPE
  R> BASE !
;

: SOWM-2DIG ( n -- )
  BASE @ >R DECIMAL
  0 MAX 99 MIN
  0 <# # # #> SOWM-TYPE
  R> BASE !
;

: SOWM-TICK ( -- )
  SOWM-MAX 1+ 1 DO
    I SOWM-LIVE? IF
      I F-STEP F@ ?DUP IF
        I SOWM-OUT !
        EXECUTE
      THEN
    THEN
  LOOP
;

: SOWM-OPEN ( step-xt draw-xt keys-flag -- id|0 )
  SOWM-NEW DUP 0= IF 2DROP 2DROP 0 EXIT THEN
  >R
  R@ F-KEYS F!
  R@ F-DRAW F!
  R@ F-STEP F!
  R>
;

: SOWM-DRAW! ( xt id -- ) F-DRAW F! ;

\ One record is step, draw, keys. The client table is wiped by
\ SOWM-RESET; this list is not.
: SOWM-PREC ( i -- addr )
  3 * CELLS SOWM-PROGS + ;

: SOWM-FIND-PROG ( step -- i | -1 )
  SOWM-PN @ 0 ?DO
    DUP I SOWM-PREC @ = IF
      DROP I UNLOOP EXIT
    THEN
  LOOP
  DROP -1
;

: SOWM-PSTORE ( step draw keys i -- )
  >R
  R@ SOWM-PREC 2 CELLS + !
  R@ SOWM-PREC CELL+ !
  R> SOWM-PREC !
;

: SOWM-MIRROR ( step draw keys -- step draw keys )
  DUP SOWM-LKEYS !
  OVER SOWM-LDRAW !
  ROT DUP SOWM-LSTEP ! -ROT
;

\ A zero step clears the list. The same step updates its record.
: SOWM-LINK ( step-xt draw-xt keys-flag -- )
  ROT DUP 0= IF
    DROP 2DROP
    0 SOWM-PN !
    0 SOWM-PI !
    0 SOWM-LSTEP !
    0 SOWM-LDRAW !
    0 SOWM-LKEYS !
    EXIT
  THEN
  DUP SOWM-FIND-PROG
  DUP 0< IF
    DROP
    SOWM-PN @ SOWM-NPROG >= IF DROP 2DROP EXIT THEN
    SOWM-PN @
    1 SOWM-PN +!
  THEN
  >R ROT ROT
  SOWM-MIRROR
  R>
  SOWM-PSTORE
;

: SOWM-OPEN-PROG ( i -- id|0 )
  DUP 0 SOWM-PN @ WITHIN 0= IF DROP 0 EXIT THEN
  DUP SOWM-PREC @
  OVER SOWM-PREC CELL+ @
  ROT SOWM-PREC 2 CELLS + @
  SOWM-OPEN
;

: SOWM-ATTACH ( -- id|0 )
  SOWM-PN @ 1- SOWM-OPEN-PROG
;

: SOWM-ATTACH-ALL ( -- )
  SOWM-PN @ 0 ?DO
    I SOWM-OPEN-PROG DROP
  LOOP
;

\ The next press opens the next program. SOWM-RESET starts again at the first.
: SOWM-NEXT-PROG ( -- id|0 )
  SOWM-PN @ 0= IF 0 EXIT THEN
  SOWM-PI @ SOWM-PN @ MOD
  SOWM-OPEN-PROG
  1 SOWM-PI +!
;

: SOWM-HOLD ( -- )
  SOWM-PROGS SOWM-PSAVE SOWM-NPROG 3 * CELLS CMOVE
  SOWM-PN @ SOWM-PNS !
  SOWM-PI @ SOWM-PIS !
  SOWM-LSTEP @ SOWM-LSS !
  SOWM-LDRAW @ SOWM-LDS !
  SOWM-LKEYS @ SOWM-LKS !
;

: SOWM-HELD ( -- )
  SOWM-PSAVE SOWM-PROGS SOWM-NPROG 3 * CELLS CMOVE
  SOWM-PNS @ SOWM-PN !
  SOWM-PIS @ SOWM-PI !
  SOWM-LSS @ SOWM-LSTEP !
  SOWM-LDS @ SOWM-LDRAW !
  SOWM-LKS @ SOWM-LKEYS !
;

: SOWM-TAKES? ( -- flag )
  SOWM-FOCUS@ DUP SOWM-LIVE? 0= IF DROP 0 EXIT THEN
  F-KEYS F@
;

: SOWM-BACK ( -- )
  SOWM-OUT @ F-LEN F@ DUP 0= IF DROP EXIT THEN
  1- SOWM-OUT @ F-LEN F!
;

: SOWM-CHAR ( c -- )
  SOWM-FOCUS@ SOWM-LIVE? 0= IF DROP EXIT THEN
  SOWM-FOCUS@ F-KEYS F@ 0= IF DROP EXIT THEN
  SOWM-FOCUS@ SOWM-OUT !
  DUP 8 = OVER 127 = OR IF DROP SOWM-BACK EXIT THEN
  DUP 13 = IF DROP 10 THEN
  DUP 9 = OVER 10 = OR OVER BL 127 WITHIN OR IF
    SOWM-EMIT EXIT
  THEN
  DROP
;

: SOWM-COUNT-STEP ( -- )
  SOWM-OUT @ F-PRIV F@ 1+
  DUP SOWM-OUT @ F-PRIV F!
  SOWM-PAGE
  S" count " SOWM-TYPE
  SOWM.
  10 SOWM-EMIT
;

\ TIME&DATE leaves ( sec min hour day month year ).
: SOWM-CLOCK-STEP ( -- )
  SOWM-PAGE
  TIME&DATE
  >R >R >R
  SWAP ROT
  SOWM-2DIG [CHAR] : SOWM-EMIT
  SOWM-2DIG [CHAR] : SOWM-EMIT
  SOWM-2DIG BL SOWM-EMIT
  R> SOWM-2DIG [CHAR] - SOWM-EMIT
  R> SOWM-2DIG [CHAR] - SOWM-EMIT
  R> SOWM.
;

: SOWM-NOTE-STEP ( -- )
  SOWM-OUT @ F-PRIV F@ IF EXIT THEN
  -1 SOWM-OUT @ F-PRIV F!
  S" type here" SOWM-TYPE
  10 SOWM-EMIT
;

: SOWM-COUNTER ( -- id|0 )
  ['] SOWM-COUNT-STEP 0 0 SOWM-OPEN ;

: SOWM-CLOCK ( -- id|0 )
  ['] SOWM-CLOCK-STEP 0 0 SOWM-OPEN ;

: SOWM-NOTE ( -- id|0 )
  ['] SOWM-NOTE-STEP 0 -1 SOWM-OPEN ;

\ Content box. The 18 is the title band, so the height loses both borders
\ plus that band. A dead id reports an empty box.
: SOWM-VIEW ( id -- x y w h )
  DUP SOWM-LIVE? 0= IF DROP 0 0 0 0 EXIT THEN
  DUP F-X F@ SOWM-EDGE +
  OVER F-Y F@ SOWM-EDGE +
  ROT
  DUP F-W F@ SOWM-EDGE 2* - 0 MAX
  SWAP F-H F@ SOWM-EDGE 2* - 18 - 0 MAX
;

: SOWM-CLIP ( x y w h -- )
  0 MAX SOWM-CH !
  0 MAX SOWM-CW !
  SOWM-CY !
  SOWM-CX !
;

\ Translated point. The flag is true only when it sits inside the box.
: SOWM-XY ( x y -- ax ay flag )
  OVER 0 SOWM-CW @ WITHIN
  OVER 0 SOWM-CH @ WITHIN
  AND >R
  SOWM-CY @ +
  SWAP SOWM-CX @ +
  SWAP
  R>
;

\ Local rectangle clipped to the box, then shifted into screen pixels.
\ An empty result is a single 0.
: SOWM-BOX ( x y w h -- x' y' w' h' flag | 0 )
  BH ! BW ! BY ! BX !
  BW @ 1 < BH @ 1 < OR IF 0 EXIT THEN
  BX @ BW @ + BR !
  BY @ BH @ + BT !
  BX @ 0 MAX BX !
  BY @ 0 MAX BY !
  BR @ SOWM-CW @ MIN BR !
  BT @ SOWM-CH @ MIN BT !
  BR @ BX @ - BW !
  BT @ BY @ - BH !
  BW @ 1 < BH @ 1 < OR IF 0 EXIT THEN
  BX @ SOWM-CX @ +
  BY @ SOWM-CY @ +
  BW @ BH @ -1
;

: SOWM-PCELL ( i -- addr )
  SOWM-OUT @ 1- SOWM-PSLOTS * + CELLS SOWM-PRIV + ;

: SOWM-P@ ( i -- n )
  DUP 0 SOWM-PSLOTS WITHIN 0= IF DROP 0 EXIT THEN
  SOWM-OUT @ SOWM-LIVE? 0= IF DROP 0 EXIT THEN
  SOWM-PCELL @
;

: SOWM-P! ( n i -- )
  DUP 0 SOWM-PSLOTS WITHIN 0= IF 2DROP EXIT THEN
  SOWM-OUT @ SOWM-LIVE? 0= IF 2DROP EXIT THEN
  SOWM-PCELL !
;

\ Proposed position, its step, and the farthest legal position.
\ A zero room parks the ball so a short window does not vibrate.
: SOWM-AXIS ( pos delta room -- pos delta )
  BA-R ! BA-D ! BA-P !
  BA-R @ 0= IF
    0 BA-P !
    0 BA-D !
  ELSE
    BA-P @ 0< IF
      0 BA-P !
      BA-D @ ABS BA-D !
    THEN
    BA-P @ BA-R @ > IF
      BA-R @ BA-P !
      BA-D @ ABS NEGATE BA-D !
    THEN
  THEN
  BA-P @ BA-D @
;

: SOWM-NOSTEP ( -- ) ;
: SOWM-NOSTEP2 ( -- ) ;

\ --- checks. SOWM-TEST leaves an empty stack and prints sowm-ok. ---

: T= ( actual expected -- )
  2DUP = IF 2DROP EXIT THEN
  SWAP CR ." sowm-fail got " . ." expected " . CR
  ABORT
;

: SOWM-TEST ( -- )
  SOWM-RESET
  800 600 SOWM-SCREEN
  SOWM-NEW 1 T=
  SOWM-FOCUS@ 1 T=  SOWM-HEAD@ 1 T=  SOWM-COUNT 1 T=
  1 F-STEP F@ 0 T=  1 F-LEN F@ 0 T=  1 F-KEYS F@ -1 T=
  1 SOWM-X@ 40 T=   1 SOWM-Y@ 40 T=
  1 SOWM-W@ SOWM-DEFW T=  1 SOWM-H@ SOWM-DEFH T=
  1 SOWM-NEXT@ 1 T=  1 SOWM-PREV@ 1 T=
  SOWM-NEW 2 T=
  SOWM-FOCUS@ 2 T=  SOWM-HEAD@ 1 T=  SOWM-COUNT 2 T=
  1 SOWM-NEXT@ 2 T=  2 SOWM-NEXT@ 1 T=
  1 SOWM-PREV@ 2 T=  2 SOWM-PREV@ 1 T=
  2 SOWM-X@ 68 T=  2 SOWM-Y@ 68 T=
  50 50 SOWM-HIT 1 T=
  80 80 SOWM-HIT 2 T=
  0 0 SOWM-HIT 0 T=
  50 50 SOWM-HOVER  SOWM-FOCUS@ 1 T=
  0 0 SOWM-HOVER    SOWM-FOCUS@ 1 T=
  1 80 80 SOWM-DOWN
  SOWM-FOCUS@ 2 T=
  90 100 SOWM-MOTION  SOWM-UP
  2 SOWM-X@ 78 T=  2 SOWM-Y@ 88 T=  2 SOWM-FS@ 0 T=
  2 78 88 SOWM-DOWN
  118 103 SOWM-MOTION  SOWM-UP
  2 SOWM-W@ 220 T=  2 SOWM-H@ 125 T=
  SOWM-CENTER
  2 SOWM-X@ 290 T=  2 SOWM-Y@ 237 T=
  SOWM-FULL
  2 SOWM-X@ 0 T=  2 SOWM-Y@ 0 T=
  2 SOWM-W@ 800 T=  2 SOWM-H@ 600 T=  2 SOWM-FS@ -1 T=
  SOWM-FULL
  2 SOWM-X@ 290 T=  2 SOWM-Y@ 237 T=
  2 SOWM-W@ 220 T=  2 SOWM-H@ 125 T=  2 SOWM-FS@ 0 T=
  SOWM-NEXT  SOWM-FOCUS@ 1 T=
  SOWM-PREV  SOWM-FOCUS@ 2 T=
  2 SOWM-GO  SOWM-COUNT 0 T=  SOWM-FOCUS@ 0 T=  SOWM-DESK@ 2 T=
  SOWM-NEW 3 T=  SOWM-COUNT 1 T=
  1 SOWM-GO  SOWM-COUNT 2 T=  SOWM-FOCUS@ 1 T=  SOWM-DESK@ 1 T=
  2 SOWM-SEND
  SOWM-DESK@ 1 T=  SOWM-COUNT 1 T=  SOWM-FOCUS@ 2 T=
  2 SOWM-GO  SOWM-COUNT 2 T=  SOWM-FOCUS@ 3 T=
  SOWM-KILL  SOWM-COUNT 1 T=  SOWM-FOCUS@ 1 T=
  1 SOWM-GO  SOWM-COUNT 1 T=  SOWM-FOCUS@ 2 T=
  SOWM-KILL  SOWM-COUNT 0 T=  SOWM-FOCUS@ 0 T=
  SOWM-KILL
  1 SOWM-GO
  0 SOWM-GO  SOWM-DESK@ 1 T=
  7 SOWM-GO  SOWM-DESK@ 1 T=
  \ Programs keep stepping on a desktop that is not shown.
  SOWM-RESET
  800 600 SOWM-SCREEN
  SOWM-TICK
  SOWM-COUNTER 1 T=
  1 F-DRAW F@ 0 T=  1 F-KEYS F@ 0 T=
  SOWM-TICK
  1 F-PRIV F@ 1 T=
  1 F-LEN F@ 8 T=
  1 SOWM-TPTR C@ [CHAR] c T=
  1 SOWM-TPTR 6 + C@ [CHAR] 1 T=
  1 SOWM-TPTR 7 + C@ 10 T=
  [CHAR] Z SOWM-CHAR
  1 F-LEN F@ 8 T=
  2 SOWM-GO
  SOWM-DESK@ 2 T=
  1 F-DESK F@ 1 T=
  SOWM-TICK
  1 F-PRIV F@ 2 T=
  1 SOWM-TPTR 6 + C@ [CHAR] 2 T=
  SOWM-CLOCK 2 T=
  SOWM-FOCUS@ 2 T=
  SOWM-TICK
  1 F-PRIV F@ 3 T=
  2 F-LEN F@ 19 T=
  2 SOWM-TPTR C@ [CHAR] 0 [CHAR] : WITHIN -1 T=
  2 SOWM-TPTR CHAR+ C@ [CHAR] 0 [CHAR] : WITHIN -1 T=
  2 SOWM-TPTR 11 + C@ [CHAR] - T=
  1 SOWM-GO
  SOWM-NOTE 3 T=
  3 F-KEYS F@ -1 T=
  SOWM-TICK
  3 F-LEN F@ 10 T=
  3 SOWM-TPTR 9 + C@ 10 T=
  [CHAR] A SOWM-CHAR
  3 F-LEN F@ 11 T=
  3 SOWM-TPTR 10 + C@ [CHAR] A T=
  8 SOWM-CHAR
  3 F-LEN F@ 10 T=
  127 SOWM-CHAR
  3 F-LEN F@ 9 T=
  13 SOWM-CHAR
  3 F-LEN F@ 10 T=
  3 SOWM-TPTR 9 + C@ 10 T=
  1 SOWM-OUT !
  SOWM-PAGE
  1 F-LEN F@ 0 T=
  SOWM-TMAX 0 DO I SOWM-EMIT LOOP
  1 F-LEN F@ SOWM-TMAX T=
  1 SOWM-TPTR C@ 0 T=
  99 SOWM-EMIT
  1 F-LEN F@ SOWM-TMAX T=
  1 SOWM-TPTR C@ 1 T=
  1 SOWM-TPTR SOWM-TMAX 1- + C@ 99 T=
  \ Content box. Local (0,0) is the bottom-left under the title.
  SOWM-RESET
  800 600 SOWM-SCREEN
  SOWM-NEW DROP
  1 SOWM-VIEW
  86 T= 174 T= 43 T= 43 T=
  0 SOWM-VIEW
  0 T= 0 T= 0 T= 0 T=
  1 SOWM-VIEW SOWM-CLIP
  SOWM-CX @ 43 T=  SOWM-CY @ 43 T=
  SOWM-CW @ 174 T=  SOWM-CH @ 86 T=
  0 0 SOWM-XY
  -1 T= 43 T= 43 T=
  174 0 SOWM-XY
  0 T= 43 T= 217 T=
  0 0 174 86 SOWM-BOX
  -1 T= 86 T= 174 T= 43 T= 43 T=
  -4 -4 20 10 SOWM-BOX
  -1 T= 6 T= 16 T= 43 T= 43 T=
  200 0 10 10 SOWM-BOX
  0 T=
  10 20 -3 -4 SOWM-CLIP
  SOWM-CW @ 0 T=  SOWM-CH @ 0 T=
  0 0 SOWM-XY
  0 T= 20 T= 10 T=
  \ Link survives SOWM-RESET. Attach stores the newest program.
  SOWM-HOLD
  ['] SOWM-NOSTEP 0 -1 SOWM-LINK
  SOWM-ATTACH 2 T=
  2 F-STEP F@ ['] SOWM-NOSTEP T=
  2 F-DRAW F@ 0 T=
  2 F-KEYS F@ -1 T=
  2 F-LEN F@ 0 T=
  2 SOWM-OUT !
  0 SOWM-P@ 0 T=
  99 7 SOWM-P!
  7 SOWM-P@ 99 T=
  1 SOWM-OUT !
  7 SOWM-P@ 0 T=
  99 8 SOWM-P!
  0 SOWM-P@ 0 T=
  0 SOWM-OUT !
  123 0 SOWM-P!
  0 SOWM-P@ 0 T=
  2 SOWM-OUT !
  7 SOWM-P@ 99 T=
  SOWM-RESET
  SOWM-LSTEP @ ['] SOWM-NOSTEP T=
  0 0 0 SOWM-LINK
  SOWM-ATTACH 0 T=
  SOWM-PN @ 0 T=
  ['] SOWM-NOSTEP 0 -1 SOWM-LINK
  ['] SOWM-NOSTEP2 0 0 SOWM-LINK
  ['] SOWM-NOSTEP 0 0 SOWM-LINK
  SOWM-PN @ 2 T=
  0 SOWM-PREC @ ['] SOWM-NOSTEP T=
  0 SOWM-PREC 2 CELLS + @ 0 T=
  1 SOWM-PREC @ ['] SOWM-NOSTEP2 T=
  SOWM-RESET
  800 600 SOWM-SCREEN
  SOWM-ATTACH-ALL
  SOWM-COUNT 2 T=
  1 F-STEP F@ ['] SOWM-NOSTEP T=
  2 F-STEP F@ ['] SOWM-NOSTEP2 T=
  SOWM-NEXT-PROG 3 T=
  3 F-STEP F@ ['] SOWM-NOSTEP T=
  SOWM-NEXT-PROG 4 T=
  4 F-STEP F@ ['] SOWM-NOSTEP2 T=
  SOWM-NEXT-PROG 5 T=
  5 F-STEP F@ ['] SOWM-NOSTEP T=
  SOWM-HELD
  SOWM-PN @ SOWM-PNS @ T=
  SOWM-RESET
  SOWM-MAX 0 DO SOWM-NEW DROP LOOP
  SOWM-COUNT SOWM-MAX T=
  SOWM-NEW 0 T=
  SOWM-COUNTER 0 T=
  SOWM-CLOCK 0 T=
  SOWM-NOTE 0 T=
  SOWM-ATTACH 0 T=
  DEPTH 0 T=
  ." sowm-ok " CR
;

CR .( SOWM policy loaded — type SOWM-TEST to check it.) CR
