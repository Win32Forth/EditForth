\ FIXEDPOINT32.fth — single-cell fixed point, 32-bit cells
\
\ EditForthPWA cells are signed 32-bit. FIXEDPOINT.fth is the 64-bit file.
\ A value is one signed cell. XBITS fraction bits sit at the bottom.
\ This file is built for 28. A real value then stays inside about +/-8.
\ Load it with 1 CELLS equal to 4.
\
\ + and - are the cell words. 2* doubles a value. 2/ halves it.
\ X* multiplies and X/ divides. Both round toward zero.
\ XSQRT of a negative value is 0.
\ XSIN and XCOS take radians. A huge angle loses a little,
\ because the turn is reduced with a rounded 2*pi.
\
\ XLN is the natural log. XLOG is base 10. Zero and negative return 0.
\ XEXP is e^x. XALOG is 10^x. A result smaller than one cell is 0.
\ A result above the cell is the largest cell. A result below the cell
\ is the most negative cell. XLN of a tiny positive value does that,
\ because ln(2^-28) is about -19 and does not fit.
\ XASIN and XACOS outside [-1,1] return 0. XATAN2 of 0 0 returns 0.
\
\ The fraction inside exp, log, and atanh is two bits wider than XBITS.
\ Results stay within a few cells of the nearest value.
\
\ Load on EditForthPWA:
\   INCLUDE the path of this file
\   ALSO FIXED-POINT
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW FIXEDPOINT32-MODULE [THEN]

1 CELLS 4 <> [IF]
  .( FIXEDPOINT32 needs 32-bit cells. ) CR ABORT
[THEN]

ONLY FORTH DEFINITIONS
VOCABULARY FIXED-POINT
ONLY FORTH ALSO FIXED-POINT DEFINITIONS
ALSO FLOATING
DECIMAL

[UNDEFINED] XBITS
[IF] 28 CONSTANT XBITS
[ELSE] .( Externally defined XBITS = ) XBITS . CR [THEN]

XBITS 28 <> [IF]
  .( FIXEDPOINT32 is built for 28 fraction bits. ) CR ABORT
[THEN]

\ Compile 2^XBITS into the caller. The value is frozen at load.
: XUNIT ( -- n )
  [ 1 XBITS LSHIFT ] LITERAL POSTPONE LITERAL ; IMMEDIATE

\ ( F: r -- ) ( -- n )
: F>X ( F: r -- n )
  XUNIT S>D D>F F* F>S ;

\ ( n -- ) ( F: -- r )
: X>F ( n -- ) ( F: -- r )
  S>D D>F XUNIT S>D D>F F/ ;

\ M*, then a logical right shift of XBITS on the 64-bit product.
\ The high cell is the sign. A negative product is biased by
\ 2^XBITS-1 so the shift rounds toward zero instead of down.
: X* ( n1 n2 -- n3 )
  M*
  DUP 0< IF [ 1 XBITS LSHIFT 1- ] LITERAL 0 D+ THEN
  [ 32 XBITS - ] LITERAL LSHIFT
  SWAP
  [ XBITS ] LITERAL RSHIFT
  OR ;

\ Shift a double left by XBITS. ( lo hi -- lo hi )
: (XLSHIFT) ( d1 -- d2 )
  SWAP >R
  [ XBITS ] LITERAL LSHIFT
  R@ [ 32 XBITS - ] LITERAL RSHIFT
  OR
  R> [ XBITS ] LITERAL LSHIFT
  SWAP ;

\ Fixed divide. Shifts the dividend up by XBITS, then SM/REM.
\ A zero divisor is the kernel divide. A quotient that does not
\ fit in the cell is that divide's overflow result.
: X/ ( n1 n2 -- n3 )
  SWAP S>D (XLSHIFT) ROT SM/REM NIP ;

\ Floor of the integer square root of a nonnegative double.
\ The guess starts above every root this file asks for.
: (DSQRT) ( d -- n )
  2DUP OR 0= IF 2DROP 0 EXIT THEN
  [ 1 30 LSHIFT ] LITERAL
  BEGIN
    DUP >R
    >R
    2DUP R> UM/MOD NIP
    R> SWAP OVER + 2/
    2DUP >
  WHILE
    NIP
  REPEAT
  DROP NIP NIP ;

