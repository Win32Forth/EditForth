\ BANNER.fth — big character printer
\
\ From F83X, made sequential by Tom Zimmer. The DOS program cleared the
\ screen and looped until a key. This copy prints on the console and
\ returns when a key is waiting. It runs on EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/BANNER.fth
\   BANNER-DEMO
\
\ BANNER ( c-addr u -- ) prints one message in an 8-by-7 glyph.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW BANNER_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

[UNDEFINED] BOUNDS [IF]
: BOUNDS ( a n -- a+n a ) OVER + SWAP ;
[THEN]

CREATE CHAR-MATRIX
    (  ) $00 C, $00 C, $00 C, $00 C, $00 C, $00 C, $00 C, $00 C,
    ( !) $20 C, $20 C, $20 C, $20 C, $20 C, $00 C, $20 C, $00 C,
    ( ") $50 C, $50 C, $50 C, $00 C, $00 C, $00 C, $00 C, $00 C,
    ( #) $50 C, $50 C, $F8 C, $50 C, $F8 C, $50 C, $50 C, $00 C,
    ( $) $20 C, $78 C, $A0 C, $70 C, $28 C, $F0 C, $20 C, $00 C,
    ( %) $C0 C, $C8 C, $10 C, $20 C, $40 C, $98 C, $18 C, $00 C,
    ( &) $40 C, $A0 C, $A0 C, $40 C, $A8 C, $90 C, $68 C, $00 C,
    ( ') $30 C, $30 C, $10 C, $20 C, $00 C, $00 C, $00 C, $00 C,
    ( () $20 C, $40 C, $80 C, $80 C, $80 C, $40 C, $20 C, $00 C,
    ( cp) $20 C, $10 C, $08 C, $08 C, $08 C, $10 C, $20 C, $00 C,
    ( *) $20 C, $A8 C, $70 C, $20 C, $70 C, $A8 C, $20 C, $00 C,
    ( +) $00 C, $20 C, $20 C, $70 C, $20 C, $20 C, $00 C, $00 C,
    ( ,) $00 C, $00 C, $00 C, $30 C, $30 C, $10 C, $20 C, $00 C,
    ( -) $00 C, $00 C, $00 C, $70 C, $00 C, $00 C, $00 C, $00 C,
    ( .) $00 C, $00 C, $00 C, $00 C, $00 C, $30 C, $30 C, $00 C,
    ( /) $00 C, $08 C, $10 C, $20 C, $40 C, $80 C, $00 C, $00 C,
    ( 0) $70 C, $88 C, $98 C, $A8 C, $C8 C, $88 C, $70 C, $00 C,
    ( 1) $20 C, $60 C, $20 C, $20 C, $20 C, $20 C, $70 C, $00 C,
    ( 2) $70 C, $88 C, $08 C, $30 C, $40 C, $80 C, $F8 C, $00 C,
    ( 3) $F8 C, $10 C, $20 C, $30 C, $08 C, $88 C, $70 C, $00 C,
    ( 4) $10 C, $30 C, $50 C, $90 C, $F8 C, $10 C, $10 C, $00 C,
    ( 5) $F8 C, $80 C, $F0 C, $08 C, $08 C, $88 C, $70 C, $00 C,
    ( 6) $38 C, $40 C, $80 C, $F0 C, $88 C, $88 C, $70 C, $00 C,
    ( 7) $F8 C, $08 C, $10 C, $20 C, $40 C, $40 C, $40 C, $00 C,
    ( 8) $70 C, $88 C, $88 C, $70 C, $88 C, $88 C, $70 C, $00 C,
    ( 9) $70 C, $88 C, $88 C, $78 C, $08 C, $10 C, $E0 C, $00 C,
    ( :) $00 C, $60 C, $60 C, $00 C, $60 C, $60 C, $00 C, $00 C,
    ( ;) $00 C, $60 C, $60 C, $00 C, $60 C, $60 C, $40 C, $00 C,
    ( <) $10 C, $20 C, $40 C, $80 C, $40 C, $20 C, $10 C, $00 C,
    ( =) $00 C, $00 C, $F8 C, $00 C, $F8 C, $00 C, $00 C, $00 C,
    ( >) $40 C, $20 C, $10 C, $08 C, $10 C, $20 C, $40 C, $00 C,
    ( ?) $70 C, $88 C, $10 C, $20 C, $20 C, $00 C, $20 C, $00 C,
    ( @) $70 C, $88 C, $A8 C, $B8 C, $B0 C, $80 C, $78 C, $00 C,
    ( A) $20 C, $70 C, $88 C, $88 C, $F8 C, $88 C, $88 C, $00 C,
    ( B) $F0 C, $88 C, $88 C, $F0 C, $88 C, $88 C, $F0 C, $00 C,
    ( C) $70 C, $88 C, $80 C, $80 C, $80 C, $88 C, $70 C, $00 C,
    ( D) $F0 C, $48 C, $48 C, $48 C, $48 C, $48 C, $F0 C, $00 C,
    ( E) $F8 C, $80 C, $80 C, $F0 C, $80 C, $80 C, $F8 C, $00 C,
    ( F) $F8 C, $80 C, $80 C, $F0 C, $80 C, $80 C, $80 C, $00 C,
    ( G) $78 C, $80 C, $80 C, $80 C, $98 C, $88 C, $78 C, $00 C,
    ( H) $88 C, $88 C, $88 C, $F8 C, $88 C, $88 C, $88 C, $00 C,
    ( I) $70 C, $20 C, $20 C, $20 C, $20 C, $20 C, $70 C, $00 C,
    ( J) $08 C, $08 C, $08 C, $08 C, $08 C, $88 C, $78 C, $00 C,
    ( K) $88 C, $90 C, $A0 C, $C0 C, $A0 C, $90 C, $88 C, $00 C,
    ( L) $80 C, $80 C, $80 C, $80 C, $80 C, $80 C, $F8 C, $00 C,
    ( M) $88 C, $D8 C, $A8 C, $A8 C, $88 C, $88 C, $88 C, $00 C,
    ( N) $88 C, $88 C, $C8 C, $A8 C, $98 C, $88 C, $88 C, $00 C,
    ( O) $70 C, $88 C, $88 C, $88 C, $88 C, $88 C, $70 C, $00 C,
    ( P) $F0 C, $88 C, $88 C, $F0 C, $80 C, $80 C, $80 C, $00 C,
    ( Q) $70 C, $88 C, $88 C, $88 C, $A8 C, $90 C, $68 C, $00 C,
    ( R) $F0 C, $88 C, $88 C, $F0 C, $A0 C, $90 C, $88 C, $00 C,
    ( S) $70 C, $88 C, $80 C, $70 C, $08 C, $88 C, $70 C, $00 C,
    ( T) $F8 C, $20 C, $20 C, $20 C, $20 C, $20 C, $20 C, $00 C,
    ( U) $88 C, $88 C, $88 C, $88 C, $88 C, $88 C, $70 C, $00 C,
    ( V) $88 C, $88 C, $88 C, $88 C, $88 C, $50 C, $20 C, $00 C,
    ( W) $88 C, $88 C, $88 C, $A8 C, $A8 C, $D8 C, $88 C, $00 C,
    ( X) $88 C, $88 C, $50 C, $20 C, $50 C, $88 C, $88 C, $00 C,
    ( Y) $88 C, $88 C, $50 C, $20 C, $20 C, $20 C, $20 C, $00 C,
    ( Z) $F8 C, $08 C, $10 C, $20 C, $40 C, $80 C, $F8 C, $00 C,
    ( [) $78 C, $40 C, $40 C, $40 C, $40 C, $40 C, $78 C, $00 C,
    ( \) $00 C, $80 C, $40 C, $20 C, $10 C, $08 C, $00 C, $00 C,
    ( ]) $F0 C, $10 C, $10 C, $10 C, $10 C, $10 C, $F0 C, $00 C,
    ( ^) $00 C, $00 C, $20 C, $50 C, $88 C, $00 C, $00 C, $00 C,
    ( _) $00 C, $00 C, $00 C, $00 C, $00 C, $00 C, $00 C, $F8 C,

CREATE BITS  128 C, 64 C, 32 C, 16 C, 8 C, 4 C, 2 C, 1 C,

: BIT ( byte n -- flag )
  BITS + C@ AND 0= 1+ ;

: LC>UC ( c -- c )
  DUP 96 128 WITHIN  32 AND - ;

: BCHAR ( byte -- )
  7 0 DO
    DUP I BIT IF 35 EMIT ELSE 32 EMIT THEN
  LOOP DROP ;

: BANNER ( c-addr u -- )
  BOUNDS
  8 0 DO
    CR 2DUP
    ?DO
      I C@ 127 AND LC>UC 32 -
      DUP 0 64 WITHIN IF
        8 * CHAR-MATRIX + J + C@ BCHAR
      ELSE
        DROP 7 0 DO 32 EMIT LOOP
      THEN
    LOOP
  LOOP
  2DROP ;

VARIABLE BN-STOP

: BN-PAUSE ( -- )
  MS@ 1200 +
  BEGIN DUP MS@ U<  KEY? OR UNTIL DROP
  KEY? IF -1 BN-STOP ! THEN ;

: BANNER-DEMO ( -- )
  CR ." BANNER prints large characters. A key stops it." CR
  0 BN-STOP !
  BEGIN
    BN-STOP @ 0=
  WHILE
    CR S"   WELCOME" BANNER
    CR S" TO EDITFORTH" BANNER
    BN-PAUSE
    BN-STOP @ 0= IF
      CR S"    BANNER" BANNER
      CR S"   PROGRAM" BANNER
      BN-PAUSE
    THEN
  REPEAT
  KEY? IF KEY DROP THEN
  CR ." BANNER finished." CR ;

CR .( Run: BANNER-DEMO ) CR
