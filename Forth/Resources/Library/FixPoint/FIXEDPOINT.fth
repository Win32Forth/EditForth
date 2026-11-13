\ FIXEDPOINT.fth — single-cell fixed point
\
\ A value is one signed cell. XBITS fraction bits sit at the bottom.
\ The default is 28. This file reads XBITS when it loads.
\
\ + and - are the cell words. 2* doubles a value. 2/ halves it.
\ X* multiplies and X/ divides. Both round toward zero.
\ XSQRT of a negative value is 0.
\ XSIN and XCOS take radians. Inside a few turns of zero they stay
\ within 2 cells of the nearest value. A huge angle loses that,
\ because the turn is reduced with a rounded 2*pi.
\
\ XLN is the natural log. XLOG is base 10. Zero and negative return 0.
\ XEXP is e^x. XALOG is 10^x. A result smaller than one cell is 0.
\ A result that does not fit is the largest cell.
\ XASIN and XACOS outside [-1,1] return 0. XATAN2 of 0 0 returns 0.
\ Those eight stay within 3 cells of the nearest value.
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

[UNDEFINED] XBITS 
[IF] 28 CONSTANT XBITS 
[ELSE] .( Externally defined XBITS = ) XBITS . [THEN]

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

\ ln 2 and ln 10, rounded at load. The wide forms keep the fraction.
\ (XLOG2F) is log2(10)-3 at 2^64. The 3 is added on its own.
3196577161300663915 CONSTANT (XLN2)
49946518145322874 CONSTANT (XLN2+)
618095479 CONSTANT (XLN10)
5938525176524057593 CONSTANT (XLOG2F)
111189606 CONSTANT (XTAN8)
210828714 CONSTANT (XPI4)
379625062 CONSTANT (XSQRT2)
1 62 LSHIFT CONSTANT (X62)
1 XBITS LSHIFT CONSTANT (X1)
1 63 LSHIFT 1- CONSTANT (XMAX)

\ Q62 multiply. Same bias as X*, then a 62-bit shift.
: (X*62) ( n1 n2 -- n3 )
  M*
  DUP 0< IF [ 1 62 LSHIFT 1- ] LITERAL 0 D+ THEN
  2 LSHIFT
  SWAP
  62 RSHIFT
  OR ;

\ Logical left shift of a double by 6. ( lo hi -- lo hi )
: (DSHL6) ( d1 -- d2 )
  6 LSHIFT
  OVER 58 RSHIFT OR
  SWAP
  6 LSHIFT
  SWAP ;

\ Nearest cell after a right shift. Half goes away from zero.
: (XNEAR) ( n sh -- n2 )
  SWAP DUP 0< >R
  ABS SWAP
  DUP >R
  1- 1 SWAP LSHIFT
  +
  R> RSHIFT
  R> IF NEGATE THEN ;

\ x = k*ln2 + f, with f a Q62 fraction in [-ln2/2, ln2/2].
: (XEXPRED) ( n -- k f )
  S>D (XLSHIFT) (DSHL6)
  (XLN2) SM/REM
  SWAP
  DUP ABS 2* (XLN2) >= IF
    DUP 0< IF
      (XLN2) +
      SWAP 1- SWAP
    ELSE
      (XLN2) -
      SWAP 1+ SWAP
    THEN
  THEN ;

\ exp(f) at Q62. f is under the unit, and stays there.
: (XEXPPOLY) ( f -- p )
  DUP >R
  (X62)
  16
  BEGIN
    >R
    OVER (X*62)
    R@ /
    (X62) +
    R> 1-
    DUP 0=
  UNTIL
  DROP NIP
  R> DROP ;

\ Turn Q62 exp(f) and the power of two into a Q28 cell.
\ A positive (k-34) shifts left. A negative one shifts right.
: (XEXP-SCALE) ( p k -- n )
  34 -
  DUP 0= IF DROP EXIT THEN
  DUP 0> IF
    DUP 62 >= IF 2DROP (XMAX) EXIT THEN
    2DUP
    (XMAX) SWAP RSHIFT
    > IF
      2DROP (XMAX)
    ELSE
      LSHIFT
    THEN
    EXIT
  THEN
  NEGATE
  DUP 62 > IF 2DROP 0 EXIT THEN
  (XNEAR) ;

: (XEXP-KF) ( k f -- n )
  (XEXPPOLY) SWAP (XEXP-SCALE) ;

: XEXP ( n1 -- n2 )
  (XEXPRED) (XEXP-KF) ;

\ Nearest cell of a double after a right shift of 30.
: (DNEAR30) ( d -- n )
  DUP 0< >R
  R@ IF DNEGATE THEN
  [ 1 29 LSHIFT ] LITERAL 0 D+
  SWAP 30 RSHIFT
  SWAP 34 LSHIFT
  OR
  R> IF NEGATE THEN ;

\ 10^x for a positive cell. x*log2(10) is built at 2^92.
: (XALOG+) ( n -- k f )
  DUP 3 *
  0 SWAP
  ROT (XLOG2F) M*
  D+
  DUP 28 RSHIFT
  OVER [ 1 27 LSHIFT ] LITERAL AND IF 1+ THEN
  DUP >R
  28 LSHIFT
  -
  (DNEAR30)
  R> SWAP
  (XLN2) (X*62) ;

: XALOG ( n1 -- n2 )
  DUP 0< >R
  ABS
  (XALOG+)
  R> IF SWAP NEGATE SWAP NEGATE THEN
  (XEXP-KF) ;