\ Integer root of n<<XBITS, so the result keeps this scale.
\ Zero and negative return 0.
: XSQRT ( n1 -- n2 )
  DUP 1 < IF DROP 0 EXIT THEN
  S>D (XLSHIFT) (DSQRT) ;

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

\ The wide steps use a 64-bit double. Two extra fraction bits
\ leave a little headroom under the top of a 32-bit cell.
\ (XLN2) is ln 2 at 2^30. (XLOG2F) is log2(10)-3 at 2^30.
\ (ELN2) is ln 2 at 2^56, split into cells. (ELOG2) is log10(2)
\ at the same scale. (XMAX) is the largest positive cell.
744261118 CONSTANT (XLN2)
618095479 CONSTANT (XLN10)
345667660 CONSTANT (XLOG2F)
111189606 CONSTANT (XTAN8)
210828714 CONSTANT (XPI4)
379625062 CONSTANT (XSQRT2)
1 30 LSHIFT CONSTANT (X30)
1 XBITS LSHIFT CONSTANT (X1)
2147483647 CONSTANT (XMAX)
1 31 LSHIFT CONSTANT (XMIN)
-137244806 CONSTANT (ELN2LO)
11629079 CONSTANT (ELN2HI)
1115547644 CONSTANT (ELOG2LO)
5050445 CONSTANT (ELOG2HI)

\ Magnitude. The most negative cell has no positive twin,
\ so it becomes (XMAX). One cell at this scale is invisible
\ to the angles and powers that use it.
: (XABS) ( n -- u )
  DUP 0< 0= IF EXIT THEN
  NEGATE
  DUP 0< IF DROP (XMAX) THEN ;

\ Q30 multiply. Same bias as X*, then a 30-bit shift.
: (X*30) ( n1 n2 -- n3 )
  M*
  DUP 0< IF [ 1 30 LSHIFT 1- ] LITERAL 0 D+ THEN
  2 LSHIFT
  SWAP
  30 RSHIFT
  OR ;

\ Logical left shift of a double by 2. ( lo hi -- lo hi )
: (DSHL2) ( d1 -- d2 )
  2 LSHIFT
  OVER 30 RSHIFT OR
  SWAP
  2 LSHIFT
  SWAP ;

\ Logical left shift of a double by 30.
: (DSHL30) ( d1 -- d2 )
  30 LSHIFT
  OVER 2 RSHIFT OR
  SWAP
  30 LSHIFT
  SWAP ;

\ Cell e times a positive 64-bit constant. ( u clo chi -- d )
: (UM*C) ( u clo chi -- d )
  ROT
  DUP >R
  UM*
  DROP
  R> ROT
  UM*
  ROT
  + ;

\ Nearest cell after a right shift. Half goes away from zero.
: (XNEAR) ( n sh -- n2 )
  SWAP DUP 0< >R
  ABS SWAP
  DUP >R
  1- 1 SWAP LSHIFT
  +
  R> RSHIFT
  R> IF NEGATE THEN ;

\ Nearest Q28 cell of a double that holds a Q56 value.
\ A value that does not fit is the cell rail of that sign.
: (DSAT28) ( d -- n )
  DUP 0< >R
  R@ IF DNEGATE THEN
  [ 1 27 LSHIFT ] LITERAL 0 D+
  DUP 28 RSHIFT IF
    2DROP
    R> IF (XMIN) ELSE (XMAX) THEN
    EXIT
  THEN
  4 LSHIFT
  SWAP 28 RSHIFT
  OR
  DUP 0< IF
    DROP
    R> IF (XMIN) ELSE (XMAX) THEN
    EXIT
  THEN
  R> IF NEGATE THEN ;

\ x = k*ln2 + f, with f a Q30 fraction in [-ln2/2, ln2/2].
: (XEXPRED) ( n -- k f )
  S>D (DSHL2)
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

\ exp(f) at Q30. f is under half of ln 2, and stays there.
: (XEXPPOLY) ( f -- p )
  DUP >R
  (X30)
  16
  BEGIN
    >R
    OVER (X*30)
    R@ /
    (X30) +
    R> 1-
    DUP 0=
  UNTIL
  DROP NIP
  R> DROP ;

