\ FIXEDPOINT.fth — single-cell fixed point, first slice
\
\ Introductory and incomplete. Division, square root, and trig are later.
\
\ A value is one signed cell. XBITS fraction bits sit at the bottom.
\ The default is 28. Every value in one calculation uses that same scale.
\ + and - are the cell words. X* multiplies, then divides the double-cell
\ product by 2^XBITS. The quotient rounds toward zero.
\
\ Load:
\   FROMLIB FLOAD FixPoint/FIXEDPOINT.fth
\   ALSO FIXED-POINT
\
\ Not in this slice: division, square root, and trig.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW FIXEDPOINT-MODULE [THEN]

ONLY FORTH DEFINITIONS
VOCABULARY FIXED-POINT
ONLY FORTH ALSO FIXED-POINT DEFINITIONS
ALSO FLOATING
DECIMAL

28 VALUE XBITS

: XUNIT ( -- n )
  1 XBITS LSHIFT ;

\ ( F: r -- ) ( -- n )
: F>X ( F: r -- n )
  XUNIT S>D D>F F* F>S ;

\ ( n -- ) ( F: -- r )
: X>F ( n -- ) ( F: -- r )
  S>D D>F XUNIT S>D D>F F/ ;

: X* ( n1 n2 -- n3 )
  XUNIT */ ;

ONLY FORTH DEFINITIONS
