\ JV-INI.fth — load a Win32Forth Julia parameter file.
\
\ Included by the Julia files while GRAPHICS, FLOATING, and
\ FIXED-POINT are in the search order. L opens a file.
\ JV-INI ( c-addr u -- ior ) reads that path. 0 means the
\ keys that were present were stored. 1 means the file could
\ not be opened, and nothing changed.
\ A bad value is skipped. A missing key keeps its current
\ value. The walker is not reset.
\ Xx and Yy are accepted and not stored. They are the last
\ plotted pixel, not the view.
\ julia-style is applied after the other keys. 1 selects
\ Mandelbrot. Any other value selects Julia through JV-STYLE.
\ p1 and p2 are stored in JV-P1 and JV-P2. fzoom-dist is
\ not in the file.

CREATE JV-IBUF 4096 ALLOT
CREATE JV-IPATH 256 ALLOT
VARIABLE JV-ILEN
VARIABLE JV-IPOS
VARIABLE JV-IEND
VARIABLE JV-ISEC
VARIABLE JV-ISAW
VARIABLE JV-ISTY
VARIABLE JV-LA
VARIABLE JV-LU

: JV-BLANK? ( c -- flag )
  DUP BL = OVER 9 = OR SWAP 13 = OR ;

\ Drop spaces, tabs, and CR from both ends.
: JV-LEAD ( c-addr u -- c-addr u )
  BEGIN
    DUP 0= IF EXIT THEN
    OVER C@ JV-BLANK? IF
      1 /STRING
    ELSE
      EXIT
    THEN
  AGAIN ;

: JV-TRAIL ( c-addr u -- c-addr u )
  BEGIN
    DUP 0= IF EXIT THEN
    2DUP + 1- C@ JV-BLANK? IF
      1-
    ELSE
      EXIT
    THEN
  AGAIN ;

: JV-TRIM ( c-addr u -- c-addr u )
  JV-LEAD JV-TRAIL ;

: JV-NUM ( c-addr u -- flag )
  DUP 0= IF 2DROP FALSE EXIT THEN
  >FLOAT ;

\ Leave the cell alone when the text is not a float, or when
\ the magnitude does not fit in Q28.
: JV-FX! ( c-addr u addr -- )
  >R
  JV-NUM 0= IF R> DROP EXIT THEN
  FDUP FABS 1000000000.0e0 F< 0= IF FDROP R> DROP EXIT THEN
  F>X R> ! ;

: JV-FN! ( c-addr u addr -- )
  >R
  JV-NUM 0= IF R> DROP EXIT THEN
  FDUP FABS 1000000000.0e0 F< 0= IF FDROP R> DROP EXIT THEN
  F>S R> ! ;

: JV-STYLE! ( c-addr u -- )
  JV-NUM 0= IF EXIT THEN
  FDUP FABS 1000000000.0e0 F< 0= IF FDROP EXIT THEN
  F>S JV-ISTY !
  -1 JV-ISAW ! ;

: JV-SECTION ( c-addr u -- )
  DUP 0= IF 2DROP EXIT THEN
  1 /STRING
  DUP IF
    2DUP + 1- C@ [CHAR] ] = IF 1- THEN
  THEN
  JV-TRIM
  2DUP S" mandelbrot" CEQUAL IF 2DROP 1 JV-ISEC ! EXIT THEN
  2DUP S" julia" CEQUAL IF 2DROP 2 JV-ISEC ! EXIT THEN
  2DROP 0 JV-ISEC ! ;

: JV-MAND-KEY ( ka ku va vu -- )
  2OVER S" distortion" CEQUAL IF 2SWAP 2DROP JV-DIST JV-FX! EXIT THEN
  2OVER S" detail" CEQUAL IF 2SWAP 2DROP JV-MDET JV-FN! EXIT THEN
  2OVER S" pattern" CEQUAL IF 2SWAP 2DROP JV-PAT JV-FN! EXIT THEN
  2OVER S" maxx" CEQUAL IF 2SWAP 2DROP JV-MAXX JV-FX! EXIT THEN
  2OVER S" minx" CEQUAL IF 2SWAP 2DROP JV-MINX JV-FX! EXIT THEN
  2OVER S" maxy" CEQUAL IF 2SWAP 2DROP JV-MAXY JV-FX! EXIT THEN
  2OVER S" miny" CEQUAL IF 2SWAP 2DROP JV-MINY JV-FX! EXIT THEN
  2DROP 2DROP ;

