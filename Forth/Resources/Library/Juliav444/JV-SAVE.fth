\ JV-SAVE.fth — write the TRUECOLOR picture as JPEG, PNG, or TIFF.
\
\ Included by the Julia files while GRAPHICS is in the search order.
\ S opens the picture panel. It offers JPEG, PNG, or TIFF.
\ The name still ends in .jpg, .jpeg, .png, .tif, or .tiff.
\ G-PIX is BGRA, top row first. The writers want RGB in that
\ same order. JPEG and PNG come from Sample/IMAGE-OUT.fth.
\ TIFF is uncompressed RGB.

FROMLIB S" Sample/IMAGE-OUT.fth" INCLUDED

CREATE JV-SVPATH 256 ALLOT
VARIABLE JV-SVP
VARIABLE JV-SVW
VARIABLE JV-SVH
VARIABLE JV-SVPIX
VARIABLE JV-SVPA
VARIABLE JV-SVPU
VARIABLE JV-SVBUF
VARIABLE JV-SVLEN
VARIABLE JV-RGBP

: JV-W8 ( c -- )
  JV-SVP @ C!
  1 JV-SVP +! ;

: JV-W2 ( u -- )
  DUP JV-W8
  8 RSHIFT JV-W8 ;

: JV-W4 ( u -- )
  DUP JV-W2
  16 RSHIFT JV-W2 ;

\ TIFF types: SHORT is 3, LONG is 4. A short value that fits
\ is stored in the low half of the four-byte field.
: JV-ENT ( tag type count value -- )
  >R >R >R
  JV-W2
  R> JV-W2
  R> JV-W4
  R> JV-W4 ;

\ Uncompressed chunky RGB. The strip starts at byte 140.
: JV-TIFF ( pix w h c-addr u -- ior )
  JV-SVPU ! JV-SVPA ! JV-SVH ! JV-SVW ! JV-SVPIX !
  JV-SVW @ JV-SVH @ * 3 *
  DUP 0= IF DROP 1 EXIT THEN
  140 + JV-SVLEN !
  JV-SVLEN @ ALLOCATE ?DUP IF DROP DROP 1 EXIT THEN
  JV-SVBUF !
  JV-SVBUF @ JV-SVP !
  [CHAR] I JV-W8 [CHAR] I JV-W8
  42 JV-W2
  8 JV-W4
  10 JV-W2
  256 4 1 JV-SVW @ JV-ENT
  257 4 1 JV-SVH @ JV-ENT
  258 3 3 134 JV-ENT
  259 3 1 1 JV-ENT
  262 3 1 2 JV-ENT
  273 4 1 140 JV-ENT
  277 3 1 3 JV-ENT
  278 4 1 JV-SVH @ JV-ENT
  279 4 1 JV-SVW @ JV-SVH @ * 3 * JV-ENT
  284 3 1 1 JV-ENT
  0 JV-W4
  8 JV-W2 8 JV-W2 8 JV-W2
  JV-SVPIX @ JV-SVBUF @ 140 + JV-SVW @ JV-SVH @ * 3 * MOVE
  JV-SVPA @ JV-SVPU @ W/O BIN CREATE-FILE
  ?DUP IF
    NIP
    JV-SVBUF @ FREE DROP
    EXIT
  THEN
  >R
  JV-SVBUF @ JV-SVLEN @ R@ WRITE-FILE
  R> CLOSE-FILE OR
  JV-SVBUF @ FREE DROP ;

\ One RGB byte per channel. Row 0 is the top of G-PIX.
\ The buffer stays in JV-RGBP. R@ inside the DO is the column.
: JV-PIXRGB ( -- addr )
  G-PX G-PY * 3 * ALLOCATE THROW JV-RGBP !
  G-PY 0 DO
    G-PX 0 DO
      G-PIX J G-PX * I + 4 * +
      DUP 2 + C@
      OVER 1+ C@
      ROT C@
      J G-PX * I + 3 * JV-RGBP @ +
      SWAP
      OVER 2 + C!
      SWAP
      OVER 1+ C!
      C!
    LOOP
  LOOP
  JV-RGBP @ ;

: JV-CLOW ( c -- c )
  DUP [CHAR] A [CHAR] Z 1+ WITHIN IF 32 OR THEN ;

\ I is the return-stack top. Do not >R inside this DO.
: JV-SAME? ( c-addr1 u1 c-addr2 u2 -- flag )
  ROT OVER <> IF 2DROP DROP FALSE EXIT THEN
  0 DO
    OVER I + C@ JV-CLOW
    OVER I + C@ JV-CLOW
    <> IF
      2DROP UNLOOP FALSE EXIT
    THEN
  LOOP
  2DROP TRUE ;

: JV-LAST ( c-addr u n -- c-addr2 n )
  >R
  DUP R@ < IF
    R> DROP 2DROP 0 0 EXIT
  THEN
  R@ - +
  R> ;

\ 1 png, 2 jpeg, 3 tiff, 0 anything else.
: JV-KIND ( c-addr u -- n )
  2DUP 5 JV-LAST S" .jpeg" JV-SAME? IF 2DROP 2 EXIT THEN
  2DUP 5 JV-LAST S" .tiff" JV-SAME? IF 2DROP 3 EXIT THEN
  2DUP 4 JV-LAST S" .jpg" JV-SAME? IF 2DROP 2 EXIT THEN
  2DUP 4 JV-LAST S" .png" JV-SAME? IF 2DROP 1 EXIT THEN
  2DUP 4 JV-LAST S" .tif" JV-SAME? IF 2DROP 3 EXIT THEN
  2DROP 0 ;

: JV-EMIT ( pix w h c-addr u n -- ior )
  DUP 1 = IF DROP save-png EXIT THEN
  DUP 2 = IF DROP save-jpg EXIT THEN
  DROP JV-TIFF ;

: JV-WRITE ( c-addr u -- ior )
  G-PIX 0= G-PX G-PY * 0= OR IF 2DROP 1 EXIT THEN
  2DUP JV-KIND
  DUP 0= IF DROP 2DROP 1 EXIT THEN
  >R
  JV-PIXRGB DUP JV-RGBP !
  G-PX G-PY
  4 PICK 4 PICK
  R> JV-EMIT
  >R 2DROP
  JV-RGBP @ FREE DROP
  R> ;

: JV-ASK ( -- ior )
  [DEFINED] (APP-FILE-SAVE-PICTURE) [IF]
    (APP-FILE-SAVE-PICTURE)
  [ELSE]
    (APP-FILE-SAVE-AS)
  [THEN] ;

: JV-SAVE ( -- )
  G-PIX 0= IF
    S" No picture to save." JV-LINE
    EXIT
  THEN
  JV-ASK IF EXIT THEN
  JV-SVPATH 250 (APP-FILE-PATH) ?DUP 0= IF EXIT THEN
  JV-SVPATH SWAP 2DUP JV-KIND 0= IF
    2DROP
    S" The name needs to end in .jpg, .png, or .tiff." JV-LINE
    EXIT
  THEN
  JV-WRITE IF
    S" Could not save that picture." JV-LINE
  THEN ;
