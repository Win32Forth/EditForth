\ lines-demo.fth — bouncing Bresenham trails for EditForth / 64Forth
\ Port of the JimmyForth fs-demo. Public domain.
\ Uses GRAPHICS LINE (x0 y0 x1 y1 --), already Bresenham in app-points.fth.
\ Stop: any key (in the graphics window).

\ Editor EMIT: own WINDOW/KEY loop — stock wrap only (no KEY-DROP pause).
EMIT-NO-WRAPPER

ONLY FORTH ALSO GRAPHICS DEFINITIONS

16 CONSTANT TRAIL

CREATE P   40 , 20 , 500 , 300 ,          \ x0 y0 x1 y1
CREATE V    5 ,  3 ,  -4 ,   5 ,
CREATE HIST  TRAIL 4 CELLS * ALLOT
VARIABLE HEAD
VARIABLE TICKS

: P@     ( k -- n )  CELLS P + @ ;
: V@     ( k -- n )  CELLS V + @ ;
: LIMIT  ( k -- n )  1 AND IF G-PY ELSE G-PX THEN 1- ;

: BOUNCE ( -- )
  4 0 DO
    I V@  I CELLS P + +!
    I P@ 0<  I P@ I LIMIT > OR IF
      I V@ NEGATE  I CELLS V + !
      I V@  I CELLS P + +!
    THEN
  LOOP ;

: ENTRY ( n -- a )  4 CELLS * HIST + ;
: SAVE  ( -- )
  4 0 DO  I P@  I CELLS HEAD @ ENTRY + !  LOOP
  HEAD @ 1+ TRAIL MOD HEAD ! ;

\ JimmyForth palette indices 2..9, nibble colors expanded (* 17)
CREATE PAL
  238 ,  68 ,  51 ,     \ e43
  255 , 153 ,  51 ,     \ f93
  255 , 221 ,  51 ,     \ fd3
   85 , 204 ,  85 ,     \ 5c5
   51 , 204 , 221 ,     \ 3cd
   51 , 102 , 238 ,     \ 36e
  153 ,  85 , 238 ,     \ 95e
  255 ,  85 , 187 ,     \ f5b

: PEN ( k -- )
  TICKS @ 4 / +  8 MOD  3 CELLS * PAL +
  DUP @  SWAP CELL+ DUP @  SWAP CELL+ @  RGB COLOR ! ;

: TRAILS ( -- )
  TRAIL 0 DO
    I ENTRY
    DUP @  SWAP CELL+ DUP @  SWAP CELL+ DUP @  SWAP CELL+ @
    I PEN  LINE
  LOOP ;

: FRAME ( -- )
  PIX-ERASE  BOUNCE  SAVE  TRAILS
  1 TICKS +!  PREFRESH ;

: PREFILL ( -- )
  TRAIL 0 DO  BOUNCE SAVE  LOOP ;

: RESET-LINES ( -- )
  40 P !  20 P CELL+ !  500 P 2 CELLS + !  300 P 3 CELLS + !
  5 V !   3 V CELL+ !   -4 V 2 CELLS + !    5 V 3 CELLS + !
  0 HEAD !  0 TICKS !
  ;

: LINES ( -- )
  PIXEL-ON  TRUECOLOR  S" Bresenham lines" APP-NAME
  WINDOW  WHITE  PCLS
  RESET-LINES  PREFILL
  BEGIN  FRAME  16 MS  KEY?  UNTIL
  KEY DROP  WINDOW-OFF ;

\ Stay in GRAPHICS for the runner (do not redefine Autoload's FORTH MAIN).
: RUN-LINES  ( -- )  LINES ;

\ Leave search order FORTH then GRAPHICS: console CR / .( win (FORTH first),
\ and RUN-LINES stays findable for EMIT-WINDOW-APP without a manual ALSO.
\ Do not end with ONLY FORTH (drops GRAPHICS) or ONLY GRAPHICS (ALSO missing).
ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

CR .( LINES - bouncing trails; any key stops) CR
CR .( Run:  RUN-LINES ) CR
CR .( Emit: EMIT-WINDOW-APP RUN-LINES ) CR
CR .( Click the graphics window, then press a key to stop.) CR
