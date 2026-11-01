\ FPMATH.fth — floating-point exercise
\
\ From Dr. Dobb's Journal, September 1988, translated by R. L. Smith.
\ Five passes of square root, log, exp, arctan, and sine. The last
\ result of each pass is printed. Runs on EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/FPMATH.fth
\   FPMATH
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW FPMATH_MODULE [THEN]

ONLY FORTH DEFINITIONS
ALSO FLOATING
DECIMAL

5 CONSTANT NLOOPS
FVARIABLE ARGUMENT
FVARIABLE RESULT

: F2* ( F: r -- r*2 ) 2.0E0 F* ;

: TESTSQRT ( -- )
  ." SQUARE ROOTS   "
  NLOOPS 0 DO
    ." ."
    0.0E0 ARGUMENT F!
    BEGIN
      ARGUMENT F@ 1000.0E0 F> 0=
    WHILE
      ARGUMENT F@ FSQRT RESULT F!
      ARGUMENT F@ 1.0E0 F+ ARGUMENT F!
    REPEAT
  LOOP
  CR ."   last " RESULT F@ F. CR ;

: TESTLN ( -- )
  ." LOGS   "
  NLOOPS 0 DO
    ." ."
    0.1E0 ARGUMENT F!
    BEGIN
      ARGUMENT F@ 1000.1E0 F> 0=
    WHILE
      ARGUMENT F@ FLN RESULT F!
      ARGUMENT F@ 1.0E0 F+ ARGUMENT F!
    REPEAT
  LOOP
  CR ."   last " RESULT F@ F. CR ;

: TESTEXP ( -- )
  ." EXPONENTIALS   "
  NLOOPS 0 DO
    ." ."
    0.0E0 ARGUMENT F!
    BEGIN
      ARGUMENT F@ 10.0E0 F> 0=
    WHILE
      ARGUMENT F@ FEXP RESULT F!
      ARGUMENT F@ 0.01E0 F+ ARGUMENT F!
    REPEAT
  LOOP
  CR ."   last " RESULT F@ F. CR ;

: TESTARCTAN ( -- )
  ." ARCTANS   "
  NLOOPS 0 DO
    ." ."
    0.1E0 ARGUMENT F!
    BEGIN
      ARGUMENT F@ 10.0E0 F> 0=
    WHILE
      ARGUMENT F@ FATAN RESULT F!
      ARGUMENT F@ 0.01E0 F+ ARGUMENT F!
    REPEAT
  LOOP
  CR ."   last " RESULT F@ F. CR ;

: TESTSIN ( -- )
  ." SINES   "
  NLOOPS 0 DO
    ." ."
    0.0E0 ARGUMENT F!
    BEGIN
      ARGUMENT F@ 3.141592653589793E0 F2* F> 0=
    WHILE
      ARGUMENT F@ FSIN RESULT F!
      ARGUMENT F@ 3.141592653589793E0 360.0E0 F/ F+ ARGUMENT F!
    REPEAT
  LOOP
  CR ."   last " RESULT F@ F. CR ;

: FPMATH ( -- )
  TESTSQRT TESTLN TESTEXP TESTARCTAN TESTSIN
  CR ." FPMATH finished." CR ;

ONLY FORTH ALSO FLOATING ALSO FORTH DEFINITIONS

CR .( Run: FPMATH ) CR
