\ LINES.fth — the Sample/LINES fan, linked into a SOWM window.
\ Load after the ball. Both stay linked. Public domain.

ONLY FORTH DEFINITIONS
DECIMAL
[DEFINED] ANEW [IF] ANEW SOWM_LINES [THEN]

CREATE LINES-HUE
  $E6C36A , $6CB6FF , $E07070 , $70C070 ,
  $E0E070 , $C070E0 , $70E0E0 , $F0F0F0 ,

\ Same generator as Sample/LINES.fth. Seeds are private cells 0, 1, and 2.
: LRND ( n -- n2 )
  1 MAX
  0 SOWM-P@ 177 /MOD 2*    SWAP 171 * SWAP - $FFFF AND DUP 0 SOWM-P!
  1 SOWM-P@ 176 /MOD 35 *  SWAP 172 * SWAP - $FFFF AND DUP 1 SOWM-P!
  2 SOWM-P@ 178 /MOD 63 *  SWAP 170 * SWAP - $FFFF AND DUP 2 SOWM-P!
  + + SWAP MOD ;

: LINES-STEP ( -- )
  SOWM-OUT @ SOWM-LIVE? 0= IF EXIT THEN
  7 SOWM-P@ 0= IF
    MS@ $FFFF AND 0 SOWM-P!
    MS@ 2* 1- $FFFF AND 1 SOWM-P!
    MS@ 2/ 1+ $FFFF AND 2 SOWM-P!
    -1 7 SOWM-P!
  THEN
  SOWM-OUT @ SOWM-VIEW >R >R 2DROP R> R>
  2DUP
  SWAP 1 MAX LRND 3 SOWM-P!
  1 MAX LRND 4 SOWM-P!
  SWAP 1 MAX LRND 5 SOWM-P!
  1 MAX LRND 6 SOWM-P!
;

: LINES-DRAW ( -- )
  7 SOWM-P@ 0= IF EXIT THEN
  0 SOWM-P@ 7 AND CELLS LINES-HUE + @ SOWM-INK !
  12 0 DO
    3 SOWM-P@ I +
    4 SOWM-P@ I -
    5 SOWM-P@ I -
    6 SOWM-P@ I +
    SOWM-LINE
  LOOP
;

['] LINES-STEP ['] LINES-DRAW 0 SOWM-LINK

\ Present when the ball was loaded first. Prints nothing on success.
[DEFINED] BALL-STEP [IF]
: LINES-SEE ( -- )
  SOWM-PN @ 2 T=
  0 SOWM-PREC @ ['] BALL-STEP T=
  1 SOWM-PREC @ ['] LINES-STEP T=
;
[THEN]