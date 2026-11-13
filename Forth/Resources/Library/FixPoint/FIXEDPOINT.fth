\ FIXEDPOINT.fth — single-cell fixed point
\
\ A value is one signed cell. XBITS fraction bits sit at the bottom.
\ The default is 28. This file reads XBITS when it loads.
\ A later TO XBITS does not change the literals in these words.
\ Every value in one calculation uses that same scale.
\
\ + and - are the cell words. 2* doubles a value. 2/ halves it.
\ X* multiplies and X/ divides. Both round toward zero.
\ XSQRT of a negative value is 0.
\ XSIN and XCOS take radians. Inside a few turns of zero they stay
\ within 2 cells of the nearest value. A huge angle loses that,
\ because the turn is reduced with a rounded 2*pi.
\
\ Log, exp, and inverse trig are not in this file.
\
\ Load:
\   FROMLIB FLOAD FixPoint/FIXEDPOINT.fth
\   ALSO FIXED-POINT
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW FIXEDPOINT-MODULE [THEN]

ONLY FORTH DEFINITIONS
VOCABULARY FIXED-POINT
ONLY FORTH ALSO FIXED-POINT DEFINITIONS
ALSO FLOATING
DECIMAL

28 VALUE XBITS

\ Compile 2^XBITS into the caller. The value is frozen at load.
: XUNIT ( -- n )
  [ 1 XBITS LSHIFT ] LITERAL POSTPONE LITERAL ; IMMEDIATE

\ ( F: r -- ) ( -- n )
: F>X ( F: r -- n )
  XUNIT S>D D>F F* F>S ;

\ ( n -- ) ( F: -- r )
: X>F ( n -- ) ( F: -- r )
  S>D D>F XUNIT S>D D>F F/ ;

\ M*, then a logical right shift of XBITS on the double product.
\ The high cell is the sign. A negative product is biased by
\ 2^XBITS-1 so the shift rounds toward zero instead of down.
: X* ( n1 n2 -- n3 )
  M*
  DUP 0< IF [ 1 XBITS LSHIFT 1- ] LITERAL 0 D+ THEN
  [ 64 XBITS - ] LITERAL LSHIFT
  SWAP
  [ XBITS ] LITERAL RSHIFT
  OR ;

\ Shift a double left by XBITS. ( lo hi -- lo hi )
: (XLSHIFT) ( d1 -- d2 )
  SWAP >R
  [ XBITS ] LITERAL LSHIFT
  R@ [ 64 XBITS - ] LITERAL RSHIFT
  OR
  R> [ XBITS ] LITERAL LSHIFT
  SWAP ;

\ Fixed divide. Shifts the dividend up by XBITS, then SM/REM.
\ A zero divisor returns -1. A quotient that does not fit in
\ the cell is the kernel divide's overflow result.
: X/ ( n1 n2 -- n3 )
  SWAP S>D (XLSHIFT) ROT SM/REM NIP ;

\ Integer root of n<<XBITS, so the result keeps this scale.
\ Zero and negative return 0. The guess starts above every root
\ that fits, and each step is (g + n/g)/2.
: XSQRT ( n1 -- n2 )
  DUP 1 < IF DROP 0 EXIT THEN
  S>D (XLSHIFT)
  [ 1 46 LSHIFT ] LITERAL
  BEGIN
    \ The guess sits on the radicand, so copy the double before UM/MOD.
    DUP >R
    >R
    2DUP R> UM/MOD NIP
    R> SWAP OVER + 2/
    2DUP >
  WHILE
    NIP
  REPEAT
  DROP NIP NIP ;

\ Radians, nearest cell. Frozen at load, same rule as XUNIT.
843314857 CONSTANT XPI
421657428 CONSTANT XPI/2
1686629713 CONSTANT X2PI

\ Taylor factor for sin on [-pi/2, pi/2]. u is z*z.
: (SPOLY) ( u -- f )
  XUNIT OVER 272 / -
  OVER 210 / X*  XUNIT SWAP -
  OVER 156 / X*  XUNIT SWAP -
  OVER 110 / X*  XUNIT SWAP -
  OVER 72 / X*   XUNIT SWAP -
  OVER 42 / X*   XUNIT SWAP -
  OVER 20 / X*   XUNIT SWAP -
  OVER 6 / X*    XUNIT SWAP -
  NIP ;

\ Taylor value for cos on [-pi/2, pi/2].
: (CPOLY) ( u -- f )
  XUNIT OVER 240 / -
  OVER 182 / X*  XUNIT SWAP -
  OVER 132 / X*  XUNIT SWAP -
  OVER 90 / X*   XUNIT SWAP -
  OVER 56 / X*   XUNIT SWAP -
  OVER 30 / X*   XUNIT SWAP -
  OVER 12 / X*   XUNIT SWAP -
  OVER 2 / X*    XUNIT SWAP -
  NIP ;

: (XSIN0) ( z -- sin )
  DUP >R
  DUP X* (SPOLY)
  R> X* ;

: (XCOS0) ( z -- cos )
  DUP X* (CPOLY) ;

\ Reduce to [-pi, pi], then fold into the Taylor range.
\ (XTRIG) returns sine under cosine.
: (XTRIG) ( ang -- sin cos )
  S>D X2PI SM/REM DROP
  DUP XPI > IF X2PI - THEN
  DUP XPI NEGATE < IF X2PI + THEN
  DUP XPI/2 > IF
    XPI SWAP -
    DUP (XCOS0) SWAP (XSIN0) SWAP NEGATE
    EXIT
  THEN
  DUP XPI/2 NEGATE < IF
    XPI +
    DUP (XCOS0) SWAP (XSIN0) NEGATE SWAP NEGATE
    EXIT
  THEN
  DUP (XCOS0) SWAP (XSIN0) SWAP ;

: XSIN ( n1 -- n2 )
  (XTRIG) DROP ;

: XCOS ( n1 -- n2 )
  (XTRIG) NIP ;

ONLY FORTH DEFINITIONS