\ Turn Q30 exp(f) and the power of two into a Q28 cell.
\ A positive (k-2) shifts left. A negative one shifts right.
: (XEXP-SCALE) ( p k -- n )
  2 -
  DUP 0= IF DROP EXIT THEN
  DUP 0> IF
    DUP 30 >= IF 2DROP (XMAX) EXIT THEN
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
  DUP 30 > IF 2DROP 0 EXIT THEN
  (XNEAR) ;

: (XEXP-KF) ( k f -- n )
  (XEXPPOLY) SWAP (XEXP-SCALE) ;

: XEXP ( n1 -- n2 )
  (XEXPRED) (XEXP-KF) ;

\ 10^x for a nonnegative cell. y = x*log2(10) is built at 2^60.
\ k is the nearest integer of y. f is the fraction times ln 2.
: (XALOG+) ( n -- k f )
  DUP (XLOG2F) M*
  ROT 3 M* (DSHL30) D+
  DUP 26 RSHIFT
  OVER [ 1 25 LSHIFT ] LITERAL AND IF 1+ THEN
  DUP >R
  26 LSHIFT
  0 SWAP
  D-
  (DSAT28)
  R> SWAP
  (XLN2) (X*30) ;

: XALOG ( n1 -- n2 )
  DUP 0< >R
  (XABS)
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

\ atanh at Q30. s*s is consumed by the last NIP.
: (XATANH) ( s -- a )
  DUP >R
  DUP (X*30)
  [ 1 30 LSHIFT 13 / ] LITERAL
  OVER (X*30) [ 1 30 LSHIFT 11 / ] LITERAL +
  OVER (X*30) [ 1 30 LSHIFT 9 / ] LITERAL +
  OVER (X*30) [ 1 30 LSHIFT 7 / ] LITERAL +
  OVER (X*30) [ 1 30 LSHIFT 5 / ] LITERAL +
  OVER (X*30) [ 1 30 LSHIFT 3 / ] LITERAL +
  OVER (X*30) (X30) +
  NIP
  R> (X*30) ;

\ ln of the normalized mantissa, as a Q28 cell.
: (XLN-M) ( m -- ln )
  DUP (X1) -
  SWAP (X1) +
  >R
  S>D (DSHL30)
  R> SM/REM NIP
  (XATANH) 2*
  2 (XNEAR) ;

\ e * c, then restore the sign of e. ( e clo chi -- d )
: (E*C) ( e clo chi -- d )
  ROT
  DUP 0< >R
  ABS
  ROT ROT
  (UM*C)
  R> IF DNEGATE THEN ;

\ Add e * c to a Q28 cell. c is the 2^56 constant under the call.
: (XADD-E) ( q28 e clo chi -- n )
  (E*C)
  ROT S>D (XLSHIFT) D+
  (DSAT28) ;

: XLN ( n1 -- n2 )
  DUP 1 < IF DROP 0 EXIT THEN
  (XNORM) >R
  (XLN-M)
  R> (ELN2LO) (ELN2HI) (XADD-E) ;

: XLOG ( n1 -- n2 )
  DUP 1 < IF DROP 0 EXIT THEN
  (XNORM) >R
  (XLN-M) (XLN10) X/
  R> (ELOG2LO) (ELOG2HI) (XADD-E) ;

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
  DUP 0< IF (XABS) (XATANABS) NEGATE EXIT THEN
  (XATANABS) ;

\ y x -- angle. x is on top, same as FATAN2.
: XATAN2 ( n1 n2 -- n3 )
  2DUP OR 0= IF 2DROP 0 EXIT THEN
  OVER (XABS) OVER (XABS) > IF
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

: (XASIN+) ( n -- r )
  DUP (X1) = IF DROP XPI/2 EXIT THEN
  DUP >R
  (X1) OVER - SWAP (X1) +
  M*
  (DSQRT)
  R> SWAP XATAN2 ;

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
  (X1) OVER - SWAP (X1) +
  M*
  (DSQRT)
  R> XATAN2 ;

ONLY FORTH DEFINITIONS