: JV-JUL-KEY ( ka ku va vu -- )
  2OVER S" xx" CEQUAL 2OVER S" yy" CEQUAL OR IF
    2DROP 2DROP EXIT
  THEN
  2OVER S" aa" CEQUAL IF 2SWAP 2DROP JV-AA JV-FX! EXIT THEN
  2OVER S" bb" CEQUAL IF 2SWAP 2DROP JV-BB JV-FX! EXIT THEN
  2OVER S" p1" CEQUAL IF 2SWAP 2DROP JV-P1 JV-FX! EXIT THEN
  2OVER S" p2" CEQUAL IF 2SWAP 2DROP JV-P2 JV-FX! EXIT THEN
  2OVER S" julia-detail" CEQUAL IF 2SWAP 2DROP JV-JDET JV-FN! EXIT THEN
  2OVER S" julia-style" CEQUAL IF 2SWAP 2DROP JV-STYLE! EXIT THEN
  2OVER S" color_false" CEQUAL IF 2SWAP 2DROP JV-CF JV-FN! EXIT THEN
  2OVER S" color_true" CEQUAL IF 2SWAP 2DROP JV-CT JV-FN! EXIT THEN
  2OVER S" colorstep" CEQUAL IF 2SWAP 2DROP JV-STEP JV-FN! EXIT THEN
  2OVER S" rgb-to-inc" CEQUAL IF 2SWAP 2DROP JV-INC JV-FN! EXIT THEN
  2OVER S" fzoom-posx" CEQUAL IF 2SWAP 2DROP JV-FZPX JV-FX! EXIT THEN
  2OVER S" fzoom-posye" CEQUAL IF 2SWAP 2DROP JV-FZPY JV-FX! EXIT THEN
  2OVER S" fposy" CEQUAL IF 2SWAP 2DROP JV-FPOSY JV-FX! EXIT THEN
  2OVER S" fposx" CEQUAL IF 2SWAP 2DROP JV-FPOSX JV-FX! EXIT THEN
  2OVER S" fdist" CEQUAL IF 2SWAP 2DROP JV-FDIST JV-FX! EXIT THEN
  2DROP 2DROP ;

: JV-ONEKEY ( ka ku va vu -- )
  JV-ISEC @ 1 = IF JV-MAND-KEY EXIT THEN
  JV-ISEC @ 2 = IF JV-JUL-KEY EXIT THEN
  2DROP 2DROP ;

\ c-addr u -- ka ku va vu true | false
: JV-ISPLIT ( c-addr u -- ka ku va vu true | false )
  JV-LU ! JV-LA !
  JV-LU @ 0 ?DO
    JV-LA @ I + C@ [CHAR] = = IF
      JV-LA @ I JV-TRIM
      JV-LA @ I + 1+ JV-LU @ I - 1- JV-TRIM
      TRUE UNLOOP EXIT
    THEN
  LOOP
  FALSE ;

: JV-FEED ( c-addr u -- )
  JV-TRIM
  DUP 0= IF 2DROP EXIT THEN
  OVER C@ DUP [CHAR] ; = SWAP [CHAR] # = OR IF 2DROP EXIT THEN
  OVER C@ [CHAR] [ = IF JV-SECTION EXIT THEN
  JV-ISPLIT 0= IF EXIT THEN
  JV-ONEKEY ;

\ The next line, not including the LF. IPOS moves past it.
: JV-NEXTLINE ( -- c-addr u )
  JV-IPOS @ JV-IEND !
  BEGIN
    JV-IEND @ JV-ILEN @ < IF
      JV-IEND @ JV-IBUF + C@ 10 <>
    ELSE
      FALSE
    THEN
  WHILE
    1 JV-IEND +!
  REPEAT
  JV-IBUF JV-IPOS @ +
  JV-IEND @ JV-IPOS @ -
  JV-IEND @ JV-ILEN @ < IF 1 JV-IEND +! THEN
  JV-IEND @ JV-IPOS ! ;

: JV-SCAN ( -- )
  0 JV-ISEC !
  0 JV-ISAW !
  0 JV-IPOS !
  BEGIN JV-IPOS @ JV-ILEN @ < WHILE
    JV-NEXTLINE JV-FEED
  REPEAT
  JV-ISAW @ IF
    JV-ISTY @ JV-STYLE
    JV-ISTY @ 1 = IF -1 ELSE 0 THEN JV-MAN !
  THEN ;

\ OPEN-FILE already consumes the path. The cell under it stays.
: JV-READ ( c-addr u -- flag )
  R/O OPEN-FILE IF DROP FALSE EXIT THEN
  >R
  JV-IBUF 4095 R@ READ-FILE
  R> CLOSE-FILE DROP
  IF DROP FALSE EXIT THEN
  JV-ILEN !
  TRUE ;

: JV-INI ( c-addr u -- ior )
  DUP 0= IF 2DROP 1 EXIT THEN
  JV-READ 0= IF 1 EXIT THEN
  JV-SCAN
  0 ;

\ True when a file was applied. Cancel stays quiet.
: JV-LOAD ( -- flag )
  (APP-FILE-CHOOSE) IF FALSE EXIT THEN
  JV-IPATH 250 (APP-FILE-PATH) ?DUP 0= IF FALSE EXIT THEN
  JV-IPATH SWAP JV-INI IF
    S" Could not read that parameter file." JV-LINE
    FALSE EXIT
  THEN
  TRUE ;
