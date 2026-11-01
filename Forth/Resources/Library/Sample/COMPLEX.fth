\ COMPLEX.fth — complex floating point
\
\ Mark Smiley, with corrections by R. L. Smith. The F-PC version used a
\ software float stack (FPUSH, FPOP, FPSEXP). This copy uses the host
\ FLOATING words. A complex value is two floats: real, then imaginary
\ on top. It runs on EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/COMPLEX.fth
\   COMPLEX-DEMO
\
\ The word list is in Sample/COMPLEX.txt.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW COMPLEX_MODULE [THEN]

ONLY FORTH DEFINITIONS
ALSO FLOATING
DECIMAL

FVARIABLE ZT-RE
FVARIABLE ZT-IM
FVARIABLE ZT-RE2
FVARIABLE ZT-IM2
FVARIABLE ZT-DEN
FVARIABLE ZT-MAG

\ ( F: re im -- )  imag is on top.
: ZDROP ( F: z -- ) FDROP FDROP ;

: ZDUP ( F: z -- z z ) FOVER FOVER ;

: ZNIP ( F: z1 z2 -- z2 )
  ZT-IM F! ZT-RE F!
  FDROP FDROP
  ZT-RE F@ ZT-IM F@ ;

: ZSWAP ( F: z1 z2 -- z2 z1 )
  ZT-IM F! ZT-RE F!
  ZT-IM2 F! ZT-RE2 F!
  ZT-RE F@ ZT-IM F@
  ZT-RE2 F@ ZT-IM2 F@ ;

: ZNEGATE ( F: z -- -z )
  FNEGATE FSWAP FNEGATE FSWAP ;

: ZCONJUGATE ( F: z -- z* ) FNEGATE ;

: ZJ* ( F: z -- z*j ) FNEGATE FSWAP ;

: Z+ ( F: z1 z2 -- z3 )
  FROT F+
  ZT-IM F!
  F+
  ZT-IM F@ ;

: Z- ( F: z1 z2 -- z3 )
  ZT-IM F! ZT-RE F!
  ZT-IM2 F! ZT-RE2 F!
  ZT-RE2 F@ ZT-RE F@ F-
  ZT-IM2 F@ ZT-IM F@ F- ;

: F^2 ( F: r -- r^2 ) FDUP F* ;
: F2/ ( F: r -- r/2 ) 2.0E0 F/ ;
: F2* ( F: r -- r*2 ) 2.0E0 F* ;

: Z* ( F: z1 z2 -- z3 )
  ZT-IM F! ZT-RE F!
  ZT-IM2 F! ZT-RE2 F!
  ZT-RE2 F@ ZT-RE F@ F*
  ZT-IM2 F@ ZT-IM F@ F*
  F-
  ZT-RE2 F@ ZT-IM F@ F*
  ZT-IM2 F@ ZT-RE F@ F*
  F+ ;

: Z/ ( F: z1 z2 -- z3 )
  ZT-IM F! ZT-RE F!
  ZT-IM2 F! ZT-RE2 F!
  ZT-RE F@ F^2 ZT-IM F@ F^2 F+
  FDUP F0= ABORT" Z/ divide by zero"
  ZT-DEN F!
  ZT-RE2 F@ ZT-RE F@ F*
  ZT-IM2 F@ ZT-IM F@ F*
  F+ ZT-DEN F@ F/
  ZT-IM2 F@ ZT-RE F@ F*
  ZT-RE2 F@ ZT-IM F@ F*
  F- ZT-DEN F@ F/ ;

: ZVARIABLE ( "name" -- )
  CREATE FALIGN 0.0E0 F, 0.0E0 F, ;

: Z! ( addr -- ) ( F: re im -- )
  DUP 1 FLOATS + F! F! ;

: Z@ ( addr -- ) ( F: -- re im )
  DUP F@ 1 FLOATS + F@ ;

: ZMAG ( F: re im -- r )
  FDUP F* FSWAP FDUP F* F+ FSQRT ;

: TOPOLAR ( F: x y -- r theta )
  ZT-IM F! ZT-RE F!
  ZT-RE F@ ZT-IM F@ ZMAG
  ZT-IM F@ ZT-RE F@ FATAN2 ;

: TOCART ( F: r theta -- x y )
  ZT-IM F! ZT-RE F!
  ZT-RE F@ ZT-IM F@ FCOS F*
  ZT-RE F@ ZT-IM F@ FSIN F* ;

: ZSQRT ( F: re im -- re2 im2 )
  ZT-IM F! ZT-RE F!
  ZT-RE F@ ZT-IM F@ ZMAG ZT-MAG F!
  ZT-IM F@ F0< >R
  ZT-MAG F@ ZT-RE F@ F+ F2/ FSQRT
  ZT-MAG F@ ZT-RE F@ F- FABS F2/ FSQRT
  R> IF FNEGATE THEN ;

: -ZSQRT ( F: z -- z ) ZSQRT ZNEGATE ;

: Z. ( F: re im -- )
  FSWAP CR ."  real " F. ." imag " F. ;

: COMPLEX-DEMO ( -- )
  CR ." 2+3i plus 4+5i"
  2.0E0 3.0E0  4.0E0 5.0E0 Z+ Z.
  CR ." 2+3i times 4+5i"
  2.0E0 3.0E0  4.0E0 5.0E0 Z* Z.
  CR ." magnitude of 3+4i"
  3.0E0 4.0E0 ZMAG CR F. CR
  CR ." square root of -1"
  -1.0E0 0.0E0 ZSQRT Z.
  CR ." square root of i"
  0.0E0 1.0E0 ZSQRT Z. ;

ONLY FORTH ALSO FLOATING ALSO FORTH DEFINITIONS

CR .( Run: COMPLEX-DEMO ) CR
