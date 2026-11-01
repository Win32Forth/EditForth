\ KOKO.fth — Konrad Koller's fractal for the EditForth graphics window
\
\ Modifications for F-PC and TCOM by Tom Zimmer, 05/23/93.
\ The DOS program used 640x350x16, a BIOS clock seed, and BYE.
\ This copy draws on the COLOR8 window and returns to the console.
\
\ Load:
\   FROMLIB FLOAD Sample/KOKO.fth
\   KOKO
\
\ Return keeps the number that is shown. Any key in the graphics
\ window stops the plot and returns to the console.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW KOKO_MODULE [THEN]
[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]

ONLY FORTH DEFINITIONS
ALSO FLOATING
DECIMAL

FVARIABLE A
FVARIABLE BB
FVARIABLE C
FVARIABLE X
FVARIABLE Y
FVARIABLE YY
FVARIABLE FWID
FVARIABLE FHEI

: KOKO-CREDIT ( -- )
  CR ." KOKO, by Konrad Koller, draws a fractal in the graphics window."
  CR ." Return keeps a shown number. Any key returns to the console." CR
  ;

\ ( fvar -- )  Print the current value and accept a replacement.
: FPROMPT ( fvar -- )
  DUP F@ F. ." : "
  PAD 40 ACCEPT DUP 0= IF 2DROP EXIT THEN
  PAD SWAP >FLOAT IF F! ELSE DROP THEN ;

: KOKO-ASK ( -- )
  CR ." KOKO by Konrad Koller" CR
  CR ." Return keeps the value that is shown." CR
  57.23e0 A F!
  12.3e0 BB F!
  43.23e0 C F!
  CR ." A = " A FPROMPT
  CR ." BB = " BB FPROMPT
  CR ." C = " C FPROMPT
  ;

ONLY FORTH ALSO FLOATING ALSO GRAPHICS DEFINITIONS
DECIMAL

VARIABLE KOKO-N
VARIABLE KOKO-COLOR

: FSIGN ( F: r -- s )
  F0< IF -1.0e0 ELSE 1.0e0 THEN ;

: KOKO-STEP ( -- )
  Y F@ BB F@ F*
  C F@ F-
  FABS FSQRT
  Y F@ FSIGN F*
  X F@ FSWAP F-
  YY F!
  A F@ Y F@ F- X F!
  YY F@ Y F!
  C F@ FNEGATE C F! ;

: FPX ( F: r -- ) ( -- n flag )
  FDUP -1.0e0 F< IF FDROP 0 FALSE EXIT THEN
  FDUP G-PX S>D D>F F> IF FDROP 0 FALSE EXIT THEN
  F>S TRUE ;

: FPY ( F: r -- ) ( -- n flag )
  FDUP -1.0e0 F< IF FDROP 0 FALSE EXIT THEN
  FDUP G-PY S>D D>F F> IF FDROP 0 FALSE EXIT THEN
  F>S TRUE ;

: KOKO-PLOT ( -- )
  X F@ FWID F@ F+ FPX 0= IF DROP EXIT THEN
  Y F@ FHEI F@ F+ FPY 0= IF DROP DROP EXIT THEN
  G-PY 1- SWAP - PLOT ;

: KOKO ( -- )
  DECIMAL
  KOKO-ASK
  S" EditForth KOKO" APP-NAME
  WINDOW PIXEL-ON COLOR8
  WHITE
  G-PX 2/ S>D D>F FWID F!
  G-PY 2/ S>D D>F FHEI F!
  0.0e0 X F!  0.0e0 Y F!
  0 KOKO-N !  1 KOKO-COLOR !  KOKO-COLOR @ COLOR !
  65535 0 DO
    1 KOKO-N +!
    KOKO-N @ 256 MOD 0= IF
      KOKO-COLOR @ 1+ 15 MOD 1+ KOKO-COLOR !
      KOKO-COLOR @ COLOR !
    THEN
    KOKO-STEP
    KOKO-PLOT
    I 63 AND 0= IF PREFRESH KEY? IF LEAVE THEN THEN
  LOOP
  PREFRESH
  KEY? IF KEY DROP THEN
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO FLOATING ALSO GRAPHICS ALSO FORTH DEFINITIONS

KOKO-CREDIT
CR .( Run:  KOKO ) CR