\ m in [sqrt(1/2), sqrt(2)], and the power of two that got it there.
: (XNORM) ( n -- m e )
  0
  BEGIN OVER [ 1 XBITS LSHIFT 1 LSHIFT ] LITERAL >= WHILE
    SWAP 2/ SWAP 1+
  REPEAT
  BEGIN OVER (X1) < WHILE
    SWAP 2* SWAP 1-
  REPEAT
  OVER (XSQRT2) > IF
    SWAP 2/ SWAP 1+
  THEN ;

\ atanh at Q62. s*s is consumed by the last NIP.
: (XATANH) ( s -- a )
  DUP >R
  DUP (X*62)
  [ 1 62 LSHIFT 13 / ] LITERAL
  OVER (X*62) [ 1 62 LSHIFT 11 / ] LITERAL +
  OVER (X*62) [ 1 62 LSHIFT 9 / ] LITERAL +
  OVER (X*62) [ 1 62 LSHIFT 7 / ] LITERAL +
  OVER (X*62) [ 1 62 LSHIFT 5 / ] LITERAL +
  OVER (X*62) [ 1 62 LSHIFT 3 / ] LITERAL +
  OVER (X*62) (X62) +
  NIP
  R> (X*62) ;

: XLN ( n1 -- n2 )
  DUP 1 < IF DROP 0 EXIT THEN
  (XNORM) >R
  DUP (X1) -
  SWAP (X1) +
  >R
  S>D (XLSHIFT) (XLSHIFT) (DSHL6)
  R> SM/REM NIP
  (XATANH) 2*
  34 (XNEAR)
  R> (XLN2+) *
  28 (XNEAR)
  + ;

: XLOG ( n1 -- n2 )
  XLN (XLN10) X/ ;

\ atan on [-tan(pi/8), tan(pi/8)]. u = z*z stays under the sum.
: (XATAN0) ( z -- r )
  DUP >R
  DUP X*
  [ 1 XBITS LSHIFT 19 / ] LITERAL NEGATE
  OVER X* [ 1 XBITS LSHIFT 17 / ] LITERAL +
  OVER X* [ 1 XBITS LSHIFT 15 / ] LITERAL -
  OVER X* [ 1 XBITS LSHIFT 13 / ] LITERAL +
  OVER X* [ 1 XBITS LSHIFT 11 / ] LITERAL -
  OVER X* [ 1 XBITS LSHIFT 9 / ] LITERAL +
  OVER X* [ 1 XBITS LSHIFT 7 / ] LITERAL -
  OVER X* [ 1 XBITS LSHIFT 5 / ] LITERAL +
  OVER X* [ 1 XBITS LSHIFT 3 / ] LITERAL -
  OVER X* (X1) +
  NIP
  R> X* ;

\ 0 <= n <= 1.
: (XATANLE) ( n -- r )
  DUP (XTAN8) > IF
    DUP (X1) - SWAP (X1) + X/
    (XATAN0) (XPI4) +
    EXIT
  THEN
  (XATAN0) ;

: (XATANABS) ( n -- r )
  DUP (X1) > IF
    (X1) SWAP X/
    DUP 0= IF DROP XPI/2 EXIT THEN
    (XATANLE)
    XPI/2 SWAP -
    EXIT
  THEN
  (XATANLE) ;

: XATAN ( n1 -- n2 )
  DUP 0< IF NEGATE (XATANABS) NEGATE EXIT THEN
  (XATANABS) ;

\ y x -- angle. x is on top, same as FATAN2.
: XATAN2 ( n1 n2 -- n3 )
  2DUP OR 0= IF 2DROP 0 EXIT THEN
  OVER ABS OVER ABS > IF
    OVER 0< >R
    SWAP X/ XATAN
    R> IF XPI/2 + NEGATE ELSE XPI/2 SWAP - THEN
    EXIT
  THEN
  OVER 0< >R
  DUP 0< >R
  X/ XATAN
  R> IF
    R> IF XPI - ELSE XPI + THEN
  ELSE
    R> DROP
  THEN ;

\ Floor of the integer square root.
: (ISQRT) ( n -- root )
  DUP 2 < IF EXIT THEN
  >R
  (X1)
  BEGIN
    R@ OVER /
    OVER + 2/
    2DUP >
  WHILE
    NIP
  REPEAT
  DROP
  R> DROP ;

: (XASIN+) ( n -- r )
  DUP (X1) = IF DROP XPI/2 EXIT THEN
  DUP >R
  (X1) OVER - SWAP (X1) + *
  (ISQRT)
  DUP 0= IF R> 2DROP XPI/2 EXIT THEN
  R> SWAP X/ XATAN ;

: XASIN ( n1 -- n2 )
  DUP (X1) > IF DROP 0 EXIT THEN
  DUP (X1) NEGATE < IF DROP 0 EXIT THEN
  DUP 0< IF NEGATE (XASIN+) NEGATE EXIT THEN
  (XASIN+) ;

: XACOS ( n1 -- n2 )
  DUP (X1) > IF DROP 0 EXIT THEN
  DUP (X1) NEGATE < IF DROP 0 EXIT THEN
  DUP (X1) = IF DROP 0 EXIT THEN
  DUP (X1) NEGATE = IF DROP XPI EXIT THEN
  DUP >R
  (X1) OVER - SWAP (X1) + *
  (ISQRT)
  R> XATAN2 ;

ONLY FORTH DEFINITIONS
